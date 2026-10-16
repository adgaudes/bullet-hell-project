extends SceneTree
## Danni alle macchine della carovana (spec D-093, task 6 del piano A) sulla run vera di
## `arena_run.tscn`: contatto dei rottamatori e dei boss, immunita dopo un colpo, guasto e
## riparazione, ritirata, rigenerazione, anello, fumo e segno del guasto, guinzaglio, incastro e
## posti murati. Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/machine_damage_tests.gd

const RunScene := preload("res://scenes/main/arena_run.tscn")
## Piano aperto e quasi in piano (pendenza <= 0,08 fra x -18 e 18, z 12-20): contatti, guasto,
## ritirata e posti murati. Il corridoio dei 5 s di corsa sta a z -16 (x -18..18).
const AREA := Vector3(0.0, 0.0, 16.0)
const LANE_START := Vector3(-16.0, 0.0, -16.0)

var _failures := 0
var _scene: Node3D
var _run: ArenaRun
var _field: TerrainField
var _player: PlayerCharacter
var _caravan: Caravan
var _director: EnemyDirector
var _path: PathField
var _scraps: ScrapField
var _turret: Machine
## Colpi ricevuti e cambi di stato, `[macchina, valore]`, e notifiche `changed` della carovana.
var _hits: Array = []
var _states: Array = []
var _changed := 0
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
	_path = _scene.get_node(^"PathField")
	_scraps = _scene.get_node(^"ScrapField")
	_director.spawning = false
	await _frames(5)
	# Come machine_modules_tests: niente chiodatrice del giocatore, level-up, boss ne eventi;
	# il giocatore non muore.
	(_scene.get_node(^"PlayerWeapon") as AutoWeapon).set_physics_process(false)
	_run.progression.xp_first_level = 100000
	_run.boss_call_at = 0.0
	for event: WorldEvent in [_run.quake_event, _run.train_event]:
		if event != null:
			event.schedule([])
	_player._invulnerable_left = 3600.0
	_caravan.changed.connect(_on_caravan_changed)
	_watch(_caravan.lead())
	await _test_services_and_marks()
	await _test_scavenger_contact()
	await _test_boss_contact()
	await _test_breakdown_and_repair()
	await _test_regeneration()
	await _test_retreat()
	await _test_retreating_cargo_leaves_scrap()
	await _test_walled_slots()
	await _test_walled_retreat_point()
	await _test_leash()
	await _test_pit()
	await _test_run_without_teleport()
	# Ruling 17: una macchina guasta (fumo acceso) si libera con la scena senza errori.
	_turret.take_hit(_turret.health)
	_check(_turret.is_broken(), "la Torretta resta guasta fino alla fine")
	await _frames(10)
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


# --- Servizi, anello, fumo e segno -----------------------------------------------------------

## Il direttore della run e un servizio della carovana; ogni macchina ha anello, fumo e punto
## esclamativo, figli diretti sul layer visivo 2; l'anello col colore del modulo e la texture
## del pennello, una sola per tutti.
func _test_services_and_marks() -> void:
	print("services and marks")
	_check(_caravan.enemy_director() == _director and _director.caravan == _caravan,
		"la carovana ha il direttore della run (enemy_director) e lui la carovana")
	var lead := _caravan.lead()
	_place_player(AREA)
	_gather_machines()
	_turret = _caravan.add_machine(&"turret")
	_check(_turret != null, "una macchina con la Torretta")
	if _turret == null:
		return
	_watch(_turret)
	await _frames(2)
	var lead_ring := lead.get_node_or_null(^"GroundRing") as Decal
	var turret_ring := _turret.get_node_or_null(^"GroundRing") as Decal
	_check(lead_ring != null and turret_ring != null, "ogni macchina ha il suo anello a terra (GroundRing)")
	if lead_ring == null or turret_ring == null:
		return
	_check(lead_ring.texture_albedo == BrushPreview.ring_texture() and turret_ring.texture_albedo == lead_ring.texture_albedo
		and turret_ring.texture_emission == lead_ring.texture_albedo, "le due macchine condividono la texture ad anello del pennello")
	_check(lead_ring.size.is_equal_approx(Vector3(1.5, 0.6, 1.5)) and lead_ring.position.is_equal_approx(Machine.RIG_GROUND)
		and lead_ring.cull_mask == 1 and lead_ring.layers == Machine.VISUAL_LAYER,
		"anello di raggio 0,75 m, alto 0,6 m e centrato sul suolo, dipinge solo il layer 1")
	_check(lead_ring.modulate.is_equal_approx(MachineCatalog.find(&"cargo").color)
		and turret_ring.modulate.is_equal_approx(MachineCatalog.find(&"turret").color),
		"anello col colore del modulo (Cassone %s, Torretta %s)" % [lead_ring.modulate.to_html(false), turret_ring.modulate.to_html(false)])
	var smoke := _turret.get_node_or_null(^"Smoke") as CPUParticles3D
	var mark := _turret.get_node_or_null(^"BrokenMark") as Label3D
	_check(smoke != null and mark != null and smoke.get_parent() == _turret and mark.get_parent() == _turret,
		"fumo (Smoke) e punto esclamativo (BrokenMark) figli diretti della macchina")
	if smoke == null or mark == null:
		return
	_check(not smoke.emitting and not smoke.visible and not mark.visible, "spenti finche la macchina non si guasta")
	_check(smoke.layers == Machine.VISUAL_LAYER and mark.layers == Machine.VISUAL_LAYER and not lead._parts.has(lead_ring),
		"sul layer visivo della macchina, fuori dal telaio")
	_check(mark.text == "!" and mark.no_depth_test and mark.billboard == BaseMaterial3D.BILLBOARD_ENABLED
		and mark.outline_size > 0 and mark.modulate.r > 0.8 and mark.modulate.g < 0.4,
		"punto esclamativo rosso col contorno, sempre rivolto alla camera e senza depth test")


# --- Contatto ----------------------------------------------------------------------------------

## Un rottamatore fermo a 0,5 m toglie 1 PV; il secondo colpo solo dopo 0,8 s; a 1,2 m niente.
## Con l'invulnerabilita il contatto si prova ma non passa. Il raggio e quello della carovana
## (0,8 m), non quello del giocatore (0,75).
func _test_scavenger_contact() -> void:
	print("scavenger contact")
	var lead := _caravan.lead()
	_place_player(AREA)
	_place_machine(lead, AREA + Vector3(-2.5, 0.0, 0.0))
	_check(await _settle(lead), "il capofila si ferma al suo posto")
	var health := lead.health
	lead.grant_invulnerability(2.0)
	_hits.clear()
	_spawn_still(lead.global_position + Vector3(0.5, 0.0, 0.0))
	await _frames(30)
	_check(lead.health == health and _hits_on(lead).is_empty(), "invulnerabile: un rottamatore a 0,5 m non toglie nulla, nessun damaged")
	_check(not lead.take_hit(1) and lead.health == health, "take_hit falso durante l'invulnerabilita")
	_check(lead.accepts_contact(), "ma la macchina accetta il contatto: il direttore la prova lo stesso")
	lead._invulnerable_left = 0.0
	var first := -1
	var second := -1
	var open_after_hit := true
	for i in 90:
		await physics_frame
		var count := _hits_on(lead).size()
		if count >= 1 and first < 0:
			first = i
			open_after_hit = lead.accepts_contact()
		if count >= 2:
			second = i
			break
	_check(first >= 0 and first <= 2 and _hits_on(lead)[0] == 1, "finita l'invulnerabilita il rottamatore fermo a 0,5 m toglie 1 PV (passo %d)" % first)
	_check(not open_after_hit, "dopo un colpo vero accepts_contact e falso (immunita)")
	_check(second >= 0 and second - first >= 45 and second - first <= 54,
		"il secondo colpo arriva dopo 0,8 s, non prima di 0,75 (%d passi)" % (second - first))
	_check(lead.health == health - 2, "due colpi: %d -> %d PV" % [health, lead.health])
	await _clear_enemies()
	await _frames(60)
	_hits.clear()
	health = lead.health
	_spawn_still(lead.global_position + Vector3(1.2, 0.0, 0.0))
	await _frames(60)
	_check(lead.health == health and _hits_on(lead).is_empty(), "a 1,2 m nessun danno in 1 s")
	await _clear_enemies()
	# Sul bordo: 2 cm dentro il raggio della carovana, fuori da quello del giocatore.
	var edge := _caravan.tuning.contact_radius - 0.02
	_check(_run.tuning.contact_radius < edge, "il raggio del giocatore (%.2f) e piu corto di %.2f m" % [_run.tuning.contact_radius, edge])
	_check(await _settle(lead), "il capofila e di nuovo fermo")
	_spawn_still(lead.global_position + Vector3(0.0, 0.0, -edge))
	await _frames(3)
	_check(lead.health == health - 1, "a %.2f m il rottamatore colpisce: vale contact_radius della carovana (%d PV)" % [edge, lead.health])
	await _clear_enemies()
	lead.heal(lead.max_health)
	_check(lead.health == lead.max_health, "pulizia: capofila a vita piena")


## Un boss entro 1,5 m toglie 2 PV con un solo colpo; la regola da 1 PV dei rottamatori non vale
## per i boss (`self_driven`): fermo a 0,5 m senza la sua guida non toglie nulla, un rottamatore
## nello stesso punto si.
func _test_boss_contact() -> void:
	print("boss contact")
	var lead := _caravan.lead()
	_place_player(AREA)
	_check(await _settle(lead), "il capofila e fermo al suo posto")
	await _frames(60)
	var boss := _run._make_demolisher()
	boss.speed = 0.0
	boss.wall_attraction_radius = 0.0
	_check(boss.contact_damage == 2 and is_equal_approx(boss.contact_radius, 1.5), "Demolitore: 2 PV entro 1,5 m")
	var at := lead.global_position + Vector3(-1.2, 0.0, 0.0)
	_hits.clear()
	var health := lead.health
	_director.add_enemy(boss, Vector3(at.x, boss.spawn_center_height(), at.z))
	await _frames(30)
	var hits := _hits_on(lead)
	_check(lead.health == health - 2 and hits.size() == 1 and hits[0] == 2,
		"un Demolitore fermo a 1,2 m toglie 2 PV, un solo damaged(2) in 0,5 s (%s)" % [hits])
	# Senza giocatore `drive` esce subito: il boss resta un nemico fermo a 0,5 m.
	boss.player = null
	await _frames(60)
	boss.global_position = Vector3(lead.global_position.x - 0.5, boss.global_position.y, lead.global_position.z)
	boss.reset_physics_interpolation()
	_hits.clear()
	health = lead.health
	await _frames(60)
	_check(lead.health == health and _hits_on(lead).is_empty(), "un boss a 0,5 m senza la sua guida non toglie nulla: il contatto da 1 PV salta i self_driven")
	_spawn_still(lead.global_position + Vector3(0.5, 0.0, 0.0))
	await _frames(3)
	_check(lead.health == health - 1 and _hits_on(lead).size() == 1, "controllo: un rottamatore a 0,5 m toglie 1 PV (%d)" % lead.health)
	_director.enemies.erase(boss)
	boss.queue_free()
	await _clear_enemies()
	lead.heal(lead.max_health)


# --- Guasto, riparazione, rigenerazione ---------------------------------------------------------

## A 0 PV la macchina e guasta: Torretta senza tiratore, ferma (resta la gravita), nessun altro
## danno, fumo, punto esclamativo e anello rosso; guasta piu di 8 s la vita non risale. Riparata
## riparte a 3 PV coi moduli accesi; `repair` su una macchina in ordine non fa nulla.
func _test_breakdown_and_repair() -> void:
	print("breakdown and repair")
	var machine := _turret
	var module := machine.module(&"turret") as TurretModule
	var gun := module.weapon()
	_place_player(AREA)
	_check(gun.shooter == machine, "la Torretta spara dalla sua macchina")
	_place_machine(machine, _caravan.slot_target(machine) + Vector3(0.0, 0.0, -4.0))
	await _frames(15)
	_check(_planar_speed(machine) > 1.0, "la macchina corre verso il suo posto (%.1f m/s)" % _planar_speed(machine))
	_states.clear()
	_changed = 0
	_check(machine.take_hit(machine.health), "un colpo da tutta la vita va a segno")
	_check(machine.health == 0 and machine.state == Machine.State.BROKEN and machine.is_broken(), "a 0 PV la macchina e guasta")
	_check(gun.shooter == null and not module.active, "la sua Torretta e spenta: shooter nullo")
	var broken := _caravan.broken_machines()
	_check(broken.size() == 1 and broken[0] == machine, "broken_machines() la elenca")
	_check(_states_of(machine) == [Machine.State.BROKEN] and _changed > 0, "state_changed(BROKEN) e changed della carovana")
	var smoke := machine.get_node(^"Smoke") as CPUParticles3D
	var mark := machine.get_node(^"BrokenMark") as Label3D
	var ring := machine.get_node(^"GroundRing") as Decal
	_check(smoke.emitting and smoke.visible and mark.visible, "fumo ed esclamativo visibili")
	_check(ring.modulate.is_equal_approx(BrushPreview.INVALID_COLOR), "anello rosso")
	await _frames(2)
	var at := machine.global_position
	_hits.clear()
	_spawn_still(machine.global_position + Vector3(0.5, 0.0, 0.0))
	await _frames(58)
	_check(_planar_speed(machine) < 0.05 and Machine.planar_distance(machine.global_position, at) < 0.05,
		"dopo 1 s ferma (%.3f m/s, %.3f m)" % [_planar_speed(machine), Machine.planar_distance(machine.global_position, at)])
	_check(machine.is_on_floor() and absf(machine.global_position.y - _field.height_at(at) - Caravan.GROUND_CLEARANCE) < 0.1,
		"e poggia sul suolo")
	_check(machine.health == 0 and _hits_on(machine).is_empty() and not machine.take_hit(1), "nessun altro danno, nemmeno a contatto")
	await _clear_enemies()
	await _frames(8 * 60)
	_check(machine.health == 0 and machine.is_broken(), "guasta per oltre 8 s: la vita non risale")
	_states.clear()
	_changed = 0
	machine.repair(_caravan.tuning.repair_health_fraction)
	_check(machine.health == 3 and machine.state == Machine.State.OK, "riparata a meta vita: 3 PV, in ordine")
	_check(gun.shooter == machine and module.active, "la Torretta riaccesa spara di nuovo dalla macchina")
	_check(not smoke.emitting and not mark.visible, "niente piu fumo ne esclamativo")
	_check(ring.modulate.is_equal_approx(MachineCatalog.find(&"turret").color), "anello di nuovo del colore del modulo")
	_check(_states_of(machine) == [Machine.State.OK] and _changed > 0 and _caravan.broken_machines().is_empty(),
		"state_changed(OK), changed, nessuna macchina guasta")
	_states.clear()
	_changed = 0
	machine.repair(1.0)
	_check(machine.health == 3 and _states.is_empty() and _changed == 0, "repair su una macchina in ordine non fa nulla")
	# Dopo la riparazione la vita risale come dopo un colpo: +1 PV a 8 s.
	var steps := await _steps_until_health(machine, 4, 9 * 60)
	_check(steps >= 450 and steps <= 510, "riparata: 3 PV a 7,5 s, 4 entro 8,5 s (passo %d)" % steps)


## Rigenerazione da un colpo vero: +1 PV dopo 8 s senza colpi, poi uno ogni 4 s fino a 6.
func _test_regeneration() -> void:
	print("regeneration")
	var machine := _turret
	_place_player(AREA)
	await _frames(60)
	var before := machine.health
	_check(machine.take_hit(before - 2) and machine.health == 2 and machine.state == Machine.State.OK,
		"un colpo porta la Torretta a 2 PV (sopra il 30%: resta in ordine)")
	var changes: Array[Vector2i] = []
	var last := machine.health
	for i in 24 * 60:
		await physics_frame
		if machine.health != last:
			last = machine.health
			changes.append(Vector2i(i, last))
	var expected: Array[int] = [3, 4, 5, 6]
	var ok := changes.size() == expected.size()
	for k in mini(changes.size(), expected.size()):
		var at_step := 480 + 240 * k
		ok = ok and changes[k].y == expected[k] and absi(changes[k].x - at_step) <= 30
	_check(ok, "8 s senza colpi poi +1 PV, poi +1 ogni 4 s fino a 6, poi piu nulla (%s)" % [changes])


# --- Ritirata -----------------------------------------------------------------------------------

## Con 1 PV (sotto il 30%) e un nemico a est la Torretta va a 4-6 m dal giocatore dal lato ovest
## e continua a sparare; resta li (nessun ritorno al posto in 4 s); a 4 PV torna al posto.
func _test_retreat() -> void:
	print("retreat")
	var machine := _turret
	var lead := _caravan.lead()
	_place_player(AREA)
	_place_machine(lead, AREA + Vector3(-2.5, 0.0, 0.0))
	_place_machine(machine, _caravan.slot_target(machine))
	_protect_others(machine, 60.0)
	await _frames(30)
	var enemy_at := AREA + Vector3(2.5, 0.0, 0.0)
	var clear := true
	for each in _caravan.machines:
		clear = clear and Machine.planar_distance(_caravan.slot_target(each), enemy_at) > 1.0
	_check(clear, "nessun posto del grappolo entro 1 m dal nemico")
	var enemy := _spawn_still(enemy_at)
	await _frames(2)
	_check(machine.take_hit(machine.health - 1) and machine.health == 1 and machine.state == Machine.State.RETREAT,
		"con 1 PV (sotto il 30%) la macchina si ritira")
	var enemy_health := enemy.health
	await _frames(150)
	var distance := Machine.planar_distance(machine.global_position, _player.global_position)
	_check(machine.state == Machine.State.RETREAT and distance >= 4.0 and distance <= 6.0
		and machine.global_position.x < _player.global_position.x - 3.0,
		"col nemico a est va a 4-6 m dal giocatore dal lato ovest (%.1f m, x %.1f)" % [distance, machine.global_position.x - _player.global_position.x])
	var gun := (machine.module(&"turret") as TurretModule).weapon()
	_check(gun.shooter == machine and enemy.health < enemy_health,
		"la Torretta continua a sparare (vita del nemico %d -> %d)" % [enemy_health, enemy.health])
	var jump := await _largest_jump(machine, 240)
	distance = Machine.planar_distance(machine.global_position, _player.global_position)
	_check(jump < 1.0 and machine.state == Machine.State.RETREAT and distance >= 4.0 and distance <= 6.0,
		"ferma in ritirata per 4 s non torna al posto (salto massimo %.2f m, a %.1f m)" % [jump, distance])
	machine.health = 4
	await _frames(120)
	_check(machine.state == Machine.State.OK and Machine.planar_distance(machine.global_position, _caravan.slot_target(machine)) < 1.0,
		"a 4 PV torna in ordine e al suo posto (%.2f m)" % Machine.planar_distance(machine.global_position, _caravan.slot_target(machine)))
	await _clear_enemies()
	_protect_others(machine, 0.0)
	machine.heal(machine.max_health)


## Due Cassoni: il primo punta un rottame e poi si ritira; il rottame passa al secondo, il primo
## non lo insegue piu.
func _test_retreating_cargo_leaves_scrap() -> void:
	print("retreating cargo leaves scrap")
	var a := _caravan.lead()
	var b := _caravan.add_machine(&"cargo")
	_check(b != null, "un secondo Cassone")
	if b == null:
		return
	_watch(b)
	await _frames(1)
	# Passi fisici spenti: le mete si chiedono a mano.
	a.set_physics_process(false)
	b.set_physics_process(false)
	a._hit_cooldown_left = 0.0
	a._invulnerable_left = 0.0
	_place_player(AREA)
	a.cargo().carried = 0
	b.cargo().carried = 0
	_place_machine(a, AREA + Vector3(-1.5, 0.0, 0.0))
	var scrap := AREA + Vector3(3.0, 0.0, 0.0)
	_place_machine(b, scrap + Vector3(0.0, 0.0, 1.5))
	_scraps.spawn_on_ground(scrap)
	_check(Machine.planar_distance(a._choose_destination(), scrap) < 0.5 and a.cargo().claimed_scrap() != null, "il primo Cassone punta il rottame")
	_check(Machine.planar_distance(b._choose_destination(), scrap) > 1.0, "il secondo, piu vicino, lo salta: e gia meta del primo")
	_check(a.take_hit(a.health - 1) and a.state == Machine.State.RETREAT, "a 1 PV il primo Cassone si ritira")
	_check(a.cargo().claimed_scrap() == null and not _caravan.is_scrap_claimed(scrap, b.cargo()), "in ritirata non tiene piu il rottame")
	b.cargo().tick(_caravan.tuning.cargo_search_interval)
	_check(Machine.planar_distance(b._choose_destination(), scrap) < 0.5, "il secondo Cassone ora lo punta")
	a.cargo().tick(_caravan.tuning.cargo_search_interval)
	_check(Machine.planar_distance(a._choose_destination(), scrap) > 1.0, "un Cassone in ritirata non insegue rottami")
	_scraps.take_near(scrap, 0.5, 10)
	a.heal(a.max_health)
	_check(a.state == Machine.State.OK, "curato torna in ordine")
	a.set_physics_process(true)
	b.set_physics_process(true)
	_place_machine(b, _caravan.slot_target(b))
	await _frames(2)


# --- Posti murati, guinzaglio, incastro -----------------------------------------------------------

## Il posto dentro un muro si scarta: slot_target da il primo punto percorribile ruotato di
## +-30/+-60 gradi; una macchina aggiunta col posto murato nasce li.
func _test_walled_slots() -> void:
	print("walled slots")
	var lead := _caravan.lead()
	var machine := _turret
	lead.set_physics_process(false)
	machine.set_physics_process(false)
	_place_player(AREA)
	_place_machine(lead, AREA + Vector3(-2.5, 0.0, 0.0))
	_place_machine(machine, AREA + Vector3(6.0, 0.0, -2.0))
	var raw := _raw_slot(machine.slot)
	var wall := _add_wall(raw)
	await _frames(2)
	_path.scan_static_obstacles()
	_path.solve()
	_check(not _path.is_walkable(raw), "il posto della Torretta e dentro un muro")
	var target := _caravan.slot_target(machine)
	_check(_caravan.is_open_point(target) and _outside(target, raw, 1.0),
		"slot_target lo scarta: punto percorribile fuori dal muro (a %.1f m dal posto)" % Machine.planar_distance(target, raw))
	var index := _caravan._free_slot()
	var raw_new := _raw_slot(index)
	var wall_new := _add_wall(raw_new)
	await _frames(2)
	_path.scan_static_obstacles()
	_path.solve()
	var added := _caravan.add_machine(&"magnet")
	_check(added != null, "una macchina in piu")
	if added != null:
		_watch(added)
		_check(added.slot == index and not _path.is_walkable(raw_new) and _outside(added.global_position, raw_new, 1.0)
			and Machine.planar_distance(added.global_position, _caravan.slot_target(added)) < 0.05,
			"col posto murato nasce su slot_target, fuori dal muro")
	for each: Node in [wall, wall_new]:
		_scene.remove_child(each)
		each.free()
	await _frames(2)
	_path.scan_static_obstacles()
	_path.solve()
	lead.set_physics_process(true)
	machine.set_physics_process(true)
	await _frames(30)


## Un muro sul punto di ritirata ideale: la macchina si ritira a 4-6 m su un punto ruotato, fuori
## dal muro, e non torna al posto in 4 s (nessun ciclo d'incastro).
func _test_walled_retreat_point() -> void:
	print("walled retreat point")
	var machine := _turret
	var lead := _caravan.lead()
	_place_player(AREA)
	_place_machine(lead, AREA + Vector3(-2.5, 0.0, 0.0))
	_place_machine(machine, _caravan.slot_target(machine))
	_protect_others(machine, 60.0)
	var ideal := AREA + Vector3(-_caravan.tuning.retreat_distance, 0.0, 0.0)
	var wall := _add_wall(ideal)
	await _frames(2)
	_path.scan_static_obstacles()
	_path.solve()
	_check(not _path.is_walkable(ideal), "il punto di ritirata ideale e dentro un muro")
	_spawn_still(AREA + Vector3(2.5, 0.0, 0.0))
	await _frames(2)
	_check(machine.take_hit(machine.health - 1) and machine.state == Machine.State.RETREAT, "a 1 PV la Torretta si ritira")
	var jump := await _largest_jump(machine, 240)
	var distance := Machine.planar_distance(machine.global_position, _player.global_position)
	_check(machine.state == Machine.State.RETREAT and distance >= 4.0 and distance <= 6.0 and _outside(machine.global_position, ideal, 1.4),
		"si ritira a 4-6 m dal giocatore, fuori dal muro (%.1f m)" % distance)
	_check(jump < 1.0, "e in 4 s non torna mai al posto (salto massimo %.2f m)" % jump)
	_scene.remove_child(wall)
	wall.free()
	await _frames(2)
	_path.scan_static_obstacles()
	_path.solve()
	await _clear_enemies()
	_protect_others(machine, 0.0)
	machine.health = machine.max_health
	await _frames(2)


## Oltre 20 m dal giocatore la macchina torna al suo posto entro 0,25 s, poggiata sul suolo.
func _test_leash() -> void:
	print("leash")
	var machine := _turret
	var p := AREA + Vector3(-12.0, 0.0, 0.0)
	_place_player(p)
	_gather_machines()
	await _frames(30)
	_check(is_equal_approx(_caravan.tuning.leash_distance, 20.0) and is_equal_approx(_caravan.tuning.stuck_seconds, 3.0),
		"guinzaglio di 20 m, incastro di 3 s")
	_place_machine(machine, p + Vector3(25.0, 0.0, 0.0))
	var step := await _steps_until_teleport(machine, 15)
	_check(step >= 0 and Machine.planar_distance(machine.global_position, _caravan.slot_target(machine)) < 0.5,
		"a 25 m torna al suo posto entro 0,25 s (passo %d)" % step)
	await _check_on_ground(machine)


## Chiusa in una buca a piu di 5 m dal giocatore: ferma fino a `stuck_seconds`, poi torna al posto.
func _test_pit() -> void:
	print("pit")
	var machine := _turret
	var p := AREA + Vector3(-12.0, 0.0, 0.0)
	_place_player(p)
	_gather_machines()
	await _frames(30)
	# Buca a campana larga 2 m e profonda 3: la macchina scivola sul fondo e s'incastra contro
	# la parete verso il suo posto.
	var pit := p + Vector3(9.0, 0.0, 0.0)
	_field.set_protected(pit, 8.0, false)
	for i in 10:
		_field.sculpt(pit, 2.0, -0.3)
	await _frames(2)
	_path.solve()
	_place_machine(machine, pit)
	var stuck := _caravan.tuning.stuck_seconds
	var early := int((stuck - 0.5) * 60.0)
	var step := await _steps_until_teleport(machine, int((stuck + 1.0) * 60.0))
	_check(step >= early, "nella buca resta ferma per %.1f s (torna al passo %d)" % [stuck - 0.5, step])
	_check(step >= 0 and Machine.planar_distance(machine.global_position, _caravan.slot_target(machine)) < 1.0,
		"entro %.0f s torna al suo posto" % (stuck + 1.0))
	await _check_on_ground(machine)
	_field.reset_to_base(pit, Vector2(4.0, 4.0))
	await _frames(2)
	_path.solve()


## Il giocatore corre a 6 m/s per 5 s dritto, poi 3 s a zig-zag (gira ogni 0,25 s): nessuna
## macchina salta di oltre 1 m in un passo (ne guinzaglio ne incastro scattano seguendolo).
func _test_run_without_teleport() -> void:
	print("run without teleport")
	_place_player(LANE_START)
	_gather_machines()
	await _frames(60)
	var last: Array[Vector3] = []
	for each in _caravan.machines:
		last.append(each.global_position)
	var worst := 0.0
	var farthest := 0.0
	var start := _player.global_position
	Input.action_press(&"move_right")
	for i in 300:
		await physics_frame
		worst = maxf(worst, _step_jump(last))
		farthest = maxf(farthest, _farthest_from_player())
	Input.action_release(&"move_right")
	var ran := Machine.planar_distance(_player.global_position, start)
	for k in 12:
		var action := &"move_forward" if k % 2 == 0 else &"move_back"
		Input.action_press(action)
		for i in 15:
			await physics_frame
			worst = maxf(worst, _step_jump(last))
			farthest = maxf(farthest, _farthest_from_player())
		Input.action_release(action)
	_check(ran >= 25.0, "il giocatore corre %.1f m in 5 s" % ran)
	_check(worst < 1.0, "nessuna macchina salta di oltre 1 m in un passo (%.2f m; al massimo a %.1f m dal giocatore)" % [worst, farthest])
	await _frames(30)


# --- Aiuti ----------------------------------------------------------------------------------------

func _watch(machine: Machine) -> void:
	machine.damaged.connect(_on_damaged.bind(machine))
	machine.state_changed.connect(_on_state_changed.bind(machine))


func _on_damaged(amount: int, machine: Machine) -> void:
	_hits.append([machine, amount])


func _on_state_changed(state: int, machine: Machine) -> void:
	_states.append([machine, state])


func _on_caravan_changed() -> void:
	_changed += 1


func _hits_on(machine: Machine) -> Array[int]:
	var result: Array[int] = []
	for entry: Array in _hits:
		if entry[0] == machine:
			result.append(entry[1])
	return result


func _states_of(machine: Machine) -> Array:
	var result: Array = []
	for entry: Array in _states:
		if entry[0] == machine:
			result.append(entry[1])
	return result


func _place_player(at: Vector3) -> void:
	_player.global_position = Vector3(at.x, _field.height_at(at) + 0.88, at.z)
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	_path.solve()


func _place_machine(machine: Machine, at: Vector3) -> void:
	machine.global_position = Vector3(at.x, _field.height_at(at) + Caravan.GROUND_CLEARANCE, at.z)
	machine.velocity = Vector3.ZERO
	machine.reset_physics_interpolation()


## Tutte le macchine al loro posto attorno al giocatore.
func _gather_machines() -> void:
	for each in _caravan.machines:
		_place_machine(each, _caravan.slot_target(each))


## Le macchine diverse da [param machine] invulnerabili per [param seconds] (0: di nuovo colpibili).
func _protect_others(machine: Machine, seconds: float) -> void:
	for each in _caravan.machines:
		if each == machine:
			continue
		if seconds > 0.0:
			each.grant_invulnerability(seconds)
		else:
			each._invulnerable_left = 0.0


## Rottamatore fermo (stordito a lungo) e robusto: la Torretta non lo abbatte.
func _spawn_still(at: Vector3) -> Enemy:
	var enemy := _director.spawn_at(at)
	enemy.health = 9999
	enemy.stun(60.0)
	return enemy


func _clear_enemies() -> void:
	_director.clear_horde()
	await _frames(20)


func _planar_speed(machine: Machine) -> float:
	return Vector2(machine.velocity.x, machine.velocity.z).length()


## Aspetta che [param machine] stia ferma per 10 passi (al piu 5 s).
func _settle(machine: Machine) -> bool:
	var still := 0
	for i in 300:
		await physics_frame
		still = still + 1 if _planar_speed(machine) < 0.05 else 0
		if still >= 10:
			return true
	return false


## Passi fino a che la vita arriva a [param health], -1 se non ci arriva entro [param limit].
func _steps_until_health(machine: Machine, health: int, limit: int) -> int:
	for i in limit:
		await physics_frame
		if machine.health == health:
			return i
	return -1


## Passi fino al primo salto di oltre 2 m (un ritorno al posto), -1 se non arriva entro
## [param limit]; al salto la macchina e alla quota del suolo piu GROUND_CLEARANCE.
func _steps_until_teleport(machine: Machine, limit: int) -> int:
	var previous := machine.global_position
	for i in limit:
		await physics_frame
		var now := machine.global_position
		if Machine.planar_distance(now, previous) > 2.0:
			var ground := _field.height_at(now) + Caravan.GROUND_CLEARANCE
			_check(absf(now.y - ground) < 0.05, "al ritorno poggia alla quota del suolo (%.3f m di scarto)" % (now.y - ground))
			return i
		previous = now
	return -1


func _check_on_ground(machine: Machine) -> void:
	await _frames(10)
	var ground := _field.height_at(machine.global_position) + Caravan.GROUND_CLEARANCE
	_check(machine.global_position.y > ground - 0.1, "e qualche passo dopo resta sopra il suolo (%.3f m)" % (machine.global_position.y - ground))


## Salto planare piu lungo di [param machine] in un passo, su [param steps] passi.
func _largest_jump(machine: Machine, steps: int) -> float:
	var worst := 0.0
	var previous := machine.global_position
	for i in steps:
		await physics_frame
		worst = maxf(worst, Machine.planar_distance(machine.global_position, previous))
		previous = machine.global_position
	return worst


## Salto piu lungo fra tutte le macchine rispetto al passo prima; aggiorna [param last].
func _step_jump(last: Array[Vector3]) -> float:
	var worst := 0.0
	for i in _caravan.machines.size():
		var now := _caravan.machines[i].global_position
		worst = maxf(worst, Machine.planar_distance(now, last[i]))
		last[i] = now
	return worst


func _farthest_from_player() -> float:
	var farthest := 0.0
	for each in _caravan.machines:
		farthest = maxf(farthest, Machine.planar_distance(each.global_position, _player.global_position))
	return farthest


## Posto [param index] del grappolo senza scartare i muri (come `_slot_point` prima del task 6).
func _raw_slot(index: int) -> Vector3:
	var place := _caravan.slot_of(index)
	var direction := _caravan._back_direction().rotated(Vector3.UP, deg_to_rad(place.x))
	var point := _player.global_position + direction * place.y
	return Vector3(point.x, _field.height_at(point), point.z)


## Blocco di rovina 2 x 2 m (layer 1, come i muri del quartiere) centrato su [param at].
func _add_wall(at: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.0, 2.0)
	shape.shape = box
	wall.add_child(shape)
	_scene.add_child(wall)
	wall.global_position = Vector3(at.x, _field.height_at(at) + 1.0, at.z)
	return wall


## Fuori dal quadrato di mezzo lato [param half] centrato su [param center] (piano XZ).
func _outside(point: Vector3, center: Vector3, half: float) -> bool:
	return maxf(absf(point.x - center.x), absf(point.z - center.z)) > half
