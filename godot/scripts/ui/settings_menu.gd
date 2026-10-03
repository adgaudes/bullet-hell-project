class_name SettingsMenu
extends PanelContainer
## Pannello impostazioni navigabile con controller, tastiera e mouse.

signal back_requested

@onready var _fps_option: OptionButton = %FpsOption
@onready var _vsync_option: OptionButton = %VsyncOption
@onready var _msaa_option: OptionButton = %MsaaOption
@onready var _window_option: OptionButton = %WindowOption
@onready var _scale_option: OptionButton = %ScaleOption
@onready var _invert_x: CheckButton = %InvertX
@onready var _invert_y: CheckButton = %InvertY
@onready var _back_button: Button = %BackButton
@onready var _settings: GameSettingsService = get_node(^"/root/GameSettings")

const RENDER_SCALES: Array[float] = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0]


func _ready() -> void:
	_fill_options()
	_fps_option.item_selected.connect(_on_fps_selected)
	_vsync_option.item_selected.connect(_on_vsync_selected)
	_msaa_option.item_selected.connect(_on_msaa_selected)
	_window_option.item_selected.connect(_on_window_selected)
	_scale_option.item_selected.connect(_on_scale_selected)
	_invert_x.toggled.connect(_settings.set_invert_aim_x)
	_invert_y.toggled.connect(_settings.set_invert_aim_y)
	_back_button.pressed.connect(func(): back_requested.emit())


## Sincronizza i controlli e mette il focus sulla prima opzione.
func open() -> void:
	_sync_from_settings()
	show()
	_fps_option.grab_focus()


func focused_control() -> Control:
	return get_viewport().gui_get_focus_owner()


func _fill_options() -> void:
	_add_items(_fps_option, ["30", "60", "90", "120 (predefinito)", "144", "Illimitato"])
	_add_items(_vsync_option, ["Mailbox (predefinito)", "Classico", "Off"])
	_add_items(_msaa_option, ["Off", "2x", "4x (predefinito)", "8x"])
	_add_items(_window_option, ["Finestra", "Schermo intero", "Finestra senza bordi"])
	_add_items(_scale_option, ["50%", "60%", "70%", "80%", "90%", "100% (predefinito)"])


func _add_items(option: OptionButton, labels: Array[String]) -> void:
	for label in labels:
		option.add_item(label)


func _sync_from_settings() -> void:
	_fps_option.select(GameSettingsService.FPS_CAPS.find(_settings.fps_cap))
	_vsync_option.select(GameSettingsService.VSYNC_MODES.find(_settings.vsync_mode))
	_msaa_option.select(GameSettingsService.MSAA_MODES.find(_settings.msaa_3d))
	_window_option.select(GameSettingsService.WINDOW_MODES.find(_settings.window_mode))
	_scale_option.select(_closest_scale_index(_settings.render_scale))
	_invert_x.set_pressed_no_signal(_settings.invert_aim_x)
	_invert_y.set_pressed_no_signal(_settings.invert_aim_y)


func _on_fps_selected(index: int) -> void:
	_settings.set_fps_cap(GameSettingsService.FPS_CAPS[index])


func _on_vsync_selected(index: int) -> void:
	_settings.set_vsync_mode(GameSettingsService.VSYNC_MODES[index])


func _on_msaa_selected(index: int) -> void:
	_settings.set_msaa_3d(GameSettingsService.MSAA_MODES[index])


func _on_window_selected(index: int) -> void:
	_settings.set_window_mode(GameSettingsService.WINDOW_MODES[index])


func _on_scale_selected(index: int) -> void:
	_settings.set_render_scale(RENDER_SCALES[index])


func _closest_scale_index(value: float) -> int:
	var closest := 0
	var distance := INF
	for index in RENDER_SCALES.size():
		var candidate_distance := absf(RENDER_SCALES[index] - value)
		if candidate_distance < distance:
			distance = candidate_distance
			closest = index
	return closest
