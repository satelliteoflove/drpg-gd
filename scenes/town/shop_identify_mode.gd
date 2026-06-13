class_name ShopIdentifyMode
extends RefCounted

var shop = null


func init(p_shop: Control) -> void:
	shop = p_shop


func reset() -> void:
	pass


func populate() -> void:
	if GameState.party.inventory == null or GameState.party.inventory.is_empty():
		var label := Label.new()
		label.text = "(No items to identify)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop.items_list.add_child(label)
		return

	var found_any := false
	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		if item == null:
			continue
		if item.is_identified:
			continue

		found_any = true
		shop.displayed_items.append(item)
		var btn := _create_identify_button(i, item)
		shop.items_list.add_child(btn)
		shop.item_buttons.append(btn)

	if not found_any:
		var label := Label.new()
		label.text = "(No unidentified items)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop.items_list.add_child(label)


func get_info_suffix(item: Item) -> String:
	var cost := item.buy_price / 2
	return "\n\n[color=yellow]Identify cost: %d gold[/color]" % cost


func get_help_text() -> String:
	var h_nav := KeyBindingHelper.get_horizontal_help()
	var v_nav := KeyBindingHelper.get_nav_help()
	var confirm := KeyBindingHelper.get_confirm_help()
	var cancel := KeyBindingHelper.get_cancel_help()
	return "%s mode | %s | %s: Identify | %s" % [h_nav, v_nav, confirm.split(":")[0], cancel]


func get_mode_message() -> String:
	return "Select an item to identify."


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


func _create_identify_button(index: int, item: Item) -> Button:
	var cost := item.buy_price / 2
	var can_afford := GameState.party.has_gold(cost)
	var chips: Array = [{"text": "%d g" % cost,
		"fg": UIColors.INFO if can_afford else UIColors.TEXT_DANGER, "bg": UIColors.SURFACE_SELECTED}]
	var btn: Button = shop.make_item_row(item, chips, not can_afford)
	if not can_afford:
		btn.disabled = true
		btn.tooltip_text = "Not enough gold"
	btn.pressed.connect(_on_identify_item.bind(index, item))
	return btn


func _on_identify_item(_index: int, item: Item) -> void:
	var cost := item.buy_price / 2
	if not GameState.party.spend_gold(cost):
		shop.message_label.text = "Not enough gold!"
		return

	item.is_identified = true
	shop.message_label.text = "Identified %s for %d gold." % [item.get_display_name(), cost]

	shop.refresh_display()
	if shop.nav and not shop.item_buttons.is_empty():
		shop.nav.select(0)
