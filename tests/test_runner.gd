extends SceneTree

var failures := 0
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_standard_setup()
	_test_scout_movement()
	_test_combat_rules()
	_test_miner_captures_bomb()
	_test_public_move_history()
	_test_expanded_policy_features()
	_test_game_end_reasons()
	_test_training_iteration()
	if failures == 0:
		print("PASS: %d Stratego checks" % checks)
		quit(0)
	else:
		printerr("FAIL: %d of %d checks failed" % [failures, checks])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("  FAILED: %s" % message)


func _test_standard_setup() -> void:
	var game := StrategoGame.new()
	game.setup_random(12345)
	_expect(game.count_alive(StrategoGame.BLUE) == 40, "Blue starts with 40 pieces")
	_expect(game.count_alive(StrategoGame.RED) == 40, "Red starts with 40 pieces")
	_expect(game.find_alive_piece(StrategoGame.RED, StrategoGame.FLAG).position.y != 3, "Red Flag is not placed on its front row")
	_expect(game.find_alive_piece(StrategoGame.BLUE, StrategoGame.FLAG).position.y != 6, "Blue Flag is not placed on its front row")
	for lake in StrategoGame.LAKES:
		_expect(game.piece_at(lake).is_empty(), "Lake %s is empty" % lake)
	for player in [StrategoGame.BLUE, StrategoGame.RED]:
		var counts := {}
		for piece: Dictionary in game.pieces:
			if piece.player == player:
				counts[piece.type] = int(counts.get(piece.type, 0)) + 1
		for type: String in StrategoGame.PIECE_COUNTS:
			_expect(int(counts.get(type, 0)) == int(StrategoGame.PIECE_COUNTS[type]), "%s has correct %s count" % [game.player_name(player), type])


func _test_scout_movement() -> void:
	var game := StrategoGame.new()
	game.setup_empty()
	game.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(0, 0))
	game.add_piece(StrategoGame.BOMB, StrategoGame.BLUE, Vector2i(0, 2))
	game.add_piece("4", StrategoGame.RED, Vector2i(3, 0))
	var moves := game.get_moves_for(Vector2i(0, 0))
	var destinations: Array[Vector2i] = []
	for move: Dictionary in moves:
		destinations.append(move.to)
	_expect(Vector2i(2, 0) in destinations, "Scout can travel across empty squares")
	_expect(Vector2i(3, 0) in destinations, "Scout can attack the first enemy in its path")
	_expect(Vector2i(4, 0) not in destinations, "Scout cannot pass through an enemy")
	_expect(Vector2i(0, 2) not in destinations, "Scout cannot enter a friendly occupied square")
	_expect(Vector2i(0, 3) not in destinations, "Scout cannot pass through a friendly piece")


func _test_combat_rules() -> void:
	var game := StrategoGame.new()
	_expect(game.resolve_combat(StrategoGame.MINER, StrategoGame.BOMB) == "attacker", "Miner defuses bomb")
	_expect(game.resolve_combat("4", StrategoGame.BOMB) == "defender", "Bomb defeats a non-miner")
	_expect(game.resolve_combat(StrategoGame.SPY, StrategoGame.MARSHAL) == "attacker", "Attacking spy defeats marshal")
	_expect(game.resolve_combat(StrategoGame.MARSHAL, StrategoGame.SPY) == "attacker", "Attacking marshal defeats spy")
	_expect(game.resolve_combat("7", "7") == "both", "Equal ranks remove each other")
	_expect(game.resolve_combat("4", "6") == "defender", "Higher defending rank wins")
	_expect(game.resolve_combat("9", "5") == "attacker", "Higher attacking rank wins")
	_expect(game.resolve_combat("2", StrategoGame.FLAG) == "attacker", "Any movable piece captures the flag")


func _test_miner_captures_bomb() -> void:
	var game := StrategoGame.new()
	game.setup_empty()
	game.add_piece(StrategoGame.MINER, StrategoGame.BLUE, Vector2i(0, 0))
	game.add_piece(StrategoGame.BOMB, StrategoGame.RED, Vector2i(0, 1))
	game.add_piece(StrategoGame.SCOUT, StrategoGame.RED, Vector2i(9, 9))
	var result := game.apply_move(Vector2i(0, 0), Vector2i(0, 1))
	_expect(result.ok and result.result == "attacker", "Miner attack is applied")
	var survivor := game.piece_at(Vector2i(0, 1))
	_expect(not survivor.is_empty() and survivor.type == StrategoGame.MINER, "Miner occupies a defused bomb square")


func _test_public_move_history() -> void:
	var game := StrategoGame.new()
	game.setup_empty()
	var scout_id := game.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(0, 0))
	game.add_piece(StrategoGame.SCOUT, StrategoGame.RED, Vector2i(9, 9))
	game.apply_move(Vector2i(0, 0), Vector2i(0, 1))
	var scout: Dictionary = game.pieces[scout_id]
	_expect(bool(scout.has_moved), "Moving piece is publicly marked as moved")
	_expect(int(scout.move_count) == 1, "Piece move count is recorded")
	_expect(Vector2i(0, 0) in scout.recent_positions, "Piece history retains its starting square")
	_expect(Vector2i(0, 1) in scout.recent_positions, "Piece history records its destination")


func _test_expanded_policy_features() -> void:
	var policy := _zero_policy()
	policy.weights.trade_value = 1.0
	var valuable_game := StrategoGame.new()
	valuable_game.setup_empty()
	valuable_game.add_piece(StrategoGame.MARSHAL, StrategoGame.BLUE, Vector2i(0, 0))
	var general_id := valuable_game.add_piece("9", StrategoGame.RED, Vector2i(0, 1))
	valuable_game.pieces[general_id].revealed = true
	var valuable_score := policy.score_move(valuable_game, {"from": Vector2i(0, 0), "to": Vector2i(0, 1)}, StrategoGame.BLUE)

	var cheap_game := StrategoGame.new()
	cheap_game.setup_empty()
	cheap_game.add_piece(StrategoGame.MARSHAL, StrategoGame.BLUE, Vector2i(0, 0))
	var scout_id := cheap_game.add_piece(StrategoGame.SCOUT, StrategoGame.RED, Vector2i(0, 1))
	cheap_game.pieces[scout_id].revealed = true
	var cheap_score := policy.score_move(cheap_game, {"from": Vector2i(0, 0), "to": Vector2i(0, 1)}, StrategoGame.BLUE)
	_expect(valuable_score > cheap_score, "Trade feature values a General capture above a Scout capture")

	policy = _zero_policy()
	policy.weights.unknown_piece_risk = -1.0
	var marshal_game := StrategoGame.new()
	marshal_game.setup_empty()
	marshal_game.add_piece(StrategoGame.MARSHAL, StrategoGame.BLUE, Vector2i(0, 0))
	marshal_game.add_piece("4", StrategoGame.RED, Vector2i(0, 1))
	var marshal_probe := policy.score_move(marshal_game, {"from": Vector2i(0, 0), "to": Vector2i(0, 1)}, StrategoGame.BLUE)
	var scout_game := StrategoGame.new()
	scout_game.setup_empty()
	scout_game.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(0, 0))
	scout_game.add_piece("4", StrategoGame.RED, Vector2i(0, 1))
	var scout_probe := policy.score_move(scout_game, {"from": Vector2i(0, 0), "to": Vector2i(0, 1)}, StrategoGame.BLUE)
	_expect(scout_probe > marshal_probe, "Unknown-risk feature prefers probing with a low-value piece")

	policy = _zero_policy()
	policy.weights.target_has_moved = 1.0
	marshal_game.pieces[1].has_moved = true
	var moved_target_score := policy.score_move(marshal_game, {"from": Vector2i(0, 0), "to": Vector2i(0, 1)}, StrategoGame.BLUE)
	marshal_game.pieces[1].has_moved = false
	var stationary_target_score := policy.score_move(marshal_game, {"from": Vector2i(0, 0), "to": Vector2i(0, 1)}, StrategoGame.BLUE)
	_expect(moved_target_score > stationary_target_score, "Moved-target feature recognizes a non-Bomb target")

	policy = _zero_policy()
	policy.weights.stronger_enemy_escape = 1.0
	var escape_game := StrategoGame.new()
	escape_game.setup_empty()
	escape_game.add_piece("4", StrategoGame.BLUE, Vector2i(4, 6))
	var captain_id := escape_game.add_piece("6", StrategoGame.RED, Vector2i(4, 4))
	escape_game.pieces[captain_id].revealed = true
	var retreat_score := policy.score_move(escape_game, {"from": Vector2i(4, 6), "to": Vector2i(4, 7)}, StrategoGame.BLUE)
	var approach_score := policy.score_move(escape_game, {"from": Vector2i(4, 6), "to": Vector2i(4, 5)}, StrategoGame.BLUE)
	_expect(retreat_score > approach_score, "Stronger-enemy feature can reward moving away from a revealed superior piece")

	policy = _zero_policy()
	policy.weights.concealment_hold = 1.0
	var concealment_game := StrategoGame.new()
	concealment_game.setup_empty()
	var blue_general_id := concealment_game.add_piece("9", StrategoGame.BLUE, Vector2i(4, 6))
	var marshal_id := concealment_game.add_piece(StrategoGame.MARSHAL, StrategoGame.RED, Vector2i(4, 4))
	concealment_game.pieces[marshal_id].revealed = true
	var concealed_move_score := policy.score_move(concealment_game, {"from": Vector2i(4, 6), "to": Vector2i(4, 7)}, StrategoGame.BLUE)
	concealment_game.pieces[blue_general_id].has_moved = true
	var exposed_move_score := policy.score_move(concealment_game, {"from": Vector2i(4, 6), "to": Vector2i(4, 7)}, StrategoGame.BLUE)
	_expect(concealed_move_score < exposed_move_score, "Concealment feature discourages revealing an unmoved General near a revealed Marshal")


func _zero_policy() -> StrategoBotPolicy:
	var policy := StrategoBotPolicy.new()
	for key: String in policy.weights:
		policy.weights[key] = 0.0
	return policy


func _test_game_end_reasons() -> void:
	var immobilized := StrategoGame.new()
	immobilized.setup_empty()
	immobilized.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(0, 0))
	immobilized.add_piece(StrategoGame.FLAG, StrategoGame.RED, Vector2i(9, 9))
	immobilized.add_piece(StrategoGame.BOMB, StrategoGame.RED, Vector2i(8, 9))
	immobilized.apply_move(Vector2i(0, 0), Vector2i(0, 1))
	_expect(immobilized.game_over and immobilized.winner == StrategoGame.BLUE, "Player with no legal moves loses")
	_expect(immobilized.end_reason == "no_legal_moves", "Immobilization records its end reason")

	var quiet_draw := StrategoGame.new()
	quiet_draw.setup_empty()
	quiet_draw.max_quiet_plies = 1
	quiet_draw.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(0, 0))
	quiet_draw.add_piece(StrategoGame.SCOUT, StrategoGame.RED, Vector2i(9, 9))
	quiet_draw.apply_move(Vector2i(0, 0), Vector2i(0, 1))
	_expect(quiet_draw.game_over and quiet_draw.winner == StrategoGame.DRAW, "No-combat limit produces a draw")
	_expect(quiet_draw.end_reason == "no_combat_limit", "No-combat draw records its end reason")

	var move_draw := StrategoGame.new()
	move_draw.setup_empty()
	move_draw.max_plies = 1
	move_draw.max_quiet_plies = 10
	move_draw.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(0, 0))
	move_draw.add_piece(StrategoGame.SCOUT, StrategoGame.RED, Vector2i(9, 9))
	move_draw.apply_move(Vector2i(0, 0), Vector2i(0, 1))
	_expect(move_draw.end_reason == "move_limit", "Total-move draw records its end reason")

	var flag_game := StrategoGame.new()
	flag_game.setup_empty()
	flag_game.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(0, 0))
	flag_game.add_piece(StrategoGame.FLAG, StrategoGame.RED, Vector2i(0, 1))
	flag_game.apply_move(Vector2i(0, 0), Vector2i(0, 1))
	_expect(flag_game.game_over and flag_game.end_reason == "flag_captured", "Flag capture records its end reason")


func _test_training_iteration() -> void:
	var policy := StrategoBotPolicy.new()
	var trainer := SelfPlayTrainer.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9981
	var result := trainer.train_iteration(policy, rng, 0)
	_expect(trainer.total_matches == 1, "Trainer completes a self-play match")
	_expect(int(result.plies) > 0, "Self-play match makes legal moves")
	_expect(policy.games_trained == 1, "Policy records its training game")
