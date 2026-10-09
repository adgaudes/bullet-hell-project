class_name EnemyDirector
extends Node3D
## Orda lenta (D-038): fa nascere i rottamatori in un anello attorno al
## giocatore, fuori dallo schermo (D-039), con ritmo crescente e li muove tutti
## in un solo passo fisico. Chi resta troppo indietro torna sull'anello. Ogni nemico segue il
## PathField verso il giocatore (aggira le mura, passa dai varchi); se il
## giocatore e irraggiungibile punta dritto e si ammassa contro le mura.
## Le celle Lowered lo rallentano come rallentano il giocatore.

signal enemy_killed(world_position: Vector3, total: int)

const SCAVENGER_MODEL := preload("res://assets/models/scavenger.glb")
## Lineare: vernice dello scafo dei rottamatori (e colore dei loro frammenti).
const BODY_COLOR := Color(0.42, 0.1, 0.05)
## Lineare: scafo dei rottamatori veloci (D-056), blu elettrico per distinguerli a colpo d'occhio.
const RUNNER_COLOR := Color(0.05, 0.22, 0.85)
const SEPARATION_RADIUS := 0.8
const SEPARATION_WEIGHT := 1.6
## Sotto questa distanza dal giocatore si punta dritto, senza waypoint.
const DIRECT_CHASE_DISTANCE := 1.8
const ACCELERATION := 18.0
## Distanza planare a cui una commissione (Enemy.errand_point) e raggiunta.
const ERRAND_REACH := 0.9

@export var tuning: RunTuning
@export var player: PlayerCharacter
@export var path_field: PathField
@export var grid: TerrainGrid
@export var spawning := true

var enemies: Array[Enemy] = []
var kills := 0
## Nemici riportati sull'anello di comparsa perche troppo lontani.
var leashed := 0
var elapsed := 0.0
## Danno da contatto con le celle Raised (upgrade Terrapieni spinati); 0 = spento.
var spike_damage := 0
var spike_interval := 0.8
var rng := RandomNumberGenerator.new()
var _spawn_timer := 1.0
var _body_mesh: Mesh
var _base_material: ShaderMaterial
var _runner_material: ShaderMaterial
## Rottamatori veloci nati finora.
var runners_spawned := 0
var _flash_material := StandardMaterial3D.new()
# Riusati a ogni passo (R-10): secchi di separazione e copia dell'elenco dei nemici.
var _buckets: Dictionary[Vector2i, Array] = {}
var _step_list: Array[Enemy] = []


func _ready() -> void:
	Enemy.reset_gait_serial()
	if tuning == null:
		tuning = RunTuning.new()
	# Una mesh e un materiale per tutta l'orda: un nemico costa una draw call.
	_body_mesh = ActorModel.mesh_of(SCAVENGER_MODEL)
	_base_material = ActorModel.paint_material(BODY_COLOR, 2.0)
	_runner_material = ActorModel.paint_material(RUNNER_COLOR, 3.0)
	_flash_material.albedo_color = Color.WHITE
	_flash_material.emission_enabled = true
	_flash_material.emission = Color.WHITE


func _physics_process(delta: float) -> void:
	if player == null:
		return
	elapsed += delta
	if spawning and (path_field == null or path_field.is_ready()):
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_batch()
			_spawn_timer = current_spawn_interval()
	_move_enemies(delta)


func current_spawn_interval() -> float:
	var t := clampf(elapsed / maxf(tuning.spawn_ramp_seconds, 1.0), 0.0, 1.0)
	return lerpf(tuning.spawn_interval_start, tuning.spawn_interval_min, t)


func current_enemy_health() -> int:
	return tuning.enemy_health + int(elapsed / maxf(tuning.enemy_health_growth_seconds, 1.0))


## Quota di rottamatori veloci fra i nuovi nati, in questo momento del livello.
func current_runner_share() -> float:
	if tuning.runner_share_max <= 0.0 or elapsed < tuning.runner_start_seconds:
		return 0.0
	var t := clampf((elapsed - tuning.runner_start_seconds) / maxf(tuning.runner_ramp_seconds, 1.0), 0.0, 1.0)
	return tuning.runner_share_max * t


## Crea un nemico in un punto preciso (test, eventi scriptati). [param runner]:
## rottamatore veloce, con meno vita.
func spawn_at(world: Vector3, runner := false) -> Enemy:
	var enemy := Enemy.new()
	enemy.name = "Enemy%d" % (kills + enemies.size())
	if runner:
		runners_spawned += 1
		enemy.speed_scale = tuning.runner_speed / maxf(tuning.enemy_speed, 0.01)
		enemy.setup(maxi(ceili(current_enemy_health() * tuning.runner_health_share), 1), _body_mesh, _runner_material, _flash_material)
	else:
		enemy.setup(current_enemy_health(), _body_mesh, _base_material, _flash_material)
	add_enemy(enemy, Vector3(world.x, Enemy.spawn_height(), world.z))
	return enemy


## Registra un nemico gia costruito (boss): armi e scavo esplosivo lo vedono come gli altri.
func add_enemy(enemy: Enemy, world: Vector3) -> void:
	add_child(enemy)
	enemy.global_position = world
	enemy.died.connect(_on_enemy_died)
	enemies.append(enemy)


func flash_material() -> Material:
	return _flash_material


## L'orda si ritira (fine livello): tutti i nemici spariscono senza lasciare esperienza.
func clear_horde() -> void:
	for enemy in enemies:
		enemy.is_dead = true
		enemy.collision_layer = 0
		enemy.collision_mask = 0
		var tween := enemy.create_tween()
		tween.tween_property(enemy, ^"scale", Vector3.ONE * 0.05, 0.25)
		tween.tween_callback(enemy.queue_free)
	enemies.clear()


## Nemici vivi entro [param radius] (piano XZ) da [param origin].
func enemies_near(origin: Vector3, radius: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	for enemy in enemies:
		if _planar(enemy.global_position - origin).length() <= radius:
			result.append(enemy)
	return result


func _spawn_batch() -> void:
	var room := tuning.max_alive - enemies.size()
	if room <= 0:
		return
	var count := mini(rng.randi_range(tuning.batch_min, tuning.batch_max), room)
	var origin: Variant = _find_spawn_point()
	if origin == null:
		return
	for i in count:
		var offset := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
		var point: Vector3 = origin + offset
		if path_field != null and not path_field.is_walkable(point):
			point = origin
		var share := current_runner_share()
		spawn_at(point, share > 0.0 and rng.randf() < share)


## Punto libero sull'anello di comparsa attorno al giocatore, riportato dentro
## l'area giocabile; null se dopo alcuni tentativi non ne trova uno.
func _find_spawn_point() -> Variant:
	var e := (path_field.half_extent if path_field != null else 24.0) - 1.5
	var center := player.global_position
	for attempt in 12:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(tuning.spawn_ring_min, tuning.spawn_ring_max)
		var point := Vector3(
			clampf(center.x + cos(angle) * radius, -e, e), 0.0,
			clampf(center.z + sin(angle) * radius, -e, e))
		if _planar(point - center).length() < tuning.spawn_min_player_distance:
			continue
		if path_field != null and not path_field.is_walkable(point):
			continue
		return point
	return null


func _move_enemies(delta: float) -> void:
	for bucket: Array in _buckets.values():
		bucket.clear()
	for enemy in enemies:
		var key := Vector2i(floori(enemy.global_position.x), floori(enemy.global_position.z))
		if not _buckets.has(key):
			_buckets[key] = []
		_buckets[key].append(enemy)
	if _buckets.size() > 4096:
		_buckets.clear()

	var penalty := grid.lowered_speed_penalty() if grid != null else 0.0
	# Copia riusata: un nemico che muore durante il passo esce subito dall'elenco.
	_step_list.clear()
	_step_list.append_array(enemies)
	for enemy: Enemy in _step_list:
		if enemy.is_dead:
			continue
		enemy.tick_visuals(delta)
		if enemy.self_driven:
			enemy.drive(delta)
			continue
		var pos := enemy.global_position
		var to_player := _planar(player.global_position - pos)
		var direction := Vector3.ZERO
		if enemy.has_errand:
			# Commissione del boss (D-045): dritto al punto, senza guinzaglio.
			var to_errand := _planar(enemy.errand_point - pos)
			if to_errand.length() <= ERRAND_REACH:
				enemy.errand_reached.emit(enemy)
			else:
				direction = to_errand.normalized()
		else:
			# Fuori guinzaglio, o fuori dalla finestra del campo (dove andrebbe dritto e
			# resterebbe nelle rovine, E-01): torna sull'anello.
			var lost := to_player.length() > tuning.enemy_leash_distance
			if not lost and path_field != null and path_field.is_ready() and to_player.length() > tuning.spawn_ring_max + 1.0 					and not path_field.is_inside(path_field.cell_of(pos)):
				lost = true
			if lost and _leash(enemy):
				continue
			if to_player.length() > DIRECT_CHASE_DISTANCE and path_field != null:
				var waypoint: Variant = path_field.next_waypoint(pos)
				if waypoint != null:
					direction = _planar(waypoint - pos).normalized()
			if direction.is_zero_approx():
				direction = to_player.normalized()
		direction += _separation(enemy) * SEPARATION_WEIGHT
		var speed := tuning.enemy_speed * enemy.speed_scale
		if grid != null and grid.cell_state_at(pos) == TerrainState.CellState.LOWERED:
			speed *= 1.0 - penalty
		var desired := direction.limit_length(1.0) * speed
		var planar := Vector3(enemy.velocity.x, 0.0, enemy.velocity.z).move_toward(desired, ACCELERATION * delta)
		enemy.velocity = Vector3(planar.x, 0.0 if enemy.is_on_floor() else enemy.velocity.y - 9.8 * delta, planar.z)
		enemy.move_and_slide()
		if planar.length() > 0.2:
			enemy.rotation.y = atan2(-planar.x, -planar.z)
		_apply_contacts(enemy)


## Riporta un nemico disperso sull'anello di comparsa. False se non c'e posto.
func _leash(enemy: Enemy) -> bool:
	var point: Variant = _find_spawn_point()
	if point == null:
		return false
	enemy.global_position = Vector3(point.x, Enemy.spawn_height(), point.z)
	# Teletrasporto: senza questo l'interpolazione fisica disegna una striscia di 40 m.
	enemy.reset_physics_interpolation()
	enemy.velocity = Vector3.ZERO
	leashed += 1
	return true


func _apply_contacts(enemy: Enemy) -> void:
	if enemy.is_dead:
		return
	if _planar(player.global_position - enemy.global_position).length() <= tuning.contact_radius:
		player.take_damage(tuning.contact_damage)
		enemy.notify_contact()
	if spike_damage > 0 and enemy.spike_cooldown <= 0.0 and grid != null:
		for i in enemy.get_slide_collision_count():
			var collider := enemy.get_slide_collision(i).get_collider() as Node
			if collider != null and collider.get_parent() == grid:
				enemy.spike_cooldown = spike_interval
				enemy.take_damage(spike_damage)
				break


func _separation(enemy: Enemy) -> Vector3:
	var push := Vector3.ZERO
	var base := Vector2i(floori(enemy.global_position.x), floori(enemy.global_position.z))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := base + Vector2i(dx, dz)
			if not _buckets.has(key):
				continue
			for other: Enemy in _buckets[key]:
				if other == enemy:
					continue
				var away := _planar(enemy.global_position - other.global_position)
				var distance := away.length()
				if distance < SEPARATION_RADIUS and distance > 0.001:
					push += away / distance * (1.0 - distance / SEPARATION_RADIUS)
	return push


func _on_enemy_died(enemy: Enemy) -> void:
	enemies.erase(enemy)
	kills += 1
	var pos := enemy.global_position
	enemy.collision_layer = 0
	enemy.collision_mask = 0
	var tween := enemy.create_tween()
	tween.tween_property(enemy, ^"scale", Vector3.ONE * 0.05, 0.12)
	tween.tween_callback(enemy.queue_free)
	if enemy.self_driven:
		DebrisBurst.spawn(self, pos, Demolisher.BODY_COLOR, 28, 7.0, 0.3)
	else:
		DebrisBurst.spawn(self, pos, BODY_COLOR, 6)
	print("PROTOTYPE01_ENEMY_KILLED total=%d" % kills)
	enemy_killed.emit(pos, kills)


static func _planar(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
