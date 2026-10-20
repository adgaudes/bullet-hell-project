extends SceneTree
## Colosso pilotato, eventi e relitti (D-093, piano C): valori di partenza in CaravanTuning e forza
## a bordo in MachineFusion; poi, sulla carovana della scena `ruins_arena` (task 2), i posti in piu,
## il Cassone piu vicino, lo stacco gratuito degli eventi, il guasto e la ritirata forzata.
## Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/colossus_tests.gd

const TUNING_PATH := "res://resources/tuning/caravan_default.tres"
const ArenaScene := preload("res://scenes/main/ruins_arena.tscn")
const RunScene := preload("res://scenes/main/arena_run.tscn")

var _failures := 0
var t: CaravanTuning
var _scene: Node3D
var _field: TerrainField
var _caravan: Caravan
var _queue: TerrainWriteQueue
var _scrap_field: ScrapField
## Sezioni sulla run vera (`arena_run.tscn`, dal task 3).
var _run: ArenaRun
var _player: PlayerCharacter


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	if not OS.get_environment("PROTOTYPE01_SEED").is_valid_int():
		OS.set_environment("PROTOTYPE01_SEED", "20261014")
	t = load(TUNING_PATH) as CaravanTuning
	_check(t != null, "caravan_default.tres si carica come CaravanTuning")
	if t != null:
		_test_tuning()
		_test_power()
		await _test_caravan()
		await _test_relics()
		# Sezioni dei task 4-7, in ordine: _test_events,
		# _test_pilot, _test_mechanic, _test_workshop (tutte con await).
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


func _seconds(seconds: float) -> void:
	await _frames(ceili(seconds * 60))


func _test_tuning() -> void:
	print("tuning")
	_check(is_equal_approx(t.pilot_hold_seconds, 0.5) and is_equal_approx(t.pilot_mount_range, 2.5), "tenuta e portata della salita")
	_check(is_equal_approx(t.pilot_power_bonus, 0.5) and is_equal_approx(t.pilot_speed_factor, 0.7), "+50% ai moduli, -30% di velocita")
	_check(is_equal_approx(t.pilot_fuel_interval, 10.0) and t.pilot_fuel_cost == 1 and is_equal_approx(t.pilot_eject_below, 0.3), "carburante e sbalzo")
	_check(t.pilot_trample_damage == 2 and is_equal_approx(t.pilot_aim_reach, 3.0) and is_equal_approx(t.pilot_forced_retreat_seconds, 6.0), "travolgere, mira, ritirata forzata")
	_check(t.quake_detach_count == 1 and t.train_detach_count == 1 and is_equal_approx(t.train_throw_min, 6.0) and is_equal_approx(t.train_throw_max, 8.0), "eventi")
	_check(is_equal_approx(t.relic_pickup_range, 2.0) and t.module_limit == 6, "relitto a 2 m; il limite del tuning resta 6")


func _test_power() -> void:
	print("power")
	_check(is_equal_approx(MachineFusion.power_of(6, t), 1.75) and is_equal_approx(MachineFusion.power_of(6, t, true), 2.625), "forza del colosso: 1,75 autonomo, 2,625 pilotato")
	_check(is_equal_approx(MachineFusion.power_of(1, t, true), 1.5), "una piccola pilotata (solo logica) varrebbe 1,5")
	_check(is_equal_approx(MachineFusion.pilot_speed(6.0, t), 4.2), "6 m/s a piedi: 4,2 a bordo")


func _test_caravan() -> void:
	print("caravan")
	_scene = ArenaScene.instantiate()
	_scene.name = "Scene"
	root.add_child(_scene)
	_field = _scene.get_node(^"TerrainField")
	_caravan = _scene.get_node(^"Caravan")
	_scrap_field = _scene.get_node(^"ScrapField")
	_queue = TerrainWriteQueue.new()
	_queue.name = "TerrainWriteQueue"
	_queue.terrain_field = _field
	_scene.add_child(_queue)
	_caravan.configure({terrain_field = _field, write_queue = _queue})
	await _frames(2)
	_check(_caravan.scrap_field == _scrap_field, "la carovana usa lo ScrapField della scena")
	await _reset()
	_test_module_limit()
	await _test_nearest_cargo()
	await _test_detach_random()
	await _test_break_and_retreat()
	root.remove_child(_scene)
	_scene.queue_free()


## Carovana con il solo Cassone (3 rottami) e nessun posto in piu: le macchine di prima escono con
## `remove_machine` (come in fusion_tests).
func _reset() -> Machine:
	for machine in _caravan.machines.duplicate():
		_caravan.remove_machine(machine)
	_caravan.extra_module_slots = 0
	await _frames(1)
	var lead := _caravan.add_machine(&"cargo")
	_caravan.carried = 3
	return lead


## Capofila Cassone con la Torretta fusa dentro: 5 rottami chiesti (ne entrano 2, Cassone pieno a
## 5), fusione da 1, ne restano 4 nel Cassone.
func _reset_fused() -> Machine:
	var lead: Machine = await _reset()
	var turret := _add(&"turret")
	_caravan.add_scrap(5)
	_check(_caravan.fuse(lead, turret) and lead.modules.size() == 2 and _caravan.carried == 4, "Cassone e Torretta fusi, 4 rottami")
	return lead


func _add(module_id: StringName) -> Machine:
	var machine := _caravan.add_machine(module_id)
	_check(machine != null and machine.has_module(module_id), "add_machine(%s)" % module_id)
	return machine


## Guasta subito, senza immunita ne invulnerabilita.
func _break(machine: Machine) -> void:
	machine._hit_cooldown_left = 0.0
	machine._invulnerable_left = 0.0
	machine.take_hit(machine.health)


func _place(machine: Machine, at: Vector3) -> void:
	machine.global_position = Vector3(at.x, _field.height_at(at) + Caravan.GROUND_CLEARANCE, at.z)
	machine.velocity = Vector3.ZERO
	machine.reset_physics_interpolation()


## Officina mobile: il settimo posto sta nella carovana (`extra_module_slots`), non nel tuning.
func _test_module_limit() -> void:
	print("module limit")
	for id: StringName in [&"turret", &"drill", &"shovel", &"welder", &"siren"]:
		_add(id)
	_check(_caravan.module_count() == 6 and not _caravan.has_room() and _caravan.module_limit() == 6, "piena a 6")
	_caravan.extra_module_slots = 1
	_check(_caravan.module_limit() == 7 and _caravan.has_room() and _caravan.add_machine(&"magnet") != null, "Officina mobile: settimo posto")
	_check(not _caravan.has_room() and _caravan.tuning.module_limit == 6, "piena a 7; il tuning condiviso resta 6")


func _test_nearest_cargo() -> void:
	print("nearest cargo")
	await _reset()
	var a := _caravan.lead()
	var b := _add(&"cargo")
	var c := _add(&"turret")
	_place(a, Vector3(10, 0, 0))
	_place(b, Vector3(2, 0, 0))
	_place(c, Vector3(0, 0, 0))
	_check(_caravan.nearest_cargo_machine(Vector3.ZERO) == b, "il Cassone piu vicino, non il capofila ne la Torretta")
	_break(b)
	_check(_caravan.nearest_cargo_machine(Vector3.ZERO) == b, "anche guasto")
	_caravan.remove_machine(a)
	_caravan.remove_machine(b)
	_check(_caravan.nearest_cargo_machine(Vector3.ZERO) == c and _caravan.lead() == c, "senza Cassoni il capofila")
	_caravan.remove_machine(c)
	_check(_caravan.nearest_cargo_machine(Vector3.ZERO) == null, "senza macchine null")


## Stacco degli eventi (terremoto, treno): gratis, senza macchina nuova, la sorgente conserva la
## frazione di vita, i rottami di un Cassone staccato cadono a terra accanto alla macchina.
func _test_detach_random() -> void:
	print("detach random")
	var m: Machine = await _reset_fused()
	m.health = 10
	_check(m.max_health == 15, "media a 15 PV (10/15)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var id := _caravan.detach_random(m, rng)
	_check(id == &"turret" or id == &"cargo", "stacca uno dei due (%s)" % id)
	_check(m.modules.size() == 1 and m.max_health == 6 and m.health == 4 and _caravan.machines.size() == 1, "sorgente a un modulo, 4/6 (frazione conservata), nessuna macchina nuova")
	_check(_caravan.detach_random(m, rng) == &"" and m.modules.size() == 1, "una piccola non perde nulla")
	var outsider := Machine.new()
	_check(_caravan.detach_random(outsider, rng) == &"", "una macchina fuori dalla carovana non perde nulla")
	outsider.free()
	# Cassone staccato coi rottami: a terra. Si rifonde finche lo staccato e il Cassone (lo
	# staccato con la Torretta non lascia rottami: il conteggio di prima resta valido).
	var before := _scrap_field.count()
	var dropped: Array[Vector3] = []
	var on_spawn := func(at: Vector3) -> void: dropped.append(at)
	_scrap_field.scrap_spawned.connect(on_spawn)
	m = await _reset_fused()
	var tries := 1
	while _caravan.detach_random(m, rng) != &"cargo" and tries < 20:
		m = await _reset_fused()
		tries += 1
	_scrap_field.scrap_spawned.disconnect(on_spawn)
	_check(tries < 20, "il Cassone esce entro 20 prove (%d)" % tries)
	_check(_caravan.carried == 0 and _scrap_field.count() == before + 4 and dropped.size() == 4, "4 rottami a terra (5 meno il costo della fusione)")
	var beside := dropped.size() == 4
	for i in dropped.size():
		var from_machine := Machine.planar_distance(dropped[i], m.global_position)
		beside = beside and from_machine > 0.5 and from_machine < 2.0
		if i > 0:
			beside = beside and is_equal_approx(Machine.planar_distance(dropped[i], dropped[i - 1]), 0.8)
	_check(beside, "in fila accanto alla macchina, a 0,8 m l'uno dall'altro")
	# Da guasta: si stacca lo stesso e resta guasta a 0 PV.
	m = await _reset_fused()
	_break(m)
	_check(_caravan.detach_random(m, rng) != &"" and m.modules.size() == 1 and m.is_broken() and m.health == 0, "anche da guasta, resta guasta")


func _test_break_and_retreat() -> void:
	print("break and retreat")
	var m: Machine = await _reset()
	var hits := [0]
	m.damaged.connect(func(_amount: int) -> void: hits[0] += 1)
	m.break_down()
	_check(m.is_broken() and m.health == 0 and hits[0] == 0 and m._hit_cooldown_left == 0.0, "guasta subito, senza damaged ne immunita")
	m.break_down()
	_check(m.is_broken() and m.health == 0, "su una guasta non fa nulla")
	m.repair(0.5)
	m.force_retreat(1.0)
	await _frames(1)
	_check(m.state == Machine.State.RETREAT, "in ritirata forzata a meta vita (sopra retreat_below)")
	await _seconds(1.1)
	_check(m.state == Machine.State.OK, "scaduta: torna in ordine")
	m.force_retreat(1.0)
	m.break_down()
	_check(m.is_broken(), "guasta vince sulla ritirata forzata")
	_check(m.trample_damage() == 1, "travolgere di base 1")
	m.piloted = true
	_check(m.trample_damage() == 2, "travolgere pilotato 2")
	m.piloted = false


# --- Relitti dei moduli staccati (task 3) ------------------------------------------------------

## Run vera senza nemici, level-up, boss ne eventi (come fusion_tests._test_bench); il disco
## protetto della partenza si toglie per poter scolpire vicino al giocatore.
func _test_relics() -> void:
	print("relics")
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	_run = _scene.get_node(^"Run")
	_player = _scene.get_node(^"Player")
	_caravan = _scene.get_node(^"Caravan")
	_field = _scene.get_node(^"TerrainField")
	(_scene.get_node(^"EnemyDirector") as EnemyDirector).spawning = false
	await _frames(5)
	(_scene.get_node(^"PlayerWeapon") as AutoWeapon).set_physics_process(false)
	_run.progression.xp_first_level = 100000
	_run.boss_call_at = 0.0
	for event: WorldEvent in [_run.quake_event, _run.train_event]:
		if event != null:
			event.schedule([])
	var relics := _run.module_relics
	_check(relics != null and relics.get_parent() == _run and relics.name == "ModuleRelics" and relics.terrain_field == _field
		and relics.player == _player and relics.count() == 0, "ModuleRelics creato da ArenaRun coi servizi, vuoto")
	if relics == null:
		root.remove_child(_scene)
		_scene.queue_free()
		return
	# `arena_run.tscn` ha il terremoto e non il treno (sta nella scena dei binari).
	_check(_run.quake_event != null and _run.quake_event.module_relics == relics
		and (_run.train_event == null or _run.train_event.module_relics == relics), "il terremoto (e il treno, se c'e) riceve i relitti")
	_run._start_protect_left = 0.0
	_field.set_protected(Vector3.ZERO, _field.tuning.start_protected_radius_m, false)
	await _test_relic_pickup()
	await _test_relic_full_and_nearest()
	await _test_relic_follows_ground()
	await _test_relic_glint()
	_test_relic_models()
	root.remove_child(_scene)
	_scene.queue_free()


func _test_relic_pickup() -> void:
	var relics := _run.module_relics
	var at := _player.global_position + Vector3(1.0, 0.0, 0.0)
	var i := relics.drop(&"siren", at)
	_check(relics.count() == 1 and relics.module_of(i) == &"siren" and relics.nearest_index(_player.global_position, 2.0) == i, "relitto a 1 m")
	_check(relics.nearest_index(_player.global_position, 0.5) == -1, "fuori portata: nessun indice")
	await _frames(1)
	_check(_run.hud.caravan_strip().relic_prompt_visible() and not _run.hud.caravan_strip().bench_prompt_visible(), "tasto Riprendi acceso")
	var machines := _caravan.machines.size()
	await _joy(JOY_BUTTON_X)
	await _frames(2)
	_check(relics.count() == 0 and _caravan.machines.size() == machines + 1 and _caravan.machines[-1].primary_module_id() == &"siren", "X: la Sirena torna macchina piccola")
	_check(not _run.fusion_pad.has_bench_request(), "la pressione che riprende non chiede il banco")
	await _frames(1)
	_check(not _run.hud.caravan_strip().relic_prompt_visible(), "ripreso: tasto Riprendi spento")


func _test_relic_full_and_nearest() -> void:
	while _caravan.has_room():
		_caravan.add_machine(&"turret")
	var relics := _run.module_relics
	relics.drop(&"drill", _player.global_position + Vector3(1.5, 0.0, 0.0))
	relics.drop(&"shovel", _player.global_position + Vector3(0.6, 0.0, 0.0))
	await _frames(1)
	_check(not _run.hud.caravan_strip().relic_prompt_visible() and not _run.relic_available(), "piena: tasto spento")
	await _key(KEY_R)
	await _frames(2)
	_check(relics.count() == 2, "piena: R non prende nulla")
	_caravan.remove_machine(_caravan.machines[-1])
	await _frames(1)
	_check(_run.relic_available() and _run.hud.caravan_strip().relic_prompt_visible(), "con posto: tasto Riprendi acceso")
	await _key(KEY_R)
	await _frames(2)
	_check(relics.count() == 1 and relics.module_of(relics.nearest_index(_player.global_position, 5.0)) == &"drill"
		and _caravan.machines[-1].primary_module_id() == &"shovel", "con posto: R prende la Pala, la piu vicina")
	relics.discard_in_rect(Rect2(-100, -100, 200, 200))
	_check(relics.count() == 0, "discard_in_rect li toglie")


func _test_relic_follows_ground() -> void:
	var relics := _run.module_relics
	var at := _player.global_position + Vector3(4.0, 0.0, 0.0)
	var i := relics.drop(&"turret", at)
	var y0 := relics.position_of(i).y
	_check(is_equal_approx(y0, _field.height_at(at)), "il pezzo poggia alla quota del suolo")
	_field.set_protected(at, 2.0, false)
	_field.sculpt(at, 1.0, 1.0)
	await _frames(4)
	_check(relics.position_of(i).y > y0 + 0.5, "il pezzo sale col suolo")
	relics.take(i)
	_check(relics.count() == 0, "take lo toglie")


## Il luccichio si vede solo entro GLINT_RANGE dal giocatore; senza relitti _process e spento.
func _test_relic_glint() -> void:
	var relics := _run.module_relics
	var near := relics.drop(&"magnet", _player.global_position + Vector3(1.0, 0.0, 0.0))
	var far := relics.drop(&"beacon", _player.global_position + Vector3(0.0, 0.0, ModuleRelics.GLINT_RANGE + 3.0))
	await process_frame
	await process_frame
	_check(relics.is_processing() and relics.glint_visible(near) and not relics.glint_visible(far), "luccichio vicino si, lontano no")
	relics.take(near)
	relics.take(far)
	_check(relics.count() == 0 and not relics.is_processing(), "senza relitti il luccichio non gira")


## Pezzo del modulo (Torretta) o, senza pezzo (Cassone), cubo da 0,4 m del colore del catalogo;
## sempre sul layer visivo delle macchine.
func _test_relic_models() -> void:
	var relics := _run.module_relics
	var turret := relics.drop(&"turret", _player.global_position + Vector3(-3.0, 0.0, 0.0))
	var cargo := relics.drop(&"cargo", _player.global_position + Vector3(-3.0, 0.0, 2.0))
	var meshes := relics.piece_of(turret).find_children("*", "MeshInstance3D", true, false)
	var layered := not meshes.is_empty()
	for mesh: MeshInstance3D in meshes:
		layered = layered and mesh.layers == Machine.VISUAL_LAYER
	_check(meshes.size() > 1 and layered, "Torretta: il suo pezzo, sul layer delle macchine")
	var boxes := relics.piece_of(cargo).find_children("*", "MeshInstance3D", true, false)
	var box: MeshInstance3D = boxes[0] if boxes.size() == 1 else null
	_check(box != null and box.mesh is BoxMesh and (box.mesh as BoxMesh).size.is_equal_approx(Vector3.ONE * 0.4)
		and (box.material_override as StandardMaterial3D).albedo_color == MachineCatalog.find(&"cargo").color
		and box.layers == Machine.VISUAL_LAYER, "Cassone senza pezzo: cubo da 0,4 m del suo colore")
	relics.take(turret)
	relics.take(cargo)


func _send_joypad_button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	event.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


## Pressione e rilascio in frame distinti, come un dito reale (da fusion_tests).
func _joy(button: JoyButton) -> void:
	_send_joypad_button(button, true)
	await process_frame
	_send_joypad_button(button, false)
	await process_frame


func _send_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _key(key: Key) -> void:
	_send_key(key, true)
	await process_frame
	_send_key(key, false)
	await process_frame
