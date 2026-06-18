class_name ShopUpgradeMode
extends RefCounted

enum UpgradeState { BROWSING, STAT_SELECT }

var shop = null
var upgrade_state: UpgradeState = UpgradeState.BROWSING

var selected_item: Item = null
var selected_inventory_index: int = -1
var upgradeable_stats: Array[String] = []
var upgrade_stat_buttons: Array[Button] = []
var upgrade_stat_nav: MenuNavigator = null


func init(p_shop: Control) -> void:
	shop = p_shop


func reset() -> void:
	upgrade_state = UpgradeState.BROWSING
	selected_item = null
	selected_inventory_index = -1


func populate() -> void:
	if GameState.party.inventory == null or GameState.party.inventory.is_empty():
		var label := Label.new()
		label.text = "(No items to upgrade)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop.items_list.add_child(label)
		return

	var found_any := false
	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		if item == null:
			continue
		if not item.is_equipment():
			continue
		if not item.is_identified:
			continue
		if item.is_cursed:
			continue

		var upgradeable := item.get_upgradeable_stats()
		var can_upgrade_any := false
		for stat in upgradeable:
			if item.can_upgrade(stat):
				can_upgrade_any = true
				break

		if not can_upgrade_any:
			continue

		found_any = true
		shop.displayed_items.append(item)
		var btn := _create_upgrade_button(i, item)
		shop.items_list.add_child(btn)
		shop.item_buttons.append(btn)

	if not found_any:
		var label := Label.new()
		label.text = "(No upgradeable items)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop.items_list.add_child(label)


func get_info_suffix(item: Item) -> String:
	if item.is_equipment() and item.is_identified:
		var text := "\n\n[color=#%s]Upgradeable Stats:[/color]" % UIColors.ACCENT.to_html(false)
		for stat in item.get_upgradeable_stats():
			var current_level: int = item.upgrades.get(stat, 0)
			var cost := item.get_upgrade_cost(stat)
			var status := ""
			if current_level >= Item.UPGRADE_CAP:
				status = " [MAX]"
			elif not GameState.party.has_scrap(cost):
				status = " [Need %d scrap]" % cost
			text += "\n  %s +%d%s" % [stat.capitalize(), current_level, status]
		return text
	return ""


func get_help_text() -> String:
	var h_nav := KeyBindingHelper.get_horizontal_help()
	var v_nav := KeyBindingHelper.get_nav_help()
	var confirm := KeyBindingHelper.get_confirm_help()
	var cancel := KeyBindingHelper.get_cancel_help()
	return "%s mode | %s | %s: Upgrade | %s" % [h_nav, v_nav, confirm.split(":")[0], cancel]


func get_mode_message() -> String:
	return "Select an item to upgrade."


func is_dialog_active() -> bool:
	return upgrade_state != UpgradeState.BROWSING


func handle_input(event: InputEvent) -> bool:
	if upgrade_state == UpgradeState.STAT_SELECT:
		_handle_upgrade_input(event)
		return true
	return false


func handle_cancel() -> bool:
	return false


func handle_special_input(_event: InputEvent) -> bool:
	return false


func handle_confirm() -> bool:
	return false


func _create_upgrade_button(index: int, item: Item) -> Button:
	var chips: Array = []
	var pts := item.get_total_upgrade_points()
	if pts > 0:
		chips.append({"text": "+%d" % pts, "fg": UIColors.SUCCESS, "bg": UIColors.SURFACE_SELECTED})
	chips.append({"text": "UPGRADE", "fg": UIColors.INFO, "bg": UIColors.SURFACE_SELECTED})
	var btn: Button = shop.make_item_row(item, chips, false)
	btn.pressed.connect(_on_upgrade_item.bind(index, item))
	return btn


func _on_upgrade_item(index: int, item: Item) -> void:
	selected_item = item
	selected_inventory_index = index
	upgradeable_stats = item.get_upgradeable_stats()
	_show_upgrade_dialog(item)


func _show_upgrade_dialog(item: Item) -> void:
	upgrade_state = UpgradeState.STAT_SELECT
	shop.upgrade_item_name.text = item.get_display_name()

	for child in shop.upgrade_options.get_children():
		child.queue_free()
	upgrade_stat_buttons.clear()

	for stat in upgradeable_stats:
		if not item.can_upgrade(stat):
			continue

		var btn := Button.new()
		var current_level: int = item.upgrades.get(stat, 0)
		var cost := item.get_upgrade_cost(stat)
		btn.text = "%s +%d -> +%d (%d scrap)" % [stat.capitalize(), current_level, current_level + 1, cost]
		btn.custom_minimum_size = Vector2(0, 32)

		if not GameState.party.has_scrap(cost):
			btn.disabled = true
			btn.modulate = UIColors.MODULATE_DISABLED
			btn.tooltip_text = "Not enough scrap"

		btn.pressed.connect(_on_upgrade_stat_selected.bind(stat))
		shop.upgrade_options.add_child(btn)
		upgrade_stat_buttons.append(btn)

	upgrade_stat_nav = MenuNavigator.new()
	if not upgrade_stat_buttons.is_empty():
		upgrade_stat_nav.setup(upgrade_stat_buttons, 0)

	shop.modal_overlay.visible = true
	shop.upgrade_dialog.visible = true


func _on_upgrade_stat_selected(stat: String) -> void:
	if selected_item == null:
		return

	var cost := selected_item.get_upgrade_cost(stat)
	if not GameState.party.spend_scrap(cost):
		shop.message_label.text = "Not enough scrap!"
		return

	selected_item.apply_upgrade(stat)
	shop.message_label.text = "Upgraded %s's %s for %d scrap." % [selected_item.get_display_name(), stat, cost]

	shop.modal_overlay.visible = false
	shop.upgrade_dialog.visible = false
	upgrade_state = UpgradeState.BROWSING
	selected_item = null
	selected_inventory_index = -1
	shop.refresh_display()


func _on_upgrade_cancel() -> void:
	shop.modal_overlay.visible = false
	shop.upgrade_dialog.visible = false
	upgrade_state = UpgradeState.BROWSING
	selected_item = null
	selected_inventory_index = -1
	if shop.nav and not shop.item_buttons.is_empty():
		shop.nav.update_focus()


func _handle_upgrade_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		_on_upgrade_cancel()
	elif upgrade_stat_nav:
		upgrade_stat_nav.handle_input(event)


func connect_buttons() -> void:
	shop.cancel_upgrade.pressed.connect(_on_upgrade_cancel)
