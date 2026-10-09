class_name LevelUpMenu
extends CanvasLayer
## Scelta fra tre upgrade a ogni livello (PROGRESSION_SPEC). Ferma il gioco,
## si usa con controller (croce o stick, A) e con mouse o tastiera. Le carte
## restano inattive per un attimo: chi sta premendo A non sceglie per sbaglio.

signal chosen(id: StringName)
## Il menu si e appena aperto con una nuova offerta.
signal opened

const INPUT_GRACE_SECONDS := 0.4

var is_open := false
var _overlay: ColorRect
var _title: Label
var _cards: HBoxContainer
var _buttons: Array[Button] = []


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.color = Color(0.02, 0.025, 0.035, 0.78)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 24)
	center.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 34)
	column.add_child(_title)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override(&"separation", 20)
	column.add_child(_cards)
	column.add_child(ButtonPrompts.create([[&"ui_accept", "Scegli"]]))
	_overlay.hide()


## [param offer]: voci di UpgradeCatalog; [param levels]: livello attuale per id.
func open(offer: Array[Dictionary], levels: Dictionary, player_level: int) -> void:
	for button in _buttons:
		# Tolte subito dall'albero: le carte vecchie non restano un frame accanto alle nuove (U-07).
		_cards.remove_child(button)
		button.queue_free()
	_buttons.clear()
	_title.text = "LIVELLO %d  -  scegli un pezzo" % player_level
	for upgrade in offer:
		_buttons.append(_make_card(upgrade, int(levels.get(upgrade.id, 0))))
	for i in _buttons.size():
		var left := _buttons[(i - 1 + _buttons.size()) % _buttons.size()]
		var right := _buttons[(i + 1) % _buttons.size()]
		_buttons[i].focus_neighbor_left = _buttons[i].get_path_to(left)
		_buttons[i].focus_neighbor_right = _buttons[i].get_path_to(right)
	is_open = true
	get_tree().paused = true
	_overlay.show()
	_set_enabled(false)
	get_tree().create_timer(INPUT_GRACE_SECONDS, true).timeout.connect(_enable_after_grace)
	opened.emit()


func close() -> void:
	is_open = false
	_overlay.hide()
	get_viewport().gui_release_focus()
	get_tree().paused = false


func card_count() -> int:
	return _buttons.size()


## Sceglie la carta [param index] come se fosse premuta (test e automazione).
func press(index: int) -> void:
	if index >= 0 and index < _buttons.size() and not _buttons[index].disabled:
		_buttons[index].pressed.emit()


func _enable_after_grace() -> void:
	if not is_open:
		return
	_set_enabled(true)
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _set_enabled(enabled: bool) -> void:
	for button in _buttons:
		button.disabled = not enabled


func _make_card(upgrade: Dictionary, current_level: int) -> Button:
	var color: Color = UpgradeCatalog.RARITY_COLORS[upgrade.rarity].linear_to_srgb()
	var button := Button.new()
	button.custom_minimum_size = Vector2(300, 260)
	button.focus_mode = Control.FOCUS_ALL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override(&"font_size", 19)
	var level_text := "NUOVO" if current_level == 0 else "Liv. %d > %d" % [current_level, current_level + 1]
	button.text = "%s\n\n%s\n%s - %s\n\n%s" % [
		UpgradeCatalog.RARITY_NAMES[upgrade.rarity], upgrade.name,
		UpgradeCatalog.CATEGORY_NAMES.get(upgrade.category, ""), level_text, upgrade.text]
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.09, 0.1, 0.12) if state != &"focus" else Color(0.16, 0.17, 0.2)
		box.border_color = color if state != &"disabled" else color.darkened(0.5)
		var width := 6 if state == &"focus" or state == &"hover" else 3
		box.set_border_width_all(width)
		box.set_corner_radius_all(8)
		box.set_content_margin_all(16)
		button.add_theme_stylebox_override(state, box)
	var id: StringName = upgrade.id
	button.pressed.connect(func() -> void: _on_pressed(id))
	_cards.add_child(button)
	return button


func _on_pressed(id: StringName) -> void:
	if not is_open:
		return
	close()
	chosen.emit(id)
