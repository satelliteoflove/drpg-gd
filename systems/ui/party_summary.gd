class_name PartySummary
extends Control

var party: Party = null

var _label_font: Font
var _label_font_size: int = 14
var _value_font_size: int = 12
var _header_font_size: int = 16

@export var background_color: Color = Color(0.12, 0.12, 0.15, 0.9)
@export var header_color: Color = Color(0.9, 0.9, 0.9, 1.0)
@export var label_color: Color = Color(0.7, 0.7, 0.7, 1.0)
@export var value_color: Color = Color(0.3, 0.8, 1.0, 1.0)
@export var bar_bg_color: Color = Color(0.2, 0.2, 0.25, 1.0)
@export var hp_bar_color: Color = Color(0.2, 0.7, 0.3, 1.0)
@export var mp_bar_color: Color = Color(0.3, 0.5, 0.9, 1.0)
@export var warning_color: Color = Color(1.0, 0.8, 0.2, 1.0)
@export var critical_color: Color = Color(0.9, 0.3, 0.3, 1.0)

func set_party(p_party: Party) -> void:
	party = p_party
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _ready() -> void:
	_label_font = ThemeDB.fallback_font


func _draw() -> void:
	if party == null or party.is_empty():
		_draw_empty_state()
		return

	var y_offset: float = 10.0
	var padding: float = 12.0
	var section_gap: float = 16.0

	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	y_offset = _draw_header("Party Summary", y_offset, padding)
	y_offset += 8.0

	y_offset = _draw_aggregate_stats(y_offset, padding)
	y_offset += section_gap

	y_offset = _draw_resource_bars(y_offset, padding)


func _draw_empty_state() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	var text := "No Party"
	var text_size := _label_font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, _header_font_size)
	var pos := Vector2((size.x - text_size.x) / 2.0, size.y / 2.0)
	draw_string(_label_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, _header_font_size, label_color)


func _draw_header(text: String, y_offset: float, padding: float) -> float:
	var pos := Vector2(padding, y_offset + _header_font_size)
	draw_string(_label_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _header_font_size, header_color)
	return y_offset + _header_font_size + 4.0


func _draw_aggregate_stats(y_offset: float, padding: float) -> float:
	var stats := _calculate_party_stats()
	var line_height: float = _value_font_size + 6.0
	var col_width: float = (size.x - padding * 2) / 2.0

	var stat_pairs: Array[Array] = [
		["Total DPT", "%.0f" % stats.total_dpt],
		["Avg MIT", "%.0f" % stats.avg_mitigation],
		["Avg SPD", "%.0f" % stats.avg_speed],
		["Total SRV", "%.0f" % stats.total_survivability],
	]

	for i in range(stat_pairs.size()):
		@warning_ignore("integer_division")
		var row: int = i / 2
		var col: int = i % 2
		var x_pos: float = padding + col * col_width
		var y_pos: float = y_offset + row * line_height

		var label: String = stat_pairs[i][0]
		var value: String = stat_pairs[i][1]

		draw_string(_label_font, Vector2(x_pos, y_pos + _value_font_size), label + ":", HORIZONTAL_ALIGNMENT_LEFT, -1, _value_font_size, label_color)
		draw_string(_label_font, Vector2(x_pos + 70, y_pos + _value_font_size), value, HORIZONTAL_ALIGNMENT_LEFT, -1, _value_font_size, value_color)

	var rows := ceili(float(stat_pairs.size()) / 2.0)
	return y_offset + rows * line_height


func _draw_resource_bars(y_offset: float, padding: float) -> float:
	var resources := _calculate_resources()
	var bar_height: float = 14.0
	var bar_width: float = size.x - padding * 2.0

	draw_string(_label_font, Vector2(padding, y_offset + _label_font_size), "Resources", HORIZONTAL_ALIGNMENT_LEFT, -1, _label_font_size, header_color)
	y_offset += _label_font_size + 6.0

	var hp_percent: float = resources.hp_current / maxf(resources.hp_max, 1.0)
	var hp_color := hp_bar_color
	if hp_percent < 0.25:
		hp_color = critical_color
	elif hp_percent < 0.5:
		hp_color = warning_color

	draw_string(_label_font, Vector2(padding, y_offset + _value_font_size), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, _value_font_size, label_color)
	var hp_value_text := "%d/%d" % [resources.hp_current, resources.hp_max]
	var hp_text_width := _label_font.get_string_size(hp_value_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, _value_font_size).x
	draw_string(_label_font, Vector2(size.x - padding - hp_text_width, y_offset + _value_font_size), hp_value_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, _value_font_size, value_color)

	y_offset += _value_font_size + 2.0
	var hp_bar_rect := Rect2(padding, y_offset, bar_width, bar_height)
	draw_rect(hp_bar_rect, bar_bg_color)
	draw_rect(Rect2(padding, y_offset, bar_width * hp_percent, bar_height), hp_color)

	y_offset += bar_height + 8.0

	if resources.mp_max > 0:
		var mp_percent: float = resources.mp_current / maxf(resources.mp_max, 1.0)
		var mp_color := mp_bar_color
		if mp_percent < 0.25:
			mp_color = critical_color
		elif mp_percent < 0.5:
			mp_color = warning_color

		draw_string(_label_font, Vector2(padding, y_offset + _value_font_size), "MP", HORIZONTAL_ALIGNMENT_LEFT, -1, _value_font_size, label_color)
		var mp_value_text := "%d/%d" % [resources.mp_current, resources.mp_max]
		var mp_text_width := _label_font.get_string_size(mp_value_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, _value_font_size).x
		draw_string(_label_font, Vector2(size.x - padding - mp_text_width, y_offset + _value_font_size), mp_value_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, _value_font_size, value_color)

		y_offset += _value_font_size + 2.0
		var mp_bar_rect := Rect2(padding, y_offset, bar_width, bar_height)
		draw_rect(mp_bar_rect, bar_bg_color)
		draw_rect(Rect2(padding, y_offset, bar_width * mp_percent, bar_height), mp_color)

		y_offset += bar_height + 4.0

	return y_offset


func _calculate_party_stats() -> Dictionary:
	var total_dpt: float = 0.0
	var total_mitigation: float = 0.0
	var total_speed: float = 0.0
	var total_survivability: float = 0.0
	var alive_count: int = 0

	for member in party.get_members():
		if member.is_dead:
			continue

		alive_count += 1
		total_dpt += _calculate_member_dpt(member)
		total_mitigation += _calculate_member_mitigation(member)
		total_speed += float(member.agility)
		total_survivability += _calculate_member_survivability(member)

	var avg_mitigation: float = total_mitigation / maxf(alive_count, 1)
	var avg_speed: float = total_speed / maxf(alive_count, 1)

	return {
		"total_dpt": total_dpt,
		"avg_mitigation": avg_mitigation,
		"avg_speed": avg_speed,
		"total_survivability": total_survivability,
		"alive_count": alive_count,
	}


func _calculate_member_dpt(member: Character) -> float:
	var dice_str := member.weapon_dice
	var expected := _parse_dice_expected(dice_str)
	var str_bonus := float(member.strength - 10) / 4.0
	var dmg_bonus := float(member.damage_bonus)
	return expected + str_bonus + dmg_bonus


func _calculate_member_mitigation(member: Character) -> float:
	return float(member.defense) + float(member.vitality) / 4.0


func _calculate_member_survivability(member: Character) -> float:
	return float(member.max_hp) + float(member.vitality) / 2.0


func _parse_dice_expected(dice_str: String) -> float:
	if dice_str.is_empty():
		return 1.0

	var parts := dice_str.to_lower().split("d")
	if parts.size() != 2:
		return 1.0

	var num_dice := parts[0].to_int()
	if num_dice <= 0:
		num_dice = 1

	var die_sides := parts[1].to_int()
	if die_sides <= 0:
		die_sides = 4

	return num_dice * (die_sides + 1.0) / 2.0


func _calculate_resources() -> Dictionary:
	var hp_current: int = 0
	var hp_max: int = 0
	var mp_current: int = 0
	var mp_max: int = 0

	for member in party.get_members():
		hp_current += member.current_hp
		hp_max += member.max_hp
		mp_current += member.current_mp
		mp_max += member.max_mp

	return {
		"hp_current": hp_current,
		"hp_max": hp_max,
		"mp_current": mp_current,
		"mp_max": mp_max,
	}
