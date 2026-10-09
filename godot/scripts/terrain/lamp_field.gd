class_name LampField
extends Node3D
## Lampioni piazzabili (D-058, tappa 2; `DAY_NIGHT_SPEC.md` sezione 7). Possiede i
## lampioni: regole di piazzamento, limite, costo in rottami del compagno, nodo visivo e
## luce di ciascuno, registrazione in `LightField`, rimozione quando la cella cambia
## stato o quando il Demolitore ci passa sopra. Non blocca il passaggio: il campo di
## percorso non lo vede.

signal lamps_changed(count: int)
signal lamp_placed(cell: Vector2i)
signal lamp_lost(cell: Vector2i, reason: StringName)

const POLE_HEIGHT := 2.2
const HEAD_SIZE := 0.36
const LAMP_COLOR := Color(1.0, 0.85, 0.55)

@export var grid: TerrainGrid
## Chi paga i lampioni (rottami del cassone); senza compagno sono gratis (scene senza compagno).
@export var companion: Companion

## Copiati dal tuning da ArenaRun.
var scrap_cost := 3
var max_count := 6
var light_radius := 5.0
## Luce logica dove registrare i lampioni; senza, i lampioni sono solo visivi.
var light_field: LightField

var _lamps: Dictionary[Vector2i, Dictionary] = {}
var _pole_mesh: CylinderMesh
var _head_mesh: BoxMesh
var _pole_material: StandardMaterial3D
var _head_material: StandardMaterial3D


func _ready() -> void:
	if grid != null:
		grid.cell_changed.connect(_on_cell_changed)
		grid.rebuilt.connect(_on_grid_rebuilt)


func count() -> int:
	return _lamps.size()


func has_lamp(cell: Vector2i) -> bool:
	return _lamps.has(cell)


func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(_lamps.keys())
	return result


## La cella puo ricevere un lampione (regole della specifica, senza il costo).
func can_place(cell: Vector2i) -> bool:
	if grid == null or not grid.state.is_valid(cell) or grid.state.is_protected(cell):
		return false
	if grid.state.get_state(cell) == TerrainState.CellState.LOWERED:
		return false
	return not _lamps.has(cell) and _lamps.size() < max_count


## Il compagno ha i rottami per un lampione, entro il raggio di rifornimento dal punto.
func can_afford(world_target: Vector3) -> bool:
	if companion == null:
		return true
	return companion.can_supply_count(world_target, scrap_cost)


## Piazza un lampione sulla cella sotto [param world_target], pagandolo. False se rifiutato.
func place_at(world_target: Vector3) -> bool:
	var cell := grid.cell_at(world_target)
	if not can_place(cell):
		print("PROTOTYPE01_LAMP_REJECTED X=%d Y=%d reason=cell count=%d" % [cell.x, cell.y, _lamps.size()])
		return false
	if not can_afford(world_target):
		print("PROTOTYPE01_LAMP_REJECTED X=%d Y=%d reason=scrap" % [cell.x, cell.y])
		return false
	if companion != null:
		companion.spend_count(scrap_cost)
	_build_lamp(cell)
	print("PROTOTYPE01_LAMP_PLACED X=%d Y=%d count=%d" % [cell.x, cell.y, _lamps.size()])
	lamp_placed.emit(cell)
	lamps_changed.emit(_lamps.size())
	return true


## Abbatte i lampioni entro [param radius] (piano XZ) da [param world]; restituisce quanti.
func knock_down_near(world: Vector3, radius: float) -> int:
	var hit: Array[Vector2i] = []
	for cell: Vector2i in _lamps:
		var at: Vector3 = _lamps[cell].node.global_position
		if Vector2(at.x - world.x, at.z - world.z).length() <= radius:
			hit.append(cell)
	for cell in hit:
		_remove(cell, &"demolisher")
	return hit.size()


func _build_lamp(cell: Vector2i) -> void:
	if _pole_mesh == null:
		_pole_mesh = CylinderMesh.new()
		_pole_mesh.top_radius = 0.06
		_pole_mesh.bottom_radius = 0.09
		_pole_mesh.height = POLE_HEIGHT
		_pole_mesh.radial_segments = 8
		_pole_material = StandardMaterial3D.new()
		_pole_material.albedo_color = Color(0.25, 0.22, 0.2)
		_head_mesh = BoxMesh.new()
		_head_mesh.size = Vector3.ONE * HEAD_SIZE
		_head_material = StandardMaterial3D.new()
		_head_material.albedo_color = LAMP_COLOR
		_head_material.emission_enabled = true
		_head_material.emission = LAMP_COLOR
		_head_material.emission_energy_multiplier = 3.0
	var cell_state := grid.state.get_state(cell)
	var surface := grid.to_global(grid.cell_local_position(cell, cell_state))
	var base := Vector3(surface.x, surface.y * 2.0 - grid.global_position.y, surface.z)
	var lamp := Node3D.new()
	lamp.name = "Lamp_%d_%d" % [cell.x, cell.y]
	add_child(lamp)
	lamp.global_position = base
	var pole := MeshInstance3D.new()
	pole.mesh = _pole_mesh
	pole.material_override = _pole_material
	pole.position = Vector3(0.0, POLE_HEIGHT * 0.5, 0.0)
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(pole)
	var head := MeshInstance3D.new()
	head.mesh = _head_mesh
	head.material_override = _head_material
	head.position = Vector3(0.0, POLE_HEIGHT + HEAD_SIZE * 0.5, 0.0)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(head)
	# I lampioni non proiettano mai ombre (specifica, sezione 10).
	var light := OmniLight3D.new()
	light.name = "LampLight"
	light.position = Vector3(0.0, POLE_HEIGHT, 0.0)
	light.light_color = LAMP_COLOR
	light.light_energy = 1.8
	light.omni_range = light_radius * 1.15
	light.shadow_enabled = false
	lamp.add_child(light)
	var source_id := light_field.add_source(lamp, light_radius) if light_field != null else 0
	_lamps[cell] = {node = lamp, source = source_id}


func _remove(cell: Vector2i, reason: StringName) -> void:
	var entry: Dictionary = _lamps[cell]
	_lamps.erase(cell)
	if light_field != null and entry.source > 0:
		light_field.remove_source(entry.source)
	var node: Node3D = entry.node
	remove_child(node)
	node.queue_free()
	print("PROTOTYPE01_LAMP_LOST X=%d Y=%d reason=%s count=%d" % [cell.x, cell.y, reason, _lamps.size()])
	lamp_lost.emit(cell, reason)
	lamps_changed.emit(_lamps.size())


## La cella cambia stato (scavo, rialzo, demolizione, esplosione): il lampione e perso.
func _on_cell_changed(cell: Vector2i, _state: TerrainState.CellState) -> void:
	if _lamps.has(cell):
		_remove(cell, &"terrain")


func _on_grid_rebuilt() -> void:
	for cell in cells():
		_remove(cell, &"rebuild")
