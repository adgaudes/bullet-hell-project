"""Genera gli asset dell'arena "rovine riconquistate" (D-036, D-037) e li esporta in glTF.

Eseguire (Blender 5.2.2, senza interfaccia):
    blender -b --factory-startup --python tools/blender/build_arena_assets.py -- [nome ...]

Senza nomi costruisce tutti gli asset. Uscita: godot/assets/models/<nome>.glb.

Convenzioni (R-011):
- metri; origine al centro della base, a z = 0 (Blender, Z-up);
- il fronte dell'asset guarda +Y in Blender, che dopo l'export Y-up diventa -Z in Godot,
  cioe il "forward" di Godot;
- un solo oggetto per asset; i materiali hanno nomi semantici che Godot rimappa sui
  propri shader (paint, dark, metal, tire, bark, leaves, concrete): i colori qui
  servono solo all'anteprima in Blender;
- seme fisso: stessa forma a ogni esecuzione.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "godot", "assets", "models")

PREVIEW_COLORS = {
    "paint": (0.85, 0.66, 0.16, 1.0),
    "dark": (0.05, 0.05, 0.05, 1.0),
    "metal": (0.35, 0.33, 0.30, 1.0),
    "tire": (0.08, 0.08, 0.08, 1.0),
    "bark": (0.33, 0.25, 0.18, 1.0),
    "leaves": (0.25, 0.45, 0.12, 1.0),
    "concrete": (0.62, 0.58, 0.52, 1.0),
}


# --- Utilita -----------------------------------------------------------------------

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = PREVIEW_COLORS[name]
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf is not None:
            bsdf.inputs["Base Color"].default_value = PREVIEW_COLORS[name]
    return mat


def assign(obj, mat_name):
    obj.data.materials.clear()
    obj.data.materials.append(material(mat_name))
    return obj


def box(name, size, location, mat_name, bevel=0.0, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    return assign(obj, mat_name)


def cylinder(name, radius, depth, location, mat_name, vertices=12, rotation=(0.0, 0.0, 0.0), radius_top=None):
    if radius_top is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                            location=location, rotation=rotation)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=radius_top, depth=depth,
                                        location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    return assign(obj, mat_name)


def scale_top(obj, sx, sy, threshold):
    """Restringe i vertici sopra `threshold` (z locale): tetti e cofani rastremati."""
    for v in obj.data.vertices:
        if v.co.z > threshold:
            v.co.x *= sx
            v.co.y *= sy


def extrude_profile(name, profile_xz, length, mat_name):
    """Solido da un profilo chiuso nel piano XZ, estruso lungo Y e centrato."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    front = [bm.verts.new((x, -length * 0.5, z)) for x, z in profile_xz]
    back = [bm.verts.new((x, length * 0.5, z)) for x, z in profile_xz]
    n = len(profile_xz)
    bm.faces.new(front[::-1])
    bm.faces.new(back)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return assign(obj, mat_name)


def lumpy_sphere(name, radius, location, mat_name, rng, squash=0.85, roughness=0.18):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    for v in obj.data.vertices:
        offset = 1.0 + rng.uniform(-roughness, roughness)
        v.co *= offset
        v.co.z *= squash
    return assign(obj, mat_name)


def shade_flat(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = False


def join_all(name):
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        # Applica i modificatori prima di unire.
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def bottom_darkening(obj, low, high, dark=0.55):
    """Colore per vertice: piu scuro in basso (occlusione finta per chiome e cespugli)."""
    mesh = obj.data
    attr = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            z = mesh.vertices[mesh.loops[li].vertex_index].co.z
            t = max(0.0, min(1.0, (z - low) / max(high - low, 0.001)))
            c = dark + (1.0 - dark) * t
            attr.data[li].color = (c, c, c, 1.0)


def export(obj, asset_name):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, asset_name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    dims = obj.dimensions
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    mats = [m.name for m in obj.data.materials]
    print("ASSET_EXPORTED %s size=(%.2f, %.2f, %.2f) tris=%d materials=%s"
          % (asset_name, dims.x, dims.y, dims.z, tris, ",".join(mats)))


# --- Asset ------------------------------------------------------------------------

def build_wrecked_car():
    """Berlina abbandonata: lunga 4,2 m lungo Y, gomme a terra, un lato senza portiera."""
    rng = random.Random(7)
    box("Body", (1.8, 4.2, 0.62), (0.0, 0.0, 0.62), "paint", bevel=0.09)
    hood = box("Hood", (1.74, 1.2, 0.12), (0.0, 1.45, 0.98), "paint", bevel=0.04)
    hood.rotation_euler = (math.radians(-3.0), 0.0, 0.0)
    cabin = box("Cabin", (1.6, 2.0, 0.58), (0.0, -0.25, 1.22), "paint", bevel=0.06)
    scale_top(cabin, 0.86, 0.72, 0.0)
    # Vetri scuri appena fuori dall'abitacolo.
    glass = box("Glass", (1.5, 1.86, 0.4), (0.0, -0.25, 1.2), "dark")
    scale_top(glass, 0.9, 0.78, 0.0)
    glass.scale = (1.035, 1.025, 1.0)
    # Portiera mancante sul lato sinistro: vano scuro.
    box("DoorHole", (0.04, 1.0, 0.5), (-0.905, 0.0, 0.7), "dark")
    for y, name in ((2.12, "BumperFront"), (-2.12, "BumperBack")):
        box(name, (1.84, 0.12, 0.18), (0.0, y, 0.42), "metal", bevel=0.03)
    for x in (-0.6, 0.6):
        cylinder("Headlight", 0.13, 0.06, (x, 2.11, 0.78), "dark", vertices=10,
                 rotation=(math.radians(90.0), 0.0, 0.0))
    for x in (-0.8, 0.8):
        for y in (-1.35, 1.35):
            # Gomme sgonfie: cilindro schiacciato e affondato.
            wheel = cylinder("Wheel", 0.34, 0.24, (x, y, 0.26), "tire", vertices=14,
                             rotation=(0.0, math.radians(90.0), 0.0))
            wheel.scale = (1.0, 1.0, 0.8 + rng.uniform(-0.05, 0.05))
    obj = join_all("WreckedCar")
    # Ammaccature: piccoli spostamenti dei vertici della carrozzeria.
    for v in obj.data.vertices:
        if v.co.z > 0.5:
            v.co.z += rng.uniform(-0.025, 0.02)
    return obj


def build_train_carriage():
    """Vagone passeggeri: 13 m lungo Y, tetto bombato, finestrini, porte e carrelli."""
    length = 13.0
    half_w = 1.45
    profile = [(-half_w, 0.45), (half_w, 0.45), (half_w, 2.75)]
    for i in range(1, 8):
        a = math.pi * i / 8.0
        profile.append((math.cos(a) * half_w, 2.75 + math.sin(a) * 0.5))
    profile.append((-half_w, 2.75))
    extrude_profile("Shell", profile, length, "paint")
    # Finestrini e porte: pannelli scuri appena sporgenti sui fianchi.
    for side in (-1.0, 1.0):
        x = side * (half_w + 0.015)
        for y in (-4.2, -2.8, -1.4, 1.4, 2.8, 4.2):
            box("Window", (0.03, 1.0, 0.85), (x, y, 1.95), "dark")
        for y in (-5.85, 5.85, 0.0):
            box("Door", (0.03, 0.9, 1.9), (x, y, 1.45), "dark")
    for y in (-length * 0.5 - 0.015, length * 0.5 + 0.015):
        box("EndWindow", (1.6, 0.03, 0.8), (0.0, y, 2.0), "dark")
        box("Buffer", (2.2, 0.25, 0.25), (0.0, y + math.copysign(0.12, y), 0.75), "metal")
    # Carrelli con ruote, mezzi affondati nel terreno.
    for y in (-4.5, 4.5):
        box("Bogie", (2.2, 2.6, 0.35), (0.0, y, 0.3), "metal", bevel=0.04)
        for wy in (-0.8, 0.8):
            for x in (-1.0, 1.0):
                cylinder("Wheel", 0.42, 0.14, (x, y + wy, 0.35), "metal", vertices=14,
                         rotation=(0.0, math.radians(90.0), 0.0))
    box("Underframe", (2.6, length - 1.0, 0.25), (0.0, 0.0, 0.5), "metal")
    return join_all("TrainCarriage")


def build_overgrown_tree():
    """Albero frondoso: tronco curvo, tre rami, chioma a grumi. Alto circa 6,5 m."""
    rng = random.Random(11)
    trunk = cylinder("Trunk", 0.32, 3.4, (0.0, 0.0, 1.7), "bark", vertices=9, radius_top=0.18)
    for v in trunk.data.vertices:
        t = (v.co.z + 1.7) / 3.4
        v.co.x += 0.35 * t * t
    for i in range(3):
        a = i * 2.0 * math.pi / 3.0 + 0.4
        branch = cylinder("Branch", 0.12, 1.6, (0.0, 0.0, 0.0), "bark", vertices=6, radius_top=0.05)
        branch.rotation_euler = (math.radians(50.0), 0.0, a)
        branch.location = (0.3 + math.cos(a) * 0.45, math.sin(a) * 0.45, 3.0)
    clusters = [((0.35, 0.0, 4.6), 1.7), ((1.3, 0.6, 4.0), 1.2), ((-0.6, 0.8, 4.1), 1.25),
                ((0.4, -1.0, 4.2), 1.3), ((0.5, 0.3, 5.5), 1.15), ((-0.5, -0.5, 4.9), 1.0)]
    for loc, r in clusters:
        canopy = lumpy_sphere("Canopy", r, loc, "leaves", rng)
        shade_flat(canopy)
    obj = join_all("OvergrownTree")
    bottom_darkening(obj, 2.8, 6.2)
    return obj


def build_concrete_barrier():
    """Barriera stradale in cemento (profilo New Jersey), 3 m, scheggiata."""
    rng = random.Random(3)
    profile = [(-0.3, 0.0), (0.3, 0.0), (0.3, 0.08), (0.18, 0.33), (0.1, 0.82), (-0.1, 0.82),
               (-0.18, 0.33), (-0.3, 0.08)]
    shell = extrude_profile("Barrier", profile, 3.0, "concrete")
    # Spigolo rotto a un'estremita.
    for v in shell.data.vertices:
        if v.co.y > 1.4 and v.co.z > 0.5:
            v.co.z -= rng.uniform(0.15, 0.3)
            v.co.y -= rng.uniform(0.0, 0.25)
    cylinder("Rebar", 0.02, 0.5, (0.05, 1.45, 0.75), "metal", vertices=5,
             rotation=(math.radians(25.0), 0.0, 0.0))
    return join_all("ConcreteBarrier")


ASSETS = {
    "wrecked_car": build_wrecked_car,
    "train_carriage": build_train_carriage,
    "overgrown_tree": build_overgrown_tree,
    "concrete_barrier": build_concrete_barrier,
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = argv or list(ASSETS)
    for name in names:
        reset_scene()
        obj = ASSETS[name]()
        export(obj, name)


main()
