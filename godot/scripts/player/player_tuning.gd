class_name PlayerTuning
extends Resource
## Parametri di tuning del personaggio, con i valori e le unita di
## APrototype01Character (centimetri, secondi, gradi). La conversione in metri
## avviene una sola volta tramite UnrealSpace (D-023).

@export_group("Movement")
## PlanarMoveSpeed, cm/s.
@export var planar_move_speed_cm := 600.0
## MoveAcceleration (MaxAcceleration), cm/s^2.
@export var move_acceleration_cm := 2048.0
## MoveDeceleration (BrakingDecelerationWalking), cm/s^2.
@export var move_deceleration_cm := 2048.0
## GroundFriction: default di UCharacterMovementComponent, mai modificato dal prototipo.
@export var ground_friction := 8.0
## BrakingFrictionFactor: default di UCharacterMovementComponent.
@export var braking_friction_factor := 2.0

## ActuationThreshold di UInputTriggerDown su IA_Move: modulo minimo dello stick.
@export var move_actuation_threshold := 0.5

@export_group("Aim")
@export var aim_stick_dead_zone := 0.2
@export var gamepad_aim_sensitivity := 1.0
@export var gamepad_aim_rotation_interp_speed := 10.0
@export var mouse_aim_rotation_interp_speed := 25.0
## Spostamento minimo del mouse, in pixel, per passare alla mira mouse.
@export var mouse_aim_delta_threshold := 0.1

@export_group("Terrain")
## TerrainToolRange: distanza davanti al personaggio del bersaglio terreno, cm (min 100).
@export var terrain_tool_range_cm := 480.0

@export_group("Dash")
## DashSpeed, cm/s.
@export var dash_speed_cm := 3000.0
@export var dash_duration := 0.18
## Misurato dall'attivazione del dash.
@export var dash_cooldown := 1.2
@export var dash_scale_multiplier := 1.15
## Colori lineari, come FLinearColor in Unreal.
@export var dash_color_linear := Color(0.1, 0.9, 1.0)
@export var dash_cooldown_color_linear := Color(0.4, 0.4, 0.4)
