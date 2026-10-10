"""Costruttore dei modelli rifiniti con texture cotta (D-071, D-072), condiviso da
build_character_assets.py (personaggi con scheletro) e build_actor_assets.py (attori
statici).

Ogni primitiva e un oggetto a se con smussi (Bevel) o forme arrotondate (Subdivision)
applicati; i pezzi vengono uniti in una mesh sola, con un gruppo di vertici per osso se
c'e uno scheletro. Il colore di base sta nell'attributo `Col` e serve solo alla cottura:
la texture cotta (Cycles, bake `EMIT`) porta colore, usura degli spigoli (pointiness),
occlusione, grana, macchie e fango verso terra. Dopo la cottura i materiali diventano
Principled con la texture; il materiale della lampada e emissivo.

Materiali semantici: uno "vernice" (`suit` o `paint`, tinta dal codice di gioco via
`albedo_color`, quindi di base chiaro), `gear` (colori fissi), `lamp` (emissivo).
Convenzioni: metri, Z-up in Blender; `front_axis` dice da che parte e il fronte per le
rastremazioni delle scatole (+1 = +Y, attori; -1 = -Y, personaggi).
"""

import math

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

BAKE_SIZE = 1024
BAKE_SAMPLES = 48


def sock(sockets, identifier):
    """Presa di un nodo per identificatore (i nodi Mix hanno piu prese con lo stesso nome)."""
    for socket in sockets:
        if socket.identifier == identifier:
            return socket
    raise KeyError(identifier)


class RefinedBuilder:
    def __init__(self, paint_name="paint", front_axis=-1.0, bake_size=BAKE_SIZE):
        self.pieces = []
        self.materials = {}
        self.paint_name = paint_name
        self.front_axis = front_axis
        self.bake_size = bake_size
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

    def to_object(self, name, skeleton=None):
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
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.004)
        bpy.ops.object.mode_set(mode="OBJECT")
        self._bake(obj, name)
        if skeleton is not None:
            obj.parent = skeleton.obj
            obj.modifiers.new("Armature", "ARMATURE").object = skeleton.obj
        return obj

    def _bake(self, obj, name):
        image = bpy.data.images.new(name + "_albedo", self.bake_size, self.bake_size)
        image.colorspace_settings.name = "sRGB"
        for mat_name, mat in self.materials.items():
            self._bake_graph(mat, image, self._kind(mat_name))
        scene = bpy.context.scene
        scene.render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        scene.cycles.samples = BAKE_SAMPLES
        scene.render.bake.margin = 6
        scene.render.bake.use_clear = True
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.bake(type="EMIT")
        image.pack()
        for mat_name, mat in self.materials.items():
            self._final_graph(mat, image, self._kind(mat_name))
        print("BAKED %s %dx%d samples=%d" % (image.name, self.bake_size, self.bake_size, BAKE_SAMPLES))

    def _kind(self, mat_name):
        return "paint" if mat_name == self.paint_name else mat_name

    @staticmethod
    def _bake_graph(mat, image, kind):
        tree = mat.node_tree
        tree.nodes.clear()
        nodes, links = tree.nodes, tree.links
        out = nodes.new("ShaderNodeOutputMaterial")
        emit = nodes.new("ShaderNodeEmission")
        links.new(emit.outputs["Emission"], out.inputs["Surface"])
        col = nodes.new("ShaderNodeAttribute")
        col.attribute_name = "Col"
        # Usura degli spigoli: la curvatura (pointiness) schiarisce i bordi.
        geo = nodes.new("ShaderNodeNewGeometry")
        wear_ramp = nodes.new("ShaderNodeValToRGB")
        wear_ramp.color_ramp.elements[0].position = 0.5
        wear_ramp.color_ramp.elements[0].color = (1.0, 1.0, 1.0, 1.0)
        wear_ramp.color_ramp.elements[1].position = 0.62
        wear_ramp.color_ramp.elements[1].color = (1.35, 1.3, 1.2, 1.0)
        links.new(geo.outputs["Pointiness"], wear_ramp.inputs["Fac"])
        # Occlusione: scurisce gli incavi.
        ao = nodes.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = 0.18
        ao.samples = 8
        ao_ramp = nodes.new("ShaderNodeValToRGB")
        ao_ramp.color_ramp.elements[0].position = 0.3
        ao_ramp.color_ramp.elements[0].color = (0.55, 0.52, 0.5, 1.0)
        ao_ramp.color_ramp.elements[1].position = 0.95
        ao_ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)
        links.new(ao.outputs["AO"], ao_ramp.inputs["Fac"])
        # Grana e sporco: rumore fine e macchie larghe; piu sporco verso terra.
        coords = nodes.new("ShaderNodeTexCoord")
        grain = nodes.new("ShaderNodeTexNoise")
        grain.inputs["Scale"].default_value = 40.0 if kind == "paint" else 25.0
        grain.inputs["Detail"].default_value = 4.0
        grain_ramp = nodes.new("ShaderNodeValToRGB")
        grain_ramp.color_ramp.elements[0].position = 0.3
        grain_ramp.color_ramp.elements[0].color = (0.86, 0.85, 0.84, 1.0)
        grain_ramp.color_ramp.elements[1].position = 0.7
        grain_ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)
        links.new(coords.outputs["Object"], grain.inputs["Vector"])
        links.new(grain.outputs["Fac"], grain_ramp.inputs["Fac"])
        stains = nodes.new("ShaderNodeTexNoise")
        stains.inputs["Scale"].default_value = 6.0
        stains.inputs["Detail"].default_value = 3.0
        stains_ramp = nodes.new("ShaderNodeValToRGB")
        stains_ramp.color_ramp.elements[0].position = 0.42
        stains_ramp.color_ramp.elements[0].color = (0.62, 0.55, 0.46, 1.0)
        stains_ramp.color_ramp.elements[1].position = 0.55
        stains_ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)
        links.new(coords.outputs["Object"], stains.inputs["Vector"])
        links.new(stains.outputs["Fac"], stains_ramp.inputs["Fac"])
        height = nodes.new("ShaderNodeSeparateXYZ")
        links.new(coords.outputs["Object"], height.inputs["Vector"])
        mud = nodes.new("ShaderNodeMapRange")
        mud.inputs["From Min"].default_value = 0.05
        mud.inputs["From Max"].default_value = 0.6
        mud.inputs["To Min"].default_value = 0.0
        mud.inputs["To Max"].default_value = 1.0
        links.new(height.outputs["Z"], mud.inputs["Value"])
        mud_mix = nodes.new("ShaderNodeMix")
        mud_mix.data_type = "RGBA"
        sock(mud_mix.inputs, "A_Color").default_value = (0.45, 0.33, 0.2, 1.0)
        links.new(mud.outputs["Result"], sock(mud_mix.inputs, "Factor_Float"))

        def multiply(a, b):
            node = nodes.new("ShaderNodeMix")
            node.data_type = "RGBA"
            node.blend_type = "MULTIPLY"
            sock(node.inputs, "Factor_Float").default_value = 1.0
            links.new(a, sock(node.inputs, "A_Color"))
            links.new(b, sock(node.inputs, "B_Color"))
            return sock(node.outputs, "Result_Color")

        # Le lampade restano piatte e piene: niente occlusione ne grana, o incassate
        # in una cornice si spengono (gli occhi dell'orda di notte).
        shaded = col.outputs["Color"]
        if kind != "lamp":
            shaded = multiply(shaded, wear_ramp.outputs["Color"])
            shaded = multiply(shaded, ao_ramp.outputs["Color"])
            shaded = multiply(shaded, grain_ramp.outputs["Color"])
            shaded = multiply(shaded, stains_ramp.outputs["Color"])
            links.new(shaded, sock(mud_mix.inputs, "B_Color"))
            shaded = sock(mud_mix.outputs, "Result_Color")
        links.new(shaded, emit.inputs["Color"])
        target = nodes.new("ShaderNodeTexImage")
        target.image = image
        nodes.active = target

    @staticmethod
    def _final_graph(mat, image, kind):
        tree = mat.node_tree
        tree.nodes.clear()
        nodes, links = tree.nodes, tree.links
        out = nodes.new("ShaderNodeOutputMaterial")
        shader = nodes.new("ShaderNodeBsdfPrincipled")
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        links.new(tex.outputs["Color"], shader.inputs["Base Color"])
        shader.inputs["Roughness"].default_value = {"paint": 0.75, "gear": 0.65, "lamp": 0.4}[kind]
        if kind == "lamp":
            links.new(tex.outputs["Color"], shader.inputs["Emission Color"])
            shader.inputs["Emission Strength"].default_value = 3.0
        links.new(shader.outputs["BSDF"], out.inputs["Surface"])


class StaticBuilder(RefinedBuilder):
    """Stesse primitive senza osso, per gli attori statici. `paint=True` manda il pezzo
    sul materiale "vernice", `emit=True` su `lamp`, come nel vecchio Builder."""

    def __init__(self, bake_size=BAKE_SIZE):
        super().__init__(paint_name="paint", front_axis=1.0, bake_size=bake_size)

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
