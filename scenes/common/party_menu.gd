extends Control

signal closed()

enum Tab { STATUS, INVENTORY, FORMATION, SPELLS, KEYBINDINGS }

var current_tab: Tab = Tab.STATUS
var tab_buttons: Array[Button] = []
var tab_nav: MenuNavigator = null

var _scaffold: ScreenScaffold = null

var status_buttons: Array[Button] = []
var _status_on_character_tabs: bool = false
var _status_in_equip_mode: bool = false

var _inventory_tab: PartyMenuInventoryTab = null
var _formation_tab: PartyMenuFormationTab = null
var _spells_tab: PartyMenuSpellsTab = null
var _keybindings_tab: PartyMenuKeybindingsTab = null

@onready var tab_container: HBoxContainer = $MainPanel/VBox/TabBar/TabContainer
@onready var content_panel: PanelContainer = $MainPanel/VBox/ContentPanel
@onready var status_content: Control = $MainPanel/VBox/ContentPanel/StatusContent
@onready var inventory_content: Control = $MainPanel/VBox/ContentPanel/InventoryContent
@onready var formation_content: Control = $MainPanel/VBox/ContentPanel/FormationContent
@onready var inv_list: VBoxContainer = $MainPanel/VBox/ContentPanel/InventoryContent/InvHBox/ItemsPanel/ItemsScroll/ItemsList
@onready var inv_targets: VBoxContainer = $MainPanel/VBox/ContentPanel/InventoryContent/InvHBox/TargetsPanel/TargetsScroll/TargetsList
@onready var inv_targets_panel: PanelContainer = $MainPanel/VBox/ContentPanel/InventoryContent/InvHBox/TargetsPanel
@onready var form_front_row: HBoxContainer = $MainPanel/VBox/ContentPanel/FormationContent/FormVBox/FrontRowHBox/FrontRow
@onready var form_back_row: HBoxContainer = $MainPanel/VBox/ContentPanel/FormationContent/FormVBox/BackRowHBox/BackRow
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
	_install_scaffold()
	_inventory_tab = PartyMenuInventoryTab.new()
	_inventory_tab.init(inv_list, inv_targets, inv_targets_panel, info_label)
	_formation_tab = PartyMenuFormationTab.new()
	_formation_tab.init(form_front_row, form_back_row, info_label)
	_spells_tab = PartyMenuSpellsTab.new()
	_spells_tab.init(spell_party_list, spell_level_tabs, spell_list, spell_target_panel, spell_target_list, info_label)
	_keybindings_tab = PartyMenuKeybindingsTab.new()
	_keybindings_tab.init(keybind_action_list, keybind_primary_label, keybind_primary_btn, keybind_secondary_label, keybind_secondary_btn, keybind_clear_btn, keybind_reset_btn, info_label)
	_setup_tabs()
	_switch_tab(Tab.STATUS)


## Wrap the existing panel in the shared ScreenScaffold so the Party Menu gets
## the same top-bar (PARTY title + live date/gold), Back affordance, corner
## frame and backdrop as every other screen.
func _install_scaffold() -> void:
	var main: Control = $MainPanel
	remove_child(main)

	var bg := get_node_or_null("Background")
	if bg != null:
		bg.queue_free()

	_scaffold = ScreenScaffold.create({"title": "PARTY", "hint": ""})
	add_child(_scaffold)
	_scaffold.back_pressed.connect(func() -> void: _handle_back())

	main.add_theme_constant_override("margin_left", 6)
	main.add_theme_constant_override("margin_right", 6)
	main.add_theme_constant_override("margin_top", 0)
	main.add_theme_constant_override("margin_bottom", 0)
	_scaffold.body.add_child(main)


func _setup_tabs() -> void:
	for child in tab_container.get_children():
		child.queue_free()
	tab_buttons.clear()

	var tab_names := ["Status", "Inventory", "Formation", "Spells", "Keys"]
	for i in range(tab_names.size()):
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.custom_minimum_size = Vector2(120, 34)
		btn.toggle_mode = true
		_style_tab(btn)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		tab_container.add_child(btn)
		tab_buttons.append(btn)

	tab_nav = MenuNavigator.new()
	tab_nav.setup(tab_buttons, 0)


## Make the flat tab buttons read as real tabs: the active (toggled / focused)
## tab gets the arcane-accent underline; inactive tabs stay quiet.
func _style_tab(btn: Button) -> void:
	btn.focus_mode = Control.FOCUS_ALL

	var flat := StyleBoxFlat.new()
	flat.bg_color = UIColors.SURFACE_BACKGROUND
	flat.corner_radius_top_left = 6
	flat.corner_radius_top_right = 6
	flat.content_margin_left = 14
	flat.content_margin_right = 14
	flat.content_margin_top = 8
	flat.content_margin_bottom = 8

	var hover := flat.duplicate() as StyleBoxFlat
	hover.bg_color = UIColors.SURFACE_HOVER

	var active := flat.duplicate() as StyleBoxFlat
	active.bg_color = UIColors.SURFACE_CARD
	active.border_width_bottom = 3
	active.border_color = UIColors.ACCENT

	var focus := active.duplicate() as StyleBoxFlat
	focus.border_color = UIColors.BORDER_FOCUS

	btn.add_theme_stylebox_override("normal", flat)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", active)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", UIColors.TEXT_PRIMARY)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)


func _switch_tab(tab: Tab) -> void:
	current_tab = tab

	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()

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
		_keybindings_tab.listening = false
	if tab != Tab.SPELLS:
		_spells_tab.panel = PartyMenuSpellsTab.SpellPanel.PARTY
		_spells_tab.selected_character = null
		_spells_tab.selected_spell = null

	match tab:
		Tab.STATUS:
			_refresh_status()
		Tab.INVENTORY:
			_inventory_tab.refresh()
		Tab.FORMATION:
			_formation_tab.refresh()
		Tab.SPELLS:
			_spells_tab.refresh()
		Tab.KEYBINDINGS:
			_keybindings_tab.refresh()

	_update_help()


func _on_tab_pressed(tab_index: int) -> void:
	_switch_tab(tab_index as Tab)


func _unhandled_input(event: InputEvent) -> void:
	if _keybindings_tab.is_listening() and event is InputEventKey and (event as InputEventKey).pressed:
		_keybindings_tab.apply_listened_key(event as InputEventKey)
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
		if current_tab == Tab.SPELLS and _spells_tab.panel == PartyMenuSpellsTab.SpellPanel.LIST:
			_spells_tab.cycle_level(-1)
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
		if current_tab == Tab.SPELLS and _spells_tab.panel == PartyMenuSpellsTab.SpellPanel.LIST:
			_spells_tab.cycle_level(1)
			return
		var new_tab := (current_tab + 1) % Tab.size()
		_switch_tab(new_tab as Tab)
		return

	match current_tab:
		Tab.STATUS:
			_handle_status_input(event)
		Tab.INVENTORY:
			_inventory_tab.handle_input(event)
		Tab.FORMATION:
			_formation_tab.handle_input(event)
		Tab.SPELLS:
			_spells_tab.handle_input(event)
		Tab.KEYBINDINGS:
			_keybindings_tab.handle_input(event)


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
			if _inventory_tab.handle_back():
				return true
		Tab.FORMATION:
			if _formation_tab.handle_back():
				_update_help()
				return true
		Tab.SPELLS:
			if _spells_tab.handle_back():
				_update_help()
				return true
		Tab.KEYBINDINGS:
			if _keybindings_tab.handle_back():
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
			if _inventory_tab.showing_targets:
				help_label.text = base + "%s | %s: Use | %s" % [v_nav, confirm.split(":")[0], cancel]
			else:
				var id_hint := " | I: Identify" if GameState.party and GameState.party.has_living_bishop() else ""
				help_label.text = base + "%s | %s: Use%s | %s" % [v_nav, confirm.split(":")[0], id_hint, cancel]
		Tab.FORMATION:
			if _formation_tab.selected_index >= 0:
				help_label.text = base + "%s | %s: Swap | %s" % [arrow_nav, confirm.split(":")[0], cancel]
			else:
				help_label.text = base + "%s | %s | %s" % [arrow_nav, confirm, cancel]
		Tab.SPELLS:
			match _spells_tab.panel:
				PartyMenuSpellsTab.SpellPanel.PARTY:
					help_label.text = base + "%s | %s | %s" % [v_nav, confirm, cancel]
				PartyMenuSpellsTab.SpellPanel.LIST:
					help_label.text = base + "%s | %s: Spell Level | %s: Cast | %s" % [v_nav, tab_help.split(":")[0], confirm.split(":")[0], cancel]
				PartyMenuSpellsTab.SpellPanel.TARGETS:
					help_label.text = base + "%s | %s: Cast | %s" % [v_nav, confirm.split(":")[0], cancel]
		Tab.KEYBINDINGS:
			if _keybindings_tab.is_listening():
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
		btn.custom_minimum_size = Vector2(86, 46)
		btn.clip_text = true
		btn.toggle_mode = true
		if member.is_dead:
			btn.modulate = UIColors.MODULATE_DEAD
		elif _has_negative_status(member):
			btn.modulate = UIColors.TEXT_WARNING
		_add_member_hp_bar(btn, member)
		btn.pressed.connect(_on_status_member_selected.bind(i))
		character_tabs.add_child(btn)
		status_buttons.append(btn)

	_status_selected_index = 0
	_update_status_info(0)


## Adds a slim, color-coded HP bar along the bottom edge of a roster button so
## the whole party's health is readable at a glance.
func _add_member_hp_bar(btn: Button, member: Character) -> void:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.min_value = 0
	bar.max_value = maxi(1, member.max_hp)
	bar.value = member.current_hp
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = -9
	bar.offset_bottom = -5

	var pct := float(member.current_hp) / float(maxi(1, member.max_hp))
	var fill_color := UIColors.HP_GREEN
	if member.is_dead or pct < 0.25:
		fill_color = UIColors.DANGER
	elif pct < 0.5:
		fill_color = UIColors.WARNING

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = UIColors.SURFACE_BAR_BG
	bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg)

	btn.add_child(bar)


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
