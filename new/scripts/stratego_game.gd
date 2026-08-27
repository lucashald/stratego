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
const PLAYER_ORDER := [RED, GREEN, BLUE, YELLOW]

const FLAG := "F"
const LIGHT_INFANTRY := "LI"
const MEDIUM_INFANTRY := "MI"
const HEAVY_INFANTRY := "HI"
const LIGHT_ARCHER := "LA"
const MEDIUM_ARCHER := "MA"
const HEAVY_ARCHER := "HA"
const LIGHT_CAVALRY := "LC"
const MEDIUM_CAVALRY := "MC"
const HEAVY_CAVALRY := "HC"
const ROLE_INFANTRY := "infantry"
const ROLE_ARCHER := "archer"
const ROLE_CAVALRY := "cavalry"
const WEIGHT_LIGHT := "light"
const WEIGHT_MEDIUM := "medium"
const WEIGHT_HEAVY := "heavy"
const ROLE_BONUS := 3

const PHASE_PLANNING := "planning"
const PHASE_RESOLVING := "resolving"
const PHASE_GAME_OVER := "game_over"
const SCENARIO_FOUR_PLAYER := "four_player"
const SCENARIO_BRIDGE := "bridge"
const STATUS_READY := "ready"
const STATUS_WON := "won"
const STATUS_LOST := "lost"
const STATUS_BOUNCED := "bounced"

const BRIDGE_RIVER_Y := 9
const BRIDGE_COLUMNS := [8, 9, 10, 11]
const BRIDGE_STRENGTH_TARGET := 20
const DEFAULT_BRIDGE_TURN_LIMIT := 20

const MOVEMENT_BY_WEIGHT := {WEIGHT_LIGHT: 3, WEIGHT_MEDIUM: 2, WEIGHT_HEAVY: 1}
const ARMOR_BY_WEIGHT := {WEIGHT_LIGHT: 0, WEIGHT_MEDIUM: 1, WEIGHT_HEAVY: 2}
const PIECE_DEFINITIONS := {
	FLAG: {"name": "Flag", "role": "", "weight": "", "strength": 0},
	LIGHT_INFANTRY: {"name": "Light Infantry", "role": ROLE_INFANTRY, "weight": WEIGHT_LIGHT, "strength": 6},
	MEDIUM_INFANTRY: {"name": "Medium Infantry", "role": ROLE_INFANTRY, "weight": WEIGHT_MEDIUM, "strength": 7},
	HEAVY_INFANTRY: {"name": "Heavy Infantry", "role": ROLE_INFANTRY, "weight": WEIGHT_HEAVY, "strength": 8},
	LIGHT_ARCHER: {"name": "Light Archer", "role": ROLE_ARCHER, "weight": WEIGHT_LIGHT, "strength": 5},
	MEDIUM_ARCHER: {"name": "Medium Archer", "role": ROLE_ARCHER, "weight": WEIGHT_MEDIUM, "strength": 6},
	HEAVY_ARCHER: {"name": "Heavy Archer", "role": ROLE_ARCHER, "weight": WEIGHT_HEAVY, "strength": 7},
	LIGHT_CAVALRY: {"name": "Light Cavalry", "role": ROLE_CAVALRY, "weight": WEIGHT_LIGHT, "strength": 6},
	MEDIUM_CAVALRY: {"name": "Medium Cavalry", "role": ROLE_CAVALRY, "weight": WEIGHT_MEDIUM, "strength": 7},
	HEAVY_CAVALRY: {"name": "Heavy Cavalry", "role": ROLE_CAVALRY, "weight": WEIGHT_HEAVY, "strength": 8},
}
const PIECE_NAMES := {
	FLAG: "Flag", LIGHT_INFANTRY: "Light Infantry", MEDIUM_INFANTRY: "Medium Infantry", HEAVY_INFANTRY: "Heavy Infantry",
	LIGHT_ARCHER: "Light Archer", MEDIUM_ARCHER: "Medium Archer", HEAVY_ARCHER: "Heavy Archer",
	LIGHT_CAVALRY: "Light Cavalry", MEDIUM_CAVALRY: "Medium Cavalry", HEAVY_CAVALRY: "Heavy Cavalry",
}
const PIECE_COUNTS := {
	FLAG: 1, HEAVY_INFANTRY: 2, MEDIUM_INFANTRY: 2, LIGHT_INFANTRY: 2,
	HEAVY_ARCHER: 2, MEDIUM_ARCHER: 2, LIGHT_ARCHER: 1, MEDIUM_CAVALRY: 1,
}
const BRIDGE_ATTACKER_ROSTER := [
	HEAVY_INFANTRY, HEAVY_INFANTRY, MEDIUM_INFANTRY, MEDIUM_INFANTRY, LIGHT_INFANTRY,
	HEAVY_ARCHER, MEDIUM_ARCHER, LIGHT_ARCHER, HEAVY_CAVALRY, MEDIUM_CAVALRY, MEDIUM_CAVALRY, LIGHT_CAVALRY,
]
const BRIDGE_DEFENDER_ROSTER := [
	HEAVY_INFANTRY, HEAVY_INFANTRY, HEAVY_INFANTRY, MEDIUM_INFANTRY, MEDIUM_INFANTRY, LIGHT_INFANTRY,
	HEAVY_ARCHER, HEAVY_ARCHER, MEDIUM_ARCHER, MEDIUM_ARCHER, LIGHT_ARCHER, MEDIUM_CAVALRY,
]
const LAKES := [
	Vector2i(7, 7), Vector2i(8, 7), Vector2i(11, 7), Vector2i(12, 7),
	Vector2i(7, 8), Vector2i(8, 8), Vector2i(11, 8), Vector2i(12, 8),
	Vector2i(7, 11), Vector2i(8, 11), Vector2i(11, 11), Vector2i(12, 11),
	Vector2i(7, 12), Vector2i(8, 12), Vector2i(11, 12), Vector2i(12, 12),
]

var board: Array = []
var pieces: Array[Dictionary] = []
var active_players: Array[int] = []
var eliminated_players: Array[int] = []
var player_teams: Dictionary = {}
var orders: Dictionary = {}
var ready_players: Array[int] = []
var battle_history: Array[Dictionary] = []
var last_round_events: Array[Dictionary] = []
var last_move := {"from": Vector2i(-1, -1), "to": Vector2i(-1, -1), "visible_to": [], "action": ""}

var phase := PHASE_PLANNING
var scenario := SCENARIO_FOUR_PLAYER
var configured_player_count := 4
var round_number := 1
var turn_number := 1
var game_over := false
var winner := DRAW
var winning_team := DRAW
var end_reason := ""
var withdrawing_player := DRAW
var last_eliminated_player := DRAW
var last_elimination_reason := ""
var private_battle_results := true
var vision_range := DEFAULT_VISION_RANGE
var bridge_attacker := BLUE
var bridge_defender := RED
var bridge_turn_limit := DEFAULT_BRIDGE_TURN_LIMIT
var bridge_strength_target := BRIDGE_STRENGTH_TARGET

# Compatibility counters retained for the model/training shell.
var current_player := BLUE
var ply_count := 0
var quiet_plies := 0
var max_plies := 1200
var max_quiet_plies := 240

var _visible_cells_by_player: Dictionary = {}
var _visibility_dirty := true
var _cached_vision_range := -1
var _rng := RandomNumberGenerator.new()
var _forced_rolls: Array[int] = []


func _init() -> void:
	_rng.randomize()
	setup_empty()


func setup_empty() -> void:
	board.clear()
	for _y in BOARD_SIZE:
		var row: Array[int] = []
		for _x in BOARD_SIZE:
			row.append(EMPTY)
		board.append(row)
	pieces.clear()
	active_players.clear()
	eliminated_players.clear()
	player_teams.clear()
	orders.clear()
	ready_players.clear()
	battle_history.clear()
	last_round_events.clear()
	last_move = {"from": Vector2i(-1, -1), "to": Vector2i(-1, -1), "visible_to": [], "action": ""}
	phase = PHASE_PLANNING
	scenario = SCENARIO_FOUR_PLAYER
	configured_player_count = 4
	round_number = 1
	turn_number = 1
	game_over = false
	winner = DRAW
	winning_team = DRAW
	end_reason = ""
	withdrawing_player = DRAW
	last_eliminated_player = DRAW
	last_elimination_reason = ""
	private_battle_results = true
	vision_range = DEFAULT_VISION_RANGE
	bridge_attacker = BLUE
	bridge_defender = RED
	bridge_turn_limit = DEFAULT_BRIDGE_TURN_LIMIT
	bridge_strength_target = BRIDGE_STRENGTH_TARGET
	current_player = BLUE
	ply_count = 0
	quiet_plies = 0
	_forced_rolls.clear()
	_visible_cells_by_player.clear()
	_visibility_dirty = true
	_cached_vision_range = -1


func setup_random(seed_value: int = 0, player_count: int = 4, use_private_battle_results: bool = true, _unused_legacy_range: int = 0) -> void:
	setup_empty()
	scenario = SCENARIO_FOUR_PLAYER
	configured_player_count = clampi(player_count, 2, 4)
	private_battle_results = use_private_battle_results
	_seed_rng(seed_value)
	var roster := players_for_count(configured_player_count)
	for player in roster:
		player_teams[player] = player
		_place_army(player, _starting_cells(player), _rng)
	active_players.assign(roster)
	current_player = BLUE if BLUE in active_players else active_players[0]
	_record_all_sightings()


func setup_bridge(seed_value: int = 0, attacker: int = BLUE, defender: int = RED, turn_limit: int = DEFAULT_BRIDGE_TURN_LIMIT, use_private_battle_results: bool = true) -> void:
	setup_empty()
	scenario = SCENARIO_BRIDGE
	configured_player_count = 2
	private_battle_results = use_private_battle_results
	bridge_attacker = attacker
	bridge_defender = defender
	bridge_turn_limit = maxi(1, turn_limit)
	player_teams[attacker] = attacker
	player_teams[defender] = defender
	_seed_rng(seed_value)
	_place_roster(attacker, BRIDGE_ATTACKER_ROSTER, _bridge_attacker_deployment(), _rng)
	_place_roster(defender, BRIDGE_DEFENDER_ROSTER, _bridge_defender_deployment(), _rng)
	active_players.assign([defender, attacker])
	_sort_active_players()
	current_player = attacker
	_record_all_sightings()


func _seed_rng(seed_value: int) -> void:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value


static func players_for_count(player_count: int) -> Array[int]:
	match clampi(player_count, 2, 4):
		2: return [RED, BLUE]
		3: return [RED, GREEN, BLUE]
		_: return [RED, GREEN, BLUE, YELLOW]


func _place_army(player: int, deployment: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	var cells := deployment.duplicate()
	_shuffle(cells, rng)
	add_piece(FLAG, player, cells.pop_front())
	var types: Array[String] = []
	for type: String in PIECE_COUNTS:
		if type != FLAG:
			for _count in int(PIECE_COUNTS[type]):
				types.append(type)
	_shuffle(types, rng)
	for index in types.size():
		add_piece(types[index], player, cells[index])


func _place_roster(player: int, roster: Array, deployment: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	var cells := deployment.duplicate()
	var types := roster.duplicate()
	_shuffle(cells, rng)
	_shuffle(types, rng)
	for index in types.size():
		add_piece(String(types[index]), player, cells[index])


func _starting_cells(player: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match player:
		RED:
			for y in range(0, 2):
				for x in range(6, 13): cells.append(Vector2i(x, y))
		GREEN:
			for y in range(6, 13):
				for x in range(18, 20): cells.append(Vector2i(x, y))
		BLUE:
			for y in range(18, 20):
				for x in range(6, 13): cells.append(Vector2i(x, y))
		YELLOW:
			for y in range(6, 13):
				for x in range(0, 2): cells.append(Vector2i(x, y))
	return cells


func _bridge_attacker_deployment() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in BOARD_SIZE: cells.append(Vector2i(x, BOARD_SIZE - 1))
	return cells


func _bridge_defender_deployment() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(0, BRIDGE_RIVER_Y):
		for x in BOARD_SIZE: cells.append(Vector2i(x, y))
	return cells


func valid_deployment_cells(player: int) -> Array[Vector2i]:
	if scenario == SCENARIO_BRIDGE:
		return _bridge_attacker_deployment() if player == bridge_attacker else _bridge_defender_deployment()
	return _starting_cells(player)


func is_in_deployment(player: int, position: Vector2i) -> bool:
	return position in valid_deployment_cells(player)


func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary


func add_piece(type: String, player: int, position: Vector2i, strength_override: int = -1) -> int:
	assert(type in PIECE_DEFINITIONS)
	assert(is_inside(position) and not is_blocked_terrain(position))
	assert(board[position.y][position.x] == EMPTY)
	var definition: Dictionary = PIECE_DEFINITIONS[type]
	var starting_strength: int = int(definition.strength) if strength_override < 0 else strength_override
	var weight := String(definition.weight)
	var id := pieces.size()
	pieces.append({
		"id": id, "type": type, "player": player, "role": String(definition.role), "weight": weight,
		"strength": starting_strength, "max_strength": starting_strength, "armor": int(ARMOR_BY_WEIGHT.get(weight, 0)),
		"position": position, "previous_position": position, "alive": true, "revealed_to": [], "seen_by": [],
		"round_status": STATUS_READY, "movement_used": 0, "melee_count": 0, "participated_in_combat": false,
		"main_done": false, "move_count": 0, "recent_positions": [position],
	})
	board[position.y][position.x] = id
	if player not in active_players:
		active_players.append(player)
		_sort_active_players()
	if player not in player_teams: player_teams[player] = player
	_visibility_dirty = true
	return id


func _sort_active_players() -> void:
	active_players.sort_custom(func(a: int, b: int) -> bool: return PLAYER_ORDER.find(a) < PLAYER_ORDER.find(b))


func set_player_team(player: int, team: int) -> void:
	player_teams[player] = team


func are_allied_players(first: int, second: int) -> bool:
	return int(player_teams.get(first, first)) == int(player_teams.get(second, second))


func piece_at(position: Vector2i) -> Dictionary:
	if not is_inside(position): return {}
	var id: int = board[position.y][position.x]
	return {} if id == EMPTY else pieces[id]


func is_inside(position: Vector2i) -> bool:
	return position.x >= 0 and position.y >= 0 and position.x < BOARD_SIZE and position.y < BOARD_SIZE


func is_lake(position: Vector2i) -> bool:
	return scenario != SCENARIO_BRIDGE and position in LAKES


func is_water(position: Vector2i) -> bool:
	return scenario == SCENARIO_BRIDGE and position.y == BRIDGE_RIVER_Y and position.x not in BRIDGE_COLUMNS


func is_bridge(position: Vector2i) -> bool:
	return scenario == SCENARIO_BRIDGE and position.y == BRIDGE_RIVER_Y and position.x in BRIDGE_COLUMNS


func is_blocked_terrain(position: Vector2i) -> bool:
	return is_lake(position) or is_water(position)


func is_movable(piece: Dictionary) -> bool:
	return not piece.is_empty() and bool(piece.get("alive", false)) and piece.type != FLAG and int(piece.strength) > 0


func movement_limit_for(piece: Dictionary) -> int:
	return int(MOVEMENT_BY_WEIGHT.get(piece.get("weight", ""), 0))


func order_for_piece(piece_id: int) -> Dictionary:
	if piece_id < 0 or piece_id >= pieces.size(): return {}
	var player := int(pieces[piece_id].player)
	return orders.get(player, {}).get(piece_id, {})


func orders_for_player(player: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for order: Dictionary in orders.get(player, {}).values(): result.append(order.duplicate(true))
	return result


func projected_order_position(piece_id: int, impulse: int) -> Vector2i:
	var piece: Dictionary = pieces[piece_id]
	var path: Array = order_for_piece(piece_id).get("path", [])
	if impulse <= 0 or path.is_empty(): return piece.position
	return path[mini(impulse, path.size()) - 1]


func projected_main_destination(piece_id: int) -> Vector2i:
	var path: Array = order_for_piece(piece_id).get("path", [])
	return pieces[piece_id].position if path.is_empty() else path.back()


func set_unit_order(player: int, piece_id: int, path: Array, ranged_target: Vector2i = Vector2i(-1, -1), leftover: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if phase != PHASE_PLANNING or game_over or player in ready_players:
		return {"ok": false, "message": "Orders can only be changed during planning."}
	if piece_id < 0 or piece_id >= pieces.size(): return {"ok": false, "message": "Unknown formation."}
	var piece: Dictionary = pieces[piece_id]
	if not is_movable(piece) or int(piece.player) != player:
		return {"ok": false, "message": "That formation cannot receive this order."}
	var normalized_path: Array[Vector2i] = []
	var previous: Vector2i = piece.position
	for value in path:
		var step: Vector2i = value
		if previous.distance_to(step) != 1.0 or not is_inside(step) or is_blocked_terrain(step):
			return {"ok": false, "message": "Paths must use adjacent passable squares."}
		normalized_path.append(step)
		previous = step
	var movement_cost := normalized_path.size()
	if ranged_target.x >= 0:
		if piece.role != ROLE_ARCHER: return {"ok": false, "message": "Only Archers can receive ranged orders."}
		if previous.distance_to(ranged_target) != 1.0:
			return {"ok": false, "message": "Archers can only target an adjacent square after their main path."}
		movement_cost += 1
	if leftover.x >= 0:
		if previous.distance_to(leftover) != 1.0 or not is_inside(leftover) or is_blocked_terrain(leftover):
			return {"ok": false, "message": "Leftover movement is one adjacent passable square."}
		movement_cost += 1
	if movement_cost > movement_limit_for(piece):
		return {"ok": false, "message": "That order exceeds the formation's movement allowance."}
	var candidate := {"piece_id": piece_id, "player": player, "path": normalized_path, "ranged_target": ranged_target, "leftover": leftover}
	if not _same_player_order_is_clear(player, piece_id, candidate):
		return {"ok": false, "message": "Friendly formations would collide on the same impulse."}
	if player not in orders: orders[player] = {}
	orders[player][piece_id] = candidate
	return {"ok": true, "order": candidate.duplicate(true)}


func append_order_step(player: int, piece_id: int, step: Vector2i) -> Dictionary:
	var current := order_for_piece(piece_id)
	var path: Array = current.get("path", []).duplicate()
	path.append(step)
	return set_unit_order(player, piece_id, path, current.get("ranged_target", Vector2i(-1, -1)), current.get("leftover", Vector2i(-1, -1)))


func pop_order_step(player: int, piece_id: int) -> Dictionary:
	var current := order_for_piece(piece_id)
	var path: Array = current.get("path", []).duplicate()
	if not path.is_empty(): path.pop_back()
	return set_unit_order(player, piece_id, path, current.get("ranged_target", Vector2i(-1, -1)), current.get("leftover", Vector2i(-1, -1)))


func set_ranged_order(player: int, piece_id: int, target: Vector2i) -> Dictionary:
	var current := order_for_piece(piece_id)
	return set_unit_order(player, piece_id, current.get("path", []), target, current.get("leftover", Vector2i(-1, -1)))


func set_leftover_order(player: int, piece_id: int, target: Vector2i) -> Dictionary:
	var current := order_for_piece(piece_id)
	return set_unit_order(player, piece_id, current.get("path", []), current.get("ranged_target", Vector2i(-1, -1)), target)


func clear_unit_order(player: int, piece_id: int) -> void:
	if phase == PHASE_PLANNING and player not in ready_players and player in orders: orders[player].erase(piece_id)


func clear_player_orders(player: int) -> void:
	if phase == PHASE_PLANNING and player not in ready_players: orders[player] = {}


func _same_player_order_is_clear(player: int, piece_id: int, candidate: Dictionary) -> bool:
	var old_order: Dictionary = order_for_piece(piece_id)
	if player not in orders: orders[player] = {}
	orders[player][piece_id] = candidate
	var own_pieces: Array[Dictionary] = []
	for piece: Dictionary in pieces:
		if piece.alive and int(piece.player) == player: own_pieces.append(piece)
	var clear := true
	for impulse in range(1, 4):
		var occupied: Dictionary = {}
		for piece: Dictionary in own_pieces:
			var position := projected_order_position(int(piece.id), impulse)
			if position in occupied:
				var defender := piece_at(position)
				if defender.is_empty() or are_allied_players(player, int(defender.player)):
					clear = false
					break
			occupied[position] = piece.id
		if not clear: break
		for first_index in own_pieces.size():
			for second_index in range(first_index + 1, own_pieces.size()):
				var first: Dictionary = own_pieces[first_index]
				var second: Dictionary = own_pieces[second_index]
				var first_previous := projected_order_position(int(first.id), impulse - 1)
				var second_previous := projected_order_position(int(second.id), impulse - 1)
				var first_current := projected_order_position(int(first.id), impulse)
				var second_current := projected_order_position(int(second.id), impulse)
				if first_previous == second_current and second_previous == first_current and first_previous != first_current:
					clear = false
					break
			if not clear: break
	if clear:
		var leftover_occupied: Dictionary = {}
		for piece: Dictionary in own_pieces:
			var order := order_for_piece(int(piece.id))
			var position: Vector2i = order.get("leftover", projected_main_destination(int(piece.id)))
			if position.x < 0: position = projected_main_destination(int(piece.id))
			if position in leftover_occupied:
				var defender := piece_at(position)
				if defender.is_empty() or are_allied_players(player, int(defender.player)):
					clear = false
					break
			leftover_occupied[position] = piece.id
	if old_order.is_empty(): orders[player].erase(piece_id)
	else: orders[player][piece_id] = old_order
	return clear


func mark_player_ready(player: int) -> Dictionary:
	if phase != PHASE_PLANNING or player not in active_players:
		return {"ok": false, "message": "This player cannot become ready now."}
	if player not in ready_players: ready_players.append(player)
	return {"ok": true, "all_ready": all_players_ready()}


func all_players_ready() -> bool:
	for player in active_players:
		if player not in ready_players: return false
	return not active_players.is_empty()


func resolve_round() -> Array[Dictionary]:
	if phase != PHASE_PLANNING or game_over or not all_players_ready(): return []
	phase = PHASE_RESOLVING
	last_round_events.clear()
	_begin_round_state()
	_record_all_sightings()
	for impulse in range(1, 4):
		var proposals: Array[Dictionary] = []
		for piece: Dictionary in pieces:
			if not is_movable(piece) or bool(piece.main_done): continue
			var path: Array = order_for_piece(int(piece.id)).get("path", [])
			if path.size() >= impulse:
				proposals.append({"piece_id": int(piece.id), "from": piece.position, "to": path[impulse - 1], "is_attacker": true, "impulse": impulse})
		if not proposals.is_empty(): last_round_events.append_array(_resolve_movement_batch(proposals, "impulse_%d" % impulse))
		_record_all_sightings()
	last_round_events.append_array(_resolve_ranged_phase())
	_record_all_sightings()
	var leftover_proposals: Array[Dictionary] = []
	for piece: Dictionary in pieces:
		if not _eligible_for_leftover(piece): continue
		var target: Vector2i = order_for_piece(int(piece.id)).get("leftover", Vector2i(-1, -1))
		if target.x >= 0 and piece.position.distance_to(target) == 1.0:
			leftover_proposals.append({"piece_id": int(piece.id), "from": piece.position, "to": target, "is_attacker": true, "impulse": 4})
	if not leftover_proposals.is_empty(): last_round_events.append_array(_resolve_movement_batch(leftover_proposals, "leftover"))
	_record_all_sightings()
	_finish_round()
	return last_round_events.duplicate(true)


func _begin_round_state() -> void:
	for piece: Dictionary in pieces:
		if piece.alive:
			pieces[piece.id].round_status = STATUS_READY
			pieces[piece.id].movement_used = 0
			pieces[piece.id].melee_count = 0
			pieces[piece.id].participated_in_combat = false
			pieces[piece.id].main_done = false


func _resolve_movement_batch(proposals: Array[Dictionary], batch_name: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var proposal_by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		var id := int(proposal.piece_id)
		if id >= 0 and id < pieces.size() and pieces[id].alive and pieces[id].position == proposal.from:
			proposal_by_id[id] = proposal
			pieces[id].movement_used = int(pieces[id].movement_used) + 1
	var handled: Dictionary = {}
	var battles: Array[Dictionary] = []
	var allied_collisions: Array[Dictionary] = []
	var ids: Array = proposal_by_id.keys()
	for first_index in ids.size():
		var first_id: int = ids[first_index]
		if first_id in handled: continue
		var first: Dictionary = proposal_by_id[first_id]
		for second_index in range(first_index + 1, ids.size()):
			var second_id: int = ids[second_index]
			if second_id in handled: continue
			var second: Dictionary = proposal_by_id[second_id]
			if first.from == second.to and first.to == second.from:
				if are_allied_players(int(pieces[first_id].player), int(pieces[second_id].player)):
					allied_collisions.append({"ids": [first_id, second_id], "position": first.to, "crossing": true})
				else:
					battles.append({"participants": [first.duplicate(true), second.duplicate(true)], "position": first.to, "crossing": true})
				handled[first_id] = true
				handled[second_id] = true
				break
	var destination_groups: Dictionary = {}
	for id_value in ids:
		var id := int(id_value)
		if id in handled: continue
		var proposal: Dictionary = proposal_by_id[id]
		if proposal.to not in destination_groups: destination_groups[proposal.to] = []
		destination_groups[proposal.to].append(proposal)
	var ordinary_moves: Array[Dictionary] = []
	for destination in destination_groups:
		var arrivals: Array = destination_groups[destination]
		var participants: Array[Dictionary] = []
		for arrival: Dictionary in arrivals: participants.append(arrival.duplicate(true))
		var occupant := piece_at(destination)
		var occupant_leaves := not occupant.is_empty() and int(occupant.id) in proposal_by_id and int(occupant.id) not in handled
		if not occupant.is_empty() and not occupant_leaves:
			participants.append({"piece_id": int(occupant.id), "from": destination, "to": destination, "is_attacker": false, "impulse": arrivals[0].impulse})
		if participants.size() == 1:
			ordinary_moves.append(arrivals[0])
			continue
		var teams: Dictionary = {}
		for participant: Dictionary in participants: teams[_team_for_piece(int(participant.piece_id))] = true
		if teams.size() == 1:
			var collision_ids: Array[int] = []
			for participant: Dictionary in participants: collision_ids.append(int(participant.piece_id))
			allied_collisions.append({"ids": collision_ids, "position": destination, "crossing": false, "stationary_id": int(occupant.id) if not occupant.is_empty() and not occupant_leaves else EMPTY})
		else:
			battles.append({"participants": participants, "position": destination, "crossing": false})
		for participant: Dictionary in participants: handled[int(participant.piece_id)] = true
	for move: Dictionary in ordinary_moves: _clear_piece_square(int(move.piece_id))
	for battle: Dictionary in battles:
		for participant: Dictionary in battle.participants:
			if bool(participant.is_attacker): _clear_piece_square(int(participant.piece_id))
	for move: Dictionary in ordinary_moves:
		var id := int(move.piece_id)
		if not pieces[id].alive: continue
		if piece_at(move.to).is_empty():
			_place_piece(id, move.to, move.from)
			events.append(_movement_event(id, move.from, move.to, batch_name))
		else:
			_place_piece(id, move.from, move.from)
			_mark_bounced(id, false)
			events.append(_bounce_event([id], move.to, batch_name, "occupied_after_resolution"))
	for collision: Dictionary in allied_collisions:
		var collision_ids: Array[int] = []
		for id_value in collision.ids:
			var id := int(id_value)
			collision_ids.append(id)
			_mark_bounced(id, false)
		events.append(_bounce_event(collision_ids, collision.position, batch_name, "allied_collision"))
	var retreat_intents: Array[Dictionary] = []
	for battle: Dictionary in battles:
		var result := _resolve_battle(battle.participants, battle.position, bool(battle.crossing), batch_name)
		events.append(result.event)
		retreat_intents.append_array(result.retreats)
	if not retreat_intents.is_empty(): events.append_array(_resolve_retreats(retreat_intents, batch_name))
	return events


func _resolve_battle(participants: Array, contested: Vector2i, crossing: bool, batch_name: String) -> Dictionary:
	var scores: Dictionary = {}
	var raw_rolls: Dictionary = {}
	var participant_ids: Array[int] = []
	for participant: Dictionary in participants:
		var id := int(participant.piece_id)
		if id in participant_ids or not pieces[id].alive: continue
		participant_ids.append(id)
		var raw := _roll_d10()
		var score := mini(raw, int(pieces[id].strength))
		if bool(participant.is_attacker) and pieces[id].role == ROLE_CAVALRY: score += ROLE_BONUS
		if not bool(participant.is_attacker) and pieces[id].role == ROLE_INFANTRY: score += ROLE_BONUS
		scores[id] = score
		raw_rolls[id] = raw
		pieces[id].participated_in_combat = true
		pieces[id].melee_count = int(pieces[id].melee_count) + 1
	var highest := -1
	for score in scores.values(): highest = maxi(highest, int(score))
	var top_ids: Array[int] = []
	var top_teams: Dictionary = {}
	for id in participant_ids:
		if int(scores[id]) == highest:
			top_ids.append(id)
			top_teams[_team_for_piece(id)] = true
	var unique_winner_id := top_ids[0] if top_ids.size() == 1 else EMPTY
	var damage_by_id: Dictionary = {}
	for target_id in participant_ids:
		var opposing_score := -1
		var opposing_critical := false
		for source_id in participant_ids:
			if are_allied_players(int(pieces[target_id].player), int(pieces[source_id].player)): continue
			if int(scores[source_id]) > opposing_score:
				opposing_score = int(scores[source_id])
				opposing_critical = int(raw_rolls[source_id]) == 10
			elif int(scores[source_id]) == opposing_score and int(raw_rolls[source_id]) == 10:
				opposing_critical = true
		var effective_armor := int(pieces[target_id].armor) * (2 if target_id == unique_winner_id else 1)
		var damage := maxi(0, opposing_score - effective_armor) + (1 if opposing_critical else 0)
		damage_by_id[target_id] = damage
	for id in participant_ids:
		pieces[id].strength = maxi(0, int(pieces[id].strength) - int(damage_by_id[id]))
		if int(pieces[id].strength) <= 0: _remove_piece(id)
	if not crossing and is_inside(contested):
		var occupant := piece_at(contested)
		if not occupant.is_empty() and int(occupant.id) in participant_ids: board[contested.y][contested.x] = EMPTY
	var retreats: Array[Dictionary] = []
	var outcomes: Dictionary = {}
	if unique_winner_id != EMPTY:
		var winner_team := _team_for_piece(unique_winner_id)
		for id in participant_ids:
			if not pieces[id].alive:
				outcomes[id] = "destroyed"
			elif id == unique_winner_id:
				outcomes[id] = STATUS_WON
				pieces[id].round_status = STATUS_WON
				pieces[id].main_done = true
			elif _team_for_piece(id) == winner_team:
				outcomes[id] = STATUS_BOUNCED
				_mark_bounced(id, true)
				_place_bouncer(id, _participant_for(id, participants).from)
			else:
				outcomes[id] = STATUS_LOST
				_mark_lost(id)
				retreats.append(_retreat_intent(id, _participant_for(id, participants), participants, scores, crossing))
		if pieces[unique_winner_id].alive:
			var winner_participant := _participant_for(unique_winner_id, participants)
			_place_piece(unique_winner_id, winner_participant.to if crossing else contested, winner_participant.from)
	else:
		for id in participant_ids:
			if not pieces[id].alive:
				outcomes[id] = "destroyed"
			elif _team_for_piece(id) in top_teams:
				outcomes[id] = STATUS_BOUNCED
				_mark_bounced(id, true)
				_place_bouncer(id, _participant_for(id, participants).from)
			else:
				outcomes[id] = STATUS_LOST
				_mark_lost(id)
				retreats.append(_retreat_intent(id, _participant_for(id, participants), participants, scores, crossing))
	var event := {
		"ok": true, "action": "crossing_battle" if crossing else "melee", "batch": batch_name, "combat": true,
		"ranged": false, "crossing": crossing, "to": contested, "participants": participant_ids.duplicate(),
		"scores": scores.duplicate(true), "raw_rolls": raw_rolls.duplicate(true), "damage": damage_by_id.duplicate(true),
		"outcomes": outcomes.duplicate(true), "winner_id": unique_winner_id,
		"result": "win" if unique_winner_id != EMPTY else "bounce", "known_to": _battle_viewers_for_ids(participant_ids),
	}
	for id in participant_ids:
		for viewer in event.known_to: reveal_piece_to(id, viewer)
	battle_history.append(event.duplicate(true))
	last_move = {"from": participants[0].from, "to": contested, "visible_to": event.known_to.duplicate(), "action": event.action}
	return {"event": event, "retreats": retreats}


func _participant_for(piece_id: int, participants: Array) -> Dictionary:
	for participant: Dictionary in participants:
		if int(participant.piece_id) == piece_id: return participant
	return {}


func _retreat_intent(piece_id: int, participant: Dictionary, participants: Array, scores: Dictionary, crossing: bool) -> Dictionary:
	var target: Vector2i
	if bool(participant.is_attacker) and not crossing:
		target = participant.from
	else:
		var source := _highest_opposing_participant(piece_id, participants, scores)
		var direction := Vector2i(signi(participant.from.x - source.from.x), signi(participant.from.y - source.from.y))
		target = participant.from + direction
	return {"piece_id": piece_id, "from": participant.from, "to": target}


func _highest_opposing_participant(piece_id: int, participants: Array, scores: Dictionary) -> Dictionary:
	var selected: Dictionary = {}
	var selected_score := -1
	for participant: Dictionary in participants:
		var other_id := int(participant.piece_id)
		if are_allied_players(int(pieces[piece_id].player), int(pieces[other_id].player)): continue
		if int(scores[other_id]) > selected_score:
			selected = participant
			selected_score = int(scores[other_id])
	return selected


func _resolve_retreats(retreats: Array[Dictionary], batch_name: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var valid_by_target: Dictionary = {}
	for retreat: Dictionary in retreats:
		var id := int(retreat.piece_id)
		if not pieces[id].alive: continue
		var target: Vector2i = retreat.to
		if not is_inside(target) or is_blocked_terrain(target) or not piece_at(target).is_empty():
			_remove_piece(id)
			events.append({"ok": true, "action": "retreat", "batch": batch_name, "piece_id": id, "from": retreat.from, "to": target, "result": "retreat_destroyed", "combat": false})
		else:
			if target not in valid_by_target: valid_by_target[target] = []
			valid_by_target[target].append(retreat)
	for target in valid_by_target:
		var group: Array = valid_by_target[target]
		if group.size() == 1:
			var retreat: Dictionary = group[0]
			_place_piece(int(retreat.piece_id), target, retreat.from)
			events.append({"ok": true, "action": "retreat", "batch": batch_name, "piece_id": int(retreat.piece_id), "from": retreat.from, "to": target, "result": "retreated", "combat": false})
			continue
		var teams: Dictionary = {}
		for retreat: Dictionary in group: teams[_team_for_piece(int(retreat.piece_id))] = true
		if teams.size() == 1:
			var ids: Array[int] = []
			for retreat: Dictionary in group:
				ids.append(int(retreat.piece_id))
				_remove_piece(int(retreat.piece_id))
			events.append({"ok": true, "action": "retreat_collision", "batch": batch_name, "to": target, "participants": ids, "result": "congestion_destroyed", "combat": false})
		else:
			events.append(_resolve_retreat_battle(group, target, batch_name))
	return events


func _resolve_retreat_battle(group: Array, target: Vector2i, batch_name: String) -> Dictionary:
	var ids: Array[int] = []
	var scores: Dictionary = {}
	var raw_rolls: Dictionary = {}
	for retreat: Dictionary in group:
		var id := int(retreat.piece_id)
		ids.append(id)
		var raw := _roll_d10()
		raw_rolls[id] = raw
		scores[id] = mini(raw, int(pieces[id].strength))
		pieces[id].participated_in_combat = true
	var highest := -1
	for score in scores.values(): highest = maxi(highest, int(score))
	var top_ids: Array[int] = []
	for id in ids:
		if int(scores[id]) == highest: top_ids.append(id)
	var winner_id := top_ids[0] if top_ids.size() == 1 else EMPTY
	var damage: Dictionary = {}
	for target_id in ids:
		var opposing_score := -1
		var critical := false
		for source_id in ids:
			if are_allied_players(int(pieces[target_id].player), int(pieces[source_id].player)): continue
			if int(scores[source_id]) > opposing_score:
				opposing_score = int(scores[source_id])
				critical = int(raw_rolls[source_id]) == 10
			elif int(scores[source_id]) == opposing_score and int(raw_rolls[source_id]) == 10: critical = true
		var effective_armor := int(pieces[target_id].armor) * (2 if target_id == winner_id else 1)
		var amount := maxi(0, opposing_score - effective_armor) + (1 if critical else 0)
		damage[target_id] = amount
		pieces[target_id].strength = maxi(0, int(pieces[target_id].strength) - amount)
	for id in ids:
		if id != winner_id or int(pieces[id].strength) <= 0: _remove_piece(id)
	if winner_id != EMPTY and pieces[winner_id].alive: _place_piece(winner_id, target, pieces[winner_id].position)
	var event := {
		"ok": true, "action": "retreat_battle", "batch": batch_name, "combat": true, "retreat_battle": true,
		"to": target, "participants": ids, "scores": scores, "raw_rolls": raw_rolls, "damage": damage,
		"winner_id": winner_id, "result": "retreat_battle_winner" if winner_id != EMPTY and pieces[winner_id].alive else "retreat_battle_mutual_destruction",
		"known_to": _battle_viewers_for_ids(ids),
	}
	battle_history.append(event.duplicate(true))
	return event


func _resolve_ranged_phase() -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	for piece: Dictionary in pieces:
		if not _eligible_to_shoot(piece): continue
		var target_position: Vector2i = order_for_piece(int(piece.id)).get("ranged_target", Vector2i(-1, -1))
		if target_position.x < 0 or piece.position.distance_to(target_position) != 1.0: continue
		var target := piece_at(target_position)
		if target.is_empty() or are_allied_players(int(piece.player), int(target.player)) or target.type == FLAG: continue
		var resolution := calculate_ranged(piece, target)
		shots.append({"shooter_id": int(piece.id), "target_id": int(target.id), "from": piece.position, "to": target_position, "resolution": resolution})
		pieces[piece.id].movement_used = int(pieces[piece.id].movement_used) + 1
		pieces[piece.id].participated_in_combat = true
	var total_damage: Dictionary = {}
	for shot: Dictionary in shots:
		var target_id := int(shot.target_id)
		total_damage[target_id] = int(total_damage.get(target_id, 0)) + int(shot.resolution.defender_damage)
	for target_id_value in total_damage:
		var target_id := int(target_id_value)
		if not pieces[target_id].alive: continue
		pieces[target_id].strength = maxi(0, int(pieces[target_id].strength) - int(total_damage[target_id]))
		if int(pieces[target_id].strength) <= 0: _remove_piece(target_id)
	var events: Array[Dictionary] = []
	for shot: Dictionary in shots:
		var shooter_id := int(shot.shooter_id)
		var target_id := int(shot.target_id)
		var event := {
			"ok": true, "action": "ranged", "batch": "ranged", "combat": true, "ranged": true,
			"from": shot.from, "to": shot.to, "shooter_id": shooter_id, "target_id": target_id,
			"attacker_score": int(shot.resolution.attacker_score), "attacker_raw_roll": int(shot.resolution.attacker_raw_roll),
			"defender_damage": int(shot.resolution.defender_damage), "result": "ranged_destroyed" if not pieces[target_id].alive else "ranged_hit",
			"known_to": _battle_viewers_for_ids([shooter_id, target_id]),
		}
		battle_history.append(event.duplicate(true))
		events.append(event)
	return events


func _eligible_to_shoot(piece: Dictionary) -> bool:
	return is_movable(piece) and piece.role == ROLE_ARCHER and String(piece.round_status) in [STATUS_READY, STATUS_WON] and int(piece.movement_used) < movement_limit_for(piece) and order_for_piece(int(piece.id)).get("ranged_target", Vector2i(-1, -1)).x >= 0


func _eligible_for_leftover(piece: Dictionary) -> bool:
	return is_movable(piece) and String(piece.round_status) in [STATUS_READY, STATUS_WON] and int(piece.movement_used) < movement_limit_for(piece) and int(piece.melee_count) < 2


func _movement_event(piece_id: int, from: Vector2i, to: Vector2i, batch_name: String) -> Dictionary:
	var viewers := _move_viewers(int(pieces[piece_id].player), from, to)
	last_move = {"from": from, "to": to, "visible_to": viewers.duplicate(), "action": "move"}
	return {"ok": true, "action": "move", "batch": batch_name, "combat": false, "piece_id": piece_id, "from": from, "to": to, "result": "move", "visible_to": viewers}


func _bounce_event(ids: Array[int], position: Vector2i, batch_name: String, reason: String) -> Dictionary:
	return {"ok": true, "action": "bounce", "batch": batch_name, "combat": false, "participants": ids, "to": position, "result": "bounce", "reason": reason}


func _mark_bounced(piece_id: int, combat: bool) -> void:
	pieces[piece_id].round_status = STATUS_BOUNCED
	pieces[piece_id].main_done = true
	if combat: pieces[piece_id].participated_in_combat = true


func _mark_lost(piece_id: int) -> void:
	pieces[piece_id].round_status = STATUS_LOST
	pieces[piece_id].main_done = true
	pieces[piece_id].participated_in_combat = true


func _place_bouncer(piece_id: int, origin: Vector2i) -> void:
	if not pieces[piece_id].alive: return
	if piece_at(origin).is_empty(): _place_piece(piece_id, origin, origin)
	elif int(piece_at(origin).id) != piece_id: _remove_piece(piece_id)


func _clear_piece_square(piece_id: int) -> void:
	if piece_id < 0 or piece_id >= pieces.size(): return
	var position: Vector2i = pieces[piece_id].position
	if is_inside(position) and board[position.y][position.x] == piece_id: board[position.y][position.x] = EMPTY


func _place_piece(piece_id: int, position: Vector2i, from: Vector2i) -> void:
	if not pieces[piece_id].alive or not is_inside(position): return
	board[position.y][position.x] = piece_id
	_record_piece_move(piece_id, from, position)


func _team_for_piece(piece_id: int) -> int:
	var player := int(pieces[piece_id].player)
	return int(player_teams.get(player, player))


func calculate_melee(attacker: Dictionary, defender: Dictionary, attacker_raw_roll: int = -1, defender_raw_roll: int = -1, both_attacking: bool = false) -> Dictionary:
	var attacker_raw := _roll_d10() if attacker_raw_roll < 1 else clampi(attacker_raw_roll, 1, 10)
	var defender_raw := _roll_d10() if defender_raw_roll < 1 else clampi(defender_raw_roll, 1, 10)
	var attacker_score := mini(attacker_raw, int(attacker.strength))
	var defender_score := mini(defender_raw, int(defender.strength))
	if attacker.role == ROLE_CAVALRY: attacker_score += ROLE_BONUS
	if both_attacking:
		if defender.role == ROLE_CAVALRY: defender_score += ROLE_BONUS
	elif defender.role == ROLE_INFANTRY: defender_score += ROLE_BONUS
	var winner_name := ""
	if attacker_score > defender_score: winner_name = "attacker"
	elif defender_score > attacker_score: winner_name = "defender"
	var attacker_armor := int(attacker.armor) * (2 if winner_name == "attacker" else 1)
	var defender_armor := int(defender.armor) * (2 if winner_name == "defender" else 1)
	return {
		"attacker_raw_roll": attacker_raw, "defender_raw_roll": defender_raw,
		"attacker_score": attacker_score, "defender_score": defender_score,
		"attacker_wins": winner_name == "attacker", "defender_wins": winner_name == "defender", "tie": winner_name.is_empty(),
		"score_winner": winner_name,
		"attacker_damage": maxi(0, defender_score - attacker_armor) + (1 if defender_raw == 10 else 0),
		"defender_damage": maxi(0, attacker_score - defender_armor) + (1 if attacker_raw == 10 else 0),
		"critical_attacker": attacker_raw == 10, "critical_defender": defender_raw == 10,
	}


func calculate_ranged(attacker: Dictionary, defender: Dictionary, raw_roll: int = -1) -> Dictionary:
	var attacker_raw := _roll_d10() if raw_roll < 1 else clampi(raw_roll, 1, 10)
	var attacker_score := mini(attacker_raw, int(attacker.strength))
	return {
		"attacker_raw_roll": attacker_raw, "defender_raw_roll": 0, "attacker_score": attacker_score, "defender_score": 0,
		"attacker_damage": 0, "defender_damage": maxi(0, attacker_score - int(defender.armor)) + (1 if attacker_raw == 10 else 0),
		"critical_attacker": attacker_raw == 10, "critical_defender": false, "score_winner": "attacker",
	}


func expected_battle_score(piece: Dictionary, is_attacker: bool) -> float:
	if piece.is_empty() or piece.type == FLAG: return 0.0
	var expected := 0.0
	for raw_roll in range(1, 11): expected += float(mini(raw_roll, int(piece.strength))) / 10.0
	if is_attacker and piece.role == ROLE_CAVALRY: expected += ROLE_BONUS
	if not is_attacker and piece.role == ROLE_INFANTRY: expected += ROLE_BONUS
	return expected


func melee_advantage(attacker: Dictionary, defender: Dictionary) -> float:
	return 100.0 if defender.type == FLAG else expected_battle_score(attacker, true) - expected_battle_score(defender, false)


func expected_ranged_damage(attacker: Dictionary, defender: Dictionary) -> float:
	var total := 0.0
	for raw_roll in range(1, 11):
		var score := mini(raw_roll, int(attacker.strength))
		total += float(maxi(0, score - int(defender.armor)) + (1 if raw_roll == 10 else 0)) / 10.0
	return total


func set_forced_rolls(raw_rolls: Array[int]) -> void:
	_forced_rolls.assign(raw_rolls)


func _roll_d10() -> int:
	return _forced_rolls.pop_front() if not _forced_rolls.is_empty() else _rng.randi_range(1, 10)


func withdraw_player(player: int) -> Dictionary:
	if phase != PHASE_PLANNING or game_over or player not in active_players:
		return {"ok": false, "message": "Withdrawal is only available during planning."}
	withdrawing_player = player
	game_over = true
	phase = PHASE_GAME_OVER
	end_reason = "withdrawal"
	var opposing_players: Array[int] = []
	for candidate in active_players:
		if not are_allied_players(player, candidate): opposing_players.append(candidate)
	if scenario == SCENARIO_BRIDGE: winner = bridge_defender if player == bridge_attacker else bridge_attacker
	elif opposing_players.size() == 1: winner = opposing_players[0]
	else: winner = DRAW
	winning_team = int(player_teams.get(winner, winner)) if winner != DRAW else DRAW
	return {"ok": true, "action": "withdraw", "player": player, "winner": winner, "end_reason": end_reason, "surviving_strength": total_strength(player)}


func _finish_round() -> void:
	ply_count += 1
	turn_number = round_number
	_check_flag_eliminations()
	if not game_over and scenario == SCENARIO_BRIDGE:
		if bridge_strength_across() >= bridge_strength_target: _finish_game(bridge_attacker, "bridge_breakthrough")
		elif round_number >= bridge_turn_limit: _finish_game(bridge_defender, "turn_limit")
		elif total_strength(bridge_attacker) <= 0: _finish_game(bridge_defender, "attacker_destroyed")
		elif total_strength(bridge_defender) <= 0: _finish_game(bridge_attacker, "defender_destroyed")
	if not game_over and scenario == SCENARIO_FOUR_PLAYER: _finish_if_one_team_remains()
	if game_over:
		phase = PHASE_GAME_OVER
		return
	round_number += 1
	turn_number = round_number
	orders.clear()
	ready_players.clear()
	phase = PHASE_PLANNING


func bridge_strength_across() -> int:
	var total := 0
	for piece: Dictionary in pieces:
		if piece.alive and int(piece.player) == bridge_attacker and piece.type != FLAG and piece.position.y < BRIDGE_RIVER_Y: total += int(piece.strength)
	return total


func _check_flag_eliminations() -> void:
	if scenario != SCENARIO_FOUR_PLAYER: return
	var to_eliminate: Array[int] = []
	for player in active_players:
		if count_alive_type(player, FLAG) == 0: to_eliminate.append(player)
	for player in to_eliminate: _eliminate_player(player, "flag_captured")


func _eliminate_player(player: int, reason: String) -> void:
	if player not in active_players: return
	for piece: Dictionary in pieces:
		if piece.alive and int(piece.player) == player: _remove_piece(int(piece.id))
	active_players.erase(player)
	if player not in eliminated_players: eliminated_players.append(player)
	last_eliminated_player = player
	last_elimination_reason = reason


func _finish_if_one_team_remains() -> bool:
	var teams: Dictionary = {}
	for player in active_players: teams[int(player_teams.get(player, player))] = true
	if teams.size() > 1: return false
	_finish_game(DRAW if active_players.is_empty() else active_players[0], "mutual_destruction" if active_players.is_empty() else "last_team_standing")
	return true


func _finish_game(winning_player: int, reason: String) -> void:
	game_over = true
	winner = winning_player
	winning_team = int(player_teams.get(winning_player, winning_player)) if winning_player != DRAW else DRAW
	end_reason = reason
	phase = PHASE_GAME_OVER


func _remove_piece(id: int) -> void:
	if id < 0 or id >= pieces.size(): return
	_clear_piece_square(id)
	pieces[id].alive = false
	pieces[id].strength = 0
	pieces[id].position = Vector2i(-1, -1)
	_visibility_dirty = true


func _record_piece_move(id: int, from: Vector2i, to: Vector2i) -> void:
	pieces[id].previous_position = from
	pieces[id].position = to
	if from != to:
		pieces[id].move_count = int(pieces[id].move_count) + 1
		var history: Array = pieces[id].recent_positions
		history.append(to)
		while history.size() > 8: history.pop_front()
		pieces[id].recent_positions = history
	_visibility_dirty = true


func is_position_visible_to(position: Vector2i, player: int) -> bool:
	if not is_inside(position): return false
	_ensure_visibility_cache()
	return position in _visible_cells_by_player.get(player, {})


func _ensure_visibility_cache() -> void:
	if not _visibility_dirty and _cached_vision_range == vision_range: return
	_visible_cells_by_player.clear()
	for player in PLAYER_ORDER: _visible_cells_by_player[player] = {}
	for piece: Dictionary in pieces:
		if not piece.alive: continue
		var visible_cells: Dictionary = _visible_cells_by_player[int(piece.player)]
		for y_offset in range(-vision_range, vision_range + 1):
			var horizontal_reach := vision_range - absi(y_offset)
			for x_offset in range(-horizontal_reach, horizontal_reach + 1):
				var visible_position: Vector2i = piece.position + Vector2i(x_offset, y_offset)
				if is_inside(visible_position): visible_cells[visible_position] = true
	_visibility_dirty = false
	_cached_vision_range = vision_range


func _record_all_sightings() -> void:
	_visibility_dirty = true
	_ensure_visibility_cache()
	for piece: Dictionary in pieces:
		if not piece.alive: continue
		for player in active_players:
			if player != int(piece.player) and is_position_visible_to(piece.position, player):
				var seen_by: Array = pieces[piece.id].seen_by
				if player not in seen_by: seen_by.append(player)
				pieces[piece.id].seen_by = seen_by


func is_piece_visible_to(piece: Dictionary, player: int) -> bool:
	if piece.is_empty() or not bool(piece.get("alive", false)): return false
	return true if int(piece.player) == player else is_position_visible_to(piece.position, player)


func observed_piece_at(position: Vector2i, player: int) -> Dictionary:
	var piece := piece_at(position)
	return piece if is_piece_visible_to(piece, player) else {}


func has_seen_piece(piece: Dictionary, player: int) -> bool:
	return player == int(piece.player) or player in piece.get("seen_by", [])


func reveal_piece_to(piece_id: int, player: int) -> void:
	if piece_id < 0 or piece_id >= pieces.size(): return
	var viewers: Array = pieces[piece_id].revealed_to
	if player not in viewers: viewers.append(player)
	pieces[piece_id].revealed_to = viewers


func reveal_piece_to_all(piece_id: int) -> void:
	for player in PLAYER_ORDER: reveal_piece_to(piece_id, player)


func is_piece_revealed_to(piece: Dictionary, player: int) -> bool:
	return not piece.is_empty() and (int(piece.player) == player or (player in piece.get("revealed_to", []) and is_piece_visible_to(piece, player)))


func is_piece_revealed_to_any_opponent(piece: Dictionary, owner: int) -> bool:
	for viewer in piece.get("revealed_to", []):
		if int(viewer) != owner: return true
	return false


func _move_viewers(moving_player: int, from: Vector2i, to: Vector2i) -> Array[int]:
	var viewers: Array[int] = []
	for player in active_players:
		if player == moving_player or is_position_visible_to(from, player) or is_position_visible_to(to, player): viewers.append(player)
	return viewers


func _battle_viewers_for_ids(ids: Array[int]) -> Array[int]:
	if not private_battle_results: return active_players.duplicate()
	var viewers: Array[int] = []
	for id in ids:
		if id >= 0 and id < pieces.size() and int(pieces[id].player) not in viewers: viewers.append(int(pieces[id].player))
	return viewers


func battle_events_for(player: int) -> Array[Dictionary]:
	var known_events: Array[Dictionary] = []
	for event in battle_history:
		if player in event.get("known_to", []): known_events.append(event.duplicate(true))
	return known_events


func player_name(player: int) -> String:
	match player:
		BLUE: return "Blue"
		RED: return "Red"
		GREEN: return "Green"
		YELLOW: return "Yellow"
	return "Draw"


func piece_display_code(piece: Dictionary) -> String:
	if piece.type == FLAG: return FLAG
	return "%s%s%d" % [String(piece.weight).substr(0, 1).to_upper(), String(piece.role).substr(0, 1).to_upper(), int(piece.strength)]


func piece_description(piece: Dictionary) -> String:
	if piece.type == FLAG: return "Flag — immobile objective"
	return "%s — Strength %d/%d · Move %d · Armor %d" % [PIECE_NAMES[piece.type], int(piece.strength), int(piece.max_strength), movement_limit_for(piece), int(piece.armor)]


func get_material_score(player: int) -> float:
	return float(total_strength(player))


func total_strength(player: int) -> int:
	var total := 0
	for piece: Dictionary in pieces:
		if piece.alive and int(piece.player) == player and piece.type != FLAG: total += int(piece.strength)
	return total


func count_alive(player: int) -> int:
	var count := 0
	for piece: Dictionary in pieces:
		if piece.alive and int(piece.player) == player: count += 1
	return count


func count_alive_type(player: int, type: String) -> int:
	var count := 0
	for piece: Dictionary in pieces:
		if piece.alive and int(piece.player) == player and piece.type == type: count += 1
	return count


func find_alive_piece(player: int, type: String) -> Dictionary:
	for piece: Dictionary in pieces:
		if piece.alive and int(piece.player) == player and piece.type == type: return piece
	return {}


# Compatibility helpers: WEGO exposes one-square planning options rather than
# mutating the board as soon as a move is selected.
func get_moves_for(from: Vector2i) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	var piece := piece_at(from)
	if not is_movable(piece) or phase != PHASE_PLANNING: return moves
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var destination: Vector2i = from + direction
		if is_inside(destination) and not is_blocked_terrain(destination):
			moves.append({"from": from, "to": destination, "piece_id": int(piece.id), "player": int(piece.player), "action": "order_step", "cost": 1})
	return moves


func get_legal_moves(player: int = current_player) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for piece: Dictionary in pieces:
		if piece.alive and int(piece.player) == player: moves.append_array(get_moves_for(piece.position))
	return moves


func advancement_delta(_player: int, from: Vector2i, to: Vector2i) -> float:
	var center := Vector2(float(BOARD_SIZE - 1) * 0.5, float(BOARD_SIZE - 1) * 0.5)
	return Vector2(from).distance_to(center) - Vector2(to).distance_to(center)


func center_lane_distance(player: int, position: Vector2i) -> float:
	var center := float(BOARD_SIZE - 1) * 0.5
	return absf(float(position.x) - center) if player in [RED, BLUE] else absf(float(position.y) - center)


func home_edge_distance(player: int, position: Vector2i) -> int:
	match player:
		RED: return position.y
		GREEN: return BOARD_SIZE - 1 - position.x
		BLUE: return BOARD_SIZE - 1 - position.y
		YELLOW: return position.x
	return BOARD_SIZE
