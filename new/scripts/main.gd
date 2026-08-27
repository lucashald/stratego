extends Control

var game := StrategoGame.new()
var bot := StrategoBotPolicy.new()
var rng := RandomNumberGenerator.new()
var board_view: StrategoBoardView
var status_label: Label
var detail_label: Label
var objective_label: Label
var count_labels: Dictionary = {}
var history: RichTextLabel
var ready_button: Button
var clear_button: Button
var withdraw_button: Button
var ranged_toggle: CheckButton
var leftover_toggle: CheckButton
var privacy_toggle: CheckButton
var spectator_mode := false
var selected_scenario := StrategoGame.SCENARIO_BRIDGE
var session_id := 0


func _ready() -> void:
	rng.randomize()
	_build_interface()
	start_bridge_game()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#09101d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	var title := Label.new()
	title.text = "WEGO FORMATIONS"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#f8df9a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var bridge_button := _make_button("New Bridge Battle")
	bridge_button.pressed.connect(start_bridge_game)
	top.add_child(bridge_button)
	var four_player_button := _make_button("New 4-Player Battle")
	four_player_button.pressed.connect(start_four_player_game)
	top.add_child(four_player_button)
	var watch_button := _make_button("Watch 4 Bots")
	watch_button.pressed.connect(start_spectator_game)
	top.add_child(watch_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)
	board_view = StrategoBoardView.new()
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.order_changed.connect(_on_order_changed)
	board_view.selection_changed.connect(_on_selection_changed)
	body.add_child(board_view)

	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size.x = 340
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(side_scroll)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 320
	side.add_theme_constant_override("separation", 8)
	side_scroll.add_child(side)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color("#f8df9a"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(status_label)
	objective_label = Label.new()
	objective_label.add_theme_color_override("font_color", Color("#9fd8ff"))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(objective_label)
	detail_label = Label.new()
	detail_label.text = "Select a formation and draw its path."
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_color_override("font_color", Color("#b9c7dc"))
	side.add_child(detail_label)

	var action_grid := GridContainer.new()
	action_grid.columns = 2
	action_grid.add_theme_constant_override("h_separation", 8)
	action_grid.add_theme_constant_override("v_separation", 6)
	side.add_child(action_grid)
	ready_button = _make_button("Ready & Resolve")
	ready_button.pressed.connect(_on_ready_pressed)
	action_grid.add_child(ready_button)
	clear_button = _make_button("Clear My Orders")
	clear_button.pressed.connect(_on_clear_orders)
	action_grid.add_child(clear_button)
	withdraw_button = _make_button("Withdraw")
	withdraw_button.pressed.connect(_on_withdraw)
	action_grid.add_child(withdraw_button)

	ranged_toggle = CheckButton.new()
	ranged_toggle.text = "Archer target"
	ranged_toggle.button_pressed = true
	ranged_toggle.tooltip_text = "With an Archer selected, click an adjacent visible enemy to schedule ranged fire."
	ranged_toggle.toggled.connect(_on_ranged_toggled)
	action_grid.add_child(ranged_toggle)
	leftover_toggle = CheckButton.new()
	leftover_toggle.text = "Set leftover move"
	leftover_toggle.tooltip_text = "The next square clicked is the unit's simultaneous one-square leftover move."
	leftover_toggle.toggled.connect(_on_leftover_toggled)
	action_grid.add_child(leftover_toggle)
	privacy_toggle = CheckButton.new()
	privacy_toggle.text = "Private battle details"
	privacy_toggle.button_pressed = true
	privacy_toggle.tooltip_text = "Only players involved in combat receive its full formation details."
	action_grid.add_child(privacy_toggle)

	var counts := GridContainer.new()
	counts.columns = 1
	counts.add_theme_constant_override("h_separation", 16)
	side.add_child(counts)
	var colors := {
		StrategoGame.BLUE: Color("#78a7ff"), StrategoGame.RED: Color("#ff8990"),
		StrategoGame.GREEN: Color("#72e3a7"), StrategoGame.YELLOW: Color("#ffe27a"),
	}
	for player in [StrategoGame.BLUE, StrategoGame.RED, StrategoGame.GREEN, StrategoGame.YELLOW]:
		var label := Label.new()
		label.add_theme_color_override("font_color", colors[player])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		counts.add_child(label)
		count_labels[player] = label

	var rule_title := Label.new()
	rule_title.text = "ROUND ORDER"
	rule_title.add_theme_color_override("font_color", Color("#f8df9a"))
	rule_title.add_theme_font_size_override("font_size", 15)
	side.add_child(rule_title)
	var rules := Label.new()
	rules.text = "1  Simultaneous movement: Light 3 · Medium 2 · Heavy 1\n2  Melee, then simultaneous retreats\n3  Eligible Archers fire simultaneously\n4  One-square leftover movement\n5  End-of-round victory check\n\nTies bounce. Losing retreats. Both end the unit's round. Winning doubles Armor for that combat."
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.add_theme_font_size_override("font_size", 13)
	rules.add_theme_color_override("font_color", Color("#b9c7dc"))
	side.add_child(rules)

	var log_title := Label.new()
	log_title.text = "ROUND LOG"
	log_title.add_theme_color_override("font_color", Color("#f8df9a"))
	log_title.add_theme_font_size_override("font_size", 15)
	side.add_child(log_title)
	history = RichTextLabel.new()
	history.bbcode_enabled = true
	history.scroll_active = true
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.custom_minimum_size.y = 130
	history.add_theme_color_override("default_color", Color("#cbd5e1"))
	side.add_child(history)


func _make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(145, 40)
	return button


func start_bridge_game() -> void:
	session_id += 1
	spectator_mode = false
	selected_scenario = StrategoGame.SCENARIO_BRIDGE
	game = StrategoGame.new()
	game.setup_bridge(rng.randi(), StrategoGame.BLUE, StrategoGame.RED, 20, privacy_toggle.button_pressed)
	_configure_board(false)
	history.clear()
	_log_line("Bridge battle started. You command the Blue attacker.", true)
	_log_line("Red may deploy anywhere north of the river; Blue begins on its board edge.")
	_update_interface()


func start_four_player_game() -> void:
	session_id += 1
	spectator_mode = false
	selected_scenario = StrategoGame.SCENARIO_FOUR_PLAYER
	game = StrategoGame.new()
	game.setup_random(rng.randi(), 4, privacy_toggle.button_pressed)
	_configure_board(false)
	history.clear()
	_log_line("Four-player WEGO battle started. You command Blue.", true)
	_log_line("The four-color fog and private battle-information framework is active.")
	_update_interface()


func start_spectator_game() -> void:
	session_id += 1
	spectator_mode = true
	selected_scenario = StrategoGame.SCENARIO_FOUR_PLAYER
	game = StrategoGame.new()
	game.setup_random(rng.randi(), 4, privacy_toggle.button_pressed)
	_configure_board(true)
	history.clear()
	_log_line("Four-bot simultaneous-order exhibition started.", true)
	_update_interface()
	_run_spectator_round(session_id)


func _configure_board(show_all: bool) -> void:
	board_view.viewing_player = StrategoGame.BLUE
	board_view.reveal_all = show_all
	board_view.interaction_enabled = not show_all
	board_view.prefer_ranged = ranged_toggle.button_pressed
	board_view.leftover_mode = leftover_toggle.button_pressed
	board_view.set_game(game)


func _on_ready_pressed() -> void:
	if spectator_mode or game.game_over or game.phase != StrategoGame.PHASE_PLANNING:
		return
	board_view.clear_selection()
	game.mark_player_ready(StrategoGame.BLUE)
	_plan_unready_bots()
	_resolve_ready_round()


func _plan_unready_bots() -> void:
	for player in game.active_players:
		if player == StrategoGame.BLUE and not spectator_mode:
			continue
		if player in game.ready_players:
			continue
		bot.plan_round(game, player, rng)
		game.mark_player_ready(player)


func _resolve_ready_round() -> void:
	if not game.all_players_ready():
		return
	var resolved_round := game.round_number
	var events: Array[Dictionary] = game.resolve_round()
	_log_line("Round %d resolved: %d movement/combat events." % [resolved_round, events.size()], true)
	for event: Dictionary in events:
		_log_event(event)
		if bool(event.get("combat", false)) and (board_view.reveal_all or StrategoGame.BLUE in event.get("known_to", [])):
			board_view.show_combat(event)
	board_view.clear_selection()
	_update_interface()
	if game.game_over:
		_log_game_end()


func _on_clear_orders() -> void:
	if spectator_mode or game.phase != StrategoGame.PHASE_PLANNING:
		return
	game.clear_player_orders(StrategoGame.BLUE)
	board_view.clear_selection()
	detail_label.text = "Your orders were cleared."
	board_view.queue_redraw()


func _on_withdraw() -> void:
	if spectator_mode or game.game_over:
		return
	var result: Dictionary = game.withdraw_player(StrategoGame.BLUE)
	if bool(result.get("ok", false)):
		_log_line("Blue withdrew with %d current Strength surviving." % int(result.surviving_strength), true)
		_log_game_end()
	_update_interface()


func _on_ranged_toggled(enabled: bool) -> void:
	board_view.prefer_ranged = enabled
	if enabled and leftover_toggle.button_pressed:
		leftover_toggle.button_pressed = false
	board_view.queue_redraw()


func _on_leftover_toggled(enabled: bool) -> void:
	board_view.leftover_mode = enabled
	if enabled and ranged_toggle.button_pressed:
		ranged_toggle.button_pressed = false
	board_view.queue_redraw()


func _on_order_changed(message: String) -> void:
	detail_label.text = message
	_update_interface(false)


func _on_selection_changed(description: String) -> void:
	detail_label.text = description


func _run_spectator_round(active_session: int) -> void:
	if active_session != session_id or not spectator_mode or game.game_over:
		return
	await get_tree().create_timer(0.7).timeout
	if active_session != session_id or not spectator_mode or game.game_over:
		return
	_plan_unready_bots()
	_resolve_ready_round()
	if not game.game_over:
		_run_spectator_round(active_session)


func _update_interface(update_detail: bool = true) -> void:
	if game.game_over:
		status_label.text = "Battle complete"
	elif game.phase == StrategoGame.PHASE_PLANNING:
		status_label.text = "Round %d · Planning" % game.round_number
	else:
		status_label.text = "Round %d · Resolving" % game.round_number
	if game.scenario == StrategoGame.SCENARIO_BRIDGE:
		objective_label.text = "Blue breakthrough: %d/%d current Strength north of river · Defender wins after Round %d" % [game.bridge_strength_across(), game.bridge_strength_target, game.bridge_turn_limit]
	else:
		objective_label.text = "Four-player fog battle · simultaneous orders · last army/team standing"
	for player in count_labels:
		var label: Label = count_labels[player]
		label.visible = player in game.active_players or player in game.eliminated_players
		label.text = "%s · %d units · %d Strength" % [game.player_name(player), game.count_alive(player), game.total_strength(player)]
	ready_button.disabled = spectator_mode or game.game_over or game.phase != StrategoGame.PHASE_PLANNING
	clear_button.disabled = ready_button.disabled
	withdraw_button.disabled = spectator_mode or game.game_over or game.phase != StrategoGame.PHASE_PLANNING
	ranged_toggle.disabled = spectator_mode or game.game_over
	leftover_toggle.disabled = spectator_mode or game.game_over
	if update_detail and game.game_over:
		detail_label.text = "%s won: %s." % [game.player_name(game.winner), game.end_reason.replace("_", " ")]
	board_view.interaction_enabled = not spectator_mode and not game.game_over and game.phase == StrategoGame.PHASE_PLANNING
	board_view.queue_redraw()


func _log_event(event: Dictionary) -> void:
	if not _event_is_known_to_viewer(event):
		return
	var action := String(event.get("action", ""))
	match action:
		"move":
			var piece_id := int(event.get("piece_id", StrategoGame.EMPTY))
			if piece_id >= 0 and piece_id < game.pieces.size() and int(game.pieces[piece_id].player) != StrategoGame.BLUE:
				var impulse := String(event.get("batch", "impulse")).replace("_", " ")
				_log_line("Observed a %s enemy formation moving during %s." % [String(game.pieces[piece_id].weight).capitalize(), impulse])
		"melee", "crossing_battle":
			var ids: Array = event.get("participants", [])
			var labels: Array[String] = []
			for id in ids:
				if id >= 0 and id < game.pieces.size():
					labels.append("%s %s" % [game.player_name(int(game.pieces[id].player)), game.piece_display_code(game.pieces[id])])
			var outcome := "bounce" if int(event.get("winner_id", StrategoGame.EMPTY)) == StrategoGame.EMPTY else "%s wins" % game.player_name(int(game.pieces[int(event.winner_id)].player))
			_log_line("%s: %s → %s." % ["Crossing battle" if action == "crossing_battle" else "Melee", ", ".join(labels), outcome])
		"ranged":
			_log_line("Archer fire dealt %d damage%s." % [int(event.get("defender_damage", 0)), " and destroyed the target" if event.result == "ranged_destroyed" else ""])
		"retreat_battle":
			_log_line("Enemy retreats collided: %s." % String(event.result).replace("_", " "))
		"retreat":
			if event.result == "retreat_destroyed": _log_line("A blocked or off-map retreat destroyed a formation.")
		"bounce":
			if event.get("reason", "") == "allied_collision": _log_line("Allied formations collided and bounced without combat.")


func _event_is_known_to_viewer(event: Dictionary) -> bool:
	if spectator_mode:
		return true
	if bool(event.get("combat", false)):
		return StrategoGame.BLUE in event.get("known_to", [])
	if String(event.get("action", "")) == "move":
		return StrategoGame.BLUE in event.get("visible_to", [])
	var ids: Array = event.get("participants", []).duplicate()
	if event.has("piece_id"):
		ids.append(int(event.piece_id))
	for id in ids:
		if id >= 0 and id < game.pieces.size() and int(game.pieces[id].player) == StrategoGame.BLUE:
			return true
	return false


func _log_game_end() -> void:
	if game.winner == StrategoGame.DRAW:
		_log_line("Battle ended without a sole winner: %s." % game.end_reason.replace("_", " "), true)
	else:
		_log_line("%s wins by %s." % [game.player_name(game.winner), game.end_reason.replace("_", " ")], true)


func _log_line(text_value: String, important: bool = false) -> void:
	if history == null:
		return
	history.append_text(("[color=#f8df9a][b]%s[/b][/color]" if important else "%s") % text_value)
	history.append_text("\n")
	history.scroll_to_line(maxi(0, history.get_line_count() - 1))
