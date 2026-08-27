class_name StrategoBoardView
extends Control

signal order_changed(message: String)
signal selection_changed(description: String)

const LIGHT_SQUARE := Color("#d8c69d")
const DARK_SQUARE := Color("#b8a477")
const WATER_COLOR := Color("#277993")
const BRIDGE_COLOR := Color("#9b7c51")
const BLUE_COLOR := Color("#2764c8")
const BLUE_EDGE := Color("#78a7ff")
const RED_COLOR := Color("#ba3c45")
const RED_EDGE := Color("#ff8990")
const GREEN_COLOR := Color("#287a55")
const GREEN_EDGE := Color("#72e3a7")
const YELLOW_COLOR := Color("#b78a19")
const YELLOW_EDGE := Color("#ffe27a")
const FOG_COLOR := Color(0.025, 0.045, 0.075, 0.72)
const IMPULSE_COLORS := [Color("#57d3ff"), Color("#a58bff"), Color("#ff8bc6")]
const LEFTOVER_COLOR := Color("#ffb454")

var game: StrategoGame
var viewing_player := StrategoGame.BLUE
var reveal_all := false
var interaction_enabled := true
var prefer_ranged := true
var leftover_mode := false
var selected_piece_id := StrategoGame.EMPTY
var combat_event: Dictionary = {}
var combat_started_msec := 0
var combat_duration_msec := 1600


func _ready() -> void:
	custom_minimum_size = Vector2(690, 690)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_process_unhandled_key_input(true)
	set_process(true)


func set_game(value: StrategoGame) -> void:
	game = value
	combat_event.clear()
	clear_selection()
	queue_redraw()


func clear_selection() -> void:
	selected_piece_id = StrategoGame.EMPTY
	selection_changed.emit("Select a formation, then click adjacent squares to draw its impulse path.")
	queue_redraw()


func _board_geometry() -> Dictionary:
	var side := minf(size.x, size.y) - 12.0
	var origin := (size - Vector2(side, side)) * 0.5
	return {"origin": origin, "side": side, "cell": side / float(StrategoGame.BOARD_SIZE)}


func _draw() -> void:
	if game == null:
		return
	var geometry := _board_geometry()
	var origin: Vector2 = geometry.origin
	var cell: float = geometry.cell
	draw_rect(Rect2(origin - Vector2(5, 5), Vector2(geometry.side + 10, geometry.side + 10)), Color("#111827"), true)
	for y in StrategoGame.BOARD_SIZE:
		for x in StrategoGame.BOARD_SIZE:
			var position := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))
			var square_color := LIGHT_SQUARE if (x + y) % 2 == 0 else DARK_SQUARE
			if game.is_lake(position) or game.is_water(position):
				square_color = WATER_COLOR
			elif game.is_bridge(position):
				square_color = BRIDGE_COLOR
			draw_rect(rect, square_color, true)
			draw_rect(rect, Color(0.07, 0.09, 0.12, 0.22), false, 1.0)
			if not reveal_all and not game.game_over and not game.is_position_visible_to(position, viewing_player):
				draw_rect(rect, FOG_COLOR, true)
				draw_rect(rect, Color(0.14, 0.2, 0.3, 0.28), false, 1.0)

	_draw_order_ghosts(origin, cell)
	_draw_selection(origin, cell)
	for piece: Dictionary in game.pieces:
		if not piece.alive:
			continue
		if not reveal_all and not game.game_over and not game.is_piece_visible_to(piece, viewing_player):
			continue
		_draw_piece(piece, origin, cell)
	if not combat_event.is_empty():
		_draw_combat_overlay(origin, cell)
	elif game.game_over:
		_draw_game_over_overlay(origin, cell, geometry.side)


func _draw_order_ghosts(origin: Vector2, cell: float) -> void:
	var players: Array = game.active_players if reveal_all else [viewing_player]
	var font := ThemeDB.fallback_font
	for player in players:
		for order: Dictionary in game.orders_for_player(player):
			var piece_id := int(order.piece_id)
			if piece_id < 0 or piece_id >= game.pieces.size() or not game.pieces[piece_id].alive:
				continue
			var previous: Vector2i = game.pieces[piece_id].position
			var path: Array = order.get("path", [])
			for index in path.size():
				var position: Vector2i = path[index]
				var color: Color = IMPULSE_COLORS[mini(index, IMPULSE_COLORS.size() - 1)]
				var previous_center := origin + (Vector2(previous) + Vector2(0.5, 0.5)) * cell
				var center := origin + (Vector2(position) + Vector2(0.5, 0.5)) * cell
				draw_line(previous_center, center, Color(color, 0.82), maxf(2.0, cell * 0.075))
				draw_circle(center, cell * 0.27, Color(color, 0.30))
				draw_arc(center, cell * 0.27, 0.0, TAU, 28, color, maxf(2.0, cell * 0.05))
				_draw_centered_text(font, str(index + 1), Rect2(center - Vector2(cell * 0.25, cell * 0.25), Vector2(cell * 0.5, cell * 0.5)), int(cell * 0.24), Color.WHITE)
				previous = position
			var ranged_target: Vector2i = order.get("ranged_target", Vector2i(-1, -1))
			if ranged_target.x >= 0:
				var ranged_center := origin + (Vector2(ranged_target) + Vector2(0.5, 0.5)) * cell
				draw_arc(ranged_center, cell * 0.32, 0.0, TAU, 32, Color("#55e5ff"), maxf(2.0, cell * 0.06))
			var leftover: Vector2i = order.get("leftover", Vector2i(-1, -1))
			if leftover.x >= 0:
				var leftover_center := origin + (Vector2(leftover) + Vector2(0.5, 0.5)) * cell
				draw_rect(Rect2(leftover_center - Vector2(cell * 0.24, cell * 0.24), Vector2(cell * 0.48, cell * 0.48)), Color(LEFTOVER_COLOR, 0.30), true)
				draw_rect(Rect2(leftover_center - Vector2(cell * 0.24, cell * 0.24), Vector2(cell * 0.48, cell * 0.48)), LEFTOVER_COLOR, false, maxf(2.0, cell * 0.05))


func _draw_selection(origin: Vector2, cell: float) -> void:
	if selected_piece_id == StrategoGame.EMPTY or selected_piece_id >= game.pieces.size():
		return
	var piece: Dictionary = game.pieces[selected_piece_id]
	if not piece.alive:
		return
	var selected_rect := Rect2(origin + Vector2(piece.position) * cell, Vector2(cell, cell))
	draw_rect(selected_rect.grow(-2.0), Color("#fff2a8"), false, 4.0)
	var projected := game.projected_main_destination(selected_piece_id)
	var order := game.order_for_piece(selected_piece_id)
	var spent: int = order.get("path", []).size()
	if order.get("ranged_target", Vector2i(-1, -1)).x >= 0:
		spent += 1
	if order.get("leftover", Vector2i(-1, -1)).x >= 0:
		spent += 1
	if spent >= game.movement_limit_for(piece):
		return
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var destination: Vector2i = projected + direction
		if game.is_inside(destination) and not game.is_blocked_terrain(destination):
			var center := origin + (Vector2(destination) + Vector2(0.5, 0.5)) * cell
			draw_circle(center, cell * 0.09, LEFTOVER_COLOR if leftover_mode else Color("#fff2a8"))


func _process(_delta: float) -> void:
	if combat_event.is_empty():
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
	var fade := clampf((float(combat_duration_msec) - elapsed) / 350.0, 0.0, 1.0)
	var destination: Vector2i = combat_event.get("to", Vector2i(-1, -1))
	if destination.x < 0:
		return
	var center := origin + (Vector2(destination) + Vector2(0.5, 0.5)) * cell
	var marker_color := Color("#f8df72") if combat_event.get("result", "") != "bounce" else Color("#c7a7ff")
	marker_color.a = fade
	draw_circle(center, cell * 0.35, Color(marker_color, 0.18 * fade))
	draw_arc(center, cell * 0.35, 0.0, TAU, 40, marker_color, maxf(3.0, cell * 0.055))


func _draw_game_over_overlay(origin: Vector2, cell: float, side: float) -> void:
	draw_rect(Rect2(origin, Vector2(side, side)), Color(0.015, 0.025, 0.04, 0.74), true)
	var card := Rect2(origin.x + side * 0.14, origin.y + side * 0.5 - cell * 1.05, side * 0.72, cell * 2.1)
	draw_rect(card, Color("#101a2b"), true)
	draw_rect(card, Color("#f8df9a"), false, maxf(2.0, cell * 0.045))
	var title := "DRAW" if game.winner == StrategoGame.DRAW else "%s WINS" % game.player_name(game.winner).to_upper()
	var reason := game.end_reason.replace("_", " ").to_upper()
	var font := ThemeDB.fallback_font
	_draw_centered_text(font, title, Rect2(card.position + Vector2(0, cell * 0.28), Vector2(card.size.x, cell * 0.58)), int(cell * 0.43), Color("#f8df9a"))
	_draw_centered_text(font, reason, Rect2(card.position + Vector2(0, cell * 1.18), Vector2(card.size.x, cell * 0.42)), int(cell * 0.22), Color.WHITE)


func _draw_centered_text(font: Font, text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var position := rect.position + Vector2((rect.size.x - text_size.x) * 0.5, (rect.size.y - text_size.y) * 0.5 + text_size.y * 0.78)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_piece(piece: Dictionary, origin: Vector2, cell: float) -> void:
	var position: Vector2i = piece.position
	var rect := Rect2(origin + Vector2(position) * cell, Vector2(cell, cell)).grow(-cell * 0.12)
	var colors := _player_colors(int(piece.player))
	draw_rect(rect, Color(0, 0, 0, 0.25), true)
	var face := rect.grow(-2.0)
	draw_rect(face, colors.fill, true)
	draw_rect(face, colors.edge, false, maxf(2.0, cell * 0.035))
	var can_see_identity := reveal_all or game.game_over or game.is_piece_revealed_to(piece, viewing_player)
	var text := game.piece_display_code(piece) if can_see_identity else "?"
	var font := ThemeDB.fallback_font
	var font_size := int(cell * (0.21 if text.length() >= 3 else 0.34))
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_position := face.position + (face.size - text_size) * 0.5 + Vector2(0, text_size.y * 0.78)
	draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _player_colors(player: int) -> Dictionary:
	match player:
		StrategoGame.BLUE: return {"fill": BLUE_COLOR, "edge": BLUE_EDGE}
		StrategoGame.RED: return {"fill": RED_COLOR, "edge": RED_EDGE}
		StrategoGame.GREEN: return {"fill": GREEN_COLOR, "edge": GREEN_EDGE}
		StrategoGame.YELLOW: return {"fill": YELLOW_COLOR, "edge": YELLOW_EDGE}
	return {"fill": Color.GRAY, "edge": Color.WHITE}


func _gui_input(event: InputEvent) -> void:
	if not interaction_enabled or game == null or game.game_over or game.phase != StrategoGame.PHASE_PLANNING:
		return
	if event is not InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if selected_piece_id != StrategoGame.EMPTY:
			var result := game.pop_order_step(viewing_player, selected_piece_id)
			order_changed.emit(result.get("message", "Removed the last impulse."))
			queue_redraw()
		accept_event()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var geometry := _board_geometry()
	var local: Vector2 = event.position - geometry.origin
	if local.x < 0 or local.y < 0 or local.x >= geometry.side or local.y >= geometry.side:
		return
	var clicked := Vector2i(int(local.x / geometry.cell), int(local.y / geometry.cell))
	var clicked_piece := game.piece_at(clicked)
	if not clicked_piece.is_empty() and int(clicked_piece.player) == viewing_player and game.is_movable(clicked_piece):
		selected_piece_id = int(clicked_piece.id)
		_emit_selected_description()
		queue_redraw()
		accept_event()
		return
	if selected_piece_id == StrategoGame.EMPTY:
		clear_selection()
		return
	var selected_piece: Dictionary = game.pieces[selected_piece_id]
	var projected := game.projected_main_destination(selected_piece_id)
	var result: Dictionary
	if leftover_mode:
		result = game.set_leftover_order(viewing_player, selected_piece_id, clicked)
	elif prefer_ranged and selected_piece.role == StrategoGame.ROLE_ARCHER and not clicked_piece.is_empty() and not game.are_allied_players(viewing_player, int(clicked_piece.player)) and projected.distance_to(clicked) == 1.0:
		result = game.set_ranged_order(viewing_player, selected_piece_id, clicked)
	else:
		result = game.append_order_step(viewing_player, selected_piece_id, clicked)
	order_changed.emit("Order updated." if bool(result.get("ok", false)) else String(result.get("message", "Invalid order.")))
	_emit_selected_description()
	queue_redraw()
	accept_event()


func _emit_selected_description() -> void:
	if selected_piece_id == StrategoGame.EMPTY:
		return
	var piece: Dictionary = game.pieces[selected_piece_id]
	var order := game.order_for_piece(selected_piece_id)
	var path: Array = order.get("path", [])
	var text := "%s · %d/%d main impulses planned" % [game.piece_description(piece), path.size(), game.movement_limit_for(piece)]
	if order.get("ranged_target", Vector2i(-1, -1)).x >= 0:
		text += " · ranged shot set"
	if order.get("leftover", Vector2i(-1, -1)).x >= 0:
		text += " · leftover move set"
	selection_changed.emit(text)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		clear_selection()
