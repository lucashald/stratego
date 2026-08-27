class_name StrategoBotPolicy
extends RefCounted

# The new-rules bot is intentionally small: it produces complete simultaneous
# orders and exercises the real collision validator instead of taking privileged
# sequential actions. Classic's trained policy remains untouched in classic/.


func plan_round(game: StrategoGame, player: int, rng: RandomNumberGenerator) -> void:
	game.clear_player_orders(player)
	var formations: Array[Dictionary] = []
	for piece: Dictionary in game.pieces:
		if game.is_movable(piece) and int(piece.player) == player:
			formations.append(piece)
	formations.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return _target_distance(game, first, player) < _target_distance(game, second, player)
	)
	for piece: Dictionary in formations:
		_plan_formation(game, piece, player, rng)


func plan_leftover(game: StrategoGame, player: int, _rng: RandomNumberGenerator) -> void:
	game.clear_player_orders(player)
	var formations: Array[Dictionary] = []
	for piece: Dictionary in game.pieces:
		if game.can_receive_leftover_order(player, int(piece.id)):
			formations.append(piece)
	formations.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return _target_distance(game, first, player) < _target_distance(game, second, player)
	)
	for piece: Dictionary in formations:
		var target := _choose_target(game, piece, player)
		var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		directions.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
			return (piece.position + first).distance_squared_to(target) < (piece.position + second).distance_squared_to(target)
		)
		for direction: Vector2i in directions:
			var result := game.set_leftover_order(player, int(piece.id), piece.position + direction)
			if bool(result.get("ok", false)):
				break


func _plan_formation(game: StrategoGame, piece: Dictionary, player: int, _rng: RandomNumberGenerator) -> void:
	var adjacent_enemy := _adjacent_enemy(game, piece.position, player)
	if piece.role == StrategoGame.ROLE_ARCHER and not adjacent_enemy.is_empty():
		game.set_unit_order(player, int(piece.id), [], adjacent_enemy.position)
		return
	var target := _choose_target(game, piece, player)
	var path: Array[Vector2i] = []
	var position: Vector2i = piece.position
	var budget := game.movement_limit_for(piece)
	for _impulse in budget:
		var candidates: Array[Vector2i] = []
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var destination: Vector2i = position + direction
			if game.is_inside(destination) and not game.is_blocked_terrain(destination):
				candidates.append(destination)
		candidates.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
			return first.distance_squared_to(target) < second.distance_squared_to(target)
		)
		var added := false
		for candidate in candidates:
			var attempted := path.duplicate()
			attempted.append(candidate)
			var result: Dictionary = game.set_unit_order(player, int(piece.id), attempted)
			if bool(result.get("ok", false)):
				path.assign(attempted)
				position = candidate
				added = true
				break
		if not added:
			break
		var occupant := game.piece_at(position)
		if not occupant.is_empty() and not game.are_allied_players(player, int(occupant.player)):
			break
	# If pathing was impossible, a zero-cost hold order still makes the bot's
	# intent explicit and remains compatible with readiness/resolution.
	if game.order_for_piece(int(piece.id)).is_empty():
		game.set_unit_order(player, int(piece.id), [])


func _adjacent_enemy(game: StrategoGame, position: Vector2i, player: int) -> Dictionary:
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var target := game.observed_piece_at(position + direction, player)
		if not target.is_empty() and not game.are_allied_players(player, int(target.player)) and target.type != StrategoGame.FLAG:
			return target
	return {}


func _choose_target(game: StrategoGame, piece: Dictionary, player: int) -> Vector2i:
	var best_position := _scenario_target(game, player)
	var best_distance: int = piece.position.distance_squared_to(best_position)
	for enemy: Dictionary in game.pieces:
		if not enemy.alive or game.are_allied_players(player, int(enemy.player)) or not game.is_piece_visible_to(enemy, player):
			continue
		var distance: int = piece.position.distance_squared_to(enemy.position)
		if distance < best_distance:
			best_distance = distance
			best_position = enemy.position
	return best_position


func _scenario_target(game: StrategoGame, player: int) -> Vector2i:
	if game.scenario == StrategoGame.SCENARIO_BRIDGE:
		if player == game.bridge_attacker:
			return Vector2i(StrategoGame.BRIDGE_COLUMNS[1], 0)
		return Vector2i(StrategoGame.BRIDGE_COLUMNS[2], StrategoGame.BRIDGE_RIVER_Y + 1)
	return Vector2i(StrategoGame.BOARD_SIZE / 2, StrategoGame.BOARD_SIZE / 2)


func _target_distance(game: StrategoGame, piece: Dictionary, player: int) -> int:
	return piece.position.distance_squared_to(_scenario_target(game, player))


func choose_move(game: StrategoGame, player: int, rng: RandomNumberGenerator) -> Dictionary:
	var options := game.get_legal_moves(player)
	return {} if options.is_empty() else options[rng.randi_range(0, options.size() - 1)]
