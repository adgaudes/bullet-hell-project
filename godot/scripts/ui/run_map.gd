class_name RunMap
extends RefCounted
## Mappa di fine livello (D-052, idea 7 di FEATURE_IDEAS): l'arena come l'ha
## scolpita il giocatore, disegnata dai delta di quota del rilievo continuo (D-085,
## `render_heights`) o dallo stato della griglia (ferrovia, `render`). Logica pura:
## produce un'immagine, non tocca nodi. Nord (-Z) in alto, est (+X) a destra.

## Lato massimo dell'immagine, in pixel, e pixel minimi per cella.
const TARGET_SIZE := 340
const MIN_CELL_PIXELS := 4
## Celle di margine attorno a cio che e successo, e lato minimo della vista.
const PADDING_CELLS := 4
const MIN_SIDE_CELLS := 25
## Rilievo continuo: passo del campionamento (meta del pennello del giocatore, cosi un
## cumulo di un metro si vede sempre), pixel minimi per campione e dislivello da cui un
## punto conta come alzato o scavato.
const HEIGHT_STEP_M := 1.2
const MIN_SAMPLE_PIXELS := 2
const HEIGHT_THRESHOLD_M := 0.4
const BARRICADE_MATCH_M := 1.5

const GROUND := Color(0.15, 0.2, 0.11)
const WALL_INITIAL := Color(0.5, 0.42, 0.3)
const TRENCH_INITIAL := Color(0.24, 0.3, 0.33)
const BUILDING := Color(0.38, 0.38, 0.4)
## Fatti dal giocatore (o dal boss): terrapieno, fossato, breccia in un muro.
const WALL_NEW := Color(1.0, 0.8, 0.3)
const TRENCH_NEW := Color(0.2, 0.8, 0.95)
const BREACH := Color(0.8, 0.32, 0.2)
const BARRICADE := Color(0.62, 0.3, 0.75)
const START_MARK := Color(1.0, 1.0, 1.0, 0.55)
const END_MARK := Color(1.0, 1.0, 1.0)
const BOSS_MARK := Color(1.0, 0.15, 0.1)
const LAMP_MARK := Color(1.0, 0.95, 0.6)


## Stato di ogni cella, in ordine di indice (Y * width + X): la fotografia da
## confrontare a fine livello.
static func snapshot(state: TerrainState) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(state.cell_count())
	for y in state.height:
		for x in state.width:
			result[y * state.width + x] = state.get_state(Vector2i(x, y))
	return result


## Celle il cui stato e diverso dalla fotografia iniziale.
static func changed_cells(state: TerrainState, initial: PackedByteArray) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in state.height:
		for x in state.width:
			var cell := Vector2i(x, y)
			if state.get_state(cell) != initial[y * state.width + x]:
				result.append(cell)
	return result


## Uguali entro l'arrotondamento a 8 bit dell'immagine.
static func same_color(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


## Colore di una cella sulla mappa.
static func cell_color(now: TerrainState.CellState, before: TerrainState.CellState, is_barricade: bool) -> Color:
	if is_barricade:
		return BARRICADE
	if now == before:
		match now:
			TerrainState.CellState.RAISED:
				return WALL_INITIAL
			TerrainState.CellState.LOWERED:
				return TRENCH_INITIAL
		return GROUND
	match now:
		TerrainState.CellState.RAISED:
			return WALL_NEW
		TerrainState.CellState.LOWERED:
			return TRENCH_NEW
	# Tornata Normal: era un muro (breccia) oppure un fossato richiuso.
	return BREACH if before == TerrainState.CellState.RAISED else GROUND


## Rilievo continuo: colore di un punto dal suo dislivello rispetto a inizio livello;
## [param initial_delta] e quanto il punto sporgeva gia dalla base a inizio livello
## (argini, cumuli e solchi del quartiere), mostrato dove il giocatore non ha toccato.
static func height_color(delta: float, is_barricade: bool, initial_delta := 0.0) -> Color:
	if is_barricade:
		return BARRICADE
	if delta > HEIGHT_THRESHOLD_M:
		return WALL_NEW
	if delta < -HEIGHT_THRESHOLD_M:
		return TRENCH_NEW
	if initial_delta > HEIGHT_THRESHOLD_M:
		return WALL_INITIAL
	if initial_delta < -HEIGHT_THRESHOLD_M:
		return TRENCH_INITIAL
	return GROUND


## Lato in campioni del rilievo a passo [param step_m].
static func height_samples(field: TerrainField, step_m := HEIGHT_STEP_M) -> int:
	return int(round(field.half_extent() * 2.0 / step_m)) + 1


## Mondo (XZ) del campione (colonna, riga): colonna cresce verso est, riga verso sud.
static func sample_world(field: TerrainField, sample: Vector2i, step_m := HEIGHT_STEP_M) -> Vector3:
	var half := field.half_extent()
	return Vector3(-half + sample.x * step_m, 0.0, -half + sample.y * step_m)


## Quote del rilievo campionate a passo [param step_m] (riga * n + colonna): la
## fotografia da confrontare a fine livello.
static func snapshot_heights(field: TerrainField, step_m := HEIGHT_STEP_M) -> PackedFloat32Array:
	var n := height_samples(field, step_m)
	var result := PackedFloat32Array()
	result.resize(n * n)
	for row in n:
		for column in n:
			result[row * n + column] = field.height_at(sample_world(field, Vector2i(column, row), step_m))
	return result


## Disegna la mappa del rilievo. [param initial]: fotografia di `snapshot_heights()`;
## [param barricades]: centri delle barricate del boss; [param buildings]: rettangoli
## mondo XZ degli edifici; [param start], [param end]: posizioni mondo del giocatore;
## [param boss]: posizione mondo del boss, o null; [param lamps]: basi dei lampioni.
static func render_heights(field: TerrainField, initial: PackedFloat32Array, barricades: Array[Vector3],
		buildings: Array[Rect2], start: Vector3, end: Vector3, boss: Variant = null, lamps: Array[Vector3] = [],
		step_m := HEIGHT_STEP_M) -> Image:
	var n := height_samples(field, step_m)
	var size := Vector2i(n, n)
	var full := Image.create(n, n, false, Image.FORMAT_RGBA8)
	full.fill(GROUND)
	var points: Array[Vector2i] = []
	for row in n:
		for column in n:
			var pixel := Vector2i(column, row)
			var world := sample_world(field, pixel, step_m)
			var i := row * n + column
			var before: float = initial[i] if i < initial.size() else field.height_at(world)
			var delta := field.height_at(world) - before
			var near_barricade := false
			for b in barricades:
				if Vector2(b.x - world.x, b.z - world.z).length() <= BARRICADE_MATCH_M + step_m * 0.5:
					near_barricade = true
					break
			full.set_pixelv(pixel, height_color(delta, near_barricade, before - field.base_height_at(world)))
			if absf(delta) > HEIGHT_THRESHOLD_M or near_barricade:
				points.append(pixel)
	for rect in buildings:
		var from := _sample_at(field, Vector3(rect.position.x, 0.0, rect.position.y), size, step_m)
		var to := _sample_at(field, Vector3(rect.end.x, 0.0, rect.end.y), size, step_m)
		for py in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
			for px in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
				if same_color(full.get_pixel(px, py), GROUND):
					full.set_pixel(px, py, BUILDING)
	var start_pixel := _sample_at(field, start, size, step_m)
	var end_pixel := _sample_at(field, end, size, step_m)
	points.append(start_pixel)
	points.append(end_pixel)
	for lamp in lamps:
		points.append(_sample_at(field, lamp, size, step_m))
	var view := view_rect(size, points)
	var scale := maxi(TARGET_SIZE / view.size.x, MIN_SAMPLE_PIXELS)
	var image := full.get_region(view)
	image.resize(view.size.x * scale, view.size.y * scale, Image.INTERPOLATE_NEAREST)
	_mark(image, (start_pixel - view.position) * scale, scale, START_MARK, true)
	if boss != null:
		_mark(image, (_sample_at(field, boss, size, step_m) - view.position) * scale, scale, BOSS_MARK, false)
	for lamp in lamps:
		_mark(image, (_sample_at(field, lamp, size, step_m) - view.position) * scale, scale, LAMP_MARK, true)
	_mark(image, (end_pixel - view.position) * scale, scale, END_MARK, false)
	return image


## Campione (colonna, riga) piu vicino a un punto del mondo, dentro la mappa.
static func _sample_at(field: TerrainField, world: Vector3, size: Vector2i, step_m: float) -> Vector2i:
	var half := field.half_extent()
	return Vector2i(
		clampi(roundi((world.x + half) / step_m), 0, size.x - 1),
		clampi(roundi((world.z + half) / step_m), 0, size.y - 1))


## Riquadro quadrato di celle (pixel della mappa intera) che contiene le celle
## cambiate e i punti dati, col margine; mai piu piccolo di MIN_SIDE_CELLS.
static func view_rect(size: Vector2i, points: Array[Vector2i]) -> Rect2i:
	if points.is_empty():
		points = [size / 2]
	var lo := points[0]
	var hi := points[0]
	for point in points:
		lo = Vector2i(mini(lo.x, point.x), mini(lo.y, point.y))
		hi = Vector2i(maxi(hi.x, point.x), maxi(hi.y, point.y))
	var side := maxi(maxi(hi.x - lo.x, hi.y - lo.y) + 1 + PADDING_CELLS * 2, MIN_SIDE_CELLS)
	side = mini(side, mini(size.x, size.y))
	var center := (lo + hi) / 2
	var origin := Vector2i(
		clampi(center.x - side / 2, 0, size.x - side),
		clampi(center.y - side / 2, 0, size.y - side))
	return Rect2i(origin, Vector2i(side, side))


## Disegna la mappa. [param initial]: fotografia di `snapshot()` a inizio livello;
## [param barricades]: celle delle barricate del boss; [param buildings]: rettangoli
## mondo XZ degli edifici; [param start], [param end]: posizioni mondo del giocatore;
## [param boss]: posizione mondo del boss, o null.
static func render(grid: TerrainGrid, initial: PackedByteArray, barricades: Dictionary,
		buildings: Array[Rect2], start: Vector3, end: Vector3, boss: Variant = null, lamps: Array[Vector2i] = []) -> Image:
	var state := grid.state
	var size := Vector2i(state.width, state.height)
	# Un pixel per cella, in coordinate mondo: colonna = X mondo, riga = Z mondo.
	var full := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	full.fill(GROUND)
	var points: Array[Vector2i] = []
	for y in state.height:
		for x in state.width:
			var cell := Vector2i(x, y)
			var now := state.get_state(cell)
			var before := initial[y * state.width + x] as TerrainState.CellState
			var pixel := _pixel_of(grid, cell, size)
			full.set_pixelv(pixel, cell_color(now, before, barricades.has(cell)))
			if now != before or barricades.has(cell):
				points.append(pixel)
	for rect in buildings:
		var from := _pixel_at(grid, Vector3(rect.position.x, 0.0, rect.position.y), size)
		var to := _pixel_at(grid, Vector3(rect.end.x, 0.0, rect.end.y), size)
		for py in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
			for px in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
				if same_color(full.get_pixel(px, py), GROUND):
					full.set_pixel(px, py, BUILDING)
	var start_pixel := _pixel_at(grid, start, size)
	var end_pixel := _pixel_at(grid, end, size)
	points.append(start_pixel)
	points.append(end_pixel)
	for lamp in lamps:
		points.append(_pixel_of(grid, lamp, size))
	var view := view_rect(size, points)
	var scale := maxi(TARGET_SIZE / view.size.x, MIN_CELL_PIXELS)
	var image := full.get_region(view)
	image.resize(view.size.x * scale, view.size.y * scale, Image.INTERPOLATE_NEAREST)
	_mark(image, (start_pixel - view.position) * scale, scale, START_MARK, true)
	if boss != null:
		_mark(image, (_pixel_at(grid, boss, size) - view.position) * scale, scale, BOSS_MARK, false)
	for lamp in lamps:
		_mark(image, (_pixel_of(grid, lamp, size) - view.position) * scale, scale, LAMP_MARK, true)
	_mark(image, (end_pixel - view.position) * scale, scale, END_MARK, false)
	return image


## Pixel (colonna, riga) della cella: colonna cresce verso est, riga verso sud.
static func _pixel_of(grid: TerrainGrid, cell: Vector2i, size: Vector2i) -> Vector2i:
	return _pixel_at(grid, grid.to_global(grid.cell_local_position(cell, TerrainState.CellState.NORMAL)), size)


static func _pixel_at(grid: TerrainGrid, world: Vector3, size: Vector2i) -> Vector2i:
	var local := grid.to_local(world)
	var step := grid.cell_size_m()
	return Vector2i(
		clampi(roundi(local.x / step + (size.x - 1) * 0.5), 0, size.x - 1),
		clampi(roundi(local.z / step + (size.y - 1) * 0.5), 0, size.y - 1))


## Segno quadrato pieno, o solo il bordo, centrato sulla cella.
static func _mark(image: Image, top_left: Vector2i, scale: int, color: Color, hollow: bool) -> void:
	var grow := maxi(scale / 4, 1)
	var from := top_left - Vector2i(grow, grow)
	var to := top_left + Vector2i(scale + grow, scale + grow)
	for y in range(from.y, to.y):
		for x in range(from.x, to.x):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var edge := x == from.x or y == from.y or x == to.x - 1 or y == to.y - 1
			if hollow and not edge:
				continue
			image.set_pixel(x, y, image.get_pixel(x, y).blend(color))
