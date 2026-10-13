"""Anteprime a giro di un personaggio (D-088), per giudicare forma e colori senza Godot.

Workbench con luce da studio, cavita e contorno: `clay` grigio uniforme (forma),
`colors` il colore per angolo `Col` (zone), `painted` le texture cotte. Le viste di
gioco riproducono la camera di IsometricCameraRig (inclinazione 55 gradi, braccio 15 m,
FOV orizzontale 90 gradi): il personaggio e piccolo come in gioco.
"""
import math
import os

import bpy
from mathutils import Vector

GAME_PITCH_DEG = 55.0
GAME_ARM_M = 15.0
GAME_HFOV_DEG = 90.0


def _bounds(objects):
    points = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return low, high


def _camera(scene):
    cam = scene.camera
    if cam is None:
        cam = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
        scene.collection.objects.link(cam)
        scene.camera = cam
    return cam


def _look(cam, position, target):
    cam.location = position
    cam.rotation_euler = (Vector(target) - Vector(position)).to_track_quat("-Z", "Y").to_euler()


def _shot(scene, path, size):
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def render_views(objects, out_dir, mode="clay", head=None, size=(900, 1100)):
    out_dir = os.path.abspath(out_dir)
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.film_transparent = False
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = {"clay": "SINGLE", "colors": "VERTEX", "painted": "TEXTURE"}[mode]
    shading.single_color = (0.62, 0.6, 0.58)
    shading.show_cavity = True
    shading.cavity_type = "BOTH"
    shading.show_object_outline = True
    shading.show_shadows = True
    scene.world = scene.world or bpy.data.worlds.new("PreviewWorld")
    low, high = _bounds(objects)
    center = (low + high) * 0.5
    height = high.z - low.z
    head = Vector(head) if head is not None else Vector((center.x, center.y, low.z + height * 0.9))
    cam = _camera(scene)
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "AUTO"
    cam.data.lens = 50.0
    distance = height * 2.0
    # Il fronte del personaggio guarda -Y: la vista 0 e da -Y.
    for i in range(8):
        a = math.radians(45.0 * i)
        position = center + Vector((math.sin(a) * distance, -math.cos(a) * distance, height * 0.12))
        _look(cam, position, center)
        _shot(scene, os.path.join(out_dir, "turn_%d.png" % i), size)
    _look(cam, head + Vector((0.25, -1.1, 0.12)), head)
    _shot(scene, os.path.join(out_dir, "face.png"), (900, 900))
    pitch = math.radians(GAME_PITCH_DEG)
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.angle = math.radians(GAME_HFOV_DEG)
    for name, sign, arm in (("game_back", 1.0, GAME_ARM_M), ("game_front", -1.0, GAME_ARM_M), ("game_zoom", 1.0, 4.0)):
        position = center + Vector((0.0, sign * math.cos(pitch) * arm, math.sin(pitch) * arm))
        _look(cam, position, center)
        _shot(scene, os.path.join(out_dir, name + ".png"), (1280, 800))
    cam.data.sensor_fit = "AUTO"
    cam.data.lens = 50.0
    print("TURNTABLE %s views=12" % out_dir)
