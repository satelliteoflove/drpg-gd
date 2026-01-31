extends Control

enum FocusPanel { PARTY, SLOTS, ITEMS }

var current_panel: FocusPanel = FocusPanel.PARTY
var selected_character: Character = null
var selected_slot_type: Item.ItemType = Item.ItemType.WEAPON

var party_nav: MenuNavigator = null
var slots_nav: MenuNavigator = null
var items_nav: MenuNavigator = null

var party_buttons: Array[Button] = []
var slot_buttons: Array[Button] = []
var item_buttons: Array[Button] = []
var available_items: Array[Item] = []

const EQUIPMENT_SLOTS: Array[Item.ItemType] = [
	Item.ItemType.WEAPON,
	Item.ItemType.ARMOR,
	Item.ItemType.SHIELD,
	Item.ItemType.HELMET,
	Item.ItemType.GLOVES,
	Item.ItemType.BOOTS,
	Item.ItemType.ACCESSORY
]

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var party_list: VBoxContainer = $VBoxContainer/MainPanel/PartyPanel/PartyList
@onready var slots_list: VBoxContainer = $VBoxContainer/MainPanel/SlotsPanel/SlotsList
@onready var items_list: VBoxContainer = $VBoxContainer/MainPanel/ItemsPanel/ItemsList
@onready var info_label: RichTextLabel = $VBoxContainer/InfoPanel/InfoLabel
@onready var message_label: Label = $VBoxContainer/MessageLabel
@onready var back_button: Button = $VBoxContainer/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_refresh_party_list()
	_set_panel(FocusPanel.PARTY)


func _refresh_party_list() -> void:
	for child in party_list.get_children():
		child.queue_free()
	party_buttons.clear()

	var members := GameState.party.get_members()
	if members.is_empty():
		var label := Label.new()
		label.text = "(No party members)"
		party_list.add_child(label)
		return

	for character in members:
		var btn := Button.new()
		btn.text = "%s - Lv %d %s" % [
			character.get_display_name(),
			character.level,
			character.get_class_name()
		]
		btn.custom_minimum_size = Vector2(200, 30)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_party_member_selected.bind(character))
		party_list.add_child(btn)
		party_buttons.append(btn)

	party_nav = MenuNavigator.new()
	if not party_buttons.is_empty():
		party_nav.setup(party_buttons, 0)


func _refresh_slots_list() -> void:
	for child in slots_list.get_children():
		child.queue_free()
	slot_buttons.clear()

	if selected_character == null:
		return

	for slot_type in EQUIPMENT_SLOTS:
		var equipped: Item = selected_character.get_equipped_item(slot_type)
		var slot_name := _get_slot_name(slot_type)
		var item_name := equipped.get_display_name() if equipped else "(empty)"

		var btn := Button.new()
		btn.text = "%s: %s" % [slot_name, item_name]
		if equipped and equipped.is_cursed:
			btn.text += " [CURSED]"
		btn.custom_minimum_size = Vector2(250, 30)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_slot_selected.bind(slot_type))
		slots_list.add_child(btn)
		slot_buttons.append(btn)

	slots_nav = MenuNavigator.new()
	if not slot_buttons.is_empty():
		slots_nav.setup(slot_buttons, 0)


func _refresh_items_list() -> void:
	for child in items_list.get_children():
		child.queue_free()
	item_buttons.clear()
	available_items.clear()

	if selected_character == null:
		return

	var unequip_btn := Button.new()
	unequip_btn.text = "(Unequip)"
	unequip_btn.custom_minimum_size = Vector2(200, 30)
	unequip_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	unequip_btn.pressed.connect(_on_unequip_selected)
	items_list.add_child(unequip_btn)
	item_buttons.append(unequip_btn)

	if GameState.party.inventory == null:
		items_nav = MenuNavigator.new()
		items_nav.setup(item_buttons, 0)
		return

	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		if item == null:
			continue
		if not item.is_equipment():
			continue
		if item.item_type != selected_slot_type:
			continue

		available_items.append(item)
		var btn := Button.new()
		var can_equip := selected_character.can_equip_item(item)
		btn.text = item.get_display_name()
		if not can_equip:
			btn.text += " [X]"
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6)
		btn.custom_minimum_size = Vector2(200, 30)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_item_selected.bind(item))
		items_list.add_child(btn)
		item_buttons.append(btn)

	items_nav = MenuNavigator.new()
	if not item_buttons.is_empty():
		items_nav.setup(item_buttons, 0)


func _get_slot_name(slot_type: Item.ItemType) -> String:
	match slot_type:
		Item.ItemType.WEAPON: return "Weapon"
		Item.ItemType.ARMOR: return "Armor"
		Item.ItemType.SHIELD: return "Shield"
		Item.ItemType.HELMET: return "Helmet"
		Item.ItemType.GLOVES: return "Gloves"
		Item.ItemType.BOOTS: return "Boots"
		Item.ItemType.ACCESSORY: return "Accessory"
		_: return "Unknown"


func _set_panel(panel: FocusPanel) -> void:
	current_panel = panel
	_update_panel_highlights()

	var h_nav := KeyBindingHelper.get_horizontal_help()

	match panel:
		FocusPanel.PARTY:
			message_label.text = "Select a party member. [%s panels]" % h_nav
			_update_character_info()
		FocusPanel.SLOTS:
			message_label.text = "Select an equipment slot. [%s panels]" % h_nav
			_update_slot_info()
		FocusPanel.ITEMS:
			message_label.text = "Select an item to equip. [%s panels]" % h_nav
			_update_item_info()


func _update_panel_highlights() -> void:
	for btn in party_buttons:
		btn.modulate = Color.WHITE if current_panel == FocusPanel.PARTY else Color(0.7, 0.7, 0.7)
	for btn in slot_buttons:
		btn.modulate = Color.WHITE if current_panel == FocusPanel.SLOTS else Color(0.7, 0.7, 0.7)
	for i in range(item_buttons.size()):
		var btn := item_buttons[i]
		if current_panel == FocusPanel.ITEMS:
			if i > 0 and i - 1 < available_items.size():
				var item := available_items[i - 1]
				if not selected_character.can_equip_item(item):
					btn.modulate = Color(0.6, 0.6, 0.6)
				else:
					btn.modulate = Color.WHITE
			else:
				btn.modulate = Color.WHITE
		else:
			btn.modulate = Color(0.7, 0.7, 0.7)


func _update_character_info() -> void:
	if party_nav == null or party_buttons.is_empty():
		info_label.text = "No party members."
		return

	var idx := party_nav.get_current_index()
	var members := GameState.party.get_members()
	if idx < 0 or idx >= members.size():
		return

	var character: Character = members[idx]
	var text := "[b]%s[/b]\n" % character.get_display_name()
	text += "Level %d %s %s\n\n" % [character.level, character.get_race_name(), character.get_class_name()]
	text += "STR: %d  INT: %d  PIE: %d\n" % [character.strength, character.intelligence, character.piety]
	text += "VIT: %d  AGI: %d  LCK: %d\n\n" % [character.vitality, character.agility, character.luck]
	text += "Weapon: %s\n" % character.weapon_dice
	text += "Defense: %d  Accuracy: %+d\n" % [character.defense, character.accuracy]
	info_label.text = text


func _update_slot_info() -> void:
	if slots_nav == null or slot_buttons.is_empty() or selected_character == null:
		return

	var idx := slots_nav.get_current_index()
	if idx < 0 or idx >= EQUIPMENT_SLOTS.size():
		return

	var slot_type: Item.ItemType = EQUIPMENT_SLOTS[idx]
	var equipped: Item = selected_character.get_equipped_item(slot_type)

	if equipped:
		var text := "[b]%s[/b]\n" % equipped.get_display_name()
		text += "Type: %s\n" % equipped.get_type_name()
		text += "%s\n" % equipped.get_stats_text()
		if equipped.is_cursed:
			text += "\n[color=red]CURSED - Cannot unequip[/color]"
			text += "\n[color=gray]Visit Shop to uncurse (destroys item)[/color]"
		info_label.text = text
	else:
		info_label.text = "[b]%s[/b]\n(Empty slot)" % _get_slot_name(slot_type)


func _update_item_info() -> void:
	if items_nav == null or item_buttons.is_empty():
		return

	var idx := items_nav.get_current_index()
	if idx == 0:
		var equipped: Item = selected_character.get_equipped_item(selected_slot_type)
		if equipped and equipped.is_cursed:
			info_label.text = "[b]Unequip[/b]\n[color=red]Cannot unequip - item is cursed![/color]\nVisit Shop to uncurse."
		else:
			info_label.text = "[b]Unequip[/b]\nRemove the currently equipped item and return it to inventory."
		return

	var item_idx := idx - 1
	if item_idx < 0 or item_idx >= available_items.size():
		return

	var item: Item = available_items[item_idx]
	var text := "[b]%s[/b]\n" % item.get_display_name()
	text += "Type: %s\n" % item.get_type_name()
	text += "%s\n" % item.get_stats_text()

	if item.is_cursed:
		text += "\n[color=orange]Warning: This item is cursed![/color]"

	if not selected_character.can_equip_item(item):
		text += "\n[color=red]Cannot equip:[/color]\n"
		if selected_character.level < item.required_level:
			text += "- Requires level %d\n" % item.required_level
		if not item.required_classes.is_empty() and not (selected_character.character_class in item.required_classes):
			text += "- Class cannot use\n"
		if not item.required_races.is_empty() and not (selected_character.race in item.required_races):
			text += "- Race cannot use\n"
		if item.item_type == Item.ItemType.SHIELD and selected_character.equipped_weapon and selected_character.equipped_weapon.two_handed:
			text += "- Using two-handed weapon\n"
	info_label.text = text


func _on_party_member_selected(character: Character) -> void:
	selected_character = character
	_refresh_slots_list()
	_refresh_items_list()
	_set_panel(FocusPanel.SLOTS)
	message_label.text = "Selected %s. Choose an equipment slot." % character.get_display_name()


func _on_slot_selected(slot_type: Item.ItemType) -> void:
	selected_slot_type = slot_type
	_refresh_items_list()
	_set_panel(FocusPanel.ITEMS)
	message_label.text = "Select an item for %s slot." % _get_slot_name(slot_type)


func _on_item_selected(item: Item) -> void:
	if selected_character == null:
		return

	if not selected_character.can_equip_item(item):
		message_label.text = "%s cannot equip %s!" % [selected_character.get_display_name(), item.get_display_name()]
		return

	var old_item: Item = selected_character.get_equipped_item(item.item_type)
	if old_item and old_item.is_cursed:
		message_label.text = "Cannot replace cursed item! Visit Shop to uncurse first."
		return

	GameState.party.inventory.remove_item(item.id, 1)

	old_item = selected_character.equip_item(item)

	if old_item:
		GameState.party.inventory.add_item(old_item, 1)
		message_label.text = "Equipped %s. Returned %s to inventory." % [item.get_display_name(), old_item.get_display_name()]
	else:
		message_label.text = "Equipped %s." % item.get_display_name()

	_refresh_slots_list()
	_refresh_items_list()
	_set_panel(FocusPanel.SLOTS)


func _on_unequip_selected() -> void:
	if selected_character == null:
		return

	var equipped: Item = selected_character.get_equipped_item(selected_slot_type)
	if equipped and equipped.is_cursed:
		message_label.text = "Cannot unequip cursed item! Visit Shop to uncurse."
		return

	var old_item: Item = selected_character.unequip_slot(selected_slot_type)

	if old_item:
		var leftover := GameState.party.inventory.add_item(old_item, 1)
		if leftover > 0:
			selected_character.equip_item(old_item)
			message_label.text = "Inventory is full! Cannot unequip."
		else:
			message_label.text = "Unequipped %s." % old_item.get_display_name()
	else:
		message_label.text = "Nothing equipped in that slot."

	_refresh_slots_list()
	_refresh_items_list()
	_set_panel(FocusPanel.SLOTS)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		match current_panel:
			FocusPanel.PARTY:
				_on_back_pressed()
			FocusPanel.SLOTS:
				_set_panel(FocusPanel.PARTY)
			FocusPanel.ITEMS:
				_set_panel(FocusPanel.SLOTS)
		return

	if event.is_action_pressed("menu_left"):
		_switch_panel(-1)
		return
	elif event.is_action_pressed("menu_right"):
		_switch_panel(1)
		return

	var nav: MenuNavigator = _get_current_nav()
	if nav == null:
		return

	if event.is_action_pressed("menu_up"):
		nav._move(-1)
		_update_current_info()
	elif event.is_action_pressed("menu_down"):
		nav._move(1)
		_update_current_info()
	elif event.is_action_pressed("menu_confirm"):
		nav._confirm()


func _switch_panel(direction: int) -> void:
	var new_panel := current_panel

	if direction < 0:
		match current_panel:
			FocusPanel.SLOTS:
				new_panel = FocusPanel.PARTY
			FocusPanel.ITEMS:
				new_panel = FocusPanel.SLOTS
	else:
		match current_panel:
			FocusPanel.PARTY:
				if selected_character != null:
					new_panel = FocusPanel.SLOTS
			FocusPanel.SLOTS:
				new_panel = FocusPanel.ITEMS

	if new_panel != current_panel:
		_set_panel(new_panel)


func _get_current_nav() -> MenuNavigator:
	match current_panel:
		FocusPanel.PARTY: return party_nav
		FocusPanel.SLOTS: return slots_nav
		FocusPanel.ITEMS: return items_nav
	return null


func _update_current_info() -> void:
	match current_panel:
		FocusPanel.PARTY:
			_update_character_info()
		FocusPanel.SLOTS:
			_update_slot_info()
		FocusPanel.ITEMS:
			_update_item_info()


func _on_back_pressed() -> void:
	SceneManager.go_to_town()
