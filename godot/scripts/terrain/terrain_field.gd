class_name TerrainField
extends Node3D
## Rilievo continuo del livello (D-082, D-085). Le quote vivono in `_heights` (un
## valore ogni SPACING metri, origine al centro, sorgente di verita anche in headless);
## il nodo Terrain3D, se c'e, le rispecchia per la resa. Nessun altro script parla con
## Terrain3D: tutto passa da qui. Scrive solo `sculpt`/`level`; chi vuole reagire a un
## cambio si collega a `region_changed`. `player_sculpted` e per cio che dipende dal
## tool del giocatore (rottami, suoni, impronte, contatori).

signal region_changed(aabb: AABB)
## Terrain3D e pronto per colori e strati (solo con finestra, un fotogramma dopo `_ready`).
signal render_ready
signal player_sculpted(center: Vector3, radius: float, volume: float, mode: int)

enum ToolMode { DIG, RAISE, LEVEL, LAMP }

const SPACING := 0.5
const MIN_HEIGHT := -2.5
const MAX_HEIGHT := 4.0
const REGION_SIZE := 256
const SAVE_MAGIC := "TFLD"
const SAVE_VERSION := 2
const TOOL_MODE_NAMES: Array[String] = ["Dig", "Raise", "Level", "Lamp"]

@export var size_m := 204.0
@export var tuning: TerrainTuning
## Senza resa (test headless, benchmark) il nodo Terrain3D non viene creato.
@export var render := true

var resolution := 0
var volume_moved := 0.0
var _half := 0.0
var _heights := PackedFloat32Array()
var _base := PackedFloat32Array()
var _protected := PackedByteArray()
var _terrain: Terrain3D
var _terrain_ready := false
var _collision: TerrainCollision


func _ready() -> void:
	if tuning == null:
		tuning = TerrainTuning.new()
	resolution = int(round(size_m / SPACING)) + 1
	_half = (resolution - 1) * SPACING * 0.5
	_heights.resize(resolution * resolution)
	_heights.fill(0.0)
	_base = _heights.duplicate()
	_protected.resize(resolution * resolution)
	_protected.fill(0)
	_collision = TerrainCollision.new()
	_collision.name = "Collision"
	add_child(_collision)
	_collision.setup(self)
	if render and not DisplayServer.get_name() == "headless":
		_build_terrain3d()
	print("PROTOTYPE01_TERRAIN_FIELD_READY resolution=%d size_m=%.0f" % [resolution, size_m])


func half_extent() -> float:
	return _half


func terrain3d() -> Terrain3D:
	return _terrain if _terrain_ready else null


# --- Letture ---------------------------------------------------------------------------

func height_at(p: Vector3) -> float:
	return _sample(_heights, p)


func base_height_at(p: Vector3) -> float:
	return _sample(_base, p)


func delta_at(p: Vector3) -> float:
	return height_at(p) - base_height_at(p)


func normal_at(p: Vector3) -> Vector3:
	var dx := height_at(p + Vector3(SPACING, 0.0, 0.0)) - height_at(p - Vector3(SPACING, 0.0, 0.0))
	var dz := height_at(p + Vector3(0.0, 0.0, SPACING)) - height_at(p - Vector3(0.0, 0.0, SPACING))
	return Vector3(-dx, 2.0 * SPACING, -dz).normalized()


## Pendenza locale in metri di quota per metro (0 = piano).
func slope_at(p: Vector3) -> float:
	var n := normal_at(p)
	return Vector2(n.x, n.z).length() / maxf(n.y, 0.001)


## Dislivello per metro da [param a] a [param b], positivo in salita.
func grade_between(a: Vector3, b: Vector3) -> float:
	var run := Vector2(b.x - a.x, b.z - a.z).length()
	if run < 0.0001:
		return 0.0
	return (height_at(b) - height_at(a)) / run


## In discesa sempre; in salita solo se nessun tratto di SPACING supera [param max_grade].
func can_step(from: Vector3, to: Vector3, max_grade: float) -> bool:
	var run := Vector2(to.x - from.x, to.z - from.z).length()
	if run < 0.0001:
		return true
	var steps := maxi(int(ceil(run / SPACING)), 1)
	var previous := height_at(from)
	for i in range(1, steps + 1):
		var point := from.lerp(to, float(i) / steps)
		var h := height_at(point)
		if h - previous > max_grade * (run / steps):
			return false
		previous = h
	return true


## Vero se nel disco la differenza fra quota massima e minima resta sotto [param tolerance].
func is_flat(center: Vector3, radius: float, tolerance: float) -> bool:
	var lo := INF
	var hi := -INF
	for p in _disc_points(center, radius):
		var h := _heights[p]
		lo = minf(lo, h)
		hi = maxf(hi, h)
	return hi - lo <= tolerance


## Punto (Vector3 con quota) entro [param radius] con il maggior delta sopra [param min_delta], o null.
func highest_bump(center: Vector3, radius: float, min_delta: float) -> Variant:
	var best: Variant = null
	var best_delta := min_delta
	for p in _disc_points(center, radius):
		var d := _heights[p] - _base[p]
		if d > best_delta:
			best_delta = d
			best = _vertex_world(p)
	return best


func is_protected(p: Vector3) -> bool:
	var i := _index_of(p)
	return i >= 0 and _protected[i] != 0


func set_protected(center: Vector3, radius: float, on: bool) -> void:
	for p in _disc_points(center, radius):
		_protected[p] = 1 if on else 0


# --- Scritture -------------------------------------------------------------------------

## Pennello a campana: [param amount] metri al centro, zero sul bordo; negativo scava.
## Restituisce il volume spostato in m3, col segno; i pixel protetti non cambiano.
func sculpt(center: Vector3, radius: float, amount: float) -> float:
	return _brush(center, radius, func(h: float, falloff: float) -> float:
		return h + amount * falloff)


## Avvicina il disco a [param target]: strength 1 al centro lo porta esattamente li.
func level(center: Vector3, radius: float, target: float, strength: float) -> float:
	return _brush(center, radius, func(h: float, falloff: float) -> float:
		return h + (target - h) * clampf(strength * falloff, 0.0, 1.0))


func player_sculpt(center: Vector3, radius: float, amount: float, mode: int) -> float:
	var volume := sculpt(center, radius, amount)
	volume_moved += absf(volume)
	player_sculpted.emit(center, radius, volume, mode)
	return volume


func player_level(center: Vector3, radius: float, strength: float) -> float:
	var volume := level(center, radius, height_at(center), strength)
	volume_moved += absf(volume)
	player_sculpted.emit(center, radius, volume, ToolMode.LEVEL)
	return volume


## Livella del giocatore con la terra disponibile: se per alzare i dintorni servirebbero
## piu di [param max_raise_m3], la pennellata viene scalata (spec sezione 3: Livella
## scambia terra nei due versi, non la crea).
func player_level_budget(center: Vector3, radius: float, strength: float, max_raise_m3: float) -> float:
	var target := height_at(center)
	var needed := _raise_volume(center, radius, target, strength)
	if needed > max_raise_m3:
		strength *= maxf(max_raise_m3, 0.0) / needed
	if strength <= 0.0:
		return 0.0
	return player_level(center, radius, strength)


## Terra (m3) che `level` aggiungerebbe nel disco, senza scrivere.
func _raise_volume(center: Vector3, radius: float, target: float, strength: float) -> float:
	var raised := 0.0
	var r2 := radius * radius
	var x0 := maxi(int(floor((center.x - radius + _half) / SPACING)), 0)
	var x1 := mini(int(ceil((center.x + radius + _half) / SPACING)), resolution - 1)
	var z0 := maxi(int(floor((center.z - radius + _half) / SPACING)), 0)
	var z1 := mini(int(ceil((center.z + radius + _half) / SPACING)), resolution - 1)
	for iz in range(z0, z1 + 1):
		var wz := iz * SPACING - _half
		for ix in range(x0, x1 + 1):
			var wx := ix * SPACING - _half
			var d2 := ((wx - center.x) * (wx - center.x) + (wz - center.z) * (wz - center.z)) / r2
			if d2 >= 1.0:
				continue
			var i := iz * resolution + ix
			if _protected[i] != 0:
				continue
			var falloff := (1.0 - d2) * (1.0 - d2)
			var before := _heights[i]
			var after := clampf(before + (target - before) * clampf(strength * falloff, 0.0, 1.0), MIN_HEIGHT, MAX_HEIGHT)
			raised += maxf(after - before, 0.0) * SPACING * SPACING
	return raised


## Fissa il rilievo attuale come "naturale": delta e bump si misurano da qui.
func commit_base() -> void:
	_base = _heights.duplicate()
	if _terrain_ready:
		TerrainSurface.update_base(_terrain, _base, resolution, _half)


## Strato di tile (TerrainSurface.LAYER_*) sul control map di Terrain3D in un disco; niente in headless.
func paint_layer(center: Vector3, radius: float, layer: int) -> void:
	if not _terrain_ready:
		return
	var data := _terrain.data
	var pixel := Color(Terrain3DUtil.as_float(Terrain3DUtil.enc_base(layer)), 0.0, 0.0, 0.0)
	for p in _disc_points(center, radius):
		data.set_pixel(Terrain3DRegion.TYPE_CONTROL, _vertex_world(p), pixel)
	_mark_regions(center, radius)
	data.update_maps(Terrain3DRegion.TYPE_CONTROL, false)


## Pittura sul color map di Terrain3D (strade, piazza, cumuli, barricate); niente in headless.
func tint(center: Vector3, radius: float, color: Color, strength: float) -> void:
	if not _terrain_ready:
		return
	_tint_disc(center, radius, color, strength)
	_terrain.data.update_maps(Terrain3DRegion.TYPE_COLOR, false)


## Tante pennellate di colore con un solo aggiornamento delle mappe (prato dipinto).
func tint_points(points: Array[Vector3], radius: float, color: Color, strength: float) -> void:
	if not _terrain_ready or points.is_empty():
		return
	for center in points:
		_tint_disc(center, radius, color, strength)
	_terrain.data.update_maps(Terrain3DRegion.TYPE_COLOR, false)


func _tint_disc(center: Vector3, radius: float, color: Color, strength: float) -> void:
	var data := _terrain.data
	for p in _disc_points(center, radius):
		var world := _vertex_world(p)
		var d := Vector2(world.x - center.x, world.z - center.z).length() / radius
		var w := clampf(strength * (1.0 - d * d), 0.0, 1.0)
		var old: Color = data.get_pixel(Terrain3DRegion.TYPE_COLOR, world)
		var mixed := Color(old.r, old.g, old.b, old.a).lerp(Color(color.r, color.g, color.b, old.a), w)
		data.set_pixel(Terrain3DRegion.TYPE_COLOR, world, mixed)
	_mark_regions(center, radius)


# --- Salvataggio del rilievo di base ------------------------------------------------

## Scrive le quote e il seme del layout che le ha prodotte ([param layout_seed]):
## un file cotto con un altro quartiere viene rifiutato da `load_base`.
func save_base(path: String, layout_seed := 0) -> int:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return 0
	file.store_buffer(SAVE_MAGIC.to_ascii_buffer())
	file.store_32(SAVE_VERSION)
	file.store_32(resolution)
	file.store_float(size_m)
	file.store_32(layout_seed)
	var raw := _heights.to_byte_array()
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	file.store_32(raw.size())
	file.store_32(packed.size())
	file.store_buffer(packed)
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	return 20 + packed.size()


func load_base(path: String, layout_seed := 0) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	if file.get_buffer(4).get_string_from_ascii() != SAVE_MAGIC or file.get_32() != SAVE_VERSION:
		return false
	if file.get_32() != resolution or not is_equal_approx(file.get_float(), size_m):
		return false
	if file.get_32() != layout_seed:
		return false
	var raw_size := file.get_32()
	var packed_size := file.get_32()
	var raw := file.get_buffer(packed_size).decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != resolution * resolution * 4:
		return false
	_heights = raw.to_float32_array()
	_base = _heights.duplicate()
	_mirror_all()
	region_changed.emit(AABB(Vector3(-_half, MIN_HEIGHT, -_half), Vector3(_half * 2.0, MAX_HEIGHT - MIN_HEIGHT, _half * 2.0)))
	return true


# --- Interni ---------------------------------------------------------------------------

func _index_of(p: Vector3) -> int:
	var ix := int(round((p.x + _half) / SPACING))
	var iz := int(round((p.z + _half) / SPACING))
	if ix < 0 or iz < 0 or ix >= resolution or iz >= resolution:
		return -1
	return iz * resolution + ix


func _vertex_world(i: int) -> Vector3:
	var ix := i % resolution
	var iz := i / resolution
	return Vector3(ix * SPACING - _half, _heights[i], iz * SPACING - _half)


func _sample(array: PackedFloat32Array, p: Vector3) -> float:
	var fx := clampf((p.x + _half) / SPACING, 0.0, resolution - 1.001)
	var fz := clampf((p.z + _half) / SPACING, 0.0, resolution - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * resolution + ix
	var top := lerpf(array[i], array[i + 1], tx)
	var bottom := lerpf(array[i + resolution], array[i + resolution + 1], tx)
	return lerpf(top, bottom, tz)


## Indici dei vertici dentro il disco (XZ).
func _disc_points(center: Vector3, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x0 := maxi(int(floor((center.x - radius + _half) / SPACING)), 0)
	var x1 := mini(int(ceil((center.x + radius + _half) / SPACING)), resolution - 1)
	var z0 := maxi(int(floor((center.z - radius + _half) / SPACING)), 0)
	var z1 := mini(int(ceil((center.z + radius + _half) / SPACING)), resolution - 1)
	var r2 := radius * radius
	for iz in range(z0, z1 + 1):
		var wz := iz * SPACING - _half
		for ix in range(x0, x1 + 1):
			var wx := ix * SPACING - _half
			if (wx - center.x) * (wx - center.x) + (wz - center.z) * (wz - center.z) <= r2:
				out.append(iz * resolution + ix)
	return out


func _brush(center: Vector3, radius: float, shape: Callable) -> float:
	var volume := 0.0
	var r2 := radius * radius
	var x0 := maxi(int(floor((center.x - radius + _half) / SPACING)), 0)
	var x1 := mini(int(ceil((center.x + radius + _half) / SPACING)), resolution - 1)
	var z0 := maxi(int(floor((center.z - radius + _half) / SPACING)), 0)
	var z1 := mini(int(ceil((center.z + radius + _half) / SPACING)), resolution - 1)
	for iz in range(z0, z1 + 1):
		var wz := iz * SPACING - _half
		for ix in range(x0, x1 + 1):
			var wx := ix * SPACING - _half
			var d2 := ((wx - center.x) * (wx - center.x) + (wz - center.z) * (wz - center.z)) / r2
			if d2 >= 1.0:
				continue
			var i := iz * resolution + ix
			if _protected[i] != 0:
				continue
			var falloff := (1.0 - d2) * (1.0 - d2)
			var before := _heights[i]
			var after := clampf(shape.call(before, falloff), MIN_HEIGHT, MAX_HEIGHT)
			_heights[i] = after
			volume += (after - before) * SPACING * SPACING
	_mirror_rect(x0, z0, x1, z1)
	var lo := Vector3(x0 * SPACING - _half, MIN_HEIGHT, z0 * SPACING - _half)
	var hi := Vector3(x1 * SPACING - _half, MAX_HEIGHT, z1 * SPACING - _half)
	region_changed.emit(AABB(lo, hi - lo))
	return volume


# --- Terrain3D (solo resa) ------------------------------------------------------------

func _build_terrain3d() -> void:
	_terrain = Terrain3D.new()
	_terrain.name = "Terrain3D"
	_terrain.vertex_spacing = SPACING
	_terrain.region_size = REGION_SIZE
	add_child(_terrain)
	# La collisione di Terrain3D non serve (D-085: chunk nostri); l'oggetto nasce con il nodo.
	_disable_terrain3d_collision()
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_terrain.set_camera(camera)
	# In headless (e nel primo fotogramma) `data` non esiste ancora.
	if _terrain.data == null:
		await get_tree().process_frame
	if _terrain.data == null or not is_inside_tree():
		return
	_disable_terrain3d_collision()
	var region_m := REGION_SIZE * SPACING
	for gx in [-region_m * 0.5, region_m * 0.5]:
		for gz in [-region_m * 0.5, region_m * 0.5]:
			_terrain.data.add_region_blankp(Vector3(gx, 0.0, gz), false)
	_apply_quality_preset()
	_terrain_ready = true
	TerrainSurface.apply(_terrain)
	TerrainSurface.update_base(_terrain, _base, resolution, _half)
	_mirror_all()
	render_ready.emit()


## Steam Deck e Basso: meno anelli di LOD e piu piccoli (spec 6.3).
func _apply_quality_preset() -> void:
	var settings := get_node_or_null(^"/root/GameSettings") as GameSettingsService
	if settings == null:
		return
	if settings.preset == GameSettingsService.Preset.STEAM_DECK or settings.preset == GameSettingsService.Preset.LOW:
		_terrain.mesh_lods = 5
		_terrain.mesh_size = 32


func _disable_terrain3d_collision() -> void:
	if _terrain != null and _terrain.collision != null:
		_terrain.collision.mode = Terrain3DCollision.DISABLED


func _mirror_all() -> void:
	if not _terrain_ready:
		return
	_mirror_rect(0, 0, resolution - 1, resolution - 1)


func _mirror_rect(x0: int, z0: int, x1: int, z1: int) -> void:
	if not _terrain_ready:
		return
	var data := _terrain.data
	for iz in range(z0, z1 + 1):
		for ix in range(x0, x1 + 1):
			data.set_height(Vector3(ix * SPACING - _half, 0.0, iz * SPACING - _half), _heights[iz * resolution + ix])
	var lo := Vector3(x0 * SPACING - _half, 0.0, z0 * SPACING - _half)
	var hi := Vector3(x1 * SPACING - _half, 0.0, z1 * SPACING - _half)
	for corner in [lo, Vector3(hi.x, 0.0, lo.z), Vector3(lo.x, 0.0, hi.z), hi]:
		var region: Terrain3DRegion = data.get_regionp(corner)
		if region != null:
			region.edited = true
	data.update_maps(Terrain3DRegion.TYPE_HEIGHT, false)


func _mark_regions(center: Vector3, radius: float) -> void:
	for offset in [Vector3(-radius, 0, -radius), Vector3(radius, 0, -radius), Vector3(-radius, 0, radius), Vector3(radius, 0, radius)]:
		var region: Terrain3DRegion = _terrain.data.get_regionp(center + offset)
		if region != null:
			region.edited = true
