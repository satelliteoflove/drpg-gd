extends Control

signal closed()

enum Tab { STATUS, INVENTORY, FORMATION, SPELLS, KEYBINDINGS }

var current_tab: Tab = Tab.STATUS
var tab_buttons: Array[Button] = []
var tab_nav: MenuNavigator = null

var status_buttons: Array[Button] = []
var _status_on_character_tabs: bool = false
var _status_in_equip_mode: bool = false

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

@onready var tab_container: HBoxContainer = $MainPanel/VBox/TabBar/TabContainer
@onready var content_panel: PanelContainer = $MainPanel/VBox/ContentPanel
@onready var status_content: Control = $MainPanel/VBox/ContentPanel/StatusContent
@onready var inventory_content: Control = $MainPanel/VBox/ContentPanel/InventoryContent
@onready var formation_content: Control = $MainPanel/VBox/ContentPanel/FormationContent
@onready var spells_content: Control = $MainPanel/VBox/ContentPanel/SpellsContent
@onready var spell_party_list: VBoxContainer = $MainPanel/VBox/ContentPanel/SpellsContent/SpellsHBox/SpellPartyPanel/SpellPartyList
@onready var spell_level_tabs: HBoxContainer = $MainPanel/VBox/ContentPanel/SpellsContent/SpellsHBox/SpellListPanel/SpellListVBox/SpellLevelTabs
@onready var spell_list: VBoxContainer = $MainPanel/VBox/ContentPanel/SpellsContent/SpellsHBox/SpellListPanel/SpellListVBox/SpellList
@onready var spell_target_panel: PanelContainer = $MainPanel/VBox/ContentPanel/SpellsContent/SpellsHBox/SpellTargetPanel
@onready var spell_target_list: VBoxContainer = $MainPanel/VBox/ContentPanel/SpellsContent/SpellsHBox/SpellTargetPanel/SpellTargetList
@onready var keybindings_content: Control = $MainPanel/VBox/ContentPanel/KeybindingsContent
@onready var keybind_action_list: VBoxContainer = $MainPanel/VBox/ContentPanel/KeybindingsContent/KeybindVBox/KeybindHBox/ActionPanel/ActionScroll/ActionList
@onready var keybind_primary_label: Label = $MainPanel/VBox/ContentPanel/KeybindingsContent/KeybindVBox/KeybindHBox/BindingPanel/BindingVBox/PrimaryLabel
@onready var keybind_primary_btn: Button = $MainPanel/VBox/ContentPanel/KeybindingsContent/KeybindVBox/KeybindHBox/BindingPanel/BindingVBox/PrimaryBtn
@onready var keybind_secondary_label: Label = $MainPanel/VBox/ContentPanel/KeybindingsContent/KeybindVBox/KeybindHBox/BindingPanel/BindingVBox/SecondaryLabel
@onready var keybind_secondary_btn: Button = $MainPanel/VBox/ContentPanel/KeybindingsContent/KeybindVBox/KeybindHBox/BindingPanel/BindingVBox/SecondaryBtn
@onready var keybind_clear_btn: Button = $MainPanel/VBox/ContentPanel/KeybindingsContent/KeybindVBox/KeybindHBox/BindingPanel/BindingVBox/ClearSecondaryBtn
@onready var keybind_reset_btn: Button = $MainPanel/VBox/ContentPanel/KeybindingsContent/KeybindVBox/ResetBtn
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

	var tab_names := ["Status", "Inventory", "Formation", "Spells", "Keys"]
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
	inventory_content.visible = (tab == Tab.INVENTORY)
	formation_content.visible = (tab == Tab.FORMATION)
	spells_content.visible = (tab == Tab.SPELLS)
	keybindings_content.visible = (tab == Tab.KEYBINDINGS)
	_status_on_character_tabs = false
	_status_in_equip_mode = false
	if tab == Tab.STATUS:
		character_sheet.exit_equip_mode()
	info_panel.visible = (tab != Tab.STATUS)
	for btn in tab_buttons:
		btn.modulate.a = 1.0

	if tab != Tab.KEYBINDINGS:
		_keybind_listening = false

	match tab:
		Tab.STATUS:
			_refresh_status()
		Tab.INVENTORY:
			_refresh_inventory()
		Tab.FORMATION:
			_refresh_formation()
		Tab.SPELLS:
			_refresh_spells()
		Tab.KEYBINDINGS:
			_refresh_keybindings()

	_update_help()


func _on_tab_pressed(tab_index: int) -> void:
	_switch_tab(tab_index as Tab)


func _unhandled_input(event: InputEvent) -> void:
	if _keybind_listening and event is InputEventKey and (event as InputEventKey).pressed:
		_apply_listened_key(event as InputEventKey)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("menu_cancel"):
		_handle_back()
		return

	if event.is_action_pressed("menu_left"):
		if current_tab == Tab.STATUS and _status_in_equip_mode:
			_cycle_equip_character(-1)
			return
		if current_tab == Tab.STATUS and _status_on_character_tabs:
			var new_index := (_status_selected_index - 1 + status_buttons.size()) % status_buttons.size()
			_update_status_info(new_index)
			return
		if current_tab == Tab.SPELLS and spell_panel == SpellPanel.LIST:
			_cycle_spell_level(-1)
			return
		var new_tab := (current_tab - 1 + Tab.size()) % Tab.size()
		_switch_tab(new_tab as Tab)
		return
	if event.is_action_pressed("menu_right"):
		if current_tab == Tab.STATUS and _status_in_equip_mode:
			_cycle_equip_character(1)
			return
		if current_tab == Tab.STATUS and _status_on_character_tabs:
			var new_index := (_status_selected_index + 1) % status_buttons.size()
			_update_status_info(new_index)
			return
		if current_tab == Tab.SPELLS and spell_panel == SpellPanel.LIST:
			_cycle_spell_level(1)
			return
		var new_tab := (current_tab + 1) % Tab.size()
		_switch_tab(new_tab as Tab)
		return

	match current_tab:
		Tab.STATUS:
			_handle_status_input(event)
		Tab.INVENTORY:
			_handle_inventory_input(event)
		Tab.FORMATION:
			_handle_formation_input(event)
		Tab.SPELLS:
			_handle_spells_input(event)
		Tab.KEYBINDINGS:
			_handle_keybindings_input(event)


func _handle_back() -> bool:
	match current_tab:
		Tab.STATUS:
			if _status_in_equip_mode:
				_back_equip_mode()
				return true
			if _status_on_character_tabs:
				_status_on_character_tabs = false
				_update_status_tab_highlight()
				_update_help()
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
		Tab.KEYBINDINGS:
			if _keybind_listening:
				_keybind_listening = false
				_update_keybind_detail()
				_update_help()
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
	var tab_help := KeyBindingHelper.get_tab_help()
	var base := "%s | " % tab_help

	match current_tab:
		Tab.STATUS:
			if _status_in_equip_mode:
				var equip_mode: int = character_sheet.get_equip_mode()
				if equip_mode == 2:
					help_label.text = "%s | %s: Equip | %s: Switch char | %s" % [v_nav, confirm.split(":")[0], tab_help, cancel]
				else:
					help_label.text = "%s | %s: Browse items | %s: Switch char | %s" % [v_nav, confirm.split(":")[0], tab_help, cancel]
			elif _status_on_character_tabs:
				var select_key := KeyBindingHelper.get_action_key("menu_select")
				help_label.text = "%s: Switch character | %s: Equip | %s: Details | K: Main tabs | %s" % [tab_help, confirm.split(":")[0], select_key, cancel]
			else:
				help_label.text = base + "J: Characters | %s" % cancel
		Tab.INVENTORY:
			if inv_showing_targets:
				help_label.text = base + "%s | %s: Use | %s" % [v_nav, confirm.split(":")[0], cancel]
			else:
				var id_hint := " | I: Identify" if GameState.party and GameState.party.has_living_bishop() else ""
				help_label.text = base + "%s | %s: Use%s | %s" % [v_nav, confirm.split(":")[0], id_hint, cancel]
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
					help_label.text = base + "%s | %s: Spell Level | %s: Cast | %s" % [v_nav, tab_help.split(":")[0], confirm.split(":")[0], cancel]
				SpellPanel.TARGETS:
					help_label.text = base + "%s | %s: Cast | %s" % [v_nav, confirm.split(":")[0], cancel]
		Tab.KEYBINDINGS:
			if _keybind_listening:
				help_label.text = "Press a key to bind | Esc: Cancel"
			else:
				var select_key := KeyBindingHelper.get_action_key("menu_select")
				var sort_key := KeyBindingHelper.get_action_key("menu_sort")
				var reorder_key := KeyBindingHelper.get_action_key("menu_reorder")
				help_label.text = base + "%s | %s: Primary | %s: Secondary | %s: Clear 2nd | %s: Reset All | %s" % [v_nav, confirm.split(":")[0], select_key, sort_key, reorder_key, cancel]


# === STATUS TAB ===

@onready var character_tabs: HBoxContainer = $MainPanel/VBox/ContentPanel/StatusContent/StatusVBox/CharacterTabs
@onready var character_sheet: Control = $MainPanel/VBox/ContentPanel/StatusContent/StatusVBox/DetailPanel/CharacterSheet
var _status_selected_index: int = 0

func _refresh_status() -> void:
	for child in character_tabs.get_children():
		child.queue_free()
	status_buttons.clear()

	if GameState.party == null or GameState.party.is_empty():
		character_sheet.clear()
		return

	for i in range(GameState.party.size()):
		var member: Character = GameState.party.get_member_at(i)
		var btn := Button.new()
		btn.text = member.character_name
		btn.custom_minimum_size = Vector2(0, 28)
		btn.toggle_mode = true
		if member.is_dead:
			btn.modulate = UIColors.MODULATE_DEAD
		elif _has_negative_status(member):
			btn.modulate = UIColors.TEXT_WARNING
		btn.pressed.connect(_on_status_member_selected.bind(i))
		character_tabs.add_child(btn)
		status_buttons.append(btn)

	_status_selected_index = 0
	_update_status_info(0)


func _on_status_member_selected(index: int) -> void:
	if _status_on_character_tabs and index == _status_selected_index:
		_status_in_equip_mode = true
		character_sheet.enter_equip_mode()
		var focused := get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()
		info_panel.visible = true
		_update_equip_info_label()
		_update_status_tab_highlight()
		_update_help()
		return
	_status_on_character_tabs = true
	_update_status_info(index)
	_update_status_tab_highlight()
	_update_help()


func _update_status_info(index: int) -> void:
	if GameState.party == null or index >= GameState.party.size():
		return

	_status_selected_index = index
	for i in range(status_buttons.size()):
		status_buttons[i].button_pressed = (i == index)

	var member: Character = GameState.party.get_member_at(index)
	character_sheet.set_character(member, index)


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


func _update_status_tab_highlight() -> void:
	var main_alpha := 0.5 if (_status_on_character_tabs or _status_in_equip_mode) else 1.0
	var char_alpha := 0.5 if _status_in_equip_mode else (1.0 if _status_on_character_tabs else 0.6)
	for btn in tab_buttons:
		btn.modulate.a = main_alpha
	for i in range(status_buttons.size()):
		var base_modulate := Color.WHITE
		var member: Character = GameState.party.get_member_at(i)
		if member.is_dead:
			base_modulate = UIColors.MODULATE_DEAD
		elif _has_negative_status(member):
			base_modulate = UIColors.TEXT_WARNING
		status_buttons[i].modulate = base_modulate
		status_buttons[i].modulate.a = char_alpha


func _handle_status_input(event: InputEvent) -> void:
	if status_buttons.is_empty():
		return

	if _status_in_equip_mode:
		if character_sheet.handle_equip_input(event):
			if character_sheet.get_equip_mode() == 0:
				_status_in_equip_mode = false
				info_panel.visible = false
				_update_status_tab_highlight()
			_update_equip_info_label()
			_update_help()
		return

	if event.is_action_pressed("menu_select") and _status_on_character_tabs:
		character_sheet.cycle_story_focus()
		info_panel.visible = character_sheet.is_showing_detail()
		if character_sheet.is_showing_detail():
			_update_equip_info_label()
		_update_help()
		return

	if event.is_action_pressed("menu_confirm") and _status_on_character_tabs:
		_status_in_equip_mode = true
		character_sheet.enter_equip_mode()
		var focused := get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()
		info_panel.visible = true
		_update_equip_info_label()
		_update_status_tab_highlight()
		_update_help()
		return

	if event.is_action_pressed("menu_down") and not _status_on_character_tabs:
		_status_on_character_tabs = true
		_update_status_tab_highlight()
		_update_help()
		return
	if event.is_action_pressed("menu_up") and _status_on_character_tabs:
		_status_on_character_tabs = false
		_update_status_tab_highlight()
		_update_help()
		return


func _back_equip_mode() -> void:
	var mode: int = character_sheet.get_equip_mode()
	if mode == 2:
		character_sheet.back_from_items()
		_update_equip_info_label()
		_update_help()
	else:
		character_sheet.exit_equip_mode()
		_status_in_equip_mode = false
		info_panel.visible = false
		_update_status_tab_highlight()
		_update_help()


func _cycle_equip_character(direction: int) -> void:
	if status_buttons.is_empty():
		return
	var new_index := (_status_selected_index + direction + status_buttons.size()) % status_buttons.size()
	_update_status_info(new_index)
	character_sheet.enter_equip_mode()
	_update_equip_info_label()
	_update_help()


func _update_equip_info_label() -> void:
	info_label.text = character_sheet.get_info_text()


# === INVENTORY TAB ===

@onready var inv_list: VBoxContainer = $MainPanel/VBox/ContentPanel/InventoryContent/InvHBox/ItemsPanel/ItemsScroll/ItemsList
@onready var inv_targets: VBoxContainer = $MainPanel/VBox/ContentPanel/InventoryContent/InvHBox/TargetsPanel/TargetsScroll/TargetsList
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
		btn.text = "%s%s" % [item.get_display_name(), qty_text]
		btn.custom_minimum_size = Vector2(200, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_inv_item_selected.bind(i, item))
		inv_list.add_child(btn)
		inv_buttons.append(btn)

	inv_nav = MenuNavigator.new()
	inv_nav.setup(inv_buttons, 0)
	inv_nav.selection_changed.connect(_on_inv_selection_changed)

	if not inv_showing_targets:
		inv_nav.update_focus()


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
		var stats := "%d/%d HP" % [member.current_hp, member.max_hp]
		if inv_selected_item and inv_selected_item.mp_restore > 0 and member.max_mp > 0:
			stats += "  %d/%d MP" % [member.current_mp, member.max_mp]
		btn.text = "%s: %s%s" % [member.character_name, stats, status]
		btn.custom_minimum_size = Vector2(200, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if not _can_use_item_on(inv_selected_item, member):
			btn.disabled = true
			btn.modulate = UIColors.MODULATE_DISABLED

		btn.pressed.connect(_on_inv_target_selected.bind(member))
		inv_targets.add_child(btn)
		inv_target_buttons.append(btn)

	inv_target_nav = MenuNavigator.new()
	inv_target_nav.setup(inv_target_buttons, 0)
	inv_target_nav.update_focus()


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
		info_label.text = "%s cannot be used here. Equip from Status tab." % item.item_name
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

	var text := "[b]%s[/b]\n%s\n%s" % [item.get_display_name(), item.get_type_name(), item.get_stats_text()]
	if not item.is_identified and GameState.party.has_living_bishop():
		text += "\n\n[color=cyan][Press I to identify (Bishop)][/color]"
	elif item.item_type == Item.ItemType.CONSUMABLE:
		text += "\n\n[Press Enter to use]"
	elif item.is_equipment():
		text += "\n\n[Equip from Status tab]"
	info_label.text = text


func _handle_inventory_input(event: InputEvent) -> void:
	if not inv_showing_targets and event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_I:
			_try_identify_current_item()
			get_viewport().set_input_as_handled()
			return

	var active_nav: MenuNavigator = inv_target_nav if inv_showing_targets else inv_nav

	if active_nav == null:
		return

	active_nav.handle_input(event)


func _try_identify_current_item() -> void:
	if inv_nav == null or inv_buttons.is_empty():
		return
	var idx := inv_nav.get_current_index()
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
	_refresh_inventory()


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
		btn.modulate = UIColors.MODULATE_DEAD if character.is_dead else Color.WHITE
	else:
		btn.text = "(Empty)"
		btn.modulate = UIColors.MODULATE_DISABLED


func _update_formation_selection() -> void:
	for i in range(form_slot_buttons.size()):
		var btn := form_slot_buttons[i]
		if i == form_selected_index:
			btn.add_theme_color_override("font_color", UIColors.TEXT_ACTIVE)
			btn.add_theme_color_override("font_hover_color", UIColors.TEXT_ACTIVE)
		elif i == form_current_slot:
			btn.add_theme_color_override("font_color", UIColors.WARNING)
			btn.add_theme_color_override("font_hover_color", UIColors.WARNING)
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
			btn.modulate = UIColors.MODULATE_DEAD
		elif member.is_silenced():
			btn.modulate = UIColors.MODULATE_DISABLED
		btn.pressed.connect(_on_spell_party_selected.bind(member))
		spell_party_list.add_child(btn)
		spell_party_buttons.append(btn)

	spell_party_nav = MenuNavigator.new()
	spell_party_nav.setup(spell_party_buttons, 0)
	spell_party_nav.selection_changed.connect(_on_spell_party_nav_changed)

	if spell_panel == SpellPanel.PARTY:
		spell_party_nav.update_focus()


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
			btn.modulate = UIColors.MODULATE_DISABLED
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
			btn.modulate = UIColors.MODULATE_DISABLED
		elif spell_selected_character.current_mp < spell.mp_cost:
			btn.modulate = UIColors.MODULATE_DISABLED
		elif spell_selected_character.is_dead or spell_selected_character.is_silenced() or spell_selected_character.is_disabled():
			btn.modulate = UIColors.MODULATE_DISABLED

		btn.pressed.connect(_on_spell_selected.bind(spell))
		spell_list.add_child(btn)
		spell_list_buttons.append(btn)

	spell_list_nav = MenuNavigator.new()
	spell_list_nav.setup(spell_list_buttons, 0)
	spell_list_nav.selection_changed.connect(_on_spell_list_nav_changed)

	if spell_panel == SpellPanel.LIST:
		spell_list_nav.update_focus()


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
			btn.modulate = UIColors.MODULATE_DISABLED

		btn.pressed.connect(_on_spell_target_selected.bind(member))
		spell_target_list.add_child(btn)
		spell_target_buttons.append(btn)

	spell_target_nav = MenuNavigator.new()
	spell_target_nav.setup(spell_target_buttons, 0)
	spell_target_nav.update_focus()


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
	var active_nav: MenuNavigator = null
	match spell_panel:
		SpellPanel.PARTY:
			active_nav = spell_party_nav
		SpellPanel.LIST:
			active_nav = spell_list_nav
		SpellPanel.TARGETS:
			active_nav = spell_target_nav

	if active_nav == null:
		return

	active_nav.handle_input(event)


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


# === KEYBINDINGS TAB ===

var keybind_nav: MenuNavigator = null
var keybind_buttons: Array[Button] = []
var keybind_actions: Array[String] = []
var keybind_selected_action: String = ""
var _keybind_listening := false
var _keybind_listen_slot := 0


func _refresh_keybindings() -> void:
	for child in keybind_action_list.get_children():
		child.queue_free()
	keybind_buttons.clear()
	keybind_actions.clear()

	for action: String in KeybindSettings.BINDABLE_ACTIONS:
		var label: String = KeybindSettings.BINDABLE_ACTIONS[action]
		var keys := KeybindSettings.get_action_keys(action)
		var key_text := ""
		if keys.size() > 0:
			key_text = KeybindSettings.key_to_label(keys[0])
		if keys.size() > 1:
			key_text += " / " + KeybindSettings.key_to_label(keys[1])

		var btn := Button.new()
		btn.text = "%s  [%s]" % [label, key_text]
		btn.custom_minimum_size = Vector2(300, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_keybind_action_selected.bind(action))
		keybind_action_list.add_child(btn)
		keybind_buttons.append(btn)
		keybind_actions.append(action)

	var separator := Label.new()
	separator.text = ""
	keybind_action_list.add_child(separator)
	var header := Label.new()
	header.text = "--- Debug Keys (Dungeon) ---"
	header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	keybind_action_list.add_child(header)

	var debug_keys := [
		["X", "Force Combat"],
		["Shift+X", "Level Party +1"],
		["Ctrl+X", "Level Party +5"],
		["Shift+C", "Toggle Combat Math"],
		["Shift+F", "Next Floor"],
		["Ctrl+F", "Previous Floor"],
		["G", "Add 1000 Gold"],
		["K", "Add Dungeon Key"],
		["Shift+S", "Run Simulation"],
		["Shift+B", "Run Batch Sim"],
		["Ctrl+L", "Toggle AI Log"],
		["Ctrl+E", "Force Micro Event"],
		["Ctrl+V", "Toggle Verbose Debug"],
	]
	for entry in debug_keys:
		var dbtn := Button.new()
		dbtn.text = "%s  [%s]" % [entry[1], entry[0]]
		dbtn.custom_minimum_size = Vector2(300, 32)
		dbtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		dbtn.disabled = true
		dbtn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
		keybind_action_list.add_child(dbtn)

	var restore_index := keybind_actions.find(keybind_selected_action)
	if restore_index < 0:
		restore_index = 0

	keybind_nav = MenuNavigator.new()
	keybind_nav.setup(keybind_buttons, restore_index)
	keybind_nav.selection_changed.connect(_on_keybind_selection_changed)

	if not keybind_clear_btn.pressed.is_connected(_on_keybind_clear_secondary):
		keybind_clear_btn.pressed.connect(_on_keybind_clear_secondary)
		keybind_reset_btn.pressed.connect(_on_keybind_reset_defaults)
		keybind_primary_btn.pressed.connect(_on_keybind_primary_pressed)
		keybind_secondary_btn.pressed.connect(_on_keybind_secondary_pressed)

	if not keybind_actions.is_empty():
		keybind_selected_action = keybind_actions[0]
		_update_keybind_detail()

	info_label.text = "Select an action to rebind its key."
	_update_help()


func _on_keybind_action_selected(action: String) -> void:
	keybind_selected_action = action
	_start_listening(0)


func _on_keybind_selection_changed(index: int) -> void:
	if index >= 0 and index < keybind_actions.size():
		keybind_selected_action = keybind_actions[index]
		_update_keybind_detail()


func _update_keybind_detail() -> void:
	if keybind_selected_action.is_empty():
		keybind_primary_label.text = "Primary: "
		keybind_primary_btn.text = "(none)"
		keybind_secondary_label.text = "Secondary: "
		keybind_secondary_btn.text = "(none)"
		return

	var keys := KeybindSettings.get_action_keys(keybind_selected_action)
	var label: String = KeybindSettings.BINDABLE_ACTIONS.get(keybind_selected_action, "")
	keybind_primary_label.text = "Primary:"
	keybind_secondary_label.text = "Secondary:"

	if keys.size() > 0:
		keybind_primary_btn.text = KeybindSettings.key_to_label(keys[0])
	else:
		keybind_primary_btn.text = "(none)"

	if keys.size() > 1:
		keybind_secondary_btn.text = KeybindSettings.key_to_label(keys[1])
	else:
		keybind_secondary_btn.text = "(none)"

	info_label.text = "[b]%s[/b]\nEnter: rebind primary | S: rebind secondary" % label


func _on_keybind_primary_pressed() -> void:
	_start_listening(0)


func _on_keybind_secondary_pressed() -> void:
	_start_listening(1)


func _start_listening(slot: int) -> void:
	_keybind_listening = true
	_keybind_listen_slot = slot
	var slot_name := "primary" if slot == 0 else "secondary"
	var label: String = KeybindSettings.BINDABLE_ACTIONS.get(keybind_selected_action, "")
	info_label.text = "[b]%s[/b]\nPress any key for %s binding..." % [label, slot_name]
	if slot == 0:
		keybind_primary_btn.text = "..."
	else:
		keybind_secondary_btn.text = "..."
	_update_help()


func _apply_listened_key(event: InputEventKey) -> void:
	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if code == KEY_ESCAPE:
		_keybind_listening = false
		_update_keybind_detail()
		_update_help()
		return

	if code == KEY_SHIFT or code == KEY_CTRL or code == KEY_ALT or code == KEY_META:
		return

	var conflict := KeybindSettings.check_conflict(keybind_selected_action, event)
	if conflict != "":
		var key_label := KeybindSettings.key_to_label(KeybindSettings._normalize_event(event))
		_keybind_listening = false
		_update_keybind_detail()
		_update_help()
		info_label.text = "[color=yellow]%s is already bound to %s.[/color]\nClear it there first, then try again." % [key_label, conflict]
		return

	KeybindSettings.rebind_action(keybind_selected_action, _keybind_listen_slot, event)
	_keybind_listening = false
	_refresh_keybindings()


func _on_keybind_clear_secondary() -> void:
	if keybind_selected_action.is_empty():
		return
	var keys := KeybindSettings.get_action_keys(keybind_selected_action)
	if keys.size() > 1:
		InputMap.action_erase_event(keybind_selected_action, keys[1])
		KeybindSettings._save_bindings()
		_refresh_keybindings()


func _on_keybind_reset_defaults() -> void:
	KeybindSettings.reset_defaults()
	_refresh_keybindings()
	info_label.text = "All keybindings reset to defaults."


func _handle_keybindings_input(event: InputEvent) -> void:
	if keybind_nav == null:
		return

	if event.is_action_pressed("menu_select") and not keybind_selected_action.is_empty():
		_start_listening(1)
		return

	if event.is_action_pressed("menu_sort"):
		_on_keybind_clear_secondary()
		return

	if event.is_action_pressed("menu_reorder"):
		_on_keybind_reset_defaults()
		return

	keybind_nav.handle_input(event)
