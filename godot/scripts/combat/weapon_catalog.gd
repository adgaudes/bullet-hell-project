class_name WeaponCatalog
extends RefCounted
## Armi della spec D-092 (docs/superpowers/specs/2026-10-15-weapons-classes-design.md, par. 4).
## Dati in un solo posto, come UpgradeCatalog. Ogni voce: id, name, deck (&"common" o una
## classe), slot (&"auto"/&"active"), partner (l'arma compagna della fusione), fusion, unlock_cost
## (rottami in Officina, 0 = sempre disponibile), icon (UiIcon), text, base (valori al livello 1),
## levels (modifiche ai livelli 2 e 4), level_texts, branches (due opzioni ai livelli 3 e 5).
## Le modifiche usano chiavi `<valore>_mul`, `<valore>_add`, `<valore>_set` e si applicano in
## ordine di livello: 2, bivio del 3, 4, bivio del 5. Valori di partenza, non bilanciati.

const MAX_LEVEL := 5
const BRANCH_LEVELS: Array[int] = [3, 5]


static func all() -> Array[Dictionary]:
	return [
		{id = &"nailgun", name = "Chiodatrice", deck = &"engineer", slot = &"auto", partner = &"seismic_stake",
			fusion = &"fort", unlock_cost = 0, icon = &"nail",
			text = "Chiodi dritti al bersaglio. Gli argini li fermano.",
			base = {fire_interval = 0.5, damage = 1.0, weapon_range = 9.0, pierce = 0.0, projectiles = 1.0,
				spread_degrees = 12.0, projectile_speed = 24.0},
			levels = {2: {fire_interval_mul = 0.8}, 4: {pierce_add = 1.0}},
			level_texts = {2: "Spara il 25% piu spesso.", 4: "Ogni chiodo trapassa un nemico in piu."},
			branches = {
				3: [
					{id = &"burst", name = "Raffica", text = "Cadenza doppia, chiodi un po' sparpagliati.",
						mods = {fire_interval_mul = 0.5, spread_jitter_set = 8.0}},
					{id = &"bridge", name = "Chiodi da ponte", text = "Trapassano tutto e fanno 2 danni, ma un colpo ogni 0,7 s.",
						mods = {pierce_set = 99.0, damage_set = 2.0, fire_interval_set = 0.7}},
				],
				5: [
					{id = &"ricochet", name = "Rimbalzanti", text = "Un chiodo che colpisce un argine rimbalza una volta.",
						mods = {bounces_set = 1.0}},
					{id = &"incendiary", name = "Incandescenti", text = "Ogni chiodo lascia una macchia di fuoco per 2 s.",
						mods = {fire_patch_set = 1.0}},
				],
			}},
		{id = &"seismic_stake", name = "Picchetto sismico", deck = &"engineer", slot = &"active", partner = &"nailgun",
			fusion = &"fort", unlock_cost = 0, icon = &"stake",
			text = "Pianti un picchetto: si alza un anello di argine che chiude dentro chi c'e.",
			base = {cooldown = 15.0, aim_range = 6.0, ring_radius = 3.0, ring_height = 1.2, ring_width = 0.8,
				raise_delay = 0.6, hold_seconds = 12.0},
			levels = {2: {cooldown_mul = 0.85}, 4: {cooldown_mul = 0.85}},
			level_texts = {2: "Si ricarica il 15% prima.", 4: "Si ricarica il 15% prima."},
			branches = {
				3: [
					{id = &"wide", name = "Anello largo", text = "L'anello ha raggio 4,5 m.", mods = {ring_radius_set = 4.5}},
					{id = &"permanent", name = "Argine permanente", text = "L'anello non torna giu.", mods = {permanent_set = 1.0}},
				],
				5: [
					{id = &"spiked", name = "Argine chiodato", text = "Chi spinge contro l'anello prende 1 danno ogni 0,6 s.",
						mods = {spike_damage_set = 1.0}},
					{id = &"shock", name = "Scossa", text = "Quando si alza fa 3 danni a chi ci sta sopra e lo scaglia fuori.",
						mods = {shock_damage_set = 3.0}},
				],
			}},
	]


static func find(id: StringName) -> Dictionary:
	for entry in all():
		if entry.id == id:
			return entry
	return {}


## Valore [param key] dell'arma al livello dato, coi bivi presi ({3: &"a"|&"b", 5: ...}).
## Un valore assente dalla base vale 0 (i flag dei bivi: bounces, fire_patch, permanent...).
static func stat(id: StringName, key: StringName, level: int, branches: Dictionary) -> float:
	var entry := find(id)
	if entry.is_empty():
		return 0.0
	var value := float((entry.base as Dictionary).get(key, 0.0))
	for at in range(2, mini(level, MAX_LEVEL) + 1):
		var mods: Dictionary = {}
		if BRANCH_LEVELS.has(at):
			var options: Array = (entry.branches as Dictionary).get(at, [])
			var pick: StringName = branches.get(at, &"")
			if pick == &"a" and options.size() > 0:
				mods = options[0].mods
			elif pick == &"b" and options.size() > 1:
				mods = options[1].mods
		else:
			mods = (entry.levels as Dictionary).get(at, {})
		value = _apply(value, key, mods)
	return value


static func _apply(value: float, key: StringName, mods: Dictionary) -> float:
	var set_key := StringName("%s_set" % key)
	if mods.has(set_key):
		value = float(mods[set_key])
	var mul_key := StringName("%s_mul" % key)
	if mods.has(mul_key):
		value *= float(mods[mul_key])
	var add_key := StringName("%s_add" % key)
	if mods.has(add_key):
		value += float(mods[add_key])
	return value


## Le due trasformazioni al livello [param at_level] (3 o 5), vuoto altrove.
static func branch_options(id: StringName, at_level: int) -> Array[Dictionary]:
	var entry := find(id)
	var out: Array[Dictionary] = []
	if entry.is_empty():
		return out
	for option: Dictionary in (entry.branches as Dictionary).get(at_level, []):
		out.append(option)
	return out
