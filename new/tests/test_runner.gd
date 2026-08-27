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
	_test_impulse_movement()
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
	_test_leftover_allows_second_melee_only_after_win()
	_test_blocked_retreat_destroys_loser()
	_test_enemy_retreat_collision_battle()
	_test_impulse_sighting_is_remembered()
	_test_combat_reveal_requires_current_sight()
	_test_bridge_end_of_round_victory()
	_test_withdrawal_preserves_survivors_and_no_collapse()
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
	var distant_shot := game.set_unit_order(StrategoGame.RED, archer_id, [], Vector2i(8, 6))
	_expect(not bool(distant_shot.ok), "Archer orders reject non-adjacent ranged targets")


func _test_impulse_movement() -> void:
	var game := _test_game()
	var mover_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(1, 1))
	game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(18, 18))
	game.set_unit_order(StrategoGame.RED, mover_id, [Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2)])
	var events := _ready_and_resolve(game)
	_expect(game.pieces[mover_id].position == Vector2i(3, 2), "planned movement resolves one square per impulse")
	_expect(_events_with_action(events, "move").size() == 3, "a Light unit's three path squares produce three movement events")


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


func _test_leftover_allows_second_melee_only_after_win() -> void:
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
	breakthrough.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 8), 20)
	breakthrough.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(5, 0), 10)
	_ready_and_resolve(breakthrough)
	_expect(breakthrough.game_over and breakthrough.winner == StrategoGame.BLUE and breakthrough.end_reason == "bridge_breakthrough", "attacker wins only at end of round with 20 current Strength across")
	var deadline := _test_game()
	deadline.scenario = StrategoGame.SCENARIO_BRIDGE
	deadline.bridge_attacker = StrategoGame.BLUE
	deadline.bridge_defender = StrategoGame.RED
	deadline.bridge_turn_limit = 1
	deadline.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 19), 10)
	deadline.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(5, 0), 10)
	_ready_and_resolve(deadline)
	_expect(deadline.game_over and deadline.winner == StrategoGame.RED and deadline.end_reason == "turn_limit", "defender wins when the attacker fails by the testing turn limit")


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
