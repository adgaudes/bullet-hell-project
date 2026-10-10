class_name TrainEvent
extends Node3D
## Il treno della ferrovia (D-066, docs/RAILWAY_LEVEL_SPEC.md sezione 3): a intervalli
## regolari un convoglio attraversa tutta l'arena lungo uno dei due binari e
## **spiana la fascia** (le tre righe di celle attorno a z = 0): terrapieni, barricate
## e vagoni tornano Normal senza lasciare rottami, le trincee si riempiono, i
## rottami a terra e i lampioni spariscono. Chi sta sulla fascia viene travolto:
## i rottamatori muoiono (e contano come abbattuti dal giocatore), il giocatore
## subisce danno e viene spinto fuori, il compagno viene solo spinto, il boss
## subisce `boss_damage` e viene spinto.
##
## Non ha un passo fisico proprio: `ArenaRun` lo fa avanzare con il tempo di
## livello, cosi la pausa e la fine del livello lo fermano da sole.
## Il treno arriva alternativamente da est e da ovest; il binario e a caso (`rng`).

signal train_warned(direction: Vector3, seconds: float)
signal train_passing(direction: Vector3)
## Qualcosa e stato travolto: "cell", "enemy", "player", "companion", "boss", "lamp", "scrap".
signal train_hit(what: StringName)
signal train_passed(passes: int)

enum State { IDLE, WARNING, PASSING }

const CARRIAGE_MODEL := preload("res://assets/models/train_carriage.glb")
## Lunghezza di un vagone (modello) e spazio fra due vagoni.
const CARRIAGE_LENGTH := 13.0
const CARRIAGE_GAP := 0.7
const LOCOMOTIVE_PAINT := Color(0.12, 0.11, 0.1)
const CARRIAGE_PAINTS: Array[Color] = [
	Color(0.62, 0.20, 0.14), Color(0.88, 0.68, 0.14), Color(0.30, 0.36, 0.52), Color(0.72, 0.32, 0.12),
]
## Chi viene spinto fuori finisce a questa distanza oltre il bordo della fascia.
const PUSH_MARGIN := 0.8
## Terra delle celle spianate, per i frammenti.
const EARTH_COLOR := Color(0.44, 0.33, 0.21)
const DIRECTION_NAMES: Dictionary[int, String] = {-1: "EST", 1: "OVEST"}

@export var grid: TerrainGrid
@export var district: RailwayDistrict
@export var player: PlayerCharacter
@export var companion: Companion
@export var director: EnemyDirector
@export var lamp_field: LampField
@export var scrap_field: ScrapField
@export var hud: RunHud

## Secondi di livello del primo passaggio, poi uno ogni `interval_seconds`; 0 = mai.
var first_seconds := 90.0
var interval_seconds := 150.0
var warning_seconds := 10.0
var speed := 18.0
var carriages := 5
var player_damage := 2
var boss_damage := 30
## Il boss in campo, se c'e (lo imposta ArenaRun).
var boss: Enemy
var rng := RandomNumberGenerator.new()

var state := State.IDLE
## Secondi di livello del prossimo passaggio.
var next_at := 0.0
## +1: il treno va verso +X (viene da ovest); -1: verso -X (viene da est).
var heading := -1
var track_z := 0.0
var passes := 0
## Celle spianate, nemici travolti e colpi al giocatore nell'ultimo passaggio.
var cells_flattened := 0
var enemies_hit := 0
var player_hits := 0
var _train: Node3D
## Posizione X del muso e ultima colonna di celle gia spazzata.
var _head_x := 0.0
var _swept_column := -1
var _hit: Dictionary[Node, bool] = {}
var _first_warning := true


func _ready() -> void:
	next_at = first_seconds


func is_enabled() -> bool:
	return first_seconds > 0.0 and district != null and grid != null


func is_passing() -> bool:
	return state == State.PASSING


func direction_name() -> String:
	return DIRECTION_NAMES[heading]


## Verso del mondo da cui arriva il treno (per la freccia dell'HUD).
func arrival_direction() -> Vector3:
	return Vector3(-heading, 0.0, 0.0)


## Lunghezza del convoglio, locomotiva compresa.
func train_length() -> float:
	return (carriages + 1) * (CARRIAGE_LENGTH + CARRIAGE_GAP)


## Posizione X del muso; la coda e `train_length()` dietro.
func head_x() -> float:
	return _head_x


func seconds_to_next(elapsed: float) -> float:
	return next_at - elapsed


## Un passo, dal tempo di livello.
func advance(elapsed: float, delta: float) -> void:
	if not is_enabled():
		return
	match state:
		State.IDLE:
			if elapsed >= next_at - warning_seconds:
				_start_warning()
			else:
				return
			_tick_warning(elapsed)
		State.WARNING:
			_tick_warning(elapsed)
		State.PASSING:
			_tick_passing(delta)


func _start_warning() -> void:
	state = State.WARNING
	# Il primo viene da est (heading -1); poi si alterna.
	if _first_warning:
		_first_warning = false
	else:
		heading = -heading
	track_z = RailwayDistrict.TRACK_Z[rng.randi_range(0, RailwayDistrict.TRACK_Z.size() - 1)]
	print("PROTOTYPE01_TRAIN_WARNING from=%s track_z=%.1f at=%.1f" % [direction_name(), track_z, next_at])
	train_warned.emit(arrival_direction(), warning_seconds)


func _tick_warning(elapsed: float) -> void:
	var left := next_at - elapsed
	if hud != null:
		hud.set_event_warning("TRENO DA %s" % direction_name(), arrival_direction(), left, RunHud.TRAIN_COLOR)
	if left <= 0.0:
		_start_passing()


func _start_passing() -> void:
	state = State.PASSING
	cells_flattened = 0
	enemies_hit = 0
	player_hits = 0
	_hit.clear()
	_swept_column = -1
	# Parte oltre il portale, tutto fuori dall'arena.
	_head_x = -heading * (district.half_x() + RailwayDistrict.PORTAL_DEPTH + 4.0)
	_build_train()
	if hud != null:
		hud.clear_event_warning()
	print("PROTOTYPE01_TRAIN_PASS from=%s track_z=%.1f" % [direction_name(), track_z])
	train_passing.emit(arrival_direction())


func _tick_passing(delta: float) -> void:
	_head_x += heading * speed * delta
	_place_train()
	_sweep_cells()
	_sweep_actors()
	var tail_x := _head_x - heading * train_length()
	if heading * tail_x > district.half_x() + RailwayDistrict.PORTAL_DEPTH + 4.0:
		_finish_pass()


func _finish_pass() -> void:
	state = State.IDLE
	passes += 1
	next_at += interval_seconds
	if _train != null:
		_train.queue_free()
		_train = null
	print("PROTOTYPE01_TRAIN_PASSED passes=%d cells=%d enemies=%d player_hits=%d" % [passes, cells_flattened, enemies_hit, player_hits])
	train_passed.emit(passes)


# --- Effetti sul mondo ----------------------------------------------------------------

## Il muso entra in una colonna di celle: tutta la fascia in quella colonna torna Normal,
## senza rottami (a differenza del Demolitore), e cio che c'e sopra sparisce.
func _sweep_cells() -> void:
	var head_cell := grid.cell_at(Vector3(_head_x, 0.0, 0.0))
	var column := head_cell.y
	if column < 0 or column >= grid.state.height:
		return
	if _swept_column < 0:
		_swept_column = column - heading
	var center_row := grid.cell_at(Vector3.ZERO).x
	while _swept_column != column:
		_swept_column += heading
		for dx in range(-RailwayDistrict.TRACK_HALF_ROWS, RailwayDistrict.TRACK_HALF_ROWS + 1):
			var cell := Vector2i(center_row + dx, _swept_column)
			if not grid.state.is_valid(cell):
				continue
			var at := grid.to_global(grid.cell_local_position(cell, TerrainState.CellState.NORMAL))
			at.y = 0.0
			var was := grid.state.get_state(cell)
			if was != TerrainState.CellState.NORMAL and grid.force_cell_state(cell, TerrainState.CellState.NORMAL):
				cells_flattened += 1
				if was == TerrainState.CellState.RAISED:
					DebrisBurst.spawn(get_parent(), at + Vector3(0.0, 0.8, 0.0), EARTH_COLOR, 12, 5.0, 0.2)
				train_hit.emit(&"cell")
			if lamp_field != null and lamp_field.knock_down_near(at, grid.cell_size_m() * 0.6) > 0:
				train_hit.emit(&"lamp")
			if scrap_field != null and scrap_field.take_near(at, grid.cell_size_m() * 0.75, 16) > 0:
				train_hit.emit(&"scrap")


## Chi sta sulla fascia fra coda e muso viene travolto, una volta per passaggio.
func _sweep_actors() -> void:
	var tail_x := _head_x - heading * train_length()
	if player != null and _covers(player.global_position, tail_x) and not _hit.has(player):
		_hit[player] = true
		player_hits += 1
		player.take_damage(player_damage)
		_push_out(player)
		train_hit.emit(&"player")
		print("PROTOTYPE01_TRAIN_HIT what=player")
	if companion != null and _covers(companion.global_position, tail_x) and not _hit.has(companion):
		_hit[companion] = true
		_push_out(companion)
		train_hit.emit(&"companion")
	if director == null:
		return
	for enemy in director.enemies.duplicate():
		if enemy.is_dead or _hit.has(enemy) or not _covers(enemy.global_position, tail_x):
			continue
		_hit[enemy] = true
		if enemy == boss or enemy.self_driven:
			enemy.take_damage(boss_damage)
			if not enemy.is_dead:
				_push_out(enemy)
			train_hit.emit(&"boss")
			print("PROTOTYPE01_TRAIN_HIT what=boss damage=%d" % boss_damage)
		else:
			enemies_hit += 1
			enemy.take_damage(enemy.health)
			train_hit.emit(&"enemy")


func _covers(at: Vector3, tail_x: float) -> bool:
	if not RailwayDistrict.is_on_tracks(Vector2(at.x, at.z)):
		return false
	return minf(_head_x, tail_x) - 0.5 <= at.x and at.x <= maxf(_head_x, tail_x) + 0.5


## Spinto fuori dalla fascia dal lato dove gia pende (a z = 0 verso sud, dove sta la camera).
func _push_out(body: Node3D) -> void:
	var at := body.global_position
	var side := 1.0 if at.z >= 0.0 else -1.0
	at.z = side * (RailwayDistrict.track_half_width() + PUSH_MARGIN)
	body.global_position = at
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
	body.reset_physics_interpolation()


# --- Convoglio visivo ----------------------------------------------------------------

func _build_train() -> void:
	if _train != null:
		_train.queue_free()
	_train = Node3D.new()
	_train.name = "Train"
	add_child(_train)
	for i in carriages + 1:
		var paint := LOCOMOTIVE_PAINT if i == 0 else CARRIAGE_PAINTS[(i - 1) % CARRIAGE_PAINTS.size()]
		var carriage: Node3D = district.spawn_model(CARRIAGE_MODEL, _train, Transform3D.IDENTITY,
			{&"tint": paint, &"rust": 0.25 if i == 0 else 0.5, &"overgrowth": 0.0})
		carriage.name = "Locomotive" if i == 0 else "Carriage%d" % i
		if i == 0:
			var stack := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.35
			mesh.bottom_radius = 0.45
			mesh.height = 1.4
			stack.mesh = mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.08, 0.08, 0.08)
			stack.material_override = material
			stack.position = Vector3(0.0, 3.9, -CARRIAGE_LENGTH * 0.35)
			carriage.add_child(stack)
	_place_train()


## Il modello del vagone e lungo l'asse Z locale: imbardata di 90 gradi per correre lungo X.
func _place_train() -> void:
	if _train == null:
		return
	var pitch := CARRIAGE_LENGTH + CARRIAGE_GAP
	for i in _train.get_child_count():
		var carriage := _train.get_child(i) as Node3D
		var center_x := _head_x - heading * (pitch * i + CARRIAGE_LENGTH * 0.5)
		carriage.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 * heading), Vector3(center_x, 0.0, track_z))
