@tool
class_name RuneBadge extends Control

## A small procedurally-drawn arcane emblem (no font/art dependency) used to mark
## town destinations. Each Kind draws a distinct geometric sigil.

enum Kind { TRIANGLE, DIAMOND, PENTAGON, HEXAGON, STAR, CIRCLE, CHEVRON_DOWN, ARCH }

@export var kind: Kind = Kind.DIAMOND:
	set(v): kind = v; queue_redraw()
@export var color: Color = Color(0.88, 0.75, 0.48, 0.95):
	set(v): color = v; queue_redraw()
@export var width: float = 2.0:
	set(v): width = v; queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _faint() -> Color:
	return Color(color.r, color.g, color.b, color.a * 0.35)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 3.0
	if r <= 1.0:
		return
	match kind:
		Kind.TRIANGLE:
			_poly(c, r, 3, -PI / 2.0)
			_gem(c)
		Kind.DIAMOND:
			_poly(c, r, 4, -PI / 2.0)
			_gem(c)
		Kind.PENTAGON:
			_poly(c, r, 5, -PI / 2.0)
			_gem(c)
		Kind.HEXAGON:
			_poly(c, r, 6, -PI / 2.0)
			_gem(c)
		Kind.STAR:
			_star(c, r, 5)
		Kind.CIRCLE:
			draw_arc(c, r, 0.0, TAU, 40, color, width, true)
			draw_arc(c, r * 0.42, 0.0, TAU, 24, _faint(), width * 0.8, true)
		Kind.CHEVRON_DOWN:
			_chevron(c + Vector2(0, -r * 0.45), r)
			_chevron(c + Vector2(0, r * 0.15), r)
		Kind.ARCH:
			_arch(c, r)


func _poly(c: Vector2, r: float, n: int, off: float) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := off + TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	pts.append(pts[0])
	draw_polyline(pts, color, width, true)


func _star(c: Vector2, r: float, n: int) -> void:
	var pts := PackedVector2Array()
	for i in n * 2:
		var rr := r if i % 2 == 0 else r * 0.44
		var a := -PI / 2.0 + PI * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	pts.append(pts[0])
	draw_polyline(pts, color, width, true)


func _chevron(c: Vector2, r: float) -> void:
	draw_polyline(PackedVector2Array([
		c + Vector2(-r * 0.8, -r * 0.3),
		c + Vector2(0, r * 0.4),
		c + Vector2(r * 0.8, -r * 0.3),
	]), color, width + 0.5, true)


func _arch(c: Vector2, r: float) -> void:
	var base := c + Vector2(0, r * 0.55)
	draw_arc(c + Vector2(0, r * 0.05), r * 0.72, PI, TAU, 24, color, width, true)
	draw_line(Vector2(c.x - r * 0.72, c.y + r * 0.05), Vector2(c.x - r * 0.72, base.y), color, width, true)
	draw_line(Vector2(c.x + r * 0.72, c.y + r * 0.05), Vector2(c.x + r * 0.72, base.y), color, width, true)
	draw_line(Vector2(c.x - r * 0.72, base.y), Vector2(c.x + r * 0.72, base.y), color, width, true)


func _gem(c: Vector2) -> void:
	draw_circle(c, 2.0, color)
