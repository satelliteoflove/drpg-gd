extends Control

signal closed()

enum Tab { STATUS, EQUIPMENT, INVENTORY, FORMATION }

var current_tab: Tab = Tab.STATUS
var tab_buttons: Array[Button] = []
var tab_nav: MenuNavigator = null

var status_nav: MenuNavigator = null
var status_buttons: Array[Button] = []

var equip_party_nav: MenuNavigator = null
var equip_slots_nav: MenuNavigator = null
var equip_items_nav: MenuNavigator = null
var equip_party_buttons: Array[Button] = []
var equip_slot_buttons: Array[Button] = []
var equip_item_buttons: Array[Button] = []
var equip_selected_character: Character = null
var equip_selected_slot: Item.ItemType = Item.ItemType.WEAPON
var equip_available_items: Array[Item] = []
enum EquipPanel { PARTY, SLOTS, ITEMS }
var equip_panel: EquipPanel = EquipPanel.PARTY

var inv_nav: MenuNavigator = null
var inv_target_nav: MenuNavigator = null
var inv_buttons: Array[Button] = []
var inv_target_buttons: Array[Button] = []
var inv_selected_item: Item = null
var inv_showing_targets: bool = false

var form_slot_buttons: Array[Button] = []
var form_selected_index: int = -1
var form_current_slot: int = 0

const EQUIPMENT_SLOTS: Array[Item.ItemType] = [
	Item.ItemType.WEAPON,
	Item.ItemType.ARMOR,
	Item.ItemType.SHIELD,
	Item.ItemType.HELMET,
	Item.ItemType.GLOVES,
	Item.ItemType.BOOTS,
	Item.ItemType.ACCESSORY
]

@onready var tab_container: HBoxContainer = $MainPanel/VBox/TabBar/TabContainer
@onready var content_panel: PanelContainer = $MainPanel/VBox/ContentPanel
@onready var status_content: Control = $MainPanel/VBox/ContentPanel/StatusContent
@onready var equipment_content: Control = $MainPanel/VBox/ContentPanel/EquipmentContent
@onready var inventory_content: Control = $MainPanel/VBox/ContentPanel/InventoryContent
@onready var formation_content: Control = $MainPanel/VBox/ContentPanel/FormationContent
@onready var info_panel: PanelContainer = $MainPanel/VBox/InfoPanel
@onready var info_label: RichTextLabel = $MainPanel/VBox/InfoPanel/InfoLabel
@onready var help_label: Label = $MainPanel/VBox/HelpLabel


func _ready() -> void:
	_setup_tabs()
	_switch_tab(Tab.STATUS)


func _setup_tabs() -> void:
	for child in tab_container.get_children():
		child.queue_free()
	tab_buttons.clear()

	var tab_names := ["1: Status", "2: Equipment", "3: Inventory", "4: Formation"]
	for i in range(tab_names.size()):
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.custom_minimum_size = Vector2(120, 30)
		btn.toggle_mode = true
		btn.pressed.connect(_on_tab_pressed.bind(i))
		tab_container.add_child(btn)
		tab_buttons.append(btn)

	tab_nav = MenuNavigator.new()
	tab_nav.setup(tab_buttons, 0)


func _switch_tab(tab: Tab) -> void:
	current_tab = tab

	for i in range(tab_buttons.size()):
		tab_buttons[i].button_pressed = (i == tab)

	status_content.visible = (tab == Tab.STATUS)
	equipment_content.visible = (tab == Tab.EQUIPMENT)
	inventory_content.visible = (tab == Tab.INVENTORY)
	formation_content.visible = (tab == Tab.FORMATION)

	match tab:
		Tab.STATUS:
			_refresh_status()
		Tab.EQUIPMENT:
			_refresh_equipment()
		Tab.INVENTORY:
			_refresh_inventory()
		Tab.FORMATION:
			_refresh_formation()

	_update_help()


func _on_tab_pressed(tab_index: int) -> void:
	_switch_tab(tab_index as Tab)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		if _handle_back():
			var vp := get_viewport()
			if vp:
				vp.set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_switch_tab(Tab.STATUS)
				return
			KEY_2:
				_switch_tab(Tab.EQUIPMENT)
				return
			KEY_3:
				_switch_tab(Tab.INVENTORY)
				return
			KEY_4:
				_switch_tab(Tab.FORMATION)
				return

	match current_tab:
		Tab.STATUS:
			_handle_status_input(event)
		Tab.EQUIPMENT:
			_handle_equipment_input(event)
		Tab.INVENTORY:
			_handle_inventory_input(event)
		Tab.FORMATION:
			_handle_formation_input(event)


func _handle_back() -> bool:
	match current_tab:
		Tab.EQUIPMENT:
			if equip_panel == EquipPanel.ITEMS:
				equip_panel = EquipPanel.SLOTS
				_refresh_equipment()
				return true
			elif equip_panel == EquipPanel.SLOTS:
				equip_panel = EquipPanel.PARTY
				equip_selected_character = null
				_refresh_equipment()
				return true
		Tab.INVENTORY:
			if inv_showing_targets:
				inv_showing_targets = false
				inv_selected_item = null
				_refresh_inventory()
				return true
		Tab.FORMATION:
			if form_selected_index >= 0:
				form_selected_index = -1
				_refresh_formation()
				return true

	_close()
	return true


func _close() -> void:
	if closed.get_connections().is_empty():
		SceneManager.go_to_town()
	else:
		closed.emit()


func _update_help() -> void:
	var v_nav := KeyBindingHelper.get_nav_help()
	var confirm := KeyBindingHelper.get_confirm_help()
	var cancel := KeyBindingHelper.get_cancel_help()
	var arrow_nav := KeyBindingHelper.get_arrow_nav_help()
	var base := "1-4: Tabs | "

	match current_tab:
		Tab.STATUS:
			help_label.text = base + "%s | %s" % [v_nav, cancel]
		Tab.EQUIPMENT:
			match equip_panel:
				EquipPanel.PARTY:
					help_label.text = base + "%s | %s | %s" % [v_nav, confirm, cancel]
				EquipPanel.SLOTS:
					help_label.text = base + "%s | %s | %s" % [v_nav, confirm, cancel]
				EquipPanel.ITEMS:
					help_label.text = base + "%s | %s: Equip | %s" % [v_nav, confirm.split(":")[0], cancel]
		Tab.INVENTORY:
			if inv_showing_targets:
				help_label.text = base + "%s | %s: Use | %s" % [v_nav, confirm.split(":")[0], cancel]
			else:
				help_label.text = base + "%s | %s: Use | %s" % [v_nav, confirm.split(":")[0], cancel]
		Tab.FORMATION:
			if form_selected_index >= 0:
				help_label.text = base + "%s | %s: Swap | %s" % [arrow_nav, confirm.split(":")[0], cancel]
			else:
				help_label.text = base + "%s | %s | %s" % [arrow_nav, confirm, cancel]


# === STATUS TAB ===

@onready var status_list: VBoxContainer = $MainPanel/VBox/ContentPanel/StatusContent/StatusList

func _refresh_status() -> void:
	for child in status_list.get_children():
		child.queue_free()
	status_buttons.clear()

	if GameState.party == null or GameState.party.is_empty():
		var label := Label.new()
		label.text = "(No party members)"
		status_list.add_child(label)
		info_label.text = "Visit the Tavern to recruit party members."
		return

	for i in range(GameState.party.size()):
		var member: Character = GameState.party.get_member_at(i)
		var btn := Button.new()
		var row_marker := "[F]" if i < 3 else "[B]"
		var status_indicator := _get_brief_status(member)
		btn.text = "%s %s - L%d %s %s" % [row_marker, member.character_name, member.level, CharacterEnums.get_class_name(member.character_class), status_indicator]
		btn.custom_minimum_size = Vector2(350, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if member.is_dead:
			btn.modulate = Color(0.7, 0.3, 0.3)
		elif _has_negative_status(member):
			btn.modulate = Color(1.0, 0.8, 0.4)
		btn.pressed.connect(_on_status_member_selected.bind(i))
		status_list.add_child(btn)
		status_buttons.append(btn)

	status_nav = MenuNavigator.new()
	status_nav.setup(status_buttons, 0)
	status_nav.selection_changed.connect(_on_status_selection_changed)
	_update_status_info(0)


func _on_status_member_selected(index: int) -> void:
	_update_status_info(index)


func _on_status_selection_changed(index: int) -> void:
	_update_status_info(index)


func _update_status_info(index: int) -> void:
	if GameState.party == null or index >= GameState.party.size():
		return

	var member: Character = GameState.party.get_member_at(index)
	var row := "Front Row" if index < 3 else "Back Row"
	var text := "[b]%s[/b] (%s)\n" % [member.character_name, row]
	text += "Level %d %s %s\n" % [member.level, CharacterEnums.get_race_name(member.race), CharacterEnums.get_class_name(member.character_class)]
	text += "Alignment: %s\n\n" % CharacterEnums.get_alignment_name(member.alignment)
	text += "HP: %d/%d    MP: %d/%d\n" % [member.current_hp, member.max_hp, member.current_mp, member.max_mp]
	text += "STR: %d  INT: %d  PIE: %d\n" % [member.strength, member.intelligence, member.piety]
	text += "VIT: %d  AGI: %d  LCK: %d\n" % [member.vitality, member.agility, member.luck]
	text += "XP: %d\n" % member.experience
	text += "Weapon: %s  Defense: %d  Accuracy: %+d" % [member.weapon_dice, member.defense, member.accuracy]

	var status_text := _get_status_effects_text(member)
	if status_text == "OK":
		text += "\n\nStatus: [color=green]OK[/color]"
	else:
		text += "\n\nStatus: [color=yellow]%s[/color]" % status_text

	if member.is_dead:
		text += "\n\n[color=red]DEAD - Visit the Temple for resurrection[/color]"

	info_label.text = text


func _get_status_effects_text(member: Character) -> String:
	var effects: Array[String] = []
	for status in member.status_effects:
		if status == CharacterEnums.StatusEffect.DEAD:
			continue
		effects.append(CharacterEnums.get_status_name(status))
	if effects.is_empty():
		return "OK"
	return ", ".join(effects)


func _get_brief_status(member: Character) -> String:
	if member.is_dead:
		return "[DEAD]"
	var abbrevs: Array[String] = []
	for status in member.status_effects:
		if status == CharacterEnums.StatusEffect.DEAD:
			continue
		abbrevs.append(CharacterEnums.get_status_abbreviation(status))
	if abbrevs.is_empty():
		return ""
	return "[%s]" % "/".join(abbrevs)


func _has_negative_status(member: Character) -> bool:
	for status in member.status_effects:
		if status != CharacterEnums.StatusEffect.NONE and status != CharacterEnums.StatusEffect.DEAD and status != CharacterEnums.StatusEffect.BLESSED:
			return true
	return false


func _handle_status_input(event: InputEvent) -> void:
	if status_nav == null:
		return
	if event.is_action_pressed("menu_up"):
		status_nav._move(-1)
	elif event.is_action_pressed("menu_down"):
		status_nav._move(1)


# === EQUIPMENT TAB ===

@onready var equip_party_list: VBoxContainer = $MainPanel/VBox/ContentPanel/EquipmentContent/EquipHBox/PartyPanel/PartyList
@onready var equip_slots_list: VBoxContainer = $MainPanel/VBox/ContentPanel/EquipmentContent/EquipHBox/SlotsPanel/SlotsList
@onready var equip_items_list: VBoxContainer = $MainPanel/VBox/ContentPanel/EquipmentContent/EquipHBox/ItemsPanel/ItemsList

func _refresh_equipment() -> void:
	_refresh_equip_party()
	_refresh_equip_slots()
	_refresh_equip_items()
	_update_equip_info()
	_update_help()


func _refresh_equip_party() -> void:
	for child in equip_party_list.get_children():
		child.queue_free()
	equip_party_buttons.clear()

	if GameState.party == null or GameState.party.is_empty():
		var label := Label.new()
		label.text = "(No party)"
		equip_party_list.add_child(label)
		return

	for member in GameState.party.get_members():
		var btn := Button.new()
		btn.text = "%s - L%d" % [member.character_name, member.level]
		btn.custom_minimum_size = Vector2(140, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_equip_party_selected.bind(member))
		equip_party_list.add_child(btn)
		equip_party_buttons.append(btn)

	equip_party_nav = MenuNavigator.new()
	equip_party_nav.setup(equip_party_buttons, 0)

	if equip_panel == EquipPanel.PARTY:
		equip_party_nav._update_focus()


func _refresh_equip_slots() -> void:
	for child in equip_slots_list.get_children():
		child.queue_free()
	equip_slot_buttons.clear()

	if equip_selected_character == null:
		var label := Label.new()
		label.text = "Select a character"
		equip_slots_list.add_child(label)
		return

	for slot_type in EQUIPMENT_SLOTS:
		var equipped: Item = equip_selected_character.get_equipped_item(slot_type)
		var slot_name := _get_slot_name(slot_type)
		var item_name := equipped.item_name if equipped else "(empty)"

		var btn := Button.new()
		btn.text = "%s: %s" % [slot_name, item_name]
		btn.custom_minimum_size = Vector2(180, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_equip_slot_selected.bind(slot_type))
		equip_slots_list.add_child(btn)
		equip_slot_buttons.append(btn)

	equip_slots_nav = MenuNavigator.new()
	equip_slots_nav.setup(equip_slot_buttons, 0)

	if equip_panel == EquipPanel.SLOTS:
		equip_slots_nav._update_focus()


func _refresh_equip_items() -> void:
	for child in equip_items_list.get_children():
		child.queue_free()
	equip_item_buttons.clear()
	equip_available_items.clear()

	if equip_selected_character == null:
		return

	var unequip_btn := Button.new()
	unequip_btn.text = "(Unequip)"
	unequip_btn.custom_minimum_size = Vector2(140, 28)
	unequip_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	unequip_btn.pressed.connect(_on_equip_unequip)
	equip_items_list.add_child(unequip_btn)
	equip_item_buttons.append(unequip_btn)

	if GameState.party.inventory == null:
		equip_items_nav = MenuNavigator.new()
		equip_items_nav.setup(equip_item_buttons, 0)
		return

	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		if item == null or not item.is_equipment() or item.item_type != equip_selected_slot:
			continue

		equip_available_items.append(item)
		var btn := Button.new()
		btn.text = item.item_name
		btn.custom_minimum_size = Vector2(140, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not equip_selected_character.can_equip_item(item):
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6)
		btn.pressed.connect(_on_equip_item_selected.bind(item))
		equip_items_list.add_child(btn)
		equip_item_buttons.append(btn)

	equip_items_nav = MenuNavigator.new()
	equip_items_nav.setup(equip_item_buttons, 0)

	if equip_panel == EquipPanel.ITEMS:
		equip_items_nav._update_focus()


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


func _on_equip_party_selected(character: Character) -> void:
	equip_selected_character = character
	equip_panel = EquipPanel.SLOTS
	_refresh_equipment()


func _on_equip_slot_selected(slot_type: Item.ItemType) -> void:
	equip_selected_slot = slot_type
	equip_panel = EquipPanel.ITEMS
	_refresh_equipment()


func _on_equip_item_selected(item: Item) -> void:
	if equip_selected_character == null or not equip_selected_character.can_equip_item(item):
		return

	GameState.party.inventory.remove_item(item.id, 1)
	var old_item: Item = equip_selected_character.equip_item(item)
	if old_item:
		GameState.party.inventory.add_item(old_item, 1)

	equip_panel = EquipPanel.SLOTS
	_refresh_equipment()


func _on_equip_unequip() -> void:
	if equip_selected_character == null:
		return

	var old_item: Item = equip_selected_character.unequip_slot(equip_selected_slot)
	if old_item:
		GameState.party.inventory.add_item(old_item, 1)

	equip_panel = EquipPanel.SLOTS
	_refresh_equipment()


func _update_equip_info() -> void:
	match equip_panel:
		EquipPanel.PARTY:
			if equip_party_nav and not equip_party_buttons.is_empty():
				var idx := equip_party_nav.get_current_index()
				var members := GameState.party.get_members()
				if idx >= 0 and idx < members.size():
					var m: Character = members[idx]
					info_label.text = "[b]%s[/b]\nL%d %s\nWeapon: %s\nDefense: %d" % [m.character_name, m.level, CharacterEnums.get_class_name(m.character_class), m.weapon_dice, m.defense]
					return
			info_label.text = "Select a party member to manage equipment."
		EquipPanel.SLOTS:
			if equip_slots_nav and equip_selected_character:
				var idx := equip_slots_nav.get_current_index()
				if idx >= 0 and idx < EQUIPMENT_SLOTS.size():
					var slot_type: Item.ItemType = EQUIPMENT_SLOTS[idx]
					var equipped: Item = equip_selected_character.get_equipped_item(slot_type)
					if equipped:
						info_label.text = "[b]%s[/b]\n%s\n%s" % [equipped.item_name, equipped.get_type_name(), equipped.get_stats_text()]
					else:
						info_label.text = "[b]%s[/b]\n(Empty)" % _get_slot_name(slot_type)
					return
			info_label.text = "Select an equipment slot."
		EquipPanel.ITEMS:
			if equip_items_nav:
				var idx := equip_items_nav.get_current_index()
				if idx == 0:
					info_label.text = "[b]Unequip[/b]\nRemove current item and return to inventory."
				elif idx > 0 and idx - 1 < equip_available_items.size():
					var item: Item = equip_available_items[idx - 1]
					info_label.text = "[b]%s[/b]\n%s\n%s" % [item.item_name, item.get_type_name(), item.get_stats_text()]
				return
			info_label.text = "Select an item to equip."


func _handle_equipment_input(event: InputEvent) -> void:
	var nav: MenuNavigator = null
	match equip_panel:
		EquipPanel.PARTY:
			nav = equip_party_nav
		EquipPanel.SLOTS:
			nav = equip_slots_nav
		EquipPanel.ITEMS:
			nav = equip_items_nav

	if nav == null:
		return

	if event.is_action_pressed("menu_up"):
		nav._move(-1)
		_update_equip_info()
	elif event.is_action_pressed("menu_down"):
		nav._move(1)
		_update_equip_info()
	elif event.is_action_pressed("menu_confirm"):
		nav._confirm()


# === INVENTORY TAB ===

@onready var inv_list: VBoxContainer = $MainPanel/VBox/ContentPanel/InventoryContent/InvHBox/ItemsPanel/ItemsList
@onready var inv_targets: VBoxContainer = $MainPanel/VBox/ContentPanel/InventoryContent/InvHBox/TargetsPanel/TargetsList
@onready var inv_targets_panel: PanelContainer = $MainPanel/VBox/ContentPanel/InventoryContent/InvHBox/TargetsPanel

func _refresh_inventory() -> void:
	_refresh_inv_items()
	_refresh_inv_targets()
	_update_inv_info()
	_update_help()


func _refresh_inv_items() -> void:
	for child in inv_list.get_children():
		child.queue_free()
	inv_buttons.clear()

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
		btn.text = "%s%s" % [item.item_name, qty_text]
		btn.custom_minimum_size = Vector2(200, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_inv_item_selected.bind(i, item))
		inv_list.add_child(btn)
		inv_buttons.append(btn)

	inv_nav = MenuNavigator.new()
	inv_nav.setup(inv_buttons, 0)
	inv_nav.selection_changed.connect(_on_inv_selection_changed)

	if not inv_showing_targets:
		inv_nav._update_focus()


func _refresh_inv_targets() -> void:
	for child in inv_targets.get_children():
		child.queue_free()
	inv_target_buttons.clear()

	inv_targets_panel.visible = inv_showing_targets

	if not inv_showing_targets or inv_selected_item == null:
		return

	for member in GameState.party.get_members():
		var btn := Button.new()
		var status := " [DEAD]" if member.is_dead else ""
		btn.text = "%s: %d/%d HP%s" % [member.character_name, member.current_hp, member.max_hp, status]
		btn.custom_minimum_size = Vector2(200, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if not _can_use_item_on(inv_selected_item, member):
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6)

		btn.pressed.connect(_on_inv_target_selected.bind(member))
		inv_targets.add_child(btn)
		inv_target_buttons.append(btn)

	inv_target_nav = MenuNavigator.new()
	inv_target_nav.setup(inv_target_buttons, 0)
	inv_target_nav._update_focus()


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


func _on_inv_item_selected(_slot_index: int, item: Item) -> void:
	if item.item_type != Item.ItemType.CONSUMABLE:
		info_label.text = "%s cannot be used here. Equip from Equipment tab." % item.item_name
		return

	if item.heal_amount <= 0 and item.mp_restore <= 0 and item.cures_status.is_empty():
		info_label.text = "%s has no usable effect." % item.item_name
		return

	inv_selected_item = item
	inv_showing_targets = true
	_refresh_inventory()


func _on_inv_target_selected(character: Character) -> void:
	if inv_selected_item == null or not _can_use_item_on(inv_selected_item, character):
		return

	var msg := "Used %s on %s. " % [inv_selected_item.item_name, character.character_name]

	if inv_selected_item.heal_amount > 0:
		var healed := character.heal(inv_selected_item.heal_amount)
		msg += "Restored %d HP. " % healed

	if inv_selected_item.mp_restore > 0:
		var restored := character.restore_mp(inv_selected_item.mp_restore)
		msg += "Restored %d MP. " % restored

	GameState.party.inventory.remove_item(inv_selected_item.id, 1)
	info_label.text = msg

	inv_selected_item = null
	inv_showing_targets = false
	_refresh_inventory()


func _on_inv_selection_changed(_index: int) -> void:
	_update_inv_info()


func _update_inv_info() -> void:
	if inv_showing_targets:
		info_label.text = "Select a target for %s." % inv_selected_item.item_name
		return

	if inv_nav == null or inv_buttons.is_empty():
		return

	var idx := inv_nav.get_current_index()
	if idx < 0 or GameState.party.inventory == null or idx >= GameState.party.inventory.size():
		return

	var item: Item = GameState.party.inventory.get_item_at(idx)
	if item == null:
		return

	var text := "[b]%s[/b]\n%s\n%s" % [item.item_name, item.get_type_name(), item.get_stats_text()]
	if item.item_type == Item.ItemType.CONSUMABLE:
		text += "\n\n[Press Enter to use]"
	elif item.is_equipment():
		text += "\n\n[Equip from Equipment tab]"
	info_label.text = text


func _handle_inventory_input(event: InputEvent) -> void:
	var nav: MenuNavigator = inv_target_nav if inv_showing_targets else inv_nav

	if nav == null:
		return

	if event.is_action_pressed("menu_up"):
		nav._move(-1)
		if not inv_showing_targets:
			_update_inv_info()
	elif event.is_action_pressed("menu_down"):
		nav._move(1)
		if not inv_showing_targets:
			_update_inv_info()
	elif event.is_action_pressed("menu_confirm"):
		nav._confirm()


# === FORMATION TAB ===

@onready var form_front_row: HBoxContainer = $MainPanel/VBox/ContentPanel/FormationContent/FormVBox/FrontRowHBox/FrontRow
@onready var form_back_row: HBoxContainer = $MainPanel/VBox/ContentPanel/FormationContent/FormVBox/BackRowHBox/BackRow

func _refresh_formation() -> void:
	_build_formation_slots()
	_update_formation_selection()
	_update_help()


func _build_formation_slots() -> void:
	for child in form_front_row.get_children():
		child.queue_free()
	for child in form_back_row.get_children():
		child.queue_free()
	form_slot_buttons.clear()

	for i in range(3):
		var btn := _create_form_slot_button(i)
		form_front_row.add_child(btn)
		form_slot_buttons.append(btn)

	for i in range(3, 6):
		var btn := _create_form_slot_button(i)
		form_back_row.add_child(btn)
		form_slot_buttons.append(btn)


func _create_form_slot_button(slot_index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 50)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_form_slot_pressed.bind(slot_index))
	_update_form_slot_button(btn, slot_index)
	return btn


func _update_form_slot_button(btn: Button, slot_index: int) -> void:
	var character: Character = null
	if GameState.party and slot_index < GameState.party.size():
		character = GameState.party.get_member_at(slot_index)

	if character:
		btn.text = "%s\nL%d %s" % [character.character_name, character.level, CharacterEnums.get_class_name(character.character_class)]
		btn.modulate = Color(0.7, 0.3, 0.3) if character.is_dead else Color.WHITE
	else:
		btn.text = "(Empty)"
		btn.modulate = Color(0.5, 0.5, 0.5)


func _update_formation_selection() -> void:
	for i in range(form_slot_buttons.size()):
		var btn := form_slot_buttons[i]
		if i == form_selected_index:
			btn.add_theme_color_override("font_color", Color(0, 1, 0))
			btn.add_theme_color_override("font_hover_color", Color(0, 1, 0))
		elif i == form_current_slot:
			btn.add_theme_color_override("font_color", Color(1, 1, 0))
			btn.add_theme_color_override("font_hover_color", Color(1, 1, 0))
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_color_override("font_hover_color")

	_update_form_info()


func _update_form_info() -> void:
	var character: Character = null
	if GameState.party and form_current_slot < GameState.party.size():
		character = GameState.party.get_member_at(form_current_slot)

	if character:
		var row_name := "Front Row" if form_current_slot < 3 else "Back Row"
		var text := "[b]%s[/b] (%s)\n" % [character.character_name, row_name]
		text += "Level %d %s %s\n" % [character.level, CharacterEnums.get_race_name(character.race), CharacterEnums.get_class_name(character.character_class)]
		text += "HP: %d/%d  MP: %d/%d\n" % [character.current_hp, character.max_hp, character.current_mp, character.max_mp]
		text += "AGI: %d (affects turn order)\n\n" % character.agility

		if form_current_slot < 3:
			text += "[color=yellow]Front row: Full weapon range, targeted first[/color]"
		else:
			text += "[color=cyan]Back row: -1 weapon range, protected[/color]"

		if character.is_dead:
			text += "\n[color=red]DEAD[/color]"

		info_label.text = text
	else:
		var row_name := "Front Row" if form_current_slot < 3 else "Back Row"
		info_label.text = "Empty slot (%s)" % row_name


func _on_form_slot_pressed(slot_index: int) -> void:
	if form_selected_index < 0:
		var character: Character = null
		if GameState.party and slot_index < GameState.party.size():
			character = GameState.party.get_member_at(slot_index)
		if character:
			form_selected_index = slot_index
			_update_formation_selection()
	else:
		if slot_index != form_selected_index:
			_swap_formation(form_selected_index, slot_index)
		form_selected_index = -1
		_update_formation_selection()


func _swap_formation(from_index: int, to_index: int) -> void:
	if GameState.party == null:
		return

	var from_char: Character = null
	var to_char: Character = null

	if from_index < GameState.party.size():
		from_char = GameState.party.get_member_at(from_index)
	if to_index < GameState.party.size():
		to_char = GameState.party.get_member_at(to_index)

	if from_char == null and to_char == null:
		return

	if from_char != null and to_char != null:
		GameState.party.swap_positions(from_index, to_index)
	elif from_char != null:
		_move_to_empty_slot(from_index, to_index)
	else:
		_move_to_empty_slot(to_index, from_index)

	for i in range(form_slot_buttons.size()):
		_update_form_slot_button(form_slot_buttons[i], i)


func _move_to_empty_slot(from_index: int, to_index: int) -> void:
	if to_index >= GameState.party.size():
		return

	var moves := to_index - from_index
	if moves > 0:
		for i in range(moves):
			GameState.party.swap_positions(from_index + i, from_index + i + 1)
	else:
		for i in range(-moves):
			GameState.party.swap_positions(from_index - i, from_index - i - 1)


func _handle_formation_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_left"):
		_move_form_selection(-1, 0)
	elif event.is_action_pressed("menu_right"):
		_move_form_selection(1, 0)
	elif event.is_action_pressed("menu_up"):
		_move_form_selection(0, -1)
	elif event.is_action_pressed("menu_down"):
		_move_form_selection(0, 1)
	elif event.is_action_pressed("menu_confirm"):
		_on_form_slot_pressed(form_current_slot)


func _move_form_selection(dx: int, dy: int) -> void:
	var col := form_current_slot % 3
	var row := form_current_slot / 3

	col = clampi(col + dx, 0, 2)
	row = clampi(row + dy, 0, 1)

	form_current_slot = row * 3 + col
	_update_formation_selection()
