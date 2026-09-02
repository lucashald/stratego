extends SceneTree

# Headless host for the MCP bridge. Starts a bridge-scenario game with the
# heuristic bot on the defending side and serves commands until killed.
#
#   godot --headless --path . --script res://scripts/mcp_host.gd -- --port 8765 --seed 7

var bridge: StrategoMCPBridge = null


func _initialize() -> void:
	var arguments := _parse_arguments()
	var game := StrategoGame.new()
	game.setup_bridge(int(arguments.get("seed", 0)))
	bridge = StrategoMCPBridge.new()
	bridge.game = game
	bridge.bot = StrategoBotPolicy.new()
	bridge.controlled_player = game.bridge_attacker
	bridge.rng.seed = int(arguments.get("seed", 0))
	root.add_child(bridge)
	if bridge.start(int(arguments.get("port", StrategoMCPBridge.DEFAULT_PORT))) != OK:
		quit(1)
		return
	print("[mcp] bridge scenario ready; controlling player %d" % bridge.controlled_player)


func _finalize() -> void:
	if bridge != null: bridge.stop()


func _parse_arguments() -> Dictionary:
	var result := {}
	var arguments := OS.get_cmdline_user_args()
	for index in arguments.size():
		var argument := String(arguments[index])
		if argument.begins_with("--") and index + 1 < arguments.size():
			result[argument.substr(2)] = arguments[index + 1]
	return result
