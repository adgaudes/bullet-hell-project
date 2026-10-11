extends SceneTree
## Test del tema dell'interfaccia (D-080). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/ui_theme_tests.gd

const MenuScene := preload("res://scenes/main/main_menu.tscn")

var _failures := 0


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	await _frames(1)
	_test_palette()
	_test_theme_on_root()
	await _test_screens_focus()
	await _frames(2)
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _test_palette() -> void:
	_check(UiPalette.title_font() != null and UiPalette.text_font() != null, "i due font si caricano")
	_check(UiPalette.title_font() != ThemeDB.fallback_font and UiPalette.text_font() != ThemeDB.fallback_font, "nessuno dei due e il font di riserva")
	_check(UiPalette.text_font(700) != UiPalette.text_font(400), "il peso 700 e una variazione distinta")
	var theme := UiPalette.build_theme()
	_check(theme.default_font == UiPalette.text_font(), "font di testo predefinito nel tema")
	_check(theme.default_font_size == 18, "testo a 18 px")
	for variation: StringName in [&"TitleLabel", &"SectionLabel", &"MutedLabel", &"HudLabel", &"ScrapLabel"]:
		_check(theme.get_type_variation_base(variation) == &"Label", "variante %s di Label" % variation)
	for variation: StringName in [&"MainButton", &"CardButton"]:
		_check(theme.get_type_variation_base(variation) == &"Button", "variante %s di Button" % variation)
	_check(theme.get_font_size(&"font_size", &"TitleLabel") == 40, "titolo a 40 px")
	var smallest := 999
	for type_name in theme.get_font_size_type_list():
		for size_name in theme.get_font_size_list(type_name):
			smallest = mini(smallest, theme.get_font_size(size_name, type_name))
	_check(smallest >= 14, "nessuna dimensione sotto 14 px (minima %d)" % smallest)
	var normal := theme.get_stylebox(&"normal", &"Button") as StyleBoxFlat
	var focus := theme.get_stylebox(&"focus", &"Button") as StyleBoxFlat
	var hover := theme.get_stylebox(&"hover", &"Button") as StyleBoxFlat
	_check(normal != null and focus != null and hover != null, "pulsante con stylebox piatti")
	_check(focus.border_color == UiPalette.FOCUS and focus.border_color != hover.border_color, "focus turchese, diverso dall'hover")
	_check(focus.shadow_size > 0 and normal.shadow_size == 0, "bagliore solo sul focus")
	_check(UiPalette.paper_texture() != null and UiPalette.paper_texture() == UiPalette.paper_texture(), "grana di carta generata una volta")


func _test_theme_on_root() -> void:
	_check(root.theme != null and root.theme.default_font == UiPalette.text_font(), "l'autoload UiTheme applica il tema alla radice")


## Ogni pulsante delle schermate eredita dal tema un focus diverso dal normale.
func _test_screens_focus() -> void:
	var menu := MenuScene.instantiate()
	root.add_child(menu)
	await _frames(3)
	var buttons: Array[Button] = []
	_collect_buttons(menu, buttons)
	_check(buttons.size() >= 4, "menu con almeno 4 pulsanti (%d)" % buttons.size())
	var all_distinct := true
	var all_big := true
	for button in buttons:
		if button.get_theme_stylebox(&"focus") == button.get_theme_stylebox(&"normal"):
			all_distinct = false
		if button.get_theme_font_size(&"font_size") < 14:
			all_big = false
	_check(all_distinct, "ogni pulsante del menu ha un focus distinto")
	_check(all_big, "nessun pulsante sotto 14 px")
	_check((menu.get_node_or_null(^"Background") as Control) != null, "menu con sfondo dipinto")
	menu.queue_free()
	await _frames(2)


func _collect_buttons(node: Node, out: Array[Button]) -> void:
	if node is Button:
		out.append(node)
	for child in node.get_children():
		_collect_buttons(child, out)
