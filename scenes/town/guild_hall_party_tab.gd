class_name GuildHallPartyTab
extends RefCounted

enum PartyMode { NORMAL, REORDER_SELECT, REORDER_MOVE, FORMATION_LIST, FORMATION_SAVE, FORMATION_MANAGE }
enum SortMode { DEFAULT, NAME, LEVEL, CLASS, RACE }

const MAX_FORMATIONS: int = 10

signal message_changed(text: String)
signal display_refresh_requested()

var party_mode: PartyMode = PartyMode.NORMAL
var party_focus: int = 0
var reorder_index: int = -1
var _reorder_original_ids: Array[String] = []
var _reorder_pre_grab_ids: Array[String] = []
var roster_sort_mode: SortMode = SortMode.DEFAULT
var _displayed_available_chars: Array[Character] = []
var _selected_formation: PartyFormation = null
var formation_name_edit: LineEdit = null

var party_nav: MenuNavigator = null
var nav: MenuNavigator = null
var buttons: Array[Button] = []
var party_buttons: Array[Button] = []
var roster_buttons: Array[Button] = []

var options_list: VBoxContainer
var detail: CharacterDetailView


func init(p_options_list: VBoxContainer, p_detail: CharacterDetailView) -> void:
	options_list = p_options_list
	detail = p_detail


func reset() -> void:
	party_mode = PartyMode.NORMAL
	reorder_index = -1
	roster_sort_mode = SortMode.DEFAULT
	_selected_formation = null


func populate() -> void:
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
		var moving := party_mode == PartyMode.REORDER_MOVE and i == reorder_index
		var btn := _create_party_button(member, i < 3, moving)
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
		message_changed.emit("Select a character to move, then press Enter.")
	elif party_mode == PartyMode.REORDER_MOVE:
		message_changed.emit("Move with Up/Down. Enter to place, Esc to cancel.")
	elif GameState.party.is_full():
		message_changed.emit("Party is full.")
	elif GameState.party.is_empty():
		message_changed.emit("Add characters to form your party.")
	else:
		message_changed.emit("Manage your adventuring party.")

	_update_party_info()


func handle_input(event: InputEvent) -> void:
	if party_mode == PartyMode.FORMATION_SAVE:
		if event.is_action_pressed("menu_cancel"):
			_on_formation_save_cancelled()
		return

	if party_mode in [PartyMode.REORDER_SELECT, PartyMode.REORDER_MOVE]:
		_handle_reorder_input(event)
		return

	if party_mode in [PartyMode.FORMATION_LIST, PartyMode.FORMATION_MANAGE]:
		if event.is_action_pressed("menu_cancel"):
			if party_mode == PartyMode.FORMATION_MANAGE:
				_on_formation_manage_back()
			else:
				_on_formation_back()
			return
		if nav:
			nav.handle_input(event)
		return

	if event.is_action_pressed("menu_sort") and party_mode == PartyMode.NORMAL:
		_cycle_sort()
		return

	if GameState.party.size() > 1:
		if event.is_action_pressed("menu_reorder"):
			_enter_reorder_mode()
			return

	if party_nav and party_nav.items.size() > 0:
		party_nav.handle_input(event)


func handle_back() -> bool:
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

	if party_mode == PartyMode.REORDER_SELECT:
		var reorder := KeyBindingHelper.get_reorder_help().split(":")[0]
		return "%s | %s: Grab | %s: Done | %s" % [v_nav, confirm.split(":")[0], reorder, cancel]
	elif party_mode == PartyMode.REORDER_MOVE:
		return "%s: Move | %s: Place | %s: Undo" % [v_nav.split(":")[0], confirm.split(":")[0], cancel.split(":")[0]]
	elif party_mode == PartyMode.FORMATION_SAVE:
		return "Type name | Enter: Confirm | %s" % cancel
	elif party_mode in [PartyMode.FORMATION_LIST, PartyMode.FORMATION_MANAGE]:
		return "%s | %s | %s" % [v_nav, confirm, cancel]
	elif GameState.party.size() > 1:
		var reorder := KeyBindingHelper.get_reorder_help()
		return "%s | %s | %s | %s | %s" % [h_nav, v_nav, confirm, reorder, sort_hint]
	else:
		return "%s | %s | %s | %s | %s" % [h_nav, v_nav, confirm, cancel, sort_hint]


func _clear_options() -> void:
	for child in options_list.get_children():
		child.queue_free()
	buttons.clear()
	nav = null
	party_nav = null
	party_buttons.clear()
	roster_buttons.clear()
	formation_name_edit = null


func _setup_nav() -> void:
	if buttons.is_empty():
		return
	nav = MenuNavigator.new()
	nav.setup(buttons, 0)


func _create_party_button(character: Character, front_row: bool, moving: bool = false) -> Button:
	var in_party := GameState.party.get_member(character.id) != null
	var chips: Array = []
	if moving:
		chips.append({"text": "◄ MOVING ►", "fg": UIColors.WARNING, "bg": UIColors.SURFACE_SELECTED})
	if in_party:
		chips.append({"text": "FRONT" if front_row else "BACK",
			"fg": UIColors.FRONT_ROW if front_row else UIColors.BACK_ROW, "bg": UIColors.SURFACE_SELECTED})
	var dim := false
	if character.is_dead:
		chips.append({"text": "DEAD", "fg": UIColors.TEXT_DANGER, "bg": Color(0.28, 0.10, 0.12)})
		dim = true
	elif not character.is_available():
		var t_elapsed := character.get_training_days_elapsed(GameState.game_day)
		chips.append({"text": "TRAINING %d/%d" % [t_elapsed, character.get_training_total()],
			"fg": UIColors.TEXT_WARNING, "bg": UIColors.SURFACE_SELECTED})
		dim = true
	var btn := MenuListRow.create({
		"badge": CharacterEnums.get_class_name(character.character_class).substr(0, 1).to_upper(),
		"badge_color": UIColors.class_color(character.character_class),
		"title": character.character_name,
		"title_color": UIColors.WARNING if moving else (UIColors.TEXT_DANGER if character.is_dead else UIColors.TEXT_PRIMARY),
		"subtitle": "L%d %s" % [character.level, CharacterEnums.get_class_name(character.character_class)],
		"chips": chips,
		"dim": dim and not moving,
	})
	if not character.is_dead and not character.is_available():
		btn.disabled = true
	return btn


func _on_party_member_pressed(character: Character) -> void:
	GameState.party.remove_member(character.id)
	party_focus = GameState.party.size()
	display_refresh_requested.emit()


func _on_roster_add_pressed(character: Character) -> void:
	if GameState.party.is_full():
		return
	if not character.is_available() or character.is_dead:
		return
	character.town_job = -1
	GameState.party.add_member(character)
	party_focus = GameState.party.size()
	display_refresh_requested.emit()


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
	_sort_party_by_role()
	message_changed.emit("Added %d characters to party." % to_add)
	display_refresh_requested.emit()


func _sort_party_by_role() -> void:
	const FRONT_CLASSES := [
		CharacterEnums.CharacterClass.FIGHTER,
		CharacterEnums.CharacterClass.LORD,
		CharacterEnums.CharacterClass.VALKYRIE,
		CharacterEnums.CharacterClass.SAMURAI,
		CharacterEnums.CharacterClass.MONK,
		CharacterEnums.CharacterClass.NINJA,
	]
	var members := GameState.party.get_members().duplicate()
	members.sort_custom(func(a: Character, b: Character) -> bool:
		var a_front := a.character_class in FRONT_CLASSES
		var b_front := b.character_class in FRONT_CLASSES
		if a_front != b_front:
			return a_front
		return false
	)
	GameState.party.clear()
	for m: Character in members:
		GameState.party.add_member(m)


func _enter_reorder_mode() -> void:
	if GameState.party.size() < 2:
		return
	_reorder_original_ids.clear()
	for m in GameState.party.get_members():
		_reorder_original_ids.append(m.id)
	party_mode = PartyMode.REORDER_SELECT
	reorder_index = 0
	party_focus = 0
	display_refresh_requested.emit()


func _confirm_reorder() -> void:
	_reorder_original_ids.clear()
	party_mode = PartyMode.NORMAL
	reorder_index = -1
	message_changed.emit("Reorder confirmed.")
	display_refresh_requested.emit()


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
	message_changed.emit("Reorder cancelled.")
	display_refresh_requested.emit()


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
	display_refresh_requested.emit()


func _move_party_member(direction: int) -> void:
	var new_index := reorder_index + direction
	if new_index < 0 or new_index >= GameState.party.size():
		return
	if GameState.party.swap_positions(reorder_index, new_index):
		reorder_index = new_index
		display_refresh_requested.emit()


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
			display_refresh_requested.emit()
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
			display_refresh_requested.emit()


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
		detail.show_text("Select a character to view details.")
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
			detail.show_text(text)
		return

	var character: Character = _get_character_at_party_index(idx)
	if character:
		# Active party members carry a real row; benched/available do not.
		var is_member := idx < party_buttons.size()
		detail.show_character(character, idx if is_member else 0, is_member)
	else:
		var all_count: int = party_buttons.size() + roster_buttons.size()
		if idx == all_count:
			detail.show_text("[b]Equipment & Spells[/b]\n\nOpen the party management screen\nto manage equipment, spells, and inventory.")
		elif idx == all_count + 1:
			detail.show_text("[b]Quick Pick Party[/b]\n\nRandomly fill empty party slots\nfrom available roster members.")
		elif idx == all_count + 2:
			var text := "[b]Formations[/b]\n\nSave and load named party compositions.\n\n"
			text += "Saved: %d/%d" % [GameState.party_formations.size(), MAX_FORMATIONS]
			detail.show_text(text)
		else:
			detail.show_text("Select a character to view details.")


func _get_character_at_party_index(idx: int) -> Character:
	if idx < party_buttons.size():
		if idx >= 0 and idx < GameState.party.size():
			return GameState.party.get_member_at(idx)
	else:
		var roster_idx := idx - party_buttons.size()
		if roster_idx >= 0 and roster_idx < _displayed_available_chars.size():
			return _displayed_available_chars[roster_idx]
	return null


func _on_formations_pressed() -> void:
	party_mode = PartyMode.FORMATION_LIST
	display_refresh_requested.emit()


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
		message_changed.emit("Formation slots full (%d/%d)." % [GameState.party_formations.size(), MAX_FORMATIONS])
	else:
		message_changed.emit("Saved formations: %d/%d" % [GameState.party_formations.size(), MAX_FORMATIONS])

	_setup_nav()
	if nav:
		nav.selection_changed.connect(_on_formation_list_selection_changed)
	_update_formation_list_info()


func _on_formation_list_selection_changed(_index: int) -> void:
	_update_formation_list_info()


func _update_formation_list_info() -> void:
	if nav == null:
		detail.show_text("Select a formation to manage.")
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
		detail.show_text(text)
		return

	var formation_idx := idx - 1
	if formation_idx >= 0 and formation_idx < GameState.party_formations.size():
		var formation := GameState.party_formations[formation_idx]
		_show_formation_info(formation)
	else:
		detail.show_text("Return to party management.")


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
	detail.show_text(text)


func _on_formation_save_pressed() -> void:
	party_mode = PartyMode.FORMATION_SAVE
	display_refresh_requested.emit()


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

	message_changed.emit("Enter a name for this formation.")

	var text := "[b]Save Formation[/b]\n\n"
	text += "[color=cyan]Current party:[/color]\n"
	for i in range(GameState.party.size()):
		var member := GameState.party.get_member_at(i)
		var row_tag := "[F]" if i < 3 else "[B]"
		text += "  %s %s - L%d %s\n" % [row_tag, member.character_name, member.level, CharacterEnums.get_class_name(member.character_class)]
	detail.show_text(text)


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
	message_changed.emit("Formation '%s' saved." % fname)
	party_mode = PartyMode.FORMATION_LIST
	display_refresh_requested.emit()


func _on_formation_save_cancelled() -> void:
	party_mode = PartyMode.FORMATION_LIST
	display_refresh_requested.emit()


func _on_formation_selected(formation: PartyFormation) -> void:
	_selected_formation = formation
	party_mode = PartyMode.FORMATION_MANAGE
	display_refresh_requested.emit()


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

	message_changed.emit("Manage formation: %s" % _selected_formation.formation_name)
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
			detail.show_text(text)
		1:
			var text := "[b]Delete Formation[/b]\n\n"
			text += "[color=red]Remove '%s' from saved formations.[/color]\n" % _selected_formation.formation_name
			text += "This cannot be undone."
			detail.show_text(text)
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
		message_changed.emit("Loaded %s (%d/%d - %d not in roster)" % [_selected_formation.formation_name, loaded, total, missing])
	else:
		message_changed.emit("Loaded %s" % _selected_formation.formation_name)

	_selected_formation = null
	party_mode = PartyMode.NORMAL
	display_refresh_requested.emit()


func _on_formation_delete() -> void:
	if _selected_formation == null:
		return
	var fname := _selected_formation.formation_name
	GameState.party_formations.erase(_selected_formation)
	_selected_formation = null
	message_changed.emit("Formation '%s' deleted." % fname)
	party_mode = PartyMode.FORMATION_LIST
	display_refresh_requested.emit()


func _on_formation_back() -> void:
	_selected_formation = null
	party_mode = PartyMode.NORMAL
	display_refresh_requested.emit()


func _on_formation_manage_back() -> void:
	_selected_formation = null
	party_mode = PartyMode.FORMATION_LIST
	display_refresh_requested.emit()


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
