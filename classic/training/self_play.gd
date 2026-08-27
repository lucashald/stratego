extends SceneTree

var games := 250
var output_path := StrategoBotPolicy.DEFAULT_USER_PATH
var seed_value := 0
var title_matches := 40
var player_count := 4
var private_battle_results := true
var scout_move_limit := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_parse_arguments()
	var incumbent := StrategoBotPolicy.load_from_path(output_path)
	var archive_enabled := output_path == StrategoBotPolicy.DEFAULT_USER_PATH
	if archive_enabled:
		incumbent.save_archive()
	var contender_path := output_path.get_basename() + "_challenger.json"
	var policy := incumbent.duplicate_policy()
	if FileAccess.file_exists(contender_path):
		var saved_contender := StrategoBotPolicy.load_from_path(contender_path)
		if saved_contender.games_trained >= incumbent.games_trained:
			policy = saved_contender
	var trainer := SelfPlayTrainer.new()
	trainer.player_count = player_count
	trainer.private_battle_results = private_battle_results
	trainer.scout_move_limit = scout_move_limit
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	print("Stratego self-play training: %d matches with %d players, %s battle results, and %s Scout range" % [games, player_count, "private" if private_battle_results else "public", _scout_range_description()])
	print("Reigning champion: generation %d after %d games" % [incumbent.generation, incumbent.games_trained])
	print("Training contender: generation %d after %d games" % [policy.generation, policy.games_trained])

	for i in games:
		var iteration_result := trainer.train_iteration(policy, rng, i)
		if archive_enabled and bool(iteration_result.accepted):
			policy.save_archive()
		if (i + 1) % maxi(1, games / 10) == 0 or i + 1 == games:
			print("  %d/%d  generation=%d  %s" % [i + 1, games, policy.generation, trainer.summary()])

	print("")
	print("Title match: %d seat-balanced evaluation games" % title_matches)
	var title_result := trainer.evaluate_policies(policy, incumbent, title_matches, rng)
	print("  Contender %d seat wins, incumbent seats %d wins, %d draws, material %+.2f" % [
		title_result.challenger_wins,
		title_result.incumbent_wins,
		title_result.draws,
		title_result.average_material,
	])
	var promoted: bool = int(title_result.score_margin) > 0 or (int(title_result.score_margin) == 0 and float(title_result.average_material) > 2.0)
	if promoted:
		var backup_path := output_path.get_basename() + "_previous_champion.json"
		incumbent.save_to_path(backup_path)
		if not policy.save_to_path(output_path):
			printerr("Could not save the new champion to: %s" % output_path)
			quit(1)
			return
		policy.save_to_path(contender_path)
		if archive_enabled:
			policy.save_archive()
		print("NEW CHAMPION: generation %d was promoted." % policy.generation)
		print("Previous champion backup: %s" % backup_path)
	else:
		if not policy.save_to_path(contender_path):
			printerr("Could not save the continuing contender to: %s" % contender_path)
			quit(1)
			return
		print("CHAMPION DEFENDS: the playable model was not replaced.")
		print("The contender was saved and will continue training next run.")
	if not promoted and not FileAccess.file_exists(output_path):
		if not incumbent.save_to_path(output_path):
			printerr("Could not save the initial champion to: %s" % output_path)
			quit(1)
			return
	quit(0)


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--games="):
			games = maxi(1, int(argument.trim_prefix("--games=")))
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--seed="):
			seed_value = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--title-matches="):
			title_matches = maxi(2, int(argument.trim_prefix("--title-matches=")))
		elif argument.begins_with("--players="):
			player_count = clampi(int(argument.trim_prefix("--players=")), 2, 4)
		elif argument.begins_with("--private-battles="):
			private_battle_results = argument.trim_prefix("--private-battles=").to_lower() not in ["false", "0", "off"]
		elif argument.begins_with("--scout-range="):
			var value := argument.trim_prefix("--scout-range=").to_lower()
			scout_move_limit = 0 if value in ["unlimited", "0", "off"] else clampi(int(value), 1, StrategoGame.BOARD_SIZE - 1)


func _scout_range_description() -> String:
	return "unlimited" if scout_move_limit == 0 else "%d-square" % scout_move_limit
