class_name MainMenu
extends Control
## Menu iniziale (D-051): Gioca, Officina, Impostazioni, Esci. Scena principale
## del progetto. "Gioca" apre la mappa di campagna (D-066), da cui si sceglie un
## livello sbloccato. Con `-- --autostart` (o `--seed=`, `--boss-at=`, `--capture=`,
## `--level=<id>`) passa subito al livello: smoke test, catture e prove rapide non si
## fermano qui.

@export var workshop: WorkshopPanel
@export var campaign_map: CampaignMapPanel

var _profile: PlayerProfileService
var _pause_menu: Node
var _column: VBoxContainer
var _scrap_label: Label
var _play: Button
var _workshop_button: Button
var _settings: Button
var _quit: Button
var _prompts: ButtonPrompts


func _ready() -> void:
	get_tree().paused = false
	_profile = get_node_or_null(^"/root/PlayerProfile") as PlayerProfileService
	_pause_menu = get_node_or_null(^"/root/PauseMenu")
	if _pause_menu != null:
		# Nel menu non c'e nulla da mettere in pausa.
		_pause_menu.set(&"enabled", false)
	_build()
	if workshop != null:
		workshop.closed.connect(_on_panel_closed.bind(_workshop_button))
	if campaign_map != null:
		campaign_map.closed.connect(_on_panel_closed.bind(_play))
		campaign_map.level_chosen.connect(start_level)
	if _pause_menu != null and _pause_menu.has_signal(&"settings_closed"):
		_pause_menu.connect(&"settings_closed", _on_panel_closed.bind(_settings))
	if _profile != null:
		_profile.changed.connect(_refresh)
	_refresh()
	# Gli effetti sonori si sintetizzano in un thread mentre il menu e aperto: "Gioca"
	# li trova pronti invece di pagarli al caricamento del livello (R-40).
	SfxLibrary.precache_async()
	print("PROTOTYPE01_MENU_READY")
	if wants_autostart(OS.get_cmdline_user_args()):
		var requested := RunLaunchOptions.level_id()
		start_level.call_deferred(requested if LevelCatalog.is_playable(requested) else LevelCatalog.first())
	else:
		_play.grab_focus()


func _exit_tree() -> void:
	if _pause_menu != null:
		_pause_menu.set(&"enabled", true)


## Vero se la riga di comando chiede di saltare il menu.
static func wants_autostart(args: PackedStringArray) -> bool:
	return RunLaunchOptions.wants_autostart(args)


## "Gioca": la mappa di campagna; senza il pannello, il primo livello.
func start_run() -> void:
	if campaign_map == null:
		start_level(LevelCatalog.first())
		return
	_set_menu_visible(false)
	campaign_map.open()


func start_level(id: StringName) -> void:
	var scene := LevelCatalog.scene_of(id)
	if scene.is_empty():
		return
	get_tree().change_scene_to_file(scene)


func open_workshop() -> void:
	if workshop == null:
		return
	_set_menu_visible(false)
	workshop.open()


func open_settings() -> void:
	if _pause_menu == null:
		return
	_set_menu_visible(false)
	_pause_menu.call(&"open_settings_only")


func focused_control() -> Control:
	return get_viewport().gui_get_focus_owner()


func _on_panel_closed(back_to: Button) -> void:
	_set_menu_visible(true)
	_refresh()
	back_to.grab_focus()


## I pannelli aperti sopra il menu hanno i propri suggerimenti dei tasti.
func _set_menu_visible(shown: bool) -> void:
	_column.visible = shown
	_prompts.visible = shown


func _refresh() -> void:
	if _profile == null:
		_scrap_label.text = ""
		return
	_scrap_label.text = "Rottami in Officina: %d     Run giocate: %d     Livelli completati: %d" \
		% [_profile.scrap, _profile.runs, _profile.victories]


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.name = "Background"
	background.color = UiPalette.BG
	var sky := ShaderMaterial.new()
	sky.shader = load("res://resources/materials/menu_sky.gdshader")
	background.material = sky
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var dust := CPUParticles2D.new()
	dust.name = "Dust"
	dust.amount = 40
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(700, 60)
	dust.position = Vector2(640, 860)
	dust.direction = Vector2(0, -1)
	dust.spread = 25.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 25.0
	dust.initial_velocity_max = 60.0
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.5
	dust.color = Color(1.0, 0.72, 0.4, 0.55)
	add_child(dust)
	var logo := GameLogo.new()
	logo.name = "Logo"
	logo.letter_size = 44
	logo.position = Vector2(72, 72)
	add_child(logo)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.custom_minimum_size = Vector2(360, 0)
	_column.position = Vector2(80, 330)
	_column.add_theme_constant_override(&"separation", 14)
	add_child(_column)
	_play = _button("Gioca", start_run)
	_workshop_button = _button("Officina", open_workshop)
	_settings = _button("Impostazioni", open_settings)
	_quit = _button("Esci", func() -> void: get_tree().quit())
	var plate := PanelContainer.new()
	plate.name = "ProfilePlate"
	add_child(plate)
	plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 40)
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_scrap_label = Label.new()
	_scrap_label.theme_type_variation = &"ScrapLabel"
	plate.add_child(_scrap_label)
	var version := Label.new()
	version.name = "Version"
	version.theme_type_variation = &"MutedLabel"
	version.text = "v%s   Godot %s" % [ProjectSettings.get_setting("application/config/version", "0"), Engine.get_version_info().string]
	add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_prompts = ButtonPrompts.create([[&"ui_accept", "Conferma"]])
	add_child(_prompts)
	_prompts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
	_prompts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_prompts.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"MainButton"
	button.custom_minimum_size = Vector2(0, 56)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(action)
	_column.add_child(button)
	return button
