class_name ShopSellMode
extends RefCounted

var shop = null

var sell_selected_indices: Array[int] = []
var sell_multi_select: bool = false


func init(p_shop: Control) -> void:
	shop = p_shop


func reset() -> void:
	sell_multi_select = false
	sell_selected_indices.clear()


func populate() -> void:
	if GameState.party.inventory == null or GameState.party.inventory.is_empty():
		var label := Label.new()
		label.text = "(No items to sell)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop.items_list.add_child(label)
		return

	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		var qty: int = GameState.party.inventory.get_quantity_at(i)
		if item:
			shop.displayed_items.append(item)
			var btn := _create_sell_button(i, item, qty)
			shop.items_list.add_child(btn)
			shop.item_buttons.append(btn)


func get_info_suffix(item: Item) -> String:
	return "\n\n[color=#%s]Sell: %d gold[/color]" % [UIColors.TEXT_HEALTHY.to_html(false), item.sell_price]


func get_help_text() -> String:
	var h_nav := KeyBindingHelper.get_horizontal_help()
	var v_nav := KeyBindingHelper.get_nav_help()
	var confirm := KeyBindingHelper.get_confirm_help()
	var cancel := KeyBindingHelper.get_cancel_help()
	if sell_multi_select:
		return "S: Toggle | A: Select all | %s: Sell | %s" % [confirm.split(":")[0], cancel]
	return "%s mode | %s | S: Multi | %s: Sell | %s" % [h_nav, v_nav, confirm.split(":")[0], cancel]


func get_mode_message() -> String:
	return "Select an item to sell."


func is_dialog_active() -> bool:
	return false


func handle_input(_event: InputEvent) -> bool:
	return false


func handle_cancel() -> bool:
	if sell_multi_select:
		sell_multi_select = false
		sell_selected_indices.clear()
		shop.refresh_display()
		return true
	return false


func handle_special_input(event: InputEvent) -> bool:
	if event.is_action_pressed("menu_select"):
		if not sell_multi_select:
			sell_multi_select = true
			shop.refresh_display()
			shop.update_help()
		elif shop.nav:
			_toggle_sell_selection(shop.nav.get_current_index())
		return true
	elif event.is_action_pressed("menu_select_all") and sell_multi_select:
		_select_all_for_sell()
		return true
	return false


func handle_confirm() -> bool:
	if sell_multi_select and not sell_selected_indices.is_empty():
		_sell_selected_items()
		return true
	return false


func _create_sell_button(index: int, item: Item, qty: int) -> Button:
	var chips: Array = []
	if sell_multi_select:
		var selected := index in sell_selected_indices
		chips.append({
			"text": "✓" if selected else "○",
			"fg": UIColors.SUCCESS if selected else UIColors.TEXT_MUTED,
			"bg": Color(0.12, 0.22, 0.14) if selected else UIColors.SURFACE_SELECTED})
	if qty > 1:
		chips.append({"text": "×%d" % qty, "fg": UIColors.TEXT_SECONDARY, "bg": UIColors.SURFACE_SELECTED})
	chips.append({"text": "%d g" % item.sell_price, "fg": UIColors.SUCCESS, "bg": UIColors.SURFACE_SELECTED})
	var btn: Button = shop.make_item_row(item, chips, false)
	btn.pressed.connect(_on_sell_item.bind(index, item))
	return btn


func _on_sell_item(slot_index: int, item: Item) -> void:
	if sell_multi_select:
		_toggle_sell_selection(slot_index)
		return

	var removed := GameState.party.inventory.remove_item(item.id, 1)
	if removed > 0:
		GameState.party.add_gold(item.sell_price)
		shop.message_label.text = "Sold %s for %d gold." % [item.item_name, item.sell_price]
	else:
		shop.message_label.text = "Failed to sell item."

	shop.refresh_display()
	if shop.nav and not shop.item_buttons.is_empty():
		shop.nav.select(0)


func _toggle_sell_selection(index: int) -> void:
	if index in sell_selected_indices:
		sell_selected_indices.erase(index)
	else:
		sell_selected_indices.append(index)
	shop.rebuild_items_keep_focus(index)


func _sell_selected_items() -> void:
	if sell_selected_indices.is_empty():
		shop.message_label.text = "No items selected to sell."
		return

	sell_selected_indices.sort()
	sell_selected_indices.reverse()

	var total_gold := 0
	var sold_count := 0

	for idx in sell_selected_indices:
		if idx >= shop.displayed_items.size():
			continue
		var item: Item = shop.displayed_items[idx]
		var removed := GameState.party.inventory.remove_item(item.id, 1)
		if removed > 0:
			total_gold += item.sell_price
			sold_count += 1

	GameState.party.add_gold(total_gold)
	shop.message_label.text = "Sold %d items for %d gold." % [sold_count, total_gold]

	sell_multi_select = false
	sell_selected_indices.clear()
	shop.refresh_display()
	if shop.nav and not shop.item_buttons.is_empty():
		shop.nav.select(0)


func _select_all_for_sell() -> void:
	sell_selected_indices.clear()
	for i in range(shop.displayed_items.size()):
		sell_selected_indices.append(i)
	shop.rebuild_items_keep_focus(shop.nav.get_current_index() if shop.nav else 0)
