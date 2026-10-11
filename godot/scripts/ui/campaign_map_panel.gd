class_name CampaignMapPanel
extends CanvasLayer
## Mappa di campagna (D-040, D-066): i livelli in fila, da sinistra a destra, con il
## loro stato (completato, sbloccato, bloccato, in costruzione). Si apre dal menu
## iniziale con "Gioca": si sceglie un livello sbloccato, A conferma e B torna.
## Controller (croce o stick), tastiera e mouse.

signal closed
signal level_chosen(id: StringName)


var is_open := false
var _profile: PlayerProfileService
var _overlay: ColorRect
var _row: HBoxContainer
var _buttons: Dictionary[StringName, Button] = {}
var _detail: Label
var _back: Button
var _marks: Dictionary[StringName, UiIcon] = {}
var _badges: Dictionary[StringName, Label] = {}

const INK := Color("3b2718")
const INK_GREEN := Color("3f7a2a")
const INK_LOCKED := Color("8a7a66")


func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	_profile = get_node_or_null(^"/root/PlayerProfile") as PlayerProfileService
	_overlay = ColorRect.new()
	_overlay.color = Color(UiPalette.BG, 0.94)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(900, 0)
	column.add_theme_constant_override(&"separation", 18)
	center.add_child(column)
	var title := Label.new()
	title.text = "PRIMA CAMPAGNA"
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override(&"separation", 24)
	column.add_child(_row)
	for i in LevelCatalog.count():
		var entry: Dictionary = LevelCatalog.all()[i]
		var id: StringName = entry.id
		if i > 0:
			# Linea rame che collega le carte, centrata in verticale.
			var link := ColorRect.new()
			link.color = UiPalette.BORDER
			link.custom_minimum_size = Vector2(40, 3)
			link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_row.add_child(link)
		var button := Button.new()
		button.theme_type_variation = &"CardButton"
		button.custom_minimum_size = Vector2(220, 140)
		button.add_theme_font_size_override(&"font_size", 18)
		button.pressed.connect(func() -> void: _on_pressed(id))
		button.focus_entered.connect(func() -> void: _show_detail(id))
		button.mouse_entered.connect(func() -> void: _show_detail(id))
		_row.add_child(button)
		_buttons[id] = button
		var mark := UiIcon.make(&"check", 26.0, UiPalette.BORDER)
		mark.name = "Mark"
		mark.outline = INK
		mark.visible = false
		button.add_child(mark)
		mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
		mark.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_marks[id] = mark
		# Numero del livello in un cerchio di rame, in alto a sinistra.
		var badge := Label.new()
		badge.name = "Badge"
		badge.text = str(i + 1)
		badge.theme_type_variation = &"SectionLabel"
		badge.add_theme_font_size_override(&"font_size", 16)
		badge.add_theme_color_override(&"font_color", INK)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.custom_minimum_size = Vector2(28, 28)
		var circle := StyleBoxFlat.new()
		circle.bg_color = UiPalette.BORDER
		circle.border_color = INK
		circle.set_border_width_all(2)
		circle.set_corner_radius_all(14)
		badge.add_theme_stylebox_override(&"normal", circle)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(badge)
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 8)
		_badges[id] = badge
	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(0, 60)
	_detail.theme_type_variation = &"MutedLabel"
	_detail.add_theme_font_size_override(&"font_size", 18)
	column.add_child(_detail)
	_back = Button.new()
	_back.text = "Torna"
	_back.theme_type_variation = &"MainButton"
	_back.custom_minimum_size = Vector2(0, 50)
	_back.pressed.connect(close)
	column.add_child(_back)
	column.add_child(ButtonPrompts.create([[&"ui_accept", "Parti"], [&"ui_cancel", "Torna"]]))
	_overlay.hide()


func _input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	is_open = true
	_refresh()
	_overlay.show()
	var fx := get_node_or_null(^"/root/UiFx") as UiFxService
	if fx != null:
		fx.pop_in(_overlay.get_child(0))
	_buttons[default_level()].grab_focus()
	_show_detail(default_level())


func close() -> void:
	if not is_open:
		return
	is_open = false
	_overlay.hide()
	var fx := get_node_or_null(^"/root/UiFx") as UiFxService
	if fx != null:
		fx.play(&"ui_back")
	closed.emit()


## Il livello proposto: l'ultimo sbloccato e giocabile.
func default_level() -> StringName:
	var chosen := LevelCatalog.first()
	for i in LevelCatalog.count():
		var id: StringName = LevelCatalog.all()[i].id
		if is_unlocked(id) and LevelCatalog.is_playable(id):
			chosen = id
	return chosen


func is_unlocked(id: StringName) -> bool:
	var index := LevelCatalog.index_of(id)
	var unlocked := _profile.levels_unlocked if _profile != null else 1
	return index >= 0 and index < unlocked


func is_completed(id: StringName) -> bool:
	return _profile != null and _profile.has_completed(id)


func can_play(id: StringName) -> bool:
	return is_unlocked(id) and LevelCatalog.is_playable(id)


## Sceglie come se il pulsante fosse premuto (test e automazione).
func press(id: StringName) -> void:
	if is_open and _buttons.has(id):
		_buttons[id].pressed.emit()


## Testo della carta piu il segno di stato ("V" completato, "X" bloccato), per test e automazione.
func button_text(id: StringName) -> String:
	if not _buttons.has(id):
		return ""
	var mark := "V" if is_completed(id) else ("" if is_unlocked(id) else "X")
	return "%d  %s\n%s" % [LevelCatalog.index_of(id) + 1, _buttons[id].text, mark]


## Icona sulla carta: `check` completato, `lock` bloccato o in costruzione, vuoto se giocabile.
func card_badge(id: StringName) -> Label:
	return _badges.get(id)


func card_mark(id: StringName) -> StringName:
	if not _marks.has(id) or not _marks[id].visible:
		return &""
	return _marks[id].kind


func _on_pressed(id: StringName) -> void:
	if not is_open or not can_play(id):
		return
	is_open = false
	_overlay.hide()
	print("PROTOTYPE01_LEVEL_CHOSEN id=%s" % id)
	level_chosen.emit(id)


func _show_detail(id: StringName) -> void:
	var entry := LevelCatalog.find(id)
	if entry.is_empty():
		return
	var state := "In costruzione" if not LevelCatalog.is_playable(id) else \
		("Completato" if is_completed(id) else ("Sbloccato" if is_unlocked(id) else "Bloccato: completa il livello precedente"))
	_detail.text = "%s\n%s  -  Boss: %s" % [entry.text, state, entry.boss]


func _refresh() -> void:
	for i in LevelCatalog.count():
		var entry: Dictionary = LevelCatalog.all()[i]
		var id: StringName = entry.id
		var button: Button = _buttons[id]
		button.text = (entry.title as String).to_upper()
		var color := INK_LOCKED
		if is_completed(id):
			color = INK_GREEN
		elif can_play(id):
			color = INK
		var mark_icon: UiIcon = _marks[id]
		mark_icon.visible = is_completed(id) or not can_play(id)
		mark_icon.kind = &"check" if is_completed(id) else &"lock"
		mark_icon.tint = UiPalette.SUCCESS if is_completed(id) else UiPalette.BORDER
		button.add_theme_color_override(&"font_color", color)
		button.add_theme_color_override(&"font_focus_color", color)
		button.add_theme_color_override(&"font_hover_color", color)
		# I livelli bloccati o in costruzione si vedono e si leggono, ma il fuoco li salta.
		button.focus_mode = Control.FOCUS_ALL if can_play(id) else Control.FOCUS_NONE
		button.disabled = not can_play(id)
