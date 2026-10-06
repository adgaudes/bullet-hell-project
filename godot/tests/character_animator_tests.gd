extends SceneTree
## Test delle animazioni con scheletro (CharacterAnimator, HipTwistModifier, D-060). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/character_animator_tests.gd
## Invarianti: il modello dell'ingegnere ha scheletro e animazioni attese; fermo/corsa
## seguono la velocita; le gambe si girano verso la marcia mentre la testa resta sulla
## mira; oltre BACKPEDAL_ANGLE si corre all'indietro (con isteresi); colpo, morte e
## ripresa non rompono la miscela; con ActorMotion spento le ossa restano ferme.

const MODEL := preload("res://assets/models/player_engineer.glb")
const SPEED := 4.0
const REFERENCE_SPEED := 6.0

var _failures := 0
var _model: Node3D
var _animator: CharacterAnimator
var _skeleton: Skeleton3D
var _head := -1
var _thigh := -1
var _hips := -1
## Pose finali (dopo i modificatori) dell'ultimo aggiornamento dello scheletro.
var _head_pose := Transform3D.IDENTITY
var _thigh_pose := Transform3D.IDENTITY
var _hips_pose := Transform3D.IDENTITY


func _initialize() -> void:
	_model = MODEL.instantiate()
	root.add_child(_model)
	_animator = CharacterAnimator.attach(_model)
	_check(_animator != null, "il modello ha scheletro e animazioni")
	if _animator == null:
		_finish()
		return
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_head = _skeleton.find_bone("DEF-head")
	_thigh = _skeleton.find_bone("DEF-thigh.L")
	_hips = _skeleton.find_bone(CharacterAnimator.HIPS_BONE)
	_skeleton.skeleton_updated.connect(_on_skeleton_updated)
	var player: AnimationPlayer = _model.find_children("*", "AnimationPlayer", true, false)[0]
	var missing := PackedStringArray()
	for animation: StringName in [CharacterAnimator.IDLE, CharacterAnimator.JOG, CharacterAnimator.AIM,
			CharacterAnimator.HIT, CharacterAnimator.DEATH]:
		if not player.has_animation(animation):
			missing.append(animation)
	_check(missing.is_empty(), "animazioni attese presenti (mancano: %s)" % ", ".join(missing))
	_check(_head >= 0 and _thigh >= 0 and _hips >= 0 and _skeleton.find_bone(CharacterAnimator.SPINE_BONE) >= 0,
		"ossa attese presenti")
	_check(_animator.aim_filter_size() == CharacterAnimator.AIM_BONES.size(),
		"la posa di mira filtra tutte le ossa di AIM_BONES (%d)" % _animator.aim_filter_size())
	var mesh := ActorModel.mesh_instance_of(_model)
	var names := PackedStringArray()
	for surface in mesh.mesh.get_surface_count():
		names.append(mesh.mesh.surface_get_material(surface).resource_name)
	_check(names.has("suit") and names.has("detail"), "superfici `suit` e `detail` (%s)" % ", ".join(names))
	var bounds := mesh.get_aabb()
	_check(bounds.size.y > 1.2, "la mesh ha l'altezza di un personaggio (%.2f m a riposo)" % bounds.size.y)

	print("Fermo e corsa")
	await _frames(20)
	_check(_animator.move_blend() < 0.01 and is_zero_approx(_animator.twist()), "da fermo: nessuna corsa, nessuna torsione")
	_animator.set_locomotion(Vector3(0.0, 0.0, -SPEED), REFERENCE_SPEED)
	var moved := await _hips_travel(40)
	_check(_animator.move_blend() > 0.95, "in marcia la corsa sostituisce il fermo (%.2f)" % _animator.move_blend())
	_check(absf(_animator.twist()) < 0.01 and not _animator.is_backpedaling(), "avanti: gambe dritte, corsa in avanti")
	_check(moved > 0.01, "la corsa muove il bacino (%.3f m)" % moved)
	var head_forward := _head_pose
	var thigh_forward := _thigh_pose

	print("Marcia di lato e all'indietro")
	_animator.set_locomotion(Vector3(SPEED, 0.0, 0.0), REFERENCE_SPEED)
	await _frames(40)
	_check(absf(_animator.twist() + PI * 0.5) < 0.02 and not _animator.is_backpedaling(),
		"verso destra: gambe girate di -90 gradi (%.2f rad)" % _animator.twist())
	_check(_yaw_between(thigh_forward, _thigh_pose) > 1.0, "le gambe seguono la marcia (%.2f rad)" % _yaw_between(thigh_forward, _thigh_pose))
	_check(_yaw_between(head_forward, _head_pose) < 0.5, "la testa resta sulla mira (%.2f rad)" % _yaw_between(head_forward, _head_pose))
	_animator.set_locomotion(Vector3(0.0, 0.0, SPEED), REFERENCE_SPEED)
	moved = await _hips_travel(40)
	_check(_animator.is_backpedaling() and absf(_animator.twist()) < 0.02, "indietro: corsa all'indietro, gambe dritte")
	_check(moved > 0.01, "anche all'indietro la corsa avanza (%.3f m)" % moved)
	# 105 gradi sta dentro la fascia d'isteresi: resta nello stato in cui era.
	var diagonal := Vector3(sin(deg_to_rad(105.0)), 0.0, -cos(deg_to_rad(105.0))) * SPEED
	_animator.set_locomotion(diagonal, REFERENCE_SPEED)
	_check(_animator.is_backpedaling(), "a 105 gradi, venendo dall'indietro, resta all'indietro")
	_animator.set_locomotion(Vector3(0.0, 0.0, -SPEED), REFERENCE_SPEED)
	_animator.set_locomotion(diagonal, REFERENCE_SPEED)
	_check(not _animator.is_backpedaling(), "a 105 gradi, venendo dall'avanti, resta in avanti")
	_animator.set_locomotion(Vector3.ZERO, REFERENCE_SPEED)
	await _frames(60)
	_check(_animator.move_blend() < 0.01 and is_zero_approx(_animator.twist()), "fermandosi torna a riposo")

	print("Colpo, morte, interruttore")
	_animator.play_hit()
	await _frames(30)
	var tree: AnimationTree = _model.find_children("*", "AnimationTree", true, false)[0]
	_check(tree.active, "dopo il colpo la miscela e ancora attiva")
	_animator.play_death()
	await _frames(5)
	_check(not tree.active and player.current_animation == CharacterAnimator.DEATH, "alla morte parte la caduta")
	_animator.revive()
	await _frames(5)
	_check(tree.active and not player.is_playing(), "revive rimette la miscela")
	_animator.set_locomotion(Vector3(0.0, 0.0, -SPEED), REFERENCE_SPEED)
	await _frames(20)
	ActorMotion.enabled = false
	await _frames(3)
	var blend := _animator.move_blend()
	moved = await _hips_travel(20)
	_check(moved < 0.0001 and is_equal_approx(blend, _animator.move_blend()), "con ActorMotion spento le ossa restano ferme")
	ActorMotion.enabled = true
	moved = await _hips_travel(20)
	_check(moved > 0.01, "riacceso, la corsa riprende")
	_finish()


func _finish() -> void:
	ActorMotion.enabled = true
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _on_skeleton_updated() -> void:
	_head_pose = _skeleton.get_bone_global_pose(_head)
	_thigh_pose = _skeleton.get_bone_global_pose(_thigh)
	_hips_pose = _skeleton.get_bone_global_pose(_hips)


## Strada fatta dal bacino (somma degli spostamenti) in [param n] frame.
func _hips_travel(n: int) -> float:
	var travel := 0.0
	var last := _hips_pose.origin
	for i in n:
		await process_frame
		travel += _hips_pose.origin.distance_to(last)
		last = _hips_pose.origin
	return travel


## Angolo attorno alla verticale fra due pose dello stesso osso.
func _yaw_between(a: Transform3D, b: Transform3D) -> float:
	var relative := b.basis.orthonormalized() * a.basis.orthonormalized().inverse()
	var turned := relative * Vector3.FORWARD
	return absf(atan2(turned.x, -turned.z))
