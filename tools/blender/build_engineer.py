"""L'Ingegnere del restyling (D-088, spec 2026-10-13): donna cartoon a 3 teste, tuta blu
stinto abbassata in vita, canottiera, manicotti e cinghia arancio, capelli grigi legati
con un cavo, chiave da treno sulla schiena, lanterna da segnale sulla spalla.

Eseguire (Blender 5.2.2):
    blender -b --factory-startup --python tools/blender/build_engineer.py -- --clay
    blender -b --factory-startup --python tools/blender/build_engineer.py
Con `--clay` costruisce la sola forma (versione bassa) e scrive le anteprime in
output/engineer/clay/ e output/engineer/clay_colors/; senza, costruisce versione alta e
bassa, pesa, cuoce e esporta godot/assets/models/player_engineer.glb.

Metodo: corpo da un grafo sulle giunture dello scheletro (sculpt.skin_body), testa e
ciocche per sezioni (sculpt.loft), abiti estratti dal corpo (sculpt.extract_shell), forme
scolpite con i pennelli dopo la suddivisione. La versione bassa (livello LOW_LEVEL) e
quella del gioco; la alta (HIGH_LEVEL, piu i pennelli di dettaglio) serve solo a cuocere
la normal map. I pennelli di forma sono funzioni della posizione, quindi danno la stessa
superficie a ogni livello. Convenzioni dello scheletro: fronte a -Y, sinistra a +X, a T.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sculpt  # noqa: E402
import render_turntable  # noqa: E402
from build_character_assets import CHEST, HEAD, HIPS, ROOT, SPINE, Skeleton, build_pack_sack, export  # noqa: E402
from refined import RefinedBuilder  # noqa: E402

LOW_LEVEL = 1
HIGH_LEVEL = 3

# Palette (colori lineari). Tuta blu-petrolio stinta, accento arancio (D-077, D-088).
SKIN = (0.66, 0.36, 0.24)
BLUSH = (0.78, 0.22, 0.16)
HAIR = (0.52, 0.53, 0.55)
SUIT_BLUE = (0.07, 0.16, 0.2)
TANK = (0.78, 0.72, 0.6)
OIL = (0.2, 0.17, 0.12)
ORANGE = (0.95, 0.32, 0.03)
LEATHER = (0.24, 0.12, 0.05)
BOOT = (0.08, 0.05, 0.035)
STEEL = (0.38, 0.38, 0.4)
DARK_METAL = (0.07, 0.07, 0.075)
COPPER = (0.5, 0.2, 0.07)
CIGAR = (0.22, 0.11, 0.05)
LANTERN_GLASS = (1.0, 0.55, 0.15)

# Proporzioni a 3 teste (scheletro della libreria, regola D-060): gambe molto corte,
# spalle larghissime, braccia corte; la testa e le mani grandi stanno nella mesh.
ENGINEER_PROPORTIONS = {
    "DEF-thigh": (0.5, (1.7, 1.0, 1.0)),
    "DEF-shin": (0.5, (1.0, 1.0, 1.0)),
    "DEF-neck": (0.35, (1.0, 1.0, 1.0)),
    "DEF-shoulder": (1.9, (1.0, 1.0, 1.0)),
    "DEF-upper_arm": (0.72, (1.0, 1.0, 1.0)),
    "DEF-forearm": (0.72, (1.0, 1.0, 1.0)),
}

HEAD_HEIGHT = 0.56


def _body_graph(s):
    """Nodi e archi del corpo nudo (pelle), sulle giunture dello scheletro."""
    nodes, edges = [], []

    def node(p, r):
        nodes.append((tuple(p), r))
        return len(nodes) - 1

    hips = s.head(HIPS)
    waist = s.head(SPINE)
    chest = s.head(CHEST)
    neck = s.tail(CHEST)
    pelvis = node(hips + Vector((0, 0, 0.02)), (0.27, 0.22))
    belly = node(waist + Vector((0, -0.04, 0.02)), (0.34, 0.3))
    ribs = node(chest, (0.33, 0.25))
    collar = node(neck + Vector((0, 0, -0.04)), (0.2, 0.16))
    edges += [(pelvis, belly), (belly, ribs), (ribs, collar)]
    for side in (".L", ".R"):
        sign = 1.0 if side == ".L" else -1.0
        hip = node(s.head("DEF-thigh" + side), 0.16)
        knee = node(s.head("DEF-shin" + side), 0.13)
        ankle = node(s.head("DEF-foot" + side), 0.11)
        toe = node(s.tail("DEF-toe" + side) + Vector((0, -0.04, 0)), 0.1)
        edges += [(pelvis, hip), (hip, knee), (knee, ankle), (ankle, toe)]
        hand = s.head("DEF-hand" + side)
        shoulder = node(s.head("DEF-upper_arm" + side), 0.14)
        elbow = node(s.head("DEF-forearm" + side), 0.115)
        forearm = node((s.head("DEF-forearm" + side) + hand) * 0.5 + Vector((0, 0, 0.01)), 0.125)
        wrist = node(hand, 0.1)
        palm = node(hand + Vector((sign * 0.12, 0, 0)), (0.15, 0.12))
        mitt = node(hand + Vector((sign * 0.28, -0.01, -0.01)), (0.14, 0.1))
        thumb_base = node(hand + Vector((sign * 0.1, -0.12, 0.0)), 0.07)
        thumb_tip = node(hand + Vector((sign * 0.18, -0.2, 0.02)), 0.06)
        edges += [(ribs, shoulder), (shoulder, elbow), (elbow, forearm), (forearm, wrist), (wrist, palm),
                  (palm, mitt), (palm, thumb_base), (thumb_base, thumb_tip)]
    return nodes, edges


def _shape(obj, s):
    """Pennelli di forma comuni a corpo e abiti (stessa funzione della posizione: gli abiti
    seguono il corpo): pancia tonda in fuori, petto basso, spalle e polpacci."""
    waist = s.head(SPINE)
    chest = s.head(CHEST)
    sculpt.grab(obj, waist + Vector((0, -0.25, 0.05)), 0.36, (0, -0.1, -0.02), scale=(1.0, 0.8, 0.9))
    sculpt.inflate(obj, chest + Vector((0, -0.2, -0.08)), 0.2, 0.03, scale=(1.4, 1.0, 0.8))
    for side in (".L", ".R"):
        sculpt.inflate(obj, s.head("DEF-upper_arm" + side), 0.16, 0.025)
        knee = s.head("DEF-shin" + side)
        ankle = s.head("DEF-foot" + side)
        sculpt.inflate(obj, (knee + ankle) * 0.5 + Vector((0, 0.06, 0)), 0.12, 0.02)


def _shape_hands(body, s):
    """Muffola: tre dita grosse divise da due solchi sul dorso e sul palmo."""
    for side in (".L", ".R"):
        hand = s.head("DEF-hand" + side)
        sign = 1.0 if side == ".L" else -1.0
        for dy in (-0.035, 0.035):
            for dz in (0.09, -0.09):
                a = hand + Vector((sign * 0.2, dy, dz))
                b = hand + Vector((sign * 0.44, dy, dz * 0.6))
                sculpt.crease_line(body, [a, b], 0.03, 0.018)


def _blob(name, center, radii, sides=12, rings=7):
    """Ellissoide a quadrilateri (occhi, orecchie, palpebre): loft di anelli lungo Z."""
    cx, cy, cz = center
    rx, ry, rz = radii
    result = []
    for k in range(rings):
        t = -1.0 + 2.0 * (k + 0.5) / rings
        f = math.sqrt(max(0.0, 1.0 - t * t))
        result.append(sculpt.Ring((cx, cy, cz + t * rz), rx * f, ry * f, sides=sides))
    return sculpt.loft(name, result)


def _head(s, level):
    """Testa grande a uovo, mento alto e sporgente, guance, ghigno; naso, occhi socchiusi,
    sopracciglia e orecchie come forme proprie (piu leggibili dall'alto)."""
    top = s.head(HEAD)
    profile = [(-0.02, 0.1, 0.1), (0.02, 0.17, 0.16), (0.07, 0.22, 0.21), (0.13, 0.25, 0.24), (0.19, 0.265, 0.255),
               (0.25, 0.27, 0.26), (0.31, 0.265, 0.255), (0.37, 0.25, 0.24), (0.43, 0.215, 0.205), (0.48, 0.16, 0.155),
               (0.52, 0.09, 0.09), (0.545, 0.03, 0.03)]
    head = sculpt.loft("Head", [sculpt.Ring(top + Vector((0, -0.02, z)), rx, ry, sides=16) for z, rx, ry in profile])
    sculpt.subdivide(head, level + 1)
    sculpt.grab(head, top + Vector((0, -0.22, 0.03)), 0.13, (0, -0.07, 0.03), scale=(1.5, 1.0, 0.8))  # mento
    sculpt.grab(head, top + Vector((0, -0.2, -0.02)), 0.12, (0, 0.0, 0.03), scale=(1.6, 1.0, 0.6))  # mascella
    for sign in (1.0, -1.0):
        sculpt.inflate(head, top + Vector((sign * 0.14, -0.2, 0.15)), 0.08, 0.03)  # guance
        sculpt.grab(head, top + Vector((sign * 0.09, -0.25, 0.29)), 0.07, (0, -0.03, 0.0))  # arcate
    sculpt.crease_line(head, [top + Vector((-0.11, -0.25, 0.115)), top + Vector((-0.02, -0.29, 0.1)),
                              top + Vector((0.07, -0.285, 0.105)), top + Vector((0.13, -0.24, 0.135))], 0.018, 0.022)
    parts = {"head": head}
    lip = _blob("Lip", (0.01, -0.27, top.z + 0.083), (0.06, 0.018, 0.013), sides=10, rings=5)
    sculpt.subdivide(lip, level)
    parts["lip"] = lip
    nose = sculpt.tube("Nose", [top + Vector((0.0, -0.27, 0.26)), top + Vector((0.02, -0.33, 0.21)),
                                top + Vector((0.04, -0.35, 0.175))], [0.035, 0.05, 0.055], sides=12)
    sculpt.subdivide(nose, level + 1)
    parts["nose"] = nose
    for sign in (1.0, -1.0):
        eye = _blob("Eye", (sign * 0.085, -0.252, top.z + 0.235), (0.04, 0.02, 0.024), sides=10, rings=5)
        lid = _blob("Lid", (sign * 0.085, -0.255, top.z + 0.262), (0.052, 0.03, 0.02), sides=10, rings=5)
        brow = sculpt.tube("Brow", [top + Vector((sign * 0.035, -0.28, 0.282)), top + Vector((sign * 0.09, -0.278, 0.305)),
                                    top + Vector((sign * 0.15, -0.252, 0.3))], [0.022, 0.03, 0.018], sides=8)
        ear = _blob("Ear", (sign * 0.265, -0.0, top.z + 0.22), (0.03, 0.055, 0.07), sides=10, rings=5)
        for key, obj in (("eye", eye), ("lid", lid), ("brow", brow), ("ear", ear)):
            sculpt.subdivide(obj, level)
            parts["%s%s" % (key, "_l" if sign > 0 else "_r")] = obj
    return parts


def build_organic(s, level, detail, materials):
    """Parti organiche al livello di suddivisione `level`; `detail` aggiunge i pennelli fini
    (solo per la versione alta). Ogni parte ha il colore per angolo e il materiale."""
    suit = materials["suit"]
    nodes, edges = _body_graph(s)
    base = sculpt.skin_body("BodyBase", nodes, edges)
    # Un livello prima di ritagliare gli abiti: bordi meno a gradini.
    sculpt.subdivide(base, 1)
    waist_z = s.head(SPINE).z
    chest_z = s.head(CHEST).z
    neck_z = s.tail(CHEST).z
    top = s.head(HEAD)
    elbow_x = abs(s.head("DEF-forearm.L").x)
    wrist_x = abs(s.head("DEF-hand.L").x)
    parts = {}
    # Abiti estratti dal corpo: seguono il corpo come quelli veri.
    parts["shirt"] = sculpt.extract_shell(base, "Shirt", lambda p: waist_z - 0.08 < p.z
                                          < chest_z + 0.1 - (0.09 * max(0.0, 1.0 - abs(p.x) / 0.16) if p.y < 0 else 0.0)
                                          and abs(p.x) < 0.3, 0.012, 0.012)
    parts["belt"] = sculpt.extract_shell(base, "Belt", lambda p: waist_z - 0.17 < p.z < waist_z - 0.11
                                         and abs(p.x) < 0.5, 0.05, 0.025)
    parts["waistband"] = sculpt.extract_shell(base, "Waistband", lambda p: waist_z - 0.12 < p.z < waist_z - 0.0
                                              and abs(p.x) < 0.5, 0.04, 0.03)
    parts["overalls"] = sculpt.extract_shell(base, "Overalls", lambda p: 0.26 < p.z < waist_z - 0.02
                                             and abs(p.x) < 0.5, 0.022, 0.016)
    parts["boots"] = sculpt.extract_shell(base, "Boots", lambda p: p.z < 0.26 and abs(p.x) < 0.5, 0.028, 0.02)
    parts["cuffs"] = sculpt.extract_shell(base, "Cuffs", lambda p: elbow_x + 0.04 < abs(p.x) < wrist_x + 0.02
                                          and p.z > waist_z, 0.016, 0.014)
    parts["body"] = base
    for obj in parts.values():
        sculpt.subdivide(obj, level)
    for key in ("body", "shirt", "overalls", "waistband", "belt"):
        _shape(parts[key], s)
    _shape_hands(parts["body"], s)
    sculpt.set_color(parts["body"], SKIN)
    sculpt.set_color(parts["shirt"], TANK)
    sculpt.set_color(parts["overalls"], SUIT_BLUE)
    sculpt.set_color(parts["waistband"], SUIT_BLUE)
    sculpt.set_color(parts["belt"], LEATHER)
    sculpt.set_color(parts["boots"], BOOT)
    sculpt.set_color(parts["cuffs"], ORANGE)
    sculpt.tint(parts["shirt"], (0.08, -0.33, waist_z + 0.1), 0.12, OIL, 0.8)
    sculpt.tint(parts["shirt"], (-0.12, -0.3, chest_z - 0.05), 0.07, OIL, 0.6)
    # Spalline della canottiera, dal petto alla schiena sopra le spalle.
    straps = []
    for sign in (1.0, -1.0):
        straps.append(sculpt.tube("Strap", [(sign * 0.15, -0.24, chest_z + 0.06), (sign * 0.19, -0.12, neck_z + 0.02),
                                            (sign * 0.19, 0.08, neck_z + 0.0), (sign * 0.15, 0.2, chest_z + 0.04)],
                                  [(0.04, 0.012)] * 4, sides=8))
    # Maniche della tuta annodate davanti, appena fuori dalla pancia vera; il nodo di lato.
    def front(x, z):
        near = [v.co.y for v in parts["waistband"].data.vertices if abs(v.co.x - x) < 0.05 and abs(v.co.z - z) < 0.05]
        return min(near) if near else -0.4

    band_z = waist_z - 0.07
    knot = Vector((0.1, front(0.1, band_z) - 0.06, band_z))
    for sign in (1.0, -1.0):
        path = [(sign * 0.4, 0.02, band_z), (sign * 0.42, front(sign * 0.42, band_z) * 0.5, band_z)]
        for x in (sign * 0.32, sign * 0.18):
            path.append((x, front(x, band_z) - 0.045, band_z))
        path.append(tuple(knot + Vector((sign * 0.03, 0.0, 0.0))))
        straps.append(sculpt.tube("Sleeve", path, [0.055, 0.06, 0.065, 0.065, 0.06], sides=10))
    for dx, length in ((0.02, 0.17), (0.07, 0.13)):
        straps.append(sculpt.tube("SleeveEnd", [tuple(knot + Vector((dx - 0.02, -0.01, -0.02))),
                                                tuple(knot + Vector((dx, -0.03, -length)))], [0.055, 0.065], sides=10))
    parts["knot"] = _blob("Knot", tuple(knot), (0.075, 0.06, 0.065), sides=10, rings=5)
    # Tracolla arancio della chiave: dalla spalla sinistra all'anca destra sul petto.
    def chest_front(x, z):
        near = [v.co.y for v in parts["shirt"].data.vertices if abs(v.co.x - x) < 0.05 and abs(v.co.z - z) < 0.05]
        return min(near) if near else -0.35

    sling = [(0.22, 0.02, neck_z + 0.04)]
    for t in (0.0, 0.33, 0.66, 1.0):
        x, z = 0.2 - 0.48 * t, chest_z + 0.08 - (chest_z + 0.08 - waist_z + 0.02) * t
        sling.append((x, chest_front(x, z) - 0.018, z))
    straps.append(sculpt.tube("Sling", sling, [(0.05, 0.014)] * len(sling), sides=8))
    for i, obj in enumerate(straps):
        sculpt.subdivide(obj, level)
        parts["strap_%d" % i] = obj
    sculpt.subdivide(parts["knot"], level)
    for key in ("strap_0", "strap_1"):
        sculpt.set_color(parts[key], TANK)
    for key in ("strap_2", "strap_3", "strap_4", "strap_5", "knot"):
        sculpt.set_color(parts[key], SUIT_BLUE)
    sculpt.set_color(parts["strap_6"], ORANGE)
    face = _head(s, level)
    for key, obj in face.items():
        kind = key[:-2] if key[-2:] in ("_l", "_r") else key
        sculpt.set_color(obj, {"eye": (0.03, 0.025, 0.02), "brow": HAIR}.get(kind, SKIN))
        parts[key] = obj
    sculpt.tint(face["nose"], top + Vector((0.04, -0.36, 0.18)), 0.07, BLUSH, 0.9)
    for sign in (1.0, -1.0):
        sculpt.tint(face["head"], top + Vector((sign * 0.15, -0.22, 0.15)), 0.08, BLUSH, 0.55)
    # Capelli: calotta a ciocche con l'attaccatura alta davanti, crocchia dietro legata dal cavo.
    # Anelli inclinati attorno al centro della testa: attaccatura alta sulla fronte, bassa sulla nuca.
    cap = sculpt.loft("Hair", [sculpt.Ring(top + Vector((0, -0.02 + dy, z)), rx, ry, axis=(0.0, -0.35, 1.0), sides=16)
                               for z, dy, rx, ry in ((0.27, 0.03, 0.29, 0.295), (0.35, 0.0, 0.3, 0.305),
                                                     (0.44, -0.01, 0.27, 0.275), (0.52, -0.01, 0.2, 0.2),
                                                     (0.575, -0.01, 0.11, 0.11), (0.6, -0.01, 0.03, 0.03))])
    bun = sculpt.loft("Bun", [sculpt.Ring(top + Vector((0, y, 0.45)), r, r, axis="y", sides=12)
                              for y, r in ((0.22, 0.05), (0.27, 0.11), (0.34, 0.12), (0.4, 0.08), (0.43, 0.02))])
    for obj in (cap, bun):
        sculpt.subdivide(obj, level)
        sculpt.set_color(obj, HAIR)
    for i in range(9):
        a = math.radians(-80.0 + i * 20.0)
        sculpt.crease_line(cap, [top + Vector((math.sin(a) * 0.12, -math.cos(a) * 0.12 + 0.05, 0.6)),
                                 top + Vector((math.sin(a) * 0.32, -math.cos(a) * 0.32 + 0.05, 0.3))], 0.02, 0.007)
    parts["hair"] = cap
    parts["bun"] = bun
    parts["cable"] = sculpt.tube("Cable", [top + Vector((0, 0.3, 0.45)), top + Vector((0, 0.31, 0.45))], [0.12, 0.12],
                                 sides=12)
    parts["plug_cable"] = sculpt.tube("PlugCable", [top + Vector((0.1, 0.31, 0.42)), top + Vector((0.14, 0.33, 0.33)),
                                                    top + Vector((0.13, 0.31, 0.24))], [0.012] * 3, sides=6)
    for key in ("cable", "plug_cable"):
        sculpt.subdivide(parts[key], level)
        sculpt.set_color(parts[key], ORANGE)
    if detail:
        _detail(parts, s)
    for obj in parts.values():
        sculpt.assign_material(obj, suit)
    return parts


def _detail(parts, s):
    """Pennelli fini della versione alta: pieghe della tuta e della canottiera, rughe."""
    waist_z = s.head(SPINE).z
    sculpt.fold_noise(parts["overalls"], lambda p: True, 0.012, 9.0, seed=1)
    sculpt.fold_noise(parts["shirt"], lambda p: p.z < waist_z + 0.15, 0.006, 14.0, seed=2)
    for key in ("waistband", "strap_2", "strap_3", "knot"):
        sculpt.fold_noise(parts[key], lambda p: True, 0.01, 12.0, seed=3)
    top = s.head(HEAD)
    for k in range(3):
        z = 0.35 + 0.025 * k
        sculpt.crease_line(parts["head"], [top + Vector((-0.1, -0.26, z)), top + Vector((0.1, -0.26, z))], 0.008, 0.004)
    for sign in (1.0, -1.0):
        sculpt.crease_line(parts["head"], [top + Vector((sign * 0.06, -0.28, 0.17)), top + Vector((sign * 0.11, -0.25, 0.11))],
                           0.01, 0.006)  # pieghe naso-labbra
    sculpt.crease_line(parts["head"], [top + Vector((-0.17, -0.21, 0.27)), top + Vector((-0.12, -0.23, 0.18))],
                       0.008, 0.006)  # cicatrice


def build_gear(rb, s):
    """Accessori duri con refined.py, ciascuno rigido sul suo osso: zaino-officina, chiave
    da treno in diagonale con cinghia arancio, lanterna da segnale sulla spalla destra,
    fiaschetta all'anca, attrezzi alla cintura, sigaro, chiodatrice nella destra."""
    chest_z = s.head(CHEST).z
    neck_z = s.tail(CHEST).z
    waist_z = s.head(SPINE).z
    top = s.head(HEAD)
    pack_z = (chest_z + neck_z) * 0.5 - 0.02
    # Zaino-officina: tanica, manometro, tubi; cinghie arancio.
    rb.box(CHEST, (0.46, 0.26, 0.42), (0.0, 0.36, pack_z), DARK_METAL, bevel=0.05, segments=3)
    rb.box(CHEST, (0.36, 0.06, 0.3), (0.0, 0.5, pack_z + 0.02), COPPER, bevel=0.03)
    rb.cyl(CHEST, 0.07, 0.03, (0.14, 0.53, pack_z + 0.14), STEEL, axis="y", sides=16, bevel=0.01)
    rb.cyl(CHEST, 0.055, 0.01, (0.14, 0.548, pack_z + 0.14), (0.85, 0.82, 0.7), axis="y", sides=16, bevel=0.003)
    rb.cyl(CHEST, 0.025, 0.5, (-0.24, 0.42, pack_z), STEEL, sides=10, rot=(0.0, 20.0, 0.0), bevel=0.006)
    for x in (-0.17, 0.17):
        rb.box(CHEST, (0.06, 0.1, 0.5), (x, 0.17, pack_z - 0.02), ORANGE, mat="suit", bevel=0.015)
    # Chiave da treno enorme in diagonale sulla schiena, cinghia arancio.
    rb.box(CHEST, (0.07, 0.05, 1.05), (0.0, 0.56, pack_z + 0.05), STEEL, rot=(0.0, 38.0, 0.0), bevel=0.02)
    rb.cyl(CHEST, 0.13, 0.06, (-0.31, 0.56, pack_z + 0.45), STEEL, axis="y", sides=6, bevel=0.015)
    rb.box(CHEST, (0.05, 0.03, 0.9), (0.06, 0.53, pack_z), ORANGE, mat="suit", rot=(0.0, 38.0, 0.0), bevel=0.01)
    # Lanterna da segnale ferroviario in cima allo zaino, sopra la spalla destra.
    lx, ly, lz = -0.2, 0.3, pack_z + 0.3
    rb.box(CHEST, (0.14, 0.14, 0.18), (lx, ly, lz), DARK_METAL, bevel=0.02)
    rb.cyl(CHEST, 0.05, 0.03, (lx, ly - 0.08, lz), LANTERN_GLASS, mat="lamp", axis="y", sides=14, bevel=0.005)
    rb.cyl(CHEST, 0.05, 0.03, (lx, ly + 0.08, lz), LANTERN_GLASS, mat="lamp", axis="y", sides=14, bevel=0.005)
    rb.cyl(CHEST, 0.012, 0.12, (lx, ly, lz + 0.13), STEEL, axis="x", sides=8)
    rb.cyl(CHEST, 0.03, 0.12, (lx, ly, lz - 0.14), STEEL, sides=10)
    # Fiaschetta all'anca sinistra, attrezzi alla cintura.
    rb.box(HIPS, (0.04, 0.12, 0.16), (0.36, -0.04, waist_z - 0.12), STEEL, bevel=0.015)
    rb.box(HIPS, (0.03, 0.03, 0.18), (-0.3, -0.2, waist_z - 0.15), DARK_METAL, rot=(0.0, 15.0, 0.0), bevel=0.006)
    rb.cyl(HIPS, 0.05, 0.03, (-0.22, -0.26, waist_z - 0.11), (0.2, 0.2, 0.22), axis="y", sides=14)
    # Sigaro spento all'angolo della bocca.
    rb.cyl(HEAD, 0.018, 0.14, (top.x + 0.08, top.y - 0.33, top.z + 0.1), CIGAR, mat="suit", axis="y",
           rot=(0.0, 0.0, -25.0), sides=10, bevel=0.004)
    # Chiodatrice da binari nella destra: corpo, caricatore, punta.
    grip = s.head("DEF-hand.R") + Vector((-0.1, 0.0, 0.0))
    rb.box("DEF-hand.R", (0.07, 0.09, 0.16), (grip.x - 0.05, grip.y, grip.z - 0.1), LEATHER, bevel=0.02)
    rb.box("DEF-hand.R", (0.6, 0.12, 0.13), (grip.x - 0.2, grip.y, grip.z - 0.17), DARK_METAL, bevel=0.03, segments=3)
    rb.box("DEF-hand.R", (0.16, 0.1, 0.22), (grip.x - 0.12, grip.y, grip.z - 0.32), COPPER, bevel=0.02)
    rb.cyl("DEF-hand.R", 0.05, 0.1, (grip.x - 0.52, grip.y, grip.z - 0.17), ORANGE, mat="suit", axis="x", sides=14)
    return {"pack_z": pack_z, "sack_center": (0.0, 0.3, pack_z - 0.5)}


def _clay(s):
    rb = RefinedBuilder(paint_name="suit", bake_normal=False)
    parts = build_organic(s, LOW_LEVEL, False, rb.materials)
    build_gear(rb, s)
    objects = list(parts.values()) + rb.pieces
    for obj in rb.pieces:
        if obj.data.color_attributes.get("Col") is not None:
            obj.data.color_attributes.active_color = obj.data.color_attributes["Col"]
    tris = sum(sculpt.mesh_stats(o)["tris"] for o in objects)
    head = s.head(HEAD) + Vector((0.0, 0.0, 0.25))
    render_turntable.render_views(objects, os.path.join(ROOT, "output", "engineer", "clay"), "clay", head)
    render_turntable.render_views(objects, os.path.join(ROOT, "output", "engineer", "clay_colors"), "colors", head)
    low = min(min((o.matrix_world @ Vector(c)).z for c in o.bound_box) for o in objects)
    high = max(max((o.matrix_world @ Vector(c)).z for c in o.bound_box) for o in objects)
    print("ENGINEER_CLAY tris=%d height=%.2f head_z=%.2f parts=%d" % (tris, high - low, s.head(HEAD).z, len(objects)))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = Skeleton(ENGINEER_PROPORTIONS)
    s.obj.data.pose_position = "REST"
    if "--clay" in argv:
        _clay(s)
        return
    build_and_export(s)


def build_and_export(s):
    raise NotImplementedError("Task 5")


if __name__ == "__main__":
    main()
