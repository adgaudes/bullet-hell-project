# Armi e classi, piano 1: impianto — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** l'impianto delle armi della spec D-092 funzionante col kit dell'Ingegnere: catalogo dati, basi `Weapon`/`ActiveWeapon`, chiodatrice con livelli e bivi, Picchetto sismico come prima attiva, slot, carte arma nel level-up con schermata del bivio, coda di scritture sul terreno, striscia del HUD, comandi E/F e LT/RB.

**Architecture:** i dati vivono in `WeaponCatalog` e `ClassCatalog` (classi statiche come `UpgradeCatalog`). Ogni arma e un nodo che legge i propri valori da `WeaponCatalog.stat()` dato livello e bivi. `WeaponLoadout`, creato da `ArenaRun` all'avvio (nessuna scena da modificare), possiede gli slot, adotta il nodo `PlayerWeapon` esistente come chiodatrice e riceve dal giocatore la pressione dei tasti attivi. `WeaponOffers` costruisce le carte arma; `RunProgression.roll_offer` le mescola alle carte del mazzo di classe.

**Tech Stack:** Godot 4.7.2, GDScript, suite headless `extends SceneTree` (`PROTOTYPE01_TESTS PASS/FAIL`), gate `tools/godot/Invoke-GodotChecks.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-15-weapons-classes-design.md` (questo piano copre il par. 11, punto 1). Piani successivi: 2 kit comune, 3 classi (una per piano o in parallelo), 4 casse/Officina/scelta classe/profilo v2, 5 suoni ed effetti, 6 bilanciamento.

## Global Constraints

- Comandi Godot sempre con `godot_console`, suite una alla volta (`--headless --path godot --fixed-fps 60 --script res://tests/<suite>.gd`), `--check-only` su ogni script toccato.
- Nessuna scena `.tscn` modificata in questo piano: il loadout si crea da codice.
- Identificatori in inglese, testi a schermo in italiano senza accenti tipografici (come il resto del catalogo).
- Valori di partenza dalla spec par. 4.1, non bilanciati; un solo posto: `WeaponCatalog`.
- Le scritture delle armi sul terreno passano solo da `TerrainWriteQueue` (una per passo fisico, raggio massimo 2,5 m).
- Controller e tastiera equivalenti: `weapon_active_1` = E / LT, `weapon_active_2` = F / RB.
- Default di classe: `engineer`; `--class=<id>` da riga di comando.
- Budget: tutte le armi insieme al massimo 1,0 ms per passo in piu (benchmark Deck, 70 nemici).

## Review Focus

1. Carta bivio scelta e poi level-up multipli in coda: il secondo level-up non deve aprirsi sopra la schermata del bivio, ne perdere un livello.
2. Attiva premuta durante la pausa o col menu aperto: nessun uso, nessuna ricarica consumata.
3. Picchetto lanciato su zona protetta (cortile di partenza) o fuori campo: nessuna scritta, nessun errore, ricarica consumata comunque.
4. Classe senza armi implementate (`--class=sapper` in questo piano): la run parte senza errori, chiodatrice spenta, nessuna carta arma impossibile.
5. Compagno con Torretta: continua a sparare con i valori di oggi (`AutoWeapon` senza `weapon_id`).

---

### Task 1: dati — `WeaponCatalog`, `ClassCatalog`, mazzi in `UpgradeCatalog`

**Files:**
- Create: `godot/scripts/combat/weapon_catalog.gd`
- Create: `godot/scripts/progression/class_catalog.gd`
- Modify: `godot/scripts/progression/upgrade_catalog.gd` (campo `deck`, via le carte `nail_*`)
- Test: `godot/tests/weapon_catalog_tests.gd`

**Interfaces:**
- Produces:
  - `WeaponCatalog.find(id: StringName) -> Dictionary` (vuoto se manca)
  - `WeaponCatalog.all() -> Array[Dictionary]`
  - `WeaponCatalog.stat(id: StringName, key: StringName, level: int, branches: Dictionary) -> float`
  - `WeaponCatalog.branch_options(id: StringName, at_level: int) -> Array[Dictionary]` (due voci `{id, name, text}`)
  - `WeaponCatalog.MAX_LEVEL := 5`, `BRANCH_LEVELS := [3, 5]`
  - voce arma: `{id, name, deck, slot (&"auto"/&"active"), partner, fusion, unlock_cost, icon, text, base: Dictionary, levels: {2: mods, 4: mods}, branches: {3: [opt_a, opt_b], 5: [...]}, level_texts: {2: String, 4: String}}`; mods con chiavi `<stat>_mul`, `<stat>_add`, `<stat>_set`
  - `ClassCatalog.all()`, `ClassCatalog.find(id)`, `ClassCatalog.start_weapons(id) -> Array[StringName]` (solo armi presenti in `WeaponCatalog`), `ClassCatalog.DEFAULT := &"engineer"`
  - `UpgradeCatalog` voci con `deck` (`&"common"` o id di classe)

- [ ] **Step 1: test che fallisce**

```gdscript
extends SceneTree
## Dati delle armi e delle classi (spec D-092, par. 3-5). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/weapon_catalog_tests.gd

var _failures := 0


func _initialize() -> void:
	_test_nailgun_stats()
	_test_branches()
	_test_classes()
	_test_upgrade_decks()
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _test_nailgun_stats() -> void:
	print("nailgun stats")
	_check(not WeaponCatalog.find(&"nailgun").is_empty(), "la chiodatrice e nel catalogo")
	_check(is_equal_approx(WeaponCatalog.stat(&"nailgun", &"fire_interval", 1, {}), 0.5), "liv. 1: un colpo ogni 0,5 s")
	_check(is_equal_approx(WeaponCatalog.stat(&"nailgun", &"fire_interval", 2, {}), 0.4), "liv. 2: cadenza +25%")
	_check(WeaponCatalog.stat(&"nailgun", &"pierce", 4, {3: &"a"}) == 1.0, "liv. 4: +1 trapassato")
	_check(WeaponCatalog.stat(&"nailgun", &"damage", 1, {}) == 1.0, "1 danno")


func _test_branches() -> void:
	print("branches")
	var options := WeaponCatalog.branch_options(&"nailgun", 3)
	_check(options.size() == 2, "due opzioni al livello 3")
	_check(is_equal_approx(WeaponCatalog.stat(&"nailgun", &"fire_interval", 3, {3: &"a"}), 0.2), "Raffica: cadenza x2 sopra il liv. 2")
	_check(is_equal_approx(WeaponCatalog.stat(&"nailgun", &"fire_interval", 3, {3: &"b"}), 0.7), "Chiodi da ponte: un colpo ogni 0,7 s")
	_check(WeaponCatalog.stat(&"nailgun", &"damage", 3, {3: &"b"}) == 2.0, "Chiodi da ponte: 2 danni")
	_check(WeaponCatalog.branch_options(&"nailgun", 2).is_empty(), "nessun bivio al livello 2")
	_check(WeaponCatalog.branch_options(&"seismic_stake", 5).size() == 2, "il picchetto ha il bivio al 5")
	for entry in WeaponCatalog.all():
		for at in WeaponCatalog.BRANCH_LEVELS:
			_check(WeaponCatalog.branch_options(entry.id, at).size() == 2, "%s: due bivi al %d" % [entry.id, at])


func _test_classes() -> void:
	print("classes")
	_check(ClassCatalog.all().size() == 4, "quattro classi")
	_check(ClassCatalog.start_weapons(&"engineer") == [&"nailgun", &"seismic_stake"] as Array[StringName], "kit dell'Ingegnere")
	_check(ClassCatalog.start_weapons(&"sapper").is_empty(), "kit del Guastatore non ancora implementato: vuoto")
	_check(ClassCatalog.find(&"nobody").is_empty(), "classe sconosciuta: vuota")


func _test_upgrade_decks() -> void:
	print("upgrade decks")
	var ids := UpgradeCatalog.all().map(func(u: Dictionary) -> StringName: return u.id)
	_check(not ids.has(&"nail_rate") and not ids.has(&"nail_pierce") and not ids.has(&"nail_spread"), "carte nail_* tolte")
	var valid := [&"common", &"engineer", &"sapper", &"mechanic", &"weeder"]
	_check(UpgradeCatalog.all().all(func(u: Dictionary) -> bool: return valid.has(u.get(&"deck", &""))), "ogni carta ha un mazzo valido")
	var engineer := UpgradeCatalog.all().filter(func(u: Dictionary) -> bool: return u.deck == &"engineer")
	_check(engineer.size() == 2, "mazzo Ingegnere: Pala larga e Argini spinati")
	var mechanic := UpgradeCatalog.all().filter(func(u: Dictionary) -> bool: return u.deck == &"mechanic")
	_check(mechanic.size() == 2, "mazzo Meccanico: Torretta e Faro")
	var sapper := UpgradeCatalog.all().filter(func(u: Dictionary) -> bool: return u.deck == &"sapper")
	_check(sapper.size() == 1, "mazzo Guastatore: Scavo esplosivo")
```

- [ ] **Step 2: eseguire, deve fallire**

Run: `godot_console --headless --path godot --fixed-fps 60 --script res://tests/weapon_catalog_tests.gd`
Expected: errore di parsing, `WeaponCatalog` non dichiarato.

- [ ] **Step 3: `weapon_catalog.gd`**

```gdscript
class_name WeaponCatalog
extends RefCounted
## Armi della spec D-092 (docs/superpowers/specs/2026-10-15-weapons-classes-design.md, par. 4).
## Dati in un solo posto, come UpgradeCatalog. Ogni voce: id, name, deck (&"common" o una
## classe), slot (&"auto"/&"active"), partner (l'arma compagna della fusione), fusion, unlock_cost
## (rottami in Officina, 0 = sempre disponibile), icon (UiIcon), text, base (valori al livello 1),
## levels (modifiche ai livelli 2 e 4), level_texts, branches (due opzioni ai livelli 3 e 5).
## Le modifiche usano chiavi `<valore>_mul`, `<valore>_add`, `<valore>_set` e si applicano in
## ordine di livello: 2, bivio del 3, 4, bivio del 5.

const MAX_LEVEL := 5
const BRANCH_LEVELS: Array[int] = [3, 5]


static func all() -> Array[Dictionary]:
	return [
		{id = &"nailgun", name = "Chiodatrice", deck = &"engineer", slot = &"auto", partner = &"seismic_stake",
			fusion = &"fort", unlock_cost = 0, icon = &"nail",
			text = "Chiodi dritti al bersaglio. Gli argini li fermano.",
			base = {fire_interval = 0.5, damage = 1.0, weapon_range = 9.0, pierce = 0.0, projectiles = 1.0,
				spread_degrees = 12.0, projectile_speed = 24.0},
			levels = {2: {fire_interval_mul = 0.8}, 4: {pierce_add = 1.0}},
			level_texts = {2: "Spara il 25% piu spesso.", 4: "Ogni chiodo trapassa un nemico in piu."},
			branches = {
				3: [
					{id = &"burst", name = "Raffica", text = "Cadenza doppia, chiodi un po' sparpagliati.",
						mods = {fire_interval_mul = 0.5, spread_jitter_set = 8.0}},
					{id = &"bridge", name = "Chiodi da ponte", text = "Trapassano tutto e fanno 2 danni, ma un colpo ogni 0,7 s.",
						mods = {pierce_set = 99.0, damage_set = 2.0, fire_interval_set = 0.7}},
				],
				5: [
					{id = &"ricochet", name = "Rimbalzanti", text = "Un chiodo che colpisce un argine rimbalza una volta.",
						mods = {bounces_set = 1.0}},
					{id = &"incendiary", name = "Incandescenti", text = "Ogni chiodo lascia una macchia di fuoco per 2 s.",
						mods = {fire_patch_set = 1.0}},
				],
			}},
		{id = &"seismic_stake", name = "Picchetto sismico", deck = &"engineer", slot = &"active", partner = &"nailgun",
			fusion = &"fort", unlock_cost = 0, icon = &"stake",
			text = "Pianti un picchetto: si alza un anello di argine che chiude dentro chi c'e.",
			base = {cooldown = 15.0, aim_range = 6.0, ring_radius = 3.0, ring_height = 1.2, ring_width = 0.8,
				raise_delay = 0.6, hold_seconds = 12.0},
			levels = {2: {cooldown_mul = 0.85}, 4: {cooldown_mul = 0.85}},
			level_texts = {2: "Si ricarica il 15% prima.", 4: "Si ricarica il 15% prima."},
			branches = {
				3: [
					{id = &"wide", name = "Anello largo", text = "L'anello ha raggio 4,5 m.", mods = {ring_radius_set = 4.5}},
					{id = &"permanent", name = "Argine permanente", text = "L'anello non torna giu.", mods = {permanent_set = 1.0}},
				],
				5: [
					{id = &"spiked", name = "Argine chiodato", text = "Chi spinge contro l'anello prende 1 danno ogni 0,6 s.",
						mods = {spike_damage_set = 1.0}},
					{id = &"shock", name = "Scossa", text = "Quando si alza fa 3 danni a chi ci sta sopra e lo scaglia fuori.",
						mods = {shock_damage_set = 3.0}},
				],
			}},
	]


static func find(id: StringName) -> Dictionary:
	for entry in all():
		if entry.id == id:
			return entry
	return {}


## Valore [param key] dell'arma al livello dato, coi bivi presi ({3: &"a"|&"b", 5: ...}).
## Un valore assente dalla base vale 0 (i flag dei bivi: bounces, fire_patch, permanent...).
static func stat(id: StringName, key: StringName, level: int, branches: Dictionary) -> float:
	var entry := find(id)
	if entry.is_empty():
		return 0.0
	var value := float((entry.base as Dictionary).get(key, 0.0))
	for at in range(2, mini(level, MAX_LEVEL) + 1):
		var mods: Dictionary = {}
		if BRANCH_LEVELS.has(at):
			var options: Array = (entry.branches as Dictionary).get(at, [])
			var pick: StringName = branches.get(at, &"")
			if pick == &"a" and options.size() > 0:
				mods = options[0].mods
			elif pick == &"b" and options.size() > 1:
				mods = options[1].mods
		else:
			mods = (entry.levels as Dictionary).get(at, {})
		value = _apply(value, key, mods)
	return value


static func _apply(value: float, key: StringName, mods: Dictionary) -> float:
	var set_key := StringName("%s_set" % key)
	if mods.has(set_key):
		value = float(mods[set_key])
	var mul_key := StringName("%s_mul" % key)
	if mods.has(mul_key):
		value *= float(mods[mul_key])
	var add_key := StringName("%s_add" % key)
	if mods.has(add_key):
		value += float(mods[add_key])
	return value


## Le due trasformazioni al livello [param at_level] (3 o 5), vuoto altrove.
static func branch_options(id: StringName, at_level: int) -> Array[Dictionary]:
	var entry := find(id)
	var out: Array[Dictionary] = []
	if entry.is_empty():
		return out
	for option: Dictionary in (entry.branches as Dictionary).get(at_level, []):
		out.append(option)
	return out
```

- [ ] **Step 4: `class_catalog.gd`**

```gdscript
class_name ClassCatalog
extends RefCounted
## Le quattro classi del roster (D-077, D-092): nome, colore d'accento, kit iniziale e mazzo.
## Il kit elenca tutte le armi della spec; `start_weapons` restituisce solo quelle gia nel
## catalogo, cosi una classe senza armi implementate parte comunque.

const DEFAULT := &"engineer"


static func all() -> Array[Dictionary]:
	return [
		{id = &"engineer", name = "Ingegnere", color = Color(1.0, 0.45, 0.08),
			kit = [&"nailgun", &"seismic_stake"], start_cards = [] as Array[StringName],
			text = "Equilibrata: chiodi e argini."},
		{id = &"sapper", name = "Guastatore", color = Color(0.9, 0.12, 0.08),
			kit = [&"scrap_launcher", &"dig_charge"], start_cards = [] as Array[StringName],
			text = "Scavo esplosivo: crateri e parabole."},
		{id = &"mechanic", name = "Meccanico", color = Color(0.1, 0.75, 0.72),
			kit = [&"welder", &"crane_magnet"], start_cards = [] as Array[StringName],
			text = "Compagno potenziato: archi elettrici e calamite."},
		{id = &"weeder", name = "Erbacciaia", color = Color(0.85, 0.15, 0.6),
			kit = [&"scythe", &"bramble"], start_cards = [] as Array[StringName],
			text = "Vegetazione come difesa: falci e rovi."},
	]


static func find(id: StringName) -> Dictionary:
	for entry in all():
		if entry.id == id:
			return entry
	return {}


static func start_weapons(id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for weapon_id: StringName in find(id).get(&"kit", []):
		if not WeaponCatalog.find(weapon_id).is_empty():
			out.append(weapon_id)
	return out
```

- [ ] **Step 5: `upgrade_catalog.gd`** — togliere le tre voci `nail_rate`, `nail_pierce`, `nail_spread`; aggiungere `deck` a ogni voce: `common` per companion_magnet, companion_cargo, boots, patch, reach, torch_range, field_patch, lucky_scrap, nail_jar; `engineer` per brush_size, spiked_wall; `sapper` per dig_blast; `mechanic` per companion_turret, beacon_range. Aggiornare il commento di testa (campo `deck`, spec D-092 par. 5).

- [ ] **Step 6: eseguire, deve passare**

Run: la suite del passo 2. Expected: `PROTOTYPE01_TESTS PASS`.

- [ ] **Step 7: aggiornare `run_progression_tests.gd`** — `_test_maxed_upgrades_disappear` usa `nail_rate`: sostituire con `boots` (max 3). Eseguire la suite: PASS.

- [ ] **Step 8: commit** `Armi (D-092): WeaponCatalog, ClassCatalog, mazzi per classe; carte nail_* tolte; test`

---

### Task 2: base `Weapon` e chiodatrice coi bivi

**Files:**
- Create: `godot/scripts/combat/weapon.gd`
- Modify: `godot/scripts/combat/auto_weapon.gd` (estende `Weapon`, chiodi in `MultiMesh`, Raffica, Chiodi da ponte, Rimbalzanti, Incandescenti)
- Test: `godot/tests/weapons_tests.gd`

**Interfaces:**
- Consumes: `WeaponCatalog.stat`, `WeaponCatalog.find`
- Produces:
  - `class_name Weapon extends Node3D`: `weapon_id: StringName`, `level := 1`, `branches: Dictionary`, `shooter: Node3D`, `director: EnemyDirector`, `terrain_field: TerrainField`, `manual_aim := false`, `stat(key) -> float`, `has_branch(option_id: StringName) -> bool`, `set_level(new_level: int)`, `choose_branch(at_level: int, pick: StringName)`, virtuale `_apply_stats()`
  - `AutoWeapon` mantiene i campi esportati di oggi; con `weapon_id` vuoto (Torretta del compagno) si comporta come oggi.

- [ ] **Step 1: test che fallisce** (`weapons_tests.gd`): scena minima costruita da codice (director senza percorsi, come `actor_motion_tests.gd:215`): un `EnemyDirector` con `spawning = false`, un nemico fermo a 5 m, un tiratore `Node3D`. Controlli:
  - chiodatrice liv. 1 col catalogo: dopo 0,6 s il nemico ha preso 1 danno;
  - `set_level(2)` porta `fire_interval` a 0,4;
  - Raffica (`choose_branch(3, &"a")` dopo `set_level(3)`): `fire_interval` 0,2;
  - Chiodi da ponte: tre nemici in fila, un solo colpo li colpisce tutti e tre, 2 danni ciascuno;
  - Rimbalzanti: un muro di collisione (`StaticBody3D` con `BoxShape3D`) davanti, nemico dietro di lato: il chiodo che tocca il muro continua con direzione riflessa (`bounces` consumato);
  - Incandescenti: dopo l'impatto resta una macchia (`fire_patch_count() == 1`) e un nemico fermo nella macchia perde vita nei 2 s;
  - `AutoWeapon` senza `weapon_id` mantiene `fire_interval` impostato a mano (Torretta).
  - Nessun `MeshInstance3D` figlio per chiodo: `get_child_count()` resta costante sparando 20 colpi.

```gdscript
extends SceneTree
## Armi (spec D-092): danno, valori per livello, bivi che cambiano davvero il comportamento.
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/weapons_tests.gd

var _failures := 0
var _root: Node3D
var _director: EnemyDirector


func _initialize() -> void:
	_root = Node3D.new()
	get_root().add_child(_root)
	_director = EnemyDirector.new()
	_director.spawning = false
	_root.add_child(_director)
	await process_frame
	await _test_nailgun_base()
	await _test_nailgun_levels()
	await _test_bridge_pierces_all()
	await _test_ricochet()
	await _test_incendiary()
	await _test_legacy_turret()
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _enemy_at(p: Vector3, hp := 50) -> Enemy:
	var enemy := _director.spawn_at(p)
	enemy.health = hp
	enemy.max_health = hp
	enemy.speed_scale = 0.0
	return enemy


func _nailgun(at: Vector3) -> AutoWeapon:
	var shooter := Node3D.new()
	_root.add_child(shooter)
	shooter.global_position = at
	var weapon := AutoWeapon.new()
	weapon.weapon_id = &"nailgun"
	weapon.shooter = shooter
	weapon.director = _director
	_root.add_child(weapon)
	return weapon


func _seconds(s: float) -> void:
	for i in int(s * 60.0):
		await physics_frame


func _clear() -> void:
	_director.clear_horde()
	for child in _root.get_children():
		if child != _director:
			child.queue_free()
	await process_frame
```

(i sei test seguono lo schema: crea, `await _seconds(...)`, `_check`, `await _clear()`; i valori attesi sono quelli elencati sopra.)

- [ ] **Step 2: eseguire, deve fallire** (`weapon_id` non esiste).

- [ ] **Step 3: `weapon.gd`**

```gdscript
class_name Weapon
extends Node3D
## Base delle armi automatiche (spec D-092, par. 8): livello, bivi presi e valori letti da
## WeaponCatalog. Le sottoclassi rileggono i valori in `_apply_stats()`.

signal changed

@export var weapon_id: StringName
@export var shooter: Node3D
@export var director: EnemyDirector
@export var terrain_field: TerrainField
@export var manual_aim := false
var level := 1
## Bivi presi: {3: &"a"|&"b", 5: ...}.
var branches: Dictionary = {}


func _ready() -> void:
	if weapon_id != &"":
		_apply_stats()


func stat(key: StringName) -> float:
	return WeaponCatalog.stat(weapon_id, key, level, branches)


## Vero se il bivio [param option_id] (es. &"burst") e fra quelli presi.
func has_branch(option_id: StringName) -> bool:
	for at in branches:
		var options := WeaponCatalog.branch_options(weapon_id, at)
		var index := 0 if branches[at] == &"a" else 1
		if index < options.size() and options[index].id == option_id:
			return true
	return false


func set_level(new_level: int) -> void:
	level = clampi(new_level, 1, WeaponCatalog.MAX_LEVEL)
	_apply_stats()
	changed.emit()


func choose_branch(at_level: int, pick: StringName) -> void:
	branches[at_level] = pick
	_apply_stats()
	changed.emit()


func _apply_stats() -> void:
	pass
```

- [ ] **Step 4: `auto_weapon.gd`** — `extends Weapon`; togliere `@export var shooter/director/manual_aim` (ereditati); `_apply_stats()` copia `fire_interval`, `damage`, `weapon_range`, `pierce`, `projectiles`, `spread_degrees`, `projectile_speed` da `stat()` e legge `bounces`, `fire_patch`, `spread_jitter`. Chiodi: un `MultiMeshInstance3D` con `MAX_NAILS` istanze (`visible_instance_count` = chiodi vivi), dati in `_nails: Array[Dictionary]` senza nodo. Rimbalzo: se il raggio del tratto tocca il mondo e il chiodo ha `bounces > 0`, `direction = direction.bounce(Vector3(n.x, 0, n.z).normalized())` con `n = wall.normal`, `bounces -= 1`, il chiodo resta vivo dal punto d'impatto. Macchie di fuoco: `_patches: Array[Dictionary]` `{position, left}`, secondo `MultiMeshInstance3D` di dischi arancio emissivi (raggio 1 m), danno 1 ogni 0,5 s a `director.enemies_near(position, 1.0)`; `fire_patch_count() -> int`. Raffica: angolo casuale ±`spread_jitter` gradi su ogni colpo (rng del nodo, seme fisso 7 per i test). Commento di testa aggiornato (D-092, bivi).

- [ ] **Step 5: eseguire `weapons_tests.gd`** → PASS; eseguire `actor_motion_tests.gd`, `arena_run_tests.gd`, `companion_tests.gd` → PASS.

- [ ] **Step 6: commit** `Armi (D-092): base Weapon; chiodatrice dal catalogo con Raffica, Chiodi da ponte, Rimbalzanti, Incandescenti; chiodi in MultiMesh; test`

---

### Task 3: `ActiveWeapon`, `TerrainWriteQueue`, Picchetto sismico

**Files:**
- Create: `godot/scripts/terrain/terrain_write_queue.gd`
- Create: `godot/scripts/combat/active_weapon.gd`
- Create: `godot/scripts/combat/weapons/seismic_stake.gd`
- Test: `godot/tests/weapons_tests.gd` (nuovi casi), `godot/tests/terrain_write_queue_tests.gd`

**Interfaces:**
- Consumes: `Weapon`, `TerrainField.level/height_at/base_height_at/is_protected/begin_batch/end_batch`
- Produces:
  - `TerrainWriteQueue extends Node`: `terrain_field: TerrainField`, `push_level(center: Vector3, radius: float, target: float, strength := 1.0)`, `pending() -> int`, al massimo `WRITES_PER_STEP := 1` per passo fisico; raggio oltre `MAX_RADIUS := 2.5` viene limitato; punti protetti o fuori campo scartati.
  - `ActiveWeapon extends Weapon`: `cooldown_left: float`, `cooldown_total() -> float` (= `stat(&"cooldown")`), `can_trigger() -> bool`, `trigger() -> bool` (consuma la ricarica se possibile), `aim_point() -> Vector3`, `write_queue: TerrainWriteQueue`, virtuale `_fire(at: Vector3)`, segnale `triggered(at: Vector3)`.
  - `SeismicStake extends ActiveWeapon`: `ring_count() -> int` (anelli alzati vivi).

- [ ] **Step 1: test che falliscono**
  - `terrain_write_queue_tests.gd`: `TerrainField` headless (`render = false`, `size_m = Vector2(40, 40)`), 5 `push_level` → dopo 1 passo fisico `pending() == 4`, dopo 5 passi 0 e la quota al centro di ogni disco vicina al bersaglio; un punto protetto (`set_protected`) non cambia; raggio 6 viene ridotto a 2,5 (la quota a 4 m dal centro non cambia).
  - `weapons_tests.gd` nuovi casi: Picchetto con tiratore che guarda verso -Z, `manual_aim = true`: `trigger()` vero, subito dopo `can_trigger()` falso e `cooldown_left` ~15; dopo `raise_delay` e lo svuotamento della coda, la quota sull'anello (raggio 3 dal punto mirato) e sopra 1,0 m rispetto alla base e al centro resta sotto 0,3; con `hold_seconds` a 0,5 (valore impostato nel test) l'anello torna sotto 0,2; con il bivio `permanent` non torna giu; con `shock` un nemico sull'anello perde 3 PV; in mira automatica il punto mirato e il centro del gruppo di 4 nemici, non quello del nemico isolato.

- [ ] **Step 2: eseguire, devono fallire.**

- [ ] **Step 3: `terrain_write_queue.gd`**

```gdscript
class_name TerrainWriteQueue
extends Node
## Coda delle scritture delle armi sul terreno (spec D-092, par. 8-9): al piu WRITES_PER_STEP
## pennellate per passo fisico, raggio limitato, punti protetti o fuori campo scartati. Un anello
## del picchetto (12 dischi) sale cosi in 12 passi: si vede crescere e non pesa su un solo frame.

const WRITES_PER_STEP := 1
const MAX_RADIUS := 2.5

var terrain_field: TerrainField
var _jobs: Array[Dictionary] = []


func _ready() -> void:
	process_physics_priority = -10


func push_level(center: Vector3, radius: float, target: float, strength := 1.0) -> void:
	if terrain_field == null or terrain_field.is_protected(center):
		return
	var half := terrain_field.half_extents()
	if absf(center.x) > half.x or absf(center.z) > half.y:
		return
	_jobs.append({center = center, radius = minf(radius, MAX_RADIUS), target = target, strength = strength})


func pending() -> int:
	return _jobs.size()


func clear() -> void:
	_jobs.clear()


func _physics_process(_delta: float) -> void:
	if _jobs.is_empty() or terrain_field == null:
		return
	terrain_field.begin_batch()
	for i in mini(WRITES_PER_STEP, _jobs.size()):
		var job: Dictionary = _jobs.pop_front()
		terrain_field.level(job.center, job.radius, job.target, job.strength)
	terrain_field.end_batch()
```

- [ ] **Step 4: `active_weapon.gd`**

```gdscript
class_name ActiveWeapon
extends Weapon
## Base delle armi attive su tasto (spec D-092, par. 3): ricarica a tempo, punto di mira secondo
## la mira manuale (davanti a chi spara, alla portata) o automatica (centro del gruppo piu fitto).

signal triggered(at: Vector3)

## Lato della griglia con cui si contano i gruppi di nemici per la mira automatica.
const CLUSTER_CELL := 2.0

var write_queue: TerrainWriteQueue
var cooldown_left := 0.0


func cooldown_total() -> float:
	return stat(&"cooldown")


func can_trigger() -> bool:
	return cooldown_left <= 0.0 and shooter != null and not get_tree().paused


func trigger() -> bool:
	if not can_trigger():
		return false
	cooldown_left = cooldown_total()
	var at := aim_point()
	_fire(at)
	triggered.emit(at)
	changed.emit()
	return true


func aim_point() -> Vector3:
	var reach := stat(&"aim_range")
	var origin := shooter.global_position
	if not manual_aim and director != null:
		var cluster := densest_cluster(origin, reach)
		if cluster != null:
			return cluster
	var forward: Vector3 = shooter.facing_direction() if shooter.has_method(&"facing_direction") else -shooter.global_basis.z
	return origin + Vector3(forward.x, 0.0, forward.z).normalized() * reach * (1.0 if manual_aim else 0.5)


## Centro (media) dei nemici della cella di CLUSTER_CELL metri piu affollata entro [param reach].
func densest_cluster(origin: Vector3, reach: float) -> Variant:
	var cells: Dictionary = {}
	for enemy in director.enemies_near(origin, reach):
		if enemy.is_dead:
			continue
		var key := Vector2i(floori(enemy.global_position.x / CLUSTER_CELL), floori(enemy.global_position.z / CLUSTER_CELL))
		var cell: Array = cells.get_or_add(key, [])
		cell.append(enemy.global_position)
	var best: Array = []
	for key in cells:
		if (cells[key] as Array).size() > best.size():
			best = cells[key]
	if best.is_empty():
		return null
	var sum := Vector3.ZERO
	for p: Vector3 in best:
		sum += p
	var center := sum / best.size()
	return Vector3(center.x, origin.y, center.z)


func _physics_process(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(cooldown_left - delta, 0.0)


func _fire(_at: Vector3) -> void:
	pass
```

- [ ] **Step 5: `weapons/seismic_stake.gd`** — `class_name SeismicStake extends ActiveWeapon`. `_fire(at)`: aggiunge `{center, raise_left = raise_delay, hold_left = hold_seconds, raised = false}` a `_rings` e un paletto visivo (`MeshInstance3D` cilindro 0,08x1,2 m, colore di classe). Ogni passo: quando `raise_left` scade mette in coda 12 dischi (`push_level(p, ring_width + 0.1, base_height_at(p) + ring_height)` su `ring_radius`, angoli di 30°), con `shock` fa `shock_damage` ai nemici a meno di `ring_width` dall'anello e chiama `director.shove_from(center, ring_radius + 1.0, 9.0)`; con `spiked` ogni 0,6 s 1 danno ai nemici a meno di `ring_width + 0.3` dall'anello; quando `hold_left` scade e non e `permanent`, mette in coda i dischi che riportano alla base (`push_level(p, ..., base_height_at(p))`). `ring_count()`. Polvere: un `GPUParticles3D` breve per anello (con `DisplayServer` headless saltato).

- [ ] **Step 6: eseguire le due suite** → PASS.

- [ ] **Step 7: commit** `Armi (D-092): ActiveWeapon con mira manuale o al gruppo piu fitto, TerrainWriteQueue, Picchetto sismico coi bivi; test`

---

### Task 4: `WeaponLoadout`, comandi attivi, integrazione in `ArenaRun`

**Files:**
- Create: `godot/scripts/combat/weapon_loadout.gd`
- Modify: `godot/scripts/player/player_character.gd` (azioni `weapon_active_1/2`, segnale `active_weapon_pressed(slot: int)`)
- Modify: `godot/project.godot` (azioni nuove)
- Modify: `godot/scripts/services/run_launch_options.gd` (`--class=`)
- Modify: `godot/scripts/run/arena_run.gd` (creazione del loadout, classe, mira, via i rami `nail_*`)
- Test: `godot/tests/loadout_tests.gd`, `godot/tests/input_events_tests.gd` (caso nuovo)

**Interfaces:**
- Consumes: `Weapon`, `ActiveWeapon`, `ClassCatalog.start_weapons`, `TerrainWriteQueue`
- Produces:
  - `WeaponLoadout extends Node`: costanti `AUTO_SLOTS := 3`, `ACTIVE_SLOTS := 2`; campi `player: PlayerCharacter`, `director`, `terrain_field`, `class_id: StringName`, `write_queue: TerrainWriteQueue`; `adopt(weapon: Weapon)` (il `PlayerWeapon` della scena); `setup_class(id: StringName)`; `has_weapon(id) -> bool`; `weapon(id) -> Weapon`; `level_of(id) -> int`; `autos() -> Array[Weapon]`; `actives() -> Array[ActiveWeapon]`; `free_slots(slot: StringName) -> int`; `add(id) -> Weapon`; `level_up(id) -> int`; `needs_branch(id) -> bool` (prossimo livello e 3 o 5); `choose_branch(id, pick)` (sale di livello e fissa il bivio); `trigger_active(slot: int) -> bool`; `set_manual_aim(on: bool)`; segnali `changed`, `active_triggered(slot: int, at: Vector3)`.
  - `PlayerCharacter.active_weapon_pressed(slot: int)` (0 o 1).
  - `RunLaunchOptions.class_id(args) -> StringName` (vuoto se assente).

- [ ] **Step 1: test che falliscono** (`loadout_tests.gd`, headless con nodi minimi come in `weapons_tests.gd`):
  - `setup_class(&"engineer")` con `adopt(chiodatrice)`: `has_weapon(&"nailgun")`, `has_weapon(&"seismic_stake")`, `free_slots(&"auto") == 2`, `free_slots(&"active") == 1`;
  - `setup_class(&"sapper")`: nessuna arma, la chiodatrice adottata e spenta (`process_mode == PROCESS_MODE_DISABLED`, `visible == false`);
  - `level_up(&"nailgun")` → 2; `needs_branch(&"nailgun")` vero; `choose_branch(&"nailgun", &"a")` → livello 3, `branches[3] == &"a"`; oltre il 5 `level_up` resta 5;
  - `trigger_active(0)` vero con il picchetto carico, falso subito dopo; `trigger_active(1)` falso (slot vuoto); con `get_tree().paused = true` falso e la ricarica non cambia;
  - `set_manual_aim(true)` arriva a tutte le armi.
  - `input_events_tests.gd`: un `InputEventKey` E premuto produce `active_weapon_pressed(0)` al passo successivo; F produce 1; un `InputEventJoypadMotion` LT oltre la soglia una sola volta finche non torna sotto.

- [ ] **Step 2: eseguire, devono fallire.**

- [ ] **Step 3: `project.godot`** — azioni `weapon_active_1` (tasto fisico E = 69; asse joypad 4, valore 1.0, deadzone 0.5) e `weapon_active_2` (tasto fisico F = 70; pulsante joypad 10), nello stesso formato di `weapon_aim_mode`.

- [ ] **Step 4: `player_character.gd`** — `signal active_weapon_pressed(slot: int)`; `STARTED_ACTIONS` + `&"weapon_active_1"`, `&"weapon_active_2"`; in `_run_pending_actions` emettere il segnale con slot 0/1.

- [ ] **Step 5: `weapon_loadout.gd`** — implementazione degli interface sopra. `add(id)`: crea il nodo dallo script dell'arma (`WEAPON_SCRIPTS: Dictionary[StringName, Script] = {&"nailgun": AutoWeapon, &"seismic_stake": SeismicStake}`), imposta `weapon_id`, `shooter = player`, `director`, `terrain_field`, `manual_aim`, per le attive `write_queue`; lo aggiunge come figlio del loadout. La chiodatrice adottata non viene ricreata. `_ready` collega `player.active_weapon_pressed` a `trigger_active`. Stampa `PROTOTYPE01_WEAPON_ADDED id=%s` e `PROTOTYPE01_WEAPON_LEVEL id=%s level=%d branch=%s`.

- [ ] **Step 6: `run_launch_options.gd`** — `class_id()` legge `--class=`; aggiungere `"--class="` ad `AUTOSTART_PREFIXES`.

- [ ] **Step 7: `arena_run.gd`** — `var loadout: WeaponLoadout`, `var class_id: StringName`; in `_ready`, dopo l'impostazione di `weapon`: `weapon.weapon_id = &"nailgun"` (i valori di `tuning` restano solo per la Torretta), creare `TerrainWriteQueue` e `WeaponLoadout` come figli di `get_parent()` (aggiunta differita come la Torretta), `loadout.adopt(weapon)`, `loadout.setup_class(class_id)`; `class_id` = `RunLaunchOptions.class_id()` o `ClassCatalog.DEFAULT`; `_on_aim_mode_changed` chiama `loadout.set_manual_aim`; in `apply_upgrade` togliere i rami `nail_rate`, `nail_pierce`, `nail_spread`. Stampa `PROTOTYPE01_CLASS id=%s` accanto a `PROTOTYPE01_RUN_START`.

- [ ] **Step 8: eseguire** `loadout_tests.gd`, `input_events_tests.gd`, `arena_run_tests.gd`, `boss_tests.gd`, `companion_tests.gd` → PASS. Smoke: `godot_console --headless --path godot --quit-after 600 -- --autostart --class=sapper` senza errori.

- [ ] **Step 9: commit** `Armi (D-092): WeaponLoadout con slot, livelli e bivi; comandi E/F e LT/RB per le attive; classe da --class=; test`

---

### Task 5: carte arma — `WeaponOffers`, mazzi in `RunProgression`, schermata del bivio

**Files:**
- Create: `godot/scripts/progression/weapon_offers.gd`
- Modify: `godot/scripts/progression/run_progression.gd` (mazzo di classe, provider delle carte arma, carta arma per prima)
- Modify: `godot/scripts/ui/level_up_menu.gd` (titolo e sottotitolo impostabili, livello mostrato dalla carta)
- Modify: `godot/scripts/run/arena_run.gd` (scelta delle carte arma, bivio in coda)
- Test: `godot/tests/weapon_offers_tests.gd`, `godot/tests/run_progression_tests.gd`, `godot/tests/arena_run_tests.gd`

**Interfaces:**
- Consumes: `WeaponLoadout.has_weapon/level_of/free_slots/needs_branch`, `ClassCatalog`, `WeaponCatalog`
- Produces:
  - carta arma: `{id = &"w:<kind>:<weapon_id>", name, category = &"weapon", rarity, max_level = 0, requires = "", deck, text, weapon_id, kind (&"new"|&"level"|&"branch"), shown_level: int}`; carta di trasformazione: `{id = &"wb:<weapon_id>:<at>:<a|b>", ...}`
  - `WeaponOffers.cards(loadout: WeaponLoadout, class_id: StringName, unlocked: Array[StringName]) -> Array[Dictionary]`
  - `WeaponOffers.branch_cards(weapon_id: StringName, at_level: int) -> Array[Dictionary]`
  - `WeaponOffers.parse(id: StringName) -> Dictionary` (`{kind, weapon_id, at, pick}`)
  - `RunProgression.class_id: StringName`, `RunProgression.weapon_cards: Callable` (restituisce `Array[Dictionary]`)
  - `LevelUpMenu.open(offer, levels, player_level, title := "", subtitle := "")`

- [ ] **Step 1: test che falliscono**
  - `weapon_offers_tests.gd`: con l'Ingegnere appena partito → carte `level` per chiodatrice e picchetto, nessuna `new` (nessun'altra arma del suo mazzo o comune sbloccata), nessuna carta di altre classi; chiodatrice al 2 → la sua carta e `branch`, Rara; chiodatrice al 5 → nessuna carta per lei; `branch_cards(&"nailgun", 3)` → due carte `wb:nailgun:3:a/b` coi nomi Raffica e Chiodi da ponte; `parse` restituisce i campi giusti.
  - `run_progression_tests.gd`: con `class_id = &"engineer"` in 500 offerte nessuna carta con `deck` di un'altra classe; con `weapon_cards` che restituisce una carta, la prima carta dell'offerta e sempre quella; regole esistenti (distinte, seme, pieta) ancora vere.
  - `arena_run_tests.gd`: scegliere la carta `branch` della chiodatrice apre una seconda schermata con due carte e titolo "CHIODATRICE"; il livello della chiodatrice sale solo dopo la seconda scelta; due level-up in coda: dopo il bivio si apre il secondo level-up (`_pending_level_ups` scende di 1 per il bivio).

- [ ] **Step 2: eseguire, devono fallire.**

- [ ] **Step 3: `weapon_offers.gd`** — rarita: `new` Non comune, `level` Comune, `branch` Raro (fusione nel piano 2). Testo della carta `level`: `level_texts[next]`; della carta `new`: `text` del catalogo; della carta `branch`: "Scegli una trasformazione." Un'arma e candidata `new` se il suo `deck` e `common` o `class_id`, non e posseduta, ha `unlock_cost == 0` o e in `unlocked`, e c'e uno slot libero del suo tipo.

- [ ] **Step 4: `run_progression.gd`** — `eligible()` scarta le carte con `deck` diverso da `common` e da `class_id`; `roll_offer()`: se `weapon_cards` e valido e restituisce carte, la prima carta e scelta fra quelle (pesata per rarita, rispettando la pieta), poi le altre due dal resto con la regola delle categorie e la preferenza per il mazzo di classe sulla seconda; `choose()` non e chiamato per le carte arma.

- [ ] **Step 5: `level_up_menu.gd`** — parametri `title`/`subtitle` (default "LIVELLO %d" e "scegli un pezzo"); in `_make_card` il livello mostrato e `upgrade.get(&"shown_level", current_level)`; icona: `upgrade.get(&"icon", UiIcon.for_category(upgrade.category))`.

- [ ] **Step 6: `arena_run.gd`** — `progression.class_id = class_id`; `progression.weapon_cards = func(): return WeaponOffers.cards(loadout, class_id, [])`; `_on_upgrade_chosen(id)`: se `id` inizia con `w:` o `wb:` passa a `_on_weapon_card(id)`: `new` → `loadout.add`, `level` → `loadout.level_up`, `branch` → `level_up_menu.open(WeaponOffers.branch_cards(...), {}, 0, nome.to_upper(), "scegli una trasformazione")` senza scalare `_pending_level_ups`, `wb:` → `loadout.choose_branch` e poi la coda come oggi.

- [ ] **Step 7: eseguire le tre suite** → PASS; `simulate_runs.gd`: liste di preferenza con `&"w:level:nailgun"`, `&"w:branch:nailgun"` al posto delle `nail_*`, e la scelta della trasformazione A; eseguire una simulazione breve (`-- --runs=1`) senza errori.

- [ ] **Step 8: commit** `Armi (D-092): carte arma (nuova, livello, bivio) da WeaponOffers, mazzi di classe nel level-up, schermata del bivio; bot aggiornati; test`

---

### Task 6: striscia delle armi nel HUD e icona del picchetto

**Files:**
- Create: `godot/scripts/ui/weapon_strip.gd`
- Modify: `godot/scripts/ui/ui_icon.gd` (tipo `stake`)
- Modify: `godot/scripts/ui/run_hud.gd` (striscia, comandi delle attive nella riga dei comandi)
- Modify: `godot/scripts/run/arena_run.gd` (collegare `loadout.changed` alla striscia, ricarica a ogni passo)
- Test: `godot/tests/hud_weapon_tests.gd`

**Interfaces:**
- Consumes: `WeaponLoadout.autos/actives/changed`, `ActiveWeapon.cooldown_left/cooldown_total`
- Produces: `WeaponStrip extends PanelContainer`: `set_slots(autos: Array[Dictionary], actives: Array[Dictionary])` con voci `{icon, level, branches: String ("A", "AB"...), cooldown: float 0..1}`; `slot_text(i) -> String` per i test; `RunHud.set_weapons(autos, actives)`.

- [ ] **Step 1: test che fallisce** — HUD istanziato da solo: `set_weapons` con chiodatrice liv. 3 bivio A e picchetto a meta ricarica → tre slot automatici (uno pieno, due vuoti), due attivi (uno con ricarica 0,5, uno vuoto con il prompt E/F o LT/RB), `slot_text(0)` contiene "3" e "A".
- [ ] **Step 2: eseguire, deve fallire.**
- [ ] **Step 3: implementare** `WeaponStrip`: pannello `strip` del tema, in basso a destra (`PRESET_BOTTOM_RIGHT`, margine 24; la riga dei comandi occupa gia il basso a sinistra), slot da 52 px: `UiIcon`, 5 tacche, lettere dei bivi, per gli attivi uno spicchio scuro (`draw_arc` pieno) proporzionale alla ricarica e il `ButtonPrompts` dell'azione. `UiIcon` `stake`: paletto con punta e cerchio a terra. Riga dei comandi: `[&"weapon_active_1", "Attiva 1"], [&"weapon_active_2", "Attiva 2"]`.
- [ ] **Step 4: eseguire** `hud_weapon_tests.gd`, `ui_theme_tests.gd`, `button_prompts_tests.gd` → PASS.
- [ ] **Step 5: commit** `Armi (D-092): striscia delle armi nel HUD con livelli, bivi e ricarica; icona del picchetto; test`

---

### Task 7: verifica finale, benchmark, catture, documenti

**Files:**
- Modify: `docs/MIGRATION_STATUS.md`, `docs/PROJECT_ROADMAP.md` (Stato operativo), `docs/DECISIONS.md` (D-092: avanzamento), `docs/INDEX.md` (questo piano), `docs/GODOT_WORKFLOW.md` (`--class=`)
- Create: `godot/tests/tools/capture_weapons.gd` (catture in `output/weapons/`)

- [ ] **Step 1: gate completo** `powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1` → `GODOT_CHECKS PASS`.
- [ ] **Step 2: benchmark** prima (sul commit di partenza, `git stash` non serve: si misura su `66eaaf4` in un worktree) e dopo, `--enemies=70 --preset=deck`; differenza del passo sotto 1,0 ms.
- [ ] **Step 3: catture** `capture_weapons.gd`: chiodatrice base e con ciascun bivio, picchetto che sale e anello alzato con nemici dentro, HUD con le due armi, schermata del bivio.
- [ ] **Step 4: documenti** aggiornati; commit `Armi (D-092): piano 1 chiuso; gate, benchmark e catture; documenti`.
