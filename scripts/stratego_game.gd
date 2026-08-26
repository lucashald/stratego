class_name StrategoGame
extends RefCounted

const BOARD_SIZE := 10
const EMPTY := -1
const BLUE := 0
const RED := 1
const DRAW := -1

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
	Vector2i(2, 4), Vector2i(3, 4), Vector2i(6, 4), Vector2i(7, 4),
	Vector2i(2, 5), Vector2i(3, 5), Vector2i(6, 5), Vector2i(7, 5),
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
var max_plies := 500
var max_quiet_plies := 120
var last_move := {"from": Vector2i(-1, -1), "to": Vector2i(-1, -1)}


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
	last_move = {"from": Vector2i(-1, -1), "to": Vector2i(-1, -1)}


func setup_random(seed_value: int = 0) -> void:
	setup_empty()
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	_place_army(RED, range(0, 4), rng)
	_place_army(BLUE, range(6, 10), rng)
	# In classic Stratego, Red makes the first move.
	current_player = RED


func _place_army(player: int, rows: Array, rng: RandomNumberGenerator) -> void:
	var cells: Array[Vector2i] = []
	for y in rows:
		for x in BOARD_SIZE:
			cells.append(Vector2i(x, y))
	_shuffle(cells, rng)
	var front_row := 3 if player == RED else 6
	var flag_candidates: Array[Vector2i] = []
	for cell in cells:
		if cell.y != front_row:
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
		"revealed": false,
	})
	board[position.y][position.x] = id
	return id


func piece_at(position: Vector2i) -> Dictionary:
	if not is_inside(position):
		return {}
	var id: int = board[position.y][position.x]
	if id == EMPTY:
		return {}
	return pieces[id]


func is_inside(position: Vector2i) -> bool:
	return position.x >= 0 and position.y >= 0 and position.x < BOARD_SIZE and position.y < BOARD_SIZE


func is_lake(position: Vector2i) -> bool:
	return position in LAKES


func is_movable(piece: Dictionary) -> bool:
	return not piece.is_empty() and piece.alive and piece.type != FLAG and piece.type != BOMB


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
	var distance_limit := BOARD_SIZE if piece.type == SCOUT else 1
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
	}
	board[from.y][from.x] = EMPTY

	if defender.is_empty():
		board[to.y][to.x] = attacker_id
		_record_piece_move(attacker_id, from, to)
		quiet_plies += 1
	else:
		event.combat = true
		event.defender_type = defender.type
		pieces[attacker_id].revealed = true
		pieces[defender.id].revealed = true
		var result := resolve_combat(attacker.type, defender.type)
		event.result = result
		if defender.type == FLAG and result == "attacker":
			_remove_piece(defender.id)
			board[to.y][to.x] = attacker_id
			_record_piece_move(attacker_id, from, to)
			game_over = true
			winner = current_player
			end_reason = "flag_captured"
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

	last_move = {"from": from, "to": to}
	ply_count += 1
	if not game_over:
		current_player = other_player(current_player)
		if current_player == BLUE:
			turn_number += 1
		if ply_count >= max_plies or quiet_plies >= max_quiet_plies:
			game_over = true
			winner = DRAW
			event.result = "draw"
			end_reason = "move_limit" if ply_count >= max_plies else "no_combat_limit"
		elif get_legal_moves(current_player).is_empty():
			game_over = true
			winner = other_player(current_player)
			event.result = "immobilized"
			end_reason = "no_legal_moves"
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


func other_player(player: int) -> int:
	return RED if player == BLUE else BLUE


func player_name(player: int) -> String:
	if player == BLUE:
		return "Blue"
	if player == RED:
		return "Red"
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
