extends Control

signal closed()

enum Tab { STATUS, EQUIPMENT, INVENTORY, FORMATION, SPELLS }

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

var spell_party_nav: MenuNavigator = null
var spell_list_nav: MenuNavigator = null
var spell_target_nav: MenuNavigator = null
var spell_party_buttons: Array[Button] = []
var spell_list_buttons: Array[Button] = []
var spell_target_buttons: Array[Button] = []
var spell_selected_character: Character = null
var spell_selected_spell: Spell = null
var spell_current_level: int = 1
var spell_all_spells: Dictionary = {}
enum SpellPanel { PARTY, LIST, TARGETS }
var spell_panel: SpellPanel = SpellPanel.PARTY

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
@onready var spells_content: Control = $MainPanel/VBox/ContentPanel/SpellsContent
@onready var spell_party_list: VBoxContainer = $MainPanel/VBox/ContentPanel/SpellsContent/SpellsHBox/SpellPartyPanel/SpellPartyList
@onready var spell_level_tabs: HBoxContainer = $MainPanel/VBox/ContentPanel/SpellsContent/SpellsHBox/SpellListPanel/SpellListVBox/SpellLevelTabs
@onready var spell_list: VBoxContainer = $MainPanel/VBox/ContentPanel/SpellsContent/SpellsHBox/SpellListPanel/SpellListVBox/SpellList
@onready var spell_target_panel: PanelContainer = $MainPanel/VBox/ContentPanel/SpellsContent/SpellsHBox/SpellTargetPanel
@onready var spell_target_list: VBoxContainer = $MainPanel/VBox/ContentPanel/SpellsContent/SpellsHBox/SpellTargetPanel/SpellTargetList
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

	var tab_names := ["1: Status", "2: Equipment", "3: Inventory", "4: Formation", "5: Spells"]
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
	spells_content.visible = (tab == Tab.SPELLS)

	match tab:
		Tab.STATUS:
			_refresh_status()
		Tab.EQUIPMENT:
			_refresh_equipment()
		Tab.INVENTORY:
			_refresh_inventory()
		Tab.FORMATION:
			_refresh_formation()
		Tab.SPELLS:
			_refresh_spells()

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
			KEY_5:
				_switch_tab(Tab.SPELLS)
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
		Tab.SPELLS:
			_handle_spells_input(event)


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
		Tab.SPELLS:
			if spell_panel == SpellPanel.TARGETS:
				spell_panel = SpellPanel.LIST
				spell_selected_spell = null
				_refresh_spells()
				return true
			elif spell_panel == SpellPanel.LIST:
				spell_panel = SpellPanel.PARTY
				spell_selected_character = null
				spell_all_spells.clear()
				_refresh_spells()
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
	var h_nav := KeyBindingHelper.get_horizontal_help()
	var base := "1-5: Tabs | "

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
		Tab.SPELLS:
			match spell_panel:
				SpellPanel.PARTY:
					help_label.text = base + "%s | %s | %s" % [v_nav, confirm, cancel]
				SpellPanel.LIST:
					help_label.text = base + "%s | %s: Spell Level | %s: Cast | %s" % [v_nav, h_nav, confirm.split(":")[0], cancel]
				SpellPanel.TARGETS:
					help_label.text = base + "%s | %s: Cast | %s" % [v_nav, confirm.split(":")[0], cancel]


# === STATUS TAB ===

@onready var status_list: VBoxContainer = $MainPanel/VBox/ContentPanel/StatusContent/StatusHBox/StatusListPanel/StatusList
@onready var attribute_bars: AttributeBars = $MainPanel/VBox/ContentPanel/StatusContent/StatusHBox/AttributePanel/AttributeVBox/AttributeBars
@onready var radar_chart: RadarChart = $MainPanel/VBox/ContentPanel/StatusContent/StatusHBox/ChartPanel/ChartVBox/RadarChart
@onready var party_summary: Control = $MainPanel/VBox/ContentPanel/StatusContent/StatusHBox/SummaryPanel/PartySummary

func _refresh_status() -> void:
	for child in status_list.get_children():
		child.queue_free()
	status_buttons.clear()

	if party_summary:
		party_summary.set_party(GameState.party)

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
	text += "Level %d %s %s  |  %s\n" % [member.level, CharacterEnums.get_race_name(member.race), CharacterEnums.get_class_name(member.character_class), CharacterEnums.get_alignment_name(member.alignment)]
	text += "HP: %d/%d    MP: %d/%d    XP: %d\n" % [member.current_hp, member.max_hp, member.current_mp, member.max_mp, member.experience]
	text += "Weapon: %s  |  Defense: %d  |  Accuracy: %+d" % [member.weapon_dice, member.defense, member.accuracy]

	var status_text := _get_status_effects_text(member)
	if status_text == "OK":
		text += "\nStatus: [color=green]OK[/color]"
	else:
		text += "\nStatus: [color=yellow]%s[/color]" % status_text

	if member.is_dead:
		text += "\n[color=red]DEAD - Visit the Temple for resurrection[/color]"

	info_label.text = text
	_update_combat_radar(member)


func _update_combat_radar(member: Character) -> void:
	if attribute_bars:
		attribute_bars.set_character(member)

	if radar_chart:
		var combat_stats := _calculate_combat_stats(member)
		radar_chart.set_data(combat_stats)


func _calculate_combat_stats(member: Character) -> Array[Dictionary]:
	var stats: Array[Dictionary] = []

	var dpt_val := _calculate_expected_dpt(member)
	var dpt_max := 25.0

	var mitigation_val := _calculate_mitigation(member)
	var mitigation_max := 40.0

	var evasion_val := float(member.evasion) + float(member.agility) / 4.0
	var evasion_max := 20.0

	var speed_val := float(member.agility)
	var speed_max := 25.0

	var survivability_val := _calculate_survivability(member)
	var survivability_max := 50.0

	stats.append({ "label": "DPT", "value": dpt_val, "max_value": dpt_max })
	stats.append({ "label": "MIT", "value": mitigation_val, "max_value": mitigation_max })
	stats.append({ "label": "EVA", "value": evasion_val, "max_value": evasion_max })
	stats.append({ "label": "SPD", "value": speed_val, "max_value": speed_max })
	stats.append({ "label": "SRV", "value": survivability_val, "max_value": survivability_max })

	return stats


func _calculate_mitigation(member: Character) -> float:
	return float(member.defense) + float(member.vitality) / 4.0


func _calculate_survivability(member: Character) -> float:
	return float(member.max_hp) + float(member.vitality) / 2.0


func _calculate_expected_dpt(member: Character) -> float:
	var dice_str := member.weapon_dice
	var expected := _parse_dice_expected(dice_str)
	var str_bonus := float(member.strength - 10) / 4.0
	var dmg_bonus := float(member.damage_bonus)
	return expected + str_bonus + dmg_bonus


func _parse_dice_expected(dice_str: String) -> float:
	if dice_str.is_empty():
		return 1.0

	var parts := dice_str.to_lower().split("d")
	if parts.size() != 2:
		return 1.0

	var num_dice := parts[0].to_int()
	if num_dice <= 0:
		num_dice = 1

	var die_sides := parts[1].to_int()
	if die_sides <= 0:
		die_sides = 4

	return num_dice * (die_sides + 1.0) / 2.0


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


# === SPELLS TAB ===

func _refresh_spells() -> void:
	_refresh_spell_party()
	_refresh_spell_level_tabs()
	_refresh_spell_list()
	_refresh_spell_targets()
	_update_spell_info()
	_update_help()


func _refresh_spell_party() -> void:
	for child in spell_party_list.get_children():
		child.queue_free()
	spell_party_buttons.clear()

	if GameState.party == null or GameState.party.is_empty():
		var label := Label.new()
		label.text = "(No party)"
		spell_party_list.add_child(label)
		return

	for i in range(GameState.party.size()):
		var member: Character = GameState.party.get_member_at(i)
		var btn := Button.new()
		var status_text := ""
		if member.is_dead:
			status_text = " [DEAD]"
		elif member.is_silenced():
			status_text = " [SIL]"
		btn.text = "%s - MP: %d/%d%s" % [member.character_name, member.current_mp, member.max_mp, status_text]
		btn.custom_minimum_size = Vector2(180, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if member.is_dead:
			btn.modulate = Color(0.7, 0.3, 0.3)
		elif member.is_silenced():
			btn.modulate = Color(0.6, 0.6, 0.6)
		btn.pressed.connect(_on_spell_party_selected.bind(member))
		spell_party_list.add_child(btn)
		spell_party_buttons.append(btn)

	spell_party_nav = MenuNavigator.new()
	spell_party_nav.setup(spell_party_buttons, 0)
	spell_party_nav.selection_changed.connect(_on_spell_party_nav_changed)

	if spell_panel == SpellPanel.PARTY:
		spell_party_nav._update_focus()


func _on_spell_party_selected(character: Character) -> void:
	spell_selected_character = character
	spell_current_level = 1
	spell_panel = SpellPanel.LIST
	_load_character_spells()
	_auto_select_first_level()
	_refresh_spells()


func _on_spell_party_nav_changed(_index: int) -> void:
	_update_spell_info()


func _load_character_spells() -> void:
	spell_all_spells.clear()
	if spell_selected_character == null:
		return
	for i in range(1, 8):
		spell_all_spells[i] = []
	for spell_id in spell_selected_character.known_spells:
		var spell: Spell = SpellDatabase.get_spell(spell_id)
		if spell == null:
			continue
		if spell_all_spells.has(spell.level):
			spell_all_spells[spell.level].append(spell)


func _auto_select_first_level() -> void:
	for lvl in range(1, 8):
		if spell_all_spells.has(lvl) and not spell_all_spells[lvl].is_empty():
			spell_current_level = lvl
			return
	spell_current_level = 1


func _refresh_spell_level_tabs() -> void:
	for child in spell_level_tabs.get_children():
		child.queue_free()

	if spell_selected_character == null:
		return

	for lvl in range(1, 8):
		var btn := Button.new()
		btn.text = "L%d" % lvl
		btn.custom_minimum_size = Vector2(36, 24)
		btn.toggle_mode = true
		btn.button_pressed = (lvl == spell_current_level)
		var has_spells: bool = spell_all_spells.has(lvl) and not spell_all_spells[lvl].is_empty()
		if not has_spells:
			btn.modulate = Color(0.4, 0.4, 0.4)
		btn.pressed.connect(_on_spell_level_selected.bind(lvl))
		spell_level_tabs.add_child(btn)


func _on_spell_level_selected(lvl: int) -> void:
	spell_current_level = lvl
	_refresh_spell_level_tabs()
	_refresh_spell_list()
	_update_spell_info()


func _refresh_spell_list() -> void:
	for child in spell_list.get_children():
		child.queue_free()
	spell_list_buttons.clear()

	if spell_selected_character == null:
		var label := Label.new()
		label.text = "Select a character"
		spell_list.add_child(label)
		return

	var spells_at_level: Array = spell_all_spells.get(spell_current_level, [])
	if spells_at_level.is_empty():
		var label := Label.new()
		label.text = "(No spells at this level)"
		spell_list.add_child(label)
		return

	for spell: Spell in spells_at_level:
		var btn := Button.new()
		btn.text = "%s  (%d MP)" % [spell.name, spell.mp_cost]
		btn.custom_minimum_size = Vector2(200, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if not spell.out_of_combat:
			btn.modulate = Color(0.5, 0.5, 0.5)
		elif spell_selected_character.current_mp < spell.mp_cost:
			btn.modulate = Color(0.6, 0.5, 0.4)
		elif spell_selected_character.is_dead or spell_selected_character.is_silenced():
			btn.modulate = Color(0.5, 0.5, 0.5)

		btn.pressed.connect(_on_spell_selected.bind(spell))
		spell_list.add_child(btn)
		spell_list_buttons.append(btn)

	spell_list_nav = MenuNavigator.new()
	spell_list_nav.setup(spell_list_buttons, 0)
	spell_list_nav.selection_changed.connect(_on_spell_list_nav_changed)

	if spell_panel == SpellPanel.LIST:
		spell_list_nav._update_focus()


func _on_spell_list_nav_changed(_index: int) -> void:
	_update_spell_info()


func _on_spell_selected(spell: Spell) -> void:
	if not spell.out_of_combat:
		info_label.text = "[b]%s[/b]\nCan only be cast in combat." % spell.name
		return

	var validation := SpellValidator.can_cast(spell_selected_character, spell, false)
	if not validation.can_cast:
		info_label.text = "[b]%s[/b]\n%s" % [spell.name, validation.reason]
		return

	match spell.target_type:
		CharacterEnums.SpellTargetType.SELF:
			_cast_spell_on_targets(spell, [spell_selected_character])
		CharacterEnums.SpellTargetType.ALL_ALLIES:
			_cast_spell_on_targets(spell, _get_living_party_members())
		_:
			spell_selected_spell = spell
			spell_panel = SpellPanel.TARGETS
			_refresh_spells()


func _refresh_spell_targets() -> void:
	for child in spell_target_list.get_children():
		child.queue_free()
	spell_target_buttons.clear()

	spell_target_panel.visible = (spell_panel == SpellPanel.TARGETS)

	if spell_panel != SpellPanel.TARGETS or spell_selected_spell == null:
		return

	var is_dead_target := spell_selected_spell.target_type == CharacterEnums.SpellTargetType.DEAD_ALLY

	for member in GameState.party.get_members():
		var btn := Button.new()
		var hp_text := "%d/%d HP" % [member.current_hp, member.max_hp]
		var status := ""
		if member.is_dead:
			status = " [DEAD]"
		btn.text = "%s: %s%s" % [member.character_name, hp_text, status]
		btn.custom_minimum_size = Vector2(200, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var valid_target := false
		if is_dead_target:
			valid_target = member.is_dead
		else:
			valid_target = not member.is_dead

		if not valid_target:
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5)

		btn.pressed.connect(_on_spell_target_selected.bind(member))
		spell_target_list.add_child(btn)
		spell_target_buttons.append(btn)

	spell_target_nav = MenuNavigator.new()
	spell_target_nav.setup(spell_target_buttons, 0)
	spell_target_nav._update_focus()


func _on_spell_target_selected(target: Character) -> void:
	if spell_selected_spell == null:
		return
	_cast_spell_on_targets(spell_selected_spell, [target])


func _cast_spell_on_targets(spell: Spell, targets: Array) -> void:
	var result := SpellCaster.cast_spell(spell_selected_character, spell, targets, false)
	var msg := "\n".join(result.messages)
	info_label.text = msg

	spell_selected_spell = null
	if spell_panel == SpellPanel.TARGETS:
		spell_panel = SpellPanel.LIST
	_refresh_spells()


func _get_living_party_members() -> Array:
	var members: Array = []
	for member in GameState.party.get_members():
		if not member.is_dead:
			members.append(member)
	return members


func _update_spell_info() -> void:
	match spell_panel:
		SpellPanel.PARTY:
			if spell_party_nav and not spell_party_buttons.is_empty():
				var idx := spell_party_nav.get_current_index()
				var members := GameState.party.get_members()
				if idx >= 0 and idx < members.size():
					var m: Character = members[idx]
					var class_name_str := CharacterEnums.get_class_name(m.character_class)
					var spell_count := m.known_spells.size()
					var text := "[b]%s[/b]\nL%d %s\nMP: %d/%d\nKnown spells: %d" % [m.character_name, m.level, class_name_str, m.current_mp, m.max_mp, spell_count]
					if m.is_dead:
						text += "\n[color=red]DEAD[/color]"
					elif m.is_silenced():
						text += "\n[color=yellow]SILENCED - Cannot cast[/color]"
					info_label.text = text
					return
			info_label.text = "Select a party member to view spells."
		SpellPanel.LIST:
			if spell_list_nav and not spell_list_buttons.is_empty():
				var idx := spell_list_nav.get_current_index()
				var spells_at_level: Array = spell_all_spells.get(spell_current_level, [])
				if idx >= 0 and idx < spells_at_level.size():
					var spell: Spell = spells_at_level[idx]
					var text := "[b]%s[/b] (L%d %s)\n" % [spell.name, spell.level, spell.get_school_name()]
					text += "MP Cost: %d  |  Target: %s\n" % [spell.mp_cost, spell.get_target_description()]
					text += "%s" % spell.description
					if not spell.out_of_combat:
						text += "\n[color=gray]Combat only[/color]"
					else:
						var fizzle := SpellValidator.calculate_fizzle_chance(spell_selected_character, spell)
						text += "\nFizzle: %d%%" % int(fizzle)
					info_label.text = text
					return
			info_label.text = "No spells at this level."
		SpellPanel.TARGETS:
			if spell_selected_spell:
				info_label.text = "Select target for [b]%s[/b]." % spell_selected_spell.name


func _handle_spells_input(event: InputEvent) -> void:
	if spell_panel == SpellPanel.LIST:
		if event.is_action_pressed("menu_left"):
			_cycle_spell_level(-1)
			return
		elif event.is_action_pressed("menu_right"):
			_cycle_spell_level(1)
			return

	var nav: MenuNavigator = null
	match spell_panel:
		SpellPanel.PARTY:
			nav = spell_party_nav
		SpellPanel.LIST:
			nav = spell_list_nav
		SpellPanel.TARGETS:
			nav = spell_target_nav

	if nav == null:
		return

	if event.is_action_pressed("menu_up"):
		nav._move(-1)
		_update_spell_info()
	elif event.is_action_pressed("menu_down"):
		nav._move(1)
		_update_spell_info()
	elif event.is_action_pressed("menu_confirm"):
		nav._confirm()


func _cycle_spell_level(direction: int) -> void:
	var new_level := spell_current_level + direction
	if new_level < 1:
		new_level = 7
	elif new_level > 7:
		new_level = 1
	spell_current_level = new_level
	_refresh_spell_level_tabs()
	_refresh_spell_list()
	_update_spell_info()
