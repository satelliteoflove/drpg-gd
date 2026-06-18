@tool
class_name ArcaneFrame extends Control

## Draws engraved arcane corner brackets (with gem accents) that frame a screen
## like an illuminated manuscript. Pure vector drawing - sharp at any size.

@export var color: Color = Color(0.87, 0.74, 0.47, 0.85):
	set(v): color = v; queue_redraw()
@export var inset: float = 16.0:
	set(v): inset = v; queue_redraw()
@export var corner_length: float = 38.0:
	set(v): corner_length = v; queue_redraw()
@export var line_width: float = 2.0:
	set(v): line_width = v; queue_redraw()
@export var gem_size: float = 5.0:
	set(v): gem_size = v; queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var r := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	if r.size.x <= 0 or r.size.y <= 0:
		return
	_corner(r.position, Vector2(1, 1))
	_corner(Vector2(r.end.x, r.position.y), Vector2(-1, 1))
	_corner(Vector2(r.position.x, r.end.y), Vector2(1, -1))
	_corner(r.end, Vector2(-1, -1))


func _corner(p: Vector2, dir: Vector2) -> void:
	var cl := corner_length
	draw_line(p, p + Vector2(dir.x * cl, 0), color, line_width, true)
	draw_line(p, p + Vector2(0, dir.y * cl), color, line_width, true)

	# Inner accent rule (shorter, fainter) for a double-engraved feel
	var faint := Color(color.r, color.g, color.b, color.a * 0.55)
	var p2 := p + Vector2(dir.x * 7.0, dir.y * 7.0)
	draw_line(p2, p2 + Vector2(dir.x * cl * 0.55, 0), faint, line_width * 0.6, true)
	draw_line(p2, p2 + Vector2(0, dir.y * cl * 0.55), faint, line_width * 0.6, true)

	# Gem at the corner vertex
	_diamond(p + Vector2(dir.x * 3.0, dir.y * 3.0), gem_size)


func _diamond(c: Vector2, s: float) -> void:
	var pts := PackedVector2Array([
		c + Vector2(0, -s), c + Vector2(s, 0),
		c + Vector2(0, s), c + Vector2(-s, 0),
	])
	draw_colored_polygon(pts, color)
