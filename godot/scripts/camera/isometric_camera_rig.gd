@tool
class_name IsometricCameraRig
extends Node3D
## Camera isometrica fissa: porta di SpringArm + Camera del personaggio Unreal.
##
## Rotazione assoluta (top_level), nessuna collisione, nessuna rotazione libera.
## Segue soltanto la posizione del bersaglio, come il braccio Unreal agganciato
## al centro della capsula.

## Braccio Unreal 1500 uu.
@export var arm_length_cm := 1500.0
## Pitch Unreal del braccio, in gradi.
@export var pitch_degrees := -55.0
## FOV orizzontale: default di UCameraComponent.
@export var horizontal_fov_degrees := 90.0
@export var target: Node3D

var _camera: Camera3D


func _ready() -> void:
	top_level = true
	_camera = get_node_or_null(^"Camera") as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "Camera"
		add_child(_camera)
	_apply()
	if not Engine.is_editor_hint():
		_camera.make_current()
		print("PROTOTYPE01_CAMERA_READY arm=%.1fm pitch=%.0f hfov=%.0f"
			% [UnrealSpace.length(arm_length_cm), pitch_degrees, horizontal_fov_degrees])


func _process(_delta: float) -> void:
	if target != null:
		global_position = target.global_position


func _apply() -> void:
	# Rig orientato verso -Z (forward Godot = +X Unreal, yaw 0).
	global_basis = Basis.from_euler(Vector3(deg_to_rad(pitch_degrees), 0.0, 0.0))
	_camera.position = Vector3(0.0, 0.0, UnrealSpace.length(arm_length_cm))
	_camera.basis = Basis.IDENTITY
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = horizontal_fov_degrees
	if target != null:
		global_position = target.global_position
