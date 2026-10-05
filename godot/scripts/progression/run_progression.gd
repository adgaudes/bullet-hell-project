class_name RunProgression
extends RefCounted
## Esperienza, livelli ed estrazione delle carte (PROGRESSION_SPEC, regole 1-4).
## Logica pura e deterministica dato il seed: nessun nodo, testabile da sola.

## Regola 1: pesi di rarita. I leggendari non sono nel catalogo del prototipo.
const RARITY_WEIGHTS: Array[float] = [60.0, 27.0, 10.0, 3.0]
const CARDS := 3

var rng := RandomNumberGenerator.new()
var catalog: Array[Dictionary] = []
## Livello di ogni upgrade posseduto.
var levels: Dictionary[StringName, int] = {}
var xp := 0
var level := 1
var xp_first_level := 5
var xp_growth := 3
## Regola 4.
var pity_level_ups := 4
var level_ups_without_rare := 0
var has_companion := true
var seed_value := 0


func setup(run_seed: int, upgrades: Array[Dictionary] = []) -> void:
	seed_value = run_seed
	rng.seed = run_seed
	catalog = upgrades if not upgrades.is_empty() else UpgradeCatalog.all()


func xp_to_next() -> int:
	return xp_first_level + xp_growth * (level - 1)


## Aggiunge esperienza; restituisce quanti livelli ha guadagnato.
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1
	return gained


func level_of(id: StringName) -> int:
	return levels.get(id, 0)


## Regola 2: niente upgrade al massimo ne pezzi per macchine che non hai.
func eligible() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for upgrade in catalog:
		if level_of(upgrade.id) >= upgrade.max_level:
			continue
		if upgrade.requires == "companion" and not has_companion:
			continue
		result.append(upgrade)
	return result


## Tre carte distinte. Regola 3: categorie diverse finche il pool lo permette.
## Regola 4: dopo pity_level_ups scelte senza Rari, la prima carta e Rara o superiore.
func roll_offer() -> Array[Dictionary]:
	var pool := eligible()
	var offer: Array[Dictionary] = []
	var used_categories: Array[StringName] = []
	var force_rare := level_ups_without_rare >= pity_level_ups
	for i in CARDS:
		var candidates := pool.filter(func(u: Dictionary) -> bool: return not offer.has(u))
		if candidates.is_empty():
			break
		var fresh := candidates.filter(func(u: Dictionary) -> bool: return not used_categories.has(u.category))
		if not fresh.is_empty():
			candidates = fresh
		if force_rare:
			var rare := candidates.filter(func(u: Dictionary) -> bool: return u.rarity >= UpgradeCatalog.Rarity.RARE)
			if rare.is_empty():
				rare = pool.filter(func(u: Dictionary) -> bool:
					return u.rarity >= UpgradeCatalog.Rarity.RARE and not offer.has(u))
			if not rare.is_empty():
				candidates = rare
				force_rare = false
		var pick := _weighted_pick(candidates)
		offer.append(pick)
		used_categories.append(pick.category)
	var has_rare := offer.any(func(u: Dictionary) -> bool: return u.rarity >= UpgradeCatalog.Rarity.RARE)
	level_ups_without_rare = 0 if has_rare else level_ups_without_rare + 1
	return offer


## Restituisce il nuovo livello dell'upgrade.
func choose(id: StringName) -> int:
	levels[id] = level_of(id) + 1
	return levels[id]


## Ogni rarita pesa come da regola 1 indipendentemente da quante carte contiene;
## le rarita assenti dal gruppo sono ignorate e i pesi rinormalizzati.
func _weighted_pick(candidates: Array) -> Dictionary:
	var per_rarity := {}
	for upgrade in candidates:
		per_rarity[upgrade.rarity] = per_rarity.get(upgrade.rarity, 0) + 1
	var total := 0.0
	var weights: Array[float] = []
	for upgrade in candidates:
		var w: float = RARITY_WEIGHTS[upgrade.rarity] / per_rarity[upgrade.rarity]
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates[candidates.size() - 1]
