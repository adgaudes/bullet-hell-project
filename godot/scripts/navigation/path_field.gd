class_name PathField
extends Node3D
## Campo di percorso verso il giocatore (D-038): griglia di celle da 1,2 m che
## copre l'area giocabile, costi di Dijkstra dal giocatore a ogni cella libera.
## Nemici e compagno seguono la cella vicina piu economica, quindi aggirano le
## mura e passano dai varchi. Le celle 1,2 m sono meta di una cella terreno
## (2,4 m) e allineate ai suoi bordi: una cella terreno Raised blocca esattamente
## 2x2 celle del campo. Gli ostacoli statici dell'arena sono letti una volta.

signal solved

const UNREACHABLE := INF
const DIAGONAL_COST := 1.41421356
## Offset dei vicini: prima i 4 ortogonali, poi le diagonali.
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

@export var target: Node3D
@export var grid: TerrainGrid
## Meta lato dell'area coperta, in metri (play_half_extent dell'arena).
@export var half_extent := 24.0
@export var cell_size := 1.2
## Ricalcolo al massimo con questa frequenza, anche se il bersaglio si muove.
@export var min_solve_interval := 0.15

var columns := 0
## Costo verso il bersaglio; UNREACHABLE per celle bloccate o isolate.
var costs := PackedFloat32Array()
var _static_blocked := PackedByteArray()
var _blocked := PackedByteArray()
## Cella terreno (indice x + y * larghezza) sotto ogni cella del campo, -1 se fuori griglia.
var _terrain_index := PackedInt32Array()
var _target_cell := Vector2i(-1, -1)
var _dirty := true
var _since_solve := 0.0
var _ready_done := false


func _ready() -> void:
	columns = int(round(half_extent * 2.0 / cell_size))
	var count := columns * columns
	costs.resize(count)
	costs.fill(UNREACHABLE)
	_static_blocked.resize(count)
	_blocked.resize(count)
	_terrain_index.resize(count)
	if grid != null:
		grid.cell_changed.connect(func(_cell: Vector2i, _state: TerrainState.CellState) -> void: _refresh_blocked())
		grid.rebuilt.connect(_refresh_terrain)
	# Gli ostacoli dell'arena entrano nello spazio fisico dopo un passo.
	await get_tree().physics_frame
	await get_tree().physics_frame
	scan_static_obstacles()
	_refresh_terrain()
	_ready_done = true
	solve()
	print("PROTOTYPE01_PATH_FIELD_READY cells=%d static_blocked=%d" % [count, _count(_static_blocked)])


func _physics_process(delta: float) -> void:
	if not _ready_done or target == null:
		return
	_since_solve += delta
	var cell := cell_of(target.global_position)
	if cell != _target_cell:
		_dirty = true
	if _dirty and _since_solve >= min_solve_interval:
		solve()


func is_ready() -> bool:
	return _ready_done


func cell_of(world: Vector3) -> Vector2i:
	return Vector2i(floori((world.x + half_extent) / cell_size), floori((world.z + half_extent) / cell_size))


func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(-half_extent + (cell.x + 0.5) * cell_size, 0.0, -half_extent + (cell.y + 0.5) * cell_size)


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < columns


func is_walkable(world: Vector3) -> bool:
	var cell := cell_of(world)
	return is_inside(cell) and _blocked[_index(cell)] == 0


func cost_at(world: Vector3) -> float:
	var cell := cell_of(world)
	return costs[_index(cell)] if is_inside(cell) else UNREACHABLE


## Centro della cella vicina che avvicina al bersaglio, o null se da qui il
## bersaglio non e raggiungibile (assedio: chi chiama punta dritto).
func next_waypoint(world: Vector3) -> Variant:
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


## Ostacoli statici dell'arena (maschera world_static), escluse le celle terreno
## che hanno uno stato dinamico.
func scan_static_obstacles() -> void:
	var space := get_world_3d().direct_space_state
	var shape := BoxShape3D.new()
	shape.size = Vector3(cell_size * 0.9, 1.0, cell_size * 0.9)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	for y in columns:
		for x in columns:
			var center := cell_center(Vector2i(x, y))
			query.transform = Transform3D(Basis(), center + Vector3(0.0, 0.8, 0.0))
			var blocked := 0
			for hit in space.intersect_shape(query, 8):
				var collider: Node = hit.collider
				if grid == null or collider.get_parent() != grid:
					blocked = 1
					break
			_static_blocked[y * columns + x] = blocked
	_dirty = true


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


func _refresh_blocked() -> void:
	for i in _blocked.size():
		var blocked := _static_blocked[i]
		var t := _terrain_index[i]
		if blocked == 0 and t >= 0:
			var terrain_cell := Vector2i(t % grid.state.width, t / grid.state.width)
			if grid.state.get_state(terrain_cell) == TerrainState.CellState.RAISED:
				blocked = 1
		_blocked[i] = blocked
	_dirty = true


## Dijkstra dal bersaglio con heap binario; diagonali solo se entrambi i lati sono liberi.
func solve() -> void:
	_since_solve = 0.0
	_dirty = false
	costs.fill(UNREACHABLE)
	if target == null:
		return
	_target_cell = cell_of(target.global_position)
	if not is_inside(_target_cell):
		return
	var heap_cost := PackedFloat32Array()
	var heap_index := PackedInt32Array()
	var start := _index(_target_cell)
	costs[start] = 0.0
	_heap_push(heap_cost, heap_index, 0.0, start)
	while not heap_index.is_empty():
		var current_cost := heap_cost[0]
		var current := heap_index[0]
		_heap_pop(heap_cost, heap_index)
		if current_cost > costs[current]:
			continue
		var cell := Vector2i(current % columns, current / columns)
		for i in NEIGHBORS.size():
			var offset := NEIGHBORS[i]
			var next := cell + offset
			if not is_inside(next):
				continue
			var ni := _index(next)
			if _blocked[ni] != 0:
				continue
			if i >= 4 and not _diagonal_open(cell, offset):
				continue
			var c := current_cost + (DIAGONAL_COST if i >= 4 else 1.0)
			if c < costs[ni]:
				costs[ni] = c
				_heap_push(heap_cost, heap_index, c, ni)
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


static func _heap_push(heap_cost: PackedFloat32Array, heap_index: PackedInt32Array, cost: float, index: int) -> void:
	heap_cost.append(cost)
	heap_index.append(index)
	var i := heap_cost.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if heap_cost[parent] <= heap_cost[i]:
			break
		_heap_swap(heap_cost, heap_index, i, parent)
		i = parent


static func _heap_pop(heap_cost: PackedFloat32Array, heap_index: PackedInt32Array) -> void:
	var last := heap_cost.size() - 1
	heap_cost[0] = heap_cost[last]
	heap_index[0] = heap_index[last]
	heap_cost.resize(last)
	heap_index.resize(last)
	var i := 0
	while true:
		var left := i * 2 + 1
		var right := left + 1
		var smallest := i
		if left < last and heap_cost[left] < heap_cost[smallest]:
			smallest = left
		if right < last and heap_cost[right] < heap_cost[smallest]:
			smallest = right
		if smallest == i:
			break
		_heap_swap(heap_cost, heap_index, i, smallest)
		i = smallest


static func _heap_swap(heap_cost: PackedFloat32Array, heap_index: PackedInt32Array, a: int, b: int) -> void:
	var c := heap_cost[a]
	heap_cost[a] = heap_cost[b]
	heap_cost[b] = c
	var n := heap_index[a]
	heap_index[a] = heap_index[b]
	heap_index[b] = n
