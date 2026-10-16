class_name MachineModule
extends Node3D
## Modulo di una macchina della carovana (spec D-093, Sezione 1): nodo figlio della Machine,
## che ne chiama `tick` a ogni passo fisico finche il modulo e attivo. Da solo e il modulo
## inerte dei tipi che non hanno ancora uno script (piano A: arrivano nei task 4 e 8).
## I servizi li passa la carovana dopo `add_child`, alle proprieta con lo stesso nome (come
## WeaponLoadout.give_services): nel `_ready` del modulo sono ancora null.

var module_id: StringName
var machine: Machine
var caravan: Caravan
var level := 0
## Un modulo spento non fa `tick` e non chiede mete (la macchina guasta, il Faro di giorno).
var active := true

# --- Servizi (dalla carovana) ---
var player: PlayerCharacter
var director: EnemyDirector
var terrain_field: TerrainField
var write_queue: TerrainWriteQueue
var scrap_field: ScrapField
var xp_field: XpField
var light_field: LightField
var path_field: PathField
var run_tuning: RunTuning


## Un passo fisico del modulo, dopo il movimento della macchina.
func tick(_delta: float) -> void:
	pass


## Punto in cui il modulo vuole portare la macchina, o null (la macchina tiene il suo posto).
func wanted_destination() -> Variant:
	return null


## Pezzo visibile da montare sulla macchina (Machine.mount_part), o null.
func build_part() -> Node3D:
	return null


## Livello del tipo di modulo (carte di livello): vale per tutti i moduli del tipo.
func apply_level(new_level: int) -> void:
	level = new_level


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	_on_active_changed(on)


func _on_active_changed(_on: bool) -> void:
	pass
