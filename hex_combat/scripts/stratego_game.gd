class_name StrategoGame
extends RefCounted

const BOARD_SIZE := 20
const GRID_TYPE := "hex_odd_q_flat"
const DEFAULT_VISION_RANGE := 4

## Board topology is flat-top, odd-column offset hexes. Coordinates remain
## Vector2i(column, row); HexGrid owns every adjacency and distance operation.
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
## Every combat die is a d6, and a formation keeps only the single highest die
## from its pool. Bonus dice therefore buy reliability, never a bigger ceiling:
## the most any pool can score off the die is 6, no matter how many it rolls.
const COMBAT_DIE_FACES := 6
## A pool always contains at least this many dice, before any bonus dice.
const COMBAT_BASE_DICE := 1
## Ordering used by the comparative "heavier than your opponent" bonus die.
## Deliberately a rank, not a stat: only which side is heavier matters, so two
## Heavies fighting each other both come away with nothing from it.
const WEIGHT_RANK := {WEIGHT_LIGHT: 0, WEIGHT_MEDIUM: 1, WEIGHT_HEAVY: 2}

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
const SCENARIO_CAMPAIGN := "campaign"
const OBJECTIVE_REACH_AREA := "reach_area"
const OBJECTIVE_SURVIVE := "survive"
const SCENARIO_MEETING := "meeting"
const SCENARIO_HIGHFIELD := "highfield"
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
const STATUS_READY := "ready"
const STATUS_WON := "won"
const STATUS_LOST := "lost"
const STATUS_BOUNCED := "bounced"

const BRIDGE_RIVER_Y := 9
const BRIDGE_COLUMNS := [8, 9, 10, 11]
const BRIDGE_STRENGTH_TARGET := 20
const DEFAULT_BRIDGE_TURN_LIMIT := 20
const REPLAY_FORMAT := "wego-formations-replay"
const REPLAY_VERSION := 9

const MOVEMENT_BY_WEIGHT := {WEIGHT_LIGHT: 3, WEIGHT_MEDIUM: 2, WEIGHT_HEAVY: 1}
const PIECE_DEFINITIONS := {
	FLAG: {"name": "Flag", "role": "", "weight": "", "strength": 0},
	# Strength is deliberately uniform across Weight. Weight is its own lever
	# (movement speed and the comparative "heavier" combat die, a rank not a
	# stat); Strength is damage and the thing veterancy and wounds move. A fresh
	# fight is decided by Weight, Role, and dice, and Strength differences only
	# emerge once someone has been hurt. Scenarios and the campaign set explicit
	# per-formation Strength; this table is only the healthy default.
	LIGHT_INFANTRY: {"name": "Light Infantry", "role": ROLE_INFANTRY, "weight": WEIGHT_LIGHT, "strength": 7},
	MEDIUM_INFANTRY: {"name": "Medium Infantry", "role": ROLE_INFANTRY, "weight": WEIGHT_MEDIUM, "strength": 7},
	HEAVY_INFANTRY: {"name": "Heavy Infantry", "role": ROLE_INFANTRY, "weight": WEIGHT_HEAVY, "strength": 7},
	LIGHT_ARCHER: {"name": "Light Archer", "role": ROLE_ARCHER, "weight": WEIGHT_LIGHT, "strength": 7},
	MEDIUM_ARCHER: {"name": "Medium Archer", "role": ROLE_ARCHER, "weight": WEIGHT_MEDIUM, "strength": 7},
	HEAVY_ARCHER: {"name": "Heavy Archer", "role": ROLE_ARCHER, "weight": WEIGHT_HEAVY, "strength": 7},
	LIGHT_CAVALRY: {"name": "Light Cavalry", "role": ROLE_CAVALRY, "weight": WEIGHT_LIGHT, "strength": 7},
	MEDIUM_CAVALRY: {"name": "Medium Cavalry", "role": ROLE_CAVALRY, "weight": WEIGHT_MEDIUM, "strength": 7},
	HEAVY_CAVALRY: {"name": "Heavy Cavalry", "role": ROLE_CAVALRY, "weight": WEIGHT_HEAVY, "strength": 7},
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
## Highfield: an asymmetric standard scenario. Both sides fight for one central
## hill (the hold objective), but the two armies are built to opposite theories
## of war. Every formation starts at the same Strength; the difference is Weight,
## Role, and numbers, so this is a clean test of those levers rather than a
## strength-total race. Verified near-even bot-vs-bot (~51/49 over 200 games).
##
## RED, the Wardens: seven heavy formations - heavy foot and two Heavy Archers
## around a Heavy Cavalry, with a medium pair. Wins by attrition and by holding
## ground as an intact wall the light horse cannot break; slow, few, and beaten
## if it advances piecemeal into numbers. Deployed as a tight block. Entries are
## [type, column, row].
##
## BLUE, the Outriders: nine fast formations - a medium core with light horse on
## the wings and two bows behind. Wins by reaching the hill first, flanking, and
## massing on the objective; loses a straight slug and cannot out-attrition the
## Wardens. Two more bodies than the Wardens, and faster, which is the whole edge.
const HIGHFIELD_OBJECTIVE := Vector2i(10, 10)
const HIGHFIELD_WARDENS := [
	[HEAVY_INFANTRY, 9, 5], [HEAVY_CAVALRY, 10, 5], [HEAVY_INFANTRY, 11, 5],
	[HEAVY_ARCHER, 9, 4], [MEDIUM_INFANTRY, 10, 4], [HEAVY_ARCHER, 11, 4],
	[MEDIUM_CAVALRY, 12, 5],
]
const HIGHFIELD_OUTRIDERS := [
	[MEDIUM_INFANTRY, 9, 14], [MEDIUM_INFANTRY, 10, 14], [MEDIUM_INFANTRY, 11, 14],
	[MEDIUM_CAVALRY, 8, 14], [MEDIUM_CAVALRY, 12, 14],
	[LIGHT_CAVALRY, 7, 14], [LIGHT_CAVALRY, 13, 14],
	[LIGHT_ARCHER, 8, 15], [MEDIUM_ARCHER, 10, 15],
]
const LAKES := [
	Vector2i(7, 7), Vector2i(8, 7), Vector2i(11, 7), Vector2i(12, 7),
	Vector2i(7, 8), Vector2i(8, 8), Vector2i(11, 8), Vector2i(12, 8),
	Vector2i(7, 11), Vector2i(8, 11), Vector2i(11, 11), Vector2i(12, 11),
	Vector2i(7, 12), Vector2i(8, 12), Vector2i(11, 12), Vector2i(12, 12),
]

var board: Array = []
var terrain: Dictionary = {}
## The raw scenario description CampaignScenario.apply() was built from, kept
## so a replay of a campaign battle can be reconstructed exactly rather than
## falling back to a generic scenario with the wrong army in it.
var campaign_battle_data: Dictionary = {}
var objectives: Array[Dictionary] = []
var pieces: Array[Dictionary] = []
var active_players: Array[int] = []
var eliminated_players: Array[int] = []
var player_teams: Dictionary = {}
var orders: Dictionary = {}
var ready_players: Array[int] = []
var battle_history: Array[Dictionary] = []
var last_round_events: Array[Dictionary] = []
## Main-phase contacts held open until every impulse has moved, and the hexes
## they cover mapped back to them so a later arrival joins the fight standing
## there instead of reading it as ordinary ground. Both are empty outside the
## main movement phase, which still resolves its one wave of contact on the spot.
var _pending_battles: Array[Dictionary] = []
var _contested_hexes: Dictionary = {}
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
## Experimental, off by default: when a melee's top score is tied and one of
## the tied formations is the defender (not the one that moved into the
## square), the defender wins instead of the tie bouncing everyone off with
## no result. A genuine three-or-more-way tie, or a tie among formations that
## are all attackers, still bounces regardless - this only resolves the
## specific case of an attacker matching the defender's score exactly.
var defender_wins_ties := false
## Experimental, off by default: narrower than defender_wins_ties. Only
## resolves a tie in the defender's favor when the tied attacker is Cavalry -
## "braced against the charge." Cavalry-attacks-Infantry is the one matchup
## where both sides' role bonuses are identical (+3 each) and so cancel,
## leaving a tie a pure coin flip with no defensive edge at all; this fixes
## just that case. Infantry-attacks-Infantry (where the attacker already has
## no bonus) and every other matchup are untouched. Composable with, but
## independent from, defender_wins_ties - if both are on, defender_wins_ties
## already covers this case and this flag adds nothing further.
var defender_resists_charge_ties := false
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


## Highfield: two asymmetric armies fight for one central hill. See the roster
## constants above for the design. Terrain is deliberately bare so the result
## reflects the composition matchup, not a map that favours one theory of war.
func setup_highfield(seed_value: int = 0, hold_rounds: int = DEFAULT_HOLD_ROUNDS, turn_limit: int = 18, use_private_battle_results: bool = true) -> void:
	setup_empty()
	scenario = SCENARIO_HIGHFIELD
	configured_player_count = 2
	private_battle_results = use_private_battle_results
	player_teams[BLUE] = BLUE
	player_teams[RED] = RED
	_seed_rng(seed_value)
	set_terrain(HIGHFIELD_OBJECTIVE, TERRAIN_OPEN)
	for entry in HIGHFIELD_WARDENS:
		add_piece(String(entry[0]), RED, Vector2i(int(entry[1]), int(entry[2])))
	for entry in HIGHFIELD_OUTRIDERS:
		add_piece(String(entry[0]), BLUE, Vector2i(int(entry[1]), int(entry[2])))
	add_hold_square_objective(HIGHFIELD_OBJECTIVE, hold_rounds, turn_limit)
	active_players.assign([RED, BLUE])
	_sort_active_players()
	current_player = BLUE
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
	# Split around the board's true centre, (BOARD_SIZE - 1) / 2.0, not the
	# integer-truncated BOARD_SIZE / 2 - that truncation was already half a
	# cell off, and adding (separation + 1) / 2 on top of it compounded into a
	# full extra cell favouring Blue at every odd separation (the default is
	# 3), which turned out to be strong enough to decide ~90% of games on its
	# own regardless of army composition. This form keeps blue_row - red_row
	# exactly equal to separation while splitting the leftover as evenly as
	# integer rows allow.
	var blue_row := clampi((BOARD_SIZE - 1 + _skirmish_separation) / 2, 0, BOARD_SIZE - 1)
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
		"strength": starting_strength, "max_strength": starting_strength,
		"position": position, "previous_position": position, "alive": true, "revealed_to": [], "seen_by": [],
		"round_status": STATUS_READY, "movement_used": 0, "steps_taken": 0, "melee_count": 0, "participated_in_combat": false,
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
## Every shot may be declared at range 1 or 2 during the post-clash action
## phase. Targets must be visible: no blind fire into fog.
func _declared_shot_type(piece: Dictionary, player: int, path: Array[Vector2i], target: Vector2i, target_id: int) -> Dictionary:
	if piece.role != ROLE_ARCHER:
		return {"ok": false, "message": "Only Archers can receive ranged orders."}
	if not is_inside(target) or is_blocked_terrain(target):
		return {"ok": false, "message": "Archers cannot target that hex."}
	if target_id >= 0:
		if target_id >= pieces.size() or not pieces[target_id].alive:
			return {"ok": false, "message": "That formation is no longer on the battlefield."}
		var aimed: Dictionary = pieces[target_id]
		if are_allied_players(player, int(aimed.player)):
			return {"ok": false, "message": "Archers cannot target an allied formation."}
		if not is_piece_visible_to(aimed, player):
			return {"ok": false, "message": "Archers can only target a formation they can see."}
	elif not is_position_visible_to(target, player):
		return {"ok": false, "message": "Archers can only target a hex they can see."}
	var declared_range := grid_distance(piece.position, target)
	if declared_range == 0:
		return {"ok": false, "message": "Archers cannot target their own hex."}
	if declared_range > 2:
		return {"ok": false, "message": "Archers can only target a hex within range 2."}
	return {"ok": true, "shot_type": SHOT_SHORT if declared_range == 1 else SHOT_LONG}


## Support is the same order as walking into an ally's hex, made deliberate.
## The resolver has joined a friendly hex with a fight open on it ever since
## melee started waiting for every impulse, so the move already meant this; what
## was missing was a way to ask for it, because planning refuses a step into your
## own line and cannot tell an intended reinforcement from a misclick.
##
## Nothing about resolution changes. If a fight is open on the hex when the
## formation arrives it joins as support, and if the hex is quiet it bounces off
## its ally exactly as it always did.
func set_support_order(player: int, piece_id: int, target: Vector2i) -> Dictionary:
	if piece_id < 0 or piece_id >= pieces.size(): return {"ok": false, "message": "Unknown formation."}
	var piece: Dictionary = pieces[piece_id]
	if not are_adjacent(piece.position, target):
		return {"ok": false, "message": "Support is one adjacent hex."}
	var occupant := piece_at(target)
	if occupant.is_empty() or not are_allied_players(player, int(occupant.player)):
		return {"ok": false, "message": "Support has to be aimed at a formation on your own side."}
	return set_unit_order(player, piece_id, [target], Vector2i(-1, -1), Vector2i(-1, -1), -1, true, true)


func set_unit_order(player: int, piece_id: int, path: Array, ranged_target: Vector2i = Vector2i(-1, -1), leftover: Vector2i = Vector2i(-1, -1), ranged_target_id: int = -1, strict_friendly: bool = true, support: bool = false) -> Dictionary:
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
			return {"ok": false, "message": "Paths must use adjacent passable hexes."}
		normalized_path.append(step)
		previous = step
	if ranged_target.x >= 0:
		return {"ok": false, "message": "Ranged attacks are chosen during reposition."}
	if leftover.x >= 0:
		return {"ok": false, "message": "Reposition orders are chosen after the main clash."}
	if normalized_path.size() > movement_limit_for(piece):
		return {"ok": false, "message": "That order exceeds the formation's movement allowance."}
	var candidate := {
		"piece_id": piece_id, "player": player, "path": normalized_path,
		"ranged_target": Vector2i(-1, -1), "ranged_target_id": -1,
		"shot_type": "", "leftover": Vector2i(-1, -1),
	}
	var support_position := normalized_path[normalized_path.size() - 1] if support and not normalized_path.is_empty() else Vector2i(-1, -1)
	if not _same_player_order_is_clear(player, piece_id, candidate, strict_friendly, support_position):
		return {"ok": false, "message": "Friendly formations would collide on the same impulse."}
	if player not in orders: orders[player] = {}
	orders[player][piece_id] = candidate
	return {"ok": true, "order": candidate.duplicate(true)}


func append_order_step(player: int, piece_id: int, step: Vector2i, strict_friendly: bool = true) -> Dictionary:
	var current := order_for_piece(piece_id)
	var path: Array = current.get("path", []).duplicate()
	path.append(step)
	return set_unit_order(player, piece_id, path, current.get("ranged_target", Vector2i(-1, -1)), current.get("leftover", Vector2i(-1, -1)), int(current.get("ranged_target_id", -1)), strict_friendly)


func append_group_order_step(player: int, piece_ids: Array[int], direction: int, strict_friendly: bool = true) -> Dictionary:
	if direction < 0 or direction >= HexGrid.DIRECTION_COUNT:
		return {"ok": false, "message": "Group movement must use one hex direction."}
	return _change_group_paths(player, piece_ids, direction, false, strict_friendly)


func pop_order_step(player: int, piece_id: int) -> Dictionary:
	var current := order_for_piece(piece_id)
	var path: Array = current.get("path", []).duplicate()
	if not path.is_empty(): path.pop_back()
	return set_unit_order(player, piece_id, path, current.get("ranged_target", Vector2i(-1, -1)), current.get("leftover", Vector2i(-1, -1)), int(current.get("ranged_target_id", -1)))


func pop_group_order_step(player: int, piece_ids: Array[int]) -> Dictionary:
	return _change_group_paths(player, piece_ids, -1, true)


func _change_group_paths(player: int, piece_ids: Array[int], direction: int, remove_last: bool, strict_friendly: bool = true) -> Dictionary:
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
			var step: Vector2i = HexGrid.neighbor(previous, direction)
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
		var first_lead := HexGrid.direction_progress(pieces[first].position, direction)
		var second_lead := HexGrid.direction_progress(pieces[second].position, direction)
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
	return int(order.get("path", []).size())


## Step distance between two cells, ignoring terrain and occupancy.
static func grid_distance(first: Vector2i, second: Vector2i) -> int:
	return HexGrid.distance(first, second)


## True when a formation can step directly from one cell to the other.
static func are_adjacent(first: Vector2i, second: Vector2i) -> bool:
	return grid_distance(first, second) == 1


## Every cell one step from origin, including off-board ones. Callers filter
## for is_inside and is_blocked_terrain themselves.
static func neighbors(origin: Vector2i) -> Array[Vector2i]:
	return HexGrid.neighbors(origin)


## Every cell within reach steps of origin, origin included. Used for vision
## and for any range-limited targeting.
static func cells_within_range(origin: Vector2i, reach: int) -> Array[Vector2i]:
	return HexGrid.cells_within_range(origin, reach)


## Whether the given square can currently be declared as a target, and as which
## shot. Returns an empty string when the declaration would be rejected, so the
## UI can offer Shoot and Suppress only where they would take.
func declared_shot_type_for(player: int, piece_id: int, target: Vector2i, target_id: int = -1) -> String:
	if phase != PHASE_LEFTOVER_PLANNING or piece_id < 0 or piece_id >= pieces.size():
		return ""
	var piece: Dictionary = pieces[piece_id]
	if int(piece.player) != player or piece.role != ROLE_ARCHER or player in ready_players or not _eligible_for_leftover(piece):
		return ""
	var typed_path: Array[Vector2i] = []
	var declaration := _declared_shot_type(piece, player, typed_path, target, target_id)
	if not bool(declaration.get("ok", false)):
		return ""
	return String(declaration.get("shot_type", ""))


func ranged_order_is_available(player: int, piece_id: int, target: Vector2i, target_id: int = -1) -> bool:
	return not declared_shot_type_for(player, piece_id, target, target_id).is_empty()


## Aimed fire at a formation: it is shot wherever it stands, if still in range.
func set_ranged_order(player: int, piece_id: int, target: Vector2i, target_id: int = -1) -> Dictionary:
	var shot_type := declared_shot_type_for(player, piece_id, target, target_id)
	if shot_type.is_empty():
		return {"ok": false, "message": "That Archer cannot attack that target during reposition."}
	if player not in orders:
		orders[player] = {}
	var candidate: Dictionary = order_for_piece(piece_id).duplicate(true)
	if candidate.is_empty():
		candidate = {"piece_id": piece_id, "player": player, "path": []}
	candidate.ranged_target = target
	candidate.ranged_target_id = target_id
	candidate.shot_type = shot_type
	candidate.leftover = Vector2i(-1, -1)
	orders[player][piece_id] = candidate
	return {"ok": true, "order": candidate.duplicate(true), "message": "Ranged attack set."}


## Suppressing fire at a square: whatever is standing there gets shot.
func set_suppress_order(player: int, piece_id: int, target: Vector2i) -> Dictionary:
	return set_ranged_order(player, piece_id, target, -1)


func set_leftover_order(player: int, piece_id: int, target: Vector2i) -> Dictionary:
	if phase == PHASE_LEFTOVER_PLANNING:
		return _set_leftover_phase_order(player, piece_id, target)
	return {"ok": false, "message": "Reposition orders are chosen after the main clash."}


func set_group_leftover_step(player: int, piece_ids: Array[int], direction: int) -> Dictionary:
	if phase == PHASE_LEFTOVER_PLANNING:
		return _set_leftover_phase_group_order(player, piece_ids, direction)
	return {"ok": false, "message": "Reposition orders are chosen after the main clash."}


func _set_leftover_phase_order(player: int, piece_id: int, target: Vector2i) -> Dictionary:
	if game_over or player in ready_players:
		return {"ok": false, "message": "Post-clash actions can only be changed before ending reposition."}
	if piece_id < 0 or piece_id >= pieces.size() or int(pieces[piece_id].player) != player:
		return {"ok": false, "message": "That formation cannot receive this leftover order."}
	if not can_receive_leftover_order(player, piece_id):
		return {"ok": false, "message": "That formation has no post-clash action available."}
	var piece: Dictionary = pieces[piece_id]
	if not are_adjacent(piece.position, target) or not is_inside(target) or is_blocked_terrain(target):
		return {"ok": false, "message": "Reposition is one adjacent passable hex."}
	var occupant := piece_at(target)
	if not occupant.is_empty() and not are_allied_players(player, int(occupant.player)) and piece.role != ROLE_CAVALRY:
		return {"ok": false, "message": "Only Cavalry may deliberately reposition into an enemy-held hex."}
	var original_orders: Dictionary = orders.get(player, {}).duplicate(true)
	if player not in orders:
		orders[player] = {}
	var candidate: Dictionary = order_for_piece(piece_id).duplicate(true)
	if candidate.is_empty():
		candidate = {"piece_id": piece_id, "player": player, "path": [], "ranged_target": Vector2i(-1, -1)}
	candidate.leftover = target
	candidate.ranged_target = Vector2i(-1, -1)
	candidate.ranged_target_id = -1
	candidate.shot_type = ""
	orders[player][piece_id] = candidate
	if not _same_player_leftover_orders_are_clear(player):
		orders[player] = original_orders
		return {"ok": false, "message": "Friendly formations would collide during reposition."}
	return {"ok": true, "order": candidate.duplicate(true), "message": "Reposition set."}


func _set_leftover_phase_group_order(player: int, piece_ids: Array[int], direction: int) -> Dictionary:
	if game_over or player in ready_players:
		return {"ok": false, "message": "Post-clash actions can only be changed before ending reposition."}
	if direction < 0 or direction >= HexGrid.DIRECTION_COUNT:
		return {"ok": false, "message": "Reposition must use one hex direction."}
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
		var target: Vector2i = HexGrid.neighbor(pieces[piece_id].position, direction)
		if not is_inside(target) or is_blocked_terrain(target):
			# This one formation's step is invalid; the rest of the selection
			# may still be fine, so only this formation is skipped.
			skipped += 1
			continue
		var occupant := piece_at(target)
		if not occupant.is_empty() and not are_allied_players(player, int(occupant.player)) and pieces[piece_id].role != ROLE_CAVALRY:
			skipped += 1
			continue
		var candidate: Dictionary = order_for_piece(piece_id).duplicate(true)
		if candidate.is_empty():
			candidate = {"piece_id": piece_id, "player": player, "path": [], "ranged_target": Vector2i(-1, -1)}
		candidate.leftover = target
		candidate.ranged_target = Vector2i(-1, -1)
		candidate.ranged_target_id = -1
		candidate.shot_type = ""
		orders[player][piece_id] = candidate
		eligible_ids.append(piece_id)
	if eligible_ids.is_empty():
		orders[player] = original_orders
		return {"ok": false, "count": 0, "skipped": skipped, "message": "No selected formations have a post-clash action available."}
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
	var message := "Reposition set for %d formation%s." % [eligible_ids.size(), "" if eligible_ids.size() == 1 else "s"]
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
		if target not in destinations:
			destinations[target] = []
		destinations[target].append(piece)
	for target in destinations:
		var contenders: Array = destinations[target]
		if contenders.size() < 2:
			continue
		var has_stationary_defender := false
		for contender: Dictionary in contenders:
			if contender.position == target:
				has_stationary_defender = true
				break
		# Any number of friendly follow-ups may enter a square their own
		# stationary formation currently defends. Enemy arrivals turn that into
		# an ordinary multiway battle; without an enemy, everyone bounces.
		if not has_stationary_defender:
			return false
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
		order.ranged_target = Vector2i(-1, -1)
		order.ranged_target_id = -1
		order.shot_type = ""
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
			order.ranged_target = Vector2i(-1, -1)
			order.ranged_target_id = -1
			order.shot_type = ""
			orders[player][piece_id] = order


func has_leftover_orders(player: int) -> bool:
	for order: Dictionary in orders.get(player, {}).values():
		if order.get("leftover", Vector2i(-1, -1)).x >= 0 or order.get("ranged_target", Vector2i(-1, -1)).x >= 0:
			return true
	return false


func _same_player_order_is_clear(player: int, piece_id: int, candidate: Dictionary, strict_friendly: bool = true, support_position: Vector2i = Vector2i(-1, -1)) -> bool:
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
				# Staggered arrivals need no special handling here, now that
				# melee waits for every impulse: both attackers end up in the
				# same fight whatever speeds they are.
				#
				# An ally standing there is support, but only when it was asked
				# for. A friendly hex with a fight open on it is joined rather
				# than bounced off, so this is a real order; walking into your
				# own line by accident is still the mistake it always was, and
				# bots still use that rejection to prune their own choices.
				if defender.is_empty() or (are_allied_players(player, int(defender.player)) and position != support_position):
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
				# Same exception as above: an ally's hex is a legal place to end
				# the round only when support was the point of the order.
				if defender.is_empty() or (are_allied_players(player, int(defender.player)) and position != support_position):
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
		return {"ok": false, "message": "That hex is outside your deployment zone."}
	var origin: Vector2i = pieces[piece_id].position
	if target == origin: return {"ok": true, "action": "redeploy", "piece_id": piece_id, "position": target}
	if board[target.y][target.x] != EMPTY:
		return {"ok": false, "message": "Another formation already holds that hex."}
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
				proposals.append({"piece_id": int(piece.id), "from": piece.position, "to": path[taken], "is_attacker": true, "arrival": impulse})
		if not proposals.is_empty(): last_round_events.append_array(_resolve_movement_batch(proposals, "impulse_%d" % impulse, true))
		_record_all_sightings()
	# Every contact opened across the three impulses is rolled here, together.
	last_round_events.append_array(_resolve_pending_battles("melee"))
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
			leftover_proposals.append({"piece_id": int(piece.id), "from": piece.position, "to": target, "is_attacker": true, "arrival": 4})
	if not leftover_proposals.is_empty():
		leftover_events.append_array(_resolve_movement_batch(leftover_proposals, "leftover"))
	_record_all_sightings()
	# Reposition orders and ranged orders are chosen together. Movement and any
	# resulting battles resolve first; surviving Archers then fire from their
	# final hexes at their targets' final hexes.
	leftover_events.append_array(_resolve_ranged_phase())
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


func _begin_round_state() -> void:
	_pending_battles.clear()
	_contested_hexes.clear()
	for piece: Dictionary in pieces:
		if piece.alive:
			pieces[piece.id].round_status = STATUS_READY
			pieces[piece.id].movement_used = 0
			pieces[piece.id].steps_taken = 0
			pieces[piece.id].melee_count = 0
			pieces[piece.id].participated_in_combat = false
			pieces[piece.id].main_done = false


func _resolve_movement_batch(proposals: Array[Dictionary], batch_name: String, defer: bool = false) -> Array[Dictionary]:
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
	# A formation walking into a fight that is already open joins it, whichever
	# side is standing there and whether or not anyone still is. Settled before
	# anything else is classified, so a contested hex is never mistaken for
	# ordinary congestion or for open ground the attackers happened to vacate.
	for id_value in ids:
		var joining_id := int(id_value)
		var joining: Dictionary = proposal_by_id[joining_id]
		if joining.to not in _contested_hexes: continue
		_join_pending_battle(int(_contested_hexes[joining.to]), joining)
		handled[joining_id] = true
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
	# Frozen before the loop below, which adds every battle participant to
	# `handled` as it classifies each square. Testing the live `handled` made
	# "did this square's occupant leave?" depend on the order destinations
	# happened to be visited, which follows piece id: a formation committing to
	# a fight one hex ahead read as stationary to whoever was behind it, and the
	# follower bounced off a square that was already being vacated. Only the
	# swap participants matched here are genuinely still contesting their own
	# origin, so they are the only ones a follower must wait behind.
	var swapping := handled.duplicate()
	for destination in destination_groups:
		var arrivals: Array = destination_groups[destination]
		var participants: Array[Dictionary] = []
		for arrival: Dictionary in arrivals: participants.append(arrival.duplicate(true))
		var occupant := piece_at(destination)
		var occupant_leaves := not occupant.is_empty() and int(occupant.id) in proposal_by_id and int(occupant.id) not in swapping
		if not occupant.is_empty() and not occupant_leaves:
			# Arrival 0: it was standing here before the round started, so nothing
			# that moves this round can reach the square ahead of it.
			participants.append({"piece_id": int(occupant.id), "from": destination, "to": destination, "is_attacker": false, "arrival": 0})
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
			# This was movement congestion, not a fight. It can end or delay the
			# current path, but it never imposes the combat-tie penalty.
			var blocker := piece_at(move.to)
			_mark_returned(id, not blocker.is_empty() and are_allied_players(int(pieces[id].player), int(blocker.player)))
			events.append(_bounce_event([id], move.to, batch_name, "occupied_after_resolution"))
	for collision: Dictionary in allied_collisions:
		# Friendly congestion carries no round-status penalty. A stationary
		# formation keeps its own path; a mover may retry only when it queued
		# behind that stationary formation. Converging movers stop this path so
		# they do not repeat the same collision on every remaining impulse.
		var stationary := int(collision.get("stationary_id", EMPTY))
		var collision_ids: Array[int] = []
		for id_value in collision.ids:
			var id := int(id_value)
			collision_ids.append(id)
			if id == stationary:
				continue
			_mark_returned(id, stationary != EMPTY)
		events.append(_bounce_event(collision_ids, collision.position, batch_name, "allied_collision"))
	var retreat_intents: Array[Dictionary] = []
	for battle: Dictionary in battles:
		if defer:
			_open_pending_battle(battle)
			continue
		var result := _resolve_battle(battle.participants, battle.position, bool(battle.crossing), batch_name)
		events.append(result.event)
		retreat_intents.append_array(result.retreats)
	if not retreat_intents.is_empty(): events.append_array(_resolve_retreats(retreat_intents, batch_name))
	return events


## Hold a contact open rather than rolling for it where it happened. Everyone in
## it stops moving at the moment of contact, and the fight's hexes are recorded
## so later arrivals join it. A crossing fight covers both of the hexes its
## participants are trading, which is why entering either one joins.
func _open_pending_battle(battle: Dictionary) -> void:
	var index := _pending_battles.size()
	_pending_battles.append(battle)
	_contested_hexes[battle.position] = index
	for participant: Dictionary in battle.participants:
		pieces[int(participant.piece_id)].main_done = true
		if bool(battle.get("crossing", false)): _contested_hexes[participant.to] = index


func _join_pending_battle(index: int, proposal: Dictionary) -> void:
	var id := int(proposal.piece_id)
	_pending_battles[index].participants.append(proposal.duplicate(true))
	# Same as any attacker: it has left the square behind it, so whoever is
	# queued there can move up on this impulse.
	_clear_piece_square(id)
	pieces[id].main_done = true


## Every fight opened during main movement, rolled together once the impulses
## are done. The waiting is the whole point: a formation that made contact on
## impulse 1 and the ally that reached it on impulse 3 are in one fight, which
## they could never be while contact resolved where it happened.
func _resolve_pending_battles(batch_name: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var retreat_intents: Array[Dictionary] = []
	for battle: Dictionary in _pending_battles:
		var result := _resolve_battle(battle.participants, battle.position, bool(battle.crossing), batch_name)
		events.append(result.event)
		retreat_intents.append_array(result.retreats)
	if not retreat_intents.is_empty(): events.append_array(_resolve_retreats(retreat_intents, batch_name))
	_pending_battles.clear()
	_contested_hexes.clear()
	return events


## How many dice a formation rolls. Every bonus but the role die is
## comparative, so it is worth nothing against an equal: two Heavies give each
## other no weight die, and two Strength-7s give each other no strength die.
## A negative opposing value means there is nobody to compare against, which
## awards neither comparative die rather than both.
func _combat_dice_count(piece: Dictionary, opposing_rank: int, opposing_strength: int, role_die: bool) -> int:
	var count := COMBAT_BASE_DICE
	if opposing_rank >= 0 and int(WEIGHT_RANK.get(String(piece.get("weight", "")), 0)) > opposing_rank: count += 1
	if opposing_strength >= 0 and int(piece.strength) > opposing_strength: count += 1
	if role_die: count += 1
	return count


## The opposing side's best claim on each comparative dimension, as
## [weight rank, Strength]. In a multiway fight a bonus die has to be earned
## against every enemy present, not just the weakest one on the square - the
## alternative would hand a Heavy a weight die for out-massing one Light while
## a second Heavy stood beside it.
func _opposing_comparators(piece_id: int, participant_ids: Array[int]) -> Array[int]:
	var rank := -1
	var strength := -1
	for other_id in participant_ids:
		if other_id == piece_id or are_allied_players(int(pieces[piece_id].player), int(pieces[other_id].player)): continue
		rank = maxi(rank, int(WEIGHT_RANK.get(String(pieces[other_id].weight), 0)))
		strength = maxi(strength, int(pieces[other_id].strength))
	return [rank, strength]


## Braced against whoever was slower to the square. A formation defends when no
## enemy reached the contested hex before it or alongside it, which makes a
## stationary occupant the defender against everyone, an early arrival the
## defender against whatever follows it in, and two enemies landing on the same
## impulse a fight where neither had time to set. Allies that arrive together are
## all braced: the die is earned by beating the enemy there, not each other.
##
## Distinct from `is_attacker`, which only records whether a formation moved into
## this fight or was already standing in it. That still decides where a loser
## falls back to, and a formation can very well have moved and be braced.
func _is_defending(piece_id: int, participants: Array) -> bool:
	var own := int(_participant_for(piece_id, participants).get("arrival", 0))
	for participant: Dictionary in participants:
		var other_id := int(participant.piece_id)
		if other_id == piece_id: continue
		if are_allied_players(int(pieces[piece_id].player), int(pieces[other_id].player)): continue
		if int(participant.get("arrival", 0)) <= own: return false
	return true


## A side's pool: one die per formation it brought, plus the comparative dice.
## Numbers are paid out here and nowhere else, which is the whole reason Strength
## scores off the leading formation alone. Stacking both would let a gang open a
## margin wide enough to delete a healthy formation on contact.
func _side_dice_count(team: int, teams: Array[int], members: Dictionary, participants: Array) -> int:
	var own: Array = members[team]
	var count := own.size()
	var best_opposing_strength := -1
	var best_opposing_weight := -1
	for other in teams:
		if other == team: continue
		best_opposing_strength = maxi(best_opposing_strength, _side_strength(members[other]))
		best_opposing_weight = maxi(best_opposing_weight, _side_weight(members[other]))
	if best_opposing_strength >= 0 and _side_strength(own) > best_opposing_strength: count += 1
	# Uniquely heaviest, so a Heavy earns nothing against another Heavy however
	# many Mediums are standing behind either of them.
	if best_opposing_weight >= 0 and _side_weight(own) > best_opposing_weight: count += 1
	for id_value in own:
		var id := int(id_value)
		var role := String(pieces[id].role)
		var defending := _is_defending(id, participants)
		if (role == ROLE_CAVALRY and not defending) or (role == ROLE_INFANTRY and defending): count += 1
	return count


func _side_strength(ids: Array) -> int:
	var best := -1
	for id_value in ids: best = maxi(best, int(pieces[int(id_value)].strength))
	return best


func _side_weight(ids: Array) -> int:
	var best := -1
	for id_value in ids: best = maxi(best, _weight_rank(pieces[int(id_value)]))
	return best


## Who gets first refusal on the ground a winning side just took. Arrival leads,
## so a formation that held the hex keeps it and its own reinforcements cannot
## shove it off. Then current Strength, so among formations that landed together
## the one leading the push takes the ground. Then id, purely so the outcome
## never depends on the order participants happen to be listed in.
func _placement_order(ids: Array, participants: Array) -> Array[int]:
	var ordered: Array[int] = []
	for id_value in ids: ordered.append(int(id_value))
	ordered.sort_custom(func(first: int, second: int) -> bool:
		var arrival_first := int(_participant_for(first, participants).get("arrival", 0))
		var arrival_second := int(_participant_for(second, participants).get("arrival", 0))
		if arrival_first != arrival_second: return arrival_first < arrival_second
		if int(pieces[first].strength) != int(pieces[second].strength): return int(pieces[first].strength) > int(pieces[second].strength)
		return first < second)
	return ordered


func _resolve_battle(participants: Array, contested: Vector2i, crossing: bool, batch_name: String) -> Dictionary:
	var scores: Dictionary = {}
	var raw_rolls: Dictionary = {}
	var bonus_dice: Dictionary = {}
	var dice_pools: Dictionary = {}
	var sixes: Dictionary = {}
	var participant_ids: Array[int] = []
	for participant: Dictionary in participants:
		var id := int(participant.piece_id)
		if id in participant_ids or not pieces[id].alive: continue
		participant_ids.append(id)
	# Nobody rolls until the whole square is known, because a side's pool depends
	# on everyone who turned up to the fight, on both sides of it.
	var teams: Array[int] = []
	var members: Dictionary = {}
	for id in participant_ids:
		var team := _team_for_piece(id)
		if team not in members:
			members[team] = ([] as Array[int])
			teams.append(team)
		members[team].append(id)
	var team_scores: Dictionary = {}
	var team_sixes: Dictionary = {}
	for team in teams:
		var side: Array = members[team]
		var count := _side_dice_count(team, teams, members, participants)
		var pool := _roll_dice_pool(count)
		team_scores[team] = int(pool.high) + _side_strength(side)
		team_sixes[team] = int(pool.sixes)
		# Stored against every formation on the side rather than against the side
		# itself, so a battle card can read one participant's row without knowing
		# how the sides were grouped. They all share the numbers because there was
		# genuinely one roll.
		for id_value in side:
			var id := int(id_value)
			scores[id] = int(team_scores[team])
			raw_rolls[id] = int(pool.high)
			sixes[id] = int(pool.sixes)
			dice_pools[id] = pool.dice
			bonus_dice[id] = count - side.size()
			pieces[id].participated_in_combat = true
			pieces[id].melee_count = int(pieces[id].melee_count) + 1
	var highest := -1
	for team in teams: highest = maxi(highest, int(team_scores[team]))
	var top_teams: Array[int] = []
	for team in teams:
		if int(team_scores[team]) == highest: top_teams.append(team)
	var winning_team := int(top_teams[0]) if top_teams.size() == 1 else -1
	if winning_team < 0 and top_teams.size() > 1 and (defender_wins_ties or defender_resists_charge_ties):
		# Both toggles answer the same question, an even score between a side that
		# was set and a side that came at it, and neither invents a winner when
		# more than one tied side was braced. The charge variant is the narrower
		# one: it only breaks the tie when everything that came at the braced side
		# was Cavalry, the case where both role dice cancel and the tie is a pure
		# coin flip.
		var braced_teams: Array[int] = []
		for team in top_teams:
			for id_value in members[team]:
				if _is_defending(int(id_value), participants):
					braced_teams.append(team)
					break
		if braced_teams.size() == 1:
			var charge_only := true
			for team in top_teams:
				if team == braced_teams[0]: continue
				for id_value in members[team]:
					if pieces[int(id_value)].role != ROLE_CAVALRY: charge_only = false
			if defender_wins_ties or charge_only:
				winning_team = braced_teams[0]
	var damage_by_id: Dictionary = {}
	for id in participant_ids:
		var team := _team_for_piece(id)
		var best_opposing := -1
		var opposing_sixes := 0
		for other in teams:
			if other == team: continue
			best_opposing = maxi(best_opposing, int(team_scores[other]))
			# The margin is the contest, but a 6 is a lucky blow rather than a won
			# one, which is what lets a side being overrun put one through the
			# winner on its way down.
			opposing_sixes = maxi(opposing_sixes, int(team_sixes[other]))
		# Two independent sources: the margin, which only a losing side pays and
		# which every formation on it pays alike, and surviving 6s, which land
		# whatever the scores did. A draw is free of margin damage, not of crits.
		var damage := 0
		if best_opposing >= 0:
			damage = maxi(0, best_opposing - int(team_scores[team])) + maxi(0, opposing_sixes - int(team_sixes[team]))
		damage_by_id[id] = damage
	for id in participant_ids:
		pieces[id].strength = maxi(0, int(pieces[id].strength) - int(damage_by_id[id]))
		if int(pieces[id].strength) <= 0: _remove_piece(id)
	if not crossing and is_inside(contested):
		var occupant := piece_at(contested)
		if not occupant.is_empty() and int(occupant.id) in participant_ids: board[contested.y][contested.x] = EMPTY
	var retreats: Array[Dictionary] = []
	var outcomes: Dictionary = {}
	var unique_winner_id := EMPTY
	if winning_team >= 0:
		# The winning side claims the ground it was ordered onto, earliest arrival
		# first. In an ordinary fight every attacker wanted the same hex, so one
		# claim lands and the rest come home, exactly as before. In a crossing
		# fight the destinations differ and an advancing line keeps its shape.
		for id in _placement_order(members[winning_team], participants):
			if not pieces[id].alive:
				outcomes[id] = "destroyed"
				continue
			var participant := _participant_for(id, participants)
			var wanted: Vector2i = participant.to
			if is_inside(wanted) and not is_blocked_terrain(wanted) and piece_at(wanted).is_empty():
				_place_piece(id, wanted, participant.from)
				outcomes[id] = STATUS_WON
				pieces[id].round_status = STATUS_WON
				pieces[id].main_done = true
				if unique_winner_id == EMPTY: unique_winner_id = id
			else:
				outcomes[id] = "returned"
				_mark_returned(id)
				_place_bouncer(id, participant.from, contested)
		for id in participant_ids:
			if _team_for_piece(id) == winning_team: continue
			if not pieces[id].alive:
				outcomes[id] = "destroyed"
			else:
				outcomes[id] = STATUS_LOST
				_mark_lost(id)
				retreats.append(_retreat_intent(id, _participant_for(id, participants), participants, crossing))
	else:
		# Level scores across opposing sides. Nobody took the hex, so every
		# survivor returns and is done for the round.
		for id in participant_ids:
			if not pieces[id].alive:
				outcomes[id] = "destroyed"
			else:
				outcomes[id] = STATUS_BOUNCED
				_mark_bounced(id, true)
				_place_bouncer(id, _participant_for(id, participants).from, contested)
	var event := {
		"ok": true, "action": "crossing_battle" if crossing else "melee", "batch": batch_name, "combat": true,
		"ranged": false, "crossing": crossing, "to": contested, "participants": participant_ids.duplicate(),
		"scores": scores.duplicate(true), "raw_rolls": raw_rolls.duplicate(true), "damage": damage_by_id.duplicate(true),
		"bonus_dice": bonus_dice.duplicate(true), "dice_pools": dice_pools.duplicate(true), "sixes": sixes.duplicate(true),
		"outcomes": outcomes.duplicate(true), "winner_id": unique_winner_id, "winner_team": winning_team,
		"result": "win" if unique_winner_id != EMPTY else ("team_win" if winning_team >= 0 else "bounce"), "known_to": _battle_viewers_for_ids(participant_ids),
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


func _retreat_intent(piece_id: int, participant: Dictionary, participants: Array, crossing: bool) -> Dictionary:
	var target: Vector2i
	var anchor: Vector2i
	var direction := -1
	if bool(participant.is_attacker) and not crossing:
		anchor = participant.to
		target = participant.from
		direction = HexGrid.direction_between(anchor, target)
	else:
		var source := _strongest_opposing_participant(piece_id, participants)
		anchor = participant.from
		target = participant.from
		var away := (HexGrid.cell_center(participant.from, Vector2.ZERO, 1.0) - HexGrid.cell_center(source.from, Vector2.ZERO, 1.0)).normalized()
		var best_alignment := -2.0
		for candidate_direction in HexGrid.DIRECTION_COUNT:
			var alignment := HexGrid.direction_screen_vector(candidate_direction).dot(away)
			if alignment > best_alignment:
				best_alignment = alignment
				direction = candidate_direction
				target = HexGrid.neighbor(participant.from, candidate_direction)
	return {"piece_id": piece_id, "from": participant.from, "to": target, "anchor": anchor, "direction": direction}


## Which enemy a loser backs away from. Score belongs to the side now, so it
## cannot pick one formation out of a line, and the direction comes from the
## strongest opposing formation instead, with the earlier arrival breaking a tie:
## the one that has held the ground longest is the one you are giving it up to.
## Formations destroyed in the same clash are only considered if nothing on that
## side is left standing to back away from.
func _strongest_opposing_participant(piece_id: int, participants: Array) -> Dictionary:
	var selected: Dictionary = {}
	var fallback: Dictionary = {}
	var best_strength := -1
	var best_arrival := 0
	for participant: Dictionary in participants:
		var other_id := int(participant.piece_id)
		if are_allied_players(int(pieces[piece_id].player), int(pieces[other_id].player)): continue
		if fallback.is_empty(): fallback = participant
		if not pieces[other_id].alive: continue
		var strength := int(pieces[other_id].strength)
		var arrival := int(participant.get("arrival", 0))
		if strength > best_strength or (strength == best_strength and arrival < best_arrival):
			selected = participant
			best_strength = strength
			best_arrival = arrival
	return selected if not selected.is_empty() else fallback


func _resolve_retreats(retreats: Array[Dictionary], batch_name: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var valid_by_target: Dictionary = {}
	for retreat: Dictionary in retreats:
		var id := int(retreat.piece_id)
		if not pieces[id].alive: continue
		var direct_target: Vector2i = retreat.to
		var target := direct_target
		var shunt_side := ""
		var destroy_reason := ""
		if not is_inside(direct_target):
			destroy_reason = "off_board"
		elif is_blocked_terrain(direct_target):
			destroy_reason = "blocked_terrain"
		else:
			var blocker := piece_at(direct_target)
			if not blocker.is_empty():
				if not are_allied_players(int(pieces[id].player), int(blocker.player)):
					destroy_reason = "enemy_blocked"
				else:
					# Treat directly away as 6 o'clock. Moving clockwise from there is
					# the retreating formation's left-hand (7 o'clock) hex, then the
					# right-hand (5 o'clock) one. Past those it will take any hex it
					# can still reach, in widening order. Only the three nearest used
					# to be tried, which meant a side that moved reinforcements up
					# behind its own line killed the formations falling back into it,
					# and losing one fight could cost several formations that had
					# somewhere to go the whole time.
					var anchor: Vector2i = retreat.get("anchor", retreat.from)
					var direction := int(retreat.get("direction", HexGrid.direction_between(anchor, direct_target)))
					if direction >= 0:
						for option in [["left", 1], ["right", -1], ["wide left", 2], ["wide right", -2], ["backward", 3]]:
							var candidate_direction := (direction + int(option[1]) + HexGrid.DIRECTION_COUNT) % HexGrid.DIRECTION_COUNT
							var candidate := HexGrid.neighbor(anchor, candidate_direction)
							if is_inside(candidate) and not is_blocked_terrain(candidate) and piece_at(candidate).is_empty():
								target = candidate
								shunt_side = String(option[0])
								break
					if shunt_side.is_empty():
						destroy_reason = "friendly_congestion"
		if not destroy_reason.is_empty():
			# Viewers resolved before the removal, which blanks the position.
			var lost_viewers := _move_viewers(int(pieces[id].player), retreat.from, direct_target)
			_remove_piece(id)
			var lost_event := {"ok": true, "action": "retreat", "batch": batch_name, "piece_id": id, "from": retreat.from, "to": direct_target, "result": "retreat_destroyed", "reason": destroy_reason, "combat": false, "known_to": lost_viewers}
			events.append(lost_event)
			battle_history.append(lost_event.duplicate(true))
		else:
			if target not in valid_by_target: valid_by_target[target] = []
			var resolved_retreat := retreat.duplicate(true)
			resolved_retreat.to = target
			resolved_retreat.direct_to = direct_target
			resolved_retreat.shunt_side = shunt_side
			valid_by_target[target].append(resolved_retreat)
	for target in valid_by_target:
		var group: Array = valid_by_target[target]
		if group.size() == 1:
			var retreat: Dictionary = group[0]
			_place_piece(int(retreat.piece_id), target, retreat.from)
			var shunt_side := String(retreat.get("shunt_side", ""))
			var moved_event := {"ok": true, "action": "retreat", "batch": batch_name, "piece_id": int(retreat.piece_id), "from": retreat.from, "to": target, "direct_to": retreat.get("direct_to", target), "shunt_side": shunt_side, "result": "retreat_shunted" if not shunt_side.is_empty() else "retreated", "combat": false, "known_to": _move_viewers(int(pieces[int(retreat.piece_id)].player), retreat.from, target)}
			events.append(moved_event)
			battle_history.append(moved_event.duplicate(true))
			continue
		var teams: Dictionary = {}
		for retreat: Dictionary in group: teams[_team_for_piece(int(retreat.piece_id))] = true
		if teams.size() == 1:
			var ids: Array[int] = []
			for retreat: Dictionary in group:
				ids.append(int(retreat.piece_id))
				_remove_piece(int(retreat.piece_id))
			var collision_event := {"ok": true, "action": "retreat_collision", "batch": batch_name, "to": target, "participants": ids, "result": "congestion_destroyed", "combat": false, "known_to": _battle_viewers_for_ids(ids)}
			events.append(collision_event)
			battle_history.append(collision_event.duplicate(true))
		else:
			events.append(_resolve_retreat_battle(group, target, batch_name))
	return events


func _resolve_retreat_battle(group: Array, target: Vector2i, batch_name: String) -> Dictionary:
	var ids: Array[int] = []
	var scores: Dictionary = {}
	var raw_rolls: Dictionary = {}
	var sixes: Dictionary = {}
	var dice_pools: Dictionary = {}
	for retreat: Dictionary in group:
		ids.append(int(retreat.piece_id))
	# Two broken formations backing into the same square. The comparative dice
	# still apply, but no role die does: nobody here is charging, and nobody is
	# braced on a square they meant to hold.
	for id in ids:
		var comparators := _opposing_comparators(id, ids)
		var pool := _roll_dice_pool(_combat_dice_count(pieces[id], comparators[0], comparators[1], false))
		raw_rolls[id] = int(pool.high)
		sixes[id] = int(pool.sixes)
		dice_pools[id] = pool.dice
		scores[id] = int(pool.high) + int(pieces[id].strength)
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
		var opposing_sixes := 0
		for source_id in ids:
			if are_allied_players(int(pieces[target_id].player), int(pieces[source_id].player)): continue
			opposing_score = maxi(opposing_score, int(scores[source_id]))
			opposing_sixes = maxi(opposing_sixes, int(sixes[source_id]))
		var amount := 0
		if opposing_score >= 0:
			amount = maxi(0, opposing_score - int(scores[target_id])) + maxi(0, opposing_sixes - int(sixes[target_id]))
		damage[target_id] = amount
		pieces[target_id].strength = maxi(0, int(pieces[target_id].strength) - amount)
	for id in ids:
		if id != winner_id or int(pieces[id].strength) <= 0: _remove_piece(id)
	if winner_id != EMPTY and pieces[winner_id].alive: _place_piece(winner_id, target, pieces[winner_id].position)
	var event := {
		"ok": true, "action": "retreat_battle", "batch": batch_name, "combat": true, "retreat_battle": true,
		"to": target, "participants": ids, "scores": scores, "raw_rolls": raw_rolls, "damage": damage,
		"sixes": sixes, "dice_pools": dice_pools,
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
		# the square after reposition movement and its battles have resolved.
		var target: Dictionary = {}
		if target_id >= 0:
			if target_id < pieces.size() and pieces[target_id].alive: target = pieces[target_id]
		else:
			target = piece_at(target_position)
		if not target.is_empty() and (are_allied_players(int(piece.player), int(target.player)) or target.type == FLAG):
			target = {}
		var shot_range := grid_distance(piece.position, target.position) if not target.is_empty() else -1
		if target.is_empty() or shot_range < 1 or shot_range > 2:
			fizzles.append({
				"shooter_id": int(piece.id), "from": piece.position, "to": target_position,
				"shot_type": shot_type, "target_id": target_id,
				"reason": "no_target" if target.is_empty() else "out_of_range",
			})
			continue
		# Range is determined when the arrow is actually loosed. A tracked target
		# that closes to range 1 therefore grants the same accuracy die as any
		# other adjacent target.
		shot_type = SHOT_SHORT if shot_range == 1 else SHOT_LONG
		var resolution := calculate_ranged(piece, target, shot_type)
		shots.append({"shooter_id": int(piece.id), "target_id": int(target.id), "from": piece.position, "to": target.position, "range": shot_range, "movement_cost": 0, "resolution": resolution})
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
			"defender_score": int(shot.resolution.defender_score), "defender_raw_roll": int(shot.resolution.defender_raw_roll),
			"attacker_dice": shot.resolution.attacker_dice.duplicate(), "defender_dice": shot.resolution.defender_dice.duplicate(),
			"attacker_bonus_dice": int(shot.resolution.attacker_bonus_dice), "defender_bonus_dice": int(shot.resolution.defender_bonus_dice),
			"attacker_sixes": int(shot.resolution.attacker_sixes), "defender_sixes": int(shot.resolution.defender_sixes),
			"shot_type": String(shot.resolution.shot_type), "hit": bool(shot.resolution.hit),
			"defender_damage": int(shot.resolution.defender_damage),
			# A graze is a shot that lost the contest and still drew blood off an
			# uncancelled 6. Worth its own result: reporting it as a miss beside
			# a non-zero damage number reads as a bug.
			"result": "ranged_destroyed" if not pieces[target_id].alive else ("ranged_hit" if bool(shot.resolution.hit) else ("ranged_graze" if int(shot.resolution.defender_damage) > 0 else "ranged_miss")),
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
	# A shot that found nothing still happened. Reporting it keeps the log
	# honest about why an Archer did not fire.
	for fizzle: Dictionary in fizzles:
		var fizzle_event := {
			"ok": true, "action": "ranged_fizzle", "batch": "ranged", "combat": false, "ranged": true,
			"from": fizzle.from, "to": fizzle.to, "shooter_id": int(fizzle.shooter_id),
			"target_id": int(fizzle.target_id), "shot_type": String(fizzle.shot_type),
			"movement_cost": 0, "result": String(fizzle.reason),
			"known_to": _battle_viewers_for_ids([int(fizzle.shooter_id)]),
		}
		battle_history.append(fizzle_event.duplicate(true))
		events.append(fizzle_event)
	return events


func _eligible_to_shoot(piece: Dictionary) -> bool:
	if not is_movable(piece) or piece.role != ROLE_ARCHER or String(piece.round_status) not in [STATUS_READY, STATUS_WON]:
		return false
	return not String(order_for_piece(int(piece.id)).get("shot_type", "")).is_empty()


## Main movement points a formation has already committed this round.
func movement_committed(piece: Dictionary) -> int:
	return int(piece.movement_used)


func _eligible_for_leftover(piece: Dictionary) -> bool:
	# Every surviving formation receives one post-clash action. Losing, an
	# opposing-side tie, or already reaching the two-melee cap still ends its
	# ability to act for the round.
	return is_movable(piece) and String(piece.round_status) in [STATUS_READY, STATUS_WON] and int(piece.melee_count) < 2


func _movement_event(piece_id: int, from: Vector2i, to: Vector2i, batch_name: String) -> Dictionary:
	var viewers := _move_viewers(int(pieces[piece_id].player), from, to)
	last_move = {"from": from, "to": to, "visible_to": viewers.duplicate(), "action": "move"}
	return {"ok": true, "action": "move", "batch": batch_name, "combat": false, "piece_id": piece_id, "from": from, "to": to, "result": "move", "visible_to": viewers}


func _bounce_event(ids: Array[int], position: Vector2i, batch_name: String, reason: String) -> Dictionary:
	return {"ok": true, "action": "bounce", "batch": batch_name, "combat": false, "participants": ids, "to": position, "result": "bounce", "reason": reason}


## The only penalized bounce: a highest-score tie spanning opposing teams.
## Movement congestion and friendly returns use _mark_returned instead.
func _mark_bounced(piece_id: int, combat: bool, may_retry: bool = false) -> void:
	pieces[piece_id].round_status = STATUS_BOUNCED
	pieces[piece_id].main_done = not may_retry
	if combat: pieces[piece_id].participated_in_combat = true


## Return a formation to where it came from without applying the opposing-tie
## penalty. It may retry a queued movement step, or stop its current main path
## while retaining any later ranged/reposition options its budget allows.
func _mark_returned(piece_id: int, may_retry: bool = false) -> void:
	pieces[piece_id].main_done = not may_retry


func _mark_lost(piece_id: int) -> void:
	pieces[piece_id].round_status = STATUS_LOST
	pieces[piece_id].main_done = true
	pieces[piece_id].participated_in_combat = true


func _place_bouncer(piece_id: int, origin: Vector2i, contested: Vector2i = Vector2i(-1, -1)) -> void:
	if not pieces[piece_id].alive: return
	if piece_at(origin).is_empty():
		_place_piece(piece_id, origin, origin)
		return
	if int(piece_at(origin).id) == piece_id: return
	# The square this formation stepped out of was filled while its fight was
	# still open, normally by the ally that advanced into the gap behind it.
	# Falling back a hex beats deleting a formation that never lost anything,
	# which is what a returning bouncer used to do to itself.
	var shunt := _adjacent_free_hex(origin, contested)
	if is_inside(shunt): _place_piece(piece_id, shunt, origin)
	else: _remove_piece(piece_id)


## A free hex beside `origin`, tried in order of how directly it leads away from
## `contested`. More forgiving than a retreat's three options, because a bouncer
## did not lose its fight and should not die for standing in traffic.
func _adjacent_free_hex(origin: Vector2i, contested: Vector2i) -> Vector2i:
	var away := HexGrid.direction_between(contested, origin) if is_inside(contested) else 0
	if away < 0: away = 0
	for offset: int in [0, 1, -1, 2, -2, 3]:
		var direction := (away + offset + HexGrid.DIRECTION_COUNT) % HexGrid.DIRECTION_COUNT
		var candidate := HexGrid.neighbor(origin, direction)
		if not is_inside(candidate) or is_blocked_terrain(candidate): continue
		if piece_at(candidate).is_empty(): return candidate
	return Vector2i(-1, -1)


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


func _weight_rank(piece: Dictionary) -> int:
	return int(WEIGHT_RANK.get(String(piece.get("weight", "")), 0))


## Resolve one melee in isolation, off the board. `attacker_dice` and
## `defender_dice` force individual dice in pool order; any die the arrays do
## not cover is rolled normally.
func calculate_melee(attacker: Dictionary, defender: Dictionary, attacker_dice: Array = [], defender_dice: Array = [], both_attacking: bool = false) -> Dictionary:
	var attacker_role := String(attacker.get("role", ""))
	var defender_role := String(defender.get("role", ""))
	# Two formations that walked through each other are both attacking, so
	# neither is braced: Infantry gets nothing and a second Cavalry charges too.
	var attacker_role_die := attacker_role == ROLE_CAVALRY
	var defender_role_die := (defender_role == ROLE_CAVALRY) if both_attacking else (defender_role == ROLE_INFANTRY)
	var attacker_count := _combat_dice_count(attacker, _weight_rank(defender), int(defender.strength), attacker_role_die)
	var defender_count := _combat_dice_count(defender, _weight_rank(attacker), int(attacker.strength), defender_role_die)
	var attacker_pool := _roll_dice_pool(attacker_count, attacker_dice)
	var defender_pool := _roll_dice_pool(defender_count, defender_dice)
	var attacker_score := int(attacker_pool.high) + int(attacker.strength)
	var defender_score := int(defender_pool.high) + int(defender.strength)
	var net_attacker_sixes := maxi(0, int(attacker_pool.sixes) - int(defender_pool.sixes))
	var net_defender_sixes := maxi(0, int(defender_pool.sixes) - int(attacker_pool.sixes))
	var winner_name := ""
	if attacker_score > defender_score: winner_name = "attacker"
	elif defender_score > attacker_score: winner_name = "defender"
	# The margin is only ever paid by the loser; the surviving 6s are paid by
	# whoever failed to match them, win, lose or draw. Because 6s cancel one
	# for one, at most one side can be owed crit damage in any single clash.
	var attacker_damage := maxi(0, defender_score - attacker_score) + net_defender_sixes
	var defender_damage := maxi(0, attacker_score - defender_score) + net_attacker_sixes
	return {
		"attacker_raw_roll": int(attacker_pool.high), "defender_raw_roll": int(defender_pool.high),
		"attacker_dice": attacker_pool.dice, "defender_dice": defender_pool.dice,
		"attacker_bonus_dice": attacker_count - COMBAT_BASE_DICE, "defender_bonus_dice": defender_count - COMBAT_BASE_DICE,
		"attacker_sixes": int(attacker_pool.sixes), "defender_sixes": int(defender_pool.sixes),
		"attacker_score": attacker_score, "defender_score": defender_score,
		"attacker_wins": winner_name == "attacker", "defender_wins": winner_name == "defender", "tie": winner_name.is_empty(),
		"score_winner": winner_name,
		"attacker_damage": attacker_damage, "defender_damage": defender_damage,
		"critical_attacker": net_attacker_sixes > 0, "critical_defender": net_defender_sixes > 0,
	}


## A shot is a contest, not a flat threshold: the target rolls its own pool and
## may simply outscore the arrow. The archer's extra die is the short shot -
## the only accuracy difference between the two ranges - and the target never
## gets one, because it is being shot at rather than shooting back.
func calculate_ranged(attacker: Dictionary, defender: Dictionary, shot_type: String = SHOT_SHORT, attacker_dice: Array = [], defender_dice: Array = []) -> Dictionary:
	var attacker_count := _combat_dice_count(attacker, _weight_rank(defender), int(defender.strength), shot_type == SHOT_SHORT)
	var defender_count := _combat_dice_count(defender, _weight_rank(attacker), int(attacker.strength), false)
	var attacker_pool := _roll_dice_pool(attacker_count, attacker_dice)
	var defender_pool := _roll_dice_pool(defender_count, defender_dice)
	var attacker_score := int(attacker_pool.high) + int(attacker.strength)
	var defender_score := int(defender_pool.high) + int(defender.strength)
	var net_attacker_sixes := maxi(0, int(attacker_pool.sixes) - int(defender_pool.sixes))
	var hit := attacker_score > defender_score
	# A shot that loses the contest still lands whatever 6s the target failed
	# to match, so an outmatched Archer is never firing for literally nothing.
	# The target's own 6s are its only defence against that, and the Archer
	# never takes damage back either way: it is being shot at that is one-sided.
	var defender_damage := maxi(0, attacker_score - defender_score) + net_attacker_sixes
	return {
		"attacker_raw_roll": int(attacker_pool.high), "defender_raw_roll": int(defender_pool.high),
		"attacker_dice": attacker_pool.dice, "defender_dice": defender_pool.dice,
		"attacker_bonus_dice": attacker_count - COMBAT_BASE_DICE, "defender_bonus_dice": defender_count - COMBAT_BASE_DICE,
		"attacker_sixes": int(attacker_pool.sixes), "defender_sixes": int(defender_pool.sixes),
		"attacker_score": attacker_score, "defender_score": defender_score, "shot_type": shot_type,
		"hit": hit, "attacker_damage": 0, "defender_damage": defender_damage,
		"critical_attacker": net_attacker_sixes > 0, "critical_defender": false,
		"score_winner": "attacker" if hit else "defender",
	}


## Average of the single highest die in a pool of `count` d6.
func expected_high_die(count: int) -> float:
	var pool := maxi(1, count)
	var total := 0.0
	for face in range(1, COMBAT_DIE_FACES + 1):
		var at_most := pow(float(face) / float(COMBAT_DIE_FACES), pool)
		var below := pow(float(face - 1) / float(COMBAT_DIE_FACES), pool)
		total += float(face) * (at_most - below)
	return total


## What a formation can expect to score against one specific opponent. Unlike
## the old flat-bonus version this cannot be evaluated in a vacuum - the pool
## size is a comparison, so the opponent has to be named.
func expected_battle_score(piece: Dictionary, opponent: Dictionary, is_attacker: bool) -> float:
	if piece.is_empty() or String(piece.get("type", "")) == FLAG: return 0.0
	var role := String(piece.get("role", ""))
	var role_die: bool = (is_attacker and role == ROLE_CAVALRY) or (not is_attacker and role == ROLE_INFANTRY)
	var count := _combat_dice_count(piece, _weight_rank(opponent), int(opponent.get("strength", -1)), role_die)
	return expected_high_die(count) + float(piece.strength)


func melee_advantage(attacker: Dictionary, defender: Dictionary) -> float:
	if String(defender.get("type", "")) == FLAG: return 100.0
	return expected_battle_score(attacker, defender, true) - expected_battle_score(defender, attacker, false)


## Every (highest die, number of 6s) result a pool of `count` d6 can produce,
## with its probability. Enumerated as a joint distribution rather than two
## independent ones because they are not independent: the highest die is a 6
## exactly when at least one 6 was rolled.
func _pool_outcomes(count: int) -> Array:
	var pool := maxi(1, count)
	var outcomes: Array = []
	for face in range(1, COMBAT_DIE_FACES):
		var chance := pow(float(face) / float(COMBAT_DIE_FACES), pool) - pow(float(face - 1) / float(COMBAT_DIE_FACES), pool)
		if chance > 0.0: outcomes.append({"high": face, "sixes": 0, "chance": chance})
	for sixes in range(1, pool + 1):
		var chance := float(_binomial(pool, sixes)) * pow(1.0 / float(COMBAT_DIE_FACES), sixes) * pow(float(COMBAT_DIE_FACES - 1) / float(COMBAT_DIE_FACES), pool - sixes)
		outcomes.append({"high": COMBAT_DIE_FACES, "sixes": sixes, "chance": chance})
	return outcomes


func _binomial(n: int, k: int) -> int:
	var result := 1
	for step in range(k): result = result * (n - step) / (step + 1)
	return result


## Expected damage from one shot, margin and crits together. The crit term has
## to be in here now that it is the whole of a hopeless shot's value: leaving it
## out would tell the bot that firing on something far too tough is worth
## exactly nothing, when an uncancelled 6 still finds a gap.
func expected_ranged_damage(attacker: Dictionary, defender: Dictionary, shot_type: String = SHOT_SHORT) -> float:
	if defender.is_empty() or String(defender.get("type", "")) == FLAG: return 0.0
	var attacker_count := _combat_dice_count(attacker, _weight_rank(defender), int(defender.strength), shot_type == SHOT_SHORT)
	var defender_count := _combat_dice_count(defender, _weight_rank(attacker), int(attacker.strength), false)
	var defender_outcomes := _pool_outcomes(defender_count)
	var total := 0.0
	for attacker_outcome: Dictionary in _pool_outcomes(attacker_count):
		for defender_outcome: Dictionary in defender_outcomes:
			var margin := (int(attacker_outcome.high) + int(attacker.strength)) - (int(defender_outcome.high) + int(defender.strength))
			var damage := maxi(0, margin) + maxi(0, int(attacker_outcome.sixes) - int(defender_outcome.sixes))
			if damage > 0:
				total += float(attacker_outcome.chance) * float(defender_outcome.chance) * float(damage)
	return total


func set_forced_rolls(raw_rolls: Array[int]) -> void:
	_forced_rolls.assign(raw_rolls)


func _roll_d6() -> int:
	var result: int = _forced_rolls.pop_front() if not _forced_rolls.is_empty() else _rng.randi_range(1, COMBAT_DIE_FACES)
	_roll_history.append(result)
	return result


## Roll a pool and reduce it to the two numbers combat actually consumes: the
## single highest die, and how many 6s came up. Forced rolls are drained in
## pool order, so a test supplies one value per die, not one per formation.
func _roll_dice_pool(count: int, forced: Array = []) -> Dictionary:
	var dice: Array[int] = []
	for index in maxi(1, count):
		if index < forced.size():
			dice.append(clampi(int(forced[index]), 1, COMBAT_DIE_FACES))
		else:
			dice.append(_roll_d6())
	var highest := 0
	var sixes := 0
	for die in dice:
		highest = maxi(highest, die)
		if die == COMBAT_DIE_FACES: sixes += 1
	return {"dice": dice, "high": highest, "sixes": sixes}


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
			})
	return encoded


func _encode_leftover_orders() -> Array[Dictionary]:
	var encoded: Array[Dictionary] = []
	for player in PLAYER_ORDER:
		var ids: Array = orders.get(player, {}).keys()
		ids.sort()
		for id_value in ids:
			var piece_id := int(id_value)
			var order: Dictionary = orders[player][piece_id]
			var move_target: Vector2i = order.get("leftover", Vector2i(-1, -1))
			var ranged_target: Vector2i = order.get("ranged_target", Vector2i(-1, -1))
			if move_target.x >= 0:
				encoded.append({"player": player, "piece_id": piece_id, "action": "move", "target": _encode_position(move_target)})
			elif ranged_target.x >= 0:
				encoded.append({
					"player": player, "piece_id": piece_id, "action": "ranged",
					"target": _encode_position(ranged_target),
					"target_id": int(order.get("ranged_target_id", -1)),
				})
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
			"movement": movement_limit_for(piece),
			"movement_used": int(piece.movement_used),
			"movement_available": _movement_available_for(piece),
			"position": _encode_position(piece.position),
			"status": String(piece.round_status), "main_done": bool(piece.main_done),
			"planned_path": path,
			"planned_ranged": _encode_position(order.get("ranged_target", Vector2i(-1, -1))),
			"planned_ranged_id": int(order.get("ranged_target_id", -1)),
			"shot_type": String(order.get("shot_type", "")),
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
		"fog": false, "viewer": player, "grid": GRID_TYPE,
		"board_size": BOARD_SIZE, "board_width": BOARD_SIZE, "board_height": BOARD_SIZE,
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
	if phase not in [PHASE_PLANNING, PHASE_LEFTOVER_PLANNING, PHASE_GAME_OVER]:
		return {}
	# Main movement and melee are resolved as one authoritative batch before the
	# UI presents them one contact at a time. During that review the game is
	# already waiting for post-clash actions, and this record contains everything
	# needed to reproduce the current in-progress round exactly.
	var partial_round: Dictionary = {}
	if phase == PHASE_LEFTOVER_PLANNING:
		if _active_replay_round.is_empty():
			return {}
		partial_round = _active_replay_round.duplicate(true)
	var teams: Array = []
	for player in PLAYER_ORDER:
		if player in player_teams:
			teams.append([player, int(player_teams[player])])
	return {
		"format": REPLAY_FORMAT,
		"version": REPLAY_VERSION,
		"setup": {
			"scenario": scenario, "seed": setup_seed, "player_count": configured_player_count,
			"grid": GRID_TYPE, "board_width": BOARD_SIZE, "board_height": BOARD_SIZE,
			"private_battle_results": private_battle_results, "vision_range": vision_range,
			"bridge_attacker": bridge_attacker, "bridge_defender": bridge_defender,
			"bridge_turn_limit": bridge_turn_limit, "bridge_strength_target": bridge_strength_target,
			"meeting_hold_rounds": _meeting_hold_rounds, "meeting_turn_limit": _meeting_turn_limit,
			"skirmish_turn_limit": _skirmish_turn_limit, "skirmish_separation": _skirmish_separation,
			"teams": teams, "deployment": deployment_placements.duplicate(true),
			"campaign_battle": campaign_battle_data.duplicate(true),
		},
		"rounds": replay_rounds.duplicate(true),
		"partial_round": partial_round,
		"capture": {
			"in_progress": not game_over,
			"round": round_number,
			"phase": phase,
			"completed_rounds": replay_rounds.size(),
		},
		# Every combat this match already produced, kept inline rather than
		# left implicit in the orders and dice. Reading what happened should
		# not require a second engine to replay the match and recompute it.
		"battle_history": battle_history.duplicate(true),
		"terminal": {
			"game_over": game_over, "winner": winner, "end_reason": end_reason,
			"withdrawal_player": withdrawing_player,
		},
		"final_state_digest": state_digest(),
	}


func save_replay(path: String) -> Dictionary:
	var document := build_replay_document()
	if document.is_empty():
		return {"ok": false, "message": "The battle has not reached a replayable state yet."}
	var absolute_path := ProjectSettings.globalize_path(path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK:
		return {"ok": false, "message": "Could not create the replay folder."}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Could not open the replay file for writing."}
	file.store_string(JSON.stringify(document, "  "))
	file.close()
	return {
		"ok": true,
		"path": absolute_path,
		"rounds": replay_rounds.size(),
		"in_progress": bool(document.get("capture", {}).get("in_progress", false)),
		"partial_round": not document.get("partial_round", {}).is_empty(),
		"digest": String(document.final_state_digest),
	}


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
			"ranged_target": Vector2i(-1, -1), "ranged_target_id": -1,
			"leftover": Vector2i(-1, -1),
		}
		if player not in orders:
			orders[player] = {}
		orders[player][piece_id] = candidate
		candidates.append(candidate)
	for candidate: Dictionary in candidates:
		# Not strict: a recorded order is a fact, not a proposal to validate.
		# It already happened, however permissively the UI accepted it - the
		# board issues orders permissively precisely because a square a
		# friendly formation holds may clear before the step comes off, and
		# replay's job is to reproduce what was submitted, not to re-judge it
		# under a stricter rule than was actually in force.
		var result := set_unit_order(int(candidate.player), int(candidate.piece_id), candidate.path, Vector2i(-1, -1), Vector2i(-1, -1), -1, false)
		if not bool(result.get("ok", false)):
			orders.clear()
			return {"ok": false, "message": "Recorded main order rejected: %s" % String(result.get("message", "invalid order"))}
	return {"ok": true, "count": candidates.size()}


func apply_replay_leftover_orders(encoded_orders: Array) -> Dictionary:
	if phase != PHASE_LEFTOVER_PLANNING or not ready_players.is_empty():
		return {"ok": false, "message": "Post-clash replay actions require an open reposition phase."}
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
		var action := String(entry.get("action", ""))
		var target := _decode_position(entry.get("target", [-1, -1]))
		if piece_id in seen_ids or not can_receive_leftover_order(player, piece_id):
			return {"ok": false, "message": "A recorded leftover order references an ineligible formation."}
		seen_ids[piece_id] = true
		var result: Dictionary
		if action == "move":
			result = set_leftover_order(player, piece_id, target)
		elif action == "ranged":
			result = set_ranged_order(player, piece_id, target, int(entry.get("target_id", -1)))
		else:
			return {"ok": false, "message": "A recorded post-clash action has an unknown type."}
		if not bool(result.get("ok", false)):
			return {"ok": false, "message": "A recorded post-clash action was rejected: %s" % String(result.get("message", "invalid order"))}
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
	if String(setup.get("grid", "")) != GRID_TYPE:
		return {"ok": false, "message": "This replay was recorded on a different board topology."}
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
	elif replay_scenario == SCENARIO_CAMPAIGN:
		# A campaign battle has no fixed roster to fall back on - the whole
		# point is that the armies are whatever survived the last one - so the
		# scenario description itself travels with the replay rather than
		# being reduced to a seed and a few numbers.
		var campaign_result := CampaignScenario.apply(replay_game, setup.get("campaign_battle", {}))
		if not bool(campaign_result.get("ok", false)):
			return campaign_result
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
			return {"ok": false, "message": "Replay diverged during the main clash of round %d." % replay_game.round_number}
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
			return {"ok": false, "message": "Replay diverged during post-clash actions in round %d." % int(round_record.get("round", -1))}
		all_events.append_array(leftover_events)
	var partial_value: Variant = document.get("partial_round", {})
	if partial_value is Dictionary and not partial_value.is_empty():
		var partial_round: Dictionary = partial_value
		if replay_game.round_number != int(partial_round.get("round", -1)):
			return {"ok": false, "message": "In-progress replay round numbering does not match the simulation."}
		var partial_order_result := replay_game.apply_replay_main_orders(partial_round.get("main_orders", []))
		if not bool(partial_order_result.get("ok", false)):
			return partial_order_result
		var partial_roll_values: Array = partial_round.get("main_rolls", [])
		var partial_rolls := _decode_rolls(partial_roll_values)
		if partial_rolls.size() != partial_roll_values.size():
			return {"ok": false, "message": "In-progress replay contains an invalid main-phase die roll."}
		replay_game.set_forced_rolls(partial_rolls)
		for player in replay_game.active_players:
			replay_game.mark_player_ready(player)
		var partial_roll_start := replay_game._roll_history.size()
		var partial_events := replay_game.resolve_main_and_ranged()
		if replay_game._roll_history.size() - partial_roll_start != partial_rolls.size():
			return {"ok": false, "message": "In-progress replay main-phase dice consumption diverged."}
		if String(partial_round.get("main_event_digest", "")) != _digest_value(partial_events) or String(partial_round.get("main_state_digest", "")) != replay_game.state_digest():
			return {"ok": false, "message": "Replay diverged during the in-progress round."}
		all_events.append_array(partial_events)
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
	return "%s — Strength %d/%d · Move %d" % [PIECE_NAMES[piece.type], int(piece.strength), int(piece.max_strength), movement_limit_for(piece)]


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
	for destination: Vector2i in neighbors(from):
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
