"""Modellazione a gabbia per i personaggi organici (restyling dell'Ingegnere, D-088).

Il metodo di un modellatore di personaggi stilizzati, scritto in codice: forme a
quadrilateri (corpo da un grafo con il modificatore Skin, teste, ciocche e tubi per
sezioni ellittiche), superfici di suddivisione, abiti estratti dalle facce del corpo con
spessore vero, e "pennelli" che spostano i vertici con caduta morbida (tira, gonfia,
incide, piega). Tutto deterministico: stessa chiamata, stessa mesh.

Convenzioni: metri, Z in alto; coordinate oggetto = mondo (gli oggetti non vengono mai
ruotati o scalati); colore per angolo nell'attributo `Col` (lo legge il pittore).
"""
import math

import bmesh
import bpy
from mathutils import Vector, noise


def _link(obj):
    bpy.context.collection.objects.link(obj)
    return obj


def _activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def _apply(obj, modifier):
    _activate(obj)
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def _falloff(distance, radius):
    t = max(0.0, 1.0 - distance / radius)
    return t * t * (3.0 - 2.0 * t)


def _scaled_distance(co, center, scale):
    d = co - Vector(center)
    return Vector((d.x / scale[0], d.y / scale[1], d.z / scale[2])).length


# -- forme ---------------------------------------------------------------------------


def skin_body(name, nodes, edges, root=0, smooth=0.5):
    """Corpo da un grafo: ogni nodo ha posizione e raggio (uniforme o (rx, ry)), ogni
    arco diventa un tubo; il modificatore Skin cuce rami e giunture a quadrilateri.
    Trappola: due nodi vicini con raggi piu grandi della loro distanza (pancia sopra il
    bacino) fanno compenetrare gli involucri e lasciano buchi e facce interne."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([Vector(p) for p, _r in nodes], [tuple(e) for e in edges], [])
    obj = _link(bpy.data.objects.new(name, mesh))
    modifier = obj.modifiers.new("Skin", "SKIN")
    modifier.branch_smoothing = smooth
    modifier.use_x_symmetry = True
    for index, (_p, radius) in enumerate(nodes):
        rx, ry = (radius, radius) if isinstance(radius, (int, float)) else radius
        skin = mesh.skin_vertices[0].data[index]
        skin.radius = (rx, ry)
        skin.use_root = index == root
    _apply(obj, modifier)
    return obj


class Ring:
    """Sezione ellittica: `rx`/`ry` sono i semiassi nel piano perpendicolare ad `axis`
    (asse z: X e Y; asse x: Y e Z; asse y: X e Z; una direzione qualsiasi: `rx` sul
    vettore orizzontale perpendicolare, `ry` sul terzo); `scale` deforma raggio per raggio."""

    def __init__(self, center, rx, ry, axis="z", sides=12, scale=None):
        self.center = Vector(center)
        self.rx, self.ry, self.axis, self.sides = rx, ry, axis, sides
        self.scale = scale or [1.0] * sides

    def _frame(self):
        named = {"z": (Vector((1, 0, 0)), Vector((0, 1, 0))), "x": (Vector((0, 1, 0)), Vector((0, 0, 1))),
                 "y": (Vector((1, 0, 0)), Vector((0, 0, 1)))}
        if isinstance(self.axis, str):
            return named[self.axis]
        direction = Vector(self.axis).normalized()
        up = Vector((0, 0, 1)) if abs(direction.z) < 0.95 else Vector((0, 1, 0))
        first = up.cross(direction).normalized()
        return first, direction.cross(first).normalized()

    def points(self):
        first, second = self._frame()
        result = []
        for i in range(self.sides):
            a = 2.0 * math.pi * i / self.sides
            u, v = math.cos(a) * self.rx * self.scale[i], math.sin(a) * self.ry * self.scale[i]
            result.append(self.center + first * u + second * v)
        return result


def loft(name, rings, cap_start=True, cap_end=True):
    """Tubo a quadrilateri attraverso gli anelli; le chiusure sono ventagli su un polo
    al centro dell'anello estremo (la suddivisione li arrotonda)."""
    sides = rings[0].sides
    if any(r.sides != sides for r in rings):
        raise ValueError("loft: anelli con numero di lati diverso")
    bm = bmesh.new()
    loops = [[bm.verts.new(p) for p in ring.points()] for ring in rings]
    for a, b in zip(loops, loops[1:]):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((a[i], a[j], b[j], b[i]))
    for loop, ring, wanted in ((loops[0], rings[0], cap_start), (loops[-1], rings[-1], cap_end)):
        if not wanted:
            continue
        pole = bm.verts.new(ring.center)
        for i in range(sides):
            bm.faces.new((loop[i], loop[(i + 1) % sides], pole))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return _link(bpy.data.objects.new(name, mesh))


def tube(name, points, radii, sides=10, cap_start=True, cap_end=True):
    """Tubo lungo una polilinea (maniche annodate, cavi, cinghie morbide): un anello per
    punto, perpendicolare alla direzione media dei due tratti vicini."""
    pts = [Vector(p) for p in points]
    rings = []
    for i, p in enumerate(pts):
        before = pts[i] - pts[i - 1] if i > 0 else pts[1] - pts[0]
        after = pts[i + 1] - pts[i] if i + 1 < len(pts) else pts[-1] - pts[-2]
        direction = before.normalized() + after.normalized()
        radius = radii[i]
        rx, ry = (radius, radius) if isinstance(radius, (int, float)) else radius
        rings.append(Ring(p, rx, ry, axis=tuple(direction), sides=sides))
    return loft(name, rings, cap_start, cap_end)


def extract_shell(source, name, keep, offset, thickness):
    """Abito tagliato dal corpo: copia le facce il cui centro soddisfa `keep`, le spinge
    fuori di `offset` lungo la normale e le chiude con uno spessore `thickness`."""
    bm = bmesh.new()
    bm.from_mesh(source.data)
    drop = [f for f in bm.faces if not keep(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * offset
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = _link(bpy.data.objects.new(name, mesh))
    modifier = obj.modifiers.new("Solidify", "SOLIDIFY")
    modifier.thickness = thickness
    modifier.offset = 1.0
    modifier.use_rim = True
    _apply(obj, modifier)
    return obj


def subdivide(obj, levels):
    modifier = obj.modifiers.new("Subdivision", "SUBSURF")
    modifier.levels = levels
    modifier.render_levels = levels
    modifier.uv_smooth = "PRESERVE_CORNERS"
    _apply(obj, modifier)
    _activate(obj)
    bpy.ops.object.shade_smooth()
    return obj


# -- colore --------------------------------------------------------------------------


def _colors(obj):
    attribute = obj.data.color_attributes.get("Col")
    if attribute is None:
        attribute = obj.data.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    obj.data.color_attributes.active_color = attribute
    return attribute


def set_color(obj, color):
    for item in _colors(obj).data:
        item.color = (color[0], color[1], color[2], 1.0)


def tint(obj, center, radius, color, strength, scale=(1.0, 1.0, 1.0)):
    """Sfuma il colore verso `color` vicino a `center` (guance, naso, macchie)."""
    data = _colors(obj).data
    mesh = obj.data
    for loop in mesh.loops:
        w = _falloff(_scaled_distance(mesh.vertices[loop.vertex_index].co, center, scale), radius) * strength
        if w <= 0.0:
            continue
        old = data[loop.index].color
        data[loop.index].color = (old[0] + (color[0] - old[0]) * w, old[1] + (color[1] - old[1]) * w,
                                  old[2] + (color[2] - old[2]) * w, 1.0)


# -- pennelli ------------------------------------------------------------------------


def grab(obj, center, radius, offset, scale=(1.0, 1.0, 1.0)):
    """Sposta di `offset` i vertici attorno a `center` (caduta ellissoidale)."""
    offset = Vector(offset)
    for v in obj.data.vertices:
        w = _falloff(_scaled_distance(v.co, center, scale), radius)
        if w > 0.0:
            v.co += offset * w
    obj.data.update()


def inflate(obj, center, radius, amount, scale=(1.0, 1.0, 1.0)):
    """Gonfia (amount > 0) o sgonfia lungo la normale attorno a `center`."""
    obj.data.update()
    for v in obj.data.vertices:
        w = _falloff(_scaled_distance(v.co, center, scale), radius)
        if w > 0.0:
            v.co += v.normal * amount * w
    obj.data.update()


def _segment_distance(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
    return (p - (a + ab * t)).length


def crease_line(obj, points, radius, depth):
    """Incide un solco lungo la polilinea (cuciture, rughe, divisione delle dita e delle ciocche)."""
    pts = [Vector(p) for p in points]
    obj.data.update()
    for v in obj.data.vertices:
        d = min(_segment_distance(v.co, a, b) for a, b in zip(pts, pts[1:]))
        w = _falloff(d, radius)
        if w > 0.0:
            v.co -= v.normal * depth * w
    obj.data.update()


def fold_noise(obj, keep, amplitude, frequency, seed=0):
    """Pieghe morbide lungo la normale dove `keep(co)` e vero (stoffa, pelle)."""
    obj.data.update()
    shift = Vector((seed * 17.31, seed * 5.77, seed * 11.13))
    for v in obj.data.vertices:
        if keep(v.co):
            v.co += v.normal * amplitude * noise.noise(v.co * frequency + shift)
    obj.data.update()


def flatten_below(obj, z):
    """Porta sul piano `z` i vertici che ci stanno sotto (suole degli stivali a terra)."""
    for v in obj.data.vertices:
        if v.co.z < z:
            v.co.z = z
    obj.data.update()


# -- utilita -------------------------------------------------------------------------


def assign_material(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)


def mesh_stats(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    stats = dict(tris=sum(len(f.verts) - 2 for f in bm.faces),
                 boundary_edges=sum(1 for e in bm.edges if e.is_boundary),
                 verts=len(bm.verts))
    bm.free()
    return stats
