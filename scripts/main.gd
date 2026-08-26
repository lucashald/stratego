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
var blue_count_label: Label
var red_count_label: Label
var history: RichTextLabel
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
	title.text = "STRATEGO"
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

	var counts := HBoxContainer.new()
	counts.add_theme_constant_override("separation", 20)
	side_panel.add_child(counts)
	blue_count_label = Label.new()
	blue_count_label.add_theme_color_override("font_color", Color("#78a7ff"))
	counts.add_child(blue_count_label)
	red_count_label = Label.new()
	red_count_label.add_theme_color_override("font_color", Color("#ff8990"))
	counts.add_child(red_count_label)

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
	rules.text = "WIN — Capture the enemy Flag\nWIN — Opponent has no legal moves\nDRAW — 120 moves without combat\nDRAW — 500 total moves\n\nHigher rank wins · Miner (3) defuses Bomb\nSpy (1) beats Marshal (10) when attacking\nScout (2) moves any clear distance"
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
	game.setup_random(rng.randi())
	board_view.viewing_player = StrategoGame.BLUE
	board_view.reveal_all = false
	board_view.interaction_enabled = not training
	board_view.set_game(game)
	history.clear()
	combat_notice_label.text = "LAST COMBAT — None yet"
	_log_line("A new battle begins. You command Blue.")
	_update_interface()
	if game.current_player == StrategoGame.RED:
		_run_computer_turn(session_id)


func start_spectator_game() -> void:
	session_id += 1
	spectator_mode = true
	game = StrategoGame.new()
	game.setup_random(rng.randi())
	board_view.reveal_all = true
	board_view.interaction_enabled = false
	board_view.set_game(game)
	history.clear()
	combat_notice_label.text = "LAST COMBAT — None yet"
	_log_line("Self-play exhibition started. Both armies use the trained policy.")
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
		game.game_over = true
		game.winner = game.other_player(game.current_player)
		game.end_reason = "no_legal_moves"
	else:
		var event := game.apply_move(move.from, move.to)
		board_view.show_combat(event)
		_log_event(event)
		var next_delay := 1.85 if bool(event.get("combat", false)) else 0.22
		_update_interface()
		if spectator_mode and not game.game_over:
			_run_computer_turn(active_session, next_delay)
		elif not spectator_mode and not game.game_over and game.current_player == StrategoGame.RED:
			_run_computer_turn(active_session, next_delay)
		return
	_update_interface()


func train_bot(number_of_games: int) -> void:
	if training or active_model_path != MODEL_PATH:
		return
	session_id += 1
	training = true
	var reigning_champion := bot.duplicate_policy()
	reigning_champion.save_archive()
	_set_buttons_disabled(true)
	board_view.interaction_enabled = false
	_log_line("Training started: %d headless self-play matches." % number_of_games)
	for i in number_of_games:
		var result := trainer.train_iteration(bot, rng, trainer.total_matches)
		status_label.text = "Training… %d / %d" % [i + 1, number_of_games]
		bot_label.text = "%s • Gen %d • %d games\nSession: %d matches • %d upgrades" % [active_model_label, bot.generation, bot.games_trained, trainer.total_matches, trainer.accepted_candidates]
		if result.accepted:
			bot.save_archive()
			_log_line("Match %d: candidate upgraded the bot (%d plies)." % [i + 1, result.plies])
		await get_tree().process_frame
	_log_line("Training complete. The contender is entering a 40-game title match.")
	var title_result: Dictionary = await _evaluate_title_match(bot, reigning_champion, 40)
	var title_message := ""
	if int(title_result.score_margin) > 0:
		reigning_champion.save_to_path(StrategoBotPolicy.PREVIOUS_CHAMPION_PATH)
		bot.save_to_path(MODEL_PATH)
		bot.save_archive()
		title_message = "New champion! Contender won %d–%d with %d draws." % [title_result.challenger_wins, title_result.incumbent_wins, title_result.draws]
	else:
		bot.copy_from(reigning_champion)
		title_message = "Champion defended %d–%d with %d draws. The playable bot was not replaced." % [title_result.incumbent_wins, title_result.challenger_wins, title_result.draws]
	trainer.reset_pending()
	training = false
	active_model_path = MODEL_PATH
	active_model_label = "Current champion"
	_refresh_model_selector(MODEL_PATH)
	_set_buttons_disabled(false)
	start_human_game()
	_log_line(title_message)


func _evaluate_title_match(contender: StrategoBotPolicy, champion: StrategoBotPolicy, matches: int) -> Dictionary:
	var contender_wins := 0
	var champion_wins := 0
	var draws := 0
	var material_total := 0.0
	var pair_seed := 0
	for i in matches:
		if i % 2 == 0:
			pair_seed = rng.randi()
		var contender_side := StrategoGame.BLUE if i % 2 == 0 else StrategoGame.RED
		var result := trainer.play_match(contender, champion, contender_side, pair_seed)
		material_total += float(result.material_delta)
		if int(result.candidate_result) > 0:
			contender_wins += 1
		elif int(result.candidate_result) < 0:
			champion_wins += 1
		else:
			draws += 1
		status_label.text = "Title match… %d / %d" % [i + 1, matches]
		await get_tree().process_frame
	return {
		"challenger_wins": contender_wins,
		"incumbent_wins": champion_wins,
		"draws": draws,
		"score_margin": contender_wins - champion_wins,
		"average_material": material_total / float(matches),
	}


func _set_buttons_disabled(value: bool) -> void:
	train_button.disabled = value or active_model_path != MODEL_PATH
	human_button.disabled = value
	watch_button.disabled = value
	model_selector.disabled = value
	refresh_models_button.disabled = value


func _on_selection_changed(description: String) -> void:
	detail_label.text = description


func _update_interface() -> void:
	board_view.queue_redraw()
	blue_count_label.text = "Blue: %d" % game.count_alive(StrategoGame.BLUE)
	red_count_label.text = "Red: %d" % game.count_alive(StrategoGame.RED)
	bot_label.text = "%s • Gen %d • %d games\nSession: %d matches • %d upgrades" % [active_model_label, bot.generation, bot.games_trained, trainer.total_matches, trainer.accepted_candidates]
	if game.game_over:
		board_view.interaction_enabled = false
		match game.end_reason:
			"no_legal_moves":
				var losing_player := game.other_player(game.winner)
				status_label.text = "%s wins • %s has no legal moves" % [game.player_name(game.winner), game.player_name(losing_player)]
				detail_label.text = "A player with no legal move loses by immobilization."
			"no_combat_limit":
				status_label.text = "Draw • %d moves without combat" % game.max_quiet_plies
				detail_label.text = "The no-combat limit prevents endless maneuvering."
			"move_limit":
				status_label.text = "Draw • %d-move limit" % game.max_plies
				detail_label.text = "The total move limit was reached."
			"flag_captured":
				status_label.text = "%s wins • Flag captured" % game.player_name(game.winner)
				detail_label.text = "Capturing the enemy Flag ends the game immediately."
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
	var coordinate := "%s%d" % [String.chr(65 + event.to.x), event.to.y + 1]
	if not event.combat:
		_log_line("%s moves to %s." % [player_name, coordinate])
	else:
		var attacker_name: String = StrategoGame.PIECE_NAMES[event.attacker_type]
		var defender_name: String = StrategoGame.PIECE_NAMES[event.defender_type]
		var outcome := "both pieces are destroyed"
		if event.result == "attacker":
			outcome = "%s survives; %s is destroyed" % [attacker_name, defender_name]
		elif event.result == "defender":
			outcome = "%s is destroyed; %s survives" % [attacker_name, defender_name]
		combat_notice_label.text = "LAST COMBAT — %s %s vs %s: %s." % [player_name, attacker_name, defender_name, outcome]
		_log_line("COMBAT — %s %s attacks %s at %s: %s." % [player_name, attacker_name, defender_name, coordinate, outcome], true)
	if bool(event.get("game_over", false)):
		_log_game_end()


func _log_game_end() -> void:
	match game.end_reason:
		"no_legal_moves":
			_log_line("GAME OVER — %s has no legal moves and loses." % game.player_name(game.other_player(game.winner)), true)
		"no_combat_limit":
			_log_line("DRAW — %d consecutive moves without combat." % game.max_quiet_plies, true)
		"move_limit":
			_log_line("DRAW — %d-move limit reached." % game.max_plies, true)
		"flag_captured":
			_log_line("GAME OVER — %s captured the Flag." % game.player_name(game.winner), true)


func _log_line(text_value: String, important: bool = false) -> void:
	if important:
		history.append_text("[color=#f8df9a][b]• %s[/b][/color]\n" % text_value)
	else:
		history.append_text("• %s\n" % text_value)
	history.scroll_to_line(maxi(0, history.get_line_count() - 1))
