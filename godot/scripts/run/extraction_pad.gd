class_name ExtractionPad
extends Node3D
## La piazzola di estrazione (D-076, idea 3 di FEATURE_IDEAS.md): battuto il boss il
## livello non finisce subito. Il mezzo di estrazione atterra solo su una **piazzola
## 3x3 di celle Normal** (ne muri ne trincee) attorno al giocatore, tenuta **integra e
## occupata per `hold_seconds`** mentre l'orda continua ad arrivare. La piazzola segue il
## giocatore: e lui a scegliere dove, spianando con il tool. Se una cella cambia o il
## giocatore si sposta su un 3x3 non piano, il conto riparte.
##
## A terra una lastra traslucida mostra il 3x3: verde quando e integro, rosso quando no.
## Come il treno e il terremoto non ha un passo fisico proprio: `ArenaRun` lo fa avanzare.

signal extraction_started
signal pad_changed(intact: bool)
signal extraction_completed

const INTACT_COLOR := Color(0.25, 0.9, 0.55, 0.35)
const BROKEN_COLOR := Color(0.95, 0.3, 0.2, 0.35)
const LANDING_COLOR := Color(0.6, 0.85, 1.0)

@export var grid: TerrainGrid
@export var player: PlayerCharacter
@export var hud: RunHud

## Secondi di piazzola integra e occupata prima dell'atterraggio; celle per lato oltre
## quella centrale (1 = 3x3).
var hold_seconds := 8.0
var radius_cells := 1

var active := false
var intact := false
var held := 0.0
var center := Vector2i(-1, -1)
var _marker: MeshInstance3D
var _material: StandardMaterial3D


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


func begin() -> void:
	active = true
	held = 0.0
	intact = false
	center = Vector2i(-1, -1)
	# Ponte fino al Task 12 del terreno continuo: senza griglia la piazzola non ha ancora
	# una forma sul rilievo (niente marker, `advance` non fa nulla).
	if grid != null:
		_ensure_marker()
	print("PROTOTYPE01_EXTRACTION_CALLED hold=%.1f" % hold_seconds)
	extraction_started.emit()


## Un passo, dal tempo di livello.
func advance(delta: float) -> void:
	if not active or grid == null or player == null:
		return
	center = grid.cell_at(player.global_position)
	var now := is_flat(center)
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
			hud.set_event_warning("ESTRAZIONE: SPIANA 3 X 3", Vector3.FORWARD, hold_seconds, RunHud.EXTRACTION_COLOR, false)
	if held >= hold_seconds:
		_complete()


func _complete() -> void:
	active = false
	if hud != null:
		hud.clear_event_warning()
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


func _update_marker() -> void:
	if _marker == null or not grid.state.is_valid(center):
		return
	_material.albedo_color = INTACT_COLOR if intact else BROKEN_COLOR
	var surface := grid.to_global(grid.cell_local_position(center, TerrainState.CellState.NORMAL))
	_marker.global_position = Vector3(surface.x, surface.y + grid.cell_size_m() * 0.0 + 0.04, surface.z)


func _cell_center(cell: Vector2i) -> Vector3:
	var p := grid.to_global(grid.cell_local_position(cell, TerrainState.CellState.NORMAL))
	return Vector3(p.x, 0.0, p.z)
