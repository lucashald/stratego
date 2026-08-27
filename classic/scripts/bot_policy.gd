class_name StrategoBotPolicy
extends RefCounted

const MODEL_VERSION := 5
const DEFAULT_USER_PATH := "user://stratego_bot.json"
const PREVIOUS_CHAMPION_PATH := "user://stratego_bot_previous_champion.json"
const CHALLENGER_PATH := "user://stratego_bot_challenger.json"
const ARCHIVE_DIRECTORY := "user://champions"

const VERSION_2_WEIGHT_KEYS := [
	"trade_value",
	"unknown_piece_risk",
	"target_has_moved",
	"post_move_mobility",
	"known_threat_after_move",
	"friendly_support",
	"repeat_position",
	"backline_probe",
	"flag_defense_change",
	"miner_preservation",
	"no_progress_urgency",
]

const VERSION_3_WEIGHT_KEYS := [
	"stronger_enemy_escape",
]

const VERSION_4_WEIGHT_KEYS := [
	"concealment_hold",
]

const VERSION_5_WEIGHT_DEFAULTS := {
	"known_loss": -100.0,
	"known_threat_after_move": -4.0,
	"stronger_enemy_escape": 1.8,
	"concealment_hold": 1.2,
	"flag_cover_change": 2.4,
	"home_intruder_intercept": 1.4,
	"unknown_contact_risk": -1.8,
	"leader_pressure": 1.0,
	"weak_player_finish": 0.7,
	"counter_target_approach": 0.9,
	"bomb_defusal": 2.5,
	"spy_strike": 3.0,
}

const LOCKED_TACTICAL_WEIGHTS := ["known_loss"]

const PIECE_VALUES := {
	StrategoGame.FLAG: 100.0,
	StrategoGame.BOMB: 4.0,
	StrategoGame.SPY: 2.0,
	StrategoGame.SCOUT: 2.0,
	StrategoGame.MINER: 4.0,
	"4": 3.0,
	"5": 4.0,
	"6": 5.0,
	"7": 6.0,
	"8": 7.0,
	"9": 9.0,
	StrategoGame.MARSHAL: 10.0,
}

var generation := 0
var games_trained := 0
var weights := {
	"bias": 0.0,
	"advance": 1.15,
	"attack": 0.4,
	"unknown_attack": -0.15,
	"known_win": 5.0,
	"known_loss": -100.0,
	"equal_trade": -0.2,
	"capture_flag": 18.0,
	"adjacent_enemy": 0.18,
	"center": 0.2,
	"scout_stride": 0.28,
	"protect_home": 0.35,
	"mobility": 0.12,
	"backtrack": -1.6,
	"trade_value": 2.0,
	"unknown_piece_risk": -2.0,
	"target_has_moved": 1.0,
	"post_move_mobility": 0.7,
	"known_threat_after_move": -4.0,
	"friendly_support": 0.3,
	"repeat_position": -1.5,
	"backline_probe": 0.8,
	"flag_defense_change": 0.8,
	"miner_preservation": 1.2,
	"no_progress_urgency": 0.8,
	"stronger_enemy_escape": 1.8,
	"concealment_hold": 1.2,
	"flag_cover_change": 2.4,
	"home_intruder_intercept": 1.4,
	"unknown_contact_risk": -1.8,
	"leader_pressure": 1.0,
	"weak_player_finish": 0.7,
	"counter_target_approach": 0.9,
	"bomb_defusal": 2.5,
	"spy_strike": 3.0,
}


func choose_move(game: StrategoGame, player: int, rng: RandomNumberGenerator) -> Dictionary:
	var moves := game.get_legal_moves(player)
	if moves.is_empty():
		return {}
	var best_move: Dictionary = moves[0]
	var best_score := -INF
	for move: Dictionary in moves:
		var score := score_move(game, move, player)
		# Small noise prevents deterministic cycles and creates varied self-play data.
		score += rng.randf_range(-0.22, 0.22)
		if score > best_score:
			best_score = score
			best_move = move
	return best_move


func score_move(game: StrategoGame, move: Dictionary, player: int) -> float:
	var from: Vector2i = move.from
	var to: Vector2i = move.to
	var piece := game.piece_at(from)
	var target := game.observed_piece_at(to, player)
	var score: float = weights.bias

	var progress := game.advancement_delta(player, from, to)
	score += weights.advance * progress
	var center_before := game.center_lane_distance(player, from)
	var center_after := game.center_lane_distance(player, to)
	score += weights.center * (center_before - center_after)
	if piece.type == StrategoGame.SCOUT:
		score += weights.scout_stride * float(from.distance_to(to) - 1.0)
	if to == piece.previous_position:
		score += weights.backtrack

	if not target.is_empty():
		var target_player: int = target.player
		score += weights.attack
		score += weights.leader_pressure * _leader_pressure(game, target_player)
		score += weights.weak_player_finish * _weak_player_finish(game, target_player)
		if not game.is_piece_revealed_to(target, player):
			score += weights.unknown_attack
			score += weights.unknown_piece_risk * piece_value(piece.type) / 10.0
			if bool(target.has_moved):
				score += weights.target_has_moved
			if not bool(target.has_moved) and game.home_edge_distance(target_player, to) <= 1:
				var probe_suitability := clampf(1.0 - piece_value(piece.type) / 10.0, 0.0, 1.0)
				score += weights.backline_probe * probe_suitability
			if piece.type == StrategoGame.MINER:
				var bombs_remaining := game.count_alive_type(target_player, StrategoGame.BOMB)
				score -= weights.miner_preservation * float(bombs_remaining) / 6.0
		else:
			var outcome := game.resolve_combat(piece.type, target.type)
			if target.type == StrategoGame.FLAG:
				score += weights.capture_flag
			elif outcome == "attacker":
				score += weights.known_win
			elif outcome == "defender":
				score += weights.known_loss
			else:
				score += weights.equal_trade
			score += weights.trade_value * _trade_delta(piece.type, target.type, outcome) / 10.0
			if piece.type == StrategoGame.MINER and target.type == StrategoGame.BOMB:
				score += weights.bomb_defusal
			if piece.type == StrategoGame.SPY and target.type == StrategoGame.MARSHAL:
				score += weights.spy_strike

	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var nearby := game.observed_piece_at(to + direction, player)
		if not nearby.is_empty() and nearby.player != player:
			score += weights.adjacent_enemy
		elif not nearby.is_empty() and nearby.player == player and nearby.position != from:
			score += weights.friendly_support

	if game.home_edge_distance(player, to) <= 2:
		score += weights.protect_home
	score += weights.mobility * float(game.get_moves_for(from).size()) / 10.0
	score += weights.post_move_mobility * float(_estimate_post_move_mobility(game, move, piece)) / 10.0
	score += weights.known_threat_after_move * float(_count_known_threats(game, move, piece))
	score += weights.stronger_enemy_escape * _stronger_enemy_escape_delta(game, move, piece)
	score -= weights.concealment_hold * _concealment_hold_pressure(game, piece)
	score += weights.unknown_contact_risk * _unknown_contact_pressure(game, move, piece)
	score += weights.counter_target_approach * _counter_target_approach(game, move, piece)
	var repeat_count := 0
	for visited_position: Vector2i in piece.recent_positions:
		if visited_position == to:
			repeat_count += 1
	score += weights.repeat_position * float(repeat_count)

	var own_flag := game.find_alive_piece(player, StrategoGame.FLAG)
	if not own_flag.is_empty():
		var before_guard := maxf(0.0, 4.0 - float(from.distance_to(own_flag.position)))
		var after_guard := maxf(0.0, 4.0 - float(to.distance_to(own_flag.position)))
		score += weights.flag_defense_change * (after_guard - before_guard)
		score += weights.flag_cover_change * _flag_cover_change(game, move, player, own_flag)
		score += weights.home_intruder_intercept * _home_intruder_intercept(game, move, player, own_flag)

	var urgency := float(game.quiet_plies) / float(game.max_quiet_plies)
	var makes_progress := 1.0 if not target.is_empty() or progress > 0.0 else 0.0
	score += weights.no_progress_urgency * urgency * makes_progress
	return score


func piece_value(type: String) -> float:
	return float(PIECE_VALUES.get(type, 1.0))


func _trade_delta(attacker_type: String, defender_type: String, outcome: String) -> float:
	if outcome == "attacker":
		return piece_value(defender_type)
	if outcome == "defender":
		return -piece_value(attacker_type)
	return piece_value(defender_type) - piece_value(attacker_type)


func _estimate_post_move_mobility(game: StrategoGame, move: Dictionary, piece: Dictionary) -> int:
	var count := 0
	var from: Vector2i = move.from
	var to: Vector2i = move.to
	var distance_limit := game.movement_limit_for(piece)
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		for distance in range(1, distance_limit + 1):
			var destination: Vector2i = to + direction * distance
			if not game.is_inside(destination) or game.is_lake(destination):
				break
			var occupant: Dictionary = {} if destination == from else game.observed_piece_at(destination, int(piece.player))
			if occupant.is_empty():
				count += 1
				continue
			if occupant.player != piece.player:
				count += 1
			break
	return count


func _count_known_threats(game: StrategoGame, move: Dictionary, piece: Dictionary) -> int:
	var threats := 0
	for enemy_piece: Dictionary in game.pieces:
		if not enemy_piece.alive or enemy_piece.player == piece.player or not game.is_piece_visible_to(enemy_piece, int(piece.player)):
			continue
		if not game.is_piece_revealed_to(enemy_piece, piece.player):
			continue
		if not game.is_movable(enemy_piece) or enemy_piece.position == move.to:
			continue
		if _can_reach_after_move(game, enemy_piece, move.from, move.to, int(piece.player)):
			if game.resolve_combat(enemy_piece.type, piece.type) == "attacker":
				threats += 1
	return threats


func _stronger_enemy_escape_delta(game: StrategoGame, move: Dictionary, piece: Dictionary) -> float:
	var escape_delta := 0.0
	var awareness_radius := 4.0
	for enemy_piece: Dictionary in game.pieces:
		if not enemy_piece.alive or enemy_piece.player == piece.player or not game.is_piece_visible_to(enemy_piece, int(piece.player)):
			continue
		if not game.is_piece_revealed_to(enemy_piece, piece.player):
			continue
		if not game.is_movable(enemy_piece) or enemy_piece.position == move.to:
			continue
		if game.resolve_combat(enemy_piece.type, piece.type) != "attacker":
			continue
		var before_distance := float(move.from.distance_to(enemy_piece.position))
		var after_distance := float(move.to.distance_to(enemy_piece.position))
		var before_pressure := maxf(0.0, awareness_radius - before_distance)
		var after_pressure := maxf(0.0, awareness_radius - after_distance)
		escape_delta += before_pressure - after_pressure
	return escape_delta


func _concealment_hold_pressure(game: StrategoGame, piece: Dictionary) -> float:
	# Once a piece moves, the opponent knows it cannot be a Bomb or Flag.
	# Moving a piece already revealed to an opponent, or one that has moved,
	# gives up no new Bomb/Flag cover.
	if bool(piece.has_moved) or game.is_piece_revealed_to_any_opponent(piece, piece.player):
		return 0.0
	var pressure := 0.0
	var awareness_radius := 4.0
	for enemy_piece: Dictionary in game.pieces:
		if not enemy_piece.alive or enemy_piece.player == piece.player or not game.is_piece_visible_to(enemy_piece, int(piece.player)):
			continue
		if not game.is_piece_revealed_to(enemy_piece, piece.player):
			continue
		if not game.is_movable(enemy_piece):
			continue
		if game.resolve_combat(enemy_piece.type, piece.type) != "attacker":
			continue
		var distance := float(piece.position.distance_to(enemy_piece.position))
		var proximity := clampf((awareness_radius - distance) / awareness_radius, 0.0, 1.0)
		pressure += proximity * piece_value(piece.type) / 10.0
	return pressure


func _leader_pressure(game: StrategoGame, target_player: int) -> float:
	if game.active_players.is_empty():
		return 0.0
	var total_alive := 0.0
	for player in game.active_players:
		total_alive += float(game.count_alive(player))
	var average_alive := total_alive / float(game.active_players.size())
	return clampf((float(game.count_alive(target_player)) - average_alive) / 10.0, -1.0, 1.0)


func _weak_player_finish(game: StrategoGame, target_player: int) -> float:
	return clampf(1.0 - float(game.count_alive(target_player)) / 40.0, 0.0, 1.0)


func _unknown_contact_pressure(game: StrategoGame, move: Dictionary, piece: Dictionary) -> float:
	var pressure := 0.0
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var nearby := game.observed_piece_at(move.to + direction, int(piece.player))
		if not nearby.is_empty() and nearby.player != piece.player and not game.is_piece_revealed_to(nearby, piece.player):
			pressure += piece_value(piece.type) / 10.0
	return pressure


func _counter_target_approach(game: StrategoGame, move: Dictionary, piece: Dictionary) -> float:
	var countered_type := ""
	if piece.type == StrategoGame.MINER:
		countered_type = StrategoGame.BOMB
	elif piece.type == StrategoGame.SPY:
		countered_type = StrategoGame.MARSHAL
	else:
		return 0.0
	var best_before := INF
	var best_after := INF
	for enemy_piece: Dictionary in game.pieces:
		if not enemy_piece.alive or enemy_piece.player == piece.player:
			continue
		if not game.is_piece_visible_to(enemy_piece, int(piece.player)):
			continue
		if not game.is_piece_revealed_to(enemy_piece, piece.player) or enemy_piece.type != countered_type:
			continue
		best_before = minf(best_before, float(move.from.distance_to(enemy_piece.position)))
		best_after = minf(best_after, float(move.to.distance_to(enemy_piece.position)))
	return 0.0 if is_inf(best_before) else best_before - best_after


func _flag_cover_change(game: StrategoGame, move: Dictionary, player: int, flag: Dictionary) -> float:
	var before_cover := 0.0
	var after_cover := 0.0
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var cover_position: Vector2i = flag.position + direction
		var occupant := game.piece_at(cover_position)
		if not occupant.is_empty() and occupant.player == player:
			before_cover += 1.0
		if cover_position == move.from:
			continue
		if cover_position == move.to:
			var target := game.observed_piece_at(move.to, player)
			if target.is_empty():
				after_cover += 1.0
			elif game.is_piece_revealed_to(target, player) and game.resolve_combat(game.piece_at(move.from).type, target.type) == "attacker":
				after_cover += 1.0
			continue
		if not occupant.is_empty() and occupant.player == player:
			after_cover += 1.0
	return after_cover - before_cover


func _home_intruder_intercept(game: StrategoGame, move: Dictionary, player: int, flag: Dictionary) -> float:
	var intercept_delta := 0.0
	var threat_radius := 6.0
	for enemy_piece: Dictionary in game.pieces:
		if not enemy_piece.alive or enemy_piece.player == player:
			continue
		if not game.is_piece_visible_to(enemy_piece, player):
			continue
		var flag_distance := float(flag.position.distance_to(enemy_piece.position))
		if flag_distance > threat_radius:
			continue
		var urgency := (threat_radius + 1.0 - flag_distance) / threat_radius
		var before_distance := float(move.from.distance_to(enemy_piece.position))
		var after_distance := float(move.to.distance_to(enemy_piece.position))
		intercept_delta += (before_distance - after_distance) * urgency
	return intercept_delta


func _can_reach_after_move(game: StrategoGame, enemy_piece: Dictionary, vacated: Vector2i, destination: Vector2i, viewing_player: int) -> bool:
	var origin: Vector2i = enemy_piece.position
	var delta: Vector2i = destination - origin
	if enemy_piece.type != StrategoGame.SCOUT:
		return absi(delta.x) + absi(delta.y) == 1
	if delta.x != 0 and delta.y != 0:
		return false
	if absi(delta.x) + absi(delta.y) > game.movement_limit_for(enemy_piece):
		return false
	var direction := Vector2i.ZERO
	if delta.x != 0:
		direction.x = 1 if delta.x > 0 else -1
	elif delta.y != 0:
		direction.y = 1 if delta.y > 0 else -1
	else:
		return false
	var cursor := origin + direction
	while cursor != destination:
		if cursor != vacated and not game.observed_piece_at(cursor, viewing_player).is_empty():
			return false
		cursor += direction
	return true


func mutated(rng: RandomNumberGenerator, strength: float = 0.35) -> StrategoBotPolicy:
	var child := StrategoBotPolicy.new()
	child.weights = weights.duplicate(true)
	child.generation = generation + 1
	child.games_trained = games_trained
	for key: String in child.weights:
		if key in LOCKED_TACTICAL_WEIGHTS:
			continue
		child.weights[key] = clampf(float(child.weights[key]) + rng.randfn(0.0, strength), -20.0, 20.0)
	return child


func mutated_sparse(rng: RandomNumberGenerator, strength: float = 0.35, changed_weights: int = 3) -> StrategoBotPolicy:
	var child := StrategoBotPolicy.new()
	child.weights = weights.duplicate(true)
	child.generation = generation + 1
	child.games_trained = games_trained
	var keys: Array = weights.keys()
	keys.erase("bias")
	keys.erase("capture_flag")
	for key in LOCKED_TACTICAL_WEIGHTS:
		keys.erase(key)
	for i in range(keys.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temporary = keys[i]
		keys[i] = keys[j]
		keys[j] = temporary
	for i in mini(changed_weights, keys.size()):
		var key: String = keys[i]
		child.weights[key] = clampf(float(child.weights[key]) + rng.randfn(0.0, strength), -20.0, 20.0)
	return child


func copy_from(other: StrategoBotPolicy) -> void:
	weights = other.weights.duplicate(true)
	generation = other.generation
	games_trained = other.games_trained


func duplicate_policy() -> StrategoBotPolicy:
	var policy := StrategoBotPolicy.new()
	policy.copy_from(self)
	return policy


func save_to_path(path: String = DEFAULT_USER_PATH) -> bool:
	var payload := {
		"model_version": MODEL_VERSION,
		"generation": generation,
		"games_trained": games_trained,
		"weights": weights,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "  "))
	return true


func save_archive() -> String:
	var absolute_directory := ProjectSettings.globalize_path(ARCHIVE_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		return ""
	var archive_path := "%s/generation_%05d_games_%07d.json" % [ARCHIVE_DIRECTORY, generation, games_trained]
	if not FileAccess.file_exists(archive_path) and not save_to_path(archive_path):
		return ""
	return archive_path


static func list_saved_models() -> Array[Dictionary]:
	var models: Array[Dictionary] = []
	_append_model_if_present(models, DEFAULT_USER_PATH, "Current champion", 0)
	_append_model_if_present(models, PREVIOUS_CHAMPION_PATH, "Previous champion", 1)
	_append_model_if_present(models, CHALLENGER_PATH, "Training contender", 2)
	if FileAccess.file_exists("res://trained_bot.json"):
		_append_model_if_present(models, "res://trained_bot.json", "Project model", 3)

	var archived: Array[Dictionary] = []
	var directory := DirAccess.open(ARCHIVE_DIRECTORY)
	if directory != null:
		for file_name in directory.get_files():
			if file_name.get_extension().to_lower() != "json":
				continue
			_append_model_if_present(archived, ARCHIVE_DIRECTORY + "/" + file_name, "Archived", 4)
	# Keep named models first and archived generations newest-first.
	for i in archived.size():
		for j in range(i + 1, archived.size()):
			var left_generation := int(archived[i].generation)
			var right_generation := int(archived[j].generation)
			var left_games := int(archived[i].games_trained)
			var right_games := int(archived[j].games_trained)
			if right_generation > left_generation or (right_generation == left_generation and right_games > left_games):
				var temporary := archived[i]
				archived[i] = archived[j]
				archived[j] = temporary
	models.append_array(archived)
	return models


static func _append_model_if_present(models: Array[Dictionary], path: String, kind: String, order: int) -> void:
	if not FileAccess.file_exists(path):
		return
	var policy := StrategoBotPolicy.load_from_path(path)
	models.append({
		"path": path,
		"kind": kind,
		"order": order,
		"generation": policy.generation,
		"games_trained": policy.games_trained,
		"label": "%s — Gen %d · %d games" % [kind, policy.generation, policy.games_trained],
	})


static func load_from_path(path: String = DEFAULT_USER_PATH) -> StrategoBotPolicy:
	var policy := StrategoBotPolicy.new()
	if not FileAccess.file_exists(path):
		return policy
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return policy
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("weights"):
		return policy
	for key: String in policy.weights:
		if parsed.weights.has(key):
			policy.weights[key] = float(parsed.weights[key])
	var saved_version := int(parsed.get("model_version", 1))
	if saved_version < 2:
		# Preserve the exact behavior of version-1 champions. New features begin
		# neutral and must earn influence through repeated title matches.
		for key: String in VERSION_2_WEIGHT_KEYS:
			policy.weights[key] = 0.0
	if saved_version < 3:
		for key: String in VERSION_3_WEIGHT_KEYS:
			policy.weights[key] = 0.0
	if saved_version < 4:
		for key: String in VERSION_4_WEIGHT_KEYS:
			policy.weights[key] = 0.0
	if saved_version < 5:
		for key: String in VERSION_5_WEIGHT_DEFAULTS:
			policy.weights[key] = float(VERSION_5_WEIGHT_DEFAULTS[key])
	# Model files cannot weaken the non-negotiable tactical loss floor.
	policy.weights.known_loss = minf(float(policy.weights.known_loss), -100.0)
	policy.generation = int(parsed.get("generation", 0))
	policy.games_trained = int(parsed.get("games_trained", 0))
	return policy
