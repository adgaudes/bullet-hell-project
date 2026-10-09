"""Genera i modelli statici low-poly degli attori senza scheletro (compagno, rottamatore,
Demolitore) e li esporta in glTF (pipeline D-037). L'ingegnere, con scheletro e animazioni,
sta in build_character_assets.py (D-060).

Eseguire (Blender 5.2.2, senza interfaccia):
    blender -b --factory-startup --python tools/blender/build_actor_assets.py -- [nome ...]

Senza nomi costruisce tutti gli asset. Uscita: godot/assets/models/<nome>.glb.
Dopo l'export: godot_console --headless --path godot --editor --quit (importa i .glb).

Convenzioni (come build_arena_assets.py):
- metri; origine al centro della base, a z = 0 (Blender, Z-up); il fronte guarda +Y in
  Blender, cioe -Z in Godot. Eccezione: `demolisher_blade` ha l'origine al centro della
  lama, perche il codice ne anima la posizione;
- un solo oggetto per asset, facce piatte, nessun rig e nessuna animazione;
- **il colore sta nei vertici** (attributo `Col`, lineare), non in texture o materiali:
  un attore costa una sola superficie. Lo shader `actor_paint.gdshader` legge anche due
  indicatori dalle UV: `UV.x = 1` la faccia emette luce (occhi, fari), `UV.y = 1` la
  faccia e "vernice" e viene moltiplicata per la tinta decisa dal codice di gioco;
- i nomi dei materiali sono semantici e li rimappa il codice: `detail` (shader a colori
  di vertice), `stripe` (striscia gialla del compagno).
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "godot", "assets", "models")

# Colori lineari.
WHITE = (1.0, 1.0, 1.0)
TIRE = (0.025, 0.024, 0.022)
DARK_METAL = (0.07, 0.07, 0.075)
STEEL = (0.3, 0.3, 0.31)
WORN_STEEL = (0.52, 0.5, 0.46)
RUST = (0.3, 0.1, 0.035)
LEATHER = (0.3, 0.15, 0.06)
BOOT = (0.06, 0.04, 0.03)
SKIN = (0.72, 0.4, 0.26)
CREAM = (0.9, 0.78, 0.5)
TEAL = (0.02, 0.3, 0.3)
CANVAS = (0.5, 0.36, 0.16)
CORAL = (0.85, 0.1, 0.16)
COPPER = (0.6, 0.22, 0.06)
WOOD = (0.3, 0.17, 0.07)
CYAN_LIGHT = (0.0, 0.8, 1.0)
WARM_LIGHT = (1.0, 0.85, 0.45)
ENEMY_EYE = (1.0, 0.75, 0.1)
BOSS_EYE = (1.0, 0.05, 0.02)
HAZARD = (0.9, 0.6, 0.05)


def shade(value):
    return (value, value, value)


class Builder:
    """Accumula primitive in un solo bmesh, con colore e indicatori per faccia."""

    def __init__(self, materials):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.materials = materials

    def _finish(self, verts, color, mat, paint, emit):
        faces = set()
        for v in verts:
            faces.update(v.link_faces)
        index = self.materials.index(mat)
        for face in faces:
            face.material_index = index
            face.smooth = False
            for loop in face.loops:
                loop[self.col] = (color[0], color[1], color[2], 1.0)
                # L'export glTF ribalta V: in Godot UV.y vale `paint`.
                loop[self.uv].uv = (1.0 if emit else 0.0, 0.0 if paint else 1.0)

    def box(self, size, center, color, mat="detail", paint=False, emit=False,
            rot=(0.0, 0.0, 0.0), top=(1.0, 1.0), bottom=(1.0, 1.0), front=(1.0, 1.0), back=(1.0, 1.0)):
        """Scatola. `top`/`bottom` restringono (x, y) le facce alta e bassa; `front`/`back`
        restringono (x, z) quelle a +Y e -Y. `rot` in gradi (Eulero XYZ)."""
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        for v in verts:
            x, y, z = v.co.x, v.co.y, v.co.z
            tb = top if z > 0.0 else bottom
            fb = front if y > 0.0 else back
            v.co = Vector((x * size[0] * tb[0] * fb[0], y * size[1] * tb[1], z * size[2] * fb[1]))
        self._place(verts, center, rot)
        self._finish(verts, color, mat, paint, emit)

    def cyl(self, radius, depth, center, color, mat="detail", paint=False, emit=False,
            axis="z", sides=8, radius_top=None, rot=(0.0, 0.0, 0.0)):
        """Prisma o tronco di cono lungo `axis`."""
        verts = bmesh.ops.create_cone(
            self.bm, cap_ends=True, cap_tris=False, segments=sides, radius1=radius,
            radius2=radius if radius_top is None else radius_top, depth=depth)["verts"]
        if axis == "x":
            bmesh.ops.rotate(self.bm, verts=verts, matrix=Matrix.Rotation(math.radians(90.0), 3, "Y"))
        elif axis == "y":
            bmesh.ops.rotate(self.bm, verts=verts, matrix=Matrix.Rotation(math.radians(-90.0), 3, "X"))
        self._place(verts, center, rot)
        self._finish(verts, color, mat, paint, emit)

    def profile(self, points_yz, width, center, color, mat="detail", paint=False, emit=False):
        """Solido da un profilo chiuso nel piano YZ, estruso lungo X e centrato in x."""
        left = [self.bm.verts.new((-width * 0.5, y, z)) for y, z in points_yz]
        right = [self.bm.verts.new((width * 0.5, y, z)) for y, z in points_yz]
        n = len(points_yz)
        faces = [self.bm.faces.new(left), self.bm.faces.new(right[::-1])]
        for i in range(n):
            j = (i + 1) % n
            faces.append(self.bm.faces.new((left[j], left[i], right[i], right[j])))
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        verts = left + right
        self._place(verts, center, (0.0, 0.0, 0.0))
        self._finish(verts, color, mat, paint, emit)

    def _place(self, verts, center, rot):
        matrix = Matrix.Translation(Vector(center)) @ Euler(
            (math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2])), "XYZ").to_matrix().to_4x4()
        bmesh.ops.transform(self.bm, verts=verts, matrix=matrix)

    def to_object(self, name):
        mesh = bpy.data.meshes.new(name)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for mat_name in self.materials:
            mat = bpy.data.materials.get(mat_name) or bpy.data.materials.new(mat_name)
            mesh.materials.append(mat)
        attribute = mesh.color_attributes["Col"]
        mesh.color_attributes.active_color = attribute
        mesh.color_attributes.render_color_index = mesh.color_attributes.find("Col")
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        return obj


def export(obj, asset_name):
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
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
    )
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    mats = [m.name for m in obj.data.materials]
    print("ASSET_EXPORTED %s size=(%.2f, %.2f, %.2f) x=[%.2f, %.2f] y=[%.2f, %.2f] z=[%.2f, %.2f] tris=%d materials=%s"
          % (asset_name, max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs),
             min(xs), max(xs), min(ys), max(ys), min(zs), max(zs), tris, ",".join(mats)))


# --- Attori ------------------------------------------------------------------------

def build_companion_cart():
    """Compagno: carretto improvvisato di 0,8 x 1,0 m. Cofano chiaro davanti (ci si monta
    la torretta, a y = 0,25 e z = 0,65), cassone di assi dietro col pianale a z = 0,60
    (i cubetti di rottame ci stanno sopra), archetto posteriore a z = 0,80 per la calamita,
    faro ciclopico e striscia gialla sul muso, quattro ruote tozze."""
    b = Builder(["detail", "stripe"])
    # Ruote e telaio.
    for x in (-0.4, 0.4):
        for y in (-0.3, 0.3):
            b.cyl(0.2, 0.16, (x, y, 0.2), TIRE, axis="x", sides=8)
            b.cyl(0.09, 0.18, (x, y, 0.2), HAZARD, axis="x", sides=6)
    b.box((0.62, 0.98, 0.16), (0.0, 0.0, 0.3), DARK_METAL)
    # Cofano motore, rastremato in avanti.
    b.box((0.7, 0.44, 0.3), (0.0, 0.29, 0.5), WHITE, paint=True, front=(0.88, 0.8))
    b.box((0.3, 0.3, 0.02), (-0.14, 0.27, 0.655), TEAL)
    b.box((0.76, 0.08, 0.1), (0.0, 0.52, 0.3), STEEL)
    # Faro ciclopico e faretto di recupero: il muso ha una faccia.
    b.cyl(0.11, 0.06, (-0.12, 0.5, 0.44), WARM_LIGHT, emit=True, axis="y", sides=8)
    b.cyl(0.06, 0.05, (0.2, 0.5, 0.42), WARM_LIGHT, emit=True, axis="y", sides=6)
    b.box((0.64, 0.05, 0.1), (0.0, 0.49, 0.585), WHITE, mat="stripe")
    b.box((0.72, 0.1, 0.035), (0.0, 0.44, 0.665), WHITE, mat="stripe")
    # Cassone: fondo, corpo, sponde di assi.
    b.box((0.7, 0.58, 0.22), (0.0, -0.21, 0.47), WHITE, paint=True, bottom=(0.9, 0.95))
    b.box((0.74, 0.6, 0.03), (0.0, -0.21, 0.585), DARK_METAL)
    for x in (-0.37, 0.37):
        b.box((0.05, 0.6, 0.15), (x, -0.21, 0.67), WOOD)
    b.box((0.74, 0.05, 0.15), (0.0, 0.08, 0.67), WOOD)
    b.box((0.2, 0.02, 0.1), (0.12, -0.52, 0.5), RUST)
    # Archetto posteriore: appoggio della calamita.
    for x in (-0.33, 0.33):
        b.box((0.06, 0.06, 0.22), (x, -0.45, 0.69), STEEL)
    b.box((0.72, 0.07, 0.06), (0.0, -0.45, 0.77), STEEL)
    # Scarico storto, di lato.
    b.cyl(0.045, 0.34, (0.31, 0.14, 0.8), RUST, sides=6, rot=(0.0, 8.0, 0.0))
    b.cyl(0.06, 0.06, (0.335, 0.14, 0.97), DARK_METAL, sides=6, rot=(0.0, 8.0, 0.0))
    return b.to_object("CompanionCart")


def build_scavenger():
    """Rottamatore: macchina-granchio tozza. Scafo color ruggine (vernice), muso a cuneo
    con visiera luminosa che sporge (si vede anche dall'alto), due chele in avanti,
    cingoli scuri, portapacchi piatto a z = 0,66 per il rottame. Una sola superficie."""
    b = Builder(["detail"])
    track = [(-0.37, 0.1), (-0.27, 0.0), (0.27, 0.0), (0.37, 0.1), (0.3, 0.27), (-0.3, 0.27)]
    for x in (-0.3, 0.3):
        b.profile(track, 0.16, (x, -0.02, 0.0), TIRE)
    b.box((0.56, 0.56, 0.34), (0.0, -0.06, 0.43), WHITE, paint=True, top=(0.82, 0.86))
    b.box((0.4, 0.4, 0.06), (0.0, -0.06, 0.63), DARK_METAL)
    b.box((0.34, 0.12, 0.2), (0.0, -0.38, 0.42), DARK_METAL)
    # Muso e visiera.
    b.box((0.42, 0.26, 0.26), (0.0, 0.32, 0.4), shade(0.7), paint=True, front=(0.7, 0.6))
    b.box((0.32, 0.1, 0.09), (0.0, 0.4, 0.53), ENEMY_EYE, emit=True)
    # Chele: braccio e punta chiara, convergenti.
    for side in (-1.0, 1.0):
        b.box((0.11, 0.34, 0.11), (side * 0.3, 0.38, 0.27), STEEL, rot=(0.0, 0.0, side * 14.0))
        b.box((0.09, 0.2, 0.14), (side * 0.22, 0.6, 0.27), WORN_STEEL, rot=(0.0, 0.0, side * 30.0),
              front=(0.4, 0.4))
    return b.to_object("Scavenger")


def build_demolisher():
    """Demolitore: ruspa di rottami, capsula 0,9 x 2,4 m. Cingoli scuri, scafo giallo
    (vernice), cofano in avanti con griglia, cabina scura arretrata con fessura rossa
    luminosa e lampeggiante sul tetto, ciminiere, contrappeso dietro. La lama e un asset
    separato (`demolisher_blade`) perche il codice la muove."""
    b = Builder(["detail"])
    track = [(-1.05, 0.25), (-0.8, 0.0), (0.8, 0.0), (1.05, 0.25), (1.05, 0.5), (0.85, 0.72),
             (-0.85, 0.72), (-1.05, 0.5)]
    for x in (-0.72, 0.72):
        b.profile(track, 0.42, (x, 0.0, 0.0), TIRE)
        for y in (-0.6, 0.0, 0.6):
            b.cyl(0.2, 0.46, (x, y, 0.36), STEEL, axis="x", sides=6)
    # Scafo e cofano.
    b.box((1.2, 1.9, 0.75), (0.0, -0.05, 0.95), WHITE, paint=True, top=(0.94, 0.96))
    b.box((1.05, 0.85, 0.46), (0.0, 0.45, 1.52), WHITE, paint=True, front=(0.9, 0.82))
    b.box((0.8, 0.06, 0.34), (0.0, 0.89, 1.5), DARK_METAL)
    for x in (-0.24, 0.0, 0.24):
        b.box((0.07, 0.08, 0.34), (x, 0.9, 1.5), HAZARD)
    b.box((0.5, 0.4, 0.03), (0.22, 0.4, 1.755), RUST)
    # Cabina: pareti scure, fessura rossa, tetto giallo, lampeggiante.
    b.box((1.0, 0.9, 0.7), (0.0, -0.42, 1.95), DARK_METAL, top=(0.9, 0.9))
    b.box((0.82, 0.08, 0.16), (0.0, 0.03, 2.03), BOSS_EYE, emit=True)
    b.box((1.08, 1.0, 0.1), (0.0, -0.42, 2.33), shade(0.85), paint=True)
    b.box((0.22, 0.22, 0.14), (0.0, -0.1, 2.44), BOSS_EYE, emit=True)
    # Ciminiere asimmetriche.
    b.cyl(0.09, 0.8, (0.38, 0.5, 2.1), DARK_METAL, sides=6)
    b.cyl(0.12, 0.12, (0.38, 0.5, 2.5), RUST, sides=6)
    b.cyl(0.07, 0.5, (-0.4, 0.62, 1.95), DARK_METAL, sides=6)
    # Contrappeso, toppe e fasce di pericolo ai fianchi.
    b.box((1.3, 0.3, 0.6), (0.0, -1.08, 0.98), DARK_METAL, back=(0.9, 0.8))
    b.box((0.5, 0.03, 0.3), (-0.2, -1.235, 1.0), HAZARD)
    for x in (-0.61, 0.61):
        b.box((0.03, 0.7, 0.3), (x, -0.3, 1.0), RUST)
    return b.to_object("Demolisher")


def build_demolisher_blade():
    """Lama da demolizione: larga 2,3 m, alta 1,1 m, concava, con filo consumato in basso,
    denti di rottame in cima e bracci di spinta verso lo scafo. Origine al centro della
    lama (il codice la tiene a 0,6 m da terra, 1,15 m davanti al boss, e la fa martellare)."""
    b = Builder(["detail"])
    blade = [(-0.1, -0.5), (0.2, -0.5), (0.08, -0.2), (0.05, 0.15), (0.14, 0.5), (-0.1, 0.5)]
    b.profile(blade, 2.3, (0.0, 0.0, 0.0), DARK_METAL)
    b.box((2.34, 0.14, 0.12), (0.0, 0.16, -0.46), WORN_STEEL)
    for i in range(6):
        x = -0.95 + i * 0.38
        b.box((0.2, 0.18, 0.26), (x, 0.03, 0.6), WORN_STEEL, top=(0.15, 0.3))
    for i in range(4):
        b.box((0.26, 0.03, 0.5), (-0.84 + i * 0.56, -0.115, 0.05), HAZARD, rot=(0.0, 25.0, 0.0))
    for x in (-1.04, 1.04):
        b.box((0.14, 1.2, 0.2), (x, -0.68, -0.2), STEEL)
        b.box((0.16, 0.3, 0.34), (x, -0.2, -0.16), DARK_METAL)
    return b.to_object("DemolisherBlade")


def build_driller():
    """Trivella (D-066): macchina da galleria su cingoli, capsula 0,9 x 2,4 m come il
    Demolitore. Scafo basso e tozzo (vernice), collare d'acciaio in avanti dove si
    innesta la punta (asset separato `driller_bit`, che il codice fa girare), cabina
    arretrata con due feritoie rosse luminose, serbatoi ai fianchi, tubo di scarico."""
    b = Builder(["detail"])
    track = [(-1.1, 0.25), (-0.85, 0.0), (0.85, 0.0), (1.1, 0.25), (1.1, 0.5), (0.9, 0.72),
             (-0.9, 0.72), (-1.1, 0.5)]
    for x in (-0.7, 0.7):
        b.profile(track, 0.46, (x, 0.0, 0.0), TIRE)
        for y in (-0.65, 0.0, 0.65):
            b.cyl(0.2, 0.5, (x, y, 0.36), STEEL, axis="x", sides=6)
    # Scafo: basso, piu largo dietro.
    b.box((1.3, 2.0, 0.7), (0.0, -0.1, 0.95), WHITE, paint=True, front=(0.85, 0.9), top=(0.92, 0.96))
    # Collare della punta: tronco di cono d'acciaio in avanti, con flangia.
    b.cyl(0.62, 0.5, (0.0, 1.05, 1.0), STEEL, axis="y", sides=10, radius_top=0.5)
    b.cyl(0.7, 0.1, (0.0, 0.82, 1.0), DARK_METAL, axis="y", sides=10)
    for i in range(8):
        a = math.radians(i * 45.0)
        b.box((0.08, 0.08, 0.08), (math.cos(a) * 0.62, 0.84, 1.0 + math.sin(a) * 0.62), WORN_STEEL)
    # Cabina arretrata, feritoie rosse, tetto.
    b.box((1.0, 0.8, 0.62), (0.0, -0.55, 1.6), DARK_METAL, top=(0.9, 0.9))
    for x in (-0.28, 0.28):
        b.box((0.34, 0.08, 0.1), (x, -0.13, 1.72), BOSS_EYE, emit=True)
    b.box((1.06, 0.88, 0.1), (0.0, -0.55, 1.95), shade(0.85), paint=True)
    # Serbatoi ai fianchi e tubo di scarico.
    for x in (-0.62, 0.62):
        b.cyl(0.17, 1.1, (x, 0.1, 1.42), RUST, axis="y", sides=8)
    b.cyl(0.08, 0.7, (-0.35, -0.8, 2.2), DARK_METAL, sides=6)
    b.cyl(0.11, 0.1, (-0.35, -0.8, 2.56), RUST, sides=6)
    # Fasce di pericolo sul retro.
    b.box((1.2, 0.04, 0.26), (0.0, -1.12, 0.95), HAZARD)
    return b.to_object("Driller")


def build_driller_bit():
    """Punta della Trivella: cono d'acciaio lungo 1,5 m con tre creste elicoidali e
    denti consumati. Origine alla base del cono (dove si innesta nel collare); l'asse
    e +Y (in Godot -Z): il codice la fa girare attorno al proprio asse."""
    b = Builder(["detail"])
    b.cyl(0.52, 1.5, (0.0, 0.75, 0.0), WORN_STEEL, axis="y", sides=10, radius_top=0.06)
    for i in range(3):
        for k in range(5):
            t = k / 5.0
            a = math.radians(i * 120.0 + t * 200.0)
            r = 0.5 - t * 0.42
            y = 0.1 + t * 1.3
            b.box((0.12, 0.3, 0.1), (math.cos(a) * r, y, math.sin(a) * r), DARK_METAL,
                  rot=(0.0, math.degrees(a) + 90.0, 0.0))
    b.cyl(0.1, 0.12, (0.0, 1.52, 0.0), STEEL, axis="y", sides=6, radius_top=0.02)
    return b.to_object("DrillerBit")


ASSETS = {
    "companion_cart": build_companion_cart,
    "scavenger": build_scavenger,
    "demolisher": build_demolisher,
    "demolisher_blade": build_demolisher_blade,
    "driller": build_driller,
    "driller_bit": build_driller_bit,
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = argv or list(ASSETS)
    for name in names:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        obj = ASSETS[name]()
        export(obj, name)


main()
