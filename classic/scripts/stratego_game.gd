class_name StrategoGame
extends RefCounted

const BOARD_SIZE := 20
const DEFAULT_VISION_RANGE := 4
const EMPTY := -1
const BLUE := 0
const RED := 1
const GREEN := 2
const YELLOW := 3
const DRAW := -1

# Clockwise order around the board: north, east, south, west.
const PLAYER_ORDER := [RED, GREEN, BLUE, YELLOW]

const FLAG := "F"
const BOMB := "B"
const SPY := "1"
const SCOUT := "2"
const MINER := "3"
const MARSHAL := "10"

const PIECE_COUNTS := {
	FLAG: 1,
	BOMB: 6,
	SPY: 1,
	SCOUT: 8,
	MINER: 5,
	"4": 4,
	"5": 4,
	"6": 4,
	"7": 3,
	"8": 2,
	"9": 1,
	MARSHAL: 1,
}

const PIECE_NAMES := {
	FLAG: "Flag",
	BOMB: "Bomb",
	SPY: "Spy",
	SCOUT: "Scout",
	MINER: "Miner",
	"4": "Sergeant",
	"5": "Lieutenant",
	"6": "Captain",
	"7": "Major",
	"8": "Colonel",
	"9": "General",
	MARSHAL: "Marshal",
}

const LAKES := [
	Vector2i(7, 7), Vector2i(8, 7), Vector2i(11, 7), Vector2i(12, 7),
	Vector2i(7, 8), Vector2i(8, 8), Vector2i(11, 8), Vector2i(12, 8),
	Vector2i(7, 11), Vector2i(8, 11), Vector2i(11, 11), Vector2i(12, 11),
	Vector2i(7, 12), Vector2i(8, 12), Vector2i(11, 12), Vector2i(12, 12),
]

var board: Array = []
var pieces: Array[Dictionary] = []
var current_player := BLUE
var game_over := false
var winner := DRAW
var end_reason := ""
var turn_number := 1
var ply_count := 0
var quiet_plies := 0
var max_plies := 1200
var max_quiet_plies := 240
var last_move := {"from": Vector2i(-1, -1), "to": Vector2i(-1, -1), "visible_to": []}
var active_players: Array[int] = []
var eliminated_players: Array[int] = []
var last_eliminated_player := DRAW
var last_elimination_reason := ""
var configured_player_count := 4
var private_battle_results := true
var scout_move_limit := 0
var vision_range := DEFAULT_VISION_RANGE
var battle_history: Array[Dictionary] = []
var _visible_cells_by_player: Dictionary = {}
var _visibility_dirty := true
var _cached_vision_range := -1


func _init() -> void:
	setup_empty()


func setup_empty() -> void:
	board.clear()
	for y in BOARD_SIZE:
		var row: Array[int] = []
		for x in BOARD_SIZE:
			row.append(EMPTY)
		board.append(row)
	pieces.clear()
	current_player = BLUE
	game_over = false
	winner = DRAW
	end_reason = ""
	turn_number = 1
	ply_count = 0
	quiet_plies = 0
	last_move = {"from": Vector2i(-1, -1), "to": Vector2i(-1, -1), "visible_to": []}
	active_players.clear()
	eliminated_players.clear()
	last_eliminated_player = DRAW
	last_elimination_reason = ""
	private_battle_results = true
	scout_move_limit = 0
	vision_range = DEFAULT_VISION_RANGE
	battle_history.clear()
	_visible_cells_by_player.clear()
	_visibility_dirty = true
	_cached_vision_range = -1


func setup_random(seed_value: int = 0, player_count: int = 4, use_private_battle_results: bool = true, scout_range: int = 0) -> void:
	setup_empty()
	configured_player_count = clampi(player_count, 2, 4)
	private_battle_results = use_private_battle_results
	scout_move_limit = clampi(scout_range, 0, BOARD_SIZE - 1)
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var roster := players_for_count(configured_player_count)
	for player in roster:
		_place_army(player, _deployment_cells(player), rng)
	active_players.assign(roster)
	# Red begins, then play proceeds clockwise around the board.
	current_player = RED


static func players_for_count(player_count: int) -> Array[int]:
	match clampi(player_count, 2, 4):
		2:
			return [RED, BLUE]
		3:
			return [RED, GREEN, BLUE]
		_:
			return [RED, GREEN, BLUE, YELLOW]


func _place_army(player: int, deployment: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	var cells := deployment.duplicate()
	_shuffle(cells, rng)
	var flag_candidates: Array[Vector2i] = []
	for cell in cells:
		if not _is_front_deployment_cell(player, cell):
			flag_candidates.append(cell)
	var flag_position: Vector2i = flag_candidates[rng.randi_range(0, flag_candidates.size() - 1)]
	add_piece(FLAG, player, flag_position)
	cells.erase(flag_position)

	var types: Array[String] = []
	for type: String in PIECE_COUNTS:
		if type == FLAG:
			continue
		for _count in int(PIECE_COUNTS[type]):
			types.append(type)
	_shuffle(types, rng)
	for i in types.size():
		add_piece(types[i], player, cells[i])


func _deployment_cells(player: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match player:
		RED:
			for y in range(0, 4):
				for x in range(5, 15):
					cells.append(Vector2i(x, y))
		GREEN:
			for y in range(5, 15):
				for x in range(16, 20):
					cells.append(Vector2i(x, y))
		BLUE:
			for y in range(16, 20):
				for x in range(5, 15):
					cells.append(Vector2i(x, y))
		YELLOW:
			for y in range(5, 15):
				for x in range(0, 4):
					cells.append(Vector2i(x, y))
	return cells


func is_in_deployment(player: int, position: Vector2i) -> bool:
	return position in _deployment_cells(player)


func _is_front_deployment_cell(player: int, position: Vector2i) -> bool:
	match player:
		RED:
			return position.y == 3
		GREEN:
			return position.x == 16
		BLUE:
			return position.y == 16
		YELLOW:
			return position.x == 3
	return false


func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temporary = values[i]
		values[i] = values[j]
		values[j] = temporary


func add_piece(type: String, player: int, position: Vector2i) -> int:
	assert(is_inside(position) and not is_lake(position))
	assert(board[position.y][position.x] == EMPTY)
	var id := pieces.size()
	pieces.append({
		"id": id,
		"type": type,
		"player": player,
		"position": position,
		"previous_position": Vector2i(-1, -1),
		"has_moved": false,
		"move_count": 0,
		"recent_positions": [position],
		"alive": true,
		"revealed_to": [],
	})
	board[position.y][position.x] = id
	if player not in active_players:
		active_players.append(player)
		_sort_active_players()
	_visibility_dirty = true
	return id


func _sort_active_players() -> void:
	active_players.sort_custom(func(a: int, b: int) -> bool:
		return PLAYER_ORDER.find(a) < PLAYER_ORDER.find(b)
	)


func piece_at(position: Vector2i) -> Dictionary:
	if not is_inside(position):
		return {}
	var id: int = board[position.y][position.x]
	if id == EMPTY:
		return {}
	return pieces[id]


func is_position_visible_to(position: Vector2i, player: int) -> bool:
	if not is_inside(position):
		return false
	_ensure_visibility_cache()
	return position in _visible_cells_by_player.get(player, {})


func _ensure_visibility_cache() -> void:
	if not _visibility_dirty and _cached_vision_range == vision_range:
		return
	_visible_cells_by_player.clear()
	for player in PLAYER_ORDER:
		_visible_cells_by_player[player] = {}
	for piece: Dictionary in pieces:
		if not piece.alive:
			continue
		var visible_cells: Dictionary = _visible_cells_by_player[int(piece.player)]
		for y_offset in range(-vision_range, vision_range + 1):
			var horizontal_reach := vision_range - absi(y_offset)
			for x_offset in range(-horizontal_reach, horizontal_reach + 1):
				var visible_position: Vector2i = piece.position + Vector2i(x_offset, y_offset)
				if is_inside(visible_position):
					visible_cells[visible_position] = true
	_visibility_dirty = false
	_cached_vision_range = vision_range


func is_piece_visible_to(piece: Dictionary, player: int) -> bool:
	if piece.is_empty() or not bool(piece.get("alive", false)):
		return false
	if int(piece.player) == player:
		return true
	return is_position_visible_to(piece.position, player)


func observed_piece_at(position: Vector2i, player: int) -> Dictionary:
	var piece := piece_at(position)
	return piece if is_piece_visible_to(piece, player) else {}


func is_inside(position: Vector2i) -> bool:
	return position.x >= 0 and position.y >= 0 and position.x < BOARD_SIZE and position.y < BOARD_SIZE


func is_lake(position: Vector2i) -> bool:
	return position in LAKES


func is_movable(piece: Dictionary) -> bool:
	return not piece.is_empty() and piece.alive and piece.type != FLAG and piece.type != BOMB


func movement_limit_for(piece: Dictionary) -> int:
	if piece.type == SCOUT:
		return BOARD_SIZE if scout_move_limit == 0 else scout_move_limit
	return 1


func get_legal_moves(player: int = current_player) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	if game_over:
		return moves
	for piece: Dictionary in pieces:
		if piece.alive and piece.player == player and is_movable(piece):
			moves.append_array(get_moves_for(piece.position))
	return moves


func get_moves_for(from: Vector2i) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	var piece := piece_at(from)
	if not is_movable(piece):
		return moves
	var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var distance_limit := movement_limit_for(piece)
	for direction in directions:
		for distance in range(1, distance_limit + 1):
			var destination: Vector2i = from + direction * distance
			if not is_inside(destination) or is_lake(destination):
				break
			var target := piece_at(destination)
			if target.is_empty():
				moves.append({"from": from, "to": destination})
				continue
			if target.player != piece.player:
				moves.append({"from": from, "to": destination})
			break
	return moves


func is_legal_move(from: Vector2i, to: Vector2i, player: int = current_player) -> bool:
	var piece := piece_at(from)
	if piece.is_empty() or piece.player != player:
		return false
	for move in get_moves_for(from):
		if move.to == to:
			return true
	return false


func apply_move(from: Vector2i, to: Vector2i) -> Dictionary:
	if game_over or not is_legal_move(from, to, current_player):
		return {"ok": false, "message": "Illegal move."}

	var attacker_id: int = board[from.y][from.x]
	var attacker: Dictionary = pieces[attacker_id]
	var defender := piece_at(to)
	var event := {
		"ok": true,
		"player": current_player,
		"from": from,
		"to": to,
		"attacker_type": attacker.type,
		"defender_type": "",
		"combat": false,
		"result": "move",
		"defender_player": DRAW,
		"eliminations": [],
		"known_to": [],
		"visible_to": _move_viewers(attacker.player, from, to),
	}
	board[from.y][from.x] = EMPTY

	if defender.is_empty():
		board[to.y][to.x] = attacker_id
		_record_piece_move(attacker_id, from, to)
		quiet_plies += 1
	else:
		event.combat = true
		event.defender_type = defender.type
		event.defender_player = defender.player
		event.known_to = _battle_result_viewers(attacker.player, defender.player)
		for viewer in event.known_to:
			reveal_piece_to(attacker_id, viewer)
			reveal_piece_to(defender.id, viewer)
		var result := resolve_combat(attacker.type, defender.type)
		event.result = result
		if defender.type == FLAG and result == "attacker":
			_remove_piece(defender.id)
			board[to.y][to.x] = attacker_id
			_record_piece_move(attacker_id, from, to)
			_eliminate_player(defender.player, "flag_captured", event.eliminations)
		elif result == "attacker":
			_remove_piece(defender.id)
			board[to.y][to.x] = attacker_id
			_record_piece_move(attacker_id, from, to)
		elif result == "defender":
			_remove_piece(attacker_id)
			board[to.y][to.x] = defender.id
		else:
			_remove_piece(attacker_id)
			_remove_piece(defender.id)
			board[to.y][to.x] = EMPTY
		quiet_plies = 0

	last_move = {"from": from, "to": to, "visible_to": event.visible_to.duplicate()}
	ply_count += 1
	if not game_over:
		if ply_count >= max_plies or quiet_plies >= max_quiet_plies:
			game_over = true
			winner = DRAW
			event.result = "draw"
			end_reason = "move_limit" if ply_count >= max_plies else "no_combat_limit"
		elif _finish_if_one_player_remains("flag_captured" if not event.eliminations.is_empty() else ""):
			pass
		else:
			_advance_to_playable_player(current_player, event.eliminations)
	event["game_over"] = game_over
	event["winner"] = winner
	event["end_reason"] = end_reason
	if bool(event.combat):
		battle_history.append(event.duplicate(true))
	return event


func _move_viewers(moving_player: int, from: Vector2i, to: Vector2i) -> Array[int]:
	var viewers: Array[int] = []
	for player in active_players:
		if player == moving_player or is_position_visible_to(from, player) or is_position_visible_to(to, player):
			viewers.append(player)
	return viewers


func _battle_result_viewers(attacker_player: int, defender_player: int) -> Array[int]:
	if not private_battle_results:
		var public_viewers := active_players.duplicate()
		for player in eliminated_players:
			if player not in public_viewers:
				public_viewers.append(player)
		return public_viewers
	return [attacker_player, defender_player]


func reveal_piece_to(piece_id: int, player: int) -> void:
	if piece_id < 0 or piece_id >= pieces.size():
		return
	var viewers: Array = pieces[piece_id].revealed_to
	if player not in viewers:
		viewers.append(player)
	pieces[piece_id].revealed_to = viewers


func reveal_piece_to_all(piece_id: int) -> void:
	for player in active_players:
		reveal_piece_to(piece_id, player)
	for player in eliminated_players:
		reveal_piece_to(piece_id, player)


func is_piece_revealed_to(piece: Dictionary, player: int) -> bool:
	if piece.is_empty():
		return false
	if int(piece.player) == player:
		return true
	return player in piece.get("revealed_to", [])


func is_piece_revealed_to_any_opponent(piece: Dictionary, owner: int) -> bool:
	for viewer in piece.get("revealed_to", []):
		if int(viewer) != owner:
			return true
	return false


func battle_events_for(player: int) -> Array[Dictionary]:
	var known_events: Array[Dictionary] = []
	for event in battle_history:
		if player in event.get("known_to", []):
			known_events.append(event.duplicate(true))
	return known_events


func _advance_to_playable_player(from_player: int, eliminations: Array) -> void:
	var previous := from_player
	while not game_over:
		var next := next_player(previous)
		if next == DRAW:
			_finish_if_one_player_remains("no_legal_moves")
			return
		if PLAYER_ORDER.find(next) <= PLAYER_ORDER.find(previous):
			turn_number += 1
		current_player = next
		if not get_legal_moves(current_player).is_empty():
			return
		_eliminate_player(current_player, "no_legal_moves", eliminations)
		if _finish_if_one_player_remains("no_legal_moves"):
			return
		previous = current_player


func _eliminate_player(player: int, reason: String, eliminations: Array) -> void:
	if player not in active_players:
		return
	for piece: Dictionary in pieces:
		if piece.alive and piece.player == player:
			if is_inside(piece.position) and board[piece.position.y][piece.position.x] == piece.id:
				board[piece.position.y][piece.position.x] = EMPTY
			_remove_piece(piece.id)
	active_players.erase(player)
	if player not in eliminated_players:
		eliminated_players.append(player)
	last_eliminated_player = player
	last_elimination_reason = reason
	eliminations.append({"player": player, "reason": reason})


func _finish_if_one_player_remains(final_reason: String) -> bool:
	if active_players.size() > 1:
		return false
	game_over = true
	winner = active_players[0] if active_players.size() == 1 else DRAW
	end_reason = final_reason if not final_reason.is_empty() else "last_player_standing"
	return true


func eliminate_immobilized_current_player() -> Dictionary:
	if game_over or not get_legal_moves(current_player).is_empty():
		return {"ok": false, "message": "Current player is not immobilized."}
	var eliminated := current_player
	var event := {
		"ok": true,
		"player": eliminated,
		"from": Vector2i(-1, -1),
		"to": Vector2i(-1, -1),
		"attacker_type": "",
		"defender_type": "",
		"defender_player": DRAW,
		"combat": false,
		"result": "immobilized",
		"eliminations": [],
	}
	_eliminate_player(eliminated, "no_legal_moves", event.eliminations)
	if not _finish_if_one_player_remains("no_legal_moves"):
		_advance_to_playable_player(eliminated, event.eliminations)
	event["game_over"] = game_over
	event["winner"] = winner
	event["end_reason"] = end_reason
	return event


func resolve_combat(attacker_type: String, defender_type: String) -> String:
	if defender_type == FLAG:
		return "attacker"
	if defender_type == BOMB:
		return "attacker" if attacker_type == MINER else "defender"
	if attacker_type == SPY and defender_type == MARSHAL:
		return "attacker"
	var attacker_rank := int(attacker_type)
	var defender_rank := int(defender_type)
	if attacker_rank > defender_rank:
		return "attacker"
	if defender_rank > attacker_rank:
		return "defender"
	return "both"


func _remove_piece(id: int) -> void:
	pieces[id].alive = false
	pieces[id].position = Vector2i(-1, -1)
	_visibility_dirty = true


func _record_piece_move(id: int, from: Vector2i, to: Vector2i) -> void:
	pieces[id].previous_position = from
	pieces[id].position = to
	pieces[id].has_moved = true
	pieces[id].move_count = int(pieces[id].move_count) + 1
	var history: Array = pieces[id].recent_positions
	history.append(to)
	while history.size() > 8:
		history.pop_front()
	pieces[id].recent_positions = history
	_visibility_dirty = true


func next_player(player: int) -> int:
	if active_players.is_empty():
		return DRAW
	var start_index := PLAYER_ORDER.find(player)
	if start_index < 0:
		start_index = 0
	for offset in range(1, PLAYER_ORDER.size() + 1):
		var candidate: int = PLAYER_ORDER[(start_index + offset) % PLAYER_ORDER.size()]
		if candidate in active_players:
			return candidate
	return DRAW


func opponents_of(player: int) -> Array[int]:
	var opponents: Array[int] = []
	for candidate in active_players:
		if candidate != player:
			opponents.append(candidate)
	return opponents


func advancement_delta(player: int, from: Vector2i, to: Vector2i) -> float:
	var center := Vector2(float(BOARD_SIZE - 1) * 0.5, float(BOARD_SIZE - 1) * 0.5)
	return Vector2(from).distance_to(center) - Vector2(to).distance_to(center)


func center_lane_distance(player: int, position: Vector2i) -> float:
	var center := float(BOARD_SIZE - 1) * 0.5
	return absf(float(position.x) - center) if player in [RED, BLUE] else absf(float(position.y) - center)


func home_edge_distance(player: int, position: Vector2i) -> int:
	match player:
		RED:
			return position.y
		GREEN:
			return BOARD_SIZE - 1 - position.x
		BLUE:
			return BOARD_SIZE - 1 - position.y
		YELLOW:
			return position.x
	return BOARD_SIZE


func player_name(player: int) -> String:
	if player == BLUE:
		return "Blue"
	if player == RED:
		return "Red"
	if player == GREEN:
		return "Green"
	if player == YELLOW:
		return "Yellow"
	return "Draw"


func get_material_score(player: int) -> float:
	var score := 0.0
	for piece: Dictionary in pieces:
		if piece.alive and piece.player == player:
			if piece.type == FLAG:
				score += 20.0
			elif piece.type == BOMB:
				score += 2.5
			else:
				score += maxf(1.0, float(int(piece.type)) * 0.65)
	return score


func count_alive(player: int) -> int:
	var count := 0
	for piece: Dictionary in pieces:
		if piece.alive and piece.player == player:
			count += 1
	return count


func count_alive_type(player: int, type: String) -> int:
	var count := 0
	for piece: Dictionary in pieces:
		if piece.alive and piece.player == player and piece.type == type:
			count += 1
	return count


func find_alive_piece(player: int, type: String) -> Dictionary:
	for piece: Dictionary in pieces:
		if piece.alive and piece.player == player and piece.type == type:
			return piece
	return {}
