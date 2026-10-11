# Restyling grafico, piano 1: fetta visiva dell'ambiente

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Portare il cortile di partenza del quartiere (`arena_run.tscn`) alla nuova resa "stilizzato ricco": tile dipinte 2K su suolo, terrapieni e rovine, vegetazione e prop ridipinti, cielo dipinto e post-produzione nuova, preset grafici con opzioni singole, camera a tre distanze; catture prima/dopo e benchmark per il giudizio del proprietario.

**Architecture:** Un modulo Blender `painter.py` produce albedo/normal/ORM (occlusione, roughness, metallo) cotte a 2048 e tile ripetibili tramite coordinate toroidali nel rumore 4D; `refined.py` lo usa per tutti i modelli, `build_surface_tiles.py` per le tile del mondo esportate come `Texture2DArray`. In Godot gli shader esistenti conservano nomi e uniform per istanza e aggiungono i campionamenti delle texture; luce e post stanno in `OvergrownArena`; i preset grafici vivono in `GameSettingsService` e si applicano a viewport, `Environment` e sole; la camera a tre distanze sta in `IsometricCameraRig` con azioni di input nuove.

**Tech Stack:** Godot 4.7.2 (Forward+, GDScript), Blender 5.2.2 (bpy, Cycles bake su CPU), Git LFS per `.png` e `.glb`, gate `tools/godot/Invoke-GodotChecks.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-11-visual-restyle-design.md`

## Global Constraints

- Nessun asset esterno, nessuna generazione AI: tutto da `tools/blender/` (spec §1, punto 2).
- Identificatori, nomi di file e nodi in inglese; testi dei menu in italiano come i menu esistenti.
- Texture: 2048 per modelli grandi e tile, 1024 per prop piccoli; importate con compressione VRAM e mipmap; versionate in LFS (`*.png`, `*.glb` già coperti da `.gitattributes`).
- Stessi nomi di shader e stesse uniform per istanza (`tint`, `rust`, `overgrowth`, `base_tint`, `top_y`, `windows`, `vine_reach`, `cell_color`, `natural`, `state_tint`); le uniform per istanza di materiali diversi sullo stesso nodo devono avere lo stesso nome e tipo (trappola documentata in `GODOT_WORKFLOW.md`).
- Nodi `SunLight` e `WorldEnvironment` restano con questi nomi (DayNightCycle, test, catture li cercano).
- Soglie della fetta (spec §8): PC preset Alto ≤ 12 ms, Massimo ≤ 16 ms, draw call ≤ 450 (Alto) / 600 (Massimo), primitive ≤ 3 M / 4 M, VRAM texture ≤ 300 MB.
- Limite fps: 30, 60, 90, 120, 144, 165, 240, Illimitato (0); default 60.
- Gate verde (`powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1`) prima di ogni commit; `--check-only` su ogni script toccato.
- Comandi Godot: `godot_console --headless --path godot --fixed-fps 60 --script res://tests/<suite>.gd`; catture mai in headless, sempre con `--quit-after`.
- Comando Blender: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/<script>.py -- [nomi]`, poi `godot_console --headless --path godot --editor --quit` per importare.
- Le tre scene con `OvergrownArena` (`arena_run`, `railway_run`, `ruins_arena`) devono continuare ad aprirsi: ogni modifica a shader e materiali vale per tutte.
- Commit piccoli, messaggio in italiano, chiusi da `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

## Review Focus

1. **Worktree nuovo con LFS**: i `.glb` e `.png` possono essere puntatori LFS; l'import scrive `valid=false` negli `.import`. Test in Task 1: `inspect_model.gd` deve stampare `texture=true orm=true`; se no, `git lfs checkout` prima di reimportare.
2. **`settings.cfg` vecchio senza le chiavi nuove**: deve caricare senza errori con preset Alto, Deck se rilevato, e salvare conservando le chiavi sconosciute. Test in Task 9.
3. **Preset Massimo su GPU senza SDFGI stabile**: con `gi_mode = SDFGI` e camera isometrica l'illuminazione può sfarfallare; il preset deve poter ricadere su SSIL senza toccare gli altri valori. Test in Task 9 (il passaggio a SSIL lascia il preset Massimo come Personalizzato con gli altri campi invariati).
4. **Camera lontana e anello di comparsa**: a 20 m la finestra mostra 20 m in orizzontale, l'anello fisso 17-23 m renderebbe visibili le comparse. Test in Task 10: con distanza lontana `spawn_ring_min` effettivo ≥ 22 m.
5. **Scene senza `GameSettings`** (test con `--script`, `--check-only`): l'arena deve costruirsi anche quando l'autoload manca, con i valori del preset Alto. Test in Task 9 (`ruins_arena_tests` e `district_tests` restano verdi senza modifiche).

---

### Task 1: Pittore Blender (`painter.py`) con albedo, normal e ORM a 2048

**Files:**
- Create: `tools/blender/painter.py`
- Modify: `tools/blender/refined.py` (`BAKE_SIZE`, `__init__`, `_bake`, `_final_graph`, `to_object` margine UV, `StaticBuilder.__init__`)
- Modify: `godot/tests/tools/inspect_model.gd`
- Create: `tools/blender/selftest_painter.py`

**Interfaces:**
- Consumes: `refined.RefinedBuilder` (API attuale: `box`, `cyl`, `sphere`, `profile`, `to_object`, `_bake`, `_bake_graph`, `_normal_graph`, `_final_graph`).
- Produces: modulo `painter` con `paint_albedo_graph(mat, image, kind, style)`, `paint_orm_graph(mat, image, kind, style)`, `paint_normal_graph(mat, image, kind, style)`, `final_graph(mat, albedo, normal, orm, kind)`, `seamless_coords(nodes, links, radius=0.35)`, `STYLES` (dizionario per `kind`: `brush_scale`, `brush_dir`, `edge_color`, `rough_base`, `rough_wear`, `metal`, `gradient_top`, `gradient_bottom`); `RefinedBuilder(..., bake_size=2048, bake_normal=True, bake_orm=True)`; `StaticBuilder(bake_size=2048, bake_normal=True, bake_orm=True)`; `inspect_model.gd` stampa `orm=<bool> tris=<n>`.

- [ ] **Step 1: Scrivere il selftest che fallisce**

`tools/blender/selftest_painter.py` (eseguito in Blender, esce con 1 se fallisce):

```python
"""Selftest del pittore: cuoce un cubo e controlla le tre immagini.
blender -b --factory-startup --python tools/blender/selftest_painter.py
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
bpy.ops.wm.read_factory_settings(use_empty=True)
from refined import StaticBuilder

b = StaticBuilder(bake_size=256, bake_normal=True, bake_orm=True)
b.box((1.0, 1.0, 1.0), (0.0, 0.0, 0.5), (0.8, 0.3, 0.2), paint=True)
b.cyl(0.2, 0.6, (0.0, 0.0, 1.3), (0.5, 0.5, 0.5))
obj = b.to_object("SelfTest")
failures = 0
for suffix, colorspace in (("_albedo", "sRGB"), ("_normal", "Non-Color"), ("_orm", "Non-Color")):
    image = bpy.data.images.get("SelfTest" + suffix)
    if image is None or image.size[0] != 256 or image.colorspace_settings.name != colorspace:
        print("FAIL image %s" % suffix); failures += 1
        continue
    pixels = image.pixels[:]
    if max(pixels) <= 0.0:
        print("FAIL image %s is black" % suffix); failures += 1
orm = bpy.data.images.get("SelfTest_orm")
if orm is not None:
    px = orm.pixels[:]
    greens = px[1::4]
    if not (0.3 < sum(greens) / len(greens) < 0.95):
        print("FAIL orm roughness out of range"); failures += 1
mat = bpy.data.materials["paint"]
bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
if not bsdf.inputs["Roughness"].is_linked or not bsdf.inputs["Normal"].is_linked:
    print("FAIL principled not wired to orm/normal"); failures += 1
print("PAINTER_SELFTEST %s failures=%d" % ("PASS" if failures == 0 else "FAIL", failures))
sys.exit(1 if failures else 0)
```

- [ ] **Step 2: Eseguirlo e vedere che fallisce**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/selftest_painter.py`
Expected: `TypeError` su `bake_orm` (argomento inesistente) → exit 1.

- [ ] **Step 3: Scrivere `painter.py`**

```python
"""Pittore condiviso (spec §3.1): grafi Cycles per albedo dipinta, normal map e ORM.

Tutte le texture sono procedurali e parametriche. `seamless_coords` mappa le UV su un
toro nel rumore 4D, cosi una tile cotta su un piano si ripete senza cuciture.
"""
import math
import bpy

TWO_PI = 2.0 * math.pi

# Parametri di pittura per materiale semantico.
STYLES = {
    "paint": dict(brush_scale=14.0, brush_dir=(1.0, 0.25), edge_color=(0.92, 0.88, 0.80),
                  rough_base=0.72, rough_wear=0.45, metal=0.0, gradient_top=1.12, gradient_bottom=0.78),
    "gear":  dict(brush_scale=22.0, brush_dir=(0.3, 1.0), edge_color=(0.85, 0.82, 0.78),
                  rough_base=0.55, rough_wear=0.30, metal=0.35, gradient_top=1.08, gradient_bottom=0.82),
    "lamp":  dict(brush_scale=0.0, brush_dir=(1.0, 0.0), edge_color=(1.0, 1.0, 1.0),
                  rough_base=0.4, rough_wear=0.4, metal=0.0, gradient_top=1.0, gradient_bottom=1.0),
    "tile":  dict(brush_scale=10.0, brush_dir=(1.0, 0.0), edge_color=(0.9, 0.86, 0.8),
                  rough_base=0.85, rough_wear=0.6, metal=0.0, gradient_top=1.0, gradient_bottom=1.0),
}


def sock(sockets, identifier):
    for socket in sockets:
        if socket.identifier == identifier:
            return socket
    raise KeyError(identifier)


def _mix(nodes, links, a, b, factor, blend="MIX"):
    node = nodes.new("ShaderNodeMix")
    node.data_type = "RGBA"
    node.blend_type = blend
    if isinstance(factor, float):
        sock(node.inputs, "Factor_Float").default_value = factor
    else:
        links.new(factor, sock(node.inputs, "Factor_Float"))
    links.new(a, sock(node.inputs, "A_Color"))
    if isinstance(b, tuple):
        sock(node.inputs, "B_Color").default_value = (*b, 1.0)
    else:
        links.new(b, sock(node.inputs, "B_Color"))
    return sock(node.outputs, "Result_Color")


def _ramp(nodes, links, value, stops):
    """stops: lista di (posizione, (r, g, b))."""
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = stops[0][0]
    ramp.color_ramp.elements[0].color = (*stops[0][1], 1.0)
    ramp.color_ramp.elements[1].position = stops[-1][0]
    ramp.color_ramp.elements[1].color = (*stops[-1][1], 1.0)
    for position, color in stops[1:-1]:
        e = ramp.color_ramp.elements.new(position)
        e.color = (*color, 1.0)
    links.new(value, ramp.inputs["Fac"])
    return ramp.outputs["Color"]


def _math(nodes, links, op, a, b=None):
    node = nodes.new("ShaderNodeMath")
    node.operation = op
    if isinstance(a, float):
        node.inputs[0].default_value = a
    else:
        links.new(a, node.inputs[0])
    if b is not None:
        if isinstance(b, float):
            node.inputs[1].default_value = b
        else:
            links.new(b, node.inputs[1])
    return node.outputs["Value"]


def seamless_coords(nodes, links, radius=0.35):
    """UV (u, v) -> (vettore 3D, W) su un toro: il rumore 4D letto qui si ripete in u e v."""
    uv = nodes.new("ShaderNodeTexCoord").outputs["UV"]
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(uv, sep.inputs["Vector"])
    u = _math(nodes, links, "MULTIPLY", sep.outputs["X"], TWO_PI)
    v = _math(nodes, links, "MULTIPLY", sep.outputs["Y"], TWO_PI)
    cu = _math(nodes, links, "MULTIPLY", _math(nodes, links, "COSINE", u), radius)
    su = _math(nodes, links, "MULTIPLY", _math(nodes, links, "SINE", u), radius)
    cv = _math(nodes, links, "MULTIPLY", _math(nodes, links, "COSINE", v), radius)
    sv = _math(nodes, links, "MULTIPLY", _math(nodes, links, "SINE", v), radius)
    comb = nodes.new("ShaderNodeCombineXYZ")
    links.new(cu, comb.inputs["X"]); links.new(su, comb.inputs["Y"]); links.new(cv, comb.inputs["Z"])
    return comb.outputs["Vector"], sv


def _noise(nodes, links, coords, scale, detail=3.0, roughness=0.5, w=None):
    node = nodes.new("ShaderNodeTexNoise")
    node.noise_dimensions = "4D" if w is not None else "3D"
    node.inputs["Scale"].default_value = scale
    node.inputs["Detail"].default_value = detail
    node.inputs["Roughness"].default_value = roughness
    links.new(coords, node.inputs["Vector"])
    if w is not None:
        links.new(w, node.inputs["W"])
    return node.outputs["Fac"]


def _brush(nodes, links, coords, style, w=None):
    """Pennellate direzionali: rumore allungato lungo `brush_dir`, a bassa frequenza."""
    if style["brush_scale"] <= 0.0:
        return None
    mapping = nodes.new("ShaderNodeMapping")
    dx, dy = style["brush_dir"]
    length = math.hypot(dx, dy) or 1.0
    angle = math.atan2(dy, dx)
    mapping.inputs["Rotation"].default_value = (0.0, 0.0, angle)
    mapping.inputs["Scale"].default_value = (1.0, 6.0, 1.0)
    links.new(coords, mapping.inputs["Vector"])
    fac = _noise(nodes, links, mapping.outputs["Vector"], style["brush_scale"], 2.0, 0.4, w)
    return _ramp(nodes, links, fac, [(0.35, (0.90, 0.90, 0.90)), (0.65, (1.06, 1.06, 1.06))])


def _wear(nodes, links):
    geo = nodes.new("ShaderNodeNewGeometry")
    return _ramp(nodes, links, geo.outputs["Pointiness"], [(0.52, (0.0, 0.0, 0.0)), (0.66, (1.0, 1.0, 1.0))])


def _ao(nodes, links, distance=0.22):
    ao = nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = distance
    ao.samples = 8
    return ao.outputs["AO"]


def paint_albedo_graph(mat, image, kind, style=None, coords=None, w=None):
    """Albedo dipinta: rampa per volume, pennellate, usura sugli spigoli, AO dipinta, sporco verso terra."""
    style = style or STYLES[kind]
    tree = mat.node_tree; nodes, links = tree.nodes, tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    emit = nodes.new("ShaderNodeEmission")
    links.new(emit.outputs["Emission"], out.inputs["Surface"])
    base = nodes.new("ShaderNodeAttribute"); base.attribute_name = "Col"
    color = base.outputs["Color"]
    if coords is None:
        coords = nodes.new("ShaderNodeTexCoord").outputs["Object"]
    if kind != "lamp":
        # Rampa per volume: piu chiaro in alto, piu scuro e saturo in basso.
        z = nodes.new("ShaderNodeSeparateXYZ"); links.new(coords, z.inputs["Vector"])
        height = _math(nodes, links, "MULTIPLY", z.outputs["Z"], 0.5)
        grad = _ramp(nodes, links, height, [(0.0, (style["gradient_bottom"],) * 3), (1.0, (style["gradient_top"],) * 3)])
        color = _mix(nodes, links, color, grad, 1.0, "MULTIPLY")
        brush = _brush(nodes, links, coords, style, w)
        if brush is not None:
            color = _mix(nodes, links, color, brush, 1.0, "MULTIPLY")
        ao = _ramp(nodes, links, _ao(nodes, links), [(0.3, (0.55, 0.50, 0.52)), (0.95, (1.0, 1.0, 1.0))])
        color = _mix(nodes, links, color, ao, 1.0, "MULTIPLY")
        stains = _ramp(nodes, links, _noise(nodes, links, coords, 5.0, 3.0, 0.6, w),
                       [(0.42, (0.66, 0.58, 0.48)), (0.55, (1.0, 1.0, 1.0))])
        color = _mix(nodes, links, color, stains, 1.0, "MULTIPLY")
        # Usura sugli spigoli con colore proprio del materiale (bordo netto, non grana).
        color = _mix(nodes, links, color, style["edge_color"], _wear(nodes, links))
        # Sporco verso terra (solo modelli: le tile passano coords senza Z utile).
        if w is None:
            mud = nodes.new("ShaderNodeMapRange")
            mud.inputs["From Min"].default_value = 0.05; mud.inputs["From Max"].default_value = 0.6
            links.new(z.outputs["Z"], mud.inputs["Value"])
            color = _mix(nodes, links, (0.40, 0.30, 0.19), color, mud.outputs["Result"])
    links.new(color, emit.inputs["Color"])
    target = nodes.new("ShaderNodeTexImage"); target.image = image; nodes.active = target


def paint_orm_graph(mat, image, kind, style=None, coords=None, w=None):
    """ORM: R = occlusione, G = roughness (base, piu bassa dove consumato), B = metallo."""
    style = style or STYLES[kind]
    tree = mat.node_tree; nodes, links = tree.nodes, tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    emit = nodes.new("ShaderNodeEmission")
    links.new(emit.outputs["Emission"], out.inputs["Surface"])
    occlusion = _ao(nodes, links) if kind != "lamp" else _math(nodes, links, "ADD", 1.0, 0.0)
    wear = _wear(nodes, links)
    rough = _math(nodes, links, "MULTIPLY_ADD", wear, style["rough_wear"] - style["rough_base"])
    # MULTIPLY_ADD: wear * (rough_wear - rough_base) + rough_base
    rough_node = rough.node; rough_node.inputs[2].default_value = style["rough_base"]
    metal = _math(nodes, links, "ADD", style["metal"], 0.0)
    comb = nodes.new("ShaderNodeCombineColor")
    links.new(occlusion, comb.inputs["Red"]); links.new(rough, comb.inputs["Green"]); links.new(metal, comb.inputs["Blue"])
    links.new(comb.outputs["Color"], emit.inputs["Color"])
    target = nodes.new("ShaderNodeTexImage"); target.image = image; nodes.active = target


def paint_normal_graph(mat, image, kind, style=None, coords=None, w=None):
    """Rilievo procedurale (Bump su un BSDF) per la normal map in spazio tangente."""
    tree = mat.node_tree; nodes, links = tree.nodes, tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfDiffuse")
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    if kind != "lamp":
        if coords is None:
            coords = nodes.new("ShaderNodeTexCoord").outputs["Object"]
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Distance"].default_value = 0.002
        if kind == "paint":
            weave = _math(nodes, links, "ADD",
                          _noise(nodes, links, coords, 160.0, 1.0, 0.5, w), _noise(nodes, links, coords, 9.0, 2.0, 0.5, w))
            bump.inputs["Strength"].default_value = 0.35
            links.new(weave, bump.inputs["Height"])
        else:
            relief = _math(nodes, links, "MULTIPLY_ADD", _noise(nodes, links, coords, 40.0, 3.0, 0.6, w), 0.25)
            relief.node.inputs[2].default_value = 0.0
            relief = _math(nodes, links, "ADD", relief, _noise(nodes, links, coords, 70.0, 5.0, 0.5, w))
            bump.inputs["Strength"].default_value = 0.2 if kind == "gear" else 0.6
            links.new(relief, bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    target = nodes.new("ShaderNodeTexImage"); target.image = image; nodes.active = target


def final_graph(mat, albedo, normal, orm, kind, style=None):
    """Principled con le tre texture: l'export glTF porta albedo, normal e ORM (metallicRoughness + occlusion)."""
    style = style or STYLES[kind]
    tree = mat.node_tree; nodes, links = tree.nodes, tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    tex = nodes.new("ShaderNodeTexImage"); tex.image = albedo
    bsdf.inputs["Roughness"].default_value = style["rough_base"]
    if kind == "lamp":
        links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 3.0
        return
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if orm is not None:
        orm_tex = nodes.new("ShaderNodeTexImage"); orm_tex.image = orm
        sep = nodes.new("ShaderNodeSeparateColor")
        links.new(orm_tex.outputs["Color"], sep.inputs["Color"])
        links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
        # Occlusione: il gruppo "glTF Material Output" e cio che l'esportatore legge.
        group = bpy.data.node_groups.get("glTF Material Output")
        if group is None:
            group = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
            group.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
            group.nodes.new("NodeGroupInput")
        gnode = nodes.new("ShaderNodeGroup"); gnode.node_tree = group
        links.new(sep.outputs["Red"], gnode.inputs["Occlusion"])
    if normal is not None:
        ntex = nodes.new("ShaderNodeTexImage"); ntex.image = normal
        nmap = nodes.new("ShaderNodeNormalMap"); nmap.space = "TANGENT"
        links.new(ntex.outputs["Color"], nmap.inputs["Color"])
        links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
```

- [ ] **Step 4: Collegare `refined.py` al pittore**

In `tools/blender/refined.py`:

```python
import painter  # dopo gli import esistenti; i build script mettono la cartella in sys.path (vedi sotto)

BAKE_SIZE = 2048

class RefinedBuilder:
    def __init__(self, paint_name="paint", front_axis=-1.0, bake_size=BAKE_SIZE, bake_normal=True, bake_orm=True):
        ...  # come oggi, piu:
        self.bake_orm = bake_orm
```

`to_object`: margine UV da `island_margin=0.004` a `0.008` (mipmap a 2K).

`_bake` sostituita:

```python
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
```

Rimuovere `_bake_graph`, `_normal_graph`, `_final_graph` (ora in `painter.py`). `StaticBuilder.__init__(self, bake_size=BAKE_SIZE, bake_normal=True, bake_orm=True)` passa i tre valori a `super().__init__`.

In testa a `build_arena_assets.py`, `build_actor_assets.py`, `build_character_assets.py`, prima di `import refined`/`from refined import`: `sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))` (se non c'è già).

- [ ] **Step 5: Eseguire il selftest**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/selftest_painter.py`
Expected: `PAINTER_SELFTEST PASS failures=0`, exit 0. Se `ShaderNodeCombineColor`/`SeparateColor` non esistono in Blender 5.2, usare `ShaderNodeCombineRGB`/`ShaderNodeSeparateRGB` con prese `R`,`G`,`B`.

- [ ] **Step 6: Ricostruire un prop e verificare l'import dell'ORM**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_arena_assets.py -- concrete_barrier` poi `godot_console --headless --path godot --editor --quit`.

Estendere `godot/tests/tools/inspect_model.gd` nel ciclo delle superfici:

```gdscript
var std := mat as BaseMaterial3D
var orm := std != null and (std.roughness_texture != null or std.ao_texture != null)
print("  SURFACE %d name=%s texture=%s normal=%s orm=%s tris=%d" % [i, mat.resource_name if mat else "",
	std != null and std.albedo_texture != null, std != null and std.normal_enabled and std.normal_texture != null,
	orm, mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size() / 3])
```

Run: `godot_console --headless --path godot --script res://tests/tools/inspect_model.gd --quit-after 100 -- --model=concrete_barrier`
Expected: `texture=true normal=true orm=true`. Se `orm=false`: aprire il `.glb` come JSON (`python -c "import json,struct;..."`) e verificare `occlusionTexture`/`metallicRoughnessTexture`; se manca solo l'occlusione, è accettabile (l'AO è già nell'albedo) ma va annotato in `GODOT_WORKFLOW.md`.

- [ ] **Step 7: Gate e commit**

Run: `powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1` → `PASS`.

```bash
git add tools/blender/painter.py tools/blender/refined.py tools/blender/selftest_painter.py tools/blender/build_*.py godot/tests/tools/inspect_model.gd godot/assets/models/concrete_barrier*
git commit -m "Pittore Blender condiviso (painter.py): albedo dipinta, normal e ORM a 2048, selftest; barriera ricotta"
```

---

### Task 2: Tile di superficie come `Texture2DArray` (`build_surface_tiles.py`)

**Files:**
- Create: `tools/blender/build_surface_tiles.py`
- Create: `godot/assets/textures/surfaces/ground_albedo.png`, `ground_normal.png`, `ground_orm.png` (+ `.import` scritti a mano prima dell'import), stessi tre per `walls_*` e `plants_*`
- Create: `godot/tests/restyle_tests.gd` (prima parte)

**Interfaces:**
- Consumes: `painter.seamless_coords`, `painter.paint_*_graph`, `painter.STYLES["tile"]`.
- Produces: tre array verticali per gruppo. `ground` (5 strati, nell'ordine): 0 `dirt`, 1 `slabs`, 2 `asphalt`, 3 `dug_soil`, 4 `mud`. `walls` (3): 0 `plaster_brick`, 1 `moss`, 2 `bark`. `plants` (2, con alpha): 0 `grass_tufts`, 1 `leaf_cards`. Percorsi `res://assets/textures/surfaces/<group>_<map>.png`, importati come `Texture2DArray`.

- [ ] **Step 1: Test Godot che fallisce**

`godot/tests/restyle_tests.gd`:

```gdscript
extends SceneTree
## Restyling grafico (spec 2026-10-11): texture, uniform, preset, camera.
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/restyle_tests.gd
var _failures := 0

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_test_surface_tiles()
	await _frames(2)
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)

func _test_surface_tiles() -> void:
	print("surface tiles")
	var expected := {"ground": 5, "walls": 3, "plants": 2}
	for group: String in expected:
		for map in ["albedo", "normal", "orm"]:
			var path := "res://assets/textures/surfaces/%s_%s.png" % [group, map]
			var tex := load(path)
			_check(tex is Texture2DArray, "%s e un Texture2DArray" % path)
			if tex is Texture2DArray:
				_check(tex.get_layers() == expected[group], "%s ha %d strati" % [path, expected[group]])
				_check(tex.get_width() == 2048 and tex.get_height() == 2048, "%s e 2048x2048" % path)
				var fmt: int = tex.get_format()
				_check(fmt in [Image.FORMAT_DXT1, Image.FORMAT_DXT5, Image.FORMAT_BPTC_RGBA, Image.FORMAT_RGTC_RG, Image.FORMAT_DXT5_RA_AS_RG], "%s e compressa in VRAM (%d)" % [path, fmt])

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame
```

- [ ] **Step 2: Eseguire e vedere che fallisce**

Run: `godot_console --headless --path godot --fixed-fps 60 --script res://tests/restyle_tests.gd`
Expected: `FAIL ... e un Texture2DArray` (file assenti), `PROTOTYPE01_TESTS FAIL`.

- [ ] **Step 3: Scrivere `build_surface_tiles.py`**

```python
"""Tile dipinte e ripetibili del mondo (spec §3.3), cotte su un piano con coordinate toroidali.
blender -b --factory-startup --python tools/blender/build_surface_tiles.py -- [ground|walls|plants ...]
Ogni gruppo esce come tre PNG verticali (strati impilati) in godot/assets/textures/surfaces/.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import painter
from painter import _mix, _ramp, _noise, _math, sock

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "godot", "assets", "textures", "surfaces")
SIZE = 2048
SAMPLES = 32

# nome -> (colore_a, colore_b, scala_macro, scala_micro, roughness, alpha)
TILES = {
    "ground": [
        ("dirt",       (0.46, 0.34, 0.22), (0.30, 0.22, 0.14), 3.0, 18.0, 0.9, False),
        ("slabs",      (0.62, 0.58, 0.50), (0.42, 0.40, 0.35), 1.0, 14.0, 0.85, False),
        ("asphalt",    (0.26, 0.25, 0.24), (0.16, 0.15, 0.15), 2.0, 24.0, 0.8, False),
        ("dug_soil",   (0.52, 0.36, 0.20), (0.30, 0.20, 0.12), 4.0, 20.0, 0.95, False),
        ("mud",        (0.22, 0.17, 0.12), (0.12, 0.10, 0.08), 2.5, 12.0, 0.35, False),
    ],
    "walls": [
        ("plaster_brick", (0.78, 0.72, 0.60), (0.60, 0.32, 0.22), 1.0, 10.0, 0.85, False),
        ("moss",          (0.22, 0.38, 0.10), (0.45, 0.52, 0.16), 3.0, 16.0, 0.9, False),
        ("bark",          (0.40, 0.30, 0.20), (0.24, 0.18, 0.12), 2.0, 22.0, 0.9, False),
    ],
    "plants": [
        ("grass_tufts", (0.24, 0.42, 0.10), (0.58, 0.66, 0.20), 1.0, 8.0, 0.9, True),
        ("leaf_cards",  (0.18, 0.36, 0.10), (0.50, 0.60, 0.18), 1.0, 6.0, 0.9, True),
    ],
}


def tile_albedo_graph(mat, image, spec):
    name, col_a, col_b, macro, micro, rough, alpha = spec
    tree = mat.node_tree; nodes, links = tree.nodes, tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    emit = nodes.new("ShaderNodeEmission")
    links.new(emit.outputs["Emission"], out.inputs["Surface"])
    coords, w = painter.seamless_coords(nodes, links)
    macro_fac = _noise(nodes, links, coords, macro, 2.0, 0.5, w)
    base = _ramp(nodes, links, macro_fac, [(0.3, col_b), (0.7, col_a)])
    brush = painter._brush(nodes, links, coords, painter.STYLES["tile"], w)
    color = _mix(nodes, links, base, brush, 1.0, "MULTIPLY")
    micro_fac = _noise(nodes, links, coords, micro, 4.0, 0.6, w)
    speck = _ramp(nodes, links, micro_fac, [(0.35, (0.85, 0.85, 0.85)), (0.7, (1.08, 1.08, 1.08))])
    color = _mix(nodes, links, color, speck, 1.0, "MULTIPLY")
    if name == "slabs":
        color = _mix(nodes, links, color, (0.30, 0.28, 0.24), _joints(nodes, links, coords, 3.0, 0.03))
    if name == "plaster_brick":
        bricks = _bricks(nodes, links)
        color = _mix(nodes, links, color, (0.58, 0.30, 0.20), bricks)
    if name == "asphalt":
        color = _mix(nodes, links, color, (0.08, 0.08, 0.08), _ramp_fac(nodes, links, _noise(nodes, links, coords, 4.0, 5.0, 0.8, w), 0.62, 0.66))
    links.new(color, emit.inputs["Color"])
    target = nodes.new("ShaderNodeTexImage"); target.image = image; nodes.active = target


def _ramp_fac(nodes, links, fac, lo, hi):
    return _ramp(nodes, links, fac, [(lo, (0.0, 0.0, 0.0)), (hi, (1.0, 1.0, 1.0))])


def _joints(nodes, links, coords, count, width):
    """Fughe fra lastre: griglia di `count` x `count` nella tile."""
    uv = nodes.new("ShaderNodeTexCoord").outputs["UV"]
    sep = nodes.new("ShaderNodeSeparateXYZ"); links.new(uv, sep.inputs["Vector"])
    fx = _math(nodes, links, "FRACT", _math(nodes, links, "MULTIPLY", sep.outputs["X"], count))
    fy = _math(nodes, links, "FRACT", _math(nodes, links, "MULTIPLY", sep.outputs["Y"], count))
    dx = _math(nodes, links, "ABSOLUTE", _math(nodes, links, "SUBTRACT", fx, 0.5))
    dy = _math(nodes, links, "ABSOLUTE", _math(nodes, links, "SUBTRACT", fy, 0.5))
    edge = _math(nodes, links, "MAXIMUM", dx, dy)
    return _math(nodes, links, "GREATER_THAN", edge, 0.5 - width)


def _bricks(nodes, links):
    brick = nodes.new("ShaderNodeTexBrick")
    brick.inputs["Scale"].default_value = 8.0
    brick.inputs["Mortar Size"].default_value = 0.02
    brick.inputs["Color1"].default_value = (0.0, 0.0, 0.0, 1.0)
    brick.inputs["Color2"].default_value = (0.0, 0.0, 0.0, 1.0)
    brick.inputs["Mortar"].default_value = (1.0, 1.0, 1.0, 1.0)
    uv = nodes.new("ShaderNodeTexCoord").outputs["UV"]
    links.new(uv, brick.inputs["Vector"])
    # Intonaco scrostato: i mattoni si vedono solo dove il rumore macro e alto.
    coords, w = painter.seamless_coords(nodes, links)
    peel = _ramp_fac(nodes, links, _noise(nodes, links, coords, 2.0, 2.0, 0.5, w), 0.55, 0.62)
    return _math(nodes, links, "MULTIPLY", peel, _math(nodes, links, "SUBTRACT", 1.0, brick.outputs["Fac"]))


def plant_alpha_graph(mat, image, spec):
    """Ciuffi (3 varianti affiancate) o cartelle di foglie: colore + alpha nel canale A."""
    name = spec[0]
    tree = mat.node_tree; nodes, links = tree.nodes, tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    emit = nodes.new("ShaderNodeEmission")
    links.new(emit.outputs["Emission"], out.inputs["Surface"])
    uv = nodes.new("ShaderNodeTexCoord").outputs["UV"]
    sep = nodes.new("ShaderNodeSeparateXYZ"); links.new(uv, sep.inputs["Vector"])
    # Tre colonne: u in [0,1/3), [1/3,2/3), [2/3,1). Ogni colonna ha 4-6 lame (grass) o 3 foglie (leaf).
    u3 = _math(nodes, links, "FRACT", _math(nodes, links, "MULTIPLY", sep.outputs["X"], 3.0))
    v = sep.outputs["Y"]  # 1 = base, 0 = punta
    coords, w = painter.seamless_coords(nodes, links)
    wobble = _math(nodes, links, "MULTIPLY_ADD", _noise(nodes, links, coords, 6.0, 1.0, 0.5, w), 0.2)
    wobble.node.inputs[2].default_value = -0.1
    blades = 5.0 if name == "grass_tufts" else 3.0
    fb = _math(nodes, links, "FRACT", _math(nodes, links, "MULTIPLY", _math(nodes, links, "ADD", u3, wobble), blades))
    half = _math(nodes, links, "MULTIPLY", v, 0.42 if name == "grass_tufts" else 0.48)  # larghezza cresce verso la base
    inside = _math(nodes, links, "LESS_THAN", _math(nodes, links, "ABSOLUTE", _math(nodes, links, "SUBTRACT", fb, 0.5)), half)
    tip = _ramp(nodes, links, v, [(0.0, spec[2]), (1.0, spec[1])])  # punta chiara, base scura
    links.new(tip, emit.inputs["Color"])
    # L'alpha va cotta a parte: Blender non cuoce ALPHA in EMIT; si cuoce una seconda immagine "mask".
    mat["alpha_fac"] = inside  # riferimento per bake_mask (vedi build_group)
    target = nodes.new("ShaderNodeTexImage"); target.image = image; nodes.active = target


def bake_plane(name, size, graph, spec, colorspace, bake_type="EMIT", samples=SAMPLES):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.mesh.primitive_plane_add(size=2.0)
    plane = bpy.context.active_object
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    plane.data.materials.append(mat)
    image = bpy.data.images.new(name, size, size, alpha=True)
    image.colorspace_settings.name = colorspace
    graph(mat, image, spec)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"; scene.cycles.device = "CPU"; scene.cycles.samples = samples
    scene.render.bake.margin = 0; scene.render.bake.use_clear = True
    if bake_type == "NORMAL":
        scene.render.bake.normal_space = "TANGENT"
    bpy.ops.object.bake(type=bake_type)
    return image


def tile_orm_graph(mat, image, spec):
    coords_style = dict(painter.STYLES["tile"]); coords_style["rough_base"] = spec[5]
    painter.paint_orm_graph(mat, image, "tile", coords_style)


def tile_normal_graph(mat, image, spec):
    tree = mat.node_tree
    coords, w = painter.seamless_coords(tree.nodes, tree.links)
    painter.paint_normal_graph(mat, image, "tile", None, coords, w)


def build_group(group):
    specs = TILES[group]
    layers = len(specs)
    sheets = {}
    for map_name, graph, colorspace, bake_type, samples in (
            ("albedo", plant_alpha_graph if group == "plants" else tile_albedo_graph, "sRGB", "EMIT", SAMPLES),
            ("normal", tile_normal_graph, "Non-Color", "NORMAL", 4),
            ("orm", tile_orm_graph, "Non-Color", "EMIT", 16)):
        sheet = bpy.data.images.new("%s_%s" % (group, map_name), SIZE, SIZE * layers, alpha=True)
        sheet.colorspace_settings.name = colorspace
        pixels = [0.0] * (SIZE * SIZE * layers * 4)
        for index, spec in enumerate(specs):
            layer = bake_plane("%s_%s_%d" % (group, map_name, index), SIZE, graph, spec, colorspace, bake_type, samples)
            if group == "plants" and map_name == "albedo":
                _apply_alpha(layer, spec)
            px = layer.pixels[:]
            # Strato 0 in alto nel PNG: Godot legge gli strati dall'alto verso il basso.
            row0 = (layers - 1 - index) * SIZE
            pixels[row0 * SIZE * 4:(row0 + SIZE) * SIZE * 4] = px
        sheet.pixels = pixels
        path = os.path.join(OUT_DIR, "%s_%s.png" % (group, map_name))
        os.makedirs(OUT_DIR, exist_ok=True)
        sheet.filepath_raw = path; sheet.file_format = "PNG"; sheet.save()
        sheets[map_name] = path
        print("TILE_SHEET %s layers=%d %s" % (sheet.name, layers, path))
    return sheets


def _apply_alpha(image, spec):
    """Cuoce la maschera di alpha dei ciuffi/foglie come seconda immagine e la copia nel canale A."""
    mat = bpy.context.active_object.data.materials[0]
    mask = bpy.data.images.new(image.name + "_mask", image.size[0], image.size[1])
    mask.colorspace_settings.name = "Non-Color"
    tree = mat.node_tree; nodes, links = tree.nodes, tree.links
    emit = next(n for n in nodes if n.type == "EMISSION")
    inside = mat["alpha_fac"]
    for link in list(emit.inputs["Color"].links):
        links.remove(link)
    links.new(inside, emit.inputs["Color"])
    target = nodes.new("ShaderNodeTexImage"); target.image = mask; nodes.active = target
    bpy.ops.object.bake(type="EMIT")
    px = list(image.pixels[:]); mpx = mask.pixels[:]
    px[3::4] = mpx[0::4]
    image.pixels = px


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for group in argv or list(TILES):
        build_group(group)


main()
```

Nota per l'implementatore: `mat["alpha_fac"] = inside` non è serializzabile come custom property; usare invece un dizionario modulo-livello `_ALPHA_SOCKETS[mat.name] = inside` e leggerlo in `_apply_alpha`. Se il tempo di bake per 10 strati x 3 mappe supera i 20 minuti, abbassare `SAMPLES` a 16: le tile non hanno AO geometrica.

- [ ] **Step 4: Scrivere i file `.import` prima dell'import in Godot**

Per ciascuno dei 9 PNG creare `<file>.png.import` (Godot lo rispetta se esiste):

```
[remap]

importer="2d_array_texture"
type="CompressedTexture2DArray"

[deps]

source_file="res://assets/textures/surfaces/ground_albedo.png"

[params]

compress/mode=2
compress/high_quality=false
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
slices/horizontal=1
slices/vertical=5
```

`slices/vertical` = numero di strati del gruppo (5, 3, 2). Per i file `*_normal.png`: `compress/normal_map=1`. Per `*_orm.png` e `*_normal.png` aggiungere `compress/channel_pack=0` e lasciare `mode=2` (VRAM compressa). Poi: `godot_console --headless --path godot --editor --quit`.

- [ ] **Step 5: Eseguire il test**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_surface_tiles.py`, poi l'import, poi `godot_console --headless --path godot --fixed-fps 60 --script res://tests/restyle_tests.gd`
Expected: tutti `ok`, `PROTOTYPE01_TESTS PASS failures=0`. Controllare a occhio `ground_albedo.png` (apribile da Esplora risorse): nessuna cucitura visibile ripetendo mentalmente il bordo.

- [ ] **Step 6: Gate, documentazione, commit**

Aggiungere a `docs/GODOT_WORKFLOW.md` (sezione Blender) il comando delle tile e la trappola: "gli `.import` delle tile vanno scritti prima dell'import, altrimenti Godot importa un `Texture2D` singolo".

```bash
git add tools/blender/build_surface_tiles.py godot/assets/textures godot/tests/restyle_tests.gd docs/GODOT_WORKFLOW.md
git commit -m "Tile di superficie dipinte e ripetibili (ground, walls, plants) come Texture2DArray a 2048, suite restyle_tests"
```

---

### Task 3: Suolo e terrapieni con tile dipinte

**Files:**
- Modify: `godot/resources/materials/terrain_cell.gdshader`
- Modify: `godot/resources/materials/ruins_ground.gdshader`
- Create: `godot/resources/materials/surface_tiles.gdshaderinc`
- Modify: `godot/scripts/terrain/terrain_grid.gd` (`_make_material`, `_apply_presentation`)
- Modify: `godot/scripts/arena/overgrown_arena.gd` (`_build_ground`)
- Modify: `godot/tests/restyle_tests.gd`

**Interfaces:**
- Consumes: array `ground_{albedo,normal,orm}` (Task 2); `ruins_ground_albedo()` esistente per la maschera strada/lastre/verde.
- Produces: `surface_tiles.gdshaderinc` con `uniform sampler2DArray ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;` più `ground_normal` (hint_normal) e `ground_orm`, costanti `TILE_DIRT 0.0, TILE_SLABS 1.0, TILE_ASPHALT 2.0, TILE_DUG 3.0, TILE_MUD 4.0`, funzioni `void sample_ground(vec2 uv, float layer, out vec3 albedo, out vec3 normal_ts, out vec3 orm)` e `vec3 sample_ground_triplanar(vec3 p, vec3 n, float layer, out vec3 orm)`. `TerrainGrid` scrive in `INSTANCE_CUSTOM.z` l'indice della tile della cella (0-2 dal seme) e passa le tre texture al materiale. `TerrainGrid.TILE_SCALE := 0.25` (una tile ogni 4 m).

- [ ] **Step 1: Test che fallisce**

In `restyle_tests.gd` aggiungere `_test_terrain_textures()` (chiamarla in `_initialize` dopo `_test_surface_tiles`):

```gdscript
const RunScene := preload("res://scenes/main/arena_run.tscn")
var _scene: Node

func _test_terrain_textures() -> void:
	print("terrain textures")
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	var grid: TerrainGrid = _scene.get_node(^"TerrainGrid")
	_scene.get_node(^"EnemyDirector").spawning = false
	await _frames(5)
	var batch: MultiMeshInstance3D = grid.get_node(^"CellsFlat")
	var material := batch.material_override as ShaderMaterial
	_check(material.get_shader_parameter(&"ground_albedo") is Texture2DArray, "le celle hanno l'array albedo")
	_check(material.get_shader_parameter(&"ground_normal") is Texture2DArray, "le celle hanno l'array normal")
	_check(material.get_shader_parameter(&"ground_orm") is Texture2DArray, "le celle hanno l'array orm")
	var seen := {}
	for index in mini(batch.multimesh.instance_count, 400):
		seen[int(batch.multimesh.get_instance_custom_data(index).b)] = true
	_check(seen.size() >= 2 and seen.keys().max() <= 2, "l'indice della tile per cella varia fra 0 e 2 (%s)" % [seen.keys()])
	var ground: MeshInstance3D = _scene.get_node(^"District").find_child("Ground", true, false)
	_check(ground != null and (ground.material_override as ShaderMaterial).get_shader_parameter(&"ground_albedo") is Texture2DArray, "il suolo usa l'array albedo")
	root.remove_child(_scene); _scene.queue_free(); await _frames(2)
```

Run: `godot_console --headless --path godot --fixed-fps 60 --script res://tests/restyle_tests.gd` → `FAIL le celle hanno l'array albedo`.

- [ ] **Step 2: `surface_tiles.gdshaderinc`**

```glsl
// Tile dipinte del mondo (Task 2): array a strati, campionate in spazio mondo.
uniform sampler2DArray ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray ground_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_scale = 0.25; // tile ogni 4 m

const float TILE_DIRT = 0.0;
const float TILE_SLABS = 1.0;
const float TILE_ASPHALT = 2.0;
const float TILE_DUG = 3.0;
const float TILE_MUD = 4.0;

void sample_ground(vec2 uv, float layer, out vec3 albedo, out vec3 normal_ts, out vec3 orm) {
	albedo = texture(ground_albedo, vec3(uv, layer)).rgb;
	normal_ts = texture(ground_normal, vec3(uv, layer)).rgb * 2.0 - 1.0;
	orm = texture(ground_orm, vec3(uv, layer)).rgb;
}

// Triplanare per i fianchi dei terrapieni: pesa i tre assi con la normale.
vec3 sample_ground_triplanar(vec3 p, vec3 n, float layer, out vec3 orm) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 ax = texture(ground_albedo, vec3(p.zy * tile_scale, layer)).rgb;
	vec3 ay = texture(ground_albedo, vec3(p.xz * tile_scale, layer)).rgb;
	vec3 az = texture(ground_albedo, vec3(p.xy * tile_scale, layer)).rgb;
	orm = texture(ground_orm, vec3(p.xz * tile_scale, layer)).rgb;
	return ax * w.x + ay * w.y + az * w.z;
}
```

- [ ] **Step 3: `terrain_cell.gdshader`**

Sostituire il corpo di `fragment()` mantenendo le uniform esistenti e aggiungendo `#include "res://resources/materials/surface_tiles.gdshaderinc"` e `varying vec4 instance_custom` già presente:

```glsl
void fragment() {
	vec3 col = batched ? COLOR.rgb : cell_color.rgb;
	float is_natural = batched ? instance_custom.x : natural;
	float tint_amount = batched ? instance_custom.y : state_tint;
	float tile = batched ? instance_custom.z : 0.0;
	float rough = 0.8;
	vec3 n = normalize(world_normal);
	if (is_natural > 0.5) {
		float green;
		vec3 mask_ground = ruins_ground_albedo(world_pos.xz, plaza_radius, green); // maschera strada/lastre/verde
		vec2 uv = world_pos.xz * tile_scale;
		vec3 top_albedo; vec3 top_n; vec3 top_orm;
		bool raised_top = n.y > 0.5 && world_pos.y > raised_top * 0.5;
		bool lowered = tint_amount > 0.8; // Lowered usa NATURAL_STATE_TINT 0.85
		float layer = raised_top ? TILE_DUG : (lowered ? TILE_MUD : tile);
		sample_ground(uv, layer, top_albedo, top_n, top_orm);
		// Erba dipinta dove la maschera dice verde (solo celle piatte).
		vec3 grass = mix(RG_GRASS_A, RG_GRASS_B, value_noise(world_pos.xz * 0.8)) * (0.85 + 0.3 * top_orm.r);
		vec3 top = raised_top ? top_albedo : mix(top_albedo, grass * 1.15, green * (1.0 - step(0.5, tile == TILE_ASPHALT ? 1.0 : 0.0)));
		// Fianchi: tile dug_soil triplanare con rampa caldo->scuro verso il basso e strati.
		vec3 side_orm;
		vec3 side = sample_ground_triplanar(world_pos, n, TILE_DUG, side_orm);
		float strata = fract(world_pos.y * 3.2 + value_noise(world_pos.xz * 0.7) * 1.4);
		side *= 0.82 + 0.22 * smoothstep(0.0, 0.25, strata) * (1.0 - smoothstep(0.75, 1.0, strata));
		side *= mix(0.55, 1.05, smoothstep(0.0, raised_top, world_pos.y));
		vec3 base = n.y > 0.5 ? top : side;
		vec3 orm = n.y > 0.5 ? top_orm : side_orm;
		if (raised_top) {
			vec2 local = fract(world_pos.xz / cell_pitch + 0.5) - 0.5;
			float edge_d = (0.5 - max(abs(local.x), abs(local.y))) * cell_pitch;
			float rim = 1.0 - smoothstep(0.1, 0.45 + 0.15 * value_noise(world_pos.xz * 3.0), edge_d);
			base = mix(base, base * vec3(1.18, 1.10, 0.95), rim * 0.85); // orlo chiaro dipinto
			base *= 0.92 + 0.16 * hash12(floor(world_pos.xz / cell_pitch + 0.5));
		}
		if (n.y > 0.5) {
			NORMAL_MAP = top_n * 0.5 + 0.5;
			NORMAL_MAP_DEPTH = 0.8;
		}
		vec3 tinted = mix(base, col, 0.55) * (0.75 + 0.5 * value_noise(world_pos.xz * 1.5));
		col = mix(base, tinted, tint_amount);
		rough = lowered ? 0.35 : mix(0.7, 1.0, orm.g);
		AO = orm.r;
		AO_LIGHT_AFFECT = 0.3;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
}
```

Nota: `NORMAL_MAP` in Godot vuole lo spazio tangente del mesh; i cubi delle celle hanno tangenti generate (`BoxMesh`), quindi la normal map sulle cime funziona.

- [ ] **Step 4: `TerrainGrid`**

```gdscript
const GROUND_ALBEDO := preload("res://assets/textures/surfaces/ground_albedo.png")
const GROUND_NORMAL := preload("res://assets/textures/surfaces/ground_normal.png")
const GROUND_ORM := preload("res://assets/textures/surfaces/ground_orm.png")
const TILE_SCALE := 0.25

func _make_material(batched: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CELL_SHADER
	material.set_shader_parameter(&"batched", batched)
	material.set_shader_parameter(&"plaza_radius", plaza_radius)
	material.set_shader_parameter(&"cell_pitch", UnrealSpace.length(_cell_size_cm))
	material.set_shader_parameter(&"ground_albedo", GROUND_ALBEDO)
	material.set_shader_parameter(&"ground_normal", GROUND_NORMAL)
	material.set_shader_parameter(&"ground_orm", GROUND_ORM)
	material.set_shader_parameter(&"tile_scale", TILE_SCALE)
	if is_inside_tree():
		material.set_shader_parameter(&"raised_top", raised_top_y())
	return material

## Tile della cella dal seme: 0 terra, 1 lastre, 2 asfalto; a chiazze, non a caso per cella.
func _cell_tile(cell: Vector2i) -> float:
	var n := OvergrownArena.fbm_static(Vector2(cell) * 0.13 + Vector2(7.1, 3.3))
	if n < 0.42:
		return 0.0
	return 1.0 if n < 0.58 else 2.0
```

In `_apply_presentation`: `multimesh.set_instance_custom_data(index, Color(1.0 if natural_ground else 0.0, tint, _cell_tile(cell), 0.0))`. In `OvergrownArena` esporre `static func fbm_static(p: Vector2) -> float` che chiama l'`_fbm` statico esistente (righe 1063-1092).

- [ ] **Step 5: `ruins_ground.gdshader` e `_build_ground`**

```glsl
shader_type spatial;
#include "res://resources/materials/noise.gdshaderinc"
#include "res://resources/materials/ruins_ground.gdshaderinc"
#include "res://resources/materials/surface_tiles.gdshaderinc"
uniform float plaza_radius = 20.0;
varying vec3 world_pos;

void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float green;
	vec3 mask = ruins_ground_albedo(world_pos.xz, plaza_radius, green);
	// La vecchia funzione decide dove sono strada, lastre e terra: si legge dal suo colore.
	float is_road = step(0.5, 1.0 - smoothstep(0.26, 0.4, mask.r)); // asfalto scuro
	float is_slab = step(0.5, smoothstep(0.5, 0.62, mask.r));
	float layer = is_road > 0.5 ? TILE_ASPHALT : (is_slab > 0.5 ? TILE_SLABS : TILE_DIRT);
	vec3 albedo; vec3 n_ts; vec3 orm;
	sample_ground(world_pos.xz * tile_scale, layer, albedo, n_ts, orm);
	vec3 grass = mix(RG_GRASS_A, RG_GRASS_B, value_noise(world_pos.xz * 0.8)) * 1.15;
	albedo = mix(albedo, grass, green * (1.0 - is_road));
	ALBEDO = albedo;
	NORMAL_MAP = n_ts * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
	ROUGHNESS = mix(0.75, 1.0, orm.g);
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.3;
}
```

In `OvergrownArena._build_ground()` il `ShaderMaterial(GROUND_SHADER)` riceve gli stessi quattro parametri (`ground_albedo`, `ground_normal`, `ground_orm`, `tile_scale`) via una funzione condivisa `static func apply_ground_tiles(material: ShaderMaterial) -> void` in `TerrainGrid` (la chiamano sia `_make_material` sia `_build_ground`). Il nodo del suolo si chiama `Ground`.

- [ ] **Step 6: Eseguire test, suite del terreno e catture**

Run: `godot_console --headless --path godot --fixed-fps 60 --script res://tests/restyle_tests.gd` → PASS. Poi `terrain_tests`, `terrain_tool_tests`, `ruins_arena_tests`, `district_tests`, `quake_tests` → PASS.
Cattura: `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_district.gd -- --out=../output/restyle/district` e `capture_closeup.gd -- --out=../output/restyle/district --at=62,1.5,62 --from=50,7,76 --name=wall_close`. Guardare `start.png` e `wall_close.png`: tile leggibili, nessuna scalettatura, stati delle celle ancora distinguibili (Lowered scuro, Raised chiaro).

- [ ] **Step 7: Gate e commit**

```bash
git add godot/resources/materials/surface_tiles.gdshaderinc godot/resources/materials/terrain_cell.gdshader godot/resources/materials/ruins_ground.gdshader godot/scripts/terrain/terrain_grid.gd godot/scripts/arena/overgrown_arena.gd godot/tests/restyle_tests.gd
git commit -m "Suolo e terrapieni con tile dipinte: array ground nelle celle e nel piano, indice di tile per cella, fianchi triplanari, normal e ORM"
```

---

### Task 4: Rovine dipinte (intonaco, mattoni, muschio) in triplanare

**Files:**
- Modify: `godot/resources/materials/ruin_overgrown.gdshader`
- Modify: `godot/scripts/arena/overgrown_arena.gd` (`_make_materials`: `_ruin_material`, `_crown_material`)
- Modify: `godot/tests/restyle_tests.gd`

**Interfaces:**
- Consumes: array `walls_{albedo,normal,orm}` (strati 0 plaster_brick, 1 moss, 2 bark).
- Produces: uniform `walls_albedo`, `walls_normal`, `walls_orm`, `wall_tile_scale = 0.35`; stesse uniform per istanza di oggi; modalità `batched` invariata.

Deviazione dalla specifica (§3.4): i gusci restano generati per impronta (6-14 x 5-12 m dal seme) e vengono dipinti in triplanare, invece di `.glb` fissi che si deformerebbero scalati. Da annotare in `DECISIONS.md` (D-077).

- [ ] **Step 1: Test che fallisce**

```gdscript
func _test_ruin_textures() -> void:
	print("ruin textures")
	_scene = RunScene.instantiate(); root.add_child(_scene)
	_scene.get_node(^"EnemyDirector").spawning = false
	await _frames(5)
	var district: Node3D = _scene.get_node(^"District")
	var block := district.find_child("Block0", true, false)
	_check(block != null, "esiste Block0")
	var piece: MeshInstance3D = block.find_child("*", true, false) if block else null
	var material := piece.material_override as ShaderMaterial if piece else null
	_check(material != null and material.get_shader_parameter(&"walls_albedo") is Texture2DArray, "i muri delle rovine usano l'array walls")
	_check(material != null and material.get_instance_shader_parameter(&"base_tint") != null or piece.get_instance_shader_parameter(&"base_tint") != null, "base_tint per istanza ancora impostata")
	var crowns: MultiMeshInstance3D = district.find_child("RuinCrowns", true, false)
	_check(crowns != null and (crowns.material_override as ShaderMaterial).get_shader_parameter(&"batched") == true, "le corone restano batched")
	root.remove_child(_scene); _scene.queue_free(); await _frames(2)
```

Run → `FAIL i muri delle rovine usano l'array walls`.

- [ ] **Step 2: Shader**

In `ruin_overgrown.gdshader` aggiungere dopo le uniform esistenti:

```glsl
uniform sampler2DArray walls_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray walls_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray walls_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wall_tile_scale = 0.35;
const float WALL_PLASTER = 0.0;
const float WALL_MOSS = 1.0;

vec3 wall_triplanar(sampler2DArray tex, vec3 p, vec3 n, float layer) {
	vec3 w = pow(abs(n), vec3(4.0)); w /= (w.x + w.y + w.z);
	return texture(tex, vec3(p.zy * wall_tile_scale, layer)).rgb * w.x
		+ texture(tex, vec3(p.xz * wall_tile_scale, layer)).rgb * w.y
		+ texture(tex, vec3(p.xy * wall_tile_scale, layer)).rgb * w.z;
}
```

Nel `fragment()` sostituire il calcolo del colore di base (`col` prima di finestre e rampicanti) con:

```glsl
	vec3 n = normalize(world_normal);
	vec3 plaster = wall_triplanar(walls_albedo, world_pos, n, WALL_PLASTER);
	vec3 plaster_orm = wall_triplanar(walls_orm, world_pos, n, WALL_PLASTER);
	vec3 col = plaster * tint_rgb * 1.35; // tint_rgb e chiaro (0.66, 0.62, 0.55): si compensa
	// Umidita dall'alto: piu scuro sotto il tetto.
	float damp = smoothstep(roof_y - 0.2, roof_y - 1.6, world_pos.y) * (1.0 - smoothstep(roof_y - 1.6, roof_y - 3.0, world_pos.y));
	col *= 1.0 - 0.25 * damp * fbm(world_pos.xy * 0.8);
	// Muschio dipinto sulle facce rivolte al cielo e dove c'e verde.
	vec3 moss_tex = wall_triplanar(walls_albedo, world_pos, n, WALL_MOSS);
	float up = smoothstep(0.3, 0.8, n.y);
	// `green` e la variabile esistente dei rampicanti/muschio: si conserva il suo calcolo e si usa qui.
```

e nella chiusura: `ALBEDO = mix(col, moss_tex, max(green, up * growth * 0.6)); ROUGHNESS = mix(mix(0.7, 1.0, plaster_orm.g), 0.95, green); AO = plaster_orm.r; AO_LIGHT_AFFECT = 0.3;`. Le finestre, le crepe, le linee di solaio e le corone in `batched` restano com'erano (il colore di istanza moltiplica `plaster`).

- [ ] **Step 3: Materiali in `OvergrownArena._make_materials()`**

```gdscript
const WALLS_ALBEDO := preload("res://assets/textures/surfaces/walls_albedo.png")
const WALLS_NORMAL := preload("res://assets/textures/surfaces/walls_normal.png")
const WALLS_ORM := preload("res://assets/textures/surfaces/walls_orm.png")

static func apply_wall_tiles(material: ShaderMaterial) -> void:
	material.set_shader_parameter(&"walls_albedo", WALLS_ALBEDO)
	material.set_shader_parameter(&"walls_normal", WALLS_NORMAL)
	material.set_shader_parameter(&"walls_orm", WALLS_ORM)
```

Chiamarla su `_ruin_material` e sul materiale delle corone (`_crown_material`, dove viene creato in `_build_ruin_details`/`_reset_ruin_details`).

- [ ] **Step 4: Test, suite, catture**

`restyle_tests` → PASS; `ruins_arena_tests`, `district_tests`, `railway_tests` → PASS. Cattura `capture_closeup.gd -- --out=../output/restyle/district --at=62,1.5,62 --from=50,7,76 --name=ruin_close`. Controllo: intonaco e mattoni leggibili, nessuna ripetizione evidente a 1280x800, corone dello stesso colore dei muri.

- [ ] **Step 5: Gate e commit**

```bash
git add godot/resources/materials/ruin_overgrown.gdshader godot/scripts/arena/overgrown_arena.gd godot/tests/restyle_tests.gd
git commit -m "Rovine dipinte: intonaco scrostato, mattoni e muschio dalle tile walls in triplanare, corone batched invariate"
```

---

### Task 5: Vegetazione e prop ridipinti

**Files:**
- Modify: `godot/resources/materials/grass_blades.gdshader`, `foliage.gdshader`, `env_baked.gdshader`
- Modify: `godot/scripts/arena/overgrown_arena.gd` (`_make_materials`, `_bush_mesh` → `_bush_card_mesh`, `_bush`, `_baked_material`, `_tuft_mesh` UV)
- Modify: `tools/blender/build_arena_assets.py` (`build_overgrown_tree`: chioma a cartelle)
- Regenerate: `godot/assets/models/{wrecked_car,train_carriage,overgrown_tree,concrete_barrier,lamp_post}.glb` e PNG estratti
- Modify: `godot/tests/restyle_tests.gd`

**Interfaces:**
- Consumes: array `plants_{albedo,normal,orm}` (0 grass_tufts con 3 colonne, 1 leaf_cards), prop ricotti da Task 1 con `_normal` e `_orm`.
- Produces: `grass_blades.gdshader` con `uniform sampler2DArray plants_albedo`, `uniform float variant_columns = 3.0`, variante scelta da `INSTANCE_ID`; `foliage.gdshader` con `plants_albedo` strato 1 su cartelle; `env_baked.gdshader` con `normal_tex`, `orm_tex`, `rim_color`, `rim_strength`; `OvergrownArena._baked_material()` passa `normal_tex` e `orm_tex` da `source.normal_texture` e `source.roughness_texture`/`ao_texture`.

- [ ] **Step 1: Test che fallisce**

```gdscript
func _test_vegetation_and_props() -> void:
	print("vegetation and props")
	_scene = RunScene.instantiate(); root.add_child(_scene)
	_scene.get_node(^"EnemyDirector").spawning = false
	await _frames(5)
	var district: Node3D = _scene.get_node(^"District")
	var tufts: MultiMeshInstance3D = district.find_child("GrassTufts", true, false)
	_check(tufts != null and (tufts.material_override as ShaderMaterial).get_shader_parameter(&"plants_albedo") is Texture2DArray, "l'erba usa l'array plants")
	var bush := district.find_child("Bush*", true, false)
	var card: MeshInstance3D = bush.get_child(0) if bush and bush.get_child_count() > 0 else null
	_check(card != null and card.mesh.get_surface_count() == 1 and card.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] != null, "i cespugli sono cartelle con UV")
	var car := district.find_child("Car*", true, false)
	var mi: MeshInstance3D = car.find_child("*", true, false) if car else null
	var mat := mi.get_surface_override_material(0) as ShaderMaterial if mi else null
	_check(mat != null and mat.get_shader_parameter(&"normal_tex") != null and mat.get_shader_parameter(&"orm_tex") != null, "i prop cotti hanno normal e orm")
	root.remove_child(_scene); _scene.queue_free(); await _frames(2)
```

Run → FAIL sui tre controlli. (Verificare i nomi reali dei nodi `Bush`/`Car` in `_bush`/`_car` e adattare i pattern.)

- [ ] **Step 2: Erba**

`grass_blades.gdshader`:

```glsl
shader_type spatial;
render_mode cull_disabled;
#include "res://resources/materials/noise.gdshaderinc"
uniform sampler2DArray plants_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform float variant_columns = 3.0;
uniform float sway = 0.06;
uniform float sway_speed = 1.4;
varying vec3 world_pos;
varying float variant;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	variant = float(INSTANCE_ID % 3);
	float phase = TIME * sway_speed + origin.x * 0.35 + origin.z * 0.27;
	float bend = max(VERTEX.y, 0.0) * sway;
	VERTEX.x += sin(phase) * bend;
	VERTEX.z += cos(phase * 0.7) * bend;
}

void fragment() {
	vec2 uv = vec2((UV.x + variant) / variant_columns, UV.y);
	vec4 tex = texture(plants_albedo, vec3(uv, 0.0));
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 col = tex.rgb * COLOR.rgb * (0.85 + 0.3 * value_noise(world_pos.xz * 1.3));
	ALBEDO = col;
	ROUGHNESS = 0.9;
	BACKLIGHT = col * 0.3;
}
```

In `_make_materials`: `_grass_material.set_shader_parameter(&"plants_albedo", PLANTS_ALBEDO)` (preload di `plants_albedo.png`); rimuovere `blade_texture` e `_blade_texture()`.

- [ ] **Step 3: Cespugli e chiome a cartelle**

`foliage.gdshader`: aggiungere `uniform sampler2DArray plants_albedo : source_color, filter_linear_mipmap, repeat_disable; uniform float leaf_layer = 1.0; uniform bool textured = false;` e nel fragment: `vec4 tex = textured ? texture(plants_albedo, vec3(UV, leaf_layer)) : vec4(1.0); if (textured) { ALPHA = tex.a; ALPHA_SCISSOR_THRESHOLD = 0.5; } col = tex.rgb * COLOR.rgb * tint.rgb * ...` (resto invariato, fiori restano `textured = false` su un secondo materiale `_flower_material`).

`OvergrownArena._bush_card_mesh()` sostituisce `_bush_mesh()`: 6 quad incrociati (3 verticali a 60° come i ciuffi, 3 inclinati di 35°) di lato 2 con UV 0-1 e normale verso l'alto mescolata con la normale del quad (`(Vector3.UP + quad_normal).normalized()`); `_bush()` usa `_bush_card_mesh()` con `_foliage_material` (`textured = true`). In `build_arena_assets.build_overgrown_tree`: le chiome `lumpy_sphere` diventano 12-18 cartelle (piani 1,6 x 1,2 m) orientate a caso attorno a 2-3 centri, materiale `leaves` con `Col` chiaro; Godot le intercetta in `_material_for("leaves")` → `_canopy_material` (`textured = true`).

- [ ] **Step 4: Prop con normal e ORM, rim light**

`env_baked.gdshader`: aggiungere

```glsl
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform bool has_maps = false;
uniform vec3 rim_color : source_color = vec3(1.0, 0.85, 0.6);
uniform float rim_strength = 0.35;
```

e nel fragment, dopo `ALBEDO`: `if (has_maps) { NORMAL_MAP = texture(normal_tex, UV).rgb; NORMAL_MAP_DEPTH = 1.0; vec3 orm = texture(orm_tex, UV).rgb; ROUGHNESS = mix(orm.g, 0.9, max(r, moss)); METALLIC = orm.b * (1.0 - max(r, moss)); AO = orm.r; AO_LIGHT_AFFECT = 0.3; } RIM = rim_strength; RIM_TINT = 0.5;` (Godot espone `RIM` e `RIM_TINT`; il colore del rim segue la luce: `rim_color` resta per una futura modulazione, impostata ma non obbligatoria).

`_baked_material()`:

```gdscript
	var normal := source.normal_texture if source.normal_enabled else null
	var orm := source.roughness_texture if source.roughness_texture != null else source.ao_texture
	material.set_shader_parameter(&"has_maps", normal != null and orm != null)
	if normal != null: material.set_shader_parameter(&"normal_tex", normal)
	if orm != null: material.set_shader_parameter(&"orm_tex", orm)
```

- [ ] **Step 5: Ricostruire i cinque prop e importare**

Run: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_arena_assets.py` (cinque bake da 2-3 minuti), poi `godot_console --headless --path godot --editor --quit`. `inspect_model.gd -- --model=wrecked_car` → `normal=true orm=true`.

- [ ] **Step 6: Test, suite, catture, benchmark**

`restyle_tests` → PASS; `ruins_arena_tests`, `district_tests`, `railway_tests`, `train_tests`, `lamp_tests`, `day_night_tests` → PASS. Catture: `capture_district.gd -- --out=../output/restyle/district` e closeup `grass_close` (`--at=40,0.5,40 --from=44,2.5,46`), `tree_close`, `car_close` (coordinate dalle catture `output/env/` esistenti: leggere i comandi in `docs/GODOT_WORKFLOW.md`, sezione catture D-073). Benchmark: `godot_console --path godot --resolution 1280x800 --script res://tests/tools/benchmark_arena.gd -- --enemies=70` → annotare `draw_calls`, `primitives`, `video_mem_mb`, `avg_frame_ms` nel messaggio di commit; soglie Alto: ≤ 450 / 3 M / 300 MB / 12 ms.

- [ ] **Step 7: Gate e commit**

```bash
git add godot/resources/materials/grass_blades.gdshader godot/resources/materials/foliage.gdshader godot/resources/materials/env_baked.gdshader godot/scripts/arena/overgrown_arena.gd tools/blender/build_arena_assets.py godot/assets/models godot/tests/restyle_tests.gd
git commit -m "Vegetazione e prop ridipinti: erba e cespugli a cartelle dalle tile plants, chioma a cartelle, prop con normal, ORM e rim light; misure nel messaggio"
```

---

### Task 6: Cielo dipinto, luce e post-produzione

**Files:**
- Create: `godot/resources/materials/sky_painted.gdshader`
- Modify: `godot/scripts/arena/overgrown_arena.gd` (`_add_sun`, `_add_environment`)
- Modify: `godot/scripts/run/day_night_cycle.gd` (`_apply_rendering`, `_find_rendering_nodes`)
- Modify: `godot/scripts/core/actor_model.gd` (`textured_paint`: rim)
- Modify: `godot/tests/restyle_tests.gd`, `godot/tests/day_night_tests.gd` se cambia il tipo di cielo

**Interfaces:**
- Produces: `sky_painted.gdshader` (`shader_type sky`) con uniform `top_color`, `horizon_color`, `ground_color`, `sun_glow_color`, `band_noise = 0.08`; `OvergrownArena.SKY_DAY := {top: Color(0.26, 0.46, 0.82), horizon: Color(0.96, 0.80, 0.62), ground: Color(0.42, 0.38, 0.28)}`; `DayNightCycle` interpola `top_color`/`horizon_color` su `ShaderMaterial` oltre che su `ProceduralSkyMaterial`; `Environment` con `glow_levels`, `ssao_radius 3.0 / intensity 1.6`, `adjustment_contrast 1.12`, `adjustment_saturation 1.22`, `tonemap_mode ACES`, `fog_light_color` dal cielo; sole energia 1.6, colore (1.0, 0.84, 0.62), `light_angular_distance 1.5`, `shadow_blur 1.2`; ambiente freddo (0.46, 0.50, 0.72) a energia 0.55 per ombre blu-viola; vignetta via `adjustment_color_correction` no: vignetta con un `ColorRect` in `RunHud`? No: si usa `glow_blend_mode SOFTLIGHT` e si rinuncia alla vignetta se non c'è un modo economico (nota in DECISIONS).

- [ ] **Step 1: Test che fallisce**

```gdscript
func _test_sky_and_post() -> void:
	print("sky and post")
	_scene = RunScene.instantiate(); root.add_child(_scene)
	_scene.get_node(^"EnemyDirector").spawning = false
	await _frames(5)
	var env: Environment = _scene.get_node(^"District/WorldEnvironment").environment
	_check(env.sky != null and env.sky.sky_material is ShaderMaterial, "il cielo e dipinto (ShaderMaterial)")
	_check(env.tonemap_mode == Environment.TONE_MAPPER_ACES, "tonemap ACES")
	_check(env.adjustment_saturation >= 1.2, "saturazione alzata")
	var sun: DirectionalLight3D = _scene.get_node(^"District/SunLight")
	_check(sun.light_angular_distance > 0.0, "il sole ha un diametro angolare (ombre morbide)")
	var dn: DayNightCycle = _scene.get_node(^"Run").day_night
	var day_top: Color = (env.sky.sky_material as ShaderMaterial).get_shader_parameter(&"top_color")
	dn.night_start_seconds = 0.0; dn.dusk_seconds = 1.0
	dn.advance(10.0)
	var night_top: Color = (env.sky.sky_material as ShaderMaterial).get_shader_parameter(&"top_color")
	_check(night_top.v < day_top.v, "di notte il cielo dipinto si scurisce")
	root.remove_child(_scene); _scene.queue_free(); await _frames(2)
```

Run → FAIL sul cielo ShaderMaterial.

- [ ] **Step 2: Shader del cielo**

```glsl
shader_type sky;
// Cielo a gradiente dipinto: tre colori, fasce leggere, alone attorno al sole.
uniform vec3 top_color : source_color = vec3(0.26, 0.46, 0.82);
uniform vec3 horizon_color : source_color = vec3(0.96, 0.80, 0.62);
uniform vec3 ground_color : source_color = vec3(0.42, 0.38, 0.28);
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.75, 0.45);
uniform float band_noise = 0.08;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void sky() {
	float h = EYEDIR.y;
	float bands = (hash(floor(vec2(h * 40.0, 0.0))) - 0.5) * band_noise;
	vec3 col;
	if (h >= 0.0) {
		float t = smoothstep(0.0, 0.55, h + bands);
		col = mix(horizon_color, top_color, t);
	} else {
		col = mix(horizon_color, ground_color, smoothstep(0.0, 0.25, -h));
	}
	float sun = pow(max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0), 24.0);
	col += sun_glow_color * sun * 0.6 * LIGHT0_ENERGY;
	COLOR = col;
}
```

- [ ] **Step 3: `_add_sun` e `_add_environment`**

```gdscript
const SKY_SHADER := preload("res://resources/materials/sky_painted.gdshader")
const SKY_DAY := {"top": Color(0.26, 0.46, 0.82), "horizon": Color(0.96, 0.80, 0.62), "ground": Color(0.42, 0.38, 0.28)}
const SUN_COLOR := Color(1.0, 0.84, 0.62)
const AMBIENT_COLOR := Color(0.46, 0.50, 0.72)  # ombre blu-viola

func _add_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	var direction := Vector3(0.78, -0.50, -0.35).normalized()  # circa 28 gradi sull'orizzonte
	sun.basis = Basis.looking_at(direction, Vector3.UP)
	sun.light_color = SUN_COLOR
	sun.light_energy = 1.6
	sun.light_angular_distance = 1.5
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = 90.0
	_add_generated(sun)

func _add_environment() -> void:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky_material.set_shader_parameter(&"top_color", SKY_DAY.top)
	sky_material.set_shader_parameter(&"horizon_color", SKY_DAY.horizon)
	sky_material.set_shader_parameter(&"ground_color", SKY_DAY.ground)
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = AMBIENT_COLOR
	environment.ambient_light_energy = 0.55
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 4.0
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = SKY_DAY.horizon
	environment.fog_density = 0.5
	environment.fog_depth_begin = 45.0
	environment.fog_depth_end = 160.0
	environment.fog_depth_curve = 1.6
	environment.fog_sun_scatter = 0.25
	environment.fog_aerial_perspective = 0.45
	environment.ssao_enabled = true
	environment.ssao_radius = 3.0
	environment.ssao_intensity = 1.6
	environment.ssao_light_affect = 0.15
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 1.1
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.set_glow_level(1, 0.6); environment.set_glow_level(3, 0.8); environment.set_glow_level(5, 0.4)
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 1.22
	# ... CameraAttributesPractical e WorldEnvironment come oggi
```

In `DayNightCycle._apply_rendering()`:

```gdscript
	var sky_mat := _environment.sky.sky_material if _environment.sky != null else null
	if sky_mat is ProceduralSkyMaterial:
		sky_mat.sky_top_color = _day_sky_top.lerp(NIGHT_SKY_TOP, t)
		sky_mat.sky_horizon_color = _day_sky_horizon.lerp(NIGHT_SKY_HORIZON, t)
	elif sky_mat is ShaderMaterial:
		sky_mat.set_shader_parameter(&"top_color", _day_sky_top.lerp(NIGHT_SKY_TOP, t))
		sky_mat.set_shader_parameter(&"horizon_color", _day_sky_horizon.lerp(NIGHT_SKY_HORIZON, t))
```

e in `_find_rendering_nodes()` leggere `_day_sky_top`/`_day_sky_horizon` dallo `ShaderMaterial` con `get_shader_parameter`. Costanti notte: `NIGHT_SKY_TOP = Color(0.04, 0.03, 0.10)`, `NIGHT_SKY_HORIZON = Color(0.16, 0.10, 0.22)` (blu-violaceo), `NIGHT_FOG_COLOR = Color(0.10, 0.08, 0.16)`.

`ActorModel.textured_paint()`: `material.rim_enabled = true; material.rim = 0.35; material.rim_tint = 0.5`.

- [ ] **Step 4: Test, suite, catture**

`restyle_tests`, `day_night_tests`, `lamp_tests`, `ruins_arena_tests` → PASS. Catture: `capture_district.gd -- --out=../output/restyle/district` (giorno), `capture_night.gd -- --out=../output/restyle/night` (vedi comando in `GODOT_WORKFLOW.md`). Controllo: ombre bluastre, cielo a gradiente senza banding grossolano, glow solo su lampade e alte luci, nessuna bruciatura sulle tile chiare (se bruciano: `tonemap_white` 5.0 o sole 1.4).

- [ ] **Step 5: Gate e commit**

```bash
git add godot/resources/materials/sky_painted.gdshader godot/scripts/arena/overgrown_arena.gd godot/scripts/run/day_night_cycle.gd godot/scripts/core/actor_model.gd godot/tests/restyle_tests.gd
git commit -m "Cielo dipinto, sole caldo con ombre blu-viola, ACES, glow a livelli, grading e rim light sugli attori; notte blu-violacea"
```

---

### Task 7: Preset grafici e opzioni singole nel servizio impostazioni

**Files:**
- Modify: `godot/scripts/services/game_settings.gd`
- Create: `godot/scripts/services/graphics_quality.gd`
- Modify: `godot/scripts/arena/overgrown_arena.gd` (applica qualità a `Environment`/sole, densità vegetazione)
- Modify: `godot/tests/settings_tests.gd`, `godot/tests/restyle_tests.gd`

**Interfaces:**
- Produces in `GameSettingsService`: `enum Preset { STEAM_DECK, LOW, MEDIUM, HIGH, MAX, CUSTOM }`, `const PRESET_NAMES`, campi `preset`, `shadow_quality` (0-3), `ssao_quality` (0-2), `gi_mode` (0 off, 1 SSIL, 2 SDFGI), `glow_quality` (0-2), `volumetric_fog` (bool), `texture_quality` (0-1), `vegetation_density` (0-2), `screen_aa` (0 off, 1 FXAA, 2 TAA), `fsr_upscaling` (bool), `camera_distance` (0-2, Task 10), `preset_chosen` (bool); `FPS_CAPS := [30, 60, 90, 120, 144, 165, 240, 0]`, `DEFAULT_FPS_CAP := 60`; `const VERSION := 2`; setter `set_preset(p)` (copia i valori del preset), setter per ogni campo (portano `preset` a `CUSTOM`); `apply_settings(viewport)` applica anche `screen_space_aa`, `use_taa`, `scaling_3d_mode`, `texture_mipmap_bias`; `apply_to_world(environment: Environment, sun: DirectionalLight3D)`; `vegetation_multiplier() -> float` (0.35, 0.65, 1.0); `static func is_steam_deck() -> bool` (`OS.get_environment("SteamDeck") == "1"`); `load_settings` conserva le chiavi sconosciute e scrive `version`.
- `GraphicsQuality` (classe statica di supporto): `static func apply(settings, environment, sun)` con la tabella dei preset `PRESETS: Dictionary[int, Dictionary]`.

Tabella dei preset (spec §5.2):

| Campo | Steam Deck | Basso | Medio | Alto | Massimo |
|---|---|---|---|---|---|
| msaa_3d | OFF | OFF | 2X | 4X | 4X |
| screen_aa | FXAA | FXAA | OFF | OFF | FXAA |
| shadow_quality | 1 | 1 | 2 | 2 | 3 |
| ssao_quality | 1 | 0 | 1 | 2 | 2 |
| gi_mode | 0 | 0 | 0 | 1 | 2 |
| glow_quality | 1 | 0 | 1 | 2 | 2 |
| volumetric_fog | false | false | false | false | true |
| texture_quality | 1 | 0 | 1 | 1 | 1 |
| vegetation_density | 1 | 0 | 1 | 2 | 2 |
| render_scale | 0.85 | 0.75 | 1.0 | 1.0 | 1.0 |
| fsr_upscaling | true | true | false | false | false |

- [ ] **Step 1: Test che fallisce (`settings_tests.gd`)**

Aggiungere a `settings_tests.gd` (usa il pattern già presente: istanza standalone con `settings_path` temporaneo):

```gdscript
func _test_graphics_presets() -> void:
	print("graphics presets")
	var s := GameSettingsScript.new()
	s.settings_path = "user://settings_test_%d.cfg" % Time.get_ticks_usec()
	root.add_child(s)
	_check(s.fps_cap == 60, "default fps 60")
	_check(s.FPS_CAPS.has(240) and s.FPS_CAPS.has(165) and s.FPS_CAPS[-1] == 0, "limiti fps fino a 240 e Illimitato")
	s.set_preset(GameSettingsService.Preset.MAX)
	_check(s.gi_mode == 2 and s.volumetric_fog and s.shadow_quality == 3, "Massimo accende SDFGI, volumetrica, ombre alte")
	s.set_gi_mode(1)
	_check(s.preset == GameSettingsService.Preset.CUSTOM and s.volumetric_fog and s.shadow_quality == 3, "toccare un'opzione porta a Personalizzato senza cambiare le altre")
	s.set_preset(GameSettingsService.Preset.STEAM_DECK)
	_check(s.render_scale == 0.85 and s.fsr_upscaling and s.msaa_3d == Viewport.MSAA_DISABLED, "preset Deck: scala 0,85 con FSR, MSAA off")
	# File vecchio senza le chiavi nuove e con una chiave sconosciuta.
	var old := ConfigFile.new()
	old.set_value("graphics", "fps_cap", 120); old.set_value("graphics", "future_key", "x")
	old.save(s.settings_path)
	_check(s.load_settings() == OK and s.fps_cap == 120 and s.preset == GameSettingsService.Preset.HIGH, "file vecchio: fps conservato, preset Alto")
	s.save_settings()
	var saved := ConfigFile.new(); saved.load(s.settings_path)
	_check(saved.get_value("graphics", "future_key", "") == "x" and saved.get_value("graphics", "version", 0) == 2, "chiavi sconosciute conservate e versione scritta")
	var env := Environment.new(); var sun := DirectionalLight3D.new()
	s.set_preset(GameSettingsService.Preset.MAX)
	s.apply_to_world(env, sun)
	_check(env.sdfgi_enabled and env.volumetric_fog_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "apply_to_world: Massimo")
	s.set_preset(GameSettingsService.Preset.STEAM_DECK)
	s.apply_to_world(env, sun)
	_check(not env.sdfgi_enabled and not env.ssil_enabled and not env.volumetric_fog_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL, "apply_to_world: Deck")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.settings_path))
	root.remove_child(s); s.free(); sun.free()
```

Run: `godot_console --headless --path godot --fixed-fps 60 --script res://tests/settings_tests.gd` → errore di parse (`set_preset` inesistente) → FAIL.

- [ ] **Step 2: `graphics_quality.gd`**

```gdscript
class_name GraphicsQuality
extends RefCounted
## Tabella dei preset grafici (spec §5.2) e applicazione a Environment e sole.

const PRESETS: Dictionary = {
	GameSettingsService.Preset.STEAM_DECK: {"msaa_3d": Viewport.MSAA_DISABLED, "screen_aa": 1, "shadow_quality": 1, "ssao_quality": 1, "gi_mode": 0, "glow_quality": 1, "volumetric_fog": false, "texture_quality": 1, "vegetation_density": 1, "render_scale": 0.85, "fsr_upscaling": true},
	GameSettingsService.Preset.LOW: {"msaa_3d": Viewport.MSAA_DISABLED, "screen_aa": 1, "shadow_quality": 1, "ssao_quality": 0, "gi_mode": 0, "glow_quality": 0, "volumetric_fog": false, "texture_quality": 0, "vegetation_density": 0, "render_scale": 0.75, "fsr_upscaling": true},
	GameSettingsService.Preset.MEDIUM: {"msaa_3d": Viewport.MSAA_2X, "screen_aa": 0, "shadow_quality": 2, "ssao_quality": 1, "gi_mode": 0, "glow_quality": 1, "volumetric_fog": false, "texture_quality": 1, "vegetation_density": 1, "render_scale": 1.0, "fsr_upscaling": false},
	GameSettingsService.Preset.HIGH: {"msaa_3d": Viewport.MSAA_4X, "screen_aa": 0, "shadow_quality": 2, "ssao_quality": 2, "gi_mode": 1, "glow_quality": 2, "volumetric_fog": false, "texture_quality": 1, "vegetation_density": 2, "render_scale": 1.0, "fsr_upscaling": false},
	GameSettingsService.Preset.MAX: {"msaa_3d": Viewport.MSAA_4X, "screen_aa": 1, "shadow_quality": 3, "ssao_quality": 2, "gi_mode": 2, "glow_quality": 2, "volumetric_fog": true, "texture_quality": 1, "vegetation_density": 2, "render_scale": 1.0, "fsr_upscaling": false},
}
const SHADOW_SIZES := [1024, 1024, 2048, 4096]
const SHADOW_MODES := [DirectionalLight3D.SHADOW_ORTHOGONAL, DirectionalLight3D.SHADOW_ORTHOGONAL,
	DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS]
const VEGETATION := [0.35, 0.65, 1.0]

static func apply(s: GameSettingsService, environment: Environment, sun: DirectionalLight3D) -> void:
	if sun != null:
		sun.shadow_enabled = s.shadow_quality > 0
		sun.directional_shadow_mode = SHADOW_MODES[s.shadow_quality]
		RenderingServer.directional_shadow_atlas_set_size(SHADOW_SIZES[s.shadow_quality], true)
	if environment == null:
		return
	environment.ssao_enabled = s.ssao_quality > 0
	environment.ssao_intensity = 1.0 if s.ssao_quality == 1 else 1.6
	environment.ssil_enabled = s.gi_mode == 1
	environment.sdfgi_enabled = s.gi_mode == 2
	if s.gi_mode == 2:
		environment.sdfgi_cascades = 4
		environment.sdfgi_min_cell_size = 0.3
		environment.sdfgi_use_occlusion = true
	environment.glow_enabled = s.glow_quality > 0
	environment.glow_intensity = 0.3 if s.glow_quality == 1 else 0.55
	environment.volumetric_fog_enabled = s.volumetric_fog
	if s.volumetric_fog:
		environment.volumetric_fog_density = 0.012
		environment.volumetric_fog_albedo = Color(0.95, 0.85, 0.7)
		environment.volumetric_fog_sun_scatter = 0.3
```

- [ ] **Step 3: `GameSettingsService`**

Aggiungere costanti, campi, `VERSION := 2`, `_unknown: Dictionary[String, Dictionary]` (sezione → {chiave: valore}); in `load_settings`: dopo le letture, per ogni sezione e chiave non riconosciuta salvare in `_unknown`; `preset` letto con `_validated_int(..., PRESET_VALUES, Preset.HIGH)`; se il file non esiste e `is_steam_deck()` → `set_preset(STEAM_DECK)` senza salvare (`preset_chosen = false`). In `save_settings`: `config.set_value("graphics", "version", VERSION)` e riscrittura di `_unknown`. Setter:

```gdscript
func set_preset(value: int) -> void:
	preset = _validated_int(value, PRESET_VALUES, Preset.HIGH)
	if preset != Preset.CUSTOM:
		for key: String in GraphicsQuality.PRESETS[preset]:
			set(key, GraphicsQuality.PRESETS[preset][key])
	preset_chosen = true
	_apply_and_save()

func _set_quality(field: StringName, value: Variant) -> void:
	if get(field) == value:
		return
	set(field, value)
	preset = Preset.CUSTOM
	_apply_and_save()

func set_shadow_quality(v: int) -> void: _set_quality(&"shadow_quality", clampi(v, 0, 3))
func set_ssao_quality(v: int) -> void: _set_quality(&"ssao_quality", clampi(v, 0, 2))
func set_gi_mode(v: int) -> void: _set_quality(&"gi_mode", clampi(v, 0, 2))
func set_glow_quality(v: int) -> void: _set_quality(&"glow_quality", clampi(v, 0, 2))
func set_volumetric_fog(v: bool) -> void: _set_quality(&"volumetric_fog", v)
func set_texture_quality(v: int) -> void: _set_quality(&"texture_quality", clampi(v, 0, 1))
func set_vegetation_density(v: int) -> void: _set_quality(&"vegetation_density", clampi(v, 0, 2))
func set_screen_aa(v: int) -> void: _set_quality(&"screen_aa", clampi(v, 0, 2))
func set_fsr_upscaling(v: bool) -> void: _set_quality(&"fsr_upscaling", v)
```

`set_msaa_3d` e `set_render_scale` esistenti passano anch'essi per `preset = Preset.CUSTOM`. In `apply_settings`: `viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if screen_aa == 1 else SCREEN_SPACE_AA_DISABLED; viewport.use_taa = screen_aa == 2; viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if fsr_upscaling and render_scale < 1.0 else SCALING_3D_MODE_BILINEAR; viewport.texture_mipmap_bias = 0.0 if texture_quality == 1 else 1.0` (ognuno solo se cambia). `apply_to_world(environment, sun)` chiama `GraphicsQuality.apply(self, environment, sun)`; `vegetation_multiplier()` restituisce `GraphicsQuality.VEGETATION[vegetation_density]`.

In `OvergrownArena`: alla fine di `_add_environment()`:

```gdscript
	var settings := get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.apply_to_world(environment, get_node_or_null(^"SunLight"))
		if not settings.changed.is_connected(_on_settings_changed):
			settings.changed.connect(_on_settings_changed)

func _on_settings_changed() -> void:
	var settings := get_node_or_null(^"/root/GameSettings")
	var we := get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if settings != null and we != null:
		settings.apply_to_world(we.environment, get_node_or_null(^"SunLight"))
```

e in `_build_ground_cover()` i conteggi `grass_tufts`, `flowers`, `litter` moltiplicati per `settings.vegetation_multiplier()` se l'autoload c'è (densità applicata alla prossima costruzione dell'arena; documentare in `PLATFORM_AND_INPUT.md`).

- [ ] **Step 4: Test**

`settings_tests` → PASS (aggiornare anche il test esistente sul default fps 120 → 60). `restyle_tests`: aggiungere `_test_world_applies_preset()` che apre `arena_run`, imposta `root.get_node("GameSettings").set_preset(MAX)` e verifica `env.sdfgi_enabled`, poi `STEAM_DECK` e verifica `not env.sdfgi_enabled`. Verificare il Review Focus 5: `ruins_arena_tests` e `district_tests` restano verdi (l'autoload esiste nei test? In `--script` gli autoload di `project.godot` vengono caricati: il nodo `/root/GameSettings` c'è ma non carica il file; il codice tollera comunque `null`).

- [ ] **Step 5: Gate e commit**

```bash
git add godot/scripts/services/game_settings.gd godot/scripts/services/graphics_quality.gd godot/scripts/arena/overgrown_arena.gd godot/tests/settings_tests.gd godot/tests/restyle_tests.gd
git commit -m "Preset grafici (Steam Deck, Basso, Medio, Alto, Massimo, Personalizzato) e opzioni singole nel servizio impostazioni; fps fino a 240 e Illimitato, default 60; settings.cfg versionato con chiavi sconosciute conservate; rilevamento Deck"
```

---

### Task 8: Menu Impostazioni con preset, opzioni singole e scorrimento

**Files:**
- Modify: `godot/scenes/ui/pause_menu.tscn` (nodo `SettingsPanel`)
- Modify: `godot/scripts/ui/settings_menu.gd`
- Modify: `godot/tests/settings_tests.gd`, `godot/tests/button_prompts_tests.gd` se tocca i prompt

**Interfaces:**
- Consumes: setter di Task 7.
- Produces: righe `PresetRow/PresetOption`, `ShadowRow/ShadowOption`, `SsaoRow/SsaoOption`, `GiRow/GiOption`, `GlowRow/GlowOption`, `VolumetricRow/VolumetricCheck`, `TextureRow/TextureOption`, `VegetationRow/VegetationOption`, `ScreenAaRow/ScreenAaOption`, `FsrRow/FsrCheck`, `CameraRow/CameraOption` (Task 10); `Content` dentro uno `ScrollContainer` (`follow_focus = true`, altezza massima 620 px); `open()` dà il fuoco a `PresetOption`.

- [ ] **Step 1: Test che fallisce**

In `settings_tests.gd`, dove oggi si verifica il fuoco su `FpsOption` (riga 249), cambiare in `PresetOption` e aggiungere:

```gdscript
	var menu: SettingsMenu = pause.get_node("%SettingsPanel")
	var preset_option: OptionButton = menu.get_node("%PresetOption")
	_check(preset_option.item_count == 6, "sei voci di preset")
	preset_option.select(4); preset_option.item_selected.emit(4)
	_check(settings.preset == GameSettingsService.Preset.MAX, "scegliere Massimo dal menu imposta il preset")
	var gi: OptionButton = menu.get_node("%GiOption")
	gi.select(1); gi.item_selected.emit(1)
	_check(settings.preset == GameSettingsService.Preset.CUSTOM and preset_option.selected == 5, "toccare GI mostra Personalizzato")
	var fps: OptionButton = menu.get_node("%FpsOption")
	_check(fps.item_count == 8 and fps.get_item_text(7) == "Illimitato", "limite fps con otto voci, l'ultima Illimitato")
	_check(menu.get_node("%Content").get_parent() is ScrollContainer, "il contenuto scorre")
```

Run → FAIL (nodi mancanti).

- [ ] **Step 2: Scena**

In `pause_menu.tscn`, dentro `SettingsPanel/Margin`, inserire `Scroll` (`ScrollContainer`, `follow_focus = true`, `horizontal_scroll_mode = 0`, `custom_minimum_size = Vector2(0, 620)`) e spostare `Content` sotto di esso (`unique_name_in_owner = true` su `Content`). Aggiungere, dopo `GraphicsHeader`, la riga `PresetRow` con il template delle righe esistenti (`Label` 280 px + `OptionButton` 300x40, `unique_name_in_owner`) e, dopo `ScaleRow`, le righe `ShadowRow`, `SsaoRow`, `GiRow`, `GlowRow`, `VolumetricRow` (`CheckButton` `VolumetricCheck`), `TextureRow`, `VegetationRow`, `ScreenAaRow`, `FsrRow` (`CheckButton` `FsrCheck`). Etichette: "Preset grafico", "Qualità ombre", "Occlusione ambientale", "Illuminazione globale", "Bagliore", "Nebbia volumetrica", "Qualità texture", "Densità vegetazione", "Antialiasing a schermo", "Upscaling FSR 2".

- [ ] **Step 3: Script**

```gdscript
@onready var _preset_option: OptionButton = %PresetOption
@onready var _shadow_option: OptionButton = %ShadowOption
# ... uno per riga
const PRESET_LABELS := ["Steam Deck", "Basso", "Medio", "Alto (predefinito)", "Massimo", "Personalizzato"]

func _fill_options() -> void:
	_add_items(_preset_option, PRESET_LABELS)
	_add_items(_fps_option, ["30", "60 (predefinito)", "90", "120", "144", "165", "240", "Illimitato"])
	_add_items(_shadow_option, ["Off", "Bassa", "Media", "Alta"])
	_add_items(_ssao_option, ["Off", "Bassa", "Alta"])
	_add_items(_gi_option, ["Off", "SSIL", "SDFGI"])
	_add_items(_glow_option, ["Off", "Basso", "Alto"])
	_add_items(_texture_option, ["Bassa", "Alta"])
	_add_items(_vegetation_option, ["Bassa", "Media", "Alta"])
	_add_items(_screen_aa_option, ["Off", "FXAA", "TAA"])
	# ... vsync, msaa, window, scale come oggi

func _sync_from_settings() -> void:
	_preset_option.select(_settings.preset)
	_shadow_option.select(_settings.shadow_quality)
	# ... ogni opzione; i CheckButton con set_pressed_no_signal
	# fps, vsync, msaa, window, scale, volumi, inversione come oggi

func _on_preset_selected(index: int) -> void:
	if index != _settings.preset:
		_settings.set_preset(index)
		_sync_from_settings()

func _on_quality_selected(setter: Callable, index: int) -> void:
	setter.call(index)
	_preset_option.select(_settings.preset)
```

In `_ready` collegare `item_selected` di ogni opzione a `_on_quality_selected.bind(_settings.set_shadow_quality)` ecc. (attenzione all'ordine degli argomenti con `bind`: `item_selected` passa `index` per primo, quindi `func _on_quality_selected(index: int, setter: Callable)`); i CheckButton a `_settings.set_volumetric_fog`/`set_fsr_upscaling` più `_preset_option.select(_settings.preset)` in un lambda. `open()`: `_preset_option.grab_focus()`. Il pulsante Indietro resta sotto lo scroll, fuori da esso, così è sempre visibile.

- [ ] **Step 4: Test manuale a controller**

`godot --path godot`: Esc → Impostazioni → navigare con il D-pad fino in fondo: lo scroll segue il fuoco, B torna indietro. Headless: `settings_tests` → PASS.

- [ ] **Step 5: Gate e commit**

```bash
git add godot/scenes/ui/pause_menu.tscn godot/scripts/ui/settings_menu.gd godot/tests/settings_tests.gd
git commit -m "Impostazioni: preset grafico, opzioni singole (ombre, SSAO, GI, bagliore, volumetrica, texture, vegetazione, AA a schermo, FSR), limite fps esteso, pannello scorrevole"
```

---

### Task 9: Benchmark per preset e verifica delle soglie

**Files:**
- Modify: `godot/tests/tools/benchmark_arena.gd`
- Modify: `docs/GODOT_WORKFLOW.md`

**Interfaces:**
- Produces: argomento `--preset=<deck|low|medium|high|max>` che chiama `GameSettings.set_preset()` prima dell'istanza della scena; la riga `render` stampa anche `preset=<nome>`.

- [ ] **Step 1: Argomento e stampa**

```gdscript
const PRESET_ARGS := {"deck": GameSettingsService.Preset.STEAM_DECK, "low": GameSettingsService.Preset.LOW,
	"medium": GameSettingsService.Preset.MEDIUM, "high": GameSettingsService.Preset.HIGH, "max": GameSettingsService.Preset.MAX}
# nel ciclo degli argomenti:
	elif arg.begins_with("--preset="):
		var settings := root.get_node_or_null("GameSettings")
		if settings != null:
			settings.set_preset(PRESET_ARGS[arg.trim_prefix("--preset=")])
			preset_name = arg.trim_prefix("--preset=")
# nella riga render:
print("PROTOTYPE01_ARENA_BENCH render preset=%s draw_calls=%d primitives=%d objects=%d video_mem_mb=%.0f" % [preset_name, ...])
```

- [ ] **Step 2: Misurare e registrare**

Run, con finestra: `godot_console --path godot --resolution 1280x800 --script res://tests/tools/benchmark_arena.gd -- --enemies=70 --preset=high` e `--preset=max`, `--preset=deck`.
Expected: Alto `avg_frame_ms ≤ 12`, `draw_calls ≤ 450`, `primitives ≤ 3000000`, `video_mem_mb ≤ 300`; Massimo `avg_frame_ms ≤ 16`, `draw_calls ≤ 600`. Se una soglia salta: per draw call ridurre `bush_count` o unire le cartelle dei cespugli in un MultiMesh; per primitive, `vegetation_density`; per VRAM, tile `walls`/`plants` a 1024; per ms su Massimo, `sdfgi_cascades = 3`. Riportare i numeri in `docs/GODOT_WORKFLOW.md` (tabella misure) e nel messaggio di commit.

- [ ] **Step 3: Commit**

```bash
git add godot/tests/tools/benchmark_arena.gd docs/GODOT_WORKFLOW.md
git commit -m "Benchmark con --preset=: misure per Steam Deck, Alto e Massimo dopo la fetta dell'ambiente"
```

---

### Task 10: Camera a tre distanze

**Files:**
- Modify: `godot/project.godot` ([input]: `camera_zoom_cycle`, `camera_zoom_in`, `camera_zoom_out`)
- Modify: `godot/scripts/camera/isometric_camera_rig.gd`
- Modify: `godot/scripts/services/game_settings.gd` (`camera_distance`, `set_camera_distance`)
- Modify: `godot/scripts/enemies/enemy_director.gd` (`ring_scale`)
- Modify: `godot/scripts/run/arena_run.gd` (collega rig → direttore)
- Modify: `godot/scripts/ui/run_hud.gd` (quinto prompt), `godot/scripts/ui/settings_menu.gd` + `pause_menu.tscn` (`CameraRow/CameraOption`)
- Modify: `godot/tests/restyle_tests.gd`, `godot/tests/button_prompts_tests.gd:80` (4 → 5), `godot/tests/path_field_tests.gd` se usa i valori dell'anello
- Modify: `docs/PLATFORM_AND_INPUT.md`

**Interfaces:**
- Produces: `IsometricCameraRig.DISTANCE_PRESETS_CM := [1100.0, 1500.0, 2000.0]`, `var distance_index := 1`, `signal distance_changed(index: int, arm_m: float)`, `func set_distance_index(index: int, instant := false) -> void`, `func cycle_distance() -> void`, `func current_arm_m() -> float`; interpolazione in `_process` con `lerp` esponenziale (costante 12/s, circa 0,25 s); input gestito in `_unhandled_input` del rig con `is_action_pressed(&"camera_zoom_cycle")`, `camera_zoom_in`, `camera_zoom_out`. `EnemyDirector.ring_scale := 1.0` moltiplica `spawn_ring_min`, `spawn_ring_max`, `spawn_min_player_distance` in `_find_spawn_point` e nel leash. `ArenaRun` collega `distance_changed` → `director.ring_scale = arm_m / 15.0` e `GameSettings.set_camera_distance(index)`; all'avvio legge `camera_distance` dalle impostazioni e chiama `set_distance_index(..., true)`.

- [ ] **Step 1: Test che fallisce**

```gdscript
func _test_camera_distance() -> void:
	print("camera distance")
	_scene = RunScene.instantiate(); root.add_child(_scene)
	var director: EnemyDirector = _scene.get_node(^"EnemyDirector")
	director.spawning = false
	await _frames(5)
	var rig: IsometricCameraRig = _scene.get_node(^"CameraRig")
	_check(is_equal_approx(rig.current_arm_m(), 15.0), "parte a 15 m")
	var ev := InputEventJoypadButton.new(); ev.button_index = JOY_BUTTON_Y; ev.pressed = true
	Input.parse_input_event(ev); ev = ev.duplicate(); ev.pressed = false; Input.parse_input_event(ev)
	await _frames(2)
	_check(rig.distance_index == 2, "Y passa al preset lontano")
	await _frames(40)
	_check(absf(rig.current_arm_m() - 20.0) < 0.2, "il braccio arriva a 20 m in meno di 0,7 s")
	_check(director.ring_scale > 1.3 and director.ring_scale * director.tuning.spawn_ring_min >= 22.0, "l'anello di comparsa si allarga con la camera lontana")
	var wheel := InputEventMouseButton.new(); wheel.button_index = MOUSE_BUTTON_WHEEL_UP; wheel.pressed = true
	wheel.position = Vector2(640, 400); wheel.global_position = wheel.position
	Input.parse_input_event(wheel)
	await _frames(2)
	_check(rig.distance_index == 1, "la rotellina in su avvicina di un preset")
	var settings := root.get_node_or_null("GameSettings")
	_check(settings == null or settings.camera_distance == 1, "la distanza si salva nelle impostazioni")
	root.remove_child(_scene); _scene.queue_free(); await _frames(2)
```

Run → FAIL (`current_arm_m` inesistente).

- [ ] **Step 2: Input map**

Aggiungere a `project.godot`, sezione `[input]`, dopo `pause`:

```
camera_zoom_cycle={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":67,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":3,"pressure":0.0,"pressed":false,"script":null)
]
}
camera_zoom_in={
"deadzone": 0.5,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":4,"canceled":false,"pressed":false,"double_click":false,"script":null)
]
}
camera_zoom_out={
"deadzone": 0.5,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":5,"canceled":false,"pressed":false,"double_click":false,"script":null)
]
}
```

- [ ] **Step 3: Rig**

```gdscript
const DISTANCE_PRESETS_CM: Array[float] = [1100.0, 1500.0, 2000.0]
const DISTANCE_SMOOTHING := 12.0
signal distance_changed(index: int, arm_m: float)
var distance_index := 1
var _arm_target_cm := 1500.0

func set_distance_index(index: int, instant := false) -> void:
	distance_index = clampi(index, 0, DISTANCE_PRESETS_CM.size() - 1)
	_arm_target_cm = DISTANCE_PRESETS_CM[distance_index]
	if instant:
		arm_length_cm = _arm_target_cm
	distance_changed.emit(distance_index, UnrealSpace.length(_arm_target_cm))

func cycle_distance() -> void:
	set_distance_index((distance_index + 1) % DISTANCE_PRESETS_CM.size())

func current_arm_m() -> float:
	return UnrealSpace.length(arm_length_cm)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed(&"camera_zoom_cycle"):
		cycle_distance()
	elif event.is_action_pressed(&"camera_zoom_in"):
		set_distance_index(distance_index - 1)
	elif event.is_action_pressed(&"camera_zoom_out"):
		set_distance_index(distance_index + 1)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_equal_approx(arm_length_cm, _arm_target_cm):
		var k := 1.0 - exp(-DISTANCE_SMOOTHING * delta)
		arm_length_cm = _arm_target_cm if absf(arm_length_cm - _arm_target_cm) < 1.0 else lerpf(arm_length_cm, _arm_target_cm, k)
	if target != null:
		global_position = target.get_global_transform_interpolated().origin
```

In `_ready`, dopo `_apply()`: `_arm_target_cm = arm_length_cm` (così `live_rebuild_tests` che impone `arm_length_cm = 2000` resta valido: aggiungere lì `rig.set_distance_index(...)` non serve, ma il setter di `arm_length_cm` deve aggiornare anche `_arm_target_cm`; farlo nel setter esistente: `_arm_target_cm = value`). Nota: `_process` non deve sovrascrivere un valore impostato dall'editor o dai test, da cui l'allineamento nel setter.

- [ ] **Step 4: Direttore, run, HUD, impostazioni**

`EnemyDirector`: `var ring_scale := 1.0`; in `_find_spawn_point` `radius = rng.randf_range(tuning.spawn_ring_min, tuning.spawn_ring_max) * ring_scale` e `spawn_min_player_distance * ring_scale`; nel leash `tuning.spawn_ring_max * ring_scale + 1.0`.

`ArenaRun._ready` (dopo aver trovato `rig` e `director`):

```gdscript
	var rig: IsometricCameraRig = get_node_or_null(^"../CameraRig")
	if rig != null:
		rig.distance_changed.connect(_on_camera_distance_changed)
		var settings := get_node_or_null(^"/root/GameSettings")
		rig.set_distance_index(settings.camera_distance if settings != null else 1, true)

func _on_camera_distance_changed(index: int, arm_m: float) -> void:
	director.ring_scale = arm_m / 15.0
	var settings := get_node_or_null(^"/root/GameSettings")
	if settings != null and settings.camera_distance != index:
		settings.set_camera_distance(index)
```

`GameSettingsService`: `var camera_distance := 1`, salvato in `controls`, `set_camera_distance(v)` → `_save_and_emit()` (non è una qualità grafica, non tocca il preset). `RunHud`: quinto prompt `[&"camera_zoom_cycle", "Distanza camera"]`; `button_prompts_tests.gd:80` → `== 5`. `SettingsMenu`: riga `CameraRow/CameraOption` ("Distanza camera": "Vicina", "Normale (predefinita)", "Lontana") che chiama `set_camera_distance`; il rig in scena ascolta `GameSettings.changed` e riallinea `distance_index` se diverso.

- [ ] **Step 5: Test e documenti**

`restyle_tests`, `button_prompts_tests`, `live_rebuild_tests`, `path_field_tests`, `district_tests`, `input_events_tests`, `settings_tests` → PASS. `docs/PLATFORM_AND_INPUT.md`: schema input con Y / C / rotellina e la riga "Distanza camera" nelle impostazioni.

- [ ] **Step 6: Gate e commit**

```bash
git add godot/project.godot godot/scripts/camera/isometric_camera_rig.gd godot/scripts/services/game_settings.gd godot/scripts/enemies/enemy_director.gd godot/scripts/run/arena_run.gd godot/scripts/ui/run_hud.gd godot/scripts/ui/settings_menu.gd godot/scenes/ui/pause_menu.tscn godot/tests docs/PLATFORM_AND_INPUT.md
git commit -m "Camera a tre distanze (11, 15, 20 m) con Y, C e rotellina, interpolata, salvata nelle impostazioni; anello di comparsa scalato con la distanza; prompt nell'HUD"
```

---

### Task 11: Catture prima/dopo, documenti e consegna

**Files:**
- Modify: `docs/ART_DIRECTION.md`, `docs/DECISIONS.md` (D-077, D-078), `docs/PROJECT_ROADMAP.md`, `docs/MIGRATION_STATUS.md`, `docs/INDEX.md`, `docs/GODOT_WORKFLOW.md`
- Output (non versionato): `output/restyle/district/`, `output/restyle/night/`, `output/restyle/before/` (copia delle catture attuali `output/district/` e `output/night/` fatte **prima** di iniziare Task 3)

- [ ] **Step 1: Prima di Task 3, conservare il "prima"**

Run: `mkdir -p output/restyle/before && cp output/district/*.png output/restyle/before/ && cp output/night/*.png output/restyle/before/` (se le cartelle non ci sono, rigenerarle sul commit `365ce5f` con `capture_district.gd` e `capture_night.gd`).

- [ ] **Step 2: Catture finali**

`capture_district.gd -- --out=../output/restyle/district`, `capture_night.gd -- --out=../output/restyle/night`, closeup `wall_close`, `ruin_close`, `grass_close`, `tree_close`, `car_close` in `output/restyle/district`. Verificare che ogni `CAPTURE <name> err=0`.

- [ ] **Step 3: Documenti**

- `ART_DIRECTION.md`: nuova sezione "Direzione dall'11 ottobre 2026 (D-077)": stilizzato ricco alla Hades II, regole comuni e tabella del roster dalla spec §2; segnare come superata la frase sul "nano steampunk" (resta vietato l'archetipo, non le proporzioni).
- `DECISIONS.md`: D-077 (restyling, pipeline propria, roster fisso, rovine dipinte in triplanare invece di `.glb`, preset grafici), D-078 (camera a tre distanze).
- `PROJECT_ROADMAP.md` "Stato operativo": fetta dell'ambiente fatta, prossimo passo giudizio del proprietario su `output/restyle/`, poi piano 2 (ingegnere), poi misura sul Deck.
- `MIGRATION_STATUS.md`: diario della sessione con le trappole trovate (es. `.import` delle tile da scrivere a mano, ORM dal glTF).
- `INDEX.md`: questo piano e il selftest/`build_surface_tiles.py`.
- `GODOT_WORKFLOW.md`: comandi delle tile, del benchmark per preset, tempi di bake.

- [ ] **Step 4: Gate completo, build e commit**

Run: gate → PASS. Export: `godot_console --headless --path godot --export-release "Windows Desktop" ../LocalBuilds/Prototype01-Godot-Win64/Prototype01.exe` e Linux; smoke test della build: `powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1 -Executable LocalBuilds/Prototype01-Godot-Win64/Prototype01.exe`.

```bash
git add docs
git commit -m "Restyling, fetta dell'ambiente chiusa: direzione artistica e roster (D-077), camera a tre distanze (D-078), roadmap, stato e indice; build riesportate"
```

Consegna al proprietario: elenco delle catture prima/dopo, misure per preset, soglie rispettate o no, cosa resta (Task 9 sul Deck fisico, piano 2 ingegnere).

---

## Self-review

**Spec coverage.** §3.1 pittore → Task 1; §3.2 scultore → non in questo piano (serve all'ingegnere, piano 2); §3.3 tile → Task 2; §3.4 rovine → Task 4 (deviazione dichiarata); §4 shader: terrain_cell/ruins_ground → Task 3, ruin_overgrown → Task 4, grass/foliage/env_baked → Task 5, actor_paint → rim in `textured_paint` (Task 6; lo shader `actor_paint` resta per i modelli blocky, nessun attore rifinito lo usa), rusted_metal invariato (binari, piano successivo), sky_painted → Task 6; §5.1 resa → Task 6; §5.2 preset e opzioni → Task 7-8; §6 camera → Task 10; §7 ordine → Task 1-11; §8 budget → Task 9; §9 verifica → `restyle_tests` in Task 2-7 e 10, `inspect_model` in Task 1, catture in Task 11; §11 documenti → Task 11. Vignetta: non implementata (nessun modo economico in `Environment`); annotata in D-077 come rinuncia.

**Placeholder.** Nessun TBD. I pattern dei nomi dei nodi `Bush*`/`Car*` in Task 5 vanno confermati leggendo `_bush`/`_car`: indicato nello step.

**Type consistency.** `GameSettingsService.Preset`, `set_preset`, `apply_to_world`, `vegetation_multiplier`, `camera_distance` usati in Task 7, 8, 9, 10 con gli stessi nomi; `IsometricCameraRig.distance_changed(index, arm_m)` in Task 10 e `ArenaRun._on_camera_distance_changed(index, arm_m)`; `TerrainGrid.apply_ground_tiles` e `OvergrownArena.apply_wall_tiles` statiche; array `plants_albedo` in grass e foliage con lo stesso nome.

**Review Focus.** 1 → Task 1 step 6 e Task 2 step 4; 2 → Task 7 step 1; 3 → Task 7 step 1 (`set_gi_mode(1)` dopo Massimo); 4 → Task 10 step 1; 5 → Task 7 step 4.
