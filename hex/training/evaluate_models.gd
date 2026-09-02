extends SceneTree

var matches := 32
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
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var result := trainer.evaluate_policies(StrategoBotPolicy.new(), StrategoBotPolicy.new(), matches, rng)
	print("WEGO heuristic seat-balance diagnostic")
	print("Candidate seats %d wins; other seats %d wins; %d draws." % [result.challenger_wins, result.incumbent_wins, result.draws])
	print("This prototype does not persist or compare trained champion files yet.")
	quit(0)


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--matches="):
			matches = maxi(2, int(argument.trim_prefix("--matches=")))
		elif argument.begins_with("--seed="):
			seed_value = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--players="):
			player_count = clampi(int(argument.trim_prefix("--players=")), 2, 4)
		elif argument.begins_with("--private-battles="):
			private_battle_results = argument.trim_prefix("--private-battles=").to_lower() not in ["false", "0", "off"]
