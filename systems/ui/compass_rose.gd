class_name CompassRose extends Control

## A small carved-stone compass for the dungeon HUD. Fixed cardinal letters
## (N top / E right / S bottom / W left) with a two-tone needle that swings to
## the party's facing, so orientation in the grid is readable at a glance.
## Drive it with `set_facing(facing)` (0=N, 1=E, 2=S, 3=W).

const LETTERS := ["N", "E", "S", "W"]

# Screen-space unit vectors for each facing (y points down).
const DIRS := [
	Vector2(0, -1),  # N
	Vector2(1, 0),   # E
	Vector2(0, 1),   # S
	Vector2(-1, 0),  # W
]

var _facing: int = 0


func set_facing(facing: int) -> void:
	facing = ((facing % 4) + 4) % 4
	if facing == _facing:
		return
	_facing = facing
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 1.0

	# Disc + ring (matches the panelled HUD surfaces).
	draw_circle(center, radius, UIColors.SURFACE_PANEL)
	draw_arc(center, radius, 0.0, TAU, 40, UIColors.BORDER_DEFAULT, 2.0, true)
	draw_arc(center, radius * 0.62, 0.0, TAU, 32, UIColors.BORDER_SUBTLE, 1.0, true)

	_draw_needle(center, radius)
	_draw_cardinals(center, radius)


func _draw_needle(center: Vector2, radius: float) -> void:
	var dir: Vector2 = DIRS[_facing]
	var perp := Vector2(-dir.y, dir.x)
	var half := radius * 0.17

	var tip := center + dir * radius * 0.66
	var base_l := center + perp * half
	var base_r := center - perp * half
	var tail := center - dir * radius * 0.46

	# Forward arm = arcane accent (this is "you"); rear arm recedes.
	draw_colored_polygon(PackedVector2Array([tip, base_l, base_r]), UIColors.ACCENT)
	draw_colored_polygon(PackedVector2Array([tail, base_l, base_r]), UIColors.TEXT_MUTED)
	draw_circle(center, half * 0.7, UIColors.TITLE_GOLD_DIM)


func _draw_cardinals(center: Vector2, radius: float) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var ring := radius * 0.82
	for i in range(4):
		var active := i == _facing
		var fsize := 16 if active else 12
		var col: Color = UIColors.TITLE_GOLD if active else UIColors.TEXT_MUTED
		var glyph: String = LETTERS[i]
		var dir2: Vector2 = DIRS[i]
		var dims := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var anchor: Vector2 = center + dir2 * ring
		var pos: Vector2 = anchor - Vector2(dims.x * 0.5, -dims.y * 0.32)
		draw_string(font, pos, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
