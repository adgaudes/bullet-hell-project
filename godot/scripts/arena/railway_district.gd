@tool
class_name RailwayDistrict
extends RuinsDistrict
## Livello 2, la ferrovia (D-066, docs/RAILWAY_LEVEL_SPEC.md): un corridoio
## rettangolare lungo X (est-ovest) e stretto in Z, attraversato per tutta la
## lunghezza da una **fascia di binari** di tre righe di celle attorno a z = 0.
##
## La fascia e riservata: niente rovine, oggetti ne cortili sopra; le celle
## restano Normal, salvo i **vagoni** (depositi di rottami sui binari) che il
## treno spazza via. Il cortile di partenza sta a cavallo dei binari: i suoi
## varchi est e ovest sono larghi quanto la fascia. Stessi mattoni del
## quartiere (RuinsDistrict), pianta e perimetro diversi: torri a nord, bordo
## basso a sud, un portale di galleria a ciascuna estremita da cui entra il treno.

## Righe di celle per lato attorno alla riga centrale (3 righe in tutto).
const TRACK_HALF_ROWS := 1
## Quota Z dei due binari (celle -1 e +1 in assi Unreal).
const TRACK_Z: Array[float] = [-CELL, CELL]
## Scartamento visivo delle rotaie (metri) e passo delle traversine.
const RAIL_GAUGE := 1.44
const SLEEPER_PITCH := 0.9
## Colore (lineare) delle celle dei vagoni: ruggine, come i rottami.
const WAGON_TINT := Color(0.55, 0.22, 0.06)
## Portali di galleria alle estremita: quanto sporgono oltre l'area giocabile.
const PORTAL_DEPTH := 8.0

@export_group("Railway")
## Vagoni abbandonati sui binari: blocchi Raised 2x3 celle che rendono rottami.
@export_range(0, 12) var wagon_count := 5:
	set(value):
		wagon_count = value
		_queue_rebuild()
## Distanza minima fra due vagoni lungo i binari.
@export var wagon_spacing := 24.0:
	set(value):
		wagon_spacing = value
		_queue_rebuild()


func _init() -> void:
	super()
	# 133 x 51 celle di 2,4 m: 319,2 x 122,4 m.
	play_half_extent = 159.6
	play_half_extent_z = 61.2
	# Lotti piu fitti: il corridoio ha meno righe di lotti del quartiere.
	lot_size = 16.0
	courtyard_count = 4
	deposit_count = 6
	trench_count = 4
	car_count = 16
	rubble_count = 16
	barrier_count = 14
	lamp_count = 12
	tree_count = 30
	bush_count = 50


# --- Geometria della fascia ----------------------------------------------------------

## Mezza larghezza della fascia dei binari, in metri (3 celle: 3,6 m).
static func track_half_width() -> float:
	return (TRACK_HALF_ROWS + 0.5) * CELL


## Il punto (mondo XZ) sta sulla fascia dei binari?
static func is_on_tracks(p: Vector2) -> bool:
	return absf(p.y) <= track_half_width()


## Tutte le celle della fascia, da ovest a est, riga per riga (assi Unreal).
static func track_cells(grid: TerrainGrid) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var center := grid.cell_at(Vector3.ZERO)
	for y in grid.state.height:
		for dx in range(-TRACK_HALF_ROWS, TRACK_HALF_ROWS + 1):
			cells.append(Vector2i(center.x + dx, y))
	return cells


# --- Composizione ----------------------------------------------------------------------

func _compose() -> void:
	terrain_features.clear()
	_reset_occupancy()
	stats["features"] = 0
	stats["wagons"] = 0
	_build_ground()
	_build_boundary()
	_reserve_tracks()
	_plan_start_courtyard()
	_plan_wagons()
	_plan_courtyards()
	_plan_deposits()
	_plan_trenches()
	_build_tracks()
	_reset_ruin_details()
	_build_blocks()
	_build_props()
	_build_perimeter()
	_build_ruin_details()
	_build_ground_cover()
	_add_sun()
	_add_environment()


## La fascia dei binari, con un margine di una cella, non ospita nulla (nemmeno
## un oggetto il cui ingombro sporga sulla fascia).
func _reserve_tracks() -> void:
	var half := track_half_width() + CELL
	_reserve(Rect2(-half_x(), -half, half_x() * 2.0, half * 2.0))


## Cortile di partenza a cavallo dei binari: l'anello perde le celle sulla fascia,
## cosi i varchi est e ovest coincidono con i binari e il treno passa senza toccare mura.
func _plan_start_courtyard() -> void:
	var r := start_courtyard_radius
	var gates: Array[int] = [0, 1, 2, 3]
	var offsets: Array[Vector2i] = []
	for offset in _ring_offsets(r, gates):
		if absi(offset.x) > TRACK_HALF_ROWS:
			offsets.append(offset)
	var half := Vector2.ONE * (r + 0.5) * CELL
	_add_feature(&"start", Vector2.ZERO, TerrainState.CellState.RAISED, offsets, gates, r, half, 2.0)
	_reserve(_rect_around(Vector2.ZERO, Vector2.ONE * start_clear_radius))


## Vagoni merci sui binari: blocchi Raised di 2 righe (binario e massicciata) per
## 3 celle lungo la linea, lontani dalla partenza e fra loro. Rendono rottami come
## i depositi, ma il treno li spazza via senza lasciarne.
func _plan_wagons() -> void:
	var placed: Array[float] = []
	var limit := half_x() - 12.0
	for i in wagon_count:
		var x := 0.0
		var found := false
		for attempt in 40:
			x = _rng.randf_range(-limit, limit)
			if absf(x) < start_clear_radius + 8.0:
				continue
			var far := true
			for other in placed:
				if absf(other - x) < wagon_spacing:
					far = false
					break
			if far:
				found = true
				break
		if not found:
			continue
		placed.append(x)
		# Binario nord (z = -2,4: dx = +1) o sud (z = +2,4: dx = -1), piu la riga centrale.
		var rows: Array[int] = [0, 1]
		if _rng.randf() < 0.5:
			rows = [-1, 0]
		var offsets: Array[Vector2i] = []
		for dx in rows:
			for dy in range(-1, 2):
				offsets.append(Vector2i(dx, dy))
		var center := snap_to_cell(Vector2(x, 0.0))
		terrain_features.append({
			kind = &"wagon", center = center, state = TerrainState.CellState.RAISED, offsets = offsets,
			gates = [], radius = 2, tint = WAGON_TINT, marker = feature_centroid(center, offsets),
		})
		stats.features += 1
		stats.wagons += 1


## Trincee parallele ai binari (canali di scolo), mai di traverso.
func _plan_trenches() -> void:
	for i in trench_count:
		var length := _rng.randi_range(6, 14)
		var half := Vector2(length * CELL * 0.5, 1.0)
		var spot: Variant = _find_free_spot(half, 2.0, start_clear_radius + 4.0)
		if spot == null:
			continue
		var center := snap_to_cell(spot)
		var offsets: Array[Vector2i] = []
		var lo := -(length / 2)
		for k in range(lo, lo + length):
			offsets.append(Vector2i(0, k))
		_add_feature(&"trench", center, TerrainState.CellState.LOWERED, offsets, [], length, half, 2.0)


## Massicciata, rotaie e traversine: solo mesh, nessuna collisione. Sporgono oltre
## il perimetro fino dentro i portali.
func _build_tracks() -> void:
	var tracks := Node3D.new()
	tracks.name = "Tracks"
	_add_generated(tracks)
	var length := half_x() * 2.0 + PORTAL_DEPTH * 2.0 + 8.0
	var ballast := StandardMaterial3D.new()
	ballast.albedo_color = Color(0.32, 0.30, 0.27)
	ballast.roughness = 0.95
	_mesh_child(tracks, _box(Vector3(length, 0.05, track_half_width() * 2.0 - 0.4)), ballast,
		Transform3D(Basis(), Vector3(0.0, 0.14, 0.0)))
	var rail_mesh := _box(Vector3(length, 0.14, 0.08))
	var sleeper_mesh := _box(Vector3(0.24, 0.1, 2.2))
	var sleepers := MultiMesh.new()
	sleepers.transform_format = MultiMesh.TRANSFORM_3D
	sleepers.mesh = sleeper_mesh
	var per_track := int(length / SLEEPER_PITCH)
	sleepers.instance_count = per_track * TRACK_Z.size()
	var index := 0
	for z in TRACK_Z:
		for side: float in [-RAIL_GAUGE * 0.5, RAIL_GAUGE * 0.5]:
			var rail := _mesh_child(tracks, rail_mesh, _rust_material, Transform3D(Basis(), Vector3(0.0, 0.29, z + side)))
			rail.set_instance_shader_parameter(&"paint", Color(0.36, 0.34, 0.33))
			rail.set_instance_shader_parameter(&"rust", 0.5)
			rail.set_instance_shader_parameter(&"overgrowth", 0.1)
		for i in per_track:
			var x := -length * 0.5 + (i + 0.5) * SLEEPER_PITCH
			sleepers.set_instance_transform(index, Transform3D(Basis(), Vector3(x, 0.21, z)))
			index += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Sleepers"
	mmi.multimesh = sleepers
	mmi.material_override = _trunk_material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tracks.add_child(mmi)


## Perimetro: torri a nord, bordo basso a sud, portali di galleria alle estremita.
func _build_perimeter() -> void:
	_build_north_towers()
	_build_portals()
	_build_south_edge()


## Alle due estremita della linea: due piloni di cemento ai lati della fascia e un
## architrave sopra, cosi il treno entra ed esce da una bocca scura.
func _build_portals() -> void:
	var ex := half_x()
	var ez := half_z()
	var gap := track_half_width() + 1.6
	for side: float in [-1.0, 1.0]:
		var x := side * (ex + PORTAL_DEPTH)
		var label := "East" if side > 0.0 else "West"
		for pier: float in [-1.0, 1.0]:
			var depth := 14.0
			_tower("%sPortal%s" % [label, "N" if pier < 0.0 else "S"],
				Vector2(x, pier * (gap + depth * 0.5)), Vector2(PORTAL_DEPTH * 2.0 - 2.0, depth), 12.0, 0.6, false)
		_ruin_block("%sPortalLintel" % label, Vector3(x, 8.0, 0.0), Vector3(PORTAL_DEPTH * 2.0 - 2.0, 4.0, gap * 2.0),
			0.0, _pick(CONCRETE_TINTS), 0.7, 0.0, false)
		# Il resto del lato corto: edifici medi sopra e sotto il portale.
		var z := gap + 14.0 + 6.0
		var index := 0
		while z < ez - 6.0:
			var footprint := Vector2(_rng.randf_range(10.0, 14.0), _rng.randf_range(10.0, 16.0))
			for pier: float in [-1.0, 1.0]:
				_tower("%sBlock%d%s" % [label, index, "N" if pier < 0.0 else "S"],
					Vector2(side * (ex + 9.0 + footprint.x * 0.5), pier * (z + footprint.y * 0.5)), footprint,
					_rng.randf_range(10.0, 22.0), _rng.randf_range(0.6, 0.9))
			z += footprint.y + _rng.randf_range(8.0, 18.0)
			index += 1
