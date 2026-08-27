extends SceneTree

var games := 32
var seed_value := 0
var player_count := 4
var private_battle_results := true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_parse_arguments()
	var trainer := SelfPlayTrainer.new()
	trainer.player_count = player_count
	trainer.private_battle_results = private_battle_results
	var first_policy := StrategoBotPolicy.new()
	var second_policy := StrategoBotPolicy.new()
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var wins: Dictionary = {}
	var draws := 0
	var total_rounds := 0
	var seats := StrategoGame.players_for_count(player_count)
	print("WEGO heuristic self-play diagnostic: %d games, %d players" % [games, player_count])
	print("No champion model is persisted while the simultaneous-order action space is still changing.")
	for index in games:
		var candidate_side: int = seats[index % seats.size()]
		var result := trainer.play_match(first_policy, second_policy, candidate_side, rng.randi())
		total_rounds += int(result.rounds)
		if int(result.winner) == StrategoGame.DRAW:
			draws += 1
		else:
			wins[int(result.winner)] = int(wins.get(int(result.winner), 0)) + 1
	print("Completed %d games; %d draws; average %.1f rounds." % [games, draws, float(total_rounds) / float(games)])
	for player in StrategoGame.players_for_count(player_count):
		print("  %s wins: %d" % [StrategoGame.new().player_name(player), int(wins.get(player, 0))])
	quit(0)


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--games="):
			games = maxi(1, int(argument.trim_prefix("--games=")))
		elif argument.begins_with("--seed="):
			seed_value = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--players="):
			player_count = clampi(int(argument.trim_prefix("--players=")), 2, 4)
		elif argument.begins_with("--private-battles="):
			private_battle_results = argument.trim_prefix("--private-battles=").to_lower() not in ["false", "0", "off"]
