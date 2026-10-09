extends SceneTree
## Test del secondo boss, la Trivella (D-066), nel livello della ferrovia. Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/driller_tests.gd

const RunScene := preload("res://scenes/main/railway_run.tscn")
const RAISED := TerrainState.CellState.RAISED
const NORMAL := TerrainState.CellState.NORMAL
const LOWERED := TerrainState.CellState.LOWERED

var _failures := 0
var _scene: Node3D
var _run: ArenaRun
var _grid: TerrainGrid
var _player: PlayerCharacter
var _companion: Companion
var _director: EnemyDirector
var _weapon: AutoWeapon
var _path: PathField
var _hud: RunHud
var _scrap: ScrapField
var _train: TrainEvent
var _audio: RunAudio
var _boss: Driller


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	_run = _scene.get_node(^"Run")
	_grid = _scene.get_node(^"TerrainGrid")
	_player = _scene.get_node(^"Player")
	_companion = _scene.get_node(^"Companion")
	_director = _scene.get_node(^"EnemyDirector")
	_weapon = _scene.get_node(^"PlayerWeapon")
	_path = _scene.get_node(^"PathField")
	_hud = _scene.get_node(^"RunHud")
	_scrap = _scene.get_node(^"ScrapField")
	_train = _scene.get_node(^"TrainEvent")
	_audio = _scene.get_node(^"RunAudio")
	_director.spawning = false
	# Niente treni durante questi test, salvo dove richiesto.
	_train.next_at = 1.0e9
	await _frames(5)
	_weapon.set_physics_process(false)
	await _test_call_and_arrival()
	await _test_aim_and_charge()
	await _test_wall_stops_and_stuns()
	await _test_charge_length_and_trench()
	await _test_blocked_by_ruin_uses_path()
	await _test_train_hits_boss()
	await _test_defeat_completes_level()
	# T-12: i nodi messi in coda con queue_free vanno liberati prima di uscire, o
	# il motore segnala istanze ObjectDB perse all'uscita.
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


func _place_player(at: Vector3) -> void:
	_player.global_position = Vector3(at.x, 0.88, at.z)
	_player.velocity = Vector3.ZERO
	_player._invulnerable_left = 0.0
	_path.solve()


func _place_boss(at: Vector3, phase: Driller.Phase, left: float) -> void:
	_boss.global_position = Vector3(at.x, Driller.boss_spawn_height(), at.z)
	_boss.velocity = Vector3.ZERO
	_boss.phase = phase
	_boss.phase_left = left
	_boss.reset_physics_interpolation()


func _cell_world(cell: Vector2i) -> Vector3:
	var p := _grid.to_global(_grid.cell_local_position(cell, NORMAL))
	return Vector3(p.x, 0.0, p.z)


func _planar(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Aspetta che la Trivella cominci (o finisca) una carica, al massimo [param frames].
func _wait_phase(phase: Driller.Phase, frames: int) -> bool:
	for i in frames:
		if _boss.phase == phase:
			return true
		await physics_frame
	return _boss.phase == phase


func _test_call_and_arrival() -> void:
	print("call and arrival")
	_check(_run.tuning.boss_kind == &"driller", "il tuning della ferrovia chiama la Trivella")
	_place_player(Vector3(0.0, 0.0, 20.0))
	_run.boss_call_at = _run.elapsed + 0.05
	await _frames(6)
	_check(_run.boss_phase == ArenaRun.BossPhase.WARNING, "a tempo scaduto il boss e annunciato")
	_check(_hud.event_warning_text().begins_with("LA TRIVELLA ARRIVA DA"), "annuncio con il suo nome: %s" % _hud.event_warning_text())
	_run._boss_warning_left = 0.05
	await _frames(6)
	_boss = _run.boss as Driller
	_check(_boss != null and _run.boss_phase == ArenaRun.BossPhase.ACTIVE, "finito il preavviso entra la Trivella")
	if _boss == null:
		return
	_check(_hud.boss_name_text() == "LA TRIVELLA" and _hud.is_boss_bar_visible(), "barra vita con il suo nome")
	_check(_boss.health == _run.tuning.driller_health and _boss.kind == &"driller" and _boss.self_driven, "vita e tipo dal tuning")
	_check(_director.enemies.has(_boss) and _train.boss == _boss, "registrata fra i nemici e nota al treno")
	_check(_audio.play_count(&"boss_spawn") >= 1, "suono d'ingresso")


## La fascia dei binari e l'unico corridoio garantito libero da rovine: i test di
## carica si fanno li, con i vagoni gia spianati.
func _clear_tracks() -> void:
	_grid.set_cell_states(RailwayDistrict.track_cells(_grid), NORMAL)


## Dopo il riposo mira al giocatore (striscia a terra), poi carica dritta scavando un solco;
## il giocatore sulla linea viene colpito una volta e spinto di lato.
func _test_aim_and_charge() -> void:
	print("aim and charge")
	_clear_tracks()
	_place_player(Vector3(-20.0, 0.0, 0.0))
	_place_boss(Vector3(2.0, 0.0, 0.0), Driller.Phase.REST, 0.1)
	_check(await _wait_phase(Driller.Phase.AIM, 30), "dal riposo passa alla mira")
	_check(_boss.get_node(^"AimStrip").visible, "striscia di mira visibile")
	_check(_boss.charge_direction.dot(Vector3(-1.0, 0.0, 0.0)) > 0.95, "mira verso il giocatore (ovest)")
	var charges := _audio.play_count(&"driller_charge")
	var health_before := _player.health
	_check(await _wait_phase(Driller.Phase.CHARGE, int(_boss.aim_seconds * 60.0) + 20), "finita la mira parte la carica")
	_check(not _boss.get_node(^"AimStrip").visible and _audio.play_count(&"driller_charge") == charges + 1, "striscia nascosta e suono della carica")
	var start := _boss.global_position
	await _frames(60)
	var moved := _boss.global_position - start
	_check(moved.x < -3.0 and absf(moved.z) < 0.5, "avanza dritta verso ovest (%.1f m)" % -moved.x)
	var speed := _planar(_boss.velocity).length()
	_check(absf(speed - _boss.charge_speed) < 0.5, "a %.1f m/s" % speed)
	_check(_boss.cells_drilled >= 2, "lascia celle Lowered dietro di se (%d)" % _boss.cells_drilled)
	var behind := _grid.cell_state_at(start + Vector3(-1.5, 0.0, 0.0))
	_check(behind == LOWERED, "la cella attraversata e un solco")
	# Arriva sul giocatore.
	_check(await _wait_phase(Driller.Phase.REST, 400), "la carica finisce in riposo")
	_check(_player.health == health_before - _boss.contact_damage, "giocatore colpito una volta (%d -> %d)" % [health_before, _player.health])
	_check(absf(_player.global_position.z) >= Driller.SIDE_PUSH - 0.5, "e spinto di lato (z=%.1f)" % _player.global_position.z)
	_check(_boss.charges == 1 and _boss.walls_broken == 0, "una carica, nessun muro")


## Un terrapieno sulla linea ferma la carica, torna Normal lasciando un rottame, e la
## Trivella resta stordita con danno doppio; poi riposa e mira di nuovo.
func _test_wall_stops_and_stuns() -> void:
	print("wall")
	_clear_tracks()
	_place_player(Vector3(-24.0, 0.0, 0.0))
	_place_boss(Vector3(2.0, 0.0, 0.0), Driller.Phase.REST, 0.05)
	var wall := _grid.cell_at(Vector3(-9.6, 0.0, 0.0))
	_grid.set_cell_states([wall], RAISED)
	var scrap_before := _scrap.count()
	_check(await _wait_phase(Driller.Phase.CHARGE, 200), "carica verso il muro")
	var stunned := false
	for i in 240:
		await physics_frame
		if _boss.phase == Driller.Phase.STUN:
			stunned = true
			break
	_check(stunned and _boss.walls_broken == 1 and _boss.last_wall == wall, "il terrapieno la ferma e la stordisce")
	_check(_grid.state.get_state(wall) == NORMAL, "il terrapieno e smontato (Normal)")
	_check(_scrap.count() == scrap_before + 1, "lascia un rottame a terra")
	_check(_planar(_boss.velocity).length() < 0.3, "ferma")
	var health := _boss.health
	_boss.take_damage(5)
	_check(_boss.health == health - int(ceil(5 * _boss.stun_damage_multiplier)), "stordita subisce danno x%.0f (%d -> %d)" % [_boss.stun_damage_multiplier, health, _boss.health])
	_check(_audio.play_count(&"boss_demolish") >= 1, "suono del muro sfondato")
	_boss.phase_left = 0.05
	await _frames(6)
	_check(_boss.phase == Driller.Phase.REST, "finito lo stordimento riposa")
	health = _boss.health
	_boss.take_damage(5)
	_check(_boss.health == health - 5, "fuori dallo stordimento danno normale")


## La carica finisce dopo `charge_length` metri; i fossati non la rallentano.
func _test_charge_length_and_trench() -> void:
	print("length and trench")
	_clear_tracks()
	_place_player(Vector3(-100.0, 0.0, 0.0))
	_place_boss(Vector3(0.0, 0.0, 0.0), Driller.Phase.REST, 0.05)
	var cells: Array[Vector2i] = []
	for k in 6:
		cells.append(_grid.cell_at(Vector3(-8.0 - k * 2.4, 0.0, 0.0)))
	_grid.set_cell_states(cells, LOWERED)
	_check(await _wait_phase(Driller.Phase.CHARGE, 200), "carica verso ovest")
	var start := _boss.global_position
	var in_trench_speed := 0.0
	for i in 600:
		await physics_frame
		if _boss.phase != Driller.Phase.CHARGE:
			break
		if _grid.cell_state_at(_boss.global_position) == LOWERED:
			in_trench_speed = maxf(in_trench_speed, _planar(_boss.velocity).length())
	var travelled := _planar(_boss.global_position - start).length()
	_check(_boss.phase == Driller.Phase.REST, "si ferma da sola")
	_check(absf(travelled - _boss.charge_length) < 2.0, "dopo %.1f m (limite %.0f)" % [travelled, _boss.charge_length])
	_check(in_trench_speed > _boss.charge_speed - 0.5, "nel fossato va a piena velocita (%.1f m/s)" % in_trench_speed)


## Con una rovina sulla linea diretta mira lungo il campo di percorso invece di
## incastrarsi; fermata contro un ostacolo che non e una cella.
func _test_blocked_by_ruin_uses_path() -> void:
	print("ruin")
	# Trova una rovina bassa e mette la Trivella dietro di essa rispetto al giocatore.
	var district: RuinsDistrict = _run.district
	var block: StaticBody3D = null
	for child in district.get_children():
		if child is StaticBody3D and child.name.begins_with("Block") and absf(child.position.z) > 12.0 \
				and absf(child.position.x) < 120.0:
			block = child
			break
	_check(block != null, "una rovina bassa trovata")
	if block == null:
		return
	var size := Vector3.ZERO
	for part in block.get_children():
		if part is CollisionShape3D:
			size = ((part as CollisionShape3D).shape as BoxShape3D).size
	var side := 1.0 if block.position.z > 0.0 else -1.0
	var boss_at: Vector3 = _run._walkable_near(block.position + Vector3(0.0, 0.0, side * (size.z * 0.5 + 4.0)), 8.0)
	var player_at: Vector3 = _run._walkable_near(block.position - Vector3(0.0, 0.0, side * (size.z * 0.5 + 6.0)), 8.0)
	_place_player(player_at)
	_place_boss(boss_at, Driller.Phase.REST, 0.05)
	_check(await _wait_phase(Driller.Phase.AIM, 30), "mira")
	var direct := _planar(player_at - boss_at).normalized()
	var aimed := _planar(_boss.charge_direction).normalized()
	_check(aimed.dot(direct) < 0.98, "non mira dritto nella rovina (deviazione %.0f gradi)" % rad_to_deg(acos(clampf(aimed.dot(direct), -1.0, 1.0))))
	_check(await _wait_phase(Driller.Phase.CHARGE, 200), "carica")
	_check(await _wait_phase(Driller.Phase.REST, 700), "e si ferma (per lunghezza o ostacolo)")


## Il treno che la travolge sui binari le toglie `train_boss_damage` e la spinge fuori.
func _test_train_hits_boss() -> void:
	print("train")
	_place_player(Vector3(0.0, 0.0, 30.0))
	# A riposo (stordita il danno raddoppierebbe): resta ferma sul binario.
	_place_boss(Vector3(-20.0, 0.0, _train.track_z if _train.track_z != 0.0 else 2.4), Driller.Phase.REST, 60.0)
	var health := _boss.health
	_train.speed = 80.0
	_train.warning_seconds = 0.5
	_train.next_at = _run.elapsed + 0.55
	for i in 700:
		await physics_frame
		if _train.passes >= 1:
			break
	_check(_train.passes == 1, "un treno e passato")
	_check(_boss.health == health - _run.tuning.train_boss_damage, "la Trivella perde %d (%d -> %d)" % [_run.tuning.train_boss_damage, health, _boss.health])
	_check(not RailwayDistrict.is_on_tracks(_planar(_boss.global_position)), "e spinta fuori dalla fascia (z=%.1f)" % _boss.global_position.z)
	_train.next_at = 1.0e9


func _test_defeat_completes_level() -> void:
	print("defeat")
	var completed := [false]
	_run.level_completed.connect(func() -> void: completed[0] = true)
	_boss.phase = Driller.Phase.REST
	_boss.phase_left = 60.0
	_boss.take_damage(_boss.health)
	await _frames(3)
	_check(completed[0] and _run.boss_phase == ArenaRun.BossPhase.DEFEATED and _run.is_over, "alla sua morte il livello e completato")
	_check(_director.enemies.is_empty(), "l'orda si ritira")
