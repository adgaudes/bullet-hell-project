class_name LightField
extends RefCounted
## Sorgenti di luce "logiche" del ciclo giorno/notte (D-058, tappa 1): torcia del
## giocatore, faro del compagno e, dalla tappa 2, i lampioni. Logica pura: dice se un
## punto e illuminato confrontando la distanza planare col raggio di ogni sorgente.
## Un nodo liberato o fuori dall'albero conta come spento, senza errori.

var _sources: Dictionary[int, Dictionary] = {}
var _next_id := 1


## Registra una sorgente centrata su [param node]; restituisce il suo id (da 1 in su).
func add_source(node: Node3D, radius: float) -> int:
	var id := _next_id
	_next_id += 1
	_sources[id] = {node = node, radius = maxf(radius, 0.0)}
	return id


func set_radius(id: int, radius: float) -> void:
	if _sources.has(id):
		_sources[id].radius = maxf(radius, 0.0)


func radius_of(id: int) -> float:
	return _sources[id].radius if _sources.has(id) else 0.0


func remove_source(id: int) -> void:
	_sources.erase(id)


func source_count() -> int:
	return _sources.size()


## Il punto e dentro almeno una sorgente accesa? Planare: la quota non conta.
func is_lit(world: Vector3) -> bool:
	for source: Dictionary in _sources.values():
		# Variant prima del tipo: assegnare un nodo liberato a una variabile Node3D e un errore.
		var holder: Variant = source.node
		if not is_instance_valid(holder):
			continue
		var node := holder as Node3D
		if node == null or not node.is_inside_tree():
			continue
		var radius: float = source.radius
		var origin := node.global_position
		var dx := world.x - origin.x
		var dz := world.z - origin.z
		if dx * dx + dz * dz <= radius * radius:
			return true
	return false
