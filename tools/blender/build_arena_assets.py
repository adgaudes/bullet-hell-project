"""Genera gli asset dell'arena "rovine riconquistate" (D-036, D-037) e li esporta in glTF.

Eseguire (Blender 5.2.2, senza interfaccia):
    blender -b --factory-startup --python tools/blender/build_arena_assets.py -- [nome ...]

Senza nomi costruisce i cinque asset rifiniti con texture cotta (D-073, circa un minuto
l'uno); `-- wrecked_car_blocky` ecc. ricostruisce i vecchi a blocchi (D-037).
Uscita: godot/assets/models/<nome>.glb. Dopo l'export:
    godot_console --headless --path godot --editor --quit   (importa i .glb)

Convenzioni (R-011):
- metri; origine al centro della base, a z = 0 (Blender, Z-up);
- il fronte dell'asset guarda +Y in Blender, che dopo l'export Y-up diventa -Z in Godot,
  cioe il "forward" di Godot;
- un solo oggetto per asset; i materiali hanno nomi semantici che Godot rimappa.
  A blocchi (D-037): paint, dark, metal, tire, bark, leaves, concrete, sugli shader
  procedurali dell'arena. Rifiniti (D-073, `refined.StaticBuilder`): `paint` (tinta per
  istanza dal codice: carrozzeria, cassa del vagone, cemento, palo), `gear` (colori
  fissi), entrambi con colore, usura, occlusione e sporco cotti in una texture 1024
  letta da `env_baked.gdshader`; `leaves` resta sullo shader del fogliame (ondeggia,
  colore di vertice scuro in basso);
- seme fisso: stessa forma a ogni esecuzione.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from refined import StaticBuilder  # noqa: E402

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


def leaf_cards(name, center, radius, count, rng, mat_name="leaves"):
    """Cartelle di fogliame attorno a `center`: piani 1,6 x 1,2 m orientati a caso dentro
    una sfera di raggio `radius`, con la normale che guarda fuori dal centro."""
    cards = []
    for _ in range(count):
        direction = Vector((rng.uniform(-1.0, 1.0), rng.uniform(-1.0, 1.0), rng.uniform(-0.4, 1.0)))
        if direction.length < 1e-3:
            direction = Vector((0.0, 0.0, 1.0))
        direction.normalize()
        location = Vector(center) + direction * radius * rng.uniform(0.25, 0.7)
        rotation = direction.to_track_quat("Z", "Y").to_euler()
        rotation.z += rng.uniform(0.0, math.tau)
        bpy.ops.mesh.primitive_plane_add(size=1.0, location=location, rotation=rotation)
        obj = bpy.context.active_object
        obj.name = name
        obj.scale = (radius * 1.1, radius * 0.85, 1.0)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        cards.append(assign(obj, mat_name))
    return cards


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


def export(obj, asset_name, vertex_color="ACTIVE"):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, asset_name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_vertex_color=vertex_color,
        export_all_vertex_colors=False,
    )
    dims = obj.dimensions
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    mats = [m.name for m in obj.data.materials]
    print("ASSET_EXPORTED %s size=(%.2f, %.2f, %.2f) tris=%d materials=%s"
          % (asset_name, dims.x, dims.y, dims.z, tris, ",".join(mats)))


# --- Asset ------------------------------------------------------------------------

def build_wrecked_car_blocky():
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


def build_train_carriage_blocky():
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


def build_overgrown_tree_blocky():
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


def build_concrete_barrier_blocky():
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


# --- Asset rifiniti con texture cotta (D-073) ----------------------------------------

# Colori lineari per la cottura. Le superfici `paint` partono chiare: la tinta la mette
# il codice di gioco (`paint` per istanza in env_baked.gdshader).
WHITE = (1.0, 1.0, 1.0)
LIGHT_CONCRETE = (0.9, 0.88, 0.85)
DARK_GLASS = (0.03, 0.04, 0.05)
HEADLIGHT = (0.72, 0.72, 0.66)
TAILLIGHT = (0.5, 0.05, 0.03)
CHROME = (0.55, 0.55, 0.56)
DARK_METAL = (0.07, 0.07, 0.075)
STEEL = (0.32, 0.32, 0.33)
RUST = (0.3, 0.1, 0.035)
TIRE = (0.025, 0.024, 0.022)
BARK = (0.11, 0.07, 0.04)
BARK_LIGHT = (0.2, 0.14, 0.08)


def build_wrecked_car():
    """Berlina abbandonata rifinita: carrozzeria smussata e rastremata, cofano, abitacolo
    con vetri, portiera mancante a sinistra, paraurti, griglia, fari, specchietto, gomme
    sgonfie con cerchioni. 4,2 m lungo Y."""
    b = StaticBuilder()
    b.box((1.8, 4.2, 0.62), (0.0, 0.0, 0.62), WHITE, paint=True, bevel=0.07, segments=3,
          front=(0.94, 0.86), back=(0.96, 0.9))
    b.box((1.74, 1.2, 0.12), (0.0, 1.45, 0.98), WHITE, paint=True, bevel=0.035, rot=(-3.0, 0.0, 0.0),
          front=(0.95, 1.0))
    b.box((1.6, 2.0, 0.58), (0.0, -0.25, 1.22), WHITE, paint=True, bevel=0.06, segments=3, top=(0.86, 0.72))
    # Vetri scuri appena fuori dall'abitacolo: bande scure fra z 1,0 e 1,4.
    b.box((1.66, 2.05, 0.4), (0.0, -0.25, 1.2), DARK_GLASS, bevel=0.01, top=(0.9, 0.78))
    # Portiera mancante a sinistra: vano scuro; a destra la portiera ha maniglia e fuga.
    b.box((0.05, 1.0, 0.5), (-0.905, 0.0, 0.7), DARK_GLASS, bevel=0.005)
    b.box((0.03, 0.02, 0.5), (0.905, 0.52, 0.7), DARK_METAL, bevel=0.0)
    b.box((0.03, 0.02, 0.5), (0.905, -0.5, 0.7), DARK_METAL, bevel=0.0)
    b.box((0.04, 0.16, 0.03), (0.91, 0.38, 0.82), CHROME, bevel=0.008)
    for y in (2.12, -2.12):
        b.box((1.84, 0.12, 0.18), (0.0, y, 0.42), CHROME, bevel=0.03, segments=3)
    b.box((0.9, 0.05, 0.22), (0.0, 2.1, 0.74), DARK_METAL, bevel=0.01)
    for x in (-0.6, 0.6):
        b.cyl(0.13, 0.08, (x, 2.1, 0.8), HEADLIGHT, axis="y", sides=10, bevel=0.01)
        b.box((0.3, 0.05, 0.12), (x, -2.11, 0.8), TAILLIGHT, bevel=0.01)
    b.box((0.12, 0.1, 0.08), (0.95, 0.75, 1.15), WHITE, paint=True, bevel=0.015)
    rng = random.Random(7)
    for x in (-0.8, 0.8):
        for y in (-1.35, 1.35):
            # Gomme sgonfie: affondate e con un cerchione sporgente.
            squash = 0.95 + rng.uniform(-0.04, 0.04)
            b.cyl(0.32 * squash, 0.24, (x, y, 0.25), TIRE, axis="x", sides=14, bevel=0.03)
            b.cyl(0.17, 0.27, (x, y, 0.25), STEEL, axis="x", sides=10, bevel=0.012)
    obj = b.to_object("WreckedCar")
    # Ammaccature: piccoli spostamenti dei vertici alti della carrozzeria.
    for v in obj.data.vertices:
        if v.co.z > 0.5:
            v.co.z += rng.uniform(-0.02, 0.015)
    return obj


def build_train_carriage():
    """Vagone passeggeri rifinito: cassa con tetto bombato, finestrini con cornice, porte
    con gradino, sfiati sul tetto, scaletta, respingenti, carrelli con ruote e assali.
    13 m lungo Y."""
    b = StaticBuilder()
    length = 13.0
    half_w = 1.45
    profile = [(-half_w, 0.45), (half_w, 0.45), (half_w, 2.75)]
    for i in range(1, 8):
        a = math.pi * i / 8.0
        profile.append((math.cos(a) * half_w, 2.75 + math.sin(a) * 0.5))
    profile.append((-half_w, 2.75))
    b.profile(profile, length, (0.0, 0.0, 0.0), WHITE, paint=True, bevel=0.035, segments=3,
              rot=(0.0, 0.0, 90.0))
    for side in (-1.0, 1.0):
        x = side * half_w
        for y in (-4.2, -2.8, -1.4, 1.4, 2.8, 4.2):
            b.box((0.06, 1.12, 0.97), (x, y, 1.95), STEEL, bevel=0.012)
            b.box((0.1, 1.0, 0.85), (x, y, 1.95), DARK_GLASS, bevel=0.005)
        for y in (-5.85, 5.85, 0.0):
            b.box((0.06, 1.02, 2.02), (x, y, 1.45), STEEL, bevel=0.012)
            b.box((0.1, 0.9, 1.9), (x, y, 1.45), DARK_GLASS, bevel=0.005)
            b.box((0.3, 0.9, 0.06), (x + side * 0.15, y, 0.4), DARK_METAL, bevel=0.01)
    for y in (-length * 0.5, length * 0.5):
        b.box((1.7, 0.06, 0.9), (0.0, y, 2.0), STEEL, bevel=0.012)
        b.box((1.6, 0.1, 0.8), (0.0, y, 2.0), DARK_GLASS, bevel=0.005)
        for x in (-0.75, 0.75):
            b.cyl(0.14, 0.3, (x, y + math.copysign(0.15, y), 0.75), DARK_METAL, axis="y", sides=10, bevel=0.02)
    # Scaletta a un'estremita.
    for x in (-0.3, 0.3):
        b.box((0.05, 0.05, 2.2), (x, -length * 0.5 - 0.12, 1.6), DARK_METAL, bevel=0.01)
    for z in (0.8, 1.2, 1.6, 2.0, 2.4):
        b.box((0.62, 0.04, 0.04), (0.0, -length * 0.5 - 0.12, z), DARK_METAL, bevel=0.008)
    for y in (-4.5, -1.5, 1.5, 4.5):
        b.box((0.5, 0.8, 0.18), (0.0, y, 3.3), STEEL, bevel=0.03, top=(0.8, 0.9))
    # Carrelli con ruote e assali, mezzi affondati nel terreno.
    for y in (-4.5, 4.5):
        b.box((2.2, 2.6, 0.35), (0.0, y, 0.3), DARK_METAL, bevel=0.04)
        for wy in (-0.8, 0.8):
            b.cyl(0.06, 2.2, (0.0, y + wy, 0.35), STEEL, axis="x", sides=8, bevel=0.0)
            for x in (-1.0, 1.0):
                b.cyl(0.42, 0.14, (x, y + wy, 0.35), STEEL, axis="x", sides=14, bevel=0.02)
    b.box((2.6, length - 1.0, 0.25), (0.0, 0.0, 0.5), DARK_METAL, bevel=0.02)
    return b.to_object("TrainCarriage")


def build_overgrown_tree():
    """Albero frondoso rifinito: tronco curvo con radici e tre rami cotti in texture,
    chioma a grumi sfaccettati sul materiale `leaves` (shader del fogliame, colore di
    vertice scuro in basso). Alto circa 6,5 m."""
    rng = random.Random(11)
    b = StaticBuilder()
    trunk = b.cyl(0.32, 3.4, (0.0, 0.0, 1.7), BARK, mat="matte", sides=9, radius_top=0.18, bevel=0.0, sharp=70.0)
    for v in trunk.data.vertices:
        t = v.co.z / 3.4
        v.co.x += 0.35 * t * t
    for i in range(4):
        a = i * 0.5 * math.pi + 0.3
        b.cyl(0.13, 0.7, (math.cos(a) * 0.32, math.sin(a) * 0.32, 0.12), BARK_LIGHT, mat="matte", sides=6,
              radius_top=0.05, bevel=0.0, rot=(0.0, 65.0, math.degrees(a)), sharp=70.0)
    for i in range(3):
        a = i * 2.0 * math.pi / 3.0 + 0.4
        b.cyl(0.12, 1.6, (0.3 + math.cos(a) * 0.45, math.sin(a) * 0.45, 3.0), BARK_LIGHT, mat="matte", sides=6,
              radius_top=0.05, bevel=0.0, rot=(50.0, 0.0, math.degrees(a)), sharp=70.0)
    obj = b.to_object("OvergrownTree")
    clusters = [((0.35, 0.0, 4.6), 1.7), ((1.3, 0.6, 4.0), 1.2), ((-0.6, 0.8, 4.1), 1.25),
                ((0.4, -1.0, 4.2), 1.3), ((0.5, 0.3, 5.5), 1.15), ((-0.5, -0.5, 4.9), 1.0)]
    canopies = []
    for loc, r in clusters:
        # Chioma a cartelle (restyling 2026-10-11): piani con UV 0..1 che il fogliame
        # ritaglia con le foglie dipinte; piu scuri verso il basso come prima.
        for card in leaf_cards("Canopy", loc, r, 7, rng):
            bottom_darkening(card, 2.8, 6.2)
            canopies.append(card)
    bpy.ops.object.select_all(action="DESELECT")
    for canopy in canopies:
        canopy.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    attribute = obj.data.color_attributes["Col"]
    obj.data.color_attributes.active_color = attribute
    obj.data.color_attributes.render_color_index = obj.data.color_attributes.find("Col")
    return obj


def build_concrete_barrier():  # texture 1024: prop piccolo
    """Barriera New Jersey rifinita: profilo smussato, spigolo scheggiato con due tondini,
    fori di sollevamento. 3 m lungo Y."""
    rng = random.Random(3)
    b = StaticBuilder(bake_size=1024)
    profile = [(-0.3, 0.0), (0.3, 0.0), (0.3, 0.08), (0.18, 0.33), (0.1, 0.82), (-0.1, 0.82),
               (-0.18, 0.33), (-0.3, 0.08)]
    shell = b.profile(profile, 3.0, (0.0, 0.0, 0.0), LIGHT_CONCRETE, paint=True, bevel=0.025, segments=2,
                      rot=(0.0, 0.0, 90.0))
    for v in shell.data.vertices:
        if v.co.y > 1.35 and v.co.z > 0.45:
            v.co.z -= rng.uniform(0.12, 0.3)
            v.co.y -= rng.uniform(0.0, 0.2)
            v.co.x *= rng.uniform(0.85, 1.0)
    b.cyl(0.02, 0.5, (0.05, 1.45, 0.72), RUST, sides=5, bevel=0.0, rot=(25.0, 0.0, 0.0))
    b.cyl(0.018, 0.4, (-0.06, 1.4, 0.68), RUST, sides=5, bevel=0.0, rot=(40.0, 15.0, 0.0))
    for y in (-0.9, 0.9):
        for x in (-0.19, 0.19):
            b.box((0.05, 0.22, 0.09), (x, y, 0.26), DARK_METAL, bevel=0.005)
    return b.to_object("ConcreteBarrier")


def build_lamp_post():
    """Lampione stradale rifinito, 5,5 m: base, palo rastremato con collare, braccio
    verso +Y con tirante, testa a lanterna con vetro spento (non e una fonte di luce)."""
    b = StaticBuilder(bake_size=1024)
    b.cyl(0.17, 0.22, (0.0, 0.0, 0.11), DARK_METAL, sides=10, bevel=0.025, segments=3)
    b.cyl(0.095, 5.2, (0.0, 0.0, 2.82), WHITE, paint=True, sides=10, radius_top=0.06, bevel=0.0, sharp=70.0)
    b.cyl(0.11, 0.1, (0.0, 0.0, 0.6), DARK_METAL, sides=10, bevel=0.012)
    b.cyl(0.08, 0.1, (0.0, 0.0, 5.4), DARK_METAL, sides=10, bevel=0.012)
    b.box((0.09, 1.5, 0.09), (0.0, 0.75, 5.36), WHITE, paint=True, bevel=0.03, segments=3)
    b.box((0.05, 0.75, 0.05), (0.0, 0.33, 5.05), WHITE, paint=True, bevel=0.015, rot=(-42.0, 0.0, 0.0))
    b.box((0.36, 0.36, 0.26), (0.0, 1.4, 5.28), DARK_METAL, bevel=0.02, bottom=(0.78, 0.78), top=(0.9, 0.9))
    b.box((0.3, 0.3, 0.1), (0.0, 1.4, 5.12), HEADLIGHT, bevel=0.01, bottom=(0.85, 0.85))
    return b.to_object("LampPost")


# Nome -> (costruttore, colore di vertice nell'export). I rifiniti hanno il colore nella
# texture; l'albero lo esporta lo stesso per la chioma (shader del fogliame).
ASSETS = {
    "wrecked_car": (build_wrecked_car, "NONE"),
    "train_carriage": (build_train_carriage, "NONE"),
    "overgrown_tree": (build_overgrown_tree, "ACTIVE"),
    "concrete_barrier": (build_concrete_barrier, "NONE"),
    "lamp_post": (build_lamp_post, "NONE"),
    "wrecked_car_blocky": (build_wrecked_car_blocky, "ACTIVE"),
    "train_carriage_blocky": (build_train_carriage_blocky, "ACTIVE"),
    "overgrown_tree_blocky": (build_overgrown_tree_blocky, "ACTIVE"),
    "concrete_barrier_blocky": (build_concrete_barrier_blocky, "ACTIVE"),
}
REFINED = ("wrecked_car", "train_carriage", "overgrown_tree", "concrete_barrier", "lamp_post")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = argv or list(REFINED)
    for name in names:
        reset_scene()
        builder, vertex_color = ASSETS[name]
        obj = builder()
        export(obj, name, vertex_color)


main()
