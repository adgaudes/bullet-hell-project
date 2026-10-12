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
## Terreno continuo (D-082): se presente, la calpestabilita viene dalla pendenza e non dalla griglia.
@export var terrain_field: TerrainField
## Pendenza massima percorribile (m/m) con `terrain_field`.
@export var max_grade := 0.8
## Meta lato dell'area giocabile lungo X, in metri (play_half_extent dell'arena).
@export var half_extent := 24.0
## Meta lato lungo Z; 0 = quadrato (arena rettangolare: D-066).
@export var half_extent_z := 0.0
@export var cell_size := 1.2
## Lato della finestra risolta, in celle (64 = 76,8 m). 0 = tutta l'arena.
@export var window_cells := 64
## La finestra si ricentra quando il bersaglio si allontana di tante celle dal suo centro.
@export var recenter_margin_cells := 8
## Ricalcolo al massimo con questa frequenza, anche se il bersaglio si muove.
@export var min_solve_interval := 0.15

## Lato della finestra in celle.
var columns := 0
## Lati dell'intera arena in celle (X e Z).
var world_columns := 0
var world_rows := 0
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
## Con `terrain_field`: celle troppo ripide (1) e, per cella, i passi consentiti verso le vicine,
## un bit per direzione nell'ordine di NEIGHBORS (0 +x, 1 -x, 2 +z, 3 -z, 4..7 diagonali).
## Senza terreno continuo la maschera resta a 255 e non pesa sul Dijkstra.
var _slope_blocked := PackedByteArray()
var _step_mask := PackedByteArray()
## Area XZ (mondo) cambiata dall'ultimo ricalcolo di pendenze; `_slopes_all` = da rifare tutte.
var _dirty_rect := Rect2()
var _has_dirty_rect := false
var _slopes_all := true
## Cella terreno (indice x + y * larghezza) sotto ogni cella del campo, -1 se fuori griglia.
var _terrain_index := PackedInt32Array()
## Chunk -> PackedByteArray(CHUNK * CHUNK) di ostacoli statici.
var _static_chunks: Dictionary[Vector2i, PackedByteArray] = {}
## Per chunk: indice della cella terreno sotto ogni cella del campo (-1 se fuori griglia),
## letto da `grid.cell_at` una volta sola: il ricentro non lo ricalcola (E-02).
var _terrain_chunks: Dictionary[Vector2i, PackedInt32Array] = {}
## Per cella: indice della vicina verso il bersaglio (-1 nessuna), NEXT_UNKNOWN se non
## ancora calcolato dall'ultima soluzione (E-03): `next_waypoint` lo legge invece di
## scandire gli otto vicini a ogni passo di ogni nemico.
const NEXT_UNKNOWN := -2
var _next := PackedInt32Array()
var _target_cell := Vector2i(-1, -1)
var _dirty := true
## Celle terreno cambiate dall'ultimo aggiornamento degli ostacoli: si rilegge una
## volta sola, non a ogni cella (la disposizione iniziale dell'arena ne cambia centinaia).
var _terrain_dirty := false
var _since_solve := 0.0
var _ready_done := false


func _ready() -> void:
	world_columns = int(round(half_extent * 2.0 / cell_size))
	world_rows = int(round(half_z() * 2.0 / cell_size))
	columns = maxi(world_columns, world_rows) if window_cells <= 0 else mini(window_cells, mini(world_columns, world_rows))
	var count := columns * columns
	costs.resize(count)
	costs.fill(UNREACHABLE)
	_static_blocked.resize(count)
	_blocked.resize(count)
	_slope_blocked.resize(count)
	_step_mask.resize(count)
	_step_mask.fill(255)
	_terrain_index.resize(count)
	_terrain_index.fill(-1)
	_next.resize(count)
	_next.fill(NEXT_UNKNOWN)
	if grid != null:
		grid.cell_changed.connect(func(_cell: Vector2i, _state: TerrainState.CellState) -> void: _terrain_dirty = true)
		grid.rebuilt.connect(_on_grid_rebuilt)
	if terrain_field != null:
		terrain_field.region_changed.connect(_on_terrain_region_changed)
	# Gli ostacoli dell'arena entrano nello spazio fisico dopo un passo.
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	if not is_inside_tree() or (target != null and not is_instance_valid(target)):
		return
	var center := Vector2i(world_columns / 2, world_rows / 2)
	origin = _origin_for(_world_cell_of(target.global_position) if target != null else center)
	_fill_window()
	_ready_done = true
	solve()
	print("PROTOTYPE01_PATH_FIELD_READY cells=%d world_cells=%d static_blocked=%d"
		% [count, world_columns * world_rows, _count(_static_blocked)])


## Meta lato lungo Z (uguale a X se `half_extent_z` e 0).
func half_z() -> float:
	return half_extent_z if half_extent_z > 0.0 else half_extent


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
	return Vector3(-half_extent + (wc.x + 0.5) * cell_size, 0.0, -half_z() + (wc.y + 0.5) * cell_size)


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < columns


## True se il punto e dentro l'arena, fuori dagli ostacoli statici e non
## sotto una cella Raised. Fuori dalla finestra legge chunk e griglia direttamente.
func is_walkable(world: Vector3) -> bool:
	_flush_terrain()
	var cell := cell_of(world)
	if is_inside(cell):
		if _blocked[_index(cell)] != 0:
			return false
		# Le celle da 1,2 m campionano la pendenza al centro: il punto esatto la rilegge.
		return terrain_field == null or terrain_field.slope_at(world) <= max_grade
	var wc := cell + origin
	if not _world_inside(wc):
		return false
	if _static_at(wc) != 0:
		return false
	if terrain_field != null:
		return terrain_field.slope_at(world) <= max_grade
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
	var index := _index(cell)
	var cached := _next[index]
	if cached == NEXT_UNKNOWN:
		cached = _best_neighbor(cell)
		_next[index] = cached
	if cached < 0:
		return null
	return cell_center(Vector2i(cached % columns, cached / columns))


# Indice della vicina con costo minore (-1 se nessuna avvicina): calcolato una volta per
# cella e per soluzione.
func _best_neighbor(cell: Vector2i) -> int:
	var best_cost := costs[_index(cell)]
	var best := -1
	for i in NEIGHBORS.size():
		var offset := NEIGHBORS[i]
		var next := cell + offset
		if not is_inside(next) or _blocked[_index(next)] != 0:
			continue
		if i >= 4 and not _diagonal_open(cell, offset):
			continue
		if not is_reachable_from(cell, next):
			continue
		var c := costs[_index(next)]
		if c < best_cost:
			best_cost = c
			best = _index(next)
	return best


## True se un nemico in [param cell] puo passare alla vicina [param neighbor]
## (celle locali): con `terrain_field` lo decide `can_step`, altrimenti e sempre vero.
func is_reachable_from(cell: Vector2i, neighbor: Vector2i) -> bool:
	if terrain_field == null:
		return true
	var offset := neighbor - cell
	var k := NEIGHBORS.find(offset)
	if k >= 0 and is_inside(cell) and is_inside(neighbor):
		return (_step_mask[_index(cell)] >> k) & 1 != 0
	return terrain_field.can_step(cell_center(cell), cell_center(neighbor), max_grade)


## Centro mondo della cella a indice locale [param index] (stessa formula di `cell_center`).
func _cell_world(index: int) -> Vector3:
	var cell := Vector2i(index % columns, index / columns)
	return Vector3(-half_extent + (cell.x + origin.x + 0.5) * cell_size, 0.0, -half_z() + (cell.y + origin.y + 0.5) * cell_size)


## Sposta la finestra attorno a [param world_cell] e la riempie dalla cache dei chunk.
func recenter(world_cell: Vector2i) -> void:
	var start := Time.get_ticks_usec()
	origin = _origin_for(world_cell)
	_fill_window()
	# I costi erano nelle coordinate della vecchia finestra: via subito, e il prossimo
	# passo fisico risolve senza aspettare `min_solve_interval`.
	costs.fill(UNREACHABLE)
	_dirty = true
	_since_solve = min_solve_interval
	recenter_count += 1
	last_recenter_usec = Time.get_ticks_usec() - start
	recentered.emit(origin)


## Dimentica gli ostacoli statici letti finora e rilegge quelli della finestra
## (ostacoli dell'arena cambiati).
func scan_static_obstacles() -> void:
	_static_chunks.clear()
	_fill_window()


func _on_terrain_region_changed(aabb: AABB) -> void:
	_terrain_dirty = true
	var rect := Rect2(aabb.position.x, aabb.position.z, aabb.size.x, aabb.size.z)
	_dirty_rect = _dirty_rect.merge(rect) if _has_dirty_rect else rect
	_has_dirty_rect = true


func _on_grid_rebuilt() -> void:
	_terrain_chunks.clear()
	_refresh_terrain()


func _needs_recenter(world_cell: Vector2i) -> bool:
	if columns >= world_columns and columns >= world_rows:
		return false
	var center := origin + Vector2i(columns / 2, columns / 2)
	var d := world_cell - center
	return maxi(absi(d.x), absi(d.y)) > recenter_margin_cells and origin != _origin_for(world_cell)


func _origin_for(world_cell: Vector2i) -> Vector2i:
	var limit := maxi(world_columns - columns, 0)
	var limit_z := maxi(world_rows - columns, 0)
	return Vector2i(clampi(world_cell.x - columns / 2, 0, limit), clampi(world_cell.y - columns / 2, 0, limit_z))


func _world_cell_of(world: Vector3) -> Vector2i:
	return Vector2i(floori((world.x + half_extent) / cell_size), floori((world.z + half_z()) / cell_size))


func _world_inside(wc: Vector2i) -> bool:
	return wc.x >= 0 and wc.y >= 0 and wc.x < world_columns and wc.y < world_rows


func _fill_window() -> void:
	_slopes_all = true
	# Chunk per chunk: una sola lettura della cache (gli array impacchettati si copiano
	# per valore: 4096 letture singole costavano quanto la soluzione intera).
	var first_chunk := Vector2i(origin.x / CHUNK, origin.y / CHUNK)
	var last_chunk := Vector2i((origin.x + columns - 1) / CHUNK, (origin.y + columns - 1) / CHUNK)
	for cy in range(first_chunk.y, last_chunk.y + 1):
		for cx in range(first_chunk.x, last_chunk.x + 1):
			var chunk := Vector2i(cx, cy)
			var data: PackedByteArray = _static_chunks.get(chunk, PackedByteArray())
			if data.is_empty():
				data = _scan_chunk(chunk)
				_static_chunks[chunk] = data
			var terrain: PackedInt32Array = _terrain_chunks.get(chunk, PackedInt32Array())
			if terrain.is_empty():
				terrain = _scan_terrain_chunk(chunk)
				_terrain_chunks[chunk] = terrain
			var x0 := maxi(cx * CHUNK, origin.x)
			var x1 := mini(cx * CHUNK + CHUNK, origin.x + columns)
			var y0 := maxi(cy * CHUNK, origin.y)
			var y1 := mini(cy * CHUNK + CHUNK, origin.y + columns)
			for wy in range(y0, y1):
				var row := (wy - origin.y) * columns - origin.x
				var chunk_row := (wy % CHUNK) * CHUNK - cx * CHUNK
				for wx in range(x0, x1):
					_static_blocked[row + wx] = data[chunk_row + wx]
					_terrain_index[row + wx] = terrain[chunk_row + wx]
	_refresh_blocked()


func _scan_terrain_chunk(chunk: Vector2i) -> PackedInt32Array:
	var data := PackedInt32Array()
	data.resize(CHUNK * CHUNK)
	data.fill(-1)
	if grid == null:
		return data
	for y in CHUNK:
		for x in CHUNK:
			var wc := chunk * CHUNK + Vector2i(x, y)
			if not _world_inside(wc):
				continue
			var center := Vector3(-half_extent + (wc.x + 0.5) * cell_size, 0.0, -half_z() + (wc.y + 0.5) * cell_size)
			var terrain_cell := grid.cell_at(center)
			if grid.state.is_valid(terrain_cell):
				data[y * CHUNK + x] = terrain_cell.y * grid.state.width + terrain_cell.x
	return data


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
				var center := Vector3(-half_extent + (wc.x + 0.5) * cell_size, 0.8, -half_z() + (wc.y + 0.5) * cell_size)
				query.transform = Transform3D(Basis(), center)
				for hit in space.intersect_shape(query, 8):
					var collider: Node = hit.collider
					if (grid == null or collider.get_parent() != grid) and (terrain_field == null or collider != terrain_field.get_node(^"Collision").body):
						blocked = 1
						break
			data[y * CHUNK + x] = blocked
	return data


func _refresh_terrain() -> void:
	if columns == 0:
		return
	_fill_window()


func _flush_terrain() -> void:
	if _terrain_dirty:
		_refresh_blocked()


func _refresh_blocked() -> void:
	_terrain_dirty = false
	if terrain_field != null:
		_refresh_slopes()
	_next.fill(NEXT_UNKNOWN)
	for i in _blocked.size():
		var blocked := _static_blocked[i]
		var t := _terrain_index[i]
		if blocked == 0 and _slope_blocked[i] != 0:
			blocked = 1
		if blocked == 0 and t >= 0 and grid != null:
			var terrain_cell := Vector2i(t % grid.state.width, t / grid.state.width)
			if grid.state.get_state(terrain_cell) == TerrainState.CellState.RAISED:
				blocked = 1
		_blocked[i] = blocked
	_dirty = true


## Ricalcola pendenza e passi solo per le celle toccate dall'area cambiata (piu un
## anello: la pendenza e i passi guardano le vicine); tutte dopo un ricentro.
func _refresh_slopes() -> void:
	var rect := _dirty_rect
	var all := _slopes_all
	var any := _has_dirty_rect
	_slopes_all = false
	_has_dirty_rect = false
	if columns == 0 or not (all or any):
		return
	var lo := Vector2i.ZERO
	var hi := Vector2i(columns - 1, columns - 1)
	if not all:
		lo = _world_cell_of(Vector3(rect.position.x, 0.0, rect.position.y)) - origin
		hi = _world_cell_of(Vector3(rect.end.x, 0.0, rect.end.y)) - origin
	var r1_lo := Vector2i(maxi(lo.x - 1, 0), maxi(lo.y - 1, 0))
	var r1_hi := Vector2i(mini(hi.x + 1, columns - 1), mini(hi.y + 1, columns - 1))
	for y in range(r1_lo.y, r1_hi.y + 1):
		for x in range(r1_lo.x, r1_hi.x + 1):
			var i := y * columns + x
			var here := _cell_world(i)
			_slope_blocked[i] = 1 if terrain_field.slope_at(here) > max_grade else 0
			var m := 0
			for k in 4:
				var nx := x + NEIGHBORS[k].x
				var ny := y + NEIGHBORS[k].y
				if nx >= 0 and ny >= 0 and nx < columns and ny < columns 						and terrain_field.can_step(here, _cell_world(ny * columns + nx), max_grade):
					m |= 1 << k
			_step_mask[i] = m
	# Diagonali dalle gambe ortogonali (in entrambi gli ordini); anello piu largo di uno.
	var r2_lo := Vector2i(maxi(lo.x - 2, 0), maxi(lo.y - 2, 0))
	var r2_hi := Vector2i(mini(hi.x + 2, columns - 1), mini(hi.y + 2, columns - 1))
	for y in range(r2_lo.y, r2_hi.y + 1):
		for x in range(r2_lo.x, r2_hi.x + 1):
			var i := y * columns + x
			var m := _step_mask[i] & 15
			for k in range(4, 8):
				var dx := NEIGHBORS[k].x
				var dy := NEIGHBORS[k].y
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= columns or ny >= columns:
					continue
				var bit_x := 0 if dx > 0 else 1
				var bit_y := 2 if dy > 0 else 3
				var via_x := (m >> bit_x) & 1 != 0 and (_step_mask[y * columns + nx] >> bit_y) & 1 != 0
				var via_y := (m >> bit_y) & 1 != 0 and (_step_mask[ny * columns + x] >> bit_x) & 1 != 0
				if via_x or via_y:
					m |= 1 << k
			_step_mask[i] = m


## Dijkstra dal bersaglio con code a secchi (costi interi: 10 ortogonale,
## 14 diagonale) e indici inline: in GDScript e circa 4 volte piu veloce
## dell'heap binario. Diagonali solo se entrambi i lati sono liberi.
func solve() -> void:
	var start_usec := Time.get_ticks_usec()
	_flush_terrain()
	costs.fill(UNREACHABLE)
	_next.fill(NEXT_UNKNOWN)
	if target == null:
		_since_solve = 0.0
		_dirty = false
		return
	var world_cell := _world_cell_of(target.global_position)
	if _ready_done and not is_inside(world_cell - origin) and _world_inside(world_cell):
		recenter(world_cell)
	# Dopo il ricentro (che li rimette a "da risolvere"): questa soluzione li chiude.
	_since_solve = 0.0
	_dirty = false
	_target_cell = world_cell - origin
	if not is_inside(_target_cell):
		return
	var n := columns
	var count := n * n
	var dist := PackedInt32Array()
	dist.resize(count)
	dist.fill(0x7fffffff)
	var blocked := _blocked
	var steps := _step_mask
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
			if left and steps[current - 1] & 1 != 0 and dist[current - 1] > c:
				dist[current - 1] = c
				buckets[c % BUCKETS].append(current - 1)
				pending += 1
			if right and steps[current + 1] & 2 != 0 and dist[current + 1] > c:
				dist[current + 1] = c
				buckets[c % BUCKETS].append(current + 1)
				pending += 1
			if up and steps[current - n] & 4 != 0 and dist[current - n] > c:
				dist[current - n] = c
				buckets[c % BUCKETS].append(current - n)
				pending += 1
			if down and steps[current + n] & 8 != 0 and dist[current + n] > c:
				dist[current + n] = c
				buckets[c % BUCKETS].append(current + n)
				pending += 1
			c = level + DIAG_COST
			if left and up and blocked[current - n - 1] == 0 and steps[current - n - 1] & 16 != 0 and dist[current - n - 1] > c:
				dist[current - n - 1] = c
				buckets[c % BUCKETS].append(current - n - 1)
				pending += 1
			if right and up and blocked[current - n + 1] == 0 and steps[current - n + 1] & 64 != 0 and dist[current - n + 1] > c:
				dist[current - n + 1] = c
				buckets[c % BUCKETS].append(current - n + 1)
				pending += 1
			if left and down and blocked[current + n - 1] == 0 and steps[current + n - 1] & 32 != 0 and dist[current + n - 1] > c:
				dist[current + n - 1] = c
				buckets[c % BUCKETS].append(current + n - 1)
				pending += 1
			if right and down and blocked[current + n + 1] == 0 and steps[current + n + 1] & 128 != 0 and dist[current + n + 1] > c:
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
