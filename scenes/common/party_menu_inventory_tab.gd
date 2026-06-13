class_name PartyMenuInventoryTab
extends RefCounted

var nav: MenuNavigator = null
var target_nav: MenuNavigator = null
var buttons: Array[Button] = []
var target_buttons: Array[Button] = []
var row_slots: Array[int] = []  # parallel to `buttons`: row index -> inventory slot
var selected_item: Item = null
var showing_targets: bool = false

var inv_list: VBoxContainer
var inv_targets: VBoxContainer
var inv_targets_panel: PanelContainer
var info_label: RichTextLabel


func init(p_inv_list: VBoxContainer, p_inv_targets: VBoxContainer, p_inv_targets_panel: PanelContainer, p_info_label: RichTextLabel) -> void:
	inv_list = p_inv_list
	inv_targets = p_inv_targets
	inv_targets_panel = p_inv_targets_panel
	info_label = p_info_label


func refresh(restore_index: int = 0) -> void:
	_refresh_items(restore_index)
	_refresh_targets()
	_update_info()


func _refresh_items(restore_index: int = 0) -> void:
	for child in inv_list.get_children():
		child.queue_free()
	buttons.clear()
	row_slots.clear()

	if GameState.party == null or GameState.party.inventory == null or GameState.party.inventory.is_empty():
		var label := Label.new()
		label.text = "Your pack is empty.  Visit the Shop to stock up."
		label.theme_type_variation = &"MutedLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inv_list.add_child(label)
		info_label.text = "[i]Nothing to use right now.[/i]"
		return

	# Gather everything, then group + sort so items are easy to find.
	var entries: Array = []
	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		if item == null:
			continue
		entries.append({
			"slot": i,
			"item": item,
			"qty": GameState.party.inventory.get_quantity_at(i),
			"group": _item_group(item),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["group"] != b["group"]:
			return a["group"] < b["group"]
		return a["item"].get_display_name().naturalnocasecmp_to(b["item"].get_display_name()) < 0)

	var last_group := -1
	for e in entries:
		if e["group"] != last_group:
			_add_group_header(_group_title(e["group"]), last_group == -1)
			last_group = e["group"]
		var row := MenuListRow.create(_item_row_cfg(e["item"], e["qty"]))
		row.pressed.connect(_on_item_selected.bind(e["slot"], e["item"]))
		inv_list.add_child(row)
		buttons.append(row)
		row_slots.append(e["slot"])

	nav = MenuNavigator.new()
	nav.setup(buttons, clampi(restore_index, 0, maxi(buttons.size() - 1, 0)))
	nav.selection_changed.connect(_on_selection_changed)

	if not showing_targets:
		nav.update_focus()


func _item_group(item: Item) -> int:
	if item.item_type == Item.ItemType.CONSUMABLE:
		return 0
	if item.is_equipment():
		return 1
	return 2


func _group_title(group: int) -> String:
	match group:
		0: return "CONSUMABLES"
		1: return "EQUIPMENT"
	return "OTHER"


func _add_group_header(title: String, first: bool) -> void:
	if not first:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inv_list.add_child(spacer)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", UIColors.TITLE_GOLD_DIM)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_list.add_child(lbl)


func _item_row_cfg(item: Item, qty: int) -> Dictionary:
	var badge := _item_badge(item)
	var subtitle := item.get_type_name()
	var stats := item.get_stats_text()
	if item.is_identified and stats != "" and stats != "No special properties":
		subtitle += "  ·  " + stats
	return {
		"badge": badge["text"],
		"badge_color": badge["color"],
		"title": item.get_display_name(),
		"title_color": (UIColors.TEXT_DANGER if (item.is_identified and item.is_cursed) else UIColors.TEXT_PRIMARY),
		"subtitle": subtitle,
		"chips": _item_chips(item, qty),
	}


func _item_badge(item: Item) -> Dictionary:
	return ItemView.badge(item)


func _item_chips(item: Item, qty: int) -> Array:
	var chips: Array = []
	if qty > 1:
		chips.append({"text": "×%d" % qty, "fg": UIColors.TEXT_SECONDARY, "bg": UIColors.SURFACE_SELECTED})
	if not item.is_identified:
		if GameState.party and GameState.party.has_living_bishop():
			chips.append({"text": "IDENTIFY?", "fg": UIColors.INFO, "bg": UIColors.SURFACE_SELECTED})
		return chips
	if item.is_cursed:
		chips.append({"text": "CURSED", "fg": UIColors.TEXT_DANGER, "bg": Color(0.28, 0.10, 0.12)})
	if item.item_type == Item.ItemType.CONSUMABLE and (item.heal_amount > 0 or item.mp_restore > 0 or not item.cures_status.is_empty()):
		chips.append({"text": "USE", "fg": UIColors.SUCCESS, "bg": Color(0.12, 0.22, 0.14)})
	elif item.is_equipment():
		chips.append({"text": "EQUIP ›", "fg": UIColors.TEXT_MUTED, "bg": UIColors.SURFACE_SELECTED})
	return chips


func _refresh_targets() -> void:
	for child in inv_targets.get_children():
		child.queue_free()
	target_buttons.clear()

	inv_targets_panel.visible = showing_targets

	if not showing_targets or selected_item == null:
		return

	for member in GameState.party.get_members():
		var usable := _can_use_item_on(selected_item, member)
		var chips: Array = [{
			"text": "%d/%d HP" % [member.current_hp, member.max_hp],
			"fg": UIColors.HP_GREEN, "bg": UIColors.SURFACE_SELECTED}]
		if selected_item and selected_item.mp_restore > 0 and member.max_mp > 0:
			chips.append({"text": "%d/%d MP" % [member.current_mp, member.max_mp],
				"fg": UIColors.MP_BLUE, "bg": UIColors.SURFACE_SELECTED})
		var subtitle := "Fallen" if member.is_dead else "L%d %s" % [member.level, CharacterEnums.get_class_name(member.character_class)]
		var btn := MenuListRow.create({
			"badge": member.character_name.substr(0, 1).to_upper(),
			"badge_color": UIColors.class_color(member.character_class),
			"title": member.character_name,
			"subtitle": subtitle,
			"chips": chips,
			"dim": not usable,
		})
		if not usable:
			btn.disabled = true
		btn.pressed.connect(_on_target_selected.bind(member))
		inv_targets.add_child(btn)
		target_buttons.append(btn)

	target_nav = MenuNavigator.new()
	target_nav.setup(target_buttons, 0)
	target_nav.update_focus()


func _can_use_item_on(item: Item, character: Character) -> bool:
	if item == null or character.is_dead:
		return false
	if item.item_type != Item.ItemType.CONSUMABLE:
		return false
	if item.heal_amount > 0 and character.current_hp < character.max_hp:
		return true
	if item.mp_restore > 0 and character.current_mp < character.max_mp:
		return true
	for status in item.cures_status:
		if character.has_status(status):
			return true
	return false


func _on_item_selected(_slot_index: int, item: Item) -> void:
	if item.item_type != Item.ItemType.CONSUMABLE:
		info_label.text = "%s cannot be used here. Equip from Status tab." % item.get_display_name()
		return

	if item.heal_amount <= 0 and item.mp_restore <= 0 and item.cures_status.is_empty():
		info_label.text = "%s has no usable effect." % item.get_display_name()
		return

	selected_item = item
	showing_targets = true
	refresh()


func _on_target_selected(character: Character) -> void:
	if selected_item == null or not _can_use_item_on(selected_item, character):
		return

	var msg := "Used %s on %s. " % [selected_item.item_name, character.character_name]

	if selected_item.heal_amount > 0:
		var healed := character.heal(selected_item.heal_amount)
		msg += "Restored %d HP. " % healed

	if selected_item.mp_restore > 0:
		var restored := character.restore_mp(selected_item.mp_restore)
		msg += "Restored %d MP. " % restored

	GameState.party.inventory.remove_item(selected_item.id, 1)
	info_label.text = msg

	selected_item = null
	showing_targets = false
	refresh()


func _on_selection_changed(_index: int) -> void:
	_update_info()


func _update_info() -> void:
	if showing_targets:
		info_label.text = "Choose who drinks [b]%s[/b]." % selected_item.get_display_name()
		return

	if nav == null or buttons.is_empty():
		return

	var idx := nav.get_current_index()
	if idx < 0 or idx >= row_slots.size():
		return
	var slot: int = row_slots[idx]
	if GameState.party.inventory == null or slot >= GameState.party.inventory.size():
		return

	var item: Item = GameState.party.inventory.get_item_at(slot)
	if item == null:
		return
	info_label.text = _item_detail_bbcode(item)


func _item_detail_bbcode(item: Item) -> String:
	var name_color := UIColors.rarity_color(item.rarity) if item.is_identified else Color(0.62, 0.48, 0.86)
	var text := "[b][color=#%s]%s[/color][/b]   [color=#%s]%s[/color]\n" % [
		name_color.to_html(false), item.get_display_name(),
		UIColors.TEXT_MUTED.to_html(false), item.get_type_name()]
	text += "[color=#%s]%s[/color]" % [UIColors.TEXT_SECONDARY.to_html(false), item.get_stats_text()]
	if item.is_identified and item.description != "":
		text += "\n[color=#%s]%s[/color]" % [UIColors.TEXT_MUTED.to_html(false), item.description]

	var hint := ""
	if not item.is_identified and GameState.party.has_living_bishop():
		hint = "Press [b]I[/b] to identify  ·  Bishop in party"
		text += "\n\n[color=#%s]%s[/color]" % [UIColors.INFO.to_html(false), hint]
	elif item.item_type == Item.ItemType.CONSUMABLE and (item.heal_amount > 0 or item.mp_restore > 0 or not item.cures_status.is_empty()):
		text += "\n\n[color=#%s]Press Enter to use[/color]" % UIColors.SUCCESS.to_html(false)
	elif item.is_equipment():
		text += "\n\n[color=#%s]Equip from the Status tab[/color]" % UIColors.TEXT_MUTED.to_html(false)
	return text


func handle_input(event: InputEvent) -> void:
	if not showing_targets and event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_I:
			try_identify_current_item()
			return

	var active_nav: MenuNavigator = target_nav if showing_targets else nav

	if active_nav == null:
		return

	active_nav.handle_input(event)


func handle_back() -> bool:
	if showing_targets:
		showing_targets = false
		selected_item = null
		refresh()
		return true
	return false


func try_identify_current_item() -> void:
	if nav == null or buttons.is_empty():
		return
	var idx := nav.get_current_index()
	if idx < 0 or idx >= row_slots.size():
		return
	var slot: int = row_slots[idx]
	if GameState.party.inventory == null or slot >= GameState.party.inventory.size():
		return
	var item: Item = GameState.party.inventory.get_item_at(slot)
	if item == null:
		return
	if item.is_identified:
		info_label.text = "%s is already identified." % item.get_display_name()
		return
	if not GameState.party.has_living_bishop():
		info_label.text = "No living Bishop in the party to identify items."
		return
	var new_item := item.duplicate() as Item
	new_item.is_identified = true
	var slot_dict := GameState.party.inventory.get_slot(slot)
	slot_dict["item"] = new_item
	info_label.text = "Identified:  [b]%s[/b]\n%s" % [new_item.get_display_name(), new_item.get_stats_text()]
	refresh(idx)
