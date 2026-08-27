extends SceneTree

var failures := 0
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_bridge_setup()
	_test_four_player_fog_framework()
	_test_private_battle_results()
	_test_order_paths_and_friendly_rejection()
	_test_group_orders_are_atomic()
	_test_planning_order_undo()
	_test_impulse_movement()
	_test_weighted_impulse_timing_and_actual_spend()
	_test_allied_collision_bounces_without_combat()
	_test_crossing_battle_both_attack()
	_test_tie_is_a_bounce()
	_test_winner_doubles_armor()
	_test_natural_ten_always_chips()
	_test_multiway_unique_winner()
	_test_multiway_friendly_leader_tie()
	_test_multiway_damage_uses_highest_opponent()
	_test_ranged_focus_fire_is_simultaneous()
	_test_archer_loss_blocks_shot_and_win_allows_it()
	_test_leftover_is_a_separate_order_phase()
	_test_leftover_allows_second_melee_only_after_win()
	_test_blocked_retreat_destroys_loser()
	_test_enemy_retreat_collision_battle()
	_test_impulse_sighting_is_remembered()
	_test_combat_reveal_requires_current_sight()
	_test_bridge_end_of_round_victory()
	_test_withdrawal_preserves_survivors_and_no_collapse()
	_test_meeting_engagement_hold_objective()
	_test_deterministic_replay_export()
	_test_bot_round_smoke()
	print("\n%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		failures += 1
		push_error("FAIL: %s" % message)


func _test_game() -> StrategoGame:
	var game := StrategoGame.new()
	game.setup_empty()
	game.scenario = "test"
	return game


func _ready_and_resolve(game: StrategoGame, rolls: Array[int] = []) -> Array[Dictionary]:
	if not rolls.is_empty():
		game.set_forced_rolls(rolls)
	for player in game.active_players.duplicate():
		game.mark_player_ready(player)
	return game.resolve_round()


func _events_with_action(events: Array[Dictionary], action: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in events:
		if String(event.get("action", "")) == action:
			found.append(event)
	return found


func _test_bridge_setup() -> void:
	var game := StrategoGame.new()
	game.setup_bridge(12345)
	_expect(game.scenario == StrategoGame.SCENARIO_BRIDGE, "bridge setup selects the bridge scenario")
	_expect(game.total_strength(game.bridge_attacker) == 82 and game.total_strength(game.bridge_defender) == 82, "bridge armies begin at equal 82 current Strength")
	var attacker_legal := true
	var defender_legal := true
	for piece: Dictionary in game.pieces:
		if int(piece.player) == game.bridge_attacker:
			attacker_legal = attacker_legal and piece.position.y == StrategoGame.BOARD_SIZE - 1
		elif int(piece.player) == game.bridge_defender:
			defender_legal = defender_legal and piece.position.y < StrategoGame.BRIDGE_RIVER_Y and not game.is_bridge(piece.position)
	_expect(attacker_legal, "bridge attacker deploys on its board edge")
	_expect(defender_legal, "bridge defender deploys anywhere on its own side and never on the bridge")
	_expect(game.is_water(Vector2i(0, StrategoGame.BRIDGE_RIVER_Y)) and game.is_bridge(Vector2i(9, StrategoGame.BRIDGE_RIVER_Y)), "river blocks non-bridge squares while bridge cells remain normal terrain")


func _test_four_player_fog_framework() -> void:
	var game := StrategoGame.new()
	game.setup_random(99, 4)
	_expect(game.active_players == [StrategoGame.RED, StrategoGame.GREEN, StrategoGame.BLUE, StrategoGame.YELLOW], "four-player color order is preserved")
	for player in game.active_players:
		_expect(game.count_alive(player) == 13 and game.total_strength(player) == 80, "%s retains the prototype army under WEGO" % game.player_name(player))
	var red_piece := game.find_alive_piece(StrategoGame.RED, StrategoGame.LIGHT_INFANTRY)
	_expect(not game.is_piece_visible_to(red_piece, StrategoGame.BLUE), "four-square fog still hides distant enemy formations")
	_expect(game.private_battle_results, "private battle information remains enabled")


func _test_private_battle_results() -> void:
	var private_game := _test_game()
	private_game.private_battle_results = true
	var attacker_id := private_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 10)
	private_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	private_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.GREEN, Vector2i(15, 15), 10)
	private_game.set_unit_order(StrategoGame.RED, attacker_id, [Vector2i(2, 1)])
	var private_battle := _events_with_action(_ready_and_resolve(private_game, [2, 2]), "melee")[0]
	_expect(private_battle.known_to == [StrategoGame.RED, StrategoGame.BLUE], "private combat details go only to participating players")
	var public_game := _test_game()
	public_game.private_battle_results = false
	var public_attacker := public_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 10)
	public_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	public_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.GREEN, Vector2i(15, 15), 10)
	public_game.set_unit_order(StrategoGame.RED, public_attacker, [Vector2i(2, 1)])
	var public_battle := _events_with_action(_ready_and_resolve(public_game, [2, 2]), "melee")[0]
	_expect(StrategoGame.GREEN in public_battle.known_to, "public combat details remain available to uninvolved players")


func _test_order_paths_and_friendly_rejection() -> void:
	var game := _test_game()
	var light_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(1, 1))
	var friend_id := game.add_piece(StrategoGame.MEDIUM_INFANTRY, StrategoGame.RED, Vector2i(3, 1))
	game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(15, 15))
	var light_order := game.set_unit_order(StrategoGame.RED, light_id, [Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)])
	_expect(bool(light_order.ok), "Light formations accept three-square turning paths")
	var too_far := game.set_unit_order(StrategoGame.RED, friend_id, [Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)])
	_expect(not bool(too_far.ok), "Medium formations reject three movement impulses")
	game.clear_player_orders(StrategoGame.RED)
	game.set_unit_order(StrategoGame.RED, light_id, [Vector2i(2, 1)])
	var collision := game.set_unit_order(StrategoGame.RED, friend_id, [Vector2i(2, 1)])
	_expect(not bool(collision.ok), "same-player orders that meet on one impulse are rejected at order time")
	_expect(game.projected_order_position(light_id, 1) == Vector2i(2, 1), "planned paths expose their impulse occupancy for ghost UI")
	var archer_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(6, 6))
	var long_shot := game.set_unit_order(StrategoGame.RED, archer_id, [], Vector2i(8, 6))
	_expect(bool(long_shot.ok), "stationary Archers accept ranged targets up to two squares away")
	var overwatch_shot := game.set_unit_order(StrategoGame.RED, archer_id, [], Vector2i(9, 6))
	_expect(bool(overwatch_shot.ok), "stationary Archers may aim beyond two squares as overwatch")
	_expect(game.declared_shot_type_for(StrategoGame.RED, archer_id, Vector2i(9, 6)) == StrategoGame.SHOT_LONG, "an overwatch declaration is a long shot")
	var moved_long_shot := game.set_unit_order(StrategoGame.RED, archer_id, [Vector2i(6, 7)], Vector2i(8, 6))
	_expect(not bool(moved_long_shot.ok), "an Archer that has ordered movement may only declare an adjacent target")
	var unseen_shot := game.set_unit_order(StrategoGame.RED, archer_id, [], Vector2i(6, 15))
	_expect(not bool(unseen_shot.ok), "Archers cannot declare a target they cannot see")


func _test_group_orders_are_atomic() -> void:
	var game := _test_game()
	var rear_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 6))
	var front_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5))
	game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	var advance := game.append_group_order_step(StrategoGame.BLUE, [rear_id, front_id], Vector2i.UP)
	_expect(bool(advance.ok), "a selected formation line can receive one atomic shared movement order")
	_expect(game.projected_order_position(rear_id, 1) == Vector2i(5, 5) and game.projected_order_position(front_id, 1) == Vector2i(5, 4), "group movement preserves formation spacing while advancing")
	var mixed_game := _test_game()
	var heavy_id := mixed_game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(8, 6))
	var light_id := mixed_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(10, 6))
	mixed_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	mixed_game.append_group_order_step(StrategoGame.BLUE, [heavy_id, light_id], Vector2i.UP)
	var second_advance := mixed_game.append_group_order_step(StrategoGame.BLUE, [heavy_id, light_id], Vector2i.UP)
	_expect(bool(second_advance.ok) and int(second_advance.count) == 1 and int(second_advance.skipped) == 1, "group movement skips formations whose movement allowance is exhausted")
	_expect(mixed_game.order_for_piece(heavy_id).path.size() == 1 and mixed_game.order_for_piece(light_id).path.size() == 2, "faster selected formations continue after slower formations stop")
	var edge_game := _test_game()
	var edge_id := edge_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(2, 0))
	var safe_id := edge_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(3, 2))
	edge_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	var rejected := edge_game.append_group_order_step(StrategoGame.BLUE, [edge_id, safe_id], Vector2i.UP)
	_expect(not bool(rejected.ok), "a shared order is rejected when any selected formation cannot execute it")
	_expect(edge_game.order_for_piece(edge_id).is_empty() and edge_game.order_for_piece(safe_id).is_empty(), "a rejected group order leaves every selected formation unchanged")


func _test_planning_order_undo() -> void:
	var game := _test_game()
	var mover_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5))
	game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	var board_view := StrategoBoardView.new()
	root.add_child(board_view)
	board_view.set_game(game)
	board_view.selected_piece_ids.assign([mover_id])
	board_view.selected_piece_id = mover_id
	board_view.issue_selected_direction(Vector2i.UP)
	_expect(board_view.can_undo_order(), "issuing an order enables planning-phase undo")
	board_view.undo_last_order()
	_expect(game.order_for_piece(mover_id).is_empty(), "undo restores the formation's previous order state")
	board_view.issue_selected_direction(Vector2i.UP)
	board_view.clear_all_orders()
	board_view.undo_last_order()
	_expect(game.order_for_piece(mover_id).path == [Vector2i(5, 4)], "clear orders can be undone before planning ends")
	board_view.clear_order_undo_history()
	_expect(not board_view.can_undo_order(), "ending planning clears order history before the next round")
	board_view.queue_free()


func _test_impulse_movement() -> void:
	var game := _test_game()
	var mover_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(1, 1))
	game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(18, 18))
	game.set_unit_order(StrategoGame.RED, mover_id, [Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2)])
	var events := _ready_and_resolve(game)
	_expect(game.pieces[mover_id].position == Vector2i(3, 2), "planned movement resolves one square per impulse")
	_expect(_events_with_action(events, "move").size() == 3, "a Light unit's three path squares produce three movement events")


func _test_weighted_impulse_timing_and_actual_spend() -> void:
	var timing_game := _test_game()
	var light_id := timing_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(1, 1))
	var medium_id := timing_game.add_piece(StrategoGame.MEDIUM_INFANTRY, StrategoGame.RED, Vector2i(1, 5))
	var heavy_id := timing_game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.RED, Vector2i(1, 9))
	timing_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(18, 18))
	timing_game.set_unit_order(StrategoGame.RED, light_id, [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)])
	timing_game.set_unit_order(StrategoGame.RED, medium_id, [Vector2i(2, 5), Vector2i(3, 5)])
	timing_game.set_unit_order(StrategoGame.RED, heavy_id, [Vector2i(2, 9)])
	_expect(timing_game.projected_order_position(medium_id, 1) == Vector2i(1, 5) and timing_game.projected_order_position(heavy_id, 2) == Vector2i(1, 9), "order ghosts keep Medium and Heavy formations stationary until their scheduled impulses")
	var timing_events := _ready_and_resolve(timing_game)
	var batches_by_piece := {light_id: [], medium_id: [], heavy_id: []}
	for event: Dictionary in _events_with_action(timing_events, "move"):
		var piece_id := int(event.piece_id)
		if piece_id in batches_by_piece:
			batches_by_piece[piece_id].append(String(event.batch))
	_expect(batches_by_piece[light_id] == ["impulse_1", "impulse_2", "impulse_3"], "Light formations move on impulses 1, 2, and 3")
	_expect(batches_by_piece[medium_id] == ["impulse_2", "impulse_3"], "Medium formations move on impulses 2 and 3")
	_expect(batches_by_piece[heavy_id] == ["impulse_3"], "Heavy formations move only on impulse 3")

	var win_game := _test_game()
	var winner := win_game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(1, 1), 10)
	win_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	win_game.set_unit_order(StrategoGame.RED, winner, [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)])
	win_game.set_forced_rolls([5, 1])
	for player in win_game.active_players:
		win_game.mark_player_ready(player)
	win_game.resolve_main_and_ranged()
	_expect(int(win_game.pieces[winner].movement_used) == 1 and win_game.can_receive_leftover_order(StrategoGame.RED, winner), "a main-phase winner spends only the movement it actually attempted before combat ended its path")

	var bounce_game := _test_game()
	var bouncer := bounce_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 10)
	bounce_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	bounce_game.set_unit_order(StrategoGame.RED, bouncer, [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)])
	bounce_game.set_forced_rolls([2, 2])
	for player in bounce_game.active_players:
		bounce_game.mark_player_ready(player)
	bounce_game.resolve_main_and_ranged()
	_expect(int(bounce_game.pieces[bouncer].movement_used) == 1 and bounce_game.pieces[bouncer].round_status == StrategoGame.STATUS_BOUNCED, "entering a contested square spends movement even when the formation bounces")


func _test_allied_collision_bounces_without_combat() -> void:
	var game := _test_game()
	var red_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(1, 2), 8)
	var green_id := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.GREEN, Vector2i(3, 2), 8)
	game.set_player_team(StrategoGame.RED, 7)
	game.set_player_team(StrategoGame.GREEN, 7)
	game.set_unit_order(StrategoGame.RED, red_id, [Vector2i(2, 2)])
	game.set_unit_order(StrategoGame.GREEN, green_id, [Vector2i(2, 2)])
	var events := _ready_and_resolve(game)
	var bounces := _events_with_action(events, "bounce")
	_expect(bounces.size() == 1 and not bool(bounces[0].combat), "different-player allies collide as a non-combat bounce")
	_expect(game.pieces[red_id].position == Vector2i(1, 2) and game.pieces[green_id].position == Vector2i(3, 2), "allied collision returns both formations to their previous squares")
	_expect(game.pieces[red_id].strength == 8 and game.pieces[green_id].strength == 8, "allied collision deals no damage")
	_expect(not bool(game.pieces[red_id].participated_in_combat) and game.pieces[red_id].round_status == StrategoGame.STATUS_BOUNCED, "non-combat bounce is distinct from combat participation and loss")
	var stationary_game := _test_game()
	var moving_id := stationary_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(1, 1), 8)
	var stationary_id := stationary_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.GREEN, Vector2i(2, 1), 8)
	stationary_game.set_player_team(StrategoGame.RED, 4)
	stationary_game.set_player_team(StrategoGame.GREEN, 4)
	stationary_game.set_unit_order(StrategoGame.RED, moving_id, [Vector2i(2, 1)])
	_ready_and_resolve(stationary_game)
	_expect(stationary_game.pieces[moving_id].round_status == StrategoGame.STATUS_BOUNCED and stationary_game.pieces[stationary_id].round_status == StrategoGame.STATUS_BOUNCED, "a stationary allied participant is also done for the round after the collision")


func _test_crossing_battle_both_attack() -> void:
	var game := _test_game()
	var red_id := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(1, 1), 10)
	var blue_id := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.BLUE, Vector2i(2, 1), 10)
	game.set_unit_order(StrategoGame.RED, red_id, [Vector2i(2, 1)])
	game.set_unit_order(StrategoGame.BLUE, blue_id, [Vector2i(1, 1)])
	var events := _ready_and_resolve(game, [4, 4])
	var battles := _events_with_action(events, "crossing_battle")
	_expect(battles.size() == 1 and int(battles[0].scores[red_id]) == 7 and int(battles[0].scores[blue_id]) == 7, "crossing enemies both receive Cavalry's attacking bonus")
	_expect(game.pieces[red_id].position == Vector2i(1, 1) and game.pieces[blue_id].position == Vector2i(2, 1), "a crossing-path tie bounces both units to their previous squares")
	var infantry_result := game.calculate_melee({"strength": 10, "role": StrategoGame.ROLE_INFANTRY, "armor": 0}, {"strength": 10, "role": StrategoGame.ROLE_INFANTRY, "armor": 0}, 4, 5, true)
	_expect(infantry_result.attacker_score == 4 and infantry_result.defender_score == 5, "crossing-path Infantry receives no defense bonus")


func _test_tie_is_a_bounce() -> void:
	var game := _test_game()
	var attacker_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 10)
	var defender_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	game.set_unit_order(StrategoGame.RED, attacker_id, [Vector2i(2, 1)])
	var events := _ready_and_resolve(game, [2, 2])
	var battle := _events_with_action(events, "melee")[0]
	_expect(battle.result == "bounce" and int(battle.winner_id) == StrategoGame.EMPTY, "equal battle scores produce no winner")
	_expect(game.pieces[attacker_id].position == Vector2i(1, 1) and game.pieces[defender_id].position == Vector2i(2, 1), "combat tie returns everyone to their previous square")
	_expect(game.pieces[attacker_id].round_status == StrategoGame.STATUS_BOUNCED and game.pieces[defender_id].round_status == StrategoGame.STATUS_BOUNCED, "tied units are bounced, not marked as losers")


func _test_winner_doubles_armor() -> void:
	var game := _test_game()
	var heavy := {"strength": 10, "role": StrategoGame.ROLE_CAVALRY, "armor": 2}
	var light := {"strength": 10, "role": StrategoGame.ROLE_ARCHER, "armor": 0}
	var heavy_win := game.calculate_melee(heavy, light, 4, 6)
	_expect(heavy_win.attacker_score == 7 and heavy_win.attacker_damage == 2, "winning Heavy uses Armor 4 for that combat")
	var medium := {"strength": 10, "role": StrategoGame.ROLE_CAVALRY, "armor": 1}
	var medium_win := game.calculate_melee(medium, light, 4, 6)
	_expect(medium_win.attacker_damage == 4, "winning Medium uses Armor 2 for that combat")
	var light_win := game.calculate_melee(light, {"strength": 10, "role": StrategoGame.ROLE_ARCHER, "armor": 0}, 7, 6)
	_expect(light_win.attacker_damage == 6, "winning Light remains Armor 0")


func _test_natural_ten_always_chips() -> void:
	var game := _test_game()
	var weak := {"strength": 1, "role": StrategoGame.ROLE_ARCHER, "armor": 0}
	var heavy := {"strength": 10, "role": StrategoGame.ROLE_INFANTRY, "armor": 2}
	var result := game.calculate_melee(weak, heavy, 10, 1)
	_expect(result.defender_damage == 1, "natural 10 adds one after doubled winner Armor and always chips")
	var ranged := game.calculate_ranged(weak, heavy, 10)
	_expect(ranged.defender_damage == 1, "natural 10 also always chips in ranged fire")


func _test_multiway_unique_winner() -> void:
	var game := _test_game()
	var first_id := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(1, 2), 10)
	var second_id := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(2, 3), 10)
	var defender_id := game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(2, 2), 10)
	game.set_unit_order(StrategoGame.RED, first_id, [Vector2i(2, 2)])
	var second_order := game.set_unit_order(StrategoGame.RED, second_id, [Vector2i(2, 2)])
	_expect(bool(second_order.ok), "multiple same-player attackers may converge on a known enemy for a multiway battle")
	var events := _ready_and_resolve(game, [7, 4, 4])
	var battle := _events_with_action(events, "melee")[0]
	_expect(int(battle.winner_id) == first_id, "a unique highest scorer wins a multiway contested square")
	_expect(game.pieces[first_id].position == Vector2i(2, 2), "unique friendly leader occupies the contested square")
	_expect(game.pieces[second_id].position == Vector2i(2, 3) and game.pieces[second_id].round_status == StrategoGame.STATUS_BOUNCED, "friendly non-winning attacker bounces")
	_expect(game.pieces[defender_id].position == Vector2i(3, 2) and game.pieces[defender_id].round_status == StrategoGame.STATUS_LOST, "opposing multiway loser retreats")


func _test_multiway_friendly_leader_tie() -> void:
	var game := _test_game()
	var first_id := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(1, 2), 10)
	var second_id := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(2, 3), 10)
	var defender_id := game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(2, 2), 10)
	game.set_unit_order(StrategoGame.RED, first_id, [Vector2i(2, 2)])
	game.set_unit_order(StrategoGame.RED, second_id, [Vector2i(2, 2)])
	_ready_and_resolve(game, [5, 5, 3])
	_expect(game.pieces[first_id].position == Vector2i(1, 2) and game.pieces[second_id].position == Vector2i(2, 3), "same-side tied leaders bounce after beating the enemy")
	_expect(game.piece_at(Vector2i(2, 2)).is_empty(), "same-side tied leaders leave the contested square empty")
	_expect(game.pieces[defender_id].position == Vector2i(3, 2), "enemy still retreats when tied friendly leaders beat it")


func _test_multiway_damage_uses_highest_opponent() -> void:
	var game := _test_game()
	var red_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 2), 10)
	var blue_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(3, 2), 10)
	var green_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.GREEN, Vector2i(2, 3), 10)
	game.set_unit_order(StrategoGame.RED, red_id, [Vector2i(2, 2)])
	game.set_unit_order(StrategoGame.BLUE, blue_id, [Vector2i(2, 2)])
	game.set_unit_order(StrategoGame.GREEN, green_id, [Vector2i(2, 2)])
	var events := _ready_and_resolve(game, [6, 4, 3])
	var battle := _events_with_action(events, "melee")[0]
	_expect(int(battle.damage[red_id]) == 4, "multiway damage uses the highest opposing score rather than summing opponents")
	_expect(int(game.pieces[red_id].strength) == 6, "the unique winner takes only that highest opposing damage")


func _test_ranged_focus_fire_is_simultaneous() -> void:
	var game := _test_game()
	var first_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 2), 5)
	var second_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(2, 1), 5)
	var target_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(2, 2), 4)
	game.set_unit_order(StrategoGame.RED, first_id, [], Vector2i(2, 2))
	game.set_unit_order(StrategoGame.RED, second_id, [], Vector2i(2, 2))
	var events := _ready_and_resolve(game, [5, 5])
	_expect(_events_with_action(events, "ranged").size() == 2, "all scheduled focus-fire shots resolve even when the target is overkilled")
	_expect(not game.pieces[target_id].alive, "simultaneous ranged damage destroys an overkilled target")
	_expect(game.pieces[first_id].strength == 5 and game.pieces[second_id].strength == 5, "ranged targets deal no return damage")
	var long_game := _test_game()
	var long_archer := long_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 5)
	var long_target := long_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(3, 1), 6)
	long_game.set_unit_order(StrategoGame.RED, long_archer, [], Vector2i(3, 1))
	var long_events := _ready_and_resolve(long_game, [4])
	var long_shots := _events_with_action(long_events, "ranged")
	_expect(long_shots.size() == 1 and int(long_shots[0].range) == 2 and int(long_shots[0].movement_cost) == 3, "a stationary Light Archer can fire at range 2 by consuming its full movement")
	_expect(long_game.pieces[long_target].strength == 2, "range-2 fire deals normal ranged damage")
	_expect(long_game.movement_committed(long_game.pieces[long_archer]) == 3 and not long_game.can_receive_leftover_order(StrategoGame.RED, long_archer), "a long shot that fires consumes everything and leaves no leftover movement")
	_test_aimed_fire_follows_its_target()
	_test_suppressing_fire_hits_the_square()
	_test_fizzled_shots_still_cost_the_aim_point()


## Aimed fire tracks the formation: a target that moves but stays in range is
## still hit, which is the whole point of targeting a unit rather than a square.
func _test_aimed_fire_follows_its_target() -> void:
	var game := _test_game()
	var archer := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 5)
	var target := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(3, 1), 6)
	game.set_unit_order(StrategoGame.RED, archer, [], Vector2i(3, 1), Vector2i(-1, -1), target)
	game.set_unit_order(StrategoGame.BLUE, target, [Vector2i(2, 1)])
	var events := _ready_and_resolve(game, [4])
	var shots := _events_with_action(events, "ranged")
	_expect(shots.size() == 1 and int(shots[0].target_id) == target, "aimed fire still hits a target that moved within range")
	_expect(int(shots[0].range) == 1, "the shot resolves at the range the target actually ended up at")
	var away_game := _test_game()
	var away_archer := away_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 5)
	var away_target := away_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(3, 1), 6)
	away_game.set_unit_order(StrategoGame.RED, away_archer, [], Vector2i(3, 1), Vector2i(-1, -1), away_target)
	away_game.set_unit_order(StrategoGame.BLUE, away_target, [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)])
	var away_events := _ready_and_resolve(away_game)
	_expect(_events_with_action(away_events, "ranged").is_empty(), "aimed fire finds nothing when the target breaks out of range")
	_expect(_events_with_action(away_events, "ranged_fizzle").size() == 1, "a shot that finds nothing is reported as a fizzle")


## Suppressing fire is aimed at ground, so whoever holds that square takes it.
func _test_suppressing_fire_hits_the_square() -> void:
	var game := _test_game()
	var archer := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 5)
	var mover := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(4, 1), 6)
	game.set_suppress_order(StrategoGame.RED, archer, Vector2i(3, 1))
	game.set_unit_order(StrategoGame.BLUE, mover, [Vector2i(3, 1)])
	var events := _ready_and_resolve(game, [4])
	var shots := _events_with_action(events, "ranged")
	_expect(shots.size() == 1 and int(shots[0].target_id) == mover, "suppressing fire hits whoever moves onto the targeted square")


## The aim point is spent during main movement, so a shot that never fires still
## costs it. That is what stops overwatch from being free for a Heavy Archer.
func _test_fizzled_shots_still_cost_the_aim_point() -> void:
	var game := _test_game()
	var light := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 5)
	var heavy := game.add_piece(StrategoGame.HEAVY_ARCHER, StrategoGame.RED, Vector2i(1, 5), 7)
	var bait := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 1), 6)
	game.set_unit_order(StrategoGame.RED, light, [], Vector2i(5, 1), Vector2i(-1, -1), bait)
	game.set_unit_order(StrategoGame.RED, heavy, [], Vector2i(5, 1), Vector2i(-1, -1), bait)
	game.set_unit_order(StrategoGame.BLUE, bait, [Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1)])
	# Stop after main and ranged so leftover eligibility can still be inspected.
	for player in game.active_players.duplicate():
		game.mark_player_ready(player)
	var events := game.resolve_main_and_ranged()
	_expect(game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING, "the round pauses for leftover planning after ranged fire")
	_expect(_events_with_action(events, "ranged_fizzle").size() == 2, "both overwatch declarations fizzle when the target never closes")
	_expect(int(game.pieces[light].aim_spent) == 1 and int(game.pieces[heavy].aim_spent) == 1, "a fizzled shot still spends the aim point")
	_expect(game.can_receive_leftover_order(StrategoGame.RED, light), "a Light Archer keeps a leftover move after a fizzled shot")
	_expect(not game.can_receive_leftover_order(StrategoGame.RED, heavy), "aiming costs a Heavy Archer its entire round")


func _test_archer_loss_blocks_shot_and_win_allows_it() -> void:
	var losing_game := _test_game()
	var losing_archer := losing_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 10)
	losing_game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(2, 1), 10)
	var untouched_target := losing_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.GREEN, Vector2i(2, 2), 10)
	losing_game.set_unit_order(StrategoGame.RED, losing_archer, [Vector2i(2, 1)], Vector2i(2, 2))
	var losing_events := _ready_and_resolve(losing_game, [1, 7])
	_expect(_events_with_action(losing_events, "ranged").is_empty() and losing_game.pieces[untouched_target].strength == 10, "an Archer that loses and retreats cannot shoot")
	var winning_game := _test_game()
	var winning_archer := winning_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 10)
	winning_game.add_piece(StrategoGame.HEAVY_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	var shot_target := winning_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.GREEN, Vector2i(2, 2), 10)
	winning_game.set_unit_order(StrategoGame.RED, winning_archer, [Vector2i(2, 1)], Vector2i(2, 2))
	var winning_events := _ready_and_resolve(winning_game, [5, 1, 4])
	_expect(_events_with_action(winning_events, "ranged").size() == 1 and winning_game.pieces[shot_target].strength == 6, "an Archer that wins melee may shoot with unused movement")


func _test_leftover_is_a_separate_order_phase() -> void:
	var game := _test_game()
	var mover := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(4, 4), 8)
	game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(18, 18), 8)
	game.set_unit_order(StrategoGame.RED, mover, [Vector2i(4, 3)])
	for player in game.active_players:
		game.mark_player_ready(player)
	game.resolve_main_and_ranged()
	_expect(game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING and game.round_number == 1, "the round pauses for leftover orders after ranged attacks")
	var presenter: Control = load("res://scripts/main.gd").new()
	presenter.game = game
	_expect(presenter._resolution_completion_label() == "ORDER LEFTOVER", "the final main-resolution button clearly opens leftover ordering")
	presenter.free()
	var order_result := game.set_leftover_order(StrategoGame.RED, mover, Vector2i(4, 2))
	_expect(bool(order_result.get("ok", false)) and game.pieces[mover].position == Vector2i(4, 3), "leftover orders are issued from the formation's resolved position")
	for player in game.active_players:
		game.mark_player_ready(player)
	var events := game.resolve_leftover_phase()
	_expect(_events_with_action(events, "move").size() == 1 and game.pieces[mover].position == Vector2i(4, 2), "ending the leftover phase resolves its simultaneous movement")
	_expect(game.phase == StrategoGame.PHASE_PLANNING and game.round_number == 2, "the next planning round starts only after leftover movement finishes")


func _test_leftover_allows_second_melee_only_after_win() -> void:
	var move_game := _test_game()
	var leftover_mover := move_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(4, 4), 8)
	move_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(18, 18), 8)
	move_game.set_leftover_order(StrategoGame.RED, leftover_mover, Vector2i(4, 3))
	var move_events := _ready_and_resolve(move_game)
	var leftover_moves: Array[Dictionary] = []
	for event: Dictionary in _events_with_action(move_events, "move"):
		if String(event.get("batch", "")) == "leftover": leftover_moves.append(event)
	_expect(leftover_moves.size() == 1 and move_game.pieces[leftover_mover].position == Vector2i(4, 3), "an uncontested leftover order executes in the leftover movement phase")
	var presenter: Control = load("res://scripts/main.gd").new()
	presenter.game = move_game
	var presentation_input: Array[Dictionary] = [{"action": "move", "batch": "leftover", "piece_id": leftover_mover, "visible_to": [StrategoGame.BLUE], "combat": false}]
	var presented_leftovers: Array[Dictionary] = presenter._visible_presentation_events(presentation_input)
	_expect(presented_leftovers.size() == 1 and presented_leftovers[0].action == "leftover_move", "ordinary leftover movement appears in the click-through resolution review")
	presenter.free()
	var group_game := _test_game()
	var exhausted_heavy := group_game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(8, 6))
	var eligible_light := group_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(10, 6))
	group_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	group_game.append_group_order_step(StrategoGame.BLUE, [exhausted_heavy, eligible_light], Vector2i.UP)
	var group_leftover := group_game.set_group_leftover_step(StrategoGame.BLUE, [exhausted_heavy, eligible_light], Vector2i.LEFT)
	_expect(bool(group_leftover.ok) and int(group_leftover.count) == 1 and int(group_leftover.skipped) == 1, "group leftover orders skip formations with no movement remaining")
	_expect(group_game.order_for_piece(exhausted_heavy).leftover.x < 0 and group_game.order_for_piece(eligible_light).leftover == Vector2i(9, 5), "eligible group members receive the shared leftover direction")
	var win_game := _test_game()
	var cavalry_id := win_game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(1, 1), 10)
	win_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	win_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.GREEN, Vector2i(2, 2), 10)
	win_game.set_unit_order(StrategoGame.RED, cavalry_id, [Vector2i(2, 1)], Vector2i(-1, -1), Vector2i(2, 2))
	var win_events := _ready_and_resolve(win_game, [4, 1, 4, 1])
	_expect(_events_with_action(win_events, "melee").size() == 2 and int(win_game.pieces[cavalry_id].melee_count) == 2, "a winner can use leftover movement for at most a second intentional melee")
	var bounce_game := _test_game()
	var bounced_id := bounce_game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(1, 1), 10)
	bounce_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	bounce_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.GREEN, Vector2i(2, 2), 10)
	bounce_game.set_unit_order(StrategoGame.RED, bounced_id, [Vector2i(2, 1)], Vector2i(-1, -1), Vector2i(2, 2))
	var bounce_events := _ready_and_resolve(bounce_game, [1, 4])
	_expect(_events_with_action(bounce_events, "melee").size() == 1 and bounce_game.pieces[bounced_id].round_status == StrategoGame.STATUS_BOUNCED, "a bounce ends the unit's round and prevents leftover re-engagement")


func _test_blocked_retreat_destroys_loser() -> void:
	var game := _test_game()
	var attacker_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 0), 10)
	var defender_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(0, 0), 10)
	game.set_unit_order(StrategoGame.RED, attacker_id, [Vector2i(0, 0)])
	var events := _ready_and_resolve(game, [5, 1])
	var retreat_events := _events_with_action(events, "retreat")
	_expect(retreat_events.size() == 1 and retreat_events[0].result == "retreat_destroyed", "retreat off-map destroys the losing formation")
	_expect(not game.pieces[defender_id].alive and game.pieces[attacker_id].position == Vector2i(0, 0), "winner occupies after the blocked defender retreat")


func _test_enemy_retreat_collision_battle() -> void:
	var game := _test_game()
	var red_attacker := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 10)
	var blue_defender := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	var yellow_attacker := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.YELLOW, Vector2i(3, 3), 10)
	var green_defender := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.GREEN, Vector2i(3, 2), 10)
	game.set_unit_order(StrategoGame.RED, red_attacker, [Vector2i(2, 1)])
	game.set_unit_order(StrategoGame.YELLOW, yellow_attacker, [Vector2i(3, 2)])
	var events := _ready_and_resolve(game, [5, 1, 5, 1, 4, 4])
	var retreat_battles := _events_with_action(events, "retreat_battle")
	_expect(retreat_battles.size() == 1, "enemy retreats entering the same previously empty square create a retreat battle")
	_expect(int(retreat_battles[0].scores[blue_defender]) == 4 and int(retreat_battles[0].scores[green_defender]) == 4, "retreat battles apply no attacker, defender, or role bonuses")
	_expect(not game.pieces[blue_defender].alive and not game.pieces[green_defender].alive, "a tied retreat battle destroys both formations with no further retreat")
	var armor_game := _test_game()
	var heavy_id := armor_game.add_piece(StrategoGame.HEAVY_ARCHER, StrategoGame.RED, Vector2i(0, 0), 10)
	var light_id := armor_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 0), 10)
	armor_game._clear_piece_square(heavy_id)
	armor_game._clear_piece_square(light_id)
	armor_game.set_forced_rolls([5, 4])
	armor_game._resolve_retreat_battle([
		{"piece_id": heavy_id, "from": Vector2i(0, 0), "to": Vector2i(1, 0)},
		{"piece_id": light_id, "from": Vector2i(2, 0), "to": Vector2i(1, 0)},
	], Vector2i(1, 0), "test")
	_expect(armor_game.pieces[heavy_id].alive and armor_game.pieces[heavy_id].strength == 10, "a unique retreat-battle winner also receives doubled Armor for that combat")


func _test_impulse_sighting_is_remembered() -> void:
	var game := _test_game()
	game.vision_range = 1
	var red_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(3, 5), 10)
	game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5), 10)
	game.set_unit_order(StrategoGame.RED, red_id, [Vector2i(4, 5), Vector2i(4, 4), Vector2i(3, 4)])
	_ready_and_resolve(game)
	_expect(game.has_seen_piece(game.pieces[red_id], StrategoGame.BLUE), "seeing a unit during any movement impulse counts as having seen it")
	_expect(not game.is_piece_visible_to(game.pieces[red_id], StrategoGame.BLUE), "a transiently seen unit can finish outside current fog vision")


func _test_combat_reveal_requires_current_sight() -> void:
	var game := _test_game()
	game.vision_range = 1
	var red_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 10)
	game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	game.set_unit_order(StrategoGame.RED, red_id, [Vector2i(2, 1)])
	_ready_and_resolve(game, [2, 2])
	_expect(game.is_piece_revealed_to(game.pieces[red_id], StrategoGame.BLUE), "combat reveals role, weight, and current Strength while the formation is in sight")
	game.set_unit_order(StrategoGame.RED, red_id, [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)])
	_ready_and_resolve(game)
	_expect(not game.is_piece_revealed_to(game.pieces[red_id], StrategoGame.BLUE), "combat identity is no longer exposed after the target leaves sight")


func _test_bridge_end_of_round_victory() -> void:
	var breakthrough := _test_game()
	breakthrough.scenario = StrategoGame.SCENARIO_BRIDGE
	breakthrough.bridge_attacker = StrategoGame.BLUE
	breakthrough.bridge_defender = StrategoGame.RED
	breakthrough.bridge_turn_limit = 20
	breakthrough.add_reach_area_objective(StrategoGame.BLUE, Rect2i(0, 0, StrategoGame.BOARD_SIZE, StrategoGame.BRIDGE_RIVER_Y), 20, "bridge_breakthrough")
	breakthrough.add_survive_objective(StrategoGame.RED, 20, "turn_limit")
	breakthrough.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 8), 20)
	breakthrough.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(5, 0), 10)
	_ready_and_resolve(breakthrough)
	_expect(breakthrough.game_over and breakthrough.winner == StrategoGame.BLUE and breakthrough.end_reason == "bridge_breakthrough", "attacker wins only at end of round with 20 current Strength across")
	var deadline := _test_game()
	deadline.scenario = StrategoGame.SCENARIO_BRIDGE
	deadline.bridge_attacker = StrategoGame.BLUE
	deadline.bridge_defender = StrategoGame.RED
	deadline.bridge_turn_limit = 1
	deadline.add_reach_area_objective(StrategoGame.BLUE, Rect2i(0, 0, StrategoGame.BOARD_SIZE, StrategoGame.BRIDGE_RIVER_Y), 20, "bridge_breakthrough")
	deadline.add_survive_objective(StrategoGame.RED, 1, "turn_limit")
	deadline.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 19), 10)
	deadline.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(5, 0), 10)
	_ready_and_resolve(deadline)
	_expect(deadline.game_over and deadline.winner == StrategoGame.RED and deadline.end_reason == "turn_limit", "defender wins when the attacker fails by the testing turn limit")


## Holding the centre must be consecutive: losing it for a single round sends
## the streak back to zero, and a contested objective at the limit is a draw.
func _test_meeting_engagement_hold_objective() -> void:
	var setup_game := StrategoGame.new()
	setup_game.setup_meeting(7)
	_expect(setup_game.scenario == StrategoGame.SCENARIO_MEETING, "meeting engagement loads its own scenario")
	_expect(setup_game.objectives.size() == 1 and setup_game.objectives[0].square == Vector2i(10, 10), "the meeting objective is the centre square")
	var blue_rows: Array = []
	var red_rows: Array = []
	for piece: Dictionary in setup_game.pieces:
		if int(piece.player) == StrategoGame.BLUE: blue_rows.append(int(piece.position.y))
		else: red_rows.append(int(piece.position.y))
	_expect(blue_rows.count(19) == blue_rows.size() and red_rows.count(0) == red_rows.size(), "both armies deploy on their own back rank")
	_expect(setup_game.total_strength(StrategoGame.BLUE) == setup_game.total_strength(StrategoGame.RED), "meeting engagements start symmetric")

	var game := StrategoGame.new()
	game.setup_empty()
	game.scenario = StrategoGame.SCENARIO_MEETING
	var objective := Vector2i(5, 5)
	game.add_hold_square_objective(objective, 3, 12)
	var holder := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, objective)
	var rival := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(5, 8))
	_ready_and_resolve(game)
	_expect(game.objective_streak(0, StrategoGame.BLUE) == 1, "holding the square banks one round")
	_ready_and_resolve(game)
	_expect(game.objective_streak(0, StrategoGame.BLUE) == 2 and not game.game_over, "two rounds is not yet enough")
	# Step off, and the consolidation has to start over.
	game.set_unit_order(StrategoGame.BLUE, holder, [Vector2i(5, 4)])
	_ready_and_resolve(game)
	_expect(game.objective_streak(0, StrategoGame.BLUE) == 0, "leaving the square resets the streak")
	game.set_unit_order(StrategoGame.BLUE, holder, [Vector2i(5, 5)])
	_ready_and_resolve(game)
	_expect(game.objective_streak(0, StrategoGame.BLUE) == 1, "retaking the square starts a fresh streak")
	_ready_and_resolve(game)
	_ready_and_resolve(game)
	_expect(game.game_over and game.winner == StrategoGame.BLUE and game.end_reason == "held_objective", "three consecutive rounds wins the objective")
	_expect(game.pieces[rival].alive, "the objective is won by holding it, not by destroying the enemy")

	var replayable := StrategoGame.new()
	replayable.setup_meeting(4, StrategoGame.BLUE, StrategoGame.RED, 3, 6)
	var bot := StrategoBotPolicy.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for round_index in 3:
		if replayable.game_over: break
		for player in replayable.active_players.duplicate():
			bot.plan_round(replayable, player, rng)
			replayable.mark_player_ready(player)
		replayable.resolve_main_and_ranged()
		for player in replayable.active_players.duplicate():
			bot.plan_leftover(replayable, player, rng)
			replayable.mark_player_ready(player)
		replayable.resolve_leftover_phase()
	var document := replayable.build_replay_document()
	_expect(String(document.setup.scenario) == StrategoGame.SCENARIO_MEETING, "a meeting replay records its scenario")
	var verified := StrategoGame.run_replay(document)
	_expect(bool(verified.get("ok", false)), "a meeting engagement replays deterministically: %s" % String(verified.get("message", "")))
	_expect(String(verified.get("digest", "")) == replayable.state_digest(), "the meeting replay reconstructs the exact final state")

	var drawn := StrategoGame.new()
	drawn.setup_empty()
	drawn.scenario = StrategoGame.SCENARIO_MEETING
	drawn.add_hold_square_objective(Vector2i(5, 5), 3, 2)
	drawn.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(1, 1))
	drawn.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(9, 9))
	_ready_and_resolve(drawn)
	_ready_and_resolve(drawn)
	_expect(drawn.game_over and drawn.winner == StrategoGame.DRAW and drawn.end_reason == "objective_contested", "an objective nobody consolidates is a draw")


func _test_withdrawal_preserves_survivors_and_no_collapse() -> void:
	var game := StrategoGame.new()
	game.setup_bridge(777)
	var first_blue := -1
	for piece: Dictionary in game.pieces:
		if int(piece.player) == StrategoGame.BLUE:
			first_blue = int(piece.id)
			break
	game.pieces[first_blue].strength = 3
	var strength_before := game.total_strength(StrategoGame.BLUE)
	var alive_before := game.count_alive(StrategoGame.BLUE)
	var result := game.withdraw_player(StrategoGame.BLUE)
	_expect(bool(result.ok) and game.winner == StrategoGame.RED and game.end_reason == "withdrawal", "human withdrawal immediately concedes during planning")
	_expect(game.total_strength(StrategoGame.BLUE) == strength_before and game.count_alive(StrategoGame.BLUE) == alive_before, "withdrawal preserves every surviving formation at current Strength")
	var lopsided := _test_game()
	lopsided.scenario = StrategoGame.SCENARIO_BRIDGE
	lopsided.bridge_attacker = StrategoGame.BLUE
	lopsided.bridge_defender = StrategoGame.RED
	lopsided.bridge_turn_limit = 20
	lopsided.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 19), 1)
	lopsided.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(5, 0), 100)
	_ready_and_resolve(lopsided)
	_expect(not lopsided.game_over, "no automatic material-collapse threshold is implemented yet")


func _test_deterministic_replay_export() -> void:
	var game := StrategoGame.new()
	game.setup_bridge(730241)
	var policy := StrategoBotPolicy.new()
	var planning_rng := RandomNumberGenerator.new()
	planning_rng.seed = 88991
	for round_index in range(6):
		if game.game_over:
			break
		for player in game.active_players.duplicate():
			policy.plan_round(game, player, planning_rng)
			game.mark_player_ready(player)
		game.resolve_round()
	var document := game.build_replay_document()
	_expect(String(document.get("format", "")) == StrategoGame.REPLAY_FORMAT and int(document.get("version", 0)) == StrategoGame.REPLAY_VERSION, "replay export identifies its versioned deterministic format")
	_expect(document.get("rounds", []).size() == game.replay_rounds.size() and game.replay_rounds.size() > 0, "replay export includes every completed round")
	var recorded_rolls := 0
	for round_value in document.get("rounds", []):
		if round_value is Dictionary:
			recorded_rolls += round_value.get("main_rolls", []).size() + round_value.get("leftover_rolls", []).size()
	_expect(recorded_rolls > 0, "replay export records the exact combat dice stream")
	var parsed_value: Variant = JSON.parse_string(JSON.stringify(document))
	var json_result: Dictionary = StrategoGame.run_replay(parsed_value as Dictionary) if parsed_value is Dictionary else {"ok": false}
	_expect(bool(json_result.get("ok", false)), "a JSON round trip replays without deterministic divergence")
	_expect(String(json_result.get("digest", "")) == game.state_digest(), "replay reconstructs the exact final authoritative state")
	var replay_path := "user://replays/automated-round-trip.json"
	var save_result := game.save_replay(replay_path)
	var load_result := StrategoGame.load_replay_document(replay_path)
	var file_result: Dictionary = StrategoGame.run_replay(load_result.get("document", {})) if bool(load_result.get("ok", false)) else {"ok": false}
	_expect(bool(save_result.get("ok", false)) and bool(load_result.get("ok", false)) and bool(file_result.get("ok", false)), "replay files save, load, and verify end to end")
	var tampered: Dictionary = document.duplicate(true)
	var tampered_setup: Dictionary = tampered.get("setup", {}).duplicate(true)
	tampered_setup.seed = int(tampered_setup.get("seed", 0)) + 1
	tampered.setup = tampered_setup
	var tampered_result := StrategoGame.run_replay(tampered)
	_expect(not bool(tampered_result.get("ok", false)), "replay verification rejects altered deterministic input")


func _test_bot_round_smoke() -> void:
	var game := StrategoGame.new()
	game.setup_random(9001, 4)
	var bot := StrategoBotPolicy.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for player in game.active_players:
		bot.plan_round(game, player, rng)
		game.mark_player_ready(player)
	var events := game.resolve_round()
	_expect(game.round_number == 2 and not events.is_empty(), "four bots can submit collision-validated WEGO orders and resolve a complete round")
	var trainer := SelfPlayTrainer.new()
	trainer.max_rounds = 4
	var result := trainer.play_match(bot, StrategoBotPolicy.new(), StrategoGame.RED, 424242)
	_expect(int(result.rounds) > 0 and int(result.rounds) <= 5, "headless self-play remains bounded under simultaneous orders")
