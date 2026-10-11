extends SceneTree
## Test dell'intro all'avvio (D-080). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/intro_tests.gd

const IntroScene := preload("res://scenes/main/boot_intro.tscn")

var _failures := 0


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	await _frames(1)
	_test_skip_rules()
	await _test_sequence_completes()
	await _test_skip_on_input()
	await _test_handoff_keeps_pause_disabled()
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


func _test_skip_rules() -> void:
	_check(BootIntro.should_skip(PackedStringArray(["--autostart"]), false), "--autostart salta l'intro")
	_check(BootIntro.should_skip(PackedStringArray(["--level=railway"]), false), "--level= salta l'intro")
	_check(BootIntro.should_skip(PackedStringArray([]), true), "headless salta l'intro")
	_check(not BootIntro.should_skip(PackedStringArray([]), false), "avvio normale: intro")
	_check(not BootIntro.should_skip(PackedStringArray(["--intro-test"]), true), "--intro-test la forza anche in headless")
	_check(RunLaunchOptions.wants_intro_test(PackedStringArray(["--intro-test"])), "RunLaunchOptions legge --intro-test")


## Con force_play la sequenza gira in headless e finisce da sola entro 5 s.
func _test_sequence_completes() -> void:
	var intro := IntroScene.instantiate() as BootIntro
	intro.force_play = true
	intro.change_scene_on_finish = false
	root.add_child(intro)
	await _frames(2)
	var pause := root.get_node("PauseMenu")
	_check(intro.is_playing and pause.get(&"enabled") == false, "intro in corso, pausa disattivata")
	var done := [false]
	intro.finished.connect(func() -> void: done[0] = true)
	await _frames(60 * 5)
	_check(done[0] and not intro.is_playing, "finita entro 5 s")
	_check(pause.get(&"enabled") == true, "pausa riattivata alla fine")
	_check(intro.logo().is_complete(), "logo completo alla fine")
	intro.queue_free()
	await _frames(1)


## Un tasto a meta la chiude prima; un secondo tasto non la chiude due volte.
func _test_skip_on_input() -> void:
	var intro := IntroScene.instantiate() as BootIntro
	intro.force_play = true
	intro.change_scene_on_finish = false
	root.add_child(intro)
	await _frames(30)
	var count := [0]
	intro.finished.connect(func() -> void: count[0] += 1)
	intro.skip()
	intro.skip()
	await _frames(60)
	_check(count[0] == 1 and not intro.is_playing, "salto: una sola fine (%d)" % count[0])
	_check(intro.logo().is_complete(), "il salto mostra il logo completo")
	intro.queue_free()
	await _frames(1)


## Quando l'intro passa la mano al menu, la pausa resta disattivata finche il menu non
## la gestisce da solo: altrimenti un Esc nel frame del cambio scena apre il pannello
## di pausa sopra il menu.
func _test_handoff_keeps_pause_disabled() -> void:
	var intro := IntroScene.instantiate() as BootIntro
	intro.force_play = true
	intro.change_scene_on_finish = true
	root.add_child(intro)
	await _frames(5)
	var pause := root.get_node("PauseMenu")
	var enabled_at_finish := [true]
	intro.finished.connect(func() -> void: enabled_at_finish[0] = pause.get(&"enabled"))
	intro.skip()
	await _frames(60)
	_check(not enabled_at_finish[0], "alla fine dell'intro con cambio scena la pausa e ancora disattivata")
	await _frames(3)
	_check(root.get_node_or_null("PauseMenu/%Overlay") != null and not (root.get_node("PauseMenu/%Overlay") as Control).visible, "nessun pannello di pausa aperto dopo il cambio scena")
	if is_instance_valid(intro):
		intro.queue_free()
	await _frames(1)
