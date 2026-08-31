class_name StrategoGame
extends RefCounted

const BOARD_SIZE := 20
const DEFAULT_VISION_RANGE := 4

## Board topology. Every adjacency and distance question in the engine goes
## through these four functions, so a different grid (hex, or square with
## diagonals) only needs them and DIRECTIONS rewritten.
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
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

const PHASE_DEPLOYMENT := "deployment"
const PHASE_PLANNING := "planning"
const PHASE_LEFTOVER_PLANNING := "leftover_planning"
const PHASE_RESOLVING := "resolving"
const PHASE_GAME_OVER := "game_over"
const SCENARIO_FOUR_PLAYER := "four_player"
const SCENARIO_CROSSROADS := "crossroads"
const SCENARIO_BRIDGE := "bridge"
const OBJECTIVE_HOLD_SQUARE := "hold_square"
const OBJECTIVE_ELIMINATE := "eliminate"
const SCENARIO_SKIRMISH := "skirmish"
const OBJECTIVE_REACH_AREA := "reach_area"
const OBJECTIVE_SURVIVE := "survive"
const SCENARIO_MEETING := "meeting"
const DEFAULT_HOLD_ROUNDS := 3
## The deploy phase's zone: how many squares deep from a player's own board
## edge they may place into, and how far the zone runs sideways from their
## edge's centreline. Chosen so the four corner zones never touch each other
## at this depth (halfwidth 6 would make adjacent zones share a cell at the
## board's quarter points).
const DEPLOYMENT_ZONE_DEPTH := 4
const DEPLOYMENT_LATERAL_HALFWIDTH := 5
## A hand-tuned formation for a 4-deep corner zone, the same philosophy as
## MEETING_DEPLOYMENT but built from the four-player roster (PIECE_COUNTS: no
## cavalry heavier or lighter than medium) rather than Meeting's, and too
## cramped a space to derive by transforming it anyway: the heavy line sits
## innermost (least travel for the slowest formations), mediums behind them,
## lights on the flanks at the shallowest rank (most travel, covered fastest),
## and the flag tucked at the literal edge. Entries are [type, lateral offset
## from the edge's own centreline, rank inward from the edge; rank 0 is the
## literal edge].
const CORNER_DEPLOYMENT := [
	[HEAVY_INFANTRY, -2, 3], [HEAVY_ARCHER, -1, 3], [HEAVY_ARCHER, 1, 3], [HEAVY_INFANTRY, 2, 3],
	[MEDIUM_INFANTRY, -4, 2], [MEDIUM_ARCHER, -2, 2], [MEDIUM_CAVALRY, 0, 2], [MEDIUM_ARCHER, 2, 2], [MEDIUM_INFANTRY, 4, 2],
	[LIGHT_INFANTRY, -3, 1], [LIGHT_ARCHER, 0, 1], [LIGHT_INFANTRY, 3, 1],
	[FLAG, 0, 0],
]
## Rows between the objective and each army's leading rank.
const MEETING_FRONT_DISTANCE := 7
const TERRAIN_OPEN := ""
const TERRAIN_LAKE := "lake"
const TERRAIN_WATER := "water"
const TERRAIN_BRIDGE := "bridge"
const SHOT_SHORT := "short"
const SHOT_LONG := "long"
const AIM_COST := 1
const STATUS_READY := "ready"
const STATUS_WON := "won"
const STATUS_LOST := "lost"
const STATUS_BOUNCED := "bounced"

const BRIDGE_RIVER_Y := 9
const BRIDGE_COLUMNS := [8, 9, 10, 11]
const BRIDGE_STRENGTH_TARGET := 20
const DEFAULT_BRIDGE_TURN_LIMIT := 20
const REPLAY_FORMAT := "wego-formations-replay"
const REPLAY_VERSION := 3

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
## Symmetric roster for meeting engagements: both sides field the same twelve so
## a result reflects play and unit design rather than an army-list advantage.
const MEETING_ROSTER := [
	HEAVY_INFANTRY, HEAVY_INFANTRY, MEDIUM_INFANTRY, MEDIUM_INFANTRY, LIGHT_INFANTRY, LIGHT_INFANTRY,
	HEAVY_ARCHER, MEDIUM_ARCHER, LIGHT_ARCHER, HEAVY_CAVALRY, MEDIUM_CAVALRY, LIGHT_CAVALRY,
]

## A battle line rather than a shuffled row: heavy foot holds the centre with the
## archer shooting over it, mediums form the second line, and the light troops
## screen the wings.
##
## This is also what fixes the arrival problem. Slow formations take the short
## central path while fast ones travel the long way round the flanks, so the two
## converge instead of the Heavies turning up rounds after the fight is decided.
## Entries are [type, column, rank], rank 0 being the line nearest the enemy.
const MEETING_DEPLOYMENT := [
	[HEAVY_INFANTRY, 9, 0], [HEAVY_ARCHER, 10, 0], [HEAVY_INFANTRY, 11, 0], [HEAVY_CAVALRY, 12, 0],
	[MEDIUM_INFANTRY, 8, 1], [MEDIUM_CAVALRY, 9, 1], [MEDIUM_ARCHER, 11, 1], [MEDIUM_INFANTRY, 12, 1],
	[LIGHT_CAVALRY, 3, 2], [LIGHT_INFANTRY, 4, 2], [LIGHT_INFANTRY, 16, 2], [LIGHT_ARCHER, 17, 2],
]
const LAKES := [
	Vector2i(7, 7), Vector2i(8, 7), Vector2i(11, 7), Vector2i(12, 7),
	Vector2i(7, 8), Vector2i(8, 8), Vector2i(11, 8), Vector2i(12, 8),
	Vector2i(7, 11), Vector2i(8, 11), Vector2i(11, 11), Vector2i(12, 11),
	Vector2i(7, 12), Vector2i(8, 12), Vector2i(11, 12), Vector2i(12, 12),
]

var board: Array = []
var terrain: Dictionary = {}
var objectives: Array[Dictionary] = []
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
## Off by default, so existing games and replays are unaffected. When on,
## Cavalry ignores the "movement left in the bank" leftover-eligibility check
## - a Heavy Cavalry formation that already spent its one point of main
## movement can still take the leftover move, rather than being permanently
## excluded from it the moment it moves at all.
var cavalry_always_leftover := false
var vision_range := DEFAULT_VISION_RANGE
var bridge_attacker := BLUE
var bridge_defender := RED
var bridge_turn_limit := DEFAULT_BRIDGE_TURN_LIMIT
var bridge_strength_target := BRIDGE_STRENGTH_TARGET
var _meeting_hold_rounds := DEFAULT_HOLD_ROUNDS
var _skirmish_turn_limit := 40
var _skirmish_separation := 3
var _meeting_turn_limit := DEFAULT_BRIDGE_TURN_LIMIT
var setup_seed := 0
var replay_rounds: Array[Dictionary] = []
## Where every piece actually ended up once deployment locked in, piece id to
## cell. The seed alone reproduces the recommended formation, not whatever a
## player dragged it to, so replay fidelity needs this recorded separately.
var deployment_placements: Dictionary = {}

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
var _roll_history: Array[int] = []
var _active_replay_round: Dictionary = {}


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
	terrain.clear()
	objectives.clear()
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
	cavalry_always_leftover = false
	vision_range = DEFAULT_VISION_RANGE
	bridge_attacker = BLUE
	bridge_defender = RED
	bridge_turn_limit = DEFAULT_BRIDGE_TURN_LIMIT
	bridge_strength_target = BRIDGE_STRENGTH_TARGET
	_meeting_hold_rounds = DEFAULT_HOLD_ROUNDS
	_meeting_turn_limit = DEFAULT_BRIDGE_TURN_LIMIT
	_skirmish_turn_limit = 40
	_skirmish_separation = 3
	setup_seed = 0
	replay_rounds.clear()
	deployment_placements.clear()
	current_player = BLUE
	ply_count = 0
	quiet_plies = 0
	_forced_rolls.clear()
	_roll_history.clear()
	_active_replay_round.clear()
	_visible_cells_by_player.clear()
	_visibility_dirty = true
	_cached_vision_range = -1


func setup_random(seed_value: int = 0, player_count: int = 4, use_private_battle_results: bool = true, _unused_legacy_range: int = 0) -> void:
	setup_empty()
	scenario = SCENARIO_FOUR_PLAYER
	apply_lake_terrain()
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
	apply_river_terrain(BRIDGE_RIVER_Y, BRIDGE_COLUMNS)
	player_teams[attacker] = attacker
	player_teams[defender] = defender
	_seed_rng(seed_value)
	_place_roster(attacker, BRIDGE_ATTACKER_ROSTER, _bridge_attacker_deployment(), _rng)
	_place_roster(defender, BRIDGE_DEFENDER_ROSTER, _bridge_defender_deployment(), _rng)
	# Breakthrough is declared first so it beats the turn limit on the last round.
	add_reach_area_objective(attacker, Rect2i(0, 0, BOARD_SIZE, BRIDGE_RIVER_Y), bridge_strength_target, "bridge_breakthrough")
	add_survive_objective(defender, bridge_turn_limit, "turn_limit")
	active_players.assign([defender, attacker])
	_sort_active_players()
	current_player = attacker
	_record_all_sightings()


## Meeting engagement: both armies deploy on their own back rank with identical
## rosters, and the win goes to whoever holds the centre square alone at the end
## of `hold_rounds` consecutive rounds. Neither side starts anywhere near it, so
## unlike the bridge crossing, arriving first is actually possible.
func setup_meeting(seed_value: int = 0, first: int = BLUE, second: int = RED, hold_rounds: int = DEFAULT_HOLD_ROUNDS, turn_limit: int = DEFAULT_BRIDGE_TURN_LIMIT, use_private_battle_results: bool = true) -> void:
	setup_empty()
	scenario = SCENARIO_MEETING
	configured_player_count = 2
	private_battle_results = use_private_battle_results
	apply_lake_terrain()
	player_teams[first] = first
	player_teams[second] = second
	_seed_rng(seed_value)
	_meeting_hold_rounds = maxi(1, hold_rounds)
	_meeting_turn_limit = maxi(1, turn_limit)
	var objective := Vector2i(BOARD_SIZE / 2, BOARD_SIZE / 2)
	set_terrain(objective, TERRAIN_OPEN)
	# The deployment rows are placed symmetrically about the objective rather
	# than on rows 0 and BOARD_SIZE-1. On an even board the centre square is not
	# equidistant from the two back ranks, and that single row of advantage is
	# worth roughly a 65/35 win rate to whichever side gets it.
	var reach := MEETING_FRONT_DISTANCE
	_place_battle_line(first, objective.y + reach, 1)
	_place_battle_line(second, objective.y - reach, -1)
	add_hold_square_objective(objective, hold_rounds, turn_limit)
	active_players.assign([second, first])
	_sort_active_players()
	current_player = first
	_record_all_sightings()


## Skirmish: a deliberately dull control scenario. Bare board, no terrain, no
## positional objective, two facing lines `separation` rows apart, and the only
## way to win is to destroy the other army.
##
## Separation is the important dial. At 2 or 3 every formation is in contact
## immediately regardless of Weight, so the result reflects combat maths alone;
## widen it and travel time re-enters, which is the variable the bridge and
## meeting scenarios are dominated by. Rosters are parameters so a run can test
## one matchup at a time rather than a whole army list.
func setup_skirmish(seed_value: int = 0, blue_roster: Array = MEETING_ROSTER, red_roster: Array = MEETING_ROSTER, separation: int = 3, turn_limit: int = 40, use_private_battle_results: bool = true) -> void:
	setup_empty()
	scenario = SCENARIO_SKIRMISH
	configured_player_count = 2
	private_battle_results = use_private_battle_results
	_skirmish_turn_limit = maxi(1, turn_limit)
	_skirmish_separation = clampi(separation, 1, BOARD_SIZE - 2)
	player_teams[BLUE] = BLUE
	player_teams[RED] = RED
	_seed_rng(seed_value)
	var middle := BOARD_SIZE / 2
	var blue_row := clampi(middle + (_skirmish_separation + 1) / 2, 0, BOARD_SIZE - 1)
	var red_row := clampi(blue_row - _skirmish_separation, 0, BOARD_SIZE - 1)
	_place_roster(BLUE, blue_roster, _back_rank_deployment(blue_row), _rng)
	_place_roster(RED, red_roster, _back_rank_deployment(red_row), _rng)
	add_eliminate_objective(_skirmish_turn_limit)
	active_players.assign([RED, BLUE])
	_sort_active_players()
	current_player = BLUE
	_record_all_sightings()


## Maps a corner formation's (lateral offset, rank-from-edge) onto an actual
## board cell for whichever edge `player` deploys along. Lateral runs along the
## edge from its own centreline; rank runs inward, 0 at the literal edge.
func _edge_cell(player: int, lateral: int, rank: int) -> Vector2i:
	var mid := BOARD_SIZE / 2
	var depth := rank
	match player:
		RED: return Vector2i(mid + lateral, depth)
		BLUE: return Vector2i(mid + lateral, BOARD_SIZE - 1 - depth)
		GREEN: return Vector2i(BOARD_SIZE - 1 - depth, mid + lateral)
		YELLOW: return Vector2i(depth, mid + lateral)
	return Vector2i(-1, -1)


## Every cell a player may deploy into: their own corner's zone, `DEPLOYMENT_
## ZONE_DEPTH` squares deep and `2 * DEPLOYMENT_LATERAL_HALFWIDTH + 1` wide,
## clear of the other three corners' zones by construction. Also doubles as
## that player's fog of war during the deploy phase (see is_position_visible_
## to) — nobody can see past their own zone to scout an opponent's opening
## formation, and if a future scenario hides terrain, this is the boundary a
## player would be shown it inside.
func deployment_zone_cells(player: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for lateral in range(-DEPLOYMENT_LATERAL_HALFWIDTH, DEPLOYMENT_LATERAL_HALFWIDTH + 1):
		for rank in DEPLOYMENT_ZONE_DEPTH:
			var cell := _edge_cell(player, lateral, rank)
			if is_inside(cell) and not is_blocked_terrain(cell): cells.append(cell)
	return cells


## The realistic default formation, as [type, cell] pairs actually placed on
## the board. A player who deploys nothing gets exactly this; CORNER_
## DEPLOYMENT's own comment explains the shape.
func recommended_deployment(player: int) -> Array:
	var placements: Array = []
	for entry: Array in CORNER_DEPLOYMENT:
		placements.append([String(entry[0]), _edge_cell(player, int(entry[1]), int(entry[2]))])
	return placements


## Crossroads: a 2v2 team battle in the four-lake clearing. Same corner map
## the four-player melee already uses, but Red+Green and Blue+Yellow are
## allied on adjacent corners rather than left to fight alone. That pairing is
## point-symmetric: rotate the board 180 degrees and Team Red becomes Team
## Blue exactly, so it is as fair as Meeting's centred deployment without
## needing a bespoke check for it.
##
## The win condition is the same hold_square primitive Meeting uses. Nothing
## about it is 2-player-specific: _check_objectives already loops every active
## player and scores by are_allied_players, so either teammate holding the
## centre builds the team's streak for free.
##
## Every army starts already placed at its recommended formation, then the
## game sits in PHASE_DEPLOYMENT so a player can override any of it before
## play begins — see redeploy_piece.
func setup_crossroads(seed_value: int = 0, hold_rounds: int = DEFAULT_HOLD_ROUNDS, turn_limit: int = 30, use_private_battle_results: bool = true) -> void:
	setup_empty()
	scenario = SCENARIO_CROSSROADS
	configured_player_count = 4
	private_battle_results = use_private_battle_results
	apply_lake_terrain()
	_seed_rng(seed_value)
	player_teams[RED] = RED
	player_teams[GREEN] = RED
	player_teams[BLUE] = BLUE
	player_teams[YELLOW] = BLUE
	for player in players_for_count(4):
		for entry in recommended_deployment(player):
			add_piece(String(entry[0]), player, entry[1])
	active_players.assign(players_for_count(4))
	_sort_active_players()
	current_player = BLUE
	add_hold_square_objective(Vector2i(BOARD_SIZE / 2, BOARD_SIZE / 2), hold_rounds, turn_limit)
	phase = PHASE_DEPLOYMENT
	# Sightings are recorded once real play starts, not here: every corner's
	# formation already exists at this point, and each player's own zone-scoped
	# fog (not the ordinary piece-radius vision) is what should govern what they
	# can see of it until deployment resolves.
	_visibility_dirty = true


## Places one army in its battle line. `front_row` is the rank nearest the
## objective and `step` points back toward that army's own edge.
func _place_battle_line(player: int, front_row: int, step: int) -> void:
	for entry in MEETING_DEPLOYMENT:
		var row: int = clampi(front_row + int(entry[2]) * step, 0, BOARD_SIZE - 1)
		var cell := Vector2i(int(entry[1]), row)
		if is_blocked_terrain(cell) or not piece_at(cell).is_empty(): continue
		add_piece(String(entry[0]), player, cell)


func _meeting_deployment_rows(player: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var forward := BOARD_SIZE / 2 + MEETING_FRONT_DISTANCE if player == current_player else BOARD_SIZE / 2 - MEETING_FRONT_DISTANCE
	var step := 1 if player == current_player else -1
	for rank in 3:
		cells.append_array(_back_rank_deployment(clampi(forward + rank * step, 0, BOARD_SIZE - 1)))
	return cells


func _back_rank_deployment(row: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in BOARD_SIZE: cells.append(Vector2i(x, row))
	return cells


func _seed_rng(seed_value: int) -> void:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	setup_seed = int(_rng.seed)


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
	if scenario == SCENARIO_MEETING:
		return _meeting_deployment_rows(player)
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
		"round_status": STATUS_READY, "movement_used": 0, "steps_taken": 0, "aim_spent": 0, "melee_count": 0, "participated_in_combat": false,
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


## Both four-player scenarios play by capture-the-flag and team survival; only
## the deployment, teams, and objective differ between them.
func _is_four_corner_scenario() -> bool:
	return scenario == SCENARIO_FOUR_PLAYER or scenario == SCENARIO_CROSSROADS


func piece_at(position: Vector2i) -> Dictionary:
	if not is_inside(position): return {}
	var id: int = board[position.y][position.x]
	return {} if id == EMPTY else pieces[id]


func is_inside(position: Vector2i) -> bool:
	return position.x >= 0 and position.y >= 0 and position.x < BOARD_SIZE and position.y < BOARD_SIZE


## Objectives are typed records rather than per-scenario branches, so a new
## scenario is a setup function plus a list of these, and both the replay format
## and an external controller can read the win condition without special cases.
##
## hold_square: a player wins by holding one square, alone, at the end of each
## of `rounds` consecutive rounds. Any round the holder is absent or the enemy
## is present resets that player's streak to zero.
func add_hold_square_objective(square: Vector2i, rounds: int, turn_limit: int) -> void:
	objectives.append({
		"type": OBJECTIVE_HOLD_SQUARE, "square": square,
		"rounds": maxi(1, rounds), "turn_limit": maxi(1, turn_limit), "streaks": {},
	})


## Losing your whole army loses the game regardless of the objective. Applies to
## objective scenarios; four-player elimination is handled by team survival.
func _finish_if_army_destroyed() -> bool:
	if objectives.is_empty() or active_players.size() != 2: return false
	for player in active_players:
		if total_strength(player) > 0: continue
		var survivor := active_players[0] if active_players[1] == player else active_players[1]
		_finish_game(survivor, "army_destroyed")
		return true
	return false


## reach_area: a player wins by having `strength` worth of surviving formations
## inside a rectangle at the end of a round. Rectangles rather than cell lists
## keep the replay format small and the objective describable in one sentence.
func add_reach_area_objective(player: int, area: Rect2i, strength: int, reason: String = "reached_objective") -> void:
	objectives.append({
		"type": OBJECTIVE_REACH_AREA, "player": player, "area": area,
		"strength": maxi(1, strength), "reason": reason,
	})


## eliminate: no positional goal at all, just destroy the other army. Losing
## every formation already loses the game, so this only supplies the deadline
## that stops two survivors circling each other forever.
func add_eliminate_objective(turn_limit: int) -> void:
	objectives.append({"type": OBJECTIVE_ELIMINATE, "turn_limit": maxi(1, turn_limit)})


## survive: a player wins simply by still being in the game at `until_round`.
## Paired with reach_area, this is an attacker/defender scenario.
func add_survive_objective(player: int, until_round: int, reason: String = "held_out") -> void:
	objectives.append({"type": OBJECTIVE_SURVIVE, "player": player, "until_round": maxi(1, until_round), "reason": reason})


## A square that represents where a player should be heading, derived from the
## objectives rather than the scenario id. Returns (-1,-1) when the scenario has
## no positional objective for that player, such as pure survival.
func objective_aim_point(player: int) -> Vector2i:
	for objective: Dictionary in objectives:
		var kind := String(objective.type)
		if kind == OBJECTIVE_HOLD_SQUARE:
			return objective.square
		if kind == OBJECTIVE_REACH_AREA:
			var area: Rect2i = objective.area
			if int(objective.player) == player:
				return area.position + area.size / 2
			# The defender's aim point is the same ground, seen from the far side.
			return Vector2i(area.position.x + area.size.x / 2, area.end.y)
	return Vector2i(-1, -1)


## Strength a player currently has standing inside an area.
func strength_in_area(player: int, area: Rect2i) -> int:
	var total := 0
	for piece: Dictionary in pieces:
		if piece.alive and int(piece.player) == player and piece.type != FLAG and area.has_point(piece.position):
			total += int(piece.strength)
	return total


## Objectives resolve in the order they were declared, so a scenario decides its
## own precedence: the bridge attacker breaking through on the final round beats
## the defender's turn-limit win because it is declared first.
func _check_objectives() -> void:
	for index in objectives.size():
		var objective: Dictionary = objectives[index]
		var kind := String(objective.type)
		var reason := String(objective.get("reason", kind))
		if kind == OBJECTIVE_REACH_AREA:
			if strength_in_area(int(objective.player), objective.area) >= int(objective.strength):
				_finish_game(int(objective.player), reason)
				return
			continue
		if kind == OBJECTIVE_SURVIVE:
			if round_number >= int(objective.until_round):
				_finish_game(int(objective.player), reason)
				return
			continue
		if kind == OBJECTIVE_ELIMINATE:
			if round_number >= int(objective.turn_limit):
				_finish_game(DRAW, "stalemate")
				return
			continue
		if kind != OBJECTIVE_HOLD_SQUARE:
			continue
		var square: Vector2i = objective.square
		var occupant := piece_at(square)
		var holder := int(occupant.player) if not occupant.is_empty() and occupant.type != FLAG else DRAW
		var streaks: Dictionary = objective.streaks
		for player in active_players:
			var holds := holder != DRAW and are_allied_players(player, holder)
			streaks[player] = int(streaks.get(player, 0)) + 1 if holds else 0
			if int(streaks[player]) >= int(objective.rounds):
				_finish_game(player, "held_objective")
				return
		objectives[index].streaks = streaks
		if round_number >= int(objective.turn_limit):
			# Nobody consolidated the position, so nobody earned it.
			_finish_game(DRAW, "objective_contested")
			return


## Rounds each player has currently held an objective square in a row.
func objective_streak(objective_index: int, player: int) -> int:
	if objective_index < 0 or objective_index >= objectives.size(): return 0
	return int(objectives[objective_index].get("streaks", {}).get(player, 0))


## Lays a river across the board with crossings at the given columns.
func apply_river_terrain(river_y: int, crossings: Array) -> void:
	for x in BOARD_SIZE:
		var cell := Vector2i(x, river_y)
		set_terrain(cell, TERRAIN_BRIDGE if x in crossings else TERRAIN_WATER)


## The four impassable ponds of the classic symmetric board.
func apply_lake_terrain() -> void:
	for cell: Vector2i in LAKES: set_terrain(cell, TERRAIN_LAKE)


## Terrain is data, not a function of which scenario is loaded, so a new map
## only has to populate the dictionary during setup.
func set_terrain(position: Vector2i, kind: String) -> void:
	if kind.is_empty(): terrain.erase(position)
	else: terrain[position] = kind


func terrain_at(position: Vector2i) -> String:
	return String(terrain.get(position, TERRAIN_OPEN))


func is_lake(position: Vector2i) -> bool:
	return terrain_at(position) == TERRAIN_LAKE


func is_water(position: Vector2i) -> bool:
	return terrain_at(position) == TERRAIN_WATER


func is_bridge(position: Vector2i) -> bool:
	return terrain_at(position) == TERRAIN_BRIDGE


func is_blocked_terrain(position: Vector2i) -> bool:
	return is_lake(position) or is_water(position)


func is_movable(piece: Dictionary) -> bool:
	return not piece.is_empty() and bool(piece.get("alive", false)) and piece.type != FLAG and int(piece.strength) > 0


func movement_limit_for(piece: Dictionary) -> int:
	return int(MOVEMENT_BY_WEIGHT.get(piece.get("weight", ""), 0))


func first_movement_impulse_for(piece: Dictionary) -> int:
	return 4 - movement_limit_for(piece)


func movement_step_index_for_impulse(piece: Dictionary, impulse: int) -> int:
	var step_index := impulse - first_movement_impulse_for(piece)
	return step_index if step_index >= 0 and step_index < movement_limit_for(piece) else -1


func impulse_for_movement_step(piece: Dictionary, step_index: int) -> int:
	return first_movement_impulse_for(piece) + step_index


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
	var completed_steps := clampi(impulse - first_movement_impulse_for(piece) + 1, 0, path.size())
	return piece.position if completed_steps == 0 else path[completed_steps - 1]


func projected_main_destination(piece_id: int) -> Vector2i:
	var path: Array = order_for_piece(piece_id).get("path", [])
	return pieces[piece_id].position if path.is_empty() else path.back()


## Validates a declared shot and returns {ok, shot_type, message}.
##
## Movement spent restricts what may be declared; the declared range sets the
## price. A formation that has already ordered movement may only take a short
## shot at an adjacent square. A stationary one may take either, and may aim
## beyond range 2 as overwatch, which is a long shot that fires only if the
## target closes. Targets must be visible: no blind fire into fog.
func _declared_shot_type(piece: Dictionary, player: int, path: Array[Vector2i], target: Vector2i, target_id: int) -> Dictionary:
	if piece.role != ROLE_ARCHER:
		return {"ok": false, "message": "Only Archers can receive ranged orders."}
	if not is_inside(target) or is_blocked_terrain(target):
		return {"ok": false, "message": "Archers cannot target that square."}
	if target_id >= 0:
		if target_id >= pieces.size() or not pieces[target_id].alive:
			return {"ok": false, "message": "That formation is no longer on the battlefield."}
		var aimed: Dictionary = pieces[target_id]
		if are_allied_players(player, int(aimed.player)):
			return {"ok": false, "message": "Archers cannot target an allied formation."}
		if not is_piece_visible_to(aimed, player):
			return {"ok": false, "message": "Archers can only target a formation they can see."}
	elif not is_position_visible_to(target, player):
		return {"ok": false, "message": "Archers can only target a square they can see."}
	var origin: Vector2i = piece.position if path.is_empty() else path.back()
	var declared_range := grid_distance(origin, target)
	if declared_range == 0:
		return {"ok": false, "message": "Archers cannot target their own square."}
	if not path.is_empty():
		if declared_range != 1:
			return {"ok": false, "message": "After moving, Archers may only target an adjacent square."}
		return {"ok": true, "shot_type": SHOT_SHORT}
	return {"ok": true, "shot_type": SHOT_SHORT if declared_range == 1 else SHOT_LONG}


func set_unit_order(player: int, piece_id: int, path: Array, ranged_target: Vector2i = Vector2i(-1, -1), leftover: Vector2i = Vector2i(-1, -1), ranged_target_id: int = -1, strict_friendly: bool = true) -> Dictionary:
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
		if not are_adjacent(previous, step) or not is_inside(step) or is_blocked_terrain(step):
			return {"ok": false, "message": "Paths must use adjacent passable squares."}
		normalized_path.append(step)
		previous = step
	var movement_cost := normalized_path.size()
	var shot_type := ""
	if ranged_target.x >= 0:
		var declaration := _declared_shot_type(piece, player, normalized_path, ranged_target, ranged_target_id)
		if not bool(declaration.get("ok", false)): return declaration
		shot_type = String(declaration.shot_type)
		# Aiming reserves one point during main movement whichever shot it is.
		# A long shot spends the remainder in the ranged phase, but only if it
		# actually fires, so the rest stays available to a shot that fizzles.
		movement_cost += 1
	if leftover.x >= 0:
		if not are_adjacent(previous, leftover) or not is_inside(leftover) or is_blocked_terrain(leftover):
			return {"ok": false, "message": "Leftover movement is one adjacent passable square."}
		movement_cost += 1
	if movement_cost > movement_limit_for(piece):
		return {"ok": false, "message": "That order exceeds the formation's movement allowance."}
	var candidate := {
		"piece_id": piece_id, "player": player, "path": normalized_path,
		"ranged_target": ranged_target, "ranged_target_id": ranged_target_id if ranged_target.x >= 0 else -1,
		"shot_type": shot_type, "leftover": leftover,
	}
	if not _same_player_order_is_clear(player, piece_id, candidate, strict_friendly):
		return {"ok": false, "message": "Friendly formations would collide on the same impulse."}
	if player not in orders: orders[player] = {}
	orders[player][piece_id] = candidate
	return {"ok": true, "order": candidate.duplicate(true)}


func append_order_step(player: int, piece_id: int, step: Vector2i, strict_friendly: bool = true) -> Dictionary:
	var current := order_for_piece(piece_id)
	var path: Array = current.get("path", []).duplicate()
	path.append(step)
	return set_unit_order(player, piece_id, path, current.get("ranged_target", Vector2i(-1, -1)), current.get("leftover", Vector2i(-1, -1)), int(current.get("ranged_target_id", -1)), strict_friendly)


func append_group_order_step(player: int, piece_ids: Array[int], direction: Vector2i, strict_friendly: bool = true) -> Dictionary:
	if absi(direction.x) + absi(direction.y) != 1:
		return {"ok": false, "message": "Group movement must use one cardinal direction."}
	return _change_group_paths(player, piece_ids, direction, false, strict_friendly)


func pop_order_step(player: int, piece_id: int) -> Dictionary:
	var current := order_for_piece(piece_id)
	var path: Array = current.get("path", []).duplicate()
	if not path.is_empty(): path.pop_back()
	return set_unit_order(player, piece_id, path, current.get("ranged_target", Vector2i(-1, -1)), current.get("leftover", Vector2i(-1, -1)), int(current.get("ranged_target_id", -1)))


func pop_group_order_step(player: int, piece_ids: Array[int]) -> Dictionary:
	return _change_group_paths(player, piece_ids, Vector2i.ZERO, true)


func _change_group_paths(player: int, piece_ids: Array[int], direction: Vector2i, remove_last: bool, strict_friendly: bool = true) -> Dictionary:
	if phase != PHASE_PLANNING or game_over or player in ready_players:
		return {"ok": false, "message": "Orders can only be changed during planning."}
	var unique_ids: Array[int] = []
	for piece_id in piece_ids:
		if piece_id not in unique_ids:
			unique_ids.append(piece_id)
	if unique_ids.is_empty():
		return {"ok": false, "message": "No formations are selected."}
	var original_orders: Dictionary = orders.get(player, {}).duplicate(true)
	if player not in orders:
		orders[player] = {}
	var candidates: Dictionary = {}
	var eligible_ids: Array[int] = []
	var skipped_for_speed := 0
	var skipped_for_path := 0
	var skipped_immobile := 0
	for piece_id in unique_ids:
		# Ordering a formation that is not yours, or that does not exist, is a
		# caller error rather than a fact about the battle, so it still fails
		# the whole call.
		if piece_id < 0 or piece_id >= pieces.size() or int(pieces[piece_id].player) != player:
			orders[player] = original_orders
			return {"ok": false, "message": "Every selected formation must belong to this player."}
		# Being unable to move is not. A selection that happens to include the
		# Flag, or a formation ground down to no Strength, is an ordinary thing
		# to drag a box around, and rejecting the whole order over it meant a
		# group containing one of them silently did nothing at all.
		if not is_movable(pieces[piece_id]):
			skipped_immobile += 1
			continue
		var current: Dictionary = original_orders.get(piece_id, {})
		if not remove_last and planned_movement_reserved(piece_id, current) >= movement_limit_for(pieces[piece_id]):
			skipped_for_speed += 1
			continue
		var path: Array = current.get("path", []).duplicate()
		if remove_last:
			if not path.is_empty():
				path.pop_back()
		else:
			var previous: Vector2i = pieces[piece_id].position if path.is_empty() else path.back()
			var step: Vector2i = previous + direction
			# Off the map or into blocked terrain is a fact about this one
			# formation's position, unrelated to anything else in the
			# selection, so it is skipped here rather than left for the
			# collision pass below to sort out.
			if not is_inside(step) or is_blocked_terrain(step):
				skipped_for_path += 1
				continue
			path.append(step)
		var candidate := {
			"piece_id": piece_id,
			"player": player,
			"path": path,
			"ranged_target": current.get("ranged_target", Vector2i(-1, -1)),
			"ranged_target_id": int(current.get("ranged_target_id", -1)),
			"shot_type": String(current.get("shot_type", "")),
			"leftover": current.get("leftover", Vector2i(-1, -1)),
		}
		candidates[piece_id] = candidate
		orders[player][piece_id] = candidate
		eligible_ids.append(piece_id)
	if eligible_ids.is_empty():
		orders[player] = original_orders
		return {"ok": false, "count": 0, "skipped": skipped_for_speed + skipped_for_path + skipped_immobile, "message": "No formations in the selection could take that step."}
	# Candidates go in one at a time rather than all at once, because
	# set_unit_order's collision check inspects the whole player's plan, not
	# just the candidate it was handed. Installing everything up front and
	# then asking whether the plan is clear only yields one global yes or no,
	# which cannot say WHICH formation is at fault - and blaming a formation
	# by some proxy such as "drop the fastest" throws out marches that were
	# never involved. Adding them individually makes each answer be about
	# that formation alone.
	#
	# Order of installation decides who yields to whom, and both keys matter.
	# Earliest mover first, because this engine already forbids a faster
	# formation following a slower one into a square it has not vacated yet,
	# so the one arriving soonest has to be placed before anything hoping to
	# follow it. Then furthest along the direction of travel first, so that a
	# column of equally fast formations installs from its head backwards and
	# advances in lockstep; installing a follower before its leader would
	# have it collide with a leader that has not been given its own step yet.
	var install_order := eligible_ids.duplicate()
	install_order.sort_custom(func(first: int, second: int) -> bool:
		var first_impulse := first_movement_impulse_for(pieces[first])
		var second_impulse := first_movement_impulse_for(pieces[second])
		if first_impulse != second_impulse:
			return first_impulse < second_impulse
		var first_lead: int = pieces[first].position.x * direction.x + pieces[first].position.y * direction.y
		var second_lead: int = pieces[second].position.x * direction.x + pieces[second].position.y * direction.y
		return first_lead > second_lead
	)
	# Back to what the player already had, so each candidate is judged against
	# the orders that survived rather than against every hopeful step.
	orders[player] = original_orders.duplicate(true)
	var applied_ids: Array[int] = []
	var skipped_for_conflict := 0
	for piece_id in install_order:
		var candidate: Dictionary = candidates[piece_id]
		# A rejected order leaves this formation's previous one untouched, so
		# there is nothing to undo here.
		if bool(set_unit_order(player, piece_id, candidate.path, candidate.ranged_target, candidate.leftover, -1, strict_friendly).get("ok", false)):
			applied_ids.append(piece_id)
		else:
			skipped_for_conflict += 1
	var skipped_total := skipped_for_speed + skipped_for_path + skipped_immobile + skipped_for_conflict
	if applied_ids.is_empty():
		orders[player] = original_orders
		return {"ok": false, "count": 0, "skipped": skipped_total, "message": "No formations in the selection could take that step."}
	var message := "Order applied to %d formation%s." % [applied_ids.size(), "" if applied_ids.size() == 1 else "s"]
	if skipped_total > 0:
		message += " %d skipped." % skipped_total
	return {"ok": true, "count": applied_ids.size(), "skipped": skipped_total, "message": message}


func planned_movement_reserved(piece_id: int, supplied_order: Dictionary = {}) -> int:
	if piece_id < 0 or piece_id >= pieces.size():
		return 0
	var order := supplied_order if not supplied_order.is_empty() else order_for_piece(piece_id)
	var piece: Dictionary = pieces[piece_id]
	var spent := int(order.get("path", []).size())
	# Only the aim point is reserved at planning time. A long shot spends the
	# rest during the ranged phase, and only if it actually fires.
	if not String(order.get("shot_type", "")).is_empty():
		spent += AIM_COST
	if order.get("leftover", Vector2i(-1, -1)).x >= 0:
		spent += 1
	return spent


## Step distance between two cells, ignoring terrain and occupancy.
static func grid_distance(first: Vector2i, second: Vector2i) -> int:
	return absi(first.x - second.x) + absi(first.y - second.y)


## True when a formation can step directly from one cell to the other.
static func are_adjacent(first: Vector2i, second: Vector2i) -> bool:
	return grid_distance(first, second) == 1


## Every cell one step from origin, including off-board ones. Callers filter
## for is_inside and is_blocked_terrain themselves.
static func neighbors(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction: Vector2i in DIRECTIONS: result.append(origin + direction)
	return result


## Every cell within reach steps of origin, origin included. Used for vision
## and for any range-limited targeting.
static func cells_within_range(origin: Vector2i, reach: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y_offset in range(-reach, reach + 1):
		var horizontal_reach := reach - absi(y_offset)
		for x_offset in range(-horizontal_reach, horizontal_reach + 1):
			result.append(origin + Vector2i(x_offset, y_offset))
	return result


## Whether the given square can currently be declared as a target, and as which
## shot. Returns an empty string when the declaration would be rejected, so the
## UI can offer Shoot and Suppress only where they would take.
func declared_shot_type_for(player: int, piece_id: int, target: Vector2i, target_id: int = -1) -> String:
	if phase != PHASE_PLANNING or piece_id < 0 or piece_id >= pieces.size():
		return ""
	var piece: Dictionary = pieces[piece_id]
	if int(piece.player) != player or piece.role != ROLE_ARCHER:
		return ""
	var current := order_for_piece(piece_id)
	var typed_path: Array[Vector2i] = []
	for step in current.get("path", []):
		typed_path.append(step)
	var declaration := _declared_shot_type(piece, player, typed_path, target, target_id)
	return String(declaration.get("shot_type", "")) if bool(declaration.get("ok", false)) else ""


func ranged_order_is_available(player: int, piece_id: int, target: Vector2i, target_id: int = -1) -> bool:
	return not declared_shot_type_for(player, piece_id, target, target_id).is_empty()


## Aimed fire at a formation: it is shot wherever it stands, if still in range.
func set_ranged_order(player: int, piece_id: int, target: Vector2i, target_id: int = -1) -> Dictionary:
	var current := order_for_piece(piece_id)
	return set_unit_order(player, piece_id, current.get("path", []), target, current.get("leftover", Vector2i(-1, -1)), target_id)


## Suppressing fire at a square: whatever is standing there gets shot.
func set_suppress_order(player: int, piece_id: int, target: Vector2i) -> Dictionary:
	return set_ranged_order(player, piece_id, target, -1)


func set_leftover_order(player: int, piece_id: int, target: Vector2i) -> Dictionary:
	if phase == PHASE_LEFTOVER_PLANNING:
		return _set_leftover_phase_order(player, piece_id, target)
	var current := order_for_piece(piece_id)
	return set_unit_order(player, piece_id, current.get("path", []), current.get("ranged_target", Vector2i(-1, -1)), target, int(current.get("ranged_target_id", -1)))


func set_group_leftover_step(player: int, piece_ids: Array[int], direction: Vector2i) -> Dictionary:
	if phase == PHASE_LEFTOVER_PLANNING:
		return _set_leftover_phase_group_order(player, piece_ids, direction)
	if phase != PHASE_PLANNING or game_over or player in ready_players:
		return {"ok": false, "message": "Orders can only be changed during planning."}
	if absi(direction.x) + absi(direction.y) != 1:
		return {"ok": false, "message": "Leftover movement must use one cardinal direction."}
	var unique_ids: Array[int] = []
	for piece_id in piece_ids:
		if piece_id not in unique_ids:
			unique_ids.append(piece_id)
	if unique_ids.is_empty():
		return {"ok": false, "message": "No formations are selected."}
	var original_orders: Dictionary = orders.get(player, {}).duplicate(true)
	if player not in orders:
		orders[player] = {}
	var candidates: Dictionary = {}
	var eligible_ids: Array[int] = []
	var skipped_for_speed := 0
	for piece_id in unique_ids:
		if piece_id < 0 or piece_id >= pieces.size() or int(pieces[piece_id].player) != player:
			orders[player] = original_orders
			return {"ok": false, "message": "Every selected formation must belong to this player."}
		# Skipped, not fatal: see _change_group_paths. A Flag in the selection
		# must not cost everything else its leftover step.
		if not is_movable(pieces[piece_id]):
			skipped_for_speed += 1
			continue
		var current: Dictionary = original_orders.get(piece_id, {})
		var path: Array = current.get("path", []).duplicate()
		var ranged_target: Vector2i = current.get("ranged_target", Vector2i(-1, -1))
		var spent_before_leftover := planned_movement_reserved(piece_id, current)
		if spent_before_leftover >= movement_limit_for(pieces[piece_id]):
			skipped_for_speed += 1
			continue
		var previous: Vector2i = pieces[piece_id].position if path.is_empty() else path.back()
		var candidate := {
			"piece_id": piece_id,
			"player": player,
			"path": path,
			"ranged_target": ranged_target,
			"leftover": previous + direction,
		}
		candidates[piece_id] = candidate
		orders[player][piece_id] = candidate
		eligible_ids.append(piece_id)
	if eligible_ids.is_empty():
		orders[player] = original_orders
		return {"ok": false, "count": 0, "skipped": skipped_for_speed, "message": "No selected formations have movement left for the leftover phase."}
	var applied_ids: Array[int] = []
	var skipped_for_conflict := 0
	for piece_id in eligible_ids:
		var candidate: Dictionary = candidates[piece_id]
		var result := set_unit_order(player, piece_id, candidate.path, candidate.ranged_target, candidate.leftover)
		if bool(result.get("ok", false)):
			applied_ids.append(piece_id)
			continue
		skipped_for_conflict += 1
		# As in _change_group_paths: one formation that cannot take this step
		# does not undo the rest of an otherwise-valid group order.
		if original_orders.has(piece_id):
			orders[player][piece_id] = original_orders[piece_id]
		else:
			orders[player].erase(piece_id)
	var skipped_total := skipped_for_speed + skipped_for_conflict
	if applied_ids.is_empty():
		orders[player] = original_orders
		return {"ok": false, "count": 0, "skipped": skipped_total, "message": "No formations in the selection could take that leftover step."}
	var message := "Leftover move set for %d formation%s." % [applied_ids.size(), "" if applied_ids.size() == 1 else "s"]
	if skipped_total > 0:
		message += " %d skipped." % skipped_total
	return {"ok": true, "count": applied_ids.size(), "skipped": skipped_total, "message": message}


func _set_leftover_phase_order(player: int, piece_id: int, target: Vector2i) -> Dictionary:
	if game_over or player in ready_players:
		return {"ok": false, "message": "Leftover orders can only be changed before ending the leftover phase."}
	if piece_id < 0 or piece_id >= pieces.size() or int(pieces[piece_id].player) != player:
		return {"ok": false, "message": "That formation cannot receive this leftover order."}
	if not can_receive_leftover_order(player, piece_id):
		return {"ok": false, "message": "That formation has no leftover movement available."}
	var piece: Dictionary = pieces[piece_id]
	if not are_adjacent(piece.position, target) or not is_inside(target) or is_blocked_terrain(target):
		return {"ok": false, "message": "Leftover movement is one adjacent passable square."}
	var original_orders: Dictionary = orders.get(player, {}).duplicate(true)
	if player not in orders:
		orders[player] = {}
	var candidate: Dictionary = order_for_piece(piece_id).duplicate(true)
	if candidate.is_empty():
		candidate = {"piece_id": piece_id, "player": player, "path": [], "ranged_target": Vector2i(-1, -1)}
	candidate.leftover = target
	orders[player][piece_id] = candidate
	if not _same_player_leftover_orders_are_clear(player):
		orders[player] = original_orders
		return {"ok": false, "message": "Friendly formations would collide during leftover movement."}
	return {"ok": true, "order": candidate.duplicate(true), "message": "Leftover move set."}


func _set_leftover_phase_group_order(player: int, piece_ids: Array[int], direction: Vector2i) -> Dictionary:
	if game_over or player in ready_players:
		return {"ok": false, "message": "Leftover orders can only be changed before ending the leftover phase."}
	if absi(direction.x) + absi(direction.y) != 1:
		return {"ok": false, "message": "Leftover movement must use one cardinal direction."}
	var unique_ids: Array[int] = []
	for piece_id in piece_ids:
		if piece_id not in unique_ids:
			unique_ids.append(piece_id)
	if unique_ids.is_empty():
		return {"ok": false, "message": "No formations are selected."}
	var original_orders: Dictionary = orders.get(player, {}).duplicate(true)
	if player not in orders:
		orders[player] = {}
	var eligible_ids: Array[int] = []
	var skipped := 0
	for piece_id in unique_ids:
		if piece_id < 0 or piece_id >= pieces.size() or int(pieces[piece_id].player) != player:
			orders[player] = original_orders
			return {"ok": false, "message": "Every selected formation must belong to this player."}
		if not can_receive_leftover_order(player, piece_id):
			skipped += 1
			continue
		var target: Vector2i = pieces[piece_id].position + direction
		if not is_inside(target) or is_blocked_terrain(target):
			# This one formation's step is invalid; the rest of the selection
			# may still be fine, so only this formation is skipped.
			skipped += 1
			continue
		var candidate: Dictionary = order_for_piece(piece_id).duplicate(true)
		if candidate.is_empty():
			candidate = {"piece_id": piece_id, "player": player, "path": [], "ranged_target": Vector2i(-1, -1)}
		candidate.leftover = target
		orders[player][piece_id] = candidate
		eligible_ids.append(piece_id)
	if eligible_ids.is_empty():
		orders[player] = original_orders
		return {"ok": false, "count": 0, "skipped": skipped, "message": "No selected formations have leftover movement available."}
	# _same_player_leftover_orders_are_clear only reports whether the whole
	# player's leftover plan collides somewhere, not which formation is at
	# fault - the collision could even involve a piece outside this
	# selection - so a colliding candidate is found by trial removal rather
	# than by inspection. Same principle as everywhere else in this
	# function: one formation's conflict should not cost the rest of the
	# selection its otherwise-valid step.
	while not _same_player_leftover_orders_are_clear(player) and not eligible_ids.is_empty():
		var culprit: int = eligible_ids.pop_back()
		if original_orders.has(culprit):
			orders[player][culprit] = original_orders[culprit]
		else:
			orders[player].erase(culprit)
		skipped += 1
	if eligible_ids.is_empty():
		orders[player] = original_orders
		return {"ok": false, "count": 0, "skipped": skipped, "message": "No formations in the selection could take that leftover step."}
	var message := "Leftover move set for %d formation%s." % [eligible_ids.size(), "" if eligible_ids.size() == 1 else "s"]
	if skipped > 0:
		message += " %d skipped." % skipped
	return {"ok": true, "count": eligible_ids.size(), "skipped": skipped, "message": message}


func can_receive_leftover_order(player: int, piece_id: int) -> bool:
	if phase != PHASE_LEFTOVER_PLANNING or piece_id < 0 or piece_id >= pieces.size():
		return false
	var piece: Dictionary = pieces[piece_id]
	return int(piece.player) == player and _eligible_for_leftover(piece)


func _same_player_leftover_orders_are_clear(player: int) -> bool:
	var own_pieces: Array[Dictionary] = []
	for piece: Dictionary in pieces:
		if piece.alive and int(piece.player) == player and piece.type != FLAG:
			own_pieces.append(piece)
	var destinations: Dictionary = {}
	for piece: Dictionary in own_pieces:
		var target: Vector2i = piece.position
		var planned: Vector2i = order_for_piece(int(piece.id)).get("leftover", Vector2i(-1, -1))
		if _eligible_for_leftover(piece) and planned.x >= 0 and are_adjacent(piece.position, planned):
			target = planned
		if target in destinations:
			return false
		destinations[target] = piece.id
	for first_index in own_pieces.size():
		for second_index in range(first_index + 1, own_pieces.size()):
			var first: Dictionary = own_pieces[first_index]
			var second: Dictionary = own_pieces[second_index]
			var first_target: Vector2i = order_for_piece(int(first.id)).get("leftover", first.position)
			var second_target: Vector2i = order_for_piece(int(second.id)).get("leftover", second.position)
			if not _eligible_for_leftover(first) or not are_adjacent(first.position, first_target):
				first_target = first.position
			if not _eligible_for_leftover(second) or not are_adjacent(second.position, second_target):
				second_target = second.position
			if first_target == second.position and second_target == first.position and first.position != second.position:
				return false
	return true


func clear_unit_order(player: int, piece_id: int) -> void:
	if player in ready_players or player not in orders:
		return
	if phase == PHASE_PLANNING:
		orders[player].erase(piece_id)
	elif phase == PHASE_LEFTOVER_PLANNING and piece_id in orders[player]:
		var order: Dictionary = orders[player][piece_id]
		order.leftover = Vector2i(-1, -1)
		orders[player][piece_id] = order


func clear_player_orders(player: int) -> void:
	if player in ready_players:
		return
	if phase == PHASE_PLANNING:
		orders[player] = {}
	elif phase == PHASE_LEFTOVER_PLANNING and player in orders:
		for piece_id in orders[player].keys():
			var order: Dictionary = orders[player][piece_id]
			order.leftover = Vector2i(-1, -1)
			orders[player][piece_id] = order


func has_leftover_orders(player: int) -> bool:
	for order: Dictionary in orders.get(player, {}).values():
		if order.get("leftover", Vector2i(-1, -1)).x >= 0:
			return true
	return false


func _same_player_order_is_clear(player: int, piece_id: int, candidate: Dictionary, strict_friendly: bool = true) -> bool:
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
				# Permissive callers accept the risk: the square may well be
				# free by the time the step actually happens, because the
				# occupant can move, win its fight and advance, or be killed.
				# Planning-time projection cannot know any of that, and the
				# resolver already turns a step that does not come off into a
				# bounce. Bots stay strict - they use this rejection to prune
				# their own colliding choices.
				if not strict_friendly:
					occupied[position] = piece.id
					continue
				# Two of your own formations may be sent at the same enemy
				# square whatever speeds they are, because committing a second
				# wave against a defender the first attack might not beat is a
				# real decision rather than a mistake to be prevented. This
				# used to additionally require both attackers to arrive on the
				# same impulse, which quietly meant only formations of matched
				# Weight could gang up: a Light and a Heavy sent at one enemy
				# were rejected outright.
				#
				# Staggered arrivals need no special handling here. If the
				# first attacker wins and takes the square, the follow-up finds
				# a friendly formation standing there and bounces, which the
				# resolver already does. If it loses, the follow-up gets its
				# own fight. An empty or allied destination is still a plain
				# collision and still refused.
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
	# The same relaxation applies to where formations END the round. Planning
	# projection assumes everyone reaches their destination, so two of your own
	# finishing on one square looks certain here when it is only likely: the
	# formation in the way may move off, win its fight and advance, or be
	# killed. A permissive caller is allowed to find out.
	if clear and strict_friendly:
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
	if phase not in [PHASE_DEPLOYMENT, PHASE_PLANNING, PHASE_LEFTOVER_PLANNING] or player not in active_players:
		return {"ok": false, "message": "This player cannot become ready now."}
	if player not in ready_players: ready_players.append(player)
	return {"ok": true, "all_ready": all_players_ready()}


func all_players_ready() -> bool:
	for player in active_players:
		if player not in ready_players: return false
	return not active_players.is_empty()


## Move one of a player's own formations to another cell inside their
## deployment zone. Only legal during PHASE_DEPLOYMENT, and only before that
## player has marked ready — once submitted, a redeploy would silently
## invalidate a decision the player already committed to.
func redeploy_piece(player: int, piece_id: int, target: Vector2i) -> Dictionary:
	if phase != PHASE_DEPLOYMENT or player in ready_players:
		return {"ok": false, "message": "Deployment is locked in."}
	if piece_id < 0 or piece_id >= pieces.size() or not pieces[piece_id].alive or int(pieces[piece_id].player) != player:
		return {"ok": false, "message": "That formation is not yours to place."}
	if target not in deployment_zone_cells(player):
		return {"ok": false, "message": "That square is outside your deployment zone."}
	var origin: Vector2i = pieces[piece_id].position
	if target == origin: return {"ok": true, "action": "redeploy", "piece_id": piece_id, "position": target}
	if board[target.y][target.x] != EMPTY:
		return {"ok": false, "message": "Another formation already holds that square."}
	board[origin.y][origin.x] = EMPTY
	board[target.y][target.x] = piece_id
	pieces[piece_id].position = target
	pieces[piece_id].previous_position = target
	pieces[piece_id].recent_positions = [target]
	_visibility_dirty = true
	return {"ok": true, "action": "redeploy", "piece_id": piece_id, "position": target}


## Restores a player's formations to the recommended deployment, undoing any
## redeploys. What "auto-deploy" resets to before marking ready, so pressing it
## after already dragging a few pieces around is not a no-op that leaves
## stragglers wherever they were last dropped.
func reset_deployment(player: int) -> Dictionary:
	if phase != PHASE_DEPLOYMENT or player in ready_players:
		return {"ok": false, "message": "Deployment is locked in."}
	# Two passes: clear every one of this player's cells first. A manual
	# redeploy may have put some other piece on a cell the recommended layout
	# wants back, and writing straight over the board array while a stale
	# occupant is still marked there would corrupt it.
	for piece: Dictionary in pieces:
		if piece.alive and int(piece.player) == player:
			var position: Vector2i = piece.position
			board[position.y][position.x] = EMPTY
	var claimed: Dictionary = {}
	for entry in recommended_deployment(player):
		var type := String(entry[0])
		var target: Vector2i = entry[1]
		for piece: Dictionary in pieces:
			var id := int(piece.id)
			if id in claimed or not piece.alive or int(piece.player) != player or piece.type != type: continue
			claimed[id] = true
			board[target.y][target.x] = id
			pieces[id].position = target
			pieces[id].previous_position = target
			pieces[id].recent_positions = [target]
			break
	_visibility_dirty = true
	return {"ok": true}


## Once every active player has locked in deployment, place the game on its
## first real round: sightings are recorded now, from wherever pieces actually
## ended up, rather than at setup against the recommended formation.
func resolve_deployment() -> bool:
	if phase != PHASE_DEPLOYMENT or not all_players_ready(): return false
	for piece: Dictionary in pieces:
		deployment_placements[piece.id] = _encode_position(piece.position)
	phase = PHASE_PLANNING
	ready_players.clear()
	_record_all_sightings()
	return true


func resolve_round() -> Array[Dictionary]:
	if phase == PHASE_LEFTOVER_PLANNING:
		return resolve_leftover_phase()
	if phase != PHASE_PLANNING or game_over or not all_players_ready(): return []
	var events := resolve_main_and_ranged()
	for player in active_players:
		mark_player_ready(player)
	events.append_array(resolve_leftover_phase())
	return events


func resolve_main_and_ranged() -> Array[Dictionary]:
	if phase != PHASE_PLANNING or game_over or not all_players_ready(): return []
	var recorded_round := round_number
	var recorded_orders := _encode_main_orders()
	var roll_start := _roll_history.size()
	phase = PHASE_RESOLVING
	last_round_events.clear()
	_begin_round_state()
	_charge_declared_aim()
	_record_all_sightings()
	for impulse in range(1, 4):
		var proposals: Array[Dictionary] = []
		for piece: Dictionary in pieces:
			if not is_movable(piece) or bool(piece.main_done): continue
			# Indexed by steps actually completed rather than by impulse
			# arithmetic. A formation turned back by one of its own can try the
			# same square again on a later impulse, and without this it would
			# propose the NEXT step instead and skip a square. movement_used is
			# charged whether or not the step lands, so retries are budgeted by
			# the same allowance as movement: a Light gets three attempts in
			# total, however it spends them.
			if impulse < first_movement_impulse_for(piece): continue
			if int(piece.movement_used) >= movement_limit_for(piece): continue
			var path: Array = order_for_piece(int(piece.id)).get("path", [])
			var taken := int(piece.steps_taken)
			if path.size() > taken:
				proposals.append({"piece_id": int(piece.id), "from": piece.position, "to": path[taken], "is_attacker": true, "impulse": impulse})
		if not proposals.is_empty(): last_round_events.append_array(_resolve_movement_batch(proposals, "impulse_%d" % impulse))
		_record_all_sightings()
	last_round_events.append_array(_resolve_ranged_phase())
	_record_all_sightings()
	ready_players.clear()
	phase = PHASE_LEFTOVER_PLANNING
	_active_replay_round = {
		"round": recorded_round,
		"main_orders": recorded_orders,
		"main_rolls": _roll_history.slice(roll_start),
		"main_event_digest": _digest_value(last_round_events),
		"main_state_digest": state_digest(),
	}
	return last_round_events.duplicate(true)


func resolve_leftover_phase() -> Array[Dictionary]:
	if phase != PHASE_LEFTOVER_PLANNING or game_over or not all_players_ready(): return []
	var recorded_round := round_number
	var recorded_orders := _encode_leftover_orders()
	var roll_start := _roll_history.size()
	phase = PHASE_RESOLVING
	var leftover_events: Array[Dictionary] = []
	var leftover_proposals: Array[Dictionary] = []
	for piece: Dictionary in pieces:
		if not _eligible_for_leftover(piece): continue
		var target: Vector2i = order_for_piece(int(piece.id)).get("leftover", Vector2i(-1, -1))
		if target.x >= 0 and are_adjacent(piece.position, target):
			leftover_proposals.append({"piece_id": int(piece.id), "from": piece.position, "to": target, "is_attacker": true, "impulse": 4})
	if not leftover_proposals.is_empty():
		leftover_events.append_array(_resolve_movement_batch(leftover_proposals, "leftover"))
		last_round_events.append_array(leftover_events)
	_record_all_sightings()
	_finish_round()
	if _active_replay_round.is_empty():
		_active_replay_round = {"round": recorded_round, "main_orders": [], "main_rolls": [], "main_event_digest": "", "main_state_digest": ""}
	_active_replay_round.leftover_orders = recorded_orders
	_active_replay_round.leftover_rolls = _roll_history.slice(roll_start)
	_active_replay_round.leftover_event_digest = _digest_value(leftover_events)
	_active_replay_round.final_state_digest = state_digest()
	replay_rounds.append(_active_replay_round.duplicate(true))
	_active_replay_round.clear()
	return leftover_events.duplicate(true)


## Aiming is paid for during main movement, before anyone moves, so the point
## is gone whether or not the shot finds a target later in the round.
func _charge_declared_aim() -> void:
	for piece: Dictionary in pieces:
		if not piece.alive or piece.role != ROLE_ARCHER: continue
		if String(order_for_piece(int(piece.id)).get("shot_type", "")).is_empty(): continue
		pieces[piece.id].aim_spent = AIM_COST


func _begin_round_state() -> void:
	for piece: Dictionary in pieces:
		if piece.alive:
			pieces[piece.id].round_status = STATUS_READY
			pieces[piece.id].movement_used = 0
			pieces[piece.id].steps_taken = 0
			pieces[piece.id].aim_spent = 0
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
			pieces[id].steps_taken = int(pieces[id].steps_taken) + 1
			events.append(_movement_event(id, move.from, move.to, batch_name))
		else:
			_place_piece(id, move.from, move.from)
			# Blocked by one of your own is a queue, not a repulse: the square
			# may well be free by a later impulse, so the formation keeps its
			# turn and tries again. Blocked by an enemy ends its round as before.
			var blocker := piece_at(move.to)
			_mark_bounced(id, false, not blocker.is_empty() and are_allied_players(int(pieces[id].player), int(blocker.player)))
			events.append(_bounce_event([id], move.to, batch_name, "occupied_after_resolution"))
	for collision: Dictionary in allied_collisions:
		# A formation that was merely bumped into never moved, so its round is
		# left alone. Marking it bounced set main_done and froze it in place,
		# which meant a formation ordered up behind a slower one could stop the
		# very formation it was queueing behind from ever moving.
		var stationary := int(collision.get("stationary_id", EMPTY))
		var collision_ids: Array[int] = []
		for id_value in collision.ids:
			var id := int(id_value)
			collision_ids.append(id)
			if id == stationary:
				# Jostled rather than repulsed. It still loses its leftover
				# move, as it always has, but main_done is left alone so it can
				# take its own later impulse. Setting that was what let a
				# formation queueing up behind a slower one freeze the very
				# formation it was waiting on.
				pieces[id].round_status = STATUS_BOUNCED
				continue
			# Retry only when something was standing in the way that may yet
			# move off. Two formations converging on one square would simply
			# converge again, so repeating that is pure waste.
			_mark_bounced(id, false, stationary != EMPTY)
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
	var role_bonuses: Dictionary = {}
	var capped_rolls: Dictionary = {}
	var participant_ids: Array[int] = []
	for participant: Dictionary in participants:
		var id := int(participant.piece_id)
		if id in participant_ids or not pieces[id].alive: continue
		participant_ids.append(id)
		var raw := _roll_d10()
		var capped := mini(raw, int(pieces[id].strength))
		var bonus := 0
		if bool(participant.is_attacker) and pieces[id].role == ROLE_CAVALRY: bonus = ROLE_BONUS
		if not bool(participant.is_attacker) and pieces[id].role == ROLE_INFANTRY: bonus = ROLE_BONUS
		scores[id] = capped + bonus
		raw_rolls[id] = raw
		# Recorded rather than left to be inferred: a display cannot reconstruct
		# the bonus from roll and score alone, because the roll is capped by a
		# Strength the reader no longer sees once damage has been applied.
		role_bonuses[id] = bonus
		capped_rolls[id] = capped
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
		"role_bonuses": role_bonuses.duplicate(true), "capped_rolls": capped_rolls.duplicate(true),
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
	var fizzles: Array[Dictionary] = []
	for piece: Dictionary in pieces:
		var order := order_for_piece(int(piece.id))
		var shot_type := String(order.get("shot_type", ""))
		if shot_type.is_empty(): continue
		if not _eligible_to_shoot(piece): continue
		var target_position: Vector2i = order.get("ranged_target", Vector2i(-1, -1))
		var target_id := int(order.get("ranged_target_id", -1))
		# Aimed fire follows the formation; suppressing fire hits whoever holds
		# the square. Either way the aim point is already spent.
		var target: Dictionary = {}
		if target_id >= 0:
			if target_id < pieces.size() and pieces[target_id].alive: target = pieces[target_id]
		else:
			target = piece_at(target_position)
		if not target.is_empty() and (are_allied_players(int(piece.player), int(target.player)) or target.type == FLAG):
			target = {}
		var shot_range := grid_distance(piece.position, target.position) if not target.is_empty() else -1
		var maximum_range := 1 if shot_type == SHOT_SHORT else 2
		if target.is_empty() or shot_range > maximum_range:
			fizzles.append({
				"shooter_id": int(piece.id), "from": piece.position, "to": target_position,
				"shot_type": shot_type, "target_id": target_id,
				"reason": "no_target" if target.is_empty() else "out_of_range",
			})
			continue
		var resolution := calculate_ranged(piece, target)
		# A long shot that finds its mark consumes everything the formation had.
		var extra_cost := 0
		if shot_type == SHOT_LONG:
			extra_cost = maxi(0, movement_limit_for(piece) - int(piece.movement_used) - int(piece.aim_spent))
		shots.append({"shooter_id": int(piece.id), "target_id": int(target.id), "from": piece.position, "to": target.position, "range": shot_range, "movement_cost": int(piece.aim_spent) + extra_cost, "resolution": resolution})
		pieces[piece.id].movement_used = int(pieces[piece.id].movement_used) + extra_cost
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
			"range": int(shot.range), "movement_cost": int(shot.movement_cost),
			"attacker_score": int(shot.resolution.attacker_score), "attacker_raw_roll": int(shot.resolution.attacker_raw_roll),
			"defender_damage": int(shot.resolution.defender_damage), "result": "ranged_destroyed" if not pieces[target_id].alive else "ranged_hit",
			"known_to": _battle_viewers_for_ids([shooter_id, target_id]),
		}
		# Trading fire identifies both parties, exactly as meeting in melee
		# does. An Archer that looses a shot has given itself away, and whoever
		# it hit has been seen closely enough to be named. Without this a
		# ranged duel could run all match with neither side learning what it
		# was shooting at, which melee never allows.
		for id in [shooter_id, target_id]:
			for viewer in event.known_to: reveal_piece_to(id, viewer)
		battle_history.append(event.duplicate(true))
		events.append(event)
	# A shot that found nothing still happened, and the aim point is still gone.
	# Reporting it keeps the log honest about why an Archer did not fire.
	for fizzle: Dictionary in fizzles:
		var fizzle_event := {
			"ok": true, "action": "ranged_fizzle", "batch": "ranged", "combat": false, "ranged": true,
			"from": fizzle.from, "to": fizzle.to, "shooter_id": int(fizzle.shooter_id),
			"target_id": int(fizzle.target_id), "shot_type": String(fizzle.shot_type),
			"movement_cost": AIM_COST, "result": String(fizzle.reason),
			"known_to": _battle_viewers_for_ids([int(fizzle.shooter_id)]),
		}
		battle_history.append(fizzle_event.duplicate(true))
		events.append(fizzle_event)
	return events


func _eligible_to_shoot(piece: Dictionary) -> bool:
	if not is_movable(piece) or piece.role != ROLE_ARCHER or String(piece.round_status) not in [STATUS_READY, STATUS_WON]:
		return false
	return not String(order_for_piece(int(piece.id)).get("shot_type", "")).is_empty()


## Points a formation has already committed this round, movement plus aiming.
func movement_committed(piece: Dictionary) -> int:
	return int(piece.movement_used) + int(piece.aim_spent)


func _eligible_for_leftover(piece: Dictionary) -> bool:
	# The fight-outcome gate (round_status) and the twice-fought cap apply
	# regardless of the toggle below - a Cavalry formation that lost still
	# doesn't get to reposition. Only the "movement left in the bank" check is
	# what the toggle bypasses.
	if not is_movable(piece) or String(piece.round_status) not in [STATUS_READY, STATUS_WON] or int(piece.melee_count) >= 2:
		return false
	if cavalry_always_leftover and piece.role == ROLE_CAVALRY:
		return true
	return movement_committed(piece) < movement_limit_for(piece)


func _movement_event(piece_id: int, from: Vector2i, to: Vector2i, batch_name: String) -> Dictionary:
	var viewers := _move_viewers(int(pieces[piece_id].player), from, to)
	last_move = {"from": from, "to": to, "visible_to": viewers.duplicate(), "action": "move"}
	return {"ok": true, "action": "move", "batch": batch_name, "combat": false, "piece_id": piece_id, "from": from, "to": to, "result": "move", "visible_to": viewers}


func _bounce_event(ids: Array[int], position: Vector2i, batch_name: String, reason: String) -> Dictionary:
	return {"ok": true, "action": "bounce", "batch": batch_name, "combat": false, "participants": ids, "to": position, "result": "bounce", "reason": reason}


## `may_retry` leaves the formation eligible to propose the same step again on
## a later impulse. Only a friendly blocker earns that: an enemy in the way is a
## repulse and ends the round, but one of your own standing there is a queue
## that may clear. round_status still becomes BOUNCED either way, so leftover
## eligibility is unchanged.
func _mark_bounced(piece_id: int, combat: bool, may_retry: bool = false) -> void:
	pieces[piece_id].round_status = STATUS_BOUNCED
	pieces[piece_id].main_done = not may_retry
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
	var result: int = _forced_rolls.pop_front() if not _forced_rolls.is_empty() else _rng.randi_range(1, 10)
	_roll_history.append(result)
	return result


func _encode_main_orders() -> Array[Dictionary]:
	var encoded: Array[Dictionary] = []
	for player in PLAYER_ORDER:
		var ids: Array = orders.get(player, {}).keys()
		ids.sort()
		for id_value in ids:
			var piece_id := int(id_value)
			var order: Dictionary = orders[player][piece_id]
			var path: Array = []
			for position: Vector2i in order.get("path", []):
				path.append(_encode_position(position))
			encoded.append({
				"player": player,
				"piece_id": piece_id,
				"path": path,
				"ranged_target": _encode_position(order.get("ranged_target", Vector2i(-1, -1))),
				"ranged_target_id": int(order.get("ranged_target_id", -1)),
				"leftover": _encode_position(order.get("leftover", Vector2i(-1, -1))),
			})
	return encoded


func _encode_leftover_orders() -> Array[Dictionary]:
	var encoded: Array[Dictionary] = []
	for player in PLAYER_ORDER:
		var ids: Array = orders.get(player, {}).keys()
		ids.sort()
		for id_value in ids:
			var piece_id := int(id_value)
			var target: Vector2i = orders[player][piece_id].get("leftover", Vector2i(-1, -1))
			if target.x >= 0:
				encoded.append({"player": player, "piece_id": piece_id, "target": _encode_position(target)})
	return encoded


static func _encode_position(position: Vector2i) -> Array[int]:
	return [position.x, position.y]


static func _decode_position(value: Variant) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


static func _json_safe(value: Variant) -> Variant:
	if value is Vector2i:
		return _encode_position(value)
	if value is Dictionary:
		var converted := {}
		var keys: Array = value.keys()
		keys.sort_custom(func(first: Variant, second: Variant) -> bool: return str(first) < str(second))
		for key in keys:
			converted[str(key)] = _json_safe(value[key])
		return converted
	if value is Array:
		var converted: Array = []
		for item in value:
			converted.append(_json_safe(item))
		return converted
	return value


## Legal single steps out of a cell: on-board, passable, ignoring occupancy.
## Occupancy is deliberately not filtered, because moving into an occupied
## square is how attacks happen.
func legal_steps_for(piece_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if piece_id < 0 or piece_id >= pieces.size(): return result
	for candidate: Vector2i in neighbors(pieces[piece_id].position):
		if is_inside(candidate) and not is_blocked_terrain(candidate): result.append(candidate)
	return result


## Per-formation combat totals for the whole match, derived from battle_history.
##
## Combat events record damage taken, not dealt, so dealt is attributed by the
## same rule the resolver uses: a formation takes damage from the highest
## opposing score, so that opponent is credited. Ranged events name their
## shooter directly and need no inference.
func combat_damage_summary() -> Dictionary:
	var totals: Dictionary = {}
	for piece: Dictionary in pieces:
		totals[int(piece.id)] = {
			"id": int(piece.id), "code": String(piece.type), "player": int(piece.player),
			"dealt": 0, "taken": 0, "kills": 0, "battles": 0,
			"alive": bool(piece.alive), "strength": int(piece.strength),
			"max_strength": int(piece.max_strength),
		}
	# Focus fire reports every contributing shot as destroying the target, so
	# credit the kill once rather than to each shooter.
	var ranged_kill_counted: Dictionary = {}
	for event: Dictionary in battle_history:
		if String(event.get("action", "")) == "ranged_fizzle": continue
		if bool(event.get("ranged", false)):
			var shooter := int(event.get("shooter_id", EMPTY))
			var target := int(event.get("target_id", EMPTY))
			var shot_damage := int(event.get("defender_damage", 0))
			if shooter in totals:
				totals[shooter].dealt += shot_damage
				totals[shooter].battles += 1
				if String(event.get("result", "")) == "ranged_destroyed" and target not in ranged_kill_counted:
					ranged_kill_counted[target] = true
					totals[shooter].kills += 1
			if target in totals:
				totals[target].taken += shot_damage
				totals[target].battles += 1
			continue
		var scores: Dictionary = event.get("scores", {})
		var damage: Dictionary = event.get("damage", {})
		var outcomes: Dictionary = event.get("outcomes", {})
		var participants: Array = event.get("participants", [])
		for participant in participants:
			var id := int(participant)
			if id in totals: totals[id].battles += 1
		for key in damage:
			var victim := int(key)
			var amount := int(damage[key])
			if amount <= 0: continue
			if victim in totals: totals[victim].taken += amount
			var dealer := EMPTY
			var best_score := -1
			for participant in participants:
				var other := int(participant)
				if other == victim or _team_for_piece(other) == _team_for_piece(victim): continue
				var other_score := int(scores.get(str(other), scores.get(other, -1)))
				if other_score > best_score:
					best_score = other_score
					dealer = other
			if dealer in totals:
				totals[dealer].dealt += amount
				if String(outcomes.get(str(victim), outcomes.get(victim, ""))) == "destroyed":
					totals[dealer].kills += 1
	return totals


## Movement a formation can still be ordered to spend right now.
##
## piece.movement_used is only reset by _begin_round_state(), which runs at the
## start of resolve_main_and_ranged() rather than at the end of the round, so
## during PHASE_PLANNING it still holds the previous round's total. Nothing in
## the engine is misled by that (order validation compares path length against
## the movement limit, and resolution resets before it reads the value), but an
## external controller reading the raw field during planning would compute the
## wrong budget.
func _movement_available_for(piece: Dictionary) -> int:
	if phase == PHASE_PLANNING: return movement_limit_for(piece)
	return maxi(0, movement_limit_for(piece) - movement_committed(piece))


## Full-truth board state for an external controller. The player argument is
## the viewer; it is currently unused because this view is omniscient, but it
## keeps the signature stable for a later fog-limited variant.
func observed_state(player: int) -> Dictionary:
	var formations: Array = []
	for piece: Dictionary in pieces:
		if not piece.alive: continue
		var order: Dictionary = order_for_piece(int(piece.id))
		var path: Array = []
		for step: Vector2i in order.get("path", []): path.append(_encode_position(step))
		formations.append({
			"id": int(piece.id), "code": String(piece.type), "player": int(piece.player),
			"mine": int(piece.player) == player, "role": String(piece.role), "weight": String(piece.weight),
			"strength": int(piece.strength), "max_strength": int(piece.max_strength),
			"armor": int(piece.armor), "movement": movement_limit_for(piece),
			"movement_used": int(piece.movement_used),
			"movement_available": _movement_available_for(piece),
			"position": _encode_position(piece.position),
			"status": String(piece.round_status), "main_done": bool(piece.main_done),
			"planned_path": path,
			"planned_ranged": _encode_position(order.get("ranged_target", Vector2i(-1, -1))),
			"planned_ranged_id": int(order.get("ranged_target_id", -1)),
			"shot_type": String(order.get("shot_type", "")),
			"aim_spent": int(piece.aim_spent),
			"planned_leftover": _encode_position(order.get("leftover", Vector2i(-1, -1))),
		})
	var terrain := {"lakes": [], "water": [], "bridge": []}
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var cell := Vector2i(x, y)
			if is_bridge(cell): terrain.bridge.append(_encode_position(cell))
			elif is_lake(cell): terrain.lakes.append(_encode_position(cell))
			elif is_water(cell): terrain.water.append(_encode_position(cell))
	var state := {
		"fog": false, "viewer": player, "board_size": BOARD_SIZE,
		"scenario": scenario, "round": round_number, "turn": turn_number, "phase": phase,
		"active_players": active_players, "eliminated_players": eliminated_players,
		"ready_players": ready_players, "game_over": game_over, "winner": winner,
		"end_reason": end_reason, "terrain": terrain, "formations": formations,
	}
	if scenario == SCENARIO_BRIDGE:
		state["objective"] = {
			"attacker": bridge_attacker, "defender": bridge_defender,
			"river_y": BRIDGE_RIVER_Y, "turn_limit": bridge_turn_limit,
			"strength_target": bridge_strength_target,
			"attacker_strength_across": bridge_strength_across(),
		}
	if not objectives.is_empty(): state["objectives"] = describe_objectives()
	return state


## Objectives as plain data with their current progress, one entry per
## objective. Each carries a one-line `summary` so an external controller can
## state the win condition without knowing the scenario.
func describe_objectives() -> Array:
	var described: Array = []
	for index in objectives.size():
		var objective: Dictionary = objectives[index]
		var kind := String(objective.type)
		var entry := {"type": kind}
		if kind == OBJECTIVE_HOLD_SQUARE:
			var streaks: Dictionary = {}
			for candidate in active_players: streaks[candidate] = objective_streak(index, candidate)
			entry["square"] = _encode_position(objective.square)
			entry["rounds_required"] = int(objective.rounds)
			entry["turn_limit"] = int(objective.turn_limit)
			entry["consecutive_rounds_held"] = streaks
			entry["summary"] = "Hold %s alone at the end of %d consecutive rounds. A draw if nobody has by round %d." % [
				str(objective.square), int(objective.rounds), int(objective.turn_limit),
			]
		elif kind == OBJECTIVE_REACH_AREA:
			var area: Rect2i = objective.area
			var owner := int(objective.player)
			entry["player"] = owner
			entry["area"] = [area.position.x, area.position.y, area.size.x, area.size.y]
			entry["strength_required"] = int(objective.strength)
			entry["strength_present"] = strength_in_area(owner, area)
			entry["summary"] = "%s wins with %d Strength inside rows %d-%d at the end of a round (currently %d)." % [
				player_name(owner), int(objective.strength), area.position.y, area.end.y - 1, strength_in_area(owner, area),
			]
		elif kind == OBJECTIVE_ELIMINATE:
			entry["turn_limit"] = int(objective.turn_limit)
			entry["summary"] = "Destroy the opposing army. A draw if both survive to the end of round %d." % int(objective.turn_limit)
		elif kind == OBJECTIVE_SURVIVE:
			entry["player"] = int(objective.player)
			entry["until_round"] = int(objective.until_round)
			entry["summary"] = "%s wins by still standing at the end of round %d." % [
				player_name(int(objective.player)), int(objective.until_round),
			]
		described.append(entry)
	return described


static func _digest_value(value: Variant) -> String:
	return JSON.stringify(_json_safe(value)).sha256_text()


func state_digest() -> String:
	var piece_state: Array = []
	for piece: Dictionary in pieces:
		var seen_by: Array = piece.get("seen_by", []).duplicate()
		var revealed_to: Array = piece.get("revealed_to", []).duplicate()
		seen_by.sort()
		revealed_to.sort()
		piece_state.append({
			"id": int(piece.id), "type": String(piece.type), "player": int(piece.player),
			"strength": int(piece.strength), "max_strength": int(piece.max_strength), "alive": bool(piece.alive),
			"position": _encode_position(piece.position), "previous_position": _encode_position(piece.previous_position),
			"round_status": String(piece.round_status), "movement_used": int(piece.movement_used),
			"melee_count": int(piece.melee_count), "main_done": bool(piece.main_done),
			"move_count": int(piece.move_count), "seen_by": seen_by, "revealed_to": revealed_to,
		})
	var teams: Array = []
	for player in PLAYER_ORDER:
		if player in player_teams:
			teams.append([player, int(player_teams[player])])
	return _digest_value({
		"scenario": scenario, "round": round_number, "turn": turn_number, "phase": phase,
		"game_over": game_over, "winner": winner, "winning_team": winning_team, "end_reason": end_reason,
		"withdrawing_player": withdrawing_player, "active_players": active_players,
		"eliminated_players": eliminated_players, "teams": teams, "pieces": piece_state,
	})


func build_replay_document() -> Dictionary:
	if phase not in [PHASE_PLANNING, PHASE_GAME_OVER]:
		return {}
	var teams: Array = []
	for player in PLAYER_ORDER:
		if player in player_teams:
			teams.append([player, int(player_teams[player])])
	return {
		"format": REPLAY_FORMAT,
		"version": REPLAY_VERSION,
		"setup": {
			"scenario": scenario, "seed": setup_seed, "player_count": configured_player_count,
			"private_battle_results": private_battle_results, "vision_range": vision_range,
			"bridge_attacker": bridge_attacker, "bridge_defender": bridge_defender,
			"bridge_turn_limit": bridge_turn_limit, "bridge_strength_target": bridge_strength_target,
			"meeting_hold_rounds": _meeting_hold_rounds, "meeting_turn_limit": _meeting_turn_limit,
			"skirmish_turn_limit": _skirmish_turn_limit, "skirmish_separation": _skirmish_separation,
			"teams": teams, "deployment": deployment_placements.duplicate(true),
		},
		"rounds": replay_rounds.duplicate(true),
		"terminal": {
			"game_over": game_over, "winner": winner, "end_reason": end_reason,
			"withdrawal_player": withdrawing_player,
		},
		"final_state_digest": state_digest(),
	}


func save_replay(path: String) -> Dictionary:
	var document := build_replay_document()
	if document.is_empty():
		return {"ok": false, "message": "Replays can be exported between rounds or after the battle."}
	var absolute_path := ProjectSettings.globalize_path(path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK:
		return {"ok": false, "message": "Could not create the replay folder."}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Could not open the replay file for writing."}
	file.store_string(JSON.stringify(document, "  "))
	file.close()
	return {"ok": true, "path": absolute_path, "rounds": replay_rounds.size(), "digest": String(document.final_state_digest)}


static func load_replay_document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "message": "No replay file exists at that location."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "Could not open the replay file."}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is not Dictionary:
		return {"ok": false, "message": "The replay file is not valid JSON replay data."}
	return {"ok": true, "document": parsed}


func apply_replay_main_orders(encoded_orders: Array) -> Dictionary:
	if phase != PHASE_PLANNING or not ready_players.is_empty():
		return {"ok": false, "message": "Main replay orders require an open planning phase."}
	orders.clear()
	var candidates: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	for entry_value in encoded_orders:
		if entry_value is not Dictionary:
			return {"ok": false, "message": "A recorded main order is malformed."}
		var entry: Dictionary = entry_value
		var player := int(entry.get("player", DRAW))
		var piece_id := int(entry.get("piece_id", EMPTY))
		if piece_id in seen_ids or piece_id < 0 or piece_id >= pieces.size() or int(pieces[piece_id].player) != player:
			return {"ok": false, "message": "A recorded main order references an invalid formation."}
		seen_ids[piece_id] = true
		var path: Array[Vector2i] = []
		for position_value in entry.get("path", []):
			path.append(_decode_position(position_value))
		var candidate := {
			"piece_id": piece_id, "player": player, "path": path,
			"ranged_target": _decode_position(entry.get("ranged_target", [-1, -1])),
			"ranged_target_id": int(entry.get("ranged_target_id", -1)),
			"leftover": _decode_position(entry.get("leftover", [-1, -1])),
		}
		if player not in orders:
			orders[player] = {}
		orders[player][piece_id] = candidate
		candidates.append(candidate)
	for candidate: Dictionary in candidates:
		var result := set_unit_order(int(candidate.player), int(candidate.piece_id), candidate.path, candidate.ranged_target, candidate.leftover, int(candidate.ranged_target_id))
		if not bool(result.get("ok", false)):
			orders.clear()
			return {"ok": false, "message": "Recorded main order rejected: %s" % String(result.get("message", "invalid order"))}
	return {"ok": true, "count": candidates.size()}


func apply_replay_leftover_orders(encoded_orders: Array) -> Dictionary:
	if phase != PHASE_LEFTOVER_PLANNING or not ready_players.is_empty():
		return {"ok": false, "message": "Leftover replay orders require an open leftover phase."}
	for player in active_players:
		clear_player_orders(player)
	var seen_ids: Dictionary = {}
	var touched_players: Array[int] = []
	for entry_value in encoded_orders:
		if entry_value is not Dictionary:
			return {"ok": false, "message": "A recorded leftover order is malformed."}
		var entry: Dictionary = entry_value
		var player := int(entry.get("player", DRAW))
		var piece_id := int(entry.get("piece_id", EMPTY))
		var target := _decode_position(entry.get("target", [-1, -1]))
		if piece_id in seen_ids or not can_receive_leftover_order(player, piece_id):
			return {"ok": false, "message": "A recorded leftover order references an ineligible formation."}
		if not are_adjacent(pieces[piece_id].position, target) or not is_inside(target) or is_blocked_terrain(target):
			return {"ok": false, "message": "A recorded leftover destination is invalid."}
		seen_ids[piece_id] = true
		if player not in orders:
			orders[player] = {}
		var candidate: Dictionary = order_for_piece(piece_id).duplicate(true)
		if candidate.is_empty():
			candidate = {"piece_id": piece_id, "player": player, "path": [], "ranged_target": Vector2i(-1, -1)}
		candidate.leftover = target
		orders[player][piece_id] = candidate
		if player not in touched_players:
			touched_players.append(player)
	for player in touched_players:
		if not _same_player_leftover_orders_are_clear(player):
			return {"ok": false, "message": "Recorded leftover orders contain a friendly collision."}
	return {"ok": true, "count": seen_ids.size()}


static func _decode_rolls(values: Array) -> Array[int]:
	var rolls: Array[int] = []
	for value in values:
		var roll := int(value)
		if roll < 1 or roll > 10:
			return []
		rolls.append(roll)
	return rolls


static func _game_from_replay_setup(document: Dictionary) -> Dictionary:
	if String(document.get("format", "")) != REPLAY_FORMAT or int(document.get("version", 0)) != REPLAY_VERSION:
		return {"ok": false, "message": "Unsupported replay format or version."}
	var setup: Dictionary = document.get("setup", {})
	var replay_game := StrategoGame.new()
	var replay_scenario := String(setup.get("scenario", ""))
	var seed := int(setup.get("seed", 0))
	var privacy := bool(setup.get("private_battle_results", true))
	if replay_scenario == SCENARIO_BRIDGE:
		replay_game.setup_bridge(seed, int(setup.get("bridge_attacker", BLUE)), int(setup.get("bridge_defender", RED)), int(setup.get("bridge_turn_limit", DEFAULT_BRIDGE_TURN_LIMIT)), privacy)
		replay_game.bridge_strength_target = int(setup.get("bridge_strength_target", BRIDGE_STRENGTH_TARGET))
	elif replay_scenario == SCENARIO_MEETING:
		replay_game.setup_meeting(seed, BLUE, RED, int(setup.get("meeting_hold_rounds", DEFAULT_HOLD_ROUNDS)), int(setup.get("meeting_turn_limit", DEFAULT_BRIDGE_TURN_LIMIT)), privacy)
	elif replay_scenario == SCENARIO_SKIRMISH:
		replay_game.setup_skirmish(seed, MEETING_ROSTER, MEETING_ROSTER, int(setup.get("skirmish_separation", 3)), int(setup.get("skirmish_turn_limit", 40)), privacy)
	elif replay_scenario == SCENARIO_FOUR_PLAYER:
		replay_game.setup_random(seed, int(setup.get("player_count", 4)), privacy)
	elif replay_scenario == SCENARIO_CROSSROADS:
		replay_game.setup_crossroads(seed, DEFAULT_HOLD_ROUNDS, 30, privacy)
		# The seed alone reproduces the recommended formation, not wherever a
		# player actually dragged pieces to, so recorded deployment is applied
		# directly and deployment is closed out rather than replayed
		# interactively.
		for id_key in setup.get("deployment", {}):
			var piece_id := int(id_key)
			if piece_id < 0 or piece_id >= replay_game.pieces.size(): continue
			replay_game.redeploy_piece(int(replay_game.pieces[piece_id].player), piece_id, _decode_position(setup.deployment[id_key]))
		for player in replay_game.active_players: replay_game.mark_player_ready(player)
		replay_game.resolve_deployment()
	else:
		return {"ok": false, "message": "The replay uses an unsupported scenario."}
	replay_game.vision_range = int(setup.get("vision_range", DEFAULT_VISION_RANGE))
	for team_value in setup.get("teams", []):
		if team_value is Array and team_value.size() == 2:
			replay_game.set_player_team(int(team_value[0]), int(team_value[1]))
	return {"ok": true, "game": replay_game}


static func run_replay(document: Dictionary) -> Dictionary:
	var setup_result := _game_from_replay_setup(document)
	if not bool(setup_result.get("ok", false)):
		return setup_result
	var replay_game: StrategoGame = setup_result.game
	var all_events: Array[Dictionary] = []
	for round_value in document.get("rounds", []):
		if round_value is not Dictionary:
			return {"ok": false, "message": "A replay round is malformed."}
		var round_record: Dictionary = round_value
		if replay_game.round_number != int(round_record.get("round", -1)):
			return {"ok": false, "message": "Replay round numbering does not match the simulation."}
		var main_order_result := replay_game.apply_replay_main_orders(round_record.get("main_orders", []))
		if not bool(main_order_result.get("ok", false)):
			return main_order_result
		var main_roll_values: Array = round_record.get("main_rolls", [])
		var main_rolls := _decode_rolls(main_roll_values)
		if main_rolls.size() != main_roll_values.size():
			return {"ok": false, "message": "Replay contains an invalid main-phase die roll."}
		replay_game.set_forced_rolls(main_rolls)
		for player in replay_game.active_players:
			replay_game.mark_player_ready(player)
		var roll_start := replay_game._roll_history.size()
		var main_events := replay_game.resolve_main_and_ranged()
		if replay_game._roll_history.size() - roll_start != main_rolls.size():
			return {"ok": false, "message": "Replay main-phase dice consumption diverged."}
		if String(round_record.get("main_event_digest", "")) != _digest_value(main_events) or String(round_record.get("main_state_digest", "")) != replay_game.state_digest():
			return {"ok": false, "message": "Replay diverged during the main or ranged phase of round %d." % replay_game.round_number}
		all_events.append_array(main_events)
		var leftover_order_result := replay_game.apply_replay_leftover_orders(round_record.get("leftover_orders", []))
		if not bool(leftover_order_result.get("ok", false)):
			return leftover_order_result
		var leftover_roll_values: Array = round_record.get("leftover_rolls", [])
		var leftover_rolls := _decode_rolls(leftover_roll_values)
		if leftover_rolls.size() != leftover_roll_values.size():
			return {"ok": false, "message": "Replay contains an invalid leftover-phase die roll."}
		replay_game.set_forced_rolls(leftover_rolls)
		for player in replay_game.active_players:
			replay_game.mark_player_ready(player)
		roll_start = replay_game._roll_history.size()
		var leftover_events := replay_game.resolve_leftover_phase()
		if replay_game._roll_history.size() - roll_start != leftover_rolls.size():
			return {"ok": false, "message": "Replay leftover-phase dice consumption diverged."}
		if String(round_record.get("leftover_event_digest", "")) != _digest_value(leftover_events) or String(round_record.get("final_state_digest", "")) != replay_game.state_digest():
			return {"ok": false, "message": "Replay diverged during leftover movement in round %d." % int(round_record.get("round", -1))}
		all_events.append_array(leftover_events)
	var terminal: Dictionary = document.get("terminal", {})
	var withdrawal := int(terminal.get("withdrawal_player", DRAW))
	if withdrawal != DRAW and not replay_game.game_over:
		var withdrawal_result := replay_game.withdraw_player(withdrawal)
		if not bool(withdrawal_result.get("ok", false)):
			return {"ok": false, "message": "Replay withdrawal could not be reproduced."}
	if String(document.get("final_state_digest", "")) != replay_game.state_digest():
		return {"ok": false, "message": "Replay final-state verification failed."}
	return {"ok": true, "game": replay_game, "events": all_events, "rounds": document.get("rounds", []).size(), "digest": replay_game.state_digest()}


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
	if not game_over: _finish_if_army_destroyed()
	if not game_over: _check_objectives()
	if not game_over and _is_four_corner_scenario(): _finish_if_one_team_remains()
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
	if not _is_four_corner_scenario(): return
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
	# Every corner's formation already exists once deployment begins (see
	# setup_crossroads), so ordinary piece-radius vision would leak a glimpse of
	# a neighbouring zone. During deployment a player can only see their own
	# zone, full stop — not the squares nearest whichever formations they
	# happen to have already placed.
	if phase == PHASE_DEPLOYMENT: return position in deployment_zone_cells(player)
	_ensure_visibility_cache()
	return position in _visible_cells_by_player.get(player, {})


func _ensure_visibility_cache() -> void:
	if not _visibility_dirty and _cached_vision_range == vision_range: return
	_visible_cells_by_player.clear()
	for player in PLAYER_ORDER: _visible_cells_by_player[player] = {}
	for piece: Dictionary in pieces:
		if not piece.alive: continue
		var visible_cells: Dictionary = _visible_cells_by_player[int(piece.player)]
		for visible_position: Vector2i in cells_within_range(piece.position, vision_range):
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
