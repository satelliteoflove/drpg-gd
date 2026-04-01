class_name ShopBuyMode
extends RefCounted

enum BuyState { BROWSING, QUANTITY_SELECT, EQUIP_SELECT }

var shop: Control
var buy_state: BuyState = BuyState.BROWSING

var selected_item: Item = null
var selected_quantity: int = 1
var max_quantity: int = 1

var equip_nav: MenuNavigator = null
var equip_buttons: Array[Button] = []
var selected_members: Array[Character] = []


func init(p_shop: Control) -> void:
	shop = p_shop


func reset() -> void:
	buy_state = BuyState.BROWSING
	selected_item = null
	selected_quantity = 1
	max_quantity = 1


func populate() -> void:
	var shop_items := ShopItems.get_shop_inventory()
	shop_items.sort_custom(_sort_by_type_and_price)

	for item in shop_items:
		shop.displayed_items.append(item)
		var btn := _create_buy_button(item)
		shop.items_list.add_child(btn)
		shop.item_buttons.append(btn)

	if shop.item_buttons.is_empty():
		var label := Label.new()
		label.text = "(Shop is empty)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop.items_list.add_child(label)


func get_info_suffix(item: Item) -> String:
	return "\n\n[color=yellow]Buy: %d gold[/color]" % item.buy_price


func get_help_text() -> String:
	var h_nav := KeyBindingHelper.get_horizontal_help()
	var v_nav := KeyBindingHelper.get_nav_help()
	var confirm := KeyBindingHelper.get_confirm_help()
	var cancel := KeyBindingHelper.get_cancel_help()
	return "%s mode | %s | %s: Buy | %s" % [h_nav, v_nav, confirm.split(":")[0], cancel]


func get_mode_message() -> String:
	return "Select an item to buy."


func is_dialog_active() -> bool:
	return buy_state != BuyState.BROWSING


func handle_input(event: InputEvent) -> bool:
	if buy_state == BuyState.QUANTITY_SELECT:
		_handle_quantity_input(event)
		return true
	if buy_state == BuyState.EQUIP_SELECT:
		_handle_equip_input(event)
		return true
	return false


func handle_cancel() -> bool:
	return false


func handle_special_input(_event: InputEvent) -> bool:
	return false


func handle_confirm() -> bool:
	return false


func _create_buy_button(item: Item) -> Button:
	var btn := Button.new()
	btn.text = "%s - %d gold" % [item.item_name, item.buy_price]
	btn.custom_minimum_size = Vector2(400, 32)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_buy_item.bind(item))

	var can_afford := GameState.party.has_gold(item.buy_price)
	var has_space := not GameState.party.inventory.is_full()

	if not can_afford:
		btn.disabled = true
		btn.modulate = UIColors.MODULATE_DISABLED
		btn.tooltip_text = "Not enough gold"
	elif not has_space and not item.is_equipment():
		btn.disabled = true
		btn.modulate = UIColors.MODULATE_DISABLED
		btn.tooltip_text = "Inventory full"

	return btn


func _sort_by_type_and_price(a: Item, b: Item) -> bool:
	if a.item_type != b.item_type:
		return a.item_type < b.item_type
	return a.buy_price < b.buy_price


func _on_buy_item(item: Item) -> void:
	if not GameState.party.has_gold(item.buy_price):
		shop.message_label.text = "Not enough gold!"
		return

	selected_item = item

	if item.item_type == Item.ItemType.CONSUMABLE:
		_show_quantity_dialog(item)
	elif item.is_equipment():
		_show_equip_dialog(item)
	else:
		_buy_to_inventory(item, 1)


func _show_quantity_dialog(item: Item) -> void:
	buy_state = BuyState.QUANTITY_SELECT
	selected_quantity = 1

	var max_afford := GameState.party.gold / item.buy_price
	var space_left := Inventory.MAX_SLOTS - GameState.party.inventory.size()
	max_quantity = mini(max_afford, space_left)
	max_quantity = maxi(1, max_quantity)

	shop.quantity_title.text = "Buy %s" % item.item_name
	_update_quantity_display()
	shop.modal_overlay.visible = true
	shop.quantity_dialog.visible = true
	shop.confirm_quantity.grab_focus()


func _update_quantity_display() -> void:
	shop.quantity_value.text = str(selected_quantity)
	shop.total_label.text = "Total: %d gold" % (selected_quantity * selected_item.buy_price)

	shop.minus_button.disabled = (selected_quantity <= 1)
	shop.plus_button.disabled = (selected_quantity >= max_quantity)


func _on_quantity_minus() -> void:
	if selected_quantity > 1:
		selected_quantity -= 1
		_update_quantity_display()


func _on_quantity_plus() -> void:
	if selected_quantity < max_quantity:
		selected_quantity += 1
		_update_quantity_display()


func _on_quantity_confirm() -> void:
	shop.modal_overlay.visible = false
	shop.quantity_dialog.visible = false
	buy_state = BuyState.BROWSING
	_buy_to_inventory(selected_item, selected_quantity)
	selected_item = null


func _on_quantity_cancel() -> void:
	shop.modal_overlay.visible = false
	shop.quantity_dialog.visible = false
	buy_state = BuyState.BROWSING
	selected_item = null
	if shop.nav and not shop.item_buttons.is_empty():
		shop.nav.update_focus()


func _show_equip_dialog(item: Item) -> void:
	buy_state = BuyState.EQUIP_SELECT
	shop.equip_item_name.text = "%s - %d gold" % [item.item_name, item.buy_price]

	for child in shop.equip_options.get_children():
		child.queue_free()
	equip_buttons.clear()
	selected_members.clear()

	var inv_btn := Button.new()
	inv_btn.text = "Add to Inventory"
	inv_btn.custom_minimum_size = Vector2(0, 32)

	if GameState.party.inventory.is_full():
		inv_btn.disabled = true
		inv_btn.modulate = UIColors.MODULATE_DISABLED
		inv_btn.tooltip_text = "Inventory full"
	inv_btn.pressed.connect(_on_equip_to_inventory)
	shop.equip_options.add_child(inv_btn)
	equip_buttons.append(inv_btn)

	for member in GameState.party.get_members():
		var btn := Button.new()
		var can_equip := member.can_equip_item(item)
		var old_item: Item = member.get_equipped_item(item.item_type)

		var will_overflow := false
		if old_item and GameState.party.inventory.is_full():
			will_overflow = true

		if can_equip and not will_overflow:
			var diff := shop.get_stat_diff(old_item, item)
			btn.text = "Equip on %s (%s)" % [member.character_name, diff]
		elif will_overflow:
			btn.text = "%s (inventory full for old item)" % member.character_name
			btn.disabled = true
			btn.modulate = UIColors.MODULATE_DISABLED
		else:
			btn.text = "%s (cannot equip)" % member.character_name
			btn.disabled = true
			btn.modulate = UIColors.MODULATE_DISABLED

		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_equip_to_member.bind(member))
		shop.equip_options.add_child(btn)
		equip_buttons.append(btn)
		selected_members.append(member)

	equip_nav = MenuNavigator.new()
	equip_nav.setup(equip_buttons, 0)

	shop.modal_overlay.visible = true
	shop.equip_dialog.visible = true


func _on_equip_to_inventory() -> void:
	shop.modal_overlay.visible = false
	shop.equip_dialog.visible = false
	buy_state = BuyState.BROWSING
	_buy_to_inventory(selected_item, 1)
	selected_item = null


func _on_equip_to_member(member: Character) -> void:
	if not member.can_equip_item(selected_item):
		return

	var old_item: Item = member.get_equipped_item(selected_item.item_type)
	if old_item and GameState.party.inventory.is_full():
		shop.message_label.text = "Inventory full! Cannot store old equipment."
		return

	if not GameState.party.spend_gold(selected_item.buy_price):
		shop.message_label.text = "Not enough gold!"
		return

	var new_item := selected_item.duplicate() as Item
	var unequipped: Item = member.equip_item(new_item)

	if unequipped:
		GameState.party.inventory.add_item(unequipped, 1)

	shop.message_label.text = "Equipped %s on %s for %d gold." % [selected_item.item_name, member.character_name, selected_item.buy_price]

	shop.modal_overlay.visible = false
	shop.equip_dialog.visible = false
	buy_state = BuyState.BROWSING
	selected_item = null
	shop.refresh_display()


func _on_equip_cancel() -> void:
	shop.modal_overlay.visible = false
	shop.equip_dialog.visible = false
	buy_state = BuyState.BROWSING
	selected_item = null
	if shop.nav and not shop.item_buttons.is_empty():
		shop.nav.update_focus()


func _buy_to_inventory(item: Item, quantity: int) -> void:
	var total_cost := item.buy_price * quantity

	if not GameState.party.has_gold(total_cost):
		shop.message_label.text = "Not enough gold!"
		return

	GameState.party.spend_gold(total_cost)

	var added := 0
	for i in range(quantity):
		var new_item := item.duplicate() as Item
		var leftover := GameState.party.inventory.add_item(new_item, 1)
		if leftover == 0:
			added += 1
		else:
			GameState.party.add_gold(item.buy_price)
			break

	if added == quantity:
		shop.message_label.text = "Bought %d %s for %d gold." % [quantity, item.item_name, total_cost]
	elif added > 0:
		shop.message_label.text = "Bought %d %s (inventory full)." % [added, item.item_name]
	else:
		shop.message_label.text = "Inventory is full!"

	shop.refresh_display()


func _handle_quantity_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		_on_quantity_cancel()
	elif event.is_action_pressed("menu_confirm"):
		_on_quantity_confirm()
	elif event.is_action_pressed("menu_left"):
		_on_quantity_minus()
	elif event.is_action_pressed("menu_right"):
		_on_quantity_plus()


func _handle_equip_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		_on_equip_cancel()
	elif equip_nav:
		equip_nav.handle_input(event)


func connect_buttons() -> void:
	shop.confirm_quantity.pressed.connect(_on_quantity_confirm)
	shop.cancel_quantity.pressed.connect(_on_quantity_cancel)
	shop.minus_button.pressed.connect(_on_quantity_minus)
	shop.plus_button.pressed.connect(_on_quantity_plus)
	shop.cancel_equip.pressed.connect(_on_equip_cancel)
