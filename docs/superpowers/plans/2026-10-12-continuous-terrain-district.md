# Terreno continuo, tappa A (quartiere): piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sostituire nel livello 1 (`arena_run.tscn`) la griglia a celle con un rilievo continuo scolpibile (Terrain3D per dati e resa, collisione a chunk nostra, Jolt), riscrivendo tool, orda, Demolitore, rottami, lampioni, eventi e mappa sulle quote.

**Architecture:** `TerrainField` (nuovo) possiede un campo di quote a passo 0,5 m (sorgente di verita in un `PackedFloat32Array`, headless-safe) e lo rispecchia nel nodo `Terrain3D` per la resa; `TerrainCollision` tiene 196 `HeightMapShape3D` da 16 m rigenerati solo sotto il pennello; tutti i consumatori leggono `height_at`/`grade_between`/`delta_at` e scrivono solo con `sculpt`/`level`; un solo segnale `region_changed(aabb)` più `player_sculpted` per ciò che dipende dal tool del giocatore. La griglia `TerrainGrid` resta nel progetto solo per la ferrovia e le scene minori (tappa B la toglie).

**Tech Stack:** Godot 4.7.2 GDScript, addon Terrain3D 1.0.2 (GDExtension, MIT), Jolt Physics, Blender 5.2 per lo zainetto, suite `tests/*.gd` headless con `godot_console`.

**Spec:** `docs/superpowers/specs/2026-10-12-continuous-terrain-design.md` (leggerla prima di ogni task; la mappa dei consumatori è in `docs/TERRAIN_MIGRATION_MAP.md`).

## Global Constraints

- Engine **Godot 4.7.2**; comandi sempre con `godot_console` (mai `godot`), vedi `docs/GODOT_WORKFLOW.md`.
- Terrain3D **1.0.2-stable** da `addons/terrain_3d/` (binari Windows/Linux x86_64 e arm64); nessun'altra dipendenza nuova; nessuna spesa.
- `physics/3d/physics_engine = "Jolt Physics"`; `floor_max_angle = atan(0.8)` su tutti i `CharacterBody3D` del livello.
- Passo dei vertici **0,5 m**; `region_size` 256; quattro regioni centrate sull'origine; quote in [−2,5, +4] m.
- Pendenza massima di marcia **0,8 m/m** (`max_grade`); saltatori 1,2.
- Pennello del giocatore: raggio **2,4 m**, 2,2 m/s al centro, campana `(1 − d²)²`; zainetto 60 m³ (20 all'avvio).
- Il tool bersaglia **3,6 m** davanti al giocatore (era 480 cm); `tool_reach` vale +1,2 m per livello.
- Chunk di collisione **32 x 32 celle (16 m)**, `HeightMapShape3D` 33 x 33, layer 1; aggiornamento nello **stesso passo fisico** di `region_changed`.
- Rottami **solo dalle vene** (un rottame ogni 0,8 m³ asportati sotto la quota di base del cumulo); mai dal suolo nudo.
- Tutti gli identificatori, i nomi di file e i log in inglese; commenti e documenti in italiano; controller e tastiera/mouse equivalenti.
- Ogni task: `--check-only` sugli script toccati, suite pertinenti verdi, commit piccolo con messaggio in italiano e trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Non toccare le scene `railway_run.tscn`, `smoke_test.tscn`, `companion_slice.tscn`, `ruins_arena.tscn` (restano sulla griglia fino alla tappa B).

## Review Focus

1. **Pennellata a cavallo di due regioni/chunk**: `sculpt` centrato a x = 0 (confine delle regioni Terrain3D e di due chunk) deve aggiornare entrambe le regioni e tutti i chunk toccati, senza cuciture né buchi di collisione. Test in Task 2 (`_test_sculpt_across_region_border`) e Task 3 (`_test_chunks_across_border`).
2. **Alzare sotto un corpo**: una pennellata positiva sotto il giocatore o un nemico non deve incastrarlo nel terreno: il corpo viene spinto su dal `HeightMapShape3D` (Jolt) e `is_on_floor()` resta vero. Test in Task 3 (`_test_body_pushed_up`).
3. **Zaino vuoto in modo Alza e zaino pieno in modo Scava**: nessuna modifica del terreno nel primo caso con anello rosso; terra persa nel secondo senza blocco. Test in Task 5 (`_test_raise_with_empty_pack`, `_test_dig_with_full_pack`).
4. **Nemico in una conca con pareti ripide**: non deve restare fermo per sempre: dopo 2 s rosicchia e la conca si apre. Test in Task 7 (`_test_enemy_gnaws_out_of_pit`).
5. **Vena esaurita e Demolitore su un cumulo del giocatore senza vena**: nessun rottame da terreno nudo in entrambi i casi. Test in Task 9 (`_test_vein_exhausted_gives_nothing`) e Task 10 (`_test_boss_levels_player_mound_without_scrap`).

---

### Task 1: Dipendenze e progetto (Terrain3D, Jolt, export, licenze)

**Files:**
- Create: `godot/addons/terrain_3d/**` (copia dal release zip; già nel branch `spike/terrain3d`, commit `c407d59`)
- Modify: `godot/project.godot` (sezione `[physics]`)
- Modify: `godot/export_presets.cfg` (nessun cambio ai filtri: `addons/terrain_3d/*` non è escluso)
- Modify: `godot/tests/addons_tests.gd`
- Modify: `docs/TOOLS_AND_LICENSES.md`, `docs/DECISIONS.md` (D-085 → Approvata)

**Interfaces:**
- Produces: la classe `Terrain3D` disponibile a runtime e in headless (`ClassDB.class_exists("Terrain3D")`), motore fisico Jolt.

- [ ] **Step 1: Test che fallisce** — in `godot/tests/addons_tests.gd` aggiungere una funzione e chiamarla in `_initialize()` dopo `_test_grass_disabled()`:

```gdscript
func _test_terrain3d_and_jolt() -> void:
	print("terrain3d and jolt")
	_check(FileAccess.file_exists("res://addons/terrain_3d/plugin.cfg"), "Terrain3D installato")
	_check(FileAccess.file_exists("res://addons/terrain_3d/bin/libterrain.windows.release.x86_64.dll"), "binario Windows presente")
	_check(FileAccess.file_exists("res://addons/terrain_3d/bin/libterrain.linux.release.x86_64.so"), "binario Linux presente")
	_check(ClassDB.class_exists("Terrain3D"), "estensione caricata (classe Terrain3D)")
	_check(ProjectSettings.get_setting("physics/3d/physics_engine", "") == "Jolt Physics", "motore fisico Jolt")
```

- [ ] **Step 2: Eseguire e vedere il FAIL**

```
godot_console --headless --path godot --fixed-fps 60 --script res://tests/addons_tests.gd
```
Atteso: `FAIL Terrain3D installato` e `FAIL motore fisico Jolt`.

- [ ] **Step 3: Installare** — dal branch dello spike: `git checkout spike/terrain3d -- godot/addons/terrain_3d` (oppure copiare `addons/terrain_3d` dallo zip `Terrain3D_v1.0.2-stable.zip`). In `godot/project.godot`, sezione `[physics]`, aggiungere la riga `3d/physics_engine="Jolt Physics"` sopra `common/physics_ticks_per_second=120`. Poi `godot_console --headless --path godot --editor --quit` due volte (la prima importa e scrive `.godot/extension_list.cfg`).

- [ ] **Step 4: Eseguire e vedere il PASS** — stesso comando dello step 2: `PROTOTYPE01_TESTS PASS`.

- [ ] **Step 5: Gate completo sotto Jolt** — `powershell -File tools/godot/Invoke-GodotChecks.ps1` deve finire con `GODOT_CHECKS PASS` (verificato il 12 ottobre 2026 nel worktree dello spike; ripetere).

- [ ] **Step 6: Documenti** — in `docs/TOOLS_AND_LICENSES.md`, sezione "Addon Godot installati", aggiungere la riga: `| Terrain3D | 1.0.2-stable (19 maggio 2026) da GitHub TokisanGames/Terrain3D | Rilievo continuo del livello (D-085): dati, clipmap, texture; collisione nostra | MIT (LICENSE.txt nell'addon); binari Windows/Linux/macOS; dichiarato per Godot 4.4-4.6, verificato su 4.7.2 (spike del 12 ottobre 2026); plugin editor non abilitato (uso solo da codice) |`. In `docs/DECISIONS.md` lo stato di D-085 diventa `Approvata`.

- [ ] **Step 7: Commit**

```bash
git add godot/addons/terrain_3d godot/project.godot godot/tests/addons_tests.gd docs/TOOLS_AND_LICENSES.md docs/DECISIONS.md
git commit -m "Terrain3D 1.0.2 e Jolt nel progetto (D-085): addon, motore fisico, test, licenza"
```

---

### Task 2: `TerrainField` (quote, pennello, interrogazioni, Terrain3D)

**Files:**
- Create: `godot/scripts/terrain/terrain_field.gd`
- Create: `godot/tests/terrain_field_tests.gd`
- Modify: `godot/scripts/terrain/terrain_tuning.gd` (nuovi campi del pennello, i vecchi restano per la griglia)

**Interfaces:**
- Produces (tutti in metri, coordinate mondo; `TerrainField extends Node3D`, `class_name TerrainField`):
  - `enum ToolMode { DIG, RAISE, LEVEL, LAMP }`
  - `signal region_changed(aabb: AABB)`; `signal player_sculpted(center: Vector3, radius: float, volume: float, mode: int)`
  - `@export var size_m := 204.0`, `@export var tuning: TerrainTuning`, `const SPACING := 0.5`, `const MIN_HEIGHT := -2.5`, `const MAX_HEIGHT := 4.0`
  - `var resolution: int`; `func half_extent() -> float`
  - `func height_at(p: Vector3) -> float`, `func base_height_at(p: Vector3) -> float`, `func delta_at(p: Vector3) -> float`, `func normal_at(p: Vector3) -> Vector3`, `func slope_at(p: Vector3) -> float`
  - `func grade_between(a: Vector3, b: Vector3) -> float`, `func can_step(from: Vector3, to: Vector3, max_grade: float) -> bool`
  - `func is_flat(center: Vector3, radius: float, tolerance: float) -> bool`, `func highest_bump(center: Vector3, radius: float, min_delta: float) -> Variant`
  - `func is_protected(p: Vector3) -> bool`, `func set_protected(center: Vector3, radius: float, on: bool) -> void`
  - `func sculpt(center: Vector3, radius: float, amount: float) -> float`, `func level(center: Vector3, radius: float, target: float, strength: float) -> float`
  - `func player_sculpt(center: Vector3, radius: float, amount: float, mode: int) -> float`, `func player_level(center: Vector3, radius: float, strength: float) -> float`
  - `func commit_base() -> void`, `func tint(center: Vector3, radius: float, color: Color, strength: float) -> void`
  - `func save_base(path: String) -> int`, `func load_base(path: String) -> bool`
  - `func terrain3d() -> Terrain3D` (null in headless finché non è pronto; mai usato dai consumatori)
  - `var volume_moved := 0.0` (somma dei |volumi| di `player_sculpt`)

- [ ] **Step 1: Tuning** — in `godot/scripts/terrain/terrain_tuning.gd` aggiungere in fondo:

```gdscript
@export_group("Brush")
## Pennello del giocatore (terreno continuo, D-082): raggio, velocita al centro, livella.
@export var brush_radius_m := 2.4
@export var sculpt_rate_m_s := 2.2
@export var level_rate := 5.0
## Pendenza massima di marcia (metri di quota per metro).
@export var max_grade := 0.8
## Zainetto di terra (m3): capacita e quantita all'avvio del livello.
@export var pack_capacity_m3 := 60.0
@export var pack_start_m3 := 20.0
## Distanza del bersaglio del tool davanti al giocatore, metri.
@export var tool_range_m := 3.6
## Dischi non scolpibili attorno alle fondamenta e al cortile di partenza (primi 10 s).
@export var protected_radius_m := 1.5
@export var start_protected_radius_m := 6.0
@export var start_protected_seconds := 10.0
```

- [ ] **Step 2: Suite che fallisce** — creare `godot/tests/terrain_field_tests.gd`:

```gdscript
extends SceneTree
## Suite del rilievo continuo (D-082, D-085): quote, pennello, livella, pendenza,
## aree protette, base, bump, salvataggio. Headless: Terrain3D viene rispecchiato
## solo quando esiste (`terrain3d()` puo essere null).
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/terrain_field_tests.gd

var _failures := 0
var _field: TerrainField


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	await _open()
	_test_flat_start()
	_test_sculpt_volume_and_bell()
	_test_sculpt_across_region_border()
	_test_level()
	_test_grade_and_can_step()
	_test_protected()
	_test_base_delta_and_bump()
	_test_is_flat()
	_test_save_load_base()
	await _test_player_sculpt_signals()
	await _frames(2)
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _open() -> void:
	_field = TerrainField.new()
	_field.size_m = 64.0
	_field.tuning = TerrainTuning.new()
	root.add_child(_field)
	await _frames(3)


func _test_flat_start() -> void:
	print("flat start")
	_check(_field.resolution == 129, "64 m a passo 0,5 = 129 vertici per lato (%d)" % _field.resolution)
	_check(is_zero_approx(_field.height_at(Vector3(3.3, 0, -7.1))), "quota zero all'inizio")
	_check(_field.normal_at(Vector3.ZERO).is_equal_approx(Vector3.UP), "normale verticale su un piano")


func _test_sculpt_volume_and_bell() -> void:
	print("sculpt")
	var volume := _field.sculpt(Vector3(10, 0, 10), 2.4, 1.0)
	_check(absf(_field.height_at(Vector3(10, 0, 10)) - 1.0) < 0.02, "al centro sale di 1 m (%.2f)" % _field.height_at(Vector3(10, 0, 10)))
	_check(_field.height_at(Vector3(11.2, 0, 10)) > 0.2 and _field.height_at(Vector3(11.2, 0, 10)) < 0.8, "a meta raggio sale a campana")
	_check(is_zero_approx(_field.height_at(Vector3(13, 0, 10))), "fuori dal raggio non cambia")
	# Volume della campana (1-d^2)^2 su un disco: pi * r^2 / 3 = 6,03 m3 per 1 m al centro.
	_check(absf(volume - 6.03) < 0.5, "volume firmato circa pi r^2 / 3 (%.2f)" % volume)
	var dug := _field.sculpt(Vector3(10, 0, 10), 2.4, -1.0)
	_check(absf(dug + volume) < 0.05 and absf(_field.height_at(Vector3(10, 0, 10))) < 0.02, "scavare la stessa quantita riporta a zero")
	_field.sculpt(Vector3(-20, 0, -20), 2.4, 10.0)
	_check(absf(_field.height_at(Vector3(-20, 0, -20)) - TerrainField.MAX_HEIGHT) < 0.01, "clamp alla quota massima")
	_field.sculpt(Vector3(-20, 0, 20), 2.4, -10.0)
	_check(absf(_field.height_at(Vector3(-20, 0, 20)) - TerrainField.MIN_HEIGHT) < 0.01, "clamp alla quota minima")


func _test_sculpt_across_region_border() -> void:
	print("sculpt across border")
	var aabb_seen: Array[AABB] = []
	var handler := func(aabb: AABB) -> void: aabb_seen.append(aabb)
	_field.region_changed.connect(handler)
	_field.sculpt(Vector3(0, 0, 0), 2.4, 0.8)
	_field.region_changed.disconnect(handler)
	_check(aabb_seen.size() == 1, "una pennellata = un solo region_changed")
	_check(aabb_seen[0].has_point(Vector3(-2.3, 0, -2.3)) and aabb_seen[0].has_point(Vector3(2.3, 0, 2.3)), "l'AABB copre tutto il pennello")
	_check(absf(_field.height_at(Vector3(-0.25, 0, -0.25)) - _field.height_at(Vector3(0.25, 0, 0.25))) < 0.05, "nessuna cucitura sul confine")
	_field.sculpt(Vector3(0, 0, 0), 2.4, -0.8)


func _test_level() -> void:
	print("level")
	_field.sculpt(Vector3(20, 0, -20), 2.4, 1.5)
	var moved := _field.level(Vector3(20, 0, -20), 3.0, 0.0, 1.0)
	_check(absf(_field.height_at(Vector3(20, 0, -20))) < 0.05, "livella porta il centro alla quota data")
	_check(moved < 0.0, "livellare un cumulo restituisce volume negativo (terra tolta)")


func _test_grade_and_can_step() -> void:
	print("grade")
	_field.sculpt(Vector3(-10, 0, 0), 2.4, 1.6)
	var foot := Vector3(-13.0, 0, 0)
	var top := Vector3(-10.0, 0, 0)
	_check(_field.grade_between(foot, top) > 0.4, "salita positiva verso il cumulo (%.2f)" % _field.grade_between(foot, top))
	_check(_field.grade_between(top, foot) < 0.0, "discesa negativa")
	_check(_field.can_step(top, foot, 0.8), "in discesa si passa sempre")
	_check(not _field.can_step(Vector3(-11.2, 0, 0), Vector3(-10.4, 0, 0), 0.3), "salita ripida oltre la soglia bloccata")
	_check(_field.can_step(Vector3(-11.2, 0, 0), Vector3(-10.4, 0, 0), 3.0), "con soglia alta si passa")
	_check(_field.slope_at(Vector3(-11.2, 0, 0)) > 0.3, "pendenza locale sul fianco")
	_field.sculpt(Vector3(-10, 0, 0), 2.4, -1.6)


func _test_protected() -> void:
	print("protected")
	_field.set_protected(Vector3(5, 0, -5), 1.5, true)
	_check(_field.is_protected(Vector3(5.5, 0, -5)), "dentro il disco protetto")
	_check(not _field.is_protected(Vector3(8, 0, -5)), "fuori dal disco")
	var volume := _field.sculpt(Vector3(5, 0, -5), 2.4, 1.0)
	_check(is_zero_approx(_field.height_at(Vector3(5, 0, -5))), "i pixel protetti non cambiano")
	_check(_field.height_at(Vector3(7.0, 0, -5)) > 0.05, "i pixel liberi dello stesso pennello cambiano")
	_check(volume > 0.0 and volume < 6.0, "il volume conta solo i pixel scritti")
	_field.set_protected(Vector3(5, 0, -5), 1.5, false)
	_field.level(Vector3(5, 0, -5), 3.0, 0.0, 1.0)


func _test_base_delta_and_bump() -> void:
	print("base and bump")
	_field.sculpt(Vector3(0, 0, 15), 3.0, 0.6)
	_field.commit_base()
	_check(absf(_field.base_height_at(Vector3(0, 0, 15)) - 0.6) < 0.02, "commit_base fissa la quota di base")
	_check(is_zero_approx(_field.delta_at(Vector3(0, 0, 15))), "delta zero subito dopo il commit")
	_field.sculpt(Vector3(4, 0, 15), 2.4, 1.2)
	_check(absf(_field.delta_at(Vector3(4, 0, 15)) - 1.2) < 0.02, "delta = attuale - base")
	var bump: Variant = _field.highest_bump(Vector3(0, 0, 15), 10.0, 0.8)
	_check(bump != null and (bump as Vector3).distance_to(Vector3(4, 0, 15)) < 0.8, "highest_bump trova la cima alzata dal giocatore")
	_check(_field.highest_bump(Vector3(-20, 0, 0), 5.0, 0.8) == null, "nessun bump dove non c'e nulla")
	_field.sculpt(Vector3(4, 0, 15), 2.4, -1.2)


func _test_is_flat() -> void:
	print("is_flat")
	_check(_field.is_flat(Vector3(-25, 0, 25), 3.0, 0.35), "piano dove e piano")
	_field.sculpt(Vector3(-25, 0, 25), 2.4, 0.5)
	_check(not _field.is_flat(Vector3(-25, 0, 25), 3.0, 0.35), "non piano con un cumulo di 0,5 m")
	_field.sculpt(Vector3(-25, 0, 25), 2.4, -0.5)


func _test_save_load_base() -> void:
	print("save/load")
	var path := "user://terrain_field_test_%d.bin" % OS.get_process_id()
	_field.sculpt(Vector3(12, 0, -12), 2.4, 0.9)
	_field.commit_base()
	var bytes := _field.save_base(path)
	_check(bytes > 0, "salvataggio scritto (%d byte)" % bytes)
	var other := TerrainField.new()
	other.size_m = 64.0
	other.tuning = TerrainTuning.new()
	root.add_child(other)
	_check(other.load_base(path), "caricamento riuscito")
	_check(absf(other.height_at(Vector3(12, 0, -12)) - 0.9) < 0.02, "le quote caricate coincidono")
	_check(absf(other.base_height_at(Vector3(12, 0, -12)) - 0.9) < 0.02, "la base caricata coincide")
	other.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_field.sculpt(Vector3(12, 0, -12), 2.4, -0.9)
	_field.commit_base()


func _test_player_sculpt_signals() -> void:
	print("player signals")
	var got: Array = []
	var handler := func(center: Vector3, radius: float, volume: float, mode: int) -> void: got.append([center, radius, volume, mode])
	_field.player_sculpted.connect(handler)
	var v := _field.player_sculpt(Vector3(0, 0, -20), 2.4, -0.3, TerrainField.ToolMode.DIG)
	_field.player_sculpted.disconnect(handler)
	_check(got.size() == 1 and got[0][3] == TerrainField.ToolMode.DIG and absf(got[0][2] - v) < 0.001, "player_sculpt emette player_sculpted con volume e modo")
	_check(absf(_field.volume_moved - absf(v)) < 0.001, "volume_moved accumula il valore assoluto")
	await _frames(1)


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

- [ ] **Step 3: Eseguire e vedere il FAIL**

```
godot_console --headless --path godot --fixed-fps 60 --script res://tests/terrain_field_tests.gd
```
Atteso: errore di parse (`TerrainField` non esiste).

- [ ] **Step 4: Implementazione** — creare `godot/scripts/terrain/terrain_field.gd`:

```gdscript
class_name TerrainField
extends Node3D
## Rilievo continuo del livello (D-082, D-085). Le quote vivono in `_heights` (un
## valore ogni SPACING metri, origine al centro, sorgente di verita anche in headless);
## il nodo Terrain3D, se c'e, le rispecchia per la resa. Nessun altro script parla con
## Terrain3D: tutto passa da qui. Scrive solo `sculpt`/`level`; chi vuole reagire a un
## cambio si collega a `region_changed`. `player_sculpted` e per cio che dipende dal
## tool del giocatore (rottami, suoni, impronte, contatori).

signal region_changed(aabb: AABB)
signal player_sculpted(center: Vector3, radius: float, volume: float, mode: int)

enum ToolMode { DIG, RAISE, LEVEL, LAMP }

const SPACING := 0.5
const MIN_HEIGHT := -2.5
const MAX_HEIGHT := 4.0
const REGION_SIZE := 256
const SAVE_MAGIC := "TFLD"
const SAVE_VERSION := 1
const TOOL_MODE_NAMES: Array[String] = ["Dig", "Raise", "Level", "Lamp"]

@export var size_m := 204.0
@export var tuning: TerrainTuning
## Senza resa (test headless, benchmark) il nodo Terrain3D non viene creato.
@export var render := true

var resolution := 0
var volume_moved := 0.0
var _half := 0.0
var _heights := PackedFloat32Array()
var _base := PackedFloat32Array()
var _protected := PackedByteArray()
var _terrain: Terrain3D
var _terrain_ready := false
var _collision: TerrainCollision


func _ready() -> void:
	if tuning == null:
		tuning = TerrainTuning.new()
	resolution = int(round(size_m / SPACING)) + 1
	_half = (resolution - 1) * SPACING * 0.5
	_heights.resize(resolution * resolution)
	_heights.fill(0.0)
	_base = _heights.duplicate()
	_protected.resize(resolution * resolution)
	_protected.fill(0)
	_collision = TerrainCollision.new()
	_collision.name = "Collision"
	add_child(_collision)
	_collision.setup(self)
	if render and not DisplayServer.get_name() == "headless":
		_build_terrain3d()
	print("PROTOTYPE01_TERRAIN_FIELD_READY resolution=%d size_m=%.0f" % [resolution, size_m])


func half_extent() -> float:
	return _half


func terrain3d() -> Terrain3D:
	return _terrain if _terrain_ready else null


# --- Letture ---------------------------------------------------------------------------

func height_at(p: Vector3) -> float:
	return _sample(_heights, p)


func base_height_at(p: Vector3) -> float:
	return _sample(_base, p)


func delta_at(p: Vector3) -> float:
	return height_at(p) - base_height_at(p)


func normal_at(p: Vector3) -> Vector3:
	var dx := height_at(p + Vector3(SPACING, 0.0, 0.0)) - height_at(p - Vector3(SPACING, 0.0, 0.0))
	var dz := height_at(p + Vector3(0.0, 0.0, SPACING)) - height_at(p - Vector3(0.0, 0.0, SPACING))
	return Vector3(-dx, 2.0 * SPACING, -dz).normalized()


## Pendenza locale in metri di quota per metro (0 = piano).
func slope_at(p: Vector3) -> float:
	var n := normal_at(p)
	return Vector2(n.x, n.z).length() / maxf(n.y, 0.001)


## Dislivello per metro da [param a] a [param b], positivo in salita.
func grade_between(a: Vector3, b: Vector3) -> float:
	var run := Vector2(b.x - a.x, b.z - a.z).length()
	if run < 0.0001:
		return 0.0
	return (height_at(b) - height_at(a)) / run


## In discesa sempre; in salita solo se nessun tratto di SPACING supera [param max_grade].
func can_step(from: Vector3, to: Vector3, max_grade: float) -> bool:
	var run := Vector2(to.x - from.x, to.z - from.z).length()
	if run < 0.0001:
		return true
	var steps := maxi(int(ceil(run / SPACING)), 1)
	var previous := height_at(from)
	for i in range(1, steps + 1):
		var point := from.lerp(to, float(i) / steps)
		var h := height_at(point)
		if h - previous > max_grade * (run / steps):
			return false
		previous = h
	return true


## Vero se nel disco la differenza fra quota massima e minima resta sotto [param tolerance].
func is_flat(center: Vector3, radius: float, tolerance: float) -> bool:
	var lo := INF
	var hi := -INF
	for p in _disc_points(center, radius):
		var h := _heights[p]
		lo = minf(lo, h)
		hi = maxf(hi, h)
	return hi - lo <= tolerance


## Punto (Vector3 con quota) entro [param radius] con il maggior delta sopra [param min_delta], o null.
func highest_bump(center: Vector3, radius: float, min_delta: float) -> Variant:
	var best: Variant = null
	var best_delta := min_delta
	for p in _disc_points(center, radius):
		var d := _heights[p] - _base[p]
		if d > best_delta:
			best_delta = d
			best = _vertex_world(p)
	return best


func is_protected(p: Vector3) -> bool:
	var i := _index_of(p)
	return i >= 0 and _protected[i] != 0


func set_protected(center: Vector3, radius: float, on: bool) -> void:
	for p in _disc_points(center, radius):
		_protected[p] = 1 if on else 0


# --- Scritture -------------------------------------------------------------------------

## Pennello a campana: [param amount] metri al centro, zero sul bordo; negativo scava.
## Restituisce il volume spostato in m3, col segno; i pixel protetti non cambiano.
func sculpt(center: Vector3, radius: float, amount: float) -> float:
	return _brush(center, radius, func(h: float, falloff: float) -> float:
		return h + amount * falloff)


## Avvicina il disco a [param target]: strength 1 al centro lo porta esattamente li.
func level(center: Vector3, radius: float, target: float, strength: float) -> float:
	return _brush(center, radius, func(h: float, falloff: float) -> float:
		return h + (target - h) * clampf(strength * falloff, 0.0, 1.0))


func player_sculpt(center: Vector3, radius: float, amount: float, mode: int) -> float:
	var volume := sculpt(center, radius, amount)
	volume_moved += absf(volume)
	player_sculpted.emit(center, radius, volume, mode)
	return volume


func player_level(center: Vector3, radius: float, strength: float) -> float:
	var volume := level(center, radius, height_at(center), strength)
	volume_moved += absf(volume)
	player_sculpted.emit(center, radius, volume, ToolMode.LEVEL)
	return volume


## Fissa il rilievo attuale come "naturale": delta e bump si misurano da qui.
func commit_base() -> void:
	_base = _heights.duplicate()


## Pittura sul color map di Terrain3D (strade, piazza, cumuli, barricate); niente in headless.
func tint(center: Vector3, radius: float, color: Color, strength: float) -> void:
	if not _terrain_ready:
		return
	var data := _terrain.data
	for p in _disc_points(center, radius):
		var world := _vertex_world(p)
		var d := Vector2(world.x - center.x, world.z - center.z).length() / radius
		var w := clampf(strength * (1.0 - d * d), 0.0, 1.0)
		var old: Color = data.get_pixel(Terrain3DRegion.TYPE_COLOR, world)
		var mixed := Color(old.r, old.g, old.b, old.a).lerp(Color(color.r, color.g, color.b, old.a), w)
		data.set_pixel(Terrain3DRegion.TYPE_COLOR, world, mixed)
	_mark_regions(center, radius)
	data.update_maps(Terrain3DRegion.TYPE_COLOR, false)


# --- Salvataggio del rilievo di base ------------------------------------------------

func save_base(path: String) -> int:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return 0
	file.store_buffer(SAVE_MAGIC.to_ascii_buffer())
	file.store_32(SAVE_VERSION)
	file.store_32(resolution)
	file.store_float(size_m)
	var raw := _heights.to_byte_array()
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	file.store_32(raw.size())
	file.store_32(packed.size())
	file.store_buffer(packed)
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	return 20 + packed.size()


func load_base(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	if file.get_buffer(4).get_string_from_ascii() != SAVE_MAGIC or file.get_32() != SAVE_VERSION:
		return false
	if file.get_32() != resolution or not is_equal_approx(file.get_float(), size_m):
		return false
	var raw_size := file.get_32()
	var packed_size := file.get_32()
	var raw := file.get_buffer(packed_size).decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != resolution * resolution * 4:
		return false
	_heights = raw.to_float32_array()
	_base = _heights.duplicate()
	_mirror_all()
	region_changed.emit(AABB(Vector3(-_half, MIN_HEIGHT, -_half), Vector3(_half * 2.0, MAX_HEIGHT - MIN_HEIGHT, _half * 2.0)))
	return true


# --- Interni ---------------------------------------------------------------------------

func _index_of(p: Vector3) -> int:
	var ix := int(round((p.x + _half) / SPACING))
	var iz := int(round((p.z + _half) / SPACING))
	if ix < 0 or iz < 0 or ix >= resolution or iz >= resolution:
		return -1
	return iz * resolution + ix


func _vertex_world(i: int) -> Vector3:
	var ix := i % resolution
	var iz := i / resolution
	return Vector3(ix * SPACING - _half, _heights[i], iz * SPACING - _half)


func _sample(array: PackedFloat32Array, p: Vector3) -> float:
	var fx := clampf((p.x + _half) / SPACING, 0.0, resolution - 1.001)
	var fz := clampf((p.z + _half) / SPACING, 0.0, resolution - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * resolution + ix
	var top := lerpf(array[i], array[i + 1], tx)
	var bottom := lerpf(array[i + resolution], array[i + resolution + 1], tx)
	return lerpf(top, bottom, tz)


## Indici dei vertici dentro il disco (XZ).
func _disc_points(center: Vector3, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x0 := maxi(int(floor((center.x - radius + _half) / SPACING)), 0)
	var x1 := mini(int(ceil((center.x + radius + _half) / SPACING)), resolution - 1)
	var z0 := maxi(int(floor((center.z - radius + _half) / SPACING)), 0)
	var z1 := mini(int(ceil((center.z + radius + _half) / SPACING)), resolution - 1)
	var r2 := radius * radius
	for iz in range(z0, z1 + 1):
		var wz := iz * SPACING - _half
		for ix in range(x0, x1 + 1):
			var wx := ix * SPACING - _half
			if (wx - center.x) * (wx - center.x) + (wz - center.z) * (wz - center.z) <= r2:
				out.append(iz * resolution + ix)
	return out


func _brush(center: Vector3, radius: float, shape: Callable) -> float:
	var volume := 0.0
	var r2 := radius * radius
	var x0 := maxi(int(floor((center.x - radius + _half) / SPACING)), 0)
	var x1 := mini(int(ceil((center.x + radius + _half) / SPACING)), resolution - 1)
	var z0 := maxi(int(floor((center.z - radius + _half) / SPACING)), 0)
	var z1 := mini(int(ceil((center.z + radius + _half) / SPACING)), resolution - 1)
	for iz in range(z0, z1 + 1):
		var wz := iz * SPACING - _half
		for ix in range(x0, x1 + 1):
			var wx := ix * SPACING - _half
			var d2 := ((wx - center.x) * (wx - center.x) + (wz - center.z) * (wz - center.z)) / r2
			if d2 >= 1.0:
				continue
			var i := iz * resolution + ix
			if _protected[i] != 0:
				continue
			var falloff := (1.0 - d2) * (1.0 - d2)
			var before := _heights[i]
			var after := clampf(shape.call(before, falloff), MIN_HEIGHT, MAX_HEIGHT)
			_heights[i] = after
			volume += (after - before) * SPACING * SPACING
	_mirror_rect(x0, z0, x1, z1)
	var lo := Vector3(x0 * SPACING - _half, MIN_HEIGHT, z0 * SPACING - _half)
	var hi := Vector3(x1 * SPACING - _half, MAX_HEIGHT, z1 * SPACING - _half)
	region_changed.emit(AABB(lo, hi - lo))
	return volume


# --- Terrain3D (solo resa) ------------------------------------------------------------

func _build_terrain3d() -> void:
	_terrain = Terrain3D.new()
	_terrain.name = "Terrain3D"
	_terrain.vertex_spacing = SPACING
	_terrain.region_size = REGION_SIZE
	_terrain.collision.mode = Terrain3DCollision.DISABLED
	add_child(_terrain)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_terrain.set_camera(camera)
	# In headless (e nel primo fotogramma) `data` non esiste ancora.
	if _terrain.data == null:
		await get_tree().process_frame
	if _terrain.data == null or not is_inside_tree():
		return
	var region_m := REGION_SIZE * SPACING
	for gx in [-region_m * 0.5, region_m * 0.5]:
		for gz in [-region_m * 0.5, region_m * 0.5]:
			_terrain.data.add_region_blankp(Vector3(gx, 0.0, gz), false)
	_terrain_ready = true
	TerrainSurface.apply(_terrain)
	_mirror_all()


func _mirror_all() -> void:
	if not _terrain_ready:
		return
	_mirror_rect(0, 0, resolution - 1, resolution - 1)


func _mirror_rect(x0: int, z0: int, x1: int, z1: int) -> void:
	if not _terrain_ready:
		return
	var data := _terrain.data
	for iz in range(z0, z1 + 1):
		for ix in range(x0, x1 + 1):
			data.set_height(Vector3(ix * SPACING - _half, 0.0, iz * SPACING - _half), _heights[iz * resolution + ix])
	var lo := Vector3(x0 * SPACING - _half, 0.0, z0 * SPACING - _half)
	var hi := Vector3(x1 * SPACING - _half, 0.0, z1 * SPACING - _half)
	for corner in [lo, Vector3(hi.x, 0.0, lo.z), Vector3(lo.x, 0.0, hi.z), hi]:
		var region: Terrain3DRegion = data.get_regionp(corner)
		if region != null:
			region.edited = true
	data.update_maps(Terrain3DRegion.TYPE_HEIGHT, false)


func _mark_regions(center: Vector3, radius: float) -> void:
	for offset in [Vector3(-radius, 0, -radius), Vector3(radius, 0, -radius), Vector3(-radius, 0, radius), Vector3(radius, 0, radius)]:
		var region: Terrain3DRegion = _terrain.data.get_regionp(center + offset)
		if region != null:
			region.edited = true
```

Nota: `TerrainCollision` (Task 3) e `TerrainSurface` (Task 14) sono referenziati qui; per far compilare questo task creare subito due **stub**: `godot/scripts/terrain/terrain_collision.gd` con `class_name TerrainCollision extends Node` e `func setup(_field: TerrainField) -> void: pass`, e `godot/scripts/terrain/terrain_surface.gd` con `class_name TerrainSurface extends RefCounted` e `static func apply(_terrain: Terrain3D) -> void: pass`. I task 3 e 14 li riempiono.

- [ ] **Step 5: Eseguire e vedere il PASS** — comando dello step 3; tutti `ok`. Poi `--check-only` su `terrain_field.gd`.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/terrain/terrain_field.gd godot/scripts/terrain/terrain_collision.gd godot/scripts/terrain/terrain_surface.gd godot/scripts/terrain/terrain_tuning.gd godot/tests/terrain_field_tests.gd
git commit -m "TerrainField: campo di quote a 0,5 m, pennello a campana, livella, pendenza, aree protette, base e bump, salvataggio, specchio su Terrain3D (D-085)"
```

---

### Task 3: `TerrainCollision` (chunk di HeightMapShape3D)

**Files:**
- Modify: `godot/scripts/terrain/terrain_collision.gd` (lo stub del Task 2)
- Modify: `godot/tests/terrain_field_tests.gd` (nuove verifiche)

**Interfaces:**
- Consumes: `TerrainField.region_changed`, `TerrainField.height_at`, `resolution`, `half_extent()`, `SPACING`.
- Produces: `class_name TerrainCollision extends Node`; `var body: StaticBody3D`; `const CHUNK_CELLS := 32`; `func setup(field: TerrainField) -> void`; `func chunk_count() -> int`; `func refreshed_count() -> int` (contatore per test e benchmark); `func refresh_aabb(aabb: AABB) -> void`.

- [ ] **Step 1: Test che fallisce** — aggiungere a `terrain_field_tests.gd` (e in `_initialize()` dopo `_test_flat_start()`):

```gdscript
func _test_collision_chunks() -> void:
	print("collision chunks")
	var collision: TerrainCollision = _field.get_node(^"Collision")
	_check(collision.chunk_count() == 25, "64 m -> 5 x 5 chunk da 16 m (%d)" % collision.chunk_count())
	_check(collision.body.collision_layer == 1, "il corpo del terreno sta sul layer 1")
	var before := collision.refreshed_count()
	_field.sculpt(Vector3(0, 0, 0), 2.4, 1.0)
	_check(collision.refreshed_count() - before == 4, "una pennellata sul confine aggiorna i quattro chunk toccati (%d)" % (collision.refreshed_count() - before))
	var space := root.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 5, 0), Vector3(0, -5, 0), 1)
	var hit := space.intersect_ray(query)
	_check(not hit.is_empty() and absf(hit.position.y - 1.0) < 0.1, "il raggio tocca la collisione alla quota nuova (%.2f)" % (hit.position.y if not hit.is_empty() else -99.0))
	_field.sculpt(Vector3(0, 0, 0), 2.4, -1.0)


func _test_body_pushed_up() -> void:
	print("body pushed up")
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.4
	shape.shape = capsule
	body.add_child(shape)
	body.floor_max_angle = atan(0.8)
	body.position = Vector3(15, 0.7, 15)
	root.add_child(body)
	for i in 10:
		body.velocity = Vector3(0, -2, 0)
		body.move_and_slide()
		await physics_frame
	_check(body.is_on_floor(), "la capsula poggia sul terreno piano")
	_field.sculpt(Vector3(15, 0, 15), 2.4, 1.0)
	for i in 10:
		body.velocity = Vector3(0, -2, 0)
		body.move_and_slide()
		await physics_frame
	_check(body.is_on_floor() and body.position.y > 1.5, "alzare sotto la capsula la spinge su (%.2f)" % body.position.y)
	body.queue_free()
	_field.sculpt(Vector3(15, 0, 15), 2.4, -1.0)
```

Nella `_initialize()` la chiamata a `_test_body_pushed_up()` va con `await`.

- [ ] **Step 2: Eseguire e vedere il FAIL** — `chunk_count` non esiste.

- [ ] **Step 3: Implementazione** — sostituire lo stub `terrain_collision.gd`:

```gdscript
class_name TerrainCollision
extends Node
## Collisione del rilievo continuo (D-085): un solo StaticBody3D sul layer 1 con un
## HeightMapShape3D per chunk di CHUNK_CELLS celle; su `region_changed` si rigenerano
## solo i chunk toccati, nello stesso passo fisico. La collisione di Terrain3D non va
## bene per il gioco (copre un raggio attorno alla camera o ricalcola tutto: 5-35 ms).

const CHUNK_CELLS := 32

var body: StaticBody3D
var _field: TerrainField
var _shapes: Dictionary[Vector2i, HeightMapShape3D] = {}
var _chunks_per_side := 0
var _refreshed := 0


func setup(field: TerrainField) -> void:
	_field = field
	body = StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var chunk_m := CHUNK_CELLS * TerrainField.SPACING
	_chunks_per_side = int(ceil(_field.half_extent() * 2.0 / chunk_m))
	var origin := -_chunks_per_side / 2
	for cx in _chunks_per_side:
		for cz in _chunks_per_side:
			var key := Vector2i(origin + cx, origin + cz)
			var shape := HeightMapShape3D.new()
			shape.map_width = CHUNK_CELLS + 1
			shape.map_depth = CHUNK_CELLS + 1
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.position = Vector3((key.x + 0.5) * chunk_m, 0.0, (key.y + 0.5) * chunk_m)
			collider.scale = Vector3(TerrainField.SPACING, 1.0, TerrainField.SPACING)
			body.add_child(collider)
			_shapes[key] = shape
			_refresh_chunk(key)
	_refreshed = 0
	_field.region_changed.connect(refresh_aabb)


func chunk_count() -> int:
	return _shapes.size()


func refreshed_count() -> int:
	return _refreshed


func refresh_aabb(aabb: AABB) -> void:
	var chunk_m := CHUNK_CELLS * TerrainField.SPACING
	var lo := Vector2i(int(floor(aabb.position.x / chunk_m)), int(floor(aabb.position.z / chunk_m)))
	var hi := Vector2i(int(floor(aabb.end.x / chunk_m)), int(floor(aabb.end.z / chunk_m)))
	for cx in range(lo.x, hi.x + 1):
		for cz in range(lo.y, hi.y + 1):
			var key := Vector2i(cx, cz)
			if _shapes.has(key):
				_refresh_chunk(key)


func _refresh_chunk(key: Vector2i) -> void:
	var shape: HeightMapShape3D = _shapes[key]
	var chunk_m := CHUNK_CELLS * TerrainField.SPACING
	var base := Vector3(key.x * chunk_m, 0.0, key.y * chunk_m)
	var heights := PackedFloat32Array()
	heights.resize((CHUNK_CELLS + 1) * (CHUNK_CELLS + 1))
	var i := 0
	for z in CHUNK_CELLS + 1:
		for x in CHUNK_CELLS + 1:
			heights[i] = _field.height_at(base + Vector3(x * TerrainField.SPACING, 0.0, z * TerrainField.SPACING))
			i += 1
	shape.map_data = heights
	_refreshed += 1
```

- [ ] **Step 4: Eseguire e vedere il PASS** — `terrain_field_tests` tutta verde (con Jolt del Task 1; con Godot Physics la capsula non viene spinta su in modo affidabile).

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/terrain/terrain_collision.gd godot/tests/terrain_field_tests.gd
git commit -m "TerrainCollision: chunk di HeightMapShape3D da 16 m rigenerati sotto il pennello nello stesso passo"
```

---

### Task 4: `SoilPack` (zainetto di terra)

**Files:**
- Create: `godot/scripts/player/soil_pack.gd`
- Modify: `godot/tests/terrain_field_tests.gd`

**Interfaces:**
- Produces: `class_name SoilPack extends RefCounted`; `signal changed(amount: float, capacity: float)`; `var capacity: float`; `var amount: float`; `func take(m3: float) -> float` (quanto ha dato davvero); `func give(m3: float) -> float` (quanto ha accolto; l'eccesso si perde); `func is_empty() -> bool`; `func fill_ratio() -> float`; `func add_capacity(m3: float) -> void`.

- [ ] **Step 1: Test che fallisce** — in `terrain_field_tests.gd`:

```gdscript
func _test_soil_pack() -> void:
	print("soil pack")
	var pack := SoilPack.new(60.0, 20.0)
	var seen: Array = []
	pack.changed.connect(func(a: float, c: float) -> void: seen.append([a, c]))
	_check(absf(pack.take(5.0) - 5.0) < 0.001 and absf(pack.amount - 15.0) < 0.001, "take toglie quello che chiede")
	_check(absf(pack.take(50.0) - 15.0) < 0.001 and pack.is_empty(), "take oltre il contenuto da solo cio che c'e e svuota")
	_check(absf(pack.give(70.0) - 60.0) < 0.001 and absf(pack.fill_ratio() - 1.0) < 0.001, "give oltre la capacita accoglie fino al tetto, il resto si perde")
	pack.add_capacity(20.0)
	_check(absf(pack.capacity - 80.0) < 0.001 and absf(pack.fill_ratio() - 0.75) < 0.001, "add_capacity alza il tetto")
	_check(seen.size() == 4, "ogni cambio emette changed (%d)" % seen.size())
```

- [ ] **Step 2: Eseguire e vedere il FAIL** — `SoilPack` non esiste.

- [ ] **Step 3: Implementazione** — `godot/scripts/player/soil_pack.gd`:

```gdscript
class_name SoilPack
extends RefCounted
## Zainetto di terra dell'ingegnere (spec sezione 3): scavare lo riempie, alzare lo
## svuota; a zaino vuoto non si alza, a zaino pieno la terra in eccesso si perde.

signal changed(amount: float, capacity: float)

var capacity: float
var amount: float


func _init(capacity_m3 := 60.0, start_m3 := 20.0) -> void:
	capacity = capacity_m3
	amount = clampf(start_m3, 0.0, capacity_m3)


func take(m3: float) -> float:
	var given := clampf(m3, 0.0, amount)
	if given > 0.0:
		amount -= given
		changed.emit(amount, capacity)
	return given


func give(m3: float) -> float:
	var room := capacity - amount
	var accepted := clampf(m3, 0.0, room)
	amount += accepted
	changed.emit(amount, capacity)
	return accepted


func is_empty() -> bool:
	return amount <= 0.001


func fill_ratio() -> float:
	return amount / maxf(capacity, 0.001)


func add_capacity(m3: float) -> void:
	capacity += m3
	changed.emit(amount, capacity)
```

- [ ] **Step 4: PASS, check-only, commit**

```bash
git add godot/scripts/player/soil_pack.gd godot/tests/terrain_field_tests.gd
git commit -m "SoilPack: zainetto di terra con capacita, prelievo, riempimento e segnale"
```

---

### Task 5: Tool del giocatore continuo, modi, anteprima a decal, zainetto

**Files:**
- Modify: `godot/scripts/player/player_character.gd` (sezione tool: righe 36-40 export, 50-66 variabili, 245-320 `_update_terrain_speed_modifier`, `_use_terrain_tool`, `_toggle_terrain_mode`, `_update_terrain_target`)
- Create: `godot/scripts/terrain/brush_preview.gd`
- Modify: `godot/scripts/player/player_tuning.gd` (riga 65: `terrain_tool_range_cm` resta per la griglia; nessun cambio)
- Modify: `godot/scripts/ui/run_hud.gd:328-336` (`set_tool_mode`), `godot/scripts/audio/run_audio.gd:173-174, 222-223`
- Modify: `godot/tests/terrain_tool_tests.gd` → nuova suite `godot/tests/terrain_brush_tests.gd` (la vecchia resta per `smoke_test.tscn`)

**Interfaces:**
- Consumes: `TerrainField.player_sculpt/player_level/is_protected/height_at/tuning`, `SoilPack`, `LampField.can_place(point: Vector3)`/`place_at(point)` (Task 11; fino ad allora il modo LAMP cicla solo se `lamp_field != null` e usa l'API attuale).
- Produces sul giocatore: `@export var terrain_field: TerrainField`; `var pack: SoilPack`; `var terrain_tool_mode: int` (valori `TerrainField.ToolMode`); `const TOOL_MODE_NAMES := ["Dig", "Raise", "Level", "Lamp"]`; `var terrain_target: Vector3`; `var tool_held := false` (vero finché il tasto è premuto); `signal terrain_mode_changed(mode: int)`; `signal terrain_tool_rejected`; `var brush_radius_bonus_m := 0.0`; `var tool_range_bonus_m := 0.0`; `func brush_radius() -> float`.
- `BrushPreview extends Decal`: `func show_ring(center: Vector3, radius: float, color: Color) -> void`, `func hide_ring() -> void`, `var last_color: Color`; costanti `DIG_COLOR := Color(0.2, 0.9, 1.0)`, `RAISE_COLOR := Color(1.0, 0.85, 0.2)`, `LEVEL_COLOR := Color(1.0, 1.0, 1.0)`, `LAMP_COLOR := Color(1.0, 0.95, 0.7)`, `INVALID_COLOR := Color(1.0, 0.2, 0.15)`.

- [ ] **Step 1: Suite che fallisce** — creare `godot/tests/terrain_brush_tests.gd` con una scena minima costruita in codice (TerrainField 64 m, Player istanziato da `res://scenes/player/player.tscn`, nessun LampField):

```gdscript
extends SceneTree
## Tool del giocatore sul rilievo continuo (spec sezione 3): pennello continuo, modi,
## zainetto, anteprima a decal, aree protette.
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/terrain_brush_tests.gd

const PlayerScene := preload("res://scenes/player/player.tscn")

var _failures := 0
var _field: TerrainField
var _player: PlayerCharacter


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_field = TerrainField.new()
	_field.size_m = 64.0
	_field.tuning = TerrainTuning.new()
	root.add_child(_field)
	_player = PlayerScene.instantiate()
	_player.terrain_field = _field
	root.add_child(_player)
	_player.global_position = Vector3(0, 0.9, 0)
	await _frames(3)
	await _test_mode_cycle()
	await _test_continuous_dig_fills_pack()
	await _test_raise_with_empty_pack()
	await _test_dig_with_full_pack()
	await _test_level_mode()
	await _test_protected_is_red()
	await _frames(2)
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _hold(seconds: float) -> void:
	_player.tool_held = true
	for i in int(seconds * 60.0):
		await physics_frame
	_player.tool_held = false
	await physics_frame


func _test_mode_cycle() -> void:
	print("mode cycle")
	_check(_player.terrain_tool_mode == TerrainField.ToolMode.DIG, "parte in Scava")
	_player._toggle_terrain_mode()
	_check(_player.terrain_tool_mode == TerrainField.ToolMode.RAISE, "poi Alza")
	_player._toggle_terrain_mode()
	_check(_player.terrain_tool_mode == TerrainField.ToolMode.LEVEL, "poi Livella")
	_player._toggle_terrain_mode()
	_check(_player.terrain_tool_mode == TerrainField.ToolMode.DIG, "senza LampField torna a Scava")
	await _frames(1)


func _test_continuous_dig_fills_pack() -> void:
	print("continuous dig")
	var target := _player.terrain_target
	var before := _player.pack.amount
	await _hold(0.5)
	_check(_field.height_at(target) < -0.3, "mezzo secondo di scavo abbassa il centro (%.2f)" % _field.height_at(target))
	_check(_player.pack.amount > before + 1.0, "lo zaino si riempie con la terra scavata (%.1f -> %.1f)" % [before, _player.pack.amount])
	_check(_player._preview.last_color == BrushPreview.DIG_COLOR, "anello ciano in Scava")


func _test_raise_with_empty_pack() -> void:
	print("raise with empty pack")
	_player.pack.take(999.0)
	_player._toggle_terrain_mode()  # RAISE
	var target := _player.terrain_target
	var h0 := _field.height_at(target)
	var rejected := 0
	var handler := func() -> void: rejected += 1
	_player.terrain_tool_rejected.connect(handler)
	await _hold(0.3)
	_player.terrain_tool_rejected.disconnect(handler)
	_check(absf(_field.height_at(target) - h0) < 0.001, "a zaino vuoto alzare non cambia il terreno")
	_check(_player._preview.last_color == BrushPreview.INVALID_COLOR, "anello rosso a zaino vuoto")
	_check(rejected > 0, "emesso terrain_tool_rejected")
	_player.pack.give(10.0)
	await _hold(0.3)
	_check(_field.height_at(target) > h0 + 0.2, "con terra nello zaino alza")
	_check(_player.pack.amount < 10.0, "alzare consuma lo zaino (%.1f)" % _player.pack.amount)


func _test_dig_with_full_pack() -> void:
	print("dig with full pack")
	_player._toggle_terrain_mode()  # LEVEL
	_player._toggle_terrain_mode()  # DIG
	_player.pack.give(999.0)
	var target := _player.terrain_target
	var h0 := _field.height_at(target)
	await _hold(0.3)
	_check(_field.height_at(target) < h0 - 0.1, "a zaino pieno si scava lo stesso")
	_check(absf(_player.pack.fill_ratio() - 1.0) < 0.001, "lo zaino resta pieno: la terra in eccesso si perde")


func _test_level_mode() -> void:
	print("level mode")
	_player._toggle_terrain_mode()  # RAISE
	_player._toggle_terrain_mode()  # LEVEL
	var target := _player.terrain_target
	_field.sculpt(target + Vector3(1.0, 0, 0), 1.5, 0.8)
	var bump := _field.height_at(target + Vector3(1.0, 0, 0))
	await _hold(0.6)
	_check(_field.height_at(target + Vector3(1.0, 0, 0)) < bump - 0.3, "livella abbassa il cumulo accanto al centro")
	_check(_player._preview.last_color == BrushPreview.LEVEL_COLOR, "anello bianco in Livella")


func _test_protected_is_red() -> void:
	print("protected")
	_player._toggle_terrain_mode()  # DIG
	_field.set_protected(_player.terrain_target, 3.0, true)
	await _frames(2)
	_check(_player._preview.last_color == BrushPreview.INVALID_COLOR, "anello rosso su area protetta")
	var h0 := _field.height_at(_player.terrain_target)
	await _hold(0.2)
	_check(absf(_field.height_at(_player.terrain_target) - h0) < 0.001, "non scava sull'area protetta")
	_field.set_protected(_player.terrain_target, 3.0, false)


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

- [ ] **Step 2: Eseguire e vedere il FAIL** — `terrain_field` non è una proprietà del giocatore.

- [ ] **Step 3: `BrushPreview`** — `godot/scripts/terrain/brush_preview.gd`:

```gdscript
class_name BrushPreview
extends Decal
## Anello di luce proiettato sul rilievo dove agisce il pennello (spec sezione 3).
## La texture e un anello generato in codice; il colore dice il modo o il rifiuto.

const DIG_COLOR := Color(0.2, 0.9, 1.0)
const RAISE_COLOR := Color(1.0, 0.85, 0.2)
const LEVEL_COLOR := Color(1.0, 1.0, 1.0)
const LAMP_COLOR := Color(1.0, 0.95, 0.7)
const INVALID_COLOR := Color(1.0, 0.2, 0.15)

var last_color := Color.TRANSPARENT
static var _ring: ImageTexture


func _ready() -> void:
	if _ring == null:
		var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var d := Vector2(x - 63.5, y - 63.5).length() / 63.5
				var a := clampf(1.0 - absf(d - 0.9) / 0.1, 0.0, 1.0)
				image.set_pixel(x, y, Color(1, 1, 1, a))
		_ring = ImageTexture.create_from_image(image)
	texture_albedo = _ring
	texture_emission = _ring
	emission_energy = 1.5
	size = Vector3(4.8, 6.0, 4.8)
	cull_mask = 1
	visible = false


func show_ring(center: Vector3, radius: float, color: Color) -> void:
	global_position = center
	size = Vector3(radius * 2.0, 6.0, radius * 2.0)
	modulate = color
	last_color = color
	visible = true


func hide_ring() -> void:
	visible = false
	last_color = Color.TRANSPARENT
```

- [ ] **Step 4: Giocatore** — in `player_character.gd`:

  1. Accanto a `@export var terrain_grid: TerrainGrid` aggiungere `@export var terrain_field: TerrainField` (la griglia resta per le scene vecchie: ogni funzione del tool fa prima `if terrain_field != null:` il ramo nuovo, altrimenti il vecchio).
  2. Sostituire `var terrain_tool_mode := TerrainState.ToolMode.DIG` e `TOOL_MODE_NAMES` con:

```gdscript
var terrain_tool_mode: int = TerrainField.ToolMode.DIG
const TOOL_MODE_NAMES: Array[String] = ["Dig", "Raise", "Level", "Lamp"]
## Pennello continuo (D-082): vero finche il tasto del tool e premuto.
var tool_held := false
var pack: SoilPack
var brush_radius_bonus_m := 0.0
var tool_range_bonus_m := 0.0
var _preview: BrushPreview
```

  3. In `_ready()` (dopo la configurazione del movimento) aggiungere:

```gdscript
	if terrain_field != null:
		pack = SoilPack.new(terrain_field.tuning.pack_capacity_m3, terrain_field.tuning.pack_start_m3)
		_preview = BrushPreview.new()
		_preview.name = "BrushPreview"
		add_child(_preview)
		_preview.top_level = true
		floor_max_angle = atan(terrain_field.tuning.max_grade)
```

  4. Dove `_unhandled_input` chiama `_use_terrain_tool()` sul fronte del tasto: con `terrain_field != null` impostare invece `tool_held = event.is_pressed()` per l'azione del tool (controllare il nome dell'azione in `_unhandled_input`, è quella che oggi chiama `_use_terrain_tool`). In `_physics_process`, dopo `_update_terrain_target()`, aggiungere `if terrain_field != null and tool_held: _apply_brush(delta)`.

  5. Nuove funzioni:

```gdscript
func brush_radius() -> float:
	return terrain_field.tuning.brush_radius_m + brush_radius_bonus_m


## Una pennellata per passo fisico finche il tasto e premuto (spec sezione 3).
func _apply_brush(delta: float) -> void:
	if _brush_blocked():
		terrain_tool_rejected.emit()
		return
	var radius := brush_radius()
	var rate := terrain_field.tuning.sculpt_rate_m_s * delta
	match terrain_tool_mode:
		TerrainField.ToolMode.DIG:
			var volume := terrain_field.player_sculpt(terrain_target, radius, -rate, terrain_tool_mode)
			pack.give(-volume)
		TerrainField.ToolMode.RAISE:
			# Chiede allo zaino la terra della pennellata intera (pi r^2 / 3 * rate); se ne ha meno, alza di meno.
			var wanted := PI * radius * radius / 3.0 * rate
			var got := pack.take(wanted)
			if got > 0.0:
				terrain_field.player_sculpt(terrain_target, radius, rate * got / wanted, terrain_tool_mode)
		TerrainField.ToolMode.LEVEL:
			var volume := terrain_field.player_level(terrain_target, radius, terrain_field.tuning.level_rate * delta)
			if volume < 0.0:
				pack.give(-volume)
			else:
				pack.take(volume)
		TerrainField.ToolMode.LAMP:
			tool_held = false
			if lamp_field == null or not lamp_field.place_at(terrain_target):
				terrain_tool_rejected.emit()
	if _animator != null:
		_animator.play_dig()


func _brush_blocked() -> bool:
	if terrain_field.is_protected(terrain_target):
		return true
	match terrain_tool_mode:
		TerrainField.ToolMode.RAISE:
			return pack.is_empty()
		TerrainField.ToolMode.LAMP:
			return lamp_field == null or not lamp_field.can_place(terrain_target) or not lamp_field.can_afford(terrain_target)
	return false


func _preview_color() -> Color:
	if _brush_blocked():
		return BrushPreview.INVALID_COLOR
	match terrain_tool_mode:
		TerrainField.ToolMode.DIG:
			return BrushPreview.DIG_COLOR
		TerrainField.ToolMode.RAISE:
			return BrushPreview.RAISE_COLOR
		TerrainField.ToolMode.LEVEL:
			return BrushPreview.LEVEL_COLOR
	return BrushPreview.LAMP_COLOR
```

  6. `_toggle_terrain_mode()` con il campo: DIG → RAISE → LEVEL → (LAMP se `lamp_field != null`) → DIG; stampa `PROTOTYPE01_TERRAIN_MODE %s` con `TOOL_MODE_NAMES[terrain_tool_mode]` e emette `terrain_mode_changed`. Il ramo griglia resta com'è (DIG → RAISE → LAMP).

  7. `_update_terrain_target()` con il campo:

```gdscript
	if terrain_field != null:
		var forward := -global_basis.z
		forward.y = 0.0
		if forward.is_zero_approx():
			_preview.hide_ring()
			return
		var reach := terrain_field.tuning.tool_range_m + tool_range_bonus_m
		terrain_target = global_position + forward.normalized() * reach
		terrain_target.y = terrain_field.height_at(terrain_target)
		if aim_device == AimDevice.MOUSE and _mouse_ground_point() != null:
			var point: Vector3 = _mouse_ground_point()
			var planar := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
			terrain_target = global_position + planar.limit_length(reach * 2.2)
			terrain_target.y = terrain_field.height_at(terrain_target)
		_preview.show_ring(terrain_target + Vector3(0.0, 1.0, 0.0), brush_radius(), _preview_color())
		return
```

  `_mouse_ground_point()` riusa il raggio del cursore già usato per la mira col mouse (cercare in `player_character.gd` dove viene letta la posizione del mouse per `aim_device == MOUSE`) intersecandolo con il piano `y = height_at(player)`; ritorna `Variant` (Vector3 o null).

  8. `_update_terrain_speed_modifier()` con il campo: `speed_multiplier = speed_bonus`; se `velocity` planare non è zero, `var g := terrain_field.grade_between(global_position, global_position + velocity.normalized() * 0.5)`; `if g > 0.0: speed_multiplier *= lerpf(1.0, 0.5, clampf(g / terrain_field.tuning.max_grade, 0.0, 1.0))`.

- [ ] **Step 5: HUD e audio** — in `run_hud.gd` `set_tool_mode(mode, lamps, max_lamps, cost)`: il confronto `mode != TerrainState.ToolMode.LAMP` diventa `mode != TerrainField.ToolMode.LAMP and mode != TerrainState.ToolMode.LAMP` (i due enum hanno LAMP a indici diversi: 2 e 3; chi chiama passa il proprio). Aggiungere `func set_pack(amount: float, capacity: float) -> void` che scrive `"%d/%d m3" % [roundi(amount), roundi(capacity)]` in una `Label` nuova `PackLabel` accanto ai comandi (stile `HudLabel`). In `run_audio.gd`: `@export var terrain_field: TerrainField`; in `_ready` `if terrain_field != null: terrain_field.player_sculpted.connect(_on_player_sculpted)`; `_on_player_sculpted(_c, _r, volume, mode)` chiama `play(&"terrain_raise" if mode == TerrainField.ToolMode.RAISE else &"terrain_dig")` al più una volta ogni 0,25 s (`_sculpt_sound_left`), con volume `-6 dB + 6 * clampf(absf(volume) / 0.2, 0, 1)`.

- [ ] **Step 6: PASS** — `terrain_brush_tests` verde; `terrain_tool_tests` (griglia, `smoke_test.tscn`) ancora verde; `--check-only` su player, hud, audio, preview.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/player/player_character.gd godot/scripts/terrain/brush_preview.gd godot/scripts/ui/run_hud.gd godot/scripts/audio/run_audio.gd godot/tests/terrain_brush_tests.gd
git commit -m "Tool continuo sul rilievo: pennello tenuto premuto, modi Scava/Alza/Livella/Lampione, zainetto, anello a decal, rallentamento in salita"
```

---

### Task 6: `PathField` sulla pendenza

**Files:**
- Modify: `godot/scripts/navigation/path_field.gd` (export, `is_walkable`, `_scan_terrain_chunk`, `_refresh_blocked`, `solve` vicini, connessioni)
- Modify: `godot/tests/path_field_tests.gd`

**Interfaces:**
- Consumes: `TerrainField.can_step`, `slope_at`, `region_changed`, `half_extent()`.
- Produces: `@export var terrain_field: TerrainField`; `@export var max_grade := 0.8`; `func is_walkable(world: Vector3) -> bool` (pendenza locale sotto la soglia e nessun ostacolo statico); `func is_reachable_from(cell: Vector2i, neighbor: Vector2i) -> bool`; il Dijkstra scarta gli archi che `can_step` rifiuta nel verso di marcia del nemico (dalla cella vicina verso il bersaglio: il campo è calcolato dal bersaglio, quindi l'arco `neighbor → cell` viene testato come salita da `neighbor` a `cell`).

- [ ] **Step 1: Test che fallisce** — in `path_field_tests.gd` (che oggi usa `grid = null`) aggiungere:

```gdscript
func _test_slope_blocks_path() -> void:
	print("slope")
	var field := TerrainField.new()
	field.size_m = 48.0
	field.tuning = TerrainTuning.new()
	root.add_child(field)
	var target := Node3D.new()
	root.add_child(target)
	target.global_position = Vector3(0, 0, 0)
	var path := PathField.new()
	path.target = target
	path.terrain_field = field
	path.half_extent = 24.0
	path.window_cells = 0
	root.add_child(path)
	await _frames(3)
	path.solve()
	var far := Vector3(0, 0, 14)
	_check(path.cost_at(far) < PathField.UNREACHABLE, "in piano la cella lontana e raggiungibile")
	# Un argine alto 1,6 m e lungo 30 m fra il bersaglio e la cella.
	for x in range(-15, 16, 2):
		field.sculpt(Vector3(x, 0, 7), 2.4, 1.6)
	await _frames(1)
	path.solve()
	_check(path.cost_at(far) > path.cost_at(Vector3(0, 0, 4)) + 20.0, "l'argine costringe ad aggirare: costo molto maggiore")
	_check(not path.is_walkable(Vector3(0, 0, 6.2)), "il fianco ripido non e calpestabile")
	_check(path.is_walkable(Vector3(0, 0, 7)), "la cima (piana) e calpestabile")
	# Dolce: un dosso di 0,4 m non blocca.
	for x in range(-15, 16, 2):
		field.level(Vector3(x, 0, 7), 2.6, 0.4, 1.0)
	await _frames(1)
	path.solve()
	_check(path.cost_at(far) < path.cost_at(Vector3(0, 0, 4)) + 15.0, "un dosso dolce si attraversa")
	path.queue_free()
	field.queue_free()
```

- [ ] **Step 2: FAIL** — `terrain_field` non esiste su `PathField`.

- [ ] **Step 3: Implementazione** — in `path_field.gd`:
  - export `@export var terrain_field: TerrainField` e `@export var max_grade := 0.8`.
  - in `_ready`, dopo il blocco `if grid != null:` aggiungere `if terrain_field != null: terrain_field.region_changed.connect(func(_aabb: AABB) -> void: _terrain_dirty = true)`.
  - `is_walkable(world)`: dopo il controllo `_static_at(wc) != 0` sostituire l'ultima riga con `if terrain_field != null: return terrain_field.slope_at(world) <= max_grade` e lasciare poi il ramo griglia.
  - `_refresh_blocked()`: quando `terrain_field != null` una cella è bloccata se `terrain_field.slope_at(_cell_world(i)) > max_grade` (aggiungere `func _cell_world(index: int) -> Vector3` che converte l'indice locale in centro mondo come fa `_scan_terrain_chunk`); il ramo griglia resta.
  - `solve()`: nel ciclo sui vicini, con `terrain_field != null`, prima di accettare l'arco aggiungere `if not terrain_field.can_step(_cell_world(neighbor_index), _cell_world(index), max_grade): continue` (il costo si propaga dal bersaglio: `index` è la cella già risolta, `neighbor` quella da raggiungere; un nemico in `neighbor` deve poter salire verso `index`, quindi il test è `can_step(neighbor → index)`).
  - `is_reachable_from(cell, neighbor)` pubblico con la stessa regola.
  - `_scan_chunk`: la condizione `collider.get_parent() != grid` diventa `(grid == null or collider.get_parent() != grid) and (terrain_field == null or collider != terrain_field.get_node(^"Collision").body)`.

- [ ] **Step 4: PASS, check-only, commit**

```bash
git add godot/scripts/navigation/path_field.gd godot/tests/path_field_tests.gd
git commit -m "PathField: calpestabilita dalla pendenza (can_step vertice per vertice), terreno continuo escluso dagli ostacoli statici"
```

---

### Task 7: Movers: pendenza, rallentamento in salita, rottamatori che scavano

**Files:**
- Modify: `godot/scripts/enemies/enemy.gd` (variabili), `godot/scripts/enemies/enemy_director.gd:233-280, 325-331`, `godot/scripts/enemies/enemy_tuning.gd` (cercare la classe `EnemyTuning`; aggiungere i campi `gnaw_delay_s := 2.0`, `gnaw_depth_m := 0.6`, `gnaw_radius_m := 1.2`, `uphill_min_speed := 0.5`)
- Modify: `godot/scripts/companion/companion.gd` (`floor_max_angle` in `_ready`)
- Create: `godot/tests/terrain_horde_tests.gd`

**Interfaces:**
- Consumes: `TerrainField.grade_between/sculpt/delta_at`, `TerrainCollision.body`.
- Produces su `Enemy`: `var max_grade := 0.8` (saltatori 1,2 al posto di `ignores_lowered`, che resta per la griglia), `var gnaw_left := 0.0`, `var stuck_seconds := 0.0`, `var is_gnawing := false`; su `EnemyDirector`: `@export var terrain_field: TerrainField`, `var gnaws := 0`.

- [ ] **Step 1: Suite che fallisce** — `godot/tests/terrain_horde_tests.gd` costruisce TerrainField 64 m + EnemyDirector + PathField + un Player (come `terrain_brush_tests`) e verifica:

```gdscript
func _test_uphill_slows() -> void:
	print("uphill")
	_field.sculpt(Vector3(0, 0, -8), 4.0, 2.0)
	var enemy := _director.spawn_at(Vector3(0, 0.6, -14), &"scavenger")
	await _frames(40)
	var flat := _director.spawn_at(Vector3(12, 0.6, -14), &"scavenger")
	await _frames(40)
	var climbed := (enemy.global_position - Vector3(0, 0, -14)).length()
	var walked := (flat.global_position - Vector3(12, 0, -14)).length()
	_check(climbed < walked * 0.85, "in salita il rottamatore avanza meno (%.1f < %.1f)" % [climbed, walked])


func _test_enemy_gnaws_out_of_pit() -> void:
	print("gnaw")
	# Conca con pareti ripide attorno al nemico.
	var at := Vector3(-15, 0, 10)
	_field.sculpt(at, 2.0, -1.8)
	var enemy := _director.spawn_at(at, &"scavenger")
	enemy.global_position = Vector3(at.x, _field.height_at(at) + 0.6, at.z)
	var h_wall := _field.height_at(at + Vector3(0, 0, 1.6))
	await _frames(60 * 3)
	_check(_director.gnaws > 0, "dopo 2 s fermo il nemico rosicchia (%d)" % _director.gnaws)
	_check(_field.height_at(at + Vector3(0, 0, 1.6)) < h_wall - 0.3 or enemy.global_position.distance_to(at) > 3.0, "la parete si abbassa o il nemico e uscito")
```

(`spawn_at` esiste già? verificare in `enemy_director.gd`; se si chiama diversamente usare il nome reale, altrimenti aggiungere `func spawn_at(world: Vector3, kind: StringName) -> Enemy` che crea il nemico con `_spawn_enemy` e lo posiziona.)

- [ ] **Step 2: FAIL** — `gnaws` non esiste.

- [ ] **Step 3: Implementazione** — in `enemy_director.gd`, nel ciclo per nemico, sostituire il blocco della penalità Lowered con:

```gdscript
		if terrain_field != null:
			var ahead := pos + direction.normalized() * 0.6 if not direction.is_zero_approx() else pos
			var g := terrain_field.grade_between(pos, ahead)
			if g > 0.0:
				speed *= lerpf(1.0, tuning.uphill_min_speed, clampf(g / enemy.max_grade, 0.0, 1.0))
		elif grid != null and not enemy.ignores_lowered and grid.cell_state_at(pos) == TerrainState.CellState.LOWERED:
			speed *= 1.0 - penalty
```

e dopo `enemy.move_and_slide()`:

```gdscript
		if terrain_field != null:
			_tick_gnaw(enemy, direction, delta)
```

con:

```gdscript
## Fermo contro il terreno da piu di gnaw_delay_s: rosicchia l'argine davanti a se.
func _tick_gnaw(enemy: Enemy, direction: Vector3, delta: float) -> void:
	var moved := Vector3(enemy.velocity.x, 0.0, enemy.velocity.z).length() * delta
	var against_terrain := false
	for i in enemy.get_slide_collision_count():
		if enemy.get_slide_collision(i).get_collider() == terrain_field.get_node(^"Collision").body:
			against_terrain = true
			break
	if against_terrain and moved < 0.2 * delta * 60.0 / 60.0 and not direction.is_zero_approx():
		enemy.stuck_seconds += delta
	else:
		enemy.stuck_seconds = 0.0
		enemy.is_gnawing = false
	if enemy.stuck_seconds < tuning.gnaw_delay_s:
		return
	enemy.is_gnawing = true
	enemy.gnaw_left -= delta
	if enemy.gnaw_left > 0.0:
		return
	enemy.gnaw_left = 1.0
	var point := enemy.global_position + direction.normalized() * 1.0
	terrain_field.sculpt(point, tuning.gnaw_radius_m, -tuning.gnaw_depth_m)
	gnaws += 1
	print("PROTOTYPE01_ENEMY_GNAW total=%d" % gnaws)
```

Spina del muro (`_apply_contacts`): con `terrain_field != null` il collider da riconoscere è `terrain_field.get_node(^"Collision").body` e la spina vale solo se `terrain_field.delta_at(enemy.global_position) > 0.3`.

In `enemy.gd`: `var max_grade := 0.8`, `var stuck_seconds := 0.0`, `var gnaw_left := 0.0`, `var is_gnawing := false`; in `setup()` aggiungere `floor_max_angle = atan(max_grade)`; dove i saltatori ricevono `ignores_lowered = true` (director riga 135) aggiungere `max_grade = 1.2` e `floor_max_angle = atan(1.2)`. Il Demolitore (`demolisher.gd`, nel suo `_ready`) e il compagno impostano `floor_max_angle = atan(0.8)`.

- [ ] **Step 4: PASS, check-only, commit**

```bash
git add godot/scripts/enemies/enemy.gd godot/scripts/enemies/enemy_director.gd godot/scripts/enemies/enemy_tuning.gd godot/scripts/companion/companion.gd godot/scripts/enemies/demolisher.gd godot/tests/terrain_horde_tests.gd
git commit -m "Orda sul rilievo: pendenza massima per nemico, rallentamento in salita, rottamatori che rosicchiano gli argini, spina solo sugli argini"
```

---

### Task 8: Quartiere a pennellate e livello 1 sul campo

**Files:**
- Modify: `godot/scripts/arena/ruins_district.gd:102-105, 244-384` (feature → pennellate), `cover_height()`
- Modify: `godot/scripts/run/arena_run.gd:54, 138, 151, 166, 205-231, 416-426, 554-575`
- Modify: `godot/scenes/main/arena_run.tscn` (nodo `TerrainGrid` → `TerrainField`, tutti i `grid = NodePath("../TerrainGrid")` → `terrain_field = NodePath("../TerrainField")`)
- Modify: `godot/tests/district_tests.gd`, `godot/tests/arena_run_tests.gd`
- Modify: `tools/godot/Invoke-GodotChecks.ps1` (marker `PROTOTYPE01_TERRAIN_GRID_READY` → accettare anche `PROTOTYPE01_TERRAIN_FIELD_READY`; lo smoke test resta sulla griglia)

**Interfaces:**
- Produces su `RuinsDistrict`: `var terrain_strokes: Array[Dictionary]` con voci `{kind: StringName, center: Vector2 (XZ), radius: float, height: float, tint: Color, scrap: int, marker: Vector2, gates: Array[int], points: Array[Vector2]}` (`points`: i centri delle pennellate che formano l'anello o la linea; `height` positiva = argine/cumulo, negativa = solco); `func apply_base_relief(field: TerrainField) -> void` (rumore + macerie + solchi delle strade, poi `commit_base()`); `func apply_strokes(field: TerrainField) -> void`; `terrain_features` resta (ferrovia).
- Produces su `ArenaRun`: `@export var terrain_field: TerrainField`; `_check_scale` confronta `terrain_field.half_extent()` con `district.half_extents()`; `_build_terrain_layout` chiama `apply_base_relief` + `apply_strokes` (o `load_base` se esiste `res://levels/district/base.bin`, vedi Step 3) e stampa `PROTOTYPE01_TERRAIN_LAYOUT_READY strokes=%d`.

- [ ] **Step 1: Test che fallisce** — in `district_tests.gd` sostituire le verifiche sulle celle (`active_collision_count`, `presented_cell_count`, feature applicate) con:

```gdscript
	var field: TerrainField = _scene.get_node(^"TerrainField")
	_check(field.resolution == 409, "quartiere 204 m -> 409 vertici per lato")
	_check(district.terrain_strokes.size() >= 10, "il quartiere produce pennellate (%d)" % district.terrain_strokes.size())
	var start: Dictionary = district.terrain_strokes[0]
	_check(start.kind == &"start" and start.points.size() > 8, "cortile di partenza come anello di pennellate")
	var ring_point: Vector2 = start.points[0]
	_check(field.height_at(Vector3(ring_point.x, 0, ring_point.y)) > 1.0, "l'argine del cortile e alto piu di 1 m")
	_check(field.delta_at(Vector3(ring_point.x, 0, ring_point.y)) > 0.8, "l'argine sporge dalla base (il Demolitore lo vede)")
	_check(absf(field.height_at(Vector3.ZERO)) < 0.3, "il centro del cortile e quasi piano")
	var deposits := 0
	for stroke: Dictionary in district.terrain_strokes:
		if stroke.kind == &"deposit":
			deposits += 1
			_check(stroke.scrap >= 6 and field.height_at(Vector3(stroke.center.x, 0, stroke.center.y)) > 1.0, "deposito = cumulo con vena")
	_check(deposits >= 6, "almeno sei depositi (%d)" % deposits)
	var bumpy := 0
	for i in 40:
		if absf(field.base_height_at(Vector3(-90 + i * 4.5, 0, 60))) > 0.15:
			bumpy += 1
	_check(bumpy > 10, "il rilievo di base e mosso (%d/40 campioni oltre 15 cm)" % bumpy)
```

In `arena_run_tests.gd` le prove "mura del cortile", "varchi", "cortile sigillato" e "muro che blocca il tiro" usano `field.sculpt(point, 2.4, 1.6)` per chiudere un varco e `field.level(point, 3.0, field.base_height_at(point), 1.0)` per aprirlo; la prova "Lowered rallenta" diventa "in salita rallenta" (misura come in Task 7).

- [ ] **Step 2: FAIL** — `TerrainField` non è nella scena.

- [ ] **Step 3: Implementazione**
  - `ruins_district.gd`: accanto a ogni `_add_feature(...)` chiamare `_add_stroke(kind, center, radius_m, height, tint, scrap, gates, points)` dove `points` sono, per gli anelli, `radius * CELL` di raggio con un punto ogni 1,6 m e un buco di 2 pennellate (3,2 m) al centro di ogni lato in `gates` (stessa logica di `_ring_offsets`, in metri), per i depositi un solo punto (raggio `size * CELL * 0.5 + 1.0`, height 1,5, scrap `6 + 2 * (size - 2)`), per le trincee una linea di punti ogni 1,2 m (height −0,8, raggio 1,6). Tinte: cumuli `Color(0.5, 0.28, 0.12)`.
  - `apply_base_relief(field)`:

```gdscript
func apply_base_relief(field: TerrainField) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.025
	var half := field.half_extent()
	var r := field.resolution
	for iz in r:
		for ix in r:
			var x := ix * TerrainField.SPACING - half
			var z := iz * TerrainField.SPACING - half
			var calm := 1.0 - 0.8 * (1.0 - smoothstep(plaza_radius_m * 0.6, plaza_radius_m * 1.3, Vector2(x, z).length()))
			var h := noise.get_noise_2d(x, z) * 1.2 + noise.get_noise_2d(x * 2.8, z * 2.8) * 0.5 + noise.get_noise_2d(x * 6.5, z * 6.5) * 0.25
			field._heights[iz * r + ix] = h * calm
	for block in _block_rects():  # Rect2 XZ delle rovine, gia noti a _build_blocks
		for k in 6:
			var angle := TAU * k / 6.0
			var p := block.get_center() + Vector2(cos(angle), sin(angle)) * (block.size.length() * 0.5 + 1.5)
			field.sculpt(Vector3(p.x, 0, p.y), 3.0, randf_range(0.4, 0.8))
	for road in _road_segments():  # coppie di Vector2 delle strade dipinte
		var length := road[0].distance_to(road[1])
		for t in int(length / 1.5):
			var p: Vector2 = road[0].lerp(road[1], t * 1.5 / length)
			field.sculpt(Vector3(p.x, 0, p.y), 2.0, -0.3)
	field.commit_base()
	field._mirror_all()
```

(`_block_rects()` e `_road_segments()` espongono dati che `_build_blocks` e la pittura della strada già calcolano; se oggi sono locali, salvarli in due array membro.)
  - `apply_strokes(field)`: per ogni stroke, per ogni punto `field.sculpt(Vector3(p.x, 0, p.y), stroke.radius, stroke.height)`; se `tint.a > 0` `field.tint(...)`; registra in `ScrapField` le vene (Task 9: `scrap_field.add_vein(center, radius, scrap, base_height)`), per ora stampa.
  - `arena_run.gd`: `_build_terrain_layout()` con `terrain_field != null`: `if not terrain_field.load_base("res://levels/district/base.bin"): district.apply_base_relief(terrain_field)`; poi `district.apply_strokes(terrain_field)`; `_initial_heights = RunMap.snapshot_heights(terrain_field)` (Task 13; fino ad allora `PackedFloat32Array()`); aree protette: per ogni rovina/torre/auto `terrain_field.set_protected(center, half_diagonal + tuning.protected_radius_m, true)`, cortile di partenza `set_protected(Vector3.ZERO, start_protected_radius_m, true)` e un timer di 10 s che lo toglie. `_refresh_marker_targets`: per gli stroke `deposit` finché `scrap_field.vein_scrap_left(center) > 0`, per i cortili finché `terrain_field.highest_bump(center, radius + 2, 0.8) != null`.
  - `arena_run.tscn`: il nodo diventa `[node name="TerrainField" type="Node3D" parent="."] script = ExtResource("terrain_field") size_m = 204.0 tuning = ExtResource("6_terrain_tuning")`; aggiornare tutti i `node_paths` (`grid` → `terrain_field`) di Player, PathField, ScrapField, Companion, LampField, EnemyDirector, QuakeEvent, ExtractionPad, Run, RunAudio, FlowPreview. **Dirlo al proprietario prima di toccare la scena.**
  - Generare `res://levels/district/base.bin` con un tool `tests/tools/bake_terrain_base.gd` (apre `arena_run.tscn`, chiama `apply_base_relief`, `save_base`) e versionarlo in LFS (`*.bin` in `.gitattributes` se non c'è).

- [ ] **Step 4: PASS** — `district_tests`, `arena_run_tests`, `terrain_field_tests`; gate con il marker aggiornato.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/arena/ruins_district.gd godot/scripts/run/arena_run.gd godot/scenes/main/arena_run.tscn godot/tests/district_tests.gd godot/tests/arena_run_tests.gd godot/tests/tools/bake_terrain_base.gd godot/levels/district/base.bin tools/godot/Invoke-GodotChecks.ps1 .gitattributes
git commit -m "Livello 1 sul rilievo continuo: TerrainField nella scena, rilievo di base mosso, cortili, depositi e trincee come pennellate, aree protette, marker"
```

---

### Task 9: Vene di rottami e rottami sul rilievo (`ScrapField`)

**Files:**
- Modify: `godot/scripts/companion/scrap_field.gd` (export, `_ready`, `spawn_on_ground`, nuovi `add_vein`, `vein_scrap_left`, `_on_player_sculpted`, `_on_region_changed`; `spawn_on_cell`, `count_on_cell`, `_on_command_applied`, `_on_cell_changed`, `_free_neighbor` restano per la griglia)
- Modify: `godot/scripts/arena/ruins_district.gd` (`apply_strokes` registra le vene)
- Modify: `godot/tests/economy_tests.gd`

**Interfaces:**
- Consumes: `TerrainField.player_sculpted`, `region_changed`, `height_at`, `base_height_at`.
- Produces: `@export var terrain_field: TerrainField`; `const SCRAP_PER_M3 := 0.8`; `func add_vein(center: Vector3, radius: float, scrap: int, base_height: float) -> void`; `func vein_scrap_left(center: Vector3) -> int` (0 se nessuna vena entro 0,5 m); `func veins() -> Array[Dictionary]` (`{center, radius, scrap_left, base_height, dug_m3}`); `func spawn_on_ground(world: Vector3) -> void` (appoggia a `height_at`); `func lowest_point_near(world: Vector3, radius: float) -> Vector3`; `func extract_from_veins(center: Vector3, radius: float, volume: float) -> int` (usato anche dal Demolitore, Task 10: scala il volume asportato sulle vene toccate e fa nascere i rottami).

- [ ] **Step 1: Test che fallisce** — in `economy_tests.gd` sostituire il test "rottami solo dalle celle Raised" con (scena: TerrainField 64 m + ScrapField collegato):

```gdscript
func _test_scrap_only_from_veins() -> void:
	print("veins")
	_scrap.add_vein(Vector3(10, 0, 10), 3.0, 6, 0.0)
	_field.sculpt(Vector3(10, 0, 10), 3.0, 1.5)
	_check(_scrap.vein_scrap_left(Vector3(10, 0, 10)) == 6, "la vena parte con sei rottami")
	var before := _scrap.count()
	_field.player_sculpt(Vector3(10, 0, 10), 2.4, -0.3, TerrainField.ToolMode.DIG)
	_check(_scrap.count() == before, "scavare la parte sopra la base del cumulo non da rottami")
	for i in 12:
		_field.player_sculpt(Vector3(10, 0, 10), 2.4, -0.3, TerrainField.ToolMode.DIG)
	_check(_scrap.count() > before, "sotto la base della vena escono rottami (%d)" % (_scrap.count() - before))
	_check(_scrap.count() - before <= 6, "mai piu della vena")
	for i in 30:
		_field.player_sculpt(Vector3(10, 0, 10), 2.4, -0.3, TerrainField.ToolMode.DIG)
	_check(_scrap.vein_scrap_left(Vector3(10, 0, 10)) == 0 and _scrap.count() - before == 6, "la vena si esaurisce a sei")
	var exhausted := _scrap.count()
	_field.player_sculpt(Vector3(10, 0, 10), 2.4, -0.3, TerrainField.ToolMode.DIG)
	_check(_scrap.count() == exhausted, "vena esaurita: niente rottami")


func _test_vein_exhausted_gives_nothing() -> void:
	print("bare ground")
	var before := _scrap.count()
	for i in 20:
		_field.player_sculpt(Vector3(-20, 0, -20), 2.4, -0.3, TerrainField.ToolMode.DIG)
	_check(_scrap.count() == before, "il suolo nudo non da rottami (D-056)")


func _test_scrap_rests_and_rolls() -> void:
	print("rest and roll")
	_field.sculpt(Vector3(-10, 0, 10), 3.0, 0.8)
	_scrap.spawn_on_ground(Vector3(-10, 0, 10))
	var scrap_y: float = _scrap.nearest(Vector3(-10, 0, 10), 0.5).y
	_check(absf(scrap_y - (_field.height_at(Vector3(-10, 0, 10)) + ScrapField.SCRAP_SIZE)) < 0.05, "il rottame poggia sulla quota del rilievo")
	_field.sculpt(Vector3(-10, 0, 10), 2.4, 1.0)
	await _frames(2)
	var moved: Variant = _scrap.nearest(Vector3(-10, 0, 10), 4.0)
	_check(moved != null and Vector2((moved as Vector3).x + 10.0, (moved as Vector3).z - 10.0).length() > 1.0, "alzare sotto il rottame lo fa rotolare piu in basso")
```

- [ ] **Step 2: FAIL** — `add_vein` non esiste.

- [ ] **Step 3: Implementazione** — in `scrap_field.gd`:

```gdscript
@export var terrain_field: TerrainField
const SCRAP_PER_M3 := 0.8
## Vene di rottami (spec 5.1): { center, radius, scrap_left, base_height, dug_m3 }.
var _veins: Array[Dictionary] = []
var _rest_heights: Dictionary[MeshInstance3D, float] = {}
```

in `_ready()`:

```gdscript
	if terrain_field != null:
		terrain_field.player_sculpted.connect(_on_player_sculpted)
		terrain_field.region_changed.connect(_on_region_changed)
```

nuove funzioni:

```gdscript
func add_vein(center: Vector3, radius: float, scrap: int, base_height: float) -> void:
	_veins.append({ center = center, radius = radius, scrap_left = scrap, base_height = base_height, dug_m3 = 0.0 })


func veins() -> Array[Dictionary]:
	return _veins


func vein_scrap_left(center: Vector3) -> int:
	for vein in _veins:
		if _planar_distance(vein.center, center) <= 0.5:
			return vein.scrap_left
	return 0


## Volume (positivo) asportato dentro il pennello: la parte sotto la quota di base
## della vena scala `dug_m3`; ogni SCRAP_PER_M3 esce un rottame nel punto piu basso.
func extract_from_veins(center: Vector3, radius: float, volume: float) -> int:
	var spawned := 0
	for vein in _veins:
		if vein.scrap_left <= 0 or _planar_distance(vein.center, center) > vein.radius + radius:
			continue
		if terrain_field.height_at(center) > vein.base_height + 0.05:
			continue
		vein.dug_m3 += volume
		while vein.dug_m3 >= SCRAP_PER_M3 and vein.scrap_left > 0:
			vein.dug_m3 -= SCRAP_PER_M3
			vein.scrap_left -= 1
			spawn_on_ground(lowest_point_near(center, radius))
			spawned += 1
			print("PROTOTYPE01_VEIN_SCRAP left=%d" % vein.scrap_left)
		if vein.scrap_left == 0 and terrain_field != null:
			terrain_field.tint(vein.center, vein.radius, Color(0, 0, 0, 0), 0.0)
	return spawned


func lowest_point_near(world: Vector3, radius: float) -> Vector3:
	var best := world
	var best_h := INF
	for k in 12:
		var angle := TAU * k / 12.0
		for r in [radius * 0.5, radius]:
			var p := world + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
			var h := terrain_field.height_at(p)
			if h < best_h:
				best_h = h
				best = p
	return best


func _on_player_sculpted(center: Vector3, radius: float, volume: float, mode: int) -> void:
	if mode != TerrainField.ToolMode.DIG or volume >= 0.0:
		return
	extract_from_veins(center, radius, -volume)


## I rottami nell'area cambiata si riappoggiano; se il suolo e salito di oltre 0,5 m
## rispetto alla posa, rotolano al punto piu basso vicino.
func _on_region_changed(aabb: AABB) -> void:
	for scrap in _scraps:
		var p := scrap.global_position
		if not aabb.has_point(Vector3(p.x, aabb.position.y + 0.1, p.z)):
			continue
		var rest: float = _rest_heights.get(scrap, p.y - SCRAP_SIZE)
		var ground := terrain_field.height_at(p)
		if ground - rest > 0.5:
			var to := lowest_point_near(p, 2.4)
			scrap.global_position = Vector3(to.x, terrain_field.height_at(to) + SCRAP_SIZE, to.z)
			print("PROTOTYPE01_SCRAP_ROLLED")
		else:
			scrap.global_position = Vector3(p.x, ground + SCRAP_SIZE, p.z)
		_rest_heights[scrap] = scrap.global_position.y - SCRAP_SIZE
		scrap.set_meta(&"base_y", scrap.position.y)
```

`spawn_on_ground(world)` con `terrain_field != null`: `spawn(Vector3(world.x, terrain_field.height_at(world) + SCRAP_SIZE, world.z))` e registra `_rest_heights[scrap]`; `_remove_at` cancella la voce. In `ruins_district.apply_strokes`, per ogni stroke `deposit`: `scrap_field.add_vein(Vector3(c.x, 0, c.y), stroke.radius, stroke.scrap, field.base_height_at(...))` (il district riceve `scrap_field` come parametro: `apply_strokes(field, scrap_field)`; `ArenaRun` lo passa).

- [ ] **Step 4: PASS, check-only, commit**

```bash
git add godot/scripts/companion/scrap_field.gd godot/scripts/arena/ruins_district.gd godot/scripts/run/arena_run.gd godot/tests/economy_tests.gd
git commit -m "Vene di rottami sepolte nei cumuli: un rottame ogni 0,8 m3 sotto la base, rottami appoggiati al rilievo che rotolano"
```

---

### Task 10: Demolitore sul rilievo (spiana, cantiere, barricate a cumulo)

**Files:**
- Modify: `godot/scripts/enemies/demolisher.gd:87, 177-178, 240-330, 470-640`
- Modify: `godot/tests/boss_tests.gd`

**Interfaces:**
- Consumes: `TerrainField.highest_bump/level/sculpt/tint/delta_at/is_flat/region_changed`, `ScrapField.extract_from_veins/vein_scrap_left`, `EnemyDirector.enemies_near`.
- Produces: `var terrain_field: TerrainField` (impostato da `ArenaRun` accanto a `grid`); `var wall_point := Vector3.INF` (nessun muro); `var demolish_point := Vector3.INF`; `var barricade_points: Array[Vector3]`; `const BARRICADE_HEIGHT := 1.5`, `const BARRICADE_RADIUS := 2.4`, `const HAMMER_RADIUS := 3.6`, `const HAMMER_RATE := 3.0`; i segnali `wall_demolished`, `barricade_built`, `scrap_delivered` passano un `Vector3` (il tipo del parametro cambia da `Vector2i` a `Vector3`; aggiornare i connettori in `arena_run.gd` e `run_audio.gd`). `barricades: Dictionary` resta per la griglia; `build_run_map` userà `barricade_points`.

- [ ] **Step 1: Test che fallisce** — in `boss_tests.gd` (scena `arena_run`, quindi già sul campo dal Task 8):

```gdscript
func _test_boss_levels_player_mound() -> void:
	print("boss levels mound")
	var at := _player.global_position + Vector3(6, 0, 0)
	_field.sculpt(at, 2.4, 1.6)
	_boss.global_position = at + Vector3(-5, 0.9, 0)
	await _frames(60 * 6)
	_check(_field.delta_at(at) < 0.6, "il Demolitore spiana il cumulo del giocatore (delta %.2f)" % _field.delta_at(at))
	_check(_boss.walls_demolished >= 1, "contato come muro demolito")


func _test_boss_levels_player_mound_without_scrap() -> void:
	print("no scrap from plain mound")
	var before := _scrap.count()
	var at := _player.global_position + Vector3(-6, 0, 0)
	_field.sculpt(at, 2.4, 1.6)
	_boss.global_position = at + Vector3(5, 0.9, 0)
	await _frames(60 * 6)
	_check(_scrap.count() == before, "un argine senza vena non da rottami al boss")


func _test_boss_demolishes_deposit_and_scrap_comes_out() -> void:
	print("deposit")
	var deposit: Dictionary = _first_stroke(&"deposit")
	var at := Vector3(deposit.center.x, 0, deposit.center.y)
	var before := _scrap.count()
	_boss.global_position = at + Vector3(5, 0.9, 0)
	await _frames(60 * 10)
	_check(_scrap.count() > before, "spianando un cumulo con vena escono rottami")


func _test_barricade_is_mound() -> void:
	print("barricade")
	_boss._site_scrap = _boss.walls_per_barricade
	_boss._try_build_at_site()
	_check(_boss.barricade_points.size() == 1, "una barricata costruita")
	var p: Vector3 = _boss.barricade_points[0]
	_check(_field.delta_at(p) > 1.0, "la barricata e un cumulo di oltre 1 m")
	_check(_field.is_flat(p, 2.4, 0.35) == false, "il cantiere non e piu piano")
	_field.level(p, 3.0, _field.base_height_at(p), 1.0)
	await _frames(2)
	_check(_boss.barricade_points.is_empty(), "scavata la barricata, il boss la dimentica")
```

- [ ] **Step 2: FAIL** — `barricade_points` non esiste.

- [ ] **Step 3: Implementazione** — in `demolisher.gd`, ramo `terrain_field != null` di ciascuna funzione (il ramo griglia resta):
  - `_nearest_wall_point() -> Vector3`: `var found: Variant = terrain_field.highest_bump(global_position, wall_attraction_radius, 0.8)`; scarta se entro 1,5 m da una `barricade_points` o da `_ignored_points` (array di Vector3 con tempo); altrimenti considera anche le vene: `for vein in scrap_field.veins(): if vein.scrap_left > 0 and planar distance <= wall_attraction_radius: candidate`; ritorna il più vicino o `Vector3.INF`.
  - movimento: `has_wall = wall_point != Vector3.INF`; `direction` verso `wall_point`; demolizione quando `_planar(wall_point - global_position).length() <= BODY_RADIUS + 1.2` **oppure** una collisione con `terrain_field.get_node(^"Collision").body` dove `terrain_field.delta_at(collision.get_position()) > 0.8` → `_start_demolition_at(collision.get_position())`.
  - `_tick_demolition` con punto: ogni passo, dopo il telegraph del martello, `var removed := -terrain_field.level(demolish_point, HAMMER_RADIUS, terrain_field.base_height_at(demolish_point), HAMMER_RATE * delta)`; se `removed > 0`: ridistribuisci la terra in un anello esterno `terrain_field.sculpt(demolish_point + ring_offset, 1.8, removed / (6 * PI * 1.8 * 1.8 / 3.0))` per sei punti attorno a raggio `HAMMER_RADIUS + 1.5` (conservazione), e `scrap_field.extract_from_veins(demolish_point, HAMMER_RADIUS, removed)`; finito quando `terrain_field.delta_at(demolish_point) < 0.3` → `walls_demolished += 1`, `wall_demolished.emit(demolish_point)`, `demolish_point = Vector3.INF`.
  - cantiere: `_pick_barricade_point() -> Vector3`: come `_pick_barricade_cell` ma in metri (`step = BARRICADE_RADIUS`), accetta un punto se `terrain_field.is_flat(point, 2.4, 0.35)` e `_point_is_free(point)` (distanze come `_cell_is_free`, `scrap_field.positions_near(point, 1.2).is_empty()`, `not terrain_field.is_protected(point)`); `_site_point`; marker a `terrain_field.height_at(point) + 0.05`.
  - `_raise_barricade_at(point)`: `barricade_points.append(point)`; `terrain_field.sculpt(point, BARRICADE_RADIUS, BARRICADE_HEIGHT)`; `terrain_field.tint(point, BARRICADE_RADIUS, BARRICADE_COLOR, 1.0)`; `barricade_built.emit(point)`.
  - `_on_region_changed(aabb)` (connesso in `_ready` se `terrain_field != null`): per ogni `barricade_points` dentro l'AABB con `terrain_field.delta_at(p) < 0.5` → rimuovi, `terrain_field.tint(p, BARRICADE_RADIUS, Color(0,0,0,0), 0.0)`, log `PROTOTYPE01_BOSS_BARRICADE_DOWN`; se `_site_point` è dentro l'AABB e non è più piano → `_clear_site(false)`.
  - `floor_max_angle = atan(0.8)` in `_ready`.

- [ ] **Step 4: PASS** — `boss_tests` verde (le prove sulle celle vengono riscritte sui punti: "disseppellimento" → "rottami rotolano", "trincea rallenta" → "salita rallenta").

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/enemies/demolisher.gd godot/scripts/run/arena_run.gd godot/scripts/audio/run_audio.gd godot/tests/boss_tests.gd
git commit -m "Demolitore sul rilievo: cerca la cima piu alta, la spiana conservando la terra, rottami dalle vene, cantiere piano e barricate a cumulo"
```

---

### Task 11: Lampioni sul rilievo (`LampField`)

**Files:**
- Modify: `godot/scripts/terrain/lamp_field.gd`
- Modify: `godot/tests/lamp_tests.gd`

**Interfaces:**
- Consumes: `TerrainField.is_flat/height_at/is_protected/region_changed`.
- Produces: `@export var terrain_field: TerrainField`; `func can_place(point: Vector3) -> bool` (sul campo: `is_flat(point, 1.0, 0.3)`, nessun lampione entro 2 m, non protetto, sotto `max_count`); `func place_at(world: Vector3) -> bool`; `func positions() -> Array[Vector3]`; segnali `lamp_placed(point: Vector3)`, `lamp_lost(point: Vector3, reason: StringName)` (tipo cambiato; aggiornare `run_hud`, `arena_run`, `run_audio`, `simulate_runs`); `cells()` resta per la griglia. Internamente `_lamps` diventa `Array[Dictionary]` `{position, node, light, rest_height}`.

- [ ] **Step 1: Test che fallisce** — in `lamp_tests.gd`:

```gdscript
func _test_lamp_rules_on_relief() -> void:
	print("lamp rules")
	var flat := _player.global_position + Vector3(4, 0, 0)
	_check(_lamps.can_place(flat), "si pianta su terreno piano")
	_field.sculpt(flat, 1.5, 0.6)
	_check(not _lamps.can_place(flat), "non si pianta su un fianco (dislivello > 0,3 m entro 1 m)")
	_field.level(flat, 2.0, _field.base_height_at(flat), 1.0)
	_check(_lamps.place_at(flat), "piantato")
	_check(not _lamps.can_place(flat + Vector3(1.5, 0, 0)), "un altro entro 2 m e rifiutato")
	_check(_lamps.can_place(flat + Vector3(3.0, 0, 0)), "a 3 m si")


func _test_lamp_falls_when_ground_moves() -> void:
	print("lamp falls")
	var p: Vector3 = _lamps.positions()[0]
	var lost: Array = []
	_lamps.lamp_lost.connect(func(point: Vector3, reason: StringName) -> void: lost.append(reason))
	_field.sculpt(p + Vector3(2.0, 0, 0), 2.4, 0.2)
	await _frames(1)
	_check(lost.is_empty() and _lamps.count() == 1, "uno spostamento sotto 0,4 m non lo abbatte")
	_field.sculpt(p, 2.4, 0.8)
	await _frames(1)
	_check(lost.size() == 1 and lost[0] == &"terrain", "oltre 0,4 m il lampione cade")
```

- [ ] **Step 2: FAIL** — `can_place(Vector3)` non accetta un punto.

- [ ] **Step 3: Implementazione** — `can_place(point: Vector3)`, `place_at`, `_build_lamp(point)` (palo a `height_at(point)`), `knock_down_near` invariata nella logica (itera `_lamps`), `_on_region_changed(aabb)`: per ogni lampione nell'AABB, `if absf(terrain_field.height_at(position) - rest_height) > 0.4: _remove(index, &"terrain")`. Il giocatore (Task 5) chiama `lamp_field.can_place(terrain_target)` e `place_at(terrain_target)`.

- [ ] **Step 4: PASS, check-only, commit**

```bash
git add godot/scripts/terrain/lamp_field.gd godot/scripts/player/player_character.gd godot/scripts/ui/run_hud.gd godot/scripts/run/arena_run.gd godot/tests/lamp_tests.gd
git commit -m "Lampioni sul rilievo: posa su terreno piano, distanza minima, caduta quando il suolo si muove di oltre 40 cm"
```

---

### Task 12: Terremoto e piazzola sul rilievo

**Files:**
- Modify: `godot/scripts/run/quake_event.gd:30, 43-58, 125-137, 179-213, 225-230`
- Modify: `godot/scripts/run/extraction_pad.gd`
- Modify: `godot/tests/quake_tests.gd`, `godot/tests/extraction_tests.gd`

**Interfaces:**
- Consumes: `TerrainField.sculpt/is_flat/is_protected/height_at`, `LampField.knock_down_near`, `EnemyDirector.enemies`.
- Produces su `QuakeEvent`: `@export var terrain_field: TerrainField`; `var fault_points: Array[Vector3]`; `var volume_moved := 0.0`; `const CREST_HEIGHT := 1.2`, `const FURROW_DEPTH := 0.6`, `const FAULT_STEP := 2.4`. Su `ExtractionPad`: `@export var terrain_field: TerrainField`; `var radius_m := 3.0`; `var tolerance_m := 0.35`; `func is_flat_at(point: Vector3) -> bool`; marker: anello (`BrushPreview`-like decal) di raggio 3 m.

- [ ] **Step 1: Test che fallisce** — in `quake_tests.gd`:

```gdscript
func _test_quake_sculpts_crest_and_furrow() -> void:
	print("crest and furrow")
	_quake.rng.seed = 5
	_quake.first_seconds = 0.5
	await _frames(60 * 8)
	_check(_quake.quakes == 1 and _quake.fault_points.size() == 18, "un terremoto con 18 pennellate")
	var crest: Vector3 = _quake.fault_points[9]
	_check(_field.delta_at(crest) > 0.8, "cresta alzata sulla faglia (%.2f)" % _field.delta_at(crest))
	_check(_quake.volume_moved > 20.0, "volume spostato contato")
```

In `extraction_tests.gd` la prova "pad broken and held": un `field.sculpt(player_pos + Vector3(1.5, 0, 0), 2.0, 0.6)` rompe la piazzola (`pad.intact == false`), `field.level(..., base, 1.0)` la ripristina.

- [ ] **Step 2: FAIL** — `fault_points` non esiste.

- [ ] **Step 3: Implementazione** — `_choose_fault()` sul campo: 18 punti a passo `FAULT_STEP` lungo `along`, scartando i protetti; `_shake_point(p)`: danno al giocatore se entro 1,2 m, nemici entro 1,2 m uccisi (`enemy.take_damage(enemy.health)`), boss risparmiato se entro 3 m, `volume_moved += absf(terrain_field.sculpt(p, 2.4, CREST_HEIGHT))`, `volume_moved += absf(terrain_field.sculpt(p + side * 2.4, 1.8, -FURROW_DEPTH))`, `lamp_field.knock_down_near(p, 1.5)`, detriti. `_tick_warning` sparge polvere sui `fault_points`. `ExtractionPad.advance`: `center_point = player.global_position`; `intact = terrain_field.is_flat_at(center_point)` con `is_flat(center, radius_m, tolerance_m)`; marker decal ad anello colorato `INTACT_COLOR`/`BROKEN_COLOR` a `height_at + 0.5`.

- [ ] **Step 4: PASS, check-only, commit**

```bash
git add godot/scripts/run/quake_event.gd godot/scripts/run/extraction_pad.gd godot/tests/quake_tests.gd godot/tests/extraction_tests.gd
git commit -m "Terremoto come cresta e solco di pennellate, piazzola di estrazione = disco piano di 3 m sul rilievo"
```

---

### Task 13: Mappa di fine livello, contatori, upgrade

**Files:**
- Modify: `godot/scripts/ui/run_map.gd` (nuove `snapshot_heights`, `render_heights`, `height_color`)
- Modify: `godot/scripts/run/arena_run.gd` (`_initial_heights`, `build_run_map`, `_show_run_map`, `_on_player_sculpted` al posto di `_on_terrain_command`, upgrade `tool_reach`, `dig_blast`, `spiked_wall`, `pack_size`, `brush_size`)
- Modify: `godot/scripts/progression/upgrade_catalog.gd` (nuova carta `brush_size`), `godot/scripts/progression/permanent_catalog.gd` (nuovo `pack_size`)
- Modify: `godot/tests/menu_tests.gd`, `godot/tests/workshop_tests.gd`, `godot/tests/run_progression_tests.gd` (se elenca le carte)

**Interfaces:**
- Produces su `RunMap`: `static func snapshot_heights(field: TerrainField, step_m := 2.4) -> PackedFloat32Array`; `static func height_color(delta: float, is_barricade: bool) -> Color` (rame `WALL_NEW` se `delta > 0.4`, blu `TRENCH_NEW` se `delta < -0.4`, `GROUND` altrimenti; `BARRICADE` se barricata); `static func render_heights(field: TerrainField, initial: PackedFloat32Array, barricades: Array[Vector3], buildings: Array[Rect2], start: Vector3, end: Vector3, boss: Variant = null, lamps: Array[Vector3] = [], step_m := 2.4) -> Image`.
- Su `ArenaRun`: `var volume_dug := 0.0`, `var volume_raised := 0.0`; piè di pagina `"Terra spostata: %d m3" % roundi(terrain_field.volume_moved)`; `player.tool_range_bonus_m = 1.2 * owned`; `pack_size` (+20 m³ per livello, Officina, costo 12 rottami, max 3) e `brush_size` (carta comune, +0,4 m di raggio per livello, max 3); `dig_blast` scatta ogni 0,5 s di scavo continuo (accumula il tempo in `_on_player_sculpted`).

- [ ] **Step 1: Test che fallisce** — in `menu_tests.gd`:

```gdscript
func _test_run_map_heights() -> void:
	print("run map heights")
	var field := TerrainField.new()
	field.size_m = 48.0
	field.tuning = TerrainTuning.new()
	field.render = false
	root.add_child(field)
	var initial := RunMap.snapshot_heights(field)
	_check(initial.size() == 21 * 21, "fotografia a passo 2,4 m su 48 m: 21 x 21 (%d)" % initial.size())
	field.sculpt(Vector3(6, 0, 6), 2.4, 1.0)
	field.sculpt(Vector3(-6, 0, -6), 2.4, -1.0)
	var image := RunMap.render_heights(field, initial, [Vector3(0, 0, 10)], [], Vector3.ZERO, Vector3(2, 0, 2))
	_check(RunMap.same_color(RunMap.height_color(0.9, false), RunMap.WALL_NEW), "alzato = rame")
	_check(RunMap.same_color(RunMap.height_color(-0.9, false), RunMap.TRENCH_NEW), "scavato = blu")
	_check(RunMap.same_color(RunMap.height_color(0.1, false), RunMap.GROUND), "sotto 0,4 m = suolo")
	_check(image.get_width() >= 100, "immagine prodotta")
	field.queue_free()
```

In `workshop_tests.gd` la riga `tool_reach = 4.8 + cell_size_m` diventa `player.tool_range_bonus_m == 1.2 * livello`; aggiungere `pack_size`: dopo l'acquisto `player.pack.capacity == 80`.

- [ ] **Step 2: FAIL** — `snapshot_heights` non esiste.

- [ ] **Step 3: Implementazione** — `snapshot_heights` campiona `field.height_at` su una griglia `n = int(field.half_extent() * 2 / step_m) + 1`; `render_heights` costruisce `full` di `n x n` pixel con `height_color(now - initial[i], near_barricade)` (`near_barricade` = esiste un punto di `barricades` entro 1,5 m), poi edifici, marker e `view_rect` esattamente come `render` (riusare `_mark`, `view_rect`, con `_pixel_at` riscritta su `step_m` e `half_extent`). `ArenaRun._on_player_sculpted(center, radius, volume, mode)`: `volume_dug += maxf(-volume, 0)`, `volume_raised += maxf(volume, 0)`, detriti a `height_at(center)`, dig blast: `_blast_charge += delta_from_last_call` (usare `Time.get_ticks_msec()` del passo) e scatta ogni 0,5 s di scavo. Upgrade `spiked_wall`: il colore passa a `terrain_field` come tinta degli argini alzati dal giocatore (`TerrainSurface.raised_tint`, Task 14; fino ad allora solo `director.spike_damage`).

- [ ] **Step 4: PASS, check-only, commit**

```bash
git add godot/scripts/ui/run_map.gd godot/scripts/run/arena_run.gd godot/scripts/progression/upgrade_catalog.gd godot/scripts/progression/permanent_catalog.gd godot/tests/menu_tests.gd godot/tests/workshop_tests.gd godot/tests/run_progression_tests.gd
git commit -m "Mappa di fine livello sui delta di quota, terra spostata al posto delle celle, upgrade pack_size e brush_size, tool_reach in metri"
```

---

### Task 14: Resa del suolo (`TerrainSurface`), tile per Terrain3D, vegetazione sul rilievo

**Files:**
- Modify: `godot/scripts/terrain/terrain_surface.gd` (lo stub del Task 2)
- Create: `godot/resources/materials/terrain_relief.gdshader` (shader override di Terrain3D)
- Modify: `tools/blender/build_surface_tiles.py` (uscita `--terrain3d`: `godot/assets/textures/terrain/<name>_albedo_height.png` e `<name>_normal_rough.png` per `dirt`, `slabs`, `asphalt`, `dug_soil`, `mud`)
- Modify: `godot/scripts/arena/overgrown_arena.gd:912-990` (`_build_ground_cover`: quota da `terrain_field`), `ruins_district.gd` (`cover_height` → `terrain_field.height_at`), `godot/scripts/arena/overgrown_arena.gd` (`@export var terrain_field: TerrainField`)
- Modify: `godot/tests/restyle_tests.gd`
- Modify: `godot/scripts/services/graphics_quality.gd` (preset Deck: `mesh_lods` 5, `mesh_size` 32)

**Interfaces:**
- Produces: `TerrainSurface.apply(terrain: Terrain3D) -> void` (assegna assets, materiale e shader); `TerrainSurface.set_raised_tint(terrain: Terrain3D, color: Color) -> void` (uniform `raised_tint` dello shader, usata da `spiked_wall`); shader uniforms `base_map: sampler2D` (texture R32F della base scritta da `TerrainField._mirror_all`/`commit_base` tramite `TerrainSurface.update_base(terrain, image)`), `raised_tint`, `dug_tint`, `mud_level`.
- Lo shader parte da quello di Terrain3D (`Terrain3DMaterial.get_shader_code()`? no: usare `material.shader_override_enabled = true` e `material.shader_override = load(...)` con un file ottenuto copiando il codice generato dal materiale: `ResourceSaver` non serve; in editor: Terrain3D → Material → "Shader Override" → "Copy" produce il file di partenza; farlo una volta e committare `terrain_relief.gdshader`). Nel fragment, dopo il calcolo di `albedo`/`normal` di Terrain3D, inserire la nostra scelta per pendenza e delta.

- [ ] **Step 1: Test che fallisce** — in `restyle_tests.gd` (`_test_vegetation_and_props` apre `arena_run`):

```gdscript
	var field: TerrainField = _scene.get_node(^"TerrainField")
	var terrain := field.terrain3d()
	if terrain != null:  # con finestra; in headless terrain3d() e null e questi controlli si saltano
		_check(terrain.material.shader_override_enabled and terrain.material.shader_override != null, "shader del rilievo attivo")
		_check(terrain.material.shader_override.code.contains("delta_tint"), "lo shader legge il delta dalla base")
		_check(terrain.assets.get_texture_count() == 5, "cinque strati di tile (%d)" % terrain.assets.get_texture_count())
	var tufts: MultiMeshInstance3D = district.find_child("GrassTufts", true, false)
	var sample := tufts.multimesh.get_instance_transform(0).origin
	_check(absf(sample.y - field.height_at(sample)) < 0.15, "il prato poggia sul rilievo (%.2f vs %.2f)" % [sample.y, field.height_at(sample)])
	var on_steep := 0
	for i in range(0, tufts.multimesh.instance_count, 97):
		if field.slope_at(tufts.multimesh.get_instance_transform(i).origin) > 0.6:
			on_steep += 1
	_check(on_steep == 0, "niente prato sui fianchi ripidi (%d)" % on_steep)
	_check(FileAccess.file_exists("res://assets/textures/terrain/dirt_albedo_height.png"), "tile impacchettate per Terrain3D")
```

- [ ] **Step 2: FAIL** — tile assenti, prato a quota 0.

- [ ] **Step 3: Tile** — in `build_surface_tiles.py` aggiungere il gruppo di uscita `terrain3d`: per ogni tile di `ground` tranne `grass`, dopo la cottura di albedo/normal/orm, scrivere con numpy `albedo.rgb + height` (altezza = canale B dell'ORM? no: l'ORM è occlusione/rugosità/metallo; l'altezza non viene cotta oggi: aggiungere una quarta mappa `height` = rumore macro della tile, `bake_layer(..., "EMIT")` con il grafo `tile_height_graph` che emette `noise(macro)` in scala di grigi) e `normal.rgb + roughness` (= canale G dell'ORM), PNG RGBA 2048 in `godot/assets/textures/terrain/`, con `.import` standard (texture 2D, mipmaps, compress VRAM). Comando: `blender -b --factory-startup --python tools/blender/build_surface_tiles.py -- terrain3d`.

- [ ] **Step 4: `TerrainSurface`**:

```gdscript
class_name TerrainSurface
extends RefCounted
## Resa del rilievo (spec 6.2): cinque strati dalle tile dipinte, scelti dallo shader
## per pendenza, quota e delta dalla base; tinte per argini alzati (muro chiodato),
## scavato e fango nelle conche. Solo con finestra: in headless Terrain3D non c'e.

const LAYERS := ["dirt", "slabs", "asphalt", "dug_soil", "mud"]
const SHADER := preload("res://resources/materials/terrain_relief.gdshader")


static func apply(terrain: Terrain3D) -> void:
	terrain.assets = Terrain3DAssets.new()
	for i in LAYERS.size():
		var asset := Terrain3DTextureAsset.new()
		asset.name = LAYERS[i]
		asset.albedo_texture = load("res://assets/textures/terrain/%s_albedo_height.png" % LAYERS[i])
		asset.normal_texture = load("res://assets/textures/terrain/%s_normal_rough.png" % LAYERS[i])
		asset.uv_scale = 0.12
		asset.detiling_rotation = 0.15
		terrain.assets.set_texture(i, asset)
	terrain.material.world_background = Terrain3DMaterial.NONE
	terrain.material.auto_shader = false
	terrain.material.shader_override_enabled = true
	terrain.material.shader_override = SHADER
	terrain.material.set_shader_param("raised_tint", Color(0.62, 0.42, 0.24))
	terrain.material.set_shader_param("dug_tint", Color(0.30, 0.20, 0.12))
	terrain.material.set_shader_param("mud_level", -0.6)


static func set_raised_tint(terrain: Terrain3D, color: Color) -> void:
	terrain.material.set_shader_param("raised_tint", color)


## La base come texture R32F (stessa risoluzione del campo) per il delta nello shader.
static func update_base(terrain: Terrain3D, base: PackedFloat32Array, resolution: int, half: float) -> void:
	var image := Image.create_from_data(resolution, resolution, false, Image.FORMAT_RF, base.to_byte_array())
	terrain.material.set_shader_param("base_map", ImageTexture.create_from_image(image))
	terrain.material.set_shader_param("base_half", half)
	terrain.material.set_shader_param("base_resolution", resolution)
```

`TerrainField.commit_base()` e `_build_terrain3d()` chiamano `TerrainSurface.update_base(_terrain, _base, resolution, _half)` quando `_terrain_ready`.

- [ ] **Step 5: Shader** — in `terrain_relief.gdshader` (copia dello shader generato da Terrain3D), aggiungere le uniform `base_map`, `base_half`, `base_resolution`, `raised_tint`, `dug_tint`, `mud_level` e, nel `fragment()` dopo che Terrain3D ha calcolato `ALBEDO` e `NORMAL_MAP`, questo blocco (le variabili `v_vertex_xz` e la pendenza vengono dal codice di Terrain3D: usare `v_vertex.xz` e la normale del terreno `w_normal` come compaiono nel file copiato):

```glsl
	// Rilievo (D-082): strati per pendenza e delta dalla base, tinte di scavato e alzato.
	vec2 base_uv = (v_vertex.xz + vec2(base_half)) / (float(base_resolution - 1) * 0.5);
	float base_h = texture(base_map, base_uv).r;
	float delta = v_vertex.y - base_h;
	float slope = 1.0 - clamp(w_normal.y, 0.0, 1.0);
	vec3 col = ALBEDO;
	float delta_tint = smoothstep(0.3, 0.9, delta);
	col = mix(col, col * raised_tint * 1.6, delta_tint * 0.7);
	float dug = smoothstep(-0.3, -0.9, delta);
	col = mix(col, dug_tint, dug * 0.6);
	float mud = smoothstep(mud_level + 0.3, mud_level - 0.2, v_vertex.y);
	col = mix(col, vec3(0.16, 0.13, 0.10), mud * 0.7);
	ROUGHNESS = mix(ROUGHNESS, 0.25, mud);
	col = mix(col, col * vec3(0.85, 0.78, 0.7), smoothstep(0.35, 0.6, slope) * 0.6);
	ALBEDO = col;
```

La scelta dello strato (quale tile) per pendenza resta affidata al control map di Terrain3D: `TerrainSurface.apply` è seguita, in `RuinsDistrict.apply_strokes`, da una pittura del control map con `terrain_field.paint_layer(center, radius, layer_index)` (nuovo metodo di `TerrainField` che chiama `data.set_control_base_id`/`set_pixel(TYPE_CONTROL, ...)` su un disco e `update_maps(TYPE_CONTROL, false)`): strada = `asphalt` (2), piazza = `slabs` (1), cime degli argini e cumuli = `dug_soil` (3), conche sotto `mud_level` = `mud` (4), resto `dirt` (0); il prato dipinto viene dal color map (`tint` verde con alpha 0,5) e dai MultiMesh.

- [ ] **Step 6: Vegetazione** — in `overgrown_arena.gd` `_build_ground_cover`, dove oggi `Vector3(p.x, height, p.y)`: con `terrain_field != null` usare `terrain_field.height_at(Vector3(p.x, 0, p.y))` e saltare il candidato se `terrain_field.slope_at(...) > 0.6`; le chiazze di prato hanno `chance` moltiplicata per `1.0 + 0.5 * clampf(-terrain_field.delta_at(...), 0.0, 1.0)` (più fitte nelle conche); `_bush`, `_tree`, rovine e prop: `base.y = terrain_field.height_at(base)` prima di piazzarli. `GraphicsQuality` preset Deck: `terrain_mesh_lods = 5`, `terrain_mesh_size = 32` applicati in `TerrainField._build_terrain3d` leggendo `GameSettingsService`.

- [ ] **Step 7: PASS** — `restyle_tests` headless (saltando i controlli con finestra) e con finestra (`godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/restyle_tests.gd`); catture `capture_district.gd -- --out=../output/terrain` e closeup `--at=0,0.5,-9.6 --from=6,4,-2 --name=rampart_close` (argine del cortile), `--at=40,0.5,40 --from=44,2.5,46 --name=grass_close`.

- [ ] **Step 8: Commit**

```bash
git add godot/scripts/terrain/terrain_surface.gd godot/scripts/terrain/terrain_field.gd godot/resources/materials/terrain_relief.gdshader tools/blender/build_surface_tiles.py godot/assets/textures/terrain godot/scripts/arena/overgrown_arena.gd godot/scripts/arena/ruins_district.gd godot/scripts/services/graphics_quality.gd godot/tests/restyle_tests.gd
git commit -m "Resa del rilievo: cinque strati dipinti su Terrain3D, tinte di alzato/scavato/fango dallo shader, prato e prop appoggiati al rilievo"
```

---

### Task 15: Zainetto sul modello dell'ingegnere

**Files:**
- Modify: `tools/blender/build_character_assets.py:523-590` (`build_player_engineer_refined`: nuova sacca)
- Modify: `godot/resources/materials/actor_paint.gdshader` (uniform `pack_fill`)
- Modify: `godot/scripts/player/player_character.gd` (`pack.changed` → `_model_material.set_shader_parameter(&"pack_fill", ratio)` e scala della sacca)
- Modify: `godot/tests/tools/capture_character.gd` (viste da dietro con zaino a 0, 0,5, 1)
- Modify: `godot/tests/player_tests.gd`

**Interfaces:**
- Produces: nel modello un pezzo `PackSack` (nome del vertex group / mesh `pack_sack`) sotto lo zaino-macchina esistente, con una striscia verticale sul fianco destro dipinta con colore di vertice `PACK_GAUGE = (0.95, 0.9, 0.8)` (il materiale la riconosce); shader `actor_paint`: `uniform float pack_fill : hint_range(0.0, 1.0) = 0.0;` e, dove `COLOR` del vertice è la tinta della striscia (`distance(COLOR.rgb, vec3(0.95, 0.9, 0.8)) < 0.05`), `ALBEDO = mix(vec3(0.82, 0.78, 0.7), vec3(0.28, 0.2, 0.12), step(1.0 - UV.y, pack_fill))` (la UV verticale della striscia va da 0 in basso a 1 in alto nel costruttore); `PlayerCharacter._on_pack_changed(amount, capacity)`.

- [ ] **Step 1: Test che fallisce** — in `player_tests.gd`:

```gdscript
func _test_pack_gauge() -> void:
	print("pack gauge")
	var field := TerrainField.new()
	field.size_m = 32.0
	field.tuning = TerrainTuning.new()
	field.render = false
	root.add_child(field)
	var player: PlayerCharacter = PlayerScene.instantiate()
	player.terrain_field = field
	root.add_child(player)
	await _frames(2)
	var material := player.paint_material() as ShaderMaterial
	_check(material != null and absf(float(material.get_shader_parameter(&"pack_fill")) - 20.0 / 60.0) < 0.01, "pack_fill parte da 20/60")
	player.pack.give(40.0)
	_check(absf(float(material.get_shader_parameter(&"pack_fill")) - 1.0) < 0.01, "zaino pieno = pack_fill 1")
	var sack := player.find_child("PackSack", true, false)
	_check(sack != null, "la sacca esiste nel modello")
	player.queue_free()
	field.queue_free()
```

(`paint_material()` esiste? verificare in `player_character.gd`; se il materiale si chiama diversamente, esporre `func paint_material() -> Material` che ritorna il materiale del corpo.)

- [ ] **Step 2: FAIL** — `pack_fill` assente.

- [ ] **Step 3: Blender** — in `build_player_engineer_refined()` dopo le righe dello zaino-macchina aggiungere la sacca di tela sotto di esso (`b.box(CHEST, (0.36, 0.26, 0.2), (0.0, 0.14, pack_z - 0.02), CANVAS, bevel=0.04, subsurf=1)`), la striscia `b.box(CHEST, (0.03, 0.22, 0.03), (0.2, 0.14, pack_z - 0.02), PACK_GAUGE, bevel=0.004)` con UV verticali 0..1 (il costruttore `b.box` deve poter ricevere `uv_vertical=True`; aggiungerlo se manca), un pezzo `pack_sack` separato come oggetto figlio `PackSack` così Godot lo trova con `find_child`. Rigenerare con il comando in `docs/GODOT_WORKFLOW.md` (sezione pipeline personaggi); cuocere la texture.

- [ ] **Step 4: Godot** — shader e giocatore come in Interfaces; a `fill_ratio() > 0.9` la sacca scala di 1,12 (`sack.scale = Vector3.ONE * 1.12`), altrimenti 1.

- [ ] **Step 5: PASS, catture** — `capture_character.gd -- --out=../output/terrain/character` con tre pose (zaino 0, 0,5, 1) da dietro e dai tre quarti alti; **giudizio del proprietario** ("vediamo come viene").

- [ ] **Step 6: Commit**

```bash
git add tools/blender/build_character_assets.py godot/assets/models/player godot/resources/materials/actor_paint.gdshader godot/scripts/player/player_character.gd godot/tests/player_tests.gd godot/tests/tools/capture_character.gd
git commit -m "Zainetto di terra sul modello dell'ingegnere con striscia-indicatore (spec sezione 3)"
```

---

### Task 16: Bot, benchmark, impronte, catture, gate e documenti

**Files:**
- Modify: `godot/tests/tools/simulate_runs.gd:395-470`, `godot/tests/tools/benchmark_arena.gd:55-85`, `godot/scripts/navigation/flow_preview.gd:393-398` (`_ground_y` → `terrain_field.height_at`), `godot/tests/flow_preview_tests.gd`, `godot/tests/input_events_tests.gd` (resta sulla griglia: nessun cambio), `godot/tests/ui_theme_tests.gd:385-387`, `godot/tests/button_prompts_tests.gd`, `godot/tests/audio_tests.gd`
- Create: `godot/tests/tools/capture_terrain.gd`
- Modify: `docs/GODOT_WORKFLOW.md`, `docs/TERRAIN_SYSTEM.md`, `docs/ART_DIRECTION.md`, `docs/PROGRESSION_SPEC.md`, `docs/FEATURE_IDEAS.md`, `docs/PROJECT_ROADMAP.md`, `docs/MIGRATION_STATUS.md`, `docs/DECISIONS.md` (nuova decisione: zainetto e rottamatori che scavano), `docs/INDEX.md`

**Interfaces:**
- Bot: `_tick_digging` sul campo: cerca la vena più vicina con `_scrap.veins()` (`scrap_left > 0`) entro 25 m, punta il bersaglio del tool su di essa e tiene `tool_held = true` finché la vena non si esaurisce o un nemico è entro 3,5 m; `_tick_rampart`: quando `_run.elapsed` supera 60 s e il campo di percorso indica il varco più usato (`path_field.next_waypoint` dal cortile), alza un argine (`RAISE` tenuto 3 s) a 6 m dal cortile su quella direzione; dopo il boss `LEVEL` tenuto finché `extraction_pad.intact`. Log dei comandi: `PROTOTYPE01_SIM_BRUSH t=%.2f mode=%s x=%.1f z=%.1f` per seme (determinismo D-055).
- Benchmark: righe `PROTOTYPE01_ARENA_BENCH terrain brush_avg_ms=%.2f brush_max_ms=%.2f chunks=%d chunk_refresh_ms=%.2f base_bake_ms=%.1f` (100 pennellate casuali dopo la costruzione).
- Catture: `capture_terrain.gd -- --out=../output/terrain`: `rampart` (argine alzato dal giocatore con anello giallo), `trench` (solco scavato), `vein_half` (cumulo con vena a metà), `barricade` (barricata del boss), `pack_back_empty`/`pack_back_full`, `overview`.

- [ ] **Step 1: Test che fallisce** — in `flow_preview_tests.gd` il test "i cambi forzati non fanno impronte" diventa: `field.sculpt(...)` (boss/evento) non chiama `show_now`, `field.player_sculpt(...)` sì; in `audio_tests.gd`: `player_sculpted` con `DIG` produce `terrain_dig` al più una volta ogni 0,25 s (tre chiamate in un passo = un suono).

- [ ] **Step 2: FAIL**, **Step 3: implementazione** come in Interfaces (le impronte si collegano a `terrain_field.player_sculpted` quando `terrain_field != null`).

- [ ] **Step 4: Gate e misure** — `powershell -File tools/godot/Invoke-GodotChecks.ps1` verde; benchmark `--preset=high` e `--preset=deck`: frame PC ≤ 12 ms, pennellata ≤ 1,5 ms media; `capture_terrain.gd`, `capture_district.gd -- --out=../output/terrain`, `capture_night.gd -- --out=../output/terrain/night`.

- [ ] **Step 5: Documenti** — `GODOT_WORKFLOW.md`: sezione "Terreno continuo" (comandi: `bake_terrain_base.gd`, `build_surface_tiles.py -- terrain3d`, `capture_terrain.gd`; trappole: `Terrain3D.data` nasce un fotogramma dopo `add_child` in headless; camera assegnata prima di ogni uso; `update_maps` solo con `region.edited`; collisione di Terrain3D spenta; Jolt obbligatorio; `set_height` non interpola). `TERRAIN_SYSTEM.md`: strategia D ibrida con Terrain3D, gate chiusi. `ART_DIRECTION.md`: suolo a strati per pendenza/delta, zainetto. `PROGRESSION_SPEC.md`: `pack_size`, `brush_size`, `tool_reach` in metri. `FEATURE_IDEAS.md`: idee 4 e 10 in termini di pennellate. `DECISIONS.md`: D-086 "zainetto sul modello e rottamatori che rosicchiano" (Provvisoria, da giudicare nel playtest). Roadmap e stato: tappa A chiusa, prossimo = tappa B (ferrovia) o giudizio del proprietario sulle catture.

- [ ] **Step 6: Commit**

```bash
git add godot/tests/tools/simulate_runs.gd godot/tests/tools/benchmark_arena.gd godot/tests/tools/capture_terrain.gd godot/scripts/navigation/flow_preview.gd godot/tests docs
git commit -m "Tappa A chiusa: bot sulle vene e sugli argini, benchmark del pennello, impronte sul rilievo, catture, documenti (D-086)"
```

---

## Self-review (fatto il 12 ottobre 2026)

- **Copertura della spec**: 2.1-2.3 → Task 1-3; 2.4 → 6; 2.5 → 7; 2.6-2.7 → 2 e 8; 3 → 4, 5, 15; 4 → 7 e 10; 5.1 → 9; 5.2 → 11; 5.3-5.4 → 12; 5.5-5.7 → 13 e 16; 6 → 8 e 14; 7-8 → ogni task più 16. Fuori da questo piano, di proposito: Trivella, treno, vagoni, saltatori sui binari (tappa B); eliminazione di `TerrainGrid` e delle scene minori (tappa B).
- **Segnaposto**: nessun "TBD"; i punti "verificare il nome reale" (`spawn_at`, `paint_material`, l'azione del tool in `_unhandled_input`, `_block_rects`/`_road_segments`) indicano una funzione da leggere nel file prima di scrivere, con il comportamento richiesto già descritto.
- **Coerenza dei tipi**: `TerrainField.ToolMode` (DIG 0, RAISE 1, LEVEL 2, LAMP 3) usato da giocatore, HUD, audio, bot; `region_changed(aabb: AABB)` e `player_sculpted(center: Vector3, radius: float, volume: float, mode: int)` ovunque; i segnali di Demolitore e LampField passano `Vector3`; `TerrainCollision.body` è il collider del terreno per PathField, direttore e boss.
- **Review Focus**: 1 → Task 2/3; 2 → Task 3; 3 → Task 5; 4 → Task 7; 5 → Task 9/10.
