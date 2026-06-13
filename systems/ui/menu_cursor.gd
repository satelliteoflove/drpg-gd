class_name MenuCursor extends Control

## A glowing gold arrow that marks the focused menu item and gently bobs toward
## it. MenuNavigator tweens its global_position between items.

@export var color: Color = Color(0.93, 0.81, 0.53, 1.0)
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	set_process(true)


func _process(delta: float) -> void:
	_t += delta * 3.5
	queue_redraw()


func _draw() -> void:
	var cy := size.y * 0.5
	var bob := (sin(_t) * 0.5 + 0.5) * 4.0
	var apex := Vector2(size.x - 4.0 + bob, cy)
	var s := 7.0
	# Soft glow behind
	_arrow(apex, s + 4.0, Color(color.r, color.g, color.b, 0.22))
	# Solid arrow
	_arrow(apex, s, color)


func _arrow(apex: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		apex,
		apex + Vector2(-s * 1.5, -s),
		apex + Vector2(-s * 1.5, s),
	]), col)
