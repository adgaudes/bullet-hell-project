class_name TerrainState
extends RefCounted
## Stato logico della griglia terreno, indipendente dalla presentazione.
##
## Coordinate di cella come in Unreal: X lungo l'asse X Unreal, Y lungo l'asse Y,
## indice = Y * width + X. I log restano cosi confrontabili con il protocollo
## di playtest della Slice A.

enum CellState { LOWERED, NORMAL, RAISED }
enum ToolMode { DIG, RAISE }

var width := 0
var height := 0
## La cella protetta non e mai modificabile.
var protected_cell := Vector2i(0, 0)

var _states := PackedByteArray()


## Ridimensiona la griglia. Come in Unreal lo stato e azzerato solo se cambia
## il numero di celle; altrimenti e conservato attraverso la ricostruzione.
func resize(new_width: int, new_height: int) -> void:
	width = new_width
	height = new_height
	var count := new_width * new_height
	if _states.size() != count:
		_states.resize(count)
		_states.fill(CellState.NORMAL)


func cell_count() -> int:
	return _states.size()


func is_valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height


func is_protected(cell: Vector2i) -> bool:
	return cell == protected_cell


## Fuori griglia vale NORMAL: nessun avvolgimento sulla riga precedente (T-04).
func get_state(cell: Vector2i) -> CellState:
	if not is_valid(cell):
		return CellState.NORMAL
	return _states[_index(cell)] as CellState


## [param raise_blocked]: true se il rialzo intersecherebbe chi lo richiede.
func can_apply(cell: Vector2i, mode: ToolMode, raise_blocked := false) -> bool:
	if not is_valid(cell) or is_protected(cell):
		return false
	var state := get_state(cell)
	if mode == ToolMode.DIG:
		return state != CellState.LOWERED
	if state == CellState.RAISED:
		return false
	return not raise_blocked


## Rifiuto dovuto solo all'occupazione: distingue il log dedicato di Unreal.
func is_occupied_rejection(cell: Vector2i, mode: ToolMode, raise_blocked: bool) -> bool:
	return is_valid(cell) and mode == ToolMode.RAISE and not is_protected(cell) \
		and get_state(cell) != CellState.RAISED and raise_blocked


## Un passo del comando: Dig abbassa di un livello, Raise alza di un livello.
## Da chiamare solo dopo can_apply().
func apply(cell: Vector2i, mode: ToolMode) -> CellState:
	var state := get_state(cell)
	if mode == ToolMode.DIG:
		state = CellState.NORMAL if state == CellState.RAISED else CellState.LOWERED
	else:
		state = CellState.NORMAL if state == CellState.LOWERED else CellState.RAISED
	_states[_index(cell)] = state
	return state


## Imposta lo stato senza regole: solo per la disposizione iniziale di una scena.
func set_state(cell: Vector2i, state: CellState) -> void:
	_states[_index(cell)] = state


static func state_name(state: CellState) -> String:
	match state:
		CellState.LOWERED:
			return "Lowered"
		CellState.RAISED:
			return "Raised"
		_:
			return "Normal"


func _index(cell: Vector2i) -> int:
	return cell.y * width + cell.x
