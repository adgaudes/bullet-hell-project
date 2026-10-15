class_name UpgradeCatalog
extends RefCounted
## Upgrade del primo prototipo (PROGRESSION_SPEC, sezione 6; D-038). Dati in
## un solo posto; gli effetti li applica ArenaRun. Ogni voce:
## id, deck (&"common" o una classe di ClassCatalog: spec D-092, par. 5), name, category,
## rarity, max_level, requires ("" o "companion"), text. Le vecchie carte della chiodatrice
## (nail_*) sono diventate i suoi livelli e bivi in WeaponCatalog.
## Le voci con `filler = true` sono ripetibili senza limite (max_level 0) e
## compaiono solo quando le carte vere non bastano a riempire l'offerta (D-056).
## `values` (R-15): le grandezze dell'effetto, lette da `ArenaRun.apply_upgrade` e
## sostituite nel `text` con `{chiave}`: un solo posto da ritoccare per bilanciare.

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

const RARITY_NAMES: Array[String] = ["COMUNE", "NON COMUNE", "RARO", "LEGGENDARIO"]
## Lineari, convertiti dalla UI.
const RARITY_COLORS: Array[Color] = [
	Color(0.75, 0.75, 0.72), Color(0.25, 0.85, 0.3), Color(0.2, 0.55, 1.0), Color(1.0, 0.55, 0.05),
]
const CATEGORY_NAMES := {
	&"weapon": "Arma", &"companion": "Pezzo compagno", &"terrain": "Tool terreno", &"character": "Personaggio",
}


## Valore numerico di un upgrade (`values[key]`), o [param default] se manca.
static func value(id: StringName, key: StringName, default: float = 0.0) -> float:
	for entry in all():
		if entry.id == id:
			var values: Dictionary = entry.get("values", {})
			return float(values.get(key, default))
	return default


## Testo della carta con i valori sostituiti (es. "{rate}" -> "25").
static func describe(entry: Dictionary) -> String:
	var text: String = entry.text
	var values: Dictionary = entry.get("values", {})
	for key in values:
		var v: Variant = values[key]
		var shown := (str(int(v)) if is_equal_approx(float(v), roundf(float(v))) else "%.1f" % float(v)) if typeof(v) != TYPE_STRING else String(v)
		text = text.replace("{%s}" % key, shown)
	return text


static func all() -> Array[Dictionary]:
	return [
		{id = &"companion_turret", deck = &"mechanic", name = "Torretta sul cassone", category = &"companion", rarity = Rarity.RARE, max_level = 3,
			requires = "companion", values = {fire_interval = 0.9, weapon_range = 8.0, rate_per_level = 1.35},
			text = "Il compagno monta una chiodatrice (portata {weapon_range} m). Ai livelli successivi spara piu spesso."},
		{id = &"companion_magnet", deck = &"common", name = "Calamita", category = &"companion", rarity = Rarity.UNCOMMON, max_level = 2,
			requires = "companion", values = {radius = 2.5, radius_per_level = 1.5},
			text = "Il compagno attira i frammenti di esperienza entro {radius} m, piu {radius_per_level} m per livello."},
		{id = &"companion_cargo", deck = &"common", name = "Cassone rinforzato", category = &"companion", rarity = Rarity.UNCOMMON, max_level = 2,
			requires = "companion", values = {capacity = 2, scrap_now = 1},
			text = "Il compagno porta {capacity} rottami in piu e ne trova {scrap_now} subito."},
		{id = &"dig_blast", deck = &"sapper", name = "Scavo esplosivo", category = &"terrain", rarity = Rarity.UNCOMMON, max_level = 3,
			requires = "", values = {damage = 2, radius = 2.4, radius_per_level = 0.8, every_seconds = 0.5},
			text = "Ogni {every_seconds} s di scavo colpisce i rottamatori entro {radius} m ({damage} danni), piu {radius_per_level} m per livello."},
		{id = &"spiked_wall", deck = &"engineer", name = "Argini spinati", category = &"terrain", rarity = Rarity.UNCOMMON, max_level = 2,
			requires = "", values = {damage = 1, interval = 0.8, interval_level_2 = 0.5},
			text = "I rottamatori che spingono contro un argine si fanno male ({damage} danno ogni {interval} s)."},
		{id = &"brush_size", deck = &"engineer", name = "Pala larga", category = &"terrain", rarity = Rarity.COMMON, max_level = 3,
			requires = "", values = {radius_per_level = 0.4},
			text = "Il pennello del tool e piu largo di {radius_per_level} m per livello."},
		{id = &"boots", deck = &"common", name = "Scarponi slacciati", category = &"character", rarity = Rarity.COMMON, max_level = 3,
			requires = "", values = {speed_percent = 10}, text = "Corri il {speed_percent}% piu veloce."},
		{id = &"patch", deck = &"common", name = "Toppa", category = &"character", rarity = Rarity.COMMON, max_level = 3,
			requires = "", values = {health = 1}, text = "Un punto vita in piu e ti rimetti in sesto del tutto."},
		{id = &"reach", deck = &"common", name = "Tasche larghe", category = &"character", rarity = Rarity.COMMON, max_level = 3,
			requires = "", values = {radius_percent = 40}, text = "Raggio di raccolta dei frammenti piu ampio del {radius_percent}%."},
		{id = &"torch_range", deck = &"common", name = "Torcia", category = &"character", rarity = Rarity.COMMON, max_level = 3,
			requires = "", values = {radius_per_level = 1.5}, text = "La tua luce arriva {radius_per_level} metri piu lontano."},
		{id = &"beacon_range", deck = &"mechanic", name = "Faro", category = &"companion", rarity = Rarity.UNCOMMON, max_level = 3,
			requires = "companion", values = {radius_per_level = 2.0}, text = "Il faro del compagno illumina {radius_per_level} metri piu lontano."},
		{id = &"field_patch", deck = &"common", name = "Rattoppo al volo", category = &"character", rarity = Rarity.COMMON, max_level = 0,
			requires = "", filler = true, values = {heal = 1}, text = "Recuperi un punto vita."},
		{id = &"lucky_scrap", deck = &"common", name = "Rottame di fortuna", category = &"companion", rarity = Rarity.COMMON, max_level = 0,
			requires = "companion", filler = true, values = {scrap_now = 1}, text = "Un rottame in piu nel cassone, se c'e posto."},
		{id = &"nail_jar", deck = &"common", name = "Barattolo di chiodi", category = &"weapon", rarity = Rarity.COMMON, max_level = 0,
			requires = "", filler = true, values = {damage = 2, radius = 7.0},
			text = "Scoppia un barattolo: {damage} danni a tutti i rottamatori entro {radius} metri."},
	]
