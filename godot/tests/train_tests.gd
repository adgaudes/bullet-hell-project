extends SceneTree
## Test del treno della ferrovia (D-066): preavviso, fascia spianata senza rottami,
## rottamatori travolti, giocatore e compagno spinti fuori, lampioni e rottami a terra
## spazzati, direzione alternata. Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/train_tests.gd

const RunScene := preload("res://scenes/main/railway_run.tscn")
const RAISED := TerrainState.CellState.RAISED
const LOWERED := TerrainState.CellState.LOWERED
const NORMAL := TerrainState.CellState.NORMAL

var _failures := 0
var _scene: Node3D
var _run: ArenaRun
var _train: TrainEvent
var _grid: TerrainGrid
var _player: PlayerCharacter
var _companion: Companion
var _director: EnemyDirector
var _weapon: AutoWeapon
var _hud: RunHud
var _lamps: LampField
var _scrap: ScrapField
var _audio: RunAudio


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	_run = _scene.get_node(^"Run")
	_train = _scene.get_node(^"TrainEvent")
	_grid = _scene.get_node(^"TerrainGrid")
	_player = _scene.get_node(^"Player")
	_companion = _scene.get_node(^"Companion")
	_director = _scene.get_node(^"EnemyDirector")
	_weapon = _scene.get_node(^"PlayerWeapon")
	_hud = _scene.get_node(^"RunHud")
	_lamps = _scene.get_node(^"LampField")
	_scrap = _scene.get_node(^"ScrapField")
	_audio = _scene.get_node(^"RunAudio")
	_director.spawning = false
	await _frames(5)
	_weapon.set_physics_process(false)
	_test_setup()
	await _test_warning()
	await _test_pass_flattens_and_hits()
	await _test_second_train_from_the_other_side()
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


func _cell_world(cell: Vector2i) -> Vector3:
	var p := _grid.to_global(_grid.cell_local_position(cell, NORMAL))
	return Vector3(p.x, 0.0, p.z)


func _place(body: Node3D, at: Vector3, y: float) -> void:
	body.global_position = Vector3(at.x, y, at.z)
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO


func _test_setup() -> void:
	print("setup")
	_check(_run.train_event == _train and _train.is_enabled(), "il treno e collegato alla regia")
	_check(is_equal_approx(_train.next_at, _run.tuning.train_first_seconds), "primo passaggio a %.0f s" % _train.next_at)
	_check(_train.state == TrainEvent.State.IDLE and not _hud.is_boss_warning_visible(), "all'inizio nessun treno e nessun annuncio")
	_check(_audio.has_sound(&"train_horn"), "il fischio esiste nella libreria")


func _test_warning() -> void:
	print("warning")
	_train.warning_seconds = 1.0
	_train.next_at = _run.elapsed + 1.05
	await _frames(6)
	_check(_train.state == TrainEvent.State.WARNING, "entro il preavviso il treno e annunciato")
	_check(_train.heading == -1 and _train.direction_name() == "EST", "il primo treno viene da est")
	_check(_hud.is_boss_warning_visible() and _hud.event_warning_text().begins_with("TRENO DA EST"), "annuncio a schermo: %s" % _hud.event_warning_text())
	_check(_audio.play_count(&"train_horn") >= 1, "fischio al preavviso")
	_check(absf(_train.track_z) == RailwayDistrict.CELL, "binario scelto a z = %.1f" % _train.track_z)


## Un muro e un vagone sulla fascia davanti al treno, un rottamatore, un lampione, un
## rottame a terra, il giocatore sul binario e il compagno accanto: dopo il passaggio
## la fascia e Normal, chi era sopra e morto o spinto fuori, i rottami non aumentano.
func _test_pass_flattens_and_hits() -> void:
	print("pass")
	_train.speed = 80.0
	var center := _grid.cell_at(Vector3.ZERO)
	# Davanti al treno (viene da est, quindi a x > 0): muro, trincea e lampione sulla fascia.
	var wall := Vector2i(center.x + 1, center.y + 10)
	var trench := Vector2i(center.x, center.y + 12)
	_grid.set_cell_states([wall], RAISED)
	_grid.set_cell_states([trench], LOWERED)
	var off_strip := Vector2i(center.x + 3, center.y + 10)
	_grid.set_cell_states([off_strip], RAISED)
	var lamp_at := _cell_world(Vector2i(center.x - 1, center.y + 14))
	_companion.add_capacity(0, 3)
	_place(_companion, lamp_at + Vector3(2.0, 0.0, 3.0), 0.3)
	_lamps.place_at(lamp_at)
	_check(_lamps.count() == 1, "lampione piazzato sulla fascia")
	_scrap.spawn_on_ground(_cell_world(Vector2i(center.x, center.y + 16)))
	var scrap_before := _scrap.count()
	var wagon_cells := 0
	for f: Dictionary in _run.district.terrain_features:
		if f.kind == &"wagon":
			wagon_cells += f.offsets.size()
	var enemy := _director.spawn_at(_cell_world(Vector2i(center.x, center.y + 20)))
	var enemy_died := [false]
	enemy.died.connect(func(_e: Enemy) -> void: enemy_died[0] = true)
	var bystander := _director.spawn_at(_cell_world(Vector2i(center.x + 4, center.y + 20)))
	var kills_before := _director.kills
	_place(_player, Vector3(30.0, 0.0, _train.track_z), 0.88)
	_player._invulnerable_left = 0.0
	var health_before := _player.health
	_place(_companion, Vector3(33.0, 0.0, 0.0), 0.3)
	# Il treno entra allo scadere del preavviso.
	for i in 90:
		await physics_frame
		if _train.state == TrainEvent.State.PASSING:
			break
	_check(_train.state == TrainEvent.State.PASSING, "finito il preavviso il treno e in corsa")
	_check(_train.get_node_or_null(^"Train") != null and _train.get_node(^"Train").get_child_count() == _run.tuning.train_carriages + 1,
		"convoglio di %d vagoni piu la locomotiva" % _run.tuning.train_carriages)
	_check(not _hud.is_boss_warning_visible(), "annuncio tolto all'ingresso")
	# Aspetta che la coda esca a ovest: (319 + 2*12 + 82) m a 80 m/s.
	for i in 600:
		await physics_frame
		if _train.state == TrainEvent.State.IDLE:
			break
	_check(_train.state == TrainEvent.State.IDLE and _train.passes == 1, "il passaggio e finito (%d)" % _train.passes)
	_check(_grid.state.get_state(wall) == NORMAL and _grid.state.get_state(trench) == NORMAL, "muro e trincea sulla fascia spianati")
	_check(_grid.state.get_state(off_strip) == RAISED, "il muro fuori dalla fascia resta")
	var wagons_left := 0
	for cell in RailwayDistrict.track_cells(_grid):
		if _grid.state.get_state(cell) != NORMAL:
			wagons_left += 1
	_check(wagons_left == 0, "tutta la fascia e Normal, vagoni compresi (%d celle non Normal)" % wagons_left)
	_check(_train.cells_flattened >= wagon_cells + 2, "celle spianate: %d (almeno %d)" % [_train.cells_flattened, wagon_cells + 2])
	_check(_scrap.count() <= scrap_before - 1, "nessun rottame dai vagoni e il rottame a terra e sparito (%d -> %d)" % [scrap_before, _scrap.count()])
	_check(_lamps.count() == 0, "lampione sulla fascia abbattuto")
	_check(enemy_died[0] and _director.kills == kills_before + 1, "rottamatore sulla fascia travolto e contato come abbattuto")
	_check(not bystander.is_dead, "rottamatore fuori dalla fascia illeso")
	_check(_player.health == health_before - _run.tuning.train_player_damage, "giocatore colpito: %d -> %d" % [health_before, _player.health])
	_check(not RailwayDistrict.is_on_tracks(Vector2(_player.global_position.x, _player.global_position.z)), "giocatore spinto fuori dalla fascia (z=%.1f)" % _player.global_position.z)
	_check(not RailwayDistrict.is_on_tracks(Vector2(_companion.global_position.x, _companion.global_position.z)), "compagno spinto fuori (z=%.1f)" % _companion.global_position.z)
	_check(_train.player_hits == 1 and _train.enemies_hit == 1, "un colpo al giocatore, un rottamatore (%d, %d)" % [_train.player_hits, _train.enemies_hit])
	_check(_train.next_at > _run.elapsed and _train.next_at - _run.elapsed <= _run.tuning.train_interval_seconds,
		"prossimo treno fra %.0f s" % (_train.next_at - _run.elapsed))
	_check(_audio.play_count(&"train_horn") >= 2, "fischio anche all'ingresso")
	bystander.queue_free()
	_director.enemies.clear()


func _test_second_train_from_the_other_side() -> void:
	print("second train")
	_place(_player, Vector3(0.0, 0.0, 20.0), 0.88)
	_place(_companion, Vector3(0.0, 0.0, 22.0), 0.3)
	_train.next_at = _run.elapsed + 1.05
	await _frames(6)
	_check(_train.state == TrainEvent.State.WARNING and _train.heading == 1 and _train.direction_name() == "OVEST", "il secondo treno viene da ovest")
	var health_before := _player.health
	for i in 90:
		await physics_frame
		if _train.state == TrainEvent.State.PASSING:
			break
	_check(_train.state == TrainEvent.State.PASSING and _train.head_x() < -_run.district.half_x() + 30.0, "parte da oltre il portale ovest (x=%.0f)" % _train.head_x())
	for i in 600:
		await physics_frame
		if _train.state == TrainEvent.State.IDLE:
			break
	_check(_train.passes == 2, "secondo passaggio concluso")
	_check(_player.health == health_before and _train.player_hits == 0, "fuori dalla fascia il giocatore non e toccato")
