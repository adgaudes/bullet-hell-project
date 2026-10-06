class_name WorkshopPanel
extends CanvasLayer
## Officina (D-049): fra un livello e l'altro si spendono i rottami portati fuori
## in upgrade permanenti. Si apre dalla schermata di fine livello, a gioco fermo;
## controller (croce o stick, A compra, B torna) e mouse o tastiera.

signal closed
signal purchased(id: StringName)
## Acquisto impossibile: rottami insufficienti o upgrade al massimo.
signal rejected(id: StringName)

const SCRAP_COLOR := Color(0.95, 0.5, 0.15)
const OWNED_COLOR := Color(0.25, 0.85, 0.3)
const UNAFFORDABLE_COLOR := Color(0.6, 0.6, 0.6)

var is_open := false
var _profile: PlayerProfileService
var _overlay: ColorRect
var _scrap_label: Label
var _rows: VBoxContainer
var _buttons: Dictionary[StringName, Button] = {}
var _back: Button


func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	_profile = get_node_or_null(^"/root/PlayerProfile") as PlayerProfileService
	_overlay = ColorRect.new()
	_overlay.color = Color(0.03, 0.03, 0.04, 0.96)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(760, 0)
	column.add_theme_constant_override(&"separation", 10)
	center.add_child(column)
	var title := Label.new()
	title.text = "OFFICINA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 38)
	column.add_child(title)
	_scrap_label = Label.new()
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scrap_label.add_theme_font_size_override(&"font_size", 22)
	_scrap_label.add_theme_color_override(&"font_color", SCRAP_COLOR)
	column.add_child(_scrap_label)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 6)
	column.add_child(_rows)
	for entry in PermanentCatalog.all():
		var id: StringName = entry.id
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 58)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override(&"font_size", 17)
		button.pressed.connect(func() -> void: _on_pressed(id))
		_rows.add_child(button)
		_buttons[id] = button
	_back = Button.new()
	_back.text = "Torna"
	_back.custom_minimum_size = Vector2(0, 50)
	_back.add_theme_font_size_override(&"font_size", 20)
	_back.pressed.connect(close)
	column.add_child(_back)
	_overlay.hide()


func _input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	if _profile == null:
		return
	is_open = true
	_refresh()
	_overlay.show()
	(_rows.get_child(0) as Button).grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_overlay.hide()
	closed.emit()


## Compra come se la riga fosse premuta (test e automazione).
func press(id: StringName) -> void:
	if is_open and _buttons.has(id):
		_buttons[id].pressed.emit()


func row_text(id: StringName) -> String:
	return _buttons[id].text if _buttons.has(id) else ""


func _on_pressed(id: StringName) -> void:
	if not is_open:
		return
	if _profile.buy(id):
		purchased.emit(id)
	else:
		rejected.emit(id)
	_refresh()


func _refresh() -> void:
	_scrap_label.text = "Rottami: %d" % _profile.scrap
	for entry in PermanentCatalog.all():
		var id: StringName = entry.id
		var level := _profile.level_of(id)
		var cost := _profile.cost_of(id)
		var price := "AL MASSIMO"
		var color := OWNED_COLOR
		if cost >= 0 and _profile.scrap >= cost:
			price = "%d rottami" % cost
			color = Color.WHITE
		elif cost >= 0:
			price = "%d rottami (ne mancano %d)" % [cost, cost - _profile.scrap]
			color = UNAFFORDABLE_COLOR
		var button := _buttons[id]
		button.text = "  %s  %d/%d  -  %s\n  %s" % [entry.name, level, (entry.costs as Array).size(), price, entry.text]
		for state: StringName in [&"font_color", &"font_focus_color", &"font_hover_color", &"font_pressed_color"]:
			button.add_theme_color_override(state, color)
