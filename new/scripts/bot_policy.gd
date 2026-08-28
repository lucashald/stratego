class_name StrategoBotPolicy
extends RefCounted

# The WEGO bot produces complete simultaneous orders and exercises the real
# collision validator instead of taking privileged sequential actions. Classic's
# trained policy remains untouched in classic/.
#
# Orders are chosen per formation rather than per army: the joint action space of
# twelve formations each with a multi-step path is far too large to enumerate, so
# each formation picks its own best order in turn and the engine's validator
# prunes anything that collides with an earlier choice.
#
# Every candidate order is scored as a weighted sum of features. Candidates are
# scored before being submitted, because validation is the expensive part; only
# the best few are actually offered to the engine.

const WEIGHT_DEFAULTS := {
	"objective_progress": 1.0,      # closing on the scenario's aim point
	"objective_occupy": 6.0,        # standing on the square a scenario is won by
	"fight_advantage": 2.2,         # expected melee edge when entering an enemy
	"losing_fight": -7.0,           # scaled penalty for attacking at a disadvantage
	"defend_in_place": 1.2,         # standing firm once contact is already made
	"infantry_receives": 1.8,       # extra for Infantry, whose bonus needs defending
	"cavalry_charges": 1.5,         # extra for Cavalry, whose bonus needs attacking
	"support": 0.5,                 # ending next to a friendly formation
	"archer_exposure": -0.8,        # ending within shot of an enemy Archer
	"ranged_damage": 1.6,           # expected damage from a declared shot
	"finish_target": 2.0,           # preferring targets a shot can actually kill
	"idle": -1.2,                   # holding for no reason
	"unknown_risk": -1.5,           # flat caution about fighting the unidentified
}

## What the bot pretends an unidentified enemy is when it has to judge a fight.
## Deliberately a parameter rather than a constant: which assumption plays best
## is an empirical question, and two bots holding different assumptions can be
## matched against each other to settle it.
const ASSUMPTION_DEFAULTS := {
	"role": StrategoGame.ROLE_INFANTRY,
	"weight": StrategoGame.WEIGHT_MEDIUM,
	"strength": 5,
}

var weights: Dictionary = WEIGHT_DEFAULTS.duplicate(true)
var assumptions: Dictionary = ASSUMPTION_DEFAULTS.duplicate(true)


## A stand-in for an enemy whose identity has not been earned. Keeps the real
## position so collision logic still works, and substitutes assumed statistics
## for the ones the bot has no right to read.
func _assumed_enemy(actual: Dictionary) -> Dictionary:
	var weight := String(assumptions.get("weight", StrategoGame.WEIGHT_MEDIUM))
	return {
		"id": actual.get("id", -1), "player": actual.get("player", -1),
		"position": actual.get("position", Vector2i(-1, -1)),
		"type": StrategoGame.MEDIUM_INFANTRY, "alive": true,
		"role": String(assumptions.get("role", StrategoGame.ROLE_INFANTRY)),
		"weight": weight,
		"strength": int(assumptions.get("strength", 5)),
		"armor": int(StrategoGame.ARMOR_BY_WEIGHT.get(weight, 1)),
	}


## The enemy as this player is entitled to see it: the real formation once its
## identity has been earned, the assumed profile until then.
func _perceived_enemy(game: StrategoGame, player: int, actual: Dictionary) -> Dictionary:
	return actual if game.is_piece_revealed_to(actual, player) else _assumed_enemy(actual)


func plan_round(game: StrategoGame, player: int, rng: RandomNumberGenerator) -> void:
	game.clear_player_orders(player)
	var formations: Array[Dictionary] = []
	for piece: Dictionary in game.pieces:
		if game.is_movable(piece) and int(piece.player) == player:
			formations.append(piece)
	# Formations nearest the objective choose first, so the ones with the least
	# room to manoeuvre are not left with whatever squares are still free.
	formations.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return _target_distance(game, first, player) < _target_distance(game, second, player)
	)
	for piece: Dictionary in formations:
		_plan_formation(game, piece, player, rng)


func plan_leftover(game: StrategoGame, player: int, rng: RandomNumberGenerator) -> void:
	game.clear_player_orders(player)
	var formations: Array[Dictionary] = []
	for piece: Dictionary in game.pieces:
		if game.can_receive_leftover_order(player, int(piece.id)):
			formations.append(piece)
	formations.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return _target_distance(game, first, player) < _target_distance(game, second, player)
	)
	for piece: Dictionary in formations:
		var scored: Array = []
		for direction: Vector2i in StrategoGame.DIRECTIONS:
			var destination: Vector2i = piece.position + direction
			if not game.is_inside(destination) or game.is_blocked_terrain(destination): continue
			scored.append({"to": destination, "score": _score_destination(game, piece, player, destination, false)})
		# Standing still is a real option in the leftover phase, not a fallback.
		var hold_score := _score_destination(game, piece, player, piece.position, true)
		scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
		for option: Dictionary in scored:
			if float(option.score) + rng.randf_range(-0.2, 0.2) < hold_score: break
			if bool(game.set_leftover_order(player, int(piece.id), option.to).get("ok", false)): break


func _plan_formation(game: StrategoGame, piece: Dictionary, player: int, rng: RandomNumberGenerator) -> void:
	var candidates: Array = []
	for entry: Dictionary in _movement_candidates(game, piece, player):
		entry["score"] = _score_destination(game, piece, player, entry.to, entry.path.is_empty()) - 0.25 * float(entry.path.size() - 1)
		candidates.append(entry)
	if piece.role == StrategoGame.ROLE_ARCHER:
		candidates.append_array(_ranged_candidates(game, piece, player))
	for candidate: Dictionary in candidates:
		candidate.score = float(candidate.score) + rng.randf_range(-0.25, 0.25)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
	for candidate: Dictionary in candidates:
		var path: Array = candidate.get("path", [])
		var typed_path: Array[Vector2i] = []
		for step in path: typed_path.append(step)
		var target: Vector2i = candidate.get("ranged_target", Vector2i(-1, -1))
		var target_id := int(candidate.get("ranged_target_id", -1))
		if bool(game.set_unit_order(player, int(piece.id), typed_path, target, Vector2i(-1, -1), target_id).get("ok", false)):
			return
	# A zero-cost hold keeps the bot's intent explicit when nothing else took.
	if game.order_for_piece(int(piece.id)).is_empty():
		game.set_unit_order(player, int(piece.id), [])


## Every square reachable within the formation's movement, with a route to it.
## Occupied squares are included as terminal steps, since entering one is how an
## attack happens.
func _movement_candidates(game: StrategoGame, piece: Dictionary, player: int) -> Array:
	var budget := game.movement_limit_for(piece)
	var origin: Vector2i = piece.position
	var routes: Dictionary = {origin: []}
	var frontier: Array[Vector2i] = [origin]
	var results: Array = [{"to": origin, "path": []}]
	for _step in budget:
		var next_frontier: Array[Vector2i] = []
		for cell: Vector2i in frontier:
			for destination: Vector2i in StrategoGame.neighbors(cell):
				if destination in routes: continue
				if not game.is_inside(destination) or game.is_blocked_terrain(destination): continue
				var route: Array = routes[cell].duplicate()
				route.append(destination)
				routes[destination] = route
				results.append({"to": destination, "path": route})
				var occupant := game.piece_at(destination)
				# Stop expanding through a square something is standing in.
				if occupant.is_empty(): next_frontier.append(destination)
		frontier = next_frontier
	return results


func _score_destination(game: StrategoGame, piece: Dictionary, player: int, destination: Vector2i, holding: bool) -> float:
	var score := 0.0
	var aim := _scenario_target(game, player)
	if aim.x >= 0:
		var before := StrategoGame.grid_distance(piece.position, aim)
		var after := StrategoGame.grid_distance(destination, aim)
		score += float(weights.objective_progress) * float(before - after)
		if destination == aim: score += float(weights.objective_occupy)

	var occupant := game.piece_at(destination)
	var entering_enemy: bool = not occupant.is_empty() and not game.are_allied_players(player, int(occupant.player)) and occupant.type != StrategoGame.FLAG
	if entering_enemy:
		# Judge the fight against what this player actually knows, not the truth.
		var defender := _perceived_enemy(game, player, occupant)
		var advantage := game.melee_advantage(piece, defender)
		score += float(weights.fight_advantage) * advantage
		if advantage < 0.0: score += float(weights.losing_fight) * absf(advantage)
		if piece.role == StrategoGame.ROLE_CAVALRY: score += float(weights.cavalry_charges)
		if not game.is_piece_revealed_to(occupant, player): score += float(weights.unknown_risk)
	elif holding:
		# Standing still is how a formation gets attacked rather than attacking,
		# which is the only way the Infantry bonus is ever collected.
		var threatened := _enemy_reach_count(game, player, destination)
		if threatened > 0:
			score += float(weights.defend_in_place)
			if piece.role == StrategoGame.ROLE_INFANTRY: score += float(weights.infantry_receives)
		else:
			score += float(weights.idle)

	var friendly := 0
	for neighbour: Vector2i in StrategoGame.neighbors(destination):
		var ally := game.piece_at(neighbour)
		if not ally.is_empty() and game.are_allied_players(player, int(ally.player)) and int(ally.id) != int(piece.id):
			friendly += 1
	score += float(weights.support) * float(friendly)
	score += float(weights.archer_exposure) * float(_archer_threat_count(game, player, destination))
	return score


## Shots the formation could declare, scored on expected damage rather than on
## which enemy happens to be nearest.
func _ranged_candidates(game: StrategoGame, piece: Dictionary, player: int) -> Array:
	var results: Array = []
	for target: Dictionary in game.pieces:
		if not target.alive or target.type == StrategoGame.FLAG: continue
		if game.are_allied_players(player, int(target.player)): continue
		if not game.is_piece_visible_to(target, player): continue
		if StrategoGame.grid_distance(piece.position, target.position) > 2: continue
		# "Shoot the weakest" would otherwise read strengths the bot has not earned.
		var perceived := _perceived_enemy(game, player, target)
		var damage := game.expected_ranged_damage(piece, perceived)
		var score := float(weights.ranged_damage) * damage
		# Prefer a shot that finishes something over chipping a healthy formation.
		if damage >= float(perceived.strength): score += float(weights.finish_target)
		score += float(weights.archer_exposure) * float(_archer_threat_count(game, player, piece.position))
		results.append({
			"to": piece.position, "path": [], "score": score,
			"ranged_target": target.position, "ranged_target_id": int(target.id),
		})
	return results


## Enemies already in contact with this square. Adjacency only and deliberately
## so: rewarding a stand whenever any enemy is merely within movement range makes
## both armies wait to be attacked and nobody ever closes.
func _enemy_reach_count(game: StrategoGame, player: int, square: Vector2i) -> int:
	var count := 0
	for enemy: Dictionary in game.pieces:
		if not game.is_movable(enemy) or game.are_allied_players(player, int(enemy.player)): continue
		if not game.is_piece_visible_to(enemy, player): continue
		if StrategoGame.are_adjacent(enemy.position, square): count += 1
	return count


func _archer_threat_count(game: StrategoGame, player: int, square: Vector2i) -> int:
	var count := 0
	for enemy: Dictionary in game.pieces:
		if not enemy.alive or enemy.role != StrategoGame.ROLE_ARCHER: continue
		if game.are_allied_players(player, int(enemy.player)): continue
		if not game.is_piece_visible_to(enemy, player): continue
		if StrategoGame.grid_distance(enemy.position, square) <= 2: count += 1
	return count


func _scenario_target(game: StrategoGame, player: int) -> Vector2i:
	# Objective-driven scenarios name their own aim point, so the bot needs no
	# per-scenario branch to play them.
	var aim := game.objective_aim_point(player)
	if aim.x >= 0:
		return aim
	if game.scenario == StrategoGame.SCENARIO_BRIDGE:
		if player == game.bridge_attacker:
			return Vector2i(StrategoGame.BRIDGE_COLUMNS[1], 0)
		return Vector2i(StrategoGame.BRIDGE_COLUMNS[2], StrategoGame.BRIDGE_RIVER_Y + 1)
	# With no objective at all, the nearest enemy is the only thing worth walking
	# toward, so the aim point falls back to the closest one.
	var best := Vector2i(-1, -1)
	var best_distance := 1 << 30
	var own := Vector2i(-1, -1)
	for piece: Dictionary in game.pieces:
		if game.is_movable(piece) and int(piece.player) == player:
			own = piece.position
			break
	if own.x < 0: return Vector2i(StrategoGame.BOARD_SIZE / 2, StrategoGame.BOARD_SIZE / 2)
	for enemy: Dictionary in game.pieces:
		if not enemy.alive or game.are_allied_players(player, int(enemy.player)): continue
		if not game.is_piece_visible_to(enemy, player): continue
		var distance := StrategoGame.grid_distance(own, enemy.position)
		if distance < best_distance:
			best_distance = distance
			best = enemy.position
	return best if best.x >= 0 else Vector2i(StrategoGame.BOARD_SIZE / 2, StrategoGame.BOARD_SIZE / 2)


func _target_distance(game: StrategoGame, piece: Dictionary, player: int) -> int:
	var aim := _scenario_target(game, player)
	return StrategoGame.grid_distance(piece.position, aim) if aim.x >= 0 else 0
