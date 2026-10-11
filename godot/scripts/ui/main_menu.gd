class_name MainMenu
extends Control
## Menu iniziale (D-051): Gioca, Officina, Impostazioni, Esci. Scena principale
## del progetto. "Gioca" apre la mappa di campagna (D-066), da cui si sceglie un
## livello sbloccato. Con `-- --autostart` (o `--seed=`, `--boss-at=`, `--capture=`,
## `--level=<id>`) passa subito al livello: smoke test, catture e prove rapide non si
## fermano qui.

const SCRAP_COLOR := Color(0.95, 0.5, 0.15)

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
	background.color = Color(0.07, 0.06, 0.05)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_column = VBoxContainer.new()
	_column.custom_minimum_size = Vector2(420, 0)
	_column.add_theme_constant_override(&"separation", 16)
	center.add_child(_column)
	var title := Label.new()
	# Titolo provvisorio: il gioco non ha ancora un nome.
	title.text = "PROTOTYPE 01"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 56)
	_column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Riscrivi il campo. Sopravvivi all'orda."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override(&"font_size", 20)
	_column.add_child(subtitle)
	_scrap_label = Label.new()
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scrap_label.add_theme_font_size_override(&"font_size", 17)
	_scrap_label.add_theme_color_override(&"font_color", SCRAP_COLOR)
	_column.add_child(_scrap_label)
	_play = _button("Gioca", start_run)
	_workshop_button = _button("Officina", open_workshop)
	_settings = _button("Impostazioni", open_settings)
	_quit = _button("Esci", func() -> void: get_tree().quit())
	_prompts = ButtonPrompts.create([[&"ui_accept", "Conferma"]])
	add_child(_prompts)
	_prompts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 28)
	_prompts.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override(&"font_size", 22)
	button.pressed.connect(action)
	_column.add_child(button)
	return button
