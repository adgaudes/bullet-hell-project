class_name TerrainHazard
extends Node3D
## Minaccia dummy graybox: porta di APrototype01TerrainHazardActor.
##
## Attraversa a velocita costante una corsia rettilinea lungo l'asse X Unreal
## della griglia, oltre entrambi i bordi. Lo sweep collide solo con il mondo
## statico (arena e celle Raised), mai con il personaggio, che non viene spinto.
## Fermata da una cella Raised o arrivata in fondo, sparisce e riparte
## dall'inizio dopo restart_delay, riusando lo stesso nodo.

signal blocked
signal reached

## Magenta acceso, lineare: distinto da personaggio e terreno.
const HAZARD_COLOR := Color(0.95, 0.05, 0.85)
const WORLD_STATIC_LAYER := 1

@export var tuning: HazardTuning
@export var terrain_grid: TerrainGrid

var lane_start := Vector3.ZERO
var lane_direction := Vector3.FORWARD
var lane_length := 10.0
var traveled_distance := 0.0
var is_resting := false

var _rest_left := 0.0
var _shape := SphereShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()
var _mesh: MeshInstance3D


func _ready() -> void:
	if tuning == null:
		tuning = HazardTuning.new()
	var radius := UnrealSpace.length(tuning.radius_cm)
	_shape.radius = radius
	_query.shape = _shape
	_query.collision_mask = WORLD_STATIC_LAYER

	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = HAZARD_COLOR.linear_to_srgb()
	_mesh = MeshInstance3D.new()
	_mesh.name = "Mesh"
	_mesh.mesh = sphere
	_mesh.material_override = material
	add_child(_mesh)

	if terrain_grid != null:
		configure_lane_from_grid(terrain_grid)
		terrain_grid.rebuilt.connect(configure_lane_from_grid.bind(terrain_grid))
	print("PROTOTYPE01_TERRAIN_SLICE_B_READY")


## Corsia fissa lungo l'asse X Unreal della griglia, centrata sulla sua origine.
func configure_lane_from_grid(grid: TerrainGrid) -> void:
	# Estremi in spazio mondo: la lunghezza resta corretta anche con griglia scalata.
	# La corsia segue la rotazione della griglia (in Unreal era sempre +X mondo,
	# con la griglia mai ruotata: stesso risultato nella scena del prototipo).
	var half_length_cm := grid.width_extent_cm() * 0.5 + tuning.lane_margin_cm
	var height_cm := tuning.lane_center_height_cm
	var start := grid.to_global(UnrealSpace.position(Vector3(-half_length_cm, 0.0, height_cm)))
	var end := grid.to_global(UnrealSpace.position(Vector3(half_length_cm, 0.0, height_cm)))
	configure_lane(start, end - start, start.distance_to(end))


## Origine, direzione planare e lunghezza (m) della corsia; riavvia dall'origine.
func configure_lane(start: Vector3, direction: Vector3, length: float) -> void:
	lane_start = start
	direction.y = 0.0
	lane_direction = direction.normalized() if not direction.is_zero_approx() else Vector3.FORWARD
	lane_length = maxf(length, 1.0)
	_restart_lane()


func _physics_process(delta: float) -> void:
	if is_resting:
		_rest_left -= delta
		if _rest_left <= 0.0:
			_restart_lane()
		return

	var step := UnrealSpace.length(maxf(tuning.move_speed_cm, 10.0)) * delta
	var motion := lane_direction * step
	_query.transform = global_transform
	_query.motion = motion
	var fractions := get_world_3d().direct_space_state.cast_motion(_query)
	if fractions[0] < 1.0:
		# Come lo sweep di AddActorWorldOffset: avanza fino al contatto e si ferma.
		global_position += motion * fractions[0]
		print("PROTOTYPE01_TERRAIN_HAZARD_BLOCKED")
		blocked.emit()
		_schedule_restart()
		return

	global_position += motion
	traveled_distance += step
	if traveled_distance >= lane_length:
		print("PROTOTYPE01_TERRAIN_HAZARD_REACHED")
		reached.emit()
		_schedule_restart()


func _schedule_restart() -> void:
	is_resting = true
	_mesh.visible = false
	_rest_left = maxf(tuning.restart_delay, 0.05)


func _restart_lane() -> void:
	traveled_distance = 0.0
	global_position = lane_start
	reset_physics_interpolation()
	_mesh.visible = true
	is_resting = false
