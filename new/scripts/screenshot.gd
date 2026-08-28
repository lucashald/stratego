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


func _initialize() -> void:
	var arguments := _parse_arguments()
	_out = String(arguments.get("out", _out))
	_frames = int(arguments.get("frames", _frames))
	_scenario = String(arguments.get("scenario", _scenario))
	# Fog leaves most of the board dark, which hides the very layout being checked.
	_reveal = String(arguments.get("reveal", "0")) == "1"
	# Play a round so the resolution-phase panels can be checked too.
	_resolve = String(arguments.get("resolve", "0")) == "1"
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
		if _scenario == StrategoGame.SCENARIO_BRIDGE and _main.has_method("start_bridge_game"):
			_main.start_bridge_game()
		elif _main.has_method("start_meeting_game"):
			_main.start_meeting_game()
		if _resolve:
			_main.call_deferred("_on_ready_pressed")
	if _started and _reveal and _main.get("board_view") != null:
		_main.board_view.reveal_all = true
		_main.board_view.queue_redraw()
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
