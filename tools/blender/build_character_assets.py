"""Genera i personaggi con scheletro e animazioni e li esporta in glTF (pipeline D-060).

Eseguire (Blender 5.2.2, senza interfaccia):
    blender -b --factory-startup --python tools/blender/build_character_assets.py -- [nome ...]

Senza nomi costruisce tutti gli asset. Uscita: godot/assets/models/<nome>.glb.
Dopo l'export: godot_console --headless --path godot --editor --quit (importa i .glb).

Come funziona:
- scheletro e animazioni vengono dalla Universal Animation Library di Quaternius (CC0,
  `third_party/quaternius_ual/`, variante Godot). Lo script la importa, butta il
  manichino, **riproporziona le ossa** (`PROPORTIONS`: gambe corte, spalle larghe) senza
  cambiarne direzione ne rollio, cosi le rotazioni delle animazioni restano valide, e
  scala la traslazione del bacino con la lunghezza delle gambe;
- il modello e fatto di **pezzi rigidi**: ogni primitiva pesa 1 su un solo osso
  (parametro `bone`), niente deformazione da sistemare. I pezzi si disegnano nella posa
  di riposo, a T, usando le posizioni delle giunture (`Skeleton.head/tail`);
- delle animazioni della libreria restano solo quelle in `ANIMATIONS`, con il nome originale.

Convenzioni:
- metri; origine a terra fra i piedi. **Nello spazio dello scheletro il fronte guarda -Y
  e la sinistra del personaggio e +X** (come la libreria); il nodo `Facing` ruota `Rig` di
  180 gradi sotto la radice, quindi in Godot il fronte guarda -Z come gli altri attori;
- colore nei vertici e materiali semantici (`suit`, `detail`) come in
  build_actor_assets.py: `UV.x = 1` emette luce, `UV.y = 1` e "vernice".
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "godot", "assets", "models")
LIBRARY = os.path.join(os.path.dirname(__file__), "third_party", "quaternius_ual",
                       "AnimationLibrary_Godot_Standard.glb")

# Colori lineari (gli stessi di build_actor_assets.py).
DARK_METAL = (0.07, 0.07, 0.075)
LEATHER = (0.3, 0.15, 0.06)
BOOT = (0.06, 0.04, 0.03)
SKIN = (0.72, 0.4, 0.26)
CREAM = (0.9, 0.78, 0.5)
TEAL = (0.02, 0.3, 0.3)
CANVAS = (0.5, 0.36, 0.16)
CORAL = (0.85, 0.1, 0.16)
COPPER = (0.6, 0.22, 0.06)
CYAN_LIGHT = (0.0, 0.8, 1.0)

HIPS = "DEF-hips"
SPINE = "DEF-spine.001"
CHEST = "DEF-spine.003"
HEAD = "DEF-head"

# Animazioni della libreria che finiscono nel .glb.
ANIMATIONS = ("Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Pistol_Idle_Loop", "Pistol_Aim_Neutral", "Hit_Chest",
              "Death01", "Interact")

# Proporzioni: per osso (senza suffisso .L/.R) la scala della lunghezza e quella, per
# asse, dello stacco dalla punta dell'osso padre. Dita rimosse.
PROPORTIONS = {
    "DEF-thigh": (0.62, (1.55, 1.0, 1.0)),
    "DEF-shin": (0.62, (1.0, 1.0, 1.0)),
    "DEF-neck": (0.6, (1.0, 1.0, 1.0)),
    "DEF-shoulder": (1.6, (1.0, 1.0, 1.0)),
    "DEF-upper_arm": (0.8, (1.0, 1.0, 1.0)),
    "DEF-forearm": (0.8, (1.0, 1.0, 1.0)),
}
REMOVED_BONES = ("DEF-f_", "DEF-thumb")


def shade(value):
    return (value, value, value)


def action_fcurves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                yield from bag.fcurves


class Skeleton:
    """Lo scheletro della libreria, riproporzionato, con le sole animazioni scelte."""

    def __init__(self):
        bpy.ops.import_scene.gltf(filepath=LIBRARY)
        for obj in list(bpy.data.objects):
            if obj.type != "ARMATURE":
                bpy.data.objects.remove(obj, do_unlink=True)
        self.obj = next(o for o in bpy.data.objects if o.type == "ARMATURE")
        self.obj.name = "Rig"
        self.obj.animation_data_clear()
        for action in list(bpy.data.actions):
            if action.name not in ANIMATIONS:
                bpy.data.actions.remove(action)
        missing = [name for name in ANIMATIONS if name not in bpy.data.actions]
        if missing:
            raise RuntimeError("Animazioni assenti dalla libreria: %s" % missing)
        # L'export glTF prende le azioni dalle tracce NLA dell'armatura: una traccia per azione.
        animation_data = self.obj.animation_data_create()
        for name in ANIMATIONS:
            action = bpy.data.actions[name]
            track = animation_data.nla_tracks.new()
            track.name = name
            strip = track.strips.new(name, int(action.frame_range[0]), action)
            if strip.action_slot is None and action.slots:
                strip.action_slot = action.slots[0]
        self.joints = {}
        self._reproportion()

    def head(self, bone):
        return self.joints[bone][0].copy()

    def tail(self, bone):
        return self.joints[bone][1].copy()

    def _reproportion(self):
        bpy.context.view_layer.objects.active = self.obj
        bpy.ops.object.mode_set(mode="EDIT")
        bones = self.obj.data.edit_bones
        for bone in list(bones):
            if bone.name.startswith(REMOVED_BONES):
                bones.remove(bone)
        old = {b.name: (b.head.copy(), b.tail.copy(), b.roll) for b in bones}
        new = {}

        def visit(bone):
            head, tail, _ = old[bone.name]
            length, joint = PROPORTIONS.get(bone.name.rsplit(".", 1)[0] if bone.name[-2:] in (".L", ".R")
                                            else bone.name, (1.0, (1.0, 1.0, 1.0)))
            if bone.parent is None:
                new_head = head.copy()
            else:
                gap = head - old[bone.parent.name][1]
                new_head = new[bone.parent.name][1] + Vector((gap.x * joint[0], gap.y * joint[1], gap.z * joint[2]))
            new[bone.name] = (new_head, new_head + (tail - head) * length)
            for child in bone.children:
                visit(child)

        roots = [b for b in bones if b.parent is None]
        for bone in roots:
            visit(bone)
        # Le gambe accorciate sollevano i piedi: tutto tranne la radice scende di quanto serve.
        feet = [name for name in new if name.startswith("DEF-toe")]
        old_floor = min(min(old[n][0].z, old[n][1].z) for n in feet)
        new_floor = min(min(new[n][0].z, new[n][1].z) for n in feet)
        drop = Vector((0.0, 0.0, old_floor - new_floor))
        root_names = {b.name for b in roots}
        for bone in bones:
            bone.use_connect = False
        for bone in bones:
            head, tail = new[bone.name]
            if bone.name not in root_names:
                head, tail = head + drop, tail + drop
            bone.head, bone.tail, bone.roll = head, tail, old[bone.name][2]
            self.joints[bone.name] = (head.copy(), tail.copy())
        bpy.ops.object.mode_set(mode="OBJECT")

        # Il bacino trasla in proporzione alle gambe: passo e molleggio restano coerenti.
        def leg(joints):
            return (joints["DEF-thigh.L"][0] - joints["DEF-shin.L"][1]).length
        ratio = leg(self.joints) / leg(old)
        hips_location = 'pose.bones["%s"].location' % HIPS
        removed = tuple('pose.bones["%s' % prefix for prefix in REMOVED_BONES)
        for action in bpy.data.actions:
            for layer in action.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        for curve in [c for c in bag.fcurves if c.data_path.startswith(removed)]:
                            bag.fcurves.remove(curve)
            for curve in action_fcurves(action):
                if curve.data_path == hips_location:
                    for key in curve.keyframe_points:
                        key.co.y *= ratio
                        key.handle_left.y *= ratio
                        key.handle_right.y *= ratio
                    curve.update()
        print("SKELETON leg_ratio=%.3f hips_z=%.3f shoulder_x=%.3f head_z=%.3f"
              % (ratio, self.joints[HIPS][0].z, self.joints["DEF-upper_arm.L"][0].x, self.joints[HEAD][0].z))


class Builder:
    """Accumula primitive in un solo bmesh, con colore, indicatori e osso per pezzo."""

    def __init__(self, materials):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.deform = self.bm.verts.layers.deform.verify()
        self.materials = materials
        self.bones = []

    def _finish(self, verts, bone, color, mat, paint, emit):
        if bone not in self.bones:
            self.bones.append(bone)
        group = self.bones.index(bone)
        faces = set()
        for v in verts:
            v[self.deform][group] = 1.0
            faces.update(v.link_faces)
        index = self.materials.index(mat)
        for face in faces:
            face.material_index = index
            face.smooth = False
            for loop in face.loops:
                loop[self.col] = (color[0], color[1], color[2], 1.0)
                # L'export glTF ribalta V: in Godot UV.y vale `paint`.
                loop[self.uv].uv = (1.0 if emit else 0.0, 0.0 if paint else 1.0)

    def box(self, bone, size, center, color, mat="detail", paint=False, emit=False,
            rot=(0.0, 0.0, 0.0), top=(1.0, 1.0), bottom=(1.0, 1.0), front=(1.0, 1.0), back=(1.0, 1.0)):
        """Scatola. `top`/`bottom` restringono (x, y) le facce alta e bassa; `front`/`back`
        restringono (x, z) quelle a -Y (il fronte) e +Y. `rot` in gradi (Eulero XYZ)."""
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        for v in verts:
            x, y, z = v.co.x, v.co.y, v.co.z
            tb = top if z > 0.0 else bottom
            fb = front if y < 0.0 else back
            v.co = Vector((x * size[0] * tb[0] * fb[0], y * size[1] * tb[1], z * size[2] * fb[1]))
        self._place(verts, center, rot)
        self._finish(verts, bone, color, mat, paint, emit)

    def cyl(self, bone, radius, depth, center, color, mat="detail", paint=False, emit=False,
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
        self._finish(verts, bone, color, mat, paint, emit)

    def _place(self, verts, center, rot):
        matrix = Matrix.Translation(Vector(center)) @ Euler(
            (math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2])), "XYZ").to_matrix().to_4x4()
        bmesh.ops.transform(self.bm, verts=verts, matrix=matrix)

    def to_object(self, name, skeleton):
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
        for bone in self.bones:
            if bone not in skeleton.joints:
                raise RuntimeError("Osso inesistente: %s" % bone)
            obj.vertex_groups.new(name=bone)
        obj.parent = skeleton.obj
        obj.modifiers.new("Armature", "ARMATURE").object = skeleton.obj
        return obj


def export(skeleton, obj, asset_name, root_name):
    root = bpy.data.objects.new(root_name, None)
    bpy.context.collection.objects.link(root)
    # L'export ignora la rotazione dell'oggetto armatura: la porta un nodo intermedio.
    facing = bpy.data.objects.new("Facing", None)
    bpy.context.collection.objects.link(facing)
    facing.parent = root
    facing.rotation_euler = (0.0, 0.0, math.pi)
    skeleton.obj.parent = facing
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, asset_name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    for item in (root, facing, skeleton.obj, obj):
        item.select_set(True)
    bpy.context.view_layer.objects.active = skeleton.obj
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_optimize_animation_size=True,
        export_skins=True,
        export_def_bones=False,
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
    )
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    mats = [m.name for m in obj.data.materials]
    print("ASSET_EXPORTED %s rest_pose x=[%.2f, %.2f] y=[%.2f, %.2f] z=[%.2f, %.2f] tris=%d bones=%d "
          "animations=%d materials=%s"
          % (asset_name, min(xs), max(xs), min(ys), max(ys), min(zs), max(zs), tris,
             len(skeleton.obj.data.bones), len(bpy.data.actions), ",".join(mats)))


# --- Personaggi --------------------------------------------------------------------

def build_player_engineer():
    """Ingegnere: tozzo, gambe corte, busto e spalle larghi, testa e mani grandi; in piedi
    arriva a circa 1,75 m con l'elmetto, come la capsula. Tuta (materiale `suit`, colorata
    dal codice), elmetto crema con lampada ciano, zaino-officina verde petrolio con rotolo,
    bombola e antenna, attrezzo da terreno nella mano destra con la punta ciano. Disegnato
    a T: le braccia corrono lungo X, l'attrezzo prolunga l'avambraccio destro."""
    s = Skeleton()
    b = Builder(["suit", "detail"])

    # Gambe: coscia, stinco, stivale largo con la punta rastremata.
    for side, sign in ((".L", 1.0), (".R", -1.0)):
        hip, knee, ankle = s.head("DEF-thigh" + side), s.head("DEF-shin" + side), s.head("DEF-foot" + side)
        b.box("DEF-thigh" + side, (0.23, 0.27, hip.z - knee.z + 0.1),
              (hip.x, 0.0, (hip.z + knee.z) * 0.5 + 0.01), shade(0.55), mat="suit")
        b.box("DEF-shin" + side, (0.21, 0.25, knee.z - ankle.z + 0.06),
              (hip.x, 0.01, (knee.z + ankle.z) * 0.5 + 0.03), shade(0.5), mat="suit")
        b.box("DEF-shin" + side, (0.24, 0.1, 0.1), (hip.x, -0.1, knee.z - 0.02), LEATHER)
        b.box("DEF-foot" + side, (0.26, 0.4, 0.2), (hip.x, -0.05, 0.1), BOOT, front=(0.85, 0.65))

    # Bacino con cintura e borsello; busto in due pezzi che si sovrappongono in vita.
    hips_z = s.head(HIPS).z
    waist_z = s.head(SPINE).z
    chest_z = s.head(CHEST).z
    neck_z = s.tail(CHEST).z
    b.box(HIPS, (0.52, 0.36, 0.22), (0.0, 0.0, hips_z + 0.05), shade(0.55), mat="suit", bottom=(0.8, 0.9))
    b.box(HIPS, (0.56, 0.4, 0.09), (0.0, 0.0, waist_z - 0.02), LEATHER)
    b.box(HIPS, (0.16, 0.1, 0.17), (0.2, -0.22, waist_z - 0.07), CANVAS)
    b.box(SPINE, (0.54, 0.38, chest_z - waist_z + 0.08), (0.0, 0.0, (waist_z + chest_z) * 0.5 + 0.02),
          shade(0.9), mat="suit")
    b.box(CHEST, (0.66, 0.44, neck_z - chest_z + 0.1), (0.0, 0.0, (chest_z + neck_z) * 0.5),
          shade(1.0), mat="suit", bottom=(0.84, 0.88))
    b.box(CHEST, (0.36, 0.04, 0.24), (0.0, -0.225, (chest_z + neck_z) * 0.5 + 0.01), shade(0.6), mat="suit")
    b.box(CHEST, (0.1, 0.02, 0.08), (-0.09, -0.25, (chest_z + neck_z) * 0.5 + 0.05), CORAL)
    # Sciarpa.
    b.box(CHEST, (0.46, 0.44, 0.1), (0.0, -0.01, neck_z + 0.03), CORAL)

    # Zaino-officina sulla schiena (+Y): corpo, tasca, rotolo sotto, bombola, antenna con bandierina.
    pack_z = (chest_z + neck_z) * 0.5 - 0.04
    b.box(CHEST, (0.48, 0.3, 0.46), (0.0, 0.36, pack_z), TEAL, top=(0.9, 0.9))
    b.box(CHEST, (0.26, 0.06, 0.2), (-0.04, 0.53, pack_z - 0.02), CANVAS)
    b.cyl(CHEST, 0.11, 0.62, (0.0, 0.38, pack_z - 0.31), CANVAS, axis="x", sides=6)
    b.cyl(CHEST, 0.08, 0.44, (-0.31, 0.38, pack_z), COPPER, sides=6)
    b.box(CHEST, (0.04, 0.04, 0.75), (0.2, 0.46, pack_z + 0.55), DARK_METAL)
    b.box(CHEST, (0.04, 0.2, 0.13), (0.2, 0.57, pack_z + 0.86), CORAL)

    # Testa grande, occhialoni, respiratore; elmetto con tesa e lampada.
    head_z = s.head(HEAD).z
    b.box(HEAD, (0.38, 0.36, 0.3), (0.0, -0.02, head_z + 0.17), SKIN)
    b.box(HEAD, (0.4, 0.08, 0.11), (0.0, -0.18, head_z + 0.21), DARK_METAL)
    for x in (-0.09, 0.09):
        b.box(HEAD, (0.11, 0.03, 0.07), (x, -0.225, head_z + 0.21), CYAN_LIGHT, emit=True)
    b.box(HEAD, (0.3, 0.1, 0.12), (0.0, -0.17, head_z + 0.07), shade(0.75))
    b.cyl(HEAD, 0.34, 0.05, (0.0, -0.04, head_z + 0.32), CREAM, sides=8)
    b.cyl(HEAD, 0.28, 0.2, (0.0, -0.01, head_z + 0.43), CREAM, sides=8, radius_top=0.2)
    b.box(HEAD, (0.14, 0.1, 0.12), (0.0, -0.28, head_z + 0.42), CYAN_LIGHT, emit=True)

    # Braccia a T: spallaccio, braccio, avambraccio, guantone.
    for side, sign in ((".L", 1.0), (".R", -1.0)):
        shoulder, elbow, wrist = (s.head("DEF-upper_arm" + side), s.head("DEF-forearm" + side),
                                  s.head("DEF-hand" + side))
        b.box("DEF-shoulder" + side, (0.26, 0.34, 0.13), (shoulder.x - sign * 0.01, shoulder.y - 0.03, shoulder.z + 0.1),
              shade(1.0), mat="suit", top=(0.8, 0.8))
        b.box("DEF-upper_arm" + side, (abs(elbow.x - shoulder.x) + 0.1, 0.2, 0.2),
              ((shoulder.x + elbow.x) * 0.5, shoulder.y, shoulder.z), shade(0.8), mat="suit")
        b.box("DEF-forearm" + side, (abs(wrist.x - elbow.x) + 0.06, 0.19, 0.19),
              ((elbow.x + wrist.x) * 0.5 + sign * 0.02, elbow.y, elbow.z), shade(0.75), mat="suit")
        b.box("DEF-hand" + side, (0.2, 0.23, 0.2), (wrist.x + sign * 0.09, wrist.y, wrist.z), LEATHER)

    # Attrezzo da terreno nella destra: prolunga l'avambraccio (-X); il serbatoio pende
    # dal lato del palmo (-Z a T), la punta luminosa e l'indicatore del fronte.
    grip = s.head("DEF-hand.R") + Vector((-0.09, 0.0, 0.0))
    b.box("DEF-hand.R", (0.62, 0.13, 0.13), (grip.x - 0.2, grip.y, grip.z - 0.16), DARK_METAL)
    b.cyl("DEF-hand.R", 0.11, 0.3, (grip.x + 0.02, grip.y, grip.z - 0.2), COPPER, axis="x", sides=6)
    b.box("DEF-hand.R", (0.12, 0.22, 0.22), (grip.x - 0.56, grip.y, grip.z - 0.16), CYAN_LIGHT, emit=True)
    obj = b.to_object("PlayerEngineerMesh", s)
    return s, obj, "PlayerEngineer"


ASSETS = {
    "player_engineer": build_player_engineer,
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = argv or list(ASSETS)
    for name in names:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        skeleton, obj, root_name = ASSETS[name]()
        export(skeleton, obj, name, root_name)


main()
