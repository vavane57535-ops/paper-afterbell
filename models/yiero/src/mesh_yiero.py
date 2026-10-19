"""Maillage du champ de distance de Yiero par blocs (marching cubes de scikit-image).

Seuls les blocs qui touchent la surface sont évalués finement ; les sommets communs à deux blocs
sont fusionnés. Utilisable seul (écrit un .npz) ou importé par build_yiero.py.
  python mesh_yiero.py --res 0.22 --out /chemin/yiero_mc.npz
"""
import argparse
import math
import multiprocessing
import os
import sys
import time

import numpy as np
from skimage.measure import marching_cubes

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import yiero_shape as ys  # noqa: E402


def domain(shape):
    lo = np.array([1e9, 1e9, 1e9])
    hi = -lo
    for comp, _k in shape.add:
        lo = np.minimum(lo, comp.lo)
        hi = np.maximum(hi, comp.hi)
    return lo - 1.0, hi + 1.0


def grid_points(origin, res, n):
    ax = [origin[i] + res * np.arange(n[i]) for i in range(3)]
    gx, gy, gz = np.meshgrid(ax[0], ax[1], ax[2], indexing="ij")
    return np.stack([gx.ravel(), gy.ravel(), gz.ravel()], axis=1)


_SHAPE = None


def _block_job(args):
    b0, res, block = args
    n = np.array([block + 1] * 3)
    pts = grid_points(b0, res, n)
    vol = _SHAPE.sdf(pts, b0, b0 + block * res).reshape(n)
    if vol.min() > 0.0 or vol.max() < 0.0:
        return None
    v, f, _nrm, _val = marching_cubes(vol.astype(np.float32), level=0.0, spacing=(res, res, res),
                                      gradient_direction="ascent", allow_degenerate=False)
    return v.astype(np.float64) + b0, f.astype(np.int64)


def mesh_sdf(shape, res=0.22, block=48, coarse=2.0, verbose=True, workers=3):
    global _SHAPE
    _SHAPE = shape
    lo, hi = domain(shape)
    # grille symétrique en x (x = 0 est un échantillon) : maillage symétrique
    half = math.ceil(max(abs(lo[0]), abs(hi[0])) / res) * res
    lo[0] = -half
    hi[0] = half
    size = hi - lo
    ncell = np.ceil(size / res).astype(int)
    nblk = np.ceil(ncell / block).astype(int)
    cn = np.ceil(size / coarse).astype(int) + 1
    cpts = grid_points(lo, coarse, cn)
    cd = shape.sdf(cpts).reshape(cn)
    jobs = []
    bsz = block * res
    for bi in range(nblk[0]):
        for bj in range(nblk[1]):
            for bk in range(nblk[2]):
                b0 = lo + np.array([bi, bj, bk]) * bsz
                b1 = b0 + bsz
                i0 = np.clip(np.floor((b0 - lo) / coarse).astype(int) - 1, 0, cn - 1)
                i1 = np.clip(np.ceil((b1 - lo) / coarse).astype(int) + 1, 0, cn - 1)
                sub = cd[i0[0]:i1[0] + 1, i0[1]:i1[1] + 1, i0[2]:i1[2] + 1]
                if sub.size == 0 or (np.min(np.abs(sub)) > 3.5 and (np.all(sub > 0) or np.all(sub < 0))):
                    continue
                jobs.append((b0, res, block))
    t0 = time.time()
    results = []
    if workers > 1:
        try:
            ctx = multiprocessing.get_context("fork")
            with ctx.Pool(workers) as pool:
                results = pool.map(_block_job, jobs, chunksize=1)
        except Exception as exc:  # repli séquentiel
            print("MC parallèle impossible (%s), calcul séquentiel" % exc)
            results = []
    if not results:
        results = [_block_job(j) for j in jobs]
    verts_all, faces_all, offset = [], [], 0
    for r in results:
        if r is None:
            continue
        verts_all.append(r[0])
        faces_all.append(r[1] + offset)
        offset += len(r[0])
    if verbose:
        print("MC %d blocs (%d utiles) en %.1f s" % (len(jobs), len(verts_all), time.time() - t0))
    verts = np.concatenate(verts_all)
    faces = np.concatenate(faces_all)
    key = np.round(verts / (res * 1e-3)).astype(np.int64)
    _u, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    inv = inv.ravel()
    verts = verts[first]
    faces = inv[faces]
    keep = (faces[:, 0] != faces[:, 1]) & (faces[:, 1] != faces[:, 2]) & (faces[:, 0] != faces[:, 2])
    faces = faces[keep]
    if verbose:
        print("MC %d sommets, %d triangles" % (len(verts), len(faces)))
    return verts, faces


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--res", type=float, default=0.22)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    t0 = time.time()
    shape = ys.YieroShape()
    print("forme prête en %.1f s" % (time.time() - t0))
    verts, faces = mesh_sdf(shape, args.res)
    extra = {}
    teeth = ys.make_teeth(shape)
    claws = ys.make_claws(shape)
    for label, items in (("teeth", teeth), ("claws", claws)):
        vs, fs, off = [], [], 0
        for it in items:
            vs.append(it["verts"]);fs.append(it["faces"] + off);off += len(it["verts"])
        extra[label + "_v"] = np.concatenate(vs)
        extra[label + "_f"] = np.concatenate(fs)
    eyes = []
    for sx in (-1, 1):
        eyes.append([ys.EYE_X * sx, ys.EYE_Y, ys.EYE_Z, ys.EYE_R])
    extra["eyes"] = np.array(eyes)
    np.savez_compressed(args.out, verts=verts, faces=faces, res=args.res, **extra)
    print("écrit", args.out, "en %.1f s" % (time.time() - t0))


if __name__ == "__main__":
    main()
