class_name CementMixer
extends ActiveWeapon
## Betoniera (spec D-092, par. 4.5), attiva del kit comune: una pozza di cemento di raggio
## `pool_radius` nel punto di mira; per `block_seconds` chi c'e dentro (anche chi ci entra) resta
## bloccato. Poi indurisce: un dosso di `bump_height` dipinto a lastricato. Bivi: Doppia colata
## (due pozze affiancate), Muro di getto (dosso da 1,2 m), Presa rapida (danno ai bloccati
## all'indurimento), Pavimento (spiana alla base invece del dosso: una piazzola liscia).

const POOL_COLOR := Color(0.55, 0.55, 0.52)
## Lo stordimento si rinnova a ogni passo per questo tempo: chi esce dalla pozza riparte subito.
const HOLD_STEP := 0.15
## Passo e raggio dei dischi del dosso dentro la pozza.
const BUMP_STEP := 1.0
const BUMP_DISC := 1.0

## Pozze: {center, radius, left, stuck: Array[Enemy], view: MeshInstance3D}.
var _pools: Array[Dictionary] = []


func pool_count() -> int:
	return _pools.size()


func _fire(at: Vector3) -> void:
	var radius := stat(&"pool_radius")
	var centers: Array[Vector3] = [at]
	if int(stat(&"pools")) >= 2:
		var origin := shooter.global_position
		var forward := Vector3(at.x - origin.x, 0.0, at.z - origin.z)
		forward = forward.normalized() if forward.length_squared() > 1e-4 else Vector3.FORWARD
		var side := forward.cross(Vector3.UP).normalized()
		centers = [at + side * radius, at - side * radius]
	for center in centers:
		_pools.append({center = center, radius = radius, left = stat(&"block_seconds"), stuck = [], view = _make_view(center, radius)})


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	for k in range(_pools.size() - 1, -1, -1):
		var pool: Dictionary = _pools[k]
		pool.left -= delta
		if director != null:
			for enemy in director.enemies_near(pool.center, pool.radius):
				if enemy.is_dead:
					continue
				enemy.stun(HOLD_STEP)
				if not (pool.stuck as Array).has(enemy):
					pool.stuck.append(enemy)
		var view: MeshInstance3D = pool.view
		view.transparency = clampf(0.6 - pool.left * 0.2, 0.0, 0.6)
		if pool.left <= 0.0:
			_harden(pool)
			view.queue_free()
			_pools.remove_at(k)


func _harden(pool: Dictionary) -> void:
	_sound(&"hit")
	var set_damage := int(stat(&"set_damage"))
	if set_damage > 0 and director != null:
		for enemy: Enemy in director.enemies_near(pool.center, pool.radius):
			if not enemy.is_dead:
				enemy.take_damage(set_damage)
	if terrain_field == null or write_queue == null:
		return
	var center: Vector3 = pool.center
	var radius: float = pool.radius
	var flatten := stat(&"flatten") > 0.0
	var height := stat(&"bump_height")
	var reach := ceili(radius / BUMP_STEP)
	for ix in range(-reach, reach + 1):
		for iz in range(-reach, reach + 1):
			var offset := Vector3(ix * BUMP_STEP, 0.0, iz * BUMP_STEP)
			if offset.length() > radius - 0.3:
				continue
			var p := center + offset
			var base := terrain_field.base_height_at(p)
			write_queue.push_level(p, BUMP_DISC, base if flatten else base + height)
	terrain_field.paint_layer(center, radius, TerrainSurface.LAYER_SLABS)


func _make_view(center: Vector3, radius: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.06
	mesh.radial_segments = 24
	mesh.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = POOL_COLOR.linear_to_srgb()
	material.roughness = 0.2
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.top_level = true
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	var ground := terrain_field.height_at(center) if terrain_field != null else center.y
	view.global_position = Vector3(center.x, ground + 0.04, center.z)
	view.reset_physics_interpolation()
	return view
