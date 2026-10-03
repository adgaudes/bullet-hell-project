class_name ScrapField
extends Node3D
## Rottami a terra: nascono quando una cella viene scavata e restano finche il
## compagno non li raccoglie. Nessuna fisica: posizioni e distanze bastano.

signal scrap_spawned(position: Vector3)

## Ruggine, lineare.
const SCRAP_COLOR := Color(0.55, 0.22, 0.06)
const SCRAP_SIZE := 0.3
const MAX_SCRAPS := 20
const BOB_HEIGHT := 0.08
const BOB_SPEED := 3.0

@export var grid: TerrainGrid

var _scraps: Array[MeshInstance3D] = []
var _mesh := BoxMesh.new()
var _material := StandardMaterial3D.new()
var _time := 0.0


func _ready() -> void:
	_mesh.size = Vector3.ONE * SCRAP_SIZE
	_material.albedo_color = SCRAP_COLOR.linear_to_srgb()
	if grid != null:
		grid.command_applied.connect(_on_command_applied)


func count() -> int:
	return _scraps.size()


func spawn(world_position: Vector3) -> void:
	if _scraps.size() >= MAX_SCRAPS:
		return
	var scrap := MeshInstance3D.new()
	scrap.mesh = _mesh
	scrap.material_override = _material
	add_child(scrap)
	scrap.global_position = world_position
	scrap.set_meta(&"base_y", world_position.y)
	_scraps.append(scrap)
	print("PROTOTYPE01_SCRAP_SPAWNED")
	scrap_spawned.emit(world_position)


## Rottame piu vicino a [param origin] entro [param radius] (piano XZ), o null.
func nearest(origin: Vector3, radius: float) -> Variant:
	var best: Variant = null
	var best_distance := radius
	for scrap in _scraps:
		var distance := _planar_distance(scrap.global_position, origin)
		if distance <= best_distance:
			best_distance = distance
			best = scrap.global_position
	return best


## Rimuove fino a [param max_count] rottami entro [param radius]; restituisce quanti.
func take_near(origin: Vector3, radius: float, max_count: int) -> int:
	var taken := 0
	for scrap in _scraps.duplicate():
		if taken >= max_count:
			break
		if _planar_distance(scrap.global_position, origin) <= radius:
			_scraps.erase(scrap)
			scrap.queue_free()
			taken += 1
	return taken


func _process(delta: float) -> void:
	_time += delta
	for scrap in _scraps:
		var base_y: float = scrap.get_meta(&"base_y")
		scrap.position.y = base_y + sin(_time * BOB_SPEED + scrap.position.x) * BOB_HEIGHT
		scrap.rotation.y += delta


## Ogni passo di scavo produce un rottame sopra la cella.
func _on_command_applied(cell: Vector2i, mode: TerrainState.ToolMode, new_state: TerrainState.CellState) -> void:
	if mode != TerrainState.ToolMode.DIG:
		return
	# cell_local_position e il centro a meta altezza: la superficie e al doppio.
	var local := grid.cell_local_position(cell, new_state)
	local.y = local.y * 2.0 + SCRAP_SIZE
	spawn(grid.to_global(local))


static func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
