"""Aperçu « argile » de Yiero (npz de mesh_yiero.py ou .glb) rendu par Blender (Cycles CPU, débruité).
  python preview_yiero.py --npz mc.npz --out planche.png [--views front,three,profile,face] [--size 480]
Vues dans le repère de PaperYiero ; la crinière (mèches) est rendue en tubes effilés.
"""
import argparse
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

VIEWS = {
    "front": ((0, 30, 160), (0, 22, 5), 40.0),
    "three": ((115, 45, 115), (0, 22, 5), 40.0),
    "profile": ((165, 30, 5), (0, 22, 5), 40.0),
    "back": ((-95, 45, -115), (0, 22, 0), 40.0),
    "face": ((0, 31, 58), (0, 28, 5), 42.0),
    "face34": ((34, 36, 46), (0, 29, 4), 44.0),
    "low": ((-3, 2, 70), (0, 30, 0), 60.0),
    "hand": ((-60, 26, 92), (-38, 6, 52), 40.0),
    "top": ((0, 150, 30), (0, 10, 10), 45.0),
    "mouth": ((4, 22, 36), (0, 22, 6), 44.0),
}


def g2b(v):
    return Vector((v[0], -v[2], v[1]))


def setup_scene(size, samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    try:
        scene.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        pass
    scene.cycles.max_bounces = 2
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 3
    scene.render.resolution_x = size
    scene.render.resolution_y = int(size * 0.75)
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("w")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.3, 0.31, 0.34, 1.0)
    bg.inputs[1].default_value = 0.5
    # clé (haut gauche avant), contre-jour (arrière), débouchage
    for rot_e, energy in (((0.85, 0.0, 0.55), 3.4), ((1.25, 0.0, -2.6), 2.2), ((1.45, 0.0, 1.9), 0.8)):
        sun = bpy.data.lights.new("sun", "SUN")
        sun.energy = energy
        sun.angle = 0.15
        ob = bpy.data.objects.new("sun", sun)
        ob.rotation_euler = rot_e
        scene.collection.objects.link(ob)
    return scene


def make_mat(name, color, rough, emit=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rough
    if emit > 0.0:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emit
    return mat


def add_mesh(verts, faces, name, mat):
    me = bpy.data.meshes.new(name)
    vb = np.stack([verts[:, 0], -verts[:, 2], verts[:, 1]], axis=1)
    me.from_pydata(vb.tolist(), [], faces.tolist())
    me.update()
    me.polygons.foreach_set("use_smooth", np.ones(len(me.polygons), dtype=bool))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(mat)
    return ob


def add_strands(points, widths, mat):
    cu = bpy.data.curves.new("mane", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 1.0
    cu.bevel_resolution = 2
    cu.use_fill_caps = True
    for pts, ws in zip(points, widths):
        sp = cu.splines.new("POLY")
        sp.points.add(len(pts) - 1)
        for i, (p, w) in enumerate(zip(pts, ws)):
            b = g2b(p)
            sp.points[i].co = (b.x, b.y, b.z, 1.0)
            sp.points[i].radius = float(w)
    ob = bpy.data.objects.new("mane", cu)
    bpy.context.scene.collection.objects.link(ob)
    cu.materials.append(mat)
    return ob


def render_views(scene, views, out):
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    paths = []
    base = os.path.splitext(out)[0]
    for name in views:
        eye, look, fov = VIEWS[name]
        cam.location = g2b(eye)
        direction = g2b(look) - g2b(eye)
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        cam_data.sensor_fit = "VERTICAL"
        cam_data.angle = math.radians(fov)
        cam_data.clip_end = 2000.0
        scene.render.filepath = "%s_%s.png" % (base, name)
        bpy.ops.render.render(write_still=True)
        paths.append(scene.render.filepath)
    return paths


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--npz")
    ap.add_argument("--glb")
    ap.add_argument("--out", required=True)
    ap.add_argument("--views", default="front,three,profile,face")
    ap.add_argument("--size", type=int, default=480)
    ap.add_argument("--samples", type=int, default=10)
    ap.add_argument("--ground", type=int, default=1)
    args = ap.parse_args(argv)
    scene = setup_scene(args.size, args.samples)
    if args.npz:
        data = np.load(args.npz)
        clay = make_mat("clay", (0.5, 0.48, 0.47, 1.0), 0.5)
        add_mesh(data["verts"], data["faces"], "Yiero", clay)
        if "teeth_v" in data:
            add_mesh(data["teeth_v"], data["teeth_f"], "Teeth", make_mat("teeth", (0.92, 0.86, 0.7, 1.0), 0.3))
            add_mesh(data["claws_v"], data["claws_f"], "Claws", make_mat("claw", (0.25, 0.2, 0.16, 1.0), 0.3))
            eye_mat = make_mat("eye", (0.95, 0.93, 0.85, 1.0), 0.3, 0.8)
            for e in data["eyes"]:
                bpy.ops.mesh.primitive_uv_sphere_add(radius=float(e[3]), location=g2b(e[:3]), segments=32, ring_count=16)
                ob = bpy.context.active_object
                ob.scale = (1.0, 0.72, 1.0)
                ob.data.materials.append(eye_mat)
                bpy.ops.object.shade_smooth()
        if "fringe_v" in data:
            add_mesh(data["fringe_v"], data["fringe_f"], "Fringe", clay)
        if args.ground:
            bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, 0))
            ob = bpy.context.active_object
            ob.data.materials.append(make_mat("ink", (0.04, 0.035, 0.04, 1.0), 0.25))
    elif args.glb:
        bpy.ops.import_scene.gltf(filepath=args.glb)
    paths = render_views(scene, args.views.split(","), args.out)
    print("PREVIEW", " ".join(paths))


if __name__ == "__main__":
    main()
