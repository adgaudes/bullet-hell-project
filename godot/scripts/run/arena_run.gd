class_name ArenaRun
extends Node
## Regia del prototipo della promessa A (D-038, docs/PROMISE_A_PROTOTYPE_SPEC.md):
## collega nemici, arma, esperienza, level-up, vita e fine run, applica alla
## griglia la disposizione del terreno (cortili, depositi, trincee) prodotta
## dall'arena grande (D-042) e gli effetti degli upgrade.
## Chiude il livello col boss (D-043): chiamata a tempo, direzione annunciata,
## arrivo del Demolitore, vittoria alla sua morte.
## Seed: `-- --seed=N` sulla riga di comando, altrimenti casuale; sempre nel log.
## `-- --boss-at=N` anticipa la chiamata del boss a N secondi.

signal boss_called(direction: Vector3)
signal level_completed

enum BossPhase { WAITING, WARNING, ACTIVE, DEFEATED }

## Direzioni di arrivo annunciate: nome e verso nel mondo (nord = -Z = alto dello schermo).
const BOSS_DIRECTIONS := [
	["NORD", Vector3(0.0, 0.0, -1.0)], ["EST", Vector3(1.0, 0.0, 0.0)],
	["SUD", Vector3(0.0, 0.0, 1.0)], ["OVEST", Vector3(-1.0, 0.0, 0.0)],
]

@export var tuning: RunTuning
## Arena grande con i punti di interesse del terreno; senza, si costruisce il solo
## cortile centrale di `tuning.wall_ring_radius`.
@export var district: RuinsDistrict
@export var player: PlayerCharacter
@export var companion: Companion
@export var grid: TerrainGrid
@export var director: EnemyDirector
@export var weapon: AutoWeapon
@export var xp_field: XpField
@export var hud: RunHud
@export var level_up_menu: LevelUpMenu
@export var game_over: GameOverPanel

var progression := RunProgression.new()
var elapsed := 0.0
var is_over := false
var run_seed := 0
var companion_weapon: AutoWeapon
var dig_blast_radius := 0.0
var boss_phase := BossPhase.WAITING
var boss: Demolisher
var boss_direction := Vector3.ZERO
var boss_direction_name := ""
## Secondi di livello a cui il boss viene chiamato (tuning o riga di comando); 0 = mai.
var boss_call_at := 0.0
var _boss_warning_left := 0.0
var _boss_rng := RandomNumberGenerator.new()
var _pending_level_ups := 0


func _ready() -> void:
	if tuning == null:
		tuning = RunTuning.new()
	run_seed = _seed_from_command_line()
	progression.setup(run_seed)
	progression.xp_first_level = tuning.xp_first_level
	progression.xp_growth = tuning.xp_growth
	progression.pity_level_ups = tuning.pity_level_ups
	progression.has_companion = companion != null
	director.rng.seed = run_seed + 1
	_boss_rng.seed = run_seed + 2
	boss_call_at = _boss_call_from_command_line(tuning.boss_call_seconds)

	player.invulnerability_seconds = tuning.player_invulnerability
	player.set_max_health(tuning.player_max_health)
	weapon.fire_interval = tuning.fire_interval
	weapon.weapon_range = tuning.weapon_range
	weapon.damage = tuning.weapon_damage
	weapon.projectile_speed = tuning.projectile_speed
	xp_field.player_radius = tuning.pickup_radius
	_build_terrain_layout()

	player.health_changed.connect(hud.set_health)
	player.died.connect(_on_player_died)
	director.enemy_killed.connect(_on_enemy_killed)
	xp_field.collected.connect(_on_xp_collected)
	level_up_menu.chosen.connect(_on_upgrade_chosen)
	game_over.restart_requested.connect(restart)
	grid.command_applied.connect(_on_terrain_command)
	hud.set_health(player.health, player.max_health)
	_refresh_xp()
	print("PROTOTYPE01_RUN_START seed=%d" % run_seed)


func _physics_process(delta: float) -> void:
	if is_over:
		return
	elapsed += delta
	hud.set_time(elapsed)
	_tick_boss(delta)


# --- Boss di fine livello ----------------------------------------------------------

func _tick_boss(delta: float) -> void:
	match boss_phase:
		BossPhase.WAITING:
			if boss_call_at > 0.0 and elapsed >= boss_call_at:
				call_boss()
		BossPhase.WARNING:
			_boss_warning_left -= delta
			hud.set_boss_warning(boss_direction_name, boss_direction, _boss_warning_left)
			if _boss_warning_left <= 0.0:
				_spawn_boss()
		BossPhase.ACTIVE:
			if is_instance_valid(boss):
				hud.set_boss_health(boss.health, boss.max_health)


## Annuncia la direzione di arrivo: il giocatore ha il preavviso per preparare il terreno.
func call_boss() -> void:
	if boss_phase != BossPhase.WAITING:
		return
	# Solo direzioni in cui c'e spazio per arrivare da lontano (vicino ai bordi no).
	var limit := _play_half_extent() - 3.0
	var options: Array = []
	for entry: Array in BOSS_DIRECTIONS:
		var point: Vector3 = player.global_position + entry[1] * tuning.boss_spawn_distance
		if absf(point.x) <= limit and absf(point.z) <= limit:
			options.append(entry)
	if options.is_empty():
		options = BOSS_DIRECTIONS
	var chosen: Array = options[_boss_rng.randi_range(0, options.size() - 1)]
	boss_direction_name = chosen[0]
	boss_direction = chosen[1]
	boss_phase = BossPhase.WARNING
	_boss_warning_left = tuning.boss_warning_seconds
	hud.set_boss_warning(boss_direction_name, boss_direction, _boss_warning_left)
	print("PROTOTYPE01_BOSS_CALLED direction=%s time=%.1f" % [boss_direction_name, elapsed])
	boss_called.emit(boss_direction)


func _spawn_boss() -> void:
	boss_phase = BossPhase.ACTIVE
	hud.clear_boss_warning()
	boss = Demolisher.new()
	boss.setup_demolisher(tuning.boss_health, director.flash_material())
	boss.player = player
	boss.grid = grid
	boss.path_field = director.path_field
	boss.director = director
	boss.companion = companion
	boss.speed = tuning.boss_speed
	boss.contact_damage = tuning.boss_contact_damage
	boss.contact_radius = tuning.boss_contact_radius
	boss.demolish_seconds = tuning.boss_demolish_seconds
	boss.wall_attraction_radius = tuning.boss_wall_attraction_radius
	boss.walls_per_barricade = tuning.boss_walls_per_barricade
	boss.max_barricades = tuning.boss_max_barricades
	var point := _boss_spawn_point()
	director.add_enemy(boss, Vector3(point.x, Demolisher.boss_spawn_height(), point.z))
	boss.rotation.y = atan2(boss_direction.x, boss_direction.z)
	boss.died.connect(_on_boss_died)
	hud.set_boss_health(boss.health, boss.max_health)
	print("PROTOTYPE01_BOSS_SPAWNED direction=%s x=%.1f z=%.1f health=%d" % [boss_direction_name, point.x, point.z, boss.health])


## Punto di ingresso nella direzione annunciata: dentro l'arena e su terreno libero.
func _boss_spawn_point() -> Vector3:
	var limit := _play_half_extent() - 3.0
	var path := director.path_field
	var side := Vector3(-boss_direction.z, 0.0, boss_direction.x)
	for lateral in [0.0, 3.0, -3.0, 6.0, -6.0, 9.0, -9.0]:
		for back in [0.0, -3.0, 3.0, -6.0]:
			var point: Vector3 = player.global_position + boss_direction * (tuning.boss_spawn_distance + back) + side * lateral
			point = Vector3(clampf(point.x, -limit, limit), 0.0, clampf(point.z, -limit, limit))
			if path == null or (path.is_walkable(point) and path.is_walkable(point + Vector3(1.0, 0.0, 1.0)) \
					and path.is_walkable(point - Vector3(1.0, 0.0, 1.0))):
				return point
	var fallback: Vector3 = player.global_position + boss_direction * tuning.boss_spawn_distance
	return Vector3(clampf(fallback.x, -limit, limit), 0.0, clampf(fallback.z, -limit, limit))


func _play_half_extent() -> float:
	if district != null:
		return district.play_half_extent
	return director.path_field.half_extent if director.path_field != null else 24.0


## Rottami che escono dal livello: quelli nel cassone, piu il premio del boss se battuto.
func scrap_out(victory: bool) -> int:
	var carried := companion.carried if companion != null else 0
	if victory:
		return carried + tuning.boss_scrap_bonus
	return int(floor(carried * tuning.death_scrap_share))


func _on_boss_died(_enemy: Enemy) -> void:
	if is_over:
		return
	is_over = true
	boss_phase = BossPhase.DEFEATED
	director.spawning = false
	director.clear_horde()
	hud.clear_boss()
	if level_up_menu.is_open:
		level_up_menu.close()
	var scrap := scrap_out(true)
	print("PROTOTYPE01_LEVEL_COMPLETE time=%.1f level=%d kills=%d scrap=%d seed=%d"
		% [elapsed, progression.level, director.kills, scrap, run_seed])
	level_completed.emit()
	game_over.open(elapsed, progression.level, director.kills, true, scrap)


## Disposizione iniziale del terreno: i punti di interesse dell'arena grande,
## oppure il solo cortile centrale.
func _build_terrain_layout() -> void:
	if district == null:
		_build_courtyard_walls()
		return
	grid.plaza_radius = district.plaza_radius()
	var raised := 0
	var lowered := 0
	for feature: Dictionary in district.terrain_features:
		var center := grid.cell_at(Vector3(feature.center.x, 0.0, feature.center.y))
		var cells: Array[Vector2i] = []
		for offset: Vector2i in feature.offsets:
			cells.append(center + offset)
		grid.set_cell_states(cells, feature.state)
		if feature.state == TerrainState.CellState.RAISED:
			raised += cells.size()
		else:
			lowered += cells.size()
	print("PROTOTYPE01_TERRAIN_LAYOUT_READY features=%d raised=%d lowered=%d"
		% [district.terrain_features.size(), raised, lowered])


## Mura del cortile: anello di celle Raised con un varco al centro di ogni lato.
func _build_courtyard_walls() -> void:
	var radius := tuning.wall_ring_radius
	if radius <= 0:
		return
	var center := Vector2i(grid.state.width / 2, grid.state.height / 2)
	var cells: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if maxi(absi(dx), absi(dy)) != radius or dx == 0 or dy == 0:
				continue
			cells.append(center + Vector2i(dx, dy))
	grid.set_cell_states(cells, TerrainState.CellState.RAISED)


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_enemy_killed(world_position: Vector3, total: int) -> void:
	xp_field.spawn(world_position, tuning.xp_per_enemy)
	hud.set_kills(total)


func _on_xp_collected(amount: int) -> void:
	if is_over:
		return
	_pending_level_ups += progression.add_xp(amount)
	_refresh_xp()
	_open_next_level_up()


func _open_next_level_up() -> void:
	if _pending_level_ups <= 0 or level_up_menu.is_open or is_over:
		return
	var offer := progression.roll_offer()
	if offer.is_empty():
		_pending_level_ups = 0
		return
	var ids := offer.map(func(u: Dictionary) -> String: return str(u.id))
	var shown_level := progression.level - _pending_level_ups + 1
	print("PROTOTYPE01_LEVEL_UP level=%d offer=%s" % [shown_level, ",".join(PackedStringArray(ids))])
	level_up_menu.open(offer, progression.levels, shown_level)


func _on_upgrade_chosen(id: StringName) -> void:
	_pending_level_ups -= 1
	var new_level := progression.choose(id)
	apply_upgrade(id, new_level)
	print("PROTOTYPE01_UPGRADE_CHOSEN id=%s level=%d" % [id, new_level])
	_open_next_level_up.call_deferred()


## Effetto di un upgrade al suo nuovo livello.
func apply_upgrade(id: StringName, new_level: int) -> void:
	match id:
		&"nail_rate":
			weapon.fire_interval /= 1.25
		&"nail_pierce":
			weapon.pierce += 1
		&"nail_spread":
			weapon.projectiles += 1
		&"companion_turret":
			_upgrade_companion_turret(new_level)
		&"companion_magnet":
			xp_field.set_attractor(companion, 2.5 + 1.5 * (new_level - 1))
			if new_level == 1:
				companion.mount_part(&"MagnetPart", _magnet_part())
		&"companion_cargo":
			companion.add_capacity(2, 1)
		&"dig_blast":
			dig_blast_radius = 2.4 + 0.8 * (new_level - 1)
		&"spiked_wall":
			director.spike_damage = 1
			director.spike_interval = 0.8 if new_level == 1 else 0.5
			_set_raised_tint(Color(0.85, 0.75, 0.7))
		&"boots":
			player.speed_bonus *= 1.1
		&"patch":
			player.set_max_health(player.max_health + 1)
		&"reach":
			xp_field.player_radius *= 1.4


func _upgrade_companion_turret(new_level: int) -> void:
	if companion_weapon == null:
		companion_weapon = AutoWeapon.new()
		companion_weapon.name = "CompanionWeapon"
		companion_weapon.shooter = companion
		companion_weapon.director = director
		companion_weapon.muzzle_height = 0.55
		companion_weapon.fire_interval = 0.9
		companion_weapon.weapon_range = 8.0
		companion_weapon.damage = tuning.weapon_damage
		companion_weapon.projectile_speed = tuning.projectile_speed
		get_parent().add_child(companion_weapon)
		companion.mount_part(&"TurretPart", _turret_part())
	else:
		companion_weapon.fire_interval /= 1.35
	print("PROTOTYPE01_COMPANION_TURRET level=%d" % new_level)


## Scavo esplosivo: ogni passo di scavo colpisce i nemici attorno alla cella.
func _on_terrain_command(cell: Vector2i, mode: TerrainState.ToolMode, new_state: TerrainState.CellState) -> void:
	if mode != TerrainState.ToolMode.DIG or dig_blast_radius <= 0.0:
		return
	var center := grid.to_global(grid.cell_local_position(cell, new_state))
	center.y = 0.1
	for enemy in director.enemies_near(center, dig_blast_radius):
		enemy.take_damage(2)
	_blast_effect(center, dig_blast_radius)
	print("PROTOTYPE01_DIG_BLAST X=%d Y=%d" % [cell.x, cell.y])


func _blast_effect(center: Vector3, radius: float) -> void:
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.05
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.6, 0.15, 0.7)
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(ring)
	ring.global_position = center
	ring.scale = Vector3(0.2, 1.0, 0.2)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, ^"scale", Vector3(radius, 1.0, radius), 0.25)
	tween.tween_property(material, ^"albedo_color:a", 0.0, 0.25)
	tween.chain().tween_callback(ring.queue_free)


## Terrapieni spinati: le celle rialzate prendono un colore metallico chiaro.
func _set_raised_tint(color: Color) -> void:
	grid.raised_color_override = color


func _turret_part() -> Node3D:
	var part := Node3D.new()
	part.position = Vector3(0.0, 0.42, -0.25)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.13)
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.16
	base_mesh.bottom_radius = 0.2
	base_mesh.height = 0.14
	base.mesh = base_mesh
	base.material_override = dark
	part.add_child(base)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.09, 0.09, 0.45)
	barrel.mesh = barrel_mesh
	barrel.material_override = dark
	barrel.position = Vector3(0.0, 0.1, -0.22)
	part.add_child(barrel)
	return part


func _magnet_part() -> Node3D:
	var part := Node3D.new()
	part.position = Vector3(0.0, 0.55, 0.42)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.08, 0.06)
	var tip := StandardMaterial3D.new()
	tip.albedo_color = Color(0.8, 0.8, 0.82)
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.1, 0.4, 0.1)
		arm.mesh = arm_mesh
		arm.material_override = red
		arm.position = Vector3(side * 0.14, 0.2, 0.0)
		part.add_child(arm)
		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(0.11, 0.08, 0.11)
		cap.mesh = cap_mesh
		cap.material_override = tip
		cap.position = Vector3(side * 0.14, 0.42, 0.0)
		part.add_child(cap)
	var bridge := MeshInstance3D.new()
	var bridge_mesh := BoxMesh.new()
	bridge_mesh.size = Vector3(0.38, 0.1, 0.1)
	bridge.mesh = bridge_mesh
	bridge.material_override = red
	part.add_child(bridge)
	return part


func _refresh_xp() -> void:
	hud.set_xp(progression.xp, progression.xp_to_next(), progression.level)


func _on_player_died() -> void:
	if is_over:
		return
	is_over = true
	director.spawning = false
	if level_up_menu.is_open:
		level_up_menu.close()
	var scrap := scrap_out(false)
	print("PROTOTYPE01_PLAYER_DIED time=%.1f level=%d kills=%d scrap=%d seed=%d"
		% [elapsed, progression.level, director.kills, scrap, run_seed])
	game_over.open(elapsed, progression.level, director.kills, false, scrap)


static func _boss_call_from_command_line(default_seconds: float) -> float:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--boss-at="):
			return arg.trim_prefix("--boss-at=").to_float()
	return default_seconds


static func _seed_from_command_line() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return arg.trim_prefix("--seed=").to_int()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi() & 0x7fffffff
