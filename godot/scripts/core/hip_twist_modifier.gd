class_name HipTwistModifier
extends SkeletonModifier3D
## Gira il bacino (e con lui le gambe) di [member angle] attorno alla verticale e
## contro-ruota la colonna: le gambe corrono verso dove si va, il busto resta dove si
## mira. Si applica dopo le animazioni, come ogni SkeletonModifier3D.

## Radianti attorno a +Y nello spazio dello scheletro; 0 = nessuna torsione.
var angle := 0.0

var _hips := -1
var _spine := -1


## [param hips_bone] e l'osso che porta le gambe, [param spine_bone] il primo sopra.
## Lo scheletro si passa esplicito: appena aggiunto, get_skeleton() e ancora nullo.
func setup(skeleton: Skeleton3D, hips_bone: StringName, spine_bone: StringName) -> void:
	_hips = skeleton.find_bone(hips_bone)
	_spine = skeleton.find_bone(spine_bone)


func _process_modification() -> void:
	if _hips < 0 or _spine < 0 or is_zero_approx(angle):
		return
	var skeleton := get_skeleton()
	var hips := skeleton.get_bone_global_pose(_hips)
	hips.basis = Basis(Vector3.UP, angle) * hips.basis
	skeleton.set_bone_global_pose(_hips, hips)
	# Letta dopo: contiene gia la torsione del bacino, che qui si toglie.
	var spine := skeleton.get_bone_global_pose(_spine)
	spine.basis = Basis(Vector3.UP, -angle) * spine.basis
	skeleton.set_bone_global_pose(_spine, spine)
