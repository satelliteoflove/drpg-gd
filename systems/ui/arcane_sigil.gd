class_name ArcaneSigil extends Control

## A glowing, slowly-rotating arcane glyph used as the heart of scene
## transitions. Drawn procedurally; inner rings counter-rotate for a
## clockwork-mystical feel.

@export var color: Color = Color(0.92, 0.80, 0.52, 0.95)
var spinning: bool = false
var _angle: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5
	resized.connect(func(): pivot_offset = size * 0.5)


func _process(delta: float) -> void:
	if spinning:
		_angle += delta * 0.7
		queue_redraw()


func _col(a: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * a)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 4.0
	if r <= 0:
		return

	# Concentric rings
	draw_arc(c, r, 0.0, TAU, 72, _col(0.7), 2.0, true)
	draw_arc(c, r * 0.70, 0.0, TAU, 56, _col(0.4), 1.5, true)

	# Outer runic ticks (rotate one way)
	for i in 12:
		var a := _angle + TAU * float(i) / 12.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * r, c + dir * (r - 11.0), _col(0.6), 2.0, true)

	# Counter-rotating diamond
	var dia := PackedVector2Array()
	for i in 4:
		var a := -_angle * 1.3 + TAU * float(i) / 4.0
		dia.append(c + Vector2(cos(a), sin(a)) * r * 0.52)
	dia.append(dia[0])
	draw_polyline(dia, _col(0.85), 2.0, true)

	# Inner triangle (rotates with the ticks)
	var tri := PackedVector2Array()
	for i in 3:
		var a := _angle * 0.8 + TAU * float(i) / 3.0 - PI / 2.0
		tri.append(c + Vector2(cos(a), sin(a)) * r * 0.34)
	tri.append(tri[0])
	draw_polyline(tri, _col(0.7), 1.5, true)

	# Glowing core
	draw_circle(c, 5.0, color)
	draw_circle(c, 9.0, _col(0.25))
