# Restyling dell'Ingegnere — piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** sostituire l'ingegnere D-071/D-074 con la donna cartoon a 3 teste della scheda D-077, modellata a gabbia con scultura cotta da alta a bassa definizione, dipinta a 2048, sullo stesso scheletro e con le stesse 13 clip, con postura di carattere e stati di colore leggibili su una tuta blu.

**Architecture:** in Blender un modulo generico `sculpt.py` costruisce forme organiche (corpo da un grafo con il modificatore Skin, teste e ciocche per sezioni, abiti estratti dal corpo, pennelli di scultura e di colore); `build_engineer.py` le usa due volte (versione alta e bassa), aggiunge gli accessori duri con `refined.py`, pesa il corpo con i pesi automatici, cuoce la normal dalla versione alta e dipinge con `painter.py`, poi esporta con le funzioni di `build_character_assets.py`. In Godot un `PostureModifier` aggiunge mento alto e pancia in fuori dopo le animazioni e `PlayerCharacter` esprime gli stati con emissione o scurimento invece della tinta arancione.

**Tech Stack:** Blender 5.2.2 (bpy, bmesh, Cycles su CPU, Workbench per le anteprime), Godot 4.7.2 GDScript, glTF.

**Spec:** `docs/superpowers/specs/2026-10-13-engineer-restyle-design.md`

## Global Constraints

- Stesso scheletro: stessi **nomi** delle ossa del `player_engineer.glb` attuale; cambiano solo le lunghezze (regola D-060: stesse direzioni e rollio).
- Stesse 13 clip, con le durate originali (`Jog_Fwd` 0,92 s, `Strafe_Left` 0,67 s ±0,03).
- Capsula di collisione invariata: raggio 0,34 m, altezza 1,76 m (`godot/scenes/player/player.tscn`).
- Triangoli del giocatore (corpo unito, sacca esclusa): **20.000-28.000**.
- Texture: albedo, normal, ORM a **2048**, un solo atlante per tutto il personaggio.
- Superfici del corpo: `suit`, `gear`, `lamp` (come oggi: draw call invariate); nodo `PackSack` con materiali `pack_sack` e `pack_gauge` invariati.
- Frame su PC (preset Alto, 70 nemici) al massimo **+0,3 ms**; primitive totali al massimo **+3 %** rispetto alla misura del Task 1.
- Nessun asset esterno, nessuna AI, nessuna spesa (D-077).
- Identificatori, file e asset in inglese; commenti e documenti in italiano, come il codice attorno.
- Controller e tastiera/mouse non sono toccati da questo lavoro.
- Comandi: Blender `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python <script> -- <argomenti>`; Godot `godot_console` (mai `godot`); dopo ogni nuovo `.glb` o nuova `class_name`: `godot_console --headless --path godot --editor --quit`.
- Suite Godot una alla volta, uccidendo i processi godot rimasti (memoria del progetto: processi stantii scrivono sullo stesso log).
- Lavoro nel worktree e branch `feature/engineer-restyle` (creato con superpowers:using-git-worktrees).

## Review Focus

1. **Pesi automatici che falliscono in silenzio**: il "bone heat" di Blender lascia vertici senza peso e quei vertici restano fermi all'origine in gioco. Atteso: nessun vertice del corpo con somma dei pesi < 0,99. Test nel Task 5 (`check_engineer.py`).
2. **Scheletro in posa animata durante la cottura**: le tracce NLA mettono l'armatura nella posa del primo fotogramma e la versione bassa cotta non combacia più con quella alta. Atteso: cottura sempre a riposo. Asserzione nel Task 4 (`build_engineer.py` controlla `pose_position == "REST"` prima di cuocere).
3. **Colpo durante lo scatto**: finito il lampo del colpo la tuta deve tornare al bagliore dello scatto, non al neutro. Test nel Task 6 (`player_tests`).
4. **Postura durante capriola e morte**: la correzione costante deforma una capriola o una caduta. Atteso: nulla durante la morte, sfumata quando il busto non è dritto. Test nel Task 6 (`character_animator_tests`).
5. **Texture rigenerate non compresse**: le texture estratte rinascono senza compressione VRAM se il loro `.import` non c'è più. Atteso: `vram_texture: true` sulle tre texture del giocatore. Controllo nel Task 5.

---

### Task 1: Worktree, misure di riferimento e catture del "prima"

**Files:**
- Modify: `tools/blender/build_character_assets.py:702-722` (asset per nome con cartella d'uscita, `main` sotto guardia)
- Create: `output/engineer/before/` (catture e copia del `.glb` attuale, fuori da Git come il resto di `output/`)

**Interfaces:**
- Produces: `build_character_assets.Skeleton`, `build_pack_sack`, `export`, `shade`, le costanti `HIPS`, `SPINE`, `CHEST`, `HEAD` importabili da un altro script senza eseguire la costruzione; `export(..., out_dir=OUT_DIR)`.
- Produces: misure di riferimento (righe `PROTOTYPE01_ARENA_BENCH frame` e `render`) annotate in `output/engineer/before/bench.txt`.

- [ ] **Step 1: Creare il worktree**

Usare superpowers:using-git-worktrees: branch `feature/engineer-restyle` da `feature/arena-run`, cartella `../Videogame-engineer`. Dentro il worktree: `godot_console --headless --path godot --editor --quit` (registra Terrain3D e importa).

- [ ] **Step 2: Copia del modello attuale e catture del "prima"**

```bash
mkdir -p output/engineer/before
cp godot/assets/models/player_engineer.glb output/engineer/before/player_engineer_d074.glb
godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 600 --script res://tests/tools/capture_character.gd -- --out=../output/engineer/before
```
Atteso: `row_front.png`, `row_back.png`, `row_game.png`, `row_side.png` in `output/engineer/before/`.

- [ ] **Step 3: Misure di riferimento**

```bash
godot_console --path godot --resolution 1280x800 --script res://tests/tools/benchmark_arena.gd -- --enemies=70 --preset=high 2>&1 | grep "ARENA_BENCH \(frame\|render\)" | tee output/engineer/before/bench.txt
```
Atteso: due righe, `frame ... avg_frame_ms=` e `render ... primitives=`. Ripetere 2 volte e tenere la mediana di `avg_frame_ms` (nessuna simulazione in parallelo: falsa le misure).

- [ ] **Step 4: Rendere importabile `build_character_assets.py`**

Sostituire il fondo del file (`ASSETS` e `main`, righe 702-722) con:

```python
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
```

e in `export` aggiungere il parametro `out_dir=OUT_DIR`, usato al posto di `OUT_DIR`:

```python
def export(skeleton, obj, asset_name, root_name, vertex_color="ACTIVE", extras=(), out_dir=OUT_DIR):
    ...
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, asset_name + ".glb")
```

Aggiornare la docstring in testa al file: "Senza nomi stampa l'uso; l'ingegnere del gioco lo costruisce `build_engineer.py`."

- [ ] **Step 5: Verificare che la guardia funzioni**

```bash
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_character_assets.py -- player_engineer_blocky 2>&1 | grep "ASSET_EXPORTED\|Error"
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python-expr "import sys; sys.path.insert(0, 'tools/blender'); import build_character_assets; print('IMPORT_OK')" 2>&1 | grep "IMPORT_OK\|ASSET_EXPORTED"
```
Atteso: la prima stampa `ASSET_EXPORTED player_engineer_blocky ...` e scrive in `output/engineer/before/`; la seconda stampa **solo** `IMPORT_OK` (nessuna costruzione all'import). `godot/assets/models/player_engineer.glb` non cambia (`git status` pulito su quel file).

- [ ] **Step 6: Commit**

```bash
git add tools/blender/build_character_assets.py
git commit -m "Ingegnere D-074 e a blocchi costruibili solo per confronto, script importabile senza costruire"
```

---

### Task 2: `sculpt.py`, modellazione a gabbia, con autoverifica

**Files:**
- Create: `tools/blender/sculpt.py`
- Create: `tools/blender/selftest_sculpt.py`

**Interfaces:**
- Produces (tutte su oggetti mesh di Blender, coordinate oggetto = mondo, oggetti non ruotati):
  - `skin_body(name, nodes, edges, root=0, smooth=0.5) -> Object` — `nodes`: lista di `((x, y, z), r)` (raggio uniforme) o `((x, y, z), (rx, ry))`; `edges`: coppie di indici. Applica il modificatore Skin, restituisce una mesh a quadrilateri chiusa.
  - `loft(name, rings, cap_start=True, cap_end=True) -> Object` — `rings`: lista di `Ring`; tutte con lo stesso numero di lati.
  - `Ring(center, rx, ry, axis="z", sides=12, scale=None)` — sezione ellittica nel piano perpendicolare ad `axis`; `scale`: lista di `sides` fattori radiali facoltativi.
  - `extract_shell(source, name, keep, offset, thickness) -> Object` — copia le facce di `source` il cui centro soddisfa `keep(Vector) -> bool`, le spinge di `offset` lungo la normale e dà spessore `thickness`.
  - `subdivide(obj, levels) -> Object` — Catmull-Clark applicato.
  - `set_color(obj, color)`; `tint(obj, center, radius, color, strength, scale=(1,1,1))` — attributo `Col` per angolo.
  - Pennelli (spostano i vertici con caduta smoothstep): `grab(obj, center, radius, offset, scale=(1,1,1))`, `inflate(obj, center, radius, amount, scale=(1,1,1))`, `crease_line(obj, points, radius, depth)`, `fold_noise(obj, keep, amplitude, frequency, seed=0)`.
  - `assign_material(obj, material)`, `mesh_stats(obj) -> dict(tris, boundary_edges, verts)`.

- [ ] **Step 1: Scrivere l'autoverifica (fallisce: il modulo non esiste)**

`tools/blender/selftest_sculpt.py`:

```python
"""Autoverifica di sculpt.py (D-088). Eseguire:
    blender -b --factory-startup --python tools/blender/selftest_sculpt.py
Stampa `SCULPT_SELFTEST PASS|FAIL failures=N` ed esce con 1 se fallisce."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

bpy.ops.wm.read_factory_settings(use_empty=True)

import sculpt  # noqa: E402

failures = 0


def check(condition, label):
    global failures
    if condition:
        print("  ok   %s" % label)
    else:
        failures += 1
        print("  FAIL %s" % label)


# Corpo da grafo: tre nodi in fila con un ramo, chiuso e a quadrilateri.
body = sculpt.skin_body("Body", [((0, 0, 0.5), 0.2), ((0, 0, 1.0), 0.25), ((0, 0, 1.4), 0.15), ((0.4, 0, 1.0), 0.08)],
                        [(0, 1), (1, 2), (1, 3)])
stats = sculpt.mesh_stats(body)
check(stats["boundary_edges"] == 0, "skin_body: mesh chiusa (%d bordi aperti)" % stats["boundary_edges"])
check(all(len(p.vertices) == 4 for p in body.data.polygons), "skin_body: solo quadrilateri")
zs = [v.co.z for v in body.data.vertices]
check(min(zs) < 0.35 and max(zs) > 1.5, "skin_body: copre i nodi (z %.2f..%.2f)" % (min(zs), max(zs)))

# Loft: 4 anelli da 8 lati con le due chiusure = 3*8 quadrilateri + 2*8 triangoli.
rings = [sculpt.Ring((0, 0, z), 0.1, 0.1, sides=8) for z in (0.0, 0.1, 0.2, 0.3)]
tube = sculpt.loft("Tube", rings)
check(len(tube.data.polygons) == 3 * 8 + 2 * 8, "loft: %d facce (attese 40)" % len(tube.data.polygons))
check(sculpt.mesh_stats(tube)["boundary_edges"] == 0, "loft: chiuso")
side = sculpt.loft("Side", [sculpt.Ring((x, 0, 0), 0.05, 0.08, axis="x", sides=8) for x in (0.0, 0.2)])
ys = [v.co.y for v in side.data.vertices]
zs = [v.co.z for v in side.data.vertices]
check(abs(max(ys) - 0.05) < 1e-4 and abs(max(zs) - 0.08) < 1e-4, "Ring asse x: rx lungo Y, ry lungo Z")

# Suddivisione: quadruplica i quadrilateri a ogni livello.
before = len(body.data.polygons)
sculpt.subdivide(body, 1)
check(len(body.data.polygons) == before * 4, "subdivide: %d -> %d facce" % (before, len(body.data.polygons)))

# Pennelli: muovono solo dentro il raggio, in modo deterministico.
far = [v.co.copy() for v in body.data.vertices if (v.co - Vector((0, 0, 0.5))).length > 0.5]
sculpt.grab(body, (0, 0, 1.0), 0.3, (0, -0.1, 0))
after_far = [v.co.copy() for v in body.data.vertices if (v.co - Vector((0, 0, 0.5))).length > 0.5]
moved_far = sum(1 for a, b in zip(far, after_far) if (a - b).length > 1e-6 and (b - Vector((0, 0, 1.0))).length > 0.3)
check(moved_far == 0, "grab: nessun vertice fuori raggio spostato")
front = min(v.co.y for v in body.data.vertices)
check(front < -0.25, "grab: la pancia esce davanti (y min %.3f)" % front)
copy_a = sculpt.loft("A", rings)
copy_b = sculpt.loft("B", rings)
sculpt.fold_noise(copy_a, lambda p: True, 0.01, 8.0, seed=3)
sculpt.fold_noise(copy_b, lambda p: True, 0.01, 8.0, seed=3)
check(all((a.co - b.co).length < 1e-9 for a, b in zip(copy_a.data.vertices, copy_b.data.vertices)),
      "fold_noise: deterministico a parita di seme")
radius_before = max(Vector((v.co.x, v.co.y)).length for v in tube.data.vertices if abs(v.co.z - 0.1) < 1e-4)
sculpt.inflate(tube, (0, 0, 0.1), 0.06, 0.02)
radius_after = max(Vector((v.co.x, v.co.y)).length for v in tube.data.vertices if abs(v.co.z - 0.1) < 0.01)
check(radius_after > radius_before + 0.015, "inflate: l'anello si allarga (%.3f -> %.3f)" % (radius_before, radius_after))
line = sculpt.loft("Line", [sculpt.Ring((0, 0, z), 0.1, 0.1, sides=16) for z in (0.0, 0.05, 0.1, 0.15, 0.2)])
sculpt.crease_line(line, [(0.1, 0, 0.0), (0.1, 0, 0.2)], 0.03, 0.01)
check(min(v.co.x for v in line.data.vertices if abs(v.co.y) < 0.01 and v.co.x > 0) < 0.095,
      "crease_line: il solco rientra lungo la linea")

# Abiti estratti: solo le facce scelte, spessore vero.
shell = sculpt.extract_shell(body, "Shirt", lambda p: 0.8 < p.z < 1.2, 0.01, 0.01)
zs = [v.co.z for v in shell.data.vertices]
check(min(zs) > 0.7 and max(zs) < 1.3, "extract_shell: solo la fascia scelta (z %.2f..%.2f)" % (min(zs), max(zs)))
check(sculpt.mesh_stats(shell)["boundary_edges"] == 0, "extract_shell: lo spessore chiude il guscio")

# Colore per angolo: set_color riempie, tint scalda solo vicino al centro.
sculpt.set_color(tube, (0.2, 0.3, 0.8))
sculpt.tint(tube, (0.1, 0, 0.3), 0.05, (1.0, 0.0, 0.0), 1.0)
cols = tube.data.color_attributes["Col"].data
reds = [c.color[0] for c in cols]
check(min(reds) < 0.21 and max(reds) > 0.9, "tint: rosso solo vicino al centro (%.2f..%.2f)" % (min(reds), max(reds)))

print("SCULPT_SELFTEST %s failures=%d" % ("PASS" if failures == 0 else "FAIL", failures))
sys.exit(1 if failures else 0)
```

- [ ] **Step 2: Eseguire e vedere il fallimento**

```bash
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/selftest_sculpt.py 2>&1 | tail -5
```
Atteso: `ModuleNotFoundError: No module named 'sculpt'`.

- [ ] **Step 3: Scrivere `sculpt.py`**

```python
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
    arco diventa un tubo; il modificatore Skin cuce rami e giunture a quadrilateri."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([Vector(p) for p, _r in nodes], [tuple(e) for e in edges], [])
    obj = _link(bpy.data.objects.new(name, mesh))
    modifier = obj.modifiers.new("Skin", "SKIN")
    modifier.branch_smoothness = smooth
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
    (asse z: X e Y; asse x: Y e Z; asse y: X e Z); `scale` deforma raggio per raggio."""

    def __init__(self, center, rx, ry, axis="z", sides=12, scale=None):
        self.center = Vector(center)
        self.rx, self.ry, self.axis, self.sides = rx, ry, axis, sides
        self.scale = scale or [1.0] * sides

    def points(self):
        result = []
        for i in range(self.sides):
            a = 2.0 * math.pi * i / self.sides
            u, v = math.cos(a) * self.rx * self.scale[i], math.sin(a) * self.ry * self.scale[i]
            offset = {"z": Vector((u, v, 0.0)), "x": Vector((0.0, u, v)), "y": Vector((u, 0.0, v))}[self.axis]
            result.append(self.center + offset)
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
```

- [ ] **Step 4: Eseguire l'autoverifica**

```bash
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/selftest_sculpt.py 2>&1 | grep "ok\|FAIL\|SELFTEST"
```
Atteso: `SCULPT_SELFTEST PASS failures=0`. Se `skin_body` produce triangoli ai rami (`solo quadrilateri` FAIL), alzare `smooth` o togliere l'asserzione **solo** se le facce non quadrilatere sono < 2 % e annotarlo nel docstring.

- [ ] **Step 5: Commit**

```bash
git add tools/blender/sculpt.py tools/blender/selftest_sculpt.py
git commit -m "sculpt.py: corpo da grafo Skin, loft a sezioni, abiti estratti, suddivisione, pennelli di forma e di colore, con autoverifica"
```

---

### Task 3: Anteprime a giro (`render_turntable.py`)

**Files:**
- Create: `tools/blender/render_turntable.py`

**Interfaces:**
- Produces: `render_views(objects, out_dir, mode="clay", head=None, size=(900, 1100))` — `mode`: `"clay"` (grigio uniforme), `"colors"` (attributo `Col`), `"painted"` (texture); `head`: punto della testa per il primo piano (`Vector`), se None la stima al 90 % dell'altezza. Scrive `turn_0.png` … `turn_7.png` (ogni 45°, 0 = di fronte), `face.png`, `game_back.png`, `game_front.png` (camera di gioco: inclinazione 55°, braccio 15 m, FOV orizzontale 90°, 1280x800) e `game_zoom.png` (stesso angolo a 4 m). Stampa `TURNTABLE <cartella> views=12`.

- [ ] **Step 1: Scrivere il modulo**

```python
"""Anteprime a giro di un personaggio (D-088), per giudicare forma e colori senza Godot.

Workbench con luce da studio, cavita e contorno: `clay` grigio uniforme (forma),
`colors` il colore per angolo `Col` (zone), `painted` le texture cotte. Le viste di
gioco riproducono la camera di IsometricCameraRig (inclinazione 55 gradi, braccio 15 m,
FOV orizzontale 90 gradi): il personaggio e piccolo come in gioco.
"""
import math
import os

import bpy
from mathutils import Vector

GAME_PITCH_DEG = 55.0
GAME_ARM_M = 15.0
GAME_HFOV_DEG = 90.0


def _bounds(objects):
    points = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return low, high


def _camera(scene):
    cam = scene.camera
    if cam is None:
        cam = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
        scene.collection.objects.link(cam)
        scene.camera = cam
    return cam


def _look(cam, position, target):
    cam.location = position
    cam.rotation_euler = (Vector(target) - Vector(position)).to_track_quat("-Z", "Y").to_euler()


def _shot(scene, path, size):
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def render_views(objects, out_dir, mode="clay", head=None, size=(900, 1100)):
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.film_transparent = False
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = {"clay": "SINGLE", "colors": "ATTRIBUTE", "painted": "TEXTURE"}[mode]
    shading.single_color = (0.62, 0.6, 0.58)
    shading.show_cavity = True
    shading.cavity_type = "BOTH"
    shading.show_object_outline = True
    shading.show_shadows = True
    scene.world = scene.world or bpy.data.worlds.new("PreviewWorld")
    low, high = _bounds(objects)
    center = (low + high) * 0.5
    height = high.z - low.z
    head = Vector(head) if head is not None else Vector((center.x, center.y, low.z + height * 0.9))
    cam = _camera(scene)
    cam.data.type = "PERSP"
    cam.data.lens = 50.0
    distance = height * 2.6
    # Il fronte del personaggio guarda -Y: la vista 0 e da -Y.
    for i in range(8):
        a = math.radians(45.0 * i)
        position = center + Vector((math.sin(a) * distance, -math.cos(a) * distance, height * 0.12))
        _look(cam, position, center)
        _shot(scene, os.path.join(out_dir, "turn_%d.png" % i), size)
    _look(cam, head + Vector((0.25, -1.1, 0.12)), head)
    _shot(scene, os.path.join(out_dir, "face.png"), (900, 900))
    pitch = math.radians(GAME_PITCH_DEG)
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.angle = math.radians(GAME_HFOV_DEG)
    for name, sign, arm in (("game_back", 1.0, GAME_ARM_M), ("game_front", -1.0, GAME_ARM_M), ("game_zoom", 1.0, 4.0)):
        position = center + Vector((0.0, sign * math.cos(pitch) * arm, math.sin(pitch) * arm))
        _look(cam, position, center)
        _shot(scene, os.path.join(out_dir, name + ".png"), (1280, 800))
    cam.data.lens = 50.0
    print("TURNTABLE %s views=12" % out_dir)
```

- [ ] **Step 2: Provarlo sul modello D-074 importato**

```bash
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python-expr "
import sys, bpy; sys.path.insert(0, 'tools/blender')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='output/engineer/before/player_engineer_d074.glb')
import render_turntable
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
render_turntable.render_views(meshes, 'output/engineer/before/turntable', mode='clay')
" 2>&1 | grep "TURNTABLE\|Error"
```
Atteso: `TURNTABLE output/engineer/before/turntable views=12` e 12 PNG. Aprirli con Read: l'ingegnere attuale è intero, centrato, visto da 8 lati; `game_back.png` lo mostra piccolo dall'alto come in gioco. **Se Workbench non rende in `-b`** (errore di contesto GPU): impostare `scene.render.engine = "CYCLES"`, `scene.cycles.samples = 16`, materiale grigio unico per `clay` e annotare la trappola in `docs/GODOT_WORKFLOW.md`.

- [ ] **Step 3: Commit**

```bash
git add tools/blender/render_turntable.py
git commit -m "Anteprime a giro dei personaggi: argilla, zone di colore o texture, primo piano e camera di gioco"
```

---

### Task 4: Forma in argilla (`build_engineer.py --clay`) — STOP per il giudizio del proprietario

**Files:**
- Modify: `tools/blender/build_character_assets.py` (`Skeleton.__init__(self, proportions=PROPORTIONS)`, `_reproportion` legge `self.proportions`; `build_pack_sack(skeleton, pack_z, sack_center=None)`)
- Create: `tools/blender/build_engineer.py`

**Interfaces:**
- Consumes: `sculpt.*` (Task 2), `render_turntable.render_views` (Task 3), `build_character_assets.Skeleton`, `HIPS`, `SPINE`, `CHEST`, `HEAD`, `shade`.
- Produces: `build_engineer.ENGINEER_PROPORTIONS`, `build_organic(s, level, detail, materials) -> dict[str, Object]` (chiavi: `body`, `head`, `shirt`, `overalls`, `boots`, `hair`, `cable`, `face`, `sleeves`), `build_gear(rb, s) -> dict` (posizioni utili: `pack_z`, `sack_center`), e la riga di comando `-- --clay` che scrive `output/engineer/clay/` (argilla) e `output/engineer/clay_colors/` (zone).

- [ ] **Step 1: Proporzioni parametriche nello scheletro**

In `build_character_assets.py`:

```python
class Skeleton:
    """Lo scheletro della libreria, riproporzionato, con le sole animazioni scelte."""

    def __init__(self, proportions=None):
        self.proportions = PROPORTIONS if proportions is None else proportions
        bpy.ops.import_scene.gltf(filepath=LIBRARY)
        ...
```
e in `_reproportion` sostituire `PROPORTIONS.get(` con `self.proportions.get(`. In `build_pack_sack` aggiungere `sack_center=None` e usarlo (`sack_center = sack_center or (0.0, 0.3, pack_z - 0.56)`, la striscia resta a `x = sack_center[0] - 0.2`, stessa `y` e `z` della sacca). Rieseguire lo Step 5 del Task 1: `player_engineer_d074` deve uscire identico (`ASSET_EXPORTED` con gli stessi `tris` e `bones` di prima).

- [ ] **Step 2: Scrivere `build_engineer.py` con la prima forma**

Il file contiene: palette, proporzioni, il grafo del corpo, testa e viso, capelli e cavo, abiti, accessori, la riga di comando. Prima versione (i numeri sono il punto di partenza: lo Step 4 li ritocca guardando le anteprime):

```python
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
        hip = node(s.head("DEF-thigh" + side), 0.15)
        knee = node(s.head("DEF-shin" + side), 0.12)
        ankle = node(s.head("DEF-foot" + side), 0.1)
        toe = node(s.tail("DEF-toe" + side) + Vector((0, -0.04, 0)), 0.09)
        edges += [(pelvis, hip), (hip, knee), (knee, ankle), (ankle, toe)]
        shoulder = node(s.head("DEF-upper_arm" + side), 0.13)
        elbow = node(s.head("DEF-forearm" + side), 0.105)
        wrist = node(s.head("DEF-hand" + side), 0.095)
        sign = 1.0 if side == ".L" else -1.0
        palm = node(s.head("DEF-hand" + side) + Vector((sign * 0.1, 0, 0)), (0.12, 0.09))
        mitt = node(s.head("DEF-hand" + side) + Vector((sign * 0.24, -0.01, -0.01)), (0.11, 0.075))
        thumb_base = node(s.head("DEF-hand" + side) + Vector((sign * 0.08, -0.1, 0.0)), 0.055)
        thumb_tip = node(s.head("DEF-hand" + side) + Vector((sign * 0.15, -0.17, 0.02)), 0.045)
        edges += [(ribs, shoulder), (shoulder, elbow), (elbow, wrist), (wrist, palm), (palm, mitt),
                  (palm, thumb_base), (thumb_base, thumb_tip)]
    return nodes, edges


def _shape_body(body, s):
    """Pennelli di forma sul corpo: pancia tonda in fuori, seno basso, spalle e polpacci."""
    waist = s.head(SPINE)
    chest = s.head(CHEST)
    sculpt.grab(body, waist + Vector((0, -0.25, 0.05)), 0.32, (0, -0.1, -0.02), scale=(1.0, 0.8, 0.9))
    sculpt.inflate(body, chest + Vector((0, -0.2, -0.08)), 0.2, 0.03, scale=(1.4, 1.0, 0.8))
    for side in (".L", ".R"):
        sculpt.inflate(body, s.head("DEF-upper_arm" + side), 0.16, 0.025)
        knee = s.head("DEF-shin" + side)
        ankle = s.head("DEF-foot" + side)
        sculpt.inflate(body, (knee + ankle) * 0.5 + Vector((0, 0.06, 0)), 0.12, 0.02)
        hand = s.head("DEF-hand" + side)
        sign = 1.0 if side == ".L" else -1.0
        # Muffola: tre dita grosse divise da due solchi.
        for dz in (-0.025, 0.025):
            a = hand + Vector((sign * 0.16, -0.09, dz))
            b = hand + Vector((sign * 0.33, -0.09, dz))
            sculpt.crease_line(body, [a, b], 0.018, 0.012)


def _head(s, level):
    """Testa grande a uovo, mento alto e sporgente, naso grosso e storto, guance."""
    top = s.head(HEAD)
    rings = []
    profile = [(-0.02, 0.1, 0.1), (0.04, 0.2, 0.19), (0.13, 0.25, 0.24), (0.24, 0.27, 0.26),
               (0.34, 0.26, 0.25), (0.42, 0.22, 0.21), (0.49, 0.14, 0.13), (0.53, 0.05, 0.05)]
    for z, rx, ry in profile:
        rings.append(sculpt.Ring(top + Vector((0, -0.02, z)), rx, ry, sides=16))
    head = sculpt.loft("Head", rings)
    sculpt.subdivide(head, level)
    face_y = top.y - 0.27
    sculpt.grab(head, top + Vector((0, -0.2, 0.04)), 0.1, (0, -0.06, 0.02), scale=(1.4, 1.0, 0.8))   # mento
    sculpt.grab(head, top + Vector((0.01, -0.25, 0.2)), 0.07, (0.02, -0.09, -0.01), scale=(0.8, 1.0, 1.1))  # naso storto
    sculpt.inflate(head, top + Vector((0.025, face_y - 0.07, 0.19)), 0.045, 0.025)  # punta del naso
    for sign in (1.0, -1.0):
        sculpt.inflate(head, top + Vector((sign * 0.13, -0.2, 0.15)), 0.07, 0.025)  # guance
        sculpt.grab(head, top + Vector((sign * 0.09, -0.24, 0.29)), 0.06, (0, -0.025, 0.0))  # arcate
        sculpt.crease_line(head, [top + Vector((sign * 0.05, -0.27, 0.25)), top + Vector((sign * 0.13, -0.25, 0.255))],
                           0.014, 0.012)  # occhi socchiusi
    sculpt.crease_line(head, [top + Vector((-0.09, -0.25, 0.1)), top + Vector((0.0, -0.27, 0.095)),
                              top + Vector((0.1, -0.25, 0.115))], 0.012, 0.01)  # ghigno
    return head


def build_organic(s, level, detail, materials):
    """Parti organiche al livello di suddivisione `level`; `detail` aggiunge i pennelli fini
    (solo per la versione alta). Ogni parte ha il colore per angolo e il materiale."""
    suit = materials["suit"]
    nodes, edges = _body_graph(s)
    base = sculpt.skin_body("BodyBase", nodes, edges)
    waist_z = s.head(SPINE).z
    chest_z = s.head(CHEST).z
    neck_z = s.tail(CHEST).z
    hips_z = s.head(HIPS).z
    parts = {}
    # Abiti estratti dalla gabbia prima della suddivisione: seguono il corpo come quelli veri.
    parts["shirt"] = sculpt.extract_shell(base, "Shirt", lambda p: waist_z - 0.06 < p.z < neck_z - 0.06
                                          and abs(p.x) < 0.32, 0.012, 0.01)
    parts["overalls"] = sculpt.extract_shell(base, "Overalls", lambda p: 0.2 < p.z < waist_z + 0.02
                                             and abs(p.x) < 0.45, 0.02, 0.014)
    parts["boots"] = sculpt.extract_shell(base, "Boots", lambda p: p.z < 0.24 and abs(p.x) < 0.45, 0.025, 0.02)
    parts["cuffs"] = sculpt.extract_shell(base, "Cuffs", lambda p: abs(p.x) > 0.62 and abs(p.x) < 0.84
                                          and abs(p.z - chest_z - 0.12) < 0.2, 0.012, 0.01)
    parts["body"] = base
    for obj in parts.values():
        sculpt.subdivide(obj, level)
    _shape_body(parts["body"], s)
    sculpt.set_color(parts["body"], SKIN)
    sculpt.set_color(parts["shirt"], TANK)
    sculpt.set_color(parts["overalls"], SUIT_BLUE)
    sculpt.set_color(parts["boots"], BOOT)
    sculpt.set_color(parts["cuffs"], ORANGE)
    sculpt.tint(parts["shirt"], (0.08, -0.3, waist_z + 0.1), 0.12, OIL, 0.8)
    sculpt.tint(parts["shirt"], (-0.12, -0.28, chest_z - 0.05), 0.07, OIL, 0.6)
    # Maniche della tuta annodate davanti in vita: due tubi che si incrociano e un nodo.
    sleeve_rings = []
    for t in range(7):
        a = math.radians(-160.0 + t * 46.0)
        sleeve_rings.append(sculpt.Ring((math.cos(a) * 0.42, math.sin(a) * 0.36 - 0.02, waist_z - 0.03 - 0.01 * t),
                                        0.07, 0.06, axis="z", sides=10))
    parts["sleeves"] = sculpt.loft("Sleeves", sleeve_rings)
    sculpt.subdivide(parts["sleeves"], level)
    sculpt.set_color(parts["sleeves"], SUIT_BLUE)
    head = _head(s, level)
    sculpt.set_color(head, SKIN)
    top = s.head(HEAD)
    sculpt.tint(head, top + Vector((0.02, -0.33, 0.19)), 0.07, BLUSH, 0.85)
    for sign in (1.0, -1.0):
        sculpt.tint(head, top + Vector((sign * 0.14, -0.22, 0.15)), 0.07, BLUSH, 0.5)
    parts["head"] = head
    # Capelli: calotta a ciocche e crocchia dietro, legata dal cavo arancio con lo spinotto.
    cap = sculpt.loft("Hair", [sculpt.Ring(top + Vector((0, 0.03, z)), rx, ry, sides=16)
                               for z, rx, ry in ((0.3, 0.29, 0.29), (0.42, 0.27, 0.27), (0.52, 0.19, 0.2),
                                                 (0.58, 0.06, 0.06))])
    bun = sculpt.loft("Bun", [sculpt.Ring(top + Vector((0, y, 0.44)), r, r, axis="y", sides=12)
                              for y, r in ((0.22, 0.05), (0.27, 0.11), (0.34, 0.12), (0.4, 0.08), (0.43, 0.02))])
    for obj in (cap, bun):
        sculpt.subdivide(obj, level)
        sculpt.set_color(obj, HAIR)
    for i in range(7):
        a = math.radians(-60.0 + i * 20.0)
        sculpt.crease_line(cap, [top + Vector((math.sin(a) * 0.2, -math.cos(a) * 0.2 + 0.03, 0.56)),
                                 top + Vector((math.sin(a) * 0.3, -math.cos(a) * 0.3 + 0.03, 0.3))], 0.02, 0.012)
    parts["hair"] = cap
    parts["bun"] = bun
    parts["cable"] = sculpt.loft("Cable", [sculpt.Ring(top + Vector((0, y, 0.44)), 0.115, 0.115, axis="y", sides=12)
                                           for y in (0.29, 0.32)])
    sculpt.subdivide(parts["cable"], level)
    sculpt.set_color(parts["cable"], ORANGE)
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
    sculpt.fold_noise(parts["sleeves"], lambda p: True, 0.01, 12.0, seed=3)
    top = s.head(HEAD)
    for k in range(3):
        z = 0.33 + 0.025 * k
        sculpt.crease_line(parts["head"], [top + Vector((-0.1, -0.25, z)), top + Vector((0.1, -0.25, z))], 0.008, 0.004)
    for sign in (1.0, -1.0):
        sculpt.crease_line(parts["head"], [top + Vector((sign * 0.06, -0.27, 0.16)), top + Vector((sign * 0.1, -0.24, 0.1))],
                           0.01, 0.006)  # pieghe naso-labbra
    sculpt.crease_line(parts["head"], [top + Vector((-0.17, -0.2, 0.27)), top + Vector((-0.12, -0.22, 0.18))],
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
    rb.box(CHEST, (0.05, 0.03, 1.1), (0.0, 0.6, pack_z + 0.05), ORANGE, mat="suit", rot=(0.0, -38.0, 0.0), bevel=0.01)
    # Lanterna da segnale ferroviario sulla spalla destra.
    shoulder = s.head("DEF-upper_arm.R")
    rb.box("DEF-shoulder.R", (0.14, 0.14, 0.18), (shoulder.x + 0.05, 0.12, shoulder.z + 0.2), DARK_METAL, bevel=0.02)
    rb.cyl("DEF-shoulder.R", 0.05, 0.03, (shoulder.x + 0.05, 0.04, shoulder.z + 0.2), LANTERN_GLASS, mat="lamp",
           axis="y", sides=14, bevel=0.005)
    rb.cyl("DEF-shoulder.R", 0.012, 0.12, (shoulder.x + 0.05, 0.12, shoulder.z + 0.33), STEEL, axis="x", sides=8)
    # Fiaschetta all'anca sinistra, attrezzi alla cintura.
    rb.box(HIPS, (0.04, 0.12, 0.16), (0.36, -0.04, waist_z - 0.12), STEEL, bevel=0.015)
    rb.box(HIPS, (0.62, 0.46, 0.06), (0.0, 0.0, waist_z - 0.08), LEATHER, mat="suit", bevel=0.02)
    rb.box(HIPS, (0.03, 0.03, 0.18), (-0.3, -0.2, waist_z - 0.15), DARK_METAL, rot=(0.0, 15.0, 0.0), bevel=0.006)
    rb.cyl(HIPS, 0.05, 0.03, (-0.22, -0.26, waist_z - 0.11), (0.2, 0.2, 0.22), axis="y", sides=14)
    # Sigaro spento all'angolo della bocca.
    rb.cyl(HEAD, 0.018, 0.14, (top.x + 0.08, top.y - 0.33, top.z + 0.1), CIGAR, mat="suit", axis="y",
           rot=(0.0, 0.0, -25.0), sides=10, bevel=0.004)
    # Chiodatrice da binari nella destra: corpo, caricatore, punta.
    grip = s.head("DEF-hand.R") + Vector((-0.1, 0.0, 0.0))
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
```

- [ ] **Step 3: Prima anteprima**

```bash
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_engineer.py -- --clay 2>&1 | grep "SKELETON\|ENGINEER_CLAY\|TURNTABLE\|Error\|Traceback" 
```
Atteso: `SKELETON leg_ratio=...`, due righe `TURNTABLE`, `ENGINEER_CLAY tris=... height=...`. Criteri numerici: `height` 1,6-1,8 m (la capsula è 1,76); `tris` entro 28.000 a livello 1 (se di più, scendere a `sides` minori nei loft prima di toccare il livello).

- [ ] **Step 4: Iterare sulla forma guardando le anteprime**

Aprire con Read `output/engineer/clay/turn_0.png`, `turn_2.png`, `turn_4.png`, `face.png`, `game_back.png`, `game_zoom.png` e `output/engineer/clay_colors/turn_0.png`. Lista di controllo, da soddisfare tutta prima dello stop (annotare per ogni giro cosa si è cambiato nel messaggio di commit):

1. circa 3 teste di altezza (testa = `HEAD_HEIGHT` circa un terzo della figura), collo quasi assente;
2. pancia tonda che sporge davanti più del petto nel profilo (`turn_2`);
3. mani a muffola grandi (larghezza della mano ≥ larghezza della testa × 0,45), pollice leggibile;
4. naso grosso e storto, mento alto e sporgente, occhi socchiusi, ghigno con il sigaro (`face.png`);
5. capelli a ciocche con crocchia e cavo arancio visibili da dietro (`turn_4`);
6. tuta abbassata in vita con maniche annodate davanti, canottiera, stivaloni, manicotti arancio;
7. nella vista di gioco (`game_back`, `game_zoom`) la silhouette si legge: testa, zaino, chiave in diagonale, lanterna;
8. nessuna compenetrazione visibile fra abiti e corpo, nessun buco, nessun pezzo che galleggia.

Ritocchi ammessi: numeri di `_body_graph`, `ENGINEER_PROPORTIONS`, `_head`, pennelli, predicati degli abiti, posizioni degli accessori. Se lo Skin modificatore dà giunture brutte fra spalle e busto, aggiungere un nodo intermedio sull'arco. Rieseguire lo Step 3 a ogni giro.

- [ ] **Step 5: Commit della forma**

```bash
git add tools/blender/build_character_assets.py tools/blender/build_engineer.py
git commit -m "Ingegnere D-088 in argilla: corpo da grafo, testa scolpita, abiti estratti, capelli con cavo, accessori; anteprime in output/engineer/clay"
```

- [ ] **Step 6: STOP — giudizio del proprietario**

Mostrare al proprietario `output/engineer/clay/` (`turn_0`, `turn_2`, `turn_4`, `face`, `game_back`, `game_zoom`) e `clay_colors/turn_0`. Chiedere **Continua / Modifica / Scarta**. Con Modifica: tornare allo Step 4 con le sue indicazioni. Con Scarta: fermare il piano e riaprire il brainstorming. Si va al Task 5 solo con **Continua**.

---

### Task 5: Versione alta, pesi, cottura, export e autoverifica Blender

**Files:**
- Modify: `tools/blender/refined.py` (`join`, `unwrap`, cottura della normal dalla versione alta)
- Modify: `tools/blender/painter.py` (`bake_normal_from_high`)
- Modify: `tools/blender/build_engineer.py` (`build_and_export`)
- Create: `tools/blender/check_engineer.py`
- Regenerate: `godot/assets/models/player_engineer.glb` e le tre texture estratte

**Interfaces:**
- Consumes: `build_organic`, `build_gear`, `ENGINEER_PROPORTIONS` (Task 4); `Skeleton`, `build_pack_sack(skeleton, pack_z, sack_center)`, `export` (Task 1 e 4).
- Produces: `RefinedBuilder.join(name, extra=()) -> Object`, `RefinedBuilder.unwrap(obj)`, `RefinedBuilder.bake(obj, name, high_objects=None)`; `painter.bake_normal_from_high(low, highs, image, extrusion, max_ray)`; `player_engineer.glb` con superfici `suit`, `gear`, `lamp`, nodo `PackSack`; riga `ENGINEER_CHECK PASS|FAIL`.

- [ ] **Step 1: Scrivere `check_engineer.py` (fallisce sul modello attuale: troppi triangoli e niente pesi da verificare come attesi)**

```python
"""Autoverifica dell'Ingegnere esportato (D-088). Eseguire:
    blender -b --factory-startup --python tools/blender/check_engineer.py
Confronta godot/assets/models/player_engineer.glb con la copia del modello D-074 in
output/engineer/before/ (stessi nomi delle ossa) e controlla triangoli, clip, superfici,
sacca, pesi e UV. Stampa `ENGINEER_CHECK PASS|FAIL failures=N`."""
import os
import sys

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
NEW = os.path.join(ROOT, "godot", "assets", "models", "player_engineer.glb")
OLD = os.path.join(ROOT, "output", "engineer", "before", "player_engineer_d074.glb")
CLIPS = 13
TRIS = (20000, 28000)

failures = 0


def check(condition, label):
    global failures
    if condition:
        print("  ok   %s" % label)
    else:
        failures += 1
        print("  FAIL %s" % label)


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    meshes = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
    return rig, meshes


old_rig, _ = load(OLD)
old_bones = sorted(b.name for b in old_rig.data.bones)
rig, meshes = load(NEW)
check(sorted(b.name for b in rig.data.bones) == old_bones, "stessi nomi delle ossa del modello D-074 (%d)" % len(old_bones))
check(len(bpy.data.actions) == CLIPS, "%d clip (attese %d)" % (len(bpy.data.actions), CLIPS))
body = next((o for name, o in meshes.items() if name.startswith("PlayerEngineerMesh")), None)
check(body is not None, "mesh del corpo PlayerEngineerMesh")
check(any(name.startswith("PackSack") for name in meshes), "sacca PackSack presente")
if body is not None:
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    check(TRIS[0] <= tris <= TRIS[1], "triangoli %d in %s" % (tris, TRIS))
    names = sorted(m.name for m in body.data.materials)
    check(names == ["gear", "lamp", "suit"], "superfici suit, gear, lamp (%s)" % ", ".join(names))
    unweighted = sum(1 for v in body.data.vertices if sum(g.weight for g in v.groups) < 0.99)
    check(unweighted == 0, "ogni vertice pesato (senza peso: %d)" % unweighted)
    over = sum(1 for v in body.data.vertices if sum(1 for g in v.groups if g.weight > 0.0) > 4)
    check(over == 0, "al massimo 4 ossa per vertice (oltre: %d)" % over)
    uv = body.data.uv_layers.active
    outside = sum(1 for d in uv.data if not (-1e-4 <= d.uv.x <= 1.0001 and -1e-4 <= d.uv.y <= 1.0001)) if uv else -1
    check(outside == 0, "UV dentro l'atlante (fuori: %d)" % outside)
    images = {img.size[0] for img in bpy.data.images if img.size[0] > 0}
    check(images == {2048}, "texture a 2048 (%s)" % sorted(images))
    zs = [v.co.z for v in body.data.vertices]
    check(1.55 <= max(zs) - min(zs) <= 1.85, "altezza a riposo %.2f m" % (max(zs) - min(zs)))
print("ENGINEER_CHECK %s failures=%d" % ("PASS" if failures == 0 else "FAIL", failures))
sys.exit(1 if failures else 0)
```

Nota: l'import glTF porta Y in alto in Blender come Z (l'importer converte): le altezze si leggono su Z.

```bash
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/check_engineer.py 2>&1 | grep "ok\|FAIL\|ENGINEER_CHECK"
```
Atteso sul modello D-074: `FAIL` (triangoli 28,3k fuori intervallo e texture a 1024 o 2048 secondo il modello), il resto informativo.

- [ ] **Step 2: Cottura della normal dalla versione alta in `painter.py`**

```python
def bake_normal_from_high(low, highs, image, extrusion=0.03, max_ray=0.08):
    """Normal map in spazio tangente cotta dalle superfici `highs` sulla `low` (attiva).
    Le `highs` hanno solo bisogno di geometria liscia; la `low` di un nodo immagine attivo
    (bersaglio) in ogni materiale."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    bake = scene.render.bake
    bake.use_selected_to_active = True
    bake.use_cage = False
    bake.cage_extrusion = extrusion
    bake.max_ray_distance = max_ray
    bake.normal_space = "TANGENT"
    for mat in low.data.materials:
        tree = mat.node_tree
        tree.nodes.clear()
        out = tree.nodes.new("ShaderNodeOutputMaterial")
        bsdf = tree.nodes.new("ShaderNodeBsdfDiffuse")
        tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        _bake_target(tree.nodes, image)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in highs:
        obj.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.bake(type="NORMAL")
    bake.use_selected_to_active = False
```

- [ ] **Step 3: Separare le fasi di `RefinedBuilder.to_object`**

In `refined.py`, sostituire `to_object` con tre metodi più `to_object` che li compone (comportamento invariato per gli altri costruttori):

```python
    def join(self, name, extra=()):
        """Unisce i pezzi (e gli oggetti `extra`, gia con materiali di questo costruttore)."""
        bpy.ops.object.select_all(action="DESELECT")
        for piece in list(self.pieces) + list(extra):
            piece.select_set(True)
        bpy.context.view_layer.objects.active = self.pieces[0]
        bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
        obj.name = name
        obj.data.name = name
        attribute = obj.data.color_attributes["Col"]
        obj.data.color_attributes.active_color = attribute
        obj.data.color_attributes.render_color_index = obj.data.color_attributes.find("Col")
        return obj

    @staticmethod
    def unwrap(obj):
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.008)
        bpy.ops.object.mode_set(mode="OBJECT")

    def to_object(self, name, skeleton=None, blends=None):
        """Unisce i pezzi, apre le UV, cuoce. `blends`: vedi `_blend_weights`."""
        if skeleton is not None:
            for piece in self.pieces:
                for group in piece.vertex_groups:
                    if group.name not in skeleton.joints:
                        raise RuntimeError("Osso inesistente: %s" % group.name)
        obj = self.join(name)
        self.unwrap(obj)
        self.bake(obj, name)
        if skeleton is not None:
            for blend in blends or ():
                self._blend_weights(obj, *blend)
            obj.parent = skeleton.obj
            obj.modifiers.new("Armature", "ARMATURE").object = skeleton.obj
        return obj
```

Rinominare `_bake(self, obj, name)` in `bake(self, obj, name, high_objects=None)` e, nel suo corpo, al posto della normal procedurale:

```python
        normal = None
        if high_objects:
            normal = bpy.data.images.new(name + "_normal", self.bake_size, self.bake_size)
            normal.colorspace_settings.name = "Non-Color"
            painter.bake_normal_from_high(obj, high_objects, normal)
            normal.pack()
        elif self.bake_normal:
            scene.render.bake.normal_space = "TANGENT"
            normal = bake_pass("_normal", "Non-Color", painter.paint_normal_graph, "NORMAL", 4)
```
L'albedo va cotta **dopo** la normal (la normal svuota i grafi dei materiali; `bake_pass` li ricostruisce): spostare la riga `albedo = bake_pass(...)` dopo il blocco della normal. Verifica di non regressione: `selftest_painter.py` deve restare `PAINTER_SELFTEST PASS`.

- [ ] **Step 4: `build_and_export` in `build_engineer.py`**

```python
def _weights(s, parts):
    """Corpo con i pesi automatici; abiti, maniche e capelli li ricevono dal corpo per
    vicinanza; la testa e cio che le sta sopra sono rigidi su DEF-head."""
    body = parts["body"]
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    s.obj.select_set(True)
    bpy.context.view_layer.objects.active = s.obj
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    for modifier in [m for m in body.modifiers if m.type == "ARMATURE"]:
        body.modifiers.remove(modifier)
    body.parent = None
    missing = sum(1 for v in body.data.vertices if sum(g.weight for g in v.groups) < 0.99)
    if missing:
        raise RuntimeError("Pesi automatici falliti su %d vertici del corpo: semplificare le giunture" % missing)
    for key in ("shirt", "overalls", "boots", "cuffs", "sleeves"):
        obj = parts[key]
        for group in body.vertex_groups:
            obj.vertex_groups.new(name=group.name)
        transfer = obj.modifiers.new("Weights", "DATA_TRANSFER")
        transfer.object = body
        transfer.use_vert_data = True
        transfer.data_types_verts = {"VGROUP_WEIGHTS"}
        transfer.vert_mapping = "POLYINTERP_NEAREST"
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.datalayout_transfer(modifier=transfer.name)
        bpy.ops.object.modifier_apply(modifier=transfer.name)
    for key in ("head", "hair", "bun", "cable"):
        group = parts[key].vertex_groups.new(name=HEAD)
        group.add(list(range(len(parts[key].data.vertices))), 1.0, "REPLACE")


def build_and_export(s):
    rb = RefinedBuilder(paint_name="suit", bake_normal=False)
    low = build_organic(s, LOW_LEVEL, False, rb.materials)
    gear = build_gear(rb, s)
    high = build_organic(s, HIGH_LEVEL, True, rb.materials)
    high_objects = list(high.values())
    for piece in rb.pieces:
        twin = piece.copy()
        twin.data = piece.data.copy()
        bpy.context.collection.objects.link(twin)
        high_objects.append(twin)
    _weights(s, low)
    obj = rb.join("PlayerEngineerMesh", extra=list(low.values()))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    rb.unwrap(obj)
    if s.obj.data.pose_position != "REST":
        raise RuntimeError("Lo scheletro deve stare a riposo durante la cottura")
    rb.bake(obj, "PlayerEngineerMesh", high_objects=high_objects)
    for twin in high_objects:
        bpy.data.objects.remove(twin, do_unlink=True)
    obj.parent = s.obj
    obj.modifiers.new("Armature", "ARMATURE").object = s.obj
    sack = build_pack_sack(s, gear["pack_z"], gear["sack_center"])
    s.obj.data.pose_position = "POSE"
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print("ENGINEER_BUILT tris=%d" % tris)
    export(s, obj, "player_engineer", "PlayerEngineer", "NONE", [sack])
```
(Togliere lo stub `raise NotImplementedError` del Task 4.)

- [ ] **Step 5: Costruire, verificare, importare**

```bash
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_engineer.py 2>&1 | grep "SKELETON\|BAKED\|ENGINEER_BUILT\|ASSET_EXPORTED\|Error\|Traceback"
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/check_engineer.py 2>&1 | grep "FAIL\|ENGINEER_CHECK"
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/selftest_painter.py 2>&1 | grep "PAINTER_SELFTEST"
godot_console --headless --path godot --editor --quit
godot_console --headless --path godot --script res://tests/tools/inspect_model.gd --quit-after 100 -- --model=player_engineer
```
Atteso: `ENGINEER_CHECK PASS failures=0`, `PAINTER_SELFTEST PASS`; `inspect_model` mostra le superfici `suit`, `gear`, `lamp` con `normal=true` e `orm=true`. Controllare negli `.import` di `player_engineer_PlayerEngineerMesh_{albedo,normal,orm}.png` che `compress/mode=2` (e `compress/normal_map=1` per la normal) e in `godot/.godot/imported/*.md5` che `vram_texture` sia vero; se no, applicare la procedura di `docs/GODOT_WORKFLOW.md` (cancellare `.md5` e `.ctex`, reimportare). Se `ENGINEER_CHECK` segnala triangoli fuori intervallo: ridurre i `sides` dei loft o i nodi dello Skin, non il livello.

- [ ] **Step 6: Anteprima dipinta**

```bash
"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python-expr "
import sys, bpy; sys.path.insert(0, 'tools/blender')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='godot/assets/models/player_engineer.glb')
import render_turntable
render_turntable.render_views([o for o in bpy.data.objects if o.type == 'MESH'], 'output/engineer/painted', mode='painted')
" 2>&1 | grep "TURNTABLE\|Error"
```
Guardare `turn_0`, `turn_4`, `face`: pittura alla Hades II (gradienti, pennellate, usura), canottiera macchiata, guance e naso arrossati, tuta blu stinta, arancio su manicotti, cinghie, cavo e chiodatrice; nessuna macchia nera da cottura sbagliata (raggi persi: alzare `max_ray`), nessuna cucitura evidente.

- [ ] **Step 7: Commit**

```bash
git add tools/blender/refined.py tools/blender/painter.py tools/blender/build_engineer.py tools/blender/check_engineer.py godot/assets/models/player_engineer*
git commit -m "Ingegnere D-088 nel gioco: versione alta cotta sulla bassa, pittura 2048, pesi automatici e trasferiti, scheletro a 3 teste, autoverifica"
```

---

### Task 6: Postura e stati di colore in Godot

**Files:**
- Create: `godot/scripts/core/posture_modifier.gd`
- Modify: `godot/scripts/core/character_animator.gd` (aggancio, `posture()`, morte e ripresa)
- Modify: `godot/scripts/player/player_character.gd:25-27,140-146,640-674` (tinta neutra, stati come emissione o scurimento, `body_material()`)
- Modify: `godot/tests/tools/capture_character.gd:9,69` (tuta bianca neutra)
- Test: `godot/tests/character_animator_tests.gd`, `godot/tests/player_tests.gd`

**Interfaces:**
- Produces: `PostureModifier.setup(skeleton: Skeleton3D, spine_bone: StringName, neck_bone: StringName, toe_bone: StringName) -> void`, `PostureModifier.belly_lean: float` (rad, default `deg_to_rad(8.0)`), `PostureModifier.chin_up: float` (rad, default `deg_to_rad(12.0)`), `PostureModifier.factor() -> float` (0..1, ultimo fattore di "busto dritto" applicato); `CharacterAnimator.posture() -> PostureModifier`; `CharacterAnimator.NECK_BONE := &"DEF-neck"`, `TOE_BONE := &"DEF-toe.L"`; `PlayerCharacter.body_material() -> StandardMaterial3D`.

- [ ] **Step 1: Test della postura (falliscono: `posture()` non esiste)**

In `character_animator_tests.gd`, prima di `print("Scavo, schivata, colpo, morte, interruttore")`:

```gdscript
	print("Postura (D-088)")
	_animator.set_locomotion(Vector3.ZERO, REFERENCE_SPEED)
	await _frames(30)
	var posture := _animator.posture()
	_check(posture != null and posture.active, "la postura e accesa")
	var toe := _skeleton.find_bone(CharacterAnimator.TOE_BONE)
	var front := _skeleton.get_bone_global_rest(toe).basis.y
	front = Vector3(front.x, 0.0, front.z).normalized()
	var head_on := _head_pose
	var chest_bone := _skeleton.find_bone(CharacterAnimator.CHEST_BONE)
	var chest_on := _skeleton.get_bone_global_pose(chest_bone).origin
	posture.active = false
	await _frames(3)
	var head_off := _head_pose
	var chest_off := _skeleton.get_bone_global_pose(chest_bone).origin
	posture.active = true
	await _frames(3)
	# Mento alto: il fronte della testa punta piu in su; pancia in fuori: il petto va indietro.
	var face_on := (head_on.basis * _skeleton.get_bone_global_rest(_head).basis.inverse() * front).y
	var face_off := (head_off.basis * _skeleton.get_bone_global_rest(_head).basis.inverse() * front).y
	_check(face_on > face_off + sin(posture.chin_up) * 0.5, "mento alto (fronte della testa %.2f -> %.2f)" % [face_off, face_on])
	_check((chest_on - chest_off).dot(front) < -0.01, "busto all'indietro (%.3f m)" % (chest_on - chest_off).dot(front))
	_check(_yaw_between(head_off, head_on) < 0.05, "la postura non gira la testa: la mira resta (%.3f rad)" % _yaw_between(head_off, head_on))
```

e dopo `_check(not tree.active and player.current_animation == CharacterAnimator.DEATH, ...)`:

```gdscript
	_check(not _animator.posture().active, "alla morte la postura si spegne")
```
dopo `_check(tree.active and not player.is_playing(), "revive rimette la miscela")`:

```gdscript
	_check(_animator.posture().active, "revive riaccende la postura")
```
e, subito dopo il controllo `lowest < standing - 0.15` della capriola, aggiungere la misura del fattore durante la capriola (Review Focus 4): spostare dentro il ciclo `for i in 40` la riga `min_factor = minf(min_factor, _animator.posture().factor())` con `var min_factor := 1.0` prima del ciclo, poi:

```gdscript
	_check(min_factor < 0.9, "durante la capriola la postura sfuma (fattore minimo %.2f)" % min_factor)
```

Aggiornare anche il controllo delle superfici: resta `suit`, `gear`, `lamp`. Il controllo d'altezza `bounds.size.y > 1.2` resta valido.

- [ ] **Step 2: Eseguire e vedere fallire**

```bash
godot_console --headless --path godot --fixed-fps 60 --quit-after 3000 --script res://tests/character_animator_tests.gd 2>&1 | tail -5
```
Atteso: errore di parsing `posture` non trovato (lo script non compila) oppure `FAIL`.

- [ ] **Step 3: `PostureModifier`**

`godot/scripts/core/posture_modifier.gd`:

```gdscript
class_name PostureModifier
extends SkeletonModifier3D
## Postura di carattere dell'Ingegnere (D-088): pancia in fuori (colonna all'indietro) e
## mento alto, aggiunti dopo ogni animazione come HipTwistModifier. Ruota attorno all'asse
## laterale del personaggio, quindi non cambia dove guarda: la mira resta. Sfuma quando il
## busto non e dritto (capriola, caduta) e si spegne alla morte (CharacterAnimator).

## Inclinazione all'indietro della colonna (rad).
@export var belly_lean := deg_to_rad(8.0)
## Testa in su rispetto alla colonna (rad).
@export var chin_up := deg_to_rad(12.0)

const UPRIGHT_MIN := 0.5
const UPRIGHT_FADE := 0.3

var _spine := -1
var _neck := -1
## Fronte del personaggio nello spazio dello scheletro, dalla punta del piede a riposo.
var _front := Vector3.BACK
var _factor := 0.0


## Lo scheletro si passa esplicito: appena aggiunto, get_skeleton() e ancora nullo.
func setup(skeleton: Skeleton3D, spine_bone: StringName, neck_bone: StringName, toe_bone: StringName) -> void:
	_spine = skeleton.find_bone(spine_bone)
	_neck = skeleton.find_bone(neck_bone)
	var toe := skeleton.find_bone(toe_bone)
	if toe >= 0:
		var direction := skeleton.get_bone_global_rest(toe).basis.y
		direction.y = 0.0
		if direction.length_squared() > 1e-4:
			_front = direction.normalized()


## Quanto della postura e stato applicato all'ultimo aggiornamento (0..1).
func factor() -> float:
	return _factor


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if _spine < 0:
		return
	var spine := skeleton.get_bone_global_pose(_spine)
	var turned := spine.basis.orthonormalized() * skeleton.get_bone_global_rest(_spine).basis.orthonormalized().inverse()
	_factor = clampf(((turned * Vector3.UP).y - UPRIGHT_MIN) / UPRIGHT_FADE, 0.0, 1.0)
	if is_zero_approx(_factor):
		return
	# Una rotazione positiva attorno a `side` porta "su" verso il fronte: qui serve il contrario.
	var side := Vector3.UP.cross(_front).normalized()
	spine.basis = Basis(side, -belly_lean * _factor) * spine.basis
	skeleton.set_bone_global_pose(_spine, spine)
	if _neck < 0:
		return
	var neck := skeleton.get_bone_global_pose(_neck)
	neck.basis = Basis(side, -chin_up * _factor) * neck.basis
	skeleton.set_bone_global_pose(_neck, neck)
```

- [ ] **Step 4: Agganciarlo in `CharacterAnimator`**

Costanti accanto a `CHEST_BONE`:

```gdscript
## Postura (D-088): collo per il mento alto, punta del piede per sapere dov'e il fronte.
const NECK_BONE := &"DEF-neck"
const TOE_BONE := &"DEF-toe.L"
```
campo `var _posture: PostureModifier`; in fondo a `_build`:

```gdscript
	_posture = PostureModifier.new()
	_posture.name = "Posture"
	skeleton.add_child(_posture)
	_posture.setup(skeleton, SPINE_BONE, NECK_BONE, TOE_BONE)
```
accessore:

```gdscript
## Postura di carattere (mento alto, pancia in fuori), dopo la torsione dei fianchi.
func posture() -> PostureModifier:
	return _posture
```
in `play_death` dopo `_twist.angle = 0.0`: `_posture.active = false`; in `revive` dopo `_tree.active = true`: `_posture.active = true`.

Poi `godot_console --headless --path godot --editor --quit` (nuova `class_name`) e `--check-only` sui due script:

```bash
godot_console --headless --path godot --check-only --script res://scripts/core/posture_modifier.gd
godot_console --headless --path godot --check-only --script res://scripts/core/character_animator.gd
```

- [ ] **Step 5: Eseguire i test della postura**

```bash
godot_console --headless --path godot --fixed-fps 60 --quit-after 3000 --script res://tests/character_animator_tests.gd 2>&1 | grep "FAIL\|PROTOTYPE01_TESTS"
```
Atteso: `PROTOTYPE01_TESTS PASS failures=0`. Se "busto all'indietro" fallisce col segno opposto, il fronte dedotto dal piede è invertito: controllare `_front` stampandolo una volta e correggere il segno in `setup`, non nel test.

- [ ] **Step 6: Test degli stati di colore (falliscono: `body_material()` non esiste)**

In `player_tests.gd`, chiamare `await _test_state_colors()` dopo `await _test_pack_gauge()` e aggiungere:

```gdscript
## Stati sulla tuta blu (D-088): neutro, scatto (bagliore), ricarica (scurita), colpo (lampo
## rosso); finito il lampo torna lo stato in corso, anche durante uno scatto.
func _test_state_colors() -> void:
	print("state colors")
	var player: PlayerCharacter = PlayerScene.instantiate()
	root.add_child(player)
	await _frames(2)
	var material := player.body_material()
	_check(material != null and material.albedo_color.is_equal_approx(Color.WHITE) and not material.emission_enabled,
		"a riposo la tuta e neutra: niente tinta, niente bagliore")
	player._set_state_color(player.tuning.dash_color_linear)
	_check(material.emission_enabled and material.emission.b > material.emission.r and material.albedo_color.is_equal_approx(Color.WHITE),
		"scatto: bagliore ciano, texture intatta")
	player._set_state_color(player.tuning.dash_cooldown_color_linear)
	_check(not material.emission_enabled and material.albedo_color.v < 0.8, "ricarica: tuta scurita, nessun bagliore")
	# Colpito mentre scatta: alla fine del lampo `_update_hit_flash` deve ripristinare lo
	# scatto. Passo fisico spento e lampo fatto scadere a mano: lo scatto vero (0,18 s)
	# finirebbe prima del lampo (0,3 s) e il test non direbbe nulla.
	player.set_physics_process(false)
	player.is_dashing = true
	player._set_state_color(player.tuning.dash_color_linear)
	player.on_hit()
	_check(material.emission_enabled and material.emission.r > 0.8 and material.emission.g < 0.3, "colpo: lampo rosso")
	player._update_hit_flash(PlayerCharacter.HIT_FLASH_SECONDS + 0.01)
	_check(material.emission_enabled and material.emission.b > material.emission.r,
		"finito il lampo durante lo scatto torna il bagliore dello scatto")
	player.is_dashing = false
	player._set_state_color(PlayerCharacter.BODY_COLOR_LINEAR)
	_check(material.albedo_color.is_equal_approx(Color.WHITE) and not material.emission_enabled, "fine ricarica: di nuovo neutra")
	player.queue_free()
```

```bash
godot_console --headless --path godot --fixed-fps 60 --quit-after 3000 --script res://tests/player_tests.gd 2>&1 | tail -4
```
Atteso: errore (`body_material` inesistente) o `FAIL`.

- [ ] **Step 7: Stati come emissione o scurimento in `PlayerCharacter`**

```gdscript
## Tuta neutra (D-088): il blu sta nella texture. Gli stati non la tingono piu: un colore
## grigio (ricarica, riposo) la scurisce o la lascia com'e, un colore acceso (scatto, colpo)
## la fa brillare per emissione, cosi resta leggibile su qualunque tinta della texture.
const BODY_COLOR_LINEAR := Color(1.0, 1.0, 1.0)
const HIT_COLOR_LINEAR := Color(1.0, 0.02, 0.02)
const HIT_FLASH_SECONDS := 0.3
## Sotto questa saturazione un colore di stato e un grigio: scurisce invece di brillare.
const STATE_GREY_SATURATION := 0.1
const STATE_GLOW_ENERGY := 0.9
```

```gdscript
func _set_body_color(linear_color: Color) -> void:
	if linear_color.s < STATE_GREY_SATURATION:
		_body_material.albedo_color = linear_color.linear_to_srgb()
		_body_material.emission_enabled = false
		return
	_body_material.albedo_color = Color.WHITE
	_body_material.emission_enabled = true
	_body_material.emission = linear_color.linear_to_srgb()
	_body_material.emission_energy_multiplier = STATE_GLOW_ENERGY


## Materiale della tuta costruito dal codice (stati di colore, test).
func body_material() -> StandardMaterial3D:
	return _body_material
```

In `on_hit()` sostituire `_body_material.albedo_color = HIT_COLOR_LINEAR.linear_to_srgb()` con `_set_body_color(HIT_COLOR_LINEAR)`. Aggiornare il commento in `_ready` ("La tuta: la tinta e lo stato (dash, colpo) va in `albedo_color`") in: "La tuta: texture cotta con la tinta neutra; gli stati passano da `_set_body_color` (D-088)". Controllare che `tuning.dash_cooldown_color_linear` (0,4 grigio) abbia saturazione < 0,1 e `dash_color_linear` (0,1/0,9/1,0) sopra: sì, valori in `player_tuning.gd:75-76`.

In `capture_character.gd` la costante diventa `const SUIT_COLOR_LINEAR := Color(1.0, 1.0, 1.0)` con commento "tuta neutra: il colore e nella texture (D-088)".

```bash
godot_console --headless --path godot --check-only --script res://scripts/player/player_character.gd
godot_console --headless --path godot --fixed-fps 60 --quit-after 3000 --script res://tests/player_tests.gd 2>&1 | grep "FAIL\|PROTOTYPE01_TESTS"
```
Atteso: `PROTOTYPE01_TESTS PASS failures=0`.

- [ ] **Step 8: Commit**

```bash
git add godot/scripts/core/posture_modifier.gd godot/scripts/core/posture_modifier.gd.uid godot/scripts/core/character_animator.gd godot/scripts/player/player_character.gd godot/tests/character_animator_tests.gd godot/tests/player_tests.gd godot/tests/tools/capture_character.gd
git commit -m "Postura di carattere (mento alto, pancia in fuori) e stati della tuta come bagliore o scurimento al posto della tinta arancione"
```

---

### Task 7: Catture finali, misure, gate e documenti

**Files:**
- Create: `output/engineer/` (catture, fuori da Git)
- Modify: `docs/DECISIONS.md` (D-088), `docs/ART_DIRECTION.md` (roster, riga 1 e "Questioni aperte": grado di caricatura deciso), `docs/PROJECT_ROADMAP.md` (Stato operativo e prossimo passo), `docs/MIGRATION_STATUS.md`, `docs/GODOT_WORKFLOW.md` (comandi di `build_engineer.py`, `check_engineer.py`, `render_turntable.py`, trappole incontrate), `docs/INDEX.md` (piano)

- [ ] **Step 1: Catture in gioco**

```bash
godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 600 --script res://tests/tools/capture_character.gd -- --out=../output/engineer
godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_motion.gd -- --out=../output/engineer/motion
godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_night.gd -- --out=../output/engineer/night
godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_district.gd -- --out=../output/engineer/district
```
Guardare con Read: `row_front`, `row_back`, `row_game` (postura visibile in tutte le pose tranne la caduta), `motion/player_*_strip.png` (niente braccia dentro la pancia nella mira e nello scavo, niente stivali che si compenetrano nella capriola; se sì: ritoccare `belly_lean` o il raggio della pancia e rifare), `night/` (lanterna accesa), `district/start.png` (leggibilità dalla camera di gioco accanto all'erba e all'orda). Confronto con `output/engineer/before/`. Proporzioni (spec 4.4): in `capture_run.gd -- --out=../output/engineer/run` i chiodi partono all'altezza della chiodatrice, l'anello del pennello è centrato davanti ai piedi e la sacca è sotto lo zaino; nelle tre distanze della camera la testa non esce dall'inquadratura. Idle di carattere: le clip esistenti non lo contengono, quindi è rimandato (spec 2 e 8) e va annotato in D-088.

- [ ] **Step 2: Misure**

```bash
godot_console --path godot --resolution 1280x800 --script res://tests/tools/benchmark_arena.gd -- --enemies=70 --preset=high 2>&1 | grep "ARENA_BENCH \(frame\|render\)"
```
Due giri, mediana di `avg_frame_ms`. Atteso entro i limiti dei Global Constraints rispetto a `output/engineer/before/bench.txt` (+0,3 ms, +3 % primitive). Se oltre: ridurre `HIGH_LEVEL` non serve (non va in gioco); ridurre i triangoli della bassa verso 20k.

- [ ] **Step 3: Gate completo**

```powershell
Get-Process godot* -ErrorAction SilentlyContinue | Stop-Process -Force
tools/godot/Invoke-GodotChecks.ps1
```
Atteso: `GODOT_CHECKS PASS`, tutte le suite verdi. Un fallimento in una suite che legge il modello (`actor_motion_tests`, `arena_run_tests`) si indaga con superpowers:systematic-debugging prima di toccare qualcosa.

- [ ] **Step 4: Documenti**

- `DECISIONS.md`, **D-088** (Provvisoria, giudizio del proprietario): scelte del 13 ottobre (caricatura forte a 3 teste, tuta blu stinto con accento arancio, gabbia a quadrilateri con scultura cotta, stop sull'argilla e suo esito), cosa è stato costruito (`sculpt.py`, `build_engineer.py`, `render_turntable.py`, `check_engineer.py`, `PostureModifier`, stati come emissione/scurimento), misure prima/dopo, trappole incontrate; aperti: giudizio sulle catture, Steam Deck non misurato.
- `ART_DIRECTION.md`: riga dell'Ingegnere aggiornata (lanterna sulla spalla, tuta blu, niente elmetto); in "Questioni aperte" il grado di caricatura diventa deciso (cartoon, 3 teste, D-088).
- `PROJECT_ROADMAP.md`, Stato operativo: voce del 13 ottobre 2026 e prossimo passo (giudizio del proprietario su `output/engineer/`, poi audio Sonniss D-084, poi stessi metodi sul compagno).
- `MIGRATION_STATUS.md`: nuovo "Ultimo aggiornamento" con fatto, verifiche, trappole, prossimo passo; il precedente scala sotto. Correggere anche la frase sulle simulazioni dei bot "in corso" (sono finite: `RAILWAY_LEVEL_SPEC.md` §8.1).
- `GODOT_WORKFLOW.md`: comandi verificati del Task 4-5 e le trappole trovate.
- `INDEX.md`: riga del piano.

- [ ] **Step 5: Commit e consegna**

```bash
git add docs/
git commit -m "Ingegnere D-088: catture, misure, gate verde e documenti"
```
Poi superpowers:finishing-a-development-branch: integrazione in `feature/arena-run` dopo il gate verde nel worktree; il **giudizio del proprietario sulle catture finali** resta aperto e va chiesto nella consegna.
