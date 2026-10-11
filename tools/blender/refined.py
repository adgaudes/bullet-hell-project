"""Costruttore dei modelli rifiniti con texture cotta (D-071, D-072), condiviso da
build_character_assets.py (personaggi con scheletro) e build_actor_assets.py (attori
statici).

Ogni primitiva e un oggetto a se con smussi (Bevel) o forme arrotondate (Subdivision)
applicati; i pezzi vengono uniti in una mesh sola, con un gruppo di vertici per osso se
c'e uno scheletro. Il colore di base sta nell'attributo `Col` e serve solo alla cottura. La pittura e in
`painter.py` (restyling 2026-10-11): albedo dipinta (rampa per volume, pennellate, usura
sugli spigoli, occlusione, macchie, fango verso terra), normal map in spazio tangente e
ORM (occlusione, roughness, metallo), tutte a 2048 per default. Dopo la cottura i
materiali diventano Principled con le tre texture; il materiale della lampada e emissivo.

Materiali semantici: uno "vernice" (`suit` o `paint`, tinta dal codice di gioco via
`albedo_color`, quindi di base chiaro), `gear` (colori fissi), `lamp` (emissivo).
Con `bake_normal=True` (D-074) cuoce anche una **normal map** in spazio tangente da un
rilievo procedurale (trama del tessuto sulla vernice, grana e graffi sul resto), che
l'export glTF porta come `normalTexture`. `to_object(..., blends=[...])` sfuma i pesi
fra due ossa attorno a un'articolazione, cosi gomiti e ginocchia si piegano invece di
compenetrare.
Convenzioni: metri, Z-up in Blender; `front_axis` dice da che parte e il fronte per le
rastremazioni delle scatole (+1 = +Y, attori; -1 = -Y, personaggi).
"""

import math

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

import painter

BAKE_SIZE = 2048
BAKE_SAMPLES = 48


class RefinedBuilder:
    def __init__(self, paint_name="paint", front_axis=-1.0, bake_size=BAKE_SIZE, bake_normal=True, bake_orm=True):
        self.pieces = []
        self.materials = {}
        self.paint_name = paint_name
        self.front_axis = front_axis
        self.bake_size = bake_size
        self.bake_normal = bake_normal
        self.bake_orm = bake_orm
        for name in (paint_name, "gear", "lamp"):
            mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
            mat.use_nodes = True
            self.materials[name] = mat

    # -- primitive ------------------------------------------------------------------

    def _mesh_object(self, bm, bone, color, mat, rot, center):
        matrix = Matrix.Translation(Vector(center)) @ Euler(
            (math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2])), "XYZ").to_matrix().to_4x4()
        bmesh.ops.transform(bm, verts=bm.verts, matrix=matrix)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        col = bm.loops.layers.float_color.new("Col")
        for face in bm.faces:
            face.smooth = True
            for loop in face.loops:
                loop[col] = (color[0], color[1], color[2], 1.0)
        mesh = bpy.data.meshes.new("Piece")
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(self.materials[mat])
        obj = bpy.data.objects.new("Piece", mesh)
        bpy.context.collection.objects.link(obj)
        if bone is not None:
            group = obj.vertex_groups.new(name=bone)
            group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
        self.pieces.append(obj)
        return obj

    @staticmethod
    def _finish_piece(obj, bevel, segments, subsurf, sharp_deg):
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        if bevel > 0.0:
            mod = obj.modifiers.new("Bevel", "BEVEL")
            mod.width = bevel
            mod.segments = segments
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(30.0)
            mod.use_clamp_overlap = True
            bpy.ops.object.modifier_apply(modifier=mod.name)
        if subsurf > 0:
            mod = obj.modifiers.new("Subdivision", "SUBSURF")
            mod.levels = subsurf
            mod.render_levels = subsurf
            bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.ops.object.shade_smooth()
        if sharp_deg is not None:
            try:
                bpy.ops.object.shade_smooth_by_angle(angle=math.radians(sharp_deg))
            except (AttributeError, TypeError):
                pass

    def box(self, bone, size, center, color, mat="gear", rot=(0.0, 0.0, 0.0), bevel=0.02, segments=2,
            subsurf=0, sharp=40.0, top=(1.0, 1.0), bottom=(1.0, 1.0), front=(1.0, 1.0), back=(1.0, 1.0)):
        """Scatola smussata (`bevel`) o arrotondata (`subsurf`). `top`/`bottom` restringono
        (x, y) le facce alta e bassa; `front`/`back` restringono (x, z) quelle sul fronte e sul retro."""
        bm = bmesh.new()
        verts = bmesh.ops.create_cube(bm, size=1.0)["verts"]
        for v in verts:
            x, y, z = v.co.x, v.co.y, v.co.z
            tb = top if z > 0.0 else bottom
            fb = front if y * self.front_axis > 0.0 else back
            v.co = Vector((x * size[0] * tb[0] * fb[0], y * size[1] * tb[1], z * size[2] * fb[1]))
        obj = self._mesh_object(bm, bone, color, mat, rot, center)
        self._finish_piece(obj, min(bevel, min(size) * 0.45), segments, subsurf, None if subsurf else sharp)
        return obj

    def cyl(self, bone, radius, depth, center, color, mat="gear", axis="z", sides=12, radius_top=None,
            rot=(0.0, 0.0, 0.0), bevel=0.015, segments=2, sharp=40.0):
        bm = bmesh.new()
        verts = bmesh.ops.create_cone(
            bm, cap_ends=True, cap_tris=False, segments=sides, radius1=radius,
            radius2=radius if radius_top is None else radius_top, depth=depth)["verts"]
        if axis == "x":
            bmesh.ops.rotate(bm, verts=verts, matrix=Matrix.Rotation(math.radians(90.0), 3, "Y"))
        elif axis == "y":
            bmesh.ops.rotate(bm, verts=verts, matrix=Matrix.Rotation(math.radians(-90.0), 3, "X"))
        obj = self._mesh_object(bm, bone, color, mat, rot, center)
        self._finish_piece(obj, min(bevel, depth * 0.4, radius * 0.4), segments, 0, sharp)
        return obj

    def sphere(self, bone, radius, center, color, mat="gear", scale=(1.0, 1.0, 1.0), cut_below=None,
               rot=(0.0, 0.0, 0.0)):
        """Sfera liscia, facoltativamente schiacciata e tagliata sotto `cut_below` (locale)."""
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=radius)
        if cut_below is not None:
            below = [v for v in bm.verts if v.co.z < cut_below]
            bmesh.ops.delete(bm, geom=below, context="VERTS")
            rim = [e for e in bm.edges if e.is_boundary]
            if rim:
                bmesh.ops.holes_fill(bm, edges=rim)
        for v in bm.verts:
            v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
        obj = self._mesh_object(bm, bone, color, mat, rot, center)
        self._finish_piece(obj, 0.0, 1, 0, 60.0)
        return obj

    def profile(self, bone, points_yz, width, center, color, mat="gear", bevel=0.02, segments=2, sharp=40.0,
                rot=(0.0, 0.0, 0.0)):
        """Solido da un profilo chiuso nel piano YZ, estruso lungo X e centrato in x;
        `rot` (gradi) lo gira dopo, attorno al proprio centro."""
        bm = bmesh.new()
        left = [bm.verts.new((-width * 0.5, y, z)) for y, z in points_yz]
        right = [bm.verts.new((width * 0.5, y, z)) for y, z in points_yz]
        n = len(points_yz)
        faces = [bm.faces.new(left), bm.faces.new(right[::-1])]
        for i in range(n):
            j = (i + 1) % n
            faces.append(bm.faces.new((left[j], left[i], right[i], right[j])))
        bmesh.ops.recalc_face_normals(bm, faces=faces)
        obj = self._mesh_object(bm, bone, color, mat, rot, center)
        self._finish_piece(obj, min(bevel, width * 0.4), segments, 0, sharp)
        return obj

    # -- unione, UV, cottura -----------------------------------------------------------

    def to_object(self, name, skeleton=None, blends=None):
        """Unisce i pezzi, apre le UV, cuoce. `blends`: lista di
        (osso_a, osso_b, articolazione, direzione da a verso b, semi-banda in metri):
        i pesi dei vertici dei due ossi sfumano lungo la direzione attorno all'articolazione."""
        if skeleton is not None:
            for piece in self.pieces:
                for group in piece.vertex_groups:
                    if group.name not in skeleton.joints:
                        raise RuntimeError("Osso inesistente: %s" % group.name)
        bpy.ops.object.select_all(action="DESELECT")
        for piece in self.pieces:
            piece.select_set(True)
        bpy.context.view_layer.objects.active = self.pieces[0]
        bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        obj.name = name
        obj.data.name = name
        attribute = obj.data.color_attributes["Col"]
        obj.data.color_attributes.active_color = attribute
        obj.data.color_attributes.render_color_index = obj.data.color_attributes.find("Col")
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.008)
        bpy.ops.object.mode_set(mode="OBJECT")
        self._bake(obj, name)
        if skeleton is not None:
            for blend in blends or ():
                self._blend_weights(obj, *blend)
            obj.parent = skeleton.obj
            obj.modifiers.new("Armature", "ARMATURE").object = skeleton.obj
        return obj

    @staticmethod
    def _blend_weights(obj, bone_a, bone_b, joint, direction, band):
        """Peso sfumato fra due ossa: a 0 oltre `band` dalla parte di a, 1 oltre `band`
        dalla parte di b, lineare in mezzo. Tocca solo i vertici che appartengono a uno dei due."""
        group_a = obj.vertex_groups.get(bone_a)
        group_b = obj.vertex_groups.get(bone_b)
        if group_a is None or group_b is None:
            return
        joint = Vector(joint)
        direction = Vector(direction).normalized()
        indexes = {group_a.index, group_b.index}
        for v in obj.data.vertices:
            if not any(g.group in indexes for g in v.groups):
                continue
            t = (direction.dot(v.co - joint) + band) / (2.0 * band)
            t = max(0.0, min(1.0, t))
            group_a.add([v.index], 1.0 - t, "REPLACE")
            group_b.add([v.index], t, "REPLACE")

    def _bake(self, obj, name):
        scene = bpy.context.scene
        scene.render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        scene.render.bake.margin = 12
        scene.render.bake.use_clear = True
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj

        def bake_pass(suffix, colorspace, graph, bake_type, samples):
            image = bpy.data.images.new(name + suffix, self.bake_size, self.bake_size)
            image.colorspace_settings.name = colorspace
            for mat_name, mat in self.materials.items():
                graph(mat, image, self._kind(mat_name))
            scene.cycles.samples = samples
            bpy.ops.object.bake(type=bake_type)
            image.pack()
            return image

        albedo = bake_pass("_albedo", "sRGB", painter.paint_albedo_graph, "EMIT", BAKE_SAMPLES)
        normal = None
        if self.bake_normal:
            scene.render.bake.normal_space = "TANGENT"
            normal = bake_pass("_normal", "Non-Color", painter.paint_normal_graph, "NORMAL", 4)
        orm = None
        if self.bake_orm:
            orm = bake_pass("_orm", "Non-Color", painter.paint_orm_graph, "EMIT", 16)
        for mat_name, mat in self.materials.items():
            painter.final_graph(mat, albedo, normal, orm, self._kind(mat_name))
        print("BAKED %s %dx%d samples=%d normal=%s orm=%s" % (albedo.name, self.bake_size, self.bake_size,
                                                             BAKE_SAMPLES, normal is not None, orm is not None))

    def _kind(self, mat_name):
        return "paint" if mat_name == self.paint_name else mat_name


class StaticBuilder(RefinedBuilder):
    """Stesse primitive senza osso, per gli attori statici. `paint=True` manda il pezzo
    sul materiale "vernice", `emit=True` su `lamp`, come nel vecchio Builder."""

    def __init__(self, bake_size=BAKE_SIZE, bake_normal=True, bake_orm=True):
        super().__init__(paint_name="paint", front_axis=1.0, bake_size=bake_size,
                         bake_normal=bake_normal, bake_orm=bake_orm)

    def _mat(self, mat, paint, emit):
        if emit:
            return "lamp"
        if paint:
            return "paint"
        return "gear" if mat == "detail" else mat

    def box(self, size, center, color, mat="detail", paint=False, emit=False, **kwargs):
        return super().box(None, size, center, color, self._mat(mat, paint, emit), **kwargs)

    def cyl(self, radius, depth, center, color, mat="detail", paint=False, emit=False, **kwargs):
        return super().cyl(None, radius, depth, center, color, self._mat(mat, paint, emit), **kwargs)

    def sphere(self, radius, center, color, mat="detail", paint=False, emit=False, **kwargs):
        return super().sphere(None, radius, center, color, self._mat(mat, paint, emit), **kwargs)

    def profile(self, points_yz, width, center, color, mat="detail", paint=False, emit=False, **kwargs):
        return super().profile(None, points_yz, width, center, color, self._mat(mat, paint, emit), **kwargs)
