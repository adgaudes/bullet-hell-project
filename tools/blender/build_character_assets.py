"""Genera i personaggi con scheletro e animazioni e li esporta in glTF (pipeline D-060).

Eseguire (Blender 5.2.2, senza interfaccia):
    blender -b --factory-startup --python tools/blender/build_character_assets.py -- [nome ...]

Senza nomi stampa l'uso; l'ingegnere del gioco lo costruisce `build_engineer.py` (D-088).
I due costruttori qui (D-074 rifinito e a blocchi) restano per confronto ed escono in
output/engineer/before/<nome>.glb.

Come funziona:
- scheletro e animazioni vengono dalla Universal Animation Library di Quaternius (CC0,
  `third_party/quaternius_ual/`, variante Godot). Lo script la importa, butta il
  manichino, **riproporziona le ossa** (`PROPORTIONS`: gambe corte, spalle larghe) senza
  cambiarne direzione ne rollio, cosi le rotazioni delle animazioni restano valide, e
  scala la traslazione del bacino con la lunghezza delle gambe;
- il modello e fatto di **pezzi rigidi**: ogni primitiva pesa 1 su un solo osso
  (parametro `bone`), niente deformazione da sistemare. I pezzi si disegnano nella posa
  di riposo, a T, usando le posizioni delle giunture (`Skeleton.head/tail`);
- delle animazioni della libreria restano solo quelle in `ANIMATIONS`, con il nome originale;
- le animazioni Mixamo di `MIXAMO_CLIPS` (`third_party/mixamo/`) vengono riportate sullo
  stesso scheletro copiando, osso per osso, la rotazione rispetto alla posa di riposo.

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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from refined import RefinedBuilder  # noqa: E402

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

## Zainetto di terra (spec terreno continuo, sezione 3): tela della sacca e striscia indicatore.
PACK_SACK = (0.5, 0.36, 0.16)
PACK_GAUGE = (0.95, 0.9, 0.8)

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

# Animazioni Mixamo (FBX senza skin in `third_party/mixamo/`, scaricate dal proprietario;
# licenza Adobe: uso libero nel gioco, vietato ridistribuire i file grezzi). Per file:
# nome dell'animazione (`_Loop` = ciclica in Godot), se togliere lo spostamento
# orizzontale del bacino, e l'intervallo in secondi da tenere (None = tutto).
MIXAMO_DIR = os.path.join(os.path.dirname(__file__), "third_party", "mixamo")
MIXAMO_FPS = 30.0
MIXAMO_CLIPS = {
    "strafe_left.fbx": ("Strafe_Left_Loop", False, None),
    "strafe_right.fbx": ("Strafe_Right_Loop", False, None),
    "run_backward.fbx": ("Run_Bwd_Loop", False, None),
    # Un solo affondo dell'attrezzo; la sola capriola, senza preparazione ne rialzata.
    "dig.fbx": ("Dig", True, (0.3, 1.5)),
    "dodge.fbx": ("Dodge", True, (0.5, 2.0)),
}
# Osso dello scheletro -> osso Mixamo (senza il prefisso `mixamorig:`).
MIXAMO_BONES = {
    "DEF-hips": "Hips", "DEF-spine.001": "Spine", "DEF-spine.002": "Spine1", "DEF-spine.003": "Spine2",
    "DEF-neck": "Neck", "DEF-head": "Head",
    "DEF-shoulder.L": "LeftShoulder", "DEF-upper_arm.L": "LeftArm", "DEF-forearm.L": "LeftForeArm",
    "DEF-hand.L": "LeftHand",
    "DEF-shoulder.R": "RightShoulder", "DEF-upper_arm.R": "RightArm", "DEF-forearm.R": "RightForeArm",
    "DEF-hand.R": "RightHand",
    "DEF-thigh.L": "LeftUpLeg", "DEF-shin.L": "LeftLeg", "DEF-foot.L": "LeftFoot", "DEF-toe.L": "LeftToeBase",
    "DEF-thigh.R": "RightUpLeg", "DEF-shin.R": "RightLeg", "DEF-foot.R": "RightFoot", "DEF-toe.R": "RightToeBase",
}


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
        self.obj.animation_data_create()
        for name in ANIMATIONS:
            self._stash(bpy.data.actions[name])
        self.joints = {}
        self._reproportion()
        for filename, (name, strip_travel, span) in MIXAMO_CLIPS.items():
            self._add_mixamo(filename, name, strip_travel, span)

    def _stash(self, action):
        """L'export glTF prende le azioni dalle tracce NLA dell'armatura: una traccia per azione."""
        track = self.obj.animation_data.nla_tracks.new()
        track.name = action.name
        strip = track.strips.new(action.name, int(action.frame_range[0]), action)
        if strip.action_slot is None and action.slots:
            strip.action_slot = action.slots[0]

    def _add_mixamo(self, filename, name, strip_travel, span):
        """Porta un'animazione Mixamo sullo scheletro. Le due pose di riposo sono la stessa
        T nello stesso verso, quindi per ogni osso basta copiare, in spazio mondo, la
        rotazione rispetto al riposo; il bacino trasla in proporzione alla sua altezza."""
        objects, actions = set(bpy.data.objects), set(bpy.data.actions)
        scene = bpy.context.scene
        # L'import FBX porta la scena a 30 fps: rimessa com'era, o l'export accelera tutto.
        fps = scene.render.fps
        bpy.ops.import_scene.fbx(filepath=os.path.join(MIXAMO_DIR, filename))
        scene.render.fps = fps
        source = next(o for o in bpy.data.objects if o not in objects and o.type == "ARMATURE")
        source_action = next(a for a in bpy.data.actions if a not in actions)
        world = source.matrix_world

        def rotation(matrix):
            return matrix.to_3x3().normalized().to_quaternion()

        def source_bone(target):
            return "mixamorig:" + MIXAMO_BONES[target]

        # Stessa posa di riposo: a T, sinistra a +X, fronte a -Y.
        arm = source.data.bones[source_bone("DEF-upper_arm.L")]
        toe = source.data.bones[source_bone("DEF-toe.L")]
        arm_axis = (world.to_3x3() @ (arm.tail_local - arm.head_local)).normalized()
        toe_axis = (world.to_3x3() @ (toe.tail_local - toe.head_local)).normalized()
        if arm_axis.x < 0.9 or toe_axis.y > -0.5:
            raise RuntimeError("%s: posa di riposo inattesa (braccio %s, punta %s)" % (filename, arm_axis, toe_axis))

        bones = list(self.obj.data.bones)
        rest = {b.name: b.matrix_local.to_quaternion() for b in bones}
        source_rest = {b.name: rotation(world @ source.data.bones[source_bone(b.name)].matrix_local)
                       for b in bones if b.name in MIXAMO_BONES}
        hips_rest = (world @ source.data.bones[source_bone(HIPS)].matrix_local).translation
        ratio = self.obj.data.bones[HIPS].head_local.z / hips_rest.z

        first, last = (int(round(v)) for v in source_action.frame_range)
        if span is not None:
            first, last = first + int(round(span[0] * MIXAMO_FPS)), first + int(round(span[1] * MIXAMO_FPS))
        frame_scale = scene.render.fps / MIXAMO_FPS
        keys = {b.name: [] for b in bones if b.name in MIXAMO_BONES}
        hips_keys = []
        for frame in range(first, last + 1):
            scene.frame_set(frame)
            time = (frame - first) * frame_scale
            pose = {}
            for bone in bones:
                parent = bone.parent.name if bone.parent else None
                if bone.name in MIXAMO_BONES:
                    now = rotation(world @ source.pose.bones[source_bone(bone.name)].matrix)
                    pose[bone.name] = now @ source_rest[bone.name].inverted() @ rest[bone.name]
                elif parent is not None:
                    pose[bone.name] = pose[parent] @ rest[parent].inverted() @ rest[bone.name]
                else:
                    pose[bone.name] = rest[bone.name].copy()
                if bone.name not in MIXAMO_BONES:
                    continue
                if parent is not None:
                    basis = (rest[parent].inverted() @ rest[bone.name]).inverted() @ pose[parent].inverted() @ pose[bone.name]
                else:
                    basis = rest[bone.name].inverted() @ pose[bone.name]
                track = keys[bone.name]
                if track and track[-1][1].dot(basis) < 0.0:
                    basis.negate()
                track.append((time, basis))
            travel = (world @ source.pose.bones[source_bone(HIPS)].matrix).translation - hips_rest
            if strip_travel:
                travel.x = travel.y = 0.0
            hips_keys.append((time, rest[HIPS].inverted() @ (travel * ratio)))

        action = bpy.data.actions.new(name)
        slot = action.slots.new(id_type="OBJECT", name=self.obj.name)
        bag = action.layers.new("Layer").strips.new(type="KEYFRAME").channelbag(slot, ensure=True)

        def curve(path, index, values):
            fcurve = bag.fcurves.new(path, index=index)
            fcurve.keyframe_points.add(len(values))
            for point, (time, value) in zip(fcurve.keyframe_points, values):
                point.co = (time, value)
                point.interpolation = "LINEAR"
            fcurve.update()

        for bone_name, track in keys.items():
            for index in range(4):
                curve('pose.bones["%s"].rotation_quaternion' % bone_name, index, [(t, q[index]) for t, q in track])
        for index in range(3):
            curve('pose.bones["%s"].location' % HIPS, index, [(t, v[index]) for t, v in hips_keys])

        armature = source.data
        bpy.data.objects.remove(source, do_unlink=True)
        bpy.data.armatures.remove(armature)
        bpy.data.actions.remove(source_action)
        self._stash(action)
        print("MIXAMO %s -> %s frames=%d seconds=%.2f hips_ratio=%.3f"
              % (filename, name, last - first + 1, (last - first) / MIXAMO_FPS, ratio))

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


def build_pack_sack(skeleton, pack_z):
    """Zainetto di terra (spec sezione 3): sacca di tela appesa sotto lo zaino-officina e
    striscia indicatore sul fianco destro, come oggetto a parte `PackSack` con due materiali
    propri (colore base, nessuna cottura): Godot lo trova con `find_child`, sostituisce il
    materiale della striscia con `pack_gauge.gdshader` e scala la sacca. UV della striscia:
    V = 0 in basso, 1 in alto (l'export glTF la ribalta: in Godot UV.y = 1 in basso)."""
    sack_mat = bpy.data.materials.new("pack_sack")
    gauge_mat = bpy.data.materials.new("pack_gauge")
    for mat, color in ((sack_mat, PACK_SACK), (gauge_mat, PACK_GAUGE)):
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
        bsdf.inputs["Roughness"].default_value = 0.85
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    def add_box(size, center, material_index):
        verts = bmesh.ops.create_cube(bm, size=1.0)["verts"]
        for v in verts:
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        bmesh.ops.translate(bm, verts=verts, vec=Vector(center))
        z0, z1 = center[2] - size[2] * 0.5, center[2] + size[2] * 0.5
        faces = {face for v in verts for face in v.link_faces}
        for face in faces:
            face.material_index = material_index
            face.smooth = False
            for loop in face.loops:
                loop[uv].uv = (0.5, (loop.vert.co.z - z0) / (z1 - z0))

    sack_center = (0.0, 0.3, pack_z - 0.56)
    add_box((0.38, 0.24, 0.22), sack_center, 0)
    add_box((0.03, 0.2, 0.18), (-0.2, 0.3, pack_z - 0.56), 1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("PackSack")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(sack_mat)
    mesh.materials.append(gauge_mat)
    obj = bpy.data.objects.new("PackSack", mesh)
    bpy.context.collection.objects.link(obj)
    group = obj.vertex_groups.new(name=CHEST)
    group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
    obj.parent = skeleton.obj
    obj.modifiers.new("Armature", "ARMATURE").object = skeleton.obj
    return obj


def export(skeleton, obj, asset_name, root_name, vertex_color="ACTIVE", extras=(), out_dir=OUT_DIR):
    root = bpy.data.objects.new(root_name, None)
    bpy.context.collection.objects.link(root)
    # L'export ignora la rotazione dell'oggetto armatura: la porta un nodo intermedio.
    facing = bpy.data.objects.new("Facing", None)
    bpy.context.collection.objects.link(facing)
    facing.parent = root
    facing.rotation_euler = (0.0, 0.0, math.pi)
    skeleton.obj.parent = facing
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, asset_name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    for item in (root, facing, skeleton.obj, obj, *extras):
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
        export_vertex_color=vertex_color,
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

def build_player_engineer_blocky():
    """Ingegnere a blocchi (D-060, D-062), tenuto per confronto: tozzo, gambe corte, busto e spalle larghi, testa e mani grandi; in piedi
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



# --- Personaggio rifinito (D-071): costruttore in refined.py ---------------------------

def build_player_engineer_refined():
    """Ingegnere rifinito (D-071, D-074): stesse proporzioni e scheletro della versione a
    blocchi, ma pezzi smussati, testa, mani e stivali arrotondati, ginocchiere,
    cinturone con tasche, sciarpa, elmetto a cupola con tesa e lampada, zaino con tubi e
    bombola, attrezzo con serbatoio; colore, usura, occlusione e sporco cotti in una
    texture 1024. D-074: volto con occhi, sopracciglia e bocca (occhialoni alzati
    sull'elmetto, respiratore abbassato sul mento), normal map cotta (trama della tuta,
    grana e graffi), pesi sfumati a ginocchia, caviglie, gomiti, polsi e busto."""
    s = Skeleton()
    b = RefinedBuilder(paint_name="suit", front_axis=-1.0, bake_normal=True)
    EYE_WHITE = (0.85, 0.84, 0.8)
    EYE_DARK = (0.03, 0.025, 0.02)
    BROW = (0.1, 0.06, 0.03)
    GOGGLE_GLASS = (0.1, 0.22, 0.26)
    SUIT = shade(0.82)
    SUIT_DARK = shade(0.62)
    STEEL = (0.42, 0.42, 0.44)

    # Gambe: coscia e stinco smussati, ginocchiera arrotondata, stivale a punta tonda con suola.
    for side, sign in ((".L", 1.0), (".R", -1.0)):
        hip, knee, ankle = s.head("DEF-thigh" + side), s.head("DEF-shin" + side), s.head("DEF-foot" + side)
        b.box("DEF-thigh" + side, (0.24, 0.28, hip.z - knee.z + 0.1), (hip.x, 0.0, (hip.z + knee.z) * 0.5 + 0.01),
              SUIT_DARK, mat="suit", bevel=0.05, segments=3)
        b.box("DEF-shin" + side, (0.22, 0.26, knee.z - ankle.z + 0.06), (hip.x, 0.01, (knee.z + ankle.z) * 0.5 + 0.03),
              SUIT_DARK, mat="suit", bevel=0.05, segments=3)
        b.box("DEF-shin" + side, (0.26, 0.14, 0.16), (hip.x, -0.1, knee.z - 0.01), LEATHER, subsurf=2)
        b.box("DEF-foot" + side, (0.27, 0.42, 0.2), (hip.x, -0.06, 0.13), BOOT, subsurf=2, front=(0.8, 0.6))
        b.box("DEF-foot" + side, (0.29, 0.44, 0.05), (hip.x, -0.06, 0.03), DARK_METAL, bevel=0.015)
        b.box("DEF-foot" + side, (0.25, 0.06, 0.14), (hip.x, 0.14, 0.2), LEATHER, bevel=0.02)

    hips_z = s.head(HIPS).z
    waist_z = s.head(SPINE).z
    chest_z = s.head(CHEST).z
    neck_z = s.tail(CHEST).z
    # Bacino, cinturone con fibbia e tasche arrotondate.
    b.box(HIPS, (0.54, 0.38, 0.24), (0.0, 0.0, hips_z + 0.05), SUIT_DARK, mat="suit", bevel=0.06, segments=3,
          bottom=(0.8, 0.9))
    b.box(HIPS, (0.58, 0.42, 0.1), (0.0, 0.0, waist_z - 0.02), LEATHER, bevel=0.02)
    b.box(HIPS, (0.1, 0.03, 0.08), (0.0, -0.22, waist_z - 0.02), STEEL, bevel=0.01)
    b.box(HIPS, (0.17, 0.11, 0.18), (0.22, -0.22, waist_z - 0.08), CANVAS, subsurf=1)
    b.box(HIPS, (0.14, 0.1, 0.15), (-0.24, 0.2, waist_z - 0.08), CANVAS, subsurf=1)
    # Busto in due pezzi, pettorina con cerniera, taschino.
    b.box(SPINE, (0.56, 0.4, chest_z - waist_z + 0.08), (0.0, 0.0, (waist_z + chest_z) * 0.5 + 0.02), SUIT,
          mat="suit", bevel=0.06, segments=3)
    b.box(CHEST, (0.68, 0.46, neck_z - chest_z + 0.1), (0.0, 0.0, (chest_z + neck_z) * 0.5), SUIT, mat="suit",
          bevel=0.08, segments=3, bottom=(0.84, 0.88))
    b.box(CHEST, (0.03, 0.02, neck_z - waist_z - 0.06), (0.0, -0.24, (waist_z + neck_z) * 0.5), DARK_METAL, bevel=0.005)
    b.box(CHEST, (0.16, 0.03, 0.12), (-0.16, -0.245, (chest_z + neck_z) * 0.5 + 0.02), SUIT_DARK, mat="suit", bevel=0.01)
    b.box(CHEST, (0.1, 0.02, 0.06), (0.14, -0.25, (chest_z + neck_z) * 0.5 + 0.05), CORAL, bevel=0.008)
    # Sciarpa arrotondata attorno al collo.
    b.cyl(CHEST, 0.27, 0.12, (0.0, -0.01, neck_z + 0.03), CORAL, sides=14, bevel=0.04, segments=3)
    b.box(CHEST, (0.1, 0.06, 0.18), (0.16, -0.2, neck_z - 0.07), CORAL, subsurf=1)

    # Zaino-officina: corpo smussato, tasca, rotolo, bombola con valvola, tubo, antenna con bandierina.
    pack_z = (chest_z + neck_z) * 0.5 - 0.04
    b.box(CHEST, (0.5, 0.32, 0.48), (0.0, 0.37, pack_z), TEAL, bevel=0.05, segments=3)
    b.box(CHEST, (0.28, 0.08, 0.22), (-0.04, 0.55, pack_z - 0.02), CANVAS, subsurf=1)
    b.cyl(CHEST, 0.11, 0.64, (0.0, 0.39, pack_z - 0.32), CANVAS, axis="x", sides=14, bevel=0.03)
    b.cyl(CHEST, 0.085, 0.46, (-0.32, 0.39, pack_z), COPPER, sides=14, bevel=0.03)
    b.cyl(CHEST, 0.04, 0.08, (-0.32, 0.39, pack_z + 0.26), STEEL, sides=10, bevel=0.01)
    b.cyl(CHEST, 0.025, 0.3, (-0.2, 0.45, pack_z + 0.2), DARK_METAL, sides=8, rot=(0.0, 50.0, 0.0), bevel=0.005)
    b.cyl(CHEST, 0.018, 0.78, (0.2, 0.47, pack_z + 0.55), DARK_METAL, sides=8, bevel=0.004)
    b.box(CHEST, (0.03, 0.2, 0.13), (0.2, 0.58, pack_z + 0.86), CORAL, bevel=0.006)
    for x in (-0.2, 0.2):
        b.box(CHEST, (0.06, 0.1, 0.5), (x, 0.17, pack_z - 0.02), LEATHER, bevel=0.015)

    # Testa arrotondata con il volto (D-074): occhi, sopracciglia, naso, bocca; respiratore
    # abbassato sul mento; occhialoni alzati sull'elmetto a cupola con tesa; lampada in alto.
    head_z = s.head(HEAD).z
    b.box(HEAD, (0.4, 0.38, 0.32), (0.0, -0.02, head_z + 0.17), SKIN, bevel=0.12, segments=4)
    b.box(HEAD, (0.06, 0.05, 0.06), (0.0, -0.2, head_z + 0.14), SKIN, subsurf=2)
    for x in (-0.085, 0.085):
        b.sphere(HEAD, 0.048, (x, -0.185, head_z + 0.21), EYE_WHITE, scale=(1.0, 0.8, 1.0))
        b.sphere(HEAD, 0.022, (x, -0.223, head_z + 0.21), EYE_DARK)
        b.box(HEAD, (0.09, 0.025, 0.026), (x, -0.212, head_z + 0.262), BROW, bevel=0.006,
              rot=(0.0, math.copysign(12.0, x), 0.0))
    b.box(HEAD, (0.09, 0.016, 0.014), (0.0, -0.212, head_z + 0.095), EYE_DARK, bevel=0.004)
    b.box(HEAD, (0.3, 0.12, 0.1), (0.0, -0.17, head_z + 0.0), shade(0.7), bevel=0.03, segments=3)
    for x in (-0.12, 0.12):
        b.cyl(HEAD, 0.045, 0.05, (x, -0.22, head_z - 0.01), STEEL, axis="y", sides=10, bevel=0.01)
    b.cyl(HEAD, 0.35, 0.05, (0.0, -0.04, head_z + 0.32), CREAM, sides=18, bevel=0.015, segments=3)
    b.sphere(HEAD, 0.29, (0.0, -0.01, head_z + 0.31), CREAM, scale=(1.0, 1.0, 0.85), cut_below=0.0)
    for x in (-0.11, 0.11):
        b.cyl(HEAD, 0.075, 0.06, (x, -0.25, head_z + 0.4), DARK_METAL, axis="y", sides=14, bevel=0.015)
        b.cyl(HEAD, 0.055, 0.02, (x, -0.283, head_z + 0.4), GOGGLE_GLASS, axis="y", sides=12, bevel=0.005)
    b.box(HEAD, (0.3, 0.05, 0.05), (0.0, -0.25, head_z + 0.4), DARK_METAL, bevel=0.01)
    b.cyl(HEAD, 0.07, 0.1, (0.0, -0.21, head_z + 0.5), DARK_METAL, axis="y", sides=12, bevel=0.015)
    b.cyl(HEAD, 0.06, 0.03, (0.0, -0.27, head_z + 0.5), CYAN_LIGHT, mat="lamp", axis="y", sides=12, bevel=0.005)

    # Braccia: spallaccio, braccio e avambraccio smussati, polsino, guantone arrotondato con pollice.
    for side, sign in ((".L", 1.0), (".R", -1.0)):
        shoulder, elbow, wrist = (s.head("DEF-upper_arm" + side), s.head("DEF-forearm" + side),
                                  s.head("DEF-hand" + side))
        b.box("DEF-shoulder" + side, (0.28, 0.36, 0.14), (shoulder.x - sign * 0.01, shoulder.y - 0.03, shoulder.z + 0.1),
              SUIT, mat="suit", bevel=0.05, segments=3, top=(0.8, 0.8))
        b.box("DEF-upper_arm" + side, (abs(elbow.x - shoulder.x) + 0.1, 0.21, 0.21),
              ((shoulder.x + elbow.x) * 0.5, shoulder.y, shoulder.z), SUIT, mat="suit", bevel=0.06, segments=3)
        b.box("DEF-forearm" + side, (abs(wrist.x - elbow.x) + 0.06, 0.2, 0.2),
              ((elbow.x + wrist.x) * 0.5 + sign * 0.02, elbow.y, elbow.z), SUIT_DARK, mat="suit", bevel=0.06, segments=3)
        b.cyl("DEF-forearm" + side, 0.115, 0.07, (wrist.x - sign * 0.02, wrist.y, wrist.z), LEATHER, axis="x",
              sides=14, bevel=0.015)
        b.box("DEF-hand" + side, (0.2, 0.22, 0.2), (wrist.x + sign * 0.1, wrist.y, wrist.z), LEATHER, subsurf=2)
        b.box("DEF-hand" + side, (0.09, 0.08, 0.08), (wrist.x + sign * 0.06, wrist.y - 0.13, wrist.z + 0.02), LEATHER,
              subsurf=2)

    # Attrezzo da terreno nella destra: canna, serbatoio con valvola, impugnatura, punta luminosa.
    grip = s.head("DEF-hand.R") + Vector((-0.09, 0.0, 0.0))
    b.box("DEF-hand.R", (0.64, 0.12, 0.12), (grip.x - 0.2, grip.y, grip.z - 0.16), DARK_METAL, bevel=0.03, segments=3)
    b.cyl("DEF-hand.R", 0.11, 0.3, (grip.x + 0.02, grip.y, grip.z - 0.2), COPPER, axis="x", sides=14, bevel=0.03)
    b.cyl("DEF-hand.R", 0.03, 0.06, (grip.x + 0.02, grip.y, grip.z - 0.06), STEEL, sides=10, bevel=0.008)
    b.cyl("DEF-hand.R", 0.03, 0.14, (grip.x - 0.3, grip.y, grip.z - 0.07), LEATHER, sides=10, bevel=0.008)
    b.cyl("DEF-hand.R", 0.09, 0.08, (grip.x - 0.5, grip.y, grip.z - 0.16), STEEL, axis="x", sides=14, bevel=0.01)
    b.box("DEF-hand.R", (0.1, 0.2, 0.2), (grip.x - 0.58, grip.y, grip.z - 0.16), CYAN_LIGHT, mat="lamp", bevel=0.03,
          segments=3)
    # Pesi sfumati alle articolazioni (D-074): da osso a osso lungo l'arto.
    blends = [(HIPS, SPINE, (0.0, 0.0, waist_z), (0.0, 0.0, 1.0), 0.05),
              (SPINE, CHEST, (0.0, 0.0, chest_z), (0.0, 0.0, 1.0), 0.06)]
    for side, sign in ((".L", 1.0), (".R", -1.0)):
        blends.append(("DEF-thigh" + side, "DEF-shin" + side, s.head("DEF-shin" + side), (0.0, 0.0, -1.0), 0.07))
        blends.append(("DEF-shin" + side, "DEF-foot" + side, s.head("DEF-foot" + side), (0.0, 0.0, -1.0), 0.05))
        blends.append(("DEF-upper_arm" + side, "DEF-forearm" + side, s.head("DEF-forearm" + side), (sign, 0.0, 0.0), 0.06))
        blends.append(("DEF-forearm" + side, "DEF-hand" + side, s.head("DEF-hand" + side), (sign, 0.0, 0.0), 0.04))
    obj = b.to_object("PlayerEngineerMesh", s, blends)
    # Zainetto di terra come oggetto a parte, dopo il corpo (Godot prende il primo mesh come corpo).
    sack = build_pack_sack(s, pack_z)
    return s, obj, "PlayerEngineer", [sack]


# Nome dell'asset -> (costruttore, colore di vertice nell'export, cartella d'uscita). Il
# modello rifinito ha il colore nella texture cotta: il colore di vertice resterebbe e
# Godot lo moltiplicherebbe. L'ingegnere del gioco lo costruisce build_engineer.py (D-088):
# questi restano per confronto e finiscono fuori dal progetto Godot.
BEFORE_DIR = os.path.join(ROOT, "output", "engineer", "before")
ASSETS = {
    "player_engineer_d074": (build_player_engineer_refined, "NONE", BEFORE_DIR),
    "player_engineer_blocky": (build_player_engineer_blocky, "ACTIVE", BEFORE_DIR),
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not argv:
        print("Uso: ... build_character_assets.py -- player_engineer_d074|player_engineer_blocky "
              "(l'ingegnere del gioco: build_engineer.py)")
        return
    for name in argv:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        builder, vertex_color, out_dir = ASSETS[name]
        built = builder()
        skeleton, obj, root_name = built[0], built[1], built[2]
        extras = built[3] if len(built) > 3 else []
        export(skeleton, obj, name, root_name, vertex_color, extras, out_dir)


if __name__ == "__main__":
    main()
