class_name Weapon
extends Node3D
## Base delle armi (spec D-092, par. 8): livello, bivi presi e valori letti da WeaponCatalog.
## Le sottoclassi rileggono i valori in `_apply_stats()`. Senza `weapon_id` (la Torretta del
## compagno) l'arma usa i valori impostati a mano.

signal changed

@export var weapon_id: StringName
@export var shooter: Node3D
@export var director: EnemyDirector
@export var terrain_field: TerrainField
## Mira manuale (D-089): l'arma segue chi spara invece di cercare il bersaglio da sola.
@export var manual_aim := false
var level := 1
## Bivi presi: {3: &"a"|&"b", 5: ...}.
var branches: Dictionary = {}


func _ready() -> void:
	if weapon_id != &"":
		_apply_stats()


func stat(key: StringName) -> float:
	return WeaponCatalog.stat(weapon_id, key, level, branches)


## Vero se la trasformazione [param option_id] (es. &"burst") e fra quelle prese.
func has_branch(option_id: StringName) -> bool:
	for at: int in branches:
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
