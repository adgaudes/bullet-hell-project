class_name WorkshopPanel
extends CanvasLayer
## Officina (D-049): fra un livello e l'altro si spendono i rottami portati fuori
## in upgrade permanenti. Si apre dalla schermata di fine livello, a gioco fermo;
## controller (croce o stick, A compra, B torna) e mouse o tastiera.

signal closed
signal purchased(id: StringName)
## Acquisto impossibile: rottami insufficienti o upgrade al massimo.
signal rejected(id: StringName)

var is_open := false
var _profile: PlayerProfileService
var _overlay: ColorRect
var _scrap_label: Label
var _rows: VBoxContainer
var _buttons: Dictionary[StringName, Button] = {}

const INK := Color("3b2718")
const INK_GREEN := Color("3f7a2a")
const INK_RED := Color("a8321e")
var _back: Button
var _dots: Dictionary[StringName, LevelDots] = {}


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
	column.custom_minimum_size = Vector2(760, 0)
	column.add_theme_constant_override(&"separation", 10)
	center.add_child(column)
	var title := Label.new()
	title.text = "OFFICINA"
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var total_row := HBoxContainer.new()
	total_row.alignment = BoxContainer.ALIGNMENT_CENTER
	total_row.add_theme_constant_override(&"separation", 8)
	column.add_child(total_row)
	var scrap_icon := UiIcon.make(&"scrap", 24.0, UiPalette.SCRAP)
	scrap_icon.name = "ScrapIcon"
	scrap_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	total_row.add_child(scrap_icon)
	_scrap_label = Label.new()
	_scrap_label.theme_type_variation = &"ScrapLabel"
	_scrap_label.add_theme_font_size_override(&"font_size", 22)
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_row.add_child(_scrap_label)
	# Le voci scorrono (R-21): il catalogo puo crescere oltre lo schermo del Deck e il
	# fuoco del controller resta sempre visibile.
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 6)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	# Il pannello non supera lo schermo: 800 px meno titolo, totale, Torna e prompt.
	scroll.custom_minimum_size.y = minf(float(PermanentCatalog.all().size()) * 64.0, 420.0)
	for entry in PermanentCatalog.all():
		var id: StringName = entry.id
		var button := Button.new()
		button.theme_type_variation = &"CardButton"
		button.custom_minimum_size = Vector2(0, 62)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: _on_pressed(id))
		_rows.add_child(button)
		_buttons[id] = button
		# Icona a sinistra; il testo lascia lo spazio con gli spazi iniziali.
		var icon := UiIcon.make(UiIcon.for_permanent(id), 34.0, UiPalette.BORDER)
		icon.name = "Icon"
		icon.outline = INK
		button.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 14)
		icon.grow_vertical = Control.GROW_DIRECTION_BOTH
		# Pallini del livello a destra: pieni quelli comprati.
		var dots := LevelDots.new()
		dots.name = "Dots"
		dots.total = (entry.costs as Array).size()
		button.add_child(dots)
		dots.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
		dots.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		dots.grow_vertical = Control.GROW_DIRECTION_BOTH
		_dots[id] = dots
	_back = Button.new()
	_back.text = "Torna"
	_back.theme_type_variation = &"MainButton"
	_back.custom_minimum_size = Vector2(0, 50)
	_back.pressed.connect(close)
	column.add_child(_back)
	column.add_child(ButtonPrompts.create([[&"ui_accept", "Compra"], [&"ui_cancel", "Torna"]]))
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
	var fx := get_node_or_null(^"/root/UiFx") as UiFxService
	if fx != null:
		fx.pop_in(_overlay.get_child(0))
	(_rows.get_child(0) as Button).grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_overlay.hide()
	var fx := get_node_or_null(^"/root/UiFx") as UiFxService
	if fx != null:
		fx.play(&"ui_back")
	closed.emit()


## Compra come se la riga fosse premuta (test e automazione).
func press(id: StringName) -> void:
	if is_open and _buttons.has(id):
		_buttons[id].pressed.emit()


func row_text(id: StringName) -> String:
	return _buttons[id].text if _buttons.has(id) else ""


func row_dots(id: StringName) -> LevelDots:
	return _dots.get(id)


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
		var color := INK_GREEN
		if cost >= 0 and _profile.scrap >= cost:
			price = "%d rottami" % cost
			color = INK
		elif cost >= 0:
			price = "%d rottami (ne mancano %d)" % [cost, cost - _profile.scrap]
			color = INK_RED
		var button := _buttons[id]
		button.text = "          %s  %d/%d  -  %s\n          %s" % [entry.name, level, (entry.costs as Array).size(), price, entry.text]
		_dots[id].filled = level
		for state: StringName in [&"font_color", &"font_focus_color", &"font_hover_color", &"font_pressed_color"]:
			button.add_theme_color_override(state, color)


## Pallini del livello di un upgrade permanente: pieni di rame quelli comprati.
class LevelDots extends Control:
	const RADIUS := 5.0
	const GAP := 6.0
	var total := 1:
		set(value):
			total = value
			custom_minimum_size = Vector2(total * (RADIUS * 2.0 + GAP), RADIUS * 2.0)
			queue_redraw()
	var filled := 0:
		set(value):
			filled = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in total:
			var center := Vector2(i * (RADIUS * 2.0 + GAP) + RADIUS, size.y * 0.5)
			draw_circle(center, RADIUS, UiPalette.BORDER if i < filled else Color(UiPalette.BORDER, 0.25))
			draw_arc(center, RADIUS, 0.0, TAU, 16, Color("3b2718"), 1.5)
