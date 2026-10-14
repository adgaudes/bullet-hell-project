class_name AutoWeapon
extends Node3D
## Chiodatrice automatica (D-038): spara da sola al nemico piu vicino in linea di
## tiro. I chiodi volano all'altezza di chi spara e si fermano sul mondo statico:
## una cella Raised (alta 1,2 m) protegge ma blocca anche i propri colpi.
## Usata dal giocatore e, con l'upgrade Torretta, dal compagno.

signal fired(count: int)

const NAIL_COLOR := Color(1.0, 0.85, 0.35)
const NAIL_LENGTH := 0.42
const HIT_RADIUS := 0.45
const MAX_NAILS := 64
## Senza linea di tiro si riprova dopo questo tempo, non a ogni passo (R-35).
const BLOCKED_RETRY := 0.08
## Candidati provati col raggio per colpo: i piu vicini bastano.
const MAX_CANDIDATES := 8

@export var shooter: Node3D
@export var director: EnemyDirector
## Altezza di sparo rispetto all'origine di chi spara.
@export var muzzle_height := 0.0
## Distanza della canna dall'origine, lungo la direzione del colpo (O-04).
@export var muzzle_forward := 0.0
## Mira manuale (D-089): spara dove guarda chi spara (`facing_direction()`), quando c'e un
## nemico in portata; altrimenti al nemico piu vicino, girando chi spara verso di lui.
@export var manual_aim := false
@export var fire_interval := 0.5
@export var weapon_range := 9.0
@export var damage := 1
@export var projectile_speed := 24.0
## Nemici attraversati oltre il primo.
@export var pierce := 0
## Chiodi per colpo, a ventaglio.
@export var projectiles := 1
@export var spread_degrees := 12.0

## Direzione planare (unitaria) dell'ultimo colpo: chi ascolta `fired` la usa per il rinculo.
var last_fire_direction := Vector3.ZERO
var _cooldown := 0.3
var _nails: Array[Dictionary] = []
var _mesh := BoxMesh.new()
var _material := StandardMaterial3D.new()


func _ready() -> void:
	_mesh.size = Vector3(0.07, 0.07, NAIL_LENGTH)
	_material.albedo_color = NAIL_COLOR.linear_to_srgb()
	_material.emission_enabled = true
	_material.emission = NAIL_COLOR.linear_to_srgb()
	_material.emission_energy_multiplier = 1.5
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _physics_process(delta: float) -> void:
	_move_nails(delta)
	if shooter == null or director == null:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	if manual_aim and shooter.has_method(&"facing_direction"):
		if director.enemies_near(muzzle(), weapon_range).is_empty():
			_cooldown = BLOCKED_RETRY
			return
		_cooldown = fire_interval
		_fire_toward(shooter.facing_direction())
		return
	var target := find_target()
	if target == null:
		_cooldown = BLOCKED_RETRY
		return
	_cooldown = fire_interval
	_fire_at(target)


func muzzle() -> Vector3:
	return shooter.global_position + Vector3(0.0, muzzle_height, 0.0)


## Punto da cui parte il chiodo: la canna, davanti a chi spara nella direzione del colpo.
func muzzle_toward(direction: Vector3) -> Vector3:
	return muzzle() + direction * muzzle_forward


## Nemico vivo piu vicino entro la portata con linea di tiro libera, o null.
func find_target() -> Enemy:
	var origin := muzzle()
	var candidates := director.enemies_near(origin, weapon_range)
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
	var space := get_world_3d().direct_space_state
	var tried := 0
	for enemy in candidates:
		if enemy.is_dead:
			continue
		if tried >= MAX_CANDIDATES:
			break
		tried += 1
		var aim := Vector3(enemy.global_position.x, origin.y, enemy.global_position.z)
		var query := PhysicsRayQueryParameters3D.create(origin, aim, 1)
		if space.intersect_ray(query).is_empty():
			return enemy
	return null


func nail_count() -> int:
	return _nails.size()


func _fire_at(target: Enemy) -> void:
	var base := muzzle()
	var forward := Vector3(target.global_position.x - base.x, 0.0, target.global_position.z - base.z).normalized()
	if shooter.has_method(&"face_shot"):
		shooter.face_shot(forward)
	_fire_toward(forward)


func _fire_toward(forward: Vector3) -> void:
	var origin := muzzle_toward(forward)
	last_fire_direction = forward
	var count := maxi(projectiles, 1)
	for i in count:
		if _nails.size() >= MAX_NAILS:
			break
		var angle := deg_to_rad(spread_degrees) * (i - (count - 1) * 0.5)
		var direction := forward.rotated(Vector3.UP, angle)
		var nail := MeshInstance3D.new()
		nail.mesh = _mesh
		nail.material_override = _material
		nail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(nail)
		nail.global_position = origin
		nail.look_at(origin + direction, Vector3.UP)
		_nails.append({node = nail, direction = direction, travelled = 0.0, pierce = pierce, hit = []})
	fired.emit(count)


## Query del chiodo riusata a ogni tratto (audit E-15: prima una nuova per chiodo e passo).
var _ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 1)


func _move_nails(delta: float) -> void:
	if _nails.is_empty():
		return
	var space := get_world_3d().direct_space_state
	var step := projectile_speed * delta
	var enemies := director.enemies if director != null else []
	# Scarto rapido (audit E-15): oltre questa distanza dal punto medio del tratto nessun
	# nemico puo essere colpito, qualunque sia il suo bonus di raggio.
	var reach := step * 0.5 + HIT_RADIUS + _max_hit_bonus(enemies)
	var reach_squared := reach * reach
	for k in range(_nails.size() - 1, -1, -1):
		var nail: Dictionary = _nails[k]
		var node: MeshInstance3D = nail.node
		var from := node.global_position
		var to: Vector3 = from + nail.direction * step
		var alive := true
		_ray.from = from
		_ray.to = to
		var wall := space.intersect_ray(_ray)
		var mid := (from + to) * 0.5
		if not wall.is_empty():
			to = wall.position
			alive = false
		if director != null:
			# Indietro: un nemico ucciso qui esce da `enemies` durante il ciclo.
			for e in range(enemies.size() - 1, -1, -1):
				if e >= enemies.size():
					continue
				var enemy: Enemy = enemies[e]
				var ex := enemy.global_position.x - mid.x
				var ez := enemy.global_position.z - mid.z
				if ex * ex + ez * ez > reach_squared:
					continue
				if enemy.is_dead or nail.hit.has(enemy):
					continue
				if _segment_distance(from, to, enemy.global_position) <= HIT_RADIUS + enemy.hit_radius_bonus:
					nail.hit.append(enemy)
					enemy.take_damage(damage)
					if nail.pierce <= 0:
						alive = false
						break
					nail.pierce -= 1
		nail.travelled += step
		if nail.travelled >= weapon_range * 1.3:
			alive = false
		if alive:
			node.global_position = to
		else:
			_nails.remove_at(k)
			node.queue_free()


func _max_hit_bonus(enemies: Array) -> float:
	var bonus := 0.0
	for enemy: Enemy in enemies:
		bonus = maxf(bonus, enemy.hit_radius_bonus)
	return bonus


## Distanza planare del punto dal segmento.
static func _segment_distance(a: Vector3, b: Vector3, p: Vector3) -> float:
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var p2 := Vector2(p.x, p.z)
	var ab := b2 - a2
	var t := 0.0
	if ab.length_squared() > 1e-8:
		t = clampf((p2 - a2).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (a2 + ab * t).distance_to(p2)
