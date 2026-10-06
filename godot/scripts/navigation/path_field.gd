class_name PathField
extends Node3D
## Campo di percorso verso il giocatore (D-038): celle da 1,2 m con costi di
## Dijkstra dal giocatore a ogni cella libera. Nemici e compagno seguono la
## cella vicina piu economica, quindi aggirano le mura e passano dai varchi.
## Le celle 1,2 m sono meta di una cella terreno (2,4 m) e allineate ai suoi
## bordi: una cella terreno Raised blocca esattamente 2x2 celle del campo.
##
## Scala (D-039): il campo risolto e una **finestra** di `window_cells` per lato
## che segue il giocatore; il costo del Dijkstra non dipende dalla dimensione
## dell'arena. Gli ostacoli statici sono letti dallo spazio fisico **una volta
## per chunk** di 16x16 celle, la prima volta che la finestra li copre.
## Fuori dalla finestra `next_waypoint` restituisce null: chi e cosi lontano
## punta dritto, come nell'assedio.
##
## Coordinate: le API pubbliche (`cell_of`, `cell_center`, `is_inside`, `costs`)
## lavorano in celle **locali** alla finestra; `origin` e lo spigolo della
## finestra in celle mondo.

signal solved
## Emesso quando la finestra si sposta: le celle locali cambiano significato.
signal recentered(origin: Vector2i)

const UNREACHABLE := INF
const DIAGONAL_COST := 1.4
## Costi interi del Dijkstra a secchi; un giro di secchi copre un passo diagonale.
const ORTHO_COST := 10
const DIAG_COST := 14
const BUCKETS := 15
const CHUNK := 16
## Offset dei vicini: prima i 4 ortogonali, poi le diagonali.
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

@export var target: Node3D
@export var grid: TerrainGrid
## Meta lato dell'area giocabile, in metri (play_half_extent dell'arena).
@export var half_extent := 24.0
@export var cell_size := 1.2
## Lato della finestra risolta, in celle (64 = 76,8 m). 0 = tutta l'arena.
@export var window_cells := 64
## La finestra si ricentra quando il bersaglio si allontana di tante celle dal suo centro.
@export var recenter_margin_cells := 8
## Ricalcolo al massimo con questa frequenza, anche se il bersaglio si muove.
@export var min_solve_interval := 0.15

## Lato della finestra in celle.
var columns := 0
## Lato dell'intera arena in celle.
var world_columns := 0
## Spigolo della finestra in celle mondo.
var origin := Vector2i.ZERO
## Costo verso il bersaglio; UNREACHABLE per celle bloccate o isolate.
var costs := PackedFloat32Array()
## Statistiche per benchmark e test.
var chunks_scanned := 0
var recenter_count := 0
var last_solve_usec := 0
var last_recenter_usec := 0

var _static_blocked := PackedByteArray()
var _blocked := PackedByteArray()
## Cella terreno (indice x + y * larghezza) sotto ogni cella del campo, -1 se fuori griglia.
var _terrain_index := PackedInt32Array()
## Chunk -> PackedByteArray(CHUNK * CHUNK) di ostacoli statici.
var _static_chunks: Dictionary[Vector2i, PackedByteArray] = {}
var _target_cell := Vector2i(-1, -1)
var _dirty := true
## Celle terreno cambiate dall'ultimo aggiornamento degli ostacoli: si rilegge una
## volta sola, non a ogni cella (la disposizione iniziale dell'arena ne cambia centinaia).
var _terrain_dirty := false
var _since_solve := 0.0
var _ready_done := false


func _ready() -> void:
	world_columns = int(round(half_extent * 2.0 / cell_size))
	columns = world_columns if window_cells <= 0 else mini(window_cells, world_columns)
	var count := columns * columns
	costs.resize(count)
	costs.fill(UNREACHABLE)
	_static_blocked.resize(count)
	_blocked.resize(count)
	_terrain_index.resize(count)
	if grid != null:
		grid.cell_changed.connect(func(_cell: Vector2i, _state: TerrainState.CellState) -> void: _terrain_dirty = true)
		grid.rebuilt.connect(_refresh_terrain)
	# Gli ostacoli dell'arena entrano nello spazio fisico dopo un passo.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var center := Vector2i(world_columns / 2, world_columns / 2)
	origin = _origin_for(_world_cell_of(target.global_position) if target != null else center)
	_fill_window()
	_ready_done = true
	solve()
	print("PROTOTYPE01_PATH_FIELD_READY cells=%d world_cells=%d static_blocked=%d"
		% [count, world_columns * world_columns, _count(_static_blocked)])


func _physics_process(delta: float) -> void:
	if not _ready_done or target == null:
		return
	_flush_terrain()
	_since_solve += delta
	var world_cell := _world_cell_of(target.global_position)
	if _needs_recenter(world_cell):
		recenter(world_cell)
	var cell := world_cell - origin
	if cell != _target_cell:
		_dirty = true
	if _dirty and _since_solve >= min_solve_interval:
		solve()


func is_ready() -> bool:
	return _ready_done


## Cella locale alla finestra (puo essere fuori: vedi is_inside).
func cell_of(world: Vector3) -> Vector2i:
	return _world_cell_of(world) - origin


func cell_center(cell: Vector2i) -> Vector3:
	var wc := cell + origin
	return Vector3(-half_extent + (wc.x + 0.5) * cell_size, 0.0, -half_extent + (wc.y + 0.5) * cell_size)


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < columns


## True se il punto e dentro l'arena, fuori dagli ostacoli statici e non
## sotto una cella Raised. Fuori dalla finestra legge chunk e griglia direttamente.
func is_walkable(world: Vector3) -> bool:
	_flush_terrain()
	var cell := cell_of(world)
	if is_inside(cell):
		return _blocked[_index(cell)] == 0
	var wc := cell + origin
	if not _world_inside(wc):
		return false
	if _static_at(wc) != 0:
		return false
	return grid == null or grid.cell_state_at(world) != TerrainState.CellState.RAISED


func cost_at(world: Vector3) -> float:
	_flush_terrain()
	var cell := cell_of(world)
	return costs[_index(cell)] if is_inside(cell) else UNREACHABLE


## Centro della cella vicina che avvicina al bersaglio, o null se da qui il
## bersaglio non e raggiungibile o il punto e fuori finestra (chi chiama punta dritto).
func next_waypoint(world: Vector3) -> Variant:
	_flush_terrain()
	var cell := cell_of(world)
	if not is_inside(cell):
		return null
	var best_cost := costs[_index(cell)]
	var best := Vector2i(-1, -1)
	for i in NEIGHBORS.size():
		var offset := NEIGHBORS[i]
		var next := cell + offset
		if not is_inside(next) or _blocked[_index(next)] != 0:
			continue
		if i >= 4 and not _diagonal_open(cell, offset):
			continue
		var c := costs[_index(next)]
		if c < best_cost:
			best_cost = c
			best = next
	if best.x < 0:
		return null
	return cell_center(best)


## Sposta la finestra attorno a [param world_cell] e la riempie dalla cache dei chunk.
func recenter(world_cell: Vector2i) -> void:
	var start := Time.get_ticks_usec()
	origin = _origin_for(world_cell)
	_fill_window()
	recenter_count += 1
	last_recenter_usec = Time.get_ticks_usec() - start
	recentered.emit(origin)


## Dimentica gli ostacoli statici letti finora e rilegge quelli della finestra
## (ostacoli dell'arena cambiati).
func scan_static_obstacles() -> void:
	_static_chunks.clear()
	_fill_window()


func _needs_recenter(world_cell: Vector2i) -> bool:
	if columns >= world_columns:
		return false
	var center := origin + Vector2i(columns / 2, columns / 2)
	var d := world_cell - center
	return maxi(absi(d.x), absi(d.y)) > recenter_margin_cells and origin != _origin_for(world_cell)


func _origin_for(world_cell: Vector2i) -> Vector2i:
	var limit := world_columns - columns
	return Vector2i(clampi(world_cell.x - columns / 2, 0, limit), clampi(world_cell.y - columns / 2, 0, limit))


func _world_cell_of(world: Vector3) -> Vector2i:
	return Vector2i(floori((world.x + half_extent) / cell_size), floori((world.z + half_extent) / cell_size))


func _world_inside(wc: Vector2i) -> bool:
	return wc.x >= 0 and wc.y >= 0 and wc.x < world_columns and wc.y < world_columns


func _fill_window() -> void:
	for y in columns:
		for x in columns:
			_static_blocked[y * columns + x] = _static_at(origin + Vector2i(x, y))
	_refresh_terrain()


## Ostacolo statico in una cella mondo, dal chunk in cache o letto ora.
func _static_at(wc: Vector2i) -> int:
	var chunk := Vector2i(wc.x / CHUNK, wc.y / CHUNK)
	var data: PackedByteArray = _static_chunks.get(chunk, PackedByteArray())
	if data.is_empty():
		data = _scan_chunk(chunk)
		_static_chunks[chunk] = data
	return data[(wc.y % CHUNK) * CHUNK + wc.x % CHUNK]


## Legge dallo spazio fisico (maschera world_static) gli ostacoli di un chunk,
## escluse le celle terreno che hanno uno stato dinamico.
func _scan_chunk(chunk: Vector2i) -> PackedByteArray:
	chunks_scanned += 1
	var data := PackedByteArray()
	data.resize(CHUNK * CHUNK)
	var space := get_world_3d().direct_space_state
	var shape := BoxShape3D.new()
	shape.size = Vector3(cell_size * 0.9, 1.0, cell_size * 0.9)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	for y in CHUNK:
		for x in CHUNK:
			var wc := chunk * CHUNK + Vector2i(x, y)
			var blocked := 0
			if not _world_inside(wc):
				blocked = 1
			else:
				var center := Vector3(-half_extent + (wc.x + 0.5) * cell_size, 0.8, -half_extent + (wc.y + 0.5) * cell_size)
				query.transform = Transform3D(Basis(), center)
				for hit in space.intersect_shape(query, 8):
					var collider: Node = hit.collider
					if grid == null or collider.get_parent() != grid:
						blocked = 1
						break
			data[y * CHUNK + x] = blocked
	return data


func _refresh_terrain() -> void:
	if columns == 0:
		return
	for y in columns:
		for x in columns:
			var i := y * columns + x
			_terrain_index[i] = -1
			if grid == null:
				continue
			var terrain_cell := grid.cell_at(cell_center(Vector2i(x, y)))
			if grid.state.is_valid(terrain_cell):
				_terrain_index[i] = terrain_cell.y * grid.state.width + terrain_cell.x
	_refresh_blocked()


func _flush_terrain() -> void:
	if _terrain_dirty:
		_refresh_blocked()


func _refresh_blocked() -> void:
	_terrain_dirty = false
	for i in _blocked.size():
		var blocked := _static_blocked[i]
		var t := _terrain_index[i]
		if blocked == 0 and t >= 0:
			var terrain_cell := Vector2i(t % grid.state.width, t / grid.state.width)
			if grid.state.get_state(terrain_cell) == TerrainState.CellState.RAISED:
				blocked = 1
		_blocked[i] = blocked
	_dirty = true


## Dijkstra dal bersaglio con code a secchi (costi interi: 10 ortogonale,
## 14 diagonale) e indici inline: in GDScript e circa 4 volte piu veloce
## dell'heap binario. Diagonali solo se entrambi i lati sono liberi.
func solve() -> void:
	var start_usec := Time.get_ticks_usec()
	_flush_terrain()
	_since_solve = 0.0
	_dirty = false
	costs.fill(UNREACHABLE)
	if target == null:
		return
	var world_cell := _world_cell_of(target.global_position)
	if _ready_done and not is_inside(world_cell - origin) and _world_inside(world_cell):
		recenter(world_cell)
	_target_cell = world_cell - origin
	if not is_inside(_target_cell):
		return
	var n := columns
	var count := n * n
	var dist := PackedInt32Array()
	dist.resize(count)
	dist.fill(0x7fffffff)
	var blocked := _blocked
	var buckets: Array[PackedInt32Array] = []
	buckets.resize(BUCKETS)
	for b in BUCKETS:
		buckets[b] = PackedInt32Array()
	var start := _target_cell.y * n + _target_cell.x
	dist[start] = 0
	buckets[0].append(start)
	var pending := 1
	var level := 0
	while pending > 0:
		var bucket := buckets[level % BUCKETS]
		if bucket.is_empty():
			level += 1
			continue
		buckets[level % BUCKETS] = PackedInt32Array()
		for current in bucket:
			pending -= 1
			if dist[current] != level:
				continue
			var x := current % n
			var y := current / n
			var left := x > 0 and blocked[current - 1] == 0
			var right := x < n - 1 and blocked[current + 1] == 0
			var up := y > 0 and blocked[current - n] == 0
			var down := y < n - 1 and blocked[current + n] == 0
			var c := level + ORTHO_COST
			if left and dist[current - 1] > c:
				dist[current - 1] = c
				buckets[c % BUCKETS].append(current - 1)
				pending += 1
			if right and dist[current + 1] > c:
				dist[current + 1] = c
				buckets[c % BUCKETS].append(current + 1)
				pending += 1
			if up and dist[current - n] > c:
				dist[current - n] = c
				buckets[c % BUCKETS].append(current - n)
				pending += 1
			if down and dist[current + n] > c:
				dist[current + n] = c
				buckets[c % BUCKETS].append(current + n)
				pending += 1
			c = level + DIAG_COST
			if left and up and blocked[current - n - 1] == 0 and dist[current - n - 1] > c:
				dist[current - n - 1] = c
				buckets[c % BUCKETS].append(current - n - 1)
				pending += 1
			if right and up and blocked[current - n + 1] == 0 and dist[current - n + 1] > c:
				dist[current - n + 1] = c
				buckets[c % BUCKETS].append(current - n + 1)
				pending += 1
			if left and down and blocked[current + n - 1] == 0 and dist[current + n - 1] > c:
				dist[current + n - 1] = c
				buckets[c % BUCKETS].append(current + n - 1)
				pending += 1
			if right and down and blocked[current + n + 1] == 0 and dist[current + n + 1] > c:
				dist[current + n + 1] = c
				buckets[c % BUCKETS].append(current + n + 1)
				pending += 1
	for i in count:
		var d := dist[i]
		if d != 0x7fffffff:
			costs[i] = d * 0.1
	last_solve_usec = Time.get_ticks_usec() - start_usec
	solved.emit()


func _diagonal_open(cell: Vector2i, offset: Vector2i) -> bool:
	var a := cell + Vector2i(offset.x, 0)
	var b := cell + Vector2i(0, offset.y)
	return is_inside(a) and is_inside(b) and _blocked[_index(a)] == 0 and _blocked[_index(b)] == 0


func _index(cell: Vector2i) -> int:
	return cell.y * columns + cell.x


static func _count(values: PackedByteArray) -> int:
	var total := 0
	for v in values:
		total += v
	return total
