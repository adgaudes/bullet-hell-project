class_name TurretModule
extends MachineModule
## Torretta (spec D-093, Sezione 1): la chiodatrice che il compagno montava con la carta
## "Torretta sul cassone", ora il modulo di una macchina. Spara da sola al rottamatore piu
## vicino entro `turret_range`; Torretta veloce (livello del tipo) divide l'intervallo per
## `turret_rate_per_level` a ogni livello, per tutte le torrette, e per la forza della macchina
## (scelta 4 di D-093).
## Spenta (macchina guasta, task 6) non spara: i chiodi gia in volo finiscono la corsa.

## Altezza della canna sull'origine della macchina (la torretta del compagno di oggi).
const MUZZLE_HEIGHT := 0.55

var _weapon: AutoWeapon


func _init() -> void:
	# Senza `weapon_id`: i valori li imposta `apply_level`, non WeaponCatalog.
	_weapon = AutoWeapon.new()
	_weapon.name = "TurretWeapon"
	_weapon.muzzle_height = MUZZLE_HEIGHT
	add_child(_weapon)


func weapon() -> AutoWeapon:
	return _weapon


## Valori dalle tarature della carovana e della run, l'intervallo ricalcolato dalla base.
## Idempotente: la carovana la richiama quando arrivano i servizi; senza direttore (o spenta)
## nessuno spara.
func apply_level(new_level: int) -> void:
	super.apply_level(new_level)
	if caravan != null and caravan.tuning != null:
		var tuning := caravan.tuning
		_weapon.weapon_range = tuning.turret_range
		_weapon.fire_interval = tuning.turret_interval / pow(tuning.turret_rate_per_level, level) / power
	if run_tuning != null:
		_weapon.damage = run_tuning.weapon_damage
		_weapon.projectile_speed = run_tuning.projectile_speed
	_weapon.director = director
	_weapon.shooter = machine if active and is_instance_valid(director) else null


func _on_active_changed(on: bool) -> void:
	if on:
		apply_level(level)
	else:
		_weapon.shooter = null


## Base e canna scure sul pianale, verso il muso (la torretta del compagno di oggi).
func build_part() -> Node3D:
	var part := Node3D.new()
	part.position = Vector3(0.0, 0.42, -0.25)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.13)
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.16
	base_mesh.bottom_radius = 0.2
	base_mesh.height = 0.14
	base.mesh = base_mesh
	base.material_override = dark
	part.add_child(base)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.09, 0.09, 0.45)
	barrel.mesh = barrel_mesh
	barrel.material_override = dark
	barrel.position = Vector3(0.0, 0.1, -0.22)
	part.add_child(barrel)
	return part
