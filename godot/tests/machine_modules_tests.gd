extends SceneTree
## Moduli Torretta, Calamita e Faro (spec D-093, task 4 del piano A) sulla run vera di
## `arena_run.tscn`: livelli per tipo e bonus della carovana che valgono anche per le macchine
## aggiunte dopo, luci dei Faro col fattore di notte, il Cassone che non illumina piu.
## Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/machine_modules_tests.gd

const RunScene := preload("res://scenes/main/arena_run.tscn")

var _failures := 0
var _scene: Node3D
var _run: ArenaRun
var _field: TerrainField
var _player: PlayerCharacter
var _caravan: Caravan
var _director: EnemyDirector
var _xp: XpField
## Macchine aggiunte dalla suite, di giorno e di notte: ognuna va in write_queue.bodies.
var _added: Array[Machine] = []
## Colpi della Torretta contati dal segnale `fired`.
var _shots := 0


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	_run = _scene.get_node(^"Run")
	_field = _scene.get_node(^"TerrainField")
	_player = _scene.get_node(^"Player")
	_caravan = _scene.get_node(^"Caravan")
	_director = _scene.get_node(^"EnemyDirector")
	_xp = _scene.get_node(^"XpField")
	_director.spawning = false
	await _frames(5)
	# Dopo il _ready della scena: la chiodatrice del giocatore non deve togliere i bersagli
	# alla Torretta; niente level-up (i rottamatori uccisi lasciano frammenti), boss ne
	# terremoto quando il tempo salta alla notte.
	(_scene.get_node(^"PlayerWeapon") as AutoWeapon).set_physics_process(false)
	_run.progression.xp_first_level = 100000
	_run.boss_call_at = 0.0
	for event: WorldEvent in [_run.quake_event, _run.train_event]:
		if event != null:
			event.schedule([])
	_player._invulnerable_left = 3600.0
	_test_lead_gives_no_light()
	await _test_turret_fires_and_stops()
	_test_turret_levels()
	await _test_magnet()
	await _test_bonuses_for_late_machines()
	await _test_beacon_at_night()
	_test_added_machines_registered()
	# Uscendo dall'albero il Faro libera la sua sorgente; resta la torcia.
	var lights := _run.light_field
	root.remove_child(_scene)
	_check(lights.source_count() == 1, "tolta la scena, il Faro ha liberato la sua sorgente (%d)" % lights.source_count())
	_scene.queue_free()
	# T-12: i nodi messi in coda con queue_free vanno liberati prima di uscire. In piu le
	# campane della notte ancora in riproduzione si chiudono solo dopo un giro del server audio,
	# che va col tempo vero e non coi passi (a scena tolta i passi durano pochi millisecondi):
	# senza l'attesa all'uscita restano istanze Ogg perse.
	await _frames(2)
	var until := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < until:
		await process_frame
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


func _place_player(at: Vector3) -> void:
	_player.global_position = Vector3(at.x, _field.height_at(at) + 0.88, at.z)
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()


func _place_machine(machine: Machine, at: Vector3) -> void:
	machine.global_position = Vector3(at.x, _field.height_at(at) + Caravan.GROUND_CLEARANCE, at.z)
	machine.velocity = Vector3.ZERO
	machine.reset_physics_interpolation()


func _add(module_id: StringName) -> Machine:
	var machine := _caravan.add_machine(module_id)
	_check(machine != null and machine.has_module(module_id), "add_machine(%s)" % module_id)
	if machine != null:
		_added.append(machine)
	return machine


## Tutte le mesh del pezzo [param part_name] sul layer visivo della macchina.
func _part_on_layer(machine: Machine, part_name: NodePath) -> bool:
	var part := machine.get_node_or_null(part_name)
	if part == null:
		return false
	var visuals := part.find_children("*", "VisualInstance3D", true, false)
	return not visuals.is_empty() and visuals.all(func(n: Node) -> bool: return (n as VisualInstance3D).layers == Machine.VISUAL_LAYER)


## Raggio dell'attrattore [param node] nel campo dei frammenti, -1 se non c'e.
func _attractor_radius(node: Node3D) -> float:
	for entry in _xp.attractors:
		if entry.node == node:
			return entry.radius
	return -1.0


func _on_turret_fired(count: int) -> void:
	_shots += count


## Plan choice 1: la prima macchina (il Cassone) non porta piu il faro; all'inizio l'unica
## sorgente e la torcia del giocatore.
func _test_lead_gives_no_light() -> void:
	print("lead gives no light")
	var lead := _caravan.lead()
	var fields := _run.light_field
	_check(lead != null and lead.has_module(&"cargo"), "il capofila e il Cassone")
	_check(fields.source_count() == 1 and fields.source_node(_run.torch_light_id) == _player,
		"solo la torcia nel campo delle luci: il Cassone non e una sorgente (%d)" % fields.source_count())
	_check(lead.find_child("BeaconLight", true, false) == null and _caravan.beacon_lights().is_empty(),
		"nessuna BeaconLight sul Cassone, nessun Faro nella carovana")
	_check(_director.caravan == _caravan, "il direttore ha la carovana")


## Una macchina Torretta spara a un rottamatore entro 8 m da se stessa; spenta smette (i chiodi
## in volo finiscono), riaccesa riprende.
func _test_turret_fires_and_stops() -> void:
	print("turret")
	_place_player(Vector3.ZERO)
	var machine := _add(&"turret")
	if machine == null:
		return
	machine.set_physics_process(false)
	var spot := Vector3(-3.0, 0.0, -3.0)
	_place_machine(machine, spot)
	var module := machine.module(&"turret") as TurretModule
	var gun := module.weapon()
	var tuning := _caravan.tuning
	_check(gun != null and gun.get_parent() == module and gun.is_inside_tree() and gun.weapon_id == &"",
		"la Torretta ha la sua chiodatrice, figlia del modulo, senza weapon_id")
	_check(gun.shooter == machine and gun.director == _director and is_equal_approx(gun.muzzle_height, 0.55),
		"spara dalla macchina, col direttore, canna a 0,55 m")
	_check(is_equal_approx(gun.weapon_range, tuning.turret_range) and is_equal_approx(gun.weapon_range, 8.0)
		and gun.damage == _run.tuning.weapon_damage and is_equal_approx(gun.projectile_speed, _run.tuning.projectile_speed),
		"portata 8 m, danno e velocita dei chiodi della run")
	_check(is_equal_approx(gun.fire_interval, 0.9), "intervallo di base 0,9 s (%.3f)" % gun.fire_interval)
	_check(_part_on_layer(machine, ^"TurretPart"), "TurretPart montato, sul layer visivo 2")
	gun.fired.connect(_on_turret_fired)
	_shots = 0
	var enemy := _director.spawn_at(spot + Vector3(5.0, 0.0, 0.0))
	enemy.health = 50
	var peak := 0
	for i in 90:
		await physics_frame
		peak = maxi(peak, gun.nail_count())
	_check(_shots > 0 and peak > 0, "spara al rottamatore a 5 m (%d colpi, %d chiodi in volo al massimo)" % [_shots, peak])
	_check(is_instance_valid(enemy) and enemy.health < 50, "e lo colpisce (vita %d)" % (enemy.health if is_instance_valid(enemy) else -1))

	module.set_active(false)
	_check(gun.shooter == null, "spenta: niente tiratore")
	await _frames(30)
	_shots = 0
	var quiet := true
	for i in 60:
		await physics_frame
		quiet = quiet and gun.nail_count() == 0
	var in_range := is_instance_valid(enemy) and not enemy.is_dead \
		and Machine.planar_distance(enemy.global_position, machine.global_position) < gun.weapon_range
	_check(in_range and quiet and _shots == 0, "spenta non spara piu, col rottamatore ancora a tiro (%d colpi)" % _shots)
	module.set_active(true)
	_check(gun.shooter == machine, "riaccesa spara di nuovo dalla macchina")
	for i in 90:
		await physics_frame
		if _shots > 0:
			break
	_check(_shots > 0, "e riprende a sparare")
	gun.fired.disconnect(_on_turret_fired)
	_director.clear_horde()
	await _frames(20)


## Torretta veloce: il livello del tipo vale per ogni torretta, anche per quelle aggiunte dopo.
func _test_turret_levels() -> void:
	print("turret levels")
	var tuning := _caravan.tuning
	var expected := tuning.turret_interval / pow(tuning.turret_rate_per_level, 2)
	_check(is_equal_approx(expected, 0.9 / (1.35 * 1.35)), "la taratura da 0,9 / 1,35^2 (%.4f)" % expected)
	_caravan.set_module_level(&"turret", 2)
	_check(_caravan.module_level(&"turret") == 2, "module_level della Torretta: 2")
	var first := _caravan.modules_of(&"turret")
	_check(first.size() == 1 and is_equal_approx((first[0] as TurretModule).weapon().fire_interval, expected),
		"set_module_level(turret, 2): la torretta passa a %.4f s" % expected)
	var late := _add(&"turret")
	if late == null:
		return
	var all := _caravan.modules_of(&"turret")
	_check(all.size() == 2 and all.all(func(m: MachineModule) -> bool: return is_equal_approx((m as TurretModule).weapon().fire_interval, expected)),
		"una Torretta aggiunta dopo ha lo stesso intervallo (%.4f)" % (late.module(&"turret") as TurretModule).weapon().fire_interval)
	_check((late.module(&"turret") as TurretModule).weapon().shooter == late, "e spara dalla sua macchina")


## Calamita: attrattore di 2,5 m, 4,0 col livello 1; spenta lo toglie e i frammenti che
## volavano verso di lei scelgono di nuovo il bersaglio.
func _test_magnet() -> void:
	print("magnet")
	var machine := _add(&"magnet")
	if machine == null:
		return
	machine.set_physics_process(false)
	_place_player(Vector3(-4.0, 0.0, -4.0))
	_place_machine(machine, Vector3(4.0, 0.0, 4.0))
	var module := machine.module(&"magnet") as MagnetModule
	_check(is_equal_approx(_attractor_radius(machine), 2.5), "attrattore di 2,5 m sulla macchina (%.2f)" % _attractor_radius(machine))
	_check(_attractor_radius(_caravan.lead()) < 0.0, "il Cassone non attira")
	_check(_part_on_layer(machine, ^"MagnetPart"), "MagnetPart montato, sul layer visivo 2")
	_caravan.set_module_level(&"magnet", 1)
	_check(is_equal_approx(_attractor_radius(machine), 4.0), "col livello 1: 4,0 m (%.2f)" % _attractor_radius(machine))

	var before := _xp.count()
	_xp.spawn(machine.global_position + Vector3(-2.0, 0.0, 0.0), 1)
	var fragment: Dictionary = _xp._fragments.back()
	await _frames(2)
	_check(fragment.target == machine, "un frammento a 2 m vola verso la Calamita")
	module.set_active(false)
	_check(_attractor_radius(machine) < 0.0, "spenta: attrattore tolto")
	_check(fragment.target == null, "il frammento che volava verso di lei torna a scegliere")
	var node: Node3D = fragment.node
	var at := node.global_position
	await _frames(10)
	_check(fragment.target == null and Machine.planar_distance(node.global_position, at) < 0.01,
		"e resta fermo: nessun altro lo attira")
	module.set_active(true)
	_check(is_equal_approx(_attractor_radius(machine), 4.0), "riaccesa: di nuovo 4,0 m")
	await _frames(60)
	_check(not _xp._fragments.has(fragment) and _xp.count() == before, "il frammento arriva alla Calamita")


## Bonus della carovana per le macchine che arrivano dopo: capienza dei Cassoni e velocita.
func _test_bonuses_for_late_machines() -> void:
	print("late machines")
	var tuning := _caravan.tuning
	_caravan.speed_scale = 1.15
	_caravan.add_cargo_capacity(2)
	var machine := _add(&"cargo")
	if machine == null:
		return
	_check(machine.cargo().capacity == tuning.cargo_capacity + 2 and machine.cargo().capacity == 7,
		"un Cassone aggiunto dopo add_cargo_capacity(2) porta 7 rottami (%d)" % machine.cargo().capacity)
	# Pieno non cerca rottami; senza campo di percorso la meta e il posto, non la cella vicina.
	machine.cargo().carried = machine.cargo().capacity
	var path := _caravan.path_field
	_caravan.path_field = null
	_place_player(Vector3(4.0, 0.0, 0.0))
	_place_machine(machine, Vector3(-5.0, 0.0, 0.0))
	var peak := 0.0
	for i in 60:
		await physics_frame
		peak = maxf(peak, Vector2(machine.velocity.x, machine.velocity.z).length())
	_caravan.path_field = path
	_caravan.speed_scale = 1.0
	_check(absf(peak - tuning.max_speed * 1.15) < 0.3 and peak > tuning.max_speed + 0.4,
		"aggiunta dopo speed_scale = 1,15 corre a %.2f m/s (%.2f)" % [tuning.max_speed * 1.15, peak])


## Faro: sorgente di 11 m sulla macchina (13 col livello 1) e la sua BeaconLight. Aggiunto di
## notte, la luce si accende al fattore corrente al passo dopo; spento e riacceso a fattore
## fermo, la luce segue.
func _test_beacon_at_night() -> void:
	print("beacon at night")
	var cycle := _run.day_night
	_run.elapsed = cycle.night_start_seconds + cycle.dusk_seconds + 1.0
	await _frames(3)
	var factor := cycle.night_factor
	_check(cycle.phase == DayNightCycle.Phase.NIGHT and is_equal_approx(factor, 1.0), "e notte, fattore 1")
	var machine := _add(&"beacon")
	if machine == null:
		return
	var module := machine.module(&"beacon") as BeaconModule
	var fields := _run.light_field
	var base := _run.tuning.beacon_radius
	_check(is_equal_approx(base, 11.0) and module.light_id != -1 and is_equal_approx(fields.radius_of(module.light_id), base),
		"sorgente di 11 m (%.1f)" % fields.radius_of(module.light_id))
	_check(fields.source_count() == 2 and fields.source_node(module.light_id) == machine,
		"la sorgente e la macchina col Faro, non la carovana ne il Cassone")
	var light := module.light
	_check(light != null and light.name == &"BeaconLight" and light.get_parent() == module
		and light.position.is_equal_approx(Vector3(0.0, 1.6, 0.0)) and light.light_color.is_equal_approx(Color(1.0, 0.9, 0.72))
		and not light.shadow_enabled, "BeaconLight figlia del modulo: a 1,6 m, luce calda, senza ombre")
	_check(_part_on_layer(machine, ^"BeaconPart"), "BeaconPart montato, sul layer visivo 2")
	await _frames(2)
	_check(light.visible and is_equal_approx(light.light_energy, 2.2 * factor) and is_equal_approx(light.omni_range, base * 1.15),
		"aggiunto di notte: acceso al fattore corrente (energia %.2f, portata %.2f)" % [light.light_energy, light.omni_range])
	var listed := _caravan.beacon_lights()
	_check(listed.size() == 1 and listed[0].light == light and is_equal_approx(listed[0].radius, base), "beacon_lights: il Faro acceso")

	module.set_active(false)
	_check(not light.visible and is_zero_approx(fields.radius_of(module.light_id)) and _caravan.beacon_lights().is_empty(),
		"spento: luce nascosta e raggio 0")
	await _frames(2)
	_check(not light.visible, "e resta spento a fattore fermo")
	module.set_active(true)
	_check(is_equal_approx(fields.radius_of(module.light_id), base), "riacceso: di nuovo 11 m")
	await _frames(2)
	_check(light.visible and is_equal_approx(light.light_energy, 2.2 * factor), "e la luce si riaccende al fattore corrente")
	_caravan.set_module_level(&"beacon", 1)
	var upgraded := base + _run.tuning.beacon_radius_per_level
	_check(is_equal_approx(upgraded, 13.0) and is_equal_approx(fields.radius_of(module.light_id), upgraded),
		"set_module_level(beacon, 1): sorgente di 13 m (%.1f)" % fields.radius_of(module.light_id))
	await _frames(2)
	_check(is_equal_approx(light.omni_range, upgraded * 1.15), "al passo dopo la portata della luce segue (%.2f)" % light.omni_range)

	# Di giorno il Faro resta acceso: lo nasconde solo il fattore (D-093, regola 4 del task).
	_run.elapsed = 1.0
	await _frames(3)
	_check(cycle.phase == DayNightCycle.Phase.DAY and not light.visible and module.active
		and is_equal_approx(fields.radius_of(module.light_id), upgraded), "di giorno la luce si spegne ma il Faro resta una sorgente")


## Review Focus #5: ogni macchina aggiunta a meta run (di giorno e di notte) sta nella
## carovana, in write_queue.bodies e nella carovana del direttore.
func _test_added_machines_registered() -> void:
	print("added machines registered")
	var missing := _added.filter(func(m: Machine) -> bool:
		return not (_caravan.machines.has(m) and _run.write_queue.bodies.has(m)))
	_check(_added.size() == 5 and missing.is_empty() and _director.caravan == _caravan,
		"%d macchine aggiunte, tutte nella carovana e in write_queue.bodies (%d fuori)" % [_added.size(), missing.size()])
	_check(_caravan.module_count() == 6 and not _caravan.has_room(), "sei moduli: carovana piena")
