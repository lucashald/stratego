extends SceneTree

var matches := 200
var challenger_path := StrategoBotPolicy.DEFAULT_USER_PATH
var incumbent_path := "user://stratego_bot_previous_champion.json"
var seed_value := 0
var player_count := 4
var private_battle_results := true
var scout_move_limit := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_parse_arguments()
	if not FileAccess.file_exists(challenger_path):
		printerr("Current model not found: %s" % challenger_path)
		quit(1)
		return
	if not FileAccess.file_exists(incumbent_path):
		printerr("Previous champion not found: %s" % incumbent_path)
		quit(1)
		return
	var challenger := StrategoBotPolicy.load_from_path(challenger_path)
	var incumbent := StrategoBotPolicy.load_from_path(incumbent_path)
	var trainer := SelfPlayTrainer.new()
	trainer.player_count = player_count
	trainer.private_battle_results = private_battle_results
	trainer.scout_move_limit = scout_move_limit
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	print("Independent Stratego champion evaluation")
	print("Current:  generation %d, %d training games" % [challenger.generation, challenger.games_trained])
	print("Previous: generation %d, %d training games" % [incumbent.generation, incumbent.games_trained])
	print("Playing %d games with each layout repeated across all %d seats and %s Scout range..." % [matches, player_count, _scout_range_description()])
	var result := trainer.evaluate_policies(challenger, incumbent, matches, rng)
	# A challenger occupies one seat. Treat a draw as the neutral share of a
	# win and infer relative strength from p = r / (r + opponent_count).
	var neutral_share := 1.0 / float(player_count)
	var score := (float(result.challenger_wins) + neutral_share * float(result.draws)) / float(result.matches)
	var bounded_score := clampf(score, 0.001, 0.999)
	var relative_strength := float(player_count - 1) * bounded_score / (1.0 - bounded_score)
	var rating_difference := 400.0 * log(relative_strength) / log(10.0)
	print("")
	print("Current %d–%d previous, %d draws" % [result.challenger_wins, result.incumbent_wins, result.draws])
	print("Current seat win rate: %.1f%% (%.1f%% is even)" % [score * 100.0, neutral_share * 100.0])
	print("Average material edge: %+.2f" % result.average_material)
	print("Estimated rating difference: %+.0f" % rating_difference)
	if int(result.score_margin) > 0:
		print("RESULT: the current champion wins this evaluation.")
	elif int(result.score_margin) < 0:
		print("RESULT: the previous champion wins this evaluation.")
	else:
		print("RESULT: the champions are tied in decisive games.")
	quit(0)


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--matches="):
			matches = maxi(2, int(argument.trim_prefix("--matches=")))
		elif argument.begins_with("--challenger="):
			challenger_path = argument.trim_prefix("--challenger=")
		elif argument.begins_with("--incumbent="):
			incumbent_path = argument.trim_prefix("--incumbent=")
		elif argument.begins_with("--seed="):
			seed_value = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--players="):
			player_count = clampi(int(argument.trim_prefix("--players=")), 2, 4)
		elif argument.begins_with("--private-battles="):
			private_battle_results = argument.trim_prefix("--private-battles=").to_lower() not in ["false", "0", "off"]
		elif argument.begins_with("--scout-range="):
			var value := argument.trim_prefix("--scout-range=").to_lower()
			scout_move_limit = 0 if value in ["unlimited", "0", "off"] else clampi(int(value), 1, StrategoGame.BOARD_SIZE - 1)


func _scout_range_description() -> String:
	return "unlimited" if scout_move_limit == 0 else "%d-square" % scout_move_limit
