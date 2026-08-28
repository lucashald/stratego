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
var assume_blue: Dictionary = {}
var assume_red: Dictionary = {}
var side_wins: Dictionary = {}


func _initialize() -> void:
	var arguments := _parse_arguments()
	games = int(arguments.get("games", games))
	scenario = String(arguments.get("scenario", scenario))
	starting_seed = int(arguments.get("seed", starting_seed))
	separation = int(arguments.get("sep", separation))
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
	var totals: Dictionary = {}
	var outcomes: Dictionary = {}
	var round_total := 0
	for index in games:
		var result := _play_one(starting_seed + index, totals)
		outcomes[result] = int(outcomes.get(result, 0)) + 1
		round_total += _last_rounds
	_report(totals, outcomes, round_total)
	quit()


var _last_rounds := 0
var _melee_shapes: Dictionary = {}


func _play_one(seed_value: int, totals: Dictionary) -> String:
	var game := StrategoGame.new()
	if scenario == StrategoGame.SCENARIO_MEETING: game.setup_meeting(seed_value)
	elif scenario == StrategoGame.SCENARIO_SKIRMISH: game.setup_skirmish(seed_value, blue_roster, red_roster, separation)
	else: game.setup_bridge(seed_value)
	# One policy per side so the two can hold different assumptions.
	var bots: Dictionary = {}
	for player in [StrategoGame.BLUE, StrategoGame.RED]:
		var policy := StrategoBotPolicy.new()
		for key in weight_overrides: policy.weights[key] = float(weight_overrides[key])
		var profile: Dictionary = assume_blue if player == StrategoGame.BLUE else assume_red
		for key in profile: policy.assumptions[key] = profile[key]
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
	if game.winner == StrategoGame.DRAW: return "draw"
	return game.end_reason


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
