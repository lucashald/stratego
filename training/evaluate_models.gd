extends SceneTree

var matches := 200
var challenger_path := StrategoBotPolicy.DEFAULT_USER_PATH
var incumbent_path := "user://stratego_bot_previous_champion.json"
var seed_value := 0


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
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	print("Independent Stratego champion evaluation")
	print("Current:  generation %d, %d training games" % [challenger.generation, challenger.games_trained])
	print("Previous: generation %d, %d training games" % [incumbent.generation, incumbent.games_trained])
	print("Playing %d games with paired layouts and swapped colors..." % matches)
	var result := trainer.evaluate_policies(challenger, incumbent, matches, rng)
	var score := (float(result.challenger_wins) + 0.5 * float(result.draws)) / float(result.matches)
	var bounded_score := clampf(score, 0.001, 0.999)
	var rating_difference := 400.0 * log(bounded_score / (1.0 - bounded_score)) / log(10.0)
	print("")
	print("Current %d–%d previous, %d draws" % [result.challenger_wins, result.incumbent_wins, result.draws])
	print("Current score: %.1f%%" % (score * 100.0))
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

