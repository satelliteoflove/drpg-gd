class_name PartyMenuInventoryTab
extends RefCounted

var nav: MenuNavigator = null
var target_nav: MenuNavigator = null
var buttons: Array[Button] = []
var target_buttons: Array[Button] = []
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

	if GameState.party == null or GameState.party.inventory == null or GameState.party.inventory.is_empty():
		var label := Label.new()
		label.text = "(Inventory empty)"
		inv_list.add_child(label)
		info_label.text = "No items. Visit the Shop to buy supplies."
		return

	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		var qty: int = GameState.party.inventory.get_quantity_at(i)
		if item == null:
			continue

		var btn := Button.new()
		var qty_text := " x%d" % qty if qty > 1 else ""
		btn.text = "%s%s" % [item.get_display_name(), qty_text]
		btn.custom_minimum_size = Vector2(200, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_item_selected.bind(i, item))
		inv_list.add_child(btn)
		buttons.append(btn)

	nav = MenuNavigator.new()
	nav.setup(buttons, clampi(restore_index, 0, maxi(buttons.size() - 1, 0)))
	nav.selection_changed.connect(_on_selection_changed)

	if not showing_targets:
		nav.update_focus()


func _refresh_targets() -> void:
	for child in inv_targets.get_children():
		child.queue_free()
	target_buttons.clear()

	inv_targets_panel.visible = showing_targets

	if not showing_targets or selected_item == null:
		return

	for member in GameState.party.get_members():
		var btn := Button.new()
		var status := " [DEAD]" if member.is_dead else ""
		var stats := "%d/%d HP" % [member.current_hp, member.max_hp]
		if selected_item and selected_item.mp_restore > 0 and member.max_mp > 0:
			stats += "  %d/%d MP" % [member.current_mp, member.max_mp]
		btn.text = "%s: %s%s" % [member.character_name, stats, status]
		btn.custom_minimum_size = Vector2(200, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if not _can_use_item_on(selected_item, member):
			btn.disabled = true
			btn.modulate = UIColors.MODULATE_DISABLED

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
		info_label.text = "Select a target for %s." % selected_item.item_name
		return

	if nav == null or buttons.is_empty():
		return

	var idx := nav.get_current_index()
	if idx < 0 or GameState.party.inventory == null or idx >= GameState.party.inventory.size():
		return

	var item: Item = GameState.party.inventory.get_item_at(idx)
	if item == null:
		return

	var text := "[b]%s[/b]\n%s\n%s" % [item.get_display_name(), item.get_type_name(), item.get_stats_text()]
	if not item.is_identified and GameState.party.has_living_bishop():
		text += "\n\n[color=cyan][Press I to identify (Bishop)][/color]"
	elif item.item_type == Item.ItemType.CONSUMABLE:
		text += "\n\n[Press Enter to use]"
	elif item.is_equipment():
		text += "\n\n[Equip from Status tab]"
	info_label.text = text


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
	if idx < 0 or GameState.party.inventory == null or idx >= GameState.party.inventory.size():
		return
	var item: Item = GameState.party.inventory.get_item_at(idx)
	if item == null:
		return
	if item.is_identified:
		info_label.text = "%s is already identified." % item.get_display_name()
		return
	if not GameState.party.has_living_bishop():
		info_label.text = "No living Bishop in party to identify items."
		return
	var new_item := item.duplicate() as Item
	new_item.is_identified = true
	var slot := GameState.party.inventory.get_slot(idx)
	slot["item"] = new_item
	info_label.text = "Identified: [b]%s[/b]\n%s" % [new_item.get_display_name(), new_item.get_stats_text()]
	refresh(idx)
