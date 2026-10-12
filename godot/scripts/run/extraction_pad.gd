class_name ExtractionPad
extends Node3D
## La piazzola di estrazione (D-076, idea 3 di FEATURE_IDEAS.md): battuto il boss il
## livello non finisce subito. Il mezzo di estrazione atterra solo su una piazzola piana
## attorno al giocatore (sul rilievo continuo, D-085: un **disco di `radius_m`** con
## dislivello sotto `tolerance_m`; sulla griglia: un **3x3 di celle Normal**), tenuta
## **integra e occupata per `hold_seconds`** mentre l'orda continua ad arrivare. La
## piazzola segue il giocatore: e lui a scegliere dove, spianando con il tool. Se il suolo
## cambia o il giocatore si sposta su un punto non piano, il conto riparte.
##
## A terra un anello (rilievo) o una lastra traslucida (griglia) mostra la piazzola: verde
## quando e integra, rosso quando no.
## Come il treno e il terremoto non ha un passo fisico proprio: `ArenaRun` lo fa avanzare.

signal extraction_started
signal pad_changed(intact: bool)
signal extraction_completed

const INTACT_COLOR := Color(0.25, 0.9, 0.55, 0.35)
const BROKEN_COLOR := Color(0.95, 0.3, 0.2, 0.35)
const LANDING_COLOR := Color(0.6, 0.85, 1.0)

@export var grid: TerrainGrid
## Rilievo continuo (D-085): con questo la piazzola e un disco piano.
@export var terrain_field: TerrainField
@export var player: PlayerCharacter
@export var hud: RunHud

## Secondi di piazzola integra e occupata prima dell'atterraggio; celle per lato oltre
## quella centrale (1 = 3x3).
var hold_seconds := 8.0
var radius_cells := 1
## Rilievo: raggio del disco e dislivello massimo ammesso dentro.
var radius_m := 3.0
var tolerance_m := 0.35

var active := false
var intact := false
var held := 0.0
var center := Vector2i(-1, -1)
## Rilievo: centro del disco (sotto il giocatore).
var center_point := Vector3.ZERO
var _marker: MeshInstance3D
var _material: StandardMaterial3D
var _ring: BrushPreview


func is_active() -> bool:
	return active


## Le celle del 3x3 attorno a [param cell].
func pad_cells(cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy in range(-radius_cells, radius_cells + 1):
		for dx in range(-radius_cells, radius_cells + 1):
			cells.append(cell + Vector2i(dx, dy))
	return cells


## Vero se tutte le celle del 3x3 attorno a [param cell] sono nella griglia e Normal.
func is_flat(cell: Vector2i) -> bool:
	for c in pad_cells(cell):
		if not grid.state.is_valid(c) or grid.state.get_state(c) != TerrainState.CellState.NORMAL:
			return false
	return true


## Rilievo: il disco attorno a [param point] e piano entro la tolleranza.
func is_flat_at(point: Vector3) -> bool:
	return terrain_field != null and terrain_field.is_flat(point, radius_m, tolerance_m)


func begin() -> void:
	active = true
	held = 0.0
	intact = false
	center = Vector2i(-1, -1)
	if terrain_field != null:
		_ensure_ring()
	elif grid != null:
		_ensure_marker()
	print("PROTOTYPE01_EXTRACTION_CALLED hold=%.1f" % hold_seconds)
	extraction_started.emit()


## Un passo, dal tempo di livello.
func advance(delta: float) -> void:
	if not active or (grid == null and terrain_field == null) or player == null:
		return
	var now := false
	if terrain_field != null:
		center_point = Vector3(player.global_position.x, 0.0, player.global_position.z)
		now = is_flat_at(center_point)
	else:
		center = grid.cell_at(player.global_position)
		now = is_flat(center)
	if now != intact:
		intact = now
		if not intact:
			held = 0.0
		pad_changed.emit(intact)
	if intact:
		held += delta
	_update_marker()
	if hud != null:
		if intact:
			hud.set_event_warning("ESTRAZIONE: TIENI LA PIAZZOLA", Vector3.FORWARD, hold_seconds - held,
				RunHud.EXTRACTION_COLOR, false)
		else:
			var hint := "ESTRAZIONE: SPIANA UN DISCO DI %d M" % int(round(radius_m * 2.0)) if terrain_field != null else "ESTRAZIONE: SPIANA 3 X 3"
			hud.set_event_warning(hint, Vector3.FORWARD, hold_seconds, RunHud.EXTRACTION_COLOR, false)
	if held >= hold_seconds:
		_complete()


func _complete() -> void:
	active = false
	if hud != null:
		hud.clear_event_warning()
	if terrain_field != null:
		var at := Vector3(center_point.x, terrain_field.height_at(center_point), center_point.z)
		DebrisBurst.spawn(get_parent(), at + Vector3(0.0, 0.5, 0.0), LANDING_COLOR, 24, 6.0, 0.16)
		if _ring != null:
			_ring.hide_ring()
		print("PROTOTYPE01_EXTRACTION_DONE x=%.1f z=%.1f" % [at.x, at.z])
	else:
		var at := _cell_center(center)
		DebrisBurst.spawn(get_parent(), at + Vector3(0.0, 0.5, 0.0), LANDING_COLOR, 24, 6.0, 0.16)
		if _marker != null:
			_marker.visible = false
		print("PROTOTYPE01_EXTRACTION_DONE X=%d Y=%d" % [center.x, center.y])
	extraction_completed.emit()


func _ensure_marker() -> void:
	if _marker != null:
		_marker.visible = true
		return
	var side := grid.cell_size_m() * (radius_cells * 2 + 1) - 0.1
	var mesh := BoxMesh.new()
	mesh.size = Vector3(side, 0.05, side)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = BROKEN_COLOR
	_marker = MeshInstance3D.new()
	_marker.mesh = mesh
	_marker.material_override = _material
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.top_level = true
	add_child(_marker)


func _ensure_ring() -> void:
	if _ring == null:
		_ring = BrushPreview.new()
		_ring.name = "PadRing"
		add_child(_ring)


func _update_marker() -> void:
	if terrain_field != null:
		if _ring != null:
			var at := Vector3(center_point.x, terrain_field.height_at(center_point) + 0.5, center_point.z)
			_ring.show_ring(at, radius_m, INTACT_COLOR if intact else BROKEN_COLOR)
		return
	if _marker == null or not grid.state.is_valid(center):
		return
	_material.albedo_color = INTACT_COLOR if intact else BROKEN_COLOR
	var surface := grid.to_global(grid.cell_local_position(center, TerrainState.CellState.NORMAL))
	_marker.global_position = Vector3(surface.x, surface.y + grid.cell_size_m() * 0.0 + 0.04, surface.z)


func _cell_center(cell: Vector2i) -> Vector3:
	var p := grid.to_global(grid.cell_local_position(cell, TerrainState.CellState.NORMAL))
	return Vector3(p.x, 0.0, p.z)
