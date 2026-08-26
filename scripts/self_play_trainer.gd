class_name SelfPlayTrainer
extends RefCounted

var total_matches := 0
var candidate_wins := 0
var champion_wins := 0
var draws := 0
var accepted_candidates := 0
var evaluation_games := 8
var pending_candidate: StrategoBotPolicy
var pending_score := 0
var pending_material := 0.0
var pending_matches := 0
var pending_seed := 0


func train_iteration(champion: StrategoBotPolicy, rng: RandomNumberGenerator, match_index: int = 0) -> Dictionary:
	if pending_candidate == null:
		var mutation_strength := maxf(0.18, 0.55 * pow(0.9995, float(champion.games_trained)))
		pending_candidate = champion.mutated_sparse(rng, mutation_strength, rng.randi_range(2, 4))
		pending_score = 0
		pending_material = 0.0
		pending_matches = 0
	var candidate_side := StrategoGame.BLUE if pending_matches % 2 == 0 else StrategoGame.RED
	if pending_matches % 2 == 0:
		pending_seed = rng.randi()
	var result := play_match(pending_candidate, champion, candidate_side, pending_seed)
	total_matches += 1
	champion.games_trained += 1
	pending_matches += 1
	pending_score += int(result.candidate_result)
	pending_material += float(result.material_delta)

	var accepted := false
	if result.candidate_result > 0:
		candidate_wins += 1
	elif result.candidate_result < 0:
		champion_wins += 1
	else:
		draws += 1

	# Evaluate each mutation across paired colors and multiple randomized
	# setups. This filters out upgrades that merely received a lucky army.
	if pending_matches >= evaluation_games:
		accepted = pending_score > 0 or (pending_score == 0 and pending_material / float(pending_matches) > 2.0)
		if accepted:
			pending_candidate.games_trained = champion.games_trained
			champion.copy_from(pending_candidate)
			accepted_candidates += 1
		pending_candidate = null
	return {
		"accepted": accepted,
		"evaluation_complete": pending_candidate == null,
		"winner": result.winner,
		"candidate_side": candidate_side,
		"plies": result.plies,
		"material_delta": result.material_delta,
	}


func reset_pending() -> void:
	pending_candidate = null
	pending_score = 0
	pending_material = 0.0
	pending_matches = 0
	pending_seed = 0


func evaluate_policies(challenger: StrategoBotPolicy, incumbent: StrategoBotPolicy, matches: int, rng: RandomNumberGenerator) -> Dictionary:
	var match_count := maxi(2, matches)
	if match_count % 2 != 0:
		match_count += 1
	var challenger_wins := 0
	var incumbent_wins := 0
	var evaluation_draws := 0
	var material_total := 0.0
	var pair_seed := 0
	var plies_total := 0
	for i in match_count:
		if i % 2 == 0:
			pair_seed = rng.randi()
		var challenger_side := StrategoGame.BLUE if i % 2 == 0 else StrategoGame.RED
		var result := play_match(challenger, incumbent, challenger_side, pair_seed)
		plies_total += int(result.plies)
		material_total += float(result.material_delta)
		if int(result.candidate_result) > 0:
			challenger_wins += 1
		elif int(result.candidate_result) < 0:
			incumbent_wins += 1
		else:
			evaluation_draws += 1
	return {
		"matches": match_count,
		"challenger_wins": challenger_wins,
		"incumbent_wins": incumbent_wins,
		"draws": evaluation_draws,
		"score_margin": challenger_wins - incumbent_wins,
		"average_material": material_total / float(match_count),
		"average_plies": float(plies_total) / float(match_count),
	}


func play_match(candidate: StrategoBotPolicy, champion: StrategoBotPolicy, candidate_side: int, seed_value: int) -> Dictionary:
	var game := StrategoGame.new()
	game.max_plies = 350
	game.setup_random(seed_value)
	var blue_policy := candidate if candidate_side == StrategoGame.BLUE else champion
	var red_policy := candidate if candidate_side == StrategoGame.RED else champion
	var blue_rng := RandomNumberGenerator.new()
	var red_rng := RandomNumberGenerator.new()
	blue_rng.seed = seed_value ^ 0x13579B
	red_rng.seed = seed_value ^ 0x2468AC

	while not game.game_over:
		var active_policy: StrategoBotPolicy = blue_policy if game.current_player == StrategoGame.BLUE else red_policy
		var active_rng := blue_rng if game.current_player == StrategoGame.BLUE else red_rng
		var move := active_policy.choose_move(game, game.current_player, active_rng)
		if move.is_empty():
			game.game_over = true
			game.winner = game.other_player(game.current_player)
			break
		game.apply_move(move.from, move.to)

	var opponent_side := game.other_player(candidate_side)
	var candidate_result := 0
	if game.winner == candidate_side:
		candidate_result = 1
	elif game.winner == opponent_side:
		candidate_result = -1
	return {
		"candidate_result": candidate_result,
		"winner": game.winner,
		"plies": game.ply_count,
		"material_delta": game.get_material_score(candidate_side) - game.get_material_score(opponent_side),
	}


func summary() -> String:
	return "%d matches  •  candidate %d–%d champion  •  %d draws  •  %d upgrades" % [
		total_matches, candidate_wins, champion_wins, draws, accepted_candidates
	]
