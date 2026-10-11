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
	await _test_logo()
	await _test_screens_focus()
	await _test_pause_and_settings()
	await _test_cards_and_panels()
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


## Il tema di progetto (`gui/theme/custom`, generato da build_theme.gd) e aggiornato
## rispetto a UiPalette: i CanvasLayer lo ricevono solo da li.
func _test_theme_on_root() -> void:
	var project := ThemeDB.get_project_theme()
	_check(project != null, "tema di progetto registrato")
	if project == null:
		return
	_check(project.get_font_size(&"font_size", &"TitleLabel") == UiPalette.SIZE_TITLE, "tema di progetto: titolo a %d" % UiPalette.SIZE_TITLE)
	_check(project.default_font_size == UiPalette.SIZE_TEXT, "tema di progetto: testo a %d" % UiPalette.SIZE_TEXT)
	var focus := project.get_stylebox(&"focus", &"Button") as StyleBoxFlat
	_check(focus != null and focus.border_color.is_equal_approx(UiPalette.FOCUS), "tema di progetto: focus turchese")
	_check(project.get_type_variation_base(&"MainButton") == &"Button" and project.get_type_variation_base(&"HudLabel") == &"Label", "tema di progetto: varianti presenti (rigenerare con build_theme.gd se manca)")


func _test_logo() -> void:
	for layout in ["wide", "stacked"]:
		var logo := GameLogo.new()
		logo.layout = layout
		root.add_child(logo)
		await _frames(1)
		_check(logo.letter_count() == GameLogo.TITLE.length(), "%s: una Label per lettera" % layout)
		_check(logo.custom_minimum_size.x > 300 and logo.custom_minimum_size.y > 80, "%s: dimensione calcolata" % layout)
		for p in [0.0, 0.5, 1.0]:
			logo.set_letter_progress(p)
			logo.set_nail_progress(p)
			logo.set_subtitle_progress(p)
			logo.set_grass_progress(p)
		logo.set_all(1.0)
		_check(logo.is_complete(), "%s: set_all(1) completa il logo" % layout)
		logo.queue_free()
	await _frames(1)


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
	_check((menu.get_node_or_null(^"Background") as ColorRect).material is ShaderMaterial, "sfondo con il cielo dipinto")
	_check(menu.get_node_or_null(^"Logo") is GameLogo, "logo nel menu")
	_check(menu.get_node_or_null(^"ProfilePlate") is PanelContainer, "targhetta del profilo")
	menu.queue_free()
	await _frames(2)


## Pausa e Impostazioni usano le varianti del tema, non dimensioni scritte a mano.
func _test_pause_and_settings() -> void:
	var pause := root.get_node("PauseMenu")
	var pause_title: Label = pause.get_node("%PausePanel/Margin/Buttons/Title")
	_check(pause_title.theme_type_variation == &"TitleLabel", "titolo della pausa in TitleLabel")
	var settings: Control = pause.get_node("%SettingsPanel")
	var header: Label = settings.get_node("%Content/GraphicsHeader")
	_check(header.theme_type_variation == &"SectionLabel", "intestazione Grafica in SectionLabel")
	_check(settings.get_node_or_null("%Content/GraphicsRule") is ColorRect, "riga rame sotto Grafica")
	var hand_sized := 0
	for node in _descendants(pause):
		if node is Control and (node as Control).has_theme_font_size_override(&"font_size"):
			hand_sized += 1
	_check(hand_sized == 0, "nessuna dimensione di font scritta a mano nella pausa (%d)" % hand_sized)
	var buttons: Array[Button] = []
	_collect_buttons(pause, buttons)
	var main_buttons := 0
	for button in buttons:
		if button.theme_type_variation == &"MainButton":
			main_buttons += 1
	_check(main_buttons >= 5, "Riprendi, Impostazioni, Torna al menu, Esci e Indietro in MainButton (%d)" % main_buttons)
	_check(settings.custom_minimum_size.x == 760.0, "pannello Impostazioni largo 760")


## Level-up a carte con fascia di rarita, Officina e campagna con le varianti del tema.
func _test_cards_and_panels() -> void:
	var level_up := LevelUpMenu.new()
	root.add_child(level_up)
	await _frames(1)
	var offer: Array[Dictionary] = UpgradeCatalog.all().slice(0, 3)
	level_up.open(offer, {}, 2)
	await _frames(2)
	_check(level_up.card_count() == 3, "tre carte")
	var text := level_up.card_text(0)
	_check(text.contains(UpgradeCatalog.RARITY_NAMES[offer[0].rarity]) and text.contains(offer[0].name), "la carta mostra rarita e nome: %s" % text.replace("
", " | "))
	_check(level_up.title_text() == "LIVELLO 2", "titolo del level-up: %s" % level_up.title_text())
	var card := level_up.card(0)
	_check(card.theme_type_variation == &"CardButton" and card.custom_minimum_size == Vector2(300, 300), "carta CardButton 300x300")
	var focus_box := card.get_theme_stylebox(&"focus") as StyleBoxFlat
	_check(focus_box != null and focus_box.shadow_size > 0, "carta con bagliore sul focus")
	level_up.close()
	level_up.queue_free()
	var workshop := WorkshopPanel.new()
	root.add_child(workshop)
	await _frames(1)
	workshop.open()
	await _frames(1)
	var rows: Array[Button] = []
	_collect_buttons(workshop, rows)
	var card_rows := 0
	for row in rows:
		if row.theme_type_variation == &"CardButton":
			card_rows += 1
	_check(card_rows == PermanentCatalog.all().size(), "righe dell'Officina in CardButton (%d)" % card_rows)
	_check(workshop._scrap_label.theme_type_variation == &"ScrapLabel", "contatore rottami in ScrapLabel")
	workshop.close()
	workshop.queue_free()
	var campaign := CampaignMapPanel.new()
	root.add_child(campaign)
	await _frames(1)
	campaign.open()
	await _frames(1)
	var level_cards: Array[Button] = []
	_collect_buttons(campaign._row, level_cards)
	_check(level_cards.size() == LevelCatalog.count() and level_cards[0].theme_type_variation == &"CardButton", "livelli della campagna come carte")
	var links := 0
	for child in campaign._row.get_children():
		if child is ColorRect:
			links += 1
	_check(links == LevelCatalog.count() - 1, "una linea rame fra una carta e l'altra (%d)" % links)
	campaign.close()
	campaign.queue_free()
	await _frames(2)


func _descendants(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_descendants(child))
	return out


func _collect_buttons(node: Node, out: Array[Button]) -> void:
	if node is Button:
		out.append(node)
	for child in node.get_children():
		_collect_buttons(child, out)
