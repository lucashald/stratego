class_name StrategoBoardView
extends Control

signal move_requested(from: Vector2i, to: Vector2i)
signal selection_changed(description: String)

const LIGHT_SQUARE := Color("#d8c69d")
const DARK_SQUARE := Color("#b8a477")
const LAKE_COLOR := Color("#2d7896")
const BLUE_COLOR := Color("#2764c8")
const BLUE_EDGE := Color("#78a7ff")
const RED_COLOR := Color("#ba3c45")
const RED_EDGE := Color("#ff8990")
const GREEN_COLOR := Color("#287a55")
const GREEN_EDGE := Color("#72e3a7")
const YELLOW_COLOR := Color("#b78a19")
const YELLOW_EDGE := Color("#ffe27a")
const FOG_COLOR := Color(0.025, 0.045, 0.075, 0.72)

var game: StrategoGame
var viewing_player := StrategoGame.BLUE
var reveal_all := false
var interaction_enabled := true
var selected := Vector2i(-1, -1)
var destinations: Array[Vector2i] = []
var combat_event: Dictionary = {}
var combat_started_msec := 0
var combat_duration_msec := 1800


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
	selected = Vector2i(-1, -1)
	destinations.clear()
	selection_changed.emit("Select one of your movable pieces.")
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
			if game.is_lake(position):
				square_color = LAKE_COLOR
			draw_rect(rect, square_color, true)
			draw_rect(rect, Color(0.07, 0.09, 0.12, 0.22), false, 1.0)
			if not reveal_all and not game.game_over and not game.is_position_visible_to(position, viewing_player):
				draw_rect(rect, FOG_COLOR, true)
				draw_rect(rect, Color(0.14, 0.2, 0.3, 0.28), false, 1.0)

	var can_see_last_move: bool = reveal_all or game.game_over or viewing_player in game.last_move.get("visible_to", [])
	if game.last_move.from.x >= 0 and can_see_last_move:
		for position: Vector2i in [game.last_move.from, game.last_move.to]:
			var rect := Rect2(origin + Vector2(position.x, position.y) * cell, Vector2(cell, cell))
			draw_rect(rect.grow(-3.0), Color("#f4d35e"), false, 3.0)

	if selected.x >= 0:
		var selected_rect := Rect2(origin + Vector2(selected.x, selected.y) * cell, Vector2(cell, cell))
		draw_rect(selected_rect.grow(-2.0), Color("#fff2a8"), false, 4.0)
	for destination in destinations:
		var center := origin + (Vector2(destination.x, destination.y) + Vector2(0.5, 0.5)) * cell
		draw_circle(center, cell * 0.11, Color(0.98, 0.92, 0.42, 0.9))

	for piece: Dictionary in game.pieces:
		if not piece.alive:
			continue
		if not reveal_all and not game.game_over and not game.is_piece_visible_to(piece, viewing_player):
			continue
		_draw_piece(piece, origin, cell)

	if not combat_event.is_empty():
		_draw_combat_overlay(origin, cell, geometry.side)
	elif game.game_over:
		_draw_game_over_overlay(origin, cell, geometry.side)


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


func _draw_combat_overlay(origin: Vector2, cell: float, side: float) -> void:
	var elapsed := float(Time.get_ticks_msec() - combat_started_msec)
	var fade := clampf((float(combat_duration_msec) - elapsed) / 350.0, 0.0, 1.0)
	var destination: Vector2i = combat_event.to
	var marker_center := origin + (Vector2(destination.x, destination.y) + Vector2(0.5, 0.5)) * cell
	var result: String = combat_event.result
	var marker_color := Color("#ff5d68") if result == "defender" else Color("#f8df72")
	marker_color.a = fade
	draw_circle(marker_center, cell * 0.34, Color(marker_color, 0.18 * fade))
	draw_arc(marker_center, cell * 0.34, 0.0, TAU, 40, marker_color, maxf(3.0, cell * 0.055))
	var cross_size := cell * 0.18
	draw_line(marker_center - Vector2(cross_size, cross_size), marker_center + Vector2(cross_size, cross_size), marker_color, maxf(3.0, cell * 0.07))
	draw_line(marker_center + Vector2(cross_size, -cross_size), marker_center + Vector2(-cross_size, cross_size), marker_color, maxf(3.0, cell * 0.07))


func _draw_game_over_overlay(origin: Vector2, cell: float, side: float) -> void:
	draw_rect(Rect2(origin, Vector2(side, side)), Color(0.015, 0.025, 0.04, 0.74), true)
	var card := Rect2(origin.x + side * 0.14, origin.y + side * 0.5 - cell * 1.05, side * 0.72, cell * 2.1)
	draw_rect(card, Color("#101a2b"), true)
	draw_rect(card, Color("#f8df9a"), false, maxf(2.0, cell * 0.045))
	var title := "DRAW" if game.winner == StrategoGame.DRAW else "%s WINS" % game.player_name(game.winner).to_upper()
	var reason := ""
	match game.end_reason:
		"flag_captured":
			reason = "%s'S FLAG WAS CAPTURED" % game.player_name(game.last_eliminated_player).to_upper()
		"no_legal_moves":
			reason = "%s HAS NO LEGAL MOVES" % game.player_name(game.last_eliminated_player).to_upper()
		"last_player_standing":
			reason = "LAST ARMY STANDING"
		"no_combat_limit":
			reason = "%d MOVES WITHOUT COMBAT" % game.max_quiet_plies
		"move_limit":
			reason = "%d-MOVE LIMIT REACHED" % game.max_plies
		_:
			reason = "GAME OVER"
	var font := ThemeDB.fallback_font
	_draw_centered_text(font, title, Rect2(card.position + Vector2(0, cell * 0.28), Vector2(card.size.x, cell * 0.58)), int(cell * 0.43), Color("#f8df9a"))
	_draw_centered_text(font, reason, Rect2(card.position + Vector2(0, cell * 1.18), Vector2(card.size.x, cell * 0.42)), int(cell * 0.22), Color.WHITE)


func _draw_centered_text(font: Font, text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var position := rect.position + Vector2((rect.size.x - text_size.x) * 0.5, (rect.size.y - text_size.y) * 0.5 + text_size.y * 0.78)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_piece(piece: Dictionary, origin: Vector2, cell: float) -> void:
	var position: Vector2i = piece.position
	var rect := Rect2(origin + Vector2(position.x, position.y) * cell, Vector2(cell, cell)).grow(-cell * 0.12)
	var colors := _player_colors(int(piece.player))
	var fill: Color = colors.fill
	var edge: Color = colors.edge
	draw_rect(rect, Color(0, 0, 0, 0.25), true)
	var face := rect.grow(-2.0)
	draw_rect(face, fill, true)
	draw_rect(face, edge, false, maxf(2.0, cell * 0.035))

	var can_see_rank: bool = reveal_all or game.game_over or game.is_piece_revealed_to(piece, viewing_player)
	var text: String = piece.type if can_see_rank else "?"
	var font := ThemeDB.fallback_font
	var font_size := int(cell * 0.34)
	if text == "10":
		font_size = int(cell * 0.28)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_position := face.position + (face.size - text_size) * 0.5 + Vector2(0, text_size.y * 0.78)
	draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _player_colors(player: int) -> Dictionary:
	match player:
		StrategoGame.BLUE:
			return {"fill": BLUE_COLOR, "edge": BLUE_EDGE}
		StrategoGame.RED:
			return {"fill": RED_COLOR, "edge": RED_EDGE}
		StrategoGame.GREEN:
			return {"fill": GREEN_COLOR, "edge": GREEN_EDGE}
		StrategoGame.YELLOW:
			return {"fill": YELLOW_COLOR, "edge": YELLOW_EDGE}
	return {"fill": Color.GRAY, "edge": Color.WHITE}


func _gui_input(event: InputEvent) -> void:
	if not interaction_enabled or game == null or game.game_over:
		return
	if event is not InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var geometry := _board_geometry()
	var local: Vector2 = event.position - geometry.origin
	if local.x < 0 or local.y < 0 or local.x >= geometry.side or local.y >= geometry.side:
		return
	var clicked := Vector2i(int(local.x / geometry.cell), int(local.y / geometry.cell))
	if clicked in destinations:
		var from := selected
		clear_selection()
		move_requested.emit(from, clicked)
		accept_event()
		return

	var piece := game.piece_at(clicked)
	if not piece.is_empty() and piece.player == viewing_player and piece.player == game.current_player and game.is_movable(piece):
		selected = clicked
		destinations.clear()
		for move: Dictionary in game.get_moves_for(clicked):
			destinations.append(move.to)
		selection_changed.emit("%s (%s) — %d legal move%s" % [
			StrategoGame.PIECE_NAMES[piece.type], piece.type, destinations.size(), "" if destinations.size() == 1 else "s"
		])
		queue_redraw()
	else:
		clear_selection()
	accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		clear_selection()
