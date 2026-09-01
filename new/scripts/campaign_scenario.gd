class_name CampaignScenario
extends RefCounted

## Builds a battle from a JSON description instead of a hardcoded setup.
##
## The shipped scenarios each place a fixed roster on fixed ground, which is
## exactly wrong for a campaign: an army that carries its dead and its damage
## between battles is different every time it fights, and the fight has to be
## built around whatever is left of it. This puts named formations with their
## own current Strength on chosen squares, so a scenario can be written to suit
## the force that survived the last one.
##
## Everything here goes through the ordinary engine calls the shipped scenarios
## use, so a loaded battle is not a special case once it starts. The resolver,
## fog, replay and bot all see a normal game.

const CODES := {
	"LI": StrategoGame.LIGHT_INFANTRY, "MI": StrategoGame.MEDIUM_INFANTRY, "HI": StrategoGame.HEAVY_INFANTRY,
	"LA": StrategoGame.LIGHT_ARCHER, "MA": StrategoGame.MEDIUM_ARCHER, "HA": StrategoGame.HEAVY_ARCHER,
	"LC": StrategoGame.LIGHT_CAVALRY, "MC": StrategoGame.MEDIUM_CAVALRY, "HC": StrategoGame.HEAVY_CAVALRY,
	"F": StrategoGame.FLAG,
}
const SIDES := {"blue": StrategoGame.BLUE, "red": StrategoGame.RED}


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "message": "No scenario at %s" % path}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {"ok": false, "message": "%s is not a JSON object" % path}
	return {"ok": true, "data": parsed}


## Configures `game` in place. Returns {ok, message, piece_ids} where piece_ids
## maps the scenario's own formation names onto engine ids, which is what lets a
## campaign follow one formation across several battles.
static func apply(game: StrategoGame, data: Dictionary) -> Dictionary:
	game.setup_empty()
	game.scenario = StrategoGame.SCENARIO_CAMPAIGN
	# Kept verbatim so a replay reconstructs this exact battle - army, ground
	# and objective - rather than a generic scenario standing in for it.
	game.campaign_battle_data = data.duplicate(true)
	game.configured_player_count = 2
	game.private_battle_results = bool(data.get("private_battle_results", true))
	game.player_teams[StrategoGame.BLUE] = StrategoGame.BLUE
	game.player_teams[StrategoGame.RED] = StrategoGame.RED

	var terrain: Dictionary = data.get("terrain", {})
	if bool(terrain.get("lakes", false)):
		game.apply_lake_terrain()
	for cell in terrain.get("open", []):
		game.set_terrain(_vector(cell), StrategoGame.TERRAIN_OPEN)
	for cell in terrain.get("water", []):
		game.set_terrain(_vector(cell), StrategoGame.TERRAIN_WATER)
	for cell in terrain.get("bridge", []):
		game.set_terrain(_vector(cell), StrategoGame.TERRAIN_BRIDGE)

	var piece_ids: Dictionary = {}
	for side in SIDES:
		for entry in data.get("armies", {}).get(side, []):
			var result := _place(game, int(SIDES[side]), entry)
			if not bool(result.get("ok", false)):
				return result
			piece_ids[String(entry.get("name", ""))] = int(result.id)

	var objective_result := _objective(game, data.get("objective", {}), int(data.get("turn_limit", 25)))
	if not bool(objective_result.get("ok", false)):
		return objective_result

	game.active_players.assign([StrategoGame.RED, StrategoGame.BLUE])
	game._sort_active_players()
	game.current_player = StrategoGame.BLUE
	game._record_all_sightings()
	return {"ok": true, "piece_ids": piece_ids, "message": String(data.get("name", "Battle"))}


static func _place(game: StrategoGame, player: int, entry: Dictionary) -> Dictionary:
	var code := String(entry.get("type", "")).to_upper()
	if code not in CODES:
		return {"ok": false, "message": "Unknown formation code '%s'" % code}
	var cell := _vector(entry.get("at", []))
	if not game.is_inside(cell):
		return {"ok": false, "message": "%s is off the board" % str(cell)}
	if game.is_blocked_terrain(cell):
		return {"ok": false, "message": "%s is blocked terrain" % str(cell)}
	if not game.piece_at(cell).is_empty():
		return {"ok": false, "message": "%s already holds a formation" % str(cell)}
	# Strength carries over from the last battle, so a veteran arrives already
	# hurt rather than being restored to full by the setup.
	var strength := int(entry.get("strength", -1))
	var id := game.add_piece(CODES[code], player, cell, strength)
	return {"ok": true, "id": id}


static func _objective(game: StrategoGame, objective: Dictionary, turn_limit: int) -> Dictionary:
	var kind := String(objective.get("kind", "eliminate"))
	match kind:
		"eliminate":
			game.add_eliminate_objective(turn_limit)
		"hold":
			game.add_hold_square_objective(_vector(objective.get("square", [10, 10])),
				int(objective.get("rounds", 3)), turn_limit)
		"reach":
			# The escape battle: get enough Strength off the far edge rather
			# than win the fight. Paired with survive for the other side, this
			# is a fighting withdrawal.
			var area: Array = objective.get("area", [])
			if area.size() != 4:
				return {"ok": false, "message": "reach objective needs area [x, y, w, h]"}
			game.add_reach_area_objective(int(SIDES.get(String(objective.get("side", "blue")), StrategoGame.BLUE)),
				Rect2i(int(area[0]), int(area[1]), int(area[2]), int(area[3])),
				int(objective.get("strength", 10)), String(objective.get("reason", "escaped")))
		"survive":
			game.add_survive_objective(int(SIDES.get(String(objective.get("side", "red")), StrategoGame.RED)),
				int(objective.get("until_round", turn_limit)), String(objective.get("reason", "held_out")))
		_:
			return {"ok": false, "message": "Unknown objective kind '%s'" % kind}
	# A second objective may be layered on, which is how one side racing for an
	# edge and the other trying to stop them becomes a single battle.
	if objective.has("also"):
		return _objective(game, objective.also, turn_limit)
	return {"ok": true}


static func _vector(value: Variant) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)
