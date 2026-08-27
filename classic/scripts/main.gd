extends Control

const MODEL_PATH := StrategoBotPolicy.DEFAULT_USER_PATH

var game := StrategoGame.new()
var bot := StrategoBotPolicy.new()
var trainer := SelfPlayTrainer.new()
var rng := RandomNumberGenerator.new()
var board_view: StrategoBoardView
var status_label: Label
var detail_label: Label
var combat_notice_label: Label
var bot_label: Label
var count_labels: Dictionary = {}
var history: RichTextLabel
var player_count_selector: OptionButton
var scout_range_selector: OptionButton
var battle_privacy_toggle: CheckButton
var model_selector: OptionButton
var refresh_models_button: Button
var train_button: Button
var human_button: Button
var watch_button: Button
var training := false
var spectator_mode := false
var session_id := 0
var active_model_path := MODEL_PATH
var active_model_label := "Current champion"
var selected_player_count := 4
var selected_private_battles := true
var selected_scout_move_limit := 0


func _ready() -> void:
	rng.randomize()
	if FileAccess.file_exists(MODEL_PATH):
		bot = StrategoBotPolicy.load_from_path(MODEL_PATH)
	elif FileAccess.file_exists("res://trained_bot.json"):
		bot = StrategoBotPolicy.load_from_path("res://trained_bot.json")
		active_model_path = "res://trained_bot.json"
		active_model_label = "Project model"
	_archive_existing_models()
	_build_interface()
	_refresh_model_selector(active_model_path)
	start_human_game()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#09101d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	root.add_child(top)
	var title := Label.new()
	title.text = "MULTIPLAYER STRATEGO"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#f8df9a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	human_button = _make_button("New Human Game")
	human_button.pressed.connect(start_human_game)
	top.add_child(human_button)
	watch_button = _make_button("Watch Self-Play")
	watch_button.pressed.connect(start_spectator_game)
	top.add_child(watch_button)
	train_button = _make_button("Train & Challenge (32)")
	train_button.pressed.connect(train_bot.bind(32))
	top.add_child(train_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)

	board_view = StrategoBoardView.new()
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.move_requested.connect(_on_human_move)
	board_view.selection_changed.connect(_on_selection_changed)
	body.add_child(board_view)

	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size.x = 330
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(side_scroll)
	var side_panel := VBoxContainer.new()
	side_panel.custom_minimum_size.x = 310
	side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_panel.add_theme_constant_override("separation", 8)
	side_scroll.add_child(side_panel)

	var player_count_row := HBoxContainer.new()
	player_count_row.add_theme_constant_override("separation", 10)
	side_panel.add_child(player_count_row)
	var player_count_title := Label.new()
	player_count_title.text = "PLAYERS"
	player_count_title.add_theme_color_override("font_color", Color("#f8df9a"))
	player_count_title.add_theme_font_size_override("font_size", 16)
	player_count_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_count_row.add_child(player_count_title)
	player_count_selector = OptionButton.new()
	player_count_selector.custom_minimum_size = Vector2(120, 38)
	for player_count in range(2, 5):
		player_count_selector.add_item("%d players" % player_count)
		player_count_selector.set_item_metadata(player_count_selector.item_count - 1, player_count)
	player_count_selector.select(2)
	player_count_selector.item_selected.connect(_on_player_count_selected)
	player_count_row.add_child(player_count_selector)

	var scout_range_row := HBoxContainer.new()
	scout_range_row.add_theme_constant_override("separation", 10)
	side_panel.add_child(scout_range_row)
	var scout_range_title := Label.new()
	scout_range_title.text = "SCOUT RANGE"
	scout_range_title.add_theme_color_override("font_color", Color("#f8df9a"))
	scout_range_title.add_theme_font_size_override("font_size", 16)
	scout_range_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scout_range_row.add_child(scout_range_title)
	scout_range_selector = OptionButton.new()
	scout_range_selector.custom_minimum_size = Vector2(120, 38)
	scout_range_selector.add_item("Unlimited")
	scout_range_selector.set_item_metadata(0, 0)
	for scout_range in range(1, 11):
		scout_range_selector.add_item("%d square%s" % [scout_range, "" if scout_range == 1 else "s"])
		scout_range_selector.set_item_metadata(scout_range_selector.item_count - 1, scout_range)
	scout_range_selector.select(0)
	scout_range_selector.tooltip_text = "Maximum number of squares a Scout may move in one turn."
	scout_range_selector.item_selected.connect(_on_scout_range_selected)
	scout_range_row.add_child(scout_range_selector)

	battle_privacy_toggle = CheckButton.new()
	battle_privacy_toggle.text = "Private battle results"
	battle_privacy_toggle.button_pressed = true
	battle_privacy_toggle.tooltip_text = "Only the two players in a battle learn the pieces' ranks."
	battle_privacy_toggle.toggled.connect(_on_battle_privacy_toggled)
	side_panel.add_child(battle_privacy_toggle)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color("#f8df9a"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_panel.add_child(status_label)

	detail_label = Label.new()
	detail_label.text = "Select one of your movable pieces."
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_color_override("font_color", Color("#b9c7dc"))
	side_panel.add_child(detail_label)

	combat_notice_label = Label.new()
	combat_notice_label.text = "LAST COMBAT — None yet"
	combat_notice_label.custom_minimum_size.y = 38
	combat_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat_notice_label.add_theme_color_override("font_color", Color("#f8df9a"))
	side_panel.add_child(combat_notice_label)

	var counts := GridContainer.new()
	counts.columns = 2
	counts.add_theme_constant_override("h_separation", 20)
	counts.add_theme_constant_override("v_separation", 4)
	side_panel.add_child(counts)
	var count_colors := {
		StrategoGame.BLUE: Color("#78a7ff"),
		StrategoGame.RED: Color("#ff8990"),
		StrategoGame.GREEN: Color("#72e3a7"),
		StrategoGame.YELLOW: Color("#ffe27a"),
	}
	for player in [StrategoGame.BLUE, StrategoGame.RED, StrategoGame.GREEN, StrategoGame.YELLOW]:
		var count_label := Label.new()
		count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count_label.add_theme_color_override("font_color", count_colors[player])
		counts.add_child(count_label)
		count_labels[player] = count_label

	var model_title := Label.new()
	model_title.text = "OPPONENT MODEL"
	model_title.add_theme_color_override("font_color", Color("#f8df9a"))
	model_title.add_theme_font_size_override("font_size", 16)
	side_panel.add_child(model_title)
	var model_row := HBoxContainer.new()
	model_row.add_theme_constant_override("separation", 6)
	side_panel.add_child(model_row)
	model_selector = OptionButton.new()
	model_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_selector.custom_minimum_size.y = 38
	model_selector.fit_to_longest_item = false
	model_selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	model_selector.item_selected.connect(_on_model_selected)
	model_row.add_child(model_selector)
	refresh_models_button = Button.new()
	refresh_models_button.text = "Refresh"
	refresh_models_button.custom_minimum_size = Vector2(72, 38)
	refresh_models_button.pressed.connect(_on_refresh_models)
	model_row.add_child(refresh_models_button)

	bot_label = Label.new()
	bot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bot_label.add_theme_color_override("font_color", Color("#91a4bf"))
	side_panel.add_child(bot_label)

	var rule_title := Label.new()
	rule_title.text = "QUICK RULES"
	rule_title.add_theme_color_override("font_color", Color("#f8df9a"))
	rule_title.add_theme_font_size_override("font_size", 16)
	side_panel.add_child(rule_title)
	var rules := Label.new()
	rules.text = "WIN — Be the last army standing\nELIMINATION — Lose your Flag or all legal moves\nDRAW — 240 moves without combat\nDRAW — 1,200 total moves\n\nFOG — Enemies appear within 4 squares\nTurns follow the active colors clockwise\nHigher rank wins · Miner (3) defuses Bomb\nSpy (1) beats Marshal (10) when attacking\nScout (2) range uses the match setting"
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.add_theme_font_size_override("font_size", 13)
	rules.add_theme_color_override("font_color", Color("#b9c7dc"))
	side_panel.add_child(rules)

	var log_title := Label.new()
	log_title.text = "BATTLE LOG"
	log_title.add_theme_color_override("font_color", Color("#f8df9a"))
	log_title.add_theme_font_size_override("font_size", 16)
	side_panel.add_child(log_title)
	history = RichTextLabel.new()
	history.bbcode_enabled = true
	history.fit_content = false
	history.scroll_active = true
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.custom_minimum_size.y = 95
	history.add_theme_color_override("default_color", Color("#cbd5e1"))
	side_panel.add_child(history)


func _make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(145, 42)
	return button


func _on_player_count_selected(index: int) -> void:
	if training or index < 0 or index >= player_count_selector.item_count:
		return
	selected_player_count = int(player_count_selector.get_item_metadata(index))
	trainer.player_count = selected_player_count
	start_human_game()


func _on_scout_range_selected(index: int) -> void:
	if training or index < 0 or index >= scout_range_selector.item_count:
		return
	selected_scout_move_limit = int(scout_range_selector.get_item_metadata(index))
	trainer.scout_move_limit = selected_scout_move_limit
	start_human_game()


func _scout_range_description() -> String:
	if selected_scout_move_limit == 0:
		return "unlimited"
	return "limited to %d square%s" % [selected_scout_move_limit, "" if selected_scout_move_limit == 1 else "s"]


func _on_battle_privacy_toggled(enabled: bool) -> void:
	if training:
		return
	selected_private_battles = enabled
	trainer.private_battle_results = selected_private_battles
	start_human_game()


func _archive_existing_models() -> void:
	for path in [StrategoBotPolicy.DEFAULT_USER_PATH, StrategoBotPolicy.PREVIOUS_CHAMPION_PATH, StrategoBotPolicy.CHALLENGER_PATH]:
		if FileAccess.file_exists(path):
			StrategoBotPolicy.load_from_path(path).save_archive()


func _refresh_model_selector(preferred_path: String = "") -> void:
	if model_selector == null:
		return
	var target_path := preferred_path if not preferred_path.is_empty() else active_model_path
	var models := StrategoBotPolicy.list_saved_models()
	model_selector.clear()
	var selected_index := 0
	for model: Dictionary in models:
		var index := model_selector.item_count
		model_selector.add_item(model.label)
		model_selector.set_item_metadata(index, model.path)
		if model.path == target_path:
			selected_index = index
	if model_selector.item_count > 0:
		model_selector.select(selected_index)
		active_model_path = str(model_selector.get_item_metadata(selected_index))
		active_model_label = model_selector.get_item_text(selected_index).get_slice(" — ", 0)
	if train_button != null:
		train_button.disabled = training or active_model_path != MODEL_PATH


func _on_model_selected(index: int) -> void:
	if training or index < 0 or index >= model_selector.item_count:
		return
	var selected_path := str(model_selector.get_item_metadata(index))
	if not FileAccess.file_exists(selected_path):
		_refresh_model_selector(MODEL_PATH)
		return
	active_model_path = selected_path
	active_model_label = model_selector.get_item_text(index).get_slice(" — ", 0)
	bot = StrategoBotPolicy.load_from_path(selected_path)
	start_human_game()
	_log_line("Opponent selected: %s, generation %d." % [active_model_label, bot.generation])
	train_button.disabled = active_model_path != MODEL_PATH
	if active_model_path != MODEL_PATH:
		detail_label.text = "Archive selected for play. Select Current champion to enable training."


func _on_refresh_models() -> void:
	_refresh_model_selector(active_model_path)
	if FileAccess.file_exists(active_model_path):
		bot = StrategoBotPolicy.load_from_path(active_model_path)
		start_human_game()
		_log_line("Model list refreshed. Using %s, generation %d." % [active_model_label, bot.generation])


func start_human_game() -> void:
	session_id += 1
	spectator_mode = false
	game = StrategoGame.new()
	game.setup_random(rng.randi(), selected_player_count, selected_private_battles, selected_scout_move_limit)
	board_view.viewing_player = StrategoGame.BLUE
	board_view.reveal_all = false
	board_view.interaction_enabled = not training
	board_view.set_game(game)
	history.clear()
	combat_notice_label.text = "LAST COMBAT — None yet"
	var opponent_names: Array[String] = []
	for player in game.active_players:
		if player != StrategoGame.BLUE:
			opponent_names.append(game.player_name(player))
	_log_line("A %d-player battle begins. You command Blue against %s." % [selected_player_count, ", ".join(opponent_names)])
	_log_line("Battle ranks are %s." % ("private to the two participants" if selected_private_battles else "public to every player"))
	_log_line("Scout movement is %s." % _scout_range_description())
	_log_line("Fog of war hides enemies more than %d squares from your army." % game.vision_range)
	_update_interface()
	if game.current_player != StrategoGame.BLUE:
		_run_computer_turn(session_id)


func start_spectator_game() -> void:
	session_id += 1
	spectator_mode = true
	game = StrategoGame.new()
	game.setup_random(rng.randi(), selected_player_count, selected_private_battles, selected_scout_move_limit)
	board_view.reveal_all = true
	board_view.interaction_enabled = false
	board_view.set_game(game)
	history.clear()
	combat_notice_label.text = "LAST COMBAT — None yet"
	_log_line("%d-player self-play exhibition started. Every army uses the selected policy." % selected_player_count)
	_update_interface()
	_run_computer_turn(session_id)


func _on_human_move(from: Vector2i, to: Vector2i) -> void:
	if training or spectator_mode or game.current_player != StrategoGame.BLUE:
		return
	var event := game.apply_move(from, to)
	board_view.show_combat(event)
	_log_event(event)
	_update_interface()
	if not game.game_over:
		_run_computer_turn(session_id, 1.85 if bool(event.get("combat", false)) else 0.42)


func _run_computer_turn(active_session: int, delay_seconds: float = -1.0) -> void:
	if game.game_over or training or active_session != session_id:
		return
	board_view.interaction_enabled = false
	_update_interface()
	var wait_time := delay_seconds if delay_seconds >= 0.0 else (0.22 if spectator_mode else 0.42)
	await get_tree().create_timer(wait_time).timeout
	if active_session != session_id or game.game_over or training:
		return
	var move := bot.choose_move(game, game.current_player, rng)
	if move.is_empty():
		var event := game.eliminate_immobilized_current_player()
		_log_event(event)
	else:
		var event := game.apply_move(move.from, move.to)
		board_view.show_combat(event)
		_log_event(event)
		var next_delay := 1.85 if bool(event.get("combat", false)) else 0.22
		_update_interface()
		if spectator_mode and not game.game_over:
			_run_computer_turn(active_session, next_delay)
		elif not spectator_mode and not game.game_over and game.current_player != StrategoGame.BLUE:
			_run_computer_turn(active_session, next_delay)
		return
	_update_interface()


func train_bot(number_of_games: int) -> void:
	if training or active_model_path != MODEL_PATH:
		return
	session_id += 1
	training = true
	trainer.player_count = selected_player_count
	trainer.private_battle_results = selected_private_battles
	trainer.scout_move_limit = selected_scout_move_limit
	var reigning_champion := bot.duplicate_policy()
	reigning_champion.save_archive()
	_set_buttons_disabled(true)
	board_view.interaction_enabled = false
	_log_line("Training started: %d headless %d-player matches with %s battle results and %s Scout movement." % [number_of_games, selected_player_count, "private" if selected_private_battles else "public", _scout_range_description()])
	for i in number_of_games:
		var result := trainer.train_iteration(bot, rng, trainer.total_matches)
		status_label.text = "Training… %d / %d" % [i + 1, number_of_games]
		bot_label.text = "%s • Gen %d • %d games\nSession: %d matches • %d upgrades" % [active_model_label, bot.generation, bot.games_trained, trainer.total_matches, trainer.accepted_candidates]
		if result.accepted:
			bot.save_archive()
			_log_line("Match %d: candidate upgraded the bot (%d plies)." % [i + 1, result.plies])
		await get_tree().process_frame
	_log_line("Training complete. The contender is entering a seat-balanced title match.")
	var title_result: Dictionary = await _evaluate_title_match(bot, reigning_champion, 40)
	var title_message := ""
	var title_won := int(title_result.score_margin) > 0 or (int(title_result.score_margin) == 0 and float(title_result.average_material) > 2.0)
	if title_won:
		reigning_champion.save_to_path(StrategoBotPolicy.PREVIOUS_CHAMPION_PATH)
		bot.save_to_path(MODEL_PATH)
		bot.save_archive()
		title_message = "New champion! Contender earned %d seat wins against %d incumbent seat wins, with %d draws and %+.1f average material." % [title_result.challenger_wins, title_result.incumbent_wins, title_result.draws, title_result.average_material]
	else:
		bot.copy_from(reigning_champion)
		title_message = "Champion defended: %d incumbent seat wins to %d contender seat wins, with %d draws. The playable bot was not replaced." % [title_result.incumbent_wins, title_result.challenger_wins, title_result.draws]
	trainer.reset_pending()
	training = false
	active_model_path = MODEL_PATH
	active_model_label = "Current champion"
	_refresh_model_selector(MODEL_PATH)
	_set_buttons_disabled(false)
	start_human_game()
	_log_line(title_message)


func _evaluate_title_match(contender: StrategoBotPolicy, champion: StrategoBotPolicy, matches: int) -> Dictionary:
	var roster := StrategoGame.players_for_count(selected_player_count)
	var match_count := maxi(roster.size(), matches)
	var remainder := match_count % roster.size()
	if remainder != 0:
		match_count += roster.size() - remainder
	var contender_wins := 0
	var champion_wins := 0
	var draws := 0
	var material_total := 0.0
	var pair_seed := 0
	for i in match_count:
		if i % roster.size() == 0:
			pair_seed = rng.randi()
		var contender_side: int = roster[i % roster.size()]
		var result := trainer.play_match(contender, champion, contender_side, pair_seed)
		material_total += float(result.material_delta)
		if int(result.candidate_result) > 0:
			contender_wins += 1
		elif int(result.candidate_result) < 0:
			champion_wins += 1
		else:
			draws += 1
		status_label.text = "Title match… %d / %d" % [i + 1, match_count]
		await get_tree().process_frame
	return {
		"challenger_wins": contender_wins,
		"incumbent_wins": champion_wins,
		"draws": draws,
		"score_margin": contender_wins * (roster.size() - 1) - champion_wins,
		"average_material": material_total / float(match_count),
	}


func _set_buttons_disabled(value: bool) -> void:
	train_button.disabled = value or active_model_path != MODEL_PATH
	human_button.disabled = value
	watch_button.disabled = value
	model_selector.disabled = value
	refresh_models_button.disabled = value
	player_count_selector.disabled = value
	scout_range_selector.disabled = value
	battle_privacy_toggle.disabled = value


func _on_selection_changed(description: String) -> void:
	detail_label.text = description


func _update_interface() -> void:
	board_view.queue_redraw()
	for player in [StrategoGame.BLUE, StrategoGame.RED, StrategoGame.GREEN, StrategoGame.YELLOW]:
		count_labels[player].visible = player in game.active_players or player in game.eliminated_players
		var state := "eliminated" if player in game.eliminated_players else "%d pieces" % game.count_alive(player)
		count_labels[player].text = "%s: %s" % [game.player_name(player), state]
	bot_label.text = "%s • Gen %d • %d games\nSession: %d matches • %d upgrades" % [active_model_label, bot.generation, bot.games_trained, trainer.total_matches, trainer.accepted_candidates]
	if game.game_over:
		board_view.interaction_enabled = false
		match game.end_reason:
			"no_legal_moves":
				status_label.text = "%s wins • %s has no legal moves" % [game.player_name(game.winner), game.player_name(game.last_eliminated_player)]
				detail_label.text = "A player with no legal move loses by immobilization."
			"no_combat_limit":
				status_label.text = "Draw • %d moves without combat" % game.max_quiet_plies
				detail_label.text = "The no-combat limit prevents endless maneuvering."
			"move_limit":
				status_label.text = "Draw • %d-move limit" % game.max_plies
				detail_label.text = "The total move limit was reached."
			"flag_captured":
				status_label.text = "%s wins • Last army standing" % game.player_name(game.winner)
				detail_label.text = "%s was the final army eliminated by Flag capture." % game.player_name(game.last_eliminated_player)
			"last_player_standing":
				status_label.text = "%s wins • Last army standing" % game.player_name(game.winner)
				detail_label.text = "Every rival army has been eliminated."
			_:
				status_label.text = "Draw" if game.winner == StrategoGame.DRAW else "%s wins!" % game.player_name(game.winner)
		return
	if spectator_mode:
		status_label.text = "Self-play • %s to move" % game.player_name(game.current_player)
		return
	if game.current_player == StrategoGame.BLUE:
		status_label.text = "Your turn • Blue"
		board_view.interaction_enabled = not training
	else:
		status_label.text = "Computer is thinking…"
		board_view.interaction_enabled = false


func _log_event(event: Dictionary) -> void:
	if not event.get("ok", false):
		return
	var player_name := game.player_name(event.player)
	# Battles remain global reports under the separate private/public result rule.
	# Fog suppresses only ordinary movement that happened outside the viewer's sight.
	var can_observe_event: bool = spectator_mode or bool(event.get("combat", false)) or StrategoGame.BLUE in event.get("visible_to", [])
	var coordinate := ""
	if event.to.x >= 0:
		coordinate = "%s%d" % [String.chr(65 + event.to.x), event.to.y + 1]
	if event.result == "immobilized":
		pass
	elif not can_observe_event:
		pass
	elif not event.combat:
		_log_line("%s moves to %s." % [player_name, coordinate])
	else:
		var knows_ranks: bool = spectator_mode or (StrategoGame.BLUE in event.get("known_to", []))
		if knows_ranks:
			var attacker_name: String = StrategoGame.PIECE_NAMES[event.attacker_type]
			var defender_name: String = StrategoGame.PIECE_NAMES[event.defender_type]
			var outcome := "both pieces are destroyed"
			if event.result == "attacker":
				outcome = "%s survives; %s is destroyed" % [attacker_name, defender_name]
			elif event.result == "defender":
				outcome = "%s is destroyed; %s survives" % [attacker_name, defender_name]
			combat_notice_label.text = "LAST COMBAT — %s %s vs %s: %s." % [player_name, attacker_name, defender_name, outcome]
			_log_line("COMBAT — %s %s attacks %s at %s: %s." % [player_name, attacker_name, defender_name, coordinate, outcome], true)
		else:
			var defender_player_name := game.player_name(event.defender_player)
			var public_outcome := "both armies lose a piece"
			if event.result == "attacker":
				public_outcome = "%s's piece survives" % player_name
			elif event.result == "defender":
				public_outcome = "%s's piece survives" % defender_player_name
			combat_notice_label.text = "LAST COMBAT — %s attacks %s at %s: %s • ranks private." % [player_name, defender_player_name, coordinate, public_outcome]
			_log_line("COMBAT — %s attacks %s at %s: %s; ranks private." % [player_name, defender_player_name, coordinate, public_outcome], true)
	for elimination: Dictionary in event.get("eliminations", []):
		var reason := "Flag captured" if elimination.reason == "flag_captured" else "No legal moves"
		_log_line("ELIMINATED — %s • %s." % [game.player_name(elimination.player), reason], true)
	if bool(event.get("game_over", false)):
		_log_game_end()


func _log_game_end() -> void:
	match game.end_reason:
		"no_legal_moves":
			_log_line("GAME OVER — %s wins after %s is immobilized." % [game.player_name(game.winner), game.player_name(game.last_eliminated_player)], true)
		"no_combat_limit":
			_log_line("DRAW — %d consecutive moves without combat." % game.max_quiet_plies, true)
		"move_limit":
			_log_line("DRAW — %d-move limit reached." % game.max_plies, true)
		"flag_captured":
			_log_line("GAME OVER — %s is the last army standing." % game.player_name(game.winner), true)
		"last_player_standing":
			_log_line("GAME OVER — %s is the last army standing." % game.player_name(game.winner), true)


func _log_line(text_value: String, important: bool = false) -> void:
	if important:
		history.append_text("[color=#f8df9a][b]• %s[/b][/color]\n" % text_value)
	else:
		history.append_text("• %s\n" % text_value)
	history.scroll_to_line(maxi(0, history.get_line_count() - 1))
