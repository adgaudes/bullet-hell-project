class_name HeightFlowField
extends RefCounted
## SPIKE: campo di percorso sul terreno a rilievo continuo. Griglia grossa (CELL metri)
## di quote campionate da HeightTerrain; una visita in ampiezza dal bersaglio dice a
## ogni casella verso quale vicina andare. Un passaggio e ammesso se la salita non
## supera `max_grade`; in discesa si passa sempre, quindi in una fossa ripida si entra
## ma non si esce. Codice di prova: non e usato dal livello vero.

## Lato di una casella del campo, in metri.
const CELL := 1.5
## Prima i quattro lati, poi le diagonali: a parita di passi si preferisce andare dritti.
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var side := 0
## Per casella: indice della casella successiva verso il bersaglio, -1 se non ci si arriva.
var next := PackedInt32Array()
## Per casella: passi fino al bersaglio, -1 se non ci si arriva.
var steps := PackedInt32Array()

var _half := 0.0
var _heights := PackedFloat32Array()


## Ricalcola il campo verso [param goal]. [param max_grade]: salita massima (m per m).
func rebuild(terrain: HeightTerrain, goal: Vector3, max_grade: float) -> void:
	_half = terrain.half_extent()
	side = int(ceil(_half * 2.0 / CELL))
	var count := side * side
	_heights.resize(count)
	for z in side:
		for x in side:
			_heights[z * side + x] = terrain.height_at(center_of(z * side + x))
	next.resize(count)
	next.fill(-1)
	steps.resize(count)
	steps.fill(-1)

	var start := cell_of(goal)
	steps[start] = 0
	next[start] = start
	var queue := PackedInt32Array([start])
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		var cx := current % side
		var cz := current / side
		for offset in NEIGHBORS:
			var nx := cx + offset.x
			var nz := cz + offset.y
			if nx < 0 or nz < 0 or nx >= side or nz >= side:
				continue
			var neighbor := nz * side + nx
			if steps[neighbor] >= 0:
				continue
			# Si cammina dalla vicina verso `current`: conta la salita in quel verso.
			var run := CELL * (1.41421356 if offset.x != 0 and offset.y != 0 else 1.0)
			if _heights[current] - _heights[neighbor] > max_grade * run:
				continue
			steps[neighbor] = steps[current] + 1
			next[neighbor] = current
			queue.append(neighbor)


func cell_of(point: Vector3) -> int:
	var x := clampi(int((point.x + _half) / CELL), 0, side - 1)
	var z := clampi(int((point.z + _half) / CELL), 0, side - 1)
	return z * side + x


func center_of(cell: int) -> Vector3:
	return Vector3((cell % side + 0.5) * CELL - _half, 0.0, (cell / side + 0.5) * CELL - _half)


## Direzione in piano (unitaria) da seguire da [param point]; zero se da li non si arriva.
func direction_at(point: Vector3) -> Vector3:
	var cell := cell_of(point)
	if next[cell] < 0:
		return Vector3.ZERO
	var toward := center_of(next[cell]) - point
	toward.y = 0.0
	return toward.normalized() if toward.length_squared() > 0.0001 else Vector3.ZERO
