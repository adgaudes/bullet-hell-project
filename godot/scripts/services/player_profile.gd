class_name PlayerProfileService
extends Node
## Profilo permanente del giocatore (D-049): rottami in Officina, upgrade
## permanenti comprati, run giocate e vinte. Salvato in `user://profile.cfg`,
## separato dalle impostazioni. Registrato come autoload `PlayerProfile`; gli
## altri script lo raggiungono con `get_node("/root/PlayerProfile")` tipizzato
## `PlayerProfileService` (il nome globale non esiste in --check-only ne nei test).

signal changed

const DEFAULT_PATH := "user://profile.cfg"
## Versione del file (R-19): un profilo di versione piu alta viene letto per quello che si
## capisce; le voci sconosciute si conservano e si riscrivono, non si perdono.
const VERSION := 1

## Percorso del salvataggio; vuoto = non si salva (test).
var profile_path := DEFAULT_PATH
## Rottami da spendere in Officina.
var scrap := 0
## Livello di ogni upgrade permanente posseduto.
var levels: Dictionary[StringName, int] = {}
var runs := 0
var victories := 0
## Livelli di campagna sbloccati: i primi N del LevelCatalog (D-066).
var levels_unlocked := 1
## Id dei livelli completati almeno una volta.
var completed_levels: PackedStringArray = []
## Esito dell'ultimo salvataggio (R-18): OK, oppure l'errore che i pannelli possono mostrare.
var last_save_error := OK
## Versione letta dal file (0 = file senza versione o assente).
var loaded_version := 0
## Upgrade con id non in catalogo (file di una versione diversa): conservati tali e quali.
var _unknown_upgrades: Dictionary[String, int] = {}


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
	completed_levels.clear()
	_unknown_upgrades.clear()


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


func has_completed(level_id: StringName) -> bool:
	return completed_levels.has(String(level_id))


## Fine di un livello: incassa i rottami portati fuori. Una vittoria sblocca il livello
## successivo a [param level_index] (da 0) e segna [param level_id] come completato.
## Restituisce l'esito del salvataggio (F-03): il chiamante lo mostra, lo stato in memoria
## resta aggiornato comunque.
func bank_run(scrap_out: int, victory: bool, level_index := 0, level_id: StringName = &"") -> Error:
	scrap += maxi(scrap_out, 0)
	runs += 1
	if victory:
		victories += 1
		levels_unlocked = maxi(levels_unlocked, level_index + 2)
		if not level_id.is_empty() and not completed_levels.has(String(level_id)):
			completed_levels.append(String(level_id))
	print("PROTOTYPE01_PROFILE_BANKED scrap_out=%d total=%d runs=%d victories=%d" % [scrap_out, scrap, runs, victories])
	var error := save_profile()
	changed.emit()
	return error


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
	loaded_version = _validated_count(config.get_value("profile", "version", 0))
	scrap = _validated_count(config.get_value("profile", "scrap", 0))
	runs = _validated_count(config.get_value("profile", "runs", 0))
	victories = _validated_count(config.get_value("profile", "victories", 0))
	levels_unlocked = maxi(_validated_count(config.get_value("profile", "levels_unlocked", 1)), 1)
	var completed: Variant = config.get_value("profile", "completed_levels", PackedStringArray())
	if completed is PackedStringArray or completed is Array:
		for item in completed:
			if item is String and not completed_levels.has(item):
				completed_levels.append(item)
	for entry in PermanentCatalog.all():
		var id: StringName = entry.id
		var level := mini(_validated_count(config.get_value("upgrades", String(id), 0)), (entry.costs as Array).size())
		if level > 0:
			levels[id] = level
	if config.has_section("upgrades"):
		for key in config.get_section_keys("upgrades"):
			if PermanentCatalog.find(StringName(key)).is_empty():
				_unknown_upgrades[key] = _validated_count(config.get_value("upgrades", key, 0))
	return OK


func save_profile(path_override: String = "") -> Error:
	if not path_override.is_empty():
		profile_path = path_override
	if profile_path.is_empty():
		return OK
	var config := ConfigFile.new()
	config.set_value("profile", "version", VERSION)
	config.set_value("profile", "scrap", scrap)
	config.set_value("profile", "runs", runs)
	config.set_value("profile", "victories", victories)
	config.set_value("profile", "levels_unlocked", levels_unlocked)
	config.set_value("profile", "completed_levels", completed_levels)
	for id: StringName in levels:
		config.set_value("upgrades", String(id), levels[id])
	for key in _unknown_upgrades:
		config.set_value("upgrades", key, _unknown_upgrades[key])
	last_save_error = ConfigIO.save_atomic(config, profile_path)
	if last_save_error != OK:
		# Marker su stderr, non push_error: il gate conta le righe "ERROR:" e qui un test lo provoca apposta.
		printerr("PROTOTYPE01_PROFILE_SAVE_FAILED path=%s error=%d" % [profile_path, last_save_error])
	return last_save_error


static func _validated_count(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return maxi(value, 0)
	if typeof(value) == TYPE_FLOAT and not is_nan(value):
		return maxi(int(value), 0)
	return 0
