class_name PermanentCatalog
extends RefCounted
## Upgrade permanenti dell'Officina (D-041, D-049; CAMPAIGN_STRUCTURE_SPEC sezione 3).
## Si comprano coi rottami portati fuori dai livelli e restano per sempre. Dati in
## un solo posto; gli effetti li applica ArenaRun all'avvio del livello. Ogni voce:
## id, name, costs (rottami per ogni livello: la lunghezza e il livello massimo), text.

static func all() -> Array[Dictionary]:
	return [
		{id = &"tool_reach", name = "Prolunga", costs = [6, 14],
			text = "Il tool arriva una cella piu lontano."},
		{id = &"base_health", name = "Telaio rinforzato", costs = [4, 8, 14],
			text = "Un punto vita in piu a ogni livello."},
		{id = &"reflexes", name = "Riflessi da officina", costs = [5, 10],
			text = "Dopo un colpo resti intoccabile 0,2 secondi in piu."},
		{id = &"cargo", name = "Cassone saldato", costs = [4, 8, 12],
			text = "Il compagno parte con 2 posti in piu per i rottami."},
		{id = &"stock", name = "Scorta", costs = [3, 7],
			text = "Il compagno parte con 2 rottami in piu nel cassone."},
		{id = &"fixed_turret", name = "Torretta fissa", costs = [30],
			text = "Il compagno parte gia con la chiodatrice sul cassone."},
		{id = &"salvage", name = "Paracadute per rottami", costs = [10],
			text = "Se vieni rottamato salvi tre quarti del cassone invece di meta."},
	]


## Voce del catalogo, o dizionario vuoto.
static func find(id: StringName) -> Dictionary:
	for entry in all():
		if entry.id == id:
			return entry
	return {}


static func max_level(id: StringName) -> int:
	var entry := find(id)
	return (entry.costs as Array).size() if not entry.is_empty() else 0
