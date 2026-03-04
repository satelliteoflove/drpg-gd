class_name AttributeBars
extends Control

const MIN_VALUE: float = 1.0
const MAX_VALUE: float = 25.0

const BAR_HEIGHT: int = 20
const BAR_SPACING: int = 4
const LABEL_WIDTH: int = 40
const VALUE_WIDTH: int = 30

@export var background_color: Color = Color(0.15, 0.15, 0.2, 1.0)
@export var bar_color: Color = Color(0.3, 0.6, 0.9, 1.0)
@export var bar_background: Color = Color(0.2, 0.2, 0.25, 1.0)
@export var label_color: Color = Color(0.9, 0.9, 0.9, 1.0)
@export var high_color: Color = Color(0.4, 0.8, 0.4, 1.0)
@export var low_color: Color = Color(0.8, 0.4, 0.4, 1.0)

var attributes: Array[Dictionary] = []


func set_character(character: Character) -> void:
	attributes.clear()
	attributes.append({ "label": "STR", "value": character.strength, "base": character.peak_strength })
	attributes.append({ "label": "INT", "value": character.intelligence, "base": character.peak_intelligence })
	attributes.append({ "label": "PIE", "value": character.piety, "base": character.peak_piety })
	attributes.append({ "label": "VIT", "value": character.vitality, "base": character.peak_vitality })
	attributes.append({ "label": "AGI", "value": character.agility, "base": character.peak_agility })
	attributes.append({ "label": "LCK", "value": character.luck, "base": character.peak_luck })
	queue_redraw()


func clear() -> void:
	attributes.clear()
	queue_redraw()


func _draw() -> void:
	if attributes.is_empty():
		return

	var font := ThemeDB.fallback_font
	var font_size := 14
	var y_offset := 0

	for attr in attributes:
		var label: String = attr.get("label", "")
		var value: int = attr.get("value", 10)
		var base: int = attr.get("base", 10)

		var bar_x: float = LABEL_WIDTH
		var bar_width: float = size.x - LABEL_WIDTH - VALUE_WIDTH - 10
		var bar_y: float = y_offset + 2

		draw_rect(Rect2(bar_x, bar_y, bar_width, BAR_HEIGHT - 4), bar_background)

		var fill_ratio: float = clampf((value - MIN_VALUE) / (MAX_VALUE - MIN_VALUE), 0.0, 1.0)
		var fill_width: float = bar_width * fill_ratio

		var color := bar_color
		if value > base:
			color = high_color
		elif value < base:
			color = low_color

		draw_rect(Rect2(bar_x, bar_y, fill_width, BAR_HEIGHT - 4), color)

		draw_string(font, Vector2(4, y_offset + BAR_HEIGHT - 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)

		var value_str := str(value)
		var value_x: float = size.x - VALUE_WIDTH
		draw_string(font, Vector2(value_x, y_offset + BAR_HEIGHT - 5), value_str, HORIZONTAL_ALIGNMENT_RIGHT, VALUE_WIDTH, font_size, label_color)

		y_offset += BAR_HEIGHT + BAR_SPACING


func _get_minimum_size() -> Vector2:
	var height := attributes.size() * (BAR_HEIGHT + BAR_SPACING)
	return Vector2(200, height)
