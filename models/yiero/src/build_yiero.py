"""Construit models/yiero/yiero.glb : maillage sculpté (SDF), décimé, rigué et peint (masques).

Lancer avec le Python de Blender (module bpy) :
  <blender-venv>/bin/python models/yiero/src/build_yiero.py --out models/yiero/yiero.glb
Options : --res 0.22 (pas du marching cubes), --target 36000 (triangles du corps),
          --cache /tmp/x.npz (réutilise le maillage brut si la forme n'a pas changé).

Contenu du .glb (repère Godot, +Z = devant) :
  - « YieroRig » : armature (os listés par yiero_shape.Layout) ;
  - « YieroBody » : maillage skinné, 3 matériaux : flesh (peau, gencives, gueule), teeth, claw ;
      UV  = position de repos (x, y), UV2 = (z de repos, paramètre t le long des dents/griffes) ;
      COLOR = (gencive, intérieur de gueule, occlusion, brillance) ;
  - « ToothChip » : pointe de la dent cassée (non skinnée, en repère de repos, suit l'os head).
"""
import argparse
import hashlib
import math
import os
import sys
import time

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import yiero_shape as ys  # noqa: E402
import mesh_yiero as ym  # noqa: E402


def g2b(a):
    a = np.asarray(a, dtype=np.float64)
    return np.stack([a[..., 0], -a[..., 2], a[..., 1]], axis=-1)


def b2g(a):
    a = np.asarray(a, dtype=np.float64)
    return np.stack([a[..., 0], a[..., 2], -a[..., 1]], axis=-1)


def shape_hash():
    h = hashlib.sha1()
    for name in ("yiero_shape.py", "mesh_yiero.py"):
        with open(os.path.join(HERE, name), "rb") as f:
            h.update(f.read())
    return h.hexdigest()[:16]


# ---------------------------------------------------------------------------
# Blender : maillage, décimation
# ---------------------------------------------------------------------------
def new_mesh_object(name, verts_g, faces):
    me = bpy.data.meshes.new(name)
    vb = g2b(verts_g)
    me.vertices.add(len(vb))
    me.vertices.foreach_set("co", vb.astype(np.float32).ravel())
    nf = len(faces)
    me.loops.add(nf * 3)
    me.loops.foreach_set("vertex_index", faces.astype(np.int32).ravel())
    me.polygons.add(nf)
    me.polygons.foreach_set("loop_start", np.arange(0, nf * 3, 3, dtype=np.int32))
    me.update(calc_edges=True)
    me.validate(clean_customdata=False)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def read_tris(ob):
    me = ob.data
    me.calc_loop_triangles()
    nv = len(me.vertices)
    co = np.zeros(nv * 3, dtype=np.float32)
    me.vertices.foreach_get("co", co)
    nt = len(me.loop_triangles)
    tri = np.zeros(nt * 3, dtype=np.int32)
    me.loop_triangles.foreach_get("vertices", tri)
    return b2g(co.reshape(-1, 3)), tri.reshape(-1, 3).astype(np.int64)


def decimate(ob, target, keep_weights):
    vg = ob.vertex_groups.new(name="keep")
    kw = np.round(keep_weights, 1)
    for w in np.unique(kw):
        idx = np.nonzero(kw == w)[0]
        if len(idx) and w > 0.0:
            vg.add(idx.tolist(), float(w) * 0.7, "REPLACE")
    n0 = len(ob.data.polygons)
    mod = ob.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = min(1.0, target / float(n0))
    mod.use_collapse_triangulate = True
    mod.use_symmetry = True
    mod.symmetry_axis = "X"
    mod.vertex_group = "keep"
    mod.vertex_group_factor = 1.0
    mod.invert_vertex_group = True
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    out = bpy.data.objects.new(ob.name + "_dec", me)
    bpy.context.scene.collection.objects.link(out)
    bpy.data.objects.remove(ob)
    return out


# ---------------------------------------------------------------------------
# Attributs calculés à partir de la forme
# ---------------------------------------------------------------------------
def sdf_normals(shape, pts, eps=0.12):
    g = np.zeros_like(pts)
    for i in range(3):
        o = np.zeros(3)
        o[i] = eps
        g[:, i] = shape.sdf(pts + o) - shape.sdf(pts - o)
    n = np.linalg.norm(g, axis=1, keepdims=True)
    return g / np.maximum(n, 1e-9)


def mesh_normals(verts, faces):
    n = np.zeros_like(verts)
    fn = np.cross(verts[faces[:, 1]] - verts[faces[:, 0]], verts[faces[:, 2]] - verts[faces[:, 0]])
    for k in range(3):
        np.add.at(n, faces[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)


def body_masks(shape, v, n):
    u, uc, rho, th, c, hh0, rs = shape.mouth_coords(v)
    d_slit = shape.sd_slit(v)
    d_cav = shape.sd_cavity(v)
    d_tongue = shape.sd_tongue(v)
    inside_lip = rho < rs - 0.3
    gum = (np.abs(d_slit) < 0.55) & inside_lip & (np.abs(u) < 1.02)
    gum_in = (np.abs(d_cav) < 0.6) & (rho > rs - 3.3) & (np.abs(u) < 1.0)
    gum = (gum | gum_in).astype(np.float64)
    mouth = (((np.abs(d_cav) < 0.7) | (np.abs(d_tongue) < 0.55)) & (rho < rs - 0.4)).astype(np.float64)
    mouth = np.maximum(mouth - gum, 0.0)
    # occlusion par le champ de distance (5 pas le long de la normale)
    ao = np.zeros(len(v))
    for i in range(1, 6):
        h = 0.7 * i
        ao += (h - shape.sdf(v + n * h)) / (2.0 ** i)
    ao = np.clip(1.0 - 0.32 * ao, 0.0, 1.0)
    # brillance de base : encre humide sur les mains, l'avant-bras et au ras de l'encre
    wet = 0.35 + 0.4 * (ys.vnoise(v * 0.09, 3) - 0.5)
    wet += 0.55 * ys.smoothstep(7.0, 0.0, v[:, 1])
    for s in (-1, 1):
        a = shape.layout.arms[s]
        wet += 0.45 * ys.smoothstep(14.0, 4.0, np.linalg.norm(v - a["W"], axis=1))
    wet = np.clip(wet, 0.0, 1.0)
    return np.stack([gum, mouth, ao, wet], axis=1)


def keep_weights(shape, v):
    """Densité préservée à la décimation : visage, gueule, mains."""
    w = np.zeros(len(v))
    w = np.maximum(w, ys.smoothstep(16.0, 8.0, np.linalg.norm((v - ys.v3(0, 26, 6)) * ys.v3(0.7, 1.0, 1.0), axis=1)))
    for s in (-1, 1):
        a = shape.layout.arms[s]
        hp = [a["W"]] + [j for fg in a["fingers"] for j in fg["joints"]] + list(a["thumb"]["joints"])
        for p in hp:
            w = np.maximum(w, ys.smoothstep(4.5, 1.5, np.linalg.norm(v - p, axis=1)))
    return w


# ---------------------------------------------------------------------------
# Poids de peau
# ---------------------------------------------------------------------------
def falloff(d, r_in, r_out):
    return ys.smoothstep(r_out, r_in, d)


def jawness(shape, v):
    u, uc, rho, th, c, hh0, rs = shape.mouth_coords(v)
    au = np.abs(u)
    width = 0.35 + 3.0 * np.clip(au - 0.92, 0.0, 1.0)
    line = np.where(au <= 1.0, c, ys.CORNER_Y - 0.6)
    j = ys.smoothstep(line + width, line - width, v[:, 1])
    j *= ys.smoothstep(-12.5, -6.5, v[:, 2])
    # bas de la mâchoire au-dessus du cou : reste à la mâchoire
    return j


def head_split(shape, v):
    """Répartit la part « tête » entre head, jaw, corner_*, brow_*, cheek_*."""
    L = shape.layout
    j = jawness(shape, v)
    out = {}
    rest = np.ones(len(v))
    for s in (-1, 1):
        t = L.tag(s)
        cpt = L.corner_point(s)
        cw = 0.9 * falloff(np.linalg.norm(v - cpt, axis=1), 1.2, 7.5)
        bw = 0.9 * falloff(np.linalg.norm((v - ys.v3(ys.EYE_X * s, 40.0, 8.0)) * ys.v3(0.8, 1.3, 1.0), axis=1), 1.0, 5.2) * (1.0 - j)
        kw = 0.85 * falloff(np.linalg.norm((v - ys.v3(8.8 * s, 31.2, 7.4)) * ys.v3(0.85, 1.25, 1.0), axis=1), 0.8, 4.6) * (1.0 - j)
        tot = cw + bw + kw
        scale = np.where(tot > 0.95, 0.95 / np.maximum(tot, 1e-9), 1.0)
        cw, bw, kw = cw * scale, bw * scale, kw * scale
        out["corner" + t] = cw
        out["brow" + t] = bw
        out["cheek" + t] = kw
        rest = rest - cw - bw - kw
    rest = np.maximum(rest, 0.0)
    out["head"] = rest * (1.0 - j)
    out["jaw"] = rest * j
    return out


def part_distances(shape, v):
    """Distances aux sous-formes, groupées par os (liste de (os ou 'HEAD', distance))."""
    L = shape.layout
    parts = []
    # torse
    ab = ys.sd_round_cone(v, ys.v3(0, -30, -12.5), ys.v3(0, 0, -12.0), 12.0, 16.5)
    parts.append(("spine", ab))
    rib = ys.sd_ellipsoid(v, ys.v3(0, 10.0, -12.0), ys.v3(19.5, 14.0, 12.5))
    w_chest = ys.smoothstep(2.0, 15.0, v[:, 1])
    parts.append(("spine", rib + 3.0 * w_chest))
    parts.append(("chest", rib + 3.0 * (1.0 - w_chest)))
    hunch = ys.sd_ellipsoid(v, ys.v3(0, 23.0, -16.0), ys.v3(19.0, 10.5, 11.0))
    parts.append(("chest", hunch))
    parts.append(("chest", shape.sd_spines(v, False)))
    neck = shape.sd_neck(v)
    parts.append(("neck", neck - 0.6))
    parts.append(("HEAD", shape.head_base(v)))
    parts.append(("HEAD", shape.sd_spines(v, True)))
    parts.append(("HEAD", shape.sd_lip(v)))
    for s in (-1, 1):
        t = L.tag(s)
        a = L.arms[s]
        pec = ys.sd_ellipsoid(v, ys.v3(8.6 * s, 12.0, -2.5), ys.v3(8.4, 6.4, 4.4))
        parts.append(("chest", pec))
        trap = ys.sd_round_cone(v, ys.v3(6.0 * s, 28.0, -13.0), ys.v3(23.0 * s, 22.5, -5.0), 7.0, 4.6)
        parts.append(("chest", trap + 1.0))
        clav = ys.sd_round_cone(v, ys.v3(4.0 * s, 21.5, -6.5), ys.v3(24.0 * s, 20.0, -2.5), 2.4, 3.0)
        parts.append(("clavicle" + t, clav))
        delt = ys.sd_ellipsoid_frame(v, a["S"] + a["d1"] * 3.5 + ys.v3(0, 2.2, -0.5), ys._frame(a["d1"]), ys.v3(6.6, 6.0, 9.5))
        parts.append(("clavicle" + t, delt + 1.2))
        parts.append(("upperarm" + t, delt + 0.4))
        S, E, W = a["S"], a["E"], a["W"]
        parts.append(("upperarm" + t, ys.sd_round_cone(v, S + a["d1"] * 2.0, E, 4.6, 3.0)))
        parts.append(("forearm" + t, ys.sd_sphere(v, E - ys.norm(a["d2"] - a["d1"]) * 1.4, 3.2) + 0.3))
        parts.append(("forearm" + t, ys.sd_round_cone(v, E, W, 3.25, 1.95)))
        parts.append(("hand" + t, ys.sd_round_cone(v, W - a["f"] * 1.0, W + a["f"] * 1.6, 2.1, 2.35) + 0.4))
        frame = np.stack([a["out"], a["up"], a["f"]])
        parts.append(("hand" + t, ys.sd_ellipsoid_frame(v, W + a["f"] * 6.0 - a["up"] * 0.2, frame, ys.v3(5.5, 1.9, 6.9))))
        for i, name in enumerate(ys.FINGERS):
            fg = a["fingers"][i]
            jn = fg["joints"]
            r = fg["radii"]
            parts.append(("hand" + t, ys.sd_sphere(v, jn[0] + a["up"] * 0.25, r[0] + 0.25) + 0.5))
            for k in range(3):
                parts.append(("%s_%d%s" % (name, k + 1, t), ys.sd_round_cone(v, jn[k], jn[k + 1], r[2 * k], r[2 * k + 1])))
        th = a["thumb"]
        jn = th["joints"]
        r = th["radii"]
        parts.append(("hand" + t, ys.sd_ellipsoid_frame(v, W + a["f"] * 3.6 - a["out"] * 2.6 - a["up"] * 0.4, frame, ys.v3(2.4, 1.9, 3.4)) + 0.3))
        for k in range(3):
            parts.append(("thumb_%d%s" % (k + 1, t), ys.sd_round_cone(v, jn[k], jn[k + 1], r[2 * k], r[2 * k + 1])))
    return parts


def body_weights(shape, v, tau=1.1):
    parts = part_distances(shape, v)
    names = [p[0] for p in parts]
    d = np.stack([p[1] for p in parts], axis=1)
    dmin = d.min(axis=1, keepdims=True)
    w = np.exp(-np.maximum(d - dmin, 0.0) / tau)
    w[d - dmin > 6.0 * tau] = 0.0
    bones = {}
    for k, name in enumerate(names):
        bones.setdefault(name, np.zeros(len(v)))
        bones[name] += w[:, k]
    head = bones.pop("HEAD")
    for name, wv in head_split(shape, v).items():
        bones.setdefault(name, np.zeros(len(v)))
        bones[name] += head * wv
    return bones


def rigid_weights(bone_map, n):
    """bone_map : dict os -> poids (scalaire) ; renvoie dict os -> tableau."""
    return {b: np.full(n, w) for b, w in bone_map.items()}


def tooth_bones(shape, tooth):
    L = shape.layout
    root = tooth["root"][None, :]
    hs = head_split(shape, root)
    out = {}
    if tooth["upper"]:
        total = hs["head"][0] + hs["jaw"][0]
        for k, w in hs.items():
            if k.startswith("corner"):
                out[k] = w[0] * 0.9
        out["head"] = max(0.0, 1.0 - sum(out.values()))
    else:
        for k, w in hs.items():
            if k.startswith("corner"):
                out[k] = w[0] * 0.7
        out["jaw"] = max(0.0, 1.0 - sum(out.values()))
    return out


def top4(bones, n):
    names = list(bones.keys())
    m = np.stack([bones[k] for k in names], axis=1)
    idx = np.argsort(-m, axis=1)[:, :4]
    wsel = np.take_along_axis(m, idx, axis=1)
    wsel = np.where(wsel < 0.015, 0.0, wsel)
    s = wsel.sum(axis=1, keepdims=True)
    wsel = wsel / np.maximum(s, 1e-9)
    return names, idx, wsel


# ---------------------------------------------------------------------------
# Construction de l'objet final
# ---------------------------------------------------------------------------
def make_material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    return mat


def build_final(shape, body_v, body_f, args):
    t0 = time.time()
    n_body = sdf_normals(shape, body_v)
    masks = body_masks(shape, body_v, n_body)
    bw = body_weights(shape, body_v)
    print("attributs du corps en %.1f s" % (time.time() - t0))
    verts = [body_v]
    faces = [body_f]
    normals = [n_body]
    mats = [np.zeros(len(body_f), dtype=np.int32)]
    colors = [masks]
    tparam = [np.zeros(len(body_v))]
    weights = [bw]
    offset = len(body_v)
    chip_v = chip_f = None
    for tooth in ys.make_teeth(shape):
        tv, tf = tooth["verts"], tooth["faces"]
        if tooth["chip"]:
            tv, tf, chip_v, chip_f = split_chip(tooth)
        nt = mesh_normals(tv, tf)
        verts.append(tv)
        faces.append(tf + offset)
        normals.append(nt)
        mats.append(np.ones(len(tf), dtype=np.int32))
        tt = np.clip(np.dot(tv - tooth["root"], tooth["down"]) / tooth["length"], 0.0, 1.0)
        tparam.append(tt)
        col = np.zeros((len(tv), 4))
        col[:, 0] = 1.0 if tooth["upper"] else 0.0
        col[:, 1] = float(tooth["row"])
        col[:, 2] = 1.0
        col[:, 3] = 1.0
        colors.append(col)
        weights.append(rigid_weights(tooth_bones(shape, tooth), len(tv)))
        offset += len(tv)
    for claw in ys.make_claws(shape):
        cv, cf = claw["verts"], claw["faces"]
        nc = mesh_normals(cv, cf)
        verts.append(cv)
        faces.append(cf + offset)
        normals.append(nc)
        mats.append(np.full(len(cf), 2, dtype=np.int32))
        base = cv[-1]
        dist = np.linalg.norm(cv - base, axis=1)
        tparam.append(np.clip(dist / max(dist.max(), 1e-6), 0.0, 1.0))
        col = np.zeros((len(cv), 4))
        col[:, 2] = 1.0
        col[:, 3] = 1.0
        colors.append(col)
        bone = "%s_3%s" % (claw["finger"], shape.layout.tag(claw["side"]))
        weights.append(rigid_weights({bone: 1.0}, len(cv)))
        offset += len(cv)
    V = np.concatenate(verts)
    F = np.concatenate(faces)
    N = np.concatenate(normals)
    M = np.concatenate(mats)
    C = np.concatenate(colors)
    T = np.concatenate(tparam)
    all_bones = [b[0] for b in shape.layout.bones]
    W = {b: np.zeros(len(V)) for b in all_bones}
    start = 0
    for wd in weights:
        n = len(next(iter(wd.values())))
        for b, wv in wd.items():
            W[b][start:start + n] += wv
        start += n
    names, idx, wsel = top4(W, len(V))
    ob = new_mesh_object("YieroBody", V, F)
    me = ob.data
    me.polygons.foreach_set("material_index", M)
    for mname, col in (("flesh", (0.05, 0.02, 0.02, 1)), ("teeth", (0.9, 0.84, 0.68, 1)), ("claw", (0.2, 0.16, 0.12, 1))):
        me.materials.append(make_material(mname, col))
    me.polygons.foreach_set("use_smooth", np.ones(len(F), dtype=bool))
    loops_v = np.zeros(len(me.loops), dtype=np.int32)
    me.loops.foreach_get("vertex_index", loops_v)
    uv0 = me.uv_layers.new(name="UVMap")
    uv1 = me.uv_layers.new(name="UVRest")
    uva = np.stack([V[loops_v, 0], 1.0 - V[loops_v, 1]], axis=1)
    uvb = np.stack([V[loops_v, 2], 1.0 - T[loops_v]], axis=1)
    uv0.data.foreach_set("uv", uva.astype(np.float32).ravel())
    uv1.data.foreach_set("uv", uvb.astype(np.float32).ravel())
    ca = me.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
    ca.data.foreach_set("color", C.astype(np.float32).ravel())
    me.color_attributes.active_color = ca
    me.normals_split_custom_set_from_vertices(g2b(N).tolist())
    # groupes de sommets
    groups = {name: ob.vertex_groups.new(name=name) for name in names}
    for slot in range(4):
        for vi in range(len(V)):
            w = float(wsel[vi, slot])
            if w <= 0.0:
                continue
            groups[names[idx[vi, slot]]].add([vi], w, "REPLACE")
    print("objet final : %d sommets, %d triangles (corps %d)" % (len(V), len(F), len(body_f)))
    chip_ob = None
    if chip_v is not None:
        chip_ob = new_mesh_object("ToothChip", chip_v, chip_f)
        chip_ob.data.materials.append(bpy.data.materials["teeth"])
        chip_ob.data.polygons.foreach_set("use_smooth", np.ones(len(chip_f), dtype=bool))
        cn = mesh_normals(chip_v, chip_f)
        chip_ob.data.normals_split_custom_set_from_vertices(g2b(cn).tolist())
        lv = np.zeros(len(chip_ob.data.loops), dtype=np.int32)
        chip_ob.data.loops.foreach_get("vertex_index", lv)
        u0 = chip_ob.data.uv_layers.new(name="UVMap")
        u1 = chip_ob.data.uv_layers.new(name="UVRest")
        u0.data.foreach_set("uv", np.stack([chip_v[lv, 0], 1.0 - chip_v[lv, 1]], axis=1).astype(np.float32).ravel())
        u1.data.foreach_set("uv", np.stack([chip_v[lv, 2], np.full(len(lv), 0.2)], axis=1).astype(np.float32).ravel())
        cc = chip_ob.data.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
        col = np.tile(np.array([1.0, 0.0, 1.0, 1.0], dtype=np.float32), len(chip_v))
        cc.data.foreach_set("color", col)
    return ob, chip_ob


def split_chip(tooth):
    """Coupe la dent en deux : chicot (reste sur la gencive) et pointe (éclat qui saute)."""
    v, f = tooth["verts"], tooth["faces"]
    t = np.dot(v - tooth["root"], tooth["down"]) / tooth["length"]
    cut = 0.52
    tip_mask = t > cut
    # chicot : on ne garde que les faces entièrement sous la coupe, puis on bouche
    keep_f = f[~np.any(tip_mask[f], axis=1)]
    stump_v, stump_f = compact(v, keep_f)
    stump_v, stump_f = cap_open(stump_v, stump_f, tooth["down"], jagged=True)
    tip_f = f[np.all(t[f] > cut - 0.2, axis=1)]
    tip_v, tip_f = compact(v, tip_f)
    tip_v, tip_f = cap_open(tip_v, tip_f, -tooth["down"], jagged=False)
    return stump_v, stump_f, tip_v, tip_f


def compact(v, f):
    used = np.unique(f.ravel())
    remap = -np.ones(len(v), dtype=np.int64)
    remap[used] = np.arange(len(used))
    return v[used], remap[f]


def cap_open(v, f, axis, jagged):
    """Bouche le bord ouvert (une boucle) par un éventail ; légèrement irrégulier si jagged."""
    edges = {}
    for tri in f:
        for a, b in ((tri[0], tri[1]), (tri[1], tri[2]), (tri[2], tri[0])):
            key = (min(a, b), max(a, b))
            edges[key] = edges.get(key, 0) + 1
    border = [e for e, c in edges.items() if c == 1]
    if not border:
        return v, f
    loop_pts = sorted(set([i for e in border for i in e]))
    centre = v[loop_pts].mean(axis=0) + axis * (0.25 if jagged else 0.1)
    v2 = np.vstack([v, centre[None, :]])
    ci = len(v)
    # orientation : on garde l'ordre des arêtes de bord dans les triangles existants (inversé)
    new_f = []
    for tri in f:
        for a, b in ((tri[0], tri[1]), (tri[1], tri[2]), (tri[2], tri[0])):
            if (min(a, b), max(a, b)) in edges and edges[(min(a, b), max(a, b))] == 1:
                new_f.append((b, a, ci))
    return v2, np.vstack([f, np.array(new_f, dtype=np.int64)])


def build_armature(shape):
    arm = bpy.data.armatures.new("YieroRig")
    ob = bpy.data.objects.new("YieroRig", arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    ebs = {}
    for name, head, tail, parent in shape.layout.bones:
        eb = arm.edit_bones.new(name)
        eb.head = g2b(head).tolist()
        eb.tail = g2b(tail).tolist()
        eb.use_deform = True
        ebs[name] = eb
    for name, head, tail, parent in shape.layout.bones:
        if parent:
            ebs[name].parent = ebs[parent]
            ebs[name].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(HERE, "..", "yiero.glb"))
    ap.add_argument("--res", type=float, default=0.22)
    ap.add_argument("--target", type=int, default=36000)
    ap.add_argument("--cache", default="")
    ap.add_argument("--blend", default="")
    args = ap.parse_args(argv)
    t0 = time.time()
    shape = ys.YieroShape()
    key = shape_hash() + "_%.3f" % args.res
    verts = faces = None
    if args.cache and os.path.exists(args.cache):
        data = np.load(args.cache)
        if str(data["key"]) == key:
            verts, faces = data["verts"], data["faces"]
            print("maillage brut repris du cache")
    if verts is None:
        verts, faces = ym.mesh_sdf(shape, args.res)
        if args.cache:
            np.savez_compressed(args.cache, verts=verts, faces=faces, key=key)
    print("maillage brut : %d triangles (%.1f s)" % (len(faces), time.time() - t0))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    raw = new_mesh_object("raw", verts, faces)
    dec = decimate(raw, args.target, keep_weights(shape, verts))
    body_v, body_f = read_tris(dec)
    bpy.data.objects.remove(dec)
    print("décimé : %d sommets, %d triangles (%.1f s)" % (len(body_v), len(body_f), time.time() - t0))
    body, chip = build_final(shape, body_v, body_f, args)
    rig = build_armature(shape)
    body.parent = rig
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in (rig, body, chip):
        if o is not None:
            o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    out = os.path.abspath(args.out)
    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_skins=True,
                              export_animations=False, export_morph=False, export_apply=False, export_yup=True,
                              export_normals=True, export_texcoords=True, export_vertex_color="ACTIVE",
                              export_materials="EXPORT", export_image_format="NONE")
    print("EXPORT", out, "%.1f s" % (time.time() - t0))


if __name__ == "__main__":
    main()
