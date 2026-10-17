extends SceneTree
## Striscia della carovana nel HUD (spec D-093, task 7 del piano A) sulla run vera di
## `arena_run.tscn`, coi soli segnali di ArenaRun: una casella per macchina con stato e vita,
## rottami "portati/capienza", tasto Ripara vicino a una macchina guasta, spicchio della
## riparazione; frecce degli indicatori sopra la colonna in basso a destra. Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/caravan_hud_tests.gd

const RunScene := preload("res://scenes/main/arena_run.tscn")
## Piano aperto e quasi in piano (come in machine_damage_tests).
const AREA := Vector3(0.0, 0.0, 16.0)
## Direzioni degli indicatori: a 1280x1280 (headless) le tre centrali arrivano sopra la colonna.
const MARKER_DIRECTIONS: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(0.8, 1.0),
	Vector2(1.0, 0.9), Vector2(1.0, 0.6), Vector2(1.0, 0.3)]

var _failures := 0
var _scene: Node3D
var _run: ArenaRun
var _field: TerrainField
var _player: PlayerCharacter
var _caravan: Caravan
var _director: EnemyDirector
var _path: PathField
## Notifiche `changed` della carovana.
var _changed := 0


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	_run = _scene.get_node(^"Run")
	_field = _scene.get_node(^"TerrainField")
	_player = _scene.get_node(^"Player")
	_caravan = _scene.get_node(^"Caravan")
	_director = _scene.get_node(^"EnemyDirector")
	_path = _scene.get_node(^"PathField")
	_director.spawning = false
	await _frames(5)
	# Come machine_damage_tests: niente chiodatrice del giocatore, level-up, boss ne eventi;
	# il giocatore non muore.
	(_scene.get_node(^"PlayerWeapon") as AutoWeapon).set_physics_process(false)
	_run.progression.xp_first_level = 100000
	_run.boss_call_at = 0.0
	for event: WorldEvent in [_run.quake_event, _run.train_event]:
		if event != null:
			event.schedule([])
	_player._invulnerable_left = 3600.0
	_caravan.changed.connect(_on_caravan_changed)
	await _test_strip()
	await _test_markers()
	root.remove_child(_scene)
	_scene.queue_free()
	# T-12: i nodi messi in coda con queue_free vanno liberati prima di uscire.
	await _frames(2)
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _on_caravan_changed() -> void:
	_changed += 1


# --- Striscia della carovana -------------------------------------------------------------------

## Caselle, rottami, stato, tasto e spicchio seguono la carovana attraverso ArenaRun.
func _test_strip() -> void:
	print("caravan strip")
	var hud := _run.hud
	var strip := hud.caravan_strip()
	_check(strip != null and strip.visible, "la striscia della carovana e a schermo")
	_check(strip.get_parent() == hud.weapon_strip().get_parent() and strip.get_index() < hud.weapon_strip().get_index(),
		"nella colonna in basso a destra, sopra la striscia delle armi")
	_check(strip.slot_count() == _caravan.machines.size() and strip.slot_count() == 1,
		"una casella per macchina (%d)" % strip.slot_count())
	_check(strip.scrap_text() == "3/5", "rottami portati su capienza (%s)" % strip.scrap_text())
	_check(strip._prompt.prompt_count() == 1 and strip._prompt.text_of(0) == "Ripara" and strip._prompt.icon_of(0) != null,
		"tasto Ripara con l'icona di Interagisci")
	_check(not strip.prompt_visible() and strip._prompt.modulate.a == 0.0, "nessuna macchina guasta: tasto spento (il suo posto resta)")
	_changed = 0
	_caravan.add_scrap(1)
	_check(strip.scrap_text() == "4/5" and _changed == 0,
		"un rottame in piu: 4/5, senza changed (arriva da carried_changed) (%s)" % strip.scrap_text())
	var lead := _caravan.lead()
	_check(_caravan.can_supply_count(lead.global_position, 2), "il Cassone fornisce 2 rottami")
	_caravan.spend_count(2)
	_check(strip.scrap_text() == "2/5", "spesi 2 rottami (%s)" % strip.scrap_text())
	_caravan.add_cargo_capacity(2)
	_caravan.add_scrap(2)
	_check(strip.scrap_text() == "4/7", "capienza +2 e 2 rottami (%s)" % strip.scrap_text())
	lead.cargo().carried += 1
	_check(strip.scrap_text() == "5/7", "un rottame scritto nel Cassone (%s)" % strip.scrap_text())

	var turret := _caravan.add_machine(&"turret")
	_check(turret != null and strip.slot_count() == 2, "una macchina in piu: due caselle")
	if turret == null:
		return
	_place_player(AREA)
	_place_machine(turret, AREA + Vector3(1.0, 0.0, 0.0))
	_break(turret)
	_check(strip.slot_state(1) == Machine.State.BROKEN and strip.slot_health(1) == 0,
		"Torretta guasta: casella BROKEN a 0 PV")
	_check(strip.slot_state(0) == Machine.State.OK and strip.slot_health(0) == lead.health, "il Cassone resta in ordine")
	_place_player(AREA + Vector3(-2.0, 0.0, 0.0))
	await _frames(2)
	_check(not strip.prompt_visible(), "a 3 m dalla guasta: niente tasto Ripara")
	_place_player(AREA + Vector3(-0.5, 0.0, 0.0))
	await _frames(2)
	_check(strip.prompt_visible(), "a 1,5 m dalla guasta: tasto Ripara")
	var nominal := roundi(_caravan.tuning.repair_seconds * Engine.physics_ticks_per_second)
	var half := int(nominal / 2.0)
	_player.interact_held = true
	await _frames(half)
	_check(_caravan.repairing_machine() == turret and is_equal_approx(strip.slot_repair(1), _caravan.repair_progress())
		and strip.slot_repair(1) > 0.4, "lo spicchio segue la riparazione (%.3f, %.3f)" % [strip.slot_repair(1), _caravan.repair_progress()])
	_check(strip.slot_repair(0) == 0.0, "nessuno spicchio sul Cassone")
	await _frames(nominal - half)
	_check(turret.state == Machine.State.OK and strip.slot_state(1) == Machine.State.OK and strip.slot_repair(1) == 0.0,
		"riparata: casella in ordine, spicchio a zero")
	_check(strip.slot_health(1) == turret.health and strip.scrap_text() == "3/7", "vita %d e rottami %s aggiornati" % [strip.slot_health(1), strip.scrap_text()])
	_check(not strip.prompt_visible(), "nessuna guasta vicino: tasto Ripara spento")
	_player.interact_held = false
	await _frames(2)


# --- Indicatori sopra la colonna -----------------------------------------------------------------

## Con la striscia della carovana (sei macchine) la colonna in basso a destra e piu alta: le frecce
## verso il basso si fermano sopra di lei. Senza carovana restano dove erano (160 px dal fondo).
func _test_markers() -> void:
	print("markers above the corner column")
	var hud := RunHud.new()
	root.add_child(hud)
	var entries: Array[Dictionary] = []
	for id: StringName in [&"cargo", &"turret", &"magnet", &"beacon", &"welder", &"siren"]:
		var module := MachineCatalog.find(id)
		entries.append({icon = module.icon, color = module.color, health = 6, max_health = 6,
			state = Machine.State.OK, repair = 0.0})
	hud.set_caravan(entries, 3, 5)
	await process_frame
	await process_frame
	var markers: Array[Dictionary] = []
	for direction in MARKER_DIRECTIONS:
		markers.append({direction = direction, distance = 30.0, color = Color.WHITE, text = "X"})
	hud.set_markers(markers)
	var column := hud._corner.get_global_rect()
	var clear := true
	var over_column := false
	for i in markers.size():
		var arrow := hud._marker_arrows[i]
		var box := Rect2(arrow.position - Vector2(16.0, 16.0), Vector2(32.0, 32.0))
		if box.intersects(column):
			clear = false
			print("    freccia %s a %s sulla colonna %s" % [MARKER_DIRECTIONS[i], arrow.position, column])
		if i >= 1 and i <= 3 and arrow.position.y > hud._root.size.y * 0.5 \
				and arrow.position.x >= column.position.x and arrow.position.x <= column.end.x:
			over_column = true
	_check(hud.caravan_strip().visible and hud.caravan_strip().slot_count() == 6, "sei macchine nella striscia")
	_check(clear, "nessuna freccia sulla colonna di carovana e armi (colonna %s)" % column)
	_check(over_column, "almeno una freccia in basso sta sopra la colonna, nella sua larghezza")

	var plain := RunHud.new()
	root.add_child(plain)
	await process_frame
	await process_frame
	var down: Array[Dictionary] = [markers[0]]
	plain.set_markers(down)
	_check(not plain.caravan_strip().visible, "senza carovana la striscia resta nascosta")
	_check(is_equal_approx(plain._marker_arrows[0].position.y, plain._root.size.y - 160.0),
		"senza carovana la freccia verso il basso resta a 160 px dal fondo (%.0f)" % plain._marker_arrows[0].position.y)
	for each: RunHud in [hud, plain]:
		root.remove_child(each)
		each.queue_free()
	await process_frame


# --- Aiuti ----------------------------------------------------------------------------------------

func _place_player(at: Vector3) -> void:
	_player.global_position = Vector3(at.x, _field.height_at(at) + 0.88, at.z)
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	_path.solve()


func _place_machine(machine: Machine, at: Vector3) -> void:
	machine.global_position = Vector3(at.x, _field.height_at(at) + Caravan.GROUND_CLEARANCE, at.z)
	machine.velocity = Vector3.ZERO
	machine.reset_physics_interpolation()


## Guasta subito, senza immunita ne invulnerabilita (subito dopo il posizionamento: una macchina
## in ordine tornerebbe al suo posto fra un passo e l'altro).
func _break(machine: Machine) -> void:
	machine._hit_cooldown_left = 0.0
	machine._invulnerable_left = 0.0
	_check(machine.take_hit(machine.health) and machine.is_broken(), "%s guasto" % machine.primary_module_id())
