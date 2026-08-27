class_name StrategoBoardView
extends Control

signal order_changed(message: String)
signal selection_changed(description: String)
signal zoom_changed(percent: int)
signal undo_availability_changed(available: bool)

const BLUE_COLOR := Color("#102d57")
const BLUE_EDGE := Color("#7fc2ff")
const RED_COLOR := Color("#5d1714")
const RED_EDGE := Color("#e88b6c")
const GREEN_COLOR := Color("#174a35")
const GREEN_EDGE := Color("#75d9aa")
const YELLOW_COLOR := Color("#665018")
const YELLOW_EDGE := Color("#ffe08a")
const GOLD := Color("#c8a15c")
const ORDER_BLUE := Color("#5ca9ff")
const ORDER_DARK := Color("#153b6b")
const LEFTOVER_COLOR := Color("#f2b15b")
const RANGED_COLOR := Color("#78e2f5")
const FOG_COLOR := Color(0.018, 0.035, 0.045, 0.68)

var game: StrategoGame
var viewing_player := StrategoGame.BLUE
var reveal_all := false
var interaction_enabled := true
var prefer_ranged := true
var leftover_mode := false
var selected_piece_id := StrategoGame.EMPTY
var selected_piece_ids: Array[int] = []
var combat_event: Dictionary = {}
var combat_started_msec := 0
var combat_duration_msec := 1600
var combat_hold := false
var zoom_level := 1.0
var pan_offset := Vector2(0, -34)
var min_zoom := 0.9
var max_zoom := 2.6
var left_button_down := false
var drag_start := Vector2.ZERO
var drag_current := Vector2.ZERO
var drag_selecting := false
var drag_additive := false
var middle_panning := false
var order_undo_stack: Array[Dictionary] = []


func _ready() -> void:
	custom_minimum_size = Vector2(900, 700)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_process_unhandled_key_input(true)
	set_process(true)


func set_game(value: StrategoGame) -> void:
	game = value
	combat_event.clear()
	order_undo_stack.clear()
	undo_availability_changed.emit(false)
	reset_view()
	clear_selection()
	queue_redraw()


func clear_selection() -> void:
	selected_piece_id = StrategoGame.EMPTY
	selected_piece_ids.clear()
	selection_changed.emit("Select formations, then click a direction to give the selection a shared order.")
	queue_redraw()


func _board_geometry() -> Dictionary:
	var base_side := maxf(300.0, minf(size.y - 80.0, size.x - 520.0))
	var side := base_side * zoom_level
	var origin := (size - Vector2(side, side)) * 0.5 + pan_offset
	return {"origin": origin, "side": side, "cell": side / float(StrategoGame.BOARD_SIZE)}


func zoom_in() -> void:
	_set_zoom(zoom_level * 1.2, Vector2(size.x * 0.5, size.y * 0.82))


func zoom_out() -> void:
	_set_zoom(zoom_level / 1.2, Vector2(size.x * 0.5, size.y * 0.82))


func reset_view() -> void:
	zoom_level = 1.0
	pan_offset = Vector2(0, -34)
	zoom_changed.emit(int(round(zoom_level * 100.0)))
	queue_redraw()


func select_all_movable() -> void:
	if game == null or not interaction_enabled:
		return
	selected_piece_ids.clear()
	for piece: Dictionary in game.pieces:
		if int(piece.player) == viewing_player and game.is_movable(piece):
			selected_piece_ids.append(int(piece.id))
	selected_piece_id = selected_piece_ids.back() if not selected_piece_ids.is_empty() else StrategoGame.EMPTY
	_emit_selected_description()
	queue_redraw()


func issue_selected_direction(direction: Vector2i) -> Dictionary:
	if not interaction_enabled or game == null or selected_piece_ids.is_empty():
		return {"ok": false, "message": "Select at least one movable formation first."}
	var before := _current_order_snapshot()
	var result: Dictionary
	if leftover_mode:
		result = game.set_group_leftover_step(viewing_player, selected_piece_ids, direction)
	else:
		result = game.append_group_order_step(viewing_player, selected_piece_ids, direction)
	if bool(result.get("ok", false)):
		_record_order_undo(before)
	order_changed.emit(String(result.get("message", "Group order updated.")))
	_emit_selected_description()
	queue_redraw()
	return result


func can_undo_order() -> bool:
	return not order_undo_stack.is_empty()


func clear_order_undo_history() -> void:
	order_undo_stack.clear()
	undo_availability_changed.emit(false)


func undo_last_order() -> void:
	if game == null or not interaction_enabled or order_undo_stack.is_empty():
		return
	game.orders[viewing_player] = order_undo_stack.pop_back().duplicate(true)
	undo_availability_changed.emit(not order_undo_stack.is_empty())
	order_changed.emit("Last order change undone.")
	_emit_selected_description()
	queue_redraw()


func clear_all_orders() -> void:
	if game == null or not interaction_enabled:
		return
	var before := _current_order_snapshot()
	game.clear_player_orders(viewing_player)
	if before == _current_order_snapshot():
		order_changed.emit("There are no orders to clear.")
		return
	_record_order_undo(before)
	order_changed.emit("Your orders were cleared.")
	_emit_selected_description()
	queue_redraw()


func _current_order_snapshot() -> Dictionary:
	return game.orders.get(viewing_player, {}).duplicate(true)


func _record_order_undo(snapshot: Dictionary) -> void:
	order_undo_stack.append(snapshot.duplicate(true))
	if order_undo_stack.size() > 100:
		order_undo_stack.pop_front()
	undo_availability_changed.emit(true)


func _set_zoom(value: float, focus: Vector2) -> void:
	var old_geometry := _board_geometry()
	var board_point := (focus - Vector2(old_geometry.origin)) / float(old_geometry.cell)
	zoom_level = clampf(value, min_zoom, max_zoom)
	var base_side := maxf(300.0, minf(size.y - 80.0, size.x - 520.0))
	var new_side := base_side * zoom_level
	var centered_origin := (size - Vector2(new_side, new_side)) * 0.5
	pan_offset = focus - centered_origin - board_point * (new_side / float(StrategoGame.BOARD_SIZE))
	_clamp_pan()
	zoom_changed.emit(int(round(zoom_level * 100.0)))
	queue_redraw()


func _clamp_pan() -> void:
	var geometry := _board_geometry()
	var side := float(geometry.side)
	var limit_x := maxf(0.0, side * 0.62)
	var limit_y := maxf(34.0, side * 0.62)
	pan_offset.x = clampf(pan_offset.x, -limit_x, limit_x)
	pan_offset.y = clampf(pan_offset.y, -limit_y, limit_y)


func _draw() -> void:
	if game == null:
		return
	_draw_surroundings()
	var geometry := _board_geometry()
	var origin: Vector2 = geometry.origin
	var cell: float = geometry.cell
	_draw_battlefield(origin, cell, float(geometry.side))
	_draw_order_ghosts(origin, cell)
	for piece: Dictionary in game.pieces:
		if not piece.alive:
			continue
		if not reveal_all and not game.game_over and not game.is_piece_visible_to(piece, viewing_player):
			continue
		_draw_piece(piece, origin, cell)
	# Selection outlines and direction controls stay above formation banners.
	_draw_selection(origin, cell)
	_draw_vignette(origin, float(geometry.side))
	_draw_drag_selection()
	if not combat_event.is_empty():
		_draw_combat_overlay(origin, cell)
	elif game.game_over:
		_draw_game_over_overlay(origin, cell, float(geometry.side))


func _draw_surroundings() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#06100e"), true)
	for index in 110:
		var px := _noise_value(index, 3) * size.x
		var py := _noise_value(index, 11) * size.y
		var radius := 12.0 + _noise_value(index, 23) * 38.0
		var tint := Color("#132c1b") if index % 3 else Color("#1b3820")
		tint.a = 0.38
		draw_circle(Vector2(px, py), radius, tint)


func _draw_battlefield(origin: Vector2, cell: float, side: float) -> void:
	draw_rect(Rect2(origin - Vector2(5, 5), Vector2(side + 10, side + 10)), Color("#332b1c"), true)
	for y in StrategoGame.BOARD_SIZE:
		for x in StrategoGame.BOARD_SIZE:
			var position := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))
			var variation := _noise_value(x + y * 20, 41)
			var ground := Color("#435532").lerp(Color("#6d7041"), variation * 0.42)
			if (x + y) % 2 == 0:
				ground = ground.lightened(0.035)
			if game.is_lake(position) or game.is_water(position):
				ground = Color("#254f59").lerp(Color("#39717a"), variation * 0.35)
			elif game.is_bridge(position):
				ground = Color("#795c37").lerp(Color("#9a7748"), variation * 0.25)
			draw_rect(rect, ground, true)
			_draw_cell_texture(position, rect, cell)
			if not reveal_all and not game.game_over and not game.is_position_visible_to(position, viewing_player):
				draw_rect(rect, FOG_COLOR, true)
			draw_rect(rect, Color(0.84, 0.85, 0.68, 0.17), false, maxf(0.7, cell * 0.017))
	_draw_river_banks(origin, cell)


func _draw_cell_texture(position: Vector2i, rect: Rect2, cell: float) -> void:
	if game.is_water(position) or game.is_lake(position):
		var wave_y := rect.position.y + cell * (0.35 + _noise_value(position.x, position.y + 80) * 0.35)
		draw_line(Vector2(rect.position.x + cell * 0.12, wave_y), Vector2(rect.end.x - cell * 0.12, wave_y), Color(0.55, 0.8, 0.82, 0.18), maxf(1.0, cell * 0.025))
	elif game.is_bridge(position):
		for plank in 3:
			var plank_y := rect.position.y + cell * float(plank + 1) / 4.0
			draw_line(Vector2(rect.position.x, plank_y), Vector2(rect.end.x, plank_y), Color(0.16, 0.11, 0.065, 0.55), maxf(1.0, cell * 0.025))
	else:
		var sprig := rect.position + Vector2(_noise_value(position.x, position.y + 17), _noise_value(position.x + 20, position.y)) * cell
		draw_circle(sprig, maxf(0.7, cell * 0.026), Color(0.78, 0.76, 0.42, 0.2))


func _draw_river_banks(origin: Vector2, cell: float) -> void:
	if game.scenario != StrategoGame.SCENARIO_BRIDGE:
		return
	var river_y := int(StrategoGame.BRIDGE_RIVER_Y)
	for x in StrategoGame.BOARD_SIZE:
		var position := Vector2i(x, river_y)
		if game.is_bridge(position):
			continue
		for edge in [-1.0, 1.0]:
			var py := origin.y + (float(river_y) + (0.04 if edge < 0 else 0.96)) * cell
			var px := origin.x + (float(x) + 0.15 + _noise_value(x, int(edge * 7.0)) * 0.7) * cell
			draw_circle(Vector2(px, py), cell * 0.09, Color("#77705b"))
			draw_circle(Vector2(px, py) - Vector2(cell * 0.02, cell * 0.02), cell * 0.052, Color("#a59c7c"))


func _draw_order_ghosts(origin: Vector2, cell: float) -> void:
	var players: Array = game.active_players if reveal_all else [viewing_player]
	var font := ThemeDB.fallback_font
	for player in players:
		for order: Dictionary in game.orders_for_player(player):
			var piece_id := int(order.piece_id)
			if piece_id < 0 or piece_id >= game.pieces.size() or not game.pieces[piece_id].alive:
				continue
			var previous: Vector2i = game.pieces[piece_id].position
			var path: Array = [] if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING else order.get("path", [])
			for index in path.size():
				var position: Vector2i = path[index]
				var previous_center := _cell_center(previous, origin, cell)
				var center := _cell_center(position, origin, cell)
				_draw_dashed_line(previous_center, center, ORDER_BLUE, maxf(2.0, cell * 0.075), cell * 0.17)
				_draw_arrow_head(previous_center, center, cell)
				draw_circle(center, cell * 0.27, Color(0.04, 0.18, 0.34, 0.9))
				draw_arc(center, cell * 0.27, 0.0, TAU, 28, Color("#a6d5ff"), maxf(1.6, cell * 0.045))
				_draw_centered_text(font, str(index + 1), Rect2(center - Vector2(cell * 0.25, cell * 0.25), Vector2(cell * 0.5, cell * 0.5)), int(cell * 0.25), Color.WHITE)
				previous = position
			if not path.is_empty():
				_draw_hex(_cell_center(path.back(), origin, cell), cell * 0.48, Color(0.15, 0.48, 0.76, 0.2), Color("#75c2ff"), maxf(1.5, cell * 0.04))
			var ranged_target: Vector2i = Vector2i(-1, -1) if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING else order.get("ranged_target", Vector2i(-1, -1))
			if ranged_target.x >= 0:
				var ranged_center := _cell_center(ranged_target, origin, cell)
				draw_arc(ranged_center, cell * 0.36, 0.0, TAU, 32, RANGED_COLOR, maxf(2.0, cell * 0.06))
				draw_line(ranged_center - Vector2(cell * 0.22, 0), ranged_center + Vector2(cell * 0.22, 0), RANGED_COLOR, 1.5)
				draw_line(ranged_center - Vector2(0, cell * 0.22), ranged_center + Vector2(0, cell * 0.22), RANGED_COLOR, 1.5)
			var leftover: Vector2i = order.get("leftover", Vector2i(-1, -1))
			if leftover.x >= 0:
				_draw_hex(_cell_center(leftover, origin, cell), cell * 0.34, Color(LEFTOVER_COLOR, 0.22), LEFTOVER_COLOR, maxf(2.0, cell * 0.05))


func _draw_selection(origin: Vector2, cell: float) -> void:
	if selected_piece_ids.is_empty():
		return
	for piece_id in selected_piece_ids:
		if piece_id < 0 or piece_id >= game.pieces.size() or not game.pieces[piece_id].alive:
			continue
		var center := _cell_center(game.pieces[piece_id].position, origin, cell)
		var primary := piece_id == selected_piece_id
		_draw_hex(center, cell * (0.53 if primary else 0.48), Color(0.45, 0.75, 1.0, 0.15), Color("#d5efff") if primary else Color("#75bfff"), maxf(2.0, cell * (0.075 if primary else 0.045)))
	var anchor_id := _command_anchor_id()
	if anchor_id == StrategoGame.EMPTY:
		return
	var projected: Vector2i = game.pieces[anchor_id].position if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING else game.projected_main_destination(anchor_id)
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var destination: Vector2i = projected + direction
		if game.is_inside(destination) and not game.is_blocked_terrain(destination):
			var marker_color := LEFTOVER_COLOR if leftover_mode else Color("#d8edff")
			var destination_center := _cell_center(destination, origin, cell)
			_draw_direction_marker(destination_center, direction, cell, marker_color)


func _command_anchor_id() -> int:
	if selected_piece_id in selected_piece_ids and _piece_has_unused_movement(selected_piece_id):
		return selected_piece_id
	for piece_id in selected_piece_ids:
		if _piece_has_unused_movement(piece_id):
			return piece_id
	return StrategoGame.EMPTY


func _piece_has_unused_movement(piece_id: int) -> bool:
	if piece_id < 0 or piece_id >= game.pieces.size():
		return false
	if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING:
		return game.can_receive_leftover_order(viewing_player, piece_id)
	var order := game.order_for_piece(piece_id)
	var spent := int(order.get("path", []).size())
	if order.get("ranged_target", Vector2i(-1, -1)).x >= 0:
		spent += 1
	if not leftover_mode and order.get("leftover", Vector2i(-1, -1)).x >= 0:
		spent += 1
	return spent < game.movement_limit_for(game.pieces[piece_id])


func _draw_direction_marker(center: Vector2, direction: Vector2i, cell: float, color: Color) -> void:
	draw_circle(center, cell * 0.31, Color(0.025, 0.16, 0.28, 0.9))
	draw_arc(center, cell * 0.31, 0.0, TAU, 28, color, maxf(2.0, cell * 0.055))
	var vector := Vector2(direction)
	var perpendicular := Vector2(-vector.y, vector.x)
	var tip := center + vector * cell * 0.17
	var back := center - vector * cell * 0.12
	draw_colored_polygon(PackedVector2Array([
		tip,
		back + perpendicular * cell * 0.14,
		back - perpendicular * cell * 0.14,
	]), color)


func _draw_drag_selection() -> void:
	if not drag_selecting:
		return
	var rect := Rect2(drag_start, drag_current - drag_start).abs()
	draw_rect(rect, Color(0.24, 0.62, 1.0, 0.14), true)
	draw_rect(rect, Color("#8dccff"), false, 2.0)


func _draw_piece(piece: Dictionary, origin: Vector2, cell: float) -> void:
	var center := _cell_center(piece.position, origin, cell)
	# Edge deployments keep their banners inside the battlefield frame.
	if int(piece.position.y) >= StrategoGame.BOARD_SIZE - 2:
		center.y -= cell * 0.22
	elif int(piece.position.y) <= 1:
		center.y += cell * 0.22
	var colors := _player_colors(int(piece.player))
	var is_selected := int(piece.id) in selected_piece_ids
	var scale := 1.12 if int(piece.id) == selected_piece_id else (1.03 if is_selected else 0.94)
	var width := cell * 0.88 * scale
	var height := cell * 1.12 * scale
	var top := center - Vector2(width * 0.5, height * 0.55)
	var banner := PackedVector2Array([
		top,
		top + Vector2(width, 0),
		top + Vector2(width, height * 0.76),
		top + Vector2(width * 0.5, height),
		top + Vector2(0, height * 0.76),
	])
	var shadow := PackedVector2Array()
	for point in banner:
		shadow.append(point + Vector2(cell * 0.06, cell * 0.08))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.48))
	draw_colored_polygon(banner, colors.fill)
	var outline := banner.duplicate()
	outline.append(banner[0])
	draw_polyline(outline, colors.edge, maxf(1.5, cell * 0.035), true)
	draw_line(top + Vector2(width * 0.1, height * 0.17), top + Vector2(width * 0.9, height * 0.17), GOLD, maxf(1.0, cell * 0.02))
	var can_see_identity := reveal_all or game.game_over or game.is_piece_revealed_to(piece, viewing_player)
	if can_see_identity:
		var weight_text := String(piece.weight).to_upper()
		var role_text := "FLAG" if piece.type == StrategoGame.FLAG else String(piece.role).to_upper()
		_draw_centered_text(ThemeDB.fallback_font, weight_text, Rect2(top + Vector2(0, height * 0.03), Vector2(width, height * 0.18)), maxi(8, int(cell * 0.15)), Color("#f6eee0"))
		_draw_centered_text(ThemeDB.fallback_font, role_text, Rect2(top + Vector2(0, height * 0.16), Vector2(width, height * 0.18)), maxi(8, int(cell * 0.14)), Color.WHITE)
		_draw_role_icon(piece, center + Vector2(0, cell * 0.02), cell * 0.22, Color("#e8e1d5"))
		_draw_strength_tab(piece, top, width, height, cell)
	else:
		_draw_centered_text(ThemeDB.fallback_font, "?", Rect2(center - Vector2(width * 0.5, height * 0.38), Vector2(width, height * 0.63)), maxi(12, int(cell * 0.39)), Color.WHITE)
		var badge_center := top + Vector2(width * 0.88, height * 0.04)
		draw_circle(badge_center, cell * 0.14, Color("#121717"))
		draw_arc(badge_center, cell * 0.14, 0, TAU, 24, Color("#dfd8c7"), 1.2)
		_draw_centered_text(ThemeDB.fallback_font, "?", Rect2(badge_center - Vector2(cell * 0.13, cell * 0.13), Vector2(cell * 0.26, cell * 0.26)), maxi(7, int(cell * 0.19)), Color.WHITE)
	if int(piece.player) == viewing_player and not game.order_for_piece(int(piece.id)).is_empty():
		var badge := top + Vector2(width * 0.94, height * 0.04)
		draw_circle(badge, cell * 0.13, Color("#152315"))
		draw_arc(badge, cell * 0.13, 0.0, TAU, 24, Color("#91d33f"), 1.5)
		draw_line(badge + Vector2(-cell * 0.055, 0), badge + Vector2(-cell * 0.01, cell * 0.05), Color("#a8df4c"), 2.0)
		draw_line(badge + Vector2(-cell * 0.01, cell * 0.05), badge + Vector2(cell * 0.07, -cell * 0.06), Color("#a8df4c"), 2.0)


func _draw_role_icon(piece: Dictionary, center: Vector2, radius: float, color: Color) -> void:
	if piece.type == StrategoGame.FLAG:
		draw_line(center + Vector2(-radius * 0.35, radius * 0.65), center + Vector2(-radius * 0.35, -radius * 0.7), color, 2.0)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-radius * 0.3, -radius * 0.65), center + Vector2(radius * 0.7, -radius * 0.35), center + Vector2(-radius * 0.3, 0)]), color)
	elif piece.role == StrategoGame.ROLE_ARCHER:
		draw_arc(center - Vector2(radius * 0.15, 0), radius * 0.75, -PI * 0.5, PI * 0.5, 18, color, 1.8)
		draw_line(center + Vector2(-radius * 0.15, -radius * 0.75), center + Vector2(-radius * 0.15, radius * 0.75), color, 1.4)
		draw_line(center + Vector2(-radius * 0.45, 0), center + Vector2(radius * 0.75, 0), color, 1.5)
	elif piece.role == StrategoGame.ROLE_CAVALRY:
		draw_arc(center, radius * 0.6, 0.05, PI * 1.5, 18, color, 2.0)
		draw_line(center + Vector2(radius * 0.25, -radius * 0.5), center + Vector2(radius * 0.72, -radius * 0.62), color, 2.0)
		draw_circle(center + Vector2(-radius * 0.18, radius * 0.54), radius * 0.12, color)
	else:
		if String(piece.weight) == StrategoGame.WEIGHT_HEAVY:
			var shield := PackedVector2Array([center + Vector2(-radius * 0.55, -radius * 0.65), center + Vector2(radius * 0.55, -radius * 0.65), center + Vector2(radius * 0.45, radius * 0.3), center + Vector2(0, radius * 0.72), center + Vector2(-radius * 0.45, radius * 0.3)])
			draw_colored_polygon(shield, Color(color, 0.22))
			var shield_line := shield.duplicate()
			shield_line.append(shield[0])
			draw_polyline(shield_line, color, 1.8, true)
		else:
			draw_line(center + Vector2(-radius * 0.55, radius * 0.62), center + Vector2(radius * 0.55, -radius * 0.62), color, 2.1)
			draw_line(center + Vector2(-radius * 0.45, -radius * 0.55), center + Vector2(radius * 0.6, radius * 0.58), color, 2.1)


func _draw_strength_tab(piece: Dictionary, top: Vector2, width: float, height: float, cell: float) -> void:
	var tab := Rect2(top + Vector2(width * 0.58, height * 0.68), Vector2(width * 0.34, height * 0.24))
	draw_rect(tab, Color("#111817"), true)
	draw_rect(tab, GOLD, false, maxf(1.0, cell * 0.022))
	_draw_centered_text(ThemeDB.fallback_font, str(int(piece.strength)), tab, maxi(10, int(cell * 0.27)), Color.WHITE)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash: float) -> void:
	var distance := from.distance_to(to)
	if distance <= 0.01:
		return
	var direction := (to - from) / distance
	var cursor := 0.0
	while cursor < distance:
		var start := from + direction * cursor
		var finish := from + direction * minf(cursor + dash, distance)
		draw_line(start, finish, color, width, true)
		cursor += dash * 1.75


func _draw_arrow_head(from: Vector2, to: Vector2, cell: float) -> void:
	var direction := (to - from).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var tip := to - direction * cell * 0.31
	var back := tip - direction * cell * 0.19
	draw_colored_polygon(PackedVector2Array([tip, back + perpendicular * cell * 0.11, back - perpendicular * cell * 0.11]), ORDER_BLUE)


func _draw_hex(center: Vector2, radius: float, fill: Color, edge: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in 6:
		var angle := -PI * 0.5 + TAU * float(index) / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, edge, width, true)


func _draw_vignette(origin: Vector2, side: float) -> void:
	var band := side * 0.065
	for index in 8:
		var alpha := 0.025 + float(index) * 0.018
		var inset := float(index) * band / 8.0
		var rect := Rect2(origin + Vector2(inset, inset), Vector2(side - inset * 2.0, side - inset * 2.0))
		draw_rect(rect, Color(0, 0, 0, alpha), false, band / 8.0)


func _process(_delta: float) -> void:
	if combat_event.is_empty() or combat_hold:
		return
	if Time.get_ticks_msec() - combat_started_msec >= combat_duration_msec:
		combat_event.clear()
	queue_redraw()


func show_combat(event: Dictionary) -> void:
	if not bool(event.get("combat", false)):
		return
	combat_event = event.duplicate(true)
	combat_started_msec = Time.get_ticks_msec()
	queue_redraw()


func _draw_combat_overlay(origin: Vector2, cell: float) -> void:
	var elapsed := float(Time.get_ticks_msec() - combat_started_msec)
	var fade := 1.0 if combat_hold else clampf((float(combat_duration_msec) - elapsed) / 350.0, 0.0, 1.0)
	var destination: Vector2i = combat_event.get("to", Vector2i(-1, -1))
	if destination.x < 0:
		return
	var center := _cell_center(destination, origin, cell)
	var marker_color := Color("#ffd06a") if combat_event.get("result", "") != "bounce" else Color("#c7a7ff")
	marker_color.a = fade
	draw_circle(center, cell * 0.45, Color(marker_color, 0.18 * fade))
	draw_arc(center, cell * 0.45, 0.0, TAU, 40, marker_color, maxf(3.0, cell * 0.07))
	# Crossed blades keep active combat legible even when banners overlap the square.
	var blade := cell * 0.27
	draw_line(center + Vector2(-blade, blade), center + Vector2(blade, -blade), Color(1.0, 0.9, 0.72, fade), maxf(2.0, cell * 0.07))
	draw_line(center + Vector2(-blade, -blade), center + Vector2(blade, blade), Color(1.0, 0.9, 0.72, fade), maxf(2.0, cell * 0.07))
	var participant_ids: Array = combat_event.get("participants", [])
	var damage: Dictionary = combat_event.get("damage", {})
	for index in mini(2, participant_ids.size()):
		var piece_id := int(participant_ids[index])
		if piece_id < 0 or piece_id >= game.pieces.size():
			continue
		var side := -1.0 if index == 0 else 1.0
		var colors := _player_colors(int(game.pieces[piece_id].player))
		var damage_value := int(damage.get(piece_id, 0))
		var damage_rect := Rect2(center + Vector2(side * cell * 0.82 - cell * 0.32, -cell * 0.82), Vector2(cell * 0.64, cell * 0.42))
		_draw_centered_text(ThemeDB.fallback_font, "-%d" % damage_value, damage_rect, maxi(12, int(cell * 0.38)), Color(colors.edge, fade))


func _draw_game_over_overlay(origin: Vector2, cell: float, side: float) -> void:
	draw_rect(Rect2(origin, Vector2(side, side)), Color(0.01, 0.02, 0.025, 0.72), true)
	var card := Rect2(origin.x + side * 0.18, origin.y + side * 0.5 - cell * 1.2, side * 0.64, cell * 2.4)
	draw_rect(card, Color("#0d171c"), true)
	draw_rect(card, GOLD, false, maxf(2.0, cell * 0.045))
	var title := "DRAW" if game.winner == StrategoGame.DRAW else "%s WINS" % game.player_name(game.winner).to_upper()
	_draw_centered_text(ThemeDB.fallback_font, title, Rect2(card.position + Vector2(0, cell * 0.35), Vector2(card.size.x, cell * 0.7)), int(cell * 0.48), Color("#f6d493"))
	_draw_centered_text(ThemeDB.fallback_font, game.end_reason.replace("_", " ").to_upper(), Rect2(card.position + Vector2(0, cell * 1.28), Vector2(card.size.x, cell * 0.48)), int(cell * 0.23), Color.WHITE)


func _draw_centered_text(font: Font, text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var position := rect.position + Vector2((rect.size.x - text_size.x) * 0.5, (rect.size.y - text_size.y) * 0.5 + text_size.y * 0.78)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _cell_center(position: Vector2i, origin: Vector2, cell: float) -> Vector2:
	return origin + (Vector2(position) + Vector2(0.5, 0.5)) * cell


func _noise_value(a: int, b: int) -> float:
	return fmod(absf(sin(float(a * 127 + b * 311)) * 43758.5453), 1.0)


func _player_colors(player: int) -> Dictionary:
	match player:
		StrategoGame.BLUE: return {"fill": BLUE_COLOR, "edge": BLUE_EDGE}
		StrategoGame.RED: return {"fill": RED_COLOR, "edge": RED_EDGE}
		StrategoGame.GREEN: return {"fill": GREEN_COLOR, "edge": GREEN_EDGE}
		StrategoGame.YELLOW: return {"fill": YELLOW_COLOR, "edge": YELLOW_EDGE}
	return {"fill": Color.GRAY, "edge": Color.WHITE}


func _gui_input(event: InputEvent) -> void:
	if game == null:
		return
	if event is InputEventMouseMotion:
		if middle_panning:
			pan_offset += event.relative
			_clamp_pan()
			queue_redraw()
			accept_event()
			return
		if not interaction_enabled or game.game_over or game.phase not in [StrategoGame.PHASE_PLANNING, StrategoGame.PHASE_LEFTOVER_PLANNING]:
			return
		if left_button_down:
			drag_current = event.position
			if drag_start.distance_to(drag_current) >= 8.0:
				drag_selecting = true
			queue_redraw()
			accept_event()
		return
	if event is not InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_set_zoom(zoom_level * 1.16, event.position)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_set_zoom(zoom_level / 1.16, event.position)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		middle_panning = event.pressed
		mouse_default_cursor_shape = Control.CURSOR_DRAG if middle_panning else Control.CURSOR_POINTING_HAND
		accept_event()
		return
	if not interaction_enabled or game.game_over or game.phase not in [StrategoGame.PHASE_PLANNING, StrategoGame.PHASE_LEFTOVER_PLANNING]:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not selected_piece_ids.is_empty():
			var before := _current_order_snapshot()
			var result: Dictionary
			if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING:
				for piece_id in selected_piece_ids:
					game.clear_unit_order(viewing_player, piece_id)
				result = {"ok": true, "message": "Removed the selected leftover move%s." % ["s" if selected_piece_ids.size() > 1 else ""]}
			elif selected_piece_ids.size() > 1:
				result = game.pop_group_order_step(viewing_player, selected_piece_ids)
			else:
				result = game.pop_order_step(viewing_player, selected_piece_id)
			if bool(result.get("ok", false)) and before != _current_order_snapshot():
				_record_order_undo(before)
			order_changed.emit(result.get("message", "Removed the last impulse."))
			_emit_selected_description()
			queue_redraw()
		accept_event()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		left_button_down = true
		drag_start = event.position
		drag_current = event.position
		drag_selecting = false
		drag_additive = event.shift_pressed or event.ctrl_pressed
		accept_event()
		return
	if not left_button_down:
		return
	left_button_down = false
	if drag_selecting:
		_select_in_rect(Rect2(drag_start, drag_current - drag_start).abs(), drag_additive)
	else:
		_handle_left_click(event.position, drag_additive)
	drag_selecting = false
	queue_redraw()
	accept_event()


func _select_in_rect(rect: Rect2, additive: bool) -> void:
	if not additive:
		selected_piece_ids.clear()
	var geometry := _board_geometry()
	for piece: Dictionary in game.pieces:
		if int(piece.player) != viewing_player or not game.is_movable(piece):
			continue
		if rect.has_point(_cell_center(piece.position, geometry.origin, geometry.cell)) and int(piece.id) not in selected_piece_ids:
			selected_piece_ids.append(int(piece.id))
	selected_piece_id = selected_piece_ids.back() if not selected_piece_ids.is_empty() else StrategoGame.EMPTY
	_emit_selected_description()


func _handle_left_click(screen_position: Vector2, additive: bool) -> void:
	var geometry := _board_geometry()
	var local: Vector2 = screen_position - Vector2(geometry.origin)
	if local.x < 0 or local.y < 0 or local.x >= geometry.side or local.y >= geometry.side:
		return
	var clicked := Vector2i(int(local.x / geometry.cell), int(local.y / geometry.cell))
	var clicked_piece := game.piece_at(clicked)
	if not clicked_piece.is_empty() and int(clicked_piece.player) == viewing_player and game.is_movable(clicked_piece):
		var clicked_id := int(clicked_piece.id)
		if additive:
			if clicked_id in selected_piece_ids:
				selected_piece_ids.erase(clicked_id)
			else:
				selected_piece_ids.append(clicked_id)
		elif clicked_id not in selected_piece_ids:
			selected_piece_ids.assign([clicked_id])
		selected_piece_id = clicked_id if clicked_id in selected_piece_ids else (selected_piece_ids.back() if not selected_piece_ids.is_empty() else StrategoGame.EMPTY)
		_emit_selected_description()
		return
	if selected_piece_ids.is_empty() or selected_piece_id == StrategoGame.EMPTY:
		clear_selection()
		return
	var selected_piece: Dictionary = game.pieces[selected_piece_id]
	var anchor_id := _command_anchor_id()
	var projected_id := anchor_id if anchor_id != StrategoGame.EMPTY else selected_piece_id
	var projected: Vector2i = game.pieces[projected_id].position if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING else game.projected_main_destination(projected_id)
	var before := _current_order_snapshot()
	var result: Dictionary
	if selected_piece_ids.size() > 1:
		if leftover_mode:
			var leftover_direction: Vector2i = clicked - projected
			result = game.set_group_leftover_step(viewing_player, selected_piece_ids, leftover_direction)
		elif prefer_ranged and selected_piece.role == StrategoGame.ROLE_ARCHER and not clicked_piece.is_empty():
			order_changed.emit("Ranged orders are issued to one Archer at a time.")
			return
		else:
			var direction: Vector2i = clicked - projected
			result = game.append_group_order_step(viewing_player, selected_piece_ids, direction)
	elif leftover_mode:
		result = game.set_leftover_order(viewing_player, selected_piece_id, clicked)
	elif prefer_ranged and selected_piece.role == StrategoGame.ROLE_ARCHER and not clicked_piece.is_empty() and not game.are_allied_players(viewing_player, int(clicked_piece.player)) and projected.distance_to(clicked) == 1.0:
		result = game.set_ranged_order(viewing_player, selected_piece_id, clicked)
	else:
		result = game.append_order_step(viewing_player, selected_piece_id, clicked)
	if bool(result.get("ok", false)) and before != _current_order_snapshot():
		_record_order_undo(before)
	order_changed.emit("Order updated." if bool(result.get("ok", false)) else String(result.get("message", "Invalid order.")))
	_emit_selected_description()


func _emit_selected_description() -> void:
	if selected_piece_ids.is_empty() or selected_piece_id == StrategoGame.EMPTY:
		selection_changed.emit("No formations selected.")
		return
	if selected_piece_ids.size() > 1:
		var ordered := 0
		for piece_id in selected_piece_ids:
			var order := game.order_for_piece(piece_id)
			if (order.get("leftover", Vector2i(-1, -1)).x >= 0) if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING else not order.is_empty():
				ordered += 1
		selection_changed.emit("%d formations selected · %d %s ordered · click a highlighted direction or use arrow keys to move all." % [selected_piece_ids.size(), ordered, "leftover" if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING else "main"])
		return
	var piece: Dictionary = game.pieces[selected_piece_id]
	var order := game.order_for_piece(selected_piece_id)
	var path: Array = order.get("path", [])
	var text := "%s · %d/%d main impulses planned" % [game.piece_description(piece), path.size(), game.movement_limit_for(piece)]
	if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING:
		text = "%s · %d movement remaining" % [game.piece_description(piece), maxi(0, game.movement_limit_for(piece) - int(piece.movement_used))]
	if order.get("ranged_target", Vector2i(-1, -1)).x >= 0:
		text += " · ranged shot set"
	if order.get("leftover", Vector2i(-1, -1)).x >= 0:
		text += " · leftover move set"
	selection_changed.emit(text)


func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or not interaction_enabled:
		return
	if event.keycode == KEY_ESCAPE:
		clear_selection()
		get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed and event.keycode == KEY_Z:
		undo_last_order()
		get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed and event.keycode == KEY_A:
		select_all_movable()
		get_viewport().set_input_as_handled()
		return
	var direction := Vector2i.ZERO
	match event.keycode:
		KEY_UP, KEY_W: direction = Vector2i.UP
		KEY_RIGHT, KEY_D: direction = Vector2i.RIGHT
		KEY_DOWN, KEY_S: direction = Vector2i.DOWN
		KEY_LEFT, KEY_A: direction = Vector2i.LEFT
	if direction != Vector2i.ZERO and not selected_piece_ids.is_empty():
		issue_selected_direction(direction)
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		clear_selection()
