"""Aperçu « argile » d'un maillage de Yiero (npz de mesh_yiero.py ou .glb) rendu par Blender.
  python preview_yiero.py --npz mc.npz --out planche.png [--views front,three,profile,face] [--size 480]
Rendu Workbench (rapide, sans GPU) ; vues dans le repère de PaperYiero.
"""
import argparse
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

VIEWS = {
    "front": ((0, 32, 165), (0, 20, 5), 42.0),
    "three": ((125, 52, 125), (0, 20, 5), 42.0),
    "profile": ((170, 32, 10), (0, 20, 10), 42.0),
    "back": ((-95, 45, -115), (0, 22, 0), 40.0),
    "face": ((0, 33, 60), (0, 28, 4), 42.0),
    "face34": ((34, 36, 46), (0, 29, 4), 44.0),
    "low": ((-3, 2, 70), (0, 30, 0), 60.0),
    "hand": ((-60, 26, 92), (-38, 6, 52), 40.0),
    "top": ((0, 150, 30), (0, 10, 10), 45.0),
    "mouth": ((4, 22, 36), (0, 22, 6), 44.0),
}


def g2b(v):
    return Vector((v[0], -v[2], v[1]))


def setup_scene(size):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 12
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 2
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 3
    scene.render.resolution_x = size
    scene.render.resolution_y = int(size * 0.75)
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("w")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.32, 0.33, 0.36, 1.0)
    bg.inputs[1].default_value = 0.55
    for rot, energy in (((0.9, 0.0, 0.6), 3.2), ((1.2, 0.0, -2.4), 1.4)):
        sun = bpy.data.lights.new("sun", "SUN")
        sun.energy = energy
        sun.angle = 0.2
        ob = bpy.data.objects.new("sun", sun)
        ob.rotation_euler = rot
        scene.collection.objects.link(ob)
    return scene


def add_mesh(verts, faces, name="Yiero", color=(0.55, 0.52, 0.5, 1.0), rough=0.55):
    me = bpy.data.meshes.new(name)
    vb = np.stack([verts[:, 0], -verts[:, 2], verts[:, 1]], axis=1)
    me.from_pydata(vb.tolist(), [], faces.tolist())
    me.update()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.new("clay")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rough
    me.materials.append(mat)
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
        cam_data.angle = math.radians(fov) * scene.render.resolution_x / scene.render.resolution_y if False else math.radians(fov)
        cam_data.sensor_fit = "VERTICAL"
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
    ap.add_argument("--ground", type=int, default=1)
    args = ap.parse_args(argv)
    scene = setup_scene(args.size)
    if args.npz:
        data = np.load(args.npz)
        add_mesh(data["verts"], data["faces"])
        if "teeth_v" in data:
            add_mesh(data["teeth_v"], data["teeth_f"], "Teeth", (0.92, 0.86, 0.7, 1.0), 0.3)
            add_mesh(data["claws_v"], data["claws_f"], "Claws", (0.25, 0.2, 0.16, 1.0), 0.3)
            for e in data["eyes"]:
                bpy.ops.mesh.primitive_uv_sphere_add(radius=float(e[3]), location=g2b(e[:3]), segments=32, ring_count=16)
                ob = bpy.context.active_object
                mat = bpy.data.materials.new("eye")
                mat.use_nodes = True
                b = mat.node_tree.nodes.get("Principled BSDF")
                b.inputs["Base Color"].default_value = (0.95, 0.93, 0.85, 1.0)
                b.inputs["Emission Color"].default_value = (0.9, 0.85, 0.7, 1.0)
                b.inputs["Emission Strength"].default_value = 0.6
                ob.data.materials.append(mat)
                bpy.ops.object.shade_smooth()
        if args.ground:
            bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, 0))
            ob = bpy.context.active_object
            mat = bpy.data.materials.new("ink")
            mat.use_nodes = True
            b = mat.node_tree.nodes.get("Principled BSDF")
            b.inputs["Base Color"].default_value = (0.04, 0.035, 0.04, 1.0)
            b.inputs["Roughness"].default_value = 0.25
            ob.data.materials.append(mat)
    elif args.glb:
        bpy.ops.import_scene.gltf(filepath=args.glb)
    paths = render_views(scene, args.views.split(","), args.out)
    print("PREVIEW", " ".join(paths))


if __name__ == "__main__":
    main()
