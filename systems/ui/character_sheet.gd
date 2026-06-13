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
const SLOT_NAMES: Array[String] = [
	"Weapon", "Armor", "Shield", "Helmet", "Gloves", "Boots", "Accessory"
]

# Dossier layout metrics
const PAD := 16.0
const COL_GAP := 14.0
const CARD_PAD := 13.0
const HERO_H := 88.0
const METER_H := 20.0
const ATTR_METER_H := 14.0
const ATTR_ROW_H := 23.0
const ROW_H := 22.0
const ROW_H_SM := 19.0
const CHIP_H := 20.0
const CHIP_FS := 12

enum EquipMode { VIEW, SLOT_SELECT, ITEM_SELECT }
enum StoryFocus { NONE, PERSONALITY, BONDS, MARKS }

var _character: Character = null
var _party_index: int = 0
var _show_row_chip: bool = true
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

var _font_display: Font
var _font_semibold: Font
var _equip_visible_rows: int = 10


func set_character(character: Character, party_index: int, show_row: bool = true) -> void:
	_character = character
	_party_index = party_index
	_show_row_chip = show_row
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
	var max_visible := maxi(_equip_visible_rows, 2)
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
	var inter := load(UITheme.INTER_PATH)
	var cinzel := load(UITheme.CINZEL_PATH)
	if inter is Font:
		_font = _make_variation(inter, 400)
		_font_semibold = _make_variation(inter, 600)
	if cinzel is Font:
		_font_display = _make_variation(cinzel, 700)
	if _font_semibold == null:
		_font_semibold = _font
	if _font_display == null:
		_font_display = _font


func _make_variation(base: Font, weight: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {"wght": weight}
	return fv


func _draw() -> void:
	if _character == null:
		return

	draw_rect(Rect2(Vector2.ZERO, size), UIColors.SURFACE_PANEL)

	# Hero band: class crest + identity + chips.
	var hero := Rect2(PAD, PAD, size.x - PAD * 2.0, HERO_H)
	_draw_hero_band(hero)

	# Three full-height wells beneath it.
	var body_top := hero.position.y + hero.size.y + 12.0
	var body_h := size.y - PAD - body_top
	var avail_w := size.x - PAD * 2.0 - COL_GAP * 2.0
	var c1_w := floorf(avail_w * 0.30)
	var c3_w := floorf(avail_w * 0.37)
	var c2_w := avail_w - c1_w - c3_w

	var c1_x := PAD
	var c2_x := c1_x + c1_w + COL_GAP
	var c3_x := c2_x + c2_w + COL_GAP

	_draw_well(Rect2(c1_x, body_top, c1_w, body_h))
	_draw_well(Rect2(c2_x, body_top, c2_w, body_h))
	_draw_well(Rect2(c3_x, body_top, c3_w, body_h))

	# Column 1: vitals + combat.
	var ix1 := c1_x + CARD_PAD
	var iw1 := c1_w - CARD_PAD * 2.0
	var y1 := body_top + CARD_PAD
	y1 = _draw_vitals(ix1, y1, iw1)
	y1 += 10.0
	y1 = _draw_divider(ix1, y1, iw1) + 8.0
	_draw_combat(ix1, y1, iw1)

	# Column 2: attributes + story.
	var ix2 := c2_x + CARD_PAD
	var iw2 := c2_w - CARD_PAD * 2.0
	var y2 := body_top + CARD_PAD
	y2 = _draw_attributes(ix2, y2, iw2)
	y2 += 10.0
	y2 = _draw_divider(ix2, y2, iw2) + 8.0
	_draw_story_summary(ix2, y2, iw2)

	# Column 3: equipment, or the live equip interaction.
	var ix3 := c3_x + CARD_PAD
	var iw3 := c3_w - CARD_PAD * 2.0
	var y3 := body_top + CARD_PAD
	if _equip_mode == EquipMode.ITEM_SELECT:
		y3 = _draw_equip_slot_header(ix3, y3, iw3)
		y3 += 6.0
		_draw_equip_items(ix3, y3, iw3, body_top + body_h - CARD_PAD)
	else:
		_draw_equipment(ix3, y3, iw3)


func _draw_hero_band(r: Rect2) -> void:
	# Raised card with a warm gold underline.
	var card := StyleBoxFlat.new()
	card.bg_color = UIColors.SURFACE_CARD
	card.set_corner_radius_all(UITheme.RADIUS_PANEL)
	card.border_width_bottom = 2
	card.border_color = UIColors.TITLE_GOLD_DIM
	card.shadow_color = UIColors.SHADOW
	card.shadow_size = 4
	card.shadow_offset = Vector2(0, 2)
	draw_style_box(card, r)

	var inset := 14.0
	var emblem_size := r.size.y - inset * 2.0
	_draw_emblem(Rect2(r.position.x + inset, r.position.y + inset, emblem_size, emblem_size))

	var tx := r.position.x + inset + emblem_size + 16.0
	var ty := r.position.y + 11.0

	# Name in carved gold.
	var name_color := UIColors.TITLE_GOLD
	if _character.is_dead:
		name_color = UIColors.TEXT_DANGER
	elif _character.pending_level_up:
		name_color = UIColors.GOLD
	draw_string(_font_display, Vector2(tx, ty + 25.0), _character.character_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, name_color)
	if _character.pending_level_up:
		var nw := _font_display.get_string_size(_character.character_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(_font_semibold, Vector2(tx + nw + 12.0, ty + 20.0), "LEVEL UP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIColors.GOLD)

	# Class / race / level subtitle.
	var sub := "Level %d   ·   %s %s" % [_character.level, CharacterEnums.get_race_name(_character.race), CharacterEnums.get_class_name(_character.character_class)]
	draw_string(_font_semibold, Vector2(tx, ty + 45.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIColors.TEXT_SECONDARY)

	# Identity chips.
	var cy := ty + 53.0
	var cx := tx
	var gender_str := "Male" if _character.gender == CharacterEnums.Gender.MALE else "Female"
	cx += _draw_chip(cx, cy, CharacterEnums.get_alignment_name(_character.alignment)) + 6.0
	cx += _draw_chip(cx, cy, gender_str) + 6.0
	cx += _draw_chip(cx, cy, "%d · %s" % [_character.get_age_years(), _character.get_life_phase_name()]) + 6.0
	if _show_row_chip:
		var row_text := "Front Row" if _party_index < 3 else "Back Row"
		var row_color := UIColors.FRONT_ROW if _party_index < 3 else UIColors.BACK_ROW
		cx += _draw_chip(cx, cy, row_text, row_color) + 6.0

	# Status chip pinned to the right edge.
	var status_text := "DEAD" if _character.is_dead else _get_status_text()
	var status_color := UIColors.SUCCESS
	if _character.is_dead:
		status_color = UIColors.TEXT_DANGER
	elif status_text != "OK":
		status_color = UIColors.TEXT_WARNING
	_draw_chip(r.position.x + r.size.x - inset - _chip_width(status_text), ty + 4.0, status_text, status_color)


func _draw_emblem(r: Rect2) -> void:
	var tint := _class_tint(_character.character_class)
	var plate := StyleBoxFlat.new()
	plate.bg_color = tint.darkened(0.55)
	plate.set_corner_radius_all(10)
	plate.set_border_width_all(2)
	plate.border_color = tint
	if _character.is_dead:
		plate.bg_color = UIColors.SURFACE_PRESSED
		plate.border_color = UIColors.BORDER_DEFAULT
	draw_style_box(plate, r)

	var initial := CharacterEnums.get_class_name(_character.character_class).substr(0, 1).to_upper()
	var fs := int(r.size.y * 0.62)
	var glyph_color := tint.lightened(0.4) if not _character.is_dead else UIColors.TEXT_MUTED
	var gw := _font_display.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font_display, Vector2(r.position.x + (r.size.x - gw) / 2.0, r.position.y + r.size.y * 0.5 + fs * 0.36), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, glyph_color)


func _class_tint(cls: int) -> Color:
	match cls:
		CharacterEnums.CharacterClass.FIGHTER, CharacterEnums.CharacterClass.SAMURAI, \
		CharacterEnums.CharacterClass.LORD, CharacterEnums.CharacterClass.VALKYRIE:
			return Color(0.82, 0.36, 0.32)
		CharacterEnums.CharacterClass.THIEF, CharacterEnums.CharacterClass.NINJA, \
		CharacterEnums.CharacterClass.MONK:
			return Color(0.42, 0.72, 0.48)
		CharacterEnums.CharacterClass.MAGE, CharacterEnums.CharacterClass.ALCHEMIST, \
		CharacterEnums.CharacterClass.PSIONIC, CharacterEnums.CharacterClass.BISHOP:
			return Color(0.50, 0.60, 0.97)
		CharacterEnums.CharacterClass.PRIEST:
			return Color(0.85, 0.72, 0.42)
		CharacterEnums.CharacterClass.BARD, CharacterEnums.CharacterClass.RANGER:
			return Color(0.80, 0.62, 0.34)
	return UIColors.ACCENT


# --- Shared drawing primitives ---


func _draw_well(r: Rect2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.105, 0.10, 0.13)
	sb.set_corner_radius_all(UITheme.RADIUS_PANEL)
	sb.set_border_width_all(1)
	sb.border_color = UIColors.BORDER_SUBTLE
	draw_style_box(sb, r)


func _draw_divider(x: float, y: float, w: float) -> float:
	draw_line(Vector2(x, y), Vector2(x + w, y), UIColors.BORDER_SUBTLE, 1.0)
	return y + 1.0


func _section(text: String, x: float, y: float, _w: float, accent: Color = UIColors.TITLE_GOLD_DIM) -> float:
	draw_rect(Rect2(x, y + 2.0, 3.0, 12.0), accent)
	draw_string(_font_semibold, Vector2(x + 9.0, y + 13.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIColors.TEXT_SECONDARY)
	return y + 22.0


func _chip_width(text: String) -> float:
	return _font_semibold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FS).x + 16.0


func _draw_chip(x: float, y: float, text: String, fg: Color = UIColors.TEXT_PRIMARY, bg: Color = UIColors.SURFACE_SELECTED) -> float:
	var w := _chip_width(text)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(CHIP_H / 2.0))
	sb.set_border_width_all(1)
	sb.border_color = UIColors.BORDER_SUBTLE
	draw_style_box(sb, Rect2(x, y, w, CHIP_H))
	var tw := _font_semibold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FS).x
	draw_string(_font_semibold, Vector2(x + (w - tw) / 2.0, y + CHIP_H - 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FS, fg)
	return w


func _draw_meter(r: Rect2, pct: float, fill: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = UIColors.SURFACE_BAR_BG
	bg.set_corner_radius_all(4)
	bg.set_border_width_all(1)
	bg.border_color = UIColors.BORDER_SUBTLE
	draw_style_box(bg, r)
	pct = clampf(pct, 0.0, 1.0)
	if pct > 0.0:
		var fb := StyleBoxFlat.new()
		fb.bg_color = fill
		fb.set_corner_radius_all(4)
		draw_style_box(fb, Rect2(r.position.x, r.position.y, maxf(r.size.x * pct, 3.0), r.size.y))


func _format_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


# === ZONE A: RESOURCES + COMBAT ===


func _draw_vitals(x: float, y: float, w: float) -> float:
	y = _section("VITALS", x, y, w)

	y = _draw_labeled_meter(x, y, w, "HP", _character.current_hp, _character.max_hp, UIColors.HP_GREEN, _preview_deltas.get("hp", 0))
	if _character.max_mp > 0:
		y += 6.0
		y = _draw_labeled_meter(x, y, w, "MP", _character.current_mp, _character.max_mp, UIColors.MP_BLUE, _preview_deltas.get("mp", 0))

	# XP toward the next level (a real progress bar, not raw points).
	y += 9.0
	if _character.level >= ExperienceTable.MAX_LEVEL:
		draw_string(_font_semibold, Vector2(x, y + 12.0), "XP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIColors.TEXT_SECONDARY)
		draw_string(_font, Vector2(x, y + 12.0), "MAX LEVEL", HORIZONTAL_ALIGNMENT_RIGHT, int(w), 12, UIColors.GOLD)
		y += 18.0
	else:
		draw_string(_font_semibold, Vector2(x, y + 12.0), "XP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIColors.TEXT_SECONDARY)
		var nxt := "%s to Lv %d" % [_format_int(_character.get_xp_to_next_level()), _character.level + 1]
		draw_string(_font, Vector2(x, y + 12.0), nxt, HORIZONTAL_ALIGNMENT_RIGHT, int(w), 12, UIColors.TEXT_SECONDARY)
		y += 16.0
		_draw_meter(Rect2(x, y, w, 8.0), _character.get_xp_progress_percent() / 100.0, UIColors.GOLD)
		y += 12.0

	# Bonus XP modifiers, if any.
	if not _character.is_dead:
		var avg_level := GameState.party.get_average_level()
		if _character.level < avg_level:
			var catchup_pct := mini(50, 5 * (avg_level - _character.level))
			draw_string(_font, Vector2(x, y + 13.0), "Catch-up  +%d%% XP" % catchup_pct, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, UIColors.SUCCESS)
			y += ROW_H_SM
		if _character.rest_bonus_xp_multiplier > 1.0:
			var rest_pct := (_character.rest_bonus_xp_multiplier - 1.0) * 100.0
			draw_string(_font, Vector2(x, y + 13.0), "Rested  +%.0f%% XP" % rest_pct, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, UIColors.SUCCESS)
			y += ROW_H_SM

	return y


func _draw_labeled_meter(x: float, y: float, w: float, label: String, cur: int, maxv: int, color: Color, delta: int) -> float:
	draw_string(_font_semibold, Vector2(x, y + 13.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIColors.TEXT_SECONDARY)
	var val := "%d / %d" % [cur, maxv]
	var vw := _font.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var dstr := ""
	var dw := 0.0
	if delta != 0:
		dstr = "  %+d" % delta
		dw = _font.get_string_size(dstr, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(_font, Vector2(x + w - vw - dw, y + 13.0), val, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIColors.TEXT_PRIMARY)
	if delta != 0:
		draw_string(_font, Vector2(x + w - dw, y + 13.0), dstr, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIColors.SUCCESS if delta > 0 else UIColors.DANGER)
	y += 17.0
	var pct := float(cur) / float(maxv) if maxv > 0 else 0.0
	var fill := color
	if pct < 0.25:
		fill = UIColors.DANGER
	elif pct < 0.5:
		fill = UIColors.WARNING
	_draw_meter(Rect2(x, y, w, METER_H), pct, fill)
	return y + METER_H


func _draw_combat(x: float, y: float, w: float) -> float:
	y = _section("COMBAT", x, y, w)

	var wpn := _character.weapon_dice
	if _preview_deltas.has("weapon_dice"):
		wpn += "  →  %s" % _preview_deltas["weapon_dice"]
	_draw_kv(x, y, w, "Weapon", wpn, UIColors.TEXT_PRIMARY)
	y += ROW_H

	var half := w / 2.0
	_draw_kv_delta(x, y, half - 6.0, "Damage", "%+d" % _character.damage_bonus, _preview_deltas.get("damage", 0))
	_draw_kv_delta(x + half, y, half, "Defense", str(_character.defense), _preview_deltas.get("defense", 0))
	y += ROW_H
	_draw_kv_delta(x, y, half - 6.0, "Accuracy", "%+d" % _character.accuracy, _preview_deltas.get("accuracy", 0))
	_draw_kv_delta(x + half, y, half, "Evasion", str(_character.evasion), _preview_deltas.get("evasion", 0))
	y += ROW_H

	if _character.death_count > 0:
		_draw_kv(x, y, w, "Deaths", str(_character.death_count), UIColors.TEXT_DANGER)
		y += ROW_H

	return y


func _draw_kv(x: float, y: float, w: float, key: String, val: String, val_color: Color) -> void:
	draw_string(_font, Vector2(x, y + 14.0), key, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, UIColors.TEXT_SECONDARY)
	draw_string(_font_semibold, Vector2(x, y + 14.0), val, HORIZONTAL_ALIGNMENT_RIGHT, int(w), FONT_SIZE_SM, val_color)


func _draw_kv_delta(x: float, y: float, w: float, key: String, val: String, delta: int) -> void:
	draw_string(_font, Vector2(x, y + 14.0), key, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, UIColors.TEXT_SECONDARY)
	var vw := _font_semibold.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM).x
	var dstr := ""
	var dw := 0.0
	if delta != 0:
		dstr = " %+d" % delta
		dw = _font.get_string_size(dstr, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM).x
	draw_string(_font_semibold, Vector2(x + w - vw - dw, y + 14.0), val, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, UIColors.TEXT_PRIMARY)
	if delta != 0:
		draw_string(_font, Vector2(x + w - dw, y + 14.0), dstr, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, UIColors.SUCCESS if delta > 0 else UIColors.DANGER)


# === ZONE B: ATTRIBUTES + STORY ===


func _draw_attributes(x: float, y: float, w: float) -> float:
	y = _section("ATTRIBUTES", x, y, w)

	var keys: Array[String] = ["strength", "intelligence", "piety", "vitality", "agility", "luck"]
	var rows: Array[Array] = [
		["STR", _character.strength, _character.peak_strength],
		["INT", _character.intelligence, _character.peak_intelligence],
		["PIE", _character.piety, _character.peak_piety],
		["VIT", _character.vitality, _character.peak_vitality],
		["AGI", _character.agility, _character.peak_agility],
		["LCK", _character.luck, _character.peak_luck],
	]

	var label_w := 34.0
	var value_w := 30.0
	var bar_x := x + label_w
	var bar_w := w - label_w - value_w - 12.0

	for i in range(rows.size()):
		var label: String = rows[i][0]
		var value: int = rows[i][1]
		var peak: int = rows[i][2]

		draw_string(_font_semibold, Vector2(x, y + 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, UIColors.TEXT_SECONDARY)

		var meter := Rect2(bar_x, y + 2.0, bar_w, ATTR_METER_H)
		var fill := clampf((float(value) - ATTR_MIN) / (ATTR_MAX - ATTR_MIN), 0.0, 1.0)
		var color := UIColors.INFO
		if value > peak:
			color = UIColors.SUCCESS
		elif value < peak:
			color = UIColors.DANGER
		_draw_meter(meter, fill, color)

		# Peak marker tick (where this stat caps out at full health/age).
		var peak_fill := clampf((float(peak) - ATTR_MIN) / (ATTR_MAX - ATTR_MIN), 0.0, 1.0)
		var tick_x := bar_x + bar_w * peak_fill
		draw_line(Vector2(tick_x, meter.position.y - 1.0), Vector2(tick_x, meter.position.y + ATTR_METER_H + 1.0), UIColors.TEXT_TITLE, 1.0)

		var vstr := str(value)
		var vw := _font_semibold.get_string_size(vstr, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM).x
		var delta: int = _preview_deltas.get(keys[i], 0)
		if delta != 0:
			var dstr := " %+d" % delta
			var dw := _font.get_string_size(dstr, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM).x
			var start := x + w - vw - dw
			draw_string(_font_semibold, Vector2(start, y + 14.0), vstr, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, UIColors.TEXT_PRIMARY)
			draw_string(_font, Vector2(start + vw, y + 14.0), dstr, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, UIColors.SUCCESS if delta > 0 else UIColors.DANGER)
		else:
			draw_string(_font_semibold, Vector2(x + w - vw, y + 14.0), vstr, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, UIColors.TEXT_PRIMARY)

		y += ATTR_ROW_H

	return y


func _draw_story_summary(x: float, y: float, w: float) -> float:
	y = _section("STORY", x, y, w)

	var personality := _get_personality_summary()
	if not personality.is_empty():
		y = _draw_story_line(x, y, w, "", personality, _story_focus == StoryFocus.PERSONALITY)
	var bonds := _get_bond_summary()
	if not bonds.is_empty():
		y = _draw_story_line(x, y, w, "Bonds:  ", bonds, _story_focus == StoryFocus.BONDS)
	var marks := _get_mark_summary()
	if not marks.is_empty():
		y = _draw_story_line(x, y, w, "Marks:  ", marks, _story_focus == StoryFocus.MARKS)

	return y


func _draw_story_line(x: float, y: float, w: float, prefix: String, body: String, focused: bool) -> float:
	var color := UIColors.TEXT_SECONDARY
	if focused:
		var hl := StyleBoxFlat.new()
		hl.bg_color = UIColors.SURFACE_SELECTED
		hl.set_corner_radius_all(4)
		draw_style_box(hl, Rect2(x - 5.0, y - 1.0, w + 8.0, ROW_H_SM))
		draw_rect(Rect2(x - 5.0, y - 1.0, 2.0, ROW_H_SM), UIColors.ACCENT)
		color = UIColors.TEXT_PRIMARY
	draw_string(_font, Vector2(x, y + 13.0), prefix + body, HORIZONTAL_ALIGNMENT_LEFT, int(w), FONT_SIZE_SM, color)
	return y + ROW_H_SM


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


# === COLUMN 3: EQUIPMENT ===


func _draw_equipment(x: float, y: float, w: float) -> float:
	var header := "EQUIPMENT"
	var accent := UIColors.TITLE_GOLD_DIM
	if _equip_mode == EquipMode.SLOT_SELECT:
		header = "EQUIP — SELECT SLOT"
		accent = UIColors.ACCENT
	y = _section(header, x, y, w, accent)

	for i in range(SLOT_NAMES.size()):
		var selected := (_equip_mode == EquipMode.SLOT_SELECT and i == _selected_slot)
		var item: Item = _character.get(SLOT_FIELDS[i])
		y = _draw_equip_row(x, y, w, SLOT_NAMES[i], item, selected)

	return y


func _draw_equip_row(x: float, y: float, w: float, label: String, item: Item, selected: bool) -> float:
	if selected:
		var hl := StyleBoxFlat.new()
		hl.bg_color = UIColors.SURFACE_SELECTED
		hl.set_corner_radius_all(4)
		draw_style_box(hl, Rect2(x - 5.0, y - 1.0, w + 10.0, ROW_H + 1.0))
		draw_rect(Rect2(x - 5.0, y - 1.0, 2.0, ROW_H + 1.0), UIColors.ACCENT)

	var label_color := UIColors.ACCENT if selected else UIColors.TEXT_MUTED
	draw_string(_font, Vector2(x, y + 15.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_SM, label_color)

	var name_x := x + 80.0
	var item_name := item.get_display_name() if item else "—"
	var name_color := UIColors.TEXT_MUTED
	if item:
		name_color = UIColors.TEXT_DANGER if item.is_cursed else UIColors.TEXT_PRIMARY
	draw_string(_font_semibold if item else _font, Vector2(name_x, y + 15.0), item_name, HORIZONTAL_ALIGNMENT_LEFT, int(w - 80.0), FONT_SIZE_SM, name_color)
	return y + ROW_H


func _draw_equip_slot_header(x: float, y: float, w: float) -> float:
	y = _section("EQUIP — SELECT ITEM", x, y, w, UIColors.ACCENT)
	var item: Item = _character.get(SLOT_FIELDS[_selected_slot])
	y = _draw_equip_row(x, y, w, SLOT_NAMES[_selected_slot], item, true)
	return y


func _draw_equip_items(x: float, y: float, w: float, bottom: float) -> void:
	var total := 1 + _available_items.size()
	_equip_visible_rows = maxi(int((bottom - y) / ROW_H), 2)

	if _available_items.is_empty():
		y = _draw_equip_item_row(x, y, w, "Unequip", _selected_item == 0, true)
		draw_string(_font, Vector2(x + 4.0, y + 15.0), "(no items for this slot)", HORIZONTAL_ALIGNMENT_LEFT, int(w), FONT_SIZE_SM, UIColors.TEXT_MUTED)
		return

	var visible_end := mini(_item_scroll_offset + _equip_visible_rows, total)
	if _item_scroll_offset > 0:
		draw_string(_font, Vector2(x + w - 14.0, y - 3.0), "▲", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIColors.TEXT_MUTED)

	for idx in range(_item_scroll_offset, visible_end):
		var selected := (idx == _selected_item)
		if idx == 0:
			y = _draw_equip_item_row(x, y, w, "Unequip", selected, true)
		else:
			var item: Item = _available_items[idx - 1]
			var can_equip: bool = _can_equip_flags[idx - 1] if (idx - 1) < _can_equip_flags.size() else true
			var nm := item.get_display_name()
			if not can_equip:
				nm += "   ✕"
			y = _draw_equip_item_row(x, y, w, nm, selected, can_equip)

	if visible_end < total:
		draw_string(_font, Vector2(x + w - 14.0, y - ROW_H + 3.0), "▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIColors.TEXT_MUTED)


func _draw_equip_item_row(x: float, y: float, w: float, text: String, selected: bool, enabled: bool) -> float:
	if selected:
		var hl := StyleBoxFlat.new()
		hl.bg_color = UIColors.SURFACE_SELECTED
		hl.set_corner_radius_all(4)
		draw_style_box(hl, Rect2(x - 5.0, y - 1.0, w + 10.0, ROW_H + 1.0))
		draw_rect(Rect2(x - 5.0, y - 1.0, 2.0, ROW_H + 1.0), UIColors.ACCENT)
	var color := UIColors.TEXT_PRIMARY if enabled else UIColors.TEXT_DISABLED
	if selected and enabled:
		color = UIColors.TEXT_TITLE
	draw_string(_font, Vector2(x + 4.0, y + 15.0), text, HORIZONTAL_ALIGNMENT_LEFT, int(w - 8.0), FONT_SIZE_SM, color)
	return y + ROW_H


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
