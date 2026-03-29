class_name CharacterSheet
extends Control

const PADDING := 12.0
const SECTION_GAP := 14.0
const LINE_HEIGHT := 18.0
const BAR_HEIGHT := 16.0
const BAR_SPACING := 4.0
const HEADER_HEIGHT := 70.0
const ATTR_LABEL_WIDTH := 36.0
const ATTR_VALUE_WIDTH := 28.0
const ATTR_MIN := 1.0
const ATTR_MAX := 25.0
const EQUIP_LABEL_WIDTH := 36.0
const SLOT_LABELS: Array[String] = ["Wpn", "Arm", "Shd", "Hlm", "Glv", "Bts", "Acc"]
const SLOT_FIELDS: Array[String] = [
	"equipped_weapon", "equipped_armor", "equipped_shield",
	"equipped_helmet", "equipped_gloves", "equipped_boots", "equipped_accessory"
]

var _character: Character = null
var _party_index: int = 0
var _font: Font


func set_character(character: Character, party_index: int) -> void:
	_character = character
	_party_index = party_index
	queue_redraw()


func clear() -> void:
	_character = null
	queue_redraw()


func _ready() -> void:
	_font = ThemeDB.fallback_font


func _draw() -> void:
	if _character == null:
		return

	draw_rect(Rect2(Vector2.ZERO, size), UIColors.SURFACE_PANEL)

	var y := PADDING
	y = _draw_identity_header(y)
	y += 4.0

	draw_line(Vector2(PADDING, y), Vector2(size.x - PADDING, y), UIColors.BORDER_SUBTLE, 1.0)
	y += 8.0

	var col_width := (size.x - PADDING * 3.0) / 2.0
	var left_x := PADDING
	var right_x := PADDING * 2.0 + col_width

	var left_y := y
	var right_y := y

	left_y = _draw_resources(left_x, left_y, col_width)
	left_y += SECTION_GAP
	left_y = _draw_combat(left_x, left_y, col_width)
	left_y += SECTION_GAP
	left_y = _draw_personality(left_x, left_y, col_width)
	left_y += SECTION_GAP
	_draw_bonds(left_x, left_y, col_width)

	right_y = _draw_attributes(right_x, right_y, col_width)
	right_y += SECTION_GAP
	right_y = _draw_equipment(right_x, right_y, col_width)
	right_y += SECTION_GAP
	_draw_marks(right_x, right_y, col_width)


func _draw_identity_header(y: float) -> float:
	var name_text := _character.character_name
	if _character.pending_level_up:
		name_text += "  *"
	var name_color := UIColors.GOLD if _character.pending_level_up else UIColors.TEXT_TITLE
	if _character.is_dead:
		name_color = UIColors.TEXT_DANGER
	draw_string(_font, Vector2(PADDING, y + UIColors.FONT_SIZE_HEADER), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_HEADER, name_color)

	var info_right := "Lv %d %s %s" % [_character.level, CharacterEnums.get_race_name(_character.race), CharacterEnums.get_class_name(_character.character_class)]
	var info_width := _font.get_string_size(info_right, HORIZONTAL_ALIGNMENT_RIGHT, -1, UIColors.FONT_SIZE_BODY).x
	draw_string(_font, Vector2(size.x - PADDING - info_width, y + UIColors.FONT_SIZE_HEADER), info_right, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_BODY, UIColors.TEXT_PRIMARY)
	y += UIColors.FONT_SIZE_HEADER + 6.0

	var gender_str := "Male" if _character.gender == CharacterEnums.Gender.MALE else "Female"
	var line2 := "%s  %s  Age: %d (%s)" % [CharacterEnums.get_alignment_name(_character.alignment), gender_str, _character.get_age_years(), _character.get_life_phase_name()]
	draw_string(_font, Vector2(PADDING, y + UIColors.FONT_SIZE_SMALL), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, UIColors.TEXT_SECONDARY)
	y += UIColors.FONT_SIZE_SMALL + 4.0

	var row_text := "Front Row" if _party_index < 3 else "Back Row"
	var row_color := UIColors.FRONT_ROW if _party_index < 3 else UIColors.BACK_ROW
	draw_string(_font, Vector2(PADDING, y + UIColors.FONT_SIZE_SMALL), row_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, row_color)

	var status_x := PADDING + _font.get_string_size(row_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL).x + 16.0

	if _character.is_dead:
		draw_string(_font, Vector2(status_x, y + UIColors.FONT_SIZE_SMALL), "[DEAD]", HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, UIColors.TEXT_DANGER)
	else:
		var status_text := _get_status_text()
		var status_color := UIColors.TEXT_WARNING if status_text != "OK" else UIColors.SUCCESS
		draw_string(_font, Vector2(status_x, y + UIColors.FONT_SIZE_SMALL), "Status: " + status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, status_color)
	y += UIColors.FONT_SIZE_SMALL + 2.0

	return y


func _draw_section_header(text: String, x: float, y: float) -> float:
	draw_string(_font, Vector2(x, y + UIColors.FONT_SIZE_SMALL), text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, UIColors.TEXT_MUTED)
	return y + UIColors.FONT_SIZE_SMALL + 4.0


func _draw_resources(x: float, y: float, width: float) -> float:
	y = _draw_section_header("RESOURCES", x, y)

	y = _draw_resource_bar(x, y, width, "HP", _character.current_hp, _character.max_hp, UIColors.HP_GREEN)
	y += 4.0
	if _character.max_mp > 0:
		y = _draw_resource_bar(x, y, width, "MP", _character.current_mp, _character.max_mp, UIColors.MP_BLUE)
		y += 4.0

	var xp_text := "XP: %d" % _character.experience
	draw_string(_font, Vector2(x, y + UIColors.FONT_SIZE_SMALL), xp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, UIColors.TEXT_PRIMARY)
	y += LINE_HEIGHT

	if not _character.is_dead:
		var avg_level := GameState.party.get_average_level()
		if _character.level < avg_level:
			var catchup_pct := mini(50, 5 * (avg_level - _character.level))
			draw_string(_font, Vector2(x, y + UIColors.FONT_SIZE_SMALL), "Catch-up: +%d%% XP" % catchup_pct, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, UIColors.SUCCESS)
			y += LINE_HEIGHT
		if _character.rest_bonus_xp_multiplier > 1.0:
			var rest_pct := (_character.rest_bonus_xp_multiplier - 1.0) * 100.0
			draw_string(_font, Vector2(x, y + UIColors.FONT_SIZE_SMALL), "Rested: +%.0f%% XP" % rest_pct, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, UIColors.SUCCESS)
			y += LINE_HEIGHT

	return y


func _draw_resource_bar(x: float, y: float, width: float, label: String, current: int, maximum: int, bar_color: Color) -> float:
	draw_string(_font, Vector2(x, y + UIColors.FONT_SIZE_SMALL), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, UIColors.TEXT_SECONDARY)

	var value_text := "%d/%d" % [current, maximum]
	var value_width := _font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, UIColors.FONT_SIZE_SMALL).x
	draw_string(_font, Vector2(x + width - value_width, y + UIColors.FONT_SIZE_SMALL), value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, UIColors.TEXT_PRIMARY)
	y += UIColors.FONT_SIZE_SMALL + 2.0

	var bar_x := x
	var bar_width := width
	draw_rect(Rect2(bar_x, y, bar_width, BAR_HEIGHT - 4), UIColors.SURFACE_BAR_BG)

	if maximum > 0:
		var percent := float(current) / float(maximum)
		var color := bar_color
		if percent < 0.25:
			color = UIColors.DANGER
		elif percent < 0.5:
			color = UIColors.WARNING
		draw_rect(Rect2(bar_x, y, bar_width * percent, BAR_HEIGHT - 4), color)
	y += BAR_HEIGHT - 2

	return y


func _draw_combat(x: float, y: float, width: float) -> float:
	y = _draw_section_header("COMBAT", x, y)

	var half := width / 2.0
	var pairs: Array[Array] = [
		["Weapon: %s" % _character.weapon_dice, "Dmg: %+d" % _character.damage_bonus],
		["Acc: %+d" % _character.accuracy, "Def: %d" % _character.defense],
		["Evasion: %d" % _character.evasion, ""],
	]
	for pair in pairs:
		draw_string(_font, Vector2(x, y + UIColors.FONT_SIZE_SMALL), pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, UIColors.TEXT_PRIMARY)
		if not pair[1].is_empty():
			draw_string(_font, Vector2(x + half, y + UIColors.FONT_SIZE_SMALL), pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, UIColors.TEXT_PRIMARY)
		y += LINE_HEIGHT

	if _character.death_count > 0:
		draw_string(_font, Vector2(x, y + UIColors.FONT_SIZE_SMALL), "Deaths: %d" % _character.death_count, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, UIColors.TEXT_DANGER)
		y += LINE_HEIGHT

	return y


func _draw_personality(x: float, y: float, _width: float) -> float:
	if _character.tendencies.is_empty():
		return y

	y = _draw_section_header("PERSONALITY", x, y)

	for axis: int in Personality.Axis.values():
		var option: int = _character.get_active_trait(axis as Personality.Axis)
		if option < 0:
			continue
		var trait_name: String = Personality.get_option_name(axis as Personality.Axis, option)
		var crystallized := _character.is_trait_crystallized(axis as Personality.Axis)
		var display := trait_name if crystallized else trait_name + " (tendency)"
		var color := UIColors.TEXT_PRIMARY if crystallized else UIColors.TEXT_SECONDARY
		draw_string(_font, Vector2(x, y + UIColors.FONT_SIZE_SMALL), display, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, color)
		y += LINE_HEIGHT

	return y


func _draw_bonds(x: float, y: float, _width: float) -> float:
	var rels := RelationshipManager.get_relationships_for(_character.id)
	if rels.is_empty():
		return y

	rels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return abs(a.get("weight", 0)) > abs(b.get("weight", 0)))

	y = _draw_section_header("BONDS", x, y)

	var count := mini(rels.size(), 3)
	for i in range(count):
		var rel: Dictionary = rels[i]
		var other := GameState.roster.get_character(rel.other_id)
		var rel_name: String = other.character_name if other else rel.other_id
		var tier: Relationships.BondTier = rel.tier
		if tier == Relationships.BondTier.NEUTRAL:
			continue
		var tier_name := Relationships.get_tier_name(tier)
		var color := UIColors.SUCCESS if tier == Relationships.BondTier.BONDED else UIColors.WARNING
		var display := "%s: %s" % [rel_name, tier_name]
		draw_string(_font, Vector2(x, y + UIColors.FONT_SIZE_SMALL), display, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, color)
		y += LINE_HEIGHT

	return y


func _draw_attributes(x: float, y: float, width: float) -> float:
	y = _draw_section_header("ATTRIBUTES", x, y)

	var attrs: Array[Array] = [
		["STR", _character.strength, _character.peak_strength],
		["INT", _character.intelligence, _character.peak_intelligence],
		["PIE", _character.piety, _character.peak_piety],
		["VIT", _character.vitality, _character.peak_vitality],
		["AGI", _character.agility, _character.peak_agility],
		["LCK", _character.luck, _character.peak_luck],
	]

	for attr in attrs:
		var label: String = attr[0]
		var value: int = attr[1]
		var peak: int = attr[2]

		draw_string(_font, Vector2(x, y + UIColors.FONT_SIZE_SMALL), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, UIColors.TEXT_SECONDARY)

		var bar_x := x + ATTR_LABEL_WIDTH
		var bar_w := width - ATTR_LABEL_WIDTH - ATTR_VALUE_WIDTH - 8.0
		draw_rect(Rect2(bar_x, y + 2, bar_w, BAR_HEIGHT - 6), UIColors.SURFACE_BAR_BG)

		var fill := clampf((float(value) - ATTR_MIN) / (ATTR_MAX - ATTR_MIN), 0.0, 1.0)
		var bar_color := UIColors.INFO
		if value > peak:
			bar_color = UIColors.SUCCESS
		elif value < peak:
			bar_color = UIColors.DANGER
		draw_rect(Rect2(bar_x, y + 2, bar_w * fill, BAR_HEIGHT - 6), bar_color)

		var val_x := x + width - ATTR_VALUE_WIDTH
		draw_string(_font, Vector2(val_x, y + UIColors.FONT_SIZE_SMALL), str(value), HORIZONTAL_ALIGNMENT_RIGHT, ATTR_VALUE_WIDTH, UIColors.FONT_SIZE_SMALL, UIColors.TEXT_PRIMARY)
		y += BAR_HEIGHT + BAR_SPACING

	return y


func _draw_equipment(x: float, y: float, _width: float) -> float:
	y = _draw_section_header("EQUIPMENT", x, y)

	for i in range(SLOT_LABELS.size()):
		var label: String = SLOT_LABELS[i]
		var item: Item = _character.get(SLOT_FIELDS[i])
		var item_name := item.item_name if item else "(none)"
		var color := UIColors.TEXT_PRIMARY if item else UIColors.TEXT_MUTED

		draw_string(_font, Vector2(x, y + UIColors.FONT_SIZE_SMALL), label + ":", HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, UIColors.TEXT_SECONDARY)
		draw_string(_font, Vector2(x + EQUIP_LABEL_WIDTH + 4, y + UIColors.FONT_SIZE_SMALL), item_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_SMALL, color)
		y += LINE_HEIGHT

	return y


func _draw_marks(x: float, y: float, width: float) -> float:
	var marks := _character.get_marks()
	if marks.is_empty():
		return y

	y = _draw_section_header("MARKS", x, y)

	var max_visible := int((size.y - y - PADDING) / LINE_HEIGHT)
	max_visible = maxi(max_visible, 1)
	var display_marks := marks.slice(maxi(0, marks.size() - max_visible))
	display_marks.reverse()

	for mark: Dictionary in display_marks:
		var mark_name: String = mark.get("name", "Unknown")
		var is_major: bool = mark.get("severity") == Marks.Severity.MAJOR
		var prefix := "* " if is_major else "  "
		var color := UIColors.GOLD if is_major else UIColors.TEXT_PRIMARY
		draw_string(_font, Vector2(x, y + UIColors.FONT_SIZE_SMALL), prefix + mark_name, HORIZONTAL_ALIGNMENT_LEFT, int(width), UIColors.FONT_SIZE_SMALL, color)
		y += LINE_HEIGHT

	return y


func _get_status_text() -> String:
	var effects: Array[String] = []
	for status in _character.status_effects:
		if status == CharacterEnums.StatusEffect.DEAD:
			continue
		effects.append(CharacterEnums.get_status_name(status))
	if effects.is_empty():
		return "OK"
	return ", ".join(effects)
