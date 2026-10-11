"""Tile dipinte e ripetibili del mondo (restyling 2026-10-11, spec §3.3).

    blender -b --factory-startup --python tools/blender/build_surface_tiles.py -- [ground|walls|plants ...]

Ogni tile e cotta con Cycles su un piano con UV 0..1 usando le coordinate toroidali di
`painter.seamless_coords`, quindi si ripete senza cuciture. Ogni gruppo esce come tre PNG
verticali (gli strati impilati, lo strato 0 in alto) in `godot/assets/textures/surfaces/`:
`<gruppo>_albedo.png`, `<gruppo>_normal.png`, `<gruppo>_orm.png`, che Godot importa come
`Texture2DArray` (gli `.import` sono scritti da questo script).

Strati, nell'ordine usato dagli shader:
  ground: 0 dirt, 1 slabs, 2 asphalt, 3 dug_soil, 4 mud, 5 grass
  walls:  0 plaster_brick, 1 moss, 2 bark
  plants: 0 grass_tufts (tre colonne di ciuffi, alpha), 1 leaf_cards (foglie, alpha)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import painter  # noqa: E402
from painter import math_node, mix, noise, ramp  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "godot", "assets", "textures", "surfaces")
SIZE = 2048
# Risoluzione per gruppo: il suolo copre lo schermo, muri e piante no (VRAM).
SIZES = {"ground": 2048, "walls": 1024, "plants": 1024}
SAMPLES = 32

# (nome, colore_a, colore_b, scala_macro, scala_micro, roughness)
TILES = {
    "ground": [
        ("dirt", (0.46, 0.34, 0.22), (0.30, 0.22, 0.14), 3.0, 18.0, 0.9),
        ("slabs", (0.62, 0.58, 0.50), (0.42, 0.40, 0.35), 1.0, 14.0, 0.85),
        ("asphalt", (0.26, 0.25, 0.24), (0.16, 0.15, 0.15), 2.0, 24.0, 0.8),
        ("dug_soil", (0.52, 0.36, 0.20), (0.30, 0.20, 0.12), 4.0, 20.0, 0.95),
        ("mud", (0.22, 0.17, 0.12), (0.12, 0.10, 0.08), 2.5, 12.0, 0.35),
        ("grass", (0.30, 0.46, 0.12), (0.52, 0.60, 0.16), 2.0, 26.0, 0.9),
    ],
    "walls": [
        ("plaster_brick", (0.78, 0.72, 0.60), (0.60, 0.32, 0.22), 1.0, 10.0, 0.85),
        ("moss", (0.22, 0.38, 0.10), (0.45, 0.52, 0.16), 3.0, 16.0, 0.9),
        ("bark", (0.40, 0.30, 0.20), (0.24, 0.18, 0.12), 2.0, 22.0, 0.9),
    ],
    "plants": [
        ("grass_tufts", (0.30, 0.52, 0.14), (0.70, 0.78, 0.28), 1.0, 8.0, 0.9),
        ("leaf_cards", (0.26, 0.48, 0.14), (0.62, 0.72, 0.24), 1.0, 6.0, 0.9),
    ],
}

# Parametri per gli `.import` di Godot (importatore "2d_array_texture").
IMPORT_TEMPLATE = """[remap]

importer="2d_array_texture"
type="CompressedTexture2DArray"

[deps]

source_file="res://assets/textures/surfaces/{name}"

[params]

compress/mode=2
compress/high_quality=false
compress/hdr_compression=1
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
slices/horizontal=1
slices/vertical={layers}
"""


# -- grafi delle tile -------------------------------------------------------------------


def step(nodes, links, fac, lo, hi):
    """Rampa 0..1 netta fra `lo` e `hi`."""
    return ramp(nodes, links, fac, [(lo, (0.0, 0.0, 0.0)), (hi, (1.0, 1.0, 1.0))])


def uv_xy(nodes, links):
    uv = nodes.new("ShaderNodeTexCoord").outputs["UV"]
    separate = nodes.new("ShaderNodeSeparateXYZ")
    links.new(uv, separate.inputs["Vector"])
    return separate.outputs["X"], separate.outputs["Y"]


def joints(nodes, links, count, width):
    """Fughe fra lastre: griglia `count` x `count` nella tile (periodica per costruzione)."""
    u, v = uv_xy(nodes, links)
    fx = math_node(nodes, links, "FRACT", math_node(nodes, links, "MULTIPLY", u, count))
    fy = math_node(nodes, links, "FRACT", math_node(nodes, links, "MULTIPLY", v, count))
    dx = math_node(nodes, links, "ABSOLUTE", math_node(nodes, links, "SUBTRACT", fx, 0.5))
    dy = math_node(nodes, links, "ABSOLUTE", math_node(nodes, links, "SUBTRACT", fy, 0.5))
    edge = math_node(nodes, links, "MAXIMUM", dx, dy)
    return math_node(nodes, links, "GREATER_THAN", edge, 0.5 - width)


def bricks(nodes, links, coords, w):
    """Mattoni a vista dove l'intonaco e scrostato (rumore macro alto)."""
    brick = nodes.new("ShaderNodeTexBrick")
    brick.inputs["Scale"].default_value = 8.0
    brick.inputs["Mortar Size"].default_value = 0.02
    brick.inputs["Color1"].default_value = (0.0, 0.0, 0.0, 1.0)
    brick.inputs["Color2"].default_value = (0.0, 0.0, 0.0, 1.0)
    brick.inputs["Mortar"].default_value = (1.0, 1.0, 1.0, 1.0)
    links.new(nodes.new("ShaderNodeTexCoord").outputs["UV"], brick.inputs["Vector"])
    peel = step(nodes, links, noise(nodes, links, coords, 2.0, 2.0, 0.5, w), 0.55, 0.62)
    return math_node(nodes, links, "MULTIPLY", peel, math_node(nodes, links, "SUBTRACT", 1.0, brick.outputs["Fac"]))


def tile_albedo_graph(mat, image, spec):
    name, col_a, col_b, macro, micro, _rough = spec
    nodes, links, emit = painter._begin_emit_graph(mat)
    coords, w = painter.seamless_coords(nodes, links)
    base = ramp(nodes, links, noise(nodes, links, coords, macro, 2.0, 0.5, w), [(0.38, col_b), (0.62, col_a)])
    strokes = painter.brush(nodes, links, coords, painter.STYLES["tile"], w)
    color = mix(nodes, links, base, strokes, 1.0, "MULTIPLY")
    speck = ramp(nodes, links, noise(nodes, links, coords, micro, 4.0, 0.6, w),
                 [(0.35, (0.74, 0.74, 0.74)), (0.7, (1.14, 1.14, 1.14))])
    color = mix(nodes, links, color, speck, 1.0, "MULTIPLY")
    # Chiazze scure a media frequenza: danno corpo "dipinto" a ogni tile.
    blotch = ramp(nodes, links, noise(nodes, links, coords, macro * 2.5, 3.0, 0.5, w),
                  [(0.45, (0.80, 0.78, 0.76)), (0.6, (1.0, 1.0, 1.0))])
    color = mix(nodes, links, color, blotch, 1.0, "MULTIPLY")
    if name == "slabs":
        color = mix(nodes, links, color, (0.30, 0.28, 0.24), joints(nodes, links, 3.0, 0.03))
        cracks = step(nodes, links, noise(nodes, links, coords, 3.0, 5.0, 0.85, w), 0.60, 0.63)
        color = mix(nodes, links, color, (0.26, 0.24, 0.20), cracks)
    elif name == "plaster_brick":
        color = mix(nodes, links, color, (0.58, 0.30, 0.20), bricks(nodes, links, coords, w))
    elif name == "asphalt":
        cracks = step(nodes, links, noise(nodes, links, coords, 4.0, 5.0, 0.8, w), 0.62, 0.66)
        color = mix(nodes, links, color, (0.08, 0.08, 0.08), cracks)
    elif name == "dirt":
        stones = step(nodes, links, noise(nodes, links, coords, 22.0, 1.0, 0.5, w), 0.66, 0.70)
        color = mix(nodes, links, color, (0.58, 0.54, 0.47), stones)
    elif name == "dug_soil":
        clods = step(nodes, links, noise(nodes, links, coords, 9.0, 2.0, 0.6, w), 0.50, 0.56)
        color = mix(nodes, links, color, (0.34, 0.22, 0.12), clods)
        pebbles = step(nodes, links, noise(nodes, links, coords, 28.0, 1.0, 0.5, w), 0.70, 0.73)
        color = mix(nodes, links, color, (0.62, 0.56, 0.48), pebbles)
    elif name == "grass":
        # Fili e ciuffi: rumore fitto piu chiazze gialle d'erba secca.
        blades = ramp(nodes, links, noise(nodes, links, coords, 60.0, 2.0, 0.6, w),
                      [(0.4, (0.72, 0.78, 0.60)), (0.6, (1.12, 1.10, 0.90))])
        color = mix(nodes, links, color, blades, 1.0, "MULTIPLY")
        dry = step(nodes, links, noise(nodes, links, coords, 3.0, 2.0, 0.5, w), 0.56, 0.62)
        color = mix(nodes, links, color, (0.62, 0.58, 0.22), math_node(nodes, links, "MULTIPLY", dry, 0.6))
    elif name == "mud":
        puddles = step(nodes, links, noise(nodes, links, coords, 2.0, 2.0, 0.5, w), 0.52, 0.56)
        color = mix(nodes, links, color, (0.09, 0.08, 0.07), puddles)
    links.new(color, emit.inputs["Color"])
    painter._bake_target(nodes, image)
    return None


def plant_graph(mat, image, spec):
    """Strato 0: ciuffi d'erba in tre colonne (5 lame appuntite ciascuna). Strato 1:
    cartelle di fogliame, chiazze organiche con buchi. Punta chiara e base scura.
    Restituisce la presa 0/1 della maschera di alpha."""
    name, col_a, col_b = spec[0], spec[1], spec[2]
    nodes, links, emit = painter._begin_emit_graph(mat)
    u, v = uv_xy(nodes, links)  # v = 0 alla base (fondo del PNG), 1 in punta
    coords, w = painter.seamless_coords(nodes, links)
    if name == "grass_tufts":
        column_u = math_node(nodes, links, "FRACT", math_node(nodes, links, "MULTIPLY", u, 3.0))
        wobble = math_node(nodes, links, "MULTIPLY_ADD", noise(nodes, links, coords, 4.0, 1.0, 0.5, w), 0.08, -0.04)
        phase = math_node(nodes, links, "FRACT",
                          math_node(nodes, links, "MULTIPLY", math_node(nodes, links, "ADD", column_u, wobble), 5.0))
        # Lama larga alla base e appuntita: semi-larghezza = 0.45 * (1 - v)^1.6.
        taper = math_node(nodes, links, "POWER", math_node(nodes, links, "SUBTRACT", 1.0, v), 1.6)
        half = math_node(nodes, links, "MULTIPLY", taper, 0.45)
        distance = math_node(nodes, links, "ABSOLUTE", math_node(nodes, links, "SUBTRACT", phase, 0.5))
        inside = math_node(nodes, links, "LESS_THAN", distance, half)
        tip_line = math_node(nodes, links, "MULTIPLY_ADD", noise(nodes, links, coords, 3.0, 1.0, 0.5, w), 0.35, 0.62)
        inside = math_node(nodes, links, "MULTIPLY", inside, math_node(nodes, links, "LESS_THAN", v, tip_line))
    else:
        # Chiazze di foglie: rumore a soglia dentro un'ellisse morbida, con buchi.
        blobs = step(nodes, links, noise(nodes, links, coords, 4.5, 3.0, 0.55, w), 0.46, 0.49)
        du = math_node(nodes, links, "MULTIPLY", math_node(nodes, links, "SUBTRACT", u, 0.5), 2.1)
        dv = math_node(nodes, links, "MULTIPLY", math_node(nodes, links, "SUBTRACT", v, 0.5), 2.1)
        radius = math_node(nodes, links, "SQRT", math_node(nodes, links, "ADD",
                           math_node(nodes, links, "MULTIPLY", du, du), math_node(nodes, links, "MULTIPLY", dv, dv)))
        edge = math_node(nodes, links, "MULTIPLY_ADD", noise(nodes, links, coords, 8.0, 2.0, 0.5, w), 0.3, 0.75)
        inside = math_node(nodes, links, "MULTIPLY", blobs, math_node(nodes, links, "LESS_THAN", radius, edge))
    color = ramp(nodes, links, v, [(0.0, col_a), (1.0, col_b)])
    grain = ramp(nodes, links, noise(nodes, links, coords, 12.0, 2.0, 0.5, w),
                 [(0.4, (0.86, 0.86, 0.86)), (0.6, (1.08, 1.08, 1.08))])
    color = mix(nodes, links, color, grain, 1.0, "MULTIPLY")
    links.new(color, emit.inputs["Color"])
    painter._bake_target(nodes, image)
    return inside


def tile_orm_graph(mat, image, spec):
    style = dict(painter.STYLES["tile"])
    style["rough_base"] = spec[5]
    style["rough_wear"] = max(0.2, spec[5] - 0.25)
    painter.paint_orm_graph(mat, image, "tile", style, painter.seamless_coords)
    return None


def tile_normal_graph(mat, image, spec):
    painter.paint_normal_graph(mat, image, "tile", None, painter.seamless_coords)
    return None


# -- cottura ----------------------------------------------------------------------------


def bake_layer(name, graph, spec, colorspace, bake_type, samples, size):
    """Cuoce una tile di lato `size` su un piano nuovo e restituisce i pixel (RGBA float)."""
    SIZE = size  # noqa: N806 (lato della tile corrente)
    bpy.ops.mesh.primitive_plane_add(size=2.0)
    plane = bpy.context.active_object
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    plane.data.materials.append(mat)
    image = bpy.data.images.new(name, SIZE, SIZE, alpha=True)
    image.colorspace_settings.name = colorspace
    alpha_socket = graph(mat, image, spec)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.render.bake.margin = 0
    scene.render.bake.use_clear = True
    if bake_type == "NORMAL":
        scene.render.bake.normal_space = "TANGENT"
    bpy.ops.object.select_all(action="DESELECT")
    plane.select_set(True)
    bpy.context.view_layer.objects.active = plane
    bpy.ops.object.bake(type=bake_type)
    pixels = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    if alpha_socket is not None:
        mask = bpy.data.images.new(name + "_mask", SIZE, SIZE)
        mask.colorspace_settings.name = "Non-Color"
        tree = mat.node_tree
        emit = next(n for n in tree.nodes if n.type == "EMISSION")
        for link in list(emit.inputs["Color"].links):
            tree.links.remove(link)
        tree.links.new(alpha_socket, emit.inputs["Color"])
        painter._bake_target(tree.nodes, mask)
        scene.cycles.samples = 4
        bpy.ops.object.bake(type="EMIT")
        mask_pixels = np.empty(SIZE * SIZE * 4, dtype=np.float32)
        mask.pixels.foreach_get(mask_pixels)
        pixels[3::4] = mask_pixels[0::4]
        bpy.data.images.remove(mask)
    bpy.data.objects.remove(plane, do_unlink=True)
    bpy.data.images.remove(image)
    return pixels


def save_sheet(group, map_name, colorspace, layers_pixels, size):
    SIZE = size  # noqa: N806
    layers = len(layers_pixels)
    sheet = bpy.data.images.new("%s_%s" % (group, map_name), SIZE, SIZE * layers, alpha=True)
    sheet.colorspace_settings.name = colorspace
    buffer = np.empty(SIZE * SIZE * layers * 4, dtype=np.float32)
    for index, pixels in enumerate(layers_pixels):
        # Le righe di Blender partono dal basso: lo strato 0 va in cima al PNG, come
        # Godot legge gli strati di un Texture2DArray (dall'alto verso il basso).
        row0 = (layers - 1 - index) * SIZE
        buffer[row0 * SIZE * 4:(row0 + SIZE) * SIZE * 4] = pixels
    sheet.pixels.foreach_set(buffer)
    os.makedirs(OUT_DIR, exist_ok=True)
    file_name = "%s_%s.png" % (group, map_name)
    path = os.path.join(OUT_DIR, file_name)
    # `save()` scrive i byte cosi come sono (niente view transform, a differenza di save_render).
    sheet.filepath_raw = path
    sheet.file_format = "PNG"
    sheet.save()
    bpy.data.images.remove(sheet)
    with open(path + ".import", "w", encoding="utf-8", newline="\n") as handle:
        handle.write(IMPORT_TEMPLATE.format(name=file_name, layers=layers))
    print("TILE_SHEET %s layers=%d %s" % (file_name, layers, path))


MAPS = (
    ("albedo", "sRGB", "EMIT", SAMPLES),
    ("normal", "Non-Color", "NORMAL", 4),
    ("orm", "Non-Color", "EMIT", 8),
)


def build_group(group):
    specs = TILES[group]
    for map_name, colorspace, bake_type, samples in MAPS:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        if map_name == "albedo":
            graph = plant_graph if group == "plants" else tile_albedo_graph
        elif map_name == "normal":
            graph = tile_normal_graph
        else:
            graph = tile_orm_graph
        size = SIZES[group]
        layers = [bake_layer("%s_%s_%s" % (group, map_name, spec[0]), graph, spec, colorspace, bake_type, samples, size)
                  for spec in specs]
        save_sheet(group, map_name, colorspace, layers, size)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for group in argv or list(TILES):
        build_group(group)


main()
