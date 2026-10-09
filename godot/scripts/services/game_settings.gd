class_name GameSettingsService
extends Node
## Impostazioni persistenti del gioco e loro applicazione ai servizi Godot.
## Registrato come autoload `GameSettings`; altri script lo raggiungono con
## `get_node("/root/GameSettings")` tipizzato `GameSettingsService`, perche il nome
## globale dell'autoload non esiste in --check-only ne nei test.

signal changed

enum WindowModeChoice { WINDOWED, EXCLUSIVE_FULLSCREEN, BORDERLESS_FULLSCREEN }

const DEFAULT_FPS_CAP := 120
const DEFAULT_VSYNC_MODE := DisplayServer.VSYNC_MAILBOX
const DEFAULT_MSAA_3D := Viewport.MSAA_4X
const DEFAULT_RENDER_SCALE := 1.0
const DEFAULT_WINDOW_MODE := WindowModeChoice.WINDOWED
const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_SFX_VOLUME := 0.8
const MASTER_BUS := &"Master"
const SFX_BUS := &"SFX"
const FPS_CAPS: Array[int] = [30, 60, 90, 120, 144, 0]
const MSAA_MODES: Array[int] = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]
const VSYNC_MODES: Array[int] = [DisplayServer.VSYNC_MAILBOX, DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_DISABLED]
const WINDOW_MODES: Array[int] = [WindowModeChoice.WINDOWED, WindowModeChoice.EXCLUSIVE_FULLSCREEN, WindowModeChoice.BORDERLESS_FULLSCREEN]

var settings_path := "user://settings.cfg"
var fps_cap := DEFAULT_FPS_CAP
var vsync_mode := DEFAULT_VSYNC_MODE
var msaa_3d := DEFAULT_MSAA_3D
var render_scale := DEFAULT_RENDER_SCALE
var window_mode := DEFAULT_WINDOW_MODE
var invert_aim_x := false
var invert_aim_y := false
## Volumi lineari 0.0-1.0; 0 silenzia il bus.
var master_volume := DEFAULT_MASTER_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
## Scritture su disco eseguite (per i test del salvataggio differito).
var save_count := 0

var _save_pending := false


func _ready() -> void:
	# Sotto i test (SceneTree con script) si parte dai default: le impostazioni
	# reali del giocatore non devono cambiare l'esito dei test.
	if Engine.get_main_loop().get_script() == null:
		load_settings()
	apply_settings()


## Ripristina i valori iniziali senza salvare automaticamente.
func reset_to_defaults() -> void:
	fps_cap = DEFAULT_FPS_CAP
	vsync_mode = DEFAULT_VSYNC_MODE
	msaa_3d = DEFAULT_MSAA_3D
	render_scale = DEFAULT_RENDER_SCALE
	window_mode = DEFAULT_WINDOW_MODE
	invert_aim_x = false
	invert_aim_y = false
	master_volume = DEFAULT_MASTER_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME


## Carica un file; valori assenti o non validi mantengono i default.
func load_settings(path_override: String = "") -> Error:
	if not path_override.is_empty():
		settings_path = path_override
	reset_to_defaults()
	var config := ConfigFile.new()
	var error := config.load(settings_path)
	if error == ERR_FILE_NOT_FOUND:
		return OK
	if error != OK:
		return error
	fps_cap = _validated_int(config.get_value("graphics", "fps_cap", fps_cap), FPS_CAPS, DEFAULT_FPS_CAP)
	vsync_mode = _validated_int(config.get_value("graphics", "vsync_mode", vsync_mode), VSYNC_MODES, DEFAULT_VSYNC_MODE)
	msaa_3d = _validated_int(config.get_value("graphics", "msaa_3d", msaa_3d), MSAA_MODES, DEFAULT_MSAA_3D)
	render_scale = _validated_render_scale(config.get_value("graphics", "render_scale", render_scale))
	window_mode = _validated_int(config.get_value("graphics", "window_mode", window_mode), WINDOW_MODES, DEFAULT_WINDOW_MODE)
	invert_aim_x = _validated_bool(config.get_value("controls", "invert_aim_x", invert_aim_x), false)
	invert_aim_y = _validated_bool(config.get_value("controls", "invert_aim_y", invert_aim_y), false)
	master_volume = _validated_volume(config.get_value("audio", "master_volume", master_volume), DEFAULT_MASTER_VOLUME)
	sfx_volume = _validated_volume(config.get_value("audio", "sfx_volume", sfx_volume), DEFAULT_SFX_VOLUME)
	return OK


## Salva tutti i valori correnti nel percorso configurato.
func save_settings(path_override: String = "") -> Error:
	if not path_override.is_empty():
		settings_path = path_override
	var config := ConfigFile.new()
	config.set_value("graphics", "fps_cap", fps_cap)
	config.set_value("graphics", "vsync_mode", vsync_mode)
	config.set_value("graphics", "msaa_3d", msaa_3d)
	config.set_value("graphics", "render_scale", render_scale)
	config.set_value("graphics", "window_mode", window_mode)
	config.set_value("controls", "invert_aim_x", invert_aim_x)
	config.set_value("controls", "invert_aim_y", invert_aim_y)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	save_count += 1
	return config.save(settings_path)


## Applica le opzioni grafiche e audio; il viewport esplicito rende la logica testabile.
## Ogni opzione grafica si tocca solo se cambia: rifare la modalita finestra o la
## scala di rendering a ogni passo di un cursore costa un ricreare di buffer (U-05).
func apply_settings(target_viewport: Viewport = null) -> void:
	if Engine.max_fps != fps_cap:
		Engine.max_fps = fps_cap
	# Il display server headless non ha una finestra su cui applicare queste opzioni.
	if DisplayServer.get_name() != "headless":
		if DisplayServer.window_get_vsync_mode() != vsync_mode:
			DisplayServer.window_set_vsync_mode(vsync_mode)
		_apply_window_mode()
	var viewport := target_viewport if target_viewport != null else get_viewport()
	if viewport != null:
		if viewport.msaa_3d != msaa_3d:
			viewport.msaa_3d = msaa_3d
		if not is_equal_approx(viewport.scaling_3d_scale, render_scale):
			viewport.scaling_3d_scale = render_scale
	apply_audio()


## Porta i volumi sui bus audio. Un bus assente dal layout viene ignorato.
func apply_audio() -> void:
	_apply_bus_volume(MASTER_BUS, master_volume)
	_apply_bus_volume(SFX_BUS, sfx_volume)


func set_fps_cap(value: int) -> void:
	fps_cap = _validated_int(value, FPS_CAPS, DEFAULT_FPS_CAP)
	_apply_and_save()


func set_vsync_mode(value: int) -> void:
	vsync_mode = _validated_int(value, VSYNC_MODES, DEFAULT_VSYNC_MODE)
	_apply_and_save()


func set_msaa_3d(value: int) -> void:
	msaa_3d = _validated_int(value, MSAA_MODES, DEFAULT_MSAA_3D)
	_apply_and_save()


func set_render_scale(value: float) -> void:
	render_scale = clampf(value, 0.5, 1.0)
	_apply_and_save()


func set_window_mode(value: int) -> void:
	window_mode = _validated_int(value, WINDOW_MODES, DEFAULT_WINDOW_MODE)
	_apply_and_save()


func set_invert_aim_x(value: bool) -> void:
	invert_aim_x = value
	_save_and_emit()


func set_invert_aim_y(value: bool) -> void:
	invert_aim_y = value
	_save_and_emit()


func set_master_volume(value: float) -> void:
	master_volume = _validated_volume(value, DEFAULT_MASTER_VOLUME)
	apply_audio()
	_save_and_emit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = _validated_volume(value, DEFAULT_SFX_VOLUME)
	apply_audio()
	_save_and_emit()


func _apply_and_save() -> void:
	apply_settings()
	_save_and_emit()


## Salvataggio differito: molti setter nello stesso frame (un cursore trascinato)
## producono una sola scrittura a fine frame (U-05).
func _save_and_emit() -> void:
	changed.emit()
	if _save_pending:
		return
	_save_pending = true
	_flush_save.call_deferred()


func _flush_save() -> void:
	if not _save_pending:
		return
	_save_pending = false
	var error := save_settings()
	if error != OK:
		push_error("Impossibile salvare le impostazioni: %s" % error_string(error))


func _exit_tree() -> void:
	# Uscita dal gioco con una scrittura ancora in attesa: non si perde.
	_flush_save()


func _apply_window_mode() -> void:
	var target := DisplayServer.WINDOW_MODE_WINDOWED
	match window_mode:
		WindowModeChoice.EXCLUSIVE_FULLSCREEN:
			target = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		WindowModeChoice.BORDERLESS_FULLSCREEN:
			target = DisplayServer.WINDOW_MODE_FULLSCREEN
	if DisplayServer.window_get_mode() != target:
		DisplayServer.window_set_mode(target)


static func _apply_bus_volume(bus: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	# linear_to_db(0) e -inf: a zero il bus viene silenziato.
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))


static func _validated_volume(value: Variant, fallback: float) -> float:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return fallback
	var parsed := float(value)
	return fallback if is_nan(parsed) else clampf(parsed, 0.0, 1.0)


## Solo interi veri: `int("abc")` sarebbe 0, che per il limite fps vale "Illimitato" (U-04).
static func _validated_int(value: Variant, allowed: Array[int], fallback: int) -> int:
	if typeof(value) != TYPE_INT:
		return fallback
	return value if value in allowed else fallback


## Solo booleani veri: `bool("false")` sarebbe true (U-04).
static func _validated_bool(value: Variant, fallback: bool) -> bool:
	return value if typeof(value) == TYPE_BOOL else fallback


static func _validated_render_scale(value: Variant) -> float:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return DEFAULT_RENDER_SCALE
	var parsed := float(value)
	return DEFAULT_RENDER_SCALE if is_nan(parsed) else clampf(parsed, 0.5, 1.0)
