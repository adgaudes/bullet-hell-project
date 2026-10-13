class_name PostureModifier
extends SkeletonModifier3D
## Postura di carattere dell'Ingegnere (D-088): pancia in fuori (colonna all'indietro) e
## mento alto, aggiunti dopo ogni animazione come HipTwistModifier. Ruota attorno all'asse
## laterale del personaggio, quindi non cambia dove guarda: la mira resta. Sfuma quando il
## busto non e dritto (capriola, caduta) e si spegne alla morte (CharacterAnimator).

## Inclinazione all'indietro della colonna (rad).
@export var belly_lean := deg_to_rad(8.0)
## Testa in su rispetto alla colonna (rad).
@export var chin_up := deg_to_rad(12.0)

const UPRIGHT_MIN := 0.5
const UPRIGHT_FADE := 0.3

var _spine := -1
var _neck := -1
## Fronte del personaggio nello spazio dello scheletro, dalla punta del piede a riposo.
var _front := Vector3.BACK
var _factor := 0.0


## Lo scheletro si passa esplicito: appena aggiunto, get_skeleton() e ancora nullo.
func setup(skeleton: Skeleton3D, spine_bone: StringName, neck_bone: StringName, toe_bone: StringName) -> void:
	_spine = skeleton.find_bone(spine_bone)
	_neck = skeleton.find_bone(neck_bone)
	var toe := skeleton.find_bone(toe_bone)
	if toe >= 0:
		var direction := skeleton.get_bone_global_rest(toe).basis.y
		direction.y = 0.0
		if direction.length_squared() > 1e-4:
			_front = direction.normalized()


## Quanto della postura e stato applicato all'ultimo aggiornamento (0..1).
func factor() -> float:
	return _factor


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if _spine < 0:
		return
	var spine := skeleton.get_bone_global_pose(_spine)
	var turned := spine.basis.orthonormalized() * skeleton.get_bone_global_rest(_spine).basis.orthonormalized().inverse()
	_factor = clampf(((turned * Vector3.UP).y - UPRIGHT_MIN) / UPRIGHT_FADE, 0.0, 1.0)
	if is_zero_approx(_factor):
		return
	# Una rotazione positiva attorno a `side` porta "su" verso il fronte: qui serve il contrario.
	var side := Vector3.UP.cross(_front).normalized()
	spine.basis = Basis(side, -belly_lean * _factor) * spine.basis
	skeleton.set_bone_global_pose(_spine, spine)
	if _neck < 0:
		return
	var neck := skeleton.get_bone_global_pose(_neck)
	neck.basis = Basis(side, -chin_up * _factor) * neck.basis
	skeleton.set_bone_global_pose(_neck, neck)
