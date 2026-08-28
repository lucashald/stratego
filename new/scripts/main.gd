extends Control

const HUD_BLUE := Color("#79b9ff")
const HUD_GOLD := Color("#b79254")
const PANEL_BG := Color(0.025, 0.055, 0.07, 0.93)
const LAST_REPLAY_PATH := "user://replays/last_replay.json"

var game := StrategoGame.new()
var bot := StrategoBotPolicy.new()
# When set, this army is driven over the MCP bridge instead of by the bot, so a
# remote opponent can play the real app rather than a headless copy of it.
var remote_bridge: StrategoMCPBridge = null
var rng := RandomNumberGenerator.new()
var board_view: StrategoBoardView

var phase_title: Label
var phase_subtitle: Label
var units_label: Label
var objective_label: Label
var objective_progress: ProgressBar
var detail_label: Label
var detail_toast: PanelContainer
var detail_help_hidden := false
var ready_button: Button
var undo_button: Button
var cancel_all_button: Button
var settings_button: Button
var planning_controls: Control
var playback_controls: Control
var settings_drawer: PanelContainer
var clear_button: Button
var withdraw_button: Button
var export_replay_button: Button
var replay_last_button: Button
var ranged_toggle: CheckButton
var leftover_toggle: CheckButton
var privacy_toggle: CheckButton
var count_labels: Dictionary = {}
var history: RichTextLabel
var settings_history: RichTextLabel

var timeline_panel: PanelContainer
var timeline_stages: Array[PanelContainer] = []
var timeline_labels: Array[Label] = []
var inspector_panel: PanelContainer
var inspector_title: Label
var inspector_stats: RichTextLabel
var inspector_order: Label
var group_move_controls: VBoxContainer
var group_move_title: Label
var battle_panel: PanelContainer
var battle_title: Label
var battle_body: RichTextLabel
var event_panel: PanelContainer

var spectator_mode := false
var replay_view_mode := false
var selected_scenario := StrategoGame.SCENARIO_BRIDGE
var session_id := 0
var resolution_mode := false
var resolution_events: Array[Dictionary] = []
var resolution_index := 0
var presentation_paused := false
var presentation_speed := 1.0
var playback_pause_button: Button
var zoom_label: Label


func _ready() -> void:
	rng.randomize()
	_build_interface()
	start_bridge_game()
	_start_remote_bridge()


## Opens the command bridge when launched with --remote, so a second commander
## can play one army over the network while this window plays the other.
func _start_remote_bridge() -> void:
	var arguments := OS.get_cmdline_user_args()
	if "--remote" not in arguments: return
	var port := StrategoMCPBridge.DEFAULT_PORT
	var index := arguments.find("--port")
	if index >= 0 and index + 1 < arguments.size(): port = int(arguments[index + 1])
	remote_bridge = StrategoMCPBridge.new()
	remote_bridge.game = game
	remote_bridge.bot = bot
	remote_bridge.controlled_player = StrategoGame.RED
	remote_bridge.player_committed.connect(_on_remote_committed)
	add_child(remote_bridge)
	if remote_bridge.start(port) != OK:
		remote_bridge.queue_free()
		remote_bridge = null
		_log_line("Could not open the command bridge on port %d: something else is already listening there. This window is playing against the bot." % port, true)
		return
	_log_line("Remote commander may connect on port %d and will play Red." % port, true)


func _on_remote_committed(_player: int) -> void:
	if resolution_mode or game.game_over: return
	if game.all_players_ready(): _resolve_ready_round()


func _build_interface() -> void:
	board_view = StrategoBoardView.new()
	board_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_view.order_changed.connect(_on_order_changed)
	board_view.examine_requested.connect(_on_examine_requested)
	board_view.selection_changed.connect(_on_selection_changed)
	board_view.zoom_changed.connect(_on_zoom_changed)
	board_view.undo_availability_changed.connect(_on_undo_availability_changed)
	add_child(board_view)
	_build_objective_panel()
	_build_phase_banner()
	_build_top_controls()
	_build_view_controls()
	_build_timeline()
	_build_detail_toast()
	_build_inspector()
	_build_battle_panel()
	_build_event_panel()
	_build_settings_drawer()


func _build_objective_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 14)
	panel.size = Vector2(400, 74)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, HUD_GOLD, 1, 8))
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)
	panel.add_child(row)
	var crest := Label.new()
	crest.text = "LION"
	crest.custom_minimum_size = Vector2(58, 54)
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crest.add_theme_font_size_override("font_size", 11)
	crest.add_theme_color_override("font_color", Color("#e7c47d"))
	crest.add_theme_stylebox_override("normal", _panel_style(Color("#0b2340"), HUD_GOLD, 2, 3))
	row.add_child(crest)
	units_label = Label.new()
	units_label.text = "Units 0"
	units_label.custom_minimum_size.x = 90
	units_label.add_theme_font_size_override("font_size", 19)
	units_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(units_label)
	var separator := VSeparator.new()
	row.add_child(separator)
	var objective_box := VBoxContainer.new()
	objective_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_box.add_theme_constant_override("separation", 4)
	row.add_child(objective_box)
	objective_label = Label.new()
	objective_label.add_theme_font_size_override("font_size", 17)
	objective_label.add_theme_color_override("font_color", Color("#f2eee8"))
	objective_box.add_child(objective_label)
	objective_progress = ProgressBar.new()
	objective_progress.custom_minimum_size = Vector2(170, 9)
	objective_progress.show_percentage = false
	objective_progress.add_theme_stylebox_override("background", _panel_style(Color("#253136"), Color.TRANSPARENT, 0, 5))
	objective_progress.add_theme_stylebox_override("fill", _panel_style(Color("#277ed0"), Color.TRANSPARENT, 0, 5))
	objective_box.add_child(objective_progress)


func _build_phase_banner() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-245, 0)
	panel.size = Vector2(490, 82)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.05, 0.065, 0.95), HUD_GOLD, 1, 5))
	add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	phase_title = Label.new()
	phase_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_title.add_theme_font_size_override("font_size", 28)
	phase_title.add_theme_color_override("font_color", HUD_BLUE)
	box.add_child(phase_title)
	phase_subtitle = Label.new()
	phase_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_subtitle.add_theme_font_size_override("font_size", 16)
	phase_subtitle.add_theme_color_override("font_color", Color("#ddd8d0"))
	box.add_child(phase_subtitle)


func _build_top_controls() -> void:
	planning_controls = HBoxContainer.new()
	planning_controls.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	planning_controls.position = Vector2(-540, 18)
	planning_controls.size = Vector2(520, 54)
	planning_controls.add_theme_constant_override("separation", 10)
	add_child(planning_controls)
	ready_button = _make_button("END PLANNING", 180)
	ready_button.add_theme_font_size_override("font_size", 18)
	ready_button.pressed.connect(_on_ready_pressed)
	planning_controls.add_child(ready_button)
	undo_button = _make_button("UNDO", 75)
	undo_button.tooltip_text = "Undo the last order change. Shortcut: Ctrl+Z."
	undo_button.pressed.connect(board_view.undo_last_order)
	planning_controls.add_child(undo_button)
	cancel_all_button = _make_button("CANCEL ALL ORDERS", 130)
	cancel_all_button.tooltip_text = "Remove every order issued this planning phase. This can be undone."
	cancel_all_button.pressed.connect(_on_clear_orders)
	planning_controls.add_child(cancel_all_button)
	settings_button = _make_button("SETTINGS", 100)
	settings_button.pressed.connect(_toggle_settings)
	planning_controls.add_child(settings_button)

	playback_controls = HBoxContainer.new()
	playback_controls.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	playback_controls.position = Vector2(-442, 18)
	playback_controls.size = Vector2(422, 54)
	playback_controls.add_theme_constant_override("separation", 4)
	add_child(playback_controls)
	for definition in [["FIRST", Callable(self, "_playback_first")], ["PREV", Callable(self, "_playback_previous")]]:
		var button := _make_button(String(definition[0]), 64)
		button.pressed.connect(definition[1])
		playback_controls.add_child(button)
	playback_pause_button = _make_button("NEXT", 128)
	playback_pause_button.add_theme_font_size_override("font_size", 17)
	playback_pause_button.pressed.connect(_playback_next)
	playback_controls.add_child(playback_pause_button)
	var last_button := _make_button("LAST", 64)
	last_button.pressed.connect(_playback_last)
	playback_controls.add_child(last_button)
	var playback_settings := _make_button("SET", 62)
	playback_settings.pressed.connect(_toggle_settings)
	playback_controls.add_child(playback_settings)


func _build_view_controls() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 164)
	panel.size = Vector2(430, 52)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, Color(0.55, 0.72, 0.82, 0.45), 1, 6))
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	var minus := _make_button("-", 44)
	minus.custom_minimum_size.y = 34
	minus.pressed.connect(board_view.zoom_out)
	row.add_child(minus)
	zoom_label = Label.new()
	zoom_label.text = "100%"
	zoom_label.custom_minimum_size.x = 60
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(zoom_label)
	var plus := _make_button("+", 44)
	plus.custom_minimum_size.y = 34
	plus.pressed.connect(board_view.zoom_in)
	row.add_child(plus)
	var fit := _make_button("FIT", 58)
	fit.custom_minimum_size.y = 34
	fit.pressed.connect(board_view.reset_view)
	row.add_child(fit)
	var select_all := _make_button("SELECT ALL", 122)
	select_all.custom_minimum_size.y = 34
	select_all.tooltip_text = "Select every movable formation. Shortcut: Ctrl+A."
	select_all.pressed.connect(board_view.select_all_movable)
	row.add_child(select_all)
	var help := _make_button("HELP", 54)
	help.custom_minimum_size.y = 34
	help.tooltip_text = "Show contextual movement help."
	help.pressed.connect(_show_detail_help)
	row.add_child(help)


func _build_timeline() -> void:
	timeline_panel = PanelContainer.new()
	timeline_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	timeline_panel.position = Vector2(-560, -70)
	timeline_panel.size = Vector2(1120, 60)
	timeline_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, HUD_GOLD, 1, 8))
	add_child(timeline_panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	timeline_panel.add_child(row)
	var timeline_title := Label.new()
	timeline_title.text = "ROUND"
	timeline_title.custom_minimum_size.x = 78
	timeline_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timeline_title.add_theme_font_size_override("font_size", 15)
	row.add_child(timeline_title)
	var names := ["IMPULSE 1\nMOVE", "IMPULSE 2\nMOVE", "IMPULSE 3\nMOVE", "BATTLES", "RETREATS", "RANGED\nATTACKS", "LEFTOVER\nMOVEMENT"]
	for index in names.size():
		if index > 0:
			var arrow := Label.new()
			arrow.text = ">"
			arrow.add_theme_font_size_override("font_size", 25)
			arrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
			row.add_child(arrow)
		var stage := PanelContainer.new()
		stage.custom_minimum_size = Vector2(106, 44)
		stage.add_theme_stylebox_override("panel", _timeline_style(false, false))
		row.add_child(stage)
		var label := Label.new()
		label.text = names[index]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		stage.add_child(label)
		timeline_stages.append(stage)
		timeline_labels.append(label)


func _build_detail_toast() -> void:
	detail_toast = PanelContainer.new()
	detail_toast.position = Vector2(14, 100)
	detail_toast.size = Vector2(400, 54)
	detail_toast.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.05, 0.065, 0.9), Color(0.4, 0.63, 0.78, 0.55), 1, 5))
	add_child(detail_toast)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	detail_toast.add_child(row)
	detail_label = Label.new()
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 14)
	detail_label.add_theme_color_override("font_color", Color("#d9e5ee"))
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(detail_label)
	var close := _make_button("X", 36)
	close.custom_minimum_size.y = 32
	close.tooltip_text = "Hide movement help."
	close.pressed.connect(_hide_detail_help)
	row.add_child(close)


func _hide_detail_help() -> void:
	detail_help_hidden = true
	detail_toast.visible = false
	inspector_panel.visible = false


func _show_detail_help() -> void:
	detail_help_hidden = false
	detail_toast.visible = not resolution_mode
	inspector_panel.visible = not resolution_mode


func _build_inspector() -> void:
	inspector_panel = PanelContainer.new()
	inspector_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	inspector_panel.position = Vector2(-330, -480)
	inspector_panel.size = Vector2(310, 380)
	inspector_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, HUD_GOLD, 1, 7))
	add_child(inspector_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 17)
	margin.add_theme_constant_override("margin_right", 17)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_bottom", 13)
	inspector_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)
	inspector_title = Label.new()
	inspector_title.add_theme_font_size_override("font_size", 20)
	inspector_title.add_theme_color_override("font_color", Color("#f3eee5"))
	box.add_child(inspector_title)
	box.add_child(HSeparator.new())
	inspector_stats = RichTextLabel.new()
	inspector_stats.bbcode_enabled = true
	inspector_stats.fit_content = true
	inspector_stats.custom_minimum_size.y = 130
	inspector_stats.add_theme_font_size_override("normal_font_size", 16)
	box.add_child(inspector_stats)
	group_move_controls = VBoxContainer.new()
	group_move_controls.add_theme_constant_override("separation", 4)
	box.add_child(group_move_controls)
	group_move_title = Label.new()
	group_move_title.text = "MOVE SELECTION"
	group_move_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group_move_title.add_theme_font_size_override("font_size", 13)
	group_move_title.add_theme_color_override("font_color", HUD_BLUE)
	group_move_controls.add_child(group_move_title)
	var move_grid := GridContainer.new()
	move_grid.columns = 3
	move_grid.add_theme_constant_override("h_separation", 4)
	move_grid.add_theme_constant_override("v_separation", 4)
	group_move_controls.add_child(move_grid)
	_add_move_spacer(move_grid)
	_add_move_button(move_grid, "UP", Vector2i.UP)
	_add_move_spacer(move_grid)
	_add_move_button(move_grid, "LEFT", Vector2i.LEFT)
	_add_move_button(move_grid, "DOWN", Vector2i.DOWN)
	_add_move_button(move_grid, "RIGHT", Vector2i.RIGHT)
	inspector_order = Label.new()
	inspector_order.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_order.add_theme_font_size_override("font_size", 14)
	inspector_order.add_theme_color_override("font_color", Color("#b9ddff"))
	box.add_child(inspector_order)


func _add_move_spacer(parent: GridContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(83, 34)
	parent.add_child(spacer)


func _add_move_button(parent: GridContainer, label: String, direction: Vector2i) -> void:
	var button := _make_button(label, 83)
	button.custom_minimum_size.y = 34
	button.pressed.connect(_issue_group_direction.bind(direction))
	parent.add_child(button)


func _issue_group_direction(direction: Vector2i) -> void:
	board_view.issue_selected_direction(direction)
	_update_inspector()


func _build_battle_panel() -> void:
	battle_panel = PanelContainer.new()
	battle_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	battle_panel.position = Vector2(-350, 100)
	battle_panel.size = Vector2(330, 700)
	battle_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, HUD_GOLD, 1, 7))
	add_child(battle_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	battle_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	battle_title = Label.new()
	battle_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_title.add_theme_font_size_override("font_size", 19)
	battle_title.add_theme_color_override("font_color", HUD_BLUE)
	battle_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(battle_title)
	box.add_child(HSeparator.new())
	battle_body = RichTextLabel.new()
	battle_body.bbcode_enabled = true
	battle_body.scroll_active = false
	battle_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_body.add_theme_font_size_override("normal_font_size", 16)
	battle_body.add_theme_color_override("default_color", Color("#dfddd7"))
	box.add_child(battle_body)


func _build_event_panel() -> void:
	event_panel = PanelContainer.new()
	event_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	event_panel.position = Vector2(16, -360)
	event_panel.size = Vector2(290, 250)
	event_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, HUD_GOLD, 1, 7))
	add_child(event_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	event_panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var title := Label.new()
	title.text = "EVENT LOG"
	title.add_theme_font_size_override("font_size", 15)
	box.add_child(title)
	history = RichTextLabel.new()
	history.bbcode_enabled = true
	history.scroll_active = true
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.add_theme_font_size_override("normal_font_size", 13)
	box.add_child(history)


func _build_settings_drawer() -> void:
	settings_drawer = PanelContainer.new()
	settings_drawer.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings_drawer.position = Vector2(-370, 88)
	settings_drawer.size = Vector2(350, 690)
	settings_drawer.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.045, 0.06, 0.98), HUD_GOLD, 1, 7))
	settings_drawer.visible = false
	add_child(settings_drawer)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	settings_drawer.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "BATTLE OPTIONS"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", HUD_BLUE)
	box.add_child(title)
	var game_buttons := GridContainer.new()
	game_buttons.columns = 2
	game_buttons.add_theme_constant_override("h_separation", 6)
	game_buttons.add_theme_constant_override("v_separation", 6)
	box.add_child(game_buttons)
	for definition in [["NEW BRIDGE", Callable(self, "start_bridge_game")], ["NEW MEETING", Callable(self, "start_meeting_game")], ["NEW 4-PLAYER", Callable(self, "start_four_player_game")], ["WATCH 4 BOTS", Callable(self, "start_spectator_game")]]:
		var button := _make_button(String(definition[0]), 145)
		button.pressed.connect(definition[1])
		game_buttons.add_child(button)
	clear_button = _make_button("CLEAR ORDERS", 145)
	clear_button.pressed.connect(_on_clear_orders)
	game_buttons.add_child(clear_button)
	withdraw_button = _make_button("WITHDRAW", 145)
	withdraw_button.pressed.connect(_on_withdraw)
	game_buttons.add_child(withdraw_button)
	export_replay_button = _make_button("EXPORT REPLAY", 145)
	export_replay_button.tooltip_text = "Save completed rounds, exact dice, and verification data as JSON."
	export_replay_button.pressed.connect(_on_export_replay)
	game_buttons.add_child(export_replay_button)
	replay_last_button = _make_button("REPLAY LAST", 145)
	replay_last_button.tooltip_text = "Reload the last export, verify it, and click through its recorded battles."
	replay_last_button.pressed.connect(_on_replay_last)
	game_buttons.add_child(replay_last_button)
	ranged_toggle = CheckButton.new()
	ranged_toggle.text = "Archer target mode"
	ranged_toggle.tooltip_text = "Target at range 1 with unused movement, or range 2 if the Archer makes no main move."
	ranged_toggle.button_pressed = true
	ranged_toggle.toggled.connect(_on_ranged_toggled)
	box.add_child(ranged_toggle)
	leftover_toggle = CheckButton.new()
	leftover_toggle.text = "Set leftover move"
	leftover_toggle.toggled.connect(_on_leftover_toggled)
	box.add_child(leftover_toggle)
	privacy_toggle = CheckButton.new()
	privacy_toggle.text = "Private battle details"
	privacy_toggle.button_pressed = true
	box.add_child(privacy_toggle)
	var counts := VBoxContainer.new()
	counts.add_theme_constant_override("separation", 2)
	box.add_child(counts)
	var colors := {StrategoGame.BLUE: Color("#78b7ff"), StrategoGame.RED: Color("#ff917c"), StrategoGame.GREEN: Color("#72e3a7"), StrategoGame.YELLOW: Color("#ffe27a")}
	for player in [StrategoGame.BLUE, StrategoGame.RED, StrategoGame.GREEN, StrategoGame.YELLOW]:
		var label := Label.new()
		label.add_theme_color_override("font_color", colors[player])
		counts.add_child(label)
		count_labels[player] = label
	var log_title := Label.new()
	log_title.text = "FULL ROUND LOG"
	log_title.add_theme_font_size_override("font_size", 14)
	box.add_child(log_title)
	settings_history = RichTextLabel.new()
	settings_history.bbcode_enabled = true
	settings_history.scroll_active = true
	settings_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_history.custom_minimum_size.y = 180
	box.add_child(settings_history)


func _make_button(text_value: String, width: float = 145.0) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(width, 46)
	button.add_theme_stylebox_override("normal", _panel_style(Color("#0d171d"), Color(0.64, 0.54, 0.38, 0.6), 1, 5))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#153049"), HUD_BLUE, 1, 5))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#204c73"), HUD_BLUE, 2, 5))
	return button


func _panel_style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _timeline_style(active: bool, completed: bool) -> StyleBoxFlat:
	var background := Color("#14385d") if active else (Color("#142a3c") if completed else Color(0, 0, 0, 0))
	var edge := HUD_BLUE if active else (Color("#678eb1") if completed else Color(1, 1, 1, 0.12))
	return _panel_style(background, edge, 2 if active else 1, 8)


func start_bridge_game() -> void:
	session_id += 1
	resolution_mode = false
	spectator_mode = false
	replay_view_mode = false
	selected_scenario = StrategoGame.SCENARIO_BRIDGE
	game = StrategoGame.new()
	game.setup_bridge(rng.randi(), StrategoGame.BLUE, StrategoGame.RED, 20, privacy_toggle.button_pressed)
	_configure_board(false)
	_clear_logs()
	_log_line("Bridge battle started. You command the Blue attacker.", true)
	_log_line("Red may deploy anywhere north of the river; Blue begins on its board edge.")
	settings_drawer.visible = false
	_update_interface()


func start_meeting_game() -> void:
	session_id += 1
	resolution_mode = false
	spectator_mode = false
	replay_view_mode = false
	selected_scenario = StrategoGame.SCENARIO_MEETING
	game = StrategoGame.new()
	game.setup_meeting(rng.randi(), StrategoGame.BLUE, StrategoGame.RED, StrategoGame.DEFAULT_HOLD_ROUNDS, 20, privacy_toggle.button_pressed)
	_configure_board(false)
	_clear_logs()
	_log_line("Meeting engagement started. You command Blue.", true)
	_log_line("Both armies are identical and deploy on their own back rank. Hold the centre square alone at the end of %d rounds in a row to win; if neither side does by round 20 the battle is a draw." % StrategoGame.DEFAULT_HOLD_ROUNDS)
	settings_drawer.visible = false
	_update_interface()


func start_four_player_game() -> void:
	session_id += 1
	resolution_mode = false
	spectator_mode = false
	replay_view_mode = false
	selected_scenario = StrategoGame.SCENARIO_FOUR_PLAYER
	game = StrategoGame.new()
	game.setup_random(rng.randi(), 4, privacy_toggle.button_pressed)
	_configure_board(false)
	_clear_logs()
	_log_line("Four-player WEGO battle started. You command Blue.", true)
	_log_line("The four-color fog and private battle-information framework is active.")
	settings_drawer.visible = false
	_update_interface()


func start_spectator_game() -> void:
	session_id += 1
	resolution_mode = false
	spectator_mode = true
	replay_view_mode = false
	selected_scenario = StrategoGame.SCENARIO_FOUR_PLAYER
	game = StrategoGame.new()
	game.setup_random(rng.randi(), 4, privacy_toggle.button_pressed)
	_configure_board(true)
	_clear_logs()
	_log_line("Four-bot simultaneous-order exhibition started.", true)
	settings_drawer.visible = false
	_update_interface()
	_run_spectator_round(session_id)


func _configure_board(show_all: bool) -> void:
	board_view.viewing_player = StrategoGame.BLUE
	board_view.reveal_all = show_all
	board_view.interaction_enabled = not show_all
	board_view.prefer_ranged = ranged_toggle.button_pressed
	board_view.leftover_mode = game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING
	board_view.set_game(game)
	if remote_bridge != null: remote_bridge.game = game


func _on_ready_pressed() -> void:
	if spectator_mode or replay_view_mode or game.game_over or resolution_mode or game.phase not in [StrategoGame.PHASE_PLANNING, StrategoGame.PHASE_LEFTOVER_PLANNING]:
		return
	board_view.clear_order_undo_history()
	board_view.clear_selection()
	game.mark_player_ready(StrategoGame.BLUE)
	_plan_unready_bots()
	if remote_bridge != null and not game.all_players_ready():
		detail_label.text = "Orders locked in. Waiting for the remote commander."
		_update_interface()
		return
	_resolve_ready_round()


func _plan_unready_bots() -> void:
	for player in game.active_players:
		if player == StrategoGame.BLUE and not spectator_mode:
			continue
		if remote_bridge != null and player == remote_bridge.controlled_player:
			continue
		if player in game.ready_players:
			continue
		if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING:
			bot.plan_leftover(game, player, rng)
		else:
			bot.plan_round(game, player, rng)
		game.mark_player_ready(player)


func _resolve_ready_round() -> void:
	if not game.all_players_ready() or resolution_mode:
		return
	var resolved_round := game.round_number
	var resolving_leftover := game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING
	var events: Array[Dictionary]
	if spectator_mode:
		events = game.resolve_round()
	elif resolving_leftover:
		events = game.resolve_leftover_phase()
	else:
		events = game.resolve_main_and_ranged()
	_log_line(("Round %d leftover movement resolved: %d events." if resolving_leftover else "Round %d movement, combat, and ranged attacks resolved: %d events.") % [resolved_round, events.size()], true)
	for event: Dictionary in events:
		_log_event(event)
	resolution_events = _visible_presentation_events(events)
	if resolution_events.is_empty():
		resolution_events.append({"action": "no_contact", "batch": "leftover" if resolving_leftover else "ranged", "combat": false, "result": "no_visible_contact"})
	resolution_index = 0
	resolution_mode = true
	presentation_paused = not spectator_mode
	presentation_speed = 1.0
	playback_pause_button.text = _resolution_completion_label() if resolution_events.size() == 1 else "NEXT"
	board_view.clear_selection()
	_update_interface()
	if spectator_mode:
		_play_resolution(session_id)


func _visible_presentation_events(events: Array[Dictionary]) -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	for event: Dictionary in events:
		if not replay_view_mode and not _event_is_known_to_viewer(event):
			continue
		var action := String(event.get("action", ""))
		var is_leftover_move := action == "move" and String(event.get("batch", "")) == "leftover"
		if bool(event.get("combat", false)) or action in ["bounce", "retreat", "retreat_collision"] or is_leftover_move:
			var presentation_event := event.duplicate(true)
			if is_leftover_move:
				presentation_event.action = "leftover_move"
			visible.append(presentation_event)
	return visible


func _play_resolution(active_session: int) -> void:
	while active_session == session_id and resolution_mode and resolution_index < resolution_events.size():
		_present_resolution_event()
		var displayed_index := resolution_index
		var event: Dictionary = resolution_events[resolution_index]
		await get_tree().create_timer(_resolution_event_duration(event) / presentation_speed).timeout
		while active_session == session_id and resolution_mode and presentation_paused:
			await get_tree().create_timer(0.12).timeout
		if active_session != session_id or not resolution_mode:
			return
		if resolution_index == displayed_index:
			resolution_index += 1
	_finish_resolution_presentation(active_session)


func _finish_resolution_presentation(active_session: int = -1) -> void:
	if not resolution_mode:
		return
	resolution_mode = false
	presentation_paused = false
	board_view.combat_hold = false
	board_view.combat_event.clear()
	_update_interface()
	if game.game_over:
		_log_game_end()
	elif spectator_mode and not replay_view_mode:
		_run_spectator_round(session_id if active_session < 0 else active_session)


func _present_resolution_event() -> void:
	if resolution_events.is_empty():
		return
	resolution_index = clampi(resolution_index, 0, resolution_events.size() - 1)
	var event: Dictionary = resolution_events[resolution_index]
	var advance_hint := "Auto advancing" if spectator_mode and not replay_view_mode else ("Click %s to continue" % _resolution_completion_label().capitalize() if resolution_index == resolution_events.size() - 1 else "Click Next to continue")
	phase_subtitle.text = "Event %d of %d · %s · %s" % [resolution_index + 1, resolution_events.size(), _action_label(String(event.get("action", "event"))).capitalize(), advance_hint]
	if bool(event.get("combat", false)):
		board_view.combat_hold = not spectator_mode or replay_view_mode
		board_view.combat_duration_msec = maxi(1400, int(_resolution_event_duration(event) * 1000.0 / presentation_speed))
		board_view.show_combat(event)
	else:
		board_view.combat_hold = false
		board_view.combat_event.clear()
	_update_battle_card(event)
	_update_timeline(_timeline_index_for_event(event))
	playback_pause_button.text = _resolution_completion_label() if resolution_index == resolution_events.size() - 1 else "NEXT"


func _resolution_completion_label() -> String:
	if replay_view_mode:
		return "FINISH REPLAY"
	if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING:
		return "ORDER LEFTOVER"
	if not game.game_over and game.phase == StrategoGame.PHASE_PLANNING:
		return "NEXT ROUND"
	return "FINISH"


func _resolution_event_duration(event: Dictionary) -> float:
	match String(event.get("action", "")):
		"melee", "crossing_battle": return 5.0
		"retreat_battle": return 4.5
		"ranged": return 4.0
		"bounce": return 3.0
		"retreat", "retreat_collision": return 2.5
		"no_contact": return 3.0
	return 2.5


func _update_battle_card(event: Dictionary) -> void:
	var action := String(event.get("action", "event"))
	var is_battle := bool(event.get("combat", false))
	battle_title.text = ("ACTIVE BATTLE: %s" if is_battle else "ACTIVE EVENT: %s") % _battle_name(event)
	if action == "leftover_move":
		var piece_id := int(event.get("piece_id", StrategoGame.EMPTY))
		var piece_text := "Formation"
		if piece_id >= 0 and piece_id < game.pieces.size():
			var piece: Dictionary = game.pieces[piece_id]
			piece_text = "%s\n%s" % [game.player_name(int(piece.player)).to_upper(), game.piece_description(piece)]
		battle_body.text = "[center][color=#f2b15b][font_size=19]LEFTOVER MOVEMENT[/font_size][/color]\n\n%s\n\n%s  ->  %s\n\n[color=#efc77c][b]MOVE COMPLETED[/b][/color][/center]" % [piece_text, str(event.get("from", Vector2i.ZERO)), str(event.get("to", Vector2i.ZERO))]
		return
	var content := "[center][color=#8fc4ff][font_size=18]%s[/font_size][/color][/center]\n\n" % _action_label(action)
	var ids: Array = event.get("participants", [])
	if action == "ranged":
		ids = [int(event.get("shooter_id", StrategoGame.EMPTY)), int(event.get("target_id", StrategoGame.EMPTY))]
	var valid_ids: Array[int] = []
	for id_value in ids:
		var id := int(id_value)
		if id >= 0 and id < game.pieces.size():
			valid_ids.append(id)
	# Two participants is the ordinary case and reads far better as a comparison
	# than as two stacked blocks. Multiway battles keep the list form.
	if valid_ids.size() == 2 and action != "ranged":
		battle_body.text = content + _battle_comparison(event, valid_ids)
		return
	for index in valid_ids.size():
		var piece: Dictionary = game.pieces[valid_ids[index]]
		var side_color := "#78b7ff" if int(piece.player) == StrategoGame.BLUE else "#ff8f78"
		content += "[color=%s][b]%s[/b][/color]\n%s\n" % [side_color, game.player_name(int(piece.player)).to_upper(), game.piece_description(piece)]
		var roll := _event_roll(event, valid_ids[index], index)
		# A natural 10 adds a point of damage after Armor, and the score alone
		# never reveals it: a weakened formation caps its score well below 10,
		# so the damage otherwise looks like it does not follow from the numbers.
		var roll_note := "  [color=#e7c47d](natural 10: +1 damage)[/color]" if roll == 10 else ""
		content += "D10 roll   [b]%d[/b]%s\nFinal score   [b]%d[/b]\nDamage taken   [b]%d[/b]\nRemaining Strength   [b]%d[/b]\n" % [roll, roll_note, _event_score(event, valid_ids[index], index), _event_damage(event, valid_ids[index], index), int(piece.strength)]
		if index < valid_ids.size() - 1:
			content += "\n[center][color=#aaa39a]VERSUS[/color][/center]\n\n"
	var winner_id := int(event.get("winner_id", StrategoGame.EMPTY))
	content += "\n[center][color=#efc77c][b]%s[/b][/color]\n%s[/center]" % [_result_label(event, winner_id), _result_detail(event, winner_id)]
	battle_body.text = content


## A head-to-head table, laid out so every number in the damage calculation is
## on the page: the raw die, the Strength that capped it, the role bonus, the
## armour that was subtracted, and the natural-10 chip. Without these the damage
## looks unrelated to the score, which is exactly how players misread it.
func _battle_comparison(event: Dictionary, ids: Array[int]) -> String:
	var winner_id := int(event.get("winner_id", StrategoGame.EMPTY))
	var left: Dictionary = game.pieces[ids[0]]
	var right: Dictionary = game.pieces[ids[1]]
	var rows: Array = []

	var names: Array = []
	for id in ids:
		var piece: Dictionary = game.pieces[id]
		var tint := "#78b7ff" if int(piece.player) == StrategoGame.BLUE else "#ff8f78"
		names.append("[color=%s][b]%s[/b][/color]" % [tint, game.piece_description(piece)])
	rows.append([names[0], "", names[1]])

	var bonuses: Dictionary = event.get("role_bonuses", {})
	var capped: Dictionary = event.get("capped_rolls", {})
	var values := func(source: Dictionary, id: int) -> int:
		return int(source.get(id, source.get(str(id), 0)))

	rows.append([str(_event_roll(event, ids[0], 0)), "D10 ROLL", str(_event_roll(event, ids[1], 1))])
	if not capped.is_empty():
		rows.append([str(values.call(capped, ids[0])), "CAPPED BY STRENGTH", str(values.call(capped, ids[1]))])
	if not bonuses.is_empty():
		var render_bonus := func(value: int) -> String:
			return "[color=#9fdc8a]+%d[/color]" % value if value > 0 else "0"
		rows.append([render_bonus.call(values.call(bonuses, ids[0])), "ROLE BONUS", render_bonus.call(values.call(bonuses, ids[1]))])
	rows.append(["[b]%d[/b]" % _event_score(event, ids[0], 0), "FINAL SCORE", "[b]%d[/b]" % _event_score(event, ids[1], 1)])

	var armour := func(piece: Dictionary) -> String:
		var doubled := int(piece.id) == winner_id
		return "%d [color=#c8a15c](doubled)[/color]" % (int(piece.armor) * 2) if doubled else str(int(piece.armor))
	rows.append([armour.call(left), "ARMOUR", armour.call(right)])

	for index in 2:
		if _event_roll(event, ids[index], index) == 10:
			var chip := ["", "NATURAL 10  +1 DAMAGE", ""]
			chip[index * 2] = "[color=#e7c47d]+1[/color]"
			rows.append(chip)
			break

	rows.append(["[color=#ff9d84]%d[/color]" % _event_damage(event, ids[0], 0), "DAMAGE TAKEN", "[color=#ff9d84]%d[/color]" % _event_damage(event, ids[1], 1)])
	rows.append([str(int(left.strength)), "STRENGTH LEFT", str(int(right.strength))])

	var table := "[table=3]"
	for row: Array in rows:
		table += "[cell]%s[/cell][cell][color=#a9a294]%s[/color][/cell][cell]%s[/cell]" % [row[0], row[1], row[2]]
	table += "[/table]"
	return "%s\n\n[center][color=#efc77c][b]%s[/b][/color]\n%s[/center]" % [
		table, _result_label(event, winner_id), _result_detail(event, winner_id),
	]


func _event_score(event: Dictionary, piece_id: int, index: int) -> int:
	if event.has("scores"):
		return int(event.scores.get(piece_id, 0))
	return int(event.get("attacker_score", 0)) if index == 0 else int(event.get("defender_score", 0))


func _event_roll(event: Dictionary, piece_id: int, index: int) -> int:
	if event.has("raw_rolls"):
		return int(event.raw_rolls.get(piece_id, 0))
	return int(event.get("attacker_raw_roll", 0)) if index == 0 else int(event.get("defender_raw_roll", 0))


func _event_damage(event: Dictionary, piece_id: int, index: int) -> int:
	if event.has("damage"):
		return int(event.damage.get(piece_id, 0))
	if String(event.get("action", "")) == "ranged":
		return 0 if index == 0 else int(event.get("defender_damage", 0))
	return int(event.get("attacker_damage", 0)) if index == 0 else int(event.get("defender_damage", 0))


func _result_label(event: Dictionary, winner_id: int) -> String:
	if winner_id >= 0 and winner_id < game.pieces.size():
		return "RESULT: %s WINS" % game.player_name(int(game.pieces[winner_id].player)).to_upper()
	return "RESULT: %s" % String(event.get("result", "bounce")).replace("_", " ").to_upper()


func _result_detail(event: Dictionary, winner_id: int) -> String:
	if String(event.get("action", "")) == "no_contact":
		return "The round completed without an observed battle"
	if winner_id >= 0:
		return "Opposing formations retreat; winner may continue"
	if String(event.get("result", "")) == "bounce":
		return "No unique winner; tied leaders bounce"
	return "No formation controls the contested square"


func _battle_name(event: Dictionary) -> String:
	var action := String(event.get("action", "battle"))
	if action in ["leftover_move", "no_contact"]:
		return _action_label(action)
	var position: Vector2i = event.get("to", Vector2i(-1, -1))
	if position.x >= 0 and game.is_bridge(position):
		return "BRIDGE CLASH"
	return _action_label(action)


func _action_label(action: String) -> String:
	match action:
		"crossing_battle": return "CROSSING-PATH BATTLE"
		"retreat_battle": return "RETREAT BATTLE"
		"ranged": return "RANGED ATTACK"
		"bounce": return "COLLISION BOUNCE"
		"retreat": return "RETREAT"
		"leftover_move": return "LEFTOVER MOVEMENT"
		"no_contact": return "NO VISIBLE CONTACT"
	return "MELEE COMBAT"


func _timeline_index_for_event(event: Dictionary) -> int:
	var action := String(event.get("action", ""))
	if action in ["melee", "crossing_battle"]: return 3
	if action in ["retreat", "retreat_battle", "retreat_collision"]: return 4
	if action == "ranged": return 5
	if String(event.get("batch", "")) == "leftover": return 6
	var batch := String(event.get("batch", ""))
	if batch.begins_with("impulse_"):
		return clampi(int(batch.trim_prefix("impulse_")) - 1, 0, 2)
	return 3


func _on_clear_orders() -> void:
	if spectator_mode or replay_view_mode or resolution_mode or game.phase not in [StrategoGame.PHASE_PLANNING, StrategoGame.PHASE_LEFTOVER_PLANNING]:
		return
	board_view.clear_all_orders()
	_update_interface(false)


func _on_withdraw() -> void:
	if spectator_mode or replay_view_mode or resolution_mode or game.game_over:
		return
	var result: Dictionary = game.withdraw_player(StrategoGame.BLUE)
	if bool(result.get("ok", false)):
		_log_line("Blue withdrew with %d current Strength surviving." % int(result.surviving_strength), true)
		_log_game_end()
	settings_drawer.visible = false
	_update_interface()


func _on_export_replay() -> void:
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "-").replace("T", "_")
	var timestamped_path := "user://replays/wego-replay-%s.json" % stamp
	var result: Dictionary = game.save_replay(timestamped_path)
	if not bool(result.get("ok", false)):
		detail_label.text = String(result.get("message", "Replay export failed."))
		_log_line(detail_label.text, true)
		return
	var last_result: Dictionary = game.save_replay(LAST_REPLAY_PATH)
	if not bool(last_result.get("ok", false)):
		detail_label.text = "Replay exported, but the Replay Last copy could not be updated."
		_log_line(detail_label.text, true)
		return
	detail_label.text = "Replay exported and verified data saved: %s" % String(result.path)
	_log_line("Replay exported: %d completed round%s · %s" % [int(result.rounds), "" if int(result.rounds) == 1 else "s", String(result.path)], true)
	_update_interface(false)


func _on_replay_last() -> void:
	var load_result := StrategoGame.load_replay_document(LAST_REPLAY_PATH)
	if not bool(load_result.get("ok", false)):
		detail_label.text = String(load_result.get("message", "The replay could not be loaded."))
		_log_line(detail_label.text, true)
		return
	var replay_result := StrategoGame.run_replay(load_result.document)
	if not bool(replay_result.get("ok", false)):
		detail_label.text = "Replay rejected: %s" % String(replay_result.get("message", "verification failed"))
		_log_line(detail_label.text, true)
		return
	session_id += 1
	resolution_mode = false
	spectator_mode = false
	replay_view_mode = true
	game = replay_result.game
	selected_scenario = game.scenario
	_configure_board(true)
	_clear_logs()
	_log_line("Replay verified: %d completed round%s reproduced exactly." % [int(replay_result.rounds), "" if int(replay_result.rounds) == 1 else "s"], true)
	_log_line("Digest %s" % String(replay_result.digest))
	resolution_events.clear()
	for event_value in replay_result.get("events", []):
		if event_value is Dictionary:
			resolution_events.append(event_value)
	resolution_events = _visible_presentation_events(resolution_events)
	resolution_index = 0
	settings_drawer.visible = false
	if not resolution_events.is_empty():
		resolution_mode = true
		presentation_paused = true
		presentation_speed = 1.0
		playback_pause_button.text = _resolution_completion_label() if resolution_events.size() == 1 else "NEXT"
	detail_label.text = "Replay verification passed. Use the battle controls to inspect every recorded contact."
	_update_interface(false)


func _on_ranged_toggled(enabled: bool) -> void:
	board_view.prefer_ranged = enabled
	if enabled and leftover_toggle.button_pressed:
		leftover_toggle.button_pressed = false
	board_view.queue_redraw()


func _on_leftover_toggled(enabled: bool) -> void:
	board_view.leftover_mode = enabled
	if enabled and ranged_toggle.button_pressed:
		ranged_toggle.button_pressed = false
	group_move_title.text = "SET LEFTOVER MOVE" if enabled else "MOVE SELECTION"
	group_move_title.add_theme_color_override("font_color", Color("#f2b15b") if enabled else HUD_BLUE)
	detail_label.text = "Leftover mode: choose one direction for every selected formation with unused movement." if enabled else "Main movement mode restored."
	_update_inspector()
	board_view.queue_redraw()


func _on_order_changed(message: String) -> void:
	detail_label.text = message
	_update_interface(false)


## Examine reports what the formation is and what its role and weight do. A
## fuller panel belongs here later; for now it answers "what am I looking at".
func _on_examine_requested(piece_id: int) -> void:
	if piece_id < 0 or piece_id >= game.pieces.size(): return
	var piece: Dictionary = game.pieces[piece_id]
	var role := String(piece.role)
	var weight := String(piece.weight)
	var role_note: String = {
		StrategoGame.ROLE_INFANTRY: "+%d battle score when defending." % StrategoGame.ROLE_BONUS,
		StrategoGame.ROLE_CAVALRY: "+%d battle score when attacking." % StrategoGame.ROLE_BONUS,
		StrategoGame.ROLE_ARCHER: "No melee bonus; may shoot during the ranged phase.",
	}.get(role, "")
	var known := game.is_piece_visible_to(piece, board_view.viewing_player)
	var strength := "Strength %d/%d." % [int(piece.strength), int(piece.max_strength)] if known else "Strength unknown."
	_log_line("%s: %s %s. Movement %d, Armor %d. %s %s" % [
		String(piece.type), weight.capitalize(), role.capitalize(),
		game.movement_limit_for(piece), int(piece.armor), strength, role_note,
	], true)
	detail_label.text = "%s %s · movement %d · armor %d · %s" % [weight.capitalize(), role.capitalize(), game.movement_limit_for(piece), int(piece.armor), strength]


func _on_selection_changed(description: String) -> void:
	detail_label.text = description
	_update_inspector()


func _on_zoom_changed(percent: int) -> void:
	if zoom_label != null:
		zoom_label.text = "%d%%" % percent


func _on_undo_availability_changed(_available: bool) -> void:
	if undo_button != null:
		undo_button.disabled = spectator_mode or replay_view_mode or resolution_mode or not board_view.can_undo_order()


func _toggle_settings() -> void:
	settings_drawer.visible = not settings_drawer.visible


func _playback_first() -> void:
	resolution_index = 0
	_present_resolution_event()


func _playback_previous() -> void:
	resolution_index = maxi(0, resolution_index - 1)
	_present_resolution_event()


func _playback_next() -> void:
	if resolution_index >= resolution_events.size() - 1:
		_finish_resolution_presentation()
	else:
		resolution_index += 1
		_present_resolution_event()


func _playback_last() -> void:
	resolution_index = maxi(0, resolution_events.size() - 1)
	_present_resolution_event()


func _run_spectator_round(active_session: int) -> void:
	if active_session != session_id or not spectator_mode or game.game_over or resolution_mode:
		return
	await get_tree().create_timer(0.7).timeout
	if active_session != session_id or not spectator_mode or game.game_over or resolution_mode:
		return
	_plan_unready_bots()
	_resolve_ready_round()


func _update_interface(update_detail: bool = true) -> void:
	var main_planning := not resolution_mode and not game.game_over and game.phase == StrategoGame.PHASE_PLANNING
	var leftover_planning := not resolution_mode and not game.game_over and game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING
	var planning := main_planning or leftover_planning
	var read_only := spectator_mode or replay_view_mode
	planning_controls.visible = not resolution_mode
	playback_controls.visible = resolution_mode
	inspector_panel.visible = not resolution_mode and not detail_help_hidden
	battle_panel.visible = resolution_mode
	event_panel.visible = resolution_mode
	detail_toast.visible = not resolution_mode and not detail_help_hidden
	if resolution_mode:
		phase_title.text = "PHASE: BATTLE RESOLUTION"
		phase_subtitle.text = "Verified replay events" if replay_view_mode else "Resolving movement collisions and combat"
		_present_resolution_event()
	elif replay_view_mode:
		phase_title.text = "REPLAY VERIFIED"
		phase_subtitle.text = "%d completed round%s reproduced exactly" % [game.replay_rounds.size(), "" if game.replay_rounds.size() == 1 else "s"]
	elif game.game_over:
		phase_title.text = "BATTLE COMPLETE"
		phase_subtitle.text = "%s · %s" % [game.player_name(game.winner), game.end_reason.replace("_", " ")]
	elif leftover_planning:
		phase_title.text = "PHASE: LEFTOVER MOVEMENT"
		phase_subtitle.text = "Round %d · Issue one optional move to formations with movement remaining" % game.round_number
	else:
		phase_title.text = "PHASE: PLANNING"
		phase_subtitle.text = "Round %d · Issue orders to all formations" % game.round_number
	units_label.text = "Units  %d" % game.count_alive(StrategoGame.BLUE)
	if game.scenario == StrategoGame.SCENARIO_BRIDGE:
		objective_label.text = "%d / %d across river" % [game.bridge_strength_across(), game.bridge_strength_target]
		objective_progress.max_value = game.bridge_strength_target
		objective_progress.value = game.bridge_strength_across()
	elif game.scenario == StrategoGame.SCENARIO_MEETING and not game.objectives.is_empty():
		var required := int(game.objectives[0].rounds)
		var held := game.objective_streak(0, StrategoGame.BLUE)
		var rival := game.objective_streak(0, StrategoGame.RED)
		objective_label.text = "Centre held %d / %d  (Red %d)" % [held, required, rival]
		objective_progress.max_value = required
		objective_progress.value = held
	else:
		objective_label.text = "%d Strength remaining" % game.total_strength(StrategoGame.BLUE)
		objective_progress.max_value = maxf(1.0, game.total_strength(StrategoGame.BLUE))
		objective_progress.value = game.total_strength(StrategoGame.BLUE)
	for player in count_labels:
		var label: Label = count_labels[player]
		label.visible = player in game.active_players or player in game.eliminated_players
		label.text = "%s · %d units · %d Strength" % [game.player_name(player), game.count_alive(player), game.total_strength(player)]
	ready_button.text = "END LEFTOVER" if leftover_planning else "END PLANNING"
	ready_button.disabled = not planning or read_only
	undo_button.disabled = not planning or read_only or not board_view.can_undo_order()
	cancel_all_button.disabled = not planning or read_only or (not game.has_leftover_orders(StrategoGame.BLUE) if leftover_planning else game.orders_for_player(StrategoGame.BLUE).is_empty())
	clear_button.disabled = not planning or read_only
	withdraw_button.disabled = not main_planning or read_only
	export_replay_button.disabled = resolution_mode or replay_view_mode or game.phase not in [StrategoGame.PHASE_PLANNING, StrategoGame.PHASE_GAME_OVER]
	replay_last_button.disabled = not FileAccess.file_exists(LAST_REPLAY_PATH)
	ranged_toggle.disabled = not main_planning or read_only
	leftover_toggle.set_pressed_no_signal(leftover_planning)
	leftover_toggle.disabled = true
	leftover_toggle.tooltip_text = "Leftover movement becomes available after battles and ranged attacks resolve."
	board_view.leftover_mode = leftover_planning
	board_view.prefer_ranged = main_planning and ranged_toggle.button_pressed
	board_view.interaction_enabled = planning and not read_only
	if not resolution_mode:
		_update_timeline(6 if leftover_planning or game.game_over else -1 if main_planning else 0)
	group_move_title.text = "SET LEFTOVER MOVE" if leftover_planning else "MOVE SELECTION"
	group_move_title.add_theme_color_override("font_color", Color("#f2b15b") if leftover_planning else HUD_BLUE)
	_update_inspector()
	if update_detail and game.game_over:
		detail_label.text = "%s won: %s." % [game.player_name(game.winner), game.end_reason.replace("_", " ")]
	board_view.queue_redraw()


func _update_timeline(active_index: int) -> void:
	for index in timeline_stages.size():
		var completed := (resolution_mode or game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING) and index < active_index
		timeline_stages[index].add_theme_stylebox_override("panel", _timeline_style(index == active_index, completed))
		timeline_labels[index].add_theme_color_override("font_color", HUD_BLUE if index == active_index else Color("#c9c6bf"))


func _update_inspector() -> void:
	if group_move_controls != null:
		group_move_controls.visible = board_view != null and board_view.interaction_enabled and not board_view.selected_piece_ids.is_empty()
	if board_view == null or game == null or board_view.selected_piece_ids.is_empty():
		inspector_title.text = "ISSUE FORMATION ORDERS"
		inspector_stats.text = "Select one or more banners.\n\n[color=#9fc8e8]Shift-click or drag[/color] to build a group.\n\n[color=#9fc8e8]Alt-click[/color] selects a formation instead of stepping into its square.\n\nMouse wheel zooms; middle-drag pans."
		inspector_order.text = "No formation selected"
		return
	if board_view.selected_piece_ids.size() > 1:
		var total_strength := 0
		var ordered := 0
		var minimum_move := 99
		var can_move_now := 0
		for piece_id in board_view.selected_piece_ids:
			var member: Dictionary = game.pieces[piece_id]
			total_strength += int(member.strength)
			minimum_move = mini(minimum_move, game.movement_limit_for(member))
			var member_order := game.order_for_piece(piece_id)
			if (member_order.get("leftover", Vector2i(-1, -1)).x >= 0) if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING else not member_order.is_empty():
				ordered += 1
			if board_view._piece_has_unused_movement(piece_id):
				can_move_now += 1
		inspector_title.text = "%d FORMATIONS SELECTED" % board_view.selected_piece_ids.size()
		inspector_stats.text = "[table=2][cell]Combined Strength[/cell][cell][right]%d[/right][/cell][cell]Slowest Movement[/cell][cell][right]%d[/right][/cell][cell]Can Move Next[/cell][cell][right]%d / %d[/right][/cell][cell]%s Orders[/cell][cell][right]%d / %d[/right][/cell][/table]" % [total_strength, minimum_move, can_move_now, board_view.selected_piece_ids.size(), "Leftover" if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING else "Main", ordered, board_view.selected_piece_ids.size()]
		inspector_order.text = "Choose the group's one-square post-ranged move. Exhausted formations are skipped." if board_view.leftover_mode else "Each command moves every selected formation with unused movement. Exhausted formations are skipped automatically."
		return
	var id := board_view.selected_piece_id
	if id < 0 or id >= game.pieces.size():
		return
	var piece: Dictionary = game.pieces[id]
	inspector_title.text = "%s %s" % [String(piece.weight).to_upper(), String(piece.role).to_upper()]
	inspector_stats.text = "[table=2][cell]Strength[/cell][cell][right]%d / %d[/right][/cell][cell]Armor[/cell][cell][right]%d[/right][/cell][cell]Movement[/cell][cell][right]%d[/right][/cell][/table]" % [int(piece.strength), int(piece.max_strength), int(piece.armor), game.movement_limit_for(piece)]
	var order := game.order_for_piece(id)
	if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING:
		var leftover: Vector2i = order.get("leftover", Vector2i(-1, -1))
		inspector_order.text = "Leftover move set to %s" % str(leftover) if leftover.x >= 0 else ("Choose one adjacent square" if game.can_receive_leftover_order(StrategoGame.BLUE, id) else "No leftover movement available")
		return
	if order.is_empty():
		inspector_order.text = "No order issued"
		return
	var path: Array = order.get("path", [])
	var message := "Order issued · %d impulse%s" % [path.size(), "" if path.size() == 1 else "s"]
	if game.scenario == StrategoGame.SCENARIO_BRIDGE:
		for index in path.size():
			var position: Vector2i = path[index]
			if position.y < StrategoGame.BRIDGE_RIVER_Y:
				message += "\nWill cross on Impulse %d" % (index + 1)
				break
	if order.get("ranged_target", Vector2i(-1, -1)).x >= 0:
		message += "\nRanged target set"
	if order.get("leftover", Vector2i(-1, -1)).x >= 0:
		message += "\nLeftover move set"
	inspector_order.text = message


func _log_event(event: Dictionary) -> void:
	if not _event_is_known_to_viewer(event):
		return
	var action := String(event.get("action", ""))
	match action:
		"move":
			var piece_id := int(event.get("piece_id", StrategoGame.EMPTY))
			if piece_id >= 0 and piece_id < game.pieces.size() and int(game.pieces[piece_id].player) != StrategoGame.BLUE:
				_log_line("Observed a %s enemy formation moving during %s." % [String(game.pieces[piece_id].weight).capitalize(), String(event.get("batch", "impulse")).replace("_", " ")])
		"melee", "crossing_battle":
			var ids: Array = event.get("participants", [])
			var labels: Array[String] = []
			for id in ids:
				if id >= 0 and id < game.pieces.size():
					labels.append("%s %s" % [game.player_name(int(game.pieces[id].player)), game.piece_display_code(game.pieces[id])])
			var winner_id := int(event.get("winner_id", StrategoGame.EMPTY))
			var outcome := "bounce" if winner_id == StrategoGame.EMPTY else "%s wins" % game.player_name(int(game.pieces[winner_id].player))
			_log_line("%s: %s -> %s." % ["Crossing battle" if action == "crossing_battle" else "Melee", ", ".join(labels), outcome])
		"ranged":
			_log_line("Archer fire dealt %d damage%s." % [int(event.get("defender_damage", 0)), " and destroyed the target" if event.result == "ranged_destroyed" else ""])
		"retreat_battle":
			_log_line("Enemy retreats collided: %s." % String(event.result).replace("_", " "))
		"retreat":
			if event.result == "retreat_destroyed":
				_log_line("A blocked or off-map retreat destroyed a formation.")
		"bounce":
			if event.get("reason", "") == "allied_collision":
				_log_line("Allied formations collided and bounced without combat.")


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


func _clear_logs() -> void:
	history.clear()
	settings_history.clear()


func _log_line(text_value: String, important: bool = false) -> void:
	var formatted := ("[color=#f8df9a][b]%s[/b][/color]" if important else "%s") % text_value
	for target in [history, settings_history]:
		if target == null:
			continue
		target.append_text(formatted + "\n")
		target.scroll_to_line(maxi(0, target.get_line_count() - 1))
