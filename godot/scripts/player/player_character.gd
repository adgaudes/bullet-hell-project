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
signal health_changed(health: int, max_health: int)
signal died
## Lo strumento terreno non ha potuto agire: cella non valida o niente rottami.
signal terrain_tool_rejected

enum AimDevice { GAMEPAD, MOUSE }

## Azioni con semantica Started di Unreal: un comando per pressione.
const STARTED_ACTIONS: Array[StringName] = [&"dash", &"terrain_tool", &"terrain_mode"]

const BODY_COLOR_LINEAR := Color(1.0, 0.35, 0.02)
const HIT_COLOR_LINEAR := Color(1.0, 0.02, 0.02)
const HIT_FLASH_SECONDS := 0.3

# --- Movimento procedurale (ActorMotion): solo sul nodo visivo `Model`. La scala del
# dash resta su `_body` (figlio di `Model`) e i colori sul materiale: si compongono.
## Radianti di fase per metro: il passo segue la strada fatta (circa 3,5 passi/s in corsa).
const STRIDE_RADIANS_PER_METER := 1.7
## Altezza (m) del saltello a ogni passo, a piena velocita di cammino.
const STRIDE_BOB := 0.07
## Velocita (1/s) con cui il saltello entra ed esce (anche quando parte il dash).
const STRIDE_BLEND_RATE := 10.0
## Inclinazione (rad) verso la direzione di marcia a piena velocita di cammino, e tetto
## del rapporto di velocita: nel dash si piega di piu, ma non oltre LEAN_ANGLE * LEAN_SPEED_CAP.
const LEAN_ANGLE := 0.12
const LEAN_SPEED_CAP := 1.8
## Velocita (1/s) con cui l'inclinazione insegue il movimento.
const LEAN_RATE := 14.0
## Dash: schiacciamento alla partenza e allungamento all'arrivo (frazione dell'altezza),
## durata dell'impulso (s). La larghezza compensa di meta, per conservare il volume a occhio.
const DASH_SQUASH := 0.2
const DASH_STRETCH := 0.14
const DASH_PULSE_SECONDS := 0.13
## Rinculo della chiodatrice: durata (s), arretramento (m) e inclinazione (rad) opposti al colpo.
const RECOIL_SECONDS := 0.1
const RECOIL_BACK := 0.07
const RECOIL_TILT := 0.07
## Sussulto quando e colpito: durata (s), schiacciamento (frazione), arretramento (m), busto indietro (rad).
const FLINCH_SECONDS := 0.24
const FLINCH_SQUASH := 0.14
const FLINCH_BACK := 0.1
const FLINCH_PITCH := 0.16

@export var tuning: PlayerTuning
## Griglia su cui agisce il tool (SetTerrainGrid in Unreal). Opzionale.
@export var terrain_grid: TerrainGrid
## Opzionale: nodo col segnale `fired` (la chiodatrice). Se presente ogni colpo da un
## rinculo visivo; se ha `last_fire_direction` il rinculo e opposto al colpo.
@export var recoil_source: Node

## Scala la velocita massima senza toccare il tuning; ricalcolato a ogni passo
## dalla cella sotto il personaggio (UpdateTerrainSpeedModifier).
var speed_multiplier := 1.0
var aim_device := AimDevice.GAMEPAD
var is_dashing := false
var is_dash_on_cooldown := false
var terrain_tool_mode := TerrainState.ToolMode.DIG
## Punto mondo bersaglio del tool, aggiornato a ogni passo fisico.
var terrain_target := Vector3.ZERO
## Compagno macchina (Companion Slice): se presente, rialzare costa un rottame
## e richiede il compagno vicino al bersaglio. Si registra da solo.
var companion: Companion
## Punti vita (prototipo della promessa A, D-038). Senza un ArenaRun che li
## imposta il personaggio non muore: le altre scene restano invariate.
var max_health := 0
var health := 0
var invulnerability_seconds := 0.8
## Moltiplicatore permanente della velocita (upgrade), combinato col terreno.
var speed_bonus := 1.0
## Portata in piu del tool, in centimetri Unreal (upgrade permanente Prolunga, D-049).
var tool_range_bonus_cm := 0.0
var _invulnerable_left := 0.0

var _movement := PlanarMovement.new()
## Ultima direzione di movimento valida (normalizzata): direzione del dash.
var _last_valid_move_direction := Vector3.ZERO
var _dash_direction := Vector3.ZERO
## Tempo dall'attivazione del dash: durata e cooldown si misurano entrambi da qui.
var _time_since_dash := 0.0
var _effective_dash_duration := 0.0
var _held_actions: Dictionary[StringName, bool] = {}
var _pending_actions: Array[StringName] = []
var _body_material := StandardMaterial3D.new()
var _base_body_scale := Vector3.ONE
var _hit_flash_left := 0.0
## Stato del movimento procedurale (vedi le costanti STRIDE_*, LEAN_*, DASH_*, RECOIL_*, FLINCH_*).
var _model_rest := Transform3D.IDENTITY
var _stride_phase := 0.0
var _stride_weight := 0.0
var _lean_pitch := 0.0
var _lean_roll := 0.0
var _was_dashing := false
## Negativo = schiacciato (partenza del dash), positivo = allungato (arrivo); torna a 0.
var _dash_pulse := 0.0
var _recoil := 0.0
## Direzione del rinculo nello spazio del personaggio (unitaria).
var _recoil_direction := Vector3.BACK
var _flinch := 0.0
var _motion_at_rest := true

## Mesh del modello (tools/blender/build_actor_assets.py, `player_engineer`): la tuta
## e la superficie `suit`, colorata da `_body_material`; il resto ha colori fissi.
@onready var _body: MeshInstance3D = ActorModel.mesh_instance_of($Model)
@onready var _collision: CollisionShape3D = $Collision
## Radice del modello: l'unico nodo mosso dal movimento procedurale.
@onready var _model: Node3D = $Model


func _ready() -> void:
	if tuning == null:
		tuning = PlayerTuning.new()
	_movement.configure(tuning)

	# Il colore di vertice della tuta e solo ombreggiatura: la tinta e lo stato (dash, colpo).
	_body_material.vertex_color_use_as_albedo = true
	_body_material.roughness = 0.8
	ActorModel.apply_materials(_body, {
		"suit": _body_material,
		# Lampada dell'elmetto e punta dell'attrezzo: l'indicatore del fronte, luminoso.
		"detail": ActorModel.paint_material(Color.WHITE, 2.5),
	})
	_base_body_scale = _body.scale
	_set_body_color(BODY_COLOR_LINEAR)
	_model_rest = _model.transform
	if recoil_source != null and recoil_source.has_signal(&"fired"):
		recoil_source.connect(&"fired", _on_recoil_source_fired)

	print("PROTOTYPE01_CHARACTER_READY")
	if terrain_grid != null:
		_update_terrain_target()
		print("PROTOTYPE01_TERRAIN_MODE Dig")


func _input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and motion.relative.length() > tuning.mouse_aim_delta_threshold:
		_set_aim_device(AimDevice.MOUSE)


## Rileva il fronte di pressione: un grilletto analogico invia un evento a ogni
## variazione sopra la dead zone e non deve ripetere il comando. I modificatori
## sono ignorati come in Unreal. Il comando e eseguito al passo fisico successivo,
## come l'input Unreal elaborato prima del Tick: nessuna pressione va persa.
func _unhandled_input(event: InputEvent) -> void:
	for action in STARTED_ACTIONS:
		if not event.is_action(action):
			continue
		var pressed := event.is_action_pressed(action)
		if pressed and not _held_actions.get(action, false):
			_pending_actions.append(action)
		_held_actions[action] = pressed


func _run_pending_actions() -> void:
	for action in _pending_actions:
		match action:
			&"dash":
				_start_dash()
			&"terrain_tool":
				_use_terrain_tool()
			&"terrain_mode":
				_toggle_terrain_mode()
	_pending_actions.clear()


func _physics_process(delta: float) -> void:
	_run_pending_actions()
	_update_terrain_speed_modifier()
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
	_update_hit_flash(delta)
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	_update_terrain_target()
	_update_motion(delta)


## Sopra una cella Lowered la velocita massima perde la penalita della griglia.
func _update_terrain_speed_modifier() -> void:
	speed_multiplier = speed_bonus
	if terrain_grid != null and terrain_grid.cell_state_at(global_position) == TerrainState.CellState.LOWERED:
		speed_multiplier *= 1.0 - terrain_grid.lowered_speed_penalty()


func _use_terrain_tool() -> void:
	if terrain_grid == null:
		return
	_update_terrain_target()
	var raising := terrain_tool_mode == TerrainState.ToolMode.RAISE
	if raising and companion != null 			and terrain_grid.can_apply_at(terrain_target, terrain_tool_mode, self) 			and not companion.can_supply(terrain_target):
		print("PROTOTYPE01_TERRAIN_RAISE_NO_SCRAP")
		terrain_tool_rejected.emit()
		return
	if not terrain_grid.apply_command_at(terrain_target, terrain_tool_mode, self):
		terrain_tool_rejected.emit()
	elif raising and companion != null:
		companion.spend()
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
	terrain_target = global_position + forward.normalized() * UnrealSpace.length(maxf(tuning.terrain_tool_range_cm, 100.0) + tool_range_bonus_cm)
	var missing_scrap := terrain_tool_mode == TerrainState.ToolMode.RAISE 		and companion != null and not companion.can_supply(terrain_target)
	terrain_grid.update_preview(terrain_target, terrain_tool_mode, self, missing_scrap)


## Sostituisce il tuning a caldo (preset di feel). Lo stato del dash in corso resta valido.
func apply_tuning(new_tuning: PlayerTuning) -> void:
	tuning = new_tuning
	_movement.configure(tuning)


## Volume collidente in coordinate mondo, come GetActorBounds(true) in Unreal.
## Usato dalla griglia terreno per non rialzare celle sopra il personaggio.
func get_collision_aabb() -> AABB:
	var capsule := _collision.shape as CapsuleShape3D
	var extent := Vector3(capsule.radius, capsule.height * 0.5, capsule.radius)
	return AABB(_collision.global_position - extent, extent * 2.0)


## Legge il movimento e aggiorna l'ultima direzione valida, come HandleMoveTriggered.
func _read_move_direction() -> Vector3:
	# Valore grezzo, senza la dead zone delle azioni: come il trigger Down di
	# IA_Move, sotto la soglia di attuazione non c'e movimento e sopra conta
	# il modulo reale dello stick.
	var move_input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back", 0.0)
	if move_input.length() < tuning.move_actuation_threshold:
		move_input = Vector2.ZERO
	var move_direction := Vector3(move_input.x, 0.0, move_input.y)
	if not move_direction.is_zero_approx():
		_last_valid_move_direction = move_direction.normalized()
	return move_direction


## Stick destro senza dead zone di azione: la dead zone e applicata come in Unreal.
func _raw_aim_input() -> Vector2:
	var aim_input := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down", 0.0)
	# Autoload cercato a runtime: i test precaricano le scene prima che gli
	# autoload esistano, e il nome globale non compilerebbe.
	var settings := get_node_or_null(^"/root/GameSettings")
	if settings != null:
		if settings.invert_aim_x:
			aim_input.x = -aim_input.x
		if settings.invert_aim_y:
			aim_input.y = -aim_input.y
	return aim_input


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


func set_max_health(value: int, heal_full := true) -> void:
	max_health = maxi(value, 1)
	health = max_health if heal_full else mini(health, max_health)
	health_changed.emit(health, max_health)


## Recupera vita fino al massimo; non rianima.
func heal(amount: int) -> void:
	if health <= 0 or amount <= 0:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func is_alive() -> bool:
	return max_health <= 0 or health > 0


## Danno con breve invulnerabilita. Restituisce true se il colpo e andato a segno.
func take_damage(amount: int) -> bool:
	if max_health <= 0 or health <= 0 or _invulnerable_left > 0.0:
		return false
	health = maxi(health - amount, 0)
	_invulnerable_left = invulnerability_seconds
	on_hit()
	print("PROTOTYPE01_PLAYER_DAMAGED health=%d" % health)
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()
	return true


## Colpito dalla sfera (Companion Slice): lampo rosso, nessun danno.
func on_hit() -> void:
	_hit_flash_left = HIT_FLASH_SECONDS
	_body_material.albedo_color = HIT_COLOR_LINEAR.linear_to_srgb()
	_flinch = 1.0


func _update_hit_flash(delta: float) -> void:
	if _hit_flash_left <= 0.0:
		return
	_hit_flash_left -= delta
	if _hit_flash_left <= 0.0:
		var color := BODY_COLOR_LINEAR
		if is_dashing:
			color = tuning.dash_color_linear
		elif is_dash_on_cooldown:
			color = tuning.dash_cooldown_color_linear
		_set_body_color(color)


func _set_body_color(linear_color: Color) -> void:
	_body_material.albedo_color = linear_color.linear_to_srgb()


# --- Movimento procedurale ---------------------------------------------------------------

## Rinculo visivo di un colpo. [param world_direction] e la direzione in cui il corpo
## viene spinto (opposta al colpo); se e zero, all'indietro rispetto a dove guarda.
## Non conosce l'arma: lo chiama chi la collega (vedi anche `recoil_source`).
func kick(world_direction := Vector3.ZERO) -> void:
	var local := Vector3(world_direction.x, 0.0, world_direction.z) * global_basis
	_recoil_direction = local.normalized() if local.length_squared() > 1e-6 else Vector3.BACK
	_recoil = 1.0


func _on_recoil_source_fired(_count: int = 1) -> void:
	var shot: Variant = recoil_source.get(&"last_fire_direction")
	kick(-(shot as Vector3) if shot is Vector3 else Vector3.ZERO)


## Passo, inclinazione, impulsi del dash, rinculo e sussulto, sommati in una sola
## trasformazione di `Model` a partire dalla posa di riposo. Legge lo stato di gioco,
## non lo cambia.
func _update_motion(delta: float) -> void:
	if not ActorMotion.enabled:
		if not _motion_at_rest:
			_model.transform = _model_rest
			_motion_at_rest = true
		return
	var walk_speed := maxf(UnrealSpace.length(tuning.planar_move_speed_cm), 0.01)
	# Velocita nello spazio del personaggio: guarda e si muove in direzioni indipendenti.
	var local_velocity := Vector3(velocity.x, 0.0, velocity.z) * global_basis
	var planar_speed := Vector2(local_velocity.x, local_velocity.z).length()

	_stride_weight = move_toward(_stride_weight,
		0.0 if is_dashing else minf(planar_speed / walk_speed, 1.0), STRIDE_BLEND_RATE * delta)
	_stride_phase = fmod(_stride_phase + minf(planar_speed, walk_speed) * STRIDE_RADIANS_PER_METER * delta, TAU)
	var bob := absf(sin(_stride_phase)) * STRIDE_BOB * _stride_weight

	var lean := local_velocity.limit_length(walk_speed * LEAN_SPEED_CAP) / walk_speed * LEAN_ANGLE
	# Avanti e -Z: beccheggio negativo = busto in avanti; rollio negativo = verso destra.
	_lean_pitch = ActorMotion.smooth(_lean_pitch, lean.z, LEAN_RATE, delta)
	_lean_roll = ActorMotion.smooth(_lean_roll, -lean.x, LEAN_RATE, delta)
	var pitch := _lean_pitch
	var roll := _lean_roll
	var slide := Vector3.ZERO

	if is_dashing != _was_dashing:
		_was_dashing = is_dashing
		_dash_pulse = -1.0 if is_dashing else 1.0
	_dash_pulse = move_toward(_dash_pulse, 0.0, delta / DASH_PULSE_SECONDS)
	var pulse := _dash_pulse * _dash_pulse
	var height := 1.0 + (pulse * DASH_STRETCH if _dash_pulse > 0.0 else -pulse * DASH_SQUASH)

	if _recoil > 0.0:
		_recoil = maxf(_recoil - delta / RECOIL_SECONDS, 0.0)
		var punch := _recoil * _recoil
		slide += _recoil_direction * (RECOIL_BACK * punch)
		pitch += _recoil_direction.z * RECOIL_TILT * punch
		roll -= _recoil_direction.x * RECOIL_TILT * punch
	if _flinch > 0.0:
		_flinch = maxf(_flinch - delta / FLINCH_SECONDS, 0.0)
		var hurt := _flinch * _flinch
		height *= 1.0 - FLINCH_SQUASH * hurt
		slide.z += FLINCH_BACK * hurt
		pitch += FLINCH_PITCH * hurt

	var width := 1.0 - (height - 1.0) * 0.5
	var pose := Basis.from_euler(Vector3(pitch, 0.0, roll)).scaled_local(Vector3(width, height, width))
	_model.transform = _model_rest * Transform3D(pose, Vector3(slide.x, bob, slide.z))
	_motion_at_rest = false
