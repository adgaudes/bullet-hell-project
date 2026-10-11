class_name SettingsMenu
extends PanelContainer
## Pannello impostazioni navigabile con controller, tastiera e mouse.
## Dal restyling 2026-10-11: preset grafico in testa, opzioni di qualita una a una (una
## modifica porta il preset a Personalizzato), limite di fps fino a 240 e Illimitato,
## contenuto scorrevole che segue il focus.

signal back_requested

@onready var _preset_option: OptionButton = %PresetOption
@onready var _fps_option: OptionButton = %FpsOption
@onready var _vsync_option: OptionButton = %VsyncOption
@onready var _msaa_option: OptionButton = %MsaaOption
@onready var _window_option: OptionButton = %WindowOption
@onready var _scale_option: OptionButton = %ScaleOption
@onready var _shadow_option: OptionButton = %ShadowOption
@onready var _ssao_option: OptionButton = %SsaoOption
@onready var _gi_option: OptionButton = %GiOption
@onready var _glow_option: OptionButton = %GlowOption
@onready var _volumetric_check: CheckButton = %VolumetricCheck
@onready var _texture_option: OptionButton = %TextureOption
@onready var _vegetation_option: OptionButton = %VegetationOption
@onready var _screen_aa_option: OptionButton = %ScreenAaOption
@onready var _fsr_check: CheckButton = %FsrCheck
@onready var _master_volume: HSlider = %MasterVolume
@onready var _master_value: Label = %MasterVolumeValue
@onready var _sfx_volume: HSlider = %SfxVolume
@onready var _sfx_value: Label = %SfxVolumeValue
@onready var _invert_x: CheckButton = %InvertX
@onready var _invert_y: CheckButton = %InvertY
@onready var _back_button: Button = %BackButton
@onready var _settings: GameSettingsService = get_node(^"/root/GameSettings")

const RENDER_SCALES: Array[float] = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
const PRESET_LABELS: Array[String] = ["Steam Deck", "Basso", "Medio", "Alto (predefinito)", "Massimo", "Personalizzato"]


func _ready() -> void:
	_fill_options()
	_preset_option.item_selected.connect(_on_preset_selected)
	_fps_option.item_selected.connect(_on_fps_selected)
	_vsync_option.item_selected.connect(_on_vsync_selected)
	_msaa_option.item_selected.connect(_on_msaa_selected)
	_window_option.item_selected.connect(_on_window_selected)
	_scale_option.item_selected.connect(_on_scale_selected)
	_shadow_option.item_selected.connect(_on_quality_selected.bind(_settings.set_shadow_quality))
	_ssao_option.item_selected.connect(_on_quality_selected.bind(_settings.set_ssao_quality))
	_gi_option.item_selected.connect(_on_quality_selected.bind(_settings.set_gi_mode))
	_glow_option.item_selected.connect(_on_quality_selected.bind(_settings.set_glow_quality))
	_texture_option.item_selected.connect(_on_quality_selected.bind(_settings.set_texture_quality))
	_vegetation_option.item_selected.connect(_on_quality_selected.bind(_settings.set_vegetation_density))
	_screen_aa_option.item_selected.connect(_on_quality_selected.bind(_settings.set_screen_aa))
	_volumetric_check.toggled.connect(_on_quality_toggled.bind(_settings.set_volumetric_fog))
	_fsr_check.toggled.connect(_on_quality_toggled.bind(_settings.set_fsr_upscaling))
	_master_volume.value_changed.connect(_on_master_volume_changed)
	_sfx_volume.value_changed.connect(_on_sfx_volume_changed)
	_invert_x.toggled.connect(_settings.set_invert_aim_x)
	_invert_y.toggled.connect(_settings.set_invert_aim_y)
	_back_button.pressed.connect(func(): back_requested.emit())


## Sincronizza i controlli e mette il focus sulla prima opzione.
func open() -> void:
	_sync_from_settings()
	show()
	_preset_option.grab_focus()


func focused_control() -> Control:
	return get_viewport().gui_get_focus_owner()


func _fill_options() -> void:
	_add_items(_preset_option, PRESET_LABELS)
	_add_items(_fps_option, ["30", "60 (predefinito)", "90", "120", "144", "165", "240", "Illimitato"])
	_add_items(_vsync_option, ["Mailbox (predefinito)", "Classico", "Off"])
	_add_items(_msaa_option, ["Off", "2x", "4x (predefinito)", "8x"])
	_add_items(_window_option, ["Finestra", "Schermo intero", "Finestra senza bordi"])
	_add_items(_scale_option, ["50%", "60%", "70%", "80%", "90%", "100% (predefinito)"])
	_add_items(_shadow_option, ["Off", "Bassa", "Media", "Alta"])
	_add_items(_ssao_option, ["Off", "Bassa", "Alta"])
	_add_items(_gi_option, ["Off", "SSIL", "SDFGI"])
	_add_items(_glow_option, ["Off", "Basso", "Alto"])
	_add_items(_texture_option, ["Bassa", "Alta"])
	_add_items(_vegetation_option, ["Bassa", "Media", "Alta"])
	_add_items(_screen_aa_option, ["Off", "FXAA", "TAA"])


func _add_items(option: OptionButton, labels: Array[String]) -> void:
	for label in labels:
		option.add_item(label)


func _sync_from_settings() -> void:
	_preset_option.select(_settings.preset)
	_fps_option.select(GameSettingsService.FPS_CAPS.find(_settings.fps_cap))
	_vsync_option.select(GameSettingsService.VSYNC_MODES.find(_settings.vsync_mode))
	_msaa_option.select(GameSettingsService.MSAA_MODES.find(_settings.msaa_3d))
	_window_option.select(GameSettingsService.WINDOW_MODES.find(_settings.window_mode))
	_scale_option.select(_closest_scale_index(_settings.render_scale))
	_shadow_option.select(_settings.shadow_quality)
	_ssao_option.select(_settings.ssao_quality)
	_gi_option.select(_settings.gi_mode)
	_glow_option.select(_settings.glow_quality)
	_volumetric_check.set_pressed_no_signal(_settings.volumetric_fog)
	_texture_option.select(_settings.texture_quality)
	_vegetation_option.select(_settings.vegetation_density)
	_screen_aa_option.select(_settings.screen_aa)
	_fsr_check.set_pressed_no_signal(_settings.fsr_upscaling)
	_master_volume.set_value_no_signal(_settings.master_volume)
	_sfx_volume.set_value_no_signal(_settings.sfx_volume)
	_refresh_volume_labels()
	_invert_x.set_pressed_no_signal(_settings.invert_aim_x)
	_invert_y.set_pressed_no_signal(_settings.invert_aim_y)


## Un preset riscrive tutte le opzioni di qualita: si risincronizzano le righe.
func _on_preset_selected(index: int) -> void:
	if index != _settings.preset:
		_settings.set_preset(index)
		_sync_from_settings()


# Riselezionare la voce gia attiva non tocca il servizio: niente riapplicazione
# della grafica ne scrittura su disco (U-05).
func _on_fps_selected(index: int) -> void:
	if GameSettingsService.FPS_CAPS[index] != _settings.fps_cap:
		_settings.set_fps_cap(GameSettingsService.FPS_CAPS[index])


func _on_vsync_selected(index: int) -> void:
	if GameSettingsService.VSYNC_MODES[index] != _settings.vsync_mode:
		_settings.set_vsync_mode(GameSettingsService.VSYNC_MODES[index])


func _on_window_selected(index: int) -> void:
	if GameSettingsService.WINDOW_MODES[index] != _settings.window_mode:
		_settings.set_window_mode(GameSettingsService.WINDOW_MODES[index])


func _on_msaa_selected(index: int) -> void:
	if GameSettingsService.MSAA_MODES[index] != _settings.msaa_3d:
		_settings.set_msaa_3d(GameSettingsService.MSAA_MODES[index])
		_preset_option.select(_settings.preset)


func _on_scale_selected(index: int) -> void:
	if not is_equal_approx(RENDER_SCALES[index], _settings.render_scale):
		_settings.set_render_scale(RENDER_SCALES[index])
		_preset_option.select(_settings.preset)


## Opzione di qualita a indice: il setter del servizio decide se e un cambiamento e
## porta il preset a Personalizzato; la riga del preset lo riflette.
func _on_quality_selected(index: int, setter: Callable) -> void:
	setter.call(index)
	_preset_option.select(_settings.preset)


func _on_quality_toggled(pressed: bool, setter: Callable) -> void:
	setter.call(pressed)
	_preset_option.select(_settings.preset)


func _on_master_volume_changed(value: float) -> void:
	if not is_equal_approx(value, _settings.master_volume):
		_settings.set_master_volume(value)
	_refresh_volume_labels()


func _on_sfx_volume_changed(value: float) -> void:
	if not is_equal_approx(value, _settings.sfx_volume):
		_settings.set_sfx_volume(value)
	_refresh_volume_labels()


func _refresh_volume_labels() -> void:
	_master_value.text = "%d%%" % roundi(_master_volume.value * 100.0)
	_sfx_value.text = "%d%%" % roundi(_sfx_volume.value * 100.0)


func _closest_scale_index(value: float) -> int:
	var closest := 0
	var distance := INF
	for index in RENDER_SCALES.size():
		var candidate_distance := absf(RENDER_SCALES[index] - value)
		if candidate_distance < distance:
			distance = candidate_distance
			closest = index
	return closest
