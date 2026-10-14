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
var _detail_id: StringName = &""
var _detail_icon: UiIcon
var _detail_name: Label
var _detail_text: Label
var _detail_level: Label
var _detail_price: Label


func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	_profile = get_node_or_null(^"/root/PlayerProfile") as PlayerProfileService
	# Fondo opaco (playtest O-13): prima la schermata di fine livello trapelava dietro.
	_overlay = ColorRect.new()
	_overlay.color = UiPalette.BG
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(1060, 0)
	column.add_theme_constant_override(&"separation", 10)
	center.add_child(column)
	# Testata: titolo a sinistra, totale dei rottami a destra.
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 8)
	column.add_child(header)
	var title := Label.new()
	title.text = "OFFICINA"
	title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var scrap_icon := UiIcon.make(&"scrap", 28.0, UiPalette.SCRAP)
	scrap_icon.name = "ScrapIcon"
	scrap_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(scrap_icon)
	_scrap_label = Label.new()
	_scrap_label.theme_type_variation = &"ScrapLabel"
	_scrap_label.add_theme_font_size_override(&"font_size", 26)
	_scrap_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_scrap_label)
	var intro := Label.new()
	intro.theme_type_variation = &"MutedLabel"
	intro.text = "I rottami che porti fuori dai livelli restano qui: spendili in migliorie che valgono per tutte le run."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(intro)
	# Corpo: a sinistra le carte per sezione, a destra il dettaglio della carta col fuoco.
	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 18)
	column.add_child(body)
	var cards := VBoxContainer.new()
	cards.add_theme_constant_override(&"separation", 6)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(cards)
	_rows = cards
	for group: Array in PermanentCatalog.GROUPS:
		var section := Label.new()
		section.theme_type_variation = &"SectionLabel"
		section.text = String(group[1]).to_upper()
		cards.add_child(section)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override(&"h_separation", 8)
		grid.add_theme_constant_override(&"v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_child(grid)
		for entry in PermanentCatalog.all():
			if entry.get("group", &"engineer") != group[0]:
				continue
			grid.add_child(_make_card(entry))
	body.add_child(_make_detail())
	_back = Button.new()
	_back.text = "Torna"
	_back.theme_type_variation = &"MainButton"
	_back.custom_minimum_size = Vector2(0, 50)
	_back.pressed.connect(close)
	column.add_child(_back)
	column.add_child(ButtonPrompts.create([[&"ui_accept", "Compra"], [&"ui_cancel", "Torna"]]))
	_overlay.hide()


## Carta di un upgrade: icona a sinistra, nome e livello, prezzo sotto, pallini in alto a destra.
func _make_card(entry: Dictionary) -> Button:
	var id: StringName = entry.id
	var button := Button.new()
	button.name = "Card_%s" % id
	button.theme_type_variation = &"CardButton"
	button.custom_minimum_size = Vector2(320, 66)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(func() -> void: _on_pressed(id))
	button.focus_entered.connect(func() -> void: _show_detail(id))
	button.mouse_entered.connect(func() -> void: _show_detail(id))
	_buttons[id] = button
	# Il testo lascia lo spazio all'icona col margine dello stile, non con spazi iniziali.
	var theme := ThemeDB.get_project_theme()
	if theme != null:
		for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			var box := theme.get_stylebox(state, &"CardButton")
			if box != null:
				box = box.duplicate()
				box.content_margin_left = 64.0
				box.content_margin_right = 52.0
				button.add_theme_stylebox_override(state, box)
	var icon := UiIcon.make(UiIcon.for_permanent(id), 36.0, UiPalette.BORDER)
	icon.name = "Icon"
	icon.outline = INK
	button.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 14)
	icon.grow_vertical = Control.GROW_DIRECTION_BOTH
	var dots := LevelDots.new()
	dots.name = "Dots"
	dots.total = (entry.costs as Array).size()
	button.add_child(dots)
	dots.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
	dots.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_dots[id] = dots
	return button


## Dettaglio: cosa fa l'upgrade, a che livello sei, quanto costa il prossimo.
func _make_detail() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Detail"
	panel.custom_minimum_size = Vector2(360, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	_detail_icon = UiIcon.make(&"scrap", 72.0, UiPalette.BORDER)
	_detail_icon.outline = INK
	_detail_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_detail_icon)
	_detail_name = Label.new()
	_detail_name.theme_type_variation = &"SectionLabel"
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_detail_name)
	_detail_text = Label.new()
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size = Vector2(320, 0)
	box.add_child(_detail_text)
	_detail_level = Label.new()
	_detail_level.theme_type_variation = &"MutedLabel"
	box.add_child(_detail_level)
	_detail_price = Label.new()
	_detail_price.theme_type_variation = &"ScrapLabel"
	_detail_price.add_theme_font_size_override(&"font_size", 22)
	_detail_price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail_price)
	return panel


func _show_detail(id: StringName) -> void:
	_detail_id = id
	var entry := PermanentCatalog.find(id)
	if entry.is_empty() or _profile == null:
		return
	_detail_icon.kind = UiIcon.for_permanent(id)
	_detail_name.text = entry.name
	_detail_text.text = entry.text
	var level := _profile.level_of(id)
	_detail_level.text = "Livello %d di %d" % [level, (entry.costs as Array).size()]
	var cost := _profile.cost_of(id)
	if cost < 0:
		_detail_price.text = "Al massimo"
		_detail_price.add_theme_color_override(&"font_color", Color("8fcf5f"))
	elif _profile.scrap >= cost:
		_detail_price.text = "Prossimo livello: %d rottami" % cost
		_detail_price.remove_theme_color_override(&"font_color")
	else:
		_detail_price.text = "Prossimo livello: %d rottami\nNe mancano %d" % [cost, cost - _profile.scrap]
		_detail_price.add_theme_color_override(&"font_color", Color("e0603f"))


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
	var first: StringName = PermanentCatalog.all()[0].id
	_buttons[first].grab_focus()
	_show_detail(first)


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
		var price := "Al massimo"
		var color := INK_GREEN
		if cost >= 0 and _profile.scrap >= cost:
			price = "%d rottami" % cost
			color = INK
		elif cost >= 0:
			price = "%d rottami, ne mancano %d" % [cost, cost - _profile.scrap]
			color = INK_RED
		var button := _buttons[id]
		button.text = "%s  %d/%d\n%s" % [entry.name, level, (entry.costs as Array).size(), price]
		_dots[id].filled = level
		for state: StringName in [&"font_color", &"font_focus_color", &"font_hover_color", &"font_pressed_color"]:
			button.add_theme_color_override(state, color)
	if _detail_id != &"":
		_show_detail(_detail_id)


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
