class_name GuildHallRosterTab
extends RefCounted

enum RosterMode { VIEW, MANAGE, CONFIRM_DELETE, RENAME, CHANGE_CLASS, ASSIGN_JOB }
enum SortMode { DEFAULT, NAME, LEVEL, CLASS, RACE }

signal message_changed(text: String)
signal display_refresh_requested()

var roster_mode: RosterMode = RosterMode.VIEW
var selected_character: Character = null
var roster_sort_mode: SortMode = SortMode.DEFAULT
var _displayed_roster_chars: Array[Character] = []

var nav: MenuNavigator = null
var buttons: Array[Button] = []
var rename_edit: LineEdit = null

var options_list: VBoxContainer
var detail: CharacterDetailView


func init(p_options_list: VBoxContainer, p_detail: CharacterDetailView) -> void:
	options_list = p_options_list
	detail = p_detail


func reset() -> void:
	roster_mode = RosterMode.VIEW
	selected_character = null
	roster_sort_mode = SortMode.DEFAULT


func populate() -> void:
	match roster_mode:
		RosterMode.VIEW:
			_populate_roster_view()
			message_changed.emit("Select a character to manage.")
		RosterMode.MANAGE:
			_populate_manage_actions()
		RosterMode.CONFIRM_DELETE:
			_populate_delete_confirm()
			message_changed.emit("Are you sure you want to delete this character?")
		RosterMode.RENAME:
			_populate_rename_screen()
			message_changed.emit("Enter a new name for the character.")
		RosterMode.CHANGE_CLASS:
			_populate_class_change()
			message_changed.emit("Select a new class. Training required.")
		RosterMode.ASSIGN_JOB:
			_populate_job_assignment()
			message_changed.emit("Select a job for %s." % selected_character.character_name)

	_update_roster_info()


func handle_input(event: InputEvent) -> void:
	if roster_mode == RosterMode.RENAME:
		if event.is_action_pressed("menu_cancel"):
			_on_roster_mode_back()
		return

	if event.is_action_pressed("menu_sort") and roster_mode == RosterMode.VIEW:
		_cycle_sort()
		return

	if event.is_action_pressed("menu_cancel"):
		if roster_mode == RosterMode.VIEW:
			return
		_on_roster_mode_back()
		return

	if nav:
		nav.handle_input(event)


func handle_back() -> bool:
	if roster_mode != RosterMode.VIEW:
		_on_roster_mode_back()
		return true
	return false


func get_sort_mode_name() -> String:
	match roster_sort_mode:
		SortMode.DEFAULT: return "Default"
		SortMode.NAME: return "Name"
		SortMode.LEVEL: return "Level"
		SortMode.CLASS: return "Class"
		SortMode.RACE: return "Race"
	return "Default"


func get_help_text() -> String:
	var v_nav := KeyBindingHelper.get_nav_help()
	var h_nav := KeyBindingHelper.get_horizontal_help()
	var confirm := KeyBindingHelper.get_confirm_help()
	var cancel := KeyBindingHelper.get_cancel_help()
	var sort_hint := KeyBindingHelper.get_sort_help(get_sort_mode_name())

	match roster_mode:
		RosterMode.RENAME:
			return "Type name | Enter: Confirm | %s" % cancel
		RosterMode.CHANGE_CLASS:
			return "%s | %s | %s | Level resets to 1!" % [v_nav, confirm, cancel]
		RosterMode.CONFIRM_DELETE:
			return "%s | %s | Permanent!" % [v_nav, confirm]
		RosterMode.VIEW:
			return "%s | %s | %s | %s | %s" % [h_nav, v_nav, confirm, cancel, sort_hint]
		_:
			return "%s | %s | %s | %s" % [h_nav, v_nav, confirm, cancel]


func _clear_options() -> void:
	for child in options_list.get_children():
		child.queue_free()
	buttons.clear()
	nav = null
	rename_edit = null


func _setup_nav() -> void:
	if buttons.is_empty():
		return
	nav = MenuNavigator.new()
	nav.setup(buttons, 0)
	nav.selection_changed.connect(_on_nav_selection_changed)
	if roster_mode == RosterMode.VIEW:
		nav.item_confirmed.connect(_on_roster_item_confirmed)


func _on_nav_selection_changed(_index: int) -> void:
	_update_roster_info()


func _on_roster_item_confirmed(index: int) -> void:
	if index >= 0 and index < _displayed_roster_chars.size():
		_on_roster_manage_selected(_displayed_roster_chars[index])


func _populate_roster_view() -> void:
	_clear_options()

	_displayed_roster_chars = _sort_characters(GameState.roster.get_all())
	for character in _displayed_roster_chars:
		var btn := _char_row(character)
		options_list.add_child(btn)
		buttons.append(btn)

	if buttons.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(No characters in roster)"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.theme_type_variation = &"MutedLabel"
		options_list.add_child(empty_label)

	_setup_nav()


func _char_row(character: Character) -> MenuListRow:
	var chips: Array = []
	var status := _status_chip(character)
	if not status.is_empty():
		chips.append(status)
	return MenuListRow.create({
		"badge": CharacterEnums.get_class_name(character.character_class).substr(0, 1).to_upper(),
		"badge_color": UIColors.class_color(character.character_class),
		"title": character.character_name,
		"title_color": UIColors.TEXT_DANGER if character.is_dead else UIColors.TEXT_PRIMARY,
		"subtitle": "L%d %s %s" % [character.level, CharacterEnums.get_race_name(character.race), CharacterEnums.get_class_name(character.character_class)],
		"chips": chips,
		"dim": character.is_dead,
	})


func _status_chip(c: Character) -> Dictionary:
	if c.has_status(CharacterEnums.StatusEffect.LOST):
		return {"text": "LOST", "fg": UIColors.TEXT_LOST, "bg": Color(0.20, 0.08, 0.08)}
	if c.is_dead:
		return {"text": "DEAD", "fg": UIColors.TEXT_DANGER, "bg": Color(0.28, 0.10, 0.12)}
	if c.is_training():
		var e := c.get_training_days_elapsed(GameState.game_day)
		return {"text": "TRAINING %d/%d" % [e, c.get_training_total()], "fg": UIColors.TEXT_WARNING, "bg": UIColors.SURFACE_SELECTED}
	if GameState.party.has_member(c):
		return {"text": "IN PARTY", "fg": UIColors.TEXT_IN_PARTY, "bg": UIColors.SURFACE_SELECTED}
	if c.town_job >= 0:
		return {"text": TownJobs.get_job_name(c.town_job).to_upper(), "fg": UIColors.INFO, "bg": UIColors.SURFACE_SELECTED}
	return {}


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

	message_changed.emit("Choose an action for %s." % selected_character.character_name)
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


func _on_roster_manage_selected(character: Character) -> void:
	selected_character = character
	roster_mode = RosterMode.MANAGE
	display_refresh_requested.emit()


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
	display_refresh_requested.emit()


func _on_delete_confirmed() -> void:
	if selected_character == null:
		_on_roster_mode_back()
		return

	if GameState.party.has_member(selected_character):
		GameState.party.remove_member(selected_character.id)

	GameState.roster.remove_character(selected_character.id)
	message_changed.emit("%s has been deleted." % selected_character.character_name)
	selected_character = null
	roster_mode = RosterMode.VIEW
	display_refresh_requested.emit()


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
	message_changed.emit("%s has been renamed to %s." % [old_name, new_name])
	selected_character = null
	roster_mode = RosterMode.VIEW
	display_refresh_requested.emit()


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
	message_changed.emit("%s begins training as %s. Available %s (%d days)." % [
		selected_character.character_name,
		CharacterEnums.get_class_name(new_class),
		GameCalendar.format_short(completion_day),
		training_days
	])
	selected_character = null
	roster_mode = RosterMode.VIEW
	display_refresh_requested.emit()


func _on_job_selected(job_index: int) -> void:
	if selected_character == null:
		_on_roster_mode_back()
		return
	selected_character.town_job = job_index
	message_changed.emit("%s assigned to %s." % [
		selected_character.character_name,
		TownJobs.get_job_name(job_index)
	])
	roster_mode = RosterMode.MANAGE
	display_refresh_requested.emit()


func _on_job_removed() -> void:
	if selected_character == null:
		_on_roster_mode_back()
		return
	var old_job := TownJobs.get_job_name(selected_character.town_job)
	selected_character.town_job = -1
	message_changed.emit("%s removed from %s." % [selected_character.character_name, old_job])
	roster_mode = RosterMode.MANAGE
	display_refresh_requested.emit()


func _on_roster_mode_back() -> void:
	match roster_mode:
		RosterMode.VIEW:
			pass
		RosterMode.MANAGE:
			roster_mode = RosterMode.VIEW
			selected_character = null
		RosterMode.CONFIRM_DELETE, RosterMode.RENAME, RosterMode.CHANGE_CLASS, RosterMode.ASSIGN_JOB:
			roster_mode = RosterMode.MANAGE
	display_refresh_requested.emit()


func _update_roster_info() -> void:
	if nav == null and roster_mode == RosterMode.VIEW:
		detail.show_text("Select a character to manage.")
		return

	match roster_mode:
		RosterMode.VIEW:
			var idx := nav.get_current_index() if nav else -1
			var characters: Array[Character] = _displayed_roster_chars
			if idx >= 0 and idx < characters.size():
				_show_character_info(characters[idx])
			else:
				detail.show_text("Select a character to manage.")
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
	# Show the Front/Back row chip only for characters actually in the party, so
	# an in-party member reads consistently whether viewed here or on the Party
	# tab; a benched roster character has no row to show.
	var pidx := GameState.party.get_members().find(character)
	detail.show_character(character, maxi(pidx, 0), pidx >= 0)


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

	detail.show_text(text)


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

	detail.show_text(text)


func _show_class_change_info() -> void:
	if selected_character == null or nav == null:
		return

	var idx := nav.get_current_index()
	var class_count := CharacterEnums.CharacterClass.values().size()
	if idx < 0 or idx >= class_count:
		detail.show_text("Press Enter to cancel.")
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

	detail.show_text(text)


func _show_job_assignment_info() -> void:
	if selected_character == null:
		detail.show_text("")
		return
	var text := "[b]%s[/b] - Job Assignment\n\n" % selected_character.character_name
	text += "Town jobs provide daily income while benched:\n"
	text += "  [color=cyan]+5 XP/day[/color] to the character\n"
	text += "  [color=yellow]+2 Gold/day[/color] to the guild treasury\n\n"
	if selected_character.town_job >= 0:
		text += "Current job: [color=cyan]%s[/color]" % TownJobs.get_job_name(selected_character.town_job)
	else:
		text += "Currently unemployed."
	detail.show_text(text)


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
	display_refresh_requested.emit()
