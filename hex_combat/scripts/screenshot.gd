extends SceneTree

# Renders the real interface to a PNG so UI work can be checked without a person
# looking at the screen. Runs the app windowed, lets it settle for a number of
# frames, saves the viewport, and quits.
#
#   godot --path . --script res://scripts/screenshot.gd -- --out shot.png --scenario meeting

var _out := "ui_shot.png"
var _frames := 30
var _counted := 0
var _scenario := StrategoGame.SCENARIO_MEETING
var _main: Node = null
var _started := false
var _reveal := false
var _resolve := false
var _zoom := 0.0
var _pan := Vector2.ZERO
var _tab := -1
var _rounds := 0
var _spectate := false
var _deploy_from := Vector2i(-1, -1)
var _deploy_to := Vector2i(-1, -1)
var _open_settings := false
var _select := 0
var _played := 0


func _initialize() -> void:
	var arguments := _parse_arguments()
	_out = String(arguments.get("out", _out))
	_frames = int(arguments.get("frames", _frames))
	_scenario = String(arguments.get("scenario", _scenario))
	# Fog leaves most of the board dark, which hides the very layout being checked.
	_reveal = String(arguments.get("reveal", "0")) == "1"
	# Play a round so the resolution-phase panels can be checked too.
	_resolve = String(arguments.get("resolve", "0")) == "1"
	_zoom = float(arguments.get("zoom", "0"))
	_pan = Vector2(float(arguments.get("panx", "0")), float(arguments.get("pany", "0")))
	_tab = int(arguments.get("tab", "-1"))
	# Play whole rounds before shooting, so a real melee card can be checked.
	_rounds = int(arguments.get("rounds", "0"))
	# Exercises the actual click handler end to end, not just the engine call it
	# wraps: --deployfrom x,y --deployto x,y (engine cell coordinates).
	_open_settings = String(arguments.get("settings", "0")) == "1"
	if arguments.has("deployfrom") and arguments.has("deployto"):
		var from_parts := String(arguments.deployfrom).split(",")
		var to_parts := String(arguments.deployto).split(",")
		_deploy_from = Vector2i(int(from_parts[0]), int(from_parts[1]))
		_deploy_to = Vector2i(int(to_parts[0]), int(to_parts[1]))
	# Both sides driven by the bot, so battles actually happen unattended.
	_spectate = String(arguments.get("spectate", "0")) == "1"
	# Select a few of the viewer's formations so the detail panel has content.
	_select = int(arguments.get("select", "0"))
	# In a SceneTree script `root` is the Window itself.
	root.size = Vector2i(int(arguments.get("width", 1600)), int(arguments.get("height", 900)))
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_counted += 1
	# Switch scenario once the interface has built itself, not during _initialize.
	if not _started and _counted >= 3:
		_started = true
		if _spectate and _main.has_method("start_spectator_game"):
			_main.start_spectator_game()
		elif _scenario == StrategoGame.SCENARIO_BRIDGE and _main.has_method("start_bridge_game"):
			_main.start_bridge_game()
		elif _scenario == StrategoGame.SCENARIO_CROSSROADS and _main.has_method("start_crossroads_game"):
			_main.start_crossroads_game()
		elif _main.has_method("start_meeting_game"):
			_main.start_meeting_game()
		if _zoom > 0.0 and _main.get("board_view") != null:
			_main.board_view.zoom_level = _zoom
			_main.board_view.pan_offset = _pan
			_main.board_view.queue_redraw()
		if _deploy_from.x >= 0 and _main.get("board_view") != null:
			var geometry: Dictionary = _main.board_view._board_geometry()
			_main.board_view._handle_deployment_click(_main.board_view._cell_center(_deploy_from, geometry.origin, geometry.cell))
			_main.board_view._handle_deployment_click(_main.board_view._cell_center(_deploy_to, geometry.origin, geometry.cell))
		if _open_settings and _main.has_method("_toggle_settings"):
			_main._toggle_settings()
		if _resolve and _rounds <= 0:
			_main.call_deferred("_on_ready_pressed")
	if _started and _reveal and _main.get("board_view") != null:
		_main.board_view.reveal_all = true
		_main.board_view.queue_redraw()
	if _select > 0 and _started and _counted == 5 and _main.get("board_view") != null:
		var chosen: Array[int] = []
		for piece in _main.game.pieces:
			if int(piece.player) == StrategoGame.BLUE and bool(piece.alive) and chosen.size() < _select:
				chosen.append(int(piece.id))
		_main.board_view.selected_piece_ids = chosen
		if not chosen.is_empty(): _main.board_view.selected_piece_id = chosen[0]
		_main._update_inspector()
	if _tab >= 0 and _main.get("left_tabs") != null:
		_main.left_tabs.current_tab = _tab
	# One round per handful of frames: end planning, skip its playback, repeat.
	if _rounds > 0 and _started and _counted % 6 == 0 and not _main.game.game_over:
		if bool(_main.resolution_mode):
			_main._skip_to_end_of_round()
		elif _played < _rounds:
			_played += 1
			_main._on_ready_pressed()
			if _played >= _rounds and _resolve: _rounds = 0
	if _counted < _frames: return false
	var image := root.get_texture().get_image()
	image.save_png(_out)
	print("[shot] wrote %s (%dx%d)" % [_out, image.get_width(), image.get_height()])
	return true


func _parse_arguments() -> Dictionary:
	var result := {}
	var arguments := OS.get_cmdline_user_args()
	for index in arguments.size():
		var argument := String(arguments[index])
		if argument.begins_with("--") and index + 1 < arguments.size():
			result[argument.substr(2)] = arguments[index + 1]
	return result
