class_name PartyMenuFormationTab
extends RefCounted

var slot_buttons: Array[Button] = []
var selected_index: int = -1
var current_slot: int = 0

var form_front_row: HBoxContainer
var form_back_row: HBoxContainer
var info_label: RichTextLabel


func init(p_front_row: HBoxContainer, p_back_row: HBoxContainer, p_info_label: RichTextLabel) -> void:
	form_front_row = p_front_row
	form_back_row = p_back_row
	info_label = p_info_label


func refresh() -> void:
	_build_slots()
	_update_selection()


func _build_slots() -> void:
	for child in form_front_row.get_children():
		child.queue_free()
	for child in form_back_row.get_children():
		child.queue_free()
	slot_buttons.clear()

	for i in range(3):
		var btn := _create_slot_button(i)
		form_front_row.add_child(btn)
		slot_buttons.append(btn)

	for i in range(3, 6):
		var btn := _create_slot_button(i)
		form_back_row.add_child(btn)
		slot_buttons.append(btn)


func _create_slot_button(slot_index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 50)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_slot_pressed.bind(slot_index))
	_update_slot_button(btn, slot_index)
	return btn


func _update_slot_button(btn: Button, slot_index: int) -> void:
	var character: Character = null
	if GameState.party and slot_index < GameState.party.size():
		character = GameState.party.get_member_at(slot_index)

	if character:
		btn.text = "%s\nL%d %s" % [character.character_name, character.level, CharacterEnums.get_class_name(character.character_class)]
		btn.modulate = UIColors.MODULATE_DEAD if character.is_dead else Color.WHITE
	else:
		btn.text = "(Empty)"
		btn.modulate = UIColors.MODULATE_DISABLED


func _update_selection() -> void:
	for i in range(slot_buttons.size()):
		var btn := slot_buttons[i]
		if i == selected_index:
			btn.add_theme_color_override("font_color", UIColors.TEXT_ACTIVE)
			btn.add_theme_color_override("font_hover_color", UIColors.TEXT_ACTIVE)
		elif i == current_slot:
			btn.add_theme_color_override("font_color", UIColors.WARNING)
			btn.add_theme_color_override("font_hover_color", UIColors.WARNING)
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_color_override("font_hover_color")

	_update_info()


func _update_info() -> void:
	var character: Character = null
	if GameState.party and current_slot < GameState.party.size():
		character = GameState.party.get_member_at(current_slot)

	if character:
		var row_name := "Front Row" if current_slot < 3 else "Back Row"
		var text := "[b]%s[/b] (%s)\n" % [character.character_name, row_name]
		text += "Level %d %s %s\n" % [character.level, CharacterEnums.get_race_name(character.race), CharacterEnums.get_class_name(character.character_class)]
		text += "HP: %d/%d  MP: %d/%d\n" % [character.current_hp, character.max_hp, character.current_mp, character.max_mp]
		text += "AGI: %d (affects turn order)\n\n" % character.agility

		if current_slot < 3:
			text += "[color=yellow]Front row: Full weapon range, targeted first[/color]"
		else:
			text += "[color=cyan]Back row: -1 weapon range, protected[/color]"

		if character.is_dead:
			text += "\n[color=red]DEAD[/color]"

		info_label.text = text
	else:
		var row_name := "Front Row" if current_slot < 3 else "Back Row"
		info_label.text = "Empty slot (%s)" % row_name


func _on_slot_pressed(slot_index: int) -> void:
	if selected_index < 0:
		var character: Character = null
		if GameState.party and slot_index < GameState.party.size():
			character = GameState.party.get_member_at(slot_index)
		if character:
			selected_index = slot_index
			_update_selection()
	else:
		if slot_index != selected_index:
			_swap_formation(selected_index, slot_index)
		selected_index = -1
		_update_selection()


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

	for i in range(slot_buttons.size()):
		_update_slot_button(slot_buttons[i], i)


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


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_left"):
		_move_selection(-1, 0)
	elif event.is_action_pressed("menu_right"):
		_move_selection(1, 0)
	elif event.is_action_pressed("menu_up"):
		_move_selection(0, -1)
	elif event.is_action_pressed("menu_down"):
		_move_selection(0, 1)
	elif event.is_action_pressed("menu_confirm"):
		_on_slot_pressed(current_slot)


func _move_selection(dx: int, dy: int) -> void:
	var col := current_slot % 3
	var row := current_slot / 3

	col = clampi(col + dx, 0, 2)
	row = clampi(row + dy, 0, 1)

	current_slot = row * 3 + col
	_update_selection()


func handle_back() -> bool:
	if selected_index >= 0:
		selected_index = -1
		refresh()
		return true
	return false
