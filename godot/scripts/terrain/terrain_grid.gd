@tool
class_name TerrainGrid
extends Node3D
## Griglia terreno graybox: porta di APrototype01TerrainGridActor.
##
## Lo stato logico vive in TerrainState; questo nodo ne e la presentazione e
## l'interfaccia in coordinate mondo. Dalla scala dell'arena grande (D-042) la
## presentazione e a lotti: un MultiMesh per stato (tre draw call per l'intera
## griglia, qualunque sia il numero di celle) e un solo StaticBody3D con una
## forma di collisione per ogni cella Raised, perche solo le Raised collidono.
## La costruzione gira anche nell'editor (@tool), come OnConstruction:
## i nodi generati non sono salvati nella scena, quindi non si duplicano.
## L'origine del nodo e il centro della griglia, sul piano del pavimento.

signal cell_changed(cell: Vector2i, state: TerrainState.CellState)
## Emesso a ogni comando applicato, con la modalita (Dig produce rottami).
signal command_applied(cell: Vector2i, mode: TerrainState.ToolMode, state: TerrainState.CellState)
## Emesso a fine ricostruzione: dimensioni o posizione delle celle possono essere cambiate.
signal rebuilt

const CELL_SHADER := preload("res://resources/materials/terrain_cell.gdshader")
## Tile dipinte del suolo (restyling 2026-10-11), condivise con il piano dell'arena.
const GROUND_ALBEDO := preload("res://assets/textures/surfaces/ground_albedo.png")
const GROUND_NORMAL := preload("res://assets/textures/surfaces/ground_normal.png")
const GROUND_ORM := preload("res://assets/textures/surfaces/ground_orm.png")
## Ripetizioni della tile per metro: una tile ogni 4 m.
const TILE_SCALE := 0.25

## Colori lineari Unreal.
const NORMAL_COLOR := Color(0.34, 0.48, 0.20)
const LOWERED_COLOR := Color(0.08, 0.16, 0.20)
const RAISED_COLOR := Color(0.64, 0.28, 0.08)
const PROTECTED_COLOR := Color(0.42, 0.12, 0.48)
const DIG_PREVIEW_COLOR := Color(0.05, 0.75, 1.0)
const RAISE_PREVIEW_COLOR := Color(1.0, 0.78, 0.05)
const LAMP_PREVIEW_COLOR := Color(1.0, 0.92, 0.7)
const INVALID_PREVIEW_COLOR := Color(1.0, 0.03, 0.03)
## Anteprima: 72% della cella visibile, 5 cm di spessore, 2 cm sopra la cella.
const PREVIEW_SIZE_RATIO := 0.72
const PREVIEW_HEIGHT_CM := 5.0
const PREVIEW_LIFT_CM := 2.0
## Istanza nascosta di un MultiMesh: scala zero, nessun triangolo disegnato.
const HIDDEN_TRANSFORM := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
## Due lotti (T-07): le celle piatte (Normal e Lowered, un cubo unitario scalato in Y
## dallo stato, senza ombre) e i terrapieni (con ombre). Ogni cella ha un'istanza in
## entrambi, visibile in uno solo: prima erano tre lotti e due istanze degeneri per cella.
const FLAT_BATCH := TerrainState.CellState.NORMAL
const RAISED_BATCH := TerrainState.CellState.RAISED
const BATCH_NAMES := {
	FLAT_BATCH: "CellsFlat",
	RAISED_BATCH: "CellsRaised",
}

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
## Raggio della piazza del suolo naturale (OvergrownArena.plaza_radius()), in metri:
## oltre, il suolo delle celle e verde come quello dell'arena.
@export var plaza_radius := 20.4:
	set(value):
		plaza_radius = value
		for material in [_material, _batch_material]:
			if material != null:
				material.set_shader_parameter(&"plaza_radius", plaza_radius)

## Quanto il colore di stato copre il suolo naturale: Normal resta quasi suolo.
const NATURAL_STATE_TINT := {
	TerrainState.CellState.NORMAL: 0.12,
	TerrainState.CellState.LOWERED: 0.85,
	TerrainState.CellState.RAISED: 0.55,
}
const NATURAL_PROTECTED_TINT := 0.75

## Colore delle celle Raised al posto di RAISED_COLOR (upgrade Terrapieni spinati);
## trasparente = nessuna sostituzione.
var raised_color_override := Color(0, 0, 0, 0):
	set(value):
		raised_color_override = value
		# Solo le celle che hanno una forma (sono o sono state Raised), non tutte le 7225 (R-33).
		for index in _raised_shapes.keys():
			var cell := Vector2i(index % state.width, index / state.width)
			if state.get_state(cell) == TerrainState.CellState.RAISED:
				_update_cell_presentation(cell)

## Tinta propria di singole celle Raised (indice -> colore lineare): le barricate del boss.
var _raised_tints: Dictionary[int, Color] = {}
var _tint_cell_count := 0

var state := TerrainState.new()
## Cella sotto l'anteprima, (-1, -1) se nascosta.
var preview_cell := Vector2i(-1, -1)
## Microsecondi dell'ultima ricostruzione, per benchmark e log.
var last_rebuild_usec := 0

# Valori di tuning normalizzati come ClampGridProperties, senza modificare la risorsa.
var _cell_size_cm := 240.0
var _cell_gap_cm := 12.0
var _heights_cm: Dictionary[int, float] = {}
var _meshes: Dictionary[int, BoxMesh] = {}
var _shapes: Dictionary[int, BoxShape3D] = {}
## Un MultiMeshInstance3D per stato; ogni cella ha un'istanza in ognuno, visibile solo in quello del suo stato.
var _batches: Dictionary[int, MultiMeshInstance3D] = {}
## Un corpo statico per blocco di COLLISION_CHUNK x COLLISION_CHUNK celle (T-03): l'AABB di
## ogni corpo copre solo il suo blocco, cosi `move_and_slide` e i raggi dei chiodi
## incontrano poche forme invece di tutte le celle Raised dell'arena.
const COLLISION_CHUNK := 8
var _raised_bodies: Dictionary[Vector2i, StaticBody3D] = {}
## Indice di cella -> forma di collisione, creata al primo rialzo e poi disattivata/riattivata.
var _raised_shapes: Dictionary[int, CollisionShape3D] = {}
## Materiale dell'anteprima (colore per istanza) e dei lotti (colore dal MultiMesh).
var _material: ShaderMaterial
var _batch_material: ShaderMaterial
var _preview: MeshInstance3D
var _rebuild_pending := false


func _ready() -> void:
	if tuning == null:
		tuning = TerrainTuning.new()
	# La frangia d'erba dello shader dipende dalla quota mondo dei terrapieni (T-11):
	# se il nodo viene spostato nell'editor, i materiali la rileggono.
	set_notify_transform(true)
	rebuild()
	if not Engine.is_editor_hint():
		print("PROTOTYPE01_TERRAIN_GRID_READY Width=%d Height=%d" % [state.width, state.height])


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree() and not _heights_cm.is_empty():
		for material in [_material, _batch_material]:
			if material != null:
				material.set_shader_parameter(&"raised_top", raised_top_y())


## Quota mondo della cima di una cella Raised (letta dallo shader per la frangia d'erba).
func raised_top_y() -> float:
	return global_position.y + UnrealSpace.length(_heights_cm[TerrainState.CellState.RAISED])


## Cambia la cella protetta (o la toglie con (-1,-1)) aggiornando la resa delle celle toccate,
## senza ricostruire la griglia.
func set_protected_cell(cell: Vector2i) -> void:
	var previous := state.protected_cell
	state.protected_cell = cell
	_update_cell_presentation(previous)
	_update_cell_presentation(cell)


## Ricostruzione idempotente: rimuove sempre i nodi generati in precedenza.
func rebuild() -> void:
	var start_usec := Time.get_ticks_usec()
	_rebuild_pending = false
	_clamp_from_tuning()
	# Le tinte sono indicizzate per cella: con una griglia di altra misura non valgono piu (R-34).
	if state.cell_count() != _tint_cell_count:
		_raised_tints.clear()
		_tint_cell_count = state.cell_count()
	for batch in _batches.values():
		remove_child(batch)
		batch.queue_free()
	_batches.clear()
	for body in _raised_bodies.values():
		remove_child(body)
		body.queue_free()
	_raised_bodies.clear()
	_raised_shapes.clear()
	if _preview != null:
		remove_child(_preview)
		_preview.queue_free()

	_material = _make_material(false)
	_batch_material = _make_material(true)
	var visual_size := UnrealSpace.length(maxf(_cell_size_cm - _cell_gap_cm, 10.0))
	var count := state.cell_count()
	for cell_state: int in _heights_cm:
		var height := UnrealSpace.length(_heights_cm[cell_state])
		var mesh := BoxMesh.new()
		mesh.size = Vector3(visual_size, height, visual_size)
		_meshes[cell_state] = mesh
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		_shapes[cell_state] = shape
	# Il lotto piatto usa un cubo alto 1 m scalato in Y dall'altezza dello stato.
	var flat_mesh := BoxMesh.new()
	flat_mesh.size = Vector3(visual_size, 1.0, visual_size)
	for batch_state: int in BATCH_NAMES:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.use_custom_data = true
		multimesh.mesh = _meshes[RAISED_BATCH] if batch_state == RAISED_BATCH else flat_mesh
		multimesh.instance_count = count
		var batch := MultiMeshInstance3D.new()
		batch.name = BATCH_NAMES[batch_state]
		batch.multimesh = multimesh
		batch.material_override = _batch_material
		# Solo i terrapieni proiettano un'ombra che si vede; le altre celle sono lastre.
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			if batch_state == RAISED_BATCH else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
		_batches[batch_state] = batch


	for y in state.height:
		for x in state.width:
			_apply_presentation(Vector2i(x, y), false)

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
	last_rebuild_usec = Time.get_ticks_usec() - start_usec
	rebuilt.emit()


func _make_material(batched: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CELL_SHADER
	material.set_shader_parameter(&"batched", batched)
	material.set_shader_parameter(&"plaza_radius", plaza_radius)
	material.set_shader_parameter(&"cell_pitch", UnrealSpace.length(_cell_size_cm))
	apply_ground_tiles(material)
	if is_inside_tree():
		material.set_shader_parameter(&"raised_top", raised_top_y())
	return material


## Passa le tile dipinte del suolo a un materiale che include surface_tiles.gdshaderinc
## (celle del terreno e piano dell'arena usano le stesse texture e la stessa scala).
static func apply_ground_tiles(material: ShaderMaterial) -> void:
	material.set_shader_parameter(&"ground_albedo", GROUND_ALBEDO)
	material.set_shader_parameter(&"ground_normal", GROUND_NORMAL)
	material.set_shader_parameter(&"ground_orm", GROUND_ORM)
	material.set_shader_parameter(&"tile_scale", TILE_SCALE)


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
		match mode:
			TerrainState.ToolMode.DIG:
				color = DIG_PREVIEW_COLOR
			TerrainState.ToolMode.LAMP:
				color = LAMP_PREVIEW_COLOR
			_:
				color = RAISE_PREVIEW_COLOR
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


## Lato di una cella in metri.
func cell_size_m() -> float:
	return UnrealSpace.length(_cell_size_cm)


func lowered_speed_penalty() -> float:
	return clampf(tuning.lowered_speed_penalty_percent, 0.0, 0.95)


## Celle presentate (istanze di ogni lotto): uguale a state.cell_count() se la
## costruzione e coerente. Per test e benchmark.
func presented_cell_count() -> int:
	var batch: MultiMeshInstance3D = _batches.get(FLAT_BATCH)
	return batch.multimesh.instance_count if batch != null else 0


## Forme di collisione attive (una per cella Raised).
## Corpo statico del blocco che contiene la cella, creato alla prima cella Raised del blocco.
## Figlio diretto della griglia: chi controlla `collider.get_parent() == grid` resta valido.
func _raised_body_for(cell: Vector2i) -> StaticBody3D:
	var chunk := Vector2i(cell.x / COLLISION_CHUNK, cell.y / COLLISION_CHUNK)
	var body: StaticBody3D = _raised_bodies.get(chunk)
	if body == null:
		body = StaticBody3D.new()
		body.name = "RaisedCells_%d_%d" % [chunk.x, chunk.y]
		body.collision_layer = 1
		body.collision_mask = 0
		add_child(body)
		_raised_bodies[chunk] = body
	return body


func active_collision_count() -> int:
	var count := 0
	for shape in _raised_shapes.values():
		if not shape.disabled:
			count += 1
	return count


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


## Disposizione iniziale (es. le mura del cortile, D-038): imposta lo stato senza
## regole ne segnali di comando. Da chiamare prima che qualcuno stia sulle celle.
func set_cell_states(cells: Array[Vector2i], cell_state: TerrainState.CellState) -> void:
	for cell in cells:
		if state.is_valid(cell) and not state.is_protected(cell):
			state.set_state(cell, cell_state)
			_apply_presentation(cell, false)
			cell_changed.emit(cell, cell_state)


## Cambio di stato a runtime fuori dalle regole del tool (boss che smonta un muro
## o alza una barricata): niente log ne `command_applied`, quindi niente rottami.
## Collisione differita come per i comandi. False se la cella non e modificabile.
func force_cell_state(cell: Vector2i, cell_state: TerrainState.CellState) -> bool:
	if not state.is_valid(cell) or state.is_protected(cell) or state.get_state(cell) == cell_state:
		return false
	state.set_state(cell, cell_state)
	_apply_presentation(cell, true)
	cell_changed.emit(cell, cell_state)
	return true


## Colore proprio di una cella quando e Raised (vale finche non viene tolto).
func set_raised_tint(cell: Vector2i, color: Color) -> void:
	if state.is_valid(cell):
		_raised_tints[cell.y * state.width + cell.x] = color
		_update_cell_presentation(cell)


func clear_raised_tint(cell: Vector2i) -> void:
	if state.is_valid(cell) and _raised_tints.erase(cell.y * state.width + cell.x):
		_update_cell_presentation(cell)


## Centro della cella nello spazio locale, alla meta dell'altezza dello stato.
func cell_local_position(cell: Vector2i, cell_state: TerrainState.CellState) -> Vector3:
	var half_width := (state.width - 1) * 0.5
	var half_height := (state.height - 1) * 0.5
	return UnrealSpace.position(Vector3(
		(cell.x - half_width) * _cell_size_cm,
		(cell.y - half_height) * _cell_size_cm,
		_heights_cm[cell_state] * 0.5))


func _clamp_from_tuning() -> void:
	var width := clampi(tuning.grid_width, 1, TerrainTuning.MAX_CELLS)
	var height := clampi(tuning.grid_height, 1, TerrainTuning.MAX_CELLS)
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


func _update_cell_presentation(cell: Vector2i) -> void:
	if state.is_valid(cell):
		_apply_presentation(cell, true)


## Colore lineare della cella nel suo stato.
func _cell_color(cell: Vector2i, cell_state: TerrainState.CellState) -> Color:
	if state.is_protected(cell):
		return PROTECTED_COLOR
	if cell_state == TerrainState.CellState.LOWERED:
		return LOWERED_COLOR
	if cell_state == TerrainState.CellState.RAISED:
		var index := cell.y * state.width + cell.x
		if _raised_tints.has(index):
			return _raised_tints[index]
		return RAISED_COLOR if raised_color_override.a <= 0.0 else raised_color_override
	return NORMAL_COLOR


func _apply_presentation(cell: Vector2i, deferred: bool) -> void:
	var cell_state := state.get_state(cell)
	var index := cell.y * state.width + cell.x
	var tint: float = NATURAL_PROTECTED_TINT if state.is_protected(cell) else NATURAL_STATE_TINT[cell_state]
	var own_batch := RAISED_BATCH if cell_state == TerrainState.CellState.RAISED else FLAT_BATCH
	for batch_state: int in _batches:
		var multimesh := _batches[batch_state].multimesh
		if batch_state != own_batch:
			multimesh.set_instance_transform(index, HIDDEN_TRANSFORM)
			continue
		var basis := Basis()
		if batch_state == FLAT_BATCH:
			basis = basis.scaled(Vector3(1.0, UnrealSpace.length(_heights_cm[cell_state]), 1.0))
		multimesh.set_instance_transform(index, Transform3D(basis, cell_local_position(cell, cell_state)))
		multimesh.set_instance_color(index, _cell_color(cell, cell_state))
		multimesh.set_instance_custom_data(index, Color(1.0 if natural_ground else 0.0, tint, 0.0, 0.0))

	# Collisione coerente con la geometria visibile: solo Raised blocca.
	# A runtime e differita (un comando puo arrivare durante una query fisica);
	# in costruzione e immediata, o la cella spingerebbe via chi ci sta sopra.
	var raised := cell_state == TerrainState.CellState.RAISED
	var collision: CollisionShape3D = _raised_shapes.get(index)
	if collision == null:
		if not raised:
			return
		collision = CollisionShape3D.new()
		collision.name = "Raised_%d_%d" % [cell.x, cell.y]
		collision.shape = _shapes[TerrainState.CellState.RAISED]
		collision.position = cell_local_position(cell, TerrainState.CellState.RAISED)
		collision.disabled = true
		_raised_body_for(cell).add_child(collision)
		_raised_shapes[index] = collision
	if deferred:
		collision.set_deferred(&"disabled", not raised)
	else:
		collision.disabled = not raised


## Il rialzo della cella intersecherebbe il volume collidente di chi lo richiede?
## Vero se un terrapieno su [param cell] intersecherebbe il volume di [param body]
## (per chi alza celle fuori dal tool: terremoto, D-075).
func raise_overlaps(cell: Vector2i, body: Node3D) -> bool:
	return _would_raise_overlap(cell, body)


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
