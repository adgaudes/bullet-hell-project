class_name TerrainWriteQueue
extends Node
## Coda delle scritture delle armi sul terreno (spec D-092, par. 8-9): al piu WRITES_PER_STEP
## pennellate per passo fisico, raggio limitato, punti protetti o fuori campo scartati. Un anello
## del picchetto sale cosi un disco alla volta: si vede crescere e non pesa su un solo frame.

const WRITES_PER_STEP := 1
const MAX_RADIUS := 2.5

var terrain_field: TerrainField
var _jobs: Array[Dictionary] = []


func _ready() -> void:
	process_physics_priority = -10


## Porta il disco verso [param target] (TerrainField.level), quando tocca a lui.
func push_level(center: Vector3, radius: float, target: float, strength := 1.0) -> void:
	if terrain_field == null or terrain_field.is_protected(center):
		return
	var half := terrain_field.half_extents()
	if absf(center.x) > half.x or absf(center.z) > half.y:
		return
	_jobs.append({center = center, radius = minf(radius, MAX_RADIUS), target = target, strength = strength})


func pending() -> int:
	return _jobs.size()


func clear() -> void:
	_jobs.clear()


func _physics_process(_delta: float) -> void:
	if _jobs.is_empty() or terrain_field == null:
		return
	terrain_field.begin_batch()
	for i in mini(WRITES_PER_STEP, _jobs.size()):
		var job: Dictionary = _jobs.pop_front()
		terrain_field.level(job.center, job.radius, job.target, job.strength)
	terrain_field.end_batch()
