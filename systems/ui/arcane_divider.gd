@tool
class_name ArcaneDivider extends Control

## A horizontal rule with a central gem and tapered ends - used under titles and
## between sections for an illuminated-tome feel.

@export var color: Color = Color(0.87, 0.74, 0.47, 0.8):
	set(v): color = v; queue_redraw()
@export var thickness: float = 1.5:
	set(v): thickness = v; queue_redraw()
@export var gem_size: float = 4.5:
	set(v): gem_size = v; queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size.y < 14.0:
		custom_minimum_size.y = 14.0
	resized.connect(queue_redraw)


func _draw() -> void:
	var y := size.y * 0.5
	var cx := size.x * 0.5
	var gap := gem_size + 6.0
	var faint := Color(color.r, color.g, color.b, color.a * 0.25)

	# Lines taper toward the ends by fading alpha via a 2-stop polyline.
	_grad_line(Vector2(2, y), Vector2(cx - gap, y), faint, color)
	_grad_line(Vector2(cx + gap, y), Vector2(size.x - 2, y), color, faint)

	# Center gem with a tiny outline diamond echo
	_diamond(Vector2(cx, y), gem_size, color)
	_diamond_outline(Vector2(cx, y), gem_size + 3.0, faint)


func _grad_line(a: Vector2, b: Vector2, ca: Color, cb: Color) -> void:
	if b.x <= a.x:
		return
	draw_polyline_colors(
		PackedVector2Array([a, b]), PackedColorArray([ca, cb]), thickness, true)


func _diamond(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s), c + Vector2(s, 0),
		c + Vector2(0, s), c + Vector2(-s, 0),
	]), col)


func _diamond_outline(c: Vector2, s: float, col: Color) -> void:
	draw_polyline(PackedVector2Array([
		c + Vector2(0, -s), c + Vector2(s, 0),
		c + Vector2(0, s), c + Vector2(-s, 0), c + Vector2(0, -s),
	]), col, 1.0, true)
