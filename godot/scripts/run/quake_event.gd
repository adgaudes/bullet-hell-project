class_name QuakeEvent
extends Node3D
## Il terremoto del quartiere (D-075, idea 2 di FEATURE_IDEAS.md): a intervalli regolari
## una **faglia** annunciata attraversa il campo vicino al giocatore. Dopo il preavviso
## (freccia e conto alla rovescia nell'HUD, polvere lungo la linea) il fronte corre da un
## capo all'altro della faglia. Sul rilievo continuo (D-085) ogni pennellata alza una
## **cresta** e scava un **solco** a fianco; sulla griglia (ferrovia) le celle Normal si
## rialzano e le trincee si riempiono. Chi sta sulla faglia: i rottamatori vengono
## travolti (contano come abbattuti), il giocatore subisce `player_damage` e il suo punto
## viene risparmiato, compagno e boss sono risparmiati. I lampioni sulla linea cadono; i
## rottami a terra rotolano o vengono riportati in superficie da ScrapField.
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
## Rilievo continuo: cresta e solco di ogni pennellata, passo fra le pennellate, raggio in
## cui un corpo e colpito o risparmiato.
const CREST_HEIGHT := 1.2
const FURROW_DEPTH := 0.6
const FAULT_STEP := 2.4
const CREST_RADIUS := 2.4
const FURROW_RADIUS := 1.8
const HIT_RADIUS := 1.2
const BOSS_SPARE_RADIUS := 3.0

## Rilievo continuo (D-085): la faglia e una fila di pennellate.
@export var terrain_field: TerrainField
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
## Pennellate della faglia sul rilievo (XZ, y = 0), da un capo all'altro.
var fault_points: Array[Vector3] = []
var fault_center := Vector3.ZERO
## Metri cubi spostati dall'ultimo terremoto (cresta piu solco, in valore assoluto).
var volume_moved := 0.0
var _fault_side := Vector3.RIGHT
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
	return first_seconds > 0.0 and terrain_field != null


## Perpendicolare alla faglia (XZ): da che lato sta il solco.
func fault_side() -> Vector3:
	return _fault_side


func _fault_size() -> int:
	return fault_points.size()


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
		% [_fault_size(), fault_center.x, fault_center.z, next_at])
	quake_warned.emit(fault_direction(), warning_seconds)


## Una linea retta di `length_cells` celle, con un orientamento a caso, il cui centro sta
## fra `distance_min` e `distance_max` metri dal giocatore in una direzione a caso.
func _choose_fault() -> void:
	fault_points.clear()
	var origin := player.global_position if player != null else Vector3.ZERO
	var toward := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(distance_min, distance_max)
	fault_center = Vector3(origin.x + cos(toward) * distance, 0.0, origin.z + sin(toward) * distance)
	var along := rng.randf_range(0.0, TAU)
	var direction := Vector3(cos(along), 0.0, sin(along))
	_fault_side = Vector3(-direction.z, 0.0, direction.x)
	var half := length_cells * 0.5
	var limit := terrain_field.half_extents() - Vector2.ONE * CREST_RADIUS
	for i in length_cells:
		var p := fault_center + direction * FAULT_STEP * (i - half + 0.5)
		if absf(p.x) > limit.x or absf(p.z) > limit.y or terrain_field.is_protected(p):
			continue
		fault_points.append(p)


func _tick_warning(elapsed: float, delta: float) -> void:
	var left := next_at - elapsed
	if hud != null:
		hud.set_event_warning("TERREMOTO", fault_direction(), left, RunHud.QUAKE_COLOR)
	_dust_left -= delta
	if _dust_left <= 0.0 and _fault_size() > 0:
		_dust_left = DUST_INTERVAL
		for i in DUST_CELLS:
			var at := _fault_position(rng.randi_range(0, _fault_size() - 1))
			DebrisBurst.spawn(get_parent(), at + Vector3(0.0, 0.15, 0.0), DUST_COLOR, 3, 1.2, 0.08)
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
	volume_moved = 0.0
	if hud != null:
		hud.clear_event_warning()
	print("PROTOTYPE01_QUAKE_START cells=%d" % _fault_size())
	quake_started.emit(fault_center)


func _tick_shaking(delta: float) -> void:
	_front_progress += delta * cells_per_second
	while _front < _fault_size() and float(_front) < _front_progress:
		_shake_point(fault_points[_front])
		_front += 1
	if _front >= _fault_size():
		_finish()


## Posizione nel mondo (XZ) della pennellata o della cella [param index] della faglia.
func _fault_position(index: int) -> Vector3:
	var p := fault_points[index]
	return Vector3(p.x, terrain_field.height_at(p), p.z)


## Una pennellata della faglia sul rilievo: cresta nel punto, solco a fianco. Il punto
## del giocatore (colpito) e quelli di compagno e boss sono risparmiati; i rottamatori
## entro HIT_RADIUS sono travolti, quelli appena fuori (e giocatore e compagno sotto la
## cresta, audit R-02) vengono riappoggiati sulla nuova
## quota (un rialzo secco sotto un corpo lo incastrerebbe nel rilievo).
func _shake_point(p: Vector3) -> void:
	if terrain_field.is_protected(p):
		return
	var at := Vector3(p.x, terrain_field.height_at(p), p.z)
	if _near(player, at):
		player.take_damage(player_damage)
		player_hits += 1
		quake_hit.emit(&"player")
		print("PROTOTYPE01_QUAKE_HIT what=player")
		return
	if _near(companion, at):
		return
	if is_instance_valid(boss) and not boss.is_dead and _planar_distance(boss.global_position, at) < BOSS_SPARE_RADIUS:
		return
	if director != null:
		for enemy in director.enemies.duplicate():
			if enemy.is_dead or enemy == boss:
				continue
			if _planar_distance(enemy.global_position, at) < HIT_RADIUS:
				enemies_hit += 1
				enemy.take_damage(enemy.health)
				quake_hit.emit(&"enemy")
	# Giocatore e compagno appena fuori da HIT_RADIUS ma sotto la cresta (audit R-02):
	# altezza sul suolo prima, per riappoggiarli dopo come i nemici.
	var spared := _spared_offsets(p)
	volume_moved += absf(terrain_field.sculpt(p, CREST_RADIUS, CREST_HEIGHT))
	volume_moved += absf(terrain_field.sculpt(p + _fault_side * FAULT_STEP, FURROW_RADIUS, -FURROW_DEPTH))
	cells_raised += 1
	_lift_bodies(p, CREST_RADIUS)
	_restore_offsets(spared)
	DebrisBurst.spawn(get_parent(), Vector3(p.x, terrain_field.height_at(p) + 0.3, p.z), EARTH_COLOR, 10, 4.0, 0.18)
	quake_hit.emit(&"cell")
	if lamp_field != null and lamp_field.knock_down_near(at, 1.5) > 0:
		quake_hit.emit(&"lamp")


## Riappoggia sulla nuova quota i nemici vivi entro [param radius] dalla pennellata.
func _lift_bodies(p: Vector3, radius: float) -> void:
	if director == null:
		return
	for enemy in director.enemies:
		if enemy.is_dead or _planar_distance(enemy.global_position, p) > radius:
			continue
		var ground := terrain_field.height_at(enemy.global_position)
		enemy.global_position.y = maxf(enemy.global_position.y, ground + enemy.spawn_center_height())


## Giocatore e compagno entro CREST_RADIUS dalla pennellata [param p], con la loro
## altezza sul suolo attuale.
func _spared_offsets(p: Vector3) -> Dictionary:
	var offsets := {}
	for body: Node3D in [player, companion]:
		if body != null and _planar_distance(body.global_position, p) <= CREST_RADIUS:
			offsets[body] = body.global_position.y - terrain_field.height_at(body.global_position)
	return offsets


## Riporta ogni corpo alla stessa altezza sul suolo nuovo, se il suolo e salito.
func _restore_offsets(offsets: Dictionary) -> void:
	for body: Node3D in offsets:
		var target: float = terrain_field.height_at(body.global_position) + offsets[body]
		if target > body.global_position.y:
			body.global_position.y = target
			body.reset_physics_interpolation()


func _near(body: Node3D, at: Vector3) -> bool:
	if body == null:
		return false
	return _planar_distance(body.global_position, at) < HIT_RADIUS


static func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _finish() -> void:
	state = State.IDLE
	quakes += 1
	next_at += interval_seconds
	print("PROTOTYPE01_QUAKE_DONE n=%d raised=%d filled=%d enemies=%d player_hits=%d volume=%.1f"
		% [quakes, cells_raised, cells_filled, enemies_hit, player_hits, volume_moved])
	if flow_preview != null:
		flow_preview.show_now()
	quake_done.emit(quakes)
