extends SceneTree

var failures := 0
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_hex_grid_topology()
	_test_campaign_files_declare_hex_grid()
	_test_bridge_setup()
	_test_four_player_fog_framework()
	_test_private_battle_results()
	_test_order_paths_and_friendly_rejection()
	_test_group_orders_apply_per_formation()
	_test_mixed_speed_formations_can_gang_up()
	_test_march_animation_staggers_by_weight()
	_test_permissive_orders_and_friendly_retry()
	_test_ranged_combat_reveals_both_parties()
	_test_planning_order_undo()
	_test_minimap_navigation_centres_main_view()
	_test_impulse_movement()
	_test_weighted_impulse_timing_and_actual_spend()
	_test_allied_collision_bounces_without_combat()
	_test_follower_advances_into_a_vacated_attack_square()
	_test_support_is_offered_on_a_friendly_formation()
	_test_reinforcing_a_defender_joins_its_fight()
	_test_bracing_is_earned_by_arriving_first()
	_test_bounced_attacker_survives_a_filled_origin()
	_test_crossing_battle_both_attack()
	_test_tie_is_a_bounce()
	_test_defender_wins_ties_toggle()
	_test_comparative_bonus_dice()
	_test_crit_sixes_cancel_across_sides()
	_test_multiway_unique_winner()
	_test_side_numbers_pay_in_dice_not_strength()
	_test_losing_side_shares_one_margin()
	_test_multiway_damage_uses_highest_opponent()
	_test_ranged_focus_fire_is_simultaneous()
	_test_archers_may_mass_a_volley_or_fire_apart()
	_test_archer_loss_blocks_shot_and_win_allows_it()
	_test_leftover_is_a_separate_order_phase()
	_test_reposition_moves_collapse_into_one_card()
	_test_reposition_keeps_unidentified_formations_secret()
	_test_leftover_contingent_friendly_square_order()
	_test_leftover_allows_second_melee_only_after_win()
	_test_universal_reposition_and_role_destinations()
	_test_phase_has_no_decision_ignores_idle_formations()
	_test_blocked_retreat_destroys_loser()
	_test_friendly_blocked_retreat_shunts()
	_test_enemy_retreat_collision_battle()
	_test_impulse_sighting_is_remembered()
	_test_combat_reveal_requires_current_sight()
	_test_bridge_end_of_round_victory()
	_test_withdrawal_preserves_survivors_and_no_collapse()
	_test_meeting_engagement_hold_objective()
	_test_highfield_setup()
	_test_deterministic_replay_export()
	_test_in_progress_replay_export()
	_test_deployment_zone_and_recommended_formation()
	_test_deployment_fog_and_redeploy()
	_test_crossroads_replay_round_trip()
	_test_bot_omniscient_toggle()
	_test_bot_round_smoke()
	_test_llm_client_parsing()
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


func _test_hex_grid_topology() -> void:
	var even_origin := Vector2i(8, 8)
	var odd_origin := Vector2i(9, 8)
	for origin in [even_origin, odd_origin]:
		var adjacent := HexGrid.neighbors(origin)
		_expect(adjacent.size() == 6, "an interior hex has six neighbours")
		var unique: Dictionary = {}
		for cell: Vector2i in adjacent:
			unique[cell] = true
			_expect(HexGrid.distance(origin, cell) == 1 and HexGrid.distance(cell, origin) == 1, "hex adjacency is symmetric on both column parities")
		_expect(unique.size() == 6, "all six hex neighbours are unique")
	_expect(HexGrid.cells_within_range(even_origin, 1).size() == 7, "hex radius one contains the origin and six neighbours")
	_expect(HexGrid.cells_within_range(even_origin, 2).size() == 19, "hex radius two contains nineteen cells")
	_expect(HexGrid.cells_within_range(even_origin, 4).size() == 61, "hex radius four contains sixty-one cells")
	for row in 6:
		for column in 6:
			var cell := Vector2i(column, row)
			_expect(HexGrid.axial_to_offset(HexGrid.offset_to_axial(cell)) == cell, "offset and axial coordinates round-trip")
			var center := HexGrid.cell_center(cell, Vector2(17, 23), 42.0)
			_expect(HexGrid.pixel_to_cell(center, Vector2(17, 23), 42.0) == cell, "rendered hex centres round-trip through hit testing")
	var probe_cell := Vector2i(8, 9)
	var probe_origin := Vector2(17, 23)
	var probe_center := HexGrid.cell_center(probe_cell, probe_origin, 42.0)
	var probe_polygon := HexGrid.polygon(probe_cell, probe_origin, 42.0)
	for index in 6:
		var near_corner := probe_center.lerp(probe_polygon[index], 0.82)
		var edge_middle := probe_center.lerp(probe_polygon[index].lerp(probe_polygon[(index + 1) % 6], 0.5), 0.92)
		_expect(HexGrid.pixel_to_cell(near_corner, probe_origin, 42.0) == probe_cell, "hit testing keeps points just inside every hex corner in their cell")
		_expect(HexGrid.pixel_to_cell(edge_middle, probe_origin, 42.0) == probe_cell, "hit testing keeps points just inside every hex edge in their cell")


func _test_campaign_files_declare_hex_grid() -> void:
	for path in [
		"res://campaign/battles/01_toll_road.json",
		"res://campaign/battles/02_ashweir_bridge.json",
		"res://campaign/current_battle.json",
	]:
		var loaded := CampaignScenario.load_file(path)
		_expect(bool(loaded.get("ok", false)) and String(loaded.get("data", {}).get("grid", "")) == StrategoGame.GRID_TYPE, "%s declares the hex coordinate system" % path.get_file())
	var current := CampaignScenario.load_file("res://campaign/current_battle.json")
	var game := StrategoGame.new()
	var applied := CampaignScenario.apply(game, current.get("data", {}))
	_expect(bool(applied.get("ok", false)) and game.scenario == StrategoGame.SCENARIO_CAMPAIGN, "the current campaign battle loads on the hex engine")


func _test_minimap_navigation_centres_main_view() -> void:
	var main_view := StrategoBoardView.new()
	main_view.size = Vector2(1000, 800)
	main_view.zoom_level = 2.0
	main_view.center_on_board_point(Vector2(15, 5))
	var main_geometry := main_view._board_geometry()
	var centred_pixel := HexGrid.cell_center(Vector2i(15, 5), main_geometry.origin, float(main_geometry.cell))
	_expect(centred_pixel.is_equal_approx(main_view.size * 0.5), "minimap navigation centres the chosen board point in the main view")

	var minimap_view := StrategoBoardView.new()
	minimap_view.size = Vector2(200, 180)
	minimap_view.overview_target = main_view
	var overview_geometry := minimap_view._overview_geometry()
	var overview_middle := Vector2(overview_geometry.origin) + Vector2(overview_geometry.size) * 0.5
	var expected_middle := HexGrid.pixel_to_cell(overview_middle, overview_geometry.origin, float(overview_geometry.cell))
	_expect(minimap_view._overview_board_point(overview_middle).is_equal_approx(Vector2(expected_middle)), "the minimap centre maps to the battlefield centre")
	var visible_board := minimap_view._overview_viewport_board_rect()
	var focused_unit_point := HexGrid.cell_center(Vector2i(15, 5), Vector2.ZERO, 1.0)
	var unit_board_size := HexGrid.board_pixel_size(1.0, StrategoGame.BOARD_SIZE, StrategoGame.BOARD_SIZE)
	_expect(visible_board.has_point(focused_unit_point) and visible_board.size.x < unit_board_size.x, "the minimap viewport frame tracks the zoomed main view")
	main_view.free()
	minimap_view.free()


func _ready_and_resolve(game: StrategoGame, rolls: Array[int] = []) -> Array[Dictionary]:
	if not rolls.is_empty():
		game.set_forced_rolls(rolls)
	for player in game.active_players.duplicate():
		game.mark_player_ready(player)
	return game.resolve_round()


func _open_reposition(game: StrategoGame, rolls: Array[int] = []) -> Array[Dictionary]:
	if not rolls.is_empty():
		game.set_forced_rolls(rolls)
	for player in game.active_players.duplicate():
		game.mark_player_ready(player)
	return game.resolve_main_and_ranged()


func _ready_and_resolve_reposition(game: StrategoGame, rolls: Array[int] = []) -> Array[Dictionary]:
	if not rolls.is_empty():
		game.set_forced_rolls(rolls)
	for player in game.active_players.duplicate():
		game.mark_player_ready(player)
	return game.resolve_leftover_phase()


func _plan_and_resolve_bot_round(game: StrategoGame, bot: StrategoBotPolicy, planning_rng: RandomNumberGenerator) -> Array[Dictionary]:
	for player in game.active_players.duplicate():
		bot.plan_round(game, player, planning_rng)
		game.mark_player_ready(player)
	var events := game.resolve_main_and_ranged()
	if game.game_over:
		return events
	for player in game.active_players.duplicate():
		bot.plan_leftover(game, player, planning_rng)
		game.mark_player_ready(player)
	events.append_array(game.resolve_leftover_phase())
	return events


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
	_expect(game.total_strength(game.bridge_attacker) == 84 and game.total_strength(game.bridge_defender) == 84, "bridge armies begin at equal 84 current Strength")
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
		_expect(game.count_alive(player) == 13 and game.total_strength(player) == 84, "%s retains the prototype army under WEGO" % game.player_name(player))
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
	var ranged_game := _test_game()
	var archer_id := ranged_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(6, 6))
	ranged_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(12, 12))
	_open_reposition(ranged_game)
	var range_two_shot := ranged_game.set_ranged_order(StrategoGame.RED, archer_id, Vector2i(8, 6))
	_expect(bool(range_two_shot.ok), "Archers accept ranged targets up to two hexes away")
	var beyond_range := ranged_game.set_ranged_order(StrategoGame.RED, archer_id, Vector2i(9, 6))
	_expect(not bool(beyond_range.ok), "Archers cannot declare speculative fire beyond range 2")
	var unseen_shot := ranged_game.set_ranged_order(StrategoGame.RED, archer_id, Vector2i(6, 15))
	_expect(not bool(unseen_shot.ok), "Archers cannot declare a target they cannot see")

	var volley_game := _test_game()
	var volley_archer := volley_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(6, 6))
	volley_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(12, 12))
	var first_step := HexGrid.neighbor(Vector2i(6, 6), HexGrid.SOUTH)
	var second_step := HexGrid.neighbor(first_step, HexGrid.SOUTH)
	var third_step := HexGrid.neighbor(second_step, HexGrid.SOUTH)
	volley_game.set_unit_order(StrategoGame.RED, volley_archer, [first_step, second_step, third_step])
	_open_reposition(volley_game)
	var volley_hex := HexGrid.neighbor(third_step, HexGrid.SOUTH_EAST)
	_expect(bool(volley_game.set_suppress_order(StrategoGame.RED, volley_archer, volley_hex).ok), "an Archer can move its full main distance and then choose an adjacent Volley instead of repositioning")
	var board: StrategoBoardView = load("res://scripts/board_view.gd").new()
	board.game = volley_game
	board.viewing_player = StrategoGame.RED
	board.selected_piece_id = volley_archer
	board.selected_piece_ids.assign([volley_archer])
	_expect(board._selected_archer_can_volley(volley_hex), "right-click recognizes an adjacent empty hex as a Volley target during reposition")
	board.free()


func _test_ranged_combat_reveals_both_parties() -> void:
	# Trading fire identifies both sides, exactly as meeting in melee does.
	# Without it a ranged duel could run a whole match with neither side ever
	# learning what it was shooting at.
	var game := _test_game()
	var shooter := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(5, 5), 10)
	var target := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 4), 10)
	_expect(not game.is_piece_revealed_to(game.pieces[shooter], StrategoGame.BLUE), "the Archer starts unidentified to its target")
	_expect(not game.is_piece_revealed_to(game.pieces[target], StrategoGame.RED), "and the target starts unidentified to the Archer")
	_open_reposition(game)
	game.set_ranged_order(StrategoGame.RED, shooter, Vector2i(5, 4), target)
	var events := _ready_and_resolve_reposition(game, [4])
	_expect(_events_with_action(events, "ranged").size() == 1, "the shot resolves as a ranged event")
	_expect(game.is_piece_revealed_to(game.pieces[shooter], StrategoGame.BLUE), "shooting reveals the Archer to the formation it fired on")
	_expect(game.is_piece_revealed_to(game.pieces[target], StrategoGame.RED), "being shot reveals the target to the Archer that fired")

	# A shot that kills still identifies the shooter, the way a melee that
	# kills still identifies the winner. The witness matters: identity is
	# recorded on the shot but only readable while that player still has
	# someone able to see the Archer, so without a survivor this would pass
	# for the wrong reason.
	var lethal := _test_game()
	var sniper := lethal.add_piece(StrategoGame.HEAVY_ARCHER, StrategoGame.RED, Vector2i(5, 5), 10)
	var victim := lethal.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 4), 1)
	lethal.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(6, 5), 10)
	_open_reposition(lethal)
	lethal.set_ranged_order(StrategoGame.RED, sniper, Vector2i(5, 4), victim)
	_ready_and_resolve_reposition(lethal, [6, 1, 1, 1, 1])
	_expect(not lethal.pieces[victim].alive, "the shot destroys a weak enough target")
	_expect(lethal.is_piece_revealed_to(lethal.pieces[sniper], StrategoGame.BLUE), "a killing shot still gives the Archer away")


func _test_permissive_orders_and_friendly_retry() -> void:
	# Order time cannot know whether a square will still be occupied when the
	# step actually happens: the formation in the way may move off, win its
	# fight and advance, or be killed. Permissive callers are allowed to find
	# out, and the resolver turns a step that does not come off into a bounce.
	var game := _test_game()
	var follower := game.add_piece(StrategoGame.MEDIUM_INFANTRY, StrategoGame.BLUE, Vector2i(5, 6))
	game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5))
	game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	_expect(not bool(game.set_unit_order(StrategoGame.BLUE, follower, [Vector2i(5, 5)], Vector2i(-1, -1), Vector2i(-1, -1), -1, true).get("ok", false)), "a strict caller still refuses a step into a square one of its own holds")
	_expect(bool(game.set_unit_order(StrategoGame.BLUE, follower, [Vector2i(5, 5)], Vector2i(-1, -1), Vector2i(-1, -1), -1, false).get("ok", false)), "a permissive caller may order that step and accept the risk")

	# The whole army marching forward is the case this exists for. The Mediums
	# are penned in behind the Heavies at impulse 2 and must bounce, then take
	# the squares the Heavies vacate at impulse 3.
	var march := StrategoGame.new()
	march.setup_meeting(1234, StrategoGame.BLUE, StrategoGame.RED, StrategoGame.DEFAULT_HOLD_ROUNDS, 20, true)
	var everyone: Array[int] = []
	var before: Dictionary = {}
	for piece: Dictionary in march.pieces:
		if piece.alive and int(piece.player) == StrategoGame.BLUE and march.is_movable(piece):
			everyone.append(int(piece.id))
			before[int(piece.id)] = piece.position
	var ordered := march.append_group_order_step(StrategoGame.BLUE, everyone, HexGrid.NORTH, false)
	_expect(bool(ordered.ok) and int(ordered.count) == everyone.size(), "select-all and march now orders every formation, none skipped")
	for player in march.active_players: march.mark_player_ready(player)
	march.resolve_main_and_ranged()
	var advanced := 0
	for piece_id in everyone:
		if march.pieces[piece_id].position != before[piece_id]: advanced += 1
	_expect(advanced == everyone.size(), "every formation in the column actually advances, the penned-in ones by retrying once the square clears")

	# A formation held up by an ENEMY is repulsed, not queued, and its round ends.
	var enemy_game := _test_game()
	var blocked := enemy_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 6))
	var wall := enemy_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5))
	enemy_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	enemy_game.set_unit_order(StrategoGame.BLUE, blocked, [Vector2i(5, 5)], Vector2i(-1, -1), Vector2i(-1, -1), -1, false)
	for player in enemy_game.active_players: enemy_game.mark_player_ready(player)
	enemy_game.resolve_main_and_ranged()
	_expect(enemy_game.pieces[blocked].position == Vector2i(5, 6) and enemy_game.pieces[wall].position == Vector2i(5, 5), "a formation queueing behind one that never moves simply stays put")

	# Being bumped into must not end the stationary formation's own round: that
	# would let a follower freeze the very formation it is queueing behind.
	var jostle := _test_game()
	var nudger := jostle.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 6))
	var leader := jostle.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5))
	jostle.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	jostle.set_unit_order(StrategoGame.BLUE, nudger, [Vector2i(5, 5)], Vector2i(-1, -1), Vector2i(-1, -1), -1, false)
	jostle.set_unit_order(StrategoGame.BLUE, leader, [Vector2i(5, 4)], Vector2i(-1, -1), Vector2i(-1, -1), -1, false)
	for player in jostle.active_players: jostle.mark_player_ready(player)
	jostle.resolve_main_and_ranged()
	_expect(jostle.pieces[leader].position == Vector2i(5, 4), "a formation bumped into still takes its own later move")
	_expect(jostle.pieces[nudger].position == Vector2i(5, 5), "and the follower takes the square once it is vacated")


func _test_march_animation_staggers_by_weight() -> void:
	# The march exists to make the impulse system visible: Weight decides which
	# impulse a formation starts on, and that timing is why a faster formation
	# cannot follow a slower one into a square it has not vacated. If every
	# formation slid at once the animation would be prettier and say nothing.
	var game := _test_game()
	var light := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 4))
	var heavy := game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(7, 4))
	game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	var view := StrategoBoardView.new()
	view.game = game
	# Both have already arrived; the animation rewinds them and walks forward.
	view.begin_march([
		{"piece_id": light, "impulse": 1, "from": Vector2i(5, 5), "to": Vector2i(5, 4), "bounce": false},
		{"piece_id": heavy, "impulse": 3, "from": Vector2i(7, 5), "to": Vector2i(7, 4), "bounce": false},
	])
	_expect(view.march_in_progress(), "issuing visible movement starts a march")

	var cell := 64.0
	# Halfway through the first beat: the Light is under way, the Heavy has not
	# stirred and so is still drawn a full square back from where it now stands.
	view._march_started_msec = Time.get_ticks_msec() - int(view.MARCH_BEAT_MSEC * 0.5)
	var light_early := view._march_offset(light, cell)
	var heavy_early := view._march_offset(heavy, cell)
	_expect(light_early.length() > 0.0 and light_early.length() < cell, "the faster formation is part way through its step on the first beat")
	_expect(is_equal_approx(heavy_early.y, cell), "the slower formation has not moved yet and is still drawn a whole square behind")

	# A beat later the order reverses: the Light has arrived and holds still
	# while the Heavy makes its move.
	view._march_started_msec = Time.get_ticks_msec() - int(view.MARCH_BEAT_MSEC * 1.5)
	var light_late := view._march_offset(light, cell)
	var heavy_late := view._march_offset(heavy, cell)
	_expect(light_late == Vector2.ZERO, "a formation that has finished its step sits still on later beats")
	_expect(heavy_late.length() > 0.0 and heavy_late.length() < cell, "the slower formation moves on its own later beat")

	# A bounce ends where it began, so it must return to zero rather than leave
	# the formation parked inside the square it was refused.
	var bounce_game := _test_game()
	var refused := bounce_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5))
	bounce_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	var bounce_view := StrategoBoardView.new()
	bounce_view.game = bounce_game
	bounce_view.begin_march([{"piece_id": refused, "impulse": 1, "from": Vector2i(5, 5), "to": Vector2i(5, 4), "bounce": true}])
	bounce_view._march_started_msec = Time.get_ticks_msec() - int(bounce_view.MARCH_BEAT_MSEC * 0.5)
	var lunge := bounce_view._march_offset(refused, cell)
	_expect(lunge.length() > 0.0 and lunge.length() < cell, "a bounced formation visibly lunges at the square it was refused")
	bounce_view._march_started_msec = Time.get_ticks_msec() - int(bounce_view.MARCH_BEAT_MSEC * 0.999)
	_expect(bounce_view._march_offset(refused, cell).length() < cell * 0.02, "the bounced formation returns to its own square by the end of the beat")
	view.free()
	bounce_view.free()


func _test_mixed_speed_formations_can_gang_up() -> void:
	# Sending two formations at one enemy is the whole point of holding melee
	# until the impulses are done. Contact used to resolve where it happened, so
	# a Light that reached the enemy on impulse 1 had already won or died before
	# the Heavy behind it moved at all, and the two could never combine however
	# they were ordered.
	var game := _test_game()
	game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(5, 5), 10)
	var fast := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(4, 5), 10)
	var slow := game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(6, 5), 10)
	_expect(game.first_movement_impulse_for(game.pieces[fast]) != game.first_movement_impulse_for(game.pieces[slow]), "the two attackers really do arrive on different impulses")
	_expect(bool(game.set_unit_order(StrategoGame.BLUE, fast, [Vector2i(5, 5)]).get("ok", false)), "the first attacker may be sent at the enemy square")
	_expect(bool(game.set_unit_order(StrategoGame.BLUE, slow, [Vector2i(5, 5)]).get("ok", false)), "a slower formation may be committed against the same enemy square as a faster one")

	# Two formations converging on an EMPTY square is still an ordinary
	# collision and must stay refused; the exception is about attacking.
	var empty_game := _test_game()
	var one := empty_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(4, 5), 10)
	var two := empty_game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(6, 5), 10)
	empty_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18), 10)
	empty_game.set_unit_order(StrategoGame.BLUE, one, [Vector2i(5, 5)])
	_expect(not bool(empty_game.set_unit_order(StrategoGame.BLUE, two, [Vector2i(5, 5)]).get("ok", false)), "two formations still may not be ordered onto the same empty square")

	# Both waves land in one fight now, whatever impulse each of them arrived on.
	# The Light makes contact on impulse 1 and the Heavy only moves on impulse 3,
	# and nothing is rolled until both are standing there.
	var ganged := _test_game()
	var defender := ganged.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(5, 5), 3)
	var early := ganged.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(4, 5), 10)
	var late := ganged.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(6, 5), 10)
	ganged.set_unit_order(StrategoGame.BLUE, early, [Vector2i(5, 5)])
	ganged.set_unit_order(StrategoGame.BLUE, late, [Vector2i(5, 5)])
	# Blue rolls four: two formations, stronger, and uniquely heaviest. Red rolls
	# two: one formation, braced, having held the hex since before the round.
	ganged.set_forced_rolls([1, 1, 1, 5, 2, 2])
	for player in ganged.active_players: ganged.mark_player_ready(player)
	var ganged_events := ganged.resolve_main_and_ranged()
	var melees := _events_with_action(ganged_events, "melee")
	_expect(melees.size() == 1, "formations arriving on different impulses fight one battle, not one each")
	_expect(int(melees[0].participants.size()) == 3 and early in melees[0].participants and late in melees[0].participants, "the slower ally is a participant in it rather than a second wave")
	_expect(int(melees[0].bonus_dice[early]) == 2 and int(melees[0].scores[early]) == 15, "the side rolls a die per formation on top of its comparative dice")
	_expect(int(melees[0].scores[defender]) == 5 and not ganged.pieces[defender].alive, "and the defender faces the pair at once instead of beating them one at a time")
	_expect(ganged.pieces[early].position == Vector2i(5, 5), "the formation that reached the hex first has first claim on it")
	_expect(ganged.pieces[late].position == Vector2i(6, 5) and ganged.pieces[late].round_status == StrategoGame.STATUS_READY, "the ally that could not stack on it comes home without a penalty")


func _test_group_orders_apply_per_formation() -> void:
	var game := _test_game()
	var rear_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 6))
	var front_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5))
	game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	var advance := game.append_group_order_step(StrategoGame.BLUE, [rear_id, front_id], HexGrid.NORTH)
	_expect(bool(advance.ok), "a selected formation line can receive one atomic shared movement order")
	_expect(game.projected_order_position(rear_id, 1) == HexGrid.neighbor(Vector2i(5, 6), HexGrid.NORTH) and game.projected_order_position(front_id, 1) == HexGrid.neighbor(Vector2i(5, 5), HexGrid.NORTH), "group movement preserves formation spacing while advancing")
	var mixed_game := _test_game()
	var heavy_id := mixed_game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(8, 6))
	var light_id := mixed_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(10, 6))
	mixed_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	mixed_game.append_group_order_step(StrategoGame.BLUE, [heavy_id, light_id], HexGrid.NORTH)
	var second_advance := mixed_game.append_group_order_step(StrategoGame.BLUE, [heavy_id, light_id], HexGrid.NORTH)
	_expect(bool(second_advance.ok) and int(second_advance.count) == 1 and int(second_advance.skipped) == 1, "group movement skips formations whose movement allowance is exhausted")
	_expect(mixed_game.order_for_piece(heavy_id).path.size() == 1 and mixed_game.order_for_piece(light_id).path.size() == 2, "faster selected formations continue after slower formations stop")
	var edge_game := _test_game()
	var edge_id := edge_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(2, 0))
	var safe_id := edge_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(3, 2))
	edge_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	var partial := edge_game.append_group_order_step(StrategoGame.BLUE, [edge_id, safe_id], HexGrid.NORTH)
	_expect(bool(partial.ok) and int(partial.count) == 1 and int(partial.skipped) == 1, "a formation that can take the step still receives it even when another selected formation cannot")
	_expect(edge_game.order_for_piece(edge_id).is_empty(), "the formation that would walk off the map is skipped, not given a broken order")
	_expect(edge_game.projected_main_destination(safe_id) == HexGrid.neighbor(Vector2i(3, 2), HexGrid.NORTH), "a formation blocked by no one else's failure still advances")

	# Select-all on a real deployment and march. Every formation with clear
	# space ahead must get its order; only the ones sitting directly behind a
	# slower formation are genuinely blocked. This regressed twice: the
	# collision check answers for the player's whole plan rather than for one
	# formation, so attributing a failure to any particular unit by proxy
	# (the fastest, say) silently threw out marches that had nothing to do
	# with the conflict, leaving only the heavies.
	var march := StrategoGame.new()
	march.setup_meeting(1234, StrategoGame.BLUE, StrategoGame.RED, StrategoGame.DEFAULT_HOLD_ROUNDS, 20, true)
	var everyone: Array[int] = []
	for piece: Dictionary in march.pieces:
		if piece.alive and int(piece.player) == StrategoGame.BLUE and march.is_movable(piece):
			everyone.append(int(piece.id))
	var march_result := march.append_group_order_step(StrategoGame.BLUE, everyone, HexGrid.NORTH)
	var stuck: Array[int] = []
	var moving: Array[int] = []
	for piece_id in everyone:
		var ahead := march.piece_at(HexGrid.neighbor(march.pieces[piece_id].position, HexGrid.NORTH))
		if march.order_for_piece(piece_id).is_empty(): stuck.append(piece_id)
		else: moving.append(piece_id)
		# The real invariant: an empty square ahead means nothing could have
		# blocked it, so it must have been ordered.
		if ahead.is_empty():
			_expect(not march.order_for_piece(piece_id).is_empty(), "a formation with an empty square ahead of it receives the group march order")
	_expect(bool(march_result.ok) and not moving.is_empty(), "select-all and march orders every formation with a legal, collision-free hex ahead")

	# The Flag cannot move, and neither can a formation ground down to no
	# Strength, but both are ordinary things to have inside a drag-selection.
	# Rejecting the whole order over one of them made a group containing one
	# silently do nothing, on the arrow keys and on click alike, since both
	# routes come through here.
	var flag_game := _test_game()
	var marcher := flag_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5))
	var standard := flag_game.add_piece(StrategoGame.FLAG, StrategoGame.BLUE, Vector2i(6, 5))
	flag_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	var with_flag := flag_game.append_group_order_step(StrategoGame.BLUE, [marcher, standard], HexGrid.NORTH)
	_expect(bool(with_flag.ok) and int(with_flag.count) == 1 and int(with_flag.skipped) == 1, "a selection containing the Flag still orders everything in it that can move")
	_expect(flag_game.projected_main_destination(marcher) == Vector2i(5, 4), "the movable formation in that selection actually advances")
	_expect(flag_game.order_for_piece(standard).is_empty(), "the Flag itself receives no order")

	var spent_game := _test_game()
	var healthy := spent_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5))
	var wiped := spent_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(7, 5))
	spent_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	spent_game.pieces[wiped].strength = 0
	var with_spent := spent_game.append_group_order_step(StrategoGame.BLUE, [healthy, wiped], HexGrid.NORTH)
	_expect(bool(with_spent.ok) and int(with_spent.count) == 1, "a formation with no Strength left is skipped rather than cancelling the group order")

	# Still a hard error: whose formation it is stays a caller mistake, not a
	# fact about the battle to be worked around.
	var enemy_game := _test_game()
	var own := enemy_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5))
	var foreign := enemy_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(9, 9))
	var mixed := enemy_game.append_group_order_step(StrategoGame.BLUE, [own, foreign], HexGrid.NORTH)
	_expect(not bool(mixed.ok) and enemy_game.order_for_piece(own).is_empty(), "a selection containing another player's formation is still refused outright")

	var collision_game := _test_game()
	var blocking_heavy := collision_game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5))
	var following_medium := collision_game.add_piece(StrategoGame.MEDIUM_INFANTRY, StrategoGame.BLUE, HexGrid.neighbor(Vector2i(5, 5), HexGrid.SOUTH))
	collision_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	# Heavy moves once, in the round's final impulse; Medium moves twice,
	# starting one impulse earlier. Ordering both forward together asks
	# Medium to step into Heavy's square before Heavy has actually vacated it
	# - a genuine timing conflict, not something either formation did wrong -
	# so Medium's step alone should be the one that does not go through.
	var blocked := collision_game.append_group_order_step(StrategoGame.BLUE, [blocking_heavy, following_medium], HexGrid.NORTH)
	_expect(bool(blocked.ok) and int(blocked.count) == 1 and int(blocked.skipped) == 1, "a formation blocked by another selected formation's timing does not cancel that formation's own valid move")
	_expect(collision_game.projected_main_destination(blocking_heavy) == Vector2i(5, 4), "the unblocked formation in the pair still gets its order")
	_expect(collision_game.order_for_piece(following_medium).is_empty(), "the formation that cannot yet make the step is the one left without an order")


func _test_planning_order_undo() -> void:
	var game := _test_game()
	var mover_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5))
	game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	var board_view := StrategoBoardView.new()
	root.add_child(board_view)
	board_view.set_game(game)
	board_view.selected_piece_ids.assign([mover_id])
	board_view.selected_piece_id = mover_id
	board_view.issue_selected_direction(HexGrid.NORTH)
	_expect(board_view.can_undo_order(), "issuing an order enables planning-phase undo")
	board_view.undo_last_order()
	_expect(game.order_for_piece(mover_id).is_empty(), "undo restores the formation's previous order state")
	board_view.issue_selected_direction(HexGrid.NORTH)
	board_view.clear_all_orders()
	board_view.undo_last_order()
	_expect(game.order_for_piece(mover_id).path == [HexGrid.neighbor(Vector2i(5, 5), HexGrid.NORTH)], "clear orders can be undone before planning ends")
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
	win_game.set_forced_rolls([5, 1, 1])
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
	_expect(not bool(game.pieces[red_id].participated_in_combat) and game.pieces[red_id].round_status == StrategoGame.STATUS_READY, "non-combat congestion carries no bounce-status penalty")
	var stationary_game := _test_game()
	var moving_id := stationary_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(1, 1), 8)
	var stationary_id := stationary_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.GREEN, Vector2i(2, 1), 8)
	stationary_game.set_player_team(StrategoGame.RED, 4)
	stationary_game.set_player_team(StrategoGame.GREEN, 4)
	stationary_game.set_unit_order(StrategoGame.RED, moving_id, [Vector2i(2, 1)])
	_ready_and_resolve(stationary_game)
	_expect(stationary_game.pieces[moving_id].round_status == StrategoGame.STATUS_READY and stationary_game.pieces[stationary_id].round_status == StrategoGame.STATUS_READY, "neither the mover nor stationary ally receives a round-status penalty")


func _test_follower_advances_into_a_vacated_attack_square() -> void:
	# A formation committing to a fight has left the square behind it, so the
	# ally queued there advances into it on the same impulse instead of bouncing.
	# The attacker is added first on purpose: the squares used to be classified
	# in piece id order against a set that the classification itself was filling
	# in, so an attacker one hex ahead read as stationary to its own follower.
	# Heavies make the cost unmissable. They move only on impulse 3, so a
	# spurious bounce there is not something they can retry, and the advance is
	# lost for the round rather than merely delayed.
	var game := _test_game()
	var enemy_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(1, 2), 1)
	var attacker_id := game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.RED, Vector2i(2, 2), 10)
	var follower_id := game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.RED, Vector2i(3, 2), 10)
	_expect(attacker_id < follower_id, "the follower is created second, which is the order that reproduced the bug")
	game.set_unit_order(StrategoGame.RED, attacker_id, [Vector2i(1, 2)])
	game.set_unit_order(StrategoGame.RED, follower_id, [Vector2i(2, 2)])
	var events := _ready_and_resolve(game)
	_expect(_events_with_action(events, "bounce").is_empty(), "following an ally into its fight is not friendly congestion")
	_expect(game.pieces[attacker_id].position == Vector2i(1, 2), "the attacker takes the square it won")
	_expect(game.pieces[follower_id].position == Vector2i(2, 2), "the follower advances into the square the attacker vacated")
	_expect(not game.pieces[enemy_id].alive, "the overmatched defender is destroyed")
	# The same line one weight class faster: the follower used to get there
	# anyway by bouncing on impulse 1 and retrying on 2, so the tell is the
	# wasted step rather than the lost square.
	var light_game := _test_game()
	light_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(1, 2), 1)
	var light_attacker := light_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(2, 2), 10)
	var light_follower := light_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(3, 2), 10)
	light_game.set_unit_order(StrategoGame.RED, light_attacker, [Vector2i(1, 2)])
	light_game.set_unit_order(StrategoGame.RED, light_follower, [Vector2i(2, 2)])
	_ready_and_resolve(light_game)
	_expect(light_game.pieces[light_follower].position == Vector2i(2, 2), "a faster follower reaches the same square")
	_expect(int(light_game.pieces[light_follower].movement_used) == 1, "and pays one step for it rather than two")


func _test_support_is_offered_on_a_friendly_formation() -> void:
	# The menu entry exists because walking into an ally does not read as an
	# order. What it offers has to match what the engine will actually accept.
	var game := _test_game()
	var holder := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5), 10)
	var neighbour := game.add_piece(StrategoGame.MEDIUM_INFANTRY, StrategoGame.BLUE, Vector2i(6, 5), 10)
	var distant := game.add_piece(StrategoGame.MEDIUM_INFANTRY, StrategoGame.BLUE, Vector2i(1, 1), 10)
	var enemy := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(4, 5), 10)
	var view: StrategoBoardView = load("res://scripts/board_view.gd").new()
	view.set_game(game)
	view.viewing_player = StrategoGame.BLUE
	view.selected_piece_ids.assign([neighbour])
	_expect(view.support_candidates_for(Vector2i(5, 5)) == [neighbour], "an adjacent selected formation is offered as support")
	_expect(view.support_candidates_for(Vector2i(4, 5)).is_empty(), "support is never offered onto an enemy")
	_expect(view.support_candidates_for(Vector2i(9, 9)).is_empty(), "or onto empty ground")
	view.selected_piece_ids.assign([distant])
	_expect(view.support_candidates_for(Vector2i(5, 5)).is_empty(), "a formation that cannot reach the hex is not offered")
	view.selected_piece_ids.assign([holder])
	_expect(view.support_candidates_for(Vector2i(5, 5)).is_empty(), "and a formation is never offered as support for itself")
	view.free()
	_expect(enemy >= 0, "the enemy stands where support must not be offered")


func _test_reinforcing_a_defender_joins_its_fight() -> void:
	# Walking into a friendly hex that has a fight open on it is support, not
	# congestion. The Light attacks on impulse 1 and the Medium relief only moves
	# on impulse 2, so this needs the fight to still be open when it gets there.
	var game := _test_game()
	var holder := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5), 10)
	var attacker := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(4, 5), 10)
	var relief := game.add_piece(StrategoGame.MEDIUM_INFANTRY, StrategoGame.BLUE, Vector2i(6, 5), 10)
	game.set_unit_order(StrategoGame.RED, attacker, [Vector2i(5, 5)])
	_expect(not bool(game.set_unit_order(StrategoGame.BLUE, relief, [Vector2i(5, 5)]).get("ok", false)), "walking into your own line by accident is still refused")
	_expect(bool(game.set_support_order(StrategoGame.BLUE, relief, Vector2i(5, 5)).get("ok", false)), "asking for support explicitly is allowed")
	# Red rolls two: one formation, charging. Blue rolls four: two formations, the
	# uniquely heaviest, and one braced Infantry. Only the holder is braced; the
	# relief arrived after the enemy did, so it brings a die but no defence die.
	var events := _ready_and_resolve(game, [3, 3, 1, 1, 1, 5])
	var melees := _events_with_action(events, "melee")
	_expect(melees.size() == 1 and relief in melees[0].participants, "a formation moving onto a defended hex joins the fight instead of bouncing")
	_expect(_events_with_action(events, "bounce").is_empty(), "and it is not treated as friendly congestion on the way in")
	_expect(int(melees[0].bonus_dice[holder]) == 2 and int(melees[0].scores[holder]) == 15, "the relief adds its die and its Weight to the side without adding a second defence die")
	_expect(int(melees[0].damage[attacker]) == 2, "the attacker faces the pair rather than the formation it set out to fight")
	_expect(game.pieces[holder].position == Vector2i(5, 5), "the formation that held the hex keeps it")
	_expect(game.pieces[relief].position == Vector2i(6, 5), "and the relief that could not stack on it returns")


func _test_bracing_is_earned_by_arriving_first() -> void:
	# Pins the rule the deferred melee pass will lean on, ahead of that pass
	# existing. Today's flow can only produce arrivals of 0 and one impulse at a
	# time, so the staggered cases below are unreachable through orders alone.
	var game := _test_game()
	var holder := game.add_piece(StrategoGame.MEDIUM_INFANTRY, StrategoGame.BLUE, Vector2i(2, 2), 7)
	var ally := game.add_piece(StrategoGame.MEDIUM_INFANTRY, StrategoGame.BLUE, Vector2i(3, 2), 7)
	var enemy := game.add_piece(StrategoGame.MEDIUM_CAVALRY, StrategoGame.RED, Vector2i(1, 2), 7)
	var standing: Array = [{"piece_id": holder, "arrival": 0}, {"piece_id": enemy, "arrival": 3}]
	_expect(game._is_defending(holder, standing), "a formation already on the hex is braced against anything that moves in")
	_expect(not game._is_defending(enemy, standing), "and whatever moved in is attacking")
	var staggered: Array = [{"piece_id": ally, "arrival": 2}, {"piece_id": enemy, "arrival": 3}]
	_expect(game._is_defending(ally, staggered), "reaching contested ground first is what braces you, not standing still")
	_expect(not game._is_defending(enemy, staggered), "the slower formation attacks into it")
	var simultaneous: Array = [{"piece_id": ally, "arrival": 3}, {"piece_id": enemy, "arrival": 3}]
	_expect(not game._is_defending(ally, simultaneous) and not game._is_defending(enemy, simultaneous), "enemies landing on the same impulse leave neither of them set")
	var together: Array = [{"piece_id": holder, "arrival": 2}, {"piece_id": ally, "arrival": 2}, {"piece_id": enemy, "arrival": 3}]
	_expect(game._is_defending(holder, together) and game._is_defending(ally, together), "allies that arrive together are both braced, since the race is against the enemy")
	var reinforced: Array = [{"piece_id": holder, "arrival": 0}, {"piece_id": ally, "arrival": 3}, {"piece_id": enemy, "arrival": 3}]
	_expect(game._is_defending(holder, reinforced), "the formation that held the hex stays braced")
	_expect(not game._is_defending(ally, reinforced), "a reinforcement that arrives with the enemy is attacking, not bracing")


func _test_bounced_attacker_survives_a_filled_origin() -> void:
	# The follower fills the square the attacker stepped out of, and then the
	# attack ties, so the attacker is sent back to a hex it no longer owns.
	var game := _test_game()
	game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(1, 2), 10)
	var attacker_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(2, 2), 10)
	var follower_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(3, 2), 10)
	game.set_unit_order(StrategoGame.RED, attacker_id, [Vector2i(1, 2)])
	game.set_unit_order(StrategoGame.RED, follower_id, [Vector2i(2, 2)])
	_ready_and_resolve(game, [2, 2])
	_expect(game.pieces[follower_id].position == Vector2i(2, 2), "the follower holds the square it advanced into")
	_expect(game.pieces[attacker_id].alive, "a tied attacker is not destroyed by its own follower taking its square")
	_expect(game.pieces[attacker_id].position == Vector2i(3, 1), "it falls back to the neighbour most directly away from the contested square")


func _test_crossing_battle_both_attack() -> void:
	var game := _test_game()
	var red_id := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(1, 1), 10)
	var blue_id := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.BLUE, Vector2i(2, 1), 10)
	game.set_unit_order(StrategoGame.RED, red_id, [Vector2i(2, 1)])
	game.set_unit_order(StrategoGame.BLUE, blue_id, [Vector2i(1, 1)])
	var events := _ready_and_resolve(game, [4, 4, 4, 4])
	var battles := _events_with_action(events, "crossing_battle")
	_expect(battles.size() == 1 and int(battles[0].bonus_dice[red_id]) == 1 and int(battles[0].bonus_dice[blue_id]) == 1, "crossing enemies both receive Cavalry's attacking die")
	_expect(int(battles[0].scores[red_id]) == 14 and int(battles[0].scores[blue_id]) == 14, "score is the kept die plus Strength on both sides")
	_expect(game.pieces[red_id].position == Vector2i(1, 1) and game.pieces[blue_id].position == Vector2i(2, 1), "a crossing-path tie bounces both units to their previous squares")
	var crossing_profile := {"strength": 10, "role": StrategoGame.ROLE_INFANTRY, "weight": StrategoGame.WEIGHT_LIGHT}
	var infantry_result := game.calculate_melee(crossing_profile.duplicate(), crossing_profile.duplicate(), [4], [5], true)
	_expect(int(infantry_result.defender_bonus_dice) == 0, "crossing-path Infantry receives no defense die")
	_expect(int(infantry_result.attacker_score) == 14 and int(infantry_result.defender_score) == 15, "both sides simply add Strength to the die they kept")


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


func _test_defender_wins_ties_toggle() -> void:
	# Off by default, so the existing bounce behaviour is untouched unless a
	# caller explicitly opts in.
	var off_game := _test_game()
	var off_attacker := off_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 10)
	off_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	off_game.set_unit_order(StrategoGame.RED, off_attacker, [Vector2i(2, 1)])
	var off_events := _ready_and_resolve(off_game, [2, 2])
	_expect(_events_with_action(off_events, "melee")[0].result == "bounce", "the toggle defaults off - a tie still bounces without it")

	# On: the exact same tie now resolves to the defender.
	var on_game := _test_game()
	var on_game_attacker := on_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 10)
	var on_game_defender := on_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	on_game.defender_wins_ties = true
	on_game.set_unit_order(StrategoGame.RED, on_game_attacker, [Vector2i(2, 1)])
	var on_events := _ready_and_resolve(on_game, [2, 2])
	var on_battle := _events_with_action(on_events, "melee")[0]
	_expect(on_battle.result == "win" and int(on_battle.winner_id) == on_game_defender, "with the toggle on, a tie resolves to the defender rather than bouncing")
	_expect(on_game.pieces[on_game_defender].position == Vector2i(2, 1) and String(on_game.pieces[on_game_defender].round_status) == StrategoGame.STATUS_WON, "the defender is treated as an ordinary winner: holds the square, marked won")
	# The toggle awards the ground, not a wound. Damage is the score margin,
	# and the margin the two of them fought to is zero by definition of a tie.
	_expect(on_game.pieces[on_game_attacker].alive and int(on_game.pieces[on_game_attacker].strength) == 10, "a tie-break win takes the square without drawing blood, because the margin is zero")

	# A genuine three-way tie is still ambiguous even with the toggle on: two
	# attackers tying each other, with the defender not part of the top score
	# at all, has no defender among the tied formations to award it to.
	var messy_game := _test_game()
	messy_game.defender_wins_ties = true
	var first_attacker := messy_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 10)
	var second_attacker := messy_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.GREEN, Vector2i(3, 1), 10)
	var messy_defender := messy_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	messy_game.set_unit_order(StrategoGame.RED, first_attacker, [Vector2i(2, 1)])
	messy_game.set_unit_order(StrategoGame.GREEN, second_attacker, [Vector2i(2, 1)])
	var messy_events := _ready_and_resolve(messy_game, [6, 6, 1])
	_expect(_events_with_action(messy_events, "melee")[0].result == "bounce", "two attackers tying each other still bounces - the rule only awards a tie the defender is actually part of")
	_expect(messy_game.pieces[first_attacker].round_status == StrategoGame.STATUS_BOUNCED and messy_game.pieces[second_attacker].round_status == StrategoGame.STATUS_BOUNCED and messy_game.pieces[messy_defender].round_status == StrategoGame.STATUS_BOUNCED, "an opposing top-score tie penalizes every surviving participant because no side won")


## The three melee bonus dice, and the fact that two of them are comparisons
## rather than tiers: an equal opponent grants neither one.
func _test_comparative_bonus_dice() -> void:
	var game := _test_game()
	var heavy_charger := {"strength": 9, "role": StrategoGame.ROLE_CAVALRY, "weight": StrategoGame.WEIGHT_HEAVY}
	var light_quarry := {"strength": 4, "role": StrategoGame.ROLE_ARCHER, "weight": StrategoGame.WEIGHT_LIGHT}
	var stacked := game.calculate_melee(heavy_charger, light_quarry, [1, 1, 1, 1], [1])
	_expect(int(stacked.attacker_bonus_dice) == 3, "heavier, stronger and charging Cavalry stack into three bonus dice")
	_expect(int(stacked.defender_bonus_dice) == 0, "the lighter, weaker Archer earns none of them")

	var mirror := {"strength": 8, "role": StrategoGame.ROLE_INFANTRY, "weight": StrategoGame.WEIGHT_HEAVY}
	var mirrored := game.calculate_melee(mirror.duplicate(), mirror.duplicate(), [1], [1, 1])
	_expect(int(mirrored.attacker_bonus_dice) == 0, "two identical Heavies grant each other no weight die and no Strength die")
	_expect(int(mirrored.defender_bonus_dice) == 1, "only the defending Infantry's role die is left")

	# Strength is two things at once now: the number added to the die, and a
	# comparative die of its own. A formation damaged below its enemy loses
	# both in the same moment, which is what makes chip damage compound.
	var healthy := {"strength": 7, "role": StrategoGame.ROLE_INFANTRY, "weight": StrategoGame.WEIGHT_MEDIUM}
	var wounded := {"strength": 6, "role": StrategoGame.ROLE_INFANTRY, "weight": StrategoGame.WEIGHT_MEDIUM}
	_expect(int(game.calculate_melee(wounded, healthy, [1], [1, 1, 1]).attacker_bonus_dice) == 0, "dropping below the enemy's Strength costs the Strength die as well as the score")
	_expect(int(game.calculate_melee(healthy, wounded, [1, 1], [1, 1]).attacker_bonus_dice) == 1, "and the enemy picks it up in the same moment")


## Every 6 is a point of damage, but only the ones the other side did not match:
## 6s cancel across the two sides one for one, and never within a side.
func _test_crit_sixes_cancel_across_sides() -> void:
	var game := _test_game()
	var charger := {"strength": 8, "role": StrategoGame.ROLE_CAVALRY, "weight": StrategoGame.WEIGHT_LIGHT}
	var weaker := {"strength": 5, "role": StrategoGame.ROLE_INFANTRY, "weight": StrategoGame.WEIGHT_LIGHT}
	var clean := game.calculate_melee(charger, weaker, [6, 1, 1], [3, 1])
	_expect(int(clean.defender_damage) == 7, "an uncancelled 6 adds a point on top of the score margin")
	var cancelled := game.calculate_melee(charger, weaker, [6, 1, 1], [6, 1])
	_expect(int(cancelled.defender_damage) == 3, "the defender's own 6 cancels it, leaving the bare margin")
	var doubled := game.calculate_melee(charger, weaker, [6, 6, 1], [6, 1])
	_expect(int(doubled.defender_damage) == 4, "6s cancel one for one, so a second attacking 6 still lands")

	# The margin is the loser's bill, but a 6 is not: it lands whatever the
	# scores did. A draw costs nobody the margin and still lets a crit through.
	var braced := {"strength": 12, "role": StrategoGame.ROLE_INFANTRY, "weight": StrategoGame.WEIGHT_LIGHT}
	var drawn := game.calculate_melee(charger, braced, [6, 1], [2, 1, 1])
	_expect(bool(drawn.tie) and int(drawn.defender_damage) == 1, "an uncancelled 6 still draws blood on a draw, where the margin buys nothing")
	_expect(int(drawn.attacker_damage) == 0, "and the side that did not roll one takes nothing at all")
	# Equal Strength, because a 6 is the top of the die: two sides can only
	# both keep a 6 and still tie if their Strengths already matched.
	var even_match := {"strength": 8, "role": StrategoGame.ROLE_INFANTRY, "weight": StrategoGame.WEIGHT_LIGHT}
	var drawn_even := game.calculate_melee(charger, even_match, [6, 1], [6, 1])
	_expect(bool(drawn_even.tie) and int(drawn_even.defender_damage) == 0 and int(drawn_even.attacker_damage) == 0, "a 6 each on a draw cancels, and a tie with nothing left over is still free")

	# The point of letting crits land on a loss: something being overrun can
	# still take a piece out of whatever is killing it.
	var overrun := {"strength": 4, "role": StrategoGame.ROLE_INFANTRY, "weight": StrategoGame.WEIGHT_LIGHT}
	var overwhelming := {"strength": 11, "role": StrategoGame.ROLE_CAVALRY, "weight": StrategoGame.WEIGHT_HEAVY}
	var last_stand := game.calculate_melee(overwhelming, overrun, [3, 1, 1, 1], [6, 1])
	_expect(bool(last_stand.attacker_wins), "the heavier, stronger charge still wins the square comfortably")
	_expect(int(last_stand.attacker_damage) == 1, "and still pays a point for it, because the loser rolled a 6 it could not match")


func _test_multiway_unique_winner() -> void:
	var game := _test_game()
	var first_id := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(1, 2), 10)
	var second_id := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(2, 3), 10)
	var defender_id := game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(2, 2), 10)
	game.set_unit_order(StrategoGame.RED, first_id, [Vector2i(2, 2)])
	var second_order := game.set_unit_order(StrategoGame.RED, second_id, [Vector2i(2, 2)])
	_expect(bool(second_order.ok), "multiple same-player attackers may converge on a known enemy for a multiway battle")
	var events := _ready_and_resolve(game, [6, 1, 3, 1, 2, 1, 1])
	var battle := _events_with_action(events, "melee")[0]
	_expect(int(battle.winner_id) == first_id, "a unique highest scorer wins a multiway contested square")
	# Blue's lone Heavy is uniquely heaviest and braced, so a weight die and a
	# defence die on top of its one formation die. Red brings two formations and
	# two charging Cavalry, and earns nothing comparative against equal Strength
	# or a heavier enemy, so both sides sit two dice above their base.
	_expect(int(battle.bonus_dice[defender_id]) == 2 and int(battle.bonus_dice[first_id]) == 2, "each side earns its comparative dice against the whole of the other")
	_expect(game.pieces[first_id].position == Vector2i(2, 2), "unique friendly leader occupies the contested square")
	_expect(game.pieces[second_id].position == Vector2i(2, 3) and game.pieces[second_id].round_status == StrategoGame.STATUS_READY, "friendly non-winning attacker returns without a bounce-status penalty")
	_expect(StrategoGame.are_adjacent(Vector2i(2, 2), game.pieces[defender_id].position) and game.pieces[defender_id].position != Vector2i(2, 2) and game.pieces[defender_id].round_status == StrategoGame.STATUS_LOST, "opposing multiway loser retreats")
	var support_game := _test_game()
	var leader := support_game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(1, 2), 10)
	var support := support_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(2, 3), 10)
	support_game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(2, 2), 10)
	support_game.set_unit_order(StrategoGame.RED, leader, [Vector2i(2, 2)])
	support_game.set_unit_order(StrategoGame.RED, support, [Vector2i(2, 2)])
	support_game.set_forced_rolls([6, 1, 3, 2, 1, 1])
	for player in support_game.active_players: support_game.mark_player_ready(player)
	support_game.resolve_main_and_ranged()
	_expect(support_game.pieces[support].round_status == StrategoGame.STATUS_READY and support_game.can_receive_leftover_order(StrategoGame.RED, support), "a friendly combat return remains eligible for its post-clash action")


func _test_side_numbers_pay_in_dice_not_strength() -> void:
	# Two formations roll two dice and keep the better of them, but the side still
	# scores off its leader's Strength alone. Stacking Strength as well would make
	# the margin the difference in total health, swamp the dice, and let any local
	# advantage delete a healthy formation on contact.
	var game := _test_game()
	var first_id := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(1, 2), 10)
	var second_id := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(2, 3), 10)
	var defender_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(2, 2), 10)
	game.set_unit_order(StrategoGame.RED, first_id, [Vector2i(2, 2)])
	game.set_unit_order(StrategoGame.RED, second_id, [Vector2i(2, 2)])
	# Red rolls four: two formations and two attacking Cavalry, with no
	# comparative die against an equal. Blue rolls two: one formation, braced.
	var events := _ready_and_resolve(game, [3, 5, 4, 1, 4, 4])
	var battle := _events_with_action(events, "melee")[0]
	_expect(int(battle.scores[first_id]) == 15 and int(battle.scores[second_id]) == 15, "both formations on a side share the side's single score")
	_expect(int(battle.scores[defender_id]) == 14, "and a side of one scores exactly what a lone formation always did")
	_expect(int(battle.damage[defender_id]) == 1, "the loser pays the margin between two sides, not the sum of what faced it")
	_expect(game.pieces[first_id].position == Vector2i(2, 2), "the leading claimant takes the contested hex")
	_expect(game.pieces[second_id].position == Vector2i(2, 3) and game.pieces[second_id].round_status == StrategoGame.STATUS_READY, "the formation that could not stack on it comes home without a penalty")


func _test_losing_side_shares_one_margin() -> void:
	# Three formations converging on one empty hex, two of them allied. Every
	# formation on the losing side pays the same margin, so there is nothing to
	# track about which of them rolled what.
	var game := _test_game()
	var attacker_id := game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(1, 2), 10)
	var weak_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(2, 3), 4)
	var strong_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.GREEN, Vector2i(3, 2), 8)
	game.set_player_team(StrategoGame.BLUE, 7)
	game.set_player_team(StrategoGame.GREEN, 7)
	game.set_unit_order(StrategoGame.RED, attacker_id, [Vector2i(2, 2)])
	game.set_unit_order(StrategoGame.BLUE, weak_id, [Vector2i(2, 2)])
	game.set_unit_order(StrategoGame.GREEN, strong_id, [Vector2i(2, 2)])
	# All three are Light so they land on the same impulse and share one fight.
	# Red rolls three: one formation, stronger, and charging. The allies roll two,
	# one per formation, braced by nobody because nothing got there first.
	var events := _ready_and_resolve(game, [1, 1, 2, 3, 3])
	var battle := _events_with_action(events, "melee")[0]
	_expect(int(battle.scores[weak_id]) == 11 and int(battle.scores[strong_id]) == 11, "the side scores off its strongest formation, whichever one rolled")
	_expect(int(battle.damage[weak_id]) == 1 and int(battle.damage[strong_id]) == 1, "every formation on the losing side pays the same margin")
	_expect(int(game.pieces[weak_id].strength) == 3 and int(game.pieces[strong_id].strength) == 7, "and pays it out of its own Strength")
	_expect(game.pieces[attacker_id].position == Vector2i(2, 2), "the winning side takes the hex it was ordered onto")


func _test_multiway_damage_uses_highest_opponent() -> void:
	var game := _test_game()
	var red_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 2), 10)
	var blue_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(3, 2), 10)
	var green_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.GREEN, Vector2i(2, 3), 10)
	game.set_unit_order(StrategoGame.RED, red_id, [Vector2i(2, 2)])
	game.set_unit_order(StrategoGame.BLUE, blue_id, [Vector2i(2, 2)])
	game.set_unit_order(StrategoGame.GREEN, green_id, [Vector2i(2, 2)])
	var events := _ready_and_resolve(game, [5, 4, 3])
	var battle := _events_with_action(events, "melee")[0]
	# Asserted as a relationship rather than three literals, so the check does
	# not quietly encode which of the three identical Archers rolled first.
	var top_score := 0
	for id_value in battle.participants: top_score = maxi(top_score, int(battle.scores[int(id_value)]))
	var margin_only := true
	var total_damage := 0
	for id_value in battle.participants:
		var id := int(id_value)
		if int(battle.damage[id]) != maxi(0, top_score - int(battle.scores[id])): margin_only = false
		total_damage += int(battle.damage[id])
	_expect(margin_only, "multiway damage is the gap to the highest opposing score, never the sum of every opponent")
	_expect(total_damage == 3, "scores of 15/14/13 cost the field three points between them, not one beating each")
	_expect(int(game.pieces[red_id].strength) == 10 or int(game.pieces[blue_id].strength) == 10 or int(game.pieces[green_id].strength) == 10, "whoever topped the square took nothing at all")


func _test_ranged_focus_fire_is_simultaneous() -> void:
	var game := _test_game()
	var first_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 2), 5)
	var second_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(2, 1), 5)
	var target_id := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(2, 2), 4)
	_open_reposition(game)
	game.set_ranged_order(StrategoGame.RED, first_id, Vector2i(2, 2), target_id)
	game.set_ranged_order(StrategoGame.RED, second_id, Vector2i(2, 2), target_id)
	var events := _ready_and_resolve_reposition(game, [5, 1, 1, 1, 4, 1, 1, 1])
	_expect(_events_with_action(events, "ranged").size() == 2, "all scheduled focus-fire shots resolve even when the target is overkilled")
	_expect(not game.pieces[target_id].alive, "simultaneous ranged damage destroys an overkilled target")
	_expect(game.pieces[first_id].strength == 5 and game.pieces[second_id].strength == 5, "a target's defensive roll never wounds the Archer back")
	var long_game := _test_game()
	var long_archer := long_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 5)
	var long_target := long_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(3, 1), 6)
	_open_reposition(long_game)
	long_game.set_ranged_order(StrategoGame.RED, long_archer, Vector2i(3, 1), long_target)
	var long_events := _ready_and_resolve_reposition(long_game, [5, 1, 1])
	var long_shots := _events_with_action(long_events, "ranged")
	_expect(long_shots.size() == 1 and int(long_shots[0].range) == 2 and int(long_shots[0].movement_cost) == 0, "ranged fire spends the Archer's post-clash action rather than a movement point")
	_expect(long_game.pieces[long_target].strength == 3, "range-2 fire still lands for its margin, without the short shot's accuracy die")
	_expect(int(long_shots[0].attacker_bonus_dice) == 0, "range 2 buys no accuracy die")
	_expect(long_game.movement_committed(long_game.pieces[long_archer]) == 0, "shooting does not retroactively spend main movement")

	# Range is an accuracy question now, not only a movement-cost one.
	var archer_profile := {"strength": 6, "role": StrategoGame.ROLE_ARCHER, "weight": StrategoGame.WEIGHT_LIGHT}
	var mark := {"strength": 6, "role": StrategoGame.ROLE_INFANTRY, "weight": StrategoGame.WEIGHT_LIGHT}
	var short_shot := game.calculate_ranged(archer_profile, mark, StrategoGame.SHOT_SHORT, [1, 1], [1])
	var long_shot := game.calculate_ranged(archer_profile, mark, StrategoGame.SHOT_LONG, [1], [1])
	_expect(int(short_shot.attacker_bonus_dice) == 1 and int(long_shot.attacker_bonus_dice) == 0, "a short shot buys one accuracy die; a long shot buys none")
	_expect(int(short_shot.defender_bonus_dice) == 0 and int(long_shot.defender_bonus_dice) == 0, "the target gets no role die and no range die of its own")
	var shrugged := game.calculate_ranged(archer_profile, mark, StrategoGame.SHOT_LONG, [2], [5])
	_expect(not bool(shrugged.hit) and int(shrugged.defender_damage) == 0, "a target that outrolls the arrow takes nothing off the margin: a shot is a contest, not a threshold")

	# The whole point of letting crits land on a loss: an Archer with no
	# business threatening this target is still not firing for nothing.
	var outmatched := {"strength": 3, "role": StrategoGame.ROLE_ARCHER, "weight": StrategoGame.WEIGHT_LIGHT}
	var armoured := {"strength": 12, "role": StrategoGame.ROLE_INFANTRY, "weight": StrategoGame.WEIGHT_HEAVY}
	var graze := game.calculate_ranged(outmatched, armoured, StrategoGame.SHOT_SHORT, [6, 1], [4, 1, 1])
	_expect(not bool(graze.hit) and int(graze.defender_damage) == 1, "a lost contest still lands an uncancelled 6: a hopeless shot can chip")
	var shrugged_crit := game.calculate_ranged(outmatched, armoured, StrategoGame.SHOT_SHORT, [6, 1], [6, 1, 1])
	_expect(int(shrugged_crit.defender_damage) == 0, "and the target's own 6 cancels even that")
	_test_aimed_fire_follows_its_target()
	_test_suppressing_fire_hits_the_square()
	_test_fizzled_shots_still_spend_the_action()


## Aimed fire tracks the formation: a target that moves but stays in range is
## still hit, which is the whole point of targeting a unit rather than a square.
func _test_aimed_fire_follows_its_target() -> void:
	var game := _test_game()
	var archer := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 5)
	var target := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(3, 1), 6)
	_open_reposition(game)
	game.set_ranged_order(StrategoGame.RED, archer, Vector2i(3, 1), target)
	game.set_leftover_order(StrategoGame.BLUE, target, Vector2i(2, 1))
	var events := _ready_and_resolve_reposition(game, [4, 1, 1, 1])
	var shots := _events_with_action(events, "ranged")
	_expect(shots.size() == 1 and int(shots[0].target_id) == target, "aimed fire still hits a target that moved within range")
	_expect(int(shots[0].range) == 1, "the shot resolves at the range the target actually ended up at")
	_expect(int(shots[0].attacker_bonus_dice) == 1, "a tracked target that closes to range 1 grants the accuracy die at resolution")
	var away_game := _test_game()
	var away_archer := away_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 5)
	var away_target := away_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(3, 1), 6)
	_open_reposition(away_game)
	away_game.set_ranged_order(StrategoGame.RED, away_archer, Vector2i(3, 1), away_target)
	away_game.set_leftover_order(StrategoGame.BLUE, away_target, Vector2i(4, 1))
	var away_events := _ready_and_resolve_reposition(away_game)
	_expect(_events_with_action(away_events, "ranged").is_empty(), "aimed fire finds nothing when the target breaks out of range")
	_expect(_events_with_action(away_events, "ranged_fizzle").size() == 1, "a shot that finds nothing is reported as a fizzle")


## Suppressing fire is aimed at ground, so whoever holds that square takes it.
func _test_suppressing_fire_hits_the_square() -> void:
	var game := _test_game()
	var archer := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 5)
	var mover := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(4, 1), 6)
	_open_reposition(game)
	game.set_suppress_order(StrategoGame.RED, archer, Vector2i(3, 1))
	game.set_leftover_order(StrategoGame.BLUE, mover, Vector2i(3, 1))
	var events := _ready_and_resolve_reposition(game, [4, 1, 1])
	var shots := _events_with_action(events, "ranged")
	_expect(shots.size() == 1 and int(shots[0].target_id) == mover, "suppressing fire hits whoever moves onto the targeted square")


## Choosing a shot excludes reposition even when the target escapes and the
## shot fizzles.
func _test_archers_may_mass_a_volley_or_fire_apart() -> void:
	# Two Archers on one hex, loosing together. One contest, one margin, and a
	# pool that rolls a die per Archer plus the comparative dice the best of them
	# earns. The same pair firing apart is two contests instead.
	var massed := _test_game()
	var lead := massed.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 8)
	var joining := massed.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 2), 5)
	var target := massed.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(2, 1), 6)
	_open_reposition(massed)
	_expect(massed.volley_leader_at(StrategoGame.RED, Vector2i(2, 1)) == StrategoGame.EMPTY, "there is nobody to join before anyone has volleyed")
	_expect(not bool(massed.set_volley_support_order(StrategoGame.RED, joining, Vector2i(2, 1)).get("ok", false)), "so support cannot be declared into thin air")
	massed.set_suppress_order(StrategoGame.RED, lead, Vector2i(2, 1))
	_expect(massed.volley_leader_at(StrategoGame.RED, Vector2i(2, 1), joining) == lead, "once a Volley is declared it can be joined")
	_expect(bool(massed.set_volley_support_order(StrategoGame.RED, joining, Vector2i(2, 1)).get("ok", false)), "and the second Archer may throw in with it")
	# Four dice for the pool: one per Archer, one for the stronger side, and one
	# accuracy die for the Archer that is already adjacent. It keeps the 5 and
	# adds the leading Archer's Strength of 8. The target rolls one and adds 6.
	var massed_events := _ready_and_resolve_reposition(massed, [1, 1, 5, 4, 3])
	var massed_shots := _events_with_action(massed_events, "ranged")
	_expect(massed_shots.size() == 1 and bool(massed_shots[0].massed), "a joined Volley resolves as one shot rather than two")
	_expect(massed_shots[0].shooters.size() == 2 and lead in massed_shots[0].shooters and joining in massed_shots[0].shooters, "and names both Archers as having loosed it")
	_expect(int(massed_shots[0].attacker_score) == 13 and int(massed_shots[0].defender_score) == 9, "the pool scores off its strongest Archer, not the sum of them")
	_expect(int(massed_shots[0].defender_damage) == 4, "one contest pays one margin")

	# The same two Archers declining to mass get their own contests, which is the
	# trade: two weaker chances that can each draw blood.
	var apart := _test_game()
	var first := apart.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 8)
	var second := apart.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 2), 5)
	apart.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(2, 1), 6)
	_open_reposition(apart)
	apart.set_suppress_order(StrategoGame.RED, first, Vector2i(2, 1))
	apart.set_suppress_order(StrategoGame.RED, second, Vector2i(2, 1))
	var apart_events := _ready_and_resolve_reposition(apart, [1, 1, 5, 4, 1, 1, 1])
	_expect(_events_with_action(apart_events, "ranged").size() == 2, "two Volleys nobody joined stay two separate shots")
	_expect(target >= 0, "the target exists in both halves of the comparison")


func _test_fizzled_shots_still_spend_the_action() -> void:
	var game := _test_game()
	var light := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 5)
	var heavy := game.add_piece(StrategoGame.HEAVY_ARCHER, StrategoGame.RED, Vector2i(1, 5), 7)
	var light_bait := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(3, 1), 6)
	var heavy_bait := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(3, 5), 6)
	_open_reposition(game)
	game.set_ranged_order(StrategoGame.RED, light, Vector2i(3, 1), light_bait)
	game.set_ranged_order(StrategoGame.RED, heavy, Vector2i(3, 5), heavy_bait)
	game.set_leftover_order(StrategoGame.BLUE, light_bait, Vector2i(4, 1))
	game.set_leftover_order(StrategoGame.BLUE, heavy_bait, Vector2i(4, 5))
	var events := _ready_and_resolve_reposition(game)
	_expect(_events_with_action(events, "ranged_fizzle").size() == 2, "both legal shots fizzle when their targets move beyond range 2")
	_expect(game.movement_committed(game.pieces[light]) == 0 and game.movement_committed(game.pieces[heavy]) == 0, "post-clash shooting does not spend main movement")


func _test_archer_loss_blocks_shot_and_win_allows_it() -> void:
	var losing_game := _test_game()
	var losing_archer := losing_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 10)
	losing_game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(2, 1), 10)
	var untouched_target := losing_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.GREEN, Vector2i(2, 2), 10)
	losing_game.set_unit_order(StrategoGame.RED, losing_archer, [Vector2i(2, 1)])
	_open_reposition(losing_game, [1, 5, 1, 1])
	var losing_order := losing_game.set_ranged_order(StrategoGame.RED, losing_archer, losing_game.pieces[untouched_target].position, untouched_target)
	_expect(not bool(losing_order.ok) and losing_game.pieces[untouched_target].strength == 10, "an Archer that lost the main melee cannot choose a post-clash shot")
	var winning_game := _test_game()
	var winning_archer := winning_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 1), 10)
	winning_game.add_piece(StrategoGame.HEAVY_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	var shot_target := winning_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.GREEN, Vector2i(2, 2), 10)
	winning_game.set_unit_order(StrategoGame.RED, winning_archer, [Vector2i(2, 1)])
	_open_reposition(winning_game, [5, 1, 1])
	winning_game.set_ranged_order(StrategoGame.RED, winning_archer, Vector2i(2, 2), shot_target)
	var winning_events := _ready_and_resolve_reposition(winning_game, [4, 1, 1])
	_expect(_events_with_action(winning_events, "ranged").size() == 1 and winning_game.pieces[shot_target].strength == 7, "an Archer that wins the main melee may choose to shoot afterward")

	var cavalry_game := _test_game()
	var threatened_archer := cavalry_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(5, 5), 6)
	var cavalry := cavalry_game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.BLUE, Vector2i(5, 4), 10)
	var distant_target := cavalry_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.GREEN, Vector2i(6, 6), 10)
	_open_reposition(cavalry_game)
	cavalry_game.set_ranged_order(StrategoGame.RED, threatened_archer, Vector2i(6, 6), distant_target)
	var cavalry_order := cavalry_game.set_leftover_order(StrategoGame.BLUE, cavalry, Vector2i(5, 5))
	_expect(bool(cavalry_order.ok), "Cavalry may deliberately reposition into an enemy-held hex")
	var cavalry_events := _ready_and_resolve_reposition(cavalry_game, [6, 1, 1, 1, 1])
	_expect(_events_with_action(cavalry_events, "melee").size() == 1 and _events_with_action(cavalry_events, "ranged").is_empty(), "a Cavalry attack that defeats an Archer resolves before and cancels its shot")


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
	_expect(presenter._resolution_completion_label() == "ORDER REPOSITION", "the final main-resolution button names the reposition phase it opens")
	presenter.free()
	var order_result := game.set_leftover_order(StrategoGame.RED, mover, Vector2i(4, 2))
	_expect(bool(order_result.get("ok", false)) and game.pieces[mover].position == Vector2i(4, 3), "leftover orders are issued from the formation's resolved position")
	for player in game.active_players:
		game.mark_player_ready(player)
	var events := game.resolve_leftover_phase()
	_expect(_events_with_action(events, "move").size() == 1 and game.pieces[mover].position == Vector2i(4, 2), "ending the leftover phase resolves its simultaneous movement")
	_expect(game.phase == StrategoGame.PHASE_PLANNING and game.round_number == 2, "the next planning round starts only after leftover movement finishes")


func _test_reposition_moves_collapse_into_one_card() -> void:
	# Reposition has no contest in it, so clicking Next once per formation was
	# pure toll. The whole phase is one card; anything that actually resolves
	# something still gets its own.
	var game := _test_game()
	var presenter: Control = load("res://scripts/main.gd").new()
	presenter.game = game
	presenter.replay_view_mode = true
	var events: Array[Dictionary] = [
		{"action": "move", "batch": "leftover", "piece_id": 0, "from": Vector2i(1, 1), "to": Vector2i(1, 2), "combat": false},
		{"action": "move", "batch": "leftover", "piece_id": 1, "from": Vector2i(2, 1), "to": Vector2i(2, 2), "combat": false},
		{"action": "move", "batch": "leftover", "piece_id": 2, "from": Vector2i(3, 1), "to": Vector2i(3, 2), "combat": false},
		{"action": "melee", "batch": "leftover", "combat": true, "participants": [0, 1]},
		{"action": "move", "batch": "impulse_1", "piece_id": 3, "from": Vector2i(4, 1), "to": Vector2i(4, 2), "combat": false},
	]
	var visible: Array = presenter._visible_presentation_events(events)
	_expect(visible.size() == 2, "three repositions and a battle are two cards, not four")
	_expect(String(visible[0].action) == "leftover_move" and visible[0].moves.size() == 3, "every reposition is gathered onto the one card")
	_expect(String(visible[1].action) == "melee", "a battle in the same phase still gets its own")
	_expect(int(visible[0].moves[2].piece_id) == 2, "and the card keeps who went where, in order")
	presenter.free()


func _test_reposition_keeps_unidentified_formations_secret() -> void:
	var game := _test_game()
	var enemy_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(4, 4), 7)
	game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(4, 7), 8)
	for player in game.active_players: game.mark_player_ready(player)
	game.resolve_main_and_ranged()
	_expect(game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING, "identity regression reaches the reposition phase")
	_expect(not game.is_piece_revealed_to(game.pieces[enemy_id], StrategoGame.BLUE), "the visible enemy entering reposition is still unidentified")
	var presenter: Control = load("res://scripts/main.gd").new()
	presenter.game = game
	_expect(not presenter._piece_identity_is_visible(game.pieces[enemy_id]), "the reposition presenter preserves the engine's hidden identity")
	_expect(presenter._card_formation_name(game.pieces[enemy_id], false) == "LIGHT FORMATION", "a hidden reposition card omits Role and Strength-bearing identity")
	presenter.free()


func _test_leftover_contingent_friendly_square_order() -> void:
	var battle_game := _test_game()
	var guard := battle_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5), 10)
	var follow_up := battle_game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.BLUE, Vector2i(5, 6), 10)
	var second_follow_up := battle_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(6, 5), 10)
	var attacker := battle_game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(4, 5), 10)
	battle_game.phase = StrategoGame.PHASE_LEFTOVER_PLANNING
	var contingent_order := battle_game.set_leftover_order(StrategoGame.BLUE, follow_up, Vector2i(5, 5))
	_expect(bool(contingent_order.ok), "reposition accepts a contingent move into a stationary friendly formation's square")
	_expect(bool(battle_game.set_leftover_order(StrategoGame.BLUE, second_follow_up, Vector2i(5, 5)).ok), "multiple friendly follow-ups may converge because multiway fights are allowed")
	battle_game.set_leftover_order(StrategoGame.RED, attacker, Vector2i(5, 5))
	battle_game.set_forced_rolls([5, 4, 3, 2, 1, 1])
	for player in battle_game.active_players: battle_game.mark_player_ready(player)
	var battle_events := battle_game.resolve_leftover_phase()
	var melee_events := _events_with_action(battle_events, "melee")
	_expect(melee_events.size() == 1 and melee_events[0].participants.size() == 4, "the defender, friendly follow-ups, and enemy arrival resolve as one multiway fight")

	var bounce_game := _test_game()
	var surviving_guard := bounce_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 5), 10)
	var follower := bounce_game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.BLUE, Vector2i(5, 6), 10)
	bounce_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18), 10)
	bounce_game.phase = StrategoGame.PHASE_LEFTOVER_PLANNING
	_expect(bool(bounce_game.set_leftover_order(StrategoGame.BLUE, follower, Vector2i(5, 5)).ok), "the same contingent order is legal when the defender may survive")
	for player in bounce_game.active_players: bounce_game.mark_player_ready(player)
	var bounce_events := bounce_game.resolve_leftover_phase()
	_expect(_events_with_action(bounce_events, "melee").is_empty() and _events_with_action(bounce_events, "bounce").size() == 1, "without an enemy arrival, the friendly formations simply bounce")
	_expect(bounce_game.pieces[surviving_guard].position == Vector2i(5, 5) and bounce_game.pieces[follower].position == Vector2i(5, 6), "the defender holds while the follower stays in its original square")


func _test_leftover_allows_second_melee_only_after_win() -> void:
	var move_game := _test_game()
	var leftover_mover := move_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(4, 4), 8)
	move_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(18, 18), 8)
	_open_reposition(move_game)
	move_game.set_leftover_order(StrategoGame.RED, leftover_mover, Vector2i(4, 3))
	var move_events := _ready_and_resolve_reposition(move_game)
	var leftover_moves: Array[Dictionary] = []
	for event: Dictionary in _events_with_action(move_events, "move"):
		if String(event.get("batch", "")) == "leftover": leftover_moves.append(event)
	_expect(leftover_moves.size() == 1 and move_game.pieces[leftover_mover].position == Vector2i(4, 3), "an uncontested leftover order executes in the leftover movement phase")
	var presenter: Control = load("res://scripts/main.gd").new()
	presenter.game = move_game
	var presentation_input: Array[Dictionary] = [{"action": "move", "batch": "leftover", "piece_id": leftover_mover, "visible_to": [StrategoGame.BLUE], "combat": false}]
	var presented_leftovers: Array[Dictionary] = presenter._visible_presentation_events(presentation_input)
	_expect(presented_leftovers.size() == 1 and presented_leftovers[0].action == "leftover_move", "ordinary leftover movement appears in the click-through resolution review")
	var congestion_input: Array[Dictionary] = [{"action": "bounce", "batch": "leftover", "participants": [leftover_mover], "known_to": [StrategoGame.BLUE], "combat": false}]
	_expect(presenter._visible_presentation_events(congestion_input).is_empty(), "non-combat congestion is skipped during click-through review")
	presenter.free()
	var group_game := _test_game()
	var exhausted_heavy := group_game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(8, 6))
	var eligible_light := group_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(10, 6))
	group_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	group_game.append_group_order_step(StrategoGame.BLUE, [exhausted_heavy, eligible_light], HexGrid.NORTH)
	_open_reposition(group_game)
	var group_leftover := group_game.set_group_leftover_step(StrategoGame.BLUE, [exhausted_heavy, eligible_light], HexGrid.SOUTH_WEST)
	_expect(bool(group_leftover.ok) and int(group_leftover.count) == 2 and int(group_leftover.skipped) == 0, "every eligible formation receives the shared reposition direction regardless of spent movement")
	var light_after_main := HexGrid.neighbor(Vector2i(10, 6), HexGrid.NORTH)
	var heavy_after_main := HexGrid.neighbor(Vector2i(8, 6), HexGrid.NORTH)
	_expect(group_game.order_for_piece(exhausted_heavy).leftover == HexGrid.neighbor(heavy_after_main, HexGrid.SOUTH_WEST) and group_game.order_for_piece(eligible_light).leftover == HexGrid.neighbor(light_after_main, HexGrid.SOUTH_WEST), "Heavy and Light formations both receive the universal reposition step")
	var win_game := _test_game()
	var cavalry_id := win_game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(1, 1), 10)
	win_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	win_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.GREEN, Vector2i(2, 2), 10)
	win_game.set_unit_order(StrategoGame.RED, cavalry_id, [Vector2i(2, 1)])
	var win_events := _open_reposition(win_game, [4, 1, 1])
	win_game.set_leftover_order(StrategoGame.RED, cavalry_id, Vector2i(2, 2))
	win_events.append_array(_ready_and_resolve_reposition(win_game, [4, 1, 1]))
	_expect(_events_with_action(win_events, "melee").size() == 2 and int(win_game.pieces[cavalry_id].melee_count) == 2, "a winner can use leftover movement for at most a second intentional melee")
	var bounce_game := _test_game()
	var bounced_id := bounce_game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(1, 1), 10)
	bounce_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 1), 10)
	bounce_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.GREEN, Vector2i(2, 2), 10)
	bounce_game.set_unit_order(StrategoGame.RED, bounced_id, [Vector2i(2, 1)])
	var bounce_events := _open_reposition(bounce_game, [4, 1, 4])
	var blocked_followup := bounce_game.set_leftover_order(StrategoGame.RED, bounced_id, Vector2i(2, 2))
	_expect(not bool(blocked_followup.ok), "a bounced formation cannot receive a reposition order")
	_expect(_events_with_action(bounce_events, "melee").size() == 1 and bounce_game.pieces[bounced_id].round_status == StrategoGame.STATUS_BOUNCED, "a bounce ends the unit's round and prevents leftover re-engagement")


func _test_universal_reposition_and_role_destinations() -> void:
	var game := _test_game()
	var cavalry := game.add_piece(StrategoGame.HEAVY_CAVALRY, StrategoGame.BLUE, Vector2i(8, 6))
	var infantry := game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(10, 6))
	var enemy := game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(9, 5))
	game.set_unit_order(StrategoGame.BLUE, cavalry, [Vector2i(8, 5)])
	game.set_unit_order(StrategoGame.BLUE, infantry, [Vector2i(10, 5)])
	_open_reposition(game)
	_expect(game.can_receive_leftover_order(StrategoGame.BLUE, cavalry) and game.can_receive_leftover_order(StrategoGame.BLUE, infantry), "exhausted Heavy Cavalry and Heavy Infantry both receive the universal reposition action")
	_expect(bool(game.set_leftover_order(StrategoGame.BLUE, cavalry, game.pieces[enemy].position).ok), "Cavalry may deliberately reposition into an enemy-held hex")
	var infantry_attack := game.set_leftover_order(StrategoGame.BLUE, infantry, game.pieces[enemy].position)
	_expect(not bool(infantry_attack.ok), "Infantry may not deliberately reposition into an enemy-held hex")
	game.pieces[infantry].round_status = StrategoGame.STATUS_LOST
	_expect(not game.can_receive_leftover_order(StrategoGame.BLUE, infantry), "losing a fight still blocks the universal post-clash action")

	var meeting := _test_game()
	var red_infantry := meeting.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(5, 4), 8)
	var blue_infantry := meeting.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, Vector2i(5, 6), 8)
	meeting.phase = StrategoGame.PHASE_LEFTOVER_PLANNING
	_expect(bool(meeting.set_leftover_order(StrategoGame.RED, red_infantry, Vector2i(5, 5)).ok) and bool(meeting.set_leftover_order(StrategoGame.BLUE, blue_infantry, Vector2i(5, 5)).ok), "opposing Infantry may independently choose the same currently empty reposition hex")
	var meeting_events := _ready_and_resolve_reposition(meeting, [5, 4])
	var meeting_battles := _events_with_action(meeting_events, "melee")
	_expect(meeting_battles.size() == 1 and int(meeting_battles[0].bonus_dice[red_infantry]) == 0 and int(meeting_battles[0].bonus_dice[blue_infantry]) == 0, "an accidental Infantry meeting becomes a battle with both formations counted as attackers")


func _test_phase_has_no_decision_ignores_idle_formations() -> void:
	# Reposition is now a universal post-clash action, so even a formation that
	# held during main planning has a real move-or-hold decision afterward.
	var idle_game := _test_game()
	idle_game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(8, 6))
	idle_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, Vector2i(18, 18))
	for player in idle_game.active_players: idle_game.mark_player_ready(player)
	idle_game.resolve_main_and_ranged()
	var idle_presenter: Control = load("res://scripts/main.gd").new()
	idle_presenter.game = idle_game
	_expect(not idle_presenter._phase_has_no_decision(), "an idle formation still receives a real universal reposition decision")
	idle_presenter.free()


func _test_blocked_retreat_destroys_loser() -> void:
	var game := _test_game()
	var attacker_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, Vector2i(1, 0), 10)
	var defender_id := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(0, 0), 10)
	game.set_unit_order(StrategoGame.RED, attacker_id, [Vector2i(0, 0)])
	var events := _ready_and_resolve(game, [5, 1])
	var retreat_events := _events_with_action(events, "retreat")
	_expect(retreat_events.size() == 1 and retreat_events[0].result == "retreat_destroyed", "retreat off-map destroys the losing formation")
	_expect(not game.pieces[defender_id].alive and game.pieces[attacker_id].position == Vector2i(0, 0), "winner occupies after the blocked defender retreat")


func _test_friendly_blocked_retreat_shunts() -> void:
	var anchor := Vector2i(8, 8)
	var direction := HexGrid.SOUTH
	var direct := HexGrid.neighbor(anchor, direction)
	var left := HexGrid.neighbor(anchor, (direction + 1) % HexGrid.DIRECTION_COUNT)
	var right := HexGrid.neighbor(anchor, (direction - 1 + HexGrid.DIRECTION_COUNT) % HexGrid.DIRECTION_COUNT)

	var left_game := _test_game()
	var left_loser := left_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, anchor, 5)
	left_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, direct, 5)
	var left_events := left_game._resolve_retreats([{"piece_id": left_loser, "from": anchor, "to": direct, "anchor": anchor, "direction": direction}], "test")
	_expect(left_game.pieces[left_loser].position == left and left_events[0].result == "retreat_shunted" and left_events[0].shunt_side == "left", "a friendly formation directly behind the loser shunts it left first")

	var right_game := _test_game()
	var right_loser := right_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, anchor, 5)
	right_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, direct, 5)
	right_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, left, 5)
	var right_events := right_game._resolve_retreats([{"piece_id": right_loser, "from": anchor, "to": direct, "anchor": anchor, "direction": direction}], "test")
	_expect(right_game.pieces[right_loser].position == right and right_events[0].shunt_side == "right", "a blocked left shunt falls back to the right-hand hex")

	var enemy_game := _test_game()
	var enemy_blocked := enemy_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, anchor, 5)
	enemy_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.RED, direct, 5)
	var enemy_events := enemy_game._resolve_retreats([{"piece_id": enemy_blocked, "from": anchor, "to": direct, "anchor": anchor, "direction": direction}], "test")
	_expect(not enemy_game.pieces[enemy_blocked].alive and enemy_events[0].reason == "enemy_blocked", "an enemy in the direct retreat hex still destroys the loser without a shunt")

	# Near retreats full is congestion, not a death sentence. This is the shape
	# that used to wipe out several formations at once: a side advances to help,
	# fills the hexes behind its own line, and its losers had nowhere the rule
	# would look.
	var crowded_game := _test_game()
	var crowded := crowded_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, anchor, 5)
	for blocked in [direct, left, right]:
		crowded_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, blocked, 5)
	var crowded_events := crowded_game._resolve_retreats([{"piece_id": crowded, "from": anchor, "to": direct, "anchor": anchor, "direction": direction}], "test")
	_expect(crowded_game.pieces[crowded].alive and crowded_events[0].result == "retreat_shunted", "a loser whose near retreats are all full keeps looking instead of dying")
	_expect(StrategoGame.are_adjacent(anchor, crowded_game.pieces[crowded].position), "and falls back to a hex it can actually reach")

	var boxed_game := _test_game()
	var boxed := boxed_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, anchor, 5)
	for step in HexGrid.DIRECTION_COUNT:
		boxed_game.add_piece(StrategoGame.LIGHT_INFANTRY, StrategoGame.BLUE, HexGrid.neighbor(anchor, step), 5)
	var boxed_events := boxed_game._resolve_retreats([{"piece_id": boxed, "from": anchor, "to": direct, "anchor": anchor, "direction": direction}], "test")
	_expect(not boxed_game.pieces[boxed].alive and boxed_events[0].reason == "friendly_congestion", "only a formation with no free neighbour at all is still lost to congestion")
	# Retreats reach the history, so a replay can answer what happened to a
	# formation that vanished. Reading the code was the only way before.
	var recorded := boxed_game.battle_history
	_expect(recorded.size() == 1 and String(recorded[0].get("action", "")) == "retreat", "a retreat is recorded in the battle history")
	_expect(String(recorded[0].get("reason", "")) == "friendly_congestion" and int(recorded[0].get("piece_id", -1)) == boxed, "with the formation it destroyed and why")
	_expect(not recorded[0].get("known_to", []).is_empty(), "and who was in a position to see it")


func _test_enemy_retreat_collision_battle() -> void:
	var game := _test_game()
	var retreat_target := Vector2i(6, 6)
	var blue_position := HexGrid.neighbor(retreat_target, HexGrid.SOUTH)
	var red_position := HexGrid.neighbor(blue_position, HexGrid.SOUTH)
	var green_position := HexGrid.neighbor(retreat_target, HexGrid.SOUTH_WEST)
	var yellow_position := HexGrid.neighbor(green_position, HexGrid.SOUTH_WEST)
	var red_attacker := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.RED, red_position, 10)
	var blue_defender := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, blue_position, 10)
	var yellow_attacker := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.YELLOW, yellow_position, 10)
	var green_defender := game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.GREEN, green_position, 10)
	game.set_unit_order(StrategoGame.RED, red_attacker, [blue_position])
	game.set_unit_order(StrategoGame.YELLOW, yellow_attacker, [green_position])
	var events := _ready_and_resolve(game, [5, 1, 5, 1, 4, 4])
	var retreat_battles := _events_with_action(events, "retreat_battle")
	_expect(retreat_battles.size() == 1, "enemy retreats entering the same previously empty square create a retreat battle")
	if retreat_battles.size() == 1:
		# Both were knocked down to Strength 6 by the melee they just lost, so an
		# equal die leaves them on equal scores.
		_expect(int(retreat_battles[0].scores[blue_defender]) == 10 and int(retreat_battles[0].scores[green_defender]) == 10, "retreat-battle score is the kept die plus current Strength")
		_expect(retreat_battles[0].dice_pools[blue_defender].size() == 1 and retreat_battles[0].dice_pools[green_defender].size() == 1, "retreat battles grant no role die: nobody here is charging or braced")
	_expect(not game.pieces[blue_defender].alive and not game.pieces[green_defender].alive, "a tied retreat battle destroys both formations with no further retreat")

	# The comparative dice do still apply. A Heavy backing into a Light gets
	# its weight die, and a winner takes nothing because the margin ran its way.
	var weight_game := _test_game()
	var heavy_id := weight_game.add_piece(StrategoGame.HEAVY_ARCHER, StrategoGame.RED, Vector2i(0, 0), 10)
	var light_id := weight_game.add_piece(StrategoGame.LIGHT_ARCHER, StrategoGame.BLUE, Vector2i(2, 0), 10)
	weight_game._clear_piece_square(heavy_id)
	weight_game._clear_piece_square(light_id)
	weight_game.set_forced_rolls([5, 1, 4])
	var weight_event := weight_game._resolve_retreat_battle([
		{"piece_id": heavy_id, "from": Vector2i(0, 0), "to": Vector2i(1, 0)},
		{"piece_id": light_id, "from": Vector2i(2, 0), "to": Vector2i(1, 0)},
	], Vector2i(1, 0), "test")
	_expect(weight_event.dice_pools[heavy_id].size() == 2 and weight_event.dice_pools[light_id].size() == 1, "the heavier formation still earns its comparative weight die in a retreat battle")
	_expect(weight_game.pieces[heavy_id].alive and weight_game.pieces[heavy_id].strength == 10, "a retreat-battle winner takes no damage, because damage is only ever the margin against it")


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
func _test_highfield_setup() -> void:
	var game := StrategoGame.new()
	game.setup_highfield(7)
	_expect(game.scenario == StrategoGame.SCENARIO_HIGHFIELD, "highfield loads its own scenario")
	_expect(game.objectives.size() == 1 and game.objectives[0].square == Vector2i(10, 10), "the highfield objective is the central hill")
	var reds: Array = []
	var blues: Array = []
	var red_lights := 0
	for piece: Dictionary in game.pieces:
		if int(piece.player) == StrategoGame.RED:
			reds.append(int(piece.position.y))
			if String(piece.weight) == StrategoGame.WEIGHT_LIGHT: red_lights += 1
		else:
			blues.append(int(piece.position.y))
	_expect(reds.size() == 7 and blues.size() == 9, "the Wardens field seven formations against nine Outriders")
	_expect(red_lights == 0, "the Wardens carry no light formations - the heavy army")
	reds.sort()
	blues.sort()
	_expect(reds.max() < 10 and blues.min() > 10, "the two armies deploy on opposite sides of the hill")
	# Weight and Strength are decoupled: every fresh formation starts equal.
	_expect(game.total_strength(StrategoGame.RED) == 49 and game.total_strength(StrategoGame.BLUE) == 63, "uniform Strength makes the asymmetry one of Weight and numbers, not a strength race")


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
	blue_rows.sort()
	red_rows.sort()
	_expect(blue_rows.min() == 17 and blue_rows.max() == 19 and red_rows.min() == 1 and red_rows.max() == 3, "each army deploys in three ranks facing the objective")
	var blue_front: int = blue_rows.min()
	var red_front: int = red_rows.max()
	_expect(absi(blue_front - 10) == absi(red_front - 10), "both leading ranks are the same distance from the objective")
	var heavy_rows: Array = []
	var light_rows: Array = []
	for piece: Dictionary in setup_game.pieces:
		if int(piece.player) != StrategoGame.RED: continue
		if String(piece.weight) == StrategoGame.WEIGHT_HEAVY: heavy_rows.append(int(piece.position.y))
		elif String(piece.weight) == StrategoGame.WEIGHT_LIGHT: light_rows.append(int(piece.position.y))
	# Slow formations lead so they reach the objective with everyone else.
	_expect(heavy_rows.min() == 3 and heavy_rows.max() == 3, "Heavy formations hold the leading rank")
	_expect(light_rows.min() == 1 and light_rows.max() == 1, "Light formations screen from the rear rank")
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

	var skirmish := StrategoGame.new()
	skirmish.setup_skirmish(3, ["LI", "LI"], ["LC", "LC"], 3, 40)
	_expect(skirmish.scenario == StrategoGame.SCENARIO_SKIRMISH, "skirmish loads its own scenario")
	_expect(skirmish.terrain.is_empty(), "the control scenario has no terrain")
	_expect(skirmish.count_alive(StrategoGame.BLUE) == 2 and skirmish.count_alive(StrategoGame.RED) == 2, "skirmish rosters are taken from their parameters")
	var rows: Dictionary = {}
	for piece: Dictionary in skirmish.pieces: rows[int(piece.player)] = int(piece.position.y)
	_expect(absi(int(rows[StrategoGame.BLUE]) - int(rows[StrategoGame.RED])) == 3, "the two lines stand the requested distance apart")
	_expect(skirmish.objective_aim_point(StrategoGame.BLUE) == Vector2i(-1, -1), "an elimination scenario has no positional aim point")
	for piece: Dictionary in skirmish.pieces:
		if int(piece.player) == StrategoGame.RED: skirmish.pieces[piece.id].strength = 0
	skirmish._remove_piece(skirmish.find_alive_piece(StrategoGame.RED, "LC").id)
	skirmish._remove_piece(skirmish.find_alive_piece(StrategoGame.RED, "LC").id)
	_ready_and_resolve(skirmish)
	_expect(skirmish.game_over and skirmish.winner == StrategoGame.BLUE and skirmish.end_reason == "army_destroyed", "destroying the opposing army wins the control scenario")

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
		_plan_and_resolve_bot_round(game, policy, planning_rng)
	var document := game.build_replay_document()
	_expect(String(document.get("format", "")) == StrategoGame.REPLAY_FORMAT and int(document.get("version", 0)) == StrategoGame.REPLAY_VERSION, "replay export identifies its versioned deterministic format")
	_expect(String(document.get("setup", {}).get("grid", "")) == StrategoGame.GRID_TYPE, "replay setup records the hex coordinate system")
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
	var replay_path := "res://replays/automated-round-trip.json"
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
	var wrong_grid: Dictionary = document.duplicate(true)
	wrong_grid.setup = wrong_grid.setup.duplicate(true)
	wrong_grid.setup.grid = "square_orthogonal"
	_expect(not bool(StrategoGame.run_replay(wrong_grid).get("ok", false)), "replay verification rejects a different board topology")


func _test_in_progress_replay_export() -> void:
	var game := StrategoGame.new()
	game.setup_bridge(99173)
	var policy := StrategoBotPolicy.new()
	var planning_rng := RandomNumberGenerator.new()
	planning_rng.seed = 44021
	for player in game.active_players.duplicate():
		policy.plan_round(game, player, planning_rng)
		game.mark_player_ready(player)
	var live_events := game.resolve_main_and_ranged()
	_expect(game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING and not game.game_over, "a live export fixture stops after combat while the battle is still in progress")
	var document := game.build_replay_document()
	_expect(not document.get("partial_round", {}).is_empty() and bool(document.get("capture", {}).get("in_progress", false)), "an in-progress export records the current partial round")
	var replay_result := StrategoGame.run_replay(document)
	_expect(bool(replay_result.get("ok", false)) and replay_result.get("events", []).size() == live_events.size(), "an in-progress export replays every resolved event from the current round")
	_expect(String(replay_result.get("digest", "")) == game.state_digest() and replay_result.game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING, "an in-progress export reconstructs the exact live battle state")
	var replay_path := "res://replays/automated-live-round.json"
	var save_result := game.save_replay(replay_path)
	var load_result := StrategoGame.load_replay_document(replay_path)
	var file_result: Dictionary = StrategoGame.run_replay(load_result.get("document", {})) if bool(load_result.get("ok", false)) else {"ok": false}
	_expect(bool(save_result.get("ok", false)) and bool(save_result.get("partial_round", false)) and bool(file_result.get("ok", false)), "an unfinished battle saves, loads, and verifies from disk")


func _test_deployment_zone_and_recommended_formation() -> void:
	var game := StrategoGame.new()
	game.setup_crossroads(4242)
	_expect(game.phase == StrategoGame.PHASE_DEPLOYMENT, "crossroads opens on a deployment phase, not planning")
	var all_players: Array = [StrategoGame.RED, StrategoGame.GREEN, StrategoGame.BLUE, StrategoGame.YELLOW]
	var claimed: Dictionary = {}
	var collision := false
	for player in all_players:
		var zone := game.deployment_zone_cells(player)
		_expect(zone.size() == (2 * StrategoGame.DEPLOYMENT_LATERAL_HALFWIDTH + 1) * StrategoGame.DEPLOYMENT_ZONE_DEPTH, "%s's deployment zone is the full rectangle, clear of lake terrain" % game.player_name(player))
		for cell in zone:
			if cell in claimed and claimed[cell] != player: collision = true
			claimed[cell] = player
		for piece: Dictionary in game.pieces:
			if int(piece.player) == player:
				_expect(piece.position in zone, "%s's recommended formation stays inside its own zone" % game.player_name(player))
	_expect(not collision, "no two corners' deployment zones share a cell")
	_expect(game.count_alive(StrategoGame.RED) == 13 and game.total_strength(StrategoGame.RED) == 84, "the recommended formation is the full roster, not a partial one")


func _test_deployment_fog_and_redeploy() -> void:
	var game := StrategoGame.new()
	game.setup_crossroads(77)
	var red_flag := game.find_alive_piece(StrategoGame.RED, StrategoGame.FLAG)
	_expect(not game.is_piece_visible_to(red_flag, StrategoGame.BLUE), "an opposing corner's formation is invisible during deployment, not just unidentified")
	_expect(game.is_piece_visible_to(red_flag, StrategoGame.RED), "a player can always see their own deployment")
	var red_cavalry := game.find_alive_piece(StrategoGame.RED, StrategoGame.MEDIUM_CAVALRY)
	var zone := game.deployment_zone_cells(StrategoGame.RED)
	var empty_cell: Vector2i = Vector2i(-1, -1)
	for cell in zone:
		if game.piece_at(cell).is_empty():
			empty_cell = cell
			break
	var moved := game.redeploy_piece(StrategoGame.RED, int(red_cavalry.id), empty_cell)
	_expect(bool(moved.get("ok", false)) and game.pieces[red_cavalry.id].position == empty_cell, "redeploying to an open cell inside the zone succeeds")
	var outside := Vector2i(StrategoGame.BOARD_SIZE / 2, StrategoGame.BOARD_SIZE / 2)
	var rejected := game.redeploy_piece(StrategoGame.RED, int(red_cavalry.id), outside)
	_expect(not bool(rejected.get("ok", false)), "redeploying outside the zone is rejected")
	var blue_infantry := game.find_alive_piece(StrategoGame.BLUE, StrategoGame.HEAVY_INFANTRY)
	var cross_owner := game.redeploy_piece(StrategoGame.RED, int(blue_infantry.id), empty_cell)
	_expect(not bool(cross_owner.get("ok", false)), "a player cannot redeploy another player's formation")
	var recommended_cell: Vector2i = Vector2i(-1, -1)
	for entry in StrategoGame.CORNER_DEPLOYMENT:
		if String(entry[0]) == StrategoGame.MEDIUM_CAVALRY: recommended_cell = game._edge_cell(StrategoGame.RED, int(entry[1]), int(entry[2]))
	var reset_result := game.reset_deployment(StrategoGame.RED)
	_expect(bool(reset_result.get("ok", false)) and game.pieces[red_cavalry.id].position == recommended_cell, "auto-deploy's reset restores a dragged formation to its recommended square")
	_expect(game.piece_at(empty_cell).is_empty(), "the square it had been dragged to is vacated by the reset")
	for player in game.active_players: game.mark_player_ready(player)
	var locked := game.redeploy_piece(StrategoGame.RED, int(red_cavalry.id), zone[0])
	_expect(not bool(locked.get("ok", false)), "deployment is locked once every player is ready")
	_expect(game.resolve_deployment(), "deployment resolves once every player has locked in")
	_expect(game.phase == StrategoGame.PHASE_PLANNING, "deployment hands off to the ordinary planning phase")
	_expect(not game.is_piece_visible_to(game.find_alive_piece(StrategoGame.BLUE, StrategoGame.FLAG), StrategoGame.RED), "ordinary fog still hides the far corners once real play begins")


func _test_crossroads_replay_round_trip() -> void:
	var game := StrategoGame.new()
	game.setup_crossroads(555)
	var moved_piece := game.find_alive_piece(StrategoGame.YELLOW, StrategoGame.LIGHT_ARCHER)
	var zone := game.deployment_zone_cells(StrategoGame.YELLOW)
	var target: Vector2i = zone[zone.size() - 1]
	if not game.piece_at(target).is_empty(): target = moved_piece.position
	game.redeploy_piece(StrategoGame.YELLOW, int(moved_piece.id), target)
	for player in game.active_players: game.mark_player_ready(player)
	game.resolve_deployment()
	var bot := StrategoBotPolicy.new()
	var planning_rng := RandomNumberGenerator.new()
	planning_rng.seed = 314
	for round_index in range(4):
		if game.game_over: break
		_plan_and_resolve_bot_round(game, bot, planning_rng)
	var document := game.build_replay_document()
	_expect(document.get("setup", {}).get("deployment", {}).size() == game.pieces.size(), "a crossroads replay records where every formation was actually deployed")
	var parsed_value: Variant = JSON.parse_string(JSON.stringify(document))
	var json_result: Dictionary = StrategoGame.run_replay(parsed_value as Dictionary) if parsed_value is Dictionary else {"ok": false}
	_expect(bool(json_result.get("ok", false)) and String(json_result.get("digest", "")) == game.state_digest(), "a crossroads replay reproduces the exact final state, redeployment included")


func _test_bot_omniscient_toggle() -> void:
	var game := _test_game()
	game.add_piece(StrategoGame.LIGHT_CAVALRY, StrategoGame.RED, Vector2i(4, 4), 8)
	var defender := game.add_piece(StrategoGame.HEAVY_INFANTRY, StrategoGame.BLUE, Vector2i(5, 4), 10)
	_expect(not game.is_piece_revealed_to(game.pieces[defender], StrategoGame.RED), "the defender genuinely has not been revealed to Red")
	var honest := StrategoBotPolicy.new()
	var perceived_honest: Dictionary = honest._perceived_enemy(game, StrategoGame.RED, game.pieces[defender])
	_expect(String(perceived_honest.role) == String(honest.assumptions.role) and int(perceived_honest.strength) == int(honest.assumptions.strength), "an honest bot substitutes its assumption for an unrevealed enemy")
	var cheater := StrategoBotPolicy.new()
	cheater.omniscient = true
	var perceived_cheater: Dictionary = cheater._perceived_enemy(game, StrategoGame.RED, game.pieces[defender])
	_expect(String(perceived_cheater.role) == StrategoGame.ROLE_INFANTRY and int(perceived_cheater.strength) == 10, "an omniscient bot reads the true stats even though the piece has not been revealed - the toggle changes the bot, not the fog state")


func _test_bot_round_smoke() -> void:
	var game := StrategoGame.new()
	game.setup_random(9001, 4)
	var bot := StrategoBotPolicy.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var events := _plan_and_resolve_bot_round(game, bot, rng)
	_expect(game.round_number == 2 and not events.is_empty(), "four bots can submit collision-validated WEGO orders and resolve a complete round")
	var trainer := SelfPlayTrainer.new()
	trainer.max_rounds = 4
	var result := trainer.play_match(bot, StrategoBotPolicy.new(), StrategoGame.RED, 424242)
	_expect(int(result.rounds) > 0 and int(result.rounds) <= 5, "headless self-play remains bounded under simultaneous orders")


func _test_llm_client_parsing() -> void:
	var body := StrategoLLMClient.build_request_body(
		[{"role": "user", "content": "orders?"}], "sonnet", 500, 0.4,
	)
	_expect(String(body.model) == "sonnet" and int(body.max_tokens) == 500 and not bool(body.stream), "the request body carries the model and asks for a whole response rather than a stream")

	_expect(StrategoLLMClient.extract_content({"choices": [{"message": {"content": "advance"}}]}) == "advance", "the assistant's text is read out of the standard response shape")
	# Some models leave content empty and put the answer in reasoning_content;
	# without the fallback those replies read as empty rather than as answers.
	_expect(StrategoLLMClient.extract_content({"choices": [{"message": {"content": "", "reasoning_content": "hold"}}]}) == "hold", "a reply delivered as reasoning_content is still found")
	_expect(StrategoLLMClient.extract_content({"choices": []}) == "", "a response with no choices yields no content rather than an error")

	var bare := StrategoLLMClient.extract_json_object('{"posture": "aggressive"}')
	_expect(String(bare.get("posture", "")) == "aggressive", "a bare JSON object parses")
	# Models wrap JSON in fences and introduce it with a sentence constantly,
	# even when instructed not to; throwing the turn away over that would make
	# LLM factions fail for presentation reasons rather than bad decisions.
	var fenced := StrategoLLMClient.extract_json_object("Here are my orders:\n```json\n{\"posture\": \"defensive\"}\n```\nHope that helps.")
	_expect(String(fenced.get("posture", "")) == "defensive", "a JSON object wrapped in prose and code fences is still recovered")
	var nested := StrategoLLMClient.extract_json_object('{"a": {"b": 2}, "c": 3}')
	_expect(int(nested.get("c", 0)) == 3, "a nested object is read to its true end, not to the first closing brace")
	var braced_string: Dictionary = StrategoLLMClient.extract_json_object('{"msg": "deal? {yes}", "ok": true}')
	_expect(bool(braced_string.get("ok", false)), "a brace inside a string does not truncate the object - alliance chat will contain them")
	_expect(StrategoLLMClient.extract_json_object("no object here").is_empty(), "prose with no JSON yields an empty result rather than a crash")
	_expect(StrategoLLMClient.extract_json_object('{"broken": ').is_empty(), "an unterminated object yields an empty result")
