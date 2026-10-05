class_name UpgradeCatalog
extends RefCounted
## Upgrade del primo prototipo (PROGRESSION_SPEC, sezione 6; D-038). Dati in
## un solo posto; gli effetti li applica ArenaRun. Ogni voce:
## id, name, category, rarity, max_level, requires ("" o "companion"), text.

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

const RARITY_NAMES: Array[String] = ["COMUNE", "NON COMUNE", "RARO", "LEGGENDARIO"]
## Lineari, convertiti dalla UI.
const RARITY_COLORS: Array[Color] = [
	Color(0.75, 0.75, 0.72), Color(0.25, 0.85, 0.3), Color(0.2, 0.55, 1.0), Color(1.0, 0.55, 0.05),
]
const CATEGORY_NAMES := {
	&"weapon": "Arma", &"companion": "Pezzo compagno", &"terrain": "Tool terreno", &"character": "Personaggio",
}


static func all() -> Array[Dictionary]:
	return [
		{id = &"nail_rate", name = "Grilletto limato", category = &"weapon", rarity = Rarity.COMMON, max_level = 4,
			requires = "", text = "La chiodatrice spara il 25% piu spesso."},
		{id = &"nail_pierce", name = "Chiodi da carpentiere", category = &"weapon", rarity = Rarity.UNCOMMON, max_level = 3,
			requires = "", text = "Ogni chiodo trapassa un rottamatore in piu."},
		{id = &"nail_spread", name = "Canna doppia", category = &"weapon", rarity = Rarity.RARE, max_level = 2,
			requires = "", text = "Un chiodo in piu a ogni colpo, a ventaglio."},
		{id = &"companion_turret", name = "Torretta sul cassone", category = &"companion", rarity = Rarity.RARE, max_level = 3,
			requires = "companion", text = "Il compagno monta una chiodatrice. Ai livelli successivi spara piu spesso."},
		{id = &"companion_magnet", name = "Calamita", category = &"companion", rarity = Rarity.UNCOMMON, max_level = 2,
			requires = "companion", text = "Il compagno attira i frammenti di esperienza attorno a se."},
		{id = &"companion_cargo", name = "Cassone rinforzato", category = &"companion", rarity = Rarity.COMMON, max_level = 3,
			requires = "companion", text = "Il compagno porta 2 rottami in piu e ne trova 1 subito."},
		{id = &"dig_blast", name = "Scavo esplosivo", category = &"terrain", rarity = Rarity.UNCOMMON, max_level = 3,
			requires = "", text = "Scavare una cella colpisce i rottamatori vicini (2 danni). Raggio maggiore a ogni livello."},
		{id = &"spiked_wall", name = "Terrapieni spinati", category = &"terrain", rarity = Rarity.UNCOMMON, max_level = 2,
			requires = "", text = "I rottamatori che spingono contro una cella rialzata si fanno male."},
		{id = &"boots", name = "Scarponi slacciati", category = &"character", rarity = Rarity.COMMON, max_level = 3,
			requires = "", text = "Corri il 10% piu veloce."},
		{id = &"patch", name = "Toppa", category = &"character", rarity = Rarity.COMMON, max_level = 3,
			requires = "", text = "Un punto vita in piu e ti rimetti in sesto del tutto."},
		{id = &"reach", name = "Tasche larghe", category = &"character", rarity = Rarity.COMMON, max_level = 3,
			requires = "", text = "Raggio di raccolta dei frammenti piu ampio del 40%."},
	]
