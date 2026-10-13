"""Autoverifica dell'Ingegnere esportato (D-088). Eseguire:
    blender -b --factory-startup --python tools/blender/check_engineer.py
Confronta godot/assets/models/player_engineer.glb con la copia del modello D-074 in
output/engineer/before/ (stessi nomi delle ossa) e controlla triangoli, clip, superfici,
sacca, pesi e UV. Stampa `ENGINEER_CHECK PASS|FAIL failures=N`."""
import os
import sys

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
NEW = os.path.join(ROOT, "godot", "assets", "models", "player_engineer.glb")
OLD = os.path.join(ROOT, "output", "engineer", "before", "player_engineer_d074.glb")
CLIPS = 13
TRIS = (20000, 28000)

failures = 0


def check(condition, label):
    global failures
    if condition:
        print("  ok   %s" % label)
    else:
        failures += 1
        print("  FAIL %s" % label)


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    meshes = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
    return rig, meshes


old_rig, _ = load(OLD)
old_bones = sorted(b.name for b in old_rig.data.bones)
rig, meshes = load(NEW)
check(sorted(b.name for b in rig.data.bones) == old_bones, "stessi nomi delle ossa del modello D-074 (%d)" % len(old_bones))
check(len(bpy.data.actions) == CLIPS, "%d clip (attese %d)" % (len(bpy.data.actions), CLIPS))
body = next((o for name, o in meshes.items() if name.startswith("PlayerEngineerMesh")), None)
check(body is not None, "mesh del corpo PlayerEngineerMesh")
check(any(name.startswith("PackSack") for name in meshes), "sacca PackSack presente")
if body is not None:
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    check(TRIS[0] <= tris <= TRIS[1], "triangoli %d in %s" % (tris, TRIS))
    names = sorted(m.name for m in body.data.materials)
    check(names == ["gear", "lamp", "suit"], "superfici suit, gear, lamp (%s)" % ", ".join(names))
    unweighted = sum(1 for v in body.data.vertices if sum(g.weight for g in v.groups) < 0.99)
    check(unweighted == 0, "ogni vertice pesato (senza peso: %d)" % unweighted)
    over = sum(1 for v in body.data.vertices if sum(1 for g in v.groups if g.weight > 0.0) > 4)
    check(over == 0, "al massimo 4 ossa per vertice (oltre: %d)" % over)
    uv = body.data.uv_layers.active
    outside = sum(1 for d in uv.data if not (-1e-4 <= d.uv.x <= 1.0001 and -1e-4 <= d.uv.y <= 1.0001)) if uv else -1
    check(outside == 0, "UV dentro l'atlante (fuori: %d)" % outside)
    images = {img.size[0] for img in bpy.data.images if img.size[0] > 0}
    check(images == {2048}, "texture a 2048 (%s)" % sorted(images))
    zs = [v.co.z for v in body.data.vertices]
    check(1.55 <= max(zs) - min(zs) <= 1.85, "altezza a riposo %.2f m" % (max(zs) - min(zs)))
print("ENGINEER_CHECK %s failures=%d" % ("PASS" if failures == 0 else "FAIL", failures))
sys.exit(1 if failures else 0)
