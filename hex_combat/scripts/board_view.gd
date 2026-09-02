class_name StrategoBoardView
extends Control

signal order_changed(message: String)
signal examine_requested(piece_id: int)
signal selection_changed(description: String)
signal zoom_changed(percent: int)
signal undo_availability_changed(available: bool)
signal view_changed

const BLUE_COLOR := Color("#1b4a86")
const BLUE_EDGE := Color("#7fc2ff")
const RED_COLOR := Color("#93251f")
const RED_EDGE := Color("#e88b6c")
const GREEN_COLOR := Color("#1f6b4a")
const GREEN_EDGE := Color("#75d9aa")
const YELLOW_COLOR := Color("#94741f")
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

## Movement animation. A round resolves all at once, so by the time anything is
## drawn every formation already stands on its final square. Rather than track a
## second copy of the board, this rewinds each formation visually and walks it
## forward again, as a pixel offset applied to the one point _draw_piece derives
## everything else from. Game state, hit testing, fog and selection keep using
## the real cell throughout, so the animation cannot desync from the rules.
##
## The beats are the engine's own movement impulses, which is the point: Weight
## decides which impulse a formation starts on, and that timing is why a faster
## formation cannot follow a slower one into a square it has not vacated yet.
## Played out, that rule becomes something you watch rather than something you
## have to be told.
const MARCH_BEAT_MSEC := 380.0
## How far into the contested square a bounced formation lunges before being
## turned back, as a fraction of a cell.
const BOUNCE_LUNGE := 0.42

# piece_id -> Array of {beat:int, from:Vector2i, to:Vector2i, bounce:bool}
var _march_steps: Dictionary = {}
# The impulse numbers that actually carried movement, in order. An impulse with
# nothing in it is skipped rather than played as an empty beat.
var _march_beats: Array[int] = []
var _march_started_msec := 0
var _march_active := false
var zoom_level := 1.0
var pan_offset := Vector2.ZERO
var min_zoom := 0.9
var max_zoom := 2.6
var left_button_down := false
var drag_start := Vector2.ZERO
var drag_current := Vector2.ZERO
var drag_selecting := false
var drag_additive := false
var drag_force_select := false

const CONTEXT_EXAMINE := 0
const CONTEXT_SHOOT := 1
const CONTEXT_SUPPRESS := 2
const CONTEXT_CANCEL := 3
const CONTEXT_SUPPORT := 4
const CONTEXT_JOIN_VOLLEY := 5

var _context_menu: PopupMenu = null
var _context_menu_cell := Vector2i(-1, -1)
var _context_menu_piece := -1
var middle_panning := false
var order_undo_stack: Array[Dictionary] = []
var overview_target: StrategoBoardView = null


func _ready() -> void:
	if overview_mode:
		# The overview is sized by its panel; the playing view demands room.
		custom_minimum_size = Vector2(0, 0)
		return
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
	var unit_size := HexGrid.board_pixel_size(1.0, StrategoGame.BOARD_SIZE, StrategoGame.BOARD_SIZE)
	var available := (size - Vector2(26, 26)).max(Vector2(300, 260))
	var base_cell := minf(available.x / unit_size.x, available.y / unit_size.y)
	var cell := base_cell * zoom_level
	var board_size := unit_size * cell
	var origin := (size - board_size) * 0.5 + pan_offset
	return {"origin": origin, "size": board_size, "cell": cell}


func zoom_in() -> void:
	_set_zoom(zoom_level * 1.2, Vector2(size.x * 0.5, size.y * 0.82))


func zoom_out() -> void:
	_set_zoom(zoom_level / 1.2, Vector2(size.x * 0.5, size.y * 0.82))


func reset_view() -> void:
	zoom_level = 1.0
	pan_offset = Vector2.ZERO
	zoom_changed.emit(int(round(zoom_level * 100.0)))
	view_changed.emit()
	queue_redraw()


## Put one board-space point at the centre of the playable view. The minimap
## uses continuous board coordinates so clicking between cells feels like map
## navigation rather than unit selection.
func center_on_board_point(board_point: Vector2) -> void:
	var geometry := _board_geometry()
	var board_size: Vector2 = geometry.size
	var centered_origin := (size - board_size) * 0.5
	var bounded := Vector2i(
		clampi(roundi(board_point.x), 0, StrategoGame.BOARD_SIZE - 1),
		clampi(roundi(board_point.y), 0, StrategoGame.BOARD_SIZE - 1),
	)
	var target := HexGrid.cell_center(bounded, Vector2.ZERO, float(geometry.cell))
	pan_offset = size * 0.5 - centered_origin - target
	_clamp_pan()
	view_changed.emit()
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


func issue_selected_direction(direction: int) -> Dictionary:
	if not interaction_enabled or game == null or selected_piece_ids.is_empty():
		return {"ok": false, "message": "Select at least one movable formation first."}
	var before := _current_order_snapshot()
	var result: Dictionary
	if leftover_mode:
		result = game.set_group_leftover_step(viewing_player, selected_piece_ids, direction)
	else:
		result = game.append_group_order_step(viewing_player, selected_piece_ids, direction, false)
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
	var new_geometry := _board_geometry()
	var centered_origin := (size - Vector2(new_geometry.size)) * 0.5
	pan_offset = focus - centered_origin - board_point * float(new_geometry.cell)
	_clamp_pan()
	zoom_changed.emit(int(round(zoom_level * 100.0)))
	view_changed.emit()
	queue_redraw()


func _clamp_pan() -> void:
	var geometry := _board_geometry()
	var board_size: Vector2 = geometry.size
	var limit_x := maxf(0.0, board_size.x * 0.62)
	var limit_y := maxf(34.0, board_size.y * 0.62)
	pan_offset.x = clampf(pan_offset.x, -limit_x, limit_x)
	pan_offset.y = clampf(pan_offset.y, -limit_y, limit_y)


## When true this view draws itself as an overview: the whole board, no chrome,
## no interaction. It is the same draw path at a smaller scale, so fog is
## inherited rather than reimplemented and cannot drift from the real rules.
var overview_mode := false


func _draw() -> void:
	if game == null:
		return
	if overview_mode:
		_draw_overview()
		return
	_draw_surroundings()
	var geometry := _board_geometry()
	var origin: Vector2 = geometry.origin
	var cell: float = geometry.cell
	var board_size: Vector2 = geometry.size
	_draw_battlefield(origin, cell, board_size)
	_draw_coordinates(origin, cell, board_size)
	_draw_order_ghosts(origin, cell)
	for piece: Dictionary in game.pieces:
		if not piece.alive:
			continue
		if not reveal_all and not game.game_over and not game.is_piece_visible_to(piece, viewing_player):
			continue
		_draw_piece(piece, origin, cell)
	# Selection outlines and direction controls stay above formation banners.
	_draw_selection(origin, cell)
	_draw_vignette(origin, board_size)
	_draw_drag_selection()
	if not combat_event.is_empty():
		_draw_combat_overlay(origin, cell)
	elif game.game_over:
		_draw_game_over_overlay(origin, cell, board_size)


## The whole board at panel scale, plus a frame showing what the main view is
## currently looking at.
func _draw_overview() -> void:
	var geometry := _overview_geometry()
	var origin: Vector2 = geometry.origin
	var cell := float(geometry.cell)
	var board_size: Vector2 = geometry.size
	draw_rect(Rect2(origin, board_size), Color("#20301f"), true)
	for y in StrategoGame.BOARD_SIZE:
		for x in StrategoGame.BOARD_SIZE:
			var position := Vector2i(x, y)
			var ground := Color("#4a5b38")
			if game.is_lake(position) or game.is_water(position): ground = Color("#2b5560")
			elif game.is_bridge(position): ground = Color("#7d5f38")
			elif _is_objective_square(position): ground = Color("#8a7130")
			var points := HexGrid.polygon(position, origin, cell, 0.15)
			draw_colored_polygon(points, ground)
			if not reveal_all and not game.game_over and not game.is_position_visible_to(position, viewing_player):
				draw_colored_polygon(points, Color(0.02, 0.04, 0.05, 0.72))
	# Formations go through the same visibility test the main board uses.
	for piece: Dictionary in game.pieces:
		if not piece.alive or piece.type == StrategoGame.FLAG: continue
		if not reveal_all and not game.game_over and not game.is_piece_visible_to(piece, viewing_player): continue
		var colors := _player_colors(int(piece.player))
		var centre := HexGrid.cell_center(piece.position, origin, cell)
		draw_circle(centre, maxf(1.6, cell * 0.34), colors.edge)
	if overview_target != null:
		var visible_board := _overview_viewport_board_rect()
		var visible_rect := Rect2(origin + visible_board.position * cell, visible_board.size * cell)
		draw_rect(visible_rect, Color(0.72, 0.9, 1.0, 0.12), true)
		draw_rect(visible_rect, Color("#c7e9ff"), false, 2.0)
	draw_rect(Rect2(origin, board_size), GOLD, false, 1.0)


func _overview_geometry() -> Dictionary:
	var unit_size := HexGrid.board_pixel_size(1.0, StrategoGame.BOARD_SIZE, StrategoGame.BOARD_SIZE)
	var available := (size - Vector2(8, 8)).max(Vector2.ONE)
	var cell := minf(available.x / unit_size.x, available.y / unit_size.y)
	var board_size := unit_size * cell
	var origin := (size - board_size) * 0.5
	return {"origin": origin, "size": board_size, "cell": cell}


func _overview_board_point(local_point: Vector2) -> Vector2:
	var geometry := _overview_geometry()
	var cell := HexGrid.pixel_to_cell(local_point, geometry.origin, float(geometry.cell))
	return Vector2(
		clampi(cell.x, 0, StrategoGame.BOARD_SIZE - 1),
		clampi(cell.y, 0, StrategoGame.BOARD_SIZE - 1),
	)


func _overview_viewport_board_rect() -> Rect2:
	if overview_target == null:
		return Rect2(Vector2.ZERO, Vector2(StrategoGame.BOARD_SIZE, StrategoGame.BOARD_SIZE))
	var target_geometry := overview_target._board_geometry()
	var target_origin: Vector2 = target_geometry.origin
	var target_cell := float(target_geometry.cell)
	var top_left := (-target_origin) / target_cell
	var bottom_right := (overview_target.size - target_origin) / target_cell
	var unit_size := HexGrid.board_pixel_size(1.0, StrategoGame.BOARD_SIZE, StrategoGame.BOARD_SIZE)
	top_left.x = clampf(top_left.x, 0.0, unit_size.x)
	top_left.y = clampf(top_left.y, 0.0, unit_size.y)
	bottom_right.x = clampf(bottom_right.x, 0.0, unit_size.x)
	bottom_right.y = clampf(bottom_right.y, 0.0, unit_size.y)
	return Rect2(top_left, (bottom_right - top_left).max(Vector2.ZERO))


## A treeline framing the play area, rather than the drifting bokeh discs that
## previously filled this space and read as interface noise. Trees are drawn only
## in the margin outside the board, so they frame without competing.
func _draw_surroundings() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0a1410"), true)
	var geometry := _board_geometry()
	var field := Rect2(Vector2(geometry.origin), Vector2(geometry.size)).grow(6.0)
	for index in 160:
		var point := Vector2(_noise_value(index, 3) * size.x, _noise_value(index, 11) * size.y)
		if field.has_point(point): continue
		var scale := 9.0 + _noise_value(index, 23) * 13.0
		_draw_tree(point, scale, index)


## A simple conifer: a dark trunk under two stacked canopies. Cheap enough to
## draw a hundred and a half of them every frame.
func _draw_tree(base: Vector2, scale: float, seed_value: int) -> void:
	var tint := Color("#14301d") if seed_value % 3 else Color("#1b3a24")
	var shade := tint.darkened(0.25)
	draw_line(base, base - Vector2(0, scale * 0.5), Color("#241a12"), maxf(1.0, scale * 0.16))
	for tier in 2:
		var lift := scale * (0.42 + float(tier) * 0.42)
		var spread := scale * (0.62 - float(tier) * 0.16)
		draw_colored_polygon(PackedVector2Array([
			base - Vector2(0, lift + scale * 0.62),
			base + Vector2(spread, -lift),
			base + Vector2(-spread, -lift),
		]), shade if tier == 0 else tint)


## Column and row numbers down the board's edges. These use engine coordinates,
## 0 to 19, so what a player reads matches the battle log, the replay files and
## anything driving the game over the command bridge.
func _draw_coordinates(origin: Vector2, cell: float, _board_size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var size_points := maxi(9, int(cell * 0.34))
	# Crowded axes drop every other label rather than overlapping.
	var stride := 1 if cell >= 26.0 else 2
	var gutter := maxf(14.0, cell * 0.62)
	for index in StrategoGame.BOARD_SIZE:
		if index % stride != 0: continue
		var faded := Color("#c9b98a")
		var column_center := HexGrid.cell_center(Vector2i(index, 0), origin, cell)
		var row_center := HexGrid.cell_center(Vector2i(0, index), origin, cell)
		_draw_centered_text(font, str(index),
			Rect2(Vector2(column_center.x - cell * 0.5, origin.y - gutter), Vector2(cell, gutter)),
			size_points, faded)
		_draw_centered_text(font, str(index),
			Rect2(Vector2(origin.x - gutter, row_center.y - cell * 0.5), Vector2(gutter, cell)),
			size_points, faded)


## Objective squares are marked so the contested ground is legible without
## reading the scenario text.
func _is_objective_square(position: Vector2i) -> bool:
	for objective: Dictionary in game.objectives:
		if String(objective.type) == StrategoGame.OBJECTIVE_HOLD_SQUARE and objective.square == position:
			return true
	return false


func _draw_battlefield(origin: Vector2, cell: float, board_size: Vector2) -> void:
	draw_rect(Rect2(origin - Vector2(5, 5), board_size + Vector2(10, 10)), Color("#332b1c"), true)
	var deploying := game.phase == StrategoGame.PHASE_DEPLOYMENT
	var zone: Dictionary = {}
	if deploying:
		for cell_position in game.deployment_zone_cells(viewing_player): zone[cell_position] = true
	for y in StrategoGame.BOARD_SIZE:
		for x in StrategoGame.BOARD_SIZE:
			var position := Vector2i(x, y)
			var center := HexGrid.cell_center(position, origin, cell)
			var radius := HexGrid.radius_for_size(cell)
			var rect := Rect2(center - Vector2(radius, cell * 0.5), Vector2(radius * 2.0, cell))
			var points := HexGrid.polygon(position, origin, cell, maxf(0.35, cell * 0.008))
			var variation := _noise_value(x + y * 20, 41)
			var ground := Color("#435532").lerp(Color("#6d7041"), variation * 0.42)
			if (x + y) % 2 == 0:
				ground = ground.lightened(0.035)
			if game.is_lake(position) or game.is_water(position):
				ground = Color("#254f59").lerp(Color("#39717a"), variation * 0.35)
			elif game.is_bridge(position):
				ground = Color("#795c37").lerp(Color("#9a7748"), variation * 0.25)
			elif _is_objective_square(position):
				ground = Color("#6d5a2a").lerp(Color("#a08a3c"), variation * 0.3)
			draw_colored_polygon(points, ground)
			if _is_objective_square(position):
				var objective_points := HexGrid.polygon(position, origin, cell, cell * 0.10)
				objective_points.append(objective_points[0])
				draw_polyline(objective_points, GOLD, maxf(1.5, cell * 0.06), true)
			_draw_cell_texture(position, rect, cell)
			if deploying:
				# The zone doubles as this player's fog: outside it is dimmed by
				# the ordinary fog pass below, so only the zone itself needs a
				# positive marker for where a placement is legal.
				if position in zone:
					var zone_points := points.duplicate()
					zone_points.append(zone_points[0])
					draw_polyline(zone_points, Color("#8dccff"), maxf(1.0, cell * 0.03), true)
			if not reveal_all and not game.game_over and not game.is_position_visible_to(position, viewing_player):
				draw_colored_polygon(points, FOG_COLOR)
			var border := points.duplicate()
			border.append(border[0])
			draw_polyline(border, Color(0.84, 0.85, 0.68, 0.17), maxf(0.7, cell * 0.017), true)
	_draw_river_overlay(origin, cell, board_size)


func _draw_cell_texture(position: Vector2i, rect: Rect2, cell: float) -> void:
	if game.is_water(position) or game.is_lake(position):
		var wave_y := rect.position.y + cell * (0.35 + _noise_value(position.x, position.y + 80) * 0.35)
		draw_line(Vector2(rect.position.x + cell * 0.12, wave_y), Vector2(rect.end.x - cell * 0.12, wave_y), Color(0.55, 0.8, 0.82, 0.18), maxf(1.0, cell * 0.025))
	elif game.is_bridge(position):
		for plank in 3:
			var plank_y := rect.position.y + cell * float(plank + 1) / 4.0
			draw_line(Vector2(rect.position.x, plank_y), Vector2(rect.end.x, plank_y), Color(0.16, 0.11, 0.065, 0.55), maxf(1.0, cell * 0.025))
	else:
		# Ground detail: a worn patch on some squares, a few tufts on others, so
		# the field reads as terrain rather than as a spreadsheet of tinted cells.
		var wear := _noise_value(position.x + 31, position.y + 7)
		if wear > 0.72:
			var patch_centre := rect.position + Vector2(0.35 + wear * 0.3, 0.4 + _noise_value(position.x, position.y + 5) * 0.25) * cell
			draw_circle(patch_centre, cell * (0.16 + wear * 0.13), Color(0.42, 0.36, 0.22, 0.24))
		var tufts := 2 if wear < 0.5 else 1
		for index in tufts:
			var tuft := rect.position + Vector2(
				_noise_value(position.x * 3 + index, position.y + 17),
				_noise_value(position.x + 20, position.y * 3 + index),
			) * cell
			var blade := maxf(1.0, cell * 0.09)
			draw_line(tuft, tuft - Vector2(blade * 0.25, blade), Color(0.55, 0.62, 0.29, 0.34), maxf(0.8, cell * 0.022))
			draw_line(tuft, tuft - Vector2(-blade * 0.2, blade * 0.85), Color(0.48, 0.57, 0.26, 0.3), maxf(0.8, cell * 0.02))
		if _noise_value(position.x + 63, position.y + 41) > 0.93:
			var stone := rect.position + Vector2(0.5, 0.55) * cell
			draw_circle(stone, cell * 0.11, Color(0.44, 0.44, 0.41, 0.5))
			draw_circle(stone - Vector2(cell * 0.02, cell * 0.03), cell * 0.075, Color(0.58, 0.58, 0.54, 0.45))


func _draw_river_overlay(origin: Vector2, cell: float, board_size: Vector2) -> void:
	if game.scenario != StrategoGame.SCENARIO_BRIDGE:
		return
	var river_y := int(StrategoGame.BRIDGE_RIVER_Y)
	var river_top := INF
	var river_bottom := -INF
	for x in StrategoGame.BOARD_SIZE:
		var center := HexGrid.cell_center(Vector2i(x, river_y), origin, cell)
		river_top = minf(river_top, center.y - cell * 0.5)
		river_bottom = maxf(river_bottom, center.y + cell * 0.5)

	# Odd columns sit half a hex lower, so the complete visual footprint of one
	# logical river row is exactly one and a half hexes high. Painting that world-
	# space band keeps the banks straight without inventing half-hex terrain.
	var river_rect := Rect2(Vector2(origin.x, river_top), Vector2(board_size.x, river_bottom - river_top))
	draw_rect(river_rect, Color("#285660"), true)
	for wave in 4:
		var wave_y := river_top + river_rect.size.y * float(wave + 1) / 5.0
		draw_line(Vector2(river_rect.position.x, wave_y), Vector2(river_rect.end.x, wave_y), Color(0.55, 0.8, 0.82, 0.12), maxf(1.0, cell * 0.022))

	var radius := HexGrid.radius_for_size(cell)
	var bridge_left := INF
	var bridge_right := -INF
	for x in StrategoGame.BOARD_SIZE:
		var position := Vector2i(x, river_y)
		if game.is_bridge(position):
			var center := HexGrid.cell_center(position, origin, cell)
			bridge_left = minf(bridge_left, center.x - radius * 0.72)
			bridge_right = maxf(bridge_right, center.x + radius * 0.72)
	if bridge_left < bridge_right:
		var deck_top := river_top - cell * 0.12
		var deck_bottom := river_bottom + cell * 0.12
		var deck_rect := Rect2(Vector2(bridge_left, deck_top), Vector2(bridge_right - bridge_left, deck_bottom - deck_top))
		draw_rect(deck_rect, Color("#8c6b40"), true)
		for plank in 6:
			var plank_y := deck_top + deck_rect.size.y * float(plank + 1) / 7.0
			draw_line(Vector2(bridge_left, plank_y), Vector2(bridge_right, plank_y), Color(0.16, 0.11, 0.065, 0.55), maxf(1.0, cell * 0.025))
		draw_line(Vector2(bridge_left, deck_top), Vector2(bridge_left, deck_bottom), Color("#b29360"), maxf(1.5, cell * 0.045))
		draw_line(Vector2(bridge_right, deck_top), Vector2(bridge_right, deck_bottom), Color("#b29360"), maxf(1.5, cell * 0.045))

	for edge_y in [river_top, river_bottom]:
		draw_line(Vector2(origin.x, edge_y), Vector2(origin.x + board_size.x, edge_y), Color("#716b56"), maxf(1.2, cell * 0.035))
		for x in range(0, StrategoGame.BOARD_SIZE, 2):
			var center := HexGrid.cell_center(Vector2i(x, river_y), origin, cell)
			if center.x >= bridge_left - cell * 0.15 and center.x <= bridge_right + cell * 0.15:
				continue
			var stone := Vector2(center.x + (_noise_value(x, int(edge_y)) - 0.5) * cell * 0.45, edge_y)
			draw_circle(stone, cell * 0.075, Color("#77705b"))
			draw_circle(stone - Vector2(cell * 0.015, cell * 0.015), cell * 0.043, Color("#a59c7c"))

	# The terrain art deliberately overlaps the halves of neighbouring hexes.
	# Restore their grid and fog on top so selection and visibility stay legible.
	for y in range(maxi(0, river_y - 1), mini(StrategoGame.BOARD_SIZE, river_y + 2)):
		for x in StrategoGame.BOARD_SIZE:
			var position := Vector2i(x, y)
			var points := HexGrid.polygon(position, origin, cell, maxf(0.35, cell * 0.008))
			if not reveal_all and not game.game_over and not game.is_position_visible_to(position, viewing_player):
				draw_colored_polygon(points, FOG_COLOR)
			var border := points.duplicate()
			border.append(border[0])
			draw_polyline(border, Color(0.84, 0.85, 0.68, 0.17), maxf(0.7, cell * 0.017), true)


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
				_draw_centered_text(font, str(game.impulse_for_movement_step(game.pieces[piece_id], index)), Rect2(center - Vector2(cell * 0.25, cell * 0.25), Vector2(cell * 0.5, cell * 0.5)), int(cell * 0.25), Color.WHITE)
				previous = position
			if not path.is_empty():
				_draw_hex(_cell_center(path.back(), origin, cell), cell * 0.48, Color(0.15, 0.48, 0.76, 0.2), Color("#75c2ff"), maxf(1.5, cell * 0.04))
			var ranged_target: Vector2i = order.get("ranged_target", Vector2i(-1, -1))
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
	# No order to project a destination from before the game has even started.
	if game.phase == StrategoGame.PHASE_DEPLOYMENT: return
	var anchor_id := _command_anchor_id()
	if anchor_id == StrategoGame.EMPTY:
		return
	var projected: Vector2i = game.pieces[anchor_id].position if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING else game.projected_main_destination(anchor_id)
	var projected_center := _cell_center(projected, origin, cell)
	for direction in HexGrid.DIRECTION_COUNT:
		var destination := HexGrid.neighbor(projected, direction)
		if game.is_inside(destination) and not game.is_blocked_terrain(destination):
			var marker_color := LEFTOVER_COLOR if leftover_mode else Color("#d8edff")
			var destination_center := _cell_center(destination, origin, cell)
			# On the boundary between the two cells, not the destination cell's
			# centre: whatever stands on the destination square stays readable.
			# The whole square is still the click target either way (hit-testing
			# is per-cell, not per-marker), so this is purely a visual move.
			_draw_direction_marker(projected_center.lerp(destination_center, 0.5), (destination_center - projected_center).normalized(), cell, marker_color)


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
	return game.planned_movement_reserved(piece_id) < game.movement_limit_for(game.pieces[piece_id])


func _draw_direction_marker(center: Vector2, direction: Vector2, cell: float, color: Color) -> void:
	draw_circle(center, cell * 0.19, Color(0.025, 0.16, 0.28, 0.9))
	draw_arc(center, cell * 0.19, 0.0, TAU, 24, color, maxf(1.6, cell * 0.04))
	var vector := direction.normalized()
	var perpendicular := Vector2(-vector.y, vector.x)
	var tip := center + vector * cell * 0.11
	var back := center - vector * cell * 0.08
	draw_colored_polygon(PackedVector2Array([
		tip,
		back + perpendicular * cell * 0.09,
		back - perpendicular * cell * 0.09,
	]), color)


func _draw_drag_selection() -> void:
	if not drag_selecting:
		return
	var rect := Rect2(drag_start, drag_current - drag_start).abs()
	draw_rect(rect, Color(0.24, 0.62, 1.0, 0.14), true)
	draw_rect(rect, Color("#8dccff"), false, 2.0)


func _draw_piece(piece: Dictionary, origin: Vector2, cell: float) -> void:
	# Every other measurement in this function hangs off this one point, so the
	# march offset is applied here and nowhere else: the art path, the
	# procedural path and the order badge all inherit it for free.
	var center := _cell_center(piece.position, origin, cell) + _march_offset(int(piece.id), cell)
	var colors := _player_colors(int(piece.player))
	var is_selected := int(piece.id) in selected_piece_ids
	var can_see_identity := reveal_all or game.game_over or game.is_piece_revealed_to(piece, viewing_player)
	# Square, so a banner sits inside its grid square instead of overhanging into
	# the ranks above and below. The pentagon is kept, compressed to fit the
	# square rather than extending past it.
	var scale := 0.86 if int(piece.id) == selected_piece_id else (0.81 if is_selected else 0.76)
	var extent := cell * scale
	var width := extent
	var height := extent
	var top := center - Vector2(width, height) * 0.5
	var banner := PackedVector2Array([
		top,
		top + Vector2(width, 0),
		top + Vector2(width, height * 0.72),
		top + Vector2(width * 0.5, height),
		top + Vector2(0, height * 0.72),
	])
	# An enemy you can see but have not identified still gets its own faction's
	# cloth, just with a question mark instead of a Role emblem. Weight is
	# public in this game, so the weight frame goes over the top: without it
	# the unknown banner would hide something the player is entitled to know.
	var art := UnitIconCatalog.texture_for_piece(piece) if can_see_identity else UnitIconCatalog.unknown_texture_for(int(piece.player))
	if art != null:
		_draw_art_piece(piece, art, Rect2(top, Vector2(width, height)), cell, colors, can_see_identity)
		if not can_see_identity:
			_draw_weight_frame(piece, banner, top, width, height, cell, colors)
	else:
		_draw_procedural_piece(piece, banner, top, width, height, center, cell, colors, can_see_identity)
	if int(piece.player) == viewing_player and not game.order_for_piece(int(piece.id)).is_empty():
		var badge := top + Vector2(width * 0.94, height * 0.04)
		draw_circle(badge, cell * 0.13, Color("#152315"))
		draw_arc(badge, cell * 0.13, 0.0, TAU, 24, Color("#91d33f"), 1.5)
		draw_line(badge + Vector2(-cell * 0.055, 0), badge + Vector2(-cell * 0.01, cell * 0.05), Color("#a8df4c"), 2.0)
		draw_line(badge + Vector2(-cell * 0.01, cell * 0.05), badge + Vector2(cell * 0.07, -cell * 0.06), Color("#a8df4c"), 2.0)


## The normalized texture owns the field, Weight frame and Role emblem. Current
## Strength and player identity remain live overlays so one Green art set can be
## shared by every faction without making opposing armies indistinguishable.
func _draw_art_piece(piece: Dictionary, art: Texture2D, rect: Rect2, cell: float, colors: Dictionary, can_see_identity: bool = true) -> void:
	var shadow_rect := Rect2(rect.position + Vector2(cell * 0.055, cell * 0.07), rect.size)
	draw_texture_rect(art, shadow_rect, false, Color(0, 0, 0, 0.48))
	draw_texture_rect(art, rect, false)
	# Strength is a secret alongside Role, so an unidentified enemy shows none.
	if can_see_identity:
		_draw_art_strength(piece, rect, cell)
	var faction_marker := rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.13)
	var marker_radius := maxf(2.0, cell * 0.075)
	draw_circle(faction_marker, marker_radius, colors.fill)
	draw_arc(faction_marker, marker_radius, 0.0, TAU, 18, colors.edge, maxf(1.0, cell * 0.025))


func _draw_art_strength(piece: Dictionary, rect: Rect2, cell: float) -> void:
	if piece.type == StrategoGame.FLAG: return
	var band := Rect2(rect.position + Vector2(0, rect.size.y * 0.56), Vector2(rect.size.x, rect.size.y * 0.27))
	var hurt := int(piece.strength) < int(piece.max_strength)
	var tint := Color("#ffd9a8") if hurt else Color.WHITE
	var numeral := str(int(piece.strength))
	var glyph := maxi(14, int(cell * 0.38))
	_draw_centered_text(ThemeDB.fallback_font, numeral, Rect2(band.position + Vector2(0, maxf(1.0, cell * 0.035)), band.size), glyph, Color(0, 0, 0, 0.78))
	_draw_centered_text(ThemeDB.fallback_font, numeral, band, glyph, tint)


## Flags, missing art and visible-but-unidentified enemies retain the old safe
## representation. In particular, the hidden path never loads a type texture or
## draws Strength.
func _draw_procedural_piece(piece: Dictionary, banner: PackedVector2Array, top: Vector2, width: float, height: float, center: Vector2, cell: float, colors: Dictionary, can_see_identity: bool) -> void:
	var shadow := PackedVector2Array()
	for point in banner:
		shadow.append(point + Vector2(cell * 0.06, cell * 0.08))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.48))
	# When frame art is present it owns the silhouette, so the coloured field is
	# inset to sit inside it rather than poking through its notched bottom.
	var framed_art := cell >= 52.0 and _frame_texture(String(piece.weight)) != null
	if framed_art:
		var centre_point := top + Vector2(width, height) * 0.5
		var field := PackedVector2Array()
		for point in banner:
			field.append(centre_point + (point - centre_point) * 0.8)
		draw_colored_polygon(field, colors.fill)
	else:
		draw_colored_polygon(banner, colors.fill)
	_draw_weight_frame(piece, banner, top, width, height, cell, colors)
	if can_see_identity:
		# "HEAVY" and "INFANTRY" cannot fit across a cell at playable zoom: the
		# font collapses to its minimum and the words turn to mush. The README's
		# piece code carries the same information in two glyphs, leaving room to
		# draw the strength large enough to read at a glance.
		var weight_text := "" if piece.type == StrategoGame.FLAG else String(piece.weight).substr(0, 1).to_upper()
		var role_text := "FLAG" if piece.type == StrategoGame.FLAG else String(piece.role).substr(0, 1).to_upper()
		# The frame already states the Weight, so the label only carries the Role:
		# a full word once there is room for it, a single letter when there is not.
		var word := "FLAG" if piece.type == StrategoGame.FLAG else String(piece.role).to_upper()
		var word_size := int(width * 0.19)
		var spelled := word_size >= 11
		var label := word if spelled else role_text
		var label_size := word_size if spelled else maxi(10, int(cell * 0.22))
		# Clear of the rim above and the numeral below, with a shadow so a light
		# letter still reads where the frame's highlight runs behind it.
		var label_box := Rect2(top + Vector2(0, height * 0.10), Vector2(width, height * 0.20))
		_draw_centered_text(ThemeDB.fallback_font, label, Rect2(label_box.position + Vector2(0, 1.0), label_box.size), label_size, Color(0, 0, 0, 0.55))
		_draw_centered_text(ThemeDB.fallback_font, label, label_box, label_size, Color("#f6eee0"))
		# The role icon only earns its space once a cell is big enough to render
		# it as something other than a smudge, and never behind the strength
		# numeral, where the two read as one doubled glyph.
		if cell >= 46.0 and cell < 52.0:
			_draw_role_icon(piece, center + Vector2(0, cell * 0.06), cell * 0.2, Color("#e8e1d5"))
		_draw_strength_tab(piece, top, width, height, cell)
	else:
		_draw_centered_text(ThemeDB.fallback_font, "?", Rect2(center - Vector2(width * 0.5, height * 0.38), Vector2(width, height * 0.63)), maxi(12, int(cell * 0.39)), Color.WHITE)
		var badge_center := top + Vector2(width * 0.88, height * 0.04)
		draw_circle(badge_center, cell * 0.14, Color("#121717"))
		draw_arc(badge_center, cell * 0.14, 0, TAU, 24, Color("#dfd8c7"), 1.2)
		_draw_centered_text(ThemeDB.fallback_font, "?", Rect2(badge_center - Vector2(cell * 0.13, cell * 0.13), Vector2(cell * 0.26, cell * 0.26)), maxi(7, int(cell * 0.19)), Color.WHITE)


## Weight frames as art. One image serves both armies: the coloured field is
## drawn underneath and the keyed frame ring sits over it. Missing files fall
## back to the procedural frames below, so the game runs with none, some or all
## of the art present.
const FRAME_TEXTURE_PATHS := {
	StrategoGame.WEIGHT_LIGHT: "res://assets/frame_light.png",
	StrategoGame.WEIGHT_MEDIUM: "res://assets/frame_medium.png",
	StrategoGame.WEIGHT_HEAVY: "res://assets/frame_heavy.png",
}
static var _frame_textures: Dictionary = {}


static func _frame_texture(weight: String) -> Texture2D:
	if weight in _frame_textures: return _frame_textures[weight]
	var path := String(FRAME_TEXTURE_PATHS.get(weight, ""))
	var texture: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
	_frame_textures[weight] = texture
	return texture


const WOOD_FRAME := Color("#7a4d22")
const WOOD_GRAIN := Color("#c69350")
const MAIL_FRAME := Color("#4d5a68")
const MAIL_RING := Color("#8f9dad")
const PLATE_FRAME := Color("#9aa4b2")
const PLATE_SHEEN := Color("#eef3fa")


## Weight is carried by the banner's material rather than a letter, because a
## texture is recognised at a glance where a glyph has to be read. It also maps
## onto Armour: bound wood at 0, mail at 1, riveted plate at 2.
func _draw_weight_frame(piece: Dictionary, banner: PackedVector2Array, top: Vector2, width: float, height: float, cell: float, colors: Dictionary) -> void:
	var outline := banner.duplicate()
	outline.append(banner[0])
	if piece.type == StrategoGame.FLAG:
		draw_polyline(outline, colors.edge, maxf(1.5, cell * 0.035), true)
		return
	# Below this size the frame art is smaller than its own grain and reads as
	# mud, where a flat coloured rim still says wood, mail or plate clearly.
	var art := _frame_texture(String(piece.weight)) if cell >= 52.0 else null
	if art != null:
		# The art already carries the material, so no procedural rim is drawn.
		# The art's own pentagon fills its bounding box, so it maps onto the
		# banner rect directly. A small bleed hides the seam at the edges.
		var bleed := Vector2(width * 0.03, height * 0.02)
		draw_texture_rect(art, Rect2(top - bleed, Vector2(width, height) + bleed * 2.0), false)
		draw_polyline(outline, Color(colors.edge, 0.28), maxf(1.0, cell * 0.012), true)
		return
	match String(piece.weight):
		StrategoGame.WEIGHT_LIGHT:
			# Bound planks: a slim rim with two seams and a leather lashing.
			draw_polyline(outline, WOOD_FRAME, maxf(1.6, cell * 0.05), true)
			draw_polyline(outline, WOOD_GRAIN, maxf(1.0, cell * 0.018), true)
			for seam in ([0.30, 0.58] if cell >= 44.0 else []):
				draw_line(top + Vector2(width * 0.08, height * seam), top + Vector2(width * 0.92, height * seam),
					Color(WOOD_GRAIN, 0.35), maxf(1.0, cell * 0.014))
		StrategoGame.WEIGHT_MEDIUM:
			# Mail: a doubled rim with a ring of links picked out along the top.
			draw_polyline(outline, MAIL_FRAME, maxf(2.0, cell * 0.07), true)
			draw_polyline(outline, MAIL_RING, maxf(1.0, cell * 0.02), true)
			if cell >= 44.0:
				var links := 6
				for index in links:
					var t := (float(index) + 0.5) / float(links)
					draw_arc(top + Vector2(width * t, height * 0.12), maxf(1.4, cell * 0.045),
						0.0, TAU, 10, Color(MAIL_RING, 0.75), maxf(1.0, cell * 0.016))
		_:
			# Plate: a thick rim, a bevel highlight along the top, and rivets.
			draw_polyline(outline, PLATE_FRAME, maxf(3.0, cell * 0.12), true)
			draw_polyline(outline, PLATE_SHEEN, maxf(1.0, cell * 0.03), true)
			if cell >= 44.0:
				draw_line(top + Vector2(width * 0.06, height * 0.05), top + Vector2(width * 0.94, height * 0.05),
					PLATE_SHEEN, maxf(1.2, cell * 0.026))
				draw_line(top + Vector2(width * 0.06, height * 0.05), top + Vector2(width * 0.06, height * 0.7),
					Color(PLATE_SHEEN, 0.5), maxf(1.0, cell * 0.02))
				var rivet := maxf(1.3, cell * 0.035)
				for spot in [Vector2(0.12, 0.08), Vector2(0.88, 0.08), Vector2(0.12, 0.68), Vector2(0.88, 0.68)]:
					draw_circle(top + Vector2(width * spot.x, height * spot.y), rivet, PLATE_SHEEN)
	# Thin and faint: the rim's job is to say which material, and a heavy army
	# tint over it pulls all three weights toward the same colour.
	draw_polyline(outline, Color(colors.edge, 0.3), maxf(1.0, cell * 0.012), true)


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


## Strength is the number a player reads most often, so it gets the largest
## glyph on the banner rather than a corner tab. Below a certain cell size the
## surrounding chrome costs more legibility than it adds, so it is dropped and
## the numeral is drawn straight onto the banner.
func _draw_strength_tab(piece: Dictionary, top: Vector2, width: float, height: float, cell: float) -> void:
	if piece.type == StrategoGame.FLAG: return
	var band := Rect2(top + Vector2(0, height * 0.28), Vector2(width, height * 0.46))
	var hurt := int(piece.strength) < int(piece.max_strength)
	var tint := Color("#ffd9a8") if hurt else Color.WHITE
	var numeral := str(int(piece.strength))
	var glyph := maxi(14, int(cell * 0.44))
	# A soft dark wash rather than a plate or an outline: an outline at this size
	# ghosts the glyph, a plate covers the shield, a wash just lifts it off.
	_draw_centered_text(ThemeDB.fallback_font, numeral, Rect2(band.position + Vector2(0, maxf(1.0, cell * 0.03)), band.size), glyph, Color(0, 0, 0, 0.6))
	_draw_centered_text(ThemeDB.fallback_font, numeral, band, glyph, tint)


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


func _draw_vignette(origin: Vector2, board_size: Vector2) -> void:
	var band := minf(board_size.x, board_size.y) * 0.065
	for index in 8:
		var alpha := 0.025 + float(index) * 0.018
		var inset := float(index) * band / 8.0
		var rect := Rect2(origin + Vector2(inset, inset), board_size - Vector2(inset, inset) * 2.0)
		draw_rect(rect, Color(0, 0, 0, alpha), false, band / 8.0)


func _process(_delta: float) -> void:
	if _march_active:
		# One extra beat of grace so the final impulse finishes easing into
		# place instead of snapping on the last frame.
		var total := (_march_beats.size() + 1) * MARCH_BEAT_MSEC
		if Time.get_ticks_msec() - _march_started_msec >= total:
			cancel_march()
		else:
			queue_redraw()
	if combat_event.is_empty() or combat_hold:
		return
	if Time.get_ticks_msec() - combat_started_msec >= combat_duration_msec:
		combat_event.clear()
	queue_redraw()


## Starts the march. `steps` is the round's visible movement, each entry
## {piece_id, impulse, from, to, bounce}; ordering and chaining are worked out
## here so callers only have to filter for what the viewer may see.
func begin_march(steps: Array) -> void:
	_march_steps.clear()
	_march_beats.clear()
	_march_active = false
	if steps.is_empty() or overview_mode:
		return
	var impulses: Array[int] = []
	for step in steps:
		var impulse := int(step.get("impulse", 0))
		if impulse > 0 and impulse not in impulses:
			impulses.append(impulse)
	if impulses.is_empty():
		return
	impulses.sort()
	_march_beats = impulses
	# Steps are chained per formation in impulse order, so a formation that
	# moves twice in a round walks its whole path, and a bounce late in the
	# round lunges from wherever the earlier steps left it rather than from the
	# square it started the round on.
	var ordered := steps.duplicate()
	ordered.sort_custom(func(a, b): return int(a.get("impulse", 0)) < int(b.get("impulse", 0)))
	var running: Dictionary = {}
	for step in ordered:
		var piece_id := int(step.get("piece_id", StrategoGame.EMPTY))
		if piece_id < 0 or piece_id >= game.pieces.size():
			continue
		var bounce := bool(step.get("bounce", false))
		var from: Vector2i = running.get(piece_id, step.get("from", Vector2i(-1, -1)))
		if from.x < 0:
			from = game.pieces[piece_id].position
		var to: Vector2i = step.get("to", from)
		if not _march_steps.has(piece_id):
			_march_steps[piece_id] = []
		_march_steps[piece_id].append({
			"beat": _march_beats.find(int(step.get("impulse", 0))),
			"from": from, "to": to, "bounce": bounce,
		})
		# A bounce ends where it began; only a real move advances the formation.
		running[piece_id] = from if bounce else to
	_march_started_msec = Time.get_ticks_msec()
	_march_active = true
	queue_redraw()


func march_in_progress() -> bool:
	return _march_active


func cancel_march() -> void:
	_march_active = false
	_march_steps.clear()
	_march_beats.clear()
	queue_redraw()


## Where a formation should appear right now, as a pixel offset from the square
## it actually occupies. Zero once its own steps are behind it, which is why a
## formation that has finished moving simply sits still while slower ones are
## still crossing the board.
func _march_offset(piece_id: int, cell: float) -> Vector2:
	if not _march_active or not _march_steps.has(piece_id):
		return Vector2.ZERO
	var steps: Array = _march_steps[piece_id]
	if steps.is_empty():
		return Vector2.ZERO
	var elapsed := float(Time.get_ticks_msec() - _march_started_msec)
	var beat := int(elapsed / MARCH_BEAT_MSEC)
	var progress := clampf((elapsed - beat * MARCH_BEAT_MSEC) / MARCH_BEAT_MSEC, 0.0, 1.0)
	# Ease out: formations leave briskly and settle, rather than sliding at a
	# constant speed like a cursor.
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var visual := Vector2(steps[0].from)
	for step: Dictionary in steps:
		var step_beat := int(step.beat)
		if step_beat < beat:
			if not bool(step.bounce):
				visual = Vector2(step.to)
		elif step_beat == beat:
			var from_point := Vector2(step.from)
			var to_point := Vector2(step.to)
			if bool(step.bounce):
				# Out and back inside one beat: the formation commits, is
				# refused, and returns. A bounce otherwise animates as nothing
				# at all, which reads as the order having been ignored.
				visual = from_point.lerp(to_point, sin(progress * PI) * BOUNCE_LUNGE)
			else:
				visual = from_point.lerp(to_point, eased)
			break
		else:
			break
	return (visual - Vector2(game.pieces[piece_id].position)) * cell


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


func _draw_game_over_overlay(origin: Vector2, cell: float, board_size: Vector2) -> void:
	draw_rect(Rect2(origin, board_size), Color(0.01, 0.02, 0.025, 0.72), true)
	var card := Rect2(origin.x + board_size.x * 0.18, origin.y + board_size.y * 0.5 - cell * 1.2, board_size.x * 0.64, cell * 2.4)
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
	return HexGrid.cell_center(position, origin, cell)


func _cell_at_screen(screen_position: Vector2) -> Vector2i:
	var geometry := _board_geometry()
	var candidate := HexGrid.pixel_to_cell(screen_position, geometry.origin, float(geometry.cell))
	if not game.is_inside(candidate):
		return Vector2i(-1, -1)
	var polygon := HexGrid.polygon(candidate, geometry.origin, float(geometry.cell))
	return candidate if Geometry2D.is_point_in_polygon(screen_position, polygon) else Vector2i(-1, -1)


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
	if overview_mode:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			left_button_down = event.pressed
			if event.pressed and overview_target != null:
				overview_target.center_on_board_point(_overview_board_point(event.position))
				accept_event()
		elif event is InputEventMouseMotion and left_button_down and overview_target != null:
			overview_target.center_on_board_point(_overview_board_point(event.position))
			accept_event()
		return
	if event is InputEventMouseMotion:
		if middle_panning:
			pan_offset += event.relative
			_clamp_pan()
			view_changed.emit()
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
	if not interaction_enabled or game.game_over or game.phase not in [StrategoGame.PHASE_DEPLOYMENT, StrategoGame.PHASE_PLANNING, StrategoGame.PHASE_LEFTOVER_PLANNING]:
		return
	if game.phase == StrategoGame.PHASE_DEPLOYMENT:
		# A separate, deliberately small path: no drag-select, no order paths,
		# no ranged targeting. Click a formation, then click where it goes.
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_deployment_click(event.position)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_handle_right_click(event.position)
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
		drag_force_select = event.alt_pressed
		accept_event()
		return
	if not left_button_down:
		return
	left_button_down = false
	if drag_selecting:
		_select_in_rect(Rect2(drag_start, drag_current - drag_start).abs(), drag_additive)
	else:
		_handle_left_click(event.position, drag_additive, drag_force_select)
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


## Right-click's primary job is "send my selection here" - a square move away
## from the small border-hugging direction markers, and a shortcut for a
## destination that is not one of the four highlighted directions at all. It
## only falls back to the context menu when there is no order to give: nothing
## selected, or the square is not a legal next step (too far, blocked, an
## archer choosing a ranged target rather than a walk-in).
func _handle_right_click(screen_position: Vector2) -> void:
	var clicked := _cell_at_screen(screen_position)
	if clicked.x < 0: return
	if not selected_piece_ids.is_empty() and selected_piece_id != StrategoGame.EMPTY:
		var clicked_piece := game.piece_at(clicked)
		# A legal Archer target needs the context menu before the quick movement
		# shortcut. On an enemy this preserves the Attack/Volley choice; on an
		# empty adjacent hex it makes Volley reachable instead of silently
		# interpreting the right-click as movement.
		if not _selected_archer_can_volley(clicked):
			var result := _issue_order_to_square(clicked, clicked_piece, true)
			if bool(result.get("ok", false)):
				queue_redraw()
				return
	_open_context_menu(screen_position)


## Right-click menu for a board square. Examine is always offered; Shoot and
## Suppress Square appear only when a selected Archer could actually declare
## them, so the menu doubles as a statement of what is legal right now.
func _open_context_menu(screen_position: Vector2) -> void:
	var cell := _cell_at_screen(screen_position)
	if cell.x < 0: return
	var occupant := game.piece_at(cell)
	var visible_occupant := not occupant.is_empty() and game.is_piece_visible_to(occupant, viewing_player)
	if _context_menu == null:
		_context_menu = PopupMenu.new()
		_context_menu.id_pressed.connect(_on_context_menu_pressed)
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color("#08131d")
		frame.border_color = GOLD
		frame.set_border_width_all(1)
		frame.set_corner_radius_all(4)
		frame.set_content_margin_all(6)
		_context_menu.add_theme_stylebox_override("panel", frame)
		var highlight := StyleBoxFlat.new()
		highlight.bg_color = Color("#14375e")
		highlight.border_color = GOLD
		highlight.set_border_width_all(1)
		highlight.set_corner_radius_all(3)
		_context_menu.add_theme_stylebox_override("hover", highlight)
		_context_menu.add_theme_color_override("font_color", Color("#f0ead6"))
		_context_menu.add_theme_color_override("font_hover_color", Color("#ffe9b8"))
		_context_menu.add_theme_font_size_override("font_size", 14)
		add_child(_context_menu)
	_context_menu.clear()
	_context_menu_cell = cell
	_context_menu_piece = int(occupant.id) if visible_occupant else StrategoGame.EMPTY
	if visible_occupant:
		_context_menu.add_item("Inspect", CONTEXT_EXAMINE)
		# Targets the unit under the cursor, not the current selection - the
		# whole point is cancelling one formation's orders without disturbing
		# whatever else is currently selected.
		if int(occupant.player) == viewing_player and interaction_enabled and _piece_has_a_pending_order(int(occupant.id)):
			_context_menu.add_item("Cancel Order", CONTEXT_CANCEL)
		# Walking into an ally is the same order, but it does not read as one.
		# Naming it is the point: reinforcing a formation that is about to be
		# attacked should look like a decision, not a pathing accident.
		if not support_candidates_for(cell).is_empty():
			_context_menu.add_item("Support", CONTEXT_SUPPORT)
	var archer_id := _selected_archer_id()
	if archer_id != StrategoGame.EMPTY:
		var enemy_here := visible_occupant and not game.are_allied_players(viewing_player, int(occupant.player))
		if enemy_here and game.ranged_order_is_available(viewing_player, archer_id, cell, int(occupant.id)):
			_context_menu.add_item("Attack", CONTEXT_SHOOT)
		if game.ranged_order_is_available(viewing_player, archer_id, cell):
			# "Volley" for suppressing fire: it reads as an action rather than as
			# a description of the targeting mode.
			_context_menu.add_item("Volley", CONTEXT_SUPPRESS)
			# Offered only once an ally has actually declared a Volley here, so
			# the third choice appears exactly when there is something to join.
			if game.volley_leader_at(viewing_player, cell, archer_id) != StrategoGame.EMPTY:
				_context_menu.add_item("Join Volley", CONTEXT_JOIN_VOLLEY)
	if _context_menu.item_count == 0: return
	_context_menu.position = Vector2i(get_screen_position() + screen_position)
	_context_menu.reset_size()
	_context_menu.popup()


## True when a formation has anything to cancel: a main-phase path, an aimed
## shot, or (during the leftover phase) a leftover move.
func _piece_has_a_pending_order(piece_id: int) -> bool:
	var order := game.order_for_piece(piece_id)
	if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING:
		return order.get("leftover", Vector2i(-1, -1)).x >= 0 or order.get("ranged_target", Vector2i(-1, -1)).x >= 0
	return not order.is_empty()


func _selected_archer_id() -> int:
	if not interaction_enabled or game.phase != StrategoGame.PHASE_LEFTOVER_PLANNING: return StrategoGame.EMPTY
	for piece_id in selected_piece_ids:
		if game.pieces[piece_id].role == StrategoGame.ROLE_ARCHER: return int(piece_id)
	return StrategoGame.EMPTY


## Which of the current selection could move up in support of the formation on
## `cell`. A query rather than logic buried in the popup, so what the menu offers
## can be covered headlessly, the same way Volley's availability is.
func support_candidates_for(cell: Vector2i) -> Array[int]:
	var candidates: Array[int] = []
	if not interaction_enabled or game == null or game.phase != StrategoGame.PHASE_PLANNING: return candidates
	var occupant := game.piece_at(cell)
	if occupant.is_empty() or not game.are_allied_players(viewing_player, int(occupant.player)): return candidates
	for piece_id in selected_piece_ids:
		var id := int(piece_id)
		if id == int(occupant.id) or int(game.pieces[id].player) != viewing_player: continue
		if not game.is_movable(game.pieces[id]) or not StrategoGame.are_adjacent(game.pieces[id].position, cell): continue
		candidates.append(id)
	return candidates


## Right-click must offer Volley before treating a legal target hex as a move.
## Kept as a small query so the input priority can be covered without opening a
## real popup in the headless rules suite.
func _selected_archer_can_volley(cell: Vector2i) -> bool:
	var archer_id := _selected_archer_id()
	return archer_id != StrategoGame.EMPTY and game.ranged_order_is_available(viewing_player, archer_id, cell)


func _on_context_menu_pressed(id: int) -> void:
	if id == CONTEXT_EXAMINE:
		if _context_menu_piece != StrategoGame.EMPTY: examine_requested.emit(_context_menu_piece)
		return
	if id == CONTEXT_CANCEL:
		if _context_menu_piece != StrategoGame.EMPTY:
			var before_cancel := _current_order_snapshot()
			game.clear_unit_order(viewing_player, _context_menu_piece)
			if before_cancel != _current_order_snapshot(): _record_order_undo(before_cancel)
			order_changed.emit("Order cancelled.")
			_emit_selected_description()
			queue_redraw()
		return
	if id == CONTEXT_SUPPORT:
		var candidates := support_candidates_for(_context_menu_cell)
		if candidates.is_empty(): return
		var before_support := _current_order_snapshot()
		var ordered := 0
		var refusal := "Invalid order."
		for candidate_id in candidates:
			var support_result := game.set_support_order(viewing_player, candidate_id, _context_menu_cell)
			if bool(support_result.get("ok", false)): ordered += 1
			else: refusal = String(support_result.get("message", refusal))
		if ordered > 0 and before_support != _current_order_snapshot(): _record_order_undo(before_support)
		order_changed.emit("Moving up in support." if ordered > 0 else refusal)
		_emit_selected_description()
		queue_redraw()
		return
	var archer_id := _selected_archer_id()
	if archer_id == StrategoGame.EMPTY: return
	var before := _current_order_snapshot()
	var result: Dictionary
	if id == CONTEXT_SHOOT:
		result = game.set_ranged_order(viewing_player, archer_id, _context_menu_cell, _context_menu_piece)
	elif id == CONTEXT_JOIN_VOLLEY:
		result = game.set_volley_support_order(viewing_player, archer_id, _context_menu_cell)
	else:
		result = game.set_suppress_order(viewing_player, archer_id, _context_menu_cell)
	if bool(result.get("ok", false)) and before != _current_order_snapshot():
		_record_order_undo(before)
	order_changed.emit("Order updated." if bool(result.get("ok", false)) else String(result.get("message", "Invalid order.")))
	_emit_selected_description()
	queue_redraw()


## True when a click on an occupied friendly square should extend the current
## order rather than select the formation standing there. The engine allows a
## formation to step into a square a friendly one is vacating, so refusing to
## issue the order at all would be more restrictive than the rules.
func _click_continues_order(clicked: Vector2i) -> bool:
	if not interaction_enabled or selected_piece_ids.is_empty() or selected_piece_id == StrategoGame.EMPTY:
		return false
	for piece_id in selected_piece_ids:
		if game.pieces[piece_id].position == clicked: return false
	var anchor_id := _command_anchor_id()
	if anchor_id == StrategoGame.EMPTY: return false
	var projected: Vector2i = game.pieces[anchor_id].position if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING else game.projected_main_destination(anchor_id)
	if not StrategoGame.are_adjacent(projected, clicked): return false
	# A friendly formation standing there with no plans to move can never
	# actually vacate the square, so treating the click as "continue my order
	# into it" would just fail the collision check every time - silently, as
	# far as a player watching the board can tell, since nothing on the board
	# visibly changes. That made it impossible to select a neighboring ally by
	# clicking it at all. Only keep the continue-the-order reading when that
	# ally is actually moving away this round.
	var occupant := game.piece_at(clicked)
	if not occupant.is_empty() and int(occupant.player) == viewing_player:
		var occupant_id := int(occupant.id)
		var occupant_projected: Vector2i = game.pieces[occupant_id].position if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING else game.projected_main_destination(occupant_id)
		if occupant_projected == clicked: return false
	return true


## Click a formation of your own to select it, click a legal cell in your own
## zone to send the selected formation there. Reuses selected_piece_id rather
## than a parallel var, so the ordinary selection ring already draws for free.
func _handle_deployment_click(screen_position: Vector2) -> void:
	var clicked := _cell_at_screen(screen_position)
	if clicked.x < 0: return
	var occupant := game.piece_at(clicked)
	if not occupant.is_empty() and int(occupant.player) == viewing_player:
		selected_piece_id = int(occupant.id)
		selected_piece_ids.assign([selected_piece_id])
		_emit_selected_description()
		queue_redraw()
		return
	if selected_piece_id == StrategoGame.EMPTY:
		return
	var result := game.redeploy_piece(viewing_player, selected_piece_id, clicked)
	order_changed.emit("Formation redeployed." if bool(result.get("ok", false)) else String(result.get("message", "Invalid placement.")))
	_emit_selected_description()
	queue_redraw()


func _handle_left_click(screen_position: Vector2, additive: bool, force_select: bool = false) -> void:
	var clicked := _cell_at_screen(screen_position)
	if clicked.x < 0: return
	var clicked_piece := game.piece_at(clicked)
	var selects_clicked_piece := not clicked_piece.is_empty() and int(clicked_piece.player) == viewing_player and game.is_movable(clicked_piece)
	# A shift/ctrl-click always means "add this to my group," never "continue my
	# order into the square it stands on" - otherwise selecting a second unit
	# fails silently the moment it happens to be adjacent to the first, which in
	# a battle line is most of the time.
	if selects_clicked_piece and not additive and not force_select and _click_continues_order(clicked):
		selects_clicked_piece = false
	if selects_clicked_piece:
		var clicked_id := int(clicked_piece.id)
		if additive:
			if clicked_id in selected_piece_ids:
				selected_piece_ids.erase(clicked_id)
			else:
				selected_piece_ids.append(clicked_id)
			selected_piece_id = clicked_id if clicked_id in selected_piece_ids else (selected_piece_ids.back() if not selected_piece_ids.is_empty() else StrategoGame.EMPTY)
			_emit_selected_description()
		elif clicked_id in selected_piece_ids:
			# A plain click on a piece that is already the (sole) selection
			# toggles it off, rather than sitting there doing nothing.
			clear_selection()
		else:
			selected_piece_ids.assign([clicked_id])
			selected_piece_id = clicked_id
			_emit_selected_description()
		return
	_issue_order_to_square(clicked, clicked_piece)


## Everything past "a square, not a piece of mine, was clicked": issue the
## current selection's order toward it. Shared by the left-click flow and the
## right-click shortcut, so the two stay identical rather than drifting.
##
## silent_on_failure drops the error toast on a failed attempt: the right-click
## shortcut falls back to the context menu when there is nothing to order, and
## flashing "Invalid order" right before that menu opens would read as if
## something had gone wrong rather than as the ordinary Inspect/Attack path.
func _issue_order_to_square(clicked: Vector2i, clicked_piece: Dictionary, silent_on_failure: bool = false) -> Dictionary:
	if selected_piece_ids.is_empty() or selected_piece_id == StrategoGame.EMPTY:
		clear_selection()
		return {"ok": false, "message": "No formation selected."}
	var selected_piece: Dictionary = game.pieces[selected_piece_id]
	var anchor_id := _command_anchor_id()
	var projected_id := anchor_id if anchor_id != StrategoGame.EMPTY else selected_piece_id
	var projected: Vector2i = game.pieces[projected_id].position if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING else game.projected_main_destination(projected_id)
	var before := _current_order_snapshot()
	var result: Dictionary
	if selected_piece_ids.size() > 1:
		var direction := HexGrid.direction_between(projected, clicked)
		if leftover_mode:
			result = game.set_group_leftover_step(viewing_player, selected_piece_ids, direction)
		elif prefer_ranged and selected_piece.role == StrategoGame.ROLE_ARCHER and not clicked_piece.is_empty():
			result = {"ok": false, "message": "Ranged orders are issued to one Archer at a time."}
		else:
			result = game.append_group_order_step(viewing_player, selected_piece_ids, direction, false)
	elif leftover_mode and prefer_ranged and selected_piece.role == StrategoGame.ROLE_ARCHER and not clicked_piece.is_empty() and game.is_piece_visible_to(clicked_piece, viewing_player) and not game.are_allied_players(viewing_player, int(clicked_piece.player)) and game.ranged_order_is_available(viewing_player, selected_piece_id, clicked, int(clicked_piece.id)):
		# Clicking a formation is aimed fire; suppressing a square is the
		# right-click menu's job.
		result = game.set_ranged_order(viewing_player, selected_piece_id, clicked, int(clicked_piece.id))
	elif leftover_mode:
		result = game.set_leftover_order(viewing_player, selected_piece_id, clicked)
	else:
		result = game.append_order_step(viewing_player, selected_piece_id, clicked, false)
	var ok := bool(result.get("ok", false))
	if ok and before != _current_order_snapshot():
		_record_order_undo(before)
	if ok or not silent_on_failure:
		order_changed.emit("Order updated." if ok else String(result.get("message", "Invalid order.")))
	if ok: _emit_selected_description()
	return result


func _emit_selected_description() -> void:
	if selected_piece_ids.is_empty() or selected_piece_id == StrategoGame.EMPTY:
		selection_changed.emit("Click a formation, then click a highlighted hex to place it." if game != null and game.phase == StrategoGame.PHASE_DEPLOYMENT else "No formations selected.")
		return
	if game.phase == StrategoGame.PHASE_DEPLOYMENT:
		selection_changed.emit("%s · click a highlighted hex to move it there." % game.piece_description(game.pieces[selected_piece_id]))
		return
	if selected_piece_ids.size() > 1:
		var ordered := 0
		for piece_id in selected_piece_ids:
			var order := game.order_for_piece(piece_id)
			if ((order.get("leftover", Vector2i(-1, -1)).x >= 0 or order.get("ranged_target", Vector2i(-1, -1)).x >= 0) if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING else not order.is_empty()):
				ordered += 1
		selection_changed.emit("%d formations selected · %d %s ordered · click a highlighted direction or use arrow keys to move all." % [selected_piece_ids.size(), ordered, "leftover" if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING else "main"])
		return
	var piece: Dictionary = game.pieces[selected_piece_id]
	var order := game.order_for_piece(selected_piece_id)
	var path: Array = order.get("path", [])
	var text := "%s · %d/%d main impulses planned" % [game.piece_description(piece), path.size(), game.movement_limit_for(piece)]
	if game.phase == StrategoGame.PHASE_LEFTOVER_PLANNING:
		text = "%s · choose one post-clash action" % game.piece_description(piece)
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
	var direction := -1
	match event.keycode:
		KEY_W, KEY_UP: direction = HexGrid.NORTH
		KEY_E: direction = HexGrid.NORTH_EAST
		KEY_D, KEY_RIGHT: direction = HexGrid.SOUTH_EAST
		KEY_X, KEY_S, KEY_DOWN: direction = HexGrid.SOUTH
		KEY_Z: direction = HexGrid.SOUTH_WEST
		KEY_Q, KEY_A, KEY_LEFT: direction = HexGrid.NORTH_WEST
	if direction >= 0 and not selected_piece_ids.is_empty():
		issue_selected_direction(direction)
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		clear_selection()
