# Terreno continuo, tappa B (ferrovia e addio alla griglia): piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Portare `railway_run.tscn` (treno, vagoni, saltatori, Trivella) e le scene minori sul rilievo continuo `TerrainField`, poi eliminare `TerrainGrid`, `TerrainState` e ogni ramo a celle, lasciando un solo sistema di terreno.

**Architecture:** `TerrainField` diventa rettangolare (`size_m: Vector2`, regioni Terrain3D N x M, chunk di collisione N x M, salvataggio versione 3 per livello) e riceve tre scritture nuove (`reset_to_base` a rettangolo per il treno, `bump_along` per la Trivella, `tint_rect`/`paint_layer_rect` per la fascia). `RailwayDistrict` produce pennellate come il quartiere (fascia piatta nella base, cortile a cavallo, vagoni = cumuli con vena, solchi paralleli). `TrainEvent` e `Driller` leggono quote e delta invece di stati di cella. Le scene minori restano su un campo da 128 m; il pericolo (`TerrainHazard`) e il Companion Slice spariscono. L'ultimo task cancella la griglia e tutti i suoi rami.

**Tech Stack:** Godot 4.7.2 GDScript, Terrain3D 1.0.2, Jolt, suite `tests/*.gd` headless con `godot_console`, gate `tools/godot/Invoke-GodotChecks.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-12-continuous-terrain-railway-design.md` (leggerla prima di ogni task; la tappa A e in `2026-10-12-continuous-terrain-design.md`).

## Global Constraints

- Engine **Godot 4.7.2**; comandi sempre con `godot_console` (mai `godot`), vedi `docs/GODOT_WORKFLOW.md`; prima di rilanciare una suite controllare che non ci siano processi `Godot*` stantii con `tests/` nella riga di comando.
- Passo dei vertici **0,5 m**; regioni Terrain3D da 256 vertici (128 m) centrate sull'origine, `ceil(half / 128) * 2` per asse; quote in [−2,5, +4] m.
- Fascia dei binari: **`abs(z) <= 3,6`** per tutta la lunghezza; rotaie a z = ±2,4; raccordo di 2 m ai lati nel rilievo di base.
- Pendenza massima di marcia 0,8 (saltatori 1,2; Trivella 10, con `floor_max_angle = atan(0,8)`).
- Argine per la Trivella: `delta_at >= 0,8` m; solco: 0,8 m sotto la base, raggio 1,2; varco: `level` a raggio 2,4 verso la base; **niente rottami dal varco** (solo dalle vene).
- Vagoni: cumuli `sculpt(c, 3,0, +1,5)` sulla fascia con vena da 8 rottami; il treno li spiana e azzera le vene senza rottami.
- Chunk di collisione 32 x 32 celle (16 m), `ceil(size / 16) + 1` per asse.
- Salvataggio della base: `TFLD` versione **3** (`resolution_x`, `resolution_z`, `size_m.x`, `size_m.y`, seme); percorso `res://levels/<level_id>/base.bin`, LFS (`*.bin` gia in `.gitattributes`), esportato (`include_filter` gia `levels/*/*.bin`).
- Identificatori, file e log in inglese; commenti e documenti in italiano; controller e tastiera/mouse equivalenti.
- Ogni task: `--check-only` sugli script toccati, suite pertinenti verdi, commit piccolo con messaggio in italiano e trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Dopo `--editor --quit` ripristinare `godot/project.godot` (`git checkout -- godot/project.godot`): il riordino non si committa.
- Non toccare i documenti di stato (`MIGRATION_STATUS.md`, `PROJECT_ROADMAP.md`) prima del Task 8.

## Review Focus

1. **Treno a cavallo dei confini delle regioni** (x = 0, x = ±128): `reset_to_base` su un rettangolo che attraversa due regioni e piu chunk deve lasciare la fascia piatta ovunque, senza cuciture. Test in Task 2 (`_test_reset_to_base`) e Task 4 (`_test_pass_flattens_and_hits`: argine a x = 0).
2. **Spinta fuori dalla fascia contro un argine alto**: il punto scelto deve essere calpestabile (delta < 0,5 e pendenza sotto la soglia), non la cima dell'argine. Test in Task 4 (`_test_pass_flattens_and_hits`, argine di atterraggio).
3. **Trivella contro un argine basso** (< 0,8 m): lo supera senza stordirsi. Test in Task 5 (`_test_low_mound_does_not_stop`).
4. **Seconda carica sullo stesso solco**: non scava oltre 0,8 m sotto la base. Test in Task 5 (`_test_furrow_is_idempotent`).
5. **Vagone scavato a meta e poi spianato**: la vena si azzera, i rottami gia usciti restano a terra. Test in Task 4 (`_test_half_dug_wagon`).

---

### Task 1: `TerrainField` rettangolare, salvataggio versione 3, base per livello

**Files:**
- Modify: `godot/scripts/terrain/terrain_field.gd`
- Modify: `godot/scripts/terrain/terrain_collision.gd`
- Modify: `godot/scripts/terrain/terrain_surface.gd` (`update_base`)
- Modify: `godot/resources/materials/terrain_relief.gdshader` (`base_half` → `vec2`)
- Modify: `godot/scripts/ui/run_map.gd` (`height_samples`, `sample_world`, `snapshot_heights`, `render_heights`, `_sample_at`)
- Modify: `godot/scripts/run/arena_run.gd` (`BASE_RELIEF_PATH` → `base_relief_path()`, `_check_scale`)
- Modify: `godot/scripts/arena/ruins_district.gd` (`apply_base_relief`, `paint_surface`: due risoluzioni e `half_extents()`)
- Modify: `godot/scripts/arena/overgrown_arena.gd` (`settle_on_relief`, `_relief_ready`)
- Modify: `godot/scripts/terrain/lamp_field.gd` (`can_place`: limiti con `half_extents()`)
- Modify: `godot/scripts/run/quake_event.gd` (limite della faglia con `half_extents()`)
- Modify: `godot/tests/tools/bake_terrain_base.gd` (`-- --level=<id>`), `godot/tests/tools/benchmark_arena.gd` (vertici)
- Modify: `godot/scenes/main/arena_run.tscn` (`size_m = Vector2(204, 204)`), tutte le suite che fanno `size_m = 64.0` (`terrain_field_tests`, `terrain_brush_tests`, `terrain_horde_tests`, `economy_tests`, `flow_preview_tests`, `menu_tests`: `grep -rn "size_m = " godot/tests`)
- Test: `godot/tests/terrain_field_tests.gd`
- Regenerate: `godot/levels/district/base.bin`

**Interfaces:**
- Produces: `TerrainField.size_m: Vector2`, `resolution_x: int`, `resolution_z: int`, `half_extents() -> Vector2`, `half_extent() -> float` (= X), `SAVE_VERSION = 3`, `ArenaRun.base_relief_path() -> String`, `RunMap.height_samples(field, step) -> Vector2i`, `TerrainSurface.update_base(terrain, base, resolution_x, resolution_z, half: Vector2)`.
- Consumes: niente di nuovo.

- [ ] **Step 1: Test che fallisce** — in `terrain_field_tests.gd` aggiungere e chiamare subito dopo `_test_flat_start()`:

```gdscript
## Campo rettangolare (spec tappa B, sezione 2): indici, quote, regioni e chunk per asse.
func _test_rectangular_field() -> void:
	print("rectangular field")
	var field := TerrainField.new()
	field.size_m = Vector2(96.0, 32.0)
	field.tuning = TerrainTuning.new()
	root.add_child(field)
	await _frames(2)
	_check(field.resolution_x == 193 and field.resolution_z == 65, "96 x 32 m -> 193 x 65 vertici (%d x %d)" % [field.resolution_x, field.resolution_z])
	_check(field.half_extents().is_equal_approx(Vector2(48.0, 16.0)), "semilati 48 x 16 (%s)" % field.half_extents())
	field.sculpt(Vector3(40.0, 0.0, -10.0), 2.4, 1.0)
	_check(absf(field.height_at(Vector3(40.0, 0.0, -10.0)) - 1.0) < 0.01, "pennellata vicino all'angolo lontano: quota 1 al centro")
	_check(is_zero_approx(field.height_at(Vector3(-40.0, 0.0, 10.0))), "l'angolo opposto resta a zero")
	var collision: TerrainCollision = field.get_node(^"Collision")
	_check(collision.chunk_count() == 7 * 3, "chunk 7 x 3 (%d)" % collision.chunk_count())
	var space := root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(40.0, 5.0, -10.0), Vector3(40.0, -5.0, -10.0), 1))
	_check(not hit.is_empty() and absf(hit.position.y - 1.0) < 0.1, "la collisione segue la quota anche in un campo rettangolare")
	var path := "user://rect_base_test.bin"
	field.commit_base()
	var bytes := field.save_base(path, 5)
	var other := TerrainField.new()
	other.size_m = Vector2(96.0, 32.0)
	other.tuning = TerrainTuning.new()
	root.add_child(other)
	await _frames(2)
	_check(bytes > 0 and other.load_base(path, 5), "salvataggio versione 3 e ricarica su un campo uguale")
	_check(absf(other.height_at(Vector3(40.0, 0.0, -10.0)) - 1.0) < 0.01, "le quote ricaricate sono le stesse")
	var square := TerrainField.new()
	square.size_m = Vector2(96.0, 96.0)
	square.tuning = TerrainTuning.new()
	root.add_child(square)
	await _frames(2)
	_check(not square.load_base(path, 5), "un campo di altra forma rifiuta il file")
	var old := FileAccess.open("user://rect_base_v2.bin", FileAccess.WRITE)
	old.store_buffer("TFLD".to_ascii_buffer())
	old.store_32(2)
	old.close()
	_check(not other.load_base("user://rect_base_v2.bin", 5), "la versione 2 non si legge piu")
	for node in [field, other, square]:
		node.queue_free()
	await _frames(2)
```

- [ ] **Step 2: Eseguire e vedere il FAIL**

```
godot_console --headless --path godot --fixed-fps 60 --script res://tests/terrain_field_tests.gd
```
Atteso: errore di parse (`size_m` e `float`, `resolution_x` non esiste) o `FAIL 96 x 32 m`.

- [ ] **Step 3: Implementare `TerrainField` rettangolare** — in `terrain_field.gd`:

```gdscript
const SAVE_VERSION := 3

@export var size_m := Vector2(204.0, 204.0)

var resolution_x := 0
var resolution_z := 0
var _half := Vector2.ZERO


func _ready() -> void:
	if tuning == null:
		tuning = TerrainTuning.new()
	resolution_x = int(round(size_m.x / SPACING)) + 1
	resolution_z = int(round(size_m.y / SPACING)) + 1
	_half = Vector2((resolution_x - 1) * SPACING * 0.5, (resolution_z - 1) * SPACING * 0.5)
	_heights.resize(resolution_x * resolution_z)
	_heights.fill(0.0)
	_base = _heights.duplicate()
	_protected.resize(resolution_x * resolution_z)
	_protected.fill(0)
	_collision = TerrainCollision.new()
	_collision.name = "Collision"
	add_child(_collision)
	_collision.setup(self)
	if render and not DisplayServer.get_name() == "headless":
		_build_terrain3d()
	print("PROTOTYPE01_TERRAIN_FIELD_READY resolution=%dx%d size_m=%.0fx%.0f" % [resolution_x, resolution_z, size_m.x, size_m.y])


## Semilato lungo X (comodita per i chiamanti quadrati); per le scale usare `half_extents()`.
func half_extent() -> float:
	return _half.x


func half_extents() -> Vector2:
	return _half
```

Sostituire ogni `resolution` con `resolution_x`/`resolution_z` e ogni `_half` scalare con `_half.x` (asse X) o `_half.y` (asse Z):

```gdscript
func _index_of(p: Vector3) -> int:
	var ix := int(round((p.x + _half.x) / SPACING))
	var iz := int(round((p.z + _half.y) / SPACING))
	if ix < 0 or iz < 0 or ix >= resolution_x or iz >= resolution_z:
		return -1
	return iz * resolution_x + ix


func _vertex_world(i: int) -> Vector3:
	var ix := i % resolution_x
	var iz := i / resolution_x
	return Vector3(ix * SPACING - _half.x, _heights[i], iz * SPACING - _half.y)


func _sample(array: PackedFloat32Array, p: Vector3) -> float:
	var fx := clampf((p.x + _half.x) / SPACING, 0.0, resolution_x - 1.001)
	var fz := clampf((p.z + _half.y) / SPACING, 0.0, resolution_z - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * resolution_x + ix
	var top := lerpf(array[i], array[i + 1], tx)
	var bottom := lerpf(array[i + resolution_x], array[i + resolution_x + 1], tx)
	return lerpf(top, bottom, tz)


## Indici (x0, z0, x1, z1) dei vertici del rettangolo XZ, tagliati al campo.
func _rect_indices(center: Vector3, half_size: Vector2) -> Array[int]:
	return [
		maxi(int(floor((center.x - half_size.x + _half.x) / SPACING)), 0),
		maxi(int(floor((center.z - half_size.y + _half.y) / SPACING)), 0),
		mini(int(ceil((center.x + half_size.x + _half.x) / SPACING)), resolution_x - 1),
		mini(int(ceil((center.z + half_size.y + _half.y) / SPACING)), resolution_z - 1),
	]


func _full_aabb() -> AABB:
	return AABB(Vector3(-_half.x, MIN_HEIGHT, -_half.y), Vector3(_half.x * 2.0, MAX_HEIGHT - MIN_HEIGHT, _half.y * 2.0))


func _emit_rect_changed(x0: int, z0: int, x1: int, z1: int) -> void:
	var lo := Vector3(x0 * SPACING - _half.x, MIN_HEIGHT, z0 * SPACING - _half.y)
	var hi := Vector3(x1 * SPACING - _half.x, MAX_HEIGHT, z1 * SPACING - _half.y)
	region_changed.emit(AABB(lo, hi - lo))
```

`_disc_points`, `_brush` e `_raise_volume` usano `_rect_indices(center, Vector2(radius, radius))` per i limiti e `iz * resolution_x + ix` per l'indice; `_brush` finisce con `_mirror_rect(x0, z0, x1, z1)` e `_emit_rect_changed(x0, z0, x1, z1)`. `load_base` e `apply_base_relief` emettono `_full_aabb()`. `_mirror_all` → `_mirror_rect(0, 0, resolution_x - 1, resolution_z - 1)`; in `_mirror_rect` l'indice e `iz * resolution_x + ix` e le coordinate mondo usano `_half.x`/`_half.y`. `commit_base` chiama `TerrainSurface.update_base(_terrain, _base, resolution_x, resolution_z, _half)`.

Regioni in `_build_terrain3d`:

```gdscript
	var region_m := REGION_SIZE * SPACING
	var nx := int(ceil(_half.x / region_m))
	var nz := int(ceil(_half.y / region_m))
	for gx in range(-nx, nx):
		for gz in range(-nz, nz):
			_terrain.data.add_region_blankp(Vector3((gx + 0.5) * region_m, 0.0, (gz + 0.5) * region_m), false)
```

Salvataggio:

```gdscript
func save_base(path: String, layout_seed := 0) -> int:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return 0
	file.store_buffer(SAVE_MAGIC.to_ascii_buffer())
	file.store_32(SAVE_VERSION)
	file.store_32(resolution_x)
	file.store_32(resolution_z)
	file.store_float(size_m.x)
	file.store_float(size_m.y)
	file.store_32(layout_seed)
	var raw := _heights.to_byte_array()
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	file.store_32(raw.size())
	file.store_32(packed.size())
	file.store_buffer(packed)
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	return 32 + packed.size()


func load_base(path: String, layout_seed := 0) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	if file.get_buffer(4).get_string_from_ascii() != SAVE_MAGIC or file.get_32() != SAVE_VERSION:
		return false
	if file.get_32() != resolution_x or file.get_32() != resolution_z:
		return false
	if not is_equal_approx(file.get_float(), size_m.x) or not is_equal_approx(file.get_float(), size_m.y):
		return false
	if file.get_32() != layout_seed:
		return false
	var raw_size := file.get_32()
	var packed_size := file.get_32()
	var raw := file.get_buffer(packed_size).decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != resolution_x * resolution_z * 4:
		return false
	_heights = raw.to_float32_array()
	_base = _heights.duplicate()
	_mirror_all()
	region_changed.emit(_full_aabb())
	return true
```

`TerrainCollision.setup`:

```gdscript
	var chunk_m := CHUNK_CELLS * TerrainField.SPACING
	var half := _field.half_extents()
	_chunks_x = int(ceil(half.x * 2.0 / chunk_m)) + 1
	_chunks_z = int(ceil(half.y * 2.0 / chunk_m)) + 1
	for cx in _chunks_x:
		for cz in _chunks_z:
			var key := Vector2i(-_chunks_x / 2 + cx, -_chunks_z / 2 + cz)
```
(campi `_chunks_x`, `_chunks_z` al posto di `_chunks_per_side`).

`TerrainSurface.update_base(terrain, base, resolution_x, resolution_z, half: Vector2)`: `Image.create_from_data(resolution_x, resolution_z, false, Image.FORMAT_RF, ...)` e `set_shader_param("base_half", half)`. Nello shader: `uniform vec2 base_half = vec2(102.0);` e `vec2 base_uv = (v_vertex.xz + base_half) / (base_half * 2.0);`.

`RunMap`:

```gdscript
static func height_samples(field: TerrainField, step_m := HEIGHT_STEP_M) -> Vector2i:
	var half := field.half_extents()
	return Vector2i(int(round(half.x * 2.0 / step_m)) + 1, int(round(half.y * 2.0 / step_m)) + 1)


static func sample_world(field: TerrainField, sample: Vector2i, step_m := HEIGHT_STEP_M) -> Vector3:
	var half := field.half_extents()
	return Vector3(-half.x + sample.x * step_m, 0.0, -half.y + sample.y * step_m)
```
`snapshot_heights` e `render_heights` usano `var n := height_samples(field, step_m)`, cicli `for row in n.y: for column in n.x`, indice `row * n.x + column`, `size = n`; `_sample_at` usa `half.x` per X e `half.y` per Z. Chi chiama `height_samples` aspettandosi un `int` (`menu_tests._test_run_map_heights`) legge `.x`.

`ArenaRun`:

```gdscript
## Rilievo di base cotto del livello (`bake_terrain_base.gd -- --level=<id>`), in LFS.
func base_relief_path() -> String:
	return "res://levels/%s/base.bin" % level_id
```
e in `_check_scale`: `(terrain_field.half_extents() - district.half_extents()).length() > 0.5`.

`RuinsDistrict.apply_base_relief`: `var half := field.half_extents()`, cicli `for iz in field.resolution_z: for ix in field.resolution_x`, `x = ix * SPACING - half.x`, `z = iz * SPACING - half.y`, indice `iz * field.resolution_x + ix`, AABB finale `field._full_aabb()`. In `paint_surface` il prato dipinto cicla `z` su `half.y` e `x` su `half.x`. `OvergrownArena.settle_on_relief`: `var half := terrain_field.half_extents()` e `absf(body.position.x) > half.x or absf(body.position.z) > half.y`; `_relief_ready` legge `resolution_x > 0`. `LampField.can_place`: `var half := terrain_field.half_extents()`, `absf(point.x) > half.x - FLAT_RADIUS_M or absf(point.z) > half.y - FLAT_RADIUS_M`. `QuakeEvent`: `var limit := terrain_field.half_extents() - Vector2.ONE * CREST_RADIUS` e `absf(p.x) > limit.x or absf(p.z) > limit.y`. `benchmark_arena`: `field.resolution_x * field.resolution_z`.

`bake_terrain_base.gd`:

```gdscript
func _initialize() -> void:
	var level_id := &"district"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			level_id = StringName(arg.trim_prefix("--level="))
	var scene_path := LevelCatalog.scene_of(level_id)
	var scene: Node3D = (load(scene_path) as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	var district: RuinsDistrict = scene.get_node(^"District")
	var field: TerrainField = scene.get_node(^"TerrainField")
	var out := "res://levels/%s/base.bin" % level_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	field.set_protected(Vector3.ZERO, field.half_extents().length() * 2.0, false)
	district.apply_base_relief(field)
	var bytes := field.save_base(out, district.layout_seed)
	print("PROTOTYPE01_TERRAIN_BASE_BAKED level=%s path=%s bytes=%d" % [level_id, out, bytes])
	scene.queue_free()
	await physics_frame
	quit(0 if bytes > 0 else 1)
```

Scena e suite: `size_m = Vector2(204, 204)` in `arena_run.tscn`; nelle suite `field.size_m = Vector2(64.0, 64.0)`.

- [ ] **Step 4: Ricuocere la base del quartiere e vedere il PASS**

```
godot_console --headless --path godot --script res://tests/tools/bake_terrain_base.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/terrain_field_tests.gd
```
Atteso: `PROTOTYPE01_TERRAIN_BASE_BAKED level=district`, poi `PROTOTYPE01_TESTS PASS`.

- [ ] **Step 5: Suite collegate** — `district_tests`, `arena_run_tests`, `boss_tests`, `menu_tests`, `lamp_tests`, `economy_tests`, `terrain_brush_tests`, `terrain_horde_tests`, `quake_tests`, `extraction_tests`, `flow_preview_tests`, `restyle_tests` (una alla volta, log distinti). Atteso: tutte `PASS`. `--check-only` su ogni script toccato.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts godot/resources godot/scenes godot/tests godot/levels/district/base.bin
git commit -m "TerrainField rettangolare: semilati per asse, regioni e chunk N x M, base versione 3 per livello, mappa e consumatori sui due semilati"
```

---

### Task 2: Scritture nuove di `TerrainField`: `reset_to_base`, `bump_along`, `tint_rect`, `paint_layer_rect`, `collision_body`

**Files:**
- Modify: `godot/scripts/terrain/terrain_field.gd`
- Test: `godot/tests/terrain_field_tests.gd`

**Interfaces:**
- Produces: `reset_to_base(center: Vector3, half_size: Vector2) -> float` (volume assoluto, ignora le aree protette, emette `region_changed`), `bump_along(from: Vector3, to: Vector3, min_delta: float) -> Variant` (Vector3 con quota o null), `tint_rect(center: Vector3, half_size: Vector2, color: Color, strength: float)`, `paint_layer_rect(center: Vector3, half_size: Vector2, layer: int)`, `collision_body() -> StaticBody3D`.

- [ ] **Step 1: Test che fallisce** — aggiungere a `terrain_field_tests.gd` e chiamare dopo `_test_level()`:

```gdscript
## Il treno riporta la fascia alla base (spec tappa B, sezione 4): rettangolo a cavallo del
## confine delle regioni e di piu chunk, aree protette comprese, volume assoluto.
func _test_reset_to_base() -> void:
	print("reset to base")
	var collision: TerrainCollision = _field.get_node(^"Collision")
	_field.sculpt(Vector3(0.0, 0.0, 0.0), 2.4, 1.0)
	_field.sculpt(Vector3(4.0, 0.0, 1.0), 2.0, -0.8)
	_field.sculpt(Vector3(14.0, 0.0, 0.0), 2.0, 1.0)
	_field.set_protected(Vector3(-3.0, 0.0, 0.0), 1.5, true)
	_field.sculpt(Vector3(-3.0, 0.0, 0.0), 1.5, 0.5)
	_check(is_zero_approx(_field.height_at(Vector3(-3.0, 0.0, 0.0))), "la pennellata protetta non alza nulla (setup)")
	_field._protected.fill(0)
	_field.sculpt(Vector3(-3.0, 0.0, 0.0), 1.5, 0.5)
	_field.set_protected(Vector3(-3.0, 0.0, 0.0), 1.5, true)
	var before := collision.refreshed_count()
	var volume := _field.reset_to_base(Vector3(0.0, 0.0, 0.0), Vector2(8.0, 3.6))
	_check(volume > 2.0, "volume assoluto spostato (%.2f m3)" % volume)
	_check(is_zero_approx(_field.height_at(Vector3.ZERO)) and is_zero_approx(_field.height_at(Vector3(4.0, 0.0, 1.0))),
		"argine e solco nel rettangolo tornano alla base")
	_check(is_zero_approx(_field.height_at(Vector3(-3.0, 0.0, 0.0))), "anche il pixel protetto torna alla base")
	_check(absf(_field.height_at(Vector3(14.0, 0.0, 0.0)) - 1.0) < 0.01, "fuori dal rettangolo nulla cambia")
	_check(collision.refreshed_count() - before >= 2, "i chunk toccati sono stati rigenerati (%d)" % (collision.refreshed_count() - before))
	_field._protected.fill(0)
	_field.sculpt(Vector3(14.0, 0.0, 0.0), 2.0, -1.0)
	_check(_field.collision_body() == collision.body, "collision_body espone il corpo del terreno")


## Primo argine lungo un segmento (Trivella): punto con quota, o null.
func _test_bump_along() -> void:
	print("bump along")
	_field.sculpt(Vector3(6.0, 0.0, 0.0), 2.0, 1.2)
	var hit: Variant = _field.bump_along(Vector3(0.0, 0.0, 0.0), Vector3(12.0, 0.0, 0.0), 0.8)
	_check(hit != null and absf((hit as Vector3).x - 6.0) < 2.0 and (hit as Vector3).y >= 0.8, "argine trovato lungo la rotta (%s)" % str(hit))
	_check(_field.bump_along(Vector3(0.0, 0.0, 0.0), Vector3(-12.0, 0.0, 0.0), 0.8) == null, "nessun argine dall'altra parte")
	_field.sculpt(Vector3(6.0, 0.0, 0.0), 2.0, -1.2)
	_field.tint_rect(Vector3.ZERO, Vector2(10.0, 3.6), Color.RED, 1.0)
	_field.paint_layer_rect(Vector3.ZERO, Vector2(10.0, 3.6), 2)
	_check(true, "tint_rect e paint_layer_rect non fanno nulla in headless")
```

- [ ] **Step 2: Eseguire e vedere il FAIL** — stesso comando del Task 1. Atteso: `reset_to_base` non esiste (errore di parse).

- [ ] **Step 3: Implementare**

```gdscript
func collision_body() -> StaticBody3D:
	return _collision.body


## Riporta alla base i vertici del rettangolo XZ (centro e semilati), anche se protetti:
## e la pennellata del treno. Ritorna il volume assoluto spostato (m3).
func reset_to_base(center: Vector3, half_size: Vector2) -> float:
	var r := _rect_indices(center, half_size)
	if r[2] < r[0] or r[3] < r[1]:
		return 0.0
	var volume := 0.0
	for iz in range(r[1], r[3] + 1):
		for ix in range(r[0], r[2] + 1):
			var i := iz * resolution_x + ix
			volume += absf(_heights[i] - _base[i]) * SPACING * SPACING
			_heights[i] = _base[i]
	_mirror_rect(r[0], r[1], r[2], r[3])
	_emit_rect_changed(r[0], r[1], r[2], r[3])
	return volume


## Primo punto lungo il segmento (campionato ogni SPACING) che sporge dalla base di
## almeno [param min_delta]: Vector3 con la quota, o null.
func bump_along(from: Vector3, to: Vector3, min_delta: float) -> Variant:
	var run := Vector2(to.x - from.x, to.z - from.z).length()
	var steps := maxi(int(ceil(run / SPACING)), 1)
	for i in range(0, steps + 1):
		var p := from.lerp(to, float(i) / steps)
		if delta_at(p) >= min_delta:
			return Vector3(p.x, height_at(p), p.z)
	return null


## Strato di tile su un rettangolo XZ (la fascia dei binari); niente in headless.
func paint_layer_rect(center: Vector3, half_size: Vector2, layer: int) -> void:
	if not _terrain_ready:
		return
	var data := _terrain.data
	var pixel := Color(Terrain3DUtil.as_float(Terrain3DUtil.enc_base(layer)), 0.0, 0.0, 0.0)
	var r := _rect_indices(center, half_size)
	for iz in range(r[1], r[3] + 1):
		for ix in range(r[0], r[2] + 1):
			data.set_pixel(Terrain3DRegion.TYPE_CONTROL, _vertex_world(iz * resolution_x + ix), pixel)
	_mark_rect_regions(r)
	data.update_maps(Terrain3DRegion.TYPE_CONTROL, false)


## Tinta uniforme su un rettangolo XZ; strength 0 la toglie (torna al bianco).
func tint_rect(center: Vector3, half_size: Vector2, color: Color, strength: float) -> void:
	if not _terrain_ready:
		return
	var data := _terrain.data
	var r := _rect_indices(center, half_size)
	var target := Color.WHITE if strength <= 0.0 else color
	var w := 1.0 if strength <= 0.0 else clampf(strength, 0.0, 1.0)
	for iz in range(r[1], r[3] + 1):
		for ix in range(r[0], r[2] + 1):
			var world := _vertex_world(iz * resolution_x + ix)
			var old: Color = data.get_pixel(Terrain3DRegion.TYPE_COLOR, world)
			data.set_pixel(Terrain3DRegion.TYPE_COLOR, world, old.lerp(Color(target.r, target.g, target.b, old.a), w))
	_mark_rect_regions(r)
	data.update_maps(Terrain3DRegion.TYPE_COLOR, false)


func _mark_rect_regions(r: Array[int]) -> void:
	var lo := Vector3(r[0] * SPACING - _half.x, 0.0, r[1] * SPACING - _half.y)
	var hi := Vector3(r[2] * SPACING - _half.x, 0.0, r[3] * SPACING - _half.y)
	var region_m := REGION_SIZE * SPACING
	var x := lo.x
	while x <= hi.x + region_m:
		var z := lo.z
		while z <= hi.z + region_m:
			var region: Terrain3DRegion = _terrain.data.get_regionp(Vector3(minf(x, hi.x), 0.0, minf(z, hi.z)))
			if region != null:
				region.edited = true
			z += region_m
		x += region_m
```

- [ ] **Step 4: Eseguire e vedere il PASS** — `PROTOTYPE01_TESTS PASS`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/terrain/terrain_field.gd godot/tests/terrain_field_tests.gd
git commit -m "TerrainField: reset_to_base a rettangolo per il treno, bump_along per la Trivella, tinta e strato a rettangolo, corpo di collisione esposto"
```

---

### Task 3: `RailwayDistrict` a pennellate, scena della ferrovia sul rilievo, base cotta, suite della ferrovia

**Files:**
- Modify: `godot/scripts/arena/railway_district.gd`
- Modify: `godot/scripts/arena/ruins_district.gd` (`apply_base_relief` spezzata in tre passi; `apply_strokes`: vene per ogni pennellata con `scrap > 0`)
- Modify: `godot/scripts/companion/scrap_field.gd` (`exhaust_veins_in_rect`, `take_in_rect`)
- Modify: `godot/scripts/terrain/lamp_field.gd` (`knock_down_in_rect`)
- Modify: `godot/scripts/enemies/enemy_director.gd` (`uphill_speed_scale`)
- Modify: `godot/scripts/run/arena_run.gd` (marker: vene per `scrap > 0`)
- Modify: `godot/scenes/main/railway_run.tscn`
- Create: `godot/levels/railway/base.bin` (cotto)
- Test: `godot/tests/railway_tests.gd` (riscritta)

**Interfaces:**
- Consumes: Task 1-2 (`size_m: Vector2`, `reset_to_base`, `paint_layer_rect`, `tint_rect`).
- Produces: `RailwayDistrict.TRACK_HALF_WIDTH = 3.6`, `TRACK_Z = [-2.4, 2.4]`, `track_half_width()`, `is_on_tracks(p: Vector2)`, `track_rect() -> Rect2`, pennellate `kind` in `start`, `wagon` (scrap 8, tint `WAGON_TINT`), `trench`, `deposit`, cortili; `ScrapField.exhaust_veins_in_rect(rect: Rect2) -> int`, `ScrapField.take_in_rect(rect: Rect2, max_count: int) -> int`, `LampField.knock_down_in_rect(rect: Rect2) -> int`, `EnemyDirector.uphill_speed_scale(enemy: Enemy, grade: float) -> float`; la scena `railway_run.tscn` ha i nodi `TerrainField` (`size_m = Vector2(319.2, 122.4)`), `District`, `TrainEvent` con `terrain_field`.

- [ ] **Step 1: Riscrivere `railway_tests.gd` (fallisce)**

```gdscript
extends SceneTree
## Test del livello 2, la ferrovia, sul rilievo continuo (tappa B): pianta rettangolare,
## fascia dei binari piatta e libera, cortile a cavallo, vagoni come cumuli con vena,
## depositi e trincee fuori fascia, saltatori per pendenza. Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/railway_tests.gd

const RunScene := preload("res://scenes/main/railway_run.tscn")

var _failures := 0
var _scene: Node3D
var _district: RailwayDistrict
var _field: TerrainField
var _path: PathField
var _player: PlayerCharacter
var _director: EnemyDirector
var _scrap: ScrapField
var _run: ArenaRun


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	_district = _scene.get_node(^"District")
	_field = _scene.get_node(^"TerrainField")
	_path = _scene.get_node(^"PathField")
	_player = _scene.get_node(^"Player")
	_director = _scene.get_node(^"EnemyDirector")
	_scrap = _scene.get_node(^"ScrapField")
	_run = _scene.get_node(^"Run")
	_director.spawning = false
	await _frames(5)
	_test_scale()
	_test_track_strip()
	_test_start_courtyard_straddles_tracks()
	_test_wagons()
	_test_features_off_tracks()
	_test_blocks_inside_and_off_tracks()
	_test_determinism()
	await _test_spawn_and_path_in_corridor()
	await _test_markers_include_wagons()
	await _test_hoppers()
	await _frames(2)
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _strokes(kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in _district.terrain_strokes:
		if s.kind == kind:
			out.append(s)
	return out


func _test_scale() -> void:
	print("scale")
	_check(_district.half_x() > _district.half_z() * 2.0, "corridoio lungo in X (%.0f x %.0f m)" % [_district.half_x() * 2.0, _district.half_z() * 2.0])
	_check(_field.half_extents().is_equal_approx(_district.half_extents()), "il rilievo copre esattamente l'arena (%s)" % _field.half_extents())
	_check(_field.resolution_x == 639 and _field.resolution_z == 246, "campo 639 x 246 vertici (%d x %d)" % [_field.resolution_x, _field.resolution_z])
	var collision: TerrainCollision = _field.get_node(^"Collision")
	_check(collision.chunk_count() == 21 * 9, "chunk di collisione 21 x 9 (%d)" % collision.chunk_count())
	_check(is_equal_approx(_path.half_extent, _district.half_x()) and is_equal_approx(_path.half_z(), _district.half_z()), "campo di percorso esteso all'arena rettangolare")
	_check(_path.world_columns == 266 and _path.world_rows == 102, "campo di 266 x 102 celle (%d x %d)" % [_path.world_columns, _path.world_rows])
	_check(_district.get_node_or_null(^"Tracks") != null, "binari costruiti")
	_check(_district.get_node_or_null(^"RuinCrowns") != null and _district.get_node_or_null(^"RuinRebar") != null, "corone e tondini delle rovine costruiti")


## La fascia e piatta a quota zero nella base, senza bump, e libera da ostacoli statici.
func _test_track_strip() -> void:
	print("track strip")
	var rect := _district.track_rect()
	_check(rect.position.y == -RailwayDistrict.TRACK_HALF_WIDTH and rect.size.y == RailwayDistrict.TRACK_HALF_WIDTH * 2.0 and rect.size.x == _district.half_x() * 2.0,
		"track_rect copre tutta la lunghezza, 7,2 m di larghezza")
	_check(not RailwayDistrict.is_on_tracks(Vector2(0.0, 4.0)) and RailwayDistrict.is_on_tracks(Vector2(100.0, -3.5)), "is_on_tracks distingue dentro e fuori la fascia")
	var flat := true
	var no_bump := true
	var x := -_district.half_x() + 2.0
	while x < _district.half_x() - 2.0:
		for z in [-3.0, 0.0, 3.0]:
			var p := Vector3(x, 0.0, z)
			if absf(_field.base_height_at(p)) > 0.05:
				flat = false
			# I vagoni sporgono dalla base: fuori dai loro cumuli nessun bump.
			var near_wagon := false
			for w in _strokes(&"wagon"):
				if absf(w.center.x - x) < w.radius + 0.5:
					near_wagon = true
			if not near_wagon and _field.delta_at(p) > 0.05:
				no_bump = false
		x += 1.5
	_check(flat, "la base della fascia e a quota zero per tutta la lunghezza")
	_check(no_bump, "fuori dai vagoni la fascia non sporge dalla base")
	_check(absf(_field.base_height_at(Vector3(40.0, 0.0, 6.5))) < 1.3 and absf(_field.base_height_at(Vector3(40.0, 0.0, 20.0))) < 2.5, "oltre il raccordo il rilievo riprende")
	var space := _district.get_world_3d().direct_space_state
	var shape := BoxShape3D.new()
	shape.size = Vector3(_district.half_x() * 2.0 - 2.0, 2.0, RailwayDistrict.TRACK_HALF_WIDTH * 2.0 - 0.2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), Vector3(0.0, 1.2, 0.0))
	query.collision_mask = 1
	var foreign := 0
	for hit in space.intersect_shape(query, 128):
		if hit.collider != _field.collision_body():
			foreign += 1
	_check(foreign == 0, "nessun ostacolo statico sulla fascia dei binari (%d)" % foreign)


func _test_start_courtyard_straddles_tracks() -> void:
	print("start courtyard")
	var start := _strokes(&"start")
	_check(start.size() == 1 and start[0].center == Vector2.ZERO, "cortile di partenza all'origine")
	if start.is_empty():
		return
	var on_strip := 0
	for p: Vector2 in start[0].points:
		if absf(p.y) <= RailwayDistrict.TRACK_HALF_WIDTH + 1.0:
			on_strip += 1
	_check(on_strip == 0, "nessuna pennellata dell'anello sulla fascia")
	var r: float = start[0].radius
	_check(_field.delta_at(Vector3(0.0, 0.0, -r)) > 1.0 and _field.delta_at(Vector3(0.0, 0.0, r)) > 1.0, "argini a nord e a sud in piedi")
	_check(_field.delta_at(Vector3(r, 0.0, 0.0)) < 0.2 and _field.delta_at(Vector3(-r, 0.0, 2.4)) < 0.2, "varchi est e ovest aperti sulla fascia")


func _test_wagons() -> void:
	print("wagons")
	var wagons := _strokes(&"wagon")
	_check(wagons.size() >= 3, "almeno tre vagoni sui binari (%d)" % wagons.size())
	var ok := true
	for i in wagons.size():
		var w: Dictionary = wagons[i]
		ok = ok and RailwayDistrict.is_on_tracks(w.center) and w.scrap == RailwayDistrict.WAGON_SCRAP and w.tint == RailwayDistrict.WAGON_TINT
		ok = ok and absf(w.center.x) >= _district.start_clear_radius + 6.0
		ok = ok and _field.delta_at(Vector3(w.center.x, 0.0, w.center.y)) > 1.2
		ok = ok and _scrap.vein_scrap_left(Vector3(w.center.x, 0.0, w.center.y)) == RailwayDistrict.WAGON_SCRAP
		for j in i:
			ok = ok and absf(wagons[j].center.x - w.center.x) >= _district.wagon_spacing - 0.01
	_check(ok, "ogni vagone e un cumulo sulla fascia con vena da %d, lontano dalla partenza e dagli altri" % RailwayDistrict.WAGON_SCRAP)


func _test_features_off_tracks() -> void:
	print("features")
	var kinds := {}
	var off := true
	var parallel := true
	for s: Dictionary in _district.terrain_strokes:
		kinds[s.kind] = kinds.get(s.kind, 0) + 1
		if s.kind == &"wagon" or s.kind == &"start":
			continue
		for p: Vector2 in s.points:
			off = off and not RailwayDistrict.is_on_tracks(p)
		if s.kind == &"trench":
			var a: Vector2 = s.points[0]
			var b: Vector2 = s.points[s.points.size() - 1]
			parallel = parallel and absf(a.y - b.y) < 0.01
	_check(kinds.get(&"deposit", 0) >= 4, "almeno quattro depositi fuori dai binari (%d)" % kinds.get(&"deposit", 0))
	_check(kinds.get(&"trench", 0) >= 2, "almeno due trincee (%d)" % kinds.get(&"trench", 0))
	var courtyards := 0
	for kind: StringName in kinds:
		if kind != &"start" and kind != &"deposit" and kind != &"trench" and kind != &"wagon":
			courtyards += kinds[kind]
	_check(courtyards >= 3, "almeno tre cortili secondari (%d)" % courtyards)
	_check(off, "cortili, depositi e trincee fuori dalla fascia dei binari")
	_check(parallel, "le trincee corrono parallele ai binari")


func _test_blocks_inside_and_off_tracks() -> void:
	print("blocks")
	var ex := _district.half_x()
	var ez := _district.half_z()
	var inside := true
	var off := true
	var low := true
	var blocks := 0
	for child in _district.get_children():
		if not (child is StaticBody3D) or not child.name.begins_with("Block"):
			continue
		blocks += 1
		var body := child as StaticBody3D
		var size := Vector3.ZERO
		for part in body.get_children():
			if part is CollisionShape3D:
				size = ((part as CollisionShape3D).shape as BoxShape3D).size
		low = low and size.y > 0.0 and size.y <= 4.5
		inside = inside and absf(body.position.x) + size.x * 0.5 <= ex and absf(body.position.z) + size.z * 0.5 <= ez
		off = off and absf(body.position.z) - size.z * 0.5 >= RailwayDistrict.TRACK_HALF_WIDTH
	_check(blocks >= 20, "almeno 20 rovine basse (%d)" % blocks)
	_check(low, "nessuna rovina interna piu alta di 4,5 m")
	_check(inside, "tutte le rovine dentro il rettangolo giocabile")
	_check(off, "nessuna rovina sopra la fascia dei binari")


func _test_determinism() -> void:
	print("determinism")
	var before := _district.terrain_strokes.duplicate(true)
	var stats_before := _district.stats.duplicate()
	_district.rebuild()
	_check(_district.terrain_strokes == before, "stesse pennellate dopo la ricostruzione")
	_check(_district.stats == stats_before, "stesse statistiche dopo la ricostruzione %s" % [_district.stats])


func _test_spawn_and_path_in_corridor() -> void:
	print("corridor")
	_player.global_position = Vector3(100.0, _field.height_at(Vector3(100.0, 0.0, 0.0)) + 0.88, 0.0)
	_player.velocity = Vector3.ZERO
	await _frames(4)
	_check(_path.is_inside(_path.cell_of(_player.global_position)), "finestra ricentrata a 100 m lungo i binari")
	_check(_path.cost_at(_player.global_position) == 0.0, "costo zero sul giocatore")
	var inside := true
	var reachable := 0
	for i in 20:
		var spot: Variant = _director._find_spawn_point()
		if spot == null:
			inside = false
			continue
		inside = inside and absf(spot.x) <= _district.half_x() and absf(spot.z) <= _district.half_z()
		if _path.cost_at(spot) < PathField.UNREACHABLE:
			reachable += 1
	_check(inside, "punti di comparsa dentro il rettangolo")
	_check(reachable >= 15, "quasi tutti i punti di comparsa raggiungono il giocatore (%d/20)" % reachable)
	_player.global_position = Vector3(100.0, _field.height_at(Vector3(100.0, 0.0, 55.0)) + 0.88, 55.0)
	await _frames(4)
	var clamped := true
	for i in 20:
		var spot: Variant = _director._find_spawn_point()
		clamped = clamped and spot != null and absf(spot.z) <= _district.half_z()
	_check(clamped, "al bordo sud i punti restano dentro i 61 m")
	_player.global_position = Vector3(0.0, 0.88, 0.0)
	_player.velocity = Vector3.ZERO
	await _frames(4)


func _test_markers_include_wagons() -> void:
	print("markers")
	var hud: RunHud = _scene.get_node(^"RunHud")
	await _frames(70)
	var markers := _run.current_markers()
	var deposits := markers.filter(func(m: Dictionary) -> bool: return m.text == "ROTTAMI")
	_check(deposits.size() == 2, "due depositi indicati (%d)" % deposits.size())
	_check(hud.marker_count() == markers.size(), "l'HUD mostra gli stessi indicatori (%d)" % hud.marker_count())
	var nearest := INF
	var nearest_kind: StringName = &""
	for s: Dictionary in _district.terrain_strokes:
		var marker: Vector2 = s.marker
		if s.scrap > 0 and marker.length() >= ArenaRun.MARKER_MIN_DISTANCE and marker.length() < nearest:
			nearest = marker.length()
			nearest_kind = s.kind
	var first: Dictionary = deposits[0] if not deposits.is_empty() else {}
	_check(not first.is_empty() and absf(first.distance - nearest) < 0.1, "il primo indicato e il piu vicino (%s a %.0f m)" % [nearest_kind, nearest])
	# Vena azzerata: il marker del vagone sparisce.
	var wagon: Dictionary = _strokes(&"wagon")[0]
	_scrap.exhaust_veins_in_rect(Rect2(wagon.center - Vector2(4.0, 4.0), Vector2(8.0, 8.0)))
	await _frames(70)
	var left := _run.current_markers().filter(func(m: Dictionary) -> bool: return m.text == "ROTTAMI" and absf(m.distance - wagon.center.length()) < 0.5)
	_check(_scrap.vein_scrap_left(Vector3(wagon.center.x, 0.0, wagon.center.y)) == 0 and left.is_empty(), "a vena azzerata il vagone non e piu indicato")


## Saltatori (D-066, tappa B): dal tuning del livello 2, con meno vita e un altro colore,
## pendenza massima 1,2 e rallentamento in salita minore dei rottamatori.
func _test_hoppers() -> void:
	print("hoppers")
	var tuning := _director.tuning
	_check(tuning.hopper_share_max > 0.0 and RunTuning.new().hopper_share_max == 0.0, "quota dei saltatori solo nel tuning della ferrovia")
	var elapsed := _director.elapsed
	_director.elapsed = 0.0
	_check(is_zero_approx(_director.current_hopper_share()), "all'inizio nessun saltatore")
	_director.elapsed = tuning.hopper_start_seconds + tuning.hopper_ramp_seconds * 3.0
	_check(is_equal_approx(_director.current_hopper_share(), tuning.hopper_share_max), "a rampa finita la quota massima (%.0f%%)" % (tuning.hopper_share_max * 100.0))
	_director.elapsed = elapsed
	var walker := _director.spawn_at(Vector3(-12.0, 0.0, 12.0))
	var hopper := _director.spawn_kind(Vector3(-12.0, 0.0, 14.0), &"hopper")
	_check(hopper.kind == &"hopper" and is_equal_approx(hopper.max_grade, 1.2) and is_equal_approx(walker.max_grade, 0.8), "il saltatore sale fino a 1,2 m/m")
	_check(hopper.health == maxi(ceili(walker.health * tuning.hopper_health_share), 1), "meno vita (%d contro %d)" % [hopper.health, walker.health])
	_check(hopper.paint_material() != walker.paint_material(), "e di un altro colore")
	_check(is_equal_approx(_director.uphill_speed_scale(walker, 0.8), tuning.uphill_min_speed), "il rottamatore a 0,8 m/m va al minimo")
	_check(_director.uphill_speed_scale(hopper, 0.8) > _director.uphill_speed_scale(walker, 0.8) + 0.1, "il saltatore sulla stessa salita va piu forte")
	_check(is_equal_approx(_director.uphill_speed_scale(hopper, -0.5), 1.0), "in discesa velocita piena")
	for enemy: Enemy in [walker, hopper]:
		enemy.queue_free()
	_director.enemies.clear()
```

- [ ] **Step 2: Eseguire e vedere il FAIL**

```
godot_console --headless --path godot --fixed-fps 60 --script res://tests/railway_tests.gd
```
Atteso: errore di parse (`track_rect`, `WAGON_SCRAP`, `uphill_speed_scale`) o `get_node TerrainField` nullo.

- [ ] **Step 3: `RuinsDistrict`: base in tre passi e vene per ogni pennellata con rottami**

```gdscript
func apply_base_relief(field: TerrainField) -> void:
	_write_base_noise(field)
	_sculpt_base_details(field)
	_finish_base(field)


## Rumore a tre ottave attenuato (piazza, cortile e, nella ferrovia, fascia dei binari).
func _write_base_noise(field: TerrainField) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = layout_seed
	noise.frequency = 0.025
	var half := field.half_extents()
	for iz in field.resolution_z:
		for ix in field.resolution_x:
			var x := ix * TerrainField.SPACING - half.x
			var z := iz * TerrainField.SPACING - half.y
			var h := noise.get_noise_2d(x, z) * 1.2 + noise.get_noise_2d(x * 2.8, z * 2.8) * 0.5 + noise.get_noise_2d(x * 6.5, z * 6.5) * 0.25
			field._heights[iz * field.resolution_x + ix] = h * _relief_calm(Vector2(x, z))


## Cumuli di macerie attorno alle rovine e solchi lungo le strade.
func _sculpt_base_details(field: TerrainField) -> void:
	(il blocco attuale: `rubble` e `furrow` invariati)


func _finish_base(field: TerrainField) -> void:
	field.commit_base()
	field._mirror_all()
	field.region_changed.emit(field._full_aabb())
```

In `apply_strokes`: `if stroke.scrap > 0 and scrap_field != null: scrap_field.add_vein(center, stroke.radius, stroke.scrap, field.base_height_at(center))`. In `ArenaRun` (marker, riga 240 circa): `var is_deposit: bool = stroke.scrap > 0`.

- [ ] **Step 4: `RailwayDistrict` a pennellate**

```gdscript
## Mezza larghezza della fascia dei binari (metri) e raccordo ai lati nel rilievo di base.
const TRACK_HALF_WIDTH := 3.6
const TRACK_EDGE_BLEND := 2.0
## Quota Z dei due binari.
const TRACK_Z: Array[float] = [-2.4, 2.4]
## Vagoni: cumuli con vena sulla fascia (spec tappa B, sezione 3).
const WAGON_RADIUS := 3.0
const WAGON_HEIGHT := 1.5
const WAGON_SCRAP := 8
## Tinta della fascia (ghiaia scura) e dei vagoni (ruggine).
const BALLAST_TINT := Color(0.30, 0.28, 0.25)
const WAGON_TINT := Color(0.55, 0.22, 0.06)


static func track_half_width() -> float:
	return TRACK_HALF_WIDTH


static func is_on_tracks(p: Vector2) -> bool:
	return absf(p.y) <= TRACK_HALF_WIDTH


## Rettangolo mondo XZ della fascia, per tutta la lunghezza dell'arena.
func track_rect() -> Rect2:
	return Rect2(-half_x(), -TRACK_HALF_WIDTH, half_x() * 2.0, TRACK_HALF_WIDTH * 2.0)


## 0 sulla fascia, 1 oltre il raccordo: il rumore di base si spegne sui binari.
static func track_calm(z: float) -> float:
	return smoothstep(TRACK_HALF_WIDTH, TRACK_HALF_WIDTH + TRACK_EDGE_BLEND, absf(z))


func _relief_calm(p: Vector2) -> float:
	return super(p) * track_calm(p.y)


## Nessuna strada dipinta: la fascia dei binari prende il suo posto.
func _road_segments() -> Array:
	return []


## Dopo macerie e solchi la fascia torna esattamente a zero (anche sotto le macerie
## vicine), con il raccordo ai lati.
func _sculpt_base_details(field: TerrainField) -> void:
	super(field)
	var half := field.half_extents()
	for iz in field.resolution_z:
		var z := iz * TerrainField.SPACING - half.y
		var calm := track_calm(z)
		if calm >= 1.0:
			continue
		for ix in field.resolution_x:
			field._heights[iz * field.resolution_x + ix] *= calm


func _compose() -> void:
	terrain_strokes.clear()
	_reset_occupancy()
	stats["strokes"] = 0
	stats["wagons"] = 0
	_build_ground()
	_build_boundary()
	_reserve_tracks()
	_plan_start_courtyard()
	_plan_wagons()
	_plan_courtyards()
	_plan_deposits()
	_plan_trenches()
	_build_tracks()
	_reset_ruin_details()
	_build_blocks()
	_build_props()
	_build_perimeter()
	_build_ruin_details()
	_build_ground_cover()
	_add_sun()
	_add_environment()


func _reserve_tracks() -> void:
	var half := TRACK_HALF_WIDTH + CELL
	_reserve(Rect2(-half_x(), -half, half_x() * 2.0, half * 2.0))


## Anello di argini senza i tratti sulla fascia: i varchi est e ovest sono i binari.
func _plan_start_courtyard() -> void:
	var r := start_courtyard_radius
	var gates: Array[int] = [0, 1, 2, 3]
	var points: Array[Vector2] = []
	for p in _ring_points(Vector2.ZERO, r * CELL, gates):
		if absf(p.y) > TRACK_HALF_WIDTH + RAMPART_BRUSH * 0.6:
			points.append(p)
	_add_ring_stroke(&"start", Vector2.ZERO, r * CELL, gates, points)
	_reserve(_rect_around(Vector2.ZERO, Vector2.ONE * start_clear_radius))


## Vagoni merci: cumuli con vena sulla fascia, lontani dalla partenza e fra loro.
func _plan_wagons() -> void:
	var placed: Array[float] = []
	var limit := half_x() - 12.0
	for i in wagon_count:
		var x := 0.0
		var found := false
		for attempt in 40:
			x = _rng.randf_range(-limit, limit)
			if absf(x) < start_clear_radius + 8.0:
				continue
			var far := true
			for other in placed:
				if absf(other - x) < wagon_spacing:
					far = false
					break
			if far:
				found = true
				break
		if not found:
			continue
		placed.append(x)
		var center := Vector2(x, 0.0)
		_add_stroke(&"wagon", center, WAGON_RADIUS, WAGON_HEIGHT, WAGON_TINT, WAGON_SCRAP, [], [center], WAGON_RADIUS, 0.0)
		stats.wagons += 1


## Trincee parallele ai binari (canali di scolo).
func _plan_trenches() -> void:
	for i in trench_count:
		var length := _rng.randi_range(6, 14)
		var half := Vector2(length * CELL * 0.5, 1.0)
		var spot: Variant = _find_free_spot(half, 2.0, start_clear_radius + 4.0)
		if spot == null:
			continue
		var center: Vector2 = spot
		var a := center - Vector2(half.x - CELL * 0.5, 0.0)
		var b := center + Vector2(half.x - CELL * 0.5, 0.0)
		var steps := maxi(int(a.distance_to(b) / TRENCH_STEP), 1)
		var points: Array[Vector2] = []
		for t in steps + 1:
			points.append(a.lerp(b, float(t) / steps))
		_add_stroke(&"trench", center, TRENCH_BRUSH, TRENCH_DEPTH, NO_TINT, 0, [], points, TRENCH_BRUSH, a.distance_to(b) / steps)


## Strati del quartiere piu la fascia: asfalto e ghiaia scura per tutta la lunghezza.
func paint_surface(field: TerrainField) -> void:
	super(field)
	if field.terrain3d() == null:
		return
	var half := Vector2(half_x() + PORTAL_DEPTH, TRACK_HALF_WIDTH)
	field.paint_layer_rect(Vector3.ZERO, half, TerrainSurface.LAYER_ASPHALT)
	field.tint_rect(Vector3.ZERO, half, BALLAST_TINT, 0.8)
```

Togliere `TRACK_HALF_ROWS`, `track_cells`, `_add_feature` dalle tre funzioni, le ricerche `snap_to_cell`. `_build_tracks` resta (usa `TRACK_Z` e `track_half_width()`); `_build_portals` resta. Se `_plan_courtyards`/`_plan_deposits` ereditate usano ancora `_add_feature`, restano cosi fino al Task 7.

- [ ] **Step 5: `ScrapField`, `LampField`, `EnemyDirector`**

```gdscript
## Vene con il centro nel rettangolo XZ: azzerate senza rottami (il treno spazza i
## vagoni). Ritorna quante ne ha azzerate.
func exhaust_veins_in_rect(rect: Rect2) -> int:
	var count := 0
	for vein in _veins:
		if vein.scrap_left > 0 and rect.has_point(Vector2(vein.center.x, vein.center.z)):
			vein.scrap_left = 0
			vein.dug_m3 = 0.0
			if terrain_field != null:
				terrain_field.tint(vein.center, vein.radius, Color.WHITE, 1.0)
			count += 1
	return count


## Rimuove fino a [param max_count] rottami con la base nel rettangolo XZ; ritorna quanti.
func take_in_rect(rect: Rect2, max_count: int) -> int:
	var taken := 0
	for i in range(_scraps.size() - 1, -1, -1):
		if taken >= max_count:
			break
		var p := _scraps[i].global_position
		if rect.has_point(Vector2(p.x, p.z)):
			_remove_at(i)
			taken += 1
	return taken
```

```gdscript
## Abbatte i lampioni con la base nel rettangolo XZ; ritorna quanti.
func knock_down_in_rect(rect: Rect2) -> int:
	var hit := 0
	for i in range(_posts.size() - 1, -1, -1):
		var p: Vector3 = _posts[i].position
		if rect.has_point(Vector2(p.x, p.z)):
			_remove_post(i, &"demolisher")
			hit += 1
	return hit
```

Nel direttore, al posto della `lerpf` inline nel ramo `terrain_field`:

```gdscript
## Fattore di velocita in salita (spec tappa A 2.5): 1 in piano e in discesa, giu fino a
## `uphill_min_speed` quando la pendenza raggiunge la massima del nemico.
func uphill_speed_scale(enemy: Enemy, grade: float) -> float:
	if grade <= 0.0:
		return 1.0
	return lerpf(1.0, tuning.uphill_min_speed, clampf(grade / enemy.max_grade, 0.0, 1.0))
```
e nel tick: `speed *= uphill_speed_scale(enemy, terrain_field.grade_between(pos, ahead))`.

- [ ] **Step 6: Scena `railway_run.tscn`** — sostituire l'ext_resource `terrain_grid.gd` con `terrain_field.gd` (`id="5_terrain_field"`), il nodo:

```
[node name="TerrainField" type="Node3D" parent="."]
script = ExtResource("5_terrain_field")
size_m = Vector2(319.2, 122.4)
tuning = ExtResource("6_terrain_tuning")
```
`District` riceve `node_paths=PackedStringArray("terrain_field")` e `terrain_field = NodePath("../TerrainField")`; in ogni nodo `grid = NodePath("../TerrainGrid")` diventa `terrain_field = NodePath("../TerrainField")` (e `"grid"` → `"terrain_field"` nei `node_paths`); `Player`: `terrain_grid` → `terrain_field`; `ScrapField` aggiunge `bare_ground_yields_scrap = false`; `TrainEvent` riceve `terrain_field`. Confrontare con `arena_run.tscn` per i nomi esatti.

- [ ] **Step 7: Cuocere la base e vedere il PASS**

```
godot_console --headless --path godot --script res://tests/tools/bake_terrain_base.gd -- --level=railway
godot_console --headless --path godot --fixed-fps 60 --script res://tests/railway_tests.gd
```
Atteso: `PROTOTYPE01_TERRAIN_BASE_BAKED level=railway`, `levels/railway/base.bin` creato, `PROTOTYPE01_TESTS PASS`. Nota: `train_tests`, `driller_tests`, `campaign_tests` possono essere rosse fino ai Task 4-5 (i loro script cercano `TerrainGrid`); annotarlo nel ledger.

- [ ] **Step 8: Commit**

```bash
git add godot/scripts godot/scenes/main/railway_run.tscn godot/levels/railway/base.bin godot/tests/railway_tests.gd
git commit -m "Ferrovia sul rilievo: fascia piatta nella base, cortile a cavallo, vagoni come cumuli con vena, solchi paralleli, base cotta del livello 2, saltatori per pendenza"
```

---

### Task 4: Il treno sul rilievo (`TrainEvent`)

**Files:**
- Modify: `godot/scripts/run/train_event.gd`
- Test: `godot/tests/train_tests.gd` (riscritta)

**Interfaces:**
- Consumes: `TerrainField.reset_to_base`, `height_at`, `delta_at`, `slope_at`, `tuning.max_grade`; `ScrapField.exhaust_veins_in_rect`, `take_in_rect`; `LampField.knock_down_in_rect`; `RailwayDistrict.track_rect`, `TRACK_HALF_WIDTH`.
- Produces: `TrainEvent.terrain_field: TerrainField`, `volume_flattened: float`, `wagons_swept: int`, segnale `train_hit` con `&"terrain"`, `&"wagon"`, `&"scrap"`, `&"lamp"`, `&"enemy"`, `&"player"`, `&"companion"`, `&"boss"`; marker `PROTOTYPE01_TRAIN_PASSED passes=%d volume=%.1f wagons=%d enemies=%d player_hits=%d`.

- [ ] **Step 1: Riscrivere `train_tests.gd` (fallisce)** — stessa intestazione e aiuti della versione attuale (`_check`, `_frames`, `_place`), con `_field: TerrainField = _scene.get_node(^"TerrainField")` al posto di `_grid`, `_test_setup` e `_test_warning` invariati salvo `absf(_train.track_z) == 2.4`; nuovi:

```gdscript
func _test_pass_flattens_and_hits() -> void:
	print("pass")
	_train.speed = 80.0
	_run._start_protect_left = 0.0
	_field.set_protected(Vector3.ZERO, _field.tuning.start_protected_radius_m, false)
	# Davanti al treno (viene da est): un argine a cavallo del confine delle regioni (x = 0),
	# un solco, un argine fuori fascia, un lampione, un rottame a terra.
	_field.sculpt(Vector3(0.0, 0.0, 2.4), 2.0, 1.4)
	_field.sculpt(Vector3(24.0, 0.0, 0.0), 2.0, -0.8)
	_field.sculpt(Vector3(24.0, 0.0, 9.0), 2.0, 1.4)
	var lamp_at := Vector3(-30.0, 0.0, -2.4)
	_companion.add_capacity(0, 3)
	_place(_companion, lamp_at + Vector3(2.0, 0.0, 3.0), 0.3)
	_lamps.place_at(lamp_at)
	_check(_lamps.count() == 1, "lampione piazzato sulla fascia")
	_scrap.spawn_on_ground(Vector3(-40.0, 0.0, 0.0))
	var scrap_before := _scrap.count()
	var wagons := _run.district.terrain_strokes.filter(func(s: Dictionary) -> bool: return s.kind == &"wagon")
	var enemy := _director.spawn_at(Vector3(-50.0, 0.0, 0.0))
	var enemy_died := [false]
	enemy.died.connect(func(_e: Enemy) -> void: enemy_died[0] = true)
	var bystander := _director.spawn_at(Vector3(-50.0, 0.0, 10.0))
	var kills_before := _director.kills
	_place(_player, Vector3(30.0, 0.0, _train.track_z), 0.88)
	_player._invulnerable_left = 0.0
	var health_before := _player.health
	# Un argine alto proprio dove il treno spingerebbe il giocatore (Review Focus 2).
	var push_side := 1.0 if _train.track_z >= 0.0 else -1.0
	var landing_z := push_side * (RailwayDistrict.TRACK_HALF_WIDTH + TrainEvent.PUSH_MARGIN)
	_field.sculpt(Vector3(30.0, 0.0, landing_z), 2.0, 1.6)
	_place(_companion, Vector3(33.0, 0.0, 0.0), 0.3)
	for i in 90:
		await physics_frame
		if _train.state == TrainEvent.State.PASSING:
			break
	_check(_train.state == TrainEvent.State.PASSING, "finito il preavviso il treno e in corsa")
	_check(_train.get_node_or_null(^"Train") != null and _train.get_node(^"Train").get_child_count() == _run.tuning.train_carriages + 1, "convoglio di %d vagoni piu la locomotiva" % _run.tuning.train_carriages)
	_check(not _hud.is_boss_warning_visible(), "annuncio tolto all'ingresso")
	for i in 600:
		await physics_frame
		if _train.state == TrainEvent.State.IDLE:
			break
	_check(_train.state == TrainEvent.State.IDLE and _train.passes == 1, "il passaggio e finito (%d)" % _train.passes)
	_check(absf(_field.delta_at(Vector3(0.0, 0.0, 2.4))) < 0.02 and absf(_field.delta_at(Vector3(24.0, 0.0, 0.0))) < 0.02, "argine e solco sulla fascia tornano alla base")
	_check(_field.delta_at(Vector3(24.0, 0.0, 9.0)) > 1.0, "l'argine fuori dalla fascia resta")
	var flat := true
	for s: Dictionary in wagons:
		flat = flat and absf(_field.delta_at(Vector3(s.center.x, 0.0, s.center.y))) < 0.02 and _scrap.vein_scrap_left(Vector3(s.center.x, 0.0, s.center.y)) == 0
	_check(flat and _train.wagons_swept == wagons.size(), "vagoni spianati e vene azzerate (%d)" % _train.wagons_swept)
	_check(_train.volume_flattened > 20.0, "terra spostata dal treno: %.0f m3" % _train.volume_flattened)
	_check(_scrap.count() <= scrap_before - 1, "nessun rottame dai vagoni e il rottame a terra e sparito (%d -> %d)" % [scrap_before, _scrap.count()])
	_check(_lamps.count() == 0, "lampione sulla fascia abbattuto")
	_check(enemy_died[0] and _director.kills == kills_before + 1, "rottamatore sulla fascia travolto e contato come abbattuto")
	_check(not bystander.is_dead, "rottamatore fuori dalla fascia illeso")
	_check(_player.health == health_before - _run.tuning.train_player_damage, "giocatore colpito: %d -> %d" % [health_before, _player.health])
	var pp := _player.global_position
	_check(not RailwayDistrict.is_on_tracks(Vector2(pp.x, pp.z)), "giocatore spinto fuori dalla fascia (z=%.1f)" % pp.z)
	_check(_field.delta_at(pp) < 0.5 and _field.slope_at(pp) <= _field.tuning.max_grade + 0.01, "spinto su un punto calpestabile, non sull'argine (z=%.1f)" % pp.z)
	var cp := _companion.global_position
	_check(not RailwayDistrict.is_on_tracks(Vector2(cp.x, cp.z)), "compagno spinto fuori (z=%.1f)" % cp.z)
	_check(_train.player_hits == 1 and _train.enemies_hit == 1, "un colpo al giocatore, un rottamatore (%d, %d)" % [_train.player_hits, _train.enemies_hit])
	_check(_train.next_at > _run.elapsed and _train.next_at - _run.elapsed <= _run.tuning.train_interval_seconds, "prossimo treno fra %.0f s" % (_train.next_at - _run.elapsed))
	_check(_audio.play_count(&"train_horn") >= 2, "fischio anche all'ingresso")
	bystander.queue_free()
	_director.enemies.clear()


## Review Focus 5: un vagone scavato a meta ha gia dato rottami; il treno azzera il resto
## della vena ma i rottami a terra fuori fascia restano.
func _test_half_dug_wagon() -> void:
	print("half dug wagon")
	_run.district.rebuild()
	_field.load_base(_run.base_relief_path(), _run.district.layout_seed)
	_scrap.take_in_rect(Rect2(-200.0, -70.0, 400.0, 140.0), 1000)
	_scrap._veins.clear()
	_run.district.apply_strokes(_field, _scrap)
	var wagon: Dictionary = _run.district.terrain_strokes.filter(func(s: Dictionary) -> bool: return s.kind == &"wagon")[0]
	var center := Vector3(wagon.center.x, 0.0, wagon.center.y)
	var before := _scrap.count()
	for i in 12:
		_field.player_sculpt(center, 2.4, -0.3, TerrainField.ToolMode.DIG)
	var spawned := _scrap.count() - before
	_check(spawned >= 2 and _scrap.vein_scrap_left(center) < RailwayDistrict.WAGON_SCRAP, "scavando il vagone escono rottami (%d)" % spawned)
	# Il rottame piu vicino viene portato fuori fascia prima del treno (come farebbe il compagno).
	var moved := 0
	for scrap in _scrap._scraps:
		if RailwayDistrict.is_on_tracks(Vector2(scrap.global_position.x, scrap.global_position.z)):
			scrap.global_position.z = 6.0
			moved += 1
	_place(_player, Vector3(0.0, 0.0, 20.0), 0.88)
	_place(_companion, Vector3(0.0, 0.0, 22.0), 0.3)
	_train.speed = 80.0
	_train.next_at = _run.elapsed + 1.05
	for i in 700:
		await physics_frame
		if _train.passes >= 2:
			break
	_check(_train.passes == 2, "un altro treno e passato")
	_check(_scrap.vein_scrap_left(center) == 0 and absf(_field.delta_at(center)) < 0.02, "la vena del vagone e azzerata e il cumulo spianato")
	_check(_scrap.count() >= moved and moved > 0, "i rottami gia usciti restano a terra (%d)" % _scrap.count())


func _test_second_train_from_the_other_side() -> void:
	(come oggi: il terzo treno viene da est; `passes == 3`; giocatore fuori fascia non toccato)
```
Nell'`_initialize` l'ordine e: `_test_setup`, `_test_warning`, `_test_pass_flattens_and_hits`, `_test_half_dug_wagon`, `_test_second_train_from_the_other_side` (con `heading` atteso `-1` e nome `EST`, `passes == 3`).

- [ ] **Step 2: Eseguire e vedere il FAIL** — `godot_console --headless --path godot --fixed-fps 60 --script res://tests/train_tests.gd`. Atteso: `wagons_swept`/`terrain_field` non esistono.

- [ ] **Step 3: Implementare `TrainEvent` sul rilievo**

```gdscript
@export var terrain_field: TerrainField
## Passi di PUSH_STEP_M provati oltre il bordo per far atterrare chi e spinto fuori.
const PUSH_LANDING_STEPS := 6
const PUSH_STEP_M := 1.2
## Una zolla ogni tanti m3 spianati, al piu DEBRIS_PER_STEP a passo.
const DEBRIS_PER_M3 := 2.0
const DEBRIS_PER_STEP := 4

var volume_flattened := 0.0
var wagons_swept := 0
var _swept_x := 0.0
var _debris_budget := 0.0


func is_enabled() -> bool:
	return first_seconds > 0.0 and district != null and terrain_field != null
```
In `_start_passing`: `volume_flattened = 0.0`, `wagons_swept = 0`, `_debris_budget = 0.0`, `_swept_x = _head_x` (dopo aver calcolato `_head_x`). In `_tick_passing`: `_sweep_band()` al posto di `_sweep_cells()`. In `_finish_pass` il marker: `print("PROTOTYPE01_TRAIN_PASSED passes=%d volume=%.1f wagons=%d enemies=%d player_hits=%d" % [passes, volume_flattened, wagons_swept, enemies_hit, player_hits])`.

```gdscript
## Il tratto percorso dal muso in questo passo torna alla base per tutta la larghezza
## della fascia: argini, barricate e vagoni spariscono senza rottami, i solchi si riempiono.
func _sweep_band() -> void:
	var lo := minf(_swept_x, _head_x) - 0.6
	var hi := maxf(_swept_x, _head_x) + 0.6
	_swept_x = _head_x
	lo = maxf(lo, -district.half_x())
	hi = minf(hi, district.half_x())
	if hi <= lo:
		return
	var center := Vector3((lo + hi) * 0.5, 0.0, 0.0)
	var half := Vector2((hi - lo) * 0.5, RailwayDistrict.TRACK_HALF_WIDTH)
	var volume := terrain_field.reset_to_base(center, half)
	if volume > 0.01:
		volume_flattened += volume
		_debris_budget += volume
		var bursts := 0
		while _debris_budget >= DEBRIS_PER_M3 and bursts < DEBRIS_PER_STEP:
			_debris_budget -= DEBRIS_PER_M3
			bursts += 1
			var at := Vector3(rng.randf_range(lo, hi), 0.0, rng.randf_range(-half.y, half.y))
			DebrisBurst.spawn(get_parent(), at + Vector3(0.0, 0.8, 0.0), EARTH_COLOR, 12, 5.0, 0.2)
		train_hit.emit(&"terrain")
	var rect := Rect2(lo, -half.y, hi - lo, half.y * 2.0)
	if scrap_field != null:
		var swept := scrap_field.exhaust_veins_in_rect(rect)
		if swept > 0:
			wagons_swept += swept
			train_hit.emit(&"wagon")
		if scrap_field.take_in_rect(rect, 16) > 0:
			train_hit.emit(&"scrap")
	if lamp_field != null and lamp_field.knock_down_in_rect(rect) > 0:
		train_hit.emit(&"lamp")


## Spinto fuori dal lato dove gia pende, sul primo punto calpestabile (niente argini,
## niente pendii ripidi) allontanandosi dal bordo; poi sull'altro lato; altrimenti il bordo.
func _push_out(body: Node3D) -> void:
	var at := body.global_position
	var lift := clampf(at.y - terrain_field.height_at(at), 0.3, 1.5)
	var side := 1.0 if at.z >= 0.0 else -1.0
	var edge := RailwayDistrict.TRACK_HALF_WIDTH + PUSH_MARGIN
	var chosen := Vector3(at.x, 0.0, side * edge)
	var found := false
	for candidate: float in [side, -side]:
		for step in PUSH_LANDING_STEPS:
			var probe := Vector3(at.x, 0.0, candidate * (edge + step * PUSH_STEP_M))
			if absf(probe.z) > district.half_z() - 1.0:
				break
			if terrain_field.delta_at(probe) < 0.5 and terrain_field.slope_at(probe) <= terrain_field.tuning.max_grade:
				chosen = probe
				found = true
				break
		if found:
			break
	chosen.y = terrain_field.height_at(chosen) + lift
	body.global_position = chosen
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
	body.reset_physics_interpolation()
```
Togliere `grid`, `cells_flattened`, `_swept_column`, `_sweep_cells`, `PUSH_LANDING_CELLS`.

- [ ] **Step 4: Eseguire e vedere il PASS** — `train_tests` `PASS`; anche `railway_tests` resta verde.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/run/train_event.gd godot/tests/train_tests.gd
git commit -m "Treno sul rilievo: la fascia torna alla base sotto il muso, vagoni azzerati senza rottami, spinta fuori su un punto calpestabile"
```

---

### Task 5: La Trivella sul rilievo (`Driller`)

**Files:**
- Modify: `godot/scripts/enemies/driller.gd`
- Modify: `godot/scripts/run/arena_run.gd` (`_make_driller`: `terrain_field` al posto di `grid`)
- Modify: `godot/scripts/enemies/enemy_tuning.gd` o `run_tuning.gd` (dove stanno `driller_*`: aggiungere `driller_furrow_depth_m := 0.8`, `driller_wall_min_delta_m := 0.8`; `grep -n driller_ godot/scripts/run/run_tuning.gd`)
- Modify: `godot/tests/tools/capture_railway.gd` (argine con `sculpt`)
- Test: `godot/tests/driller_tests.gd` (riscritta)

**Interfaces:**
- Consumes: `TerrainField.delta_at`, `base_height_at`, `height_at`, `level`, `collision_body()`; `PathField.is_walkable`, `next_waypoint`; `ScrapField.extract_from_veins`.
- Produces: `Driller.terrain_field`, `furrow_depth_m`, `wall_min_delta_m`, `furrow_length_m: float`, `walls_broken: int`, `last_wall: Vector3` (`NO_WALL = Vector3.INF`), segnali `furrowed(point: Vector3)`, `wall_broken(point: Vector3)`; costanti `FURROW_RADIUS = 1.2`, `BREACH_RADIUS = 2.4`.

- [ ] **Step 1: Riscrivere `driller_tests.gd` (fallisce)** — stessa intestazione e aiuti, `_field: TerrainField` al posto di `_grid`; `_place_player`/`_place_boss` aggiungono la quota del rilievo (`_field.height_at(at) + 0.88`, `+ Driller.boss_spawn_height()`); `_clear_tracks()` diventa `_field.reset_to_base(Vector3.ZERO, Vector2(_run.district.half_x(), RailwayDistrict.TRACK_HALF_WIDTH))` seguita da `_run._start_protect_left = 0.0; _field.set_protected(Vector3.ZERO, _field.tuning.start_protected_radius_m, false)`; `_test_call_and_arrival`, `_test_blocked_by_ruin_uses_path`, `_test_train_hits_boss`, `_test_defeat_completes_level` invariati; gli altri:

```gdscript
func _test_aim_and_charge() -> void:
	print("aim and charge")
	_clear_tracks()
	_place_player(Vector3(-20.0, 0.0, 0.0))
	_place_boss(Vector3(2.0, 0.0, 0.0), Driller.Phase.REST, 0.1)
	_check(await _wait_phase(Driller.Phase.AIM, 30), "dal riposo passa alla mira")
	_check(_boss.get_node(^"AimStrip").visible, "striscia di mira visibile")
	_check(_boss.charge_direction.dot(Vector3(-1.0, 0.0, 0.0)) > 0.95, "mira verso il giocatore (ovest)")
	var charges := _audio.play_count(&"driller_charge")
	var health_before := _player.health
	_check(await _wait_phase(Driller.Phase.CHARGE, int(_boss.aim_seconds * 60.0) + 20), "finita la mira parte la carica")
	_check(not _boss.get_node(^"AimStrip").visible and _audio.play_count(&"driller_charge") == charges + 1, "striscia nascosta e suono della carica")
	var start := _boss.global_position
	await _frames(60)
	var moved := _boss.global_position - start
	_check(moved.x < -3.0 and absf(moved.z) < 0.5, "avanza dritta verso ovest (%.1f m)" % -moved.x)
	var speed := _planar(_boss.velocity).length()
	_check(absf(speed - _boss.charge_speed) < 0.5, "a %.1f m/s" % speed)
	_check(_boss.furrow_length_m >= 2.0, "lascia un solco dietro di se (%.1f m)" % _boss.furrow_length_m)
	var behind := Vector3(start.x - 1.5, 0.0, 0.0)
	_check(_field.delta_at(behind) < -0.6, "il punto attraversato e 0,8 m sotto la base (%.2f)" % _field.delta_at(behind))
	_check(await _wait_phase(Driller.Phase.REST, 400), "la carica finisce in riposo")
	_check(_player.health == health_before - _boss.contact_damage, "giocatore colpito una volta (%d -> %d)" % [health_before, _player.health])
	_check(absf(_player.global_position.z) >= Driller.SIDE_PUSH - 0.5, "e spinto di lato (z=%.1f)" % _player.global_position.z)
	_check(_boss.charges == 1 and _boss.walls_broken == 0, "una carica, nessun argine")


## Un argine sulla linea ferma la carica: il varco torna alla base senza rottami e la
## Trivella resta stordita con danno doppio; poi riposa e mira di nuovo.
func _test_wall_stops_and_stuns() -> void:
	print("wall")
	_clear_tracks()
	_place_player(Vector3(-24.0, 0.0, 0.0))
	_place_boss(Vector3(2.0, 0.0, 0.0), Driller.Phase.REST, 0.05)
	var wall := Vector3(-9.6, 0.0, 0.0)
	_field.sculpt(wall, 2.0, 1.4)
	var scrap_before := _scrap.count()
	_check(await _wait_phase(Driller.Phase.CHARGE, 200), "carica verso l'argine")
	var stunned := false
	for i in 240:
		await physics_frame
		if _boss.phase == Driller.Phase.STUN:
			stunned = true
			break
	_check(stunned and _boss.walls_broken == 1 and _boss.last_wall.distance_to(wall) < 2.5, "l'argine la ferma e la stordisce (%s)" % _boss.last_wall)
	_check(_field.delta_at(wall) < 0.3, "il varco e aperto (delta %.2f)" % _field.delta_at(wall))
	_check(_scrap.count() == scrap_before, "nessun rottame dal varco")
	_check(_planar(_boss.velocity).length() < 0.3, "ferma")
	var health := _boss.health
	_boss.take_damage(5)
	_check(_boss.health == health - int(ceil(5 * _boss.stun_damage_multiplier)), "stordita subisce danno x%.0f (%d -> %d)" % [_boss.stun_damage_multiplier, health, _boss.health])
	_check(_audio.play_count(&"boss_demolish") >= 1, "suono dell'argine sfondato")
	_boss.phase_left = 0.05
	await _frames(6)
	_check(_boss.phase == Driller.Phase.REST, "finito lo stordimento riposa")
	health = _boss.health
	_boss.take_damage(5)
	_check(_boss.health == health - 5, "fuori dallo stordimento danno normale")


## Un argine con una vena sotto rende i rottami della vena (non del terreno).
func _test_wall_over_vein_gives_scrap() -> void:
	print("vein under wall")
	_clear_tracks()
	_place_player(Vector3(-24.0, 0.0, 0.0))
	_place_boss(Vector3(2.0, 0.0, 0.0), Driller.Phase.REST, 0.05)
	var wall := Vector3(-9.6, 0.0, 0.0)
	_field.sculpt(wall, 2.4, 1.5)
	_scrap.add_vein(wall, 2.4, 4, _field.base_height_at(wall) + 1.0)
	var before := _scrap.count()
	_check(await _wait_phase(Driller.Phase.CHARGE, 200), "carica")
	for i in 240:
		await physics_frame
		if _boss.phase == Driller.Phase.STUN:
			break
	_check(_boss.phase == Driller.Phase.STUN and _scrap.count() > before, "sfondando il cumulo con la vena escono rottami (%d)" % (_scrap.count() - before))
	_scrap._veins.clear()
	_boss.phase_left = 0.05
	await _frames(6)


## Review Focus 3: un rialzo basso (< 0,8 m) non la ferma.
func _test_low_mound_does_not_stop() -> void:
	print("low mound")
	_clear_tracks()
	_place_player(Vector3(-30.0, 0.0, 0.0))
	_place_boss(Vector3(2.0, 0.0, 0.0), Driller.Phase.REST, 0.05)
	_field.sculpt(Vector3(-9.6, 0.0, 0.0), 2.0, 0.5)
	_check(await _wait_phase(Driller.Phase.CHARGE, 200), "carica")
	var stunned := false
	for i in 400:
		await physics_frame
		if _boss.phase == Driller.Phase.STUN:
			stunned = true
		if _boss.phase == Driller.Phase.REST:
			break
	_check(not stunned and _boss.walls_broken == 0 and _boss.global_position.x < -12.0, "supera il rialzo basso senza stordirsi (x=%.1f)" % _boss.global_position.x)


## Review Focus 4: una seconda carica sullo stesso solco non scava oltre.
func _test_furrow_is_idempotent() -> void:
	print("furrow idempotent")
	_clear_tracks()
	_place_player(Vector3(-100.0, 0.0, 0.0))
	_place_boss(Vector3(0.0, 0.0, 0.0), Driller.Phase.REST, 0.05)
	_check(await _wait_phase(Driller.Phase.CHARGE, 200), "prima carica")
	_check(await _wait_phase(Driller.Phase.REST, 700), "si ferma da sola")
	var probe := Vector3(-10.0, 0.0, 0.0)
	var first := _field.delta_at(probe)
	_check(first < -0.6 and first > -1.0, "solco a %.2f m" % first)
	_place_boss(Vector3(0.0, 0.0, 0.0), Driller.Phase.REST, 0.05)
	_check(await _wait_phase(Driller.Phase.CHARGE, 200), "seconda carica sulla stessa linea")
	_check(await _wait_phase(Driller.Phase.REST, 700), "si ferma di nuovo")
	_check(absf(_field.delta_at(probe) - first) < 0.08, "il solco resta a %.2f m (era %.2f)" % [_field.delta_at(probe), first])


## La carica finisce dopo `charge_length` metri; un solco non la rallenta.
func _test_charge_length_and_trench() -> void:
	print("length and trench")
	_clear_tracks()
	_place_player(Vector3(-100.0, 0.0, 0.0))
	_place_boss(Vector3(0.0, 0.0, 0.0), Driller.Phase.REST, 0.05)
	for k in 6:
		_field.sculpt(Vector3(-8.0 - k * 2.4, 0.0, 0.0), 2.0, -0.8)
	_check(await _wait_phase(Driller.Phase.CHARGE, 200), "carica verso ovest")
	var start := _boss.global_position
	var in_trench_speed := 0.0
	for i in 600:
		await physics_frame
		if _boss.phase != Driller.Phase.CHARGE:
			break
		if _field.delta_at(_boss.global_position) < -0.4:
			in_trench_speed = maxf(in_trench_speed, _planar(_boss.velocity).length())
	var travelled := _planar(_boss.global_position - start).length()
	_check(_boss.phase == Driller.Phase.REST, "si ferma da sola")
	_check(absf(travelled - _boss.charge_length) < 2.0, "dopo %.1f m (limite %.0f)" % [travelled, _boss.charge_length])
	_check(in_trench_speed > _boss.charge_speed - 0.5, "nel solco va a piena velocita (%.1f m/s)" % in_trench_speed)
```
Ordine in `_initialize`: call, aim, wall, vein, low mound, idempotent, length, ruin, train, defeat.

- [ ] **Step 2: Eseguire e vedere il FAIL** — `godot_console --headless --path godot --fixed-fps 60 --script res://tests/driller_tests.gd`. Atteso: `furrow_length_m`/`terrain_field` non esistono.

- [ ] **Step 3: Implementare**

```gdscript
signal furrowed(point: Vector3)
signal wall_broken(point: Vector3)

const NO_WALL := Vector3.INF
const FURROW_RADIUS := 1.2
const BREACH_RADIUS := 2.4

var terrain_field: TerrainField
var furrow_depth_m := 0.8
var wall_min_delta_m := 0.8
var furrow_length_m := 0.0
var walls_broken := 0
var last_wall := NO_WALL
```
In `setup_driller`: togliere `ignores_lowered = true`; `max_grade = 10.0`; `floor_max_angle = atan(0.8)`. `drive`: `if player == null or terrain_field == null: return`.

```gdscript
func _aim_direction() -> Vector3:
	var pos := global_position
	var direct := _planar(player.global_position - pos)
	if direct.length_squared() < 0.01:
		return -global_basis.z
	direct = direct.normalized()
	if path_field == null or not path_field.is_ready():
		return direct
	for meters in AIM_PROBE_METERS:
		var probe := pos + direct * meters
		# Un argine lo vuole (lo sfonda); una rovina no.
		if not path_field.is_walkable(probe) and terrain_field.delta_at(probe) < wall_min_delta_m:
			var waypoint: Variant = path_field.next_waypoint(pos)
			if waypoint != null:
				var via := _planar(waypoint - pos)
				if via.length_squared() > 0.01:
					return via.normalized()
			break
	return direct


func _update_aim_strip() -> void:
	var from := global_position
	from.y = terrain_field.height_at(from) + 0.4
	...


func _start_charge() -> void:
	... last_wall = NO_WALL ...


func _tick_charge(delta: float) -> void:
	rotation.y = atan2(-charge_direction.x, -charge_direction.z)
	var planar := Vector3(velocity.x, 0.0, velocity.z).move_toward(charge_direction * charge_speed, ACCELERATION * delta)
	velocity = Vector3(planar.x, 0.0 if is_on_floor() else velocity.y - 9.8 * delta, planar.z)
	move_and_slide()
	var pos := global_position
	var tip := pos + charge_direction * BIT_REACH
	if terrain_field.delta_at(tip) >= wall_min_delta_m:
		_break_wall(Vector3(tip.x, 0.0, tip.z))
		return
	# Solco: la punta porta il terreno a furrow_depth_m sotto la base, mai oltre.
	var floor_h := terrain_field.base_height_at(tip) - furrow_depth_m
	if terrain_field.height_at(tip) > floor_h + 0.05:
		var volume := terrain_field.level(Vector3(tip.x, 0.0, tip.z), FURROW_RADIUS, floor_h, 1.0)
		if volume < -0.01:
			furrow_length_m += Vector2(velocity.x, velocity.z).length() * delta
			DebrisBurst.spawn(get_parent(), Vector3(tip.x, terrain_field.height_at(tip) + 0.3, tip.z), EARTH_COLOR, 6, 3.0, 0.16)
			furrowed.emit(Vector3(tip.x, 0.0, tip.z))
	_hit_in_the_way(player, true)
	if companion != null:
		_hit_in_the_way(companion, false)
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().y > 0.5:
			continue
		var collider := collision.get_collider() as Node
		if collider != null and collider != terrain_field.collision_body():
			_end_charge(&"blocked")
			return
	if _planar(pos - charge_start).length() >= charge_length:
		_end_charge(&"length")


## Un argine ferma la carica: il varco torna alla base (la terra si polverizza, niente
## rottami salvo quelli di una vena sotto), la Trivella resta stordita con la punta scoperta.
func _break_wall(point: Vector3) -> void:
	var volume := terrain_field.level(point, BREACH_RADIUS, terrain_field.base_height_at(point), 1.0)
	walls_broken += 1
	last_wall = point
	DebrisBurst.spawn(get_parent(), point + Vector3(0.0, 0.6, 0.0), EARTH_COLOR, 14, 5.0, 0.22)
	if scrap_field != null and volume < 0.0:
		scrap_field.extract_from_veins(point, BREACH_RADIUS, -volume)
	print("PROTOTYPE01_DRILLER_WALL x=%.1f z=%.1f total=%d" % [point.x, point.z, walls_broken])
	wall_broken.emit(point)
	_end_charge(&"wall")
	phase = Phase.STUN
	phase_left = stun_seconds
	print("PROTOTYPE01_DRILLER_STUNNED seconds=%.1f" % stun_seconds)
	stunned.emit(stun_seconds)


func _end_charge(reason: StringName) -> void:
	velocity = Vector3.ZERO
	phase = Phase.REST
	phase_left = rest_seconds
	print("PROTOTYPE01_DRILLER_CHARGE_END reason=%s furrow_m=%.1f" % [reason, furrow_length_m])
	charge_ended.emit(reason)
```
Togliere `grid`, `cells_drilled`, `cell_drilled`, `NO_CELL`, `_cell_center`. In `ArenaRun._make_driller`: `driller.terrain_field = terrain_field`, `driller.furrow_depth_m = tuning.driller_furrow_depth_m`, `driller.wall_min_delta_m = tuning.driller_wall_min_delta_m`. `ScrapField.extract_from_veins` controlla `height_at(center) > base_height + 0.05` (il varco appena livellato sta alla base: passa). In `capture_railway.gd`: `var field: TerrainField = scene.get_node(^"TerrainField"); field.sculpt(boss.global_position + Vector3(-7.2, 0.0, 0.0), 2.0, 1.4)`.

- [ ] **Step 4: Eseguire e vedere il PASS** — `driller_tests` e `campaign_tests` `PASS`.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/enemies/driller.gd godot/scripts/run godot/tests/driller_tests.gd godot/tests/tools/capture_railway.gd
git commit -m "Trivella sul rilievo: solco idempotente sotto la base, argine di 0,8 m che la ferma e si apre senza rottami, rovine aggirate via campo"
```

---

### Task 6: Scene minori sul rilievo, via il pericolo e il Companion Slice

**Files:**
- Modify: `godot/scenes/main/smoke_test.tscn`, `godot/scenes/main/ruins_arena.tscn`
- Delete: `godot/scenes/main/companion_slice.tscn`, `godot/scripts/terrain/terrain_hazard.gd` (+ `.uid`), `godot/scripts/terrain/hazard_tuning.gd` (+ `.uid`), `godot/resources/tuning/hazard_default.tres`, `godot/tests/terrain_tests.gd`, `godot/tests/slice_b_tests.gd`, `godot/tests/terrain_tool_tests.gd`
- Modify: `godot/scripts/companion/companion.gd` (via `hazard`, `grid`, `_assist_against_hazard`, la chiamata a riga 145)
- Modify: `godot/tests/companion_tests.gd` (riscritta su `ruins_arena.tscn`), `godot/tests/ruins_arena_tests.gd`, `godot/tests/input_events_tests.gd`, `godot/tests/live_rebuild_tests.gd`, `godot/tests/player_tests.gd` (solo se cerca `TerrainGrid`)
- Modify: `docs/GODOT_PARITY_CHECKLIST.md` (Slice B e pericolo: non esistono piu, nota in testa)

**Interfaces:**
- Consumes: Task 1 (`size_m: Vector2`).
- Produces: `smoke_test.tscn` = `Arena` + `TerrainField` (`size_m = Vector2(128, 128)`, `terrain_default.tres`) + `Player(terrain_field)` + `CameraRig` + `TuningSwitcher`; `ruins_arena.tscn` = `OvergrownArena(terrain_field)` + `TerrainField` (128) + `Player` + `CameraRig` + `TuningSwitcher` + `ScrapField(terrain_field)` + `Companion(player, scrap_field)`.

- [ ] **Step 1: Test che fallisce** — nuova `companion_tests.gd`:

```gdscript
extends SceneTree
## Test del compagno e del campo dei rottami sulla scena `ruins_arena` (tappa B: il
## Companion Slice e il pericolo non esistono piu). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/companion_tests.gd

const ArenaScene := preload("res://scenes/main/ruins_arena.tscn")

var _failures := 0
var _player: PlayerCharacter
var _field: TerrainField
var _companion: Companion
var _scraps: ScrapField


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	await _load_scene()
	await _test_supply_distance()
	await _reload_scene()
	await _test_scrap_field_offset_and_cap()
	await _frames(2)
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


## can_supply: rottami a bordo e compagno entro il raggio d'azione dal bersaglio.
func _test_supply_distance() -> void:
	print("supply")
	_check(_player.companion == _companion, "il compagno si registra sul giocatore")
	_check(_companion.carried == 3, "dotazione iniziale 3 rottami")
	_companion.set_physics_process(false)
	_companion.global_position = Vector3(0.0, 0.3, -2.0)
	_check(_companion.can_supply(Vector3(0.0, 0.0, 2.0)), "vicino e con rottami rifornisce")
	_companion.carried = 0
	_check(not _companion.can_supply(Vector3(0.0, 0.0, 2.0)), "senza rottami no")
	_companion.carried = 3
	_companion.global_position = Vector3(20.0, 0.3, 20.0)
	_check(not _companion.can_supply(Vector3(0.0, 0.0, 2.0)), "lontano no")
	_check(_scraps.terrain_field == _field, "il campo dei rottami sta sul rilievo")
	_scraps.spawn_on_ground(Vector3(4.0, 0.0, 4.0))
	var found: Variant = _scraps.nearest(Vector3(4.0, 0.0, 4.0), 0.1)
	_check(found != null and absf((found as Vector3).y - ScrapField.SCRAP_SIZE) < ScrapField.BOB_HEIGHT + 0.01, "il rottame poggia sulla quota del rilievo")
```
piu `_test_scrap_field_offset_and_cap` copiato da oggi senza la riga `_hazard.set_physics_process(false)`, e gli aiuti `_check`, `_load_scene` (`_player = scene.get_node("Player")`, `_field = scene.get_node("TerrainField")`, `_companion`, `_scraps`), `_reload_scene`, `_frames`.

- [ ] **Step 2: Eseguire e vedere il FAIL** — `godot_console --headless --path godot --fixed-fps 60 --script res://tests/companion_tests.gd`. Atteso: `TerrainField` non trovato nella scena.

- [ ] **Step 3: Scene e cancellazioni** — `smoke_test.tscn`: ext_resource `terrain_field.gd` al posto di `terrain_grid.gd`; via `7_hazard`, `8_hazard_tuning` e il nodo `TerrainHazard`; nodo:

```
[node name="TerrainField" type="Node3D" parent="."]
script = ExtResource("5_terrain")
size_m = Vector2(128, 128)
tuning = ExtResource("6_terrain_tuning")
```
`Player`: `node_paths=PackedStringArray("terrain_field")`, `terrain_field = NodePath("../TerrainField")`. Aggiornare `load_steps`. `ruins_arena.tscn`: idem, piu `OvergrownArena` con `node_paths=PackedStringArray("terrain_field")` e `terrain_field = NodePath("../TerrainField")`, `ScrapField` con `terrain_field`, `Companion` con `node_paths=PackedStringArray("player", "scrap_field")`. Cancellare i file elencati (`git rm`). `Companion`: togliere gli export `grid` e `hazard`, la chiamata `_assist_against_hazard()` e la funzione; aggiornare il commento in testa.

- [ ] **Step 4: Suite collegate** — `ruins_arena_tests`: `_field: TerrainField` al posto di `_grid`, via la riga su `TerrainHazard`, `_test_cells_use_natural_ground` → 

```gdscript
func _test_relief_present() -> void:
	print("relief")
	_check(_field.resolution_x == 257 and _field.half_extents().is_equal_approx(Vector2(64.0, 64.0)), "campo da 128 m (%d vertici)" % _field.resolution_x)
	_check(_arena.terrain_field == _field and _arena._relief_ready(), "l'arena conosce il rilievo")
	_check(_arena.get_node_or_null(^"Ground") == null, "nessun pavimento piatto: il suolo e il rilievo")
```
(se `_build_ground` crea un nodo con altro nome, usare quello; il pavimento piatto sparisce nel Task 7, quindi questo controllo entra nel Task 7 se qui fallisce: annotarlo).
`input_events_tests`: `_field: TerrainField` al posto di `_grid` (`scene.get_node("TerrainField")`); `_test_trigger_fires_once_per_pull` diventa:

```gdscript
## Grilletto: finche e premuto il pennello lavora a ogni passo; al rilascio si ferma;
## una nuova pressione riparte (tappa A: azione continua, non un colpo per pressione).
func _test_trigger_holds_brush() -> void:
	print("right trigger")
	var strokes := [0]
	_field.player_sculpted.connect(func(_c, _r, _v, _m): strokes[0] += 1)
	for value in [0.3, 0.6, 0.8, 1.0, 0.9]:
		_joy_motion(TRIGGER_RIGHT, value)
		await _frames(1)
	_check(_player.tool_held and strokes[0] >= 2, "grilletto tirato: pennello continuo (%d pennellate)" % strokes[0])
	_joy_motion(TRIGGER_RIGHT, 0.2)
	await _frames(2)
	var after_release := strokes[0]
	await _frames(3)
	_check(not _player.tool_held and strokes[0] == after_release, "sotto la soglia il pennello si ferma")
	_joy_motion(TRIGGER_RIGHT, 1.0)
	await _frames(2)
	_check(strokes[0] > after_release, "nuova pressione: riparte")
	_joy_motion(TRIGGER_RIGHT, 0.0)
	await _frames(1)
```
e `_test_hold_per_source`:

```gdscript
func _test_hold_per_source() -> void:
	print("hold per source")
	_mouse_button(MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	_check(_player.tool_held, "il clic tiene il pennello")
	_joy_motion(TRIGGER_RIGHT, 0.6)
	await _frames(1)
	_joy_motion(TRIGGER_RIGHT, 1.0)
	await _frames(1)
	_mouse_button(MOUSE_BUTTON_LEFT, false)
	await _frames(1)
	_check(_player.tool_held, "clic rilasciato ma grilletto tirato: resta premuto")
	_joy_motion(TRIGGER_RIGHT, 0.0)
	await _frames(2)
	_check(not _player.tool_held, "rilasciato tutto: si ferma")
	_mouse_button(MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	_check(_player.tool_held, "una nuova pressione riparte")
	_mouse_button(MOUSE_BUTTON_LEFT, false)
	await _frames(1)
```
(`tool_held` e la proprieta esposta dal giocatore nella tappa A: `grep -n "tool_held" godot/scripts/player/player_character.gd`). `_test_tuning_switcher` resta. `live_rebuild_tests`: via `TerrainGridScript`, `_test_terrain_grid`, `_cells`. `player_tests`: verificare che non tocchi `TerrainGrid`.

- [ ] **Step 5: Eseguire e vedere il PASS** — `companion_tests`, `ruins_arena_tests`, `input_events_tests`, `live_rebuild_tests`, `player_tests`: `PASS`. `--check-only` su `companion.gd`.

- [ ] **Step 6: Commit**

```bash
git add -A godot/scenes/main godot/scripts/companion godot/scripts/terrain godot/resources/tuning godot/tests docs/GODOT_PARITY_CHECKLIST.md
git commit -m "Scene minori sul rilievo: smoke test e arena in rovina su un campo da 128 m; via Companion Slice, pericolo e suite della sola griglia"
```

---

### Task 7: Addio alla griglia

**Files:**
- Delete: `godot/scripts/terrain/terrain_grid.gd` (+ `.uid`), `terrain_state.gd` (+ `.uid`), `godot/resources/materials/terrain_cell.gdshader`, `godot/resources/materials/ruins_ground.gdshader` (solo se `grep -rn "ruins_ground.gdshader" godot` non trova altri usi oltre `overgrown_arena.gd`)
- Modify (rami `grid` da togliere, righe nell'inventario del 12 ottobre 2026): `scripts/run/arena_run.gd`, `scripts/player/player_character.gd`, `scripts/navigation/path_field.gd`, `scripts/navigation/flow_preview.gd`, `scripts/companion/scrap_field.gd`, `scripts/terrain/lamp_field.gd`, `scripts/run/extraction_pad.gd`, `scripts/audio/run_audio.gd`, `scripts/enemies/demolisher.gd`, `scripts/run/quake_event.gd`, `scripts/ui/run_map.gd`, `scripts/ui/run_hud.gd`, `scripts/arena/ruins_district.gd`, `scripts/arena/railway_district.gd`, `scripts/arena/overgrown_arena.gd`, `scripts/enemies/enemy_director.gd`, `scripts/enemies/enemy.gd`, `scripts/terrain/terrain_tuning.gd`, `scripts/terrain/brush_preview.gd` (se serve esporre `LAMP_COLOR`)
- Modify: `resources/tuning/terrain_default.tres`, `terrain_arena.tres`, `terrain_railway.tres`, `terrain_district.tres` (solo i campi del pennello)
- Modify: `tests/flow_preview_tests.gd`, `tests/menu_tests.gd`, `tests/district_tests.gd`, `tests/economy_tests.gd`, `tests/ui_theme_tests.gd`, `tests/button_prompts_tests.gd` (se usa `TerrainState`), `tests/tools/capture_extraction.gd`, `capture_flow.gd`, `capture_motion.gd`, `capture_workshop.gd`, `benchmark_arena.gd`, `simulate_runs.gd`
- Modify: `tools/godot/Invoke-GodotChecks.ps1` (marker solo `PROTOTYPE01_TERRAIN_FIELD_READY`; via la riga in allowlist `Parameter "material" is null`)

**Interfaces:**
- Consumes: tutto quanto sopra.
- Produces: nessun simbolo `TerrainGrid`/`TerrainState` nel progetto (`grep -rn "TerrainGrid\|TerrainState\|terrain_grid\|ignores_lowered\|cell_state_at" godot --include=*.gd --include=*.tscn --include=*.tres` vuoto); `RunMap` con le sole funzioni `*_heights`; `LampField.positions()` unica lettura; `BrushPreview.LAMP_COLOR` usato dall'HUD.

- [ ] **Step 1: Test che fallisce** — la "prova" e il gate: cancellare i due script e lo shader (`git rm`), poi

```
powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1
```
Atteso: `--check-only` rosso su ogni script che nomina `TerrainGrid`/`TerrainState` (l'elenco stampato e la lista di lavoro).

- [ ] **Step 2: Togliere i rami** — per ciascun file, nell'ordine dell'inventario:
  - `arena_run.gd`: via `@export var grid`, `set_protected_cell`, `RunMap.snapshot(grid.state)`, `command_applied`, il ramo `terrain_features` dei marker, `_check_scale` a celle, `tool_range_bonus_cm`, `_build_terrain_layout` resta solo `_build_terrain_relief()` (via `_build_courtyard_walls`), `RunMap.render` a celle, `_on_terrain_command`, `raised_color_override`, la lambda `TerrainState.ToolMode` → `TerrainField.ToolMode`. `_initial_heights` resta.
  - `player_character.gd`: via `terrain_grid`, la penalita Lowered, il tool a celle (`_use_terrain_tool` ramo griglia), il ciclo dei modi su `TerrainState.ToolMode` → `TerrainField.ToolMode` (il giocatore della tappa A ha gia il ciclo DIG → RAISE → LEVEL → LAMP: tenere quello), `_update_preview` a box (resta solo il decal), `tool_range_bonus_cm`; `print("PROTOTYPE01_TERRAIN_MODE Dig")` resta sotto `if terrain_field != null`.
  - `path_field.gd`: via `grid`, `cell_changed`/`rebuilt`, `_on_grid_rebuilt`, `_terrain_index` e `_scan_terrain_chunk` (restano `_static_blocked`, `_slope_blocked`), il ramo RAISED in `_refresh_blocked`, il confronto `collider.get_parent() != grid`; `is_walkable` = non bloccato (statico o pendenza).
  - `flow_preview.gd`, `scrap_field.gd` (`spawn_on_cell`, `_on_command_applied`, `_on_cell_changed`, `_free_neighbor`, `count_on_cell` se solo griglia), `lamp_field.gd` (`_lamps`, `cells()`, `has_lamp`, `_build_lamp`, `_remove`, `_on_cell_changed`, `_on_grid_rebuilt`, il ramo `Vector2i` di `can_place`), `extraction_pad.gd` (`pad_cells`, `is_flat(cell)`, `_ensure_marker`, `center: Vector2i`), `run_audio.gd` (`_on_terrain_command`; resta `player_sculpted`), `demolisher.gd` (tutti i rami `grid`, `_wall_target: Vector2i`, `_site_cell`, `spawn_on_cell`), `quake_event.gd` (`fault_cells`, `_shake_cell`, `_cell_center`, `cells_raised/filled` → restano i contatori del rilievo), `run_map.gd` (`snapshot`, `changed_cells`, `cell_color`, `render`, `_pixel_of`, `_pixel_at`), `run_hud.gd` (`set_tool_mode`: solo `TerrainField.ToolMode.LAMP`; colore `BrushPreview.LAMP_COLOR`), `ruins_district.gd` (`terrain_features`, `_add_feature`, `snap_to_cell`, `cell_offset_to_world`, `feature_centroid`, `_ring_offsets`; i `_plan_*` tengono solo le pennellate; `stats.features` → `stats.strokes`), `railway_district.gd` (eventuali residui), `overgrown_arena.gd` (`_build_ground` e il pavimento piatto: via; `_build_ground_cover` legge sempre il rilievo), `enemy_director.gd` (`grid`, `penalty`, ramo LOWERED, confronto con `grid`), `enemy.gd` (`ignores_lowered`), `terrain_tuning.gd` (restano `brush_*`, `sculpt_rate_m_s`, `level_rate`, `max_grade`, `pack_*`, `tool_range_m`, `protected_radius_m`, `start_protected_radius_m`, `start_protected_seconds`; commento in testa aggiornato), i quattro `.tres` (solo `script = ExtResource(...)`, nessun campo della griglia).
  - Suite e strumenti: `flow_preview_tests` tiene solo la variante sul rilievo (`_test_relief_player_strokes_trigger` e, se mancano, versioni sul rilievo di "le scie seguono il campo" e "cortile sigillato" con `sculpt`); `menu_tests` via le costanti e il blocco `TerrainState` in `_test_map_rules`; `district_tests` via le costanti e `terrain_features` (usa `terrain_strokes`); `economy_tests` costanti `TerrainField.ToolMode`; `ui_theme_tests`/`button_prompts_tests` `TerrainField.ToolMode`; `capture_extraction`/`capture_flow`/`capture_motion`/`capture_workshop`: `TerrainField` con `sculpt`/`player_sculpt` al posto di `set_cell_states`/`apply_command_at`; `benchmark_arena`: via il ramo `grid`; `simulate_runs`: via `_grid`, `TerrainState.ToolMode` → `TerrainField.ToolMode`, lo scavo del bot usa `_field` (`_tick_dig`: punta a una vena con rottami entro la portata, altrimenti scava davanti a se solo se `delta_at > 0.3`).
  - Gate: marker `"PROTOTYPE01_TERRAIN_FIELD_READY"`, allowlist vuota (`$allowedErrorPatterns = @()`).

- [ ] **Step 3: Gate completo**

```
powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1
```
Atteso: `GODOT_CHECKS PASS`. Se compare `Parameter "material" is null` senza la griglia, cercarne la causa nuova prima di riannotarla.

- [ ] **Step 4: Grep finale**

```
grep -rn "TerrainGrid\|TerrainState\|terrain_grid\|ignores_lowered\|cell_state_at\|cell_local_position\|apply_ground_tiles" godot --include=*.gd --include=*.tscn --include=*.tres --include=*.gdshader
```
Atteso: nessuna riga (i commenti storici si riscrivono).

- [ ] **Step 5: Commit**

```bash
git add -A godot tools/godot/Invoke-GodotChecks.ps1
git commit -m "Addio alla griglia a celle: TerrainGrid, TerrainState, shader delle celle e ogni ramo a celle rimossi; un solo sistema di terreno"
```

---

### Task 8: Bot della ferrovia, benchmark, catture, documenti, decisione

**Files:**
- Modify: `godot/tests/tools/simulate_runs.gd` (bot: scava i vagoni prima del treno, alza un argine sulla rotta della Trivella con `bump_along`), `godot/tests/tools/benchmark_arena.gd` (`-- --level=railway`)
- Modify: `docs/DECISIONS.md` (D-087; note su D-012 e D-067), `docs/RAILWAY_LEVEL_SPEC.md`, `docs/TERRAIN_SYSTEM.md`, `docs/TERRAIN_MIGRATION_MAP.md` (nota storica in testa), `docs/GODOT_WORKFLOW.md`, `docs/PROJECT_ROADMAP.md`, `docs/MIGRATION_STATUS.md`, `docs/INDEX.md` (questo piano), `docs/superpowers/plans/2026-10-12-continuous-terrain-railway.md` (checkbox)
- Regenerate: `output/railway/*.png`, `output/campaign/*.png` se la mappa cambia

**Interfaces:**
- Consumes: tutto.

- [ ] **Step 1: Bot della ferrovia** — in `simulate_runs.gd`, nel ramo di scavo (`_tick_dig`): se `_run.train_event != null` e `_run.train_event.state != TrainEvent.State.IDLE`, non scavare sulla fascia; il bersaglio preferito e la vena con `scrap_left > 0` piu vicina entro `reach + 2`; durante la carica della Trivella (`_run.boss is Driller and (_run.boss as Driller).is_aiming()`) e con `_player.pack.amount >= 8`: se `_field.bump_along(boss.global_position, boss.global_position + boss.charge_direction * 12.0, 0.8) == null`, tenere il pennello in modo RAISE per 0,8 s puntando `boss.global_position + boss.charge_direction * 8.0` (solo se entro la portata, altrimenti ignorare). Eseguire:

```
godot_console --headless --path godot --fixed-fps 60 --script res://tests/tools/simulate_runs.gd -- --level=railway --seeds=1,2,3 --bot=scrapper
```
(controllare la sintassi degli argomenti in testa allo script). Atteso: tre run concluse, righe `PROTOTYPE01_SIM_RESULT`; annotare in `RAILWAY_LEVEL_SPEC.md` sezione 8 esiti e tempi, con la data.

- [ ] **Step 2: Benchmark e catture**

```
godot_console --headless --path godot --fixed-fps 60 --script res://tests/tools/benchmark_arena.gd -- --level=railway
godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 4000 --script res://tests/tools/capture_railway.gd -- --out=../output/railway
```
Atteso: righe `PROTOTYPE01_ARENA_BENCH` con `chunks=189`, pennellata media sotto 1,5 ms; PNG in `output/railway/` (guardarli: fascia piatta e scura, vagoni come cumuli ruggine, Trivella con solco e argine).

- [ ] **Step 3: Export Windows e verifica**

```
godot_console --headless --path godot --export-release "Windows Desktop" ../LocalBuilds/Prototype01-Godot-Win64/Prototype01.exe
powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1 -Executable LocalBuilds/Prototype01-Godot-Win64/Prototype01.exe
```
Atteso: `GODOT_CHECKS PASS` sulla build; `levels/railway/base.bin` nel pacchetto (lo smoke della build con `--level=railway` stampa `PROTOTYPE01_TERRAIN_LAYOUT_READY` senza ricalcolo: cercare nel log l'assenza di "base ricalcolata", o misurare che l'avvio non paga 0,6 s in piu).

- [ ] **Step 4: Documenti** — `DECISIONS.md`: riga `D-087 | 2026-10-12 | Provvisoria (da giudicare nel playtest)`: ferrovia sul rilievo (fascia 3,6 m piatta, vagoni = cumuli con vena da 8, treno che riporta alla base e azzera le vene, Trivella con solco idempotente 0,8 m e varco **senza rottami**, saltatori per pendenza), scene minori sul rilievo, Companion Slice e pericolo eliminati, griglia eliminata; motivazione e conseguenze; in D-012 e D-067 una nota "superata da D-087 il 12 ottobre 2026". `RAILWAY_LEVEL_SPEC.md`: sezioni 2-5 riscritte in metri (fascia, cumuli, solco, argine) e stato "sul rilievo continuo dal 12 ottobre 2026". `TERRAIN_SYSTEM.md`: "Sistema unico: TerrainField (D-085, D-086, D-087)". `TERRAIN_MIGRATION_MAP.md`: nota in testa "storico: la griglia non esiste piu dal 12 ottobre 2026". `GODOT_WORKFLOW.md`: cottura per livello (`-- --level=railway`), suite tolte, marker del gate, allowlist vuota. `INDEX.md`: riga di questo piano. `PROJECT_ROADMAP.md` (Stato operativo: tappa B fatta, prossimo passo: giudizio del proprietario e audio Sonniss) e `MIGRATION_STATUS.md` (voce nuova con trappole incontrate).

- [ ] **Step 5: Gate finale e commit**

```
powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1
git add -A godot/tests/tools docs output/railway
git commit -m "Tappa B chiusa: bot della ferrovia su vagoni e argini, benchmark e catture del livello 2, documenti (D-087)"
```
