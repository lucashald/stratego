extends SceneTree

var failures := 0
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_standard_setup()
	_test_selectable_player_counts()
	_test_four_player_turns_and_elimination()
	_test_scout_movement()
	_test_configurable_scout_movement()
	_test_fog_of_war()
	_test_combat_rules()
	_test_private_battle_results()
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
	_expect(game.board.size() == 20 and game.board[0].size() == 20, "Four-player board is 20 by 20")
	_expect(game.active_players.size() == 4, "All four players begin active")
	for lake in StrategoGame.LAKES:
		_expect(game.piece_at(lake).is_empty(), "Lake %s is empty" % lake)
	for player in StrategoGame.PLAYER_ORDER:
		_expect(game.count_alive(player) == 40, "%s starts with 40 pieces" % game.player_name(player))
		for piece: Dictionary in game.pieces:
			if piece.player == player:
				_expect(game.is_in_deployment(player, piece.position), "%s piece starts in its edge deployment" % game.player_name(player))
		var counts := {}
		for piece: Dictionary in game.pieces:
			if piece.player == player:
				counts[piece.type] = int(counts.get(piece.type, 0)) + 1
		for type: String in StrategoGame.PIECE_COUNTS:
			_expect(int(counts.get(type, 0)) == int(StrategoGame.PIECE_COUNTS[type]), "%s has correct %s count" % [game.player_name(player), type])
	var red_flag: Vector2i = game.find_alive_piece(StrategoGame.RED, StrategoGame.FLAG).position
	var green_flag: Vector2i = game.find_alive_piece(StrategoGame.GREEN, StrategoGame.FLAG).position
	var blue_flag: Vector2i = game.find_alive_piece(StrategoGame.BLUE, StrategoGame.FLAG).position
	var yellow_flag: Vector2i = game.find_alive_piece(StrategoGame.YELLOW, StrategoGame.FLAG).position
	_expect(red_flag.y != 3, "Red Flag is not placed on its front row")
	_expect(green_flag.x != 16, "Green Flag is not placed on its front column")
	_expect(blue_flag.y != 16, "Blue Flag is not placed on its front row")
	_expect(yellow_flag.x != 3, "Yellow Flag is not placed on its front column")


func _test_four_player_turns_and_elimination() -> void:
	var turns := StrategoGame.new()
	turns.setup_empty()
	turns.add_piece(StrategoGame.SCOUT, StrategoGame.RED, Vector2i(5, 0))
	turns.add_piece(StrategoGame.SCOUT, StrategoGame.GREEN, Vector2i(19, 5))
	turns.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(5, 19))
	turns.add_piece(StrategoGame.SCOUT, StrategoGame.YELLOW, Vector2i(0, 5))
	turns.current_player = StrategoGame.RED
	turns.apply_move(Vector2i(5, 0), Vector2i(5, 1))
	_expect(turns.current_player == StrategoGame.GREEN, "Turn advances from Red to Green")
	turns.apply_move(Vector2i(19, 5), Vector2i(18, 5))
	_expect(turns.current_player == StrategoGame.BLUE, "Turn advances from Green to Blue")
	turns.apply_move(Vector2i(5, 19), Vector2i(5, 18))
	_expect(turns.current_player == StrategoGame.YELLOW, "Turn advances from Blue to Yellow")
	turns.apply_move(Vector2i(0, 5), Vector2i(1, 5))
	_expect(turns.current_player == StrategoGame.RED, "Turn advances from Yellow to Red")

	var elimination := StrategoGame.new()
	elimination.setup_empty()
	elimination.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(0, 0))
	elimination.add_piece(StrategoGame.FLAG, StrategoGame.RED, Vector2i(0, 1))
	elimination.add_piece(StrategoGame.SCOUT, StrategoGame.GREEN, Vector2i(19, 19))
	elimination.add_piece(StrategoGame.SCOUT, StrategoGame.YELLOW, Vector2i(18, 19))
	var event := elimination.apply_move(Vector2i(0, 0), Vector2i(0, 1))
	_expect(StrategoGame.RED in elimination.eliminated_players, "Capturing Red's Flag eliminates Red")
	_expect(elimination.count_alive(StrategoGame.RED) == 0, "Elimination removes the rest of an army")
	_expect(not elimination.game_over, "A Flag capture does not end a four-player game while rivals remain")
	_expect(event.eliminations.size() == 1 and event.eliminations[0].player == StrategoGame.RED, "Flag elimination is recorded in the move event")


func _test_selectable_player_counts() -> void:
	for player_count in range(2, 5):
		var game := StrategoGame.new()
		game.setup_random(4000 + player_count, player_count)
		var expected_roster := StrategoGame.players_for_count(player_count)
		_expect(game.active_players == expected_roster, "%d-player setup activates the correct colors" % player_count)
		_expect(game.configured_player_count == player_count, "%d-player setup records its match size" % player_count)
		for player in StrategoGame.PLAYER_ORDER:
			var expected_pieces := 40 if player in expected_roster else 0
			_expect(game.count_alive(player) == expected_pieces, "%d-player setup gives %s the correct piece count" % [player_count, game.player_name(player)])

	var duel := StrategoGame.new()
	duel.setup_empty()
	duel.add_piece(StrategoGame.SCOUT, StrategoGame.RED, Vector2i(5, 0))
	duel.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(5, 19))
	duel.current_player = StrategoGame.RED
	duel.apply_move(Vector2i(5, 0), Vector2i(5, 1))
	_expect(duel.current_player == StrategoGame.BLUE, "Two-player turns skip inactive Green")
	duel.apply_move(Vector2i(5, 19), Vector2i(5, 18))
	_expect(duel.current_player == StrategoGame.RED, "Two-player turns return from Blue to Red")

	var trio := StrategoGame.new()
	trio.setup_empty()
	trio.add_piece(StrategoGame.SCOUT, StrategoGame.RED, Vector2i(5, 0))
	trio.add_piece(StrategoGame.SCOUT, StrategoGame.GREEN, Vector2i(19, 5))
	trio.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(5, 19))
	trio.current_player = StrategoGame.RED
	trio.apply_move(Vector2i(5, 0), Vector2i(5, 1))
	_expect(trio.current_player == StrategoGame.GREEN, "Three-player turns include Green")
	trio.apply_move(Vector2i(19, 5), Vector2i(18, 5))
	_expect(trio.current_player == StrategoGame.BLUE, "Three-player turns proceed from Green to Blue")
	trio.apply_move(Vector2i(5, 19), Vector2i(5, 18))
	_expect(trio.current_player == StrategoGame.RED, "Three-player turns skip inactive Yellow")


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


func _test_configurable_scout_movement() -> void:
	var default_game := StrategoGame.new()
	default_game.setup_empty()
	default_game.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(0, 0))
	var default_destinations: Array[Vector2i] = []
	for move: Dictionary in default_game.get_moves_for(Vector2i(0, 0)):
		default_destinations.append(move.to)
	_expect(default_game.scout_move_limit == 0, "Scout movement is unlimited by default")
	_expect(Vector2i(10, 0) in default_destinations, "Default Scout can cross more than four clear squares")

	var limited_game := StrategoGame.new()
	limited_game.setup_empty()
	limited_game.scout_move_limit = 4
	limited_game.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(0, 0))
	limited_game.add_piece("4", StrategoGame.RED, Vector2i(0, 4))
	var limited_destinations: Array[Vector2i] = []
	for move: Dictionary in limited_game.get_moves_for(Vector2i(0, 0)):
		limited_destinations.append(move.to)
	_expect(Vector2i(4, 0) in limited_destinations, "Four-square Scout can move exactly four clear squares")
	_expect(Vector2i(5, 0) not in limited_destinations, "Four-square Scout cannot move five squares")
	_expect(Vector2i(0, 4) in limited_destinations, "Four-square Scout can attack at its maximum range")
	_expect(Vector2i(0, 5) not in limited_destinations, "Scout cannot move beyond a maximum-range target")

	var configured_game := StrategoGame.new()
	configured_game.setup_random(6789, 2, true, 4)
	_expect(configured_game.scout_move_limit == 4, "Random setup records the selected Scout range")


func _test_fog_of_war() -> void:
	var game := StrategoGame.new()
	game.setup_empty()
	var blue_id := game.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(0, 0))
	var hidden_red_id := game.add_piece("6", StrategoGame.RED, Vector2i(0, 5))
	var visible_green_id := game.add_piece("5", StrategoGame.GREEN, Vector2i(3, 1))
	_expect(game.vision_range == 4, "Fog of war uses a four-square vision range")
	_expect(game.is_piece_visible_to(game.pieces[blue_id], StrategoGame.BLUE), "A player always sees their own piece")
	_expect(game.is_piece_visible_to(game.pieces[visible_green_id], StrategoGame.BLUE), "Enemy at four orthogonal steps is visible")
	_expect(not game.is_piece_visible_to(game.pieces[hidden_red_id], StrategoGame.BLUE), "Enemy at five orthogonal steps is hidden")
	_expect(game.observed_piece_at(Vector2i(0, 5), StrategoGame.BLUE).is_empty(), "Player observation omits a fogged enemy")
	game.reveal_piece_to(hidden_red_id, StrategoGame.BLUE)
	_expect(game.is_piece_revealed_to(game.pieces[hidden_red_id], StrategoGame.BLUE), "Previously learned enemy rank remains known")
	_expect(not game.is_piece_visible_to(game.pieces[hidden_red_id], StrategoGame.BLUE), "Known rank does not track a piece through fog")
	var approach_event := game.apply_move(Vector2i(0, 0), Vector2i(0, 1))
	_expect(game.is_piece_visible_to(game.pieces[hidden_red_id], StrategoGame.BLUE), "Moving closer reveals an enemy entering four-square vision")
	_expect(StrategoGame.BLUE in approach_event.visible_to, "Moving player observes their own move")
	_expect(StrategoGame.RED in approach_event.visible_to, "Opponent observes a move entering its four-square vision")

	var distant_game := StrategoGame.new()
	distant_game.setup_empty()
	distant_game.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(0, 0))
	distant_game.add_piece(StrategoGame.SCOUT, StrategoGame.RED, Vector2i(10, 10))
	var distant_event := distant_game.apply_move(Vector2i(0, 0), Vector2i(0, 1))
	_expect(StrategoGame.RED not in distant_event.visible_to, "Distant opponent does not observe an off-camera move")

	var policy := _zero_policy()
	policy.weights.home_intruder_intercept = 1.0
	var bot_game := StrategoGame.new()
	bot_game.setup_empty()
	bot_game.add_piece(StrategoGame.FLAG, StrategoGame.BLUE, Vector2i(5, 19))
	bot_game.add_piece("4", StrategoGame.BLUE, Vector2i(0, 14))
	var intruder_id := bot_game.add_piece("5", StrategoGame.RED, Vector2i(5, 14))
	var blind_approach := policy.score_move(bot_game, {"from": Vector2i(0, 14), "to": Vector2i(1, 14)}, StrategoGame.BLUE)
	var blind_withdrawal := policy.score_move(bot_game, {"from": Vector2i(0, 14), "to": Vector2i(0, 13)}, StrategoGame.BLUE)
	_expect(not bot_game.is_piece_visible_to(bot_game.pieces[intruder_id], StrategoGame.BLUE), "Bot cannot see an enemy five squares from its army")
	_expect(is_equal_approx(blind_approach, blind_withdrawal), "Bot does not intercept an enemy hidden by fog")
	bot_game.add_piece(StrategoGame.BOMB, StrategoGame.BLUE, Vector2i(5, 18))
	var informed_approach := policy.score_move(bot_game, {"from": Vector2i(0, 14), "to": Vector2i(1, 14)}, StrategoGame.BLUE)
	var informed_withdrawal := policy.score_move(bot_game, {"from": Vector2i(0, 14), "to": Vector2i(0, 13)}, StrategoGame.BLUE)
	_expect(bot_game.is_piece_visible_to(bot_game.pieces[intruder_id], StrategoGame.BLUE), "A nearby friendly spotter reveals the intruder")
	_expect(informed_approach > informed_withdrawal, "Bot reacts to the intruder once it is visible")


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


func _test_private_battle_results() -> void:
	var private_game := StrategoGame.new()
	private_game.setup_empty()
	private_game.private_battle_results = true
	var blue_id := private_game.add_piece("6", StrategoGame.BLUE, Vector2i(0, 0))
	var red_id := private_game.add_piece("4", StrategoGame.RED, Vector2i(0, 1))
	private_game.add_piece(StrategoGame.SCOUT, StrategoGame.GREEN, Vector2i(19, 19))
	var private_event := private_game.apply_move(Vector2i(0, 0), Vector2i(0, 1))
	_expect(private_game.is_piece_revealed_to(private_game.pieces[red_id], StrategoGame.BLUE), "Private battle reveals the defender to the attacker")
	_expect(private_game.is_piece_revealed_to(private_game.pieces[blue_id], StrategoGame.RED), "Private battle reveals the attacker to the defender")
	_expect(not private_game.is_piece_revealed_to(private_game.pieces[blue_id], StrategoGame.GREEN), "Uninvolved Green does not learn the surviving attacker's rank")
	_expect(not private_game.is_piece_revealed_to(private_game.pieces[red_id], StrategoGame.GREEN), "Uninvolved Green does not learn the destroyed defender's rank")
	_expect(private_event.known_to.has(StrategoGame.BLUE) and private_event.known_to.has(StrategoGame.RED), "Private event records both combat participants")
	_expect(not private_event.known_to.has(StrategoGame.GREEN), "Private event excludes an uninvolved observer")
	_expect(private_game.battle_events_for(StrategoGame.BLUE).size() == 1, "Attacker receives the private battle-history entry")
	_expect(private_game.battle_events_for(StrategoGame.GREEN).is_empty(), "Observer does not receive the private battle-history entry")

	var public_game := StrategoGame.new()
	public_game.setup_empty()
	public_game.private_battle_results = false
	var public_blue_id := public_game.add_piece("6", StrategoGame.BLUE, Vector2i(0, 0))
	var public_red_id := public_game.add_piece("4", StrategoGame.RED, Vector2i(0, 1))
	public_game.add_piece(StrategoGame.SCOUT, StrategoGame.GREEN, Vector2i(19, 19))
	var public_event := public_game.apply_move(Vector2i(0, 0), Vector2i(0, 1))
	_expect(public_game.is_piece_revealed_to(public_game.pieces[public_blue_id], StrategoGame.GREEN), "Public battle reveals the attacker to Green")
	_expect(public_game.is_piece_revealed_to(public_game.pieces[public_red_id], StrategoGame.GREEN), "Public battle reveals the defender to Green")
	_expect(public_event.known_to.has(StrategoGame.GREEN), "Public event includes every active observer")
	_expect(public_game.battle_events_for(StrategoGame.GREEN).size() == 1, "Observer receives the public battle-history entry")

	var knowledge_game := StrategoGame.new()
	knowledge_game.setup_empty()
	knowledge_game.add_piece(StrategoGame.MARSHAL, StrategoGame.BLUE, Vector2i(5, 5))
	var known_general_id := knowledge_game.add_piece("9", StrategoGame.RED, Vector2i(5, 4))
	knowledge_game.add_piece(StrategoGame.SCOUT, StrategoGame.GREEN, Vector2i(19, 19))
	knowledge_game.reveal_piece_to(known_general_id, StrategoGame.GREEN)
	var knowledge_policy := _zero_policy()
	knowledge_policy.weights.known_win = 5.0
	var blue_unknown_score := knowledge_policy.score_move(knowledge_game, {"from": Vector2i(5, 5), "to": Vector2i(5, 4)}, StrategoGame.BLUE)
	knowledge_game.reveal_piece_to(known_general_id, StrategoGame.BLUE)
	var blue_known_score := knowledge_policy.score_move(knowledge_game, {"from": Vector2i(5, 5), "to": Vector2i(5, 4)}, StrategoGame.BLUE)
	_expect(blue_known_score > blue_unknown_score, "Bot scoring uses its own private rank knowledge rather than another player's")


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
	valuable_game.reveal_piece_to(general_id, StrategoGame.BLUE)
	var valuable_score := policy.score_move(valuable_game, {"from": Vector2i(0, 0), "to": Vector2i(0, 1)}, StrategoGame.BLUE)

	var cheap_game := StrategoGame.new()
	cheap_game.setup_empty()
	cheap_game.add_piece(StrategoGame.MARSHAL, StrategoGame.BLUE, Vector2i(0, 0))
	var scout_id := cheap_game.add_piece(StrategoGame.SCOUT, StrategoGame.RED, Vector2i(0, 1))
	cheap_game.reveal_piece_to(scout_id, StrategoGame.BLUE)
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
	escape_game.reveal_piece_to(captain_id, StrategoGame.BLUE)
	var retreat_score := policy.score_move(escape_game, {"from": Vector2i(4, 6), "to": Vector2i(4, 7)}, StrategoGame.BLUE)
	var approach_score := policy.score_move(escape_game, {"from": Vector2i(4, 6), "to": Vector2i(4, 5)}, StrategoGame.BLUE)
	_expect(retreat_score > approach_score, "Stronger-enemy feature can reward moving away from a revealed superior piece")

	policy = _zero_policy()
	policy.weights.concealment_hold = 1.0
	var concealment_game := StrategoGame.new()
	concealment_game.setup_empty()
	var blue_general_id := concealment_game.add_piece("9", StrategoGame.BLUE, Vector2i(4, 6))
	var marshal_id := concealment_game.add_piece(StrategoGame.MARSHAL, StrategoGame.RED, Vector2i(4, 4))
	concealment_game.reveal_piece_to(marshal_id, StrategoGame.BLUE)
	var concealed_move_score := policy.score_move(concealment_game, {"from": Vector2i(4, 6), "to": Vector2i(4, 7)}, StrategoGame.BLUE)
	concealment_game.pieces[blue_general_id].has_moved = true
	var exposed_move_score := policy.score_move(concealment_game, {"from": Vector2i(4, 6), "to": Vector2i(4, 7)}, StrategoGame.BLUE)
	_expect(concealed_move_score < exposed_move_score, "Concealment feature discourages revealing an unmoved General near a revealed Marshal")

	var default_policy := StrategoBotPolicy.new()
	_expect(float(default_policy.weights.known_loss) <= -100.0, "Known losing combat has a decisive tactical penalty")
	_expect(float(default_policy.weights.known_threat_after_move) < 0.0, "Known next-turn threats are penalized by default")
	_expect(float(default_policy.weights.stronger_enemy_escape) > 0.0, "Escaping a revealed stronger enemy is active by default")
	_expect(float(default_policy.weights.concealment_hold) > 0.0, "A concealed valuable piece can stay still near a revealed superior by default")
	var locked_mutation := default_policy.mutated_sparse(RandomNumberGenerator.new(), 20.0, default_policy.weights.size())
	_expect(float(locked_mutation.weights.known_loss) == float(default_policy.weights.known_loss), "Training cannot mutate away the known-loss safeguard")

	policy = _zero_policy()
	policy.weights.known_threat_after_move = -1.0
	var immediate_threat_game := StrategoGame.new()
	immediate_threat_game.setup_empty()
	immediate_threat_game.add_piece("4", StrategoGame.BLUE, Vector2i(5, 5))
	var immediate_captain_id := immediate_threat_game.add_piece("6", StrategoGame.RED, Vector2i(7, 5))
	immediate_threat_game.reveal_piece_to(immediate_captain_id, StrategoGame.BLUE)
	var threatened_destination_score := policy.score_move(immediate_threat_game, {"from": Vector2i(5, 5), "to": Vector2i(6, 5)}, StrategoGame.BLUE)
	var safe_destination_score := policy.score_move(immediate_threat_game, {"from": Vector2i(5, 5), "to": Vector2i(5, 6)}, StrategoGame.BLUE)
	_expect(safe_destination_score > threatened_destination_score, "Immediate-threat feature avoids moving into a revealed stronger piece's reach")

	policy = _zero_policy()
	policy.weights.flag_cover_change = 1.0
	var flag_cover_game := StrategoGame.new()
	flag_cover_game.setup_empty()
	flag_cover_game.add_piece(StrategoGame.FLAG, StrategoGame.BLUE, Vector2i(5, 19))
	flag_cover_game.add_piece("4", StrategoGame.BLUE, Vector2i(4, 18))
	var add_cover_score := policy.score_move(flag_cover_game, {"from": Vector2i(4, 18), "to": Vector2i(4, 19)}, StrategoGame.BLUE)
	var ignore_cover_score := policy.score_move(flag_cover_game, {"from": Vector2i(4, 18), "to": Vector2i(4, 17)}, StrategoGame.BLUE)
	_expect(add_cover_score > ignore_cover_score, "Flag-cover feature rewards directly guarding an open Flag edge")

	policy = _zero_policy()
	policy.weights.home_intruder_intercept = 1.0
	var intercept_game := StrategoGame.new()
	intercept_game.setup_empty()
	intercept_game.add_piece(StrategoGame.FLAG, StrategoGame.BLUE, Vector2i(5, 19))
	intercept_game.add_piece("4", StrategoGame.BLUE, Vector2i(5, 16))
	intercept_game.add_piece("5", StrategoGame.RED, Vector2i(5, 18))
	var intercept_score := policy.score_move(intercept_game, {"from": Vector2i(5, 16), "to": Vector2i(5, 17)}, StrategoGame.BLUE)
	var ignore_intruder_score := policy.score_move(intercept_game, {"from": Vector2i(5, 16), "to": Vector2i(4, 16)}, StrategoGame.BLUE)
	_expect(intercept_score > ignore_intruder_score, "Home-intercept feature rewards closing on an enemy near the Flag")

	policy = _zero_policy()
	policy.weights.unknown_contact_risk = -1.0
	var contact_game := StrategoGame.new()
	contact_game.setup_empty()
	contact_game.add_piece(StrategoGame.MARSHAL, StrategoGame.BLUE, Vector2i(5, 5))
	contact_game.add_piece("4", StrategoGame.RED, Vector2i(7, 5))
	var risky_contact_score := policy.score_move(contact_game, {"from": Vector2i(5, 5), "to": Vector2i(6, 5)}, StrategoGame.BLUE)
	var safe_contact_score := policy.score_move(contact_game, {"from": Vector2i(5, 5), "to": Vector2i(5, 6)}, StrategoGame.BLUE)
	_expect(safe_contact_score > risky_contact_score, "Unknown-contact feature protects valuable pieces from clustered uncertainty")

	var target_choice_game := StrategoGame.new()
	target_choice_game.setup_empty()
	target_choice_game.add_piece(StrategoGame.SCOUT, StrategoGame.BLUE, Vector2i(5, 5))
	target_choice_game.add_piece("4", StrategoGame.RED, Vector2i(5, 4))
	target_choice_game.add_piece("4", StrategoGame.GREEN, Vector2i(6, 5))
	for filler_x in range(10):
		target_choice_game.add_piece(StrategoGame.BOMB, StrategoGame.RED, Vector2i(filler_x, 0))
	policy = _zero_policy()
	policy.weights.leader_pressure = 1.0
	var attack_leader_score := policy.score_move(target_choice_game, {"from": Vector2i(5, 5), "to": Vector2i(5, 4)}, StrategoGame.BLUE)
	var attack_weak_score := policy.score_move(target_choice_game, {"from": Vector2i(5, 5), "to": Vector2i(6, 5)}, StrategoGame.BLUE)
	_expect(attack_leader_score > attack_weak_score, "Leader-pressure feature directs attacks toward the largest surviving army")
	policy = _zero_policy()
	policy.weights.weak_player_finish = 1.0
	attack_leader_score = policy.score_move(target_choice_game, {"from": Vector2i(5, 5), "to": Vector2i(5, 4)}, StrategoGame.BLUE)
	attack_weak_score = policy.score_move(target_choice_game, {"from": Vector2i(5, 5), "to": Vector2i(6, 5)}, StrategoGame.BLUE)
	_expect(attack_weak_score > attack_leader_score, "Finish feature can prioritize a depleted rival")

	policy = _zero_policy()
	policy.weights.counter_target_approach = 1.0
	var counter_game := StrategoGame.new()
	counter_game.setup_empty()
	counter_game.add_piece(StrategoGame.MINER, StrategoGame.BLUE, Vector2i(5, 5))
	var exposed_bomb_id := counter_game.add_piece(StrategoGame.BOMB, StrategoGame.RED, Vector2i(5, 2))
	counter_game.reveal_piece_to(exposed_bomb_id, StrategoGame.BLUE)
	var pursue_counter_score := policy.score_move(counter_game, {"from": Vector2i(5, 5), "to": Vector2i(5, 4)}, StrategoGame.BLUE)
	var ignore_counter_score := policy.score_move(counter_game, {"from": Vector2i(5, 5), "to": Vector2i(6, 5)}, StrategoGame.BLUE)
	_expect(pursue_counter_score > ignore_counter_score, "Counter-pursuit feature sends Miners toward revealed Bombs")

	policy = _zero_policy()
	policy.weights.bomb_defusal = 1.0
	var defusal_game := StrategoGame.new()
	defusal_game.setup_empty()
	defusal_game.add_piece(StrategoGame.MINER, StrategoGame.BLUE, Vector2i(5, 3))
	var adjacent_bomb_id := defusal_game.add_piece(StrategoGame.BOMB, StrategoGame.RED, Vector2i(5, 2))
	defusal_game.reveal_piece_to(adjacent_bomb_id, StrategoGame.BLUE)
	var defusal_score := policy.score_move(defusal_game, {"from": Vector2i(5, 3), "to": Vector2i(5, 2)}, StrategoGame.BLUE)
	var defusal_wait_score := policy.score_move(defusal_game, {"from": Vector2i(5, 3), "to": Vector2i(6, 3)}, StrategoGame.BLUE)
	_expect(defusal_score > defusal_wait_score, "Bomb-defusal feature explicitly values the Miner counter")

	policy = _zero_policy()
	policy.weights.spy_strike = 1.0
	var spy_game := StrategoGame.new()
	spy_game.setup_empty()
	spy_game.add_piece(StrategoGame.SPY, StrategoGame.BLUE, Vector2i(5, 5))
	var exposed_marshal_id := spy_game.add_piece(StrategoGame.MARSHAL, StrategoGame.RED, Vector2i(5, 4))
	spy_game.reveal_piece_to(exposed_marshal_id, StrategoGame.BLUE)
	var spy_strike_score := policy.score_move(spy_game, {"from": Vector2i(5, 5), "to": Vector2i(5, 4)}, StrategoGame.BLUE)
	var spy_wait_score := policy.score_move(spy_game, {"from": Vector2i(5, 5), "to": Vector2i(6, 5)}, StrategoGame.BLUE)
	_expect(spy_strike_score > spy_wait_score, "Spy-strike feature explicitly values attacking a revealed Marshal")


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
