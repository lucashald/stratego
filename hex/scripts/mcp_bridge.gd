class_name StrategoMCPBridge
extends Node

# Newline-delimited JSON command server. One JSON object per line in, one per
# line out, paired by "id". Deliberately not HTTP: both ends are local and
# GDScript has no request parser worth hand-rolling for this.
#
# The bridge owns no rules. Every command forwards to StrategoGame and returns
# whatever it returns, so an external controller hits exactly the same
# validation the UI does.

# 8791 rather than a rounder number: 8765 and 8188 are commonly taken by other
# local tooling on this machine.
const DEFAULT_PORT := 8791

signal command_handled(command: String, ok: bool)
## Emitted when a remotely controlled army locks in its orders, so a host that
## owns the round loop (the real app) knows it can try to resolve.
signal player_committed(player: int)

var game: StrategoGame = null
var controlled_player := StrategoGame.BLUE
var bot: StrategoBotPolicy = null
var rng := RandomNumberGenerator.new()

var _server := TCPServer.new()
var _clients: Array[StreamPeerTCP] = []
var _buffers: Array[String] = []
var _last_events: Array[Dictionary] = []
# Every event of the match, tagged with the round it came from. _last_events is
# overwritten each resolution; this is what survives to the end of the game.
var _match_events: Array[Dictionary] = []


func start(port: int = DEFAULT_PORT) -> Error:
	var result := _server.listen(port, "127.0.0.1")
	if result == OK: print("[mcp] listening on 127.0.0.1:%d" % port)
	else: printerr("[mcp] could not listen on port %d: %d" % [port, result])
	return result


func stop() -> void:
	for client: StreamPeerTCP in _clients: client.disconnect_from_host()
	_clients.clear()
	_buffers.clear()
	_server.stop()


func _process(_delta: float) -> void:
	while _server.is_connection_available():
		_clients.append(_server.take_connection())
		_buffers.append("")
	for index in range(_clients.size() - 1, -1, -1):
		var client: StreamPeerTCP = _clients[index]
		client.poll()
		if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_clients.remove_at(index)
			_buffers.remove_at(index)
			continue
		var available := client.get_available_bytes()
		if available > 0:
			_buffers[index] += client.get_utf8_string(available)
		while "\n" in _buffers[index]:
			var split := _buffers[index].split("\n", true, 1)
			_buffers[index] = split[1] if split.size() > 1 else ""
			var line := String(split[0]).strip_edges()
			if not line.is_empty(): _send(client, _handle_line(line))


func _send(client: StreamPeerTCP, payload: Dictionary) -> void:
	client.put_data((JSON.stringify(payload) + "\n").to_utf8_buffer())


func _handle_line(line: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(line)
	if not parsed is Dictionary:
		return {"id": null, "ok": false, "error": "Request must be a JSON object."}
	var request: Dictionary = parsed
	var id: Variant = request.get("id", null)
	var command := String(request.get("command", ""))
	var args: Dictionary = request.get("args", {}) if request.get("args") is Dictionary else {}
	var response: Dictionary
	if game == null:
		response = {"ok": false, "error": "No game is loaded."}
	else:
		response = _dispatch(command, args)
	response["id"] = id
	response["command"] = command
	command_handled.emit(command, bool(response.get("ok", false)))
	return response


func _dispatch(command: String, args: Dictionary) -> Dictionary:
	match command:
		"ping": return {"ok": true, "pong": true}
		"get_state": return {"ok": true, "state": game.observed_state(controlled_player)}
		"legal_steps": return _legal_steps(args)
		"new_game": return _new_game(args)
		"set_order": return _set_order(args)
		"clear_orders": return _clear_orders(args)
		"set_player": return _set_player(args)
		"commit": return _commit()
		"end_planning": return _end_planning()
		"auto_deploy": return _auto_deploy()
		"get_events": return {"ok": true, "events": _last_events}
		"get_history": return _get_history(args)
		"save_replay": return _save_replay(args)
		_: return {"ok": false, "error": "Unknown command: %s" % command}


func _get_history(args: Dictionary) -> Dictionary:
	var summary := game.combat_damage_summary()
	var rows: Array = []
	for id in summary:
		var row: Dictionary = summary[id]
		if int(row.battles) > 0 or not bool(row.alive): rows.append(row)
	rows.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return int(first.dealt) > int(second.dealt)
	)
	var response := {"ok": true, "damage": rows, "combats": game.battle_history.size()}
	if bool(args.get("events", false)): response["events"] = _match_events
	if bool(args.get("combats", true)): response["battle_history"] = game.battle_history
	return response


func _save_replay(args: Dictionary) -> Dictionary:
	var path := String(args.get("path", "res://replays/mcp_match.json"))
	var result := game.save_replay(path)
	return {
		"ok": bool(result.get("ok", false)), "path": String(result.get("path", path)),
		"rounds": int(result.get("rounds", 0)), "message": String(result.get("message", "")),
	}


func _legal_steps(args: Dictionary) -> Dictionary:
	var piece_id := int(args.get("piece_id", -1))
	var steps: Array = []
	for step: Vector2i in game.legal_steps_for(piece_id): steps.append([step.x, step.y])
	return {"ok": true, "piece_id": piece_id, "steps": steps}


func _new_game(args: Dictionary) -> Dictionary:
	var seed_value := int(args.get("seed", 0))
	var scenario := String(args.get("scenario", StrategoGame.SCENARIO_BRIDGE))
	if scenario == StrategoGame.SCENARIO_BRIDGE:
		game.setup_bridge(seed_value)
		controlled_player = game.bridge_attacker
	elif scenario == StrategoGame.SCENARIO_MEETING:
		game.setup_meeting(seed_value)
		controlled_player = StrategoGame.BLUE
	elif scenario == StrategoGame.SCENARIO_CROSSROADS:
		game.setup_crossroads(seed_value)
		controlled_player = StrategoGame.BLUE
	else:
		game.setup_random(seed_value, int(args.get("player_count", 4)))
		controlled_player = StrategoGame.BLUE
	rng.seed = seed_value
	_last_events = []
	_match_events = []
	return {"ok": true, "state": game.observed_state(controlled_player)}


func _to_vector(value: Variant) -> Vector2i:
	if value is Array and value.size() == 2: return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


func _set_order(args: Dictionary) -> Dictionary:
	var piece_id := int(args.get("piece_id", -1))
	var path: Array[Vector2i] = []
	for step in args.get("path", []): path.append(_to_vector(step))
	if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING:
		var leftover := _to_vector(args.get("leftover", args.get("path", []).back() if not path.is_empty() else null))
		var leftover_result := game.set_leftover_order(controlled_player, piece_id, leftover)
		return {"ok": bool(leftover_result.get("ok", false)), "message": String(leftover_result.get("message", ""))}
	# ranged_target_id names a formation (aimed fire); omit it to suppress the
	# square instead.
	var result := game.set_unit_order(
		controlled_player, piece_id, path,
		_to_vector(args.get("ranged_target", null)), _to_vector(args.get("leftover", null)),
		int(args.get("ranged_target_id", -1))
	)
	return {"ok": bool(result.get("ok", false)), "message": String(result.get("message", ""))}


## Locks in the current side's orders without resolving, so the other army can
## be given its orders before the round is worked out. Without this, ending the
## round would hand any un-readied player to the bot.
func _commit() -> Dictionary:
	var result := game.mark_player_ready(controlled_player)
	player_committed.emit(controlled_player)
	return {"ok": bool(result.get("ok", true)), "ready": game.ready_players.duplicate()}


## Switches which side subsequent orders belong to, so one connection can drive
## both armies. Any player left without orders is still planned by the bot.
func _set_player(args: Dictionary) -> Dictionary:
	var player := int(args.get("player", controlled_player))
	if player not in game.active_players:
		return {"ok": false, "error": "That player is not in this game."}
	controlled_player = player
	return {"ok": true, "player": controlled_player, "state": game.observed_state(controlled_player)}


func _clear_orders(args: Dictionary) -> Dictionary:
	if args.has("piece_id"): game.clear_unit_order(controlled_player, int(args.get("piece_id", -1)))
	else: game.clear_player_orders(controlled_player)
	return {"ok": true}


# Marks the controlled player ready, lets the bot plan for everyone else, then
# resolves. Mirrors main.gd's _on_ready_pressed / _plan_unready_bots pair.
func _end_planning() -> Dictionary:
	if game.game_over: return {"ok": false, "error": "The game is over."}
	if game.phase not in [StrategoGame.PHASE_PLANNING, StrategoGame.PHASE_LEFTOVER_PLANNING]:
		return {"ok": false, "error": "Not in a planning phase."}
	var leftover_phase := game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING
	var resolved_round := game.round_number
	game.mark_player_ready(controlled_player)
	for player in game.active_players:
		if player == controlled_player or player in game.ready_players: continue
		if leftover_phase: bot.plan_leftover(game, player, rng)
		else: bot.plan_round(game, player, rng)
		game.mark_player_ready(player)
	if not game.all_players_ready(): return {"ok": false, "error": "Not every player is ready."}
	_last_events = game.resolve_leftover_phase() if leftover_phase else game.resolve_main_and_ranged()
	for event: Dictionary in _last_events:
		var tagged := event.duplicate(true)
		tagged["round"] = resolved_round
		tagged["phase"] = "leftover" if leftover_phase else "main"
		_match_events.append(tagged)
	return {
		"ok": true, "resolved": "leftover" if leftover_phase else "main",
		"events": _last_events, "state": game.observed_state(controlled_player),
	}


## The lazy path for a remote commander who does not want to place formations
## by hand: resets the controlled player to the recommended deployment (in
## case anything was already dragged around) and, like end_planning, locks in
## every other unready player too rather than waiting on them. No bot planning
## is needed for the others; accepting the recommended formation already is
## what a bot does here.
func _auto_deploy() -> Dictionary:
	if game.game_over: return {"ok": false, "error": "The game is over."}
	if game.phase != StrategoGame.PHASE_DEPLOYMENT:
		return {"ok": false, "error": "Not in the deployment phase."}
	game.reset_deployment(controlled_player)
	for player in game.active_players:
		if player not in game.ready_players: game.mark_player_ready(player)
	if not game.resolve_deployment():
		return {"ok": false, "error": "Deployment did not resolve."}
	return {"ok": true, "state": game.observed_state(controlled_player)}
