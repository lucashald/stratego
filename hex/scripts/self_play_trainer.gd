class_name SelfPlayTrainer
extends RefCounted

var player_count := 4
var private_battle_results := true
var max_rounds := 120


func play_match(candidate: StrategoBotPolicy, champion: StrategoBotPolicy, candidate_side: int, seed_value: int) -> Dictionary:
	var game := StrategoGame.new()
	game.setup_random(seed_value, player_count, private_battle_results)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	while not game.game_over and game.round_number <= max_rounds:
		for player in game.active_players.duplicate():
			var policy := candidate if player == candidate_side else champion
			policy.plan_round(game, player, rng)
			game.mark_player_ready(player)
		game.resolve_round()
	if not game.game_over:
		game.game_over = true
		game.phase = StrategoGame.PHASE_GAME_OVER
		game.winner = StrategoGame.DRAW
		game.end_reason = "round_limit"
	return {"winner": game.winner, "plies": game.ply_count, "rounds": game.round_number, "reason": game.end_reason}


func evaluate_policies(challenger: StrategoBotPolicy, incumbent: StrategoBotPolicy, matches: int, rng: RandomNumberGenerator) -> Dictionary:
	var challenger_wins := 0
	var incumbent_wins := 0
	var draws := 0
	var seats := StrategoGame.players_for_count(player_count)
	for index in maxi(1, matches):
		var candidate_side: int = seats[index % seats.size()]
		var result := play_match(challenger, incumbent, candidate_side, rng.randi())
		if int(result.winner) == candidate_side:
			challenger_wins += 1
		elif int(result.winner) == StrategoGame.DRAW:
			draws += 1
		else:
			incumbent_wins += 1
	return {"challenger_wins": challenger_wins, "incumbent_wins": incumbent_wins, "draws": draws}


func train_iteration(champion: StrategoBotPolicy, rng: RandomNumberGenerator, _match_index: int = 0) -> Dictionary:
	# The next-version policy is heuristic while the WEGO action space settles.
	# Keep the old trainer entry point so launch scripts remain harmless.
	return {"accepted": false, "champion": champion, "challenger": champion, "result": evaluate_policies(champion, champion, 2, rng)}


func reset_pending() -> void:
	pass


func summary() -> String:
	return "WEGO heuristic self-play"
