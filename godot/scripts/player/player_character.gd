class_name PlayerCharacter
extends CharacterBody3D
## Personaggio graybox: porta di APrototype01Character.
##
## Movimento planare analogico, orientamento indipendente (stick destro o mouse
## deproiettato sul piano del personaggio), commutazione automatica del
## dispositivo di mira, dash con cooldown e feedback solo visivo, tool terreno
## con bersaglio fisso davanti al personaggio.
## L'origine e al centro della capsula, come la location dell'attore Unreal.

signal dash_started
signal dash_ready
signal aim_device_changed(device: AimDevice)

enum AimDevice { GAMEPAD, MOUSE }

const BODY_COLOR_LINEAR := Color(1.0, 0.35, 0.02)
const FACING_INDICATOR_COLOR_LINEAR := Color(0.0, 0.8, 1.0)

@export var tuning: PlayerTuning
## Griglia su cui agisce il tool (SetTerrainGrid in Unreal). Opzionale.
@export var terrain_grid: TerrainGrid

## Scala la velocita massima senza toccare il tuning (penalita terreno, Fase 8).
var speed_multiplier := 1.0
var aim_device := AimDevice.GAMEPAD
var is_dashing := false
var is_dash_on_cooldown := false
var terrain_tool_mode := TerrainState.ToolMode.DIG
## Punto mondo bersaglio del tool, aggiornato a ogni passo fisico.
var terrain_target := Vector3.ZERO

var _movement := PlanarMovement.new()
## Ultima direzione di movimento valida (normalizzata): direzione del dash.
var _last_valid_move_direction := Vector3.ZERO
var _dash_direction := Vector3.ZERO
## Tempo dall'attivazione del dash: durata e cooldown si misurano entrambi da qui.
var _time_since_dash := 0.0
var _effective_dash_duration := 0.0
var _body_material := StandardMaterial3D.new()
var _base_body_scale := Vector3.ONE

@onready var _body: MeshInstance3D = $Body
@onready var _facing_indicator: MeshInstance3D = $FacingIndicator
@onready var _collision: CollisionShape3D = $Collision


func _ready() -> void:
	if tuning == null:
		tuning = PlayerTuning.new()
	_movement.configure(tuning)

	_body.material_override = _body_material
	_base_body_scale = _body.scale
	_set_body_color(BODY_COLOR_LINEAR)
	var indicator_material := StandardMaterial3D.new()
	indicator_material.albedo_color = FACING_INDICATOR_COLOR_LINEAR.linear_to_srgb()
	_facing_indicator.material_override = indicator_material

	print("PROTOTYPE01_CHARACTER_READY")
	if terrain_grid != null:
		_update_terrain_target()
		print("PROTOTYPE01_TERRAIN_MODE Dig")


func _input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and motion.relative.length() > tuning.mouse_aim_delta_threshold:
		_set_aim_device(AimDevice.MOUSE)


func _unhandled_input(event: InputEvent) -> void:
	# A eventi come il trigger Started di Unreal: nessuna pressione persa tra due passi fisici.
	if event.is_action_pressed(&"dash", false, true):
		_start_dash()
	elif event.is_action_pressed(&"terrain_tool", false, true):
		_use_terrain_tool()
	elif event.is_action_pressed(&"terrain_mode", false, true):
		_toggle_terrain_mode()


func _physics_process(delta: float) -> void:
	var move_direction := _read_move_direction()

	var aim_input := _raw_aim_input()
	if aim_input.length_squared() > tuning.aim_stick_dead_zone * tuning.aim_stick_dead_zone:
		_set_aim_device(AimDevice.GAMEPAD)
	_apply_facing_rotation(aim_input, delta)

	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var requested := Vector3.ZERO
	if is_dashing:
		planar = _dash_direction * UnrealSpace.length(tuning.dash_speed_cm)
	else:
		requested = move_direction.limit_length(1.0)
	planar = _movement.calc_velocity(planar, requested, delta, speed_multiplier)

	velocity.x = planar.x
	velocity.z = planar.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta
	move_and_slide()

	# Dopo il movimento, come il TimerManager Unreal che avanza a fine tick.
	_update_dash_timers(delta)
	_update_terrain_target()


func _use_terrain_tool() -> void:
	if terrain_grid == null:
		return
	_update_terrain_target()
	terrain_grid.apply_command_at(terrain_target, terrain_tool_mode, self)
	_update_terrain_target()


func _toggle_terrain_mode() -> void:
	terrain_tool_mode = TerrainState.ToolMode.RAISE 		if terrain_tool_mode == TerrainState.ToolMode.DIG else TerrainState.ToolMode.DIG
	print("PROTOTYPE01_TERRAIN_MODE %s" % ("Dig" if terrain_tool_mode == TerrainState.ToolMode.DIG else "Raise"))
	_update_terrain_target()


## Bersaglio a distanza fissa lungo il forward planare, con anteprima sulla griglia.
func _update_terrain_target() -> void:
	if terrain_grid == null:
		return
	var forward := -global_basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		terrain_grid.hide_preview()
		return
	terrain_target = global_position + forward.normalized() * UnrealSpace.length(maxf(tuning.terrain_tool_range_cm, 100.0))
	terrain_grid.update_preview(terrain_target, terrain_tool_mode, self)


## Volume collidente in coordinate mondo, come GetActorBounds(true) in Unreal.
## Usato dalla griglia terreno per non rialzare celle sopra il personaggio.
func get_collision_aabb() -> AABB:
	var capsule := _collision.shape as CapsuleShape3D
	var extent := Vector3(capsule.radius, capsule.height * 0.5, capsule.radius)
	return AABB(_collision.global_position - extent, extent * 2.0)


## Legge il movimento e aggiorna l'ultima direzione valida, come HandleMoveTriggered.
func _read_move_direction() -> Vector3:
	var move_input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var move_direction := Vector3(move_input.x, 0.0, move_input.y)
	if not move_direction.is_zero_approx():
		_last_valid_move_direction = move_direction.normalized()
	return move_direction


## Stick destro senza dead zone di azione: la dead zone e applicata come in Unreal.
func _raw_aim_input() -> Vector2:
	return Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down", 0.0)


func _set_aim_device(device: AimDevice) -> void:
	if aim_device == device:
		return
	aim_device = device
	print("PROTOTYPE01_AIM_DEVICE %s" % ("mouse" if device == AimDevice.MOUSE else "gamepad"))
	aim_device_changed.emit(device)


func _apply_facing_rotation(aim_input: Vector2, delta: float) -> void:
	var direction := Vector3.ZERO
	var interp_speed := tuning.gamepad_aim_rotation_interp_speed

	if aim_device == AimDevice.MOUSE:
		direction = _mouse_aim_direction()
		interp_speed = tuning.mouse_aim_rotation_interp_speed
	else:
		var dead_zone := clampf(tuning.aim_stick_dead_zone, 0.0, 0.99)
		var magnitude := aim_input.length()
		if magnitude > dead_zone:
			var normalized := (minf(magnitude, 1.0) - dead_zone) / (1.0 - dead_zone)
			var response := clampf(normalized * maxf(tuning.gamepad_aim_sensitivity, 0.0), 0.0, 1.0)
			if response > 1e-4:
				direction = Vector3(aim_input.x, 0.0, aim_input.y)
				interp_speed = maxf(tuning.gamepad_aim_rotation_interp_speed, 0.0) * response

	if direction.is_zero_approx():
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = _interp_yaw(rotation.y, target_yaw, delta, interp_speed)


## FMath::RInterpTo ridotto allo yaw.
static func _interp_yaw(current: float, target: float, delta: float, speed: float) -> float:
	if speed <= 0.0:
		return target
	var difference := wrapf(target - current, -PI, PI)
	if absf(difference) < 1e-6:
		return target
	return wrapf(current + difference * clampf(delta * speed, 0.0, 1.0), -PI, PI)


func _mouse_aim_direction() -> Vector3:
	return aim_direction_at_screen(get_viewport().get_mouse_position())


## Deproietta un punto dello schermo sul piano orizzontale passante per il
## personaggio e restituisce la direzione planare verso quel punto.
func aim_direction_at_screen(screen_position: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var origin := camera.project_ray_origin(screen_position)
	var ray := camera.project_ray_normal(screen_position)
	if is_zero_approx(ray.y):
		return Vector3.ZERO
	var t := (global_position.y - origin.y) / ray.y
	if t < 0.0:
		return Vector3.ZERO
	var direction := origin + ray * t - global_position
	direction.y = 0.0
	return direction


func _start_dash() -> void:
	if is_dashing or is_dash_on_cooldown:
		return

	# In Unreal il movimento dello stesso frame e elaborato prima del dash.
	_read_move_direction()
	var forward := -global_basis.z
	forward.y = 0.0
	_dash_direction = _last_valid_move_direction if not _last_valid_move_direction.is_zero_approx() else forward
	_dash_direction.y = 0.0
	_dash_direction = _dash_direction.normalized()
	if _dash_direction.is_zero_approx():
		_dash_direction = forward.normalized()

	is_dashing = true
	_time_since_dash = 0.0
	_effective_dash_duration = maxf(tuning.dash_duration, 0.01)
	_set_body_color(tuning.dash_color_linear)
	_body.scale = _base_body_scale * tuning.dash_scale_multiplier
	print("PROTOTYPE01_DASH_STARTED")
	dash_started.emit()


func _update_dash_timers(delta: float) -> void:
	if not (is_dashing or is_dash_on_cooldown):
		return
	_time_since_dash += delta
	# Tolleranza per l'accumulo di float: 11 * (1/60) deve contare come 0,1833 s.
	if is_dashing and _time_since_dash >= _effective_dash_duration - 1e-6:
		_end_dash()
	if is_dash_on_cooldown and _time_since_dash >= maxf(tuning.dash_cooldown, _effective_dash_duration) - 1e-6:
		_end_dash_cooldown()


func _end_dash() -> void:
	is_dashing = false
	is_dash_on_cooldown = true
	velocity.x = 0.0
	velocity.z = 0.0
	_body.scale = _base_body_scale
	_set_body_color(tuning.dash_cooldown_color_linear)


func _end_dash_cooldown() -> void:
	is_dash_on_cooldown = false
	_set_body_color(BODY_COLOR_LINEAR)
	print("PROTOTYPE01_DASH_READY")
	dash_ready.emit()


func _set_body_color(linear_color: Color) -> void:
	_body_material.albedo_color = linear_color.linear_to_srgb()
