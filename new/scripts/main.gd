extends Control

const HUD_BLUE := Color("#79b9ff")
const HUD_GOLD := Color("#c9a25e")
const PANEL_BG := Color(0.035, 0.055, 0.095, 0.96)
const LAST_REPLAY_PATH := "user://replays/last_replay.json"

var game := StrategoGame.new()
var bot := StrategoBotPolicy.new()
# When set, this army is driven over the MCP bridge instead of by the bot, so a
# remote opponent can play the real app rather than a headless copy of it.
var remote_bridge: StrategoMCPBridge = null
var rng := RandomNumberGenerator.new()
var board_view: StrategoBoardView
var minimap: StrategoBoardView

var examined_piece_id := StrategoGame.EMPTY
var top_bar_actions: HBoxContainer
var objective_pips: HBoxContainer
const PIP_LIMIT := 6
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
var inspector_cards: VBoxContainer
const SELECTION_CARD_LIMIT := 4
var inspector_stats: RichTextLabel
var inspector_order: Label
var group_move_controls: VBoxContainer
var group_move_title: Label
var battle_panel: PanelContainer
var battle_title: Label
var battle_body: RichTextLabel
var battle_cards: VBoxContainer
var battle_stats: GridContainer
var battle_result: Label
var battle_result_detail: Label
var event_panel: PanelContainer
var left_tabs: TabContainer
var roster_list: VBoxContainer
var log_list: VBoxContainer
var log_box_hidden: VBoxContainer
var log_entries: Array[Dictionary] = []

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


## A serif face for the whole interface. The mockups' character comes as much
## from the letterforms as from the gold: a sans-serif reads as a utility, a
## serif reads as a campaign map. SystemFont falls back through the list, so a
## machine missing one still gets a serif.
func _apply_theme() -> void:
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Garamond", "Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "serif"])
	serif.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	var ui := Theme.new()
	for kind in ["Label", "Button", "RichTextLabel", "TabContainer", "PopupMenu", "CheckButton"]:
		ui.set_font("font", kind, serif)
	ui.set_font("normal_font", "RichTextLabel", serif)
	ui.set_font("bold_font", "RichTextLabel", serif)
	theme = ui


func _ready() -> void:
	rng.randomize()
	_apply_theme()
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


## Reserved screen regions. Panels sit beside the board rather than over it, so
## nothing occludes the field and no region ever moves. The board takes whatever
## is left, which is the one area that should flex.
const REGION_TOP := 78.0
const REGION_BOTTOM := 88.0
const REGION_LEFT := 300.0
const REGION_RIGHT := 340.0


func _build_interface() -> void:
	board_view = StrategoBoardView.new()
	_fit_to_board_region(board_view)
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
	_build_minimap()
	_build_timeline()
	_build_detail_toast()
	_build_inspector()
	_build_battle_panel()
	_build_event_panel()
	_build_settings_drawer()
	resized.connect(_on_window_resized)


## Anchors a control to the board region between the reserved bars.
func _fit_to_board_region(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = REGION_LEFT
	control.offset_right = -REGION_RIGHT
	control.offset_top = REGION_TOP
	control.offset_bottom = -REGION_BOTTOM


func _on_window_resized() -> void:
	if board_view != null: board_view.queue_redraw()


## One framed strip across the reserved top region, replacing the three panels
## that used to float over the board and occlude its first rows.
func _build_objective_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 10
	panel.offset_right = -10
	panel.offset_top = 8
	panel.custom_minimum_size.y = REGION_TOP - 16
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, HUD_GOLD, 1, 8))
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(row)

	var crest := Label.new()
	crest.text = "LION"
	crest.custom_minimum_size = Vector2(50, 44)
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crest.add_theme_font_size_override("font_size", 11)
	crest.add_theme_color_override("font_color", Color("#e7c47d"))
	crest.add_theme_stylebox_override("normal", _panel_style(Color("#0b2340"), HUD_GOLD, 2, 3))
	row.add_child(crest)

	# The battle's name, not the phase: the phase bar already says which step we
	# are in, and repeating it here wastes the most prominent slot on the screen.
	phase_title = Label.new()
	phase_title.custom_minimum_size.x = 260
	phase_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_title.add_theme_font_size_override("font_size", 21)
	phase_title.add_theme_color_override("font_color", Color("#e7c47d"))
	row.add_child(phase_title)

	var divider := VSeparator.new()
	row.add_child(divider)

	var objective_box := HBoxContainer.new()
	objective_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	objective_box.add_theme_constant_override("separation", 12)
	row.add_child(objective_box)
	objective_label = Label.new()
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 15)
	objective_label.add_theme_color_override("font_color", Color("#f2eee8"))
	objective_box.add_child(objective_label)
	# Discrete pips rather than a bar: the objective is counted in whole rounds,
	# and a bar implies a continuous quantity it does not have.
	objective_pips = HBoxContainer.new()
	objective_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	objective_pips.add_theme_constant_override("separation", 7)
	objective_box.add_child(objective_pips)

	# Kept off-screen: the round summary still writes to these.
	phase_subtitle = Label.new()
	phase_subtitle.visible = false
	objective_box.add_child(phase_subtitle)
	units_label = Label.new()
	units_label.visible = false
	objective_box.add_child(units_label)
	objective_progress = ProgressBar.new()
	objective_progress.visible = false
	objective_box.add_child(objective_progress)

	top_bar_actions = HBoxContainer.new()
	top_bar_actions.add_theme_constant_override("separation", 8)
	top_bar_actions.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(top_bar_actions)


func _build_phase_banner() -> void:
	pass


func _build_top_controls() -> void:
	# Three actions, present in every phase. Playback lives with the resolution
	# content in the right panel, and settings with the other game commands, so
	# the bar itself never changes shape as the round advances.
	planning_controls = HBoxContainer.new()
	planning_controls.add_theme_constant_override("separation", 8)
	top_bar_actions.add_child(planning_controls)
	ready_button = _make_button("END PLANNING", 168)
	ready_button.add_theme_font_size_override("font_size", 18)
	ready_button.pressed.connect(_on_ready_pressed)
	planning_controls.add_child(ready_button)
	undo_button = _make_button("UNDO", 92)
	undo_button.tooltip_text = "Undo the last order change. Shortcut: Ctrl+Z."
	undo_button.pressed.connect(board_view.undo_last_order)
	planning_controls.add_child(undo_button)
	cancel_all_button = _make_button("CANCEL ALL", 128)
	cancel_all_button.tooltip_text = "Remove every order issued this planning phase. This can be undone."
	cancel_all_button.pressed.connect(_on_clear_orders)
	_tint_button(cancel_all_button, Color("#c8564a"))
	planning_controls.add_child(cancel_all_button)


## Paint a button in a warning colour without disturbing the shared theme.
func _tint_button(button: Button, tint: Color) -> void:
	button.add_theme_color_override("font_color", tint)
	button.add_theme_color_override("font_hover_color", tint.lightened(0.3))
	button.add_theme_stylebox_override("normal", _panel_style(Color("#1c1210"), tint.darkened(0.25), 1, 5))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#2c1a16"), tint, 1, 5))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#3a201a"), tint, 1, 5))


## MAP OVERVIEW: a second board view in overview mode, showing the same game.
## Being the same draw path means it obeys fog for free.
func _build_minimap() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 10
	panel.offset_right = REGION_LEFT - 12
	panel.offset_top = -REGION_BOTTOM - 268
	panel.offset_bottom = -REGION_BOTTOM - 58
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, HUD_GOLD, 1, 6))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(_ornate_header("MAP OVERVIEW"))
	minimap = StrategoBoardView.new()
	minimap.overview_mode = true
	minimap.interaction_enabled = false
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.custom_minimum_size = Vector2(0, 170)
	minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(minimap)


func _build_view_controls() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 10
	panel.offset_right = REGION_LEFT - 12
	panel.offset_top = -REGION_BOTTOM - 52
	panel.offset_bottom = -REGION_BOTTOM - 6
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, Color(0.55, 0.72, 0.82, 0.45), 1, 6))
	add_child(panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
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


## The round as six named steps. MARCH and MELEE each carry three dots because
## there really are three of each and they alternate: the engine resolves moves,
## then battles, then retreats within *each* impulse. The bar is therefore a
## legend showing where the current event belongs, not a progress meter, and it
## is allowed to jump backwards.
const PHASE_STEPS := [
	{"name": "ORDERS", "dots": 1},
	{"name": "MARCH", "dots": 3},
	{"name": "MELEE", "dots": 3},
	{"name": "MISSILES", "dots": 1},
	{"name": "REPOSITION", "dots": 1},
	{"name": "END TURN", "dots": 1},
]
const STEP_ORDERS := 0
const STEP_MARCH := 1
const STEP_MELEE := 2
const STEP_MISSILES := 3
const STEP_REPOSITION := 4
const STEP_END_TURN := 5

var phase_step_panels: Array[PanelContainer] = []
var phase_step_labels: Array[Label] = []
var phase_step_dots: Array = []
var _active_phase_step := 0


func _build_timeline() -> void:
	timeline_panel = PanelContainer.new()
	timeline_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	timeline_panel.position = Vector2(-620, -74)
	timeline_panel.size = Vector2(1240, 64)
	timeline_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, HUD_GOLD, 1, 8))
	add_child(timeline_panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	timeline_panel.add_child(row)
	for index in PHASE_STEPS.size():
		var step: Dictionary = PHASE_STEPS[index]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(176, 54)
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_phase_step_clicked.bind(index))
		# The chevron and its icon are drawn over the panel, so the step reads as
		# an arrow in a sequence rather than as a box in a row.
		panel.draw.connect(_draw_phase_chevron.bind(panel, index))
		row.add_child(panel)
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 1)
		panel.add_child(column)
		var label := Label.new()
		label.text = "     %d   %s" % [index + 1, String(step.name)]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		column.add_child(label)
		var dot_row := HBoxContainer.new()
		dot_row.alignment = BoxContainer.ALIGNMENT_CENTER
		dot_row.add_theme_constant_override("separation", 5)
		column.add_child(dot_row)
		var dots: Array[Label] = []
		for dot_index in int(step.dots):
			var dot := Label.new()
			dot.text = "●"
			dot.add_theme_font_size_override("font_size", 12)
			dot.add_theme_color_override("font_color", Color("#3d4a4a"))
			dot_row.add_child(dot)
			dots.append(dot)
		phase_step_panels.append(panel)
		phase_step_labels.append(label)
		phase_step_dots.append(dots)
		timeline_stages.append(panel)
		timeline_labels.append(label)


## END TURN is a control, not just a marker: it resolves whatever is left of the
## round without stopping, for a player with no orders left to give.
## Arrow-shaped step with a gold glyph, drawn rather than assembled from
## widgets: Godot has no chevron container and the shape is the point.
func _draw_phase_chevron(panel: PanelContainer, index: int) -> void:
	var box := Vector2(panel.size)
	var notch := box.x * 0.12
	var shape := PackedVector2Array([
		Vector2(0, 0), Vector2(box.x - notch, 0), Vector2(box.x, box.y * 0.5),
		Vector2(box.x - notch, box.y), Vector2(0, box.y), Vector2(notch, box.y * 0.5),
	])
	var active := index == _active_phase_step
	panel.draw_colored_polygon(shape, Color("#12335c") if active else Color(0.03, 0.06, 0.1, 0.9))
	var outline := shape.duplicate()
	outline.append(shape[0])
	panel.draw_polyline(outline, HUD_GOLD if active else Color(HUD_GOLD, 0.55), 2.0 if active else 1.0, true)
	_draw_phase_glyph(panel, index, Vector2(box.x * 0.155, box.y * 0.5), box.y * 0.2)


## Simple gold glyphs, one per step: a shield, a boot, crossed swords, a bow, a
## banner and an hourglass.
func _draw_phase_glyph(panel: PanelContainer, index: int, at: Vector2, radius: float) -> void:
	var gold := Color("#e0b874")
	var line := maxf(1.4, radius * 0.17)
	match index:
		STEP_ORDERS:
			panel.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-radius * 0.7, -radius * 0.8), at + Vector2(radius * 0.7, -radius * 0.8),
				at + Vector2(radius * 0.7, radius * 0.2), at, at + Vector2(-radius * 0.7, radius * 0.2),
			]), gold)
		STEP_MARCH:
			panel.draw_line(at + Vector2(-radius * 0.3, -radius * 0.8), at + Vector2(-radius * 0.3, radius * 0.5), gold, line)
			panel.draw_line(at + Vector2(-radius * 0.3, radius * 0.5), at + Vector2(radius * 0.75, radius * 0.5), gold, line)
			panel.draw_line(at + Vector2(-radius * 0.3, -radius * 0.2), at + Vector2(radius * 0.35, -radius * 0.2), gold, line)
		STEP_MELEE:
			panel.draw_line(at + Vector2(-radius * 0.75, -radius * 0.75), at + Vector2(radius * 0.75, radius * 0.75), gold, line)
			panel.draw_line(at + Vector2(radius * 0.75, -radius * 0.75), at + Vector2(-radius * 0.75, radius * 0.75), gold, line)
		STEP_MISSILES:
			panel.draw_arc(at + Vector2(-radius * 0.2, 0), radius * 0.8, -PI * 0.45, PI * 0.45, 14, gold, line)
			panel.draw_line(at + Vector2(-radius * 0.75, 0), at + Vector2(radius * 0.8, 0), gold, line)
		STEP_REPOSITION:
			panel.draw_line(at + Vector2(-radius * 0.5, radius * 0.8), at + Vector2(-radius * 0.5, -radius * 0.8), gold, line)
			panel.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-radius * 0.45, -radius * 0.75), at + Vector2(radius * 0.8, -radius * 0.4),
				at + Vector2(-radius * 0.45, -radius * 0.05),
			]), gold)
		_:
			panel.draw_line(at + Vector2(-radius * 0.6, -radius * 0.8), at + Vector2(radius * 0.6, -radius * 0.8), gold, line)
			panel.draw_line(at + Vector2(-radius * 0.6, radius * 0.8), at + Vector2(radius * 0.6, radius * 0.8), gold, line)
			panel.draw_line(at + Vector2(-radius * 0.5, -radius * 0.8), at + Vector2(radius * 0.5, radius * 0.8), gold, line)
			panel.draw_line(at + Vector2(radius * 0.5, -radius * 0.8), at + Vector2(-radius * 0.5, radius * 0.8), gold, line)


func _on_phase_step_clicked(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if index == STEP_END_TURN:
		_skip_to_end_of_round()


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


func _show_detail_help() -> void:
	detail_help_hidden = false
	detail_toast.visible = false
	inspector_panel.visible = not resolution_mode


func _build_inspector() -> void:
	inspector_panel = PanelContainer.new()
	inspector_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	inspector_panel.offset_left = -REGION_RIGHT + 12
	inspector_panel.offset_right = -10
	inspector_panel.offset_top = REGION_TOP + 4
	inspector_panel.offset_bottom = -REGION_BOTTOM - 4
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
	box.add_child(_ornate_header("SELECTED UNITS"))
	inspector_cards = VBoxContainer.new()
	inspector_cards.add_theme_constant_override("separation", 5)
	box.add_child(inspector_cards)
	inspector_title = Label.new()
	inspector_title.add_theme_font_size_override("font_size", 20)
	inspector_title.add_theme_color_override("font_color", Color("#f3eee5"))
	box.add_child(inspector_title)
	inspector_title.visible = true
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
	battle_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	battle_panel.offset_left = -REGION_RIGHT + 12
	battle_panel.offset_right = -10
	battle_panel.offset_top = REGION_TOP + 4
	battle_panel.offset_bottom = -REGION_BOTTOM - 4
	battle_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, HUD_GOLD, 1, 7))
	add_child(battle_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	battle_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	box.add_child(_ornate_header("ACTIVE BATTLE"))
	battle_title = Label.new()
	battle_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_title.add_theme_font_size_override("font_size", 20)
	battle_title.add_theme_color_override("font_color", Color("#f3eee5"))
	battle_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(battle_title)
	box.add_child(HSeparator.new())
	battle_body = RichTextLabel.new()
	battle_body.bbcode_enabled = true
	battle_body.scroll_active = false
	battle_body.fit_content = true
	battle_body.add_theme_font_size_override("normal_font_size", 16)
	battle_body.add_theme_color_override("default_color", Color("#dfddd7"))
	# Facing banner cards for the two sides, the numbers between them, and the
	# outcome in one large line at the foot.
	battle_cards = VBoxContainer.new()
	battle_cards.add_theme_constant_override("separation", 4)
	box.add_child(battle_cards)
	battle_stats = GridContainer.new()
	battle_stats.columns = 3
	battle_stats.add_theme_constant_override("h_separation", 10)
	battle_stats.add_theme_constant_override("v_separation", 3)
	box.add_child(battle_stats)
	box.add_child(battle_body)
	var battle_spacer := Control.new()
	battle_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(battle_spacer)
	battle_result = Label.new()
	battle_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_result.add_theme_font_size_override("font_size", 21)
	battle_result.add_theme_color_override("font_color", Color("#efc77c"))
	box.add_child(battle_result)
	battle_result_detail = Label.new()
	battle_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_result_detail.add_theme_font_size_override("font_size", 14)
	battle_result_detail.add_theme_color_override("font_color", Color("#a9a294"))
	box.add_child(battle_result_detail)
	box.add_child(HSeparator.new())
	playback_controls = HBoxContainer.new()
	playback_controls.add_theme_constant_override("separation", 4)
	playback_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(playback_controls)
	playback_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	var playback_column := VBoxContainer.new()
	playback_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playback_column.add_theme_constant_override("separation", 6)
	playback_controls.add_child(playback_column)
	# The contextual action names what pressing it does, so it gets its own row
	# rather than being squeezed between the step buttons.
	playback_pause_button = _make_button("NEXT", 0)
	playback_pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playback_pause_button.clip_text = true
	playback_pause_button.add_theme_font_size_override("font_size", 17)
	playback_pause_button.pressed.connect(_playback_next)
	playback_column.add_child(playback_pause_button)
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 5)
	playback_column.add_child(steps)
	for definition in [["|<", Callable(self, "_playback_first")], ["<", Callable(self, "_playback_previous")], [">", Callable(self, "_playback_next")], [">|", Callable(self, "_playback_last")]]:
		var button := _make_button(String(definition[0]), 0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(definition[1])
		steps.add_child(button)


## The left sidebar fills its reserved region for the whole game. Tabs rather
## than a swap: the log should always be reachable even though it is rarely the
## thing you want to look at, and a tab makes it a glance away.
func _build_event_panel() -> void:
	event_panel = PanelContainer.new()
	event_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	event_panel.offset_left = 10
	event_panel.offset_right = REGION_LEFT - 12
	event_panel.offset_top = REGION_TOP + 4
	event_panel.offset_bottom = -REGION_BOTTOM - 274
	event_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_BG, HUD_GOLD, 1, 7))
	add_child(event_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	event_panel.add_child(margin)
	left_tabs = TabContainer.new()
	left_tabs.add_theme_font_size_override("font_size", 13)
	margin.add_child(left_tabs)

	var roster_scroll := ScrollContainer.new()
	roster_scroll.name = "FORMATIONS"
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_tabs.add_child(roster_scroll)
	roster_list = VBoxContainer.new()
	roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_list.add_theme_constant_override("separation", 5)
	roster_scroll.add_child(roster_list)

	var log_scroll := ScrollContainer.new()
	log_scroll.name = "LOG"
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_tabs.add_child(log_scroll)
	log_list = VBoxContainer.new()
	log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_list.add_theme_constant_override("separation", 3)
	log_scroll.add_child(log_list)
	# The running commentary is kept, hidden, because the settings drawer and
	# several call sites still write prose to it.
	history = RichTextLabel.new()
	history.bbcode_enabled = true
	history.visible = false
	log_box_hidden = VBoxContainer.new()
	log_box_hidden.visible = false
	add_child(log_box_hidden)
	log_box_hidden.add_child(history)

	left_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL


## Builds the round's log entries from its events. Rows carry a type, the
## formation they concern, the round, a one-line summary and a detail payload,
## so filtering and search can be added later without reformatting.
##
## Granularity follows the spec: where a formation ended up, and every battle.
## An impulse in which nothing happened earns no row, and a formation's whole
## march collapses into a single entry naming its destination rather than one
## row per square.
func _rebuild_log(events: Array[Dictionary]) -> void:
	var marches: Dictionary = {}
	for index in events.size():
		var event: Dictionary = events[index]
		if not _event_is_known_to_viewer(event): continue
		var action := String(event.get("action", ""))
		if action == "move":
			var mover := int(event.get("piece_id", StrategoGame.EMPTY))
			if mover < 0: continue
			# Keep only the last step, which is where the formation ended up.
			marches[mover] = {"index": index, "to": event.get("to", Vector2i.ZERO), "from": marches.get(mover, {}).get("from", event.get("from", Vector2i.ZERO))}
			continue
		if action in ["melee", "crossing_battle", "retreat_battle"]:
			log_entries.append(_battle_entry(event, index))
		elif action in ["ranged", "ranged_fizzle"]:
			log_entries.append(_shot_entry(event, index))
	for mover in marches:
		var march: Dictionary = marches[mover]
		if mover >= game.pieces.size(): continue
		var piece: Dictionary = game.pieces[mover]
		log_entries.append({
			"type": "move", "formation": mover, "round": game.round_number,
			"index": int(march.index), "mine": int(piece.player) == StrategoGame.BLUE,
			"summary": "%s marched to %s" % [game.piece_display_code(piece), str(march.to)],
			"detail": "from %s" % str(march.from),
		})
	# Round first: an index only orders events inside the round that produced
	# them, so on its own it interleaves rounds.
	log_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.round) != int(b.round): return int(a.round) < int(b.round)
		return int(a.index) < int(b.index))
	_render_log()


func _battle_entry(event: Dictionary, index: int) -> Dictionary:
	var names: Array[String] = []
	for id in event.get("participants", []):
		if int(id) >= 0 and int(id) < game.pieces.size():
			names.append(game.piece_display_code(game.pieces[int(id)]))
	var winner := int(event.get("winner_id", StrategoGame.EMPTY))
	var outcome := "bounced" if winner == StrategoGame.EMPTY else "%s won" % game.piece_display_code(game.pieces[winner])
	return {
		"type": "battle", "formation": winner, "round": game.round_number, "index": index,
		"mine": winner >= 0 and winner < game.pieces.size() and int(game.pieces[winner].player) == StrategoGame.BLUE,
		"summary": "%s at %s" % [" v ".join(names), str(event.get("to", Vector2i.ZERO))],
		"detail": outcome,
	}


func _shot_entry(event: Dictionary, index: int) -> Dictionary:
	var shooter := int(event.get("shooter_id", StrategoGame.EMPTY))
	var fizzled := String(event.get("action", "")) == "ranged_fizzle"
	var label := "shot fell short" if fizzled else "hit for %d" % int(event.get("defender_damage", 0))
	return {
		"type": "fizzle" if fizzled else "shot", "formation": shooter, "round": game.round_number, "index": index,
		"mine": shooter >= 0 and shooter < game.pieces.size() and int(game.pieces[shooter].player) == StrategoGame.BLUE,
		"summary": "%s %s" % [game.piece_display_code(game.pieces[shooter]) if shooter >= 0 and shooter < game.pieces.size() else "Archer", label],
		"detail": str(event.get("to", Vector2i.ZERO)),
	}


const LOG_TINTS := {
	"move": "#8fa5b8", "battle": "#ffb182", "shot": "#78e2f5", "fizzle": "#7d8794",
}


func _render_log() -> void:
	if log_list == null: return
	for child in log_list.get_children(): child.queue_free()
	# Newest first: the interesting entry is almost always the most recent.
	for offset in log_entries.size():
		var entry: Dictionary = log_entries[log_entries.size() - 1 - offset]
		log_list.add_child(_log_row(entry))


func _log_row(entry: Dictionary) -> Control:
	var row := Button.new()
	row.custom_minimum_size.y = 38
	row.focus_mode = Control.FOCUS_NONE
	row.tooltip_text = String(entry.detail)
	var tint := Color(String(LOG_TINTS.get(String(entry.type), "#c9c6bf")))
	var kind := String(entry.type)
	var quiet := kind == "move"
	row.add_theme_stylebox_override("normal", _log_row_style(Color("#08131d"), tint, quiet))
	row.add_theme_stylebox_override("hover", _log_row_style(Color("#12283c"), tint, false))
	# Clicking an entry jumps playback to it, which is what makes a single list
	# serve in place of a separate battle queue. An index only means anything
	# inside its own round, so older rows are shown but not wired up.
	if int(entry.round) == game.round_number:
		row.pressed.connect(_on_log_row_pressed.bind(int(entry.index)))
	else:
		row.disabled = true
		row.add_theme_stylebox_override("disabled", _log_row_style(Color("#070f16"), tint.darkened(0.4), true))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Clear of the accent edge: a full-rect preset ignores the style's content
	# margin, so the first character sat under the border.
	box.offset_left = 10
	box.offset_right = -6
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	var head := Label.new()
	head.text = "R%d  %s" % [int(entry.round), String(entry.summary)]
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", tint)
	box.add_child(head)
	var tail := Label.new()
	tail.text = String(entry.detail)
	tail.add_theme_font_size_override("font_size", 11)
	tail.add_theme_color_override("font_color", Color("#7f8a93"))
	box.add_child(tail)
	return row


## A row keyed by its kind: the accent runs down the left edge so battles and
## shots pick themselves out of a column of marches.
func _log_row_style(background: Color, accent: Color, quiet: bool) -> StyleBoxFlat:
	var style := _panel_style(background, Color("#243440"), 1, 4)
	style.border_width_left = 2 if quiet else 4
	style.border_color = accent if not quiet else Color(accent, 0.45)
	style.content_margin_left = 8
	return style


func _on_log_row_pressed(event_index: int) -> void:
	if not resolution_mode or event_index < 0 or event_index >= resolution_events.size(): return
	resolution_index = event_index
	_present_resolution_event()


## One row per formation you command, whether or not it is selected, so the
## panel is never empty and doubles as a way to select by clicking.
func _refresh_roster() -> void:
	if roster_list == null or game == null: return
	for child in roster_list.get_children(): child.queue_free()
	var owned: Array[Dictionary] = []
	for piece: Dictionary in game.pieces:
		if piece.alive and int(piece.player) == StrategoGame.BLUE and game.is_movable(piece):
			owned.append(piece)
	owned.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.position.y) * StrategoGame.BOARD_SIZE + int(a.position.x) < int(b.position.y) * StrategoGame.BOARD_SIZE + int(b.position.x)
	)
	for piece: Dictionary in owned:
		roster_list.add_child(_roster_row(piece))


func _roster_row(piece: Dictionary) -> Control:
	var id := int(piece.id)
	var selected := board_view != null and id in board_view.selected_piece_ids
	var row := Button.new()
	row.custom_minimum_size.y = 46
	row.focus_mode = Control.FOCUS_NONE
	row.add_theme_stylebox_override("normal", _panel_style(Color("#0d1c2c") if selected else Color("#08131d"), HUD_BLUE if selected else Color("#2a3a46"), 1, 5))
	row.add_theme_stylebox_override("hover", _panel_style(Color("#12283c"), HUD_BLUE, 1, 5))
	row.pressed.connect(_on_roster_row_pressed.bind(id))
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)

	var swatch := Label.new()
	swatch.text = String(piece.weight).substr(0, 1).to_upper() + String(piece.role).substr(0, 1).to_upper()
	swatch.custom_minimum_size = Vector2(34, 30)
	swatch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	swatch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	swatch.add_theme_font_size_override("font_size", 13)
	swatch.add_theme_stylebox_override("normal", _panel_style(Color("#1b4a86"), _weight_tint(String(piece.weight)), 2, 3))
	line.add_child(swatch)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	line.add_child(text)
	var name_label := Label.new()
	name_label.text = "%s %s" % [String(piece.weight).to_upper(), String(piece.role).to_upper()]
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color("#f0ead6"))
	text.add_child(name_label)
	var stat_label := Label.new()
	# Aiming spends a point, so an Archer that has declared a shot correctly
	# shows one pip already hollow.
	var spent := game.movement_committed(piece)
	var limit := game.movement_limit_for(piece)
	var pips := ""
	for index in limit: pips += "●" if index >= spent else "○"
	stat_label.text = "STR %d/%d    %s" % [int(piece.strength), int(piece.max_strength), pips]
	stat_label.add_theme_font_size_override("font_size", 11)
	stat_label.add_theme_color_override("font_color", Color("#c8a15c"))
	text.add_child(stat_label)

	if not game.order_for_piece(id).is_empty():
		var ordered := Label.new()
		ordered.text = "✓"
		ordered.custom_minimum_size.x = 18
		ordered.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ordered.add_theme_color_override("font_color", Color("#91d33f"))
		line.add_child(ordered)
	return row


func _weight_tint(weight: String) -> Color:
	match weight:
		StrategoGame.WEIGHT_LIGHT: return Color("#8a6233")
		StrategoGame.WEIGHT_MEDIUM: return Color("#9aa3ad")
	return Color("#d3a94b")


func _on_roster_row_pressed(piece_id: int) -> void:
	if board_view == null or not board_view.interaction_enabled: return
	board_view.selected_piece_ids.assign([piece_id])
	board_view.selected_piece_id = piece_id
	board_view.queue_redraw()
	_refresh_roster()
	_update_inspector()


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
	settings_button = _make_button("SETTINGS", 100)
	settings_button.pressed.connect(_toggle_settings)
	game_buttons.add_child(settings_button)
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
	if width > 0 and border.a > 0.2:
		# A second, dimmer rule just inside the first.
		style.shadow_color = Color(border, 0.35)
		style.shadow_size = 2
		style.shadow_offset = Vector2.ZERO
	return style


## A header in the mockups' voice: gold, letterspaced, flanked by rules and a
## diamond. Used wherever a panel names itself.
func _ornate_header(text_value: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var left_rule := Label.new()
	left_rule.text = "—— ♦"
	left_rule.add_theme_font_size_override("font_size", 11)
	left_rule.add_theme_color_override("font_color", Color(HUD_GOLD, 0.7))
	row.add_child(left_rule)
	var title := Label.new()
	# Letterspacing by hand: Godot has no tracking control on Label.
	var spaced := ""
	for index in text_value.length():
		spaced += text_value[index]
		if index < text_value.length() - 1: spaced += " "
	title.text = spaced
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("#e7c47d"))
	row.add_child(title)
	var right_rule := Label.new()
	right_rule.text = "♦ ——"
	right_rule.add_theme_font_size_override("font_size", 11)
	right_rule.add_theme_color_override("font_color", Color(HUD_GOLD, 0.7))
	row.add_child(right_rule)
	return row


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
	if minimap != null:
		minimap.game = game
		minimap.reveal_all = show_all
		minimap.queue_redraw()


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
	_rebuild_log(events)
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
		return
	# A reposition phase nobody can act in has nothing to decide, so it does not
	# stop and ask. Skipping is deferred a frame so the interface settles first.
	if _phase_has_no_decision() and not spectator_mode and not replay_view_mode:
		call_deferred("_on_ready_pressed")
		return
	if spectator_mode and not replay_view_mode:
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
		return "ORDER REPOSITION"
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
	battle_title.text = _battle_name(event)
	battle_result.text = ""
	battle_result_detail.text = ""
	if action == "leftover_move":
		var piece_id := int(event.get("piece_id", StrategoGame.EMPTY))
		var moved: Array[int] = []
		if piece_id >= 0 and piece_id < game.pieces.size(): moved.append(piece_id)
		_refresh_battle_cards(moved)
		for child in battle_stats.get_children(): child.queue_free()
		battle_body.visible = true
		battle_body.text = "[center]%s  ->  %s[/center]" % [str(event.get("from", Vector2i.ZERO)), str(event.get("to", Vector2i.ZERO))]
		battle_result.text = "MOVE COMPLETED"
		return
	var ids: Array = event.get("participants", [])
	if action == "ranged":
		ids = [int(event.get("shooter_id", StrategoGame.EMPTY)), int(event.get("target_id", StrategoGame.EMPTY))]
	var valid_ids: Array[int] = []
	for id_value in ids:
		var id := int(id_value)
		if id >= 0 and id < game.pieces.size():
			valid_ids.append(id)
	_refresh_battle_cards(valid_ids)
	for child in battle_stats.get_children(): child.queue_free()
	if valid_ids.is_empty():
		# Nothing fought, so the outcome line is the whole card.
		battle_body.text = ""
		battle_result_detail.text = _result_detail(event, StrategoGame.EMPTY)
		return
	var winner_id := int(event.get("winner_id", StrategoGame.EMPTY))
	battle_result.text = _result_label(event, winner_id)
	battle_result_detail.text = _result_detail(event, winner_id)
	# Two participants is the ordinary case and reads far better as a comparison
	# than as two stacked blocks. Multiway battles keep the list form.
	if valid_ids.size() == 2:
		_refresh_battle_stats(event, valid_ids)
		battle_body.text = ""
		battle_body.visible = false
		return
	var content := ""
	for index in valid_ids.size():
		var piece: Dictionary = game.pieces[valid_ids[index]]
		var roll := _event_roll(event, valid_ids[index], index)
		# A natural 10 adds a point of damage after Armor, and the score alone
		# never reveals it: a weakened formation caps its score well below 10,
		# so the damage otherwise looks like it does not follow from the numbers.
		var roll_note := "  [color=#e7c47d](natural 10: +1 damage)[/color]" if roll == 10 else ""
		content += "[color=#efc77c][b]%s[/b][/color]\nD10 roll   [b]%d[/b]%s\nFinal score   [b]%d[/b]\nDamage taken   [b]%d[/b]\nRemaining Strength   [b]%d[/b]\n\n" % [game.piece_description(piece), roll, roll_note, _event_score(event, valid_ids[index], index), _event_damage(event, valid_ids[index], index), int(piece.strength)]
	battle_body.text = content
	battle_body.visible = content != ""


## One side of a battle as a banner card: the same shield the board draws, the
## formation's name, and its army. Two of these facing each other say who is
## fighting before a single number has to be read.
func _battle_side_card(piece: Dictionary, footer: String = "") -> Control:
	var tint: Color = board_view._player_colors(int(piece.player)).edge
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(Color("#0b1620"), Color(tint, 0.55), 1, 6))
	var margin := MarginContainer.new()
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 10)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 8)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var shield := Control.new()
	shield.custom_minimum_size = Vector2(46, 46)
	shield.draw.connect(_draw_card_shield.bind(shield, piece))
	row.add_child(shield)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 1)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	var army := Label.new()
	army.text = game.player_name(int(piece.player)).to_upper()
	army.add_theme_font_size_override("font_size", 13)
	army.add_theme_color_override("font_color", tint)
	column.add_child(army)
	var name_label := Label.new()
	name_label.text = "%s %s" % [String(piece.weight).to_upper(), String(piece.role).to_upper()]
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color("#f3eee5"))
	column.add_child(name_label)
	var starting := Label.new()
	starting.text = footer if footer != "" else "STARTING STRENGTH  %d" % int(piece.max_strength)
	starting.add_theme_font_size_override("font_size", 12)
	starting.add_theme_color_override("font_color", Color("#a9a294"))
	column.add_child(starting)
	return card


## The board's banner at card size, so the same shape means the same formation
## whether you are reading the map or the panel.
func _draw_card_shield(host: Control, piece: Dictionary) -> void:
	var width := host.size.x
	var height := host.size.y * 0.94
	var banner := PackedVector2Array([
		Vector2.ZERO, Vector2(width, 0), Vector2(width, height * 0.72),
		Vector2(width * 0.5, height), Vector2(0, height * 0.72),
	])
	host.draw_colored_polygon(banner, board_view._player_colors(int(piece.player)).fill)
	var outline := banner.duplicate()
	outline.append(banner[0])
	var rim := Color("#c69350")
	if String(piece.weight) == StrategoGame.WEIGHT_MEDIUM: rim = Color("#8f9dad")
	elif String(piece.weight) == StrategoGame.WEIGHT_HEAVY: rim = Color("#eef3fa")
	host.draw_polyline(outline, rim, 3.0, true)
	var font := ThemeDB.fallback_font
	var role := String(piece.role).substr(0, 1).to_upper()
	var role_width := font.get_string_size(role, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	host.draw_string(font, Vector2((width - role_width) * 0.5, height * 0.32), role, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f6eee0"))
	var numeral := str(int(piece.strength))
	var numeral_width := font.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	host.draw_string(font, Vector2((width - numeral_width) * 0.5, height * 0.72), numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


## Crossed blades between the two cards, the same mark the board uses for a
## contested square.
func _battle_swords() -> Control:
	var host := Control.new()
	host.custom_minimum_size = Vector2(0, 26)
	host.draw.connect(_draw_swords.bind(host))
	return host


func _draw_swords(host: Control) -> void:
	var middle := host.size * 0.5
	var reach := 11.0
	for sign_value in [-1.0, 1.0]:
		host.draw_line(middle + Vector2(-reach * sign_value, -reach), middle + Vector2(reach * sign_value, reach), Color("#c8a15c"), 2.0, true)
	host.draw_line(middle + Vector2(-52, 0), middle + Vector2(-22, 0), Color(0.55, 0.47, 0.34, 0.45), 1.0)
	host.draw_line(middle + Vector2(22, 0), middle + Vector2(52, 0), Color(0.55, 0.47, 0.34, 0.45), 1.0)


## Rebuild the facing cards for however many formations the event involves.
func _refresh_battle_cards(ids: Array[int]) -> void:
	for child in battle_cards.get_children(): child.queue_free()
	for index in ids.size():
		if index > 0: battle_cards.add_child(_battle_swords())
		battle_cards.add_child(_battle_side_card(game.pieces[ids[index]]))


## A head-to-head grid, laid out so every number in the damage calculation is on
## the page: the raw die, the Strength that capped it, the role bonus, the armour
## that was subtracted, and the natural-10 chip. Without these the damage looks
## like it does not follow from the roll.
func _refresh_battle_stats(event: Dictionary, ids: Array[int]) -> void:
	for child in battle_stats.get_children(): child.queue_free()
	var winner_id := int(event.get("winner_id", StrategoGame.EMPTY))
	var left: Dictionary = game.pieces[ids[0]]
	var right: Dictionary = game.pieces[ids[1]]
	var bonuses: Dictionary = event.get("role_bonuses", {})
	var capped: Dictionary = event.get("capped_rolls", {})
	var values := func(source: Dictionary, id: int) -> int:
		return int(source.get(id, source.get(str(id), 0)))
	var plain := Color("#e6e1d6")
	var rows: Array = []
	rows.append([str(_event_roll(event, ids[0], 0)), "D10 ROLL", str(_event_roll(event, ids[1], 1)), plain])
	if not capped.is_empty():
		rows.append([str(values.call(capped, ids[0])), "CAPPED", str(values.call(capped, ids[1])), plain])
	if not bonuses.is_empty():
		var render := func(value: int) -> String: return "+%d" % value if value > 0 else "0"
		rows.append([render.call(values.call(bonuses, ids[0])), "ROLE", render.call(values.call(bonuses, ids[1])), Color("#9fdc8a")])
	rows.append([str(_event_score(event, ids[0], 0)), "SCORE", str(_event_score(event, ids[1], 1)), Color("#f3eee5")])
	var armour := func(piece: Dictionary) -> String:
		return str(int(piece.armor) * 2) if int(piece.id) == winner_id else str(int(piece.armor))
	rows.append([armour.call(left), "ARMOUR", armour.call(right), plain])
	for index in 2:
		if _event_roll(event, ids[index], index) == 10:
			var chip := ["", "NATURAL 10", "", Color("#e7c47d")]
			chip[index * 2] = "+1"
			rows.append(chip)
			break
	rows.append([str(_event_damage(event, ids[0], 0)), "DAMAGE", str(_event_damage(event, ids[1], 1)), Color("#ff9d84")])
	rows.append([str(int(left.strength)), "LEFT", str(int(right.strength)), plain])
	for row: Array in rows:
		battle_stats.add_child(_stat_cell(String(row[0]), HORIZONTAL_ALIGNMENT_RIGHT, row[3], 16))
		battle_stats.add_child(_stat_cell(String(row[1]), HORIZONTAL_ALIGNMENT_CENTER, Color("#a9a294"), 13))
		battle_stats.add_child(_stat_cell(String(row[2]), HORIZONTAL_ALIGNMENT_LEFT, row[3], 16))


func _stat_cell(text_value: String, alignment: int, tint: Color, size: int) -> Label:
	var cell := Label.new()
	cell.text = text_value
	cell.horizontal_alignment = alignment
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_font_size_override("font_size", size)
	cell.add_theme_color_override("font_color", tint)
	return cell


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
		"leftover_move": return "REPOSITION"
		"no_contact": return "NO VISIBLE CONTACT"
	return "MELEE COMBAT"


func _timeline_index_for_event(event: Dictionary) -> int:
	return int(_phase_step_for_event(event).step)


## Which step owns an event, and which of that step's dots. Retreats resolve as
## part of the melee batch that caused them, so they report as MELEE rather than
## a step of their own.
func _phase_step_for_event(event: Dictionary) -> Dictionary:
	var action := String(event.get("action", ""))
	var batch := String(event.get("batch", ""))
	var impulse := 0
	if batch.begins_with("impulse_"):
		impulse = clampi(int(batch.trim_prefix("impulse_")) - 1, 0, 2)
	if batch == "leftover":
		return {"step": STEP_REPOSITION, "dot": 0}
	if action in ["ranged", "ranged_fizzle"]:
		return {"step": STEP_MISSILES, "dot": 0}
	if action in ["melee", "crossing_battle", "retreat", "retreat_battle", "retreat_collision", "bounce"]:
		return {"step": STEP_MELEE, "dot": impulse}
	return {"step": STEP_MARCH, "dot": impulse}


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
	group_move_title.text = "SET REPOSITION MOVE" if enabled else "MOVE SELECTION"
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
	examined_piece_id = piece_id
	if board_view != null: board_view.clear_selection()
	_update_inspector()
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


## Enter is the single key that moves the round along: it advances one event,
## crosses a phase boundary, and starts the next round, so a whole turn can be
## played without reaching for the mouse.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	var key := event as InputEventKey
	if key.keycode not in [KEY_ENTER, KEY_KP_ENTER]: return
	accept_event()
	if game.game_over: return
	if resolution_mode:
		_playback_next()
	else:
		_on_ready_pressed()


## Resolves whatever remains of the round without pausing, for a player who has
## nothing left to decide.
func _skip_to_end_of_round() -> void:
	if replay_view_mode or game.game_over: return
	var guard := 0
	while guard < 64:
		guard += 1
		if resolution_mode:
			_finish_resolution_presentation()
			continue
		if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING:
			# Nothing is being ordered, so the reposition step is simply skipped.
			_on_ready_pressed()
			continue
		break


## True when a planning phase has no decision in it: nothing the player commands
## is able to act. Such a phase should not stop and ask.
func _phase_has_no_decision() -> bool:
	if game.phase != StrategoGame.PHASE_LEFTOVER_PLANNING: return false
	for piece: Dictionary in game.pieces:
		if game.can_receive_leftover_order(StrategoGame.BLUE, int(piece.id)): return false
	return true


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
	# The top bar keeps its shape all round; only what you may press changes.
	planning_controls.visible = true
	playback_controls.visible = resolution_mode
	inspector_panel.visible = not resolution_mode
	battle_panel.visible = resolution_mode
	# The sidebar is a region, not a pop-up: it is present in every phase and only
	# its contents change.
	event_panel.visible = true
	detail_toast.visible = false
	if resolution_mode:
		phase_title.text = _battle_title()
		phase_subtitle.text = "Verified replay events" if replay_view_mode else "Resolving movement collisions and combat"
		_present_resolution_event()
	elif replay_view_mode:
		phase_title.text = "REPLAY VERIFIED"
		phase_subtitle.text = "%d completed round%s reproduced exactly" % [game.replay_rounds.size(), "" if game.replay_rounds.size() == 1 else "s"]
	elif game.game_over:
		phase_title.text = "BATTLE COMPLETE"
		phase_subtitle.text = "%s · %s" % [game.player_name(game.winner), game.end_reason.replace("_", " ")]
	elif leftover_planning:
		phase_title.text = _battle_title()
		phase_subtitle.text = "Round %d · Issue one optional move to formations with movement remaining" % game.round_number
	else:
		phase_title.text = _battle_title()
		phase_subtitle.text = "Round %d · Issue orders to all formations" % game.round_number
	units_label.text = "Units  %d" % game.count_alive(StrategoGame.BLUE)
	if game.scenario == StrategoGame.SCENARIO_BRIDGE:
		objective_label.text = "OBJECTIVE: Cross the river"
		_refresh_objective_pips(mini(game.bridge_strength_across(), game.bridge_strength_target), game.bridge_strength_target)
	elif game.scenario == StrategoGame.SCENARIO_MEETING and not game.objectives.is_empty():
		var required := int(game.objectives[0].rounds)
		var held := game.objective_streak(0, StrategoGame.BLUE)
		var rival := game.objective_streak(0, StrategoGame.RED)
		objective_label.text = "OBJECTIVE: Hold the centre" + ("    Red %d/%d" % [rival, required] if rival > 0 else "")
		_refresh_objective_pips(held, required)
	else:
		# Destroy-the-army has no countable progress, so the slot carries the
		# objective in words and the pips are cleared rather than left stale.
		objective_label.text = "OBJECTIVE: Destroy the enemy army    %d Strength remaining" % game.total_strength(StrategoGame.BLUE)
		_refresh_objective_pips(0, 0)
	for player in count_labels:
		var label: Label = count_labels[player]
		label.visible = player in game.active_players or player in game.eliminated_players
		label.text = "%s · %d units · %d Strength" % [game.player_name(player), game.count_alive(player), game.total_strength(player)]
	# The primary action names the phase it ends, so the button teaches the round
	# structure rather than saying the same thing throughout.
	ready_button.text = "END REPOSITION" if leftover_planning else "END PLANNING"
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
		_update_timeline(STEP_END_TURN if game.game_over else (STEP_REPOSITION if leftover_planning else STEP_ORDERS))
	group_move_title.text = "SET REPOSITION MOVE" if leftover_planning else "MOVE SELECTION"
	group_move_title.add_theme_color_override("font_color", Color("#f2b15b") if leftover_planning else HUD_BLUE)
	_update_inspector()
	if update_detail and game.game_over:
		detail_label.text = "%s won: %s." % [game.player_name(game.winner), game.end_reason.replace("_", " ")]
	board_view.queue_redraw()


## The scenario's name, which is what belongs in the most prominent slot.
func _battle_title() -> String:
	var name_by_scenario := {
		StrategoGame.SCENARIO_BRIDGE: "Battle of the Ford",
		StrategoGame.SCENARIO_MEETING: "Battle of Oakfield",
		StrategoGame.SCENARIO_SKIRMISH: "Skirmish",
	}
	return "%s  ·  Round %d" % [String(name_by_scenario.get(game.scenario, "Battle")), game.round_number]


## Objective progress as whole pips, filled for rounds already banked. Pips only
## read as a count while you can take them in at a glance, so a large total
## falls back to the ratio in words.
func _refresh_objective_pips(filled: int, total: int) -> void:
	if objective_pips == null: return
	for child in objective_pips.get_children(): child.queue_free()
	if total <= 0: return
	if total > PIP_LIMIT:
		var ratio := Label.new()
		ratio.add_theme_font_size_override("font_size", 15)
		ratio.add_theme_color_override("font_color", Color("#e7c47d"))
		ratio.text = "%d / %d" % [filled, total]
		objective_pips.add_child(ratio)
		return
	for index in total:
		var pip := Label.new()
		pip.text = "\u25cf" if index < filled else "\u25cb"
		pip.add_theme_font_size_override("font_size", 17)
		pip.add_theme_color_override("font_color", Color("#e7c47d") if index < filled else Color(0.55, 0.55, 0.5, 0.6))
		objective_pips.add_child(pip)


func _update_timeline(active_index: int) -> void:
	_active_phase_step = active_index
	var reached: Dictionary = {}
	# Dots fill from the events already played, so an impulse that produced no
	# battles leaves its MELEE dot hollow rather than compacting the row.
	for index in mini(resolution_index, resolution_events.size()):
		var placement := _phase_step_for_event(resolution_events[index])
		reached["%d:%d" % [int(placement.step), int(placement.dot)]] = true
	for index in phase_step_panels.size():
		var completed := (resolution_mode or game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING) and index < active_index
		phase_step_panels[index].queue_redraw()
		phase_step_labels[index].add_theme_color_override("font_color", HUD_BLUE if index == active_index else Color("#c9c6bf"))
		var dots: Array = phase_step_dots[index]
		for dot_index in dots.size():
			var lit: bool = reached.has("%d:%d" % [index, dot_index])
			if index == STEP_ORDERS: lit = resolution_mode or game.round_number > 1
			dots[dot_index].add_theme_color_override("font_color", Color("#6fbf63") if lit else Color("#3d4a4a"))


## What the player is entitled to know about a formation, and what its Weight and
## Role actually do. Stating the effects beside the numbers means a player need
## not have memorised the rules to read a banner.
func _formation_detail(piece: Dictionary) -> String:
	var role_note: String = {
		StrategoGame.ROLE_INFANTRY: "+%d when defending" % StrategoGame.ROLE_BONUS,
		StrategoGame.ROLE_CAVALRY: "+%d when attacking" % StrategoGame.ROLE_BONUS,
		StrategoGame.ROLE_ARCHER: "no melee bonus; shoots at range",
	}.get(String(piece.role), "")
	var remaining := maxi(0, game.movement_limit_for(piece) - game.movement_committed(piece))
	var text := "[table=2]"
	text += "[cell]Strength[/cell][cell][right]%d / %d[/right][/cell]" % [int(piece.strength), int(piece.max_strength)]
	text += "[cell]Armour[/cell][cell][right]%d[/right][/cell]" % int(piece.armor)
	text += "[cell]Movement[/cell][cell][right]%d of %d left[/right][/cell]" % [remaining, game.movement_limit_for(piece)]
	text += "[/table]
"
	text += "[color=#9fc8e8]%s[/color] · %s
" % [String(piece.role).capitalize(), role_note]
	text += "[color=#c8a15c]%s[/color] · armour %d, moves %d
" % [
		String(piece.weight).capitalize(), int(piece.armor), game.movement_limit_for(piece),
	]
	if int(piece.strength) < int(piece.max_strength):
		# The roll is capped by current Strength, so damage quietly weakens a
		# formation's dice as well as its life.
		text += "
[color=#ffd9a8]Damaged: its die cannot roll above %d.[/color]" % int(piece.strength)
	return text


## Examine fills the same panel that shows your own formations, because it is the
## same question asked of a different subject. For an enemy the honest answer may
## be very little, and showing that emptiness is itself informative.
func _show_examined(piece: Dictionary) -> void:
	inspector_title.text = "%s %s" % [game.player_name(int(piece.player)).to_upper(), "FORMATION"]
	if game.is_piece_revealed_to(piece, StrategoGame.BLUE) or int(piece.player) == StrategoGame.BLUE:
		inspector_title.text = "%s %s" % [String(piece.weight).to_upper(), String(piece.role).to_upper()]
		inspector_stats.text = _formation_detail(piece)
		inspector_order.text = "Examined · %s" % game.player_name(int(piece.player))
		return
	inspector_stats.text = "This formation has not been identified.

Fighting it reveals its Role, Weight and current Strength. Watching it move reveals its Weight, since speed follows from it."
	inspector_order.text = "Examined · identity unknown"


## The selection as banner cards. A long selection is summarised rather than
## listed: past a handful the cards stop being readable and start being a wall.
func _refresh_inspector_cards() -> void:
	for child in inspector_cards.get_children(): child.queue_free()
	if board_view == null or game == null: return
	var ids: Array = board_view.selected_piece_ids
	if ids.is_empty() and examined_piece_id >= 0 and examined_piece_id < game.pieces.size():
		ids = [examined_piece_id]
	for index in mini(ids.size(), SELECTION_CARD_LIMIT):
		var piece_id := int(ids[index])
		if piece_id < 0 or piece_id >= game.pieces.size(): continue
		inspector_cards.add_child(_battle_side_card(game.pieces[piece_id], _order_footer(piece_id)))
	if ids.size() > SELECTION_CARD_LIMIT:
		var more := Label.new()
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		more.text = "+ %d more selected" % (ids.size() - SELECTION_CARD_LIMIT)
		more.add_theme_font_size_override("font_size", 13)
		more.add_theme_color_override("font_color", Color("#a9a294"))
		inspector_cards.add_child(more)


## What a formation has been told to do, in the space the battle card gives to
## starting Strength.
func _order_footer(piece_id: int) -> String:
	var order := game.order_for_piece(piece_id)
	if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING:
		var leftover: Vector2i = order.get("leftover", Vector2i(-1, -1))
		return "REPOSITION TO %s" % str(leftover) if leftover.x >= 0 else "NO REPOSITION SET"
	if order.is_empty(): return "NO ORDER ISSUED"
	var path: Array = order.get("path", [])
	var aimed: Vector2i = order.get("ranged_target", Vector2i(-1, -1))
	if aimed.x >= 0: return "AIMED AT %s" % str(aimed)
	return "ORDERED  %d IMPULSE%s" % [path.size(), "" if path.size() == 1 else "S"]


func _update_inspector() -> void:
	_refresh_roster()
	_refresh_inspector_cards()
	inspector_title.visible = true
	if examined_piece_id >= 0 and examined_piece_id < game.pieces.size() and board_view != null and board_view.selected_piece_ids.is_empty():
		_show_examined(game.pieces[examined_piece_id])
		return
	if group_move_controls != null:
		group_move_controls.visible = board_view != null and board_view.interaction_enabled and not board_view.selected_piece_ids.is_empty()
	if board_view == null or game == null or board_view.selected_piece_ids.is_empty():
		inspector_title.text = "NOTHING SELECTED"
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
	inspector_title.visible = false
	inspector_title.text = ""
	inspector_stats.text = _formation_detail(piece)
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
	log_entries.clear()
	if log_list != null:
		for child in log_list.get_children(): child.queue_free()
	history.clear()
	settings_history.clear()


func _log_line(text_value: String, important: bool = false) -> void:
	var formatted := ("[color=#f8df9a][b]%s[/b][/color]" if important else "%s") % text_value
	for target in [history, settings_history]:
		if target == null:
			continue
		target.append_text(formatted + "\n")
		target.scroll_to_line(maxi(0, target.get_line_count() - 1))
