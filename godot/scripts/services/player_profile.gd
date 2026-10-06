class_name PlayerProfileService
extends Node
## Profilo permanente del giocatore (D-049): rottami in Officina, upgrade
## permanenti comprati, run giocate e vinte. Salvato in `user://profile.cfg`,
## separato dalle impostazioni. Registrato come autoload `PlayerProfile`; gli
## altri script lo raggiungono con `get_node("/root/PlayerProfile")` tipizzato
## `PlayerProfileService` (il nome globale non esiste in --check-only ne nei test).

signal changed

const DEFAULT_PATH := "user://profile.cfg"

## Percorso del salvataggio; vuoto = non si salva (test).
var profile_path := DEFAULT_PATH
## Rottami da spendere in Officina.
var scrap := 0
## Livello di ogni upgrade permanente posseduto.
var levels: Dictionary[StringName, int] = {}
var runs := 0
var victories := 0
## Livelli di campagna sbloccati (per ora ne esiste uno solo).
var levels_unlocked := 1


func _init() -> void:
	# Sotto i test (SceneTree con script) si parte da un profilo vuoto e non si
	# scrive nulla: il profilo reale del giocatore non deve cambiare ne falsare i test.
	# Deciso gia qui: un test puo usare il profilo prima del primo frame.
	var main_loop := Engine.get_main_loop()
	if main_loop != null and main_loop.get_script() != null:
		profile_path = ""


func _ready() -> void:
	if not profile_path.is_empty():
		load_profile()


func reset() -> void:
	scrap = 0
	levels.clear()
	runs = 0
	victories = 0
	levels_unlocked = 1


func level_of(id: StringName) -> int:
	return levels.get(id, 0)


## Costo del prossimo livello di [param id]; -1 se e al massimo o non esiste.
func cost_of(id: StringName) -> int:
	var entry := PermanentCatalog.find(id)
	if entry.is_empty() or level_of(id) >= (entry.costs as Array).size():
		return -1
	return entry.costs[level_of(id)]


func can_buy(id: StringName) -> bool:
	var cost := cost_of(id)
	return cost >= 0 and scrap >= cost


## Compra il prossimo livello; false se e al massimo o i rottami non bastano.
func buy(id: StringName) -> bool:
	if not can_buy(id):
		return false
	scrap -= cost_of(id)
	levels[id] = level_of(id) + 1
	print("PROTOTYPE01_PERMANENT_BOUGHT id=%s level=%d scrap=%d" % [id, levels[id], scrap])
	save_profile()
	changed.emit()
	return true


## Fine di un livello: incassa i rottami portati fuori.
func bank_run(scrap_out: int, victory: bool) -> void:
	scrap += maxi(scrap_out, 0)
	runs += 1
	if victory:
		victories += 1
		levels_unlocked = maxi(levels_unlocked, 2)
	print("PROTOTYPE01_PROFILE_BANKED scrap_out=%d total=%d runs=%d victories=%d" % [scrap_out, scrap, runs, victories])
	save_profile()
	changed.emit()


## Carica un file; valori assenti o non validi diventano quelli di un profilo nuovo.
func load_profile(path_override: String = "") -> Error:
	if not path_override.is_empty():
		profile_path = path_override
	reset()
	if profile_path.is_empty():
		return OK
	var config := ConfigFile.new()
	var error := config.load(profile_path)
	if error == ERR_FILE_NOT_FOUND:
		return OK
	if error != OK:
		return error
	scrap = _validated_count(config.get_value("profile", "scrap", 0))
	runs = _validated_count(config.get_value("profile", "runs", 0))
	victories = _validated_count(config.get_value("profile", "victories", 0))
	levels_unlocked = maxi(_validated_count(config.get_value("profile", "levels_unlocked", 1)), 1)
	for entry in PermanentCatalog.all():
		var id: StringName = entry.id
		var level := mini(_validated_count(config.get_value("upgrades", String(id), 0)), (entry.costs as Array).size())
		if level > 0:
			levels[id] = level
	return OK


func save_profile(path_override: String = "") -> Error:
	if not path_override.is_empty():
		profile_path = path_override
	if profile_path.is_empty():
		return OK
	var config := ConfigFile.new()
	config.set_value("profile", "scrap", scrap)
	config.set_value("profile", "runs", runs)
	config.set_value("profile", "victories", victories)
	config.set_value("profile", "levels_unlocked", levels_unlocked)
	for id: StringName in levels:
		config.set_value("upgrades", String(id), levels[id])
	return config.save(profile_path)


static func _validated_count(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return maxi(value, 0)
	if typeof(value) == TYPE_FLOAT and not is_nan(value):
		return maxi(int(value), 0)
	return 0
