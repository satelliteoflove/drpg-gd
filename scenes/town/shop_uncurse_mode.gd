class_name ShopUncurseMode
extends RefCounted

var shop = null

var uncurse_items: Array[Dictionary] = []


func init(p_shop: Control) -> void:
	shop = p_shop


func reset() -> void:
	uncurse_items.clear()


func populate() -> void:
	uncurse_items.clear()

	if GameState.party == null or GameState.party.is_empty():
		var label := Label.new()
		label.text = "(No party members)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop.items_list.add_child(label)
		return

	var found_any := false
	for member in GameState.party.get_members():
		for slot_type in member.get_cursed_slots():
			var item: Item = member.get_equipped_item(slot_type)
			if item:
				found_any = true
				uncurse_items.append({"member": member, "slot": slot_type, "item": item})
				shop.displayed_items.append(item)
				var btn := _create_uncurse_button(uncurse_items.size() - 1, member, item)
				shop.items_list.add_child(btn)
				shop.item_buttons.append(btn)

	if not found_any:
		var label := Label.new()
		label.text = "(No cursed equipment)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop.items_list.add_child(label)


func get_info_suffix(item: Item) -> String:
	var text := "\n\n[color=#%s]Uncurse cost: %d gold[/color]" % [UIColors.TEXT_DANGER.to_html(false), item.buy_price]
	text += "\n[color=#%s]Item will be destroyed[/color]" % UIColors.TEXT_MUTED.to_html(false)
	return text


func get_help_text() -> String:
	var h_nav := KeyBindingHelper.get_horizontal_help()
	var v_nav := KeyBindingHelper.get_nav_help()
	var confirm := KeyBindingHelper.get_confirm_help()
	var cancel := KeyBindingHelper.get_cancel_help()
	return "%s mode | %s | %s: Uncurse | %s" % [h_nav, v_nav, confirm.split(":")[0], cancel]


func get_mode_message() -> String:
	return "Select cursed equipment to remove."


func is_dialog_active() -> bool:
	return false


func handle_input(_event: InputEvent) -> bool:
	return false


func handle_cancel() -> bool:
	return false


func handle_special_input(_event: InputEvent) -> bool:
	return false


func handle_confirm() -> bool:
	return false


func _create_uncurse_button(index: int, member: Character, item: Item) -> Button:
	var cost := item.buy_price
	var can_afford := GameState.party.has_gold(cost)
	var b := ItemView.badge(item)
	var btn := MenuListRow.create({
		"badge": b["text"],
		"badge_color": UIColors.TEXT_DANGER,
		"title": "%s's %s" % [member.character_name, item.get_display_name()],
		"title_color": UIColors.TEXT_DANGER,
		"subtitle": "Cursed " + item.get_type_name(),
		"chips": [{"text": "%d g" % cost,
			"fg": UIColors.GOLD if can_afford else UIColors.TEXT_DANGER, "bg": UIColors.SURFACE_SELECTED}],
		"dim": not can_afford,
	})
	if not can_afford:
		btn.disabled = true
		btn.tooltip_text = "Not enough gold"
	btn.pressed.connect(_on_uncurse_item.bind(index))
	return btn


func _on_uncurse_item(index: int) -> void:
	if index < 0 or index >= uncurse_items.size():
		return

	var data: Dictionary = uncurse_items[index]
	var member: Character = data["member"]
	var slot: Item.ItemType = data["slot"]
	var item: Item = data["item"]

	var cost := item.buy_price
	if not GameState.party.spend_gold(cost):
		shop.message_label.text = "Not enough gold!"
		return

	member.force_unequip_slot(slot)
	shop.message_label.text = "Uncursed and destroyed %s from %s for %d gold." % [item.get_display_name(), member.character_name, cost]

	shop.refresh_display()
	if shop.nav and not shop.item_buttons.is_empty():
		shop.nav.select(0)
