class_name HexGrid
extends RefCounted

## Flat-top hexes stored as odd-column offset coordinates (column, row).
## Odd-numbered columns are shifted half a hex down. This orientation gives
## the campaign's north/south axis a true straight movement direction.

const NORTH := 0
const NORTH_EAST := 1
const SOUTH_EAST := 2
const SOUTH := 3
const SOUTH_WEST := 4
const NORTH_WEST := 5
const DIRECTION_COUNT := 6
const SQRT_3 := 1.7320508075688772

const AXIAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0),
]


static func offset_to_axial(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x, cell.y - (cell.x - (cell.x & 1)) / 2)


static func axial_to_offset(axial: Vector2i) -> Vector2i:
	return Vector2i(axial.x, axial.y + (axial.x - (axial.x & 1)) / 2)


static func neighbor(origin: Vector2i, direction: int) -> Vector2i:
	if direction < 0 or direction >= DIRECTION_COUNT:
		return origin
	return axial_to_offset(offset_to_axial(origin) + AXIAL_DIRECTIONS[direction])


static func neighbors(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in DIRECTION_COUNT:
		result.append(neighbor(origin, direction))
	return result


static func direction_between(origin: Vector2i, adjacent: Vector2i) -> int:
	for direction in DIRECTION_COUNT:
		if neighbor(origin, direction) == adjacent:
			return direction
	return -1


static func distance(first: Vector2i, second: Vector2i) -> int:
	var a := offset_to_axial(first)
	var b := offset_to_axial(second)
	var dq := a.x - b.x
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2


static func cells_within_range(origin: Vector2i, reach: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var center := offset_to_axial(origin)
	for dq in range(-reach, reach + 1):
		var dr_min := maxi(-reach, -dq - reach)
		var dr_max := mini(reach, -dq + reach)
		for dr in range(dr_min, dr_max + 1):
			result.append(axial_to_offset(center + Vector2i(dq, dr)))
	return result


## `cell_size` is the point-to-point vertical height of one flat-top hex.
static func radius_for_size(cell_size: float) -> float:
	return cell_size / SQRT_3


static func board_pixel_size(cell_size: float, columns: int, rows: int) -> Vector2:
	var radius := radius_for_size(cell_size)
	var width := radius * 2.0 + float(maxi(0, columns - 1)) * radius * 1.5
	var height := float(rows) * cell_size
	if columns > 1:
		height += cell_size * 0.5
	return Vector2(width, height)


static func cell_center(cell: Vector2i, origin: Vector2, cell_size: float) -> Vector2:
	var radius := radius_for_size(cell_size)
	return origin + Vector2(
		radius + float(cell.x) * radius * 1.5,
		(float(cell.y) + 0.5 + 0.5 * float(cell.x & 1)) * cell_size,
	)


static func polygon(cell: Vector2i, origin: Vector2, cell_size: float, inset: float = 0.0) -> PackedVector2Array:
	var center := cell_center(cell, origin, cell_size)
	var radius := maxf(0.0, radius_for_size(cell_size) - inset)
	var points := PackedVector2Array()
	for index in 6:
		var angle := TAU * float(index) / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func pixel_to_cell(point: Vector2, origin: Vector2, cell_size: float) -> Vector2i:
	var radius := radius_for_size(cell_size)
	var local := point - origin - Vector2(radius, cell_size * 0.5)
	var fractional_q := (2.0 / 3.0 * local.x) / radius
	var fractional_r := (-local.x / 3.0 + SQRT_3 / 3.0 * local.y) / radius
	return axial_to_offset(_round_axial(fractional_q, fractional_r))


static func direction_screen_vector(direction: int) -> Vector2:
	if direction < 0 or direction >= DIRECTION_COUNT:
		return Vector2.ZERO
	var axial := AXIAL_DIRECTIONS[direction]
	return Vector2(1.5 * float(axial.x), SQRT_3 * (float(axial.y) + float(axial.x) * 0.5)).normalized()


static func direction_progress(cell: Vector2i, direction: int) -> float:
	var center := cell_center(cell, Vector2.ZERO, 1.0)
	return center.dot(direction_screen_vector(direction))


static func _round_axial(q: float, r: float) -> Vector2i:
	var x := q
	var z := r
	var y := -x - z
	var rounded_x := roundi(x)
	var rounded_y := roundi(y)
	var rounded_z := roundi(z)
	var x_diff := absf(float(rounded_x) - x)
	var y_diff := absf(float(rounded_y) - y)
	var z_diff := absf(float(rounded_z) - z)
	if x_diff > y_diff and x_diff > z_diff:
		rounded_x = -rounded_y - rounded_z
	elif y_diff > z_diff:
		rounded_y = -rounded_x - rounded_z
	else:
		rounded_z = -rounded_x - rounded_y
	return Vector2i(rounded_x, rounded_z)
