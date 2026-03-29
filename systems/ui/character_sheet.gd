class_name CharacterSheet
extends Control

const PADDING := 14.0
const SECTION_GAP := 12.0
const LINE_HEIGHT := 22.0
const LINE_HEIGHT_SM := 18.0
const BAR_HEIGHT := 18.0
const BAR_SPACING := 4.0
const ATTR_LABEL_WIDTH := 40.0
const ATTR_VALUE_WIDTH := 32.0
const ATTR_MIN := 1.0
const ATTR_MAX := 25.0
const EQUIP_LABEL_WIDTH := 44.0
const FONT_SIZE := UIColors.FONT_SIZE_BODY
const FONT_SIZE_SM := UIColors.FONT_SIZE_SMALL
const ZONE_GAP := 12.0
const SLOT_LABELS: Array[String] = ["Wpn", "Arm", "Shd", "Hlm", "Glv", "Bts", "Acc"]
const SLOT_FIELDS: Array[String] = [
	"equipped_weapon", "equipped_armor", "equipped_shield",
	"equipped_helmet", "equipped_gloves", "equipped_boots", "equipped_accessory"
]
const EQUIPMENT_SLOTS: Array[Item.ItemType] = [
	Item.ItemType.WEAPON, Item.ItemType.ARMOR, Item.ItemType.SHIELD,
	Item.ItemType.HELMET, Item.ItemType.GLOVES, Item.ItemType.BOOTS,
	Item.ItemType.ACCESSORY
]

enum EquipMode { VIEW, SLOT_SELECT, ITEM_SELECT }
enum StoryFocus { NONE, PERSONALITY, BONDS, MARKS }

var _character: Character = null
var _party_index: int = 0
var _font: Font

var _equip_mode: EquipMode = EquipMode.VIEW
var _selected_slot: int = 0
var _selected_item: int = 0
var _item_scroll_offset: int = 0
var _available_items: Array[Item] = []
var _can_equip_flags: Array[bool] = []
var _preview_deltas: Dictionary = {}
var _cursed_message: bool = false
var _story_focus: StoryFocus = StoryFocus.NONE


func set_character(character: Character, party_index: int) -> void:
	_character = character
	_party_index = party_index
	_story_focus = StoryFocus.NONE
	if _equip_mode == EquipMode.ITEM_SELECT:
		_populate_available_items()
		_update_preview_deltas()
	queue_redraw()


func clear() -> void:
	_character = null
	_equip_mode = EquipMode.VIEW
	_story_focus = StoryFocus.NONE
	_preview_deltas.clear()
	_available_items.clear()
	queue_redraw()


func enter_equip_mode() -> void:
	_equip_mode = EquipMode.SLOT_SELECT
	_selected_slot = 0
	_cursed_message = false
	_story_focus = StoryFocus.NONE
	_preview_deltas.clear()
	queue_redraw()


func exit_equip_mode() -> void:
	_equip_mode = EquipMode.VIEW
	_selected_slot = 0
	_selected_item = 0
	_item_scroll_offset = 0
	_available_items.clear()
	_can_equip_flags.clear()
	_preview_deltas.clear()
	_cursed_message = false
	queue_redraw()


func get_equip_mode() -> EquipMode:
	return _equip_mode


func back_from_items() -> void:
	_equip_mode = EquipMode.SLOT_SELECT
	_preview_deltas.clear()
	_available_items.clear()
	_can_equip_flags.clear()
	queue_redraw()


func cycle_story_focus() -> void:
	_story_focus = ((_story_focus + 1) % 4) as StoryFocus
	queue_redraw()


func is_showing_detail() -> bool:
	return _story_focus != StoryFocus.NONE


func get_info_text() -> String:
	if _character == null:
		return ""

	if _equip_mode == EquipMode.VIEW and _story_focus != StoryFocus.NONE:
		match _story_focus:
			StoryFocus.PERSONALITY:
				return _get_personality_detail()
			StoryFocus.BONDS:
				return _get_bonds_detail()
			StoryFocus.MARKS:
				return _get_marks_detail()

	match _equip_mode:
		EquipMode.SLOT_SELECT:
			var slot_type: Item.ItemType = EQUIPMENT_SLOTS[_selected_slot]
			var equipped: Item = _character.get_equipped_item(slot_type)
			if _cursed_message:
				return "[b]Cursed![/b]\nThis item cannot be removed."
			if equipped:
				return "[b]%s[/b]\n%s\n%s" % [equipped.get_display_name(), equipped.get_type_name(), equipped.get_stats_text()]
			return "[b]%s[/b]\n(Empty)" % SLOT_LABELS[_selected_slot]
		EquipMode.ITEM_SELECT:
			if _selected_item == 0:
				return "[b]Unequip[/b]\nRemove current item and return to inventory."
			var item_idx := _selected_item - 1
			if item_idx >= 0 and item_idx < _available_items.size():
				var item: Item = _available_items[item_idx]
				var text := "[b]%s[/b]\n%s\n%s" % [item.get_display_name(), item.get_type_name(), item.get_stats_text()]
				if not _character.can_equip_item(item):
					text += "\n[color=red]Cannot equip[/color]"
				return text
	return ""


func handle_equip_input(event: InputEvent) -> bool:
	if _character == null:
		return false

	match _equip_mode:
		EquipMode.SLOT_SELECT:
			return _handle_slot_input(event)
		EquipMode.ITEM_SELECT:
			return _handle_item_input(event)
	return false


func _handle_slot_input(event: InputEvent) -> bool:
	if event.is_action_pressed("menu_down"):
		_selected_slot = (_selected_slot + 1) % SLOT_LABELS.size()
		_cursed_message = false
		queue_redraw()
		return true
	if event.is_action_pressed("menu_up"):
		_selected_slot = (_selected_slot - 1 + SLOT_LABELS.size()) % SLOT_LABELS.size()
		_cursed_message = false
		queue_redraw()
		return true
	if event.is_action_pressed("menu_confirm"):
		_populate_available_items()
		_selected_item = 0
		_item_scroll_offset = 0
		_equip_mode = EquipMode.ITEM_SELECT
		_update_preview_deltas()
		queue_redraw()
		return true
	if event.is_action_pressed("menu_cancel"):
		exit_equip_mode()
		return true
	return false


func _handle_item_input(event: InputEvent) -> bool:
	var total_count := 1 + _available_items.size()
	if event.is_action_pressed("menu_down"):
		_selected_item = (_selected_item + 1) % total_count
		_update_scroll()
		_update_preview_deltas()
		queue_redraw()
		return true
	if event.is_action_pressed("menu_up"):
		_selected_item = (_selected_item - 1 + total_count) % total_count
		_update_scroll()
		_update_preview_deltas()
		queue_redraw()
		return true
	if event.is_action_pressed("menu_confirm"):
		if _selected_item == 0:
			_unequip_current_slot()
		else:
			var item_idx := _selected_item - 1
			if item_idx >= 0 and item_idx < _available_items.size():
				_equip_item(_available_items[item_idx])
		return true
	if event.is_action_pressed("menu_cancel"):
		_equip_mode = EquipMode.SLOT_SELECT
		_preview_deltas.clear()
		_available_items.clear()
		_can_equip_flags.clear()
		queue_redraw()
		return true
	return false


func _update_scroll() -> void:
	var max_visible := maxi(int((size.y - PADDING * 4) / LINE_HEIGHT), 2)
	if _selected_item < _item_scroll_offset:
		_item_scroll_offset = _selected_item
	elif _selected_item >= _item_scroll_offset + max_visible:
		_item_scroll_offset = _selected_item - max_visible + 1


func _populate_available_items() -> void:
	_available_items.clear()
	_can_equip_flags.clear()
	var slot_type: Item.ItemType = EQUIPMENT_SLOTS[_selected_slot]
	if GameState.party == null or GameState.party.inventory == null:
		return
	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		if item and item.is_equipment() and item.item_type == slot_type:
			_available_items.append(item)
			_can_equip_flags.append(_character.can_equip_item(item))


func _equip_item(item: Item) -> void:
	if not _character.can_equip_item(item):
		return
	GameState.party.inventory.remove_item(item.id, 1)
	var old_item: Item = _character.equip_item(item)
	if old_item:
		GameState.party.inventory.add_item(old_item, 1)
	_equip_mode = EquipMode.SLOT_SELECT
	_preview_deltas.clear()
	_available_items.clear()
	_can_equip_flags.clear()
	queue_redraw()


func _unequip_current_slot() -> void:
	var slot_type: Item.ItemType = EQUIPMENT_SLOTS[_selected_slot]
	var old_item: Item = _character.unequip_slot(slot_type)
	if old_item:
		GameState.party.inventory.add_item(old_item, 1)
	elif _character.get_equipped_item(slot_type) and _character.get_equipped_item(slot_type).is_cursed:
		_cursed_message = true
	_equip_mode = EquipMode.SLOT_SELECT
	_preview_deltas.clear()
	_available_items.clear()
	_can_equip_flags.clear()
	queue_redraw()


func _update_preview_deltas() -> void:
	_preview_deltas.clear()
	if _selected_item == 0:
		var slot_type: Item.ItemType = EQUIPMENT_SLOTS[_selected_slot]
		var old_item: Item = _character.get_equipped_item(slot_type)
		if old_item == null:
			return
		_preview_deltas["accuracy"] = -old_item.get_effective_accuracy_bonus()
		_preview_deltas["damage"] = -old_item.get_effective_damage_bonus()
		_preview_deltas["defense"] = -old_item.get_effective_defense_bonus()
		_preview_deltas["evasion"] = -old_item.get_effective_evasion_bonus()
		_preview_deltas["hp"] = -old_item.get_effective_hp_bonus()
		_preview_deltas["mp"] = -old_item.get_effective_mp_bonus()
		_preview_deltas["strength"] = -old_item.strength_bonus
		_preview_deltas["intelligence"] = -old_item.intelligence_bonus
		_preview_deltas["piety"] = -old_item.piety_bonus
		_preview_deltas["vitality"] = -old_item.vitality_bonus
		_preview_deltas["agility"] = -old_item.agility_bonus
		_preview_deltas["luck"] = -old_item.luck_bonus
		if slot_type == Item.ItemType.WEAPON:
			_preview_deltas["weapon_dice"] = "1d4"
		return

	var item_idx := _selected_item - 1
	if item_idx < 0 or item_idx >= _available_items.size():
		return

	var new_item: Item = _available_items[item_idx]
	var slot_type: Item.ItemType = EQUIPMENT_SLOTS[_selected_slot]
	var old_item: Item = _character.get_equipped_item(slot_type)

	var old_acc := old_item.get_effective_accuracy_bonus() if old_item else 0
	var old_dmg := old_item.get_effective_damage_bonus() if old_item else 0
	var old_def := old_item.get_effective_defense_bonus() if old_item else 0
	var old_eva := old_item.get_effective_evasion_bonus() if old_item else 0
	var old_hp := old_item.get_effective_hp_bonus() if old_item else 0
	var old_mp := old_item.get_effective_mp_bonus() if old_item else 0

	_preview_deltas["accuracy"] = new_item.get_effective_accuracy_bonus() - old_acc
	_preview_deltas["damage"] = new_item.get_effective_damage_bonus() - old_dmg
	_preview_deltas["defense"] = new_item.get_effective_defense_bonus() - old_def
	_preview_deltas["evasion"] = new_item.get_effective_evasion_bonus() - old_eva
	_preview_deltas["hp"] = new_item.get_effective_hp_bonus() - old_hp
	_preview_deltas["mp"] = new_item.get_effective_mp_bonus() - old_mp

	_preview_deltas["strength"] = new_item.strength_bonus - (old_item.strength_bonus if old_item else 0)
	_preview_deltas["intelligence"] = new_item.intelligence_bonus - (old_item.intelligence_bonus if old_item else 0)
	_preview_deltas["piety"] = new_item.piety_bonus - (old_item.piety_bonus if old_item else 0)
	_preview_deltas["vitality"] = new_item.vitality_bonus - (old_item.vitality_bonus if old_item else 0)
	_preview_deltas["agility"] = new_item.agility_bonus - (old_item.agility_bonus if old_item else 0)
	_preview_deltas["luck"] = new_item.luck_bonus - (old_item.luck_bonus if old_item else 0)

	if slot_type == Item.ItemType.WEAPON:
		_preview_deltas["weapon_dice"] = new_item.damage_dice if new_item.damage_dice != "" else "1d4"


# === DRAWING ===


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

	var available_w := size.x - PADDING * 2.0 - ZONE_GAP * 2.0
	var zone_a_w := floorf(available_w * 0.27)
	var zone_c_w := floorf(available_w * 0.27)
	var zone_b_w := available_w - zone_a_w - zone_c_w

	var zone_a_x := PADDING
	var zone_b_x := zone_a_x + zone_a_w + ZONE_GAP
	var zone_c_x := zone_b_x + zone_b_w + ZONE_GAP

	var body_y := y

	var a_y := body_y
	a_y = _draw_resources(zone_a_x, a_y, zone_a_w)
	a_y += SECTION_GAP
	_draw_combat(zone_a_x, a_y, zone_a_w)

	var b_y := body_y
	b_y = _draw_attributes(zone_b_x, b_y, zone_b_w)
	b_y += SECTION_GAP
	_draw_story_summary(zone_b_x, b_y, zone_b_w)

	var c_y := body_y
	if _equip_mode == EquipMode.ITEM_SELECT:
		c_y = _draw_equip_slot_header(zone_c_x, c_y, zone_c_w)
		c_y += 4.0
		draw_line(Vector2(zone_c_x, c_y), Vector2(zone_c_x + zone_c_w, c_y), UIColors.BORDER_SUBTLE, 1.0)
		c_y += 4.0
		_draw_equip_items(zone_c_x, c_y, zone_c_w)
	else:
		_draw_equipment(zone_c_x, c_y, zone_c_w)

	var div_top := body_y - 4.0
	var div_bot := size.y - PADDING
	draw_line(Vector2(zone_b_x - ZONE_GAP / 2.0, div_top), Vector2(zone_b_x - ZONE_GAP / 2.0, div_bot), UIColors.BORDER_SUBTLE, 1.0)
	draw_line(Vector2(zone_c_x - ZONE_GAP / 2.0, div_top), Vector2(zone_c_x - ZONE_GAP / 2.0, div_bot), UIColors.BORDER_SUBTLE, 1.0)


func _draw_identity_header(y: float) -> float:
	var name_text := _character.character_name
	if _character.pending_level_up:
		name_text += "  *"
	var name_color := UIColors.GOLD if _character.pending_level_up else UIColors.TEXT_TITLE
	if _character.is_dead:
		name_color = UIColors.TEXT_DANGER
	draw_string(_font, Vector2(PADDING, y + UIColors.FONT_SIZE_HEADER), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SIZE_HEADER, name_color)

	var info_right := "Lv %d %s %s" % [_character.level, CharacterEnums.get_race_name(_character.race), CharacterEnums.get_class_name(_character.character_class)]
	var info_width := _font.get_string_size(info_right, HORIZONTAL_ALIGNMENT_RIGHT, -1, FONT_SIZE).x
	draw_string(_font, Vector2(size.x - PADDING - info_width, y + UIColors.FONT_SIZE_HEADER), info_right, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.TEXT_PRIMARY)
	y += UIColors.FONT_SIZE_HEADER + 4.0

	var gender_str := "Male" if _character.gender == CharacterEnums.Gender.MALE else "Female"
	var line2 := "%s  %s  Age: %d (%s)" % [CharacterEnums.get_alignment_name(_character.alignment), gender_str, _character.get_age_years(), _character.get_life_phase_name()]
	var row_text := "Front Row" if _party_index < 3 else "Back Row"
	var row_color := UIColors.FRONT_ROW if _party_index < 3 else UIColors.BACK_ROW

	draw_string(_font, Vector2(PADDING, y + FONT_SIZE_SM), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, UIColors.TEXT_SECONDARY)

	var line2_w := _font.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM).x
	var sep_x := PADDING + line2_w + 12.0
	draw_string(_font, Vector2(sep_x, y + FONT_SIZE_SM), row_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, row_color)

	var status_x := sep_x + _font.get_string_size(row_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM).x + 12.0
	if _character.is_dead:
		draw_string(_font, Vector2(status_x, y + FONT_SIZE_SM), "[DEAD]", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, UIColors.TEXT_DANGER)
	else:
		var status_text := _get_status_text()
		var status_color := UIColors.TEXT_WARNING if status_text != "OK" else UIColors.SUCCESS
		draw_string(_font, Vector2(status_x, y + FONT_SIZE_SM), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, status_color)
	y += FONT_SIZE_SM + 2.0

	return y


func _draw_section_header(text: String, x: float, y: float, color: Color = UIColors.TEXT_MUTED) -> float:
	draw_string(_font, Vector2(x, y + FONT_SIZE_SM), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, color)
	return y + FONT_SIZE_SM + 4.0


# === ZONE A: RESOURCES + COMBAT ===


func _draw_resources(x: float, y: float, width: float) -> float:
	y = _draw_section_header("RESOURCES", x, y)

	y = _draw_resource_bar(x, y, width, "HP", _character.current_hp, _character.max_hp, UIColors.HP_GREEN, _preview_deltas.get("hp", 0))
	y += 4.0
	if _character.max_mp > 0:
		y = _draw_resource_bar(x, y, width, "MP", _character.current_mp, _character.max_mp, UIColors.MP_BLUE, _preview_deltas.get("mp", 0))
		y += 4.0

	var xp_text := "XP: %d" % _character.experience
	draw_string(_font, Vector2(x, y + FONT_SIZE), xp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.TEXT_PRIMARY)
	y += LINE_HEIGHT

	if not _character.is_dead:
		var avg_level := GameState.party.get_average_level()
		if _character.level < avg_level:
			var catchup_pct := mini(50, 5 * (avg_level - _character.level))
			draw_string(_font, Vector2(x, y + FONT_SIZE_SM), "Catch-up: +%d%% XP" % catchup_pct, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, UIColors.SUCCESS)
			y += LINE_HEIGHT_SM
		if _character.rest_bonus_xp_multiplier > 1.0:
			var rest_pct := (_character.rest_bonus_xp_multiplier - 1.0) * 100.0
			draw_string(_font, Vector2(x, y + FONT_SIZE_SM), "Rested: +%.0f%% XP" % rest_pct, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, UIColors.SUCCESS)
			y += LINE_HEIGHT_SM

	return y


func _draw_resource_bar(x: float, y: float, width: float, label: String, current: int, maximum: int, bar_color: Color, delta: int = 0) -> float:
	draw_string(_font, Vector2(x, y + FONT_SIZE), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.TEXT_SECONDARY)

	var base_text := "%d/%d" % [current, maximum]
	var base_width := _font.get_string_size(base_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, FONT_SIZE).x
	var total_text_w := base_width
	if delta != 0:
		total_text_w += _font.get_string_size(" (%+d)" % delta, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x

	draw_string(_font, Vector2(x + width - total_text_w, y + FONT_SIZE), base_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.TEXT_PRIMARY)
	if delta != 0:
		var delta_color := UIColors.SUCCESS if delta > 0 else UIColors.DANGER
		draw_string(_font, Vector2(x + width - total_text_w + base_width, y + FONT_SIZE), " (%+d)" % delta, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, delta_color)

	y += FONT_SIZE + 2.0
	draw_rect(Rect2(x, y, width, BAR_HEIGHT - 4), UIColors.SURFACE_BAR_BG)
	if maximum > 0:
		var percent := float(current) / float(maximum)
		var color := bar_color
		if percent < 0.25:
			color = UIColors.DANGER
		elif percent < 0.5:
			color = UIColors.WARNING
		draw_rect(Rect2(x, y, width * percent, BAR_HEIGHT - 4), color)
	y += BAR_HEIGHT - 2
	return y


func _draw_combat(x: float, y: float, width: float) -> float:
	y = _draw_section_header("COMBAT", x, y)

	var weapon_text := "Weapon: %s" % _character.weapon_dice
	if _preview_deltas.has("weapon_dice"):
		weapon_text += " > %s" % _preview_deltas["weapon_dice"]
	draw_string(_font, Vector2(x, y + FONT_SIZE), weapon_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.TEXT_PRIMARY)
	y += LINE_HEIGHT

	_draw_stat_with_delta(x, y, "Dmg: %+d" % _character.damage_bonus, _preview_deltas.get("damage", 0))
	_draw_stat_with_delta(x + width / 2.0, y, "Def: %d" % _character.defense, _preview_deltas.get("defense", 0))
	y += LINE_HEIGHT

	_draw_stat_with_delta(x, y, "Acc: %+d" % _character.accuracy, _preview_deltas.get("accuracy", 0))
	_draw_stat_with_delta(x + width / 2.0, y, "Eva: %d" % _character.evasion, _preview_deltas.get("evasion", 0))
	y += LINE_HEIGHT

	if _character.death_count > 0:
		draw_string(_font, Vector2(x, y + FONT_SIZE), "Deaths: %d" % _character.death_count, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.TEXT_DANGER)
		y += LINE_HEIGHT

	return y


func _draw_stat_with_delta(x: float, y: float, text: String, delta: int) -> void:
	draw_string(_font, Vector2(x, y + FONT_SIZE), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.TEXT_PRIMARY)
	if delta != 0:
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var delta_str := " %+d" % delta
		var color := UIColors.SUCCESS if delta > 0 else UIColors.DANGER
		draw_string(_font, Vector2(x + w, y + FONT_SIZE), delta_str, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


# === ZONE B: ATTRIBUTES + STORY ===


func _draw_attributes(x: float, y: float, width: float) -> float:
	y = _draw_section_header("ATTRIBUTES", x, y)

	var attr_delta_keys: Array[String] = ["strength", "intelligence", "piety", "vitality", "agility", "luck"]
	var attrs: Array[Array] = [
		["STR", _character.strength, _character.peak_strength],
		["INT", _character.intelligence, _character.peak_intelligence],
		["PIE", _character.piety, _character.peak_piety],
		["VIT", _character.vitality, _character.peak_vitality],
		["AGI", _character.agility, _character.peak_agility],
		["LCK", _character.luck, _character.peak_luck],
	]

	for i in range(attrs.size()):
		var attr: Array = attrs[i]
		var label: String = attr[0]
		var value: int = attr[1]
		var peak: int = attr[2]

		draw_string(_font, Vector2(x, y + FONT_SIZE), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.TEXT_SECONDARY)

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
		draw_string(_font, Vector2(val_x, y + FONT_SIZE), str(value), HORIZONTAL_ALIGNMENT_RIGHT, ATTR_VALUE_WIDTH, FONT_SIZE, UIColors.TEXT_PRIMARY)

		var delta: int = _preview_deltas.get(attr_delta_keys[i], 0)
		if delta != 0:
			var delta_str := " %+d" % delta
			var delta_color := UIColors.SUCCESS if delta > 0 else UIColors.DANGER
			draw_string(_font, Vector2(val_x + ATTR_VALUE_WIDTH + 2, y + FONT_SIZE), delta_str, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, delta_color)

		y += BAR_HEIGHT + BAR_SPACING

	return y


func _draw_story_summary(x: float, y: float, _width: float) -> float:
	y = _draw_section_header("STORY", x, y)

	var personality := _get_personality_summary()
	if not personality.is_empty():
		var is_focused := _story_focus == StoryFocus.PERSONALITY
		var color := UIColors.TEXT_PRIMARY if is_focused else UIColors.TEXT_SECONDARY
		var prefix := "> " if is_focused else "  "
		draw_string(_font, Vector2(x, y + FONT_SIZE_SM), prefix + personality, HORIZONTAL_ALIGNMENT_LEFT, int(_width), FONT_SIZE_SM, color)
		y += LINE_HEIGHT_SM

	var bonds := _get_bond_summary()
	if not bonds.is_empty():
		var is_focused := _story_focus == StoryFocus.BONDS
		var color := UIColors.TEXT_PRIMARY if is_focused else UIColors.TEXT_SECONDARY
		var prefix := "> " if is_focused else "  "
		draw_string(_font, Vector2(x, y + FONT_SIZE_SM), prefix + "Bonds: " + bonds, HORIZONTAL_ALIGNMENT_LEFT, int(_width), FONT_SIZE_SM, color)
		y += LINE_HEIGHT_SM

	var marks := _get_mark_summary()
	if not marks.is_empty():
		var is_focused := _story_focus == StoryFocus.MARKS
		var color := UIColors.TEXT_PRIMARY if is_focused else UIColors.TEXT_SECONDARY
		var prefix := "> " if is_focused else "  "
		draw_string(_font, Vector2(x, y + FONT_SIZE_SM), prefix + "Marks: " + marks, HORIZONTAL_ALIGNMENT_LEFT, int(_width), FONT_SIZE_SM, color)
		y += LINE_HEIGHT_SM

	return y


func _get_personality_summary() -> String:
	if _character.tendencies.is_empty():
		return ""
	var parts: Array[String] = []
	for axis: int in Personality.Axis.values():
		var option: int = _character.get_active_trait(axis as Personality.Axis)
		if option < 0:
			continue
		var trait_name: String = Personality.get_option_name(axis as Personality.Axis, option)
		if not _character.is_trait_crystallized(axis as Personality.Axis):
			trait_name += "~"
		parts.append(trait_name)
	return ", ".join(parts) if not parts.is_empty() else ""


func _get_bond_summary() -> String:
	var rels := RelationshipManager.get_relationships_for(_character.id)
	if rels.is_empty():
		return ""
	var companion_count := 0
	var bonded_count := 0
	for rel: Dictionary in rels:
		var tier: Relationships.BondTier = rel.tier
		if tier == Relationships.BondTier.COMPANION:
			companion_count += 1
		elif tier == Relationships.BondTier.BONDED:
			bonded_count += 1
	var parts: Array[String] = []
	if bonded_count > 0:
		parts.append("%d Bonded" % bonded_count)
	if companion_count > 0:
		parts.append("%d Companion%s" % [companion_count, "s" if companion_count > 1 else ""])
	return ", ".join(parts) if not parts.is_empty() else "None"


func _get_mark_summary() -> String:
	var marks := _character.get_marks()
	if marks.is_empty():
		return ""
	var minor := 0
	var major := 0
	for mark: Dictionary in marks:
		if mark.get("severity") == Marks.Severity.MAJOR:
			major += 1
		else:
			minor += 1
	var parts: Array[String] = []
	if major > 0:
		parts.append("%d major" % major)
	if minor > 0:
		parts.append("%d minor" % minor)
	return ", ".join(parts)


func _get_personality_detail() -> String:
	var text := "[b]Personality[/b]\n"
	for axis: int in Personality.Axis.values():
		var option: int = _character.get_active_trait(axis as Personality.Axis)
		if option < 0:
			continue
		var axis_name: String = Personality.get_axis_name(axis as Personality.Axis)
		var trait_name: String = Personality.get_option_name(axis as Personality.Axis, option)
		var crystallized := _character.is_trait_crystallized(axis as Personality.Axis)
		var status := "Crystallized" if crystallized else "Tendency"
		text += "%s: %s (%s)\n" % [axis_name, trait_name, status]
	return text if text.length() > 20 else "[b]Personality[/b]\nNo traits yet."


func _get_bonds_detail() -> String:
	var rels := RelationshipManager.get_relationships_for(_character.id)
	if rels.is_empty():
		return "[b]Bonds[/b]\nNo relationships."
	rels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return abs(a.get("weight", 0)) > abs(b.get("weight", 0)))
	var text := "[b]Bonds[/b]\n"
	for rel: Dictionary in rels:
		var other := GameState.roster.get_character(rel.other_id)
		var rel_name: String = other.character_name if other else rel.other_id
		var tier: Relationships.BondTier = rel.tier
		if tier == Relationships.BondTier.NEUTRAL:
			continue
		var tier_name := Relationships.get_tier_name(tier)
		text += "%s: %s\n" % [rel_name, tier_name]
	return text


func _get_marks_detail() -> String:
	var marks := _character.get_marks()
	if marks.is_empty():
		return "[b]Marks[/b]\nNo marks yet."
	var text := "[b]Marks[/b]\n"
	var display := marks.duplicate()
	display.reverse()
	for mark: Dictionary in display:
		var mark_name: String = mark.get("name", "Unknown")
		var is_major: bool = mark.get("severity") == Marks.Severity.MAJOR
		var prefix := "* " if is_major else "  "
		text += prefix + mark_name + "\n"
	return text


# === ZONE C: EQUIPMENT ===


func _draw_equipment(x: float, y: float, _width: float) -> float:
	var header_text := "EQUIPMENT"
	var header_color := UIColors.TEXT_MUTED
	if _equip_mode == EquipMode.SLOT_SELECT:
		header_text = "EQUIP (select slot)"
		header_color = UIColors.INFO
	y = _draw_section_header(header_text, x, y, header_color)

	for i in range(SLOT_LABELS.size()):
		var is_selected := (_equip_mode == EquipMode.SLOT_SELECT and i == _selected_slot)
		if is_selected:
			draw_rect(Rect2(x - 2, y - 1, _width + 4, LINE_HEIGHT), UIColors.SURFACE_SELECTED)

		var label: String = SLOT_LABELS[i]
		var item: Item = _character.get(SLOT_FIELDS[i])
		var item_name := item.get_display_name() if item else "(none)"
		var color := UIColors.TEXT_PRIMARY if item else UIColors.TEXT_MUTED

		var in_equip := _equip_mode == EquipMode.SLOT_SELECT
		var prefix := "> " if is_selected else "  "
		var prefix_color := UIColors.INFO if is_selected else UIColors.TEXT_MUTED
		if in_equip:
			draw_string(_font, Vector2(x, y + FONT_SIZE), prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, prefix_color)

		var label_x := x + (16.0 if in_equip else 0.0)
		draw_string(_font, Vector2(label_x, y + FONT_SIZE), label + ":", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.TEXT_SECONDARY)
		draw_string(_font, Vector2(label_x + EQUIP_LABEL_WIDTH + 4, y + FONT_SIZE), item_name, HORIZONTAL_ALIGNMENT_LEFT, int(_width - EQUIP_LABEL_WIDTH - 20), FONT_SIZE, color)
		y += LINE_HEIGHT

	return y


func _draw_equip_slot_header(x: float, y: float, _width: float) -> float:
	y = _draw_section_header("EQUIP (select item)", x, y, UIColors.INFO)

	var label: String = SLOT_LABELS[_selected_slot]
	var item: Item = _character.get(SLOT_FIELDS[_selected_slot])
	var item_name := item.get_display_name() if item else "(none)"
	var color := UIColors.TEXT_PRIMARY if item else UIColors.TEXT_MUTED

	draw_rect(Rect2(x - 2, y - 1, _width + 4, LINE_HEIGHT), UIColors.SURFACE_SELECTED)
	draw_string(_font, Vector2(x, y + FONT_SIZE), "> ", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.INFO)
	draw_string(_font, Vector2(x + 16, y + FONT_SIZE), label + ":", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.TEXT_SECONDARY)
	draw_string(_font, Vector2(x + 16 + EQUIP_LABEL_WIDTH + 4, y + FONT_SIZE), item_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
	y += LINE_HEIGHT

	return y


func _draw_equip_items(x: float, y: float, width: float) -> void:
	var total_count := 1 + _available_items.size()
	var max_visible := maxi(int((size.y - y - PADDING) / LINE_HEIGHT), 2)

	if _available_items.is_empty():
		var is_unequip_selected := (_selected_item == 0)
		if is_unequip_selected:
			draw_rect(Rect2(x - 2, y - 1, width + 4, LINE_HEIGHT), UIColors.SURFACE_SELECTED)
		draw_string(_font, Vector2(x, y + FONT_SIZE), "> (Unequip)", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.INFO if is_unequip_selected else UIColors.TEXT_PRIMARY)
		y += LINE_HEIGHT
		draw_string(_font, Vector2(x, y + FONT_SIZE), "  (No items available)", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.TEXT_MUTED)
		return

	var visible_end := mini(_item_scroll_offset + max_visible, total_count)

	if _item_scroll_offset > 0:
		draw_string(_font, Vector2(x + width - 20, y - LINE_HEIGHT + FONT_SIZE + 4), "^", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.TEXT_MUTED)

	for idx in range(_item_scroll_offset, visible_end):
		var is_selected := (idx == _selected_item)
		if is_selected:
			draw_rect(Rect2(x - 2, y - 1, width + 4, LINE_HEIGHT), UIColors.SURFACE_SELECTED)

		var prefix := "> " if is_selected else "  "
		var prefix_color := UIColors.INFO if is_selected else UIColors.TEXT_MUTED

		if idx == 0:
			draw_string(_font, Vector2(x, y + FONT_SIZE), prefix + "(Unequip)", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.INFO if is_selected else UIColors.TEXT_PRIMARY)
		else:
			var item_idx := idx - 1
			var item: Item = _available_items[item_idx]
			var can_equip: bool = _can_equip_flags[item_idx] if item_idx < _can_equip_flags.size() else true
			var text_color := UIColors.TEXT_PRIMARY if can_equip else UIColors.TEXT_DISABLED
			draw_string(_font, Vector2(x, y + FONT_SIZE), prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, prefix_color)
			var item_text := item.get_display_name()
			if not can_equip:
				item_text += " [x]"
			draw_string(_font, Vector2(x + 16, y + FONT_SIZE), item_text, HORIZONTAL_ALIGNMENT_LEFT, int(width - 16), FONT_SIZE, text_color)
		y += LINE_HEIGHT

	if visible_end < total_count:
		draw_string(_font, Vector2(x + width - 20, y + FONT_SIZE - 4), "v", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIColors.TEXT_MUTED)


# === HELPERS ===


func _get_status_text() -> String:
	var effects: Array[String] = []
	for status in _character.status_effects:
		if status == CharacterEnums.StatusEffect.DEAD:
			continue
		effects.append(CharacterEnums.get_status_name(status))
	if effects.is_empty():
		return "OK"
	return ", ".join(effects)
