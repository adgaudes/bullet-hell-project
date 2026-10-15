class_name WeaponLoadout
extends Node
## Slot delle armi del giocatore (spec D-092, par. 3 e 8): 3 automatiche e 2 attive. Parte col
## kit della classe (ClassCatalog), aggiunge armi, le fa salire di livello e sceglie i bivi
## (ai livelli 3 e 5 si sale solo scegliendo una trasformazione). Adotta la chiodatrice gia
## presente nella scena (`PlayerWeapon`) invece di crearne una seconda; se la classe non la
## usa la spegne. Riceve dal giocatore la pressione dei tasti delle attive.

signal changed
signal active_triggered(slot: int, at: Vector3)

const AUTO_SLOTS := 3
const ACTIVE_SLOTS := 2

var player: Node3D
var director: EnemyDirector
var terrain_field: TerrainField
var write_queue: TerrainWriteQueue
var class_id: StringName
## La chiodatrice della scena: entra negli slot solo se la classe la usa.
var adopted: Weapon
var manual_aim := false
var _autos: Array[Weapon] = []
var _actives: Array[ActiveWeapon] = []


func _ready() -> void:
	if player != null and player.has_signal(&"active_weapon_pressed"):
		player.active_weapon_pressed.connect(trigger_active)


## Script di ogni arma del catalogo; null se l'arma non e ancora implementata.
static func script_for(id: StringName) -> Script:
	match id:
		&"nailgun":
			return AutoWeapon
		&"seismic_stake":
			return SeismicStake
		&"site_blade":
			return SiteBlade
		&"jackhammer":
			return Jackhammer
		&"ram":
			return Ram
		&"cement_mixer":
			return CementMixer
	return null


## La chiodatrice della scena (senza `weapon_id` diventa la chiodatrice del catalogo).
func adopt(weapon: Weapon) -> void:
	adopted = weapon
	if weapon.weapon_id == &"":
		weapon.weapon_id = &"nailgun"
	weapon.set_level(1)
	_set_enabled(weapon, false)


func setup_class(id: StringName) -> void:
	class_id = id
	for weapon_id in ClassCatalog.start_weapons(id):
		add(weapon_id)
	print("PROTOTYPE01_LOADOUT class=%s weapons=%s" % [id, ",".join(PackedStringArray(all_ids()))])


func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for weapon: Weapon in _autos + _actives:
		ids.append(weapon.weapon_id)
	return ids


func has_weapon(id: StringName) -> bool:
	return weapon(id) != null


func weapon(id: StringName) -> Weapon:
	for w: Weapon in _autos + _actives:
		if w.weapon_id == id:
			return w
	return null


func level_of(id: StringName) -> int:
	var w := weapon(id)
	return w.level if w != null else 0


func autos() -> Array[Weapon]:
	return _autos.duplicate()


func actives() -> Array[ActiveWeapon]:
	return _actives.duplicate()


func free_slots(slot: StringName) -> int:
	return AUTO_SLOTS - _autos.size() if slot == &"auto" else ACTIVE_SLOTS - _actives.size()


## Aggiunge l'arma al livello 1; null se sconosciuta, non implementata, gia presa o senza slot.
func add(id: StringName) -> Weapon:
	var entry := WeaponCatalog.find(id)
	if entry.is_empty() or entry.slot == &"fusion" or has_weapon(id) or free_slots(entry.slot) <= 0:
		return null
	var w: Weapon
	if adopted != null and adopted.weapon_id == id:
		w = adopted
		_set_enabled(w, true)
	else:
		var script := script_for(id)
		if script == null:
			return null
		w = script.new()
		w.weapon_id = id
		w.name = "Weapon_%s" % id
		add_child(w)
	w.shooter = player
	w.director = director
	w.terrain_field = terrain_field
	w.manual_aim = manual_aim
	if &"write_queue" in w:
		w.set(&"write_queue", write_queue)
	if w is ActiveWeapon:
		var active := w as ActiveWeapon
		active.triggered.connect(func(at: Vector3) -> void: active_triggered.emit(_actives.find(active), at))
		_actives.append(active)
	else:
		_autos.append(w)
	w.changed.connect(changed.emit)
	print("PROTOTYPE01_WEAPON_ADDED id=%s" % id)
	changed.emit()
	return w


## Sale di un livello (2 o 4); al bivio o al massimo resta dov'e. Restituisce il livello.
func level_up(id: StringName) -> int:
	var w := weapon(id)
	if w == null:
		return 0
	if w.level >= WeaponCatalog.MAX_LEVEL or needs_branch(id):
		return w.level
	w.set_level(w.level + 1)
	_log_level(w)
	return w.level


## Vero se il prossimo livello dell'arma e un bivio (3 o 5).
func needs_branch(id: StringName) -> bool:
	var w := weapon(id)
	return w != null and w.level < WeaponCatalog.MAX_LEVEL and WeaponCatalog.BRANCH_LEVELS.has(w.level + 1)


## Sale al bivio scegliendo la trasformazione [param pick] (&"a" o &"b").
func choose_branch(id: StringName, pick: StringName) -> void:
	if not needs_branch(id):
		return
	var w := weapon(id)
	var at := w.level + 1
	w.branches[at] = pick
	w.set_level(at)
	_log_level(w)


## Usa l'attiva dello slot [param slot] (0 o 1); vero se e partita.
func trigger_active(slot: int) -> bool:
	if slot < 0 or slot >= _actives.size():
		return false
	return _actives[slot].trigger()


func set_manual_aim(on: bool) -> void:
	manual_aim = on
	for w: Weapon in _autos + _actives:
		w.manual_aim = on


func _log_level(w: Weapon) -> void:
	print("PROTOTYPE01_WEAPON_LEVEL id=%s level=%d branches=%s" % [w.weapon_id, w.level, w.branches])


static func _set_enabled(w: Weapon, on: bool) -> void:
	w.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	w.visible = on
