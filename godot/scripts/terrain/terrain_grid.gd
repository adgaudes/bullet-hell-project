@tool
class_name TerrainGrid
extends Node3D
## Griglia terreno graybox: porta di APrototype01TerrainGridActor.
##
## Lo stato logico vive in TerrainState; questo nodo ne e la presentazione
## (una cella = StaticBody3D con mesh e collisione) e l'interfaccia in
## coordinate mondo. Solo le celle Raised hanno collisione.
## La costruzione gira anche nell'editor (@tool), come OnConstruction:
## le celle generate non sono salvate nella scena, quindi non si duplicano.
## L'origine del nodo e il centro della griglia, sul piano del pavimento.

signal cell_changed(cell: Vector2i, state: TerrainState.CellState)
## Emesso a ogni comando applicato, con la modalita (Dig produce rottami).
signal command_applied(cell: Vector2i, mode: TerrainState.ToolMode, state: TerrainState.CellState)
## Emesso a fine ricostruzione: dimensioni o posizione delle celle possono essere cambiate.
signal rebuilt

const CELL_SHADER := preload("res://resources/materials/terrain_cell.gdshader")

## Colori lineari Unreal.
const NORMAL_COLOR := Color(0.34, 0.48, 0.20)
const LOWERED_COLOR := Color(0.08, 0.16, 0.20)
const RAISED_COLOR := Color(0.64, 0.28, 0.08)
const PROTECTED_COLOR := Color(0.42, 0.12, 0.48)
const DIG_PREVIEW_COLOR := Color(0.05, 0.75, 1.0)
const RAISE_PREVIEW_COLOR := Color(1.0, 0.78, 0.05)
const INVALID_PREVIEW_COLOR := Color(1.0, 0.03, 0.03)
## Anteprima: 72% della cella visibile, 5 cm di spessore, 2 cm sopra la cella.
const PREVIEW_SIZE_RATIO := 0.72
const PREVIEW_HEIGHT_CM := 5.0
const PREVIEW_LIFT_CM := 2.0

@export var tuning: TerrainTuning:
	set(value):
		if tuning != null and tuning.changed.is_connected(_queue_rebuild):
			tuning.changed.disconnect(_queue_rebuild)
		tuning = value
		if tuning != null:
			tuning.changed.connect(_queue_rebuild)
		_queue_rebuild()
## Celle col suolo dell'arena in rovina, tinte dallo stato (D-036). Spento = colori
## pieni del prototipo Unreal, usati dalla scena di parita.
@export var natural_ground := false:
	set(value):
		natural_ground = value
		_queue_rebuild()

## Quanto il colore di stato copre il suolo naturale: Normal resta quasi suolo.
const NATURAL_STATE_TINT := {
	TerrainState.CellState.NORMAL: 0.12,
	TerrainState.CellState.LOWERED: 0.85,
	TerrainState.CellState.RAISED: 0.8,
}
const NATURAL_PROTECTED_TINT := 0.75

var state := TerrainState.new()
## Cella sotto l'anteprima, (-1, -1) se nascosta.
var preview_cell := Vector2i(-1, -1)

# Valori di tuning normalizzati come ClampGridProperties, senza modificare la risorsa.
var _cell_size_cm := 240.0
var _cell_gap_cm := 12.0
var _heights_cm: Dictionary[int, float] = {}
var _cells: Array[StaticBody3D] = []
var _meshes: Dictionary[int, BoxMesh] = {}
var _shapes: Dictionary[int, BoxShape3D] = {}
var _material: ShaderMaterial
var _preview: MeshInstance3D
var _rebuild_pending := false


func _ready() -> void:
	if tuning == null:
		tuning = TerrainTuning.new()
	rebuild()
	if not Engine.is_editor_hint():
		print("PROTOTYPE01_TERRAIN_GRID_READY Width=%d Height=%d" % [state.width, state.height])


## Ricostruzione idempotente: rimuove sempre le celle generate in precedenza.
func rebuild() -> void:
	_rebuild_pending = false
	_clamp_from_tuning()
	for cell in _cells:
		remove_child(cell)
		cell.queue_free()
	_cells.clear()
	if _preview != null:
		remove_child(_preview)
		_preview.queue_free()

	_material = ShaderMaterial.new()
	_material.shader = CELL_SHADER
	var visual_size := UnrealSpace.length(maxf(_cell_size_cm - _cell_gap_cm, 10.0))
	for cell_state: int in _heights_cm:
		var height := UnrealSpace.length(_heights_cm[cell_state])
		var mesh := BoxMesh.new()
		mesh.size = Vector3(visual_size, height, visual_size)
		_meshes[cell_state] = mesh
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		_shapes[cell_state] = shape

	for y in state.height:
		for x in state.width:
			_cells.append(_create_cell(Vector2i(x, y)))

	var preview_size := UnrealSpace.length(maxf(_cell_size_cm - _cell_gap_cm, 10.0) * PREVIEW_SIZE_RATIO)
	var preview_mesh := BoxMesh.new()
	preview_mesh.size = Vector3(preview_size, UnrealSpace.length(PREVIEW_HEIGHT_CM), preview_size)
	_preview = MeshInstance3D.new()
	_preview.name = "Preview"
	_preview.mesh = preview_mesh
	_preview.material_override = _material
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.visible = false
	add_child(_preview)
	rebuilt.emit()


## Mostra l'anteprima sulla cella che contiene [param world_target].
## Ciano = Dig, giallo = Raise, rosso = comando impossibile.
## Restituisce se il comando e applicabile; nasconde l'anteprima fuori griglia.
## [param blocked]: vincolo esterno alla griglia (es. rottami mancanti), mostra rosso.
func update_preview(world_target: Vector3, mode: TerrainState.ToolMode, instigator: Node3D = null, blocked := false) -> bool:
	var cell := cell_at(world_target)
	if not state.is_valid(cell):
		hide_preview()
		return false

	var cell_state := state.get_state(cell)
	var can_apply := state.can_apply(cell, mode, _would_raise_overlap(cell, instigator)) and not blocked
	var position_cm := Vector3(0.0, 0.0, _heights_cm[cell_state] + PREVIEW_HEIGHT_CM * 0.5 + PREVIEW_LIFT_CM)
	var cell_position := cell_local_position(cell, cell_state)
	_preview.position = Vector3(cell_position.x, UnrealSpace.length(position_cm.z), cell_position.z)
	var color := INVALID_PREVIEW_COLOR
	if can_apply:
		color = DIG_PREVIEW_COLOR if mode == TerrainState.ToolMode.DIG else RAISE_PREVIEW_COLOR
	_preview.set_instance_shader_parameter(&"cell_color", color.linear_to_srgb())
	_preview.visible = true
	preview_cell = cell
	return can_apply


func hide_preview() -> void:
	preview_cell = Vector2i(-1, -1)
	if _preview != null:
		_preview.visible = false


## Piu modifiche nello stesso frame producono una sola ricostruzione.
func _queue_rebuild() -> void:
	if not is_node_ready() or _rebuild_pending:
		return
	_rebuild_pending = true
	_flush_rebuild.call_deferred()


func _flush_rebuild() -> void:
	# Una rebuild() diretta nel frattempo ha gia azzerato la richiesta.
	if _rebuild_pending:
		rebuild()


## Cella che contiene il punto mondo; usare state.is_valid() sul risultato.
func cell_at(world_position: Vector3) -> Vector2i:
	var unreal_local := UnrealSpace.to_unreal_position(to_local(world_position))
	var half_width := (state.width - 1) * 0.5
	var half_height := (state.height - 1) * 0.5
	# FMath::RoundToInt = floor(x + 0.5).
	return Vector2i(
		floori(unreal_local.x / _cell_size_cm + half_width + 0.5),
		floori(unreal_local.y / _cell_size_cm + half_height + 0.5))


## Stato della cella sotto il punto; [param fallback] se fuori griglia.
func cell_state_at(world_position: Vector3, fallback := TerrainState.CellState.NORMAL) -> TerrainState.CellState:
	var cell := cell_at(world_position)
	return state.get_state(cell) if state.is_valid(cell) else fallback


## Estensione lungo l'asse X Unreal (GetGridWidthWorldExtent), in cm.
func width_extent_cm() -> float:
	return state.width * _cell_size_cm


func lowered_speed_penalty() -> float:
	return clampf(tuning.lowered_speed_penalty_percent, 0.0, 0.95)


func can_apply_at(world_target: Vector3, mode: TerrainState.ToolMode, instigator: Node3D = null) -> bool:
	var cell := cell_at(world_target)
	return state.can_apply(cell, mode, _would_raise_overlap(cell, instigator))


## Un passo del comando sulla cella bersaglio. [param instigator] serve al
## controllo anti-intrappolamento del rialzo.
func apply_command_at(world_target: Vector3, mode: TerrainState.ToolMode, instigator: Node3D = null) -> bool:
	var cell := cell_at(world_target)
	var raise_blocked := _would_raise_overlap(cell, instigator)
	if not state.can_apply(cell, mode, raise_blocked):
		if state.is_occupied_rejection(cell, mode, raise_blocked):
			print("PROTOTYPE01_TERRAIN_RAISE_OCCUPIED_REJECTED X=%d Y=%d" % [cell.x, cell.y])
		else:
			print("PROTOTYPE01_TERRAIN_REJECTED X=%d Y=%d" % [cell.x, cell.y])
		return false

	var new_state := state.apply(cell, mode)
	_update_cell_presentation(cell)
	print("PROTOTYPE01_TERRAIN_CHANGED X=%d Y=%d State=%s" % [cell.x, cell.y, TerrainState.state_name(new_state)])
	cell_changed.emit(cell, new_state)
	command_applied.emit(cell, mode, new_state)
	return true


## Centro della cella nello spazio locale, alla meta dell'altezza dello stato.
func cell_local_position(cell: Vector2i, cell_state: TerrainState.CellState) -> Vector3:
	var half_width := (state.width - 1) * 0.5
	var half_height := (state.height - 1) * 0.5
	return UnrealSpace.position(Vector3(
		(cell.x - half_width) * _cell_size_cm,
		(cell.y - half_height) * _cell_size_cm,
		_heights_cm[cell_state] * 0.5))


func _clamp_from_tuning() -> void:
	var width := clampi(tuning.grid_width, 1, 15)
	var height := clampi(tuning.grid_height, 1, 15)
	# Griglia sempre dispari: la cella centrale e sotto l'origine.
	if width % 2 == 0:
		width -= 1
	if height % 2 == 0:
		height -= 1
	state.resize(width, height)
	_cell_size_cm = maxf(tuning.cell_size_cm, 100.0)
	_cell_gap_cm = clampf(tuning.cell_gap_cm, 0.0, _cell_size_cm * 0.4)
	var lowered := maxf(tuning.lowered_height_cm, 1.0)
	var normal := maxf(tuning.normal_height_cm, lowered)
	var raised := maxf(tuning.raised_height_cm, normal)
	_heights_cm = {
		TerrainState.CellState.LOWERED: lowered,
		TerrainState.CellState.NORMAL: normal,
		TerrainState.CellState.RAISED: raised,
	}


func _create_cell(cell: Vector2i) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Cell_%d_%d" % [cell.x, cell.y]
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.material_override = _material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	body.add_child(collision)

	_apply_presentation(body, cell, false)
	return body


func _update_cell_presentation(cell: Vector2i) -> void:
	if state.is_valid(cell):
		_apply_presentation(_cells[cell.y * state.width + cell.x], cell, true)


func _apply_presentation(body: StaticBody3D, cell: Vector2i, deferred: bool) -> void:
	var cell_state := state.get_state(cell)
	body.position = cell_local_position(cell, cell_state)

	var mesh_instance: MeshInstance3D = body.get_node(^"Mesh")
	mesh_instance.mesh = _meshes[cell_state]
	var color := NORMAL_COLOR
	if state.is_protected(cell):
		color = PROTECTED_COLOR
	elif cell_state == TerrainState.CellState.LOWERED:
		color = LOWERED_COLOR
	elif cell_state == TerrainState.CellState.RAISED:
		color = RAISED_COLOR
	mesh_instance.set_instance_shader_parameter(&"cell_color", color.linear_to_srgb())
	mesh_instance.set_instance_shader_parameter(&"natural", 1.0 if natural_ground else 0.0)
	var tint: float = NATURAL_PROTECTED_TINT if state.is_protected(cell) else NATURAL_STATE_TINT[cell_state]
	mesh_instance.set_instance_shader_parameter(&"state_tint", tint)

	# Collisione coerente con la geometria visibile: solo Raised blocca.
	# A runtime e differita (un comando puo arrivare durante una query fisica);
	# in costruzione e immediata, o la cella spingerebbe via chi ci sta sopra.
	var collision: CollisionShape3D = body.get_node(^"Collision")
	collision.shape = _shapes[cell_state]
	var disabled := cell_state != TerrainState.CellState.RAISED
	if deferred:
		collision.set_deferred(&"disabled", disabled)
	else:
		collision.disabled = disabled


## Il rialzo della cella intersecherebbe il volume collidente di chi lo richiede?
func _would_raise_overlap(cell: Vector2i, instigator: Node3D) -> bool:
	if instigator == null or not state.is_valid(cell) or not instigator.has_method(&"get_collision_aabb"):
		return false
	var raised := TerrainState.CellState.RAISED
	var local_box := AABB(cell_local_position(cell, raised) - _shapes[raised].size * 0.5, _shapes[raised].size)
	var world_box := global_transform * local_box
	var pawn_box: AABB = instigator.call(&"get_collision_aabb")
	# Come FBox::Intersect: il contatto sul bordo conta come intersezione.
	return world_box.position.x <= pawn_box.end.x and pawn_box.position.x <= world_box.end.x \
		and world_box.position.y <= pawn_box.end.y and pawn_box.position.y <= world_box.end.y \
		and world_box.position.z <= pawn_box.end.z and pawn_box.position.z <= world_box.end.z
