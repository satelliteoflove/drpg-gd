extends Control

enum Tab { CREATE, ROSTER, PARTY }
enum RosterMode { VIEW, MANAGE, CONFIRM_DELETE, RENAME, CHANGE_CLASS, ASSIGN_JOB }
enum PartyMode { NORMAL, REORDER_SELECT, REORDER_MOVE, FORMATION_LIST, FORMATION_SAVE, FORMATION_MANAGE }
enum SortMode { DEFAULT, NAME, LEVEL, CLASS, RACE }

const MAX_FORMATIONS: int = 10

var current_tab: Tab = Tab.CREATE
var roster_mode: RosterMode = RosterMode.VIEW
var party_mode: PartyMode = PartyMode.NORMAL
var party_focus: int = 0
var selected_character: Character = null
var reorder_index: int = -1
var _reorder_original_ids: Array[String] = []
var _reorder_pre_grab_ids: Array[String] = []
var roster_sort_mode: SortMode = SortMode.DEFAULT
var _displayed_roster_chars: Array[Character] = []
var _displayed_available_chars: Array[Character] = []
var _selected_formation: PartyFormation = null
var formation_name_edit: LineEdit = null

var nav: MenuNavigator = null
var buttons: Array[Button] = []
var party_nav: MenuNavigator = null
var roster_nav: MenuNavigator = null
var party_buttons: Array[Button] = []
var roster_buttons: Array[Button] = []
var rename_edit: LineEdit = null

@onready var title_label: Label = $MainHBox/LeftPanel/Header/TitleLabel
@onready var count_label: Label = $MainHBox/LeftPanel/Header/CountLabel
var _date_labels: Dictionary = {}
var roster_value_label: Label = null
@onready var tab_bar: TabBar = $MainHBox/LeftPanel/TabBar
@onready var options_panel: PanelContainer = $MainHBox/LeftPanel/OptionsPanel
@onready var options_list: VBoxContainer = $MainHBox/LeftPanel/OptionsPanel/ScrollContainer/OptionsList
@onready var message_label: Label = $MainHBox/LeftPanel/MessageLabel
@onready var help_label: Label = $MainHBox/LeftPanel/HelpLabel
@onready var back_button: Button = $MainHBox/LeftPanel/BackButton
@onready var info_panel: PanelContainer = $MainHBox/RightPanel/InfoPanel
@onready var info_label: RichTextLabel = $MainHBox/RightPanel/InfoPanel/InfoLabel
@onready var roster_label: Label = $MainHBox/RightPanel/RosterLabel
@onready var roster_panel: PanelContainer = $MainHBox/RightPanel/RosterPanel
@onready var roster_list: VBoxContainer = $MainHBox/RightPanel/RosterPanel/ScrollContainer/RosterList


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	tab_bar.tab_changed.connect(_on_tab_changed)
	_build_header_grid()

	if GameState.has_party():
		current_tab = Tab.PARTY
	elif not GameState.roster.is_empty():
		current_tab = Tab.PARTY
	else:
		current_tab = Tab.CREATE
	tab_bar.current_tab = current_tab
	_refresh_display()


func _build_header_grid() -> void:
	count_label.hide()
	var header: HBoxContainer = title_label.get_parent()
	_date_labels = GameCalendar.create_date_grid(GameState.game_day)
	var grid: GridContainer = _date_labels["grid"]
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_SHRINK_END
	var roster_header := Label.new()
	roster_header.text = "Roster"
	roster_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roster_header.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SMALL)
	roster_header.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	grid.add_child(roster_header)
	grid.move_child(roster_header, 3)
	roster_value_label = Label.new()
	roster_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid.add_child(roster_value_label)
	header.add_child(grid)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.shift_pressed and event.keycode == KEY_D:
		GameState.advance_game_days(30)
		message_label.text = "DEBUG: Advanced 30 days. Now %s." % GameCalendar.format_short(GameState.game_day)
		_refresh_display()


func _on_tab_changed(tab_index: int) -> void:
	current_tab = tab_index as Tab
	roster_mode = RosterMode.VIEW
	party_mode = PartyMode.NORMAL
	selected_character = null
	reorder_index = -1
	roster_sort_mode = SortMode.DEFAULT
	_selected_formation = null
	_refresh_display()


func _refresh_display() -> void:
	if not _date_labels.is_empty():
		GameCalendar.update_date_labels(_date_labels, GameState.game_day)
		roster_value_label.text = "%d/%d" % [GameState.roster.size(), GameState.roster.MAX_SIZE]
	_update_roster_overview()

	match current_tab:
		Tab.CREATE:
			_populate_create_tab()
		Tab.ROSTER:
			_populate_roster_tab()
		Tab.PARTY:
			_populate_party_tab()

	_update_help()


func _populate_create_tab() -> void:
	_clear_options()

	var create_btn := Button.new()
	create_btn.text = "Create New Character"
	create_btn.custom_minimum_size = Vector2(350, 40)

	if GameState.roster.is_full():
		create_btn.disabled = true
		create_btn.modulate = UIColors.MODULATE_DISABLED
	else:
		create_btn.pressed.connect(_on_create_character)

	options_list.add_child(create_btn)
	buttons.append(create_btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	options_list.add_child(spacer)

	var capacity_label := Label.new()
	capacity_label.text = "Roster: %d / %d characters" % [GameState.roster.size(), GameState.roster.MAX_SIZE]
	capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options_list.add_child(capacity_label)

	if GameState.roster.is_full():
		message_label.text = "Roster is full. Delete a character to make room."
	else:
		message_label.text = "Create a new adventurer to join the guild."

	_setup_nav()

	var text := "[b]Create Character[/b]\n\n"
	text += "Create a new adventurer by choosing their race,\n"
	text += "background, stats, class, alignment, and name.\n\n"
	text += "[color=cyan]Roster capacity:[/color] %d/%d\n" % [
		GameState.roster.size(), GameState.roster.MAX_SIZE
	]
	if GameState.roster.is_full():
		text += "\n[color=red]Roster is full! Delete a character to make room.[/color]"
	info_label.text = text


func _populate_roster_tab() -> void:
	match roster_mode:
		RosterMode.VIEW:
			_populate_roster_view()
			message_label.text = "Select a character to manage."
		RosterMode.MANAGE:
			_populate_manage_actions()
		RosterMode.CONFIRM_DELETE:
			_populate_delete_confirm()
			message_label.text = "Are you sure you want to delete this character?"
		RosterMode.RENAME:
			_populate_rename_screen()
			message_label.text = "Enter a new name for the character."
		RosterMode.CHANGE_CLASS:
			_populate_class_change()
			message_label.text = "Select a new class. Training required."
		RosterMode.ASSIGN_JOB:
			_populate_job_assignment()
			message_label.text = "Select a job for %s." % selected_character.character_name

	_update_roster_info()


func _populate_roster_view() -> void:
	_clear_options()

	_displayed_roster_chars = _sort_characters(GameState.roster.get_all())
	for character in _displayed_roster_chars:
		var btn := Button.new()
		btn.text = "%s - L%d %s %s" % [
			character.character_name,
			character.level,
			CharacterEnums.get_race_name(character.race),
			CharacterEnums.get_class_name(character.character_class)
		]
		btn.custom_minimum_size = Vector2(350, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if character.is_dead:
			btn.modulate = UIColors.MODULATE_DEAD
		elif character.is_training():
			btn.modulate = UIColors.TEXT_WARNING
		elif GameState.party.has_member(character):
			btn.modulate = UIColors.TEXT_IN_PARTY

		options_list.add_child(btn)
		buttons.append(btn)

	if buttons.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(No characters in roster)"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		options_list.add_child(empty_label)

	_setup_nav()


func _populate_manage_actions() -> void:
	_clear_options()

	if selected_character == null:
		roster_mode = RosterMode.VIEW
		_populate_roster_view()
		return

	var header := Label.new()
	header.text = "Managing: %s" % selected_character.character_name
	options_list.add_child(header)

	var rename_btn := Button.new()
	rename_btn.text = "Rename"
	rename_btn.custom_minimum_size = Vector2(350, 36)
	rename_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	rename_btn.pressed.connect(_on_manage_action.bind("rename"))
	options_list.add_child(rename_btn)
	buttons.append(rename_btn)

	var reclass_btn := Button.new()
	reclass_btn.text = "Change Class"
	reclass_btn.custom_minimum_size = Vector2(350, 36)
	reclass_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	reclass_btn.pressed.connect(_on_manage_action.bind("change_class"))
	options_list.add_child(reclass_btn)
	buttons.append(reclass_btn)

	var job_btn := Button.new()
	job_btn.text = "Assign Job"
	job_btn.custom_minimum_size = Vector2(350, 36)
	job_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if selected_character.is_dead or selected_character.is_training() or GameState.party.has_member(selected_character):
		job_btn.disabled = true
		job_btn.modulate = UIColors.MODULATE_DISABLED
	else:
		job_btn.pressed.connect(_on_manage_action.bind("assign_job"))
	options_list.add_child(job_btn)
	buttons.append(job_btn)

	var delete_btn := Button.new()
	delete_btn.text = "Delete"
	delete_btn.custom_minimum_size = Vector2(350, 36)
	delete_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	delete_btn.add_theme_color_override("font_color", UIColors.TEXT_DANGER)
	delete_btn.pressed.connect(_on_manage_action.bind("delete"))
	options_list.add_child(delete_btn)
	buttons.append(delete_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(350, 36)
	cancel_btn.pressed.connect(_on_roster_mode_back)
	options_list.add_child(cancel_btn)
	buttons.append(cancel_btn)

	message_label.text = "Choose an action for %s." % selected_character.character_name
	_setup_nav()
	_update_roster_info()


func _populate_delete_confirm() -> void:
	_clear_options()

	if selected_character == null:
		_on_roster_mode_back()
		return

	var confirm_btn := Button.new()
	confirm_btn.text = "Yes, delete %s" % selected_character.character_name
	confirm_btn.custom_minimum_size = Vector2(350, 36)
	confirm_btn.add_theme_color_override("font_color", UIColors.TEXT_DANGER)
	confirm_btn.pressed.connect(_on_delete_confirmed)
	options_list.add_child(confirm_btn)
	buttons.append(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "No, keep character"
	cancel_btn.custom_minimum_size = Vector2(350, 36)
	cancel_btn.pressed.connect(_on_roster_mode_back)
	options_list.add_child(cancel_btn)
	buttons.append(cancel_btn)

	_setup_nav()
	if nav:
		nav.select(1)


func _populate_rename_screen() -> void:
	_clear_options()

	if selected_character == null:
		_on_roster_mode_back()
		return

	var label := Label.new()
	label.text = "Current name: %s" % selected_character.character_name
	options_list.add_child(label)

	rename_edit = LineEdit.new()
	rename_edit.placeholder_text = "New name"
	rename_edit.text = selected_character.character_name
	rename_edit.custom_minimum_size = Vector2(350, 36)
	rename_edit.max_length = 20
	rename_edit.text_submitted.connect(_on_rename_submitted)
	options_list.add_child(rename_edit)
	rename_edit.grab_focus()
	rename_edit.select_all()

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm Rename"
	confirm_btn.custom_minimum_size = Vector2(350, 36)
	confirm_btn.pressed.connect(_on_rename_confirmed)
	options_list.add_child(confirm_btn)
	buttons.append(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(350, 36)
	cancel_btn.pressed.connect(_on_roster_mode_back)
	options_list.add_child(cancel_btn)
	buttons.append(cancel_btn)


func _populate_class_change() -> void:
	_clear_options()

	if selected_character == null:
		_on_roster_mode_back()
		return

	var stats := {
		"strength": selected_character.strength,
		"intelligence": selected_character.intelligence,
		"piety": selected_character.piety,
		"vitality": selected_character.vitality,
		"agility": selected_character.agility,
		"luck": selected_character.luck
	}

	for class_id: int in CharacterEnums.CharacterClass.values():
		var char_class: CharacterEnums.CharacterClass = class_id as CharacterEnums.CharacterClass
		var meets_reqs := ClassData.meets_requirements(char_class, stats)

		var btn := Button.new()
		btn.text = CharacterEnums.get_class_name(char_class)
		btn.custom_minimum_size = Vector2(350, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if char_class == selected_character.character_class:
			btn.text += " (current)"
			btn.disabled = true
			btn.modulate = UIColors.MODULATE_DISABLED
		elif not meets_reqs:
			btn.disabled = true
			btn.modulate = UIColors.MODULATE_DISABLED
		else:
			btn.pressed.connect(_on_class_change_selected.bind(char_class))

		options_list.add_child(btn)
		buttons.append(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(350, 36)
	cancel_btn.pressed.connect(_on_roster_mode_back)
	options_list.add_child(cancel_btn)
	buttons.append(cancel_btn)

	_setup_nav()


func _populate_party_tab() -> void:
	match party_mode:
		PartyMode.FORMATION_LIST:
			_populate_formation_list()
			return
		PartyMode.FORMATION_SAVE:
			_populate_formation_save()
			return
		PartyMode.FORMATION_MANAGE:
			_populate_formation_manage()
			return

	_clear_options()
	party_buttons.clear()
	roster_buttons.clear()

	var reordering := party_mode in [PartyMode.REORDER_SELECT, PartyMode.REORDER_MOVE]
	var party_header := Label.new()
	var header_text := "PARTY (%d/6)" % GameState.party.size()
	if reordering:
		header_text += " [REORDERING]"
	party_header.text = header_text
	party_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options_list.add_child(party_header)

	for i in range(GameState.party.size()):
		var member: Character = GameState.party.get_member_at(i)
		var btn := _create_party_button(member, i < 3)

		if party_mode == PartyMode.REORDER_MOVE:
			if i == reorder_index:
				btn.add_theme_color_override("font_color", UIColors.WARNING)
				btn.text = "> " + btn.text + " <"

		options_list.add_child(btn)
		party_buttons.append(btn)

	if party_buttons.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(No party members)"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.modulate = UIColors.MODULATE_DISABLED
		options_list.add_child(empty_label)

	if not reordering:
		var divider := HSeparator.new()
		options_list.add_child(divider)

		var available := GameState.roster.get_available(GameState.party)
		_displayed_available_chars = _sort_characters(available)
		var avail_header := Label.new()
		avail_header.text = "AVAILABLE (%d)" % _displayed_available_chars.size()
		avail_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		options_list.add_child(avail_header)

		for character in _displayed_available_chars:
			var btn := _create_party_button(character, false)
			if GameState.party.is_full():
				btn.disabled = true
				btn.modulate = UIColors.MODULATE_DISABLED
			options_list.add_child(btn)
			roster_buttons.append(btn)

		if roster_buttons.is_empty():
			var empty_label := Label.new()
			empty_label.text = "(No available characters)"
			empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_label.modulate = UIColors.MODULATE_DISABLED
			options_list.add_child(empty_label)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		options_list.add_child(spacer)

		var equip_btn := Button.new()
		equip_btn.text = "Equipment & Spells"
		equip_btn.custom_minimum_size = Vector2(350, 36)
		if GameState.party.is_empty():
			equip_btn.disabled = true
			equip_btn.modulate = UIColors.MODULATE_DISABLED
		else:
			equip_btn.pressed.connect(_on_equipment_pressed)
		options_list.add_child(equip_btn)

		var quick_btn := Button.new()
		quick_btn.text = "Quick Pick Party"
		quick_btn.custom_minimum_size = Vector2(350, 36)
		if available.is_empty() and not party_buttons.is_empty():
			quick_btn.disabled = true
			quick_btn.modulate = UIColors.MODULATE_DISABLED
		else:
			quick_btn.pressed.connect(_on_quick_pick)
		options_list.add_child(quick_btn)

		var formations_btn := Button.new()
		formations_btn.text = "Formations"
		formations_btn.custom_minimum_size = Vector2(350, 36)
		if GameState.roster.is_empty():
			formations_btn.disabled = true
			formations_btn.modulate = UIColors.MODULATE_DISABLED
		else:
			formations_btn.pressed.connect(_on_formations_pressed)
		options_list.add_child(formations_btn)

		var all_buttons: Array[Button] = []
		all_buttons.append_array(party_buttons)
		all_buttons.append_array(roster_buttons)
		all_buttons.append(equip_btn)
		all_buttons.append(quick_btn)
		all_buttons.append(formations_btn)

		if not all_buttons.is_empty():
			var focus_idx := clampi(party_focus, 0, all_buttons.size() - 1)
			party_nav = MenuNavigator.new()
			party_nav.setup(all_buttons, focus_idx)
			party_nav.selection_changed.connect(_on_party_selection_changed)
			party_nav.item_confirmed.connect(_on_party_item_confirmed)
			party_focus = 0
	else:
		if not party_buttons.is_empty():
			var ridx := clampi(reorder_index, 0, party_buttons.size() - 1)
			party_nav = MenuNavigator.new()
			party_nav.setup(party_buttons, ridx)
			party_nav.selection_changed.connect(_on_party_selection_changed)

	if party_mode == PartyMode.REORDER_SELECT:
		message_label.text = "Select a character to move, then press Enter."
	elif party_mode == PartyMode.REORDER_MOVE:
		message_label.text = "Move with Up/Down. Enter to place, Esc to cancel."
	elif GameState.party.is_full():
		message_label.text = "Party is full."
	elif GameState.party.is_empty():
		message_label.text = "Add characters to form your party."
	else:
		message_label.text = "Manage your adventuring party."

	_update_party_info()


func _create_party_button(character: Character, front_row: bool) -> Button:
	var btn := Button.new()
	var row_marker := "[F]" if front_row else "[B]"
	btn.text = "%s %s - L%d %s" % [
		row_marker if GameState.party.get_member(character.id) else "",
		character.character_name,
		character.level,
		CharacterEnums.get_class_name(character.character_class)
	]
	btn.text = btn.text.strip_edges()
	btn.custom_minimum_size = Vector2(350, 30)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if character.is_dead:
		btn.modulate = UIColors.MODULATE_DEAD
	elif not character.is_available():
		btn.disabled = true
		btn.modulate = UIColors.MODULATE_DISABLED
		var t_elapsed := character.get_training_days_elapsed(GameState.game_day)
		btn.text += " [Training %d/%d]" % [t_elapsed, character.get_training_total()]
	return btn


func _on_create_character() -> void:
	SceneManager.go_to_character_creation()


func _on_roster_manage_selected(character: Character) -> void:
	selected_character = character
	roster_mode = RosterMode.MANAGE
	_refresh_display()


func _on_manage_action(action_id: String) -> void:
	match action_id:
		"rename":
			roster_mode = RosterMode.RENAME
		"change_class":
			roster_mode = RosterMode.CHANGE_CLASS
		"assign_job":
			roster_mode = RosterMode.ASSIGN_JOB
		"delete":
			roster_mode = RosterMode.CONFIRM_DELETE
	_refresh_display()


func _on_delete_confirmed() -> void:
	if selected_character == null:
		_on_roster_mode_back()
		return

	if GameState.party.has_member(selected_character):
		GameState.party.remove_member(selected_character.id)

	GameState.roster.remove_character(selected_character.id)
	message_label.text = "%s has been deleted." % selected_character.character_name
	selected_character = null
	roster_mode = RosterMode.VIEW
	_refresh_display()


func _on_rename_submitted(new_name: String) -> void:
	if new_name.strip_edges().is_empty():
		return
	_do_rename(new_name.strip_edges())


func _on_rename_confirmed() -> void:
	if rename_edit == null:
		return
	var new_name := rename_edit.text.strip_edges()
	if new_name.is_empty():
		return
	_do_rename(new_name)


func _do_rename(new_name: String) -> void:
	if selected_character == null:
		_on_roster_mode_back()
		return

	var old_name := selected_character.character_name
	selected_character.character_name = new_name
	message_label.text = "%s has been renamed to %s." % [old_name, new_name]
	selected_character = null
	roster_mode = RosterMode.VIEW
	_refresh_display()


func _on_class_change_selected(new_class: CharacterEnums.CharacterClass) -> void:
	if selected_character == null:
		_on_roster_mode_back()
		return

	var old_class := selected_character.character_class
	var training_days := ClassData.get_training_days(old_class, new_class)
	selected_character.start_training(new_class, training_days, GameState.game_day)

	if GameState.party.has_member(selected_character):
		GameState.party.remove_member(selected_character.id)

	var completion_day := GameState.game_day + training_days
	message_label.text = "%s begins training as %s. Available %s (%d days)." % [
		selected_character.character_name,
		CharacterEnums.get_class_name(new_class),
		GameCalendar.format_short(completion_day),
		training_days
	]
	selected_character = null
	roster_mode = RosterMode.VIEW
	_refresh_display()


func _populate_job_assignment() -> void:
	_clear_options()

	if selected_character == null:
		roster_mode = RosterMode.MANAGE
		_populate_manage_actions()
		return

	var header := Label.new()
	header.text = "Assign Job: %s" % selected_character.character_name
	options_list.add_child(header)

	for job in TownJobs.get_all_jobs():
		var job_idx: int = job["id"]
		var assigned := TownJobs.count_assigned(GameState.roster, job_idx)
		var slots: int = job["slots"]
		var btn := Button.new()
		btn.text = "%s (%d/%d filled)" % [job["name"], assigned, slots]
		btn.custom_minimum_size = Vector2(350, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not TownJobs.is_slot_available(GameState.roster, job_idx) and selected_character.town_job != job_idx:
			btn.disabled = true
			btn.modulate = UIColors.MODULATE_DISABLED
		else:
			btn.pressed.connect(_on_job_selected.bind(job_idx))
		if selected_character.town_job == job_idx:
			btn.add_theme_color_override("font_color", UIColors.TEXT_IN_PARTY)
		options_list.add_child(btn)
		buttons.append(btn)

	if selected_character.town_job >= 0:
		var remove_btn := Button.new()
		remove_btn.text = "Remove Job"
		remove_btn.custom_minimum_size = Vector2(350, 36)
		remove_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		remove_btn.add_theme_color_override("font_color", UIColors.TEXT_WARNING)
		remove_btn.pressed.connect(_on_job_removed)
		options_list.add_child(remove_btn)
		buttons.append(remove_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(350, 36)
	cancel_btn.pressed.connect(_on_roster_mode_back)
	options_list.add_child(cancel_btn)
	buttons.append(cancel_btn)

	_setup_nav()
	_update_roster_info()


func _on_job_selected(job_index: int) -> void:
	if selected_character == null:
		_on_roster_mode_back()
		return
	selected_character.town_job = job_index
	message_label.text = "%s assigned to %s." % [
		selected_character.character_name,
		TownJobs.get_job_name(job_index)
	]
	roster_mode = RosterMode.MANAGE
	_refresh_display()


func _on_job_removed() -> void:
	if selected_character == null:
		_on_roster_mode_back()
		return
	var old_job := TownJobs.get_job_name(selected_character.town_job)
	selected_character.town_job = -1
	message_label.text = "%s removed from %s." % [selected_character.character_name, old_job]
	roster_mode = RosterMode.MANAGE
	_refresh_display()


func _show_job_assignment_info() -> void:
	if selected_character == null:
		info_label.text = ""
		return
	var text := "[b]%s[/b] - Job Assignment\n\n" % selected_character.character_name
	text += "Town jobs provide daily income while benched:\n"
	text += "  [color=cyan]+5 XP/day[/color] to the character\n"
	text += "  [color=yellow]+2 Gold/day[/color] to the guild treasury\n\n"
	if selected_character.town_job >= 0:
		text += "Current job: [color=cyan]%s[/color]" % TownJobs.get_job_name(selected_character.town_job)
	else:
		text += "Currently unemployed."
	info_label.text = text


func _on_roster_mode_back() -> void:
	match roster_mode:
		RosterMode.VIEW:
			pass
		RosterMode.MANAGE:
			roster_mode = RosterMode.VIEW
			selected_character = null
		RosterMode.CONFIRM_DELETE, RosterMode.RENAME, RosterMode.CHANGE_CLASS, RosterMode.ASSIGN_JOB:
			roster_mode = RosterMode.MANAGE
	_refresh_display()


func _on_party_member_pressed(character: Character) -> void:
	GameState.party.remove_member(character.id)
	party_focus = GameState.party.size()
	_refresh_display()


func _on_roster_add_pressed(character: Character) -> void:
	if GameState.party.is_full():
		return
	if not character.is_available() or character.is_dead:
		return
	character.town_job = -1
	GameState.party.add_member(character)
	party_focus = GameState.party.size()
	_refresh_display()


func _on_equipment_pressed() -> void:
	SceneManager.go_to_party_menu()


func _on_quick_pick() -> void:
	var available := GameState.roster.get_available(GameState.party)
	var eligible: Array[Character] = []
	for c in available:
		if c.is_available() and not c.is_dead:
			eligible.append(c)
	eligible.shuffle()
	var slots := 6 - GameState.party.size()
	var to_add := mini(slots, eligible.size())
	for i in range(to_add):
		eligible[i].town_job = -1
		GameState.party.add_member(eligible[i])
	message_label.text = "Added %d characters to party." % to_add
	_refresh_display()


func _enter_reorder_mode() -> void:
	if GameState.party.size() < 2:
		return
	_reorder_original_ids.clear()
	for m in GameState.party.get_members():
		_reorder_original_ids.append(m.id)
	party_mode = PartyMode.REORDER_SELECT
	reorder_index = 0
	party_focus = 0
	_refresh_display()


func _confirm_reorder() -> void:
	_reorder_original_ids.clear()
	party_mode = PartyMode.NORMAL
	reorder_index = -1
	message_label.text = "Reorder confirmed."
	_refresh_display()


func _cancel_reorder() -> void:
	var restored: Array[Character] = []
	for char_id in _reorder_original_ids:
		var member := GameState.party.get_member(char_id)
		if member:
			restored.append(member)
	GameState.party.members = restored
	_reorder_original_ids.clear()
	party_mode = PartyMode.NORMAL
	reorder_index = -1
	message_label.text = "Reorder cancelled."
	_refresh_display()


func _save_pre_grab_order() -> void:
	_reorder_pre_grab_ids.clear()
	for m in GameState.party.get_members():
		_reorder_pre_grab_ids.append(m.id)


func _restore_pre_grab_order() -> void:
	var restored: Array[Character] = []
	for char_id in _reorder_pre_grab_ids:
		var member := GameState.party.get_member(char_id)
		if member:
			restored.append(member)
	GameState.party.members = restored
	_reorder_pre_grab_ids.clear()
	party_mode = PartyMode.REORDER_SELECT
	reorder_index = party_nav.get_current_index() if party_nav else 0
	_refresh_display()


func _move_party_member(direction: int) -> void:
	var new_index := reorder_index + direction
	if new_index < 0 or new_index >= GameState.party.size():
		return
	if GameState.party.swap_positions(reorder_index, new_index):
		reorder_index = new_index
		_refresh_display()


func _on_party_item_confirmed(index: int) -> void:
	var character: Character = _get_character_at_party_index(index)
	if character == null:
		return
	if index < party_buttons.size():
		_on_party_member_pressed(character)
	else:
		_on_roster_add_pressed(character)


func _on_party_selection_changed(_index: int) -> void:
	_update_party_info()


func _update_party_info() -> void:
	if party_nav == null:
		info_label.text = "Select a character to view details."
		return

	var idx := party_nav.get_current_index()

	if party_mode in [PartyMode.REORDER_SELECT, PartyMode.REORDER_MOVE]:
		if reorder_index >= 0 and reorder_index < GameState.party.size():
			var reorder_char: Character = GameState.party.get_member_at(reorder_index)
			var row := "Front Row" if reorder_index < 3 else "Back Row"
			var text := ""
			if party_mode == PartyMode.REORDER_SELECT:
				text += "[b]SELECT: %s[/b]\n\n" % reorder_char.character_name
				text += "Position: %d (%s)\n\n" % [reorder_index + 1, row]
				text += "[color=yellow]Enter: Grab character to move.[/color]\n"
				text += "[color=yellow]R: Confirm and exit reorder.[/color]\n"
				text += "[color=yellow]Esc: Cancel all changes.[/color]"
			else:
				text += "[b]MOVING: %s[/b]\n\n" % reorder_char.character_name
				text += "Current Position: %d (%s)\n\n" % [reorder_index + 1, row]
				text += "[color=cyan]Formation Info:[/color]\n"
				text += "  Positions 1-3: Front Row (melee range)\n"
				text += "  Positions 4-6: Back Row (ranged/protected)\n\n"
				text += "[color=yellow]Up/Down: Move. Enter: Place.[/color]\n"
				text += "[color=yellow]Esc: Undo this move.[/color]"
			info_label.text = text
		return

	var character: Character = _get_character_at_party_index(idx)
	if character:
		_show_character_info(character)
	else:
		var all_count: int = party_buttons.size() + roster_buttons.size()
		if idx == all_count:
			info_label.text = "[b]Equipment & Spells[/b]\n\nOpen the party management screen\nto manage equipment, spells, and inventory."
		elif idx == all_count + 1:
			info_label.text = "[b]Quick Pick Party[/b]\n\nRandomly fill empty party slots\nfrom available roster members."
		elif idx == all_count + 2:
			var text := "[b]Formations[/b]\n\nSave and load named party compositions.\n\n"
			text += "Saved: %d/%d" % [GameState.party_formations.size(), MAX_FORMATIONS]
			info_label.text = text
		else:
			info_label.text = "Select a character to view details."


func _get_character_at_party_index(idx: int) -> Character:
	if idx < party_buttons.size():
		if idx >= 0 and idx < GameState.party.size():
			return GameState.party.get_member_at(idx)
	else:
		var roster_idx := idx - party_buttons.size()
		if roster_idx >= 0 and roster_idx < _displayed_available_chars.size():
			return _displayed_available_chars[roster_idx]
	return null


func _update_roster_info() -> void:
	if nav == null and roster_mode == RosterMode.VIEW:
		info_label.text = "Select a character to manage."
		return

	match roster_mode:
		RosterMode.VIEW:
			var idx := nav.get_current_index() if nav else -1
			var characters: Array[Character] = _displayed_roster_chars
			if idx >= 0 and idx < characters.size():
				_show_character_info(characters[idx])
			else:
				info_label.text = "Select a character to manage."
		RosterMode.MANAGE:
			if selected_character:
				_show_character_info(selected_character)
		RosterMode.CONFIRM_DELETE:
			_show_delete_info()
		RosterMode.RENAME:
			_show_rename_info()
		RosterMode.CHANGE_CLASS:
			_show_class_change_info()
		RosterMode.ASSIGN_JOB:
			_show_job_assignment_info()


func _show_character_info(character: Character) -> void:
	var text := "[b]%s[/b]  L%d %s %s  %s  Age %d (%s)\n" % [
		character.character_name,
		character.level,
		CharacterEnums.get_race_name(character.race),
		CharacterEnums.get_class_name(character.character_class),
		CharacterEnums.get_alignment_name(character.alignment),
		character.get_age_years(),
		character.get_life_phase_name()
	]

	text += "HP: %d/%d  MP: %d/%d  XP: %d" % [
		character.current_hp, character.max_hp,
		character.current_mp, character.max_mp,
		character.experience
	]
	if character.pending_level_up:
		text += " [color=yellow](Level up!)[/color]"
	text += "\n"

	text += "STR: %d  INT: %d  PIE: %d  VIT: %d  AGI: %d  LCK: %d\n" % [
		character.strength, character.intelligence, character.piety,
		character.vitality, character.agility, character.luck
	]

	text += _format_personality(character)

	var equip_text := _format_equipment(character)
	if equip_text != "":
		text += equip_text

	if character.max_spell_level > 0:
		text += "\n[color=cyan]Spells:[/color] "
		text += _format_spell_book(character)

	var all_marks := character.get_marks()
	if not all_marks.is_empty():
		var major := character.get_major_marks()
		var minor_count := all_marks.size() - major.size()
		text += "\n[color=yellow]Marks:[/color]"
		for mark in major:
			text += "\n  [color=orange]%s[/color]" % mark.get("name")
		if minor_count > 0:
			text += "\n  [color=gray](%d minor marks)[/color]" % minor_count

	if character.is_dead:
		if character.has_status(CharacterEnums.StatusEffect.LOST):
			text += "\n[color=red]LOST FOREVER[/color]"
		elif character.has_status(CharacterEnums.StatusEffect.ASHED):
			text += "\n[color=orange]ASHED[/color]"
		else:
			text += "\n[color=red]DEAD[/color]"
	elif character.is_training():
		var t_elapsed := character.get_training_days_elapsed(GameState.game_day)
		var t_total := character.get_training_total()
		var t_remain := t_total - t_elapsed
		text += "\n[color=orange]Training as %s - Day %d/%d (%d remaining)[/color]" % [
			CharacterEnums.get_class_name(character.training_target_class),
			t_elapsed, t_total, t_remain]
	elif GameState.party.has_member(character):
		text += "\n[color=cyan]In party[/color]"

	if not character.is_dead and character.town_job >= 0:
		text += "\n[color=cyan]Job: %s[/color]" % TownJobs.get_job_name(character.town_job)

	if not character.is_dead and not character.is_training():
		var preview_bonus := minf(Character.REST_BONUS_MAX, 1.0 + character.town_days_accumulated * Character.REST_BONUS_PER_TOWN_DAY)
		if character.rest_bonus_xp_multiplier > 1.0:
			text += "\n[color=green]Rested: +%.0f%% XP in dungeon[/color]" % ((character.rest_bonus_xp_multiplier - 1.0) * 100)
		elif preview_bonus > 1.0:
			text += "\n[color=green]Rested: +%.0f%% XP on next dive[/color]" % ((preview_bonus - 1.0) * 100)

	info_label.text = text


func _format_personality(character: Character) -> String:
	if character.tendencies.is_empty():
		return ""
	var parts: Array[String] = []
	for axis: int in Personality.Axis.values():
		var option: int = character.get_active_trait(axis as Personality.Axis)
		if option < 0:
			continue
		var trait_name: String = Personality.get_option_name(axis as Personality.Axis, option)
		if character.is_trait_crystallized(axis as Personality.Axis):
			parts.append("[b]%s[/b]" % trait_name)
		else:
			parts.append("[color=gray]%s[/color]" % trait_name)
	if parts.is_empty():
		return ""
	return "Personality: %s\n" % ", ".join(parts)


func _format_equipment(character: Character) -> String:
	var slots: Array[Dictionary] = [
		{"type": Item.ItemType.WEAPON, "name": "Wpn"},
		{"type": Item.ItemType.ARMOR, "name": "Arm"},
		{"type": Item.ItemType.SHIELD, "name": "Shd"},
		{"type": Item.ItemType.HELMET, "name": "Hlm"},
		{"type": Item.ItemType.GLOVES, "name": "Glv"},
		{"type": Item.ItemType.BOOTS, "name": "Bts"},
		{"type": Item.ItemType.ACCESSORY, "name": "Acc"}
	]

	var parts: Array[String] = []
	for slot_info in slots:
		var item: Item = character.get_equipped_item(slot_info["type"])
		if item:
			var item_name := item.get_display_name()
			if item.is_cursed and item.is_identified:
				parts.append("[color=red]%s[/color]" % item_name)
			else:
				parts.append(item_name)

	if parts.is_empty():
		return ""
	return "[color=cyan]Gear:[/color] %s\n" % ", ".join(parts)


func _format_spell_book(character: Character) -> String:
	if character.known_spells.is_empty():
		return "  [color=gray](No spells known)[/color]\n"

	var spells_by_level: Dictionary = {}
	for spell_id in character.known_spells:
		var spell: Spell = SpellDatabase.get_spell(spell_id)
		if spell == null:
			continue
		if not spells_by_level.has(spell.level):
			spells_by_level[spell.level] = []
		spells_by_level[spell.level].append(spell.name)

	var text := ""
	var levels: Array = spells_by_level.keys()
	levels.sort()

	for level in levels:
		var spell_names: Array = spells_by_level[level]
		var can_cast: bool = level <= character.max_spell_level
		var color := "white" if can_cast else "gray"
		text += "  [color=%s]L%d: %s[/color]\n" % [color, level, ", ".join(spell_names)]

	if character.max_spell_level > 0:
		text += "  [color=yellow]Can cast up to Level %d[/color]\n" % character.max_spell_level

	return text


func _show_delete_info() -> void:
	if selected_character == null:
		return

	var text := "[b]Delete %s?[/b]\n\n" % selected_character.character_name
	text += "Level %d %s %s\n\n" % [
		selected_character.level,
		CharacterEnums.get_race_name(selected_character.race),
		CharacterEnums.get_class_name(selected_character.character_class)
	]
	text += "[color=red]WARNING: This action cannot be undone![/color]\n\n"
	text += "The character will be permanently removed\nfrom the roster."

	if GameState.party.has_member(selected_character):
		text += "\n\n[color=orange]This character is currently in your party\nand will be removed from it.[/color]"

	info_label.text = text


func _show_rename_info() -> void:
	if selected_character == null:
		return

	var text := "[b]Rename %s[/b]\n\n" % selected_character.character_name
	text += "Level %d %s %s\n\n" % [
		selected_character.level,
		CharacterEnums.get_race_name(selected_character.race),
		CharacterEnums.get_class_name(selected_character.character_class)
	]
	text += "Enter a new name in the text field.\n"
	text += "Maximum 20 characters."

	info_label.text = text


func _show_class_change_info() -> void:
	if selected_character == null or nav == null:
		return

	var idx := nav.get_current_index()
	var class_count := CharacterEnums.CharacterClass.values().size()
	if idx < 0 or idx >= class_count:
		info_label.text = "Press Enter to cancel."
		return

	var char_class: CharacterEnums.CharacterClass = idx as CharacterEnums.CharacterClass
	var data: Dictionary = ClassData.get_class_data(char_class)
	var reqs: Dictionary = ClassData.get_requirements(char_class)

	var text := "[b]%s[/b]\n\n" % CharacterEnums.get_class_name(char_class)
	text += "HP Base: %d  MP Base: %d\n\n" % [data.get("hp_base", 0), data.get("mp_base", 0)]

	if not reqs.is_empty():
		text += "[color=cyan]Requirements:[/color]\n"
		for stat: String in reqs:
			var current_val: int = selected_character.get(stat)
			var req_val: int = reqs[stat]
			var color := "green" if current_val >= req_val else "red"
			text += "  %s: %d (have %d) [color=%s]%s[/color]\n" % [
				stat.capitalize(),
				req_val,
				current_val,
				color,
				"OK" if current_val >= req_val else "FAIL"
			]
		text += "\n"

	if char_class == selected_character.character_class:
		text += "[color=gray]This is the current class.[/color]"
	else:
		var train_days := ClassData.get_training_days(selected_character.character_class, char_class)
		var completion_day := GameState.game_day + train_days
		text += "[color=orange]Changing class will reset level to 1![/color]\n"
		text += "Training time: %d days (available %s)\n" % [train_days, GameCalendar.format_short(completion_day)]
		text += "Stats and known spells will be preserved."

	info_label.text = text


func _update_roster_overview() -> void:
	for child in roster_list.get_children():
		child.queue_free()

	var characters: Array[Character] = GameState.roster.get_all()
	if characters.is_empty():
		var label := Label.new()
		label.text = "(No characters in roster)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		roster_list.add_child(label)
		return

	for c in characters:
		var row := _create_roster_row(c)
		roster_list.add_child(row)


func _create_roster_row(c: Character) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)

	var name_label := Label.new()
	name_label.text = c.character_name
	name_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(name_label)

	var class_label := Label.new()
	class_label.text = "L%d %s" % [c.level, CharacterEnums.get_class_name(c.character_class)]
	class_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(class_label)

	var status_label := Label.new()
	if c.has_status(CharacterEnums.StatusEffect.LOST):
		status_label.text = "[LOST]"
		status_label.add_theme_color_override("font_color", UIColors.TEXT_LOST)
	elif c.is_dead:
		status_label.text = "[DEAD]"
		status_label.add_theme_color_override("font_color", UIColors.DANGER)
	elif c.is_training():
		var t_elapsed := c.get_training_days_elapsed(GameState.game_day)
		status_label.text = "[Training %d/%d]" % [t_elapsed, c.get_training_total()]
		status_label.add_theme_color_override("font_color", UIColors.TEXT_WARNING)
	elif GameState.party.has_member(c):
		status_label.text = "[PARTY]"
		status_label.add_theme_color_override("font_color", UIColors.TEXT_IN_PARTY)
	else:
		status_label.text = ""
	row.add_child(status_label)

	return row


func _sort_characters(chars: Array[Character]) -> Array[Character]:
	if roster_sort_mode == SortMode.DEFAULT:
		return chars
	var sorted := chars.duplicate()
	match roster_sort_mode:
		SortMode.NAME:
			sorted.sort_custom(func(a: Character, b: Character) -> bool:
				return a.character_name.to_lower() < b.character_name.to_lower())
		SortMode.LEVEL:
			sorted.sort_custom(func(a: Character, b: Character) -> bool:
				return a.level > b.level)
		SortMode.CLASS:
			sorted.sort_custom(func(a: Character, b: Character) -> bool:
				return a.character_class < b.character_class)
		SortMode.RACE:
			sorted.sort_custom(func(a: Character, b: Character) -> bool:
				return a.race < b.race)
	return sorted


func _cycle_sort() -> void:
	roster_sort_mode = ((roster_sort_mode + 1) % SortMode.size()) as SortMode
	_refresh_display()


func _get_sort_mode_name() -> String:
	match roster_sort_mode:
		SortMode.DEFAULT: return "Default"
		SortMode.NAME: return "Name"
		SortMode.LEVEL: return "Level"
		SortMode.CLASS: return "Class"
		SortMode.RACE: return "Race"
	return "Default"


func _on_formations_pressed() -> void:
	party_mode = PartyMode.FORMATION_LIST
	_refresh_display()


func _populate_formation_list() -> void:
	_clear_options()
	_selected_formation = null

	var save_btn := Button.new()
	save_btn.text = "Save Current Party"
	save_btn.custom_minimum_size = Vector2(350, 36)
	if GameState.party.is_empty() or GameState.party_formations.size() >= MAX_FORMATIONS:
		save_btn.disabled = true
		save_btn.modulate = UIColors.MODULATE_DISABLED
	else:
		save_btn.pressed.connect(_on_formation_save_pressed)
	options_list.add_child(save_btn)
	buttons.append(save_btn)

	for formation in GameState.party_formations:
		var btn := Button.new()
		btn.text = "%s (%d)" % [formation.formation_name, formation.member_ids.size()]
		btn.custom_minimum_size = Vector2(350, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_formation_selected.bind(formation))
		options_list.add_child(btn)
		buttons.append(btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(350, 36)
	back_btn.pressed.connect(_on_formation_back)
	options_list.add_child(back_btn)
	buttons.append(back_btn)

	if GameState.party_formations.size() >= MAX_FORMATIONS:
		message_label.text = "Formation slots full (%d/%d)." % [GameState.party_formations.size(), MAX_FORMATIONS]
	else:
		message_label.text = "Saved formations: %d/%d" % [GameState.party_formations.size(), MAX_FORMATIONS]

	_setup_nav()
	if nav:
		nav.selection_changed.connect(_on_formation_list_selection_changed)
	_update_formation_list_info()


func _on_formation_list_selection_changed(_index: int) -> void:
	_update_formation_list_info()


func _update_formation_list_info() -> void:
	if nav == null:
		info_label.text = "Select a formation to manage."
		return

	var idx := nav.get_current_index()
	if idx == 0:
		var text := "[b]Save Current Party[/b]\n\n"
		if GameState.party.is_empty():
			text += "[color=gray]No party members to save.[/color]"
		elif GameState.party_formations.size() >= MAX_FORMATIONS:
			text += "[color=red]Formation slots full (%d/%d).[/color]" % [GameState.party_formations.size(), MAX_FORMATIONS]
		else:
			text += "Save your current party composition\nas a named formation.\n\n"
			text += "[color=cyan]Current party:[/color]\n"
			for i in range(GameState.party.size()):
				var member := GameState.party.get_member_at(i)
				var row_tag := "[F]" if i < 3 else "[B]"
				text += "  %s %s - L%d %s\n" % [row_tag, member.character_name, member.level, CharacterEnums.get_class_name(member.character_class)]
		info_label.text = text
		return

	var formation_idx := idx - 1
	if formation_idx >= 0 and formation_idx < GameState.party_formations.size():
		var formation := GameState.party_formations[formation_idx]
		_show_formation_info(formation)
	else:
		info_label.text = "Return to party management."


func _show_formation_info(formation: PartyFormation) -> void:
	var text := "[b]%s[/b]\n" % formation.formation_name
	text += "Members: %d\n\n" % formation.member_ids.size()
	text += "[color=cyan]Composition:[/color]\n"
	for i in range(formation.member_ids.size()):
		var char_id := formation.member_ids[i]
		var char_name := formation.member_names[i] if i < formation.member_names.size() else "???"
		var character := GameState.roster.get_character(char_id)
		var row_tag := "[F]" if i < 3 else "[B]"
		if character:
			text += "  %s %s - L%d %s\n" % [row_tag, character.character_name, character.level, CharacterEnums.get_class_name(character.character_class)]
		else:
			text += "  %s [color=red]%s (not in roster)[/color]\n" % [row_tag, char_name]
	info_label.text = text


func _on_formation_save_pressed() -> void:
	party_mode = PartyMode.FORMATION_SAVE
	_refresh_display()


func _populate_formation_save() -> void:
	_clear_options()

	var label := Label.new()
	label.text = "Name this formation:"
	options_list.add_child(label)

	formation_name_edit = LineEdit.new()
	formation_name_edit.placeholder_text = "Formation name"
	formation_name_edit.custom_minimum_size = Vector2(350, 36)
	formation_name_edit.max_length = 30
	formation_name_edit.text_submitted.connect(_on_formation_name_submitted)
	options_list.add_child(formation_name_edit)
	formation_name_edit.grab_focus()

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(350, 36)
	confirm_btn.pressed.connect(_on_formation_save_confirmed)
	options_list.add_child(confirm_btn)
	buttons.append(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(350, 36)
	cancel_btn.pressed.connect(_on_formation_save_cancelled)
	options_list.add_child(cancel_btn)
	buttons.append(cancel_btn)

	message_label.text = "Enter a name for this formation."

	var text := "[b]Save Formation[/b]\n\n"
	text += "[color=cyan]Current party:[/color]\n"
	for i in range(GameState.party.size()):
		var member := GameState.party.get_member_at(i)
		var row_tag := "[F]" if i < 3 else "[B]"
		text += "  %s %s - L%d %s\n" % [row_tag, member.character_name, member.level, CharacterEnums.get_class_name(member.character_class)]
	info_label.text = text


func _on_formation_name_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	_do_formation_save(text.strip_edges())


func _on_formation_save_confirmed() -> void:
	if formation_name_edit == null:
		return
	var fname := formation_name_edit.text.strip_edges()
	if fname.is_empty():
		return
	_do_formation_save(fname)


func _do_formation_save(fname: String) -> void:
	var formation := PartyFormation.new()
	formation.formation_name = fname
	for i in range(GameState.party.size()):
		var member := GameState.party.get_member_at(i)
		formation.member_ids.append(member.id)
		formation.member_names.append(member.character_name)
	GameState.party_formations.append(formation)
	message_label.text = "Formation '%s' saved." % fname
	party_mode = PartyMode.FORMATION_LIST
	_refresh_display()


func _on_formation_save_cancelled() -> void:
	party_mode = PartyMode.FORMATION_LIST
	_refresh_display()


func _on_formation_selected(formation: PartyFormation) -> void:
	_selected_formation = formation
	party_mode = PartyMode.FORMATION_MANAGE
	_refresh_display()


func _populate_formation_manage() -> void:
	_clear_options()

	if _selected_formation == null:
		party_mode = PartyMode.FORMATION_LIST
		_populate_formation_list()
		return

	var header := Label.new()
	header.text = "Formation: %s" % _selected_formation.formation_name
	options_list.add_child(header)

	var load_btn := Button.new()
	load_btn.text = "Load Formation"
	load_btn.custom_minimum_size = Vector2(350, 36)
	load_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	load_btn.pressed.connect(_on_formation_load)
	options_list.add_child(load_btn)
	buttons.append(load_btn)

	var delete_btn := Button.new()
	delete_btn.text = "Delete Formation"
	delete_btn.custom_minimum_size = Vector2(350, 36)
	delete_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	delete_btn.add_theme_color_override("font_color", UIColors.TEXT_DANGER)
	delete_btn.pressed.connect(_on_formation_delete)
	options_list.add_child(delete_btn)
	buttons.append(delete_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(350, 36)
	back_btn.pressed.connect(_on_formation_manage_back)
	options_list.add_child(back_btn)
	buttons.append(back_btn)

	message_label.text = "Manage formation: %s" % _selected_formation.formation_name
	_setup_nav()
	if nav:
		nav.selection_changed.connect(_on_formation_manage_selection_changed)
	_show_formation_info(_selected_formation)


func _on_formation_manage_selection_changed(_index: int) -> void:
	if _selected_formation == null:
		return
	if nav == null:
		return
	var idx := nav.get_current_index()
	match idx:
		0:
			var text := "[b]Load Formation[/b]\n\n"
			text += "Replace your current party with\nthe members from '%s'.\n\n" % _selected_formation.formation_name
			var missing := 0
			for i in range(_selected_formation.member_ids.size()):
				var char_id := _selected_formation.member_ids[i]
				if GameState.roster.get_character(char_id) == null:
					missing += 1
			if missing > 0:
				text += "[color=orange]Warning: %d member(s) no longer in roster.[/color]" % missing
			info_label.text = text
		1:
			var text := "[b]Delete Formation[/b]\n\n"
			text += "[color=red]Remove '%s' from saved formations.[/color]\n" % _selected_formation.formation_name
			text += "This cannot be undone."
			info_label.text = text
		_:
			_show_formation_info(_selected_formation)


func _on_formation_load() -> void:
	if _selected_formation == null:
		return

	var members_to_remove: Array[String] = []
	for member in GameState.party.get_members():
		members_to_remove.append(member.id)
	for char_id in members_to_remove:
		GameState.party.remove_member(char_id)

	var loaded := 0
	var missing := 0
	var missing_names: Array[String] = []
	for i in range(_selected_formation.member_ids.size()):
		var char_id := _selected_formation.member_ids[i]
		var character := GameState.roster.get_character(char_id)
		if character and character.is_available() and not character.is_dead:
			character.town_job = -1
			GameState.party.add_member(character)
			loaded += 1
		else:
			missing += 1
			var char_name := _selected_formation.member_names[i] if i < _selected_formation.member_names.size() else "???"
			missing_names.append(char_name)

	var total := _selected_formation.member_ids.size()
	if missing > 0:
		message_label.text = "Loaded %s (%d/%d - %d not in roster)" % [_selected_formation.formation_name, loaded, total, missing]
	else:
		message_label.text = "Loaded %s" % _selected_formation.formation_name

	_selected_formation = null
	party_mode = PartyMode.NORMAL
	_refresh_display()


func _on_formation_delete() -> void:
	if _selected_formation == null:
		return
	var fname := _selected_formation.formation_name
	GameState.party_formations.erase(_selected_formation)
	_selected_formation = null
	message_label.text = "Formation '%s' deleted." % fname
	party_mode = PartyMode.FORMATION_LIST
	_refresh_display()


func _on_formation_back() -> void:
	_selected_formation = null
	party_mode = PartyMode.NORMAL
	_refresh_display()


func _on_formation_manage_back() -> void:
	_selected_formation = null
	party_mode = PartyMode.FORMATION_LIST
	_refresh_display()


func _clear_options() -> void:
	for child in options_list.get_children():
		child.queue_free()
	buttons.clear()
	nav = null
	party_nav = null
	roster_nav = null
	party_buttons.clear()
	roster_buttons.clear()
	rename_edit = null
	formation_name_edit = null


func _setup_nav() -> void:
	if buttons.is_empty():
		return
	nav = MenuNavigator.new()
	nav.setup(buttons, 0)
	nav.selection_changed.connect(_on_nav_selection_changed)
	if current_tab == Tab.ROSTER and roster_mode == RosterMode.VIEW:
		nav.item_confirmed.connect(_on_roster_item_confirmed)


func _on_roster_item_confirmed(index: int) -> void:
	if index >= 0 and index < _displayed_roster_chars.size():
		_on_roster_manage_selected(_displayed_roster_chars[index])


func _on_nav_selection_changed(_index: int) -> void:
	_update_roster_info()


func _update_help() -> void:
	var v_nav := KeyBindingHelper.get_nav_help()
	var h_nav := KeyBindingHelper.get_horizontal_help()
	var confirm := KeyBindingHelper.get_confirm_help()
	var cancel := KeyBindingHelper.get_cancel_help()
	var sort_hint := KeyBindingHelper.get_sort_help(_get_sort_mode_name())

	match current_tab:
		Tab.CREATE:
			help_label.text = "%s | %s | %s" % [h_nav, confirm, cancel]
		Tab.ROSTER:
			match roster_mode:
				RosterMode.RENAME:
					help_label.text = "Type name | Enter: Confirm | %s" % cancel
				RosterMode.CHANGE_CLASS:
					help_label.text = "%s | %s | %s | Level resets to 1!" % [v_nav, confirm, cancel]
				RosterMode.CONFIRM_DELETE:
					help_label.text = "%s | %s | Permanent!" % [v_nav, confirm]
				RosterMode.VIEW:
					help_label.text = "%s | %s | %s | %s | %s" % [h_nav, v_nav, confirm, cancel, sort_hint]
				_:
					help_label.text = "%s | %s | %s | %s" % [h_nav, v_nav, confirm, cancel]
		Tab.PARTY:
			if party_mode == PartyMode.REORDER_SELECT:
				var reorder := KeyBindingHelper.get_reorder_help().split(":")[0]
				help_label.text = "%s | %s: Grab | %s: Done | %s" % [v_nav, confirm.split(":")[0], reorder, cancel]
			elif party_mode == PartyMode.REORDER_MOVE:
				help_label.text = "%s: Move | %s: Place | %s: Undo" % [v_nav.split(":")[0], confirm.split(":")[0], cancel.split(":")[0]]
			elif party_mode == PartyMode.FORMATION_SAVE:
				help_label.text = "Type name | Enter: Confirm | %s" % cancel
			elif party_mode in [PartyMode.FORMATION_LIST, PartyMode.FORMATION_MANAGE]:
				help_label.text = "%s | %s | %s" % [v_nav, confirm, cancel]
			elif GameState.party.size() > 1:
				var reorder := KeyBindingHelper.get_reorder_help()
				help_label.text = "%s | %s | %s | %s | %s" % [h_nav, v_nav, confirm, reorder, sort_hint]
			else:
				help_label.text = "%s | %s | %s | %s | %s" % [h_nav, v_nav, confirm, cancel, sort_hint]


func _unhandled_input(event: InputEvent) -> void:
	if current_tab == Tab.ROSTER and roster_mode == RosterMode.RENAME:
		if event.is_action_pressed("menu_cancel"):
			_on_roster_mode_back()
		return

	if current_tab == Tab.PARTY and party_mode == PartyMode.FORMATION_SAVE:
		if event.is_action_pressed("menu_cancel"):
			_on_formation_save_cancelled()
		return

	if current_tab == Tab.PARTY and party_mode in [PartyMode.REORDER_SELECT, PartyMode.REORDER_MOVE]:
		_handle_reorder_input(event)
		return

	if current_tab == Tab.PARTY and party_mode in [PartyMode.FORMATION_LIST, PartyMode.FORMATION_MANAGE]:
		if event.is_action_pressed("menu_cancel"):
			if party_mode == PartyMode.FORMATION_MANAGE:
				_on_formation_manage_back()
			else:
				_on_formation_back()
			return
		if nav:
			nav.handle_input(event)
		return

	if event.is_action_pressed("menu_sort"):
		if current_tab == Tab.ROSTER and roster_mode == RosterMode.VIEW:
			_cycle_sort()
			return
		if current_tab == Tab.PARTY and party_mode == PartyMode.NORMAL:
			_cycle_sort()
			return

	if event.is_action_pressed("menu_left"):
		tab_bar.current_tab = (tab_bar.current_tab - 1 + 3) % 3
		return
	if event.is_action_pressed("menu_right"):
		tab_bar.current_tab = (tab_bar.current_tab + 1) % 3
		return

	if event.is_action_pressed("menu_cancel"):
		match current_tab:
			Tab.ROSTER:
				if roster_mode == RosterMode.VIEW:
					_on_back_pressed()
				else:
					_on_roster_mode_back()
			Tab.PARTY:
				_on_back_pressed()
			_:
				_on_back_pressed()
		return

	if current_tab == Tab.PARTY:
		_handle_party_input(event)
	elif current_tab == Tab.ROSTER or current_tab == Tab.CREATE:
		if nav:
			nav.handle_input(event)


func _handle_party_input(event: InputEvent) -> void:
	if GameState.party.size() > 1:
		if event.is_action_pressed("menu_reorder"):
			_enter_reorder_mode()
			return

	if party_nav and party_nav.items.size() > 0:
		party_nav.handle_input(event)


func _handle_reorder_input(event: InputEvent) -> void:
	if party_mode == PartyMode.REORDER_SELECT:
		if event.is_action_pressed("menu_cancel"):
			_cancel_reorder()
		elif event.is_action_pressed("menu_reorder"):
			_confirm_reorder()
		elif event.is_action_pressed("menu_up") or event.is_action_pressed("menu_down"):
			if party_nav:
				party_nav.handle_input(event)
				reorder_index = party_nav.get_current_index()
				_update_party_info()
		elif event.is_action_pressed("menu_confirm"):
			_save_pre_grab_order()
			party_mode = PartyMode.REORDER_MOVE
			_refresh_display()
	elif party_mode == PartyMode.REORDER_MOVE:
		if event.is_action_pressed("menu_cancel"):
			_restore_pre_grab_order()
		elif event.is_action_pressed("menu_up"):
			_move_party_member(-1)
		elif event.is_action_pressed("menu_down"):
			_move_party_member(1)
		elif event.is_action_pressed("menu_confirm"):
			_reorder_pre_grab_ids.clear()
			party_mode = PartyMode.REORDER_SELECT
			_refresh_display()


func _on_back_pressed() -> void:
	SceneManager.go_to_town()
