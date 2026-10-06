class_name Demolisher
extends Enemy
## Primo boss di fine livello (D-043, CAMPAIGN_STRUCTURE_SPEC sezione 5): il Demolitore.
##
## Regola col terreno, leggibile al primo incontro: **i terrapieni lo attirano e lui
## li smonta**. Ogni muro smontato lascia a terra un rottame; i **rottamatori**
## vicini lo raccolgono e lo portano al **cantiere** (lastra arancione), dove ogni
## `walls_per_barricade` rottami nasce una **barricata** (cella Raised scura) fra
## lui e il giocatore, che ferma i chiodi (D-045).
## Soluzioni che il campo offre:
## - un fossato (celle Lowered) lo rallenta come ogni altro nemico;
## - un muro a sacrificio lo tiene fermo dove la chiodatrice lo colpisce, ma
##   alimenta le sue barricate;
## - abbattere un rottamatore carico gli fa cadere il rottame: lo prende chi arriva prima;
## - scavare o occupare il cantiere lo costringe a sceglierne un altro;
## - scavare una barricata la fa crollare e restituisce il rottame.
## E un Enemy registrato nell'EnemyDirector (cosi armi, scavo esplosivo e torretta
## lo colpiscono), ma si guida da solo: `self_driven`.

signal wall_demolished(cell: Vector2i)
signal barricade_built(cell: Vector2i)
signal scrap_delivered(cell: Vector2i, stocked: int)
## Un rottamatore della squadra ha raccolto un rottame.
signal scrap_taken

const BODY_MODEL := preload("res://assets/models/demolisher.glb")
const BLADE_MODEL := preload("res://assets/models/demolisher_blade.glb")
const BODY_RADIUS := 0.9
const BODY_HEIGHT := 2.4
const BODY_COLOR := Color(0.85, 0.55, 0.05)
## Posizione locale della lama a riposo; martellando sale di BLADE_HAMMER_LIFT.
const BLADE_REST := Vector3(0.0, -0.6, -1.15)
const BLADE_HAMMER_LIFT := 0.35
## Colore lineare delle barricate: ferro scuro, distinto dai terrapieni del giocatore.
const BARRICADE_COLOR := Color(0.07, 0.06, 0.09)
const SITE_COLOR := Color(1.0, 0.35, 0.08, 0.6)
const NO_CELL := Vector2i(-1, -1)
## Terra dei terrapieni (RG_EARTH dello shader del suolo), per i frammenti.
const EARTH_COLOR := Color(0.44, 0.33, 0.21)
const ACCELERATION := 10.0
const RETARGET_SECONDS := 0.4
## Sotto questa distanza dal giocatore punta dritto, senza waypoint.
const DIRECT_CHASE_DISTANCE := 3.0

# --- Movimento procedurale (ActorMotion): solo sul telaio visivo `_rig`, che porta
# scafo e lama; il corpo fisico e `_blade.position` restano del codice di gioco.
## Punto d'appoggio a terra del telaio, nello spazio del boss (origine al centro della capsula).
const RIG_GROUND := Vector3(0.0, -BODY_HEIGHT * 0.5, 0.0)
## Mezza lunghezza e mezza larghezza (m) dei cingoli: inclinandosi il telaio si alza
## di |angolo| x braccio e non entra nel terreno.
const TRACK_HALF_LENGTH := 1.05
const TRACK_HALF_WIDTH := 0.95
## Vibrazione dei cingoli in marcia: frequenze (Hz), sobbalzo (m) e rollio (rad) a piena velocita.
const RUMBLE_HZ := 9.0
const RUMBLE_ROLL_HZ := 5.3
const RUMBLE_HEIGHT := 0.035
const RUMBLE_ROLL := 0.02
## Spostamento del peso: velocita angolare (rad/s) data al beccheggio per ogni m/s di
## cambio di velocita in avanti (parte: muso in su; si ferma: muso in giu).
const SHIFT_KICK := 0.45
## Molla che riporta il beccheggio a zero (rigidezza 1/s^2, smorzamento 1/s) e suo limite (rad).
const SHIFT_STIFFNESS := 90.0
const SHIFT_DAMPING := 9.0
const SHIFT_MAX := 0.06
## Caricamento del colpo di lama: mentre la lama sale lo scafo alza il muso (rad) e
## arretra (m); quando la lama cala torna giu con lei.
const WINDUP_PITCH := 0.05
const WINDUP_BACK := 0.06
## Velocita (1/s) con cui il caricamento entra ed esce a inizio e fine demolizione.
const WINDUP_BLEND_RATE := 8.0
## Barcollamento pesante quando e colpito: durata (s), arretramento (m), muso in su (rad),
## e scossone laterale (rad) alla frequenza indicata (Hz).
const HEAVY_STAGGER_SECONDS := 0.32
const HEAVY_STAGGER_BACK := 0.1
const HEAVY_STAGGER_PITCH := 0.04
const HEAVY_STAGGER_SHAKE := 0.02
const HEAVY_STAGGER_SHAKE_HZ := 6.0
## Frequenza del martello in `_tick_demolition` (rad/s): la stessa formula, per caricare a tempo.
const BLADE_HAMMER_RATE := 14.0

var player: PlayerCharacter
var grid: TerrainGrid
var path_field: PathField
var director: EnemyDirector
var companion: Node3D
var speed := 1.7
var contact_damage := 2
var contact_radius := 1.5
var demolish_seconds := 1.2
var wall_attraction_radius := 12.0
var walls_per_barricade := 2
var max_barricades := 8
## Rottami a terra: senza, le barricate nascono direttamente dal boss (D-043).
var scrap_field: ScrapField
var max_carriers := 3
var carrier_scrap_radius := 10.0
var carrier_recruit_radius := 14.0
var carrier_timeout := 10.0

## Celle delle barricate ancora in piedi.
var barricades: Dictionary[Vector2i, bool] = {}
var walls_demolished := 0
## Cella che sta smontando, (-1, -1) se nessuna.
var demolish_cell := Vector2i(-1, -1)

var _demolish_left := 0.0
var _pending_scrap := 0
var _wall_target := Vector2i(-1, -1)
var _retarget_left := 0.0
var _blade: MeshInstance3D
## Rottamatori al lavoro per lui: secondi rimasti prima che lascino la commissione.
var _crew: Dictionary[Enemy, float] = {}
## Cella del cantiere dove i rottami vengono portati, NO_CELL se non scelta.
var _site_cell := NO_CELL
var _site_scrap := 0
var _site_marker: MeshInstance3D
## Telaio visivo: genitore di scafo e lama, l'unico nodo mosso dal movimento procedurale.
var _rig: Node3D
var _motion_time := 0.0
var _last_forward_speed := 0.0
## Beccheggio da spostamento del peso: (angolo, velocita angolare).
var _shift := Vector2.ZERO
var _windup_weight := 0.0


func setup_demolisher(hp: int, flash_material: Material) -> void:
	name = "Demolisher"
	self_driven = true
	hit_radius_bonus = BODY_RADIUS - RADIUS
	health = hp
	max_health = hp
	collision_layer = 16
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = BODY_RADIUS
	shape.height = BODY_HEIGHT
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	# Modelli `demolisher` e `demolisher_blade` (tools/blender/build_actor_assets.py):
	# origine dello scafo a terra, quella del boss al centro della capsula. Lo scafo e
	# "vernice" tinta con BODY_COLOR; fessura rossa e lampeggiante sono luminosi.
	_base_material = ActorModel.paint_material(BODY_COLOR, 2.5, 0.7)
	_flash_material = flash_material
	_body = MeshInstance3D.new()
	_body.mesh = ActorModel.mesh_of(BODY_MODEL)
	_body.material_override = _base_material
	_body.position.y = -BODY_HEIGHT * 0.5
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_rig.add_child(_body)
	# La lama resta un nodo a parte: il codice la fa martellare.
	_blade = MeshInstance3D.new()
	_blade.mesh = ActorModel.mesh_of(BLADE_MODEL)
	_blade.material_override = ActorModel.paint_material(Color.WHITE, 0.0, 0.5)
	_blade.position = BLADE_REST
	_rig.add_child(_blade)


func _ready() -> void:
	if grid != null:
		grid.cell_changed.connect(_on_cell_changed)
	died.connect(func(_enemy: Enemy) -> void: _dismiss_crew())


## Altezza del centro della capsula sopra il pavimento.
static func boss_spawn_height() -> float:
	return BODY_HEIGHT * 0.5 + 0.02


func is_demolishing() -> bool:
	return demolish_cell.x >= 0


func crew_size() -> int:
	return _crew.size()


## Cella del cantiere, NO_CELL se nessuno.
func site_cell() -> Vector2i:
	return _site_cell


## Rottami gia consegnati al cantiere.
func site_scrap() -> int:
	return _site_scrap


## Un passo fisico, chiamato dall'EnemyDirector.
func drive(delta: float) -> void:
	if player == null or grid == null:
		return
	var pos := global_position
	var to_player := _planar(player.global_position - pos)
	if to_player.length() <= contact_radius:
		player.take_damage(contact_damage)

	_tick_crew(delta)
	_retarget_left -= delta
	var retarget := _retarget_left <= 0.0
	if retarget:
		_retarget_left = RETARGET_SECONDS
		_recruit_carriers()
		if not _site_is_valid() and _crew.keys().any(func(c: Enemy) -> bool: return c.carrying_scrap):
			_choose_site()
		_try_build_at_site()

	if is_demolishing():
		_tick_demolition(delta)
		return

	if retarget:
		_wall_target = _nearest_wall()
	var has_wall := _wall_target.x >= 0 and grid.state.get_state(_wall_target) == TerrainState.CellState.RAISED
	var direction := Vector3.ZERO
	if has_wall:
		direction = _planar(_cell_center(_wall_target) - pos).normalized()
	else:
		if to_player.length() > DIRECT_CHASE_DISTANCE and path_field != null:
			var waypoint: Variant = path_field.next_waypoint(pos)
			if waypoint != null:
				direction = _planar(waypoint - pos).normalized()
		if direction.is_zero_approx():
			direction = to_player.normalized()

	var current_speed := speed
	if grid.cell_state_at(pos) == TerrainState.CellState.LOWERED:
		current_speed *= 1.0 - grid.lowered_speed_penalty()
	var planar := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * current_speed, ACCELERATION * delta)
	velocity = Vector3(planar.x, 0.0 if is_on_floor() else velocity.y - 9.8 * delta, planar.z)
	move_and_slide()
	if planar.length() > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-planar.x, -planar.z), minf(delta * 6.0, 1.0))

	# Arrivato al muro scelto, o fermato da una cella Raised qualunque: la smonta.
	if has_wall and _planar(_cell_center(_wall_target) - global_position).length() <= BODY_RADIUS + grid.cell_size_m() * 0.5 + 0.4:
		_start_demolition(_wall_target)
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider() as Node
		if collider == null or collider.get_parent() != grid:
			continue
		var cell := grid.cell_at(collision.get_position() - collision.get_normal() * 0.3)
		if grid.state.is_valid(cell) and grid.state.get_state(cell) == TerrainState.CellState.RAISED:
			_start_demolition(cell)
			return


func _start_demolition(cell: Vector2i) -> void:
	demolish_cell = cell
	_demolish_left = demolish_seconds
	velocity = Vector3.ZERO
	print("PROTOTYPE01_BOSS_DEMOLISH_START X=%d Y=%d" % [cell.x, cell.y])


func _tick_demolition(delta: float) -> void:
	# Il giocatore l'ha scavata prima di lui: niente rottame per il boss.
	if grid.state.get_state(demolish_cell) != TerrainState.CellState.RAISED:
		demolish_cell = Vector2i(-1, -1)
		_blade.position.y = BLADE_REST.y
		return
	_demolish_left -= delta
	# La lama martella: telegraph del colpo.
	_blade.position.y = BLADE_REST.y + absf(sin(_demolish_left * BLADE_HAMMER_RATE)) * BLADE_HAMMER_LIFT
	var facing := _planar(_cell_center(demolish_cell) - global_position)
	if facing.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), minf(delta * 8.0, 1.0))
	if _demolish_left > 0.0:
		return
	var cell := demolish_cell
	var was_barricade := barricades.has(cell)
	demolish_cell = Vector2i(-1, -1)
	_blade.position.y = BLADE_REST.y
	grid.force_cell_state(cell, TerrainState.CellState.NORMAL)
	if was_barricade:
		return
	walls_demolished += 1
	DebrisBurst.spawn(get_parent(), _cell_center(cell) + Vector3(0.0, 0.6, 0.0), EARTH_COLOR, 14, 5.0, 0.22)
	print("PROTOTYPE01_BOSS_WALL_DEMOLISHED X=%d Y=%d total=%d" % [cell.x, cell.y, walls_demolished])
	wall_demolished.emit(cell)
	if scrap_field != null:
		# Il rottame resta a terra: lo prende chi arriva prima, compagno o rottamatori.
		scrap_field.spawn_on_cell(cell, TerrainState.CellState.NORMAL)
		return
	_pending_scrap += 1
	if _pending_scrap >= walls_per_barricade and barricades.size() < max_barricades:
		var site := _pick_barricade_cell()
		if site != NO_CELL:
			_raise_barricade(site)
			_pending_scrap -= walls_per_barricade


# --- Rottamatori al lavoro (D-045) ---------------------------------------------------

## Manda i rottamatori liberi piu vicini a prendere i rottami attorno al boss.
func _recruit_carriers() -> void:
	if scrap_field == null or director == null or _crew.size() >= max_carriers:
		return
	if barricades.size() >= max_barricades:
		return
	for scrap in scrap_field.positions_near(global_position, carrier_scrap_radius):
		if _crew.size() >= max_carriers:
			return
		var claimed := false
		for carrier: Enemy in _crew:
			if not carrier.carrying_scrap and _planar(carrier.errand_point - scrap).length() < 0.2:
				claimed = true
				break
		if claimed:
			continue
		var best: Enemy = null
		var best_distance := carrier_recruit_radius
		for enemy in director.enemies:
			if enemy == self or enemy.is_dead or enemy.self_driven or enemy.has_errand:
				continue
			var distance := _planar(enemy.global_position - scrap).length()
			if distance < best_distance:
				best_distance = distance
				best = enemy
		if best == null:
			continue
		best.set_errand(scrap)
		_crew[best] = carrier_timeout
		if not best.errand_reached.is_connected(_on_carrier_arrived):
			best.errand_reached.connect(_on_carrier_arrived)
			best.died.connect(_on_carrier_died)


## Toglie dalla squadra chi e morto o e stato rimosso (l'orda che si ritira).
func _prune_crew() -> void:
	for carrier in _crew.keys():
		if not is_instance_valid(carrier) or carrier.is_dead:
			_crew.erase(carrier)


func _tick_crew(delta: float) -> void:
	_prune_crew()
	for carrier: Enemy in _crew.keys():
		_crew[carrier] -= delta
		if _crew[carrier] <= 0.0:
			_release(carrier, true)
		elif carrier.carrying_scrap:
			# Senza cantiere valido aspetta accanto al boss.
			carrier.errand_point = _cell_center(_site_cell) if _site_is_valid() else global_position


func _on_carrier_arrived(carrier: Enemy) -> void:
	if not _crew.has(carrier):
		return
	if not carrier.carrying_scrap:
		if scrap_field.take_near(carrier.errand_point, 0.3, 1) == 0:
			# Il compagno (o un altro) e arrivato prima.
			_release(carrier, false)
			return
		carrier.set_carrying(true)
		_crew[carrier] = carrier_timeout
		if not _site_is_valid():
			_choose_site()
		print("PROTOTYPE01_BOSS_SCRAP_TAKEN crew=%d" % _crew.size())
		scrap_taken.emit()
		return
	if not _site_is_valid() or _planar(_cell_center(_site_cell) - carrier.global_position).length() > 1.5:
		return
	_site_scrap += 1
	_release(carrier, false)
	print("PROTOTYPE01_BOSS_SCRAP_DELIVERED X=%d Y=%d stocked=%d" % [_site_cell.x, _site_cell.y, _site_scrap])
	scrap_delivered.emit(_site_cell, _site_scrap)
	_try_build_at_site()


## Un rottamatore carico abbattuto lascia cadere il rottame: lo prende chi arriva prima.
func _on_carrier_died(carrier: Enemy) -> void:
	if not _crew.has(carrier):
		return
	_crew.erase(carrier)
	if carrier.carrying_scrap and scrap_field != null:
		scrap_field.spawn_on_ground(carrier.global_position)
		print("PROTOTYPE01_BOSS_SCRAP_DROPPED")


func _release(carrier: Enemy, drop_scrap: bool) -> void:
	_crew.erase(carrier)
	carrier.clear_errand()
	if carrier.carrying_scrap:
		carrier.set_carrying(false)
		if drop_scrap and scrap_field != null:
			scrap_field.spawn_on_ground(carrier.global_position)


func _dismiss_crew() -> void:
	_prune_crew()
	for carrier: Enemy in _crew.keys():
		_release(carrier, true)
	_clear_site()


func _site_is_valid() -> bool:
	return _site_cell != NO_CELL and grid.state.get_state(_site_cell) == TerrainState.CellState.NORMAL


func _choose_site() -> void:
	_clear_site(false)
	_site_cell = _pick_barricade_cell()
	if _site_cell == NO_CELL:
		return
	if _site_marker == null:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(grid.cell_size_m() * 0.7, 0.06, grid.cell_size_m() * 0.7)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = SITE_COLOR
		_site_marker = MeshInstance3D.new()
		_site_marker.mesh = mesh
		_site_marker.material_override = material
		_site_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_site_marker.top_level = true
		add_child(_site_marker)
	var surface := grid.to_global(grid.cell_local_position(_site_cell, TerrainState.CellState.NORMAL))
	_site_marker.global_transform = Transform3D(Basis(), Vector3(surface.x, surface.y * 2.0 - grid.global_position.y + 0.05, surface.z))
	_site_marker.visible = true
	print("PROTOTYPE01_BOSS_SITE X=%d Y=%d" % [_site_cell.x, _site_cell.y])


## I rottami gia consegnati restano del boss: passano al cantiere successivo.
func _clear_site(forget_scrap := true) -> void:
	_site_cell = NO_CELL
	if forget_scrap:
		_site_scrap = 0
	if _site_marker != null:
		_site_marker.visible = false


## Con abbastanza rottami consegnati alza la barricata, appena la cella e libera.
func _try_build_at_site() -> void:
	if _site_scrap < walls_per_barricade or barricades.size() >= max_barricades:
		return
	if not _site_is_valid():
		_choose_site()
	if _site_cell == NO_CELL or not _cell_is_free(_site_cell):
		return
	var cell := _site_cell
	_site_scrap -= walls_per_barricade
	_clear_site(false)
	_raise_barricade(cell)


## Terrapieno del giocatore piu vicino entro il raggio di attrazione, (-1,-1) se nessuno.
func _nearest_wall() -> Vector2i:
	var own := grid.cell_at(global_position)
	var reach := int(ceil(wall_attraction_radius / grid.cell_size_m()))
	var best := Vector2i(-1, -1)
	var best_distance := wall_attraction_radius
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell := own + Vector2i(dx, dy)
			if not grid.state.is_valid(cell) or barricades.has(cell):
				continue
			if grid.state.get_state(cell) != TerrainState.CellState.RAISED:
				continue
			var distance := _planar(_cell_center(cell) - global_position).length()
			if distance < best_distance:
				best_distance = distance
				best = cell
	return best


## Cella per una barricata: a due celle dal boss verso il giocatore (o accanto, se
## li non si puo). NO_CELL se non ce n'e una libera.
func _pick_barricade_cell() -> Vector2i:
	var to_player := _planar(player.global_position - global_position)
	if to_player.length() < 0.1:
		return NO_CELL
	var forward := to_player.normalized()
	var side := Vector3(-forward.z, 0.0, forward.x)
	var step := grid.cell_size_m()
	for lateral in [0.0, 1.0, -1.0, 2.0, -2.0]:
		var point: Vector3 = global_position + forward * step * 2.0 + side * step * lateral
		var cell := grid.cell_at(point)
		if not grid.state.is_valid(cell) or grid.state.get_state(cell) != TerrainState.CellState.NORMAL:
			continue
		if _cell_is_free(cell):
			return cell
	return NO_CELL


## Mai sopra giocatore, compagno, nemici o il boss stesso.
func _cell_is_free(cell: Vector2i) -> bool:
	var step := grid.cell_size_m()
	var center := _cell_center(cell)
	if not grid.can_apply_at(center, TerrainState.ToolMode.RAISE, player):
		return false
	if _planar(center - player.global_position).length() < step:
		return false
	if companion != null and _planar(center - companion.global_position).length() < step:
		return false
	if _planar(center - global_position).length() < BODY_RADIUS + step * 0.75:
		return false
	if director != null and director.enemies_near(center, step * 0.75).any(func(e: Enemy) -> bool: return e != self):
		return false
	return true


func _raise_barricade(cell: Vector2i) -> void:
	barricades[cell] = true
	grid.set_raised_tint(cell, BARRICADE_COLOR)
	grid.force_cell_state(cell, TerrainState.CellState.RAISED)
	DebrisBurst.spawn(get_parent(), _cell_center(cell) + Vector3(0.0, 1.2, 0.0), BARRICADE_COLOR, 12, 4.0, 0.2)
	print("PROTOTYPE01_BOSS_BARRICADE X=%d Y=%d standing=%d" % [cell.x, cell.y, barricades.size()])
	barricade_built.emit(cell)


## Una barricata scavata dal giocatore (o smontata) crolla: non e piu sua.
func _on_cell_changed(cell: Vector2i, cell_state: TerrainState.CellState) -> void:
	# Cantiere scavato o occupato da un terrapieno: se ne sceglie un altro.
	if cell == _site_cell and cell_state != TerrainState.CellState.NORMAL:
		_clear_site(false)
	if barricades.has(cell) and cell_state != TerrainState.CellState.RAISED:
		barricades.erase(cell)
		grid.clear_raised_tint(cell)
		print("PROTOTYPE01_BOSS_BARRICADE_DOWN X=%d Y=%d standing=%d" % [cell.x, cell.y, barricades.size()])


func _cell_center(cell: Vector2i) -> Vector3:
	var p := grid.to_global(grid.cell_local_position(cell, TerrainState.CellState.NORMAL))
	return Vector3(p.x, 0.0, p.z)


static func _planar(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- Movimento procedurale ---------------------------------------------------------------

## Vibrazione dei cingoli, spostamento del peso, caricamento del colpo e barcollamento:
## tutto sommato in una sola trasformazione del telaio. La lama e figlia del telaio e
## continua a martellare in `_blade.position.y`, quindi i due movimenti si compongono.
func _animate(delta: float) -> void:
	_motion_time += delta
	var forward := -global_basis.z
	var forward_speed := velocity.x * forward.x + velocity.z * forward.z
	var moving := clampf(Vector2(velocity.x, velocity.z).length() / maxf(speed, 0.01), 0.0, 1.0)

	_shift.y += (forward_speed - _last_forward_speed) * SHIFT_KICK
	_last_forward_speed = forward_speed
	_shift = ActorMotion.spring(_shift, SHIFT_STIFFNESS, SHIFT_DAMPING, delta)
	var pitch := clampf(_shift.x, -SHIFT_MAX, SHIFT_MAX)
	var roll := sin(_motion_time * TAU * RUMBLE_ROLL_HZ) * RUMBLE_ROLL * moving
	var rise := (0.5 + 0.5 * sin(_motion_time * TAU * RUMBLE_HZ)) * RUMBLE_HEIGHT * moving
	var slide := 0.0

	_windup_weight = move_toward(_windup_weight, 1.0 if is_demolishing() else 0.0, WINDUP_BLEND_RATE * delta)
	if _windup_weight > 0.0:
		# Stessa fase della lama: 1 con la lama in alto, 0 quando batte.
		var raised := absf(sin(_demolish_left * BLADE_HAMMER_RATE)) * _windup_weight
		pitch += WINDUP_PITCH * raised
		slide += WINDUP_BACK * raised

	if _stagger > 0.0:
		_stagger = maxf(_stagger - delta / HEAVY_STAGGER_SECONDS, 0.0)
		var hit := _stagger * _stagger
		slide += HEAVY_STAGGER_BACK * hit
		pitch += HEAVY_STAGGER_PITCH * hit
		roll += sin(_motion_time * TAU * HEAVY_STAGGER_SHAKE_HZ) * HEAVY_STAGGER_SHAKE * hit

	var pose := ActorMotion.tilt_on_ground(RIG_GROUND, pitch, roll, TRACK_HALF_LENGTH, TRACK_HALF_WIDTH)
	pose.origin += Vector3(0.0, rise, slide)
	_rig.transform = pose
	_at_rest = false


func _reset_pose() -> void:
	_rig.transform = Transform3D.IDENTITY
	_shift = Vector2.ZERO
	_last_forward_speed = 0.0
	_at_rest = true
