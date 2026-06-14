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

var _story_overlay: Control = null
var _story_overlay_title: Label = null
var _story_overlay_label: RichTextLabel = null
var _story_overlay_open: bool = false

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
	_build_story_overlay()
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

	if _story_overlay_open:
		_hide_story_overlay()

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

	# The story overlay is modal: S or Esc dismiss it, everything else is held.
	if _story_overlay_open:
		if event.is_action_pressed("menu_cancel") or event.is_action_pressed("menu_select"):
			_hide_story_overlay()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("menu_cancel"):
		_handle_back()
		return

	if event.is_action_pressed("menu_left"):
		if current_tab == Tab.STATUS and _status_in_equip_mode:
			_cycle_equip_character(-1)
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
	if _story_overlay_open:
		help_label.text = "S / Esc:  Close story"
		return

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
					help_label.text = "%s: Item | %s: Equip | ←/→: Char | %s: Back" % [v_nav, confirm.split(":")[0], cancel]
				else:
					help_label.text = "%s: Slot | %s: Items | ←/→: Char | %s: Back" % [v_nav, confirm.split(":")[0], cancel]
			else:
				var select_key := KeyBindingHelper.get_action_key("menu_select")
				help_label.text = "%s: Member | %s: Equip | %s: Story | ←/→: Tabs | %s" % [v_nav, confirm.split(":")[0], select_key, cancel]
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

@onready var character_tabs: VBoxContainer = $MainPanel/VBox/ContentPanel/StatusContent/StatusHBox/MemberRail/RailMargin/CharacterTabs
@onready var character_sheet: Control = $MainPanel/VBox/ContentPanel/StatusContent/StatusHBox/DetailPanel/CharacterSheet
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
		var btn := _build_member_button(member, i)
		btn.pressed.connect(_on_status_member_selected.bind(i))
		character_tabs.add_child(btn)
		status_buttons.append(btn)

	# The rail is the screen's primary navigation: a member is always in focus
	# and the dossier mirrors it live (no separate "enter the tab row" step).
	_status_on_character_tabs = true
	_status_selected_index = 0
	_update_status_info(0)
	_update_status_tab_highlight()


## One member row in the left rail: a full-width card button with class crest,
## name, level and a slim HP bar. Selection shows via the accent-bordered
## "pressed" style; the dossier on the right mirrors whichever row is current.
func _build_member_button(member: Character, _index: int) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_ALL
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 54)
	_style_member_button(btn)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	btn.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)

	row.add_child(_member_crest(member))

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)

	var name_lbl := Label.new()
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.text = member.character_name
	var name_color := UIColors.TEXT_DANGER if member.is_dead else \
		(UIColors.TEXT_WARNING if _has_negative_status(member) else UIColors.TEXT_PRIMARY)
	name_lbl.add_theme_color_override("font_color", name_color)
	top.add_child(name_lbl)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	var lvl := Label.new()
	lvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lvl.text = "L%d" % member.level
	lvl.add_theme_font_size_override("font_size", 12)
	lvl.add_theme_color_override("font_color", UIColors.TEXT_MUTED)
	lvl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(lvl)

	col.add_child(_member_hp_bar(member))
	return btn


func _member_crest(member: Character) -> Label:
	var dead := member.is_dead
	var color := UIColors.class_color(member.character_class)
	var b := Label.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.text = CharacterEnums.get_class_name(member.character_class).substr(0, 1).to_upper()
	b.custom_minimum_size = Vector2(30, 30)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", UIColors.TEXT_MUTED if dead else color.lightened(0.45))
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.SURFACE_PRESSED if dead else color.darkened(0.55)
	sb.set_corner_radius_all(7)
	sb.set_border_width_all(1)
	sb.border_color = UIColors.BORDER_DEFAULT if dead else color
	b.add_theme_stylebox_override("normal", sb)
	return b


## A slim, color-coded HP bar so the whole party's health reads at a glance.
func _member_hp_bar(member: Character) -> Control:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 5)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var cap := Label.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.text = "HP"
	cap.add_theme_font_size_override("font_size", 10)
	cap.add_theme_color_override("font_color", UIColors.TEXT_MUTED)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(cap)

	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.min_value = 0
	bar.max_value = maxi(1, member.max_hp)
	bar.value = 0 if member.is_dead else member.current_hp

	var pct := float(member.current_hp) / float(maxi(1, member.max_hp))
	var fill_color := UIColors.HP_GREEN
	if member.is_dead or pct < 0.25:
		fill_color = UIColors.DANGER
	elif pct < 0.5:
		fill_color = UIColors.WARNING
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = UIColors.SURFACE_BAR_BG
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	box.add_child(bar)
	return box


func _style_member_button(btn: Button) -> void:
	var flat := StyleBoxFlat.new()
	flat.bg_color = UIColors.SURFACE_CARD
	flat.set_corner_radius_all(8)
	flat.set_border_width_all(1)
	flat.border_color = UIColors.BORDER_SUBTLE

	var hover := flat.duplicate() as StyleBoxFlat
	hover.bg_color = UIColors.SURFACE_HOVER
	hover.border_color = UIColors.BORDER_HOVER

	var selected := flat.duplicate() as StyleBoxFlat
	selected.bg_color = UIColors.SURFACE_SELECTED
	selected.set_border_width_all(2)
	selected.border_color = UIColors.ACCENT

	var focus := selected.duplicate() as StyleBoxFlat
	focus.border_color = UIColors.BORDER_FOCUS

	btn.add_theme_stylebox_override("normal", flat)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", selected)
	btn.add_theme_stylebox_override("focus", focus)


func _on_status_member_selected(index: int) -> void:
	# A click on the already-focused member dives into equipment; otherwise it
	# just moves the cursor to that member.
	if index == _status_selected_index and not _status_in_equip_mode:
		_status_in_equip_mode = true
		character_sheet.enter_equip_mode()
		var focused := get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()
		_update_status_tab_highlight()
		_update_help()
		return
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
	# While editing equipment the focus lives in the dossier, so dim the rail and
	# the main tab row to make that obvious; otherwise the rail is fully lit.
	var dimmed := _status_in_equip_mode
	for btn in tab_buttons:
		btn.modulate.a = 0.5 if dimmed else 1.0
	for i in range(status_buttons.size()):
		status_buttons[i].button_pressed = (i == _status_selected_index)
		status_buttons[i].modulate.a = 0.55 if dimmed else 1.0


func _handle_status_input(event: InputEvent) -> void:
	if status_buttons.is_empty():
		return

	if _status_in_equip_mode:
		if character_sheet.handle_equip_input(event):
			if character_sheet.get_equip_mode() == 0:
				_status_in_equip_mode = false
				_update_status_tab_highlight()
			_update_help()
		return

	# Up/down move the member cursor; the dossier on the right mirrors it live.
	if event.is_action_pressed("menu_down"):
		_update_status_info((_status_selected_index + 1) % status_buttons.size())
		_update_help()
		return
	if event.is_action_pressed("menu_up"):
		_update_status_info((_status_selected_index - 1 + status_buttons.size()) % status_buttons.size())
		_update_help()
		return

	# Enter dives into equipment; select cycles the dossier's story focus.
	if event.is_action_pressed("menu_confirm"):
		_status_in_equip_mode = true
		character_sheet.enter_equip_mode()
		var focused := get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()
		_update_status_tab_highlight()
		_update_help()
		return
	if event.is_action_pressed("menu_select"):
		_toggle_story_overlay()
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


# === STORY OVERLAY ===
# The full character story (personality / bonds / marks) shown as a centered
# card on top of everything, so the dossier never has to give up height for it.


func _build_story_overlay() -> void:
	_story_overlay = Control.new()
	_story_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_story_overlay.visible = false

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.74)
	_story_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_story_overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.SURFACE_PANEL
	sb.set_corner_radius_all(UITheme.RADIUS_PANEL)
	sb.set_border_width_all(1)
	sb.border_color = UIColors.BORDER_DEFAULT
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 20
	sb.content_margin_bottom = 18
	sb.shadow_color = UIColors.SHADOW
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	_story_overlay_title = Label.new()
	_story_overlay_title.theme_type_variation = &"HeaderLabel"
	vb.add_child(_story_overlay_title)

	var rule := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = UIColors.BORDER_SUBTLE
	line.thickness = 1
	rule.add_theme_stylebox_override("separator", line)
	vb.add_child(rule)

	_story_overlay_label = RichTextLabel.new()
	_story_overlay_label.bbcode_enabled = true
	_story_overlay_label.fit_content = true
	_story_overlay_label.scroll_active = false
	_story_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_overlay_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_story_overlay_label.custom_minimum_size = Vector2(508, 0)
	vb.add_child(_story_overlay_label)

	var hint := Label.new()
	hint.theme_type_variation = &"MutedLabel"
	hint.text = "S / Esc   Close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)

	add_child(_story_overlay)


func _toggle_story_overlay() -> void:
	if _story_overlay_open:
		_hide_story_overlay()
	else:
		_show_story_overlay()


func _show_story_overlay() -> void:
	if status_buttons.is_empty() or GameState.party == null:
		return
	var member: Character = GameState.party.get_member_at(_status_selected_index)
	_story_overlay_title.text = "%s  ·  Story" % member.character_name
	_story_overlay_label.text = character_sheet.get_story_detail()
	_story_overlay.visible = true
	_story_overlay_open = true
	_update_help()


func _hide_story_overlay() -> void:
	_story_overlay.visible = false
	_story_overlay_open = false
	_update_help()
