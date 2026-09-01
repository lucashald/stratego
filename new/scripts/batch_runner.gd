extends SceneTree

# Bot-vs-bot batch runner. Both sides are the heuristic bot, so results reflect
# unit design and scenario shape rather than one player's mistakes.
#
#   godot --headless --path . --script res://scripts/batch_runner.gd -- --games 200 --scenario skirmish
#
# skirmish is the control: bare board, no terrain, no positional objective, two
# facing lines --sep rows apart, win by destroying the other army. --blue and
# --red take rosters like "LC:4,LA:4" so a single matchup can be isolated.
#
# Damage alone cannot detect a formation whose job is to stand on an objective
# and still be there at the end, so this also tracks objective occupancy,
# how quickly each weight reaches the contested ground, and melees won while
# defending rather than attacking.

var games := 100
var scenario := StrategoGame.SCENARIO_MEETING
var starting_seed := 1
var separation := 3
var blue_roster: Array = StrategoGame.MEETING_ROSTER
var red_roster: Array = StrategoGame.MEETING_ROSTER
var weight_overrides: Dictionary = {}
var blue_weight_overrides: Dictionary = {}
var red_weight_overrides: Dictionary = {}
var assume_blue: Dictionary = {}
var assume_red: Dictionary = {}
var side_wins: Dictionary = {}
var team_wins: Dictionary = {}
var cavalry_always_leftover := true
## -1 (StrategoGame.DRAW) means no cheater: an ordinary symmetric run. Set by
## --cheater blue|red.
var cheater_side := StrategoGame.DRAW
var sweep_field := ""
var sweep_values: Array = []
var sweep_weight_field := ""
var sweep_weight_values: Array = []


func _initialize() -> void:
	var arguments := _parse_arguments()
	games = int(arguments.get("games", games))
	scenario = String(arguments.get("scenario", scenario))
	starting_seed = int(arguments.get("seed", starting_seed))
	separation = int(arguments.get("sep", separation))
	# --cavalryleftover 1 lets Cavalry always take the leftover move, even
	# after fully spending its main-phase movement. A/B this against a plain
	# run of the same seeds to see whether it closes Heavy Cavalry's arrival
	# gap in Meeting.
	cavalry_always_leftover = String(arguments.get("cavalryleftover", "1")) == "1"
	# --w key=value,key=value overrides bot weights, for isolating one feature.
	if arguments.has("w"):
		for pair in String(arguments.w).split(",", false):
			var halves := String(pair).split("=")
			if halves.size() == 2: weight_overrides[String(halves[0]).strip_edges()] = float(halves[1])
	# --assume / --assumeblue / --assumered set what a bot pretends an
	# unidentified enemy is, e.g. "role=infantry,strength=5,weight=medium".
	if arguments.has("assume"):
		assume_blue = _parse_assumption(String(arguments.assume))
		assume_red = assume_blue.duplicate()
	if arguments.has("assumeblue"): assume_blue = _parse_assumption(String(arguments.assumeblue))
	if arguments.has("assumered"): assume_red = _parse_assumption(String(arguments.assumered))
	if arguments.has("blue"): blue_roster = _parse_roster(String(arguments.blue))
	if arguments.has("red"): red_roster = _parse_roster(String(arguments.red))
	# --cheater blue|red makes that side's bot read every enemy's true stats
	# instead of guessing. Pairs with --sweep to calibrate the guess: e.g.
	#   --cheater blue --sweep strength=3,4,5,6,7,8
	# runs the same cheater-vs-honest matchup once per assumed strength and
	# reports where the cheater's win-rate edge over the honest bot is
	# smallest - the assumption that costs the honest bot the least. Two
	# players only; not meaningful against crossroads/four_player.
	if arguments.has("cheater"):
		var side := String(arguments.cheater).strip_edges().to_lower()
		cheater_side = StrategoGame.BLUE if side == "blue" else (StrategoGame.RED if side == "red" else StrategoGame.DRAW)
	if arguments.has("sweep"):
		var spec := String(arguments.sweep)
		var split_at := spec.find("=")
		if split_at > 0:
			sweep_field = spec.substr(0, split_at).strip_edges()
			for raw in spec.substr(split_at + 1).split(",", false):
				var value := String(raw).strip_edges()
				sweep_values.append(int(value) if sweep_field == "strength" else value)
	# --sweepweight field=v1,v2,... A direct head-to-head, not a cheater
	# comparison: Blue plays each value of one scoring weight in turn, Red
	# stays at the defaults throughout, both otherwise identical. For tuning
	# a weight like objective_progress rather than the unknown-enemy guess.
	if arguments.has("sweepweight"):
		var spec := String(arguments.sweepweight)
		var split_at := spec.find("=")
		if split_at > 0:
			sweep_weight_field = spec.substr(0, split_at).strip_edges()
			for raw in spec.substr(split_at + 1).split(",", false):
				sweep_weight_values.append(float(String(raw).strip_edges()))
	if not sweep_field.is_empty() and cheater_side != StrategoGame.DRAW:
		_run_sweep()
	elif not sweep_weight_field.is_empty():
		_run_weight_sweep()
	else:
		var totals: Dictionary = {}
		var outcomes: Dictionary = {}
		var round_total := 0
		for index in games:
			var result := _play_one(starting_seed + index, totals)
			outcomes[result] = int(outcomes.get(result, 0)) + 1
			round_total += _last_rounds
		_report(totals, outcomes, round_total)
	quit()


func _side_name(player: int) -> String:
	return "Blue" if player == StrategoGame.BLUE else "Red"


## Runs `games` games once per swept value, applying each value to the honest
## side's assumption while the cheater side stays omniscient throughout, and
## prints the cheater's win rate at each - the value with the lowest rate is
## the assumption that best approximates the truth.
func _run_sweep() -> void:
	var honest_side := StrategoGame.RED if cheater_side == StrategoGame.BLUE else StrategoGame.BLUE
	print("\nsweeping %s over %s | cheater=%s honest=%s | %d games each" % [sweep_field, str(sweep_values), _side_name(cheater_side), _side_name(honest_side), games])
	print("%-12s %10s %10s %8s %8s" % [sweep_field, "cheater%", "honest%", "draw%", "avg len"])
	var best_value = null
	var best_cheater_pct := 101.0
	for value in sweep_values:
		var profile := {sweep_field: value}
		if honest_side == StrategoGame.BLUE: assume_blue = profile
		else: assume_red = profile
		side_wins.clear()
		team_wins.clear()
		var totals: Dictionary = {}
		var outcomes: Dictionary = {}
		var round_total := 0
		for index in games:
			var result := _play_one(starting_seed + index, totals)
			outcomes[result] = int(outcomes.get(result, 0)) + 1
			round_total += _last_rounds
		var cheater_wins := int(side_wins.get(_side_name(cheater_side), 0))
		var honest_wins := int(side_wins.get(_side_name(honest_side), 0))
		var draws := int(side_wins.get("draw", 0))
		var cheater_pct := 100.0 * float(cheater_wins) / float(games)
		var honest_pct := 100.0 * float(honest_wins) / float(games)
		var draw_pct := 100.0 * float(draws) / float(games)
		print("%-12s %9.1f%% %9.1f%% %7.1f%% %8.1f" % [str(value), cheater_pct, honest_pct, draw_pct, float(round_total) / float(games)])
		if cheater_pct < best_cheater_pct:
			best_cheater_pct = cheater_pct
			best_value = value
	print("\nsmallest cheater edge at %s = %s (%.1f%% cheater win rate). The cheater strictly knows more, so 50/50 is the floor, not necessarily reachable." % [sweep_field, str(best_value), best_cheater_pct])


## Runs `games` games once per swept value of one bot weight, applied to Blue
## only; Red stays at the plain defaults throughout. Direct win rate, not a
## cheater comparison - for tuning a scoring weight like objective_progress
## against an unchanged opponent rather than calibrating the unknown-enemy
## assumption.
func _run_weight_sweep() -> void:
	print("\nsweeping weights.%s over %s | Blue swept vs Red baseline | %d games each" % [sweep_weight_field, str(sweep_weight_values), games])
	print("%-12s %10s %10s %8s %8s" % [sweep_weight_field, "blue%", "red%", "draw%", "avg len"])
	var best_value = null
	var best_blue_pct := -1.0
	for value in sweep_weight_values:
		blue_weight_overrides = {sweep_weight_field: value}
		side_wins.clear()
		team_wins.clear()
		var totals: Dictionary = {}
		var outcomes: Dictionary = {}
		var round_total := 0
		for index in games:
			var result := _play_one(starting_seed + index, totals)
			outcomes[result] = int(outcomes.get(result, 0)) + 1
			round_total += _last_rounds
		var blue_wins := int(side_wins.get("Blue", 0))
		var red_wins := int(side_wins.get("Red", 0))
		var draws := int(side_wins.get("draw", 0))
		var blue_pct := 100.0 * float(blue_wins) / float(games)
		var red_pct := 100.0 * float(red_wins) / float(games)
		var draw_pct := 100.0 * float(draws) / float(games)
		print("%-12s %9.1f%% %9.1f%% %7.1f%% %8.1f" % [str(value), blue_pct, red_pct, draw_pct, float(round_total) / float(games)])
		if blue_pct > best_blue_pct:
			best_blue_pct = blue_pct
			best_value = value
	print("\nbest %s = %s (%.1f%% win rate for Blue against the Red baseline)" % [sweep_weight_field, str(best_value), best_blue_pct])


var _last_rounds := 0
var _melee_shapes: Dictionary = {}


func _play_one(seed_value: int, totals: Dictionary) -> String:
	var game := StrategoGame.new()
	if scenario == StrategoGame.SCENARIO_MEETING: game.setup_meeting(seed_value)
	elif scenario == "meeting_inverted": _setup_meeting_inverted(game)
	elif scenario == "meeting_heavycav": _setup_meeting_heavy_cavalry(game)
	elif scenario == StrategoGame.SCENARIO_SKIRMISH: game.setup_skirmish(seed_value, blue_roster, red_roster, separation)
	elif scenario == "crossroads": game.setup_crossroads(seed_value)
	else: game.setup_bridge(seed_value)
	game.cavalry_always_leftover = cavalry_always_leftover
	# Bots accept the recommended formation as-is; nothing here optimizes a
	# deployment. That is deliberate: it leaves deployment choice as a lever a
	# human player can use against a bot that never bothers to.
	if game.phase == StrategoGame.PHASE_DEPLOYMENT:
		for player in game.active_players: game.mark_player_ready(player)
		game.resolve_deployment()
	# One policy per side so the two can hold different assumptions. Beyond two
	# players --assumeblue is the only profile in play; every bot shares it.
	var bots: Dictionary = {}
	for player in game.active_players:
		var policy := StrategoBotPolicy.new()
		for key in weight_overrides: policy.weights[key] = float(weight_overrides[key])
		# Per-side overrides layer on top of the symmetric ones above, so a
		# weight sweep can change Blue alone and leave Red at the defaults -
		# --w changes both sides uniformly, for asking "is this weight good in
		# general"; these ask "does this side benefit against an unchanged
		# opponent."
		var side_overrides: Dictionary = blue_weight_overrides if player == StrategoGame.BLUE else (red_weight_overrides if player == StrategoGame.RED else {})
		for key in side_overrides: policy.weights[key] = float(side_overrides[key])
		var profile: Dictionary = assume_blue if (player == StrategoGame.BLUE or game.active_players.size() > 2) else assume_red
		for key in profile: policy.assumptions[key] = profile[key]
		if player == cheater_side: policy.omniscient = true
		bots[player] = policy
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Skirmish has no positional objective, so occupancy is meaningless there.
	var objective := game.objective_aim_point(StrategoGame.BLUE)
	var first_arrival: Dictionary = {}
	var occupancy: Dictionary = {}
	var guard := 0
	while not game.game_over and guard < 200:
		guard += 1
		for player in game.active_players.duplicate():
			bots[player].plan_round(game, player, rng)
			game.mark_player_ready(player)
		game.resolve_main_and_ranged()
		if game.game_over: break
		for player in game.active_players.duplicate():
			bots[player].plan_leftover(game, player, rng)
			game.mark_player_ready(player)
		game.resolve_leftover_phase()
		# Objective occupancy and time-to-objective, measured per formation.
		for piece: Dictionary in game.pieces:
			if not piece.alive or piece.type == StrategoGame.FLAG: continue
			var code := String(piece.type)
			if piece.position == objective:
				occupancy[code] = int(occupancy.get(code, 0)) + 1
			if StrategoGame.grid_distance(piece.position, objective) <= 1 and code not in first_arrival:
				first_arrival[code] = game.round_number
	for event: Dictionary in game.battle_history:
		if bool(event.get("ranged", false)): continue
		var label := "crossing" if bool(event.get("crossing", false)) else String(event.get("action", "melee"))
		_melee_shapes[label] = int(_melee_shapes.get(label, 0)) + 1
	_last_rounds = game.round_number
	_accumulate(game, totals, occupancy, first_arrival)
	var label := "draw" if game.winner == StrategoGame.DRAW else game.player_name(game.winner)
	side_wins[label] = int(side_wins.get(label, 0)) + 1
	# In a team scenario the individual winner is whichever ally happened to be
	# first in turn order when the streak completed; the team is what matters.
	if scenario == "crossroads":
		var team_label := "draw" if game.winning_team == StrategoGame.DRAW else game.player_name(game.winning_team)
		team_wins[team_label] = int(team_wins.get(team_label, 0)) + 1
	if game.winner == StrategoGame.DRAW: return "draw"
	return game.end_reason


## A stress test for the Cavalry-leftover toggle, not a shipped scenario: the
## opposite of Meeting's battle line. Meeting deliberately puts Heavies at the
## front rank to compensate for their low movement (see _place_battle_line);
## this puts them at the back instead, and Lights at the front across two
## ranks, so Light Cavalry starts as close to the objective as a formation can
## get while also being the biggest beneficiary of the toggle. If LC is going
## to look overpowered anywhere, it should be here.
func _setup_meeting_inverted(game: StrategoGame) -> void:
	game.setup_empty()
	game.scenario = StrategoGame.SCENARIO_MEETING
	game.configured_player_count = 2
	game.apply_lake_terrain()
	game.player_teams[StrategoGame.BLUE] = StrategoGame.BLUE
	game.player_teams[StrategoGame.RED] = StrategoGame.RED
	var objective := Vector2i(StrategoGame.BOARD_SIZE / 2, StrategoGame.BOARD_SIZE / 2)
	# rank 0 (nearest the objective) through rank 3 (furthest back), matching
	# "rank 1/2/3/4" counted from the front in ordinary speech.
	var ranks := [
		[[StrategoGame.LIGHT_CAVALRY, 3], [StrategoGame.LIGHT_ARCHER, 17]],
		[[StrategoGame.LIGHT_INFANTRY, 4], [StrategoGame.LIGHT_INFANTRY, 16]],
		[[StrategoGame.MEDIUM_INFANTRY, 8], [StrategoGame.MEDIUM_CAVALRY, 9], [StrategoGame.MEDIUM_ARCHER, 11], [StrategoGame.MEDIUM_INFANTRY, 12]],
		[[StrategoGame.HEAVY_INFANTRY, 9], [StrategoGame.HEAVY_ARCHER, 10], [StrategoGame.HEAVY_INFANTRY, 11], [StrategoGame.HEAVY_CAVALRY, 12]],
	]
	# One row shallower than Meeting's own MEETING_FRONT_DISTANCE (7): four
	# ranks at that distance would push the back rank to row 20, off a 20-row
	# board, clamping it onto the same row as rank 2 and silently dropping
	# every colliding piece. Six leaves headroom for all four ranks.
	var reach := 6
	for side in [[StrategoGame.BLUE, 1], [StrategoGame.RED, -1]]:
		var player: int = side[0]
		var step: int = side[1]
		var front_row: int = objective.y + reach * step
		for rank_index in ranks.size():
			for entry in ranks[rank_index]:
				var row: int = clampi(front_row + rank_index * step, 0, StrategoGame.BOARD_SIZE - 1)
				var cell := Vector2i(int(entry[1]), row)
				if game.is_blocked_terrain(cell) or not game.piece_at(cell).is_empty(): continue
				game.add_piece(String(entry[0]), player, cell)
	game.add_hold_square_objective(objective, StrategoGame.DEFAULT_HOLD_ROUNDS, StrategoGame.DEFAULT_BRIDGE_TURN_LIMIT)
	game.active_players.assign([StrategoGame.RED, StrategoGame.BLUE])
	game.current_player = StrategoGame.BLUE
	game._record_all_sightings()


## Meeting's real battle line (front rank nearest the objective, same columns
## and MEETING_FRONT_DISTANCE), except the front rank is four Heavy Cavalry
## instead of the usual 2 Heavy Infantry + Heavy Archer + Heavy Cavalry mix.
## The traffic jam that stopped Heavy Cavalry from using its leftover move in
## the standard formation came from sharing that rank with slower heavies
## competing for the same lanes; this isolates whether the jam was really
## about the mixed company, not Cavalry-with-the-toggle inherently.
func _setup_meeting_heavy_cavalry(game: StrategoGame) -> void:
	game.setup_empty()
	game.scenario = StrategoGame.SCENARIO_MEETING
	game.configured_player_count = 2
	game.apply_lake_terrain()
	game.player_teams[StrategoGame.BLUE] = StrategoGame.BLUE
	game.player_teams[StrategoGame.RED] = StrategoGame.RED
	var objective := Vector2i(StrategoGame.BOARD_SIZE / 2, StrategoGame.BOARD_SIZE / 2)
	var deployment := [
		[StrategoGame.HEAVY_CAVALRY, 9, 0], [StrategoGame.HEAVY_CAVALRY, 10, 0], [StrategoGame.HEAVY_CAVALRY, 11, 0], [StrategoGame.HEAVY_CAVALRY, 12, 0],
		[StrategoGame.MEDIUM_INFANTRY, 8, 1], [StrategoGame.MEDIUM_CAVALRY, 9, 1], [StrategoGame.MEDIUM_ARCHER, 11, 1], [StrategoGame.MEDIUM_INFANTRY, 12, 1],
		[StrategoGame.LIGHT_CAVALRY, 3, 2], [StrategoGame.LIGHT_INFANTRY, 4, 2], [StrategoGame.LIGHT_INFANTRY, 16, 2], [StrategoGame.LIGHT_ARCHER, 17, 2],
	]
	for side in [[StrategoGame.BLUE, 1], [StrategoGame.RED, -1]]:
		var player: int = side[0]
		var step: int = side[1]
		var front_row: int = objective.y + StrategoGame.MEETING_FRONT_DISTANCE * step
		for entry in deployment:
			var row: int = clampi(front_row + int(entry[2]) * step, 0, StrategoGame.BOARD_SIZE - 1)
			var cell := Vector2i(int(entry[1]), row)
			if game.is_blocked_terrain(cell) or not game.piece_at(cell).is_empty(): continue
			game.add_piece(String(entry[0]), player, cell)
	game.add_hold_square_objective(objective, StrategoGame.DEFAULT_HOLD_ROUNDS, StrategoGame.DEFAULT_BRIDGE_TURN_LIMIT)
	game.active_players.assign([StrategoGame.RED, StrategoGame.BLUE])
	game.current_player = StrategoGame.BLUE
	game._record_all_sightings()


func _accumulate(game: StrategoGame, totals: Dictionary, occupancy: Dictionary, first_arrival: Dictionary) -> void:
	var damage := game.combat_damage_summary()
	for id in damage:
		var row: Dictionary = damage[id]
		var code := String(row.code)
		if not code in totals:
			totals[code] = {
				"n": 0, "dealt": 0, "taken": 0, "kills": 0, "battles": 0,
				"survived": 0, "max_strength": 0, "end_strength": 0,
				"held": 0, "arrival_sum": 0, "arrival_n": 0,
			}
		var bucket: Dictionary = totals[code]
		bucket.n += 1
		bucket.dealt += int(row.dealt)
		bucket.taken += int(row.taken)
		bucket.kills += int(row.kills)
		bucket.battles += int(row.battles)
		bucket.max_strength += int(row.max_strength)
		bucket.end_strength += int(row.strength)
		if bool(row.alive): bucket.survived += 1
	for code in occupancy:
		if code in totals: totals[code].held += int(occupancy[code])
	for code in first_arrival:
		if code in totals:
			totals[code].arrival_sum += int(first_arrival[code])
			totals[code].arrival_n += 1


func _report(totals: Dictionary, outcomes: Dictionary, round_total: int) -> void:
	print("\n%d games of %s, seeds %d-%d" % [games, scenario, starting_seed, starting_seed + games - 1])
	print("average length: %.1f rounds" % (float(round_total) / maxf(1.0, float(games))))
	print("outcomes: %s" % JSON.stringify(outcomes))
	if not weight_overrides.is_empty(): print("weight overrides: %s" % JSON.stringify(weight_overrides))
	if not assume_blue.is_empty() or not assume_red.is_empty():
		print("Blue assumes: %s" % JSON.stringify(assume_blue if not assume_blue.is_empty() else StrategoBotPolicy.ASSUMPTION_DEFAULTS))
		print("Red  assumes: %s" % JSON.stringify(assume_red if not assume_red.is_empty() else StrategoBotPolicy.ASSUMPTION_DEFAULTS))
	print("wins by side: %s" % JSON.stringify(side_wins))
	if not team_wins.is_empty(): print("wins by team: %s" % JSON.stringify(team_wins))
	print("melee shapes: %s" % JSON.stringify(_melee_shapes))
	var codes: Array = totals.keys()
	var rank := func(code: String) -> float:
		var row: Dictionary = totals[code]
		if scenario == StrategoGame.SCENARIO_SKIRMISH:
			return (float(row.dealt) - float(row.taken)) / maxf(1.0, float(row.max_strength))
		return float(row.held) / maxf(1.0, float(row.n))
	codes.sort_custom(func(a: String, b: String) -> bool: return rank.call(a) > rank.call(b))
	var positional := scenario != StrategoGame.SCENARIO_SKIRMISH
	if positional:
		print("\n%-5s %5s %8s %8s %7s %8s %9s %8s" % ["code", "n", "dealt/s", "taken/s", "kills", "survive", "held/game", "arrival"])
	else:
		print("\n%-5s %5s %8s %8s %7s %8s %9s" % ["code", "n", "dealt/s", "taken/s", "kills", "survive", "net/s"])
	for code: String in codes:
		var row: Dictionary = totals[code]
		var count := maxf(1.0, float(row.n))
		var strength := maxf(1.0, float(row.max_strength))
		var arrival := (float(row.arrival_sum) / float(row.arrival_n)) if int(row.arrival_n) > 0 else -1.0
		if positional:
			print("%-5s %5d %8.2f %8.2f %7.2f %7.0f%% %9.2f %8s" % [
				code, int(row.n), float(row.dealt) / strength, float(row.taken) / strength,
				float(row.kills) / count, 100.0 * float(row.survived) / count,
				float(row.held) / count, "%.1f" % arrival if arrival > 0 else "never",
			])
		else:
			print("%-5s %5d %8.2f %8.2f %7.2f %7.0f%% %9.2f" % [
				code, int(row.n), float(row.dealt) / strength, float(row.taken) / strength,
				float(row.kills) / count, 100.0 * float(row.survived) / count,
				(float(row.dealt) - float(row.taken)) / strength,
			])
	print("\ndealt/s and taken/s are per point of starting Strength.")
	if positional:
		print("held/game is rounds standing on the objective, counting both sides.")
		print("arrival is the mean round a formation of that type first reached it.")
	else:
		print("net/s is dealt minus taken, per point of starting Strength.")


func _parse_arguments() -> Dictionary:
	var result := {}
	var arguments := OS.get_cmdline_user_args()
	for index in arguments.size():
		var argument := String(arguments[index])
		if argument.begins_with("--") and index + 1 < arguments.size():
			result[argument.substr(2)] = arguments[index + 1]
	return result


## Rosters like "LC:4,LA:4" so one matchup can be tested at a time.
func _parse_roster(spec: String) -> Array:
	var roster: Array = []
	for entry in spec.split(",", false):
		var parts := String(entry).split(":")
		var code := String(parts[0]).strip_edges().to_upper()
		var count := int(parts[1]) if parts.size() > 1 else 1
		for _index in count: roster.append(code)
	return roster


## Assumption specs like "role=infantry,strength=5,weight=medium".
func _parse_assumption(spec: String) -> Dictionary:
	var result: Dictionary = {}
	for pair in spec.split(",", false):
		var halves := String(pair).split("=")
		if halves.size() != 2: continue
		var key := String(halves[0]).strip_edges()
		var value := String(halves[1]).strip_edges()
		result[key] = int(value) if key == "strength" else value
	return result
