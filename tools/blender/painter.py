"""Pittore condiviso del restyling (spec 2026-10-11, §3.1): grafi Cycles che cuociono, per
ogni materiale semantico, tre texture: **albedo dipinta**, **normal map** in spazio tangente
e **ORM** (R occlusione, G roughness, B metallo).

Tutto e procedurale e parametrico, niente foto: rampa di colore per volume (chiaro in
alto, scuro e saturo nelle cavita), pennellate direzionali a bassa frequenza, usura sugli
spigoli con bordo netto e colore proprio del materiale, occlusione dipinta, macchie, sporco
verso terra. `seamless_coords` mappa le UV su un toro dentro il rumore 4D: una tile cotta
su un piano con quelle coordinate si ripete senza cuciture (usato da build_surface_tiles).

Convenzioni: i grafi di cottura terminano con un nodo immagine attivo (il bersaglio del
bake); `final_graph` ricostruisce il Principled che l'export glTF legge (albedo, normal,
metallicRoughness dall'ORM e occlusione tramite il gruppo "glTF Material Output").
"""
import math

import bpy

TWO_PI = 2.0 * math.pi

# Parametri di pittura per materiale semantico.
#   brush_scale/brush_dir: pennellate (0 = nessuna); edge_color: colore dell'usura sugli
#   spigoli; rough_base/rough_wear: roughness della superficie intatta e consumata;
#   metal: metallo; gradient_top/bottom: rampa di luminosita per volume.
STYLES = {
    "paint": dict(brush_scale=14.0, brush_dir=(1.0, 0.25), edge_color=(0.92, 0.88, 0.80),
                  rough_base=0.72, rough_wear=0.45, metal=0.0, gradient_top=1.12, gradient_bottom=0.78),
    "gear": dict(brush_scale=22.0, brush_dir=(0.3, 1.0), edge_color=(0.85, 0.82, 0.78),
                 rough_base=0.55, rough_wear=0.30, metal=0.35, gradient_top=1.08, gradient_bottom=0.82),
    "lamp": dict(brush_scale=0.0, brush_dir=(1.0, 0.0), edge_color=(1.0, 1.0, 1.0),
                 rough_base=0.4, rough_wear=0.4, metal=0.0, gradient_top=1.0, gradient_bottom=1.0),
    # Opaco e mai metallico: corteccia, legno, gomma, pietra.
    "matte": dict(brush_scale=18.0, brush_dir=(0.0, 1.0), edge_color=(0.80, 0.74, 0.66),
                  rough_base=0.9, rough_wear=0.75, metal=0.0, gradient_top=1.08, gradient_bottom=0.80),
    "tile": dict(brush_scale=10.0, brush_dir=(1.0, 0.0), edge_color=(0.9, 0.86, 0.8),
                 rough_base=0.85, rough_wear=0.6, metal=0.0, gradient_top=1.0, gradient_bottom=1.0),
}

MUD_COLOR = (0.40, 0.30, 0.19)


def sock(sockets, identifier):
    """Presa di un nodo per identificatore (i nodi Mix hanno piu prese con lo stesso nome)."""
    for socket in sockets:
        if socket.identifier == identifier:
            return socket
    raise KeyError(identifier)


# -- nodi di base -----------------------------------------------------------------------


def mix(nodes, links, a, b, factor, blend="MIX"):
    """Mix RGBA. `a`/`b` sono prese o tuple RGB; `factor` una presa o un float."""
    node = nodes.new("ShaderNodeMix")
    node.data_type = "RGBA"
    node.blend_type = blend
    if isinstance(factor, (int, float)):
        sock(node.inputs, "Factor_Float").default_value = float(factor)
    else:
        links.new(factor, sock(node.inputs, "Factor_Float"))
    for key, value in (("A_Color", a), ("B_Color", b)):
        if isinstance(value, tuple):
            sock(node.inputs, key).default_value = (*value, 1.0)
        else:
            links.new(value, sock(node.inputs, key))
    return sock(node.outputs, "Result_Color")


def ramp(nodes, links, value, stops):
    """Rampa di colore. `stops`: lista di (posizione, (r, g, b)), almeno due."""
    node = nodes.new("ShaderNodeValToRGB")
    elements = node.color_ramp.elements
    elements[0].position = stops[0][0]
    elements[0].color = (*stops[0][1], 1.0)
    elements[1].position = stops[-1][0]
    elements[1].color = (*stops[-1][1], 1.0)
    for position, color in stops[1:-1]:
        element = elements.new(position)
        element.color = (*color, 1.0)
    links.new(value, node.inputs["Fac"])
    return node.outputs["Color"]


def math_node(nodes, links, operation, a, b=None, c=None):
    """Nodo Math: ogni argomento e una presa o un float."""
    node = nodes.new("ShaderNodeMath")
    node.operation = operation
    for index, value in enumerate((a, b, c)):
        if value is None:
            continue
        if isinstance(value, (int, float)):
            node.inputs[index].default_value = float(value)
        else:
            links.new(value, node.inputs[index])
    return node.outputs["Value"]


def seamless_coords(nodes, links, radius=0.35):
    """UV (u, v) -> (vettore 3D, W) su un toro: il rumore 4D letto qui si ripete in u e v."""
    uv = nodes.new("ShaderNodeTexCoord").outputs["UV"]
    separate = nodes.new("ShaderNodeSeparateXYZ")
    links.new(uv, separate.inputs["Vector"])
    u = math_node(nodes, links, "MULTIPLY", separate.outputs["X"], TWO_PI)
    v = math_node(nodes, links, "MULTIPLY", separate.outputs["Y"], TWO_PI)
    cos_u = math_node(nodes, links, "MULTIPLY", math_node(nodes, links, "COSINE", u), radius)
    sin_u = math_node(nodes, links, "MULTIPLY", math_node(nodes, links, "SINE", u), radius)
    cos_v = math_node(nodes, links, "MULTIPLY", math_node(nodes, links, "COSINE", v), radius)
    sin_v = math_node(nodes, links, "MULTIPLY", math_node(nodes, links, "SINE", v), radius)
    combine = nodes.new("ShaderNodeCombineXYZ")
    links.new(cos_u, combine.inputs["X"])
    links.new(sin_u, combine.inputs["Y"])
    links.new(cos_v, combine.inputs["Z"])
    return combine.outputs["Vector"], sin_v


def noise(nodes, links, coords, scale, detail=3.0, roughness=0.5, w=None):
    """Rumore 3D sulle `coords`, o 4D se c'e `w` (coordinate toroidali)."""
    node = nodes.new("ShaderNodeTexNoise")
    node.noise_dimensions = "4D" if w is not None else "3D"
    node.inputs["Scale"].default_value = scale
    node.inputs["Detail"].default_value = detail
    node.inputs["Roughness"].default_value = roughness
    links.new(coords, node.inputs["Vector"])
    if w is not None:
        links.new(w, node.inputs["W"])
    return node.outputs["Fac"]


def brush(nodes, links, coords, style, w=None):
    """Pennellate direzionali: rumore allungato lungo `brush_dir`, a bassa frequenza.
    Restituisce un colore moltiplicativo attorno a 1, o None se lo stile non ne ha."""
    if style["brush_scale"] <= 0.0:
        return None
    mapping = nodes.new("ShaderNodeMapping")
    dx, dy = style["brush_dir"]
    mapping.inputs["Rotation"].default_value = (0.0, 0.0, math.atan2(dy, dx))
    mapping.inputs["Scale"].default_value = (1.0, 6.0, 1.0)
    links.new(coords, mapping.inputs["Vector"])
    fac = noise(nodes, links, mapping.outputs["Vector"], style["brush_scale"], 2.0, 0.4, w)
    return ramp(nodes, links, fac, [(0.35, (0.90, 0.90, 0.90)), (0.65, (1.06, 1.06, 1.06))])


def edge_wear(nodes, links):
    """Maschera 0..1 degli spigoli convessi (pointiness), con bordo netto. La soglia e
    alta: un cilindro liscio a pochi lati ha pointiness 0,55-0,62 su tutta la superficie
    e non deve risultare consumato ovunque (il tronco dell'albero usciva beige)."""
    geometry = nodes.new("ShaderNodeNewGeometry")
    return ramp(nodes, links, geometry.outputs["Pointiness"], [(0.64, (0.0, 0.0, 0.0)), (0.74, (1.0, 1.0, 1.0))])


def ambient_occlusion(nodes, links, distance=0.22):
    node = nodes.new("ShaderNodeAmbientOcclusion")
    node.inputs["Distance"].default_value = distance
    node.samples = 8
    return node.outputs["AO"]


def _bake_target(nodes, image):
    target = nodes.new("ShaderNodeTexImage")
    target.image = image
    nodes.active = target


def _begin_emit_graph(mat):
    tree = mat.node_tree
    tree.nodes.clear()
    nodes, links = tree.nodes, tree.links
    out = nodes.new("ShaderNodeOutputMaterial")
    emit = nodes.new("ShaderNodeEmission")
    links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return nodes, links, emit


# -- grafi di cottura -------------------------------------------------------------------


def _coords(nodes, links, coords_fn):
    """Coordinate del rumore: oggetto (modelli) o quelle di `coords_fn` (tile toroidali).
    Restituisce (coords, w, tiled)."""
    if coords_fn is None:
        return nodes.new("ShaderNodeTexCoord").outputs["Object"], None, False
    coords, w = coords_fn(nodes, links)
    return coords, w, True


def paint_albedo_graph(mat, image, kind, style=None, coords_fn=None):
    """Albedo dipinta. Senza `coords_fn` usa le coordinate oggetto (modelli: origine a
    terra, quindi il fango sale da Z = 0); con `coords_fn` toroidale (tile) niente fango,
    niente rampa per volume, niente occlusione geometrica."""
    style = style or STYLES[kind]
    nodes, links, emit = _begin_emit_graph(mat)
    base = nodes.new("ShaderNodeAttribute")
    base.attribute_name = "Col"
    color = base.outputs["Color"]
    coords, w, tiled = _coords(nodes, links, coords_fn)
    if kind != "lamp":
        separate = nodes.new("ShaderNodeSeparateXYZ")
        links.new(coords, separate.inputs["Vector"])
        if not tiled:
            # Rampa per volume: piu chiaro in alto, piu scuro e saturo in basso.
            height = math_node(nodes, links, "MULTIPLY", separate.outputs["Z"], 0.5)
            gradient = ramp(nodes, links, height, [(0.0, (style["gradient_bottom"],) * 3),
                                                   (1.0, (style["gradient_top"],) * 3)])
            color = mix(nodes, links, color, gradient, 1.0, "MULTIPLY")
        strokes = brush(nodes, links, coords, style, w)
        if strokes is not None:
            color = mix(nodes, links, color, strokes, 1.0, "MULTIPLY")
        if not tiled:
            occlusion = ramp(nodes, links, ambient_occlusion(nodes, links),
                             [(0.3, (0.55, 0.50, 0.52)), (0.95, (1.0, 1.0, 1.0))])
            color = mix(nodes, links, color, occlusion, 1.0, "MULTIPLY")
        stains = ramp(nodes, links, noise(nodes, links, coords, 5.0, 3.0, 0.6, w),
                      [(0.42, (0.66, 0.58, 0.48)), (0.55, (1.0, 1.0, 1.0))])
        color = mix(nodes, links, color, stains, 1.0, "MULTIPLY")
        if not tiled:
            # Usura sugli spigoli con il colore proprio del materiale (bordo netto, non grana).
            wear = math_node(nodes, links, "MULTIPLY", edge_wear(nodes, links), 0.8)
            color = mix(nodes, links, color, style["edge_color"], wear)
            # Sporco verso terra: fattore 0 (fango) vicino a Z = 0, 1 oltre 0,6 m.
            mud = nodes.new("ShaderNodeMapRange")
            mud.inputs["From Min"].default_value = 0.05
            mud.inputs["From Max"].default_value = 0.6
            links.new(separate.outputs["Z"], mud.inputs["Value"])
            color = mix(nodes, links, MUD_COLOR, color, mud.outputs["Result"])
    links.new(color, emit.inputs["Color"])
    _bake_target(nodes, image)


def paint_orm_graph(mat, image, kind, style=None, coords_fn=None):
    """ORM: R = occlusione, G = roughness (base, piu bassa dove consumato), B = metallo.
    Sulle tile (coords toroidali) l'occlusione e piatta e la roughness varia col rumore."""
    style = style or STYLES[kind]
    nodes, links, emit = _begin_emit_graph(mat)
    coords, w, tiled = _coords(nodes, links, coords_fn)
    if kind == "lamp" or tiled:
        occlusion = math_node(nodes, links, "ADD", 1.0, 0.0)
    else:
        occlusion = ambient_occlusion(nodes, links)
    if tiled:
        wear = noise(nodes, links, coords, 7.0, 3.0, 0.5, w)
    else:
        wear = edge_wear(nodes, links)
    # roughness = wear * (rough_wear - rough_base) + rough_base
    rough = math_node(nodes, links, "MULTIPLY_ADD", wear, style["rough_wear"] - style["rough_base"], style["rough_base"])
    metal = math_node(nodes, links, "ADD", style["metal"], 0.0)
    combine = nodes.new("ShaderNodeCombineColor")
    links.new(occlusion, combine.inputs["Red"])
    links.new(rough, combine.inputs["Green"])
    links.new(metal, combine.inputs["Blue"])
    links.new(combine.outputs["Color"], emit.inputs["Color"])
    _bake_target(nodes, image)


def paint_normal_graph(mat, image, kind, style=None, coords_fn=None):
    """Rilievo procedurale (Bump su un BSDF: Emission non ha una presa Normal) per la
    normal map in spazio tangente. Vernice: trama fine piu pieghe larghe; gear: grana e
    graffi; tile: rilievo piu marcato; lamp: piatta."""
    tree = mat.node_tree
    tree.nodes.clear()
    nodes, links = tree.nodes, tree.links
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfDiffuse")
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    if kind != "lamp":
        coords, w, _tiled = _coords(nodes, links, coords_fn)
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Distance"].default_value = 0.002
        if kind == "paint":
            height = math_node(nodes, links, "ADD",
                               noise(nodes, links, coords, 160.0, 1.0, 0.5, w),
                               noise(nodes, links, coords, 9.0, 2.0, 0.5, w))
            bump.inputs["Strength"].default_value = 0.35
        else:
            height = math_node(nodes, links, "MULTIPLY_ADD",
                               noise(nodes, links, coords, 40.0, 3.0, 0.6, w), 0.25,
                               noise(nodes, links, coords, 70.0, 5.0, 0.5, w))
            bump.inputs["Strength"].default_value = 0.6 if kind == "tile" else 0.2
        links.new(height, bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    _bake_target(nodes, image)


# -- materiale finale -------------------------------------------------------------------


def _gltf_output_group():
    """Gruppo che l'esportatore glTF legge per l'occlusione (ingresso "Occlusion")."""
    group = bpy.data.node_groups.get("glTF Material Output")
    if group is None:
        group = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
        group.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
        group.nodes.new("NodeGroupInput")
    return group


def final_graph(mat, albedo, normal, orm, kind, style=None):
    """Principled con le tre texture. L'export glTF porta albedo (baseColor), normal,
    metallicRoughness (G, B dell'ORM) e occlusion (R dell'ORM, via "glTF Material Output")."""
    style = style or STYLES[kind]
    tree = mat.node_tree
    tree.nodes.clear()
    nodes, links = tree.nodes, tree.links
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    albedo_tex = nodes.new("ShaderNodeTexImage")
    albedo_tex.image = albedo
    bsdf.inputs["Roughness"].default_value = style["rough_base"]
    if kind == "lamp":
        links.new(albedo_tex.outputs["Color"], bsdf.inputs["Base Color"])
        links.new(albedo_tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 3.0
        return
    links.new(albedo_tex.outputs["Color"], bsdf.inputs["Base Color"])
    if orm is not None:
        orm_tex = nodes.new("ShaderNodeTexImage")
        orm_tex.image = orm
        separate = nodes.new("ShaderNodeSeparateColor")
        links.new(orm_tex.outputs["Color"], separate.inputs["Color"])
        links.new(separate.outputs["Green"], bsdf.inputs["Roughness"])
        links.new(separate.outputs["Blue"], bsdf.inputs["Metallic"])
        group_node = nodes.new("ShaderNodeGroup")
        group_node.node_tree = _gltf_output_group()
        links.new(separate.outputs["Red"], group_node.inputs["Occlusion"])
    if normal is not None:
        normal_tex = nodes.new("ShaderNodeTexImage")
        normal_tex.image = normal
        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.space = "TANGENT"
        links.new(normal_tex.outputs["Color"], normal_map.inputs["Color"])
        links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
