class_name RadarChart
extends Control

signal axis_hovered(index: int, axis_data: Dictionary)
signal axis_unhovered()

@export var background_color: Color = Color(0.1, 0.1, 0.15, 0.9)
@export var grid_color: Color = Color(0.3, 0.3, 0.4, 0.5)
@export var axis_color: Color = Color(0.4, 0.4, 0.5, 0.8)
@export var fill_color: Color = Color(0.2, 0.6, 0.9, 0.4)
@export var outline_color: Color = Color(0.3, 0.8, 1.0, 0.9)
@export var label_color: Color = Color(0.9, 0.9, 0.9, 1.0)
@export var point_color: Color = Color(1.0, 1.0, 1.0, 1.0)

@export var grid_rings: int = 4
@export var outline_width: float = 2.0
@export var point_radius: float = 4.0
@export var padding: float = 30.0
@export var label_offset: float = 15.0

var axes: Array[Dictionary] = []
var _hovered_axis: int = -1


func set_data(data: Array[Dictionary]) -> void:
	axes = data
	queue_redraw()


func clear() -> void:
	axes.clear()
	queue_redraw()


func _draw() -> void:
	if axes.is_empty():
		return

	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0 - padding - label_offset
	var point_count: int = axes.size()
	var angle_step: float = TAU / point_count

	_draw_background(center, radius)
	_draw_grid_rings(center, radius)
	_draw_axis_lines(center, radius, point_count, angle_step)
	_draw_data_polygon(center, radius, point_count, angle_step)
	_draw_labels(center, radius, point_count, angle_step)


func _draw_background(center: Vector2, radius: float) -> void:
	draw_circle(center, radius + 5, background_color)


func _draw_grid_rings(center: Vector2, radius: float) -> void:
	for i in range(1, grid_rings + 1):
		var ring_radius := radius * (float(i) / grid_rings)
		draw_arc(center, ring_radius, 0, TAU, 64, grid_color, 1.0)


func _draw_axis_lines(center: Vector2, radius: float, point_count: int, angle_step: float) -> void:
	for i in range(point_count):
		var angle := angle_step * i - PI / 2.0
		var end_point := center + Vector2(cos(angle), sin(angle)) * radius
		draw_line(center, end_point, axis_color, 1.0)


func _draw_data_polygon(center: Vector2, radius: float, point_count: int, angle_step: float) -> void:
	var points: PackedVector2Array = []

	for i in range(point_count):
		var angle := angle_step * i - PI / 2.0
		var axis_data: Dictionary = axes[i]
		var value: float = axis_data.get("value", 0.0)
		var max_value: float = axis_data.get("max_value", 1.0)
		var normalized := clampf(value / max_value, 0.0, 1.0) if max_value > 0 else 0.0
		var point := center + Vector2(cos(angle), sin(angle)) * radius * normalized
		points.append(point)

	if points.size() >= 3:
		draw_colored_polygon(points, fill_color)

		for i in range(points.size()):
			var next_i := (i + 1) % points.size()
			draw_line(points[i], points[next_i], outline_color, outline_width)

		for i in range(points.size()):
			var highlight := _hovered_axis == i
			var color := Color.YELLOW if highlight else point_color
			var r := point_radius * 1.5 if highlight else point_radius
			draw_circle(points[i], r, color)


func _draw_labels(center: Vector2, radius: float, point_count: int, angle_step: float) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 12

	for i in range(point_count):
		var angle := angle_step * i - PI / 2.0
		var label_pos := center + Vector2(cos(angle), sin(angle)) * (radius + label_offset)
		var axis_data: Dictionary = axes[i]
		var label: String = axis_data.get("label", "")
		var value: float = axis_data.get("value", 0.0)

		var display_text := "%s\n%.0f" % [label, value]
		var text_size := font.get_multiline_string_size(display_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

		var text_offset := Vector2(-text_size.x / 2.0, 0)
		if angle > -PI / 4 and angle < PI / 4:
			text_offset.y = text_size.y / 4.0
		elif angle > 3 * PI / 4 or angle < -3 * PI / 4:
			text_offset.y = text_size.y / 4.0
		elif angle > 0:
			text_offset.y = text_size.y / 2.0
		else:
			text_offset.y = -text_size.y / 4.0

		var highlight := _hovered_axis == i
		var color := Color.YELLOW if highlight else label_color
		draw_multiline_string(font, label_pos + text_offset, display_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, -1, color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		var new_hovered := _get_axis_at_position(mouse_pos)
		if new_hovered != _hovered_axis:
			_hovered_axis = new_hovered
			queue_redraw()
			if _hovered_axis >= 0:
				axis_hovered.emit(_hovered_axis, axes[_hovered_axis])
			else:
				axis_unhovered.emit()


func _get_axis_at_position(pos: Vector2) -> int:
	if axes.is_empty():
		return -1

	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0 - padding - label_offset
	var point_count: int = axes.size()
	var angle_step: float = TAU / point_count

	for i in range(point_count):
		var angle: float = angle_step * i - PI / 2.0
		var axis_data: Dictionary = axes[i]
		var value: float = axis_data.get("value", 0.0)
		var max_value: float = axis_data.get("max_value", 1.0)
		var normalized: float = clampf(value / max_value, 0.0, 1.0) if max_value > 0 else 0.0
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * normalized

		if pos.distance_to(point) < point_radius * 3:
			return i

	return -1
