class_name QuakeEvent
extends Node3D
## Il terremoto del quartiere (D-075, idea 2 di FEATURE_IDEAS.md): a intervalli regolari
## una **faglia** annunciata attraversa il campo vicino al giocatore. Dopo il preavviso
## (freccia e conto alla rovescia nell'HUD, polvere lungo la linea) il fronte corre da un
## capo all'altro della faglia: le celle Normal si **rialzano** in terrapieno, le trincee
## si **riempiono**, i terrapieni restano. Chi sta su una cella della faglia: i rottamatori
## vengono travolti (contano come abbattuti), il giocatore subisce `player_damage` e la
## sua cella viene risparmiata, compagno e boss sono risparmiati. I lampioni sulla linea
## cadono; i rottami a terra vengono riportati in superficie da ScrapField.
##
## Come il treno non ha un passo fisico proprio: `ArenaRun` lo fa avanzare con il tempo di
## livello. Alla fine chiede alle impronte dell'orda (FlowPreview) di mostrarsi: il
## giocatore vede subito come la faglia devia i nemici.

signal quake_warned(direction: Vector3, seconds: float)
signal quake_started(center: Vector3)
## Qualcosa e stato colpito: "cell", "enemy", "player", "lamp".
signal quake_hit(what: StringName)
signal quake_done(quakes: int)

enum State { IDLE, WARNING, SHAKING }

const EARTH_COLOR := Color(0.44, 0.33, 0.21)
const DUST_COLOR := Color(0.6, 0.5, 0.36)
## Polvere sulla faglia durante il preavviso: ogni quanti secondi e su quante celle.
const DUST_INTERVAL := 0.35
const DUST_CELLS := 3

@export var grid: TerrainGrid
@export var player: PlayerCharacter
@export var companion: Companion
@export var director: EnemyDirector
@export var lamp_field: LampField
@export var hud: RunHud
@export var flow_preview: FlowPreview

## Secondi di livello del primo terremoto, poi uno ogni `interval_seconds`; 0 = mai.
var first_seconds := 120.0
var interval_seconds := 150.0
var warning_seconds := 6.0
## Lunghezza della faglia in celle e distanza del suo centro dal giocatore.
var length_cells := 18
var distance_min := 7.0
var distance_max := 13.0
## Celle rialzate al secondo dal fronte.
var cells_per_second := 14.0
var player_damage := 1
## Il boss in campo, se c'e (lo imposta ArenaRun).
var boss: Enemy
var rng := RandomNumberGenerator.new()

var state := State.IDLE
## Secondi di livello del prossimo terremoto.
var next_at := 0.0
var quakes := 0
## Celle della faglia, da un capo all'altro, e il suo centro nel mondo.
var fault_cells: Array[Vector2i] = []
var fault_center := Vector3.ZERO
## Esito dell'ultimo terremoto.
var cells_raised := 0
var cells_filled := 0
var enemies_hit := 0
var player_hits := 0
var _front := 0
var _front_progress := 0.0
var _dust_left := 0.0


func _ready() -> void:
	next_at = first_seconds


func is_enabled() -> bool:
	return first_seconds > 0.0 and grid != null


func is_shaking() -> bool:
	return state == State.SHAKING


## Verso del mondo in cui sta la faglia rispetto al giocatore (per la freccia dell'HUD).
func fault_direction() -> Vector3:
	if player == null:
		return Vector3.FORWARD
	var d := fault_center - player.global_position
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.01 else Vector3.FORWARD


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
			_tick_warning(elapsed, delta)
		State.WARNING:
			_tick_warning(elapsed, delta)
		State.SHAKING:
			_tick_shaking(delta)


# --- Preavviso -------------------------------------------------------------------------

func _start_warning() -> void:
	state = State.WARNING
	_choose_fault()
	_dust_left = 0.0
	print("PROTOTYPE01_QUAKE_WARNING cells=%d center=(%.1f, %.1f) at=%.1f"
		% [fault_cells.size(), fault_center.x, fault_center.z, next_at])
	quake_warned.emit(fault_direction(), warning_seconds)


## Una linea retta di `length_cells` celle, con un orientamento a caso, il cui centro sta
## fra `distance_min` e `distance_max` metri dal giocatore in una direzione a caso.
func _choose_fault() -> void:
	fault_cells.clear()
	var origin := player.global_position if player != null else Vector3.ZERO
	var toward := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(distance_min, distance_max)
	fault_center = Vector3(origin.x + cos(toward) * distance, 0.0, origin.z + sin(toward) * distance)
	var along := rng.randf_range(0.0, TAU)
	var step := Vector3(cos(along), 0.0, sin(along)) * grid.cell_size_m()
	var half := length_cells * 0.5
	for i in length_cells:
		var cell := grid.cell_at(fault_center + step * (i - half + 0.5))
		if grid.state.is_valid(cell) and not fault_cells.has(cell):
			fault_cells.append(cell)


func _tick_warning(elapsed: float, delta: float) -> void:
	var left := next_at - elapsed
	if hud != null:
		hud.set_event_warning("TERREMOTO", fault_direction(), left, RunHud.QUAKE_COLOR)
	_dust_left -= delta
	if _dust_left <= 0.0 and not fault_cells.is_empty():
		_dust_left = DUST_INTERVAL
		for i in DUST_CELLS:
			var cell := fault_cells[rng.randi_range(0, fault_cells.size() - 1)]
			DebrisBurst.spawn(get_parent(), _cell_center(cell) + Vector3(0.0, 0.15, 0.0), DUST_COLOR, 3, 1.2, 0.08)
	if left <= 0.0:
		_start_shaking()


# --- Scossa ----------------------------------------------------------------------------

func _start_shaking() -> void:
	state = State.SHAKING
	cells_raised = 0
	cells_filled = 0
	enemies_hit = 0
	player_hits = 0
	_front = 0
	_front_progress = 0.0
	if hud != null:
		hud.clear_event_warning()
	print("PROTOTYPE01_QUAKE_START cells=%d" % fault_cells.size())
	quake_started.emit(fault_center)


func _tick_shaking(delta: float) -> void:
	_front_progress += delta * cells_per_second
	while _front < fault_cells.size() and float(_front) < _front_progress:
		_shake_cell(fault_cells[_front])
		_front += 1
	if _front >= fault_cells.size():
		_finish()


func _shake_cell(cell: Vector2i) -> void:
	if not grid.state.is_valid(cell) or grid.state.is_protected(cell):
		return
	var at := _cell_center(cell)
	if player != null and grid.cell_at(player.global_position) == cell:
		player.take_damage(player_damage)
		player_hits += 1
		quake_hit.emit(&"player")
		print("PROTOTYPE01_QUAKE_HIT what=player")
		return
	# Chi e vicino al bordo della cella viene risparmiato: la collisione del terrapieno
	# arriva un passo dopo e un corpo in movimento ci finirebbe dentro.
	if _near(player, at) or _near(companion, at):
		return
	if boss != null and not boss.is_dead and grid.raise_overlaps(cell, boss):
		return
	match grid.state.get_state(cell):
		TerrainState.CellState.LOWERED:
			if grid.force_cell_state(cell, TerrainState.CellState.NORMAL):
				cells_filled += 1
				DebrisBurst.spawn(get_parent(), at + Vector3(0.0, 0.3, 0.0), EARTH_COLOR, 6, 3.0, 0.14)
				quake_hit.emit(&"cell")
		TerrainState.CellState.NORMAL:
			if director != null:
				for enemy in director.enemies.duplicate():
					if not enemy.is_dead and enemy != boss and grid.cell_at(enemy.global_position) == cell:
						enemies_hit += 1
						enemy.take_damage(enemy.health)
						quake_hit.emit(&"enemy")
			if grid.force_cell_state(cell, TerrainState.CellState.RAISED):
				cells_raised += 1
				DebrisBurst.spawn(get_parent(), at + Vector3(0.0, 1.0, 0.0), EARTH_COLOR, 10, 4.0, 0.18)
				quake_hit.emit(&"cell")
			if lamp_field != null and lamp_field.knock_down_near(at, grid.cell_size_m() * 0.6) > 0:
				quake_hit.emit(&"lamp")


func _near(body: Node3D, at: Vector3) -> bool:
	if body == null:
		return false
	var p := body.global_position
	return Vector2(p.x - at.x, p.z - at.z).length() < grid.cell_size_m() * 0.9


func _finish() -> void:
	state = State.IDLE
	quakes += 1
	next_at += interval_seconds
	print("PROTOTYPE01_QUAKE_DONE n=%d raised=%d filled=%d enemies=%d player_hits=%d"
		% [quakes, cells_raised, cells_filled, enemies_hit, player_hits])
	if flow_preview != null:
		flow_preview.show_now()
	quake_done.emit(quakes)


func _cell_center(cell: Vector2i) -> Vector3:
	var p := grid.to_global(grid.cell_local_position(cell, TerrainState.CellState.NORMAL))
	return Vector3(p.x, 0.0, p.z)
