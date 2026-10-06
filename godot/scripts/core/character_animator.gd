class_name CharacterAnimator
extends Node
## Animazioni con scheletro di un personaggio (D-060, tools/blender/build_character_assets.py):
## fermo/corsa miscelati sulla velocita, braccia e testa nella posa di mira, gambe girate
## verso la direzione di marcia (HipTwistModifier) e, oltre BACKPEDAL_ANGLE, corsa
## all'indietro. Colpo e morte a comando. Legge solo cio che gli passa il proprietario
## e muove solo le ossa: corpo fisico e valori di gioco non sanno che esiste.
## Con ActorMotion.enabled spento resta fermo nell'ultima posa.

const IDLE := &"Idle"
const JOG := &"Jog_Fwd"
const AIM := &"Pistol_Aim_Neutral"
const HIT := &"Hit_Chest"
const DEATH := &"Death01"
const HIPS_BONE := &"DEF-hips"
const SPINE_BONE := &"DEF-spine.001"
## Ossa che seguono la posa di mira invece della corsa (piu tutti i loro figli nel rig).
const AIM_BONES: Array[String] = [
	"DEF-spine.003", "DEF-neck", "DEF-head",
	"DEF-shoulder.L", "DEF-upper_arm.L", "DEF-forearm.L", "DEF-hand.L",
	"DEF-shoulder.R", "DEF-upper_arm.R", "DEF-forearm.R", "DEF-hand.R",
]
## Velocita (m/s) a cui la corsa e a passo naturale, e limiti del suo ritmo.
const JOG_STRIDE_SPEED := 3.2
const JOG_RATE_MIN := 0.7
const JOG_RATE_MAX := 2.0
## Frazione della velocita di riferimento a cui la corsa ha sostituito del tutto il fermo.
const JOG_FULL_BLEND := 0.5
## Velocita (1/s) con cui miscela e torsione inseguono il movimento.
const BLEND_RATE := 12.0
const TWIST_RATE := 14.0
## Oltre questo angolo (rad) fra mira e marcia corre all'indietro; l'isteresi evita lo
## sfarfallio quando ci si muove di lato.
const BACKPEDAL_ANGLE := deg_to_rad(100.0)
const BACKPEDAL_HYSTERESIS := deg_to_rad(12.0)

var _tree: AnimationTree
var _player: AnimationPlayer
var _twist: HipTwistModifier
var _move_target := 0.0
var _move := 0.0
var _rate := 1.0
var _twist_target := 0.0
var _backpedal := false
var _dead := false
var _frozen := false
var _aim_filter_size := 0


## Crea l'animatore per [param model] e lo aggiunge come suo figlio; null se il modello
## non ha scheletro e animazioni.
static func attach(model: Node) -> CharacterAnimator:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skeletons.is_empty():
		return null
	var animator := CharacterAnimator.new()
	animator.name = "CharacterAnimator"
	model.add_child(animator)
	animator._build(players[0], skeletons[0])
	return animator


## Miscela corrente fermo (0) / corsa (1).
func move_blend() -> float:
	return _move


## Torsione corrente delle gambe (rad).
func twist() -> float:
	return _twist.angle


func is_backpedaling() -> bool:
	return _backpedal


func aim_filter_size() -> int:
	return _aim_filter_size


## [param local_velocity] nello spazio del personaggio (avanti = -Z);
## [param reference_speed] e la sua velocita normale di marcia.
func set_locomotion(local_velocity: Vector3, reference_speed: float) -> void:
	var planar := Vector2(local_velocity.x, local_velocity.z)
	var speed := planar.length()
	_move_target = clampf(speed / maxf(reference_speed * JOG_FULL_BLEND, 0.01), 0.0, 1.0)
	if speed < 0.05:
		_twist_target = 0.0
		_backpedal = false
		_rate = 1.0
		return
	# Rotazione attorno a +Y che porta "avanti" (-Z) sulla direzione di marcia.
	var heading := atan2(-planar.x, -planar.y)
	var limit := BACKPEDAL_ANGLE + (BACKPEDAL_HYSTERESIS if not _backpedal else -BACKPEDAL_HYSTERESIS)
	_backpedal = absf(heading) > limit
	if _backpedal:
		heading -= signf(heading) * PI
	_twist_target = heading
	_rate = clampf(speed / JOG_STRIDE_SPEED, JOG_RATE_MIN, JOG_RATE_MAX) * (-1.0 if _backpedal else 1.0)


func play_hit() -> void:
	if not _dead:
		_tree.set(&"parameters/hit_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Ferma la miscela e fa cadere il personaggio; [method revive] lo rimette in piedi.
func play_death() -> void:
	if _dead:
		return
	_dead = true
	_tree.active = false
	_twist.angle = 0.0
	# La fine della run mette in pausa l'albero: la caduta deve vedersi lo stesso.
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.play(DEATH)


func revive() -> void:
	if not _dead:
		return
	_dead = false
	_player.stop()
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_tree.active = true


func _build(player: AnimationPlayer, skeleton: Skeleton3D) -> void:
	_player = player
	for animation_name: StringName in [IDLE, JOG]:
		player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR

	var blend := AnimationNodeBlendTree.new()
	blend.add_node(&"idle", _clip(IDLE))
	blend.add_node(&"jog", _clip(JOG))
	blend.add_node(&"jog_rate", AnimationNodeTimeScale.new())
	blend.add_node(&"move", AnimationNodeBlend2.new())
	blend.add_node(&"aim", _clip(AIM))
	var upper := AnimationNodeBlend2.new()
	upper.filter_enabled = true
	var aim_animation := player.get_animation(AIM)
	for track in aim_animation.get_track_count():
		var path := aim_animation.track_get_path(track)
		if path.get_subname_count() > 0 and AIM_BONES.has(String(path.get_subname(0))):
			upper.set_filter_path(path, true)
			_aim_filter_size += 1
	blend.add_node(&"upper", upper)
	blend.add_node(&"hit", _clip(HIT))
	var hit_shot := AnimationNodeOneShot.new()
	hit_shot.fadein_time = 0.04
	hit_shot.fadeout_time = 0.12
	blend.add_node(&"hit_shot", hit_shot)
	blend.connect_node(&"jog_rate", 0, &"jog")
	blend.connect_node(&"move", 0, &"idle")
	blend.connect_node(&"move", 1, &"jog_rate")
	blend.connect_node(&"upper", 0, &"move")
	blend.connect_node(&"upper", 1, &"aim")
	blend.connect_node(&"hit_shot", 0, &"upper")
	blend.connect_node(&"hit_shot", 1, &"hit")
	blend.connect_node(&"output", 0, &"hit_shot")

	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_tree.tree_root = blend
	player.get_parent().add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.set(&"parameters/upper/blend_amount", 1.0)
	_tree.set(&"parameters/move/blend_amount", 0.0)
	_tree.set(&"parameters/jog_rate/scale", 1.0)
	_tree.active = true

	_twist = HipTwistModifier.new()
	_twist.name = "HipTwist"
	skeleton.add_child(_twist)
	_twist.setup(skeleton, HIPS_BONE, SPINE_BONE)
	# La posa iniziale c'e subito, anche se ActorMotion e spento dal primo frame.
	_tree.advance(0.0)


func _clip(animation: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = animation
	return node


func _process(delta: float) -> void:
	var frozen := not ActorMotion.enabled
	if frozen != _frozen:
		_frozen = frozen
		_tree.callback_mode_process = (AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if frozen
			else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE)
	if frozen or _dead:
		return
	_move = ActorMotion.smooth(_move, _move_target, BLEND_RATE, delta)
	_twist.angle = ActorMotion.smooth(_twist.angle, _twist_target, TWIST_RATE, delta)
	_tree.set(&"parameters/move/blend_amount", _move)
	_tree.set(&"parameters/jog_rate/scale", _rate)
