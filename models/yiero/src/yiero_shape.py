"""Yiero (0.17) — forme sculptée par champ de distance signé (SDF), en numpy pur.

Repère de PaperYiero (Godot) : x à droite (côté « _r »), y en haut, z vers l'avant (vers ce que
Yiero regarde), origine = surface de l'encre quand rise = 1. Côté « _l » = x négatif (à gauche de
l'écran quand on le regarde de face), comme les sockets « eye_l » / « hand_l » de yiero_model.gd.

Design : un démon d'encre colossal qui sort de la mer d'encre jusqu'à la poitrine.
  - tête en bouclier (large aux pommettes, menton pointu), enfoncée entre des épaules voûtées ;
  - visage lisse et noir : arcades lourdes en V, orbites creusées où brillent deux yeux ronds,
    pommettes hautes et sillons poussés par un sourire qui fait le tour du visage ;
  - gueule : gencives, deux rangées de dents en aiguille, langue, gorge ;
  - crinière de mèches d'encre (fibres) autour du crâne, sur la nuque et les épaules ;
  - bras d'araignée (longs, coudes saillants), mains géantes osseuses, griffes crochues.

Le module décrit :
  - la disposition du squelette en pose de repos (Layout) ;
  - le champ de distance du corps (YieroShape.sdf) et ses sous-formes (pour les poids de peau) ;
  - les pièces explicites : dents, griffes, mèches de la crinière.
build_yiero.py s'en sert dans Blender pour mailler, riguer et exporter le .glb.
"""
import math
import numpy as np

# ---------------------------------------------------------------------------
# Repères du visage (les plans du film visent ces points : garder ces valeurs proches)
# ---------------------------------------------------------------------------
EYE_X = 7.4
EYE_Y = 35.5
EYE_Z = 6.9          # centre du globe (aplati en disque dans Godot)
EYE_R = 2.2
CORNER_Y = 30.5       # hauteur des commissures (sourire en croissant, coins sous les pommettes)
MOUTH_A_UP = 9.0      # chute de la lèvre du haut au centre
MOUTH_A_LO = 14.4     # chute de la lèvre du bas au centre
MOUTH_Z0 = -6.0       # axe vertical autour duquel la gueule s'enroule
MOUTH_THC = 1.20      # demi-ouverture angulaire du sourire (rad) : les coins sont sur les joues
CHIP_U = -0.16        # dent qui se brise au coup de drone (socket « teeth » en x ≈ -3)
BIG = 1.0e3


def v3(x, y, z):
    return np.array([x, y, z], dtype=np.float64)


def norm(v):
    return v / np.linalg.norm(v)


def rot(v, axis, ang):
    """Rotation de Rodrigues d'un vecteur autour d'un axe."""
    axis = norm(axis)
    return v * math.cos(ang) + np.cross(axis, v) * math.sin(ang) + axis * np.dot(axis, v) * (1.0 - math.cos(ang))


def mouth_up(u):
    return CORNER_Y - MOUTH_A_UP * (1.0 - u * u)


def mouth_lo(u):
    return CORNER_Y - MOUTH_A_LO * (1.0 - u * u)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------------------
# Primitives SDF vectorisées (p : (N, 3))
# ---------------------------------------------------------------------------
def length(p):
    return np.sqrt(np.sum(p * p, axis=-1))


def sd_sphere(p, c, r):
    return length(p - c) - r


def sd_ellipsoid(p, c, r):
    q = (p - c) / r
    k0 = length(q)
    k1 = length(q / r)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def sd_ellipsoid_frame(p, c, frame, r):
    """Ellipsoïde orienté : frame = matrice 3x3 dont les lignes sont les axes locaux."""
    q = (p - c) @ frame.T
    return sd_ellipsoid(q, np.zeros(3), r)


def sd_round_cone(p, a, b, r1, r2):
    ba = b - a
    l2 = float(ba @ ba)
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    pa = p - a
    y = pa @ ba
    z = y - l2
    w = pa * l2 - np.outer(y, ba)
    x2 = np.sum(w * w, axis=-1)
    y2 = y * y * l2
    z2 = z * z * l2
    k = math.copysign(1.0, rr) * rr * rr * x2
    d_end = np.sqrt(x2 + z2) * il2 - r2
    d_start = np.sqrt(x2 + y2) * il2 - r1
    d_mid = (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + y * rr) * il2 - r1
    return np.where(np.sign(z) * a2 * z2 > k, d_end, np.where(np.sign(y) * a2 * y2 < k, d_start, d_mid))


def sd_chain(p, pts, radii, k=0.0):
    """Suite de cônes arrondis le long d'une polyligne (rayon interpolé)."""
    d = np.full(p.shape[0], BIG)
    for i in range(len(pts) - 1):
        seg = sd_round_cone(p, pts[i], pts[i + 1], radii[i], radii[i + 1])
        d = np.minimum(d, seg) if k <= 0.0 else smin(d, seg, k)
    return d


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1.0 - h) + a * h - k * h * (1.0 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


def _hash3(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = h & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFF).astype(np.float64) / 65535.0


def vnoise(p, seed=0):
    """Bruit de valeur 3D lissé, dans [0, 1]."""
    fl = np.floor(p)
    i = fl.astype(np.int64)
    f = p - fl
    f = f * f * (3.0 - 2.0 * f)
    out = np.zeros(p.shape[0])
    for dx in (0, 1):
        wx = f[:, 0] if dx else 1.0 - f[:, 0]
        for dy in (0, 1):
            wy = f[:, 1] if dy else 1.0 - f[:, 1]
            for dz in (0, 1):
                wz = f[:, 2] if dz else 1.0 - f[:, 2]
                out += wx * wy * wz * _hash3(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out


def fbm(p, octaves=3, seed=0):
    total = np.zeros(p.shape[0])
    amp = 0.5
    scale = 1.0
    for o in range(octaves):
        total += amp * (vnoise(p * scale, seed + o * 17) - 0.5)
        amp *= 0.5
        scale *= 2.03
    return total


def _frame(axis_z):
    """Repère (lignes x, y, z) dont z = axis_z."""
    z = norm(axis_z)
    ref = v3(0, 1, 0) if abs(z[1]) < 0.9 else v3(1, 0, 0)
    x = norm(np.cross(ref, z))
    y = np.cross(z, x)
    return np.stack([x, y, z])


# ---------------------------------------------------------------------------
# Squelette en pose de repos
# ---------------------------------------------------------------------------
FINGERS = ("index", "middle", "ring", "pinky")
CLAW_LENGTHS = (7.6, 8.2, 7.8, 6.4, 7.0)


class Layout:
    """Articulations de repos (repère Godot). side : -1 = « _l » (x < 0), +1 = « _r »."""

    def __init__(self):
        self.bones = []      # (nom, tête, queue, parent)
        self.arms = {}
        for s in (-1, 1):
            self.arms[s] = self._arm(s)
        self._spine()
        for s in (-1, 1):
            self._arm_bones(s)

    @staticmethod
    def tag(s):
        return "_l" if s < 0 else "_r"

    def _spine(self):
        b = self.bones
        b.append(("root", v3(0, -34, -11.5), v3(0, -16, -11.5), None))
        b.append(("spine", v3(0, -16, -11.5), v3(0, 6, -11.5), "root"))
        b.append(("chest", v3(0, 6, -11.5), v3(0, 21, -10.5), "spine"))
        b.append(("neck", v3(0, 21, -10.5), v3(0, 29, -6.5), "chest"))
        b.append(("head", v3(0, 29, -6.5), v3(0, 49, -4.5), "neck"))
        # charnière de la mâchoire : derrière les commissures (la gueule s'ouvre comme un piège)
        b.append(("jaw", v3(0, 27.0, -5.0), v3(0, 13.0, 6.0), "head"))
        b.append(("lip_up", v3(0, 22.4, 7.6), v3(0, 23.4, 9.8), "head"))
        b.append(("lip_lo", v3(0, 15.2, 7.6), v3(0, 14.2, 9.8), "jaw"))
        for s in (-1, 1):
            t = self.tag(s)
            cx = self.corner_point(s)
            b.append(("corner" + t, cx, cx + v3(0, 0, 3.0), "head"))
            b.append(("brow" + t, v3(EYE_X * s, 39.6, 8.8), v3(EYE_X * s, 41.4, 10.0), "head"))
            b.append(("cheek" + t, v3(9.0 * s, 31.0, 7.6), v3(9.0 * s, 29.5, 9.4), "head"))

    def corner_point(self, s):
        th = MOUTH_THC * s
        rho = 18.4
        return v3(rho * math.sin(th), CORNER_Y, MOUTH_Z0 + rho * math.cos(th))

    def _arm(self, s):
        a = {}
        a["clav0"] = v3(4.5 * s, 21.5, -8.0)
        a["S"] = v3(25.5 * s, 18.5, -3.0)
        d1 = norm(v3(0.80 * s, 0.10, 0.59))
        a["E"] = a["S"] + 33.0 * d1
        d2 = norm(v3(-0.35 * s, -0.40, 0.85))
        a["W"] = a["E"] + 32.0 * d2
        a["d1"] = d1
        a["d2"] = d2
        f = norm(v3(-0.20 * s, -0.30, 0.93))
        up = norm(v3(0, 1, 0) - f * f[1])
        lat = norm(np.cross(up, f))          # ≈ +x
        out = lat * s                         # vers l'extérieur (côté auriculaire)
        a["f"] = f
        a["up"] = up
        a["out"] = out
        W = a["W"]
        a["K0"] = W + f * 10.2 + up * 0.15
        offsets = (-3.3, -1.1, 1.15, 3.2)
        splay = (-13.0, -4.5, 4.5, 14.0)
        lengths = ((7.0, 5.6, 4.4), (7.7, 6.1, 4.8), (7.3, 5.8, 4.6), (6.0, 4.8, 3.9))
        radii = ((1.24, 1.02, 1.05, 0.86, 0.88, 0.64), (1.28, 1.05, 1.08, 0.88, 0.9, 0.65),
                 (1.22, 1.0, 1.03, 0.84, 0.86, 0.62), (1.08, 0.9, 0.93, 0.76, 0.78, 0.55))
        fingers = []
        for i in range(4):
            k = a["K0"] + out * offsets[i] - f * (0.55 * abs(offsets[i]) / 3.3) + up * 0.1
            ang = math.radians(splay[i])
            d = norm(f * math.cos(ang) + out * math.sin(ang))
            d = norm(d - up * 0.12)
            side_axis = norm(np.cross(d, up))     # axe de flexion
            joints = [k]
            p = k
            for j in range(3):
                if j > 0:
                    d = norm(rot(d, side_axis, math.radians(11.0)))
                q = p + d * lengths[i][j]
                joints.append(q)
                p = q
            fingers.append({"joints": joints, "radii": radii[i], "axis": side_axis, "tip_dir": d})
        a["fingers"] = fingers
        tb = W + f * 2.6 - out * 2.9 - up * 0.6
        d = norm(f * 0.80 - out * 0.52 - up * 0.30)
        t_axis = norm(np.cross(d, up - out * 0.3))
        joints = [tb]
        p = tb
        for j, ln in enumerate((5.4, 4.6, 3.9)):
            if j > 0:
                d = norm(rot(d, t_axis, math.radians(12.0)))
            q = p + d * ln
            joints.append(q)
            p = q
        a["thumb"] = {"joints": joints, "radii": (1.48, 1.24, 1.24, 0.98, 0.98, 0.72), "axis": t_axis, "tip_dir": d}
        return a

    def _arm_bones(self, s):
        t = self.tag(s)
        a = self.arms[s]
        b = self.bones
        b.append(("clavicle" + t, a["clav0"], a["S"], "chest"))
        b.append(("upperarm" + t, a["S"], a["E"], "clavicle" + t))
        b.append(("forearm" + t, a["E"], a["W"], "upperarm" + t))
        b.append(("hand" + t, a["W"], a["K0"], "forearm" + t))
        for i, name in enumerate(FINGERS):
            joints = a["fingers"][i]["joints"]
            parent = "hand" + t
            for j in range(3):
                bone = "%s_%d%s" % (name, j + 1, t)
                b.append((bone, joints[j], joints[j + 1], parent))
                parent = bone
        joints = a["thumb"]["joints"]
        parent = "hand" + t
        for j in range(3):
            bone = "thumb_%d%s" % (j + 1, t)
            b.append((bone, joints[j], joints[j + 1], parent))
            parent = bone
        for i, name in enumerate(FINGERS + ("thumb",)):
            fg = a["fingers"][i] if i < 4 else a["thumb"]
            tip = fg["joints"][3]
            p0, p1, p2 = claw_points(tip - fg["tip_dir"] * 0.55, fg["tip_dir"], fg["axis"], CLAW_LENGTHS[i])
            b.append(("%s_tip%s" % (name, t), p2, p2 + norm(p2 - p1) * 1.0, "%s_3%s" % (name, t)))


# ---------------------------------------------------------------------------
# Champ de distance du corps
# ---------------------------------------------------------------------------
class Component:
    def __init__(self, name, lo, hi, fn):
        self.name = name
        self.lo = np.array(lo, dtype=np.float64)
        self.hi = np.array(hi, dtype=np.float64)
        self.fn = fn

    def hits(self, lo, hi, margin):
        return bool(np.all(self.lo - margin <= hi) and np.all(lo <= self.hi + margin))


# gouttes d'encre suspendues sous la mâchoire : (x, y du haut, z, longueur)
DRIPS = ((-3.3, 10.6, 6.4, 4.4), (2.3, 10.2, 6.0, 6.2), (6.6, 11.6, 4.2, 3.2), (-8.4, 13.6, 2.4, 3.6),
         (11.0, 16.0, -0.4, 2.6))


class YieroShape:
    def __init__(self):
        self.layout = Layout()
        self._rs_u = None
        self._rs_v = None
        self._build_mouth_table()
        self.add = []      # (Component, k) unions dans l'ordre
        self.carve = []    # (Component, k) soustractions
        self._components()

    # ----- tête : masse de base (sert aussi à placer la gueule) -----
    def head_core(self, p):
        d = sd_ellipsoid(p, v3(0, 40.0, -5.0), v3(14.6, 15.0, 14.8))                 # crâne haut
        d = smin(d, sd_ellipsoid(p, v3(0, 45.0, -11.5), v3(9.5, 11.0, 10.0)), 6.0)    # dôme arrière
        d = smin(d, sd_ellipsoid(p, v3(0, 35.0, -13.5), v3(12.0, 11.5, 9.0)), 5.0)    # occiput
        d = smin(d, sd_ellipsoid(p, v3(0, 40.0, 2.5), v3(12.0, 9.0, 8.0)), 5.0)       # front
        d = smin(d, sd_ellipsoid(p, v3(0, 28.0, -0.5), v3(17.8, 11.5, 11.0)), 6.0)    # joues
        d = smin(d, sd_ellipsoid(p, v3(0, 20.5, 3.0), v3(12.5, 7.5, 6.5)), 4.0)       # museau
        for s in (-1, 1):
            d = smin(d, sd_round_cone(p, v3(13.8 * s, 25.0, -5.5), v3(2.4 * s, 11.4, 5.8), 4.4, 2.6), 4.0)
        d = smin(d, sd_ellipsoid(p, v3(0, 10.8, 5.6), v3(4.0, 4.4, 4.2)), 4.5)        # menton pointu
        return d

    def head_base(self, p):
        d = self.head_core(p)
        for s in (-1, 1):
            # arcade sourcilière lourde en V (coin intérieur très bas) : regard mauvais, orbites dans l'ombre
            d = smin(d, sd_chain(p, [v3(0.9 * s, 36.6, 10.9), v3(6.0 * s, 39.0, 10.6), v3(11.5 * s, 41.4, 7.4),
                                     v3(15.2 * s, 42.6, 2.4)], (2.3, 2.6, 2.0, 1.3)), 2.4)
            # pommettes hautes
            d = smin(d, sd_round_cone(p, v3(5.0 * s, 32.2, 9.8), v3(14.6 * s, 34.4, 3.0), 2.0, 1.3), 2.4)
            # tempes creusées
            d = smax(d, -sd_ellipsoid(p, v3(15.2 * s, 38.8, -0.5), v3(2.6, 4.2, 3.6)), 2.5)
        d = smin(d, self.sd_folds(p), 1.8)
        for s in (-1, 1):
            d = smax(d, -sd_ellipsoid(p, v3(1.35 * s, 32.4, 11.0), v3(0.26, 0.85, 1.1)), 0.3)  # narines : deux fentes fines
        return d

    def sd_folds(self, p):
        """Bourrelets des joues poussés par le sourire (sillons nasogéniens)."""
        d = np.full(p.shape[0], BIG)
        for s in (-1, 1):
            pts = []
            for u in (0.16, 0.4, 0.64, 0.86, 1.03):
                uc = min(u, 1.0)
                th = u * MOUTH_THC * s
                rho = float(self.rho_s(uc)) - 0.9
                y = mouth_up(uc) + 2.6 + 0.6 * (1.0 - uc)
                pts.append(v3(rho * math.sin(th), y, MOUTH_Z0 + rho * math.cos(th)))
            d = np.minimum(d, sd_chain(p, pts, (1.4, 1.65, 1.6, 1.3, 0.85)))
        return d

    # ----- table du rayon de surface de la face à la hauteur de la bouche -----
    def _build_mouth_table(self):
        us = np.linspace(-1.25, 1.25, 121)
        rs = np.zeros_like(us)
        for i, u in enumerate(us):
            uc = float(np.clip(u, -1.0, 1.0))
            y = 0.5 * (mouth_up(uc) + mouth_lo(uc))
            th = u * MOUTH_THC
            dirv = v3(math.sin(th), 0.0, math.cos(th))
            lo_r, hi_r = 2.0, 40.0
            for _ in range(48):
                mid = 0.5 * (lo_r + hi_r)
                pt = v3(0, y, MOUTH_Z0) + dirv * mid
                if self.head_core(pt[None, :])[0] < 0.0:
                    lo_r = mid
                else:
                    hi_r = mid
            rs[i] = 0.5 * (lo_r + hi_r)
        self._rs_u = us
        self._rs_v = rs

    def rho_s(self, u):
        return np.interp(u, self._rs_u, self._rs_v)

    def mouth_coords(self, p):
        """(u non borné, uc, rho, th, centre c, demi-hauteur hh0, rayon de surface rs)."""
        dx = p[:, 0]
        dz = p[:, 2] - MOUTH_Z0
        rho = np.sqrt(dx * dx + dz * dz)
        th = np.arctan2(dx, dz)
        u = th / MOUTH_THC
        uc = np.clip(u, -1.0, 1.0)
        up = mouth_up(uc)
        lo = mouth_lo(uc)
        c = 0.5 * (up + lo)
        hh0 = 0.5 * (up - lo)
        rs = self.rho_s(uc)
        return u, uc, rho, th, c, hh0, rs

    def sd_slit(self, p):
        u, uc, rho, th, c, hh0, rs = self.mouth_coords(p)
        au = np.abs(uc)
        t = np.clip((rho - (rs - 2.6)) / 2.6, 0.0, 1.6)
        hh_s = hh0 + 1.5 * (1.0 - 0.55 * au ** 3)
        hh_d = hh0 + 0.12
        hh = hh_d + (hh_s - hh_d) * t
        cy = c + 0.05
        d_y = np.abs(p[:, 1] - cy) - hh
        d_in = (rs - 2.6) - rho
        d_out = rho - (rs + 3.0)
        d_th = (np.abs(th) - MOUTH_THC) * rho
        return np.maximum(np.maximum(d_y, d_in), np.maximum(d_out, d_th))

    def sd_lip(self, p):
        u, uc, rho, th, c, hh0, rs = self.mouth_coords(p)
        au = np.abs(uc)
        hh_s = hh0 + 1.5 * (1.0 - 0.55 * au ** 3)
        dy = np.abs(p[:, 1] - (c + 0.05)) - hh_s
        dr = rho - (rs - 0.15)
        d = np.sqrt(dy * dy + dr * dr) - 0.55
        d_th = (np.abs(th) - MOUTH_THC * 1.01) * rho
        return np.maximum(d, d_th)

    def sd_cavity(self, p):
        u, uc, rho, th, c, hh0, rs = self.mouth_coords(p)
        au = np.abs(uc)
        taper = 1.0 - au ** 2.5
        top = c + hh0 + 3.8 * taper
        bottom = c - hh0 - 2.2 * taper
        d_y = np.maximum(p[:, 1] - top, bottom - p[:, 1])
        d_in = 6.5 - rho
        d_out = rho - (rs - 1.9)
        d_th = (np.abs(th) - MOUTH_THC * 0.985) * rho
        cav = np.maximum(np.maximum(d_y, d_in), np.maximum(d_out, d_th))
        throat = sd_ellipsoid(p, v3(0, 19.4, -3.8), v3(8.6, 6.8, 6.4))
        return smin(cav, throat, 2.5)

    def sd_tongue(self, p):
        t = sd_ellipsoid(p, v3(0, 14.8, 0.0), v3(6.2, 1.8, 6.6))
        tip = sd_ellipsoid(p, v3(0, 15.2, 5.0), v3(3.6, 1.3, 2.4))
        return smin(t, tip, 1.5)

    def sd_sockets(self, p):
        d = np.full(p.shape[0], BIG)
        for s in (-1, 1):
            d = np.minimum(d, sd_ellipsoid(p, v3(EYE_X * s, EYE_Y + 0.2, EYE_Z + 2.2), v3(EYE_R + 1.15, EYE_R + 1.05, EYE_R + 0.9)))
        return d

    def sd_drips(self, p):
        d = np.full(p.shape[0], BIG)
        for x, y, z, L in DRIPS:
            top = v3(x, y + 1.2, z - 0.4)
            bot = v3(x * 1.02, y - L, z + 0.2)
            d = np.minimum(d, sd_round_cone(p, top, bot, 1.0, 0.3))
            d = smin(d, sd_sphere(p, bot + v3(0, -0.45, 0.05), 0.66), 0.5)
        return d

    # ----- cou, torse -----
    def sd_neck(self, p):
        return sd_round_cone(p, v3(0, 13.0, -13.0), v3(0, 30.0, -7.5), 10.0, 8.2)

    def sd_torso(self, p):
        d = sd_ellipsoid(p, v3(0, 8.5, -11.5), v3(19.5, 15.0, 12.5))                       # cage
        d = smin(d, sd_round_cone(p, v3(0, -36, -12.5), v3(0, -1, -11.5), 10.5, 15.0), 7.0)  # ventre
        d = smin(d, sd_ellipsoid(p, v3(0, 25.0, -17.5), v3(17.0, 10.5, 10.5)), 7.0)          # bosse
        for s in (-1, 1):
            a = self.layout.arms[s]
            d = smin(d, sd_round_cone(p, v3(5.0 * s, 30.0, -14.0), v3(23.5 * s, 23.5, -6.0), 7.2, 4.8), 5.0)  # trapèze
            d = smin(d, sd_ellipsoid(p, v3(9.0 * s, 13.0, -2.0), v3(8.8, 6.0, 4.4)), 4.0)                    # pectoral
            d = smin(d, sd_round_cone(p, v3(3.5 * s, 21.0, -5.5), v3(23.5 * s, 21.5, -2.5), 1.8, 2.2), 1.6)  # clavicule
            d = smin(d, sd_ellipsoid(p, v3(15.0 * s, 8.0, -14.0), v3(6.5, 11.0, 9.0)), 5.0)                  # dorsal
            delt = sd_ellipsoid_frame(p, a["S"] + a["d1"] * 3.5 + v3(0, 2.2, -0.5), _frame(a["d1"]), v3(6.8, 6.2, 9.5))
            d = smin(d, delt, 4.5)
        d = smin(d, sd_round_cone(p, v3(0, 20.0, -1.4), v3(0, 0.0, 0.2), 1.6, 1.3), 2.0)  # sternum
        for y, z in ((-6.0, -23.4), (3.0, -23.4), (11.0, -24.0), (18.0, -26.4), (25.0, -27.0), (31.0, -24.6)):
            d = smin(d, sd_sphere(p, v3(0, y, z), 2.4), 1.8)                              # vertèbres
        # côtes : bourrelets sur les flancs, sous la poitrine
        sides = (np.abs(p[:, 0]) > 8.0) & (p[:, 2] < 0.0)
        ribs = 0.55 * smoothstep(0.35, 1.0, np.sin(p[:, 1] * 1.05 + 0.6)) * smoothstep(-6.0, 1.0, p[:, 1]) * smoothstep(17.0, 10.0, p[:, 1])
        d = d + np.where(sides, -ribs * smoothstep(8.0, 14.0, np.abs(p[:, 0])), 0.0)
        return smin(d, self.sd_shoulder_spikes(p), 1.4)

    def sd_shoulder_spikes(self, p):
        """Éperons osseux sur l'acromion, rabattus vers l'arrière."""
        d = np.full(p.shape[0], BIG)
        for s in (-1, 1):
            base = v3(24.0 * s, 24.5, -7.0)
            pts = [base, base + v3(2.4 * s, 4.0, -2.2), base + v3(4.0 * s, 7.6, -5.2), base + v3(4.6 * s, 10.0, -8.8)]
            d = np.minimum(d, sd_chain(p, pts, (2.7, 1.8, 0.95, 0.15)))
        return d

    # ----- bras et mains -----
    def sd_arm(self, p, s):
        a = self.layout.arms[s]
        S, E, W = a["S"], a["E"], a["W"]
        d1, d2 = a["d1"], a["d2"]
        up_arm = sd_round_cone(p, S + d1 * 2.0, E, 5.6, 3.5)
        bicep = sd_ellipsoid_frame(p, S + d1 * 12.0 + v3(0, -0.4, 0), _frame(d1), v3(5.0, 4.8, 10.5))
        d = smin(up_arm, bicep, 3.0)
        # coude osseux + éperon qui pointe vers l'arrière
        bend = norm(d1 - d2)
        knob = sd_sphere(p, E + bend * 1.0, 3.1)
        d = smin(d, knob, 2.0)
        spur = sd_chain(p, [E + bend * 1.5, E + bend * 4.5 + v3(0, 1.2, 0), E + bend * 7.0 + v3(0, 2.6, 0)], (2.0, 0.9, 0.12))
        d = smin(d, spur, 1.2)
        fore = sd_round_cone(p, E, W, 3.9, 2.3)
        d = smin(d, fore, 2.4)
        belly = sd_ellipsoid_frame(p, E + d2 * 8.5, _frame(d2), v3(4.5, 4.0, 9.0))
        d = smin(d, belly, 2.6)
        bend_n = norm(np.cross(d1, d2))
        ridge = sd_round_cone(p, E + d2 * 3.0 + bend_n * 1.2, W + bend_n * 0.6, 1.3, 0.8)
        d = smin(d, ridge, 1.6)
        return d

    def sd_hand(self, p, s):
        a = self.layout.arms[s]
        W, f, up, out = a["W"], a["f"], a["up"], a["out"]
        frame = np.stack([out, up, f])
        palm = sd_ellipsoid_frame(p, W + f * 5.4 - up * 0.2, frame, v3(5.0, 1.75, 6.1))
        wrist = sd_round_cone(p, W - f * 1.8, W + f * 1.8, 2.0, 2.2)
        d = smin(palm, wrist, 2.0)
        heel = sd_ellipsoid_frame(p, W + f * 2.9 - up * 0.85 + out * 1.2, frame, v3(2.5, 1.3, 2.4))
        d = smin(d, heel, 1.6)
        for i in range(4):
            fg = a["fingers"][i]
            j = fg["joints"]
            r = fg["radii"]
            lateral = float((j[0] - W) @ out) * 0.4
            tendon = sd_round_cone(p, W + f * 1.8 + up * 1.0 + out * lateral, j[0] + up * 0.6, 0.6, 0.8)
            d = smin(d, tendon, 1.2)
            knuckle = sd_sphere(p, j[0] + up * 0.3, r[0] + 0.3)
            d = smin(d, knuckle, 1.2)
            for k in range(3):
                seg = sd_round_cone(p, j[k], j[k + 1], r[2 * k], r[2 * k + 1])
                d = smin(d, seg, 0.55 if k > 0 else 0.9)
                if k < 2:
                    bump = sd_sphere(p, j[k + 1] + up * 0.22, r[2 * k + 1] + 0.32)
                    d = smin(d, bump, 0.45)
        th = a["thumb"]
        j = th["joints"]
        r = th["radii"]
        base = sd_ellipsoid_frame(p, W + f * 3.2 - out * 2.4 - up * 0.4, frame, v3(2.2, 1.8, 3.1))
        d = smin(d, base, 1.6)
        for k in range(3):
            seg = sd_round_cone(p, j[k], j[k + 1], r[2 * k], r[2 * k + 1])
            d = smin(d, seg, 1.1 if k == 0 else 0.55)
            if k < 2:
                d = smin(d, sd_sphere(p, j[k + 1], r[2 * k + 1] + 0.18), 0.5)
        return d

    # ----- assemblage -----
    def _components(self):
        L = self.layout
        self.add.append((Component("torso", (-40, -37, -42), (40, 38, 11), self.sd_torso), 0.0))
        self.add.append((Component("neck", (-12, 2, -24), (12, 39, 2), self.sd_neck), 5.0))
        self.add.append((Component("head", (-22, 7, -26), (22, 56, 15), self.head_base), 4.5))
        self.add.append((Component("lip", (-21, 14, -12), (21, 34, 15), self.sd_lip), 0.45))
        self.add.append((Component("drips", (-11, 3, -3), (13, 19, 9), self.sd_drips), 0.9))
        for s in (-1, 1):
            a = L.arms[s]
            pts = np.array([a["S"], a["E"], a["W"]])
            lo = pts.min(axis=0) - 9.0
            hi = pts.max(axis=0) + 9.0
            self.add.append((Component("arm%d" % s, lo, hi, (lambda q, s=s: self.sd_arm(q, s))), 3.5))
            hp = [a["W"]] + [j for fg in a["fingers"] for j in fg["joints"]] + list(a["thumb"]["joints"])
            hp = np.array(hp)
            lo = hp.min(axis=0) - 3.5
            hi = hp.max(axis=0) + 3.5
            self.add.append((Component("hand%d" % s, lo, hi, (lambda q, s=s: self.sd_hand(q, s))), 2.0))
        self.carve.append((Component("sockets", (-13, 30, 2), (13, 42, 14), self.sd_sockets), 1.1))
        self.carve.append((Component("cavity", (-21, 8, -13), (21, 36, 15), self.sd_cavity), 0.9))
        self.carve.append((Component("slit", (-22, 12, -12), (22, 34, 17), self.sd_slit), 0.55))
        self.tongue = Component("tongue", (-9, 11, -8), (9, 19, 9), self.sd_tongue)

    def sdf(self, p, lo=None, hi=None, margin=4.0):
        if lo is None:
            lo = p.min(axis=0)
            hi = p.max(axis=0)
        d = np.full(p.shape[0], BIG)
        first = True
        for comp, k in self.add:
            if not comp.hits(lo, hi, margin + k):
                continue
            v = comp.fn(p)
            d = v if first else smin(d, v, k)
            first = False
        if first:
            return d
        for comp, k in self.carve:
            if not comp.hits(lo, hi, margin + k):
                continue
            d = smax(d, -comp.fn(p), k)
        if self.tongue.hits(lo, hi, margin):
            d = smin(d, self.tongue.fn(p), 0.7)
        # relief organique très léger (atténué sur le visage, absent dans la gueule)
        near = np.abs(d) < 2.5
        if np.any(near):
            q = p[near]
            qs = np.stack([np.abs(q[:, 0]), q[:, 1], q[:, 2]], axis=1)
            face = smoothstep(26.0, 15.0, length(q - v3(0, 28.0, 4.0)))
            amp = 0.26 * (1.0 - 0.9 * face)
            d = d.copy()
            d[near] = d[near] + amp * fbm(qs * 0.12, 3, 11)
        return d


# ---------------------------------------------------------------------------
# Pièces explicites : dents, griffes
# ---------------------------------------------------------------------------
def loft(points, radii_xy, frames, sides):
    """Tube effilé : points (n,3), radii_xy (n,2), frames : liste de (x, y) unitaires.
    Retourne (verts, faces) avec une pointe fermée au dernier point (rayon 0)."""
    verts = []
    faces = []
    n = len(points)
    for i in range(n):
        rx, ry = radii_xy[i]
        if i == n - 1:
            verts.append(points[i])
            continue
        fx, fy = frames[i]
        for k in range(sides):
            a = 2.0 * math.pi * k / sides
            verts.append(points[i] + fx * math.cos(a) * rx + fy * math.sin(a) * ry)
    for i in range(n - 2):
        for k in range(sides):
            a = i * sides + k
            b = i * sides + (k + 1) % sides
            c = (i + 1) * sides + k
            d = (i + 1) * sides + (k + 1) % sides
            faces.append((a, b, c))
            faces.append((b, d, c))
    tip = len(verts) - 1
    base = (n - 2) * sides
    for k in range(sides):
        faces.append((base + k, base + (k + 1) % sides, tip))
    centre = len(verts)
    verts.append(points[0])
    for k in range(sides):
        faces.append((centre, (k + 1) % sides, k))
    return np.array(verts), np.array(faces, dtype=np.int64)


def curve_frames(points, ref):
    frames = []
    n = len(points)
    for i in range(n):
        if i < n - 1:
            t = norm(points[i + 1] - points[i])
        else:
            t = norm(points[i] - points[i - 1])
        x = ref - t * np.dot(ref, t)
        if np.linalg.norm(x) < 1e-6:
            x = np.cross(t, v3(0, 0, 1))
        x = norm(x)
        y = np.cross(t, x)
        frames.append((x, y))
    return frames


def bezier(p0, p1, p2, n):
    pts = []
    for i in range(n):
        t = i / (n - 1)
        pts.append((1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2)
    return np.array(pts)


def tooth_mesh(root, down, tangent, inward, length, width, curl, lean, broken=0.0, sides=6):
    """Dent en aiguille, légèrement recourbée vers l'intérieur de la gueule.
    down : direction de la pointe ; tangent : le long de la gencive ; inward : vers la gorge."""
    tip = root + down * length + inward * curl * length + tangent * lean * length
    mid = root + down * length * 0.55 + inward * curl * length * 0.12 + tangent * lean * length * 0.4
    pts = bezier(root - down * 0.8, mid, tip, 8)
    if broken > 0.0:
        keep = max(3, int(round(len(pts) * (1.0 - broken))))
        pts = pts[:keep]
    radii = []
    n = len(pts)
    for i in range(n):
        t = i / (n - 1)
        r = width * 0.5 * (1.0 - t) ** 0.8 if broken <= 0.0 else width * 0.5 * (1.0 - 0.55 * t)
        if i == n - 1 and broken <= 0.0:
            r = 0.0
        radii.append((r, r * 0.66))
    frames = curve_frames(pts, tangent)
    if broken > 0.0:
        radii[-1] = (radii[-1][0] * 0.35, radii[-1][1] * 0.35)
    return loft(pts, radii, frames, sides)


def claw_points(base, direction, curl_axis, length, hook=1.2):
    d = norm(direction)
    down = norm(np.cross(curl_axis, d))      # vers la paume
    p0 = base - d * 0.6
    p1 = base + d * length * 0.55 + down * length * 0.05
    p2 = base + d * length * 0.74 + down * length * 0.55 * hook
    return p0, p1, p2


def claw_mesh(base, direction, curl_axis, length, radius, hook=1.2):
    p0, p1, p2 = claw_points(base, direction, curl_axis, length, hook)
    pts = bezier(p0, p1, p2, 11)
    radii = []
    for i in range(len(pts)):
        t = i / (len(pts) - 1)
        r = radius * (1.0 - t) ** 0.85
        radii.append((r * 0.74, r))
    radii[-1] = (0.0, 0.0)
    frames = curve_frames(pts, curl_axis)
    return loft(pts, radii, frames, 8)


def gum_wall(shape, u, depth, upper):
    """Point de la paroi de gencive (haut ou bas) à la profondeur `depth` sous la surface."""
    uc = float(np.clip(u, -1.0, 1.0))
    th = u * MOUTH_THC
    rs = float(shape.rho_s(uc))
    rho = rs - depth
    up = mouth_up(uc)
    lo = mouth_lo(uc)
    c = 0.5 * (up + lo) + 0.05
    hh0 = 0.5 * (up - lo)
    au = abs(uc)
    t = np.clip((rho - (rs - 2.6)) / 2.6, 0.0, 1.6)
    hh_s = hh0 + 1.5 * (1.0 - 0.55 * au ** 3)
    hh_d = hh0 + 0.12
    hh = hh_d + (hh_s - hh_d) * t
    y = c + hh if upper else c - hh
    pos = v3(rho * math.sin(th), y, MOUTH_Z0 + rho * math.cos(th))
    radial = v3(math.sin(th), 0.0, math.cos(th))
    tangent = v3(math.cos(th), 0.0, -math.sin(th))
    return pos, radial, tangent, 2.0 * hh0 + 0.24


def make_teeth(shape, seed=6661):
    """Liste de dents : dict(verts, faces, upper, u, row, chip, root, down, length)."""
    rng = np.random.default_rng(seed)
    teeth = []
    rows = (
        # (haut ?, nombre, profondeur, longueur relative, largeur, rangée)
        (True, 26, 1.25, (0.78, 1.06), 1.05, 0),
        (False, 24, 1.85, (0.5, 0.78), 0.95, 0),
        (True, 16, 3.1, (0.4, 0.62), 0.66, 1),
        (False, 14, 3.4, (0.32, 0.52), 0.6, 1),
    )
    for upper, n, depth, (lmin, lmax), wscale, row in rows:
        span = 0.95 if row == 0 else 0.78
        us = np.linspace(-span, span, n) + rng.uniform(-0.35, 0.35, n) * (2.0 * span / n)
        if upper and row == 0:
            k = int(np.argmin(np.abs(us - CHIP_U)))
            us[k] = CHIP_U
        for i, u in enumerate(us):
            pos, radial, tangent, gap = gum_wall(shape, u, depth, upper)
            au = abs(u)
            down = v3(0, -1, 0) if upper else v3(0, 1, 0)
            down = norm(down + radial * (0.1 if upper else 0.06))
            inward = -radial
            length = gap * rng.uniform(lmin, lmax)
            width = wscale * rng.uniform(0.95, 1.45) * (0.55 + 0.45 * (1.0 - au * au))
            fang = row == 0 and (abs(au - 0.34) < 0.05 or abs(au - 0.63) < 0.045)
            if fang:
                length *= 1.38
                width *= 1.25
            broken = 0.0
            chip = upper and row == 0 and abs(u - CHIP_U) < 1e-6
            if chip:
                length = gap * 1.05
                width = 1.55
            elif row == 0 and rng.random() < 0.06:
                broken = rng.uniform(0.35, 0.5)
            length = max(0.8, length + (0.7 if upper else 0.45))
            lean = rng.uniform(-0.2, 0.2) - u * 0.12
            curl = rng.uniform(0.05, 0.18)
            root = pos + down * -0.4
            verts, faces = tooth_mesh(root, down, tangent, inward, length, width, curl, lean, broken)
            teeth.append({"verts": verts, "faces": faces, "upper": upper, "u": float(u), "row": row,
                          "chip": chip, "root": root, "down": down, "length": length})
    return teeth


def make_claws(shape):
    claws = []
    for s in (-1, 1):
        a = shape.layout.arms[s]
        for i in range(4):
            fg = a["fingers"][i]
            tip = fg["joints"][3]
            v, f = claw_mesh(tip - fg["tip_dir"] * 0.6, fg["tip_dir"], fg["axis"], CLAW_LENGTHS[i], fg["radii"][5] + 0.2)
            claws.append({"verts": v, "faces": f, "side": s, "finger": FINGERS[i]})
        th = a["thumb"]
        tip = th["joints"][3]
        v, f = claw_mesh(tip - th["tip_dir"] * 0.6, th["tip_dir"], th["axis"], CLAW_LENGTHS[4], th["radii"][5] + 0.2)
        claws.append({"verts": v, "faces": f, "side": s, "finger": "thumb"})
    return claws


# ---------------------------------------------------------------------------
# Frange d'encre : pointes effilées et recourbées plantées autour du visage, sur la nuque et le dos
# (silhouette « ombre hérissée »). Chaque pointe est un tube aplati (flamme d'encre) ; le shader de
# Godot fait onduler la pointe au vent (paramètre le long de la pointe dans UV2.y).
# ---------------------------------------------------------------------------
FRINGE_SIDES = 7
FRINGE_RINGS = 7


def ray_surface(fn, o, d, r_max=45.0):
    """Point de surface (fn = 0) sur le rayon o + r d, o étant à l'intérieur (fn < 0)."""
    if fn(o[None, :])[0] >= 0.0:
        return None
    lo, hi = 0.0, r_max
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        if fn((o + d * mid)[None, :])[0] < 0.0:
            lo = mid
        else:
            hi = mid
    return o + d * lo


def sdf_grad(fn, p, eps=0.15):
    g = np.zeros(3)
    for i in range(3):
        e = np.zeros(3)
        e[i] = eps
        g[i] = fn((p + e)[None, :])[0] - fn((p - e)[None, :])[0]
    return norm(g)


def spike_mesh(root, d0, wide, length, r0, bend, rng):
    """Pointe : tube aplati (large selon `wide`), renflé près de la base, recourbé par `bend`."""
    pts = [root]
    d = d0
    cur = root
    seg = length / (FRINGE_RINGS - 1)
    wobble = rng.uniform(-0.18, 0.18)
    side = norm(np.cross(d0, wide))
    for i in range(1, FRINGE_RINGS):
        k = i / (FRINGE_RINGS - 1)
        d = norm(d + bend * (0.35 + k) + side * wobble * math.cos(k * 3.0))
        cur = cur + d * seg
        pts.append(cur)
    pts = np.array(pts)
    radii = []
    for i in range(FRINGE_RINGS):
        t = i / (FRINGE_RINGS - 1)
        r = r0 * (1.0 + 0.3 * math.sin(math.pi * min(t * 1.4, 1.0))) * (1.0 - t) ** 1.05
        radii.append((r, r * 0.6))
    radii[-1] = (0.0, 0.0)
    frames = curve_frames(pts, wide)
    v, f = loft(pts, radii, frames, FRINGE_SIDES)
    return v, f, pts


def fringe_allowed(az, el):
    """Zone de plantation autour du centre du crâne : az = 0 vers l'arrière, |az| = 180 devant."""
    a = abs(az)
    if el > 62.0:
        return True                      # sommet du crâne (aussi au-dessus du front)
    if a <= 112.0 and el > -38.0:
        return a > 70.0 or el > -12.0    # arrière et côtés ; bas des côtés pour la silhouette de face
    return False


def make_fringe(shape, seed=777, count=62):
    """Liste de pointes : dict(verts, faces, root, points, length, region)."""
    rng = np.random.default_rng(seed)
    out = []
    head = shape.head_base
    centre = v3(0.0, 40.0, -6.0)
    golden = math.pi * (3.0 - math.sqrt(5.0))
    total = count * 3
    for i in range(total):
        y = 1.0 - 2.0 * (i + 0.5) / total
        rr = math.sqrt(max(0.0, 1.0 - y * y))
        th = golden * i
        dirv = v3(math.cos(th) * rr, y, math.sin(th) * rr)
        el = math.degrees(math.asin(y))
        az = math.degrees(math.atan2(dirv[0], -dirv[2]))
        if not fringe_allowed(az, el):
            continue
        jit = norm(rng.normal(size=3)) * 0.05
        dirv = norm(dirv + jit)
        hit = ray_surface(head, centre, dirv)
        if hit is None:
            continue
        nrm = sdf_grad(head, hit)
        top = smoothstep(30.0, 80.0, el)
        sidefall = smoothstep(10.0, -35.0, el)
        L = rng.uniform(7.5, 15.5) * (1.0 + 0.45 * top) * (1.0 - 0.35 * sidefall)
        r0 = rng.uniform(1.8, 2.7) * (1.0 + 0.15 * top)
        backv = v3(math.copysign(0.25, dirv[0]) * min(abs(dirv[0]) * 2.0, 1.0), 0.25 + 0.35 * top, -1.0)
        d0 = norm(nrm * 0.85 + norm(backv) * 0.75 + norm(rng.normal(size=3)) * 0.14)
        bend = v3(0.0, -0.05 - 0.12 * sidefall, -0.16)
        wide = norm(np.cross(d0, nrm) + 1e-6)
        wide = norm(np.cross(nrm, d0)) if np.linalg.norm(np.cross(nrm, d0)) > 1e-3 else wide
        root = hit - nrm * 1.3
        v, f, pts = spike_mesh(root, d0, wide, L, r0, bend, rng)
        out.append({"verts": v, "faces": f, "root": root, "points": pts, "length": L, "region": "head"})
    return out
