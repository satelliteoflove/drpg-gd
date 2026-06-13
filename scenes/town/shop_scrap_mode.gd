class_name ShopScrapMode
extends RefCounted

var shop = null

var scrap_selected_indices: Array[int] = []
var scrap_multi_select: bool = false


func init(p_shop: Control) -> void:
	shop = p_shop


func reset() -> void:
	scrap_multi_select = false
	scrap_selected_indices.clear()


func populate() -> void:
	if GameState.party.inventory == null or GameState.party.inventory.is_empty():
		var label := Label.new()
		label.text = "(No items to scrap)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop.items_list.add_child(label)
		return

	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		var qty: int = GameState.party.inventory.get_quantity_at(i)
		if item:
			shop.displayed_items.append(item)
			var btn := _create_scrap_button(i, item, qty)
			shop.items_list.add_child(btn)
			shop.item_buttons.append(btn)


func get_info_suffix(_item: Item) -> String:
	return "\n\n[color=orange]Scrap yield: 1-2[/color]"


func get_help_text() -> String:
	var h_nav := KeyBindingHelper.get_horizontal_help()
	var v_nav := KeyBindingHelper.get_nav_help()
	var confirm := KeyBindingHelper.get_confirm_help()
	var cancel := KeyBindingHelper.get_cancel_help()
	if scrap_multi_select:
		return "S: Toggle | A: Select all | %s: Scrap | %s" % [confirm.split(":")[0], cancel]
	return "%s mode | %s | S: Multi | %s: Scrap | %s" % [h_nav, v_nav, confirm.split(":")[0], cancel]


func get_mode_message() -> String:
	return "Select an item to scrap."


func is_dialog_active() -> bool:
	return false


func handle_input(_event: InputEvent) -> bool:
	return false


func handle_cancel() -> bool:
	if scrap_multi_select:
		scrap_multi_select = false
		scrap_selected_indices.clear()
		shop.refresh_display()
		return true
	return false


func handle_special_input(event: InputEvent) -> bool:
	if event.is_action_pressed("menu_select"):
		if not scrap_multi_select:
			scrap_multi_select = true
			shop.refresh_display()
			shop.update_help()
		elif shop.nav:
			_toggle_scrap_selection(shop.nav.get_current_index())
		return true
	elif event.is_action_pressed("menu_select_all") and scrap_multi_select:
		_select_all_for_scrap()
		return true
	return false


func handle_confirm() -> bool:
	if scrap_multi_select and not scrap_selected_indices.is_empty():
		_scrap_selected_items()
		return true
	return false


func _create_scrap_button(index: int, item: Item, qty: int) -> Button:
	var chips: Array = []
	if scrap_multi_select:
		var selected := index in scrap_selected_indices
		chips.append({
			"text": "✓" if selected else "○",
			"fg": UIColors.SUCCESS if selected else UIColors.TEXT_MUTED,
			"bg": Color(0.12, 0.22, 0.14) if selected else UIColors.SURFACE_SELECTED})
	if qty > 1:
		chips.append({"text": "×%d" % qty, "fg": UIColors.TEXT_SECONDARY, "bg": UIColors.SURFACE_SELECTED})
	chips.append({"text": "1–2 scrap", "fg": UIColors.WARNING, "bg": UIColors.SURFACE_SELECTED})
	var btn: Button = shop.make_item_row(item, chips, false)
	btn.pressed.connect(_on_scrap_item.bind(index, item))
	return btn


func _on_scrap_item(index: int, item: Item) -> void:
	if scrap_multi_select:
		_toggle_scrap_selection(index)
		return

	var scrap_yield := randi_range(1, 2)
	var removed := GameState.party.inventory.remove_item(item.id, 1)
	if removed > 0:
		GameState.party.add_scrap(scrap_yield)
		shop.message_label.text = "Scrapped %s for %d scrap." % [item.get_display_name(), scrap_yield]
	else:
		shop.message_label.text = "Failed to scrap item."

	shop.refresh_display()
	if shop.nav and not shop.item_buttons.is_empty():
		shop.nav.select(0)


func _toggle_scrap_selection(index: int) -> void:
	if index in scrap_selected_indices:
		scrap_selected_indices.erase(index)
	else:
		scrap_selected_indices.append(index)
	shop.rebuild_items_keep_focus(index)


func _scrap_selected_items() -> void:
	if scrap_selected_indices.is_empty():
		shop.message_label.text = "No items selected to scrap."
		return

	scrap_selected_indices.sort()
	scrap_selected_indices.reverse()

	var total_scrap := 0
	var scrapped_count := 0

	for idx in scrap_selected_indices:
		if idx >= shop.displayed_items.size():
			continue
		var item: Item = shop.displayed_items[idx]
		var removed := GameState.party.inventory.remove_item(item.id, 1)
		if removed > 0:
			var scrap_yield := randi_range(1, 2)
			total_scrap += scrap_yield
			scrapped_count += 1

	GameState.party.add_scrap(total_scrap)
	shop.message_label.text = "Scrapped %d items for %d scrap." % [scrapped_count, total_scrap]

	scrap_multi_select = false
	scrap_selected_indices.clear()
	shop.refresh_display()
	if shop.nav and not shop.item_buttons.is_empty():
		shop.nav.select(0)


func _select_all_for_scrap() -> void:
	scrap_selected_indices.clear()
	for i in range(shop.displayed_items.size()):
		scrap_selected_indices.append(i)
	shop.rebuild_items_keep_focus(shop.nav.get_current_index() if shop.nav else 0)
