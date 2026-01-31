extends Control

const CharEnum = preload("res://resources/character_enums.gd")
const MenuNavigatorClass = preload("res://systems/ui/menu_navigator.gd")
const KeyBindingHelperClass = preload("res://systems/ui/key_binding_helper.gd")

var selected_index: int = -1
var slot_buttons: Array[Button] = []
var current_slot: int = 0

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var formation_panel: PanelContainer = $VBoxContainer/FormationPanel
@onready var front_row: HBoxContainer = $VBoxContainer/FormationPanel/FormationVBox/FrontRowHBox/FrontRow
@onready var back_row: HBoxContainer = $VBoxContainer/FormationPanel/FormationVBox/BackRowHBox/BackRow
@onready var info_label: RichTextLabel = $VBoxContainer/InfoPanel/InfoLabel
@onready var help_label: Label = $VBoxContainer/HelpLabel
@onready var back_button: Button = $VBoxContainer/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_build_formation_display()
	_update_selection()


func _build_formation_display() -> void:
	for child in front_row.get_children():
		child.queue_free()
	for child in back_row.get_children():
		child.queue_free()
	slot_buttons.clear()

	for i in range(3):
		var btn := _create_slot_button(i)
		front_row.add_child(btn)
		slot_buttons.append(btn)

	for i in range(3, 6):
		var btn := _create_slot_button(i)
		back_row.add_child(btn)
		slot_buttons.append(btn)


func _create_slot_button(slot_index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 60)
	btn.pressed.connect(_on_slot_pressed.bind(slot_index))
	_update_slot_button(btn, slot_index)
	return btn


func _update_slot_button(btn: Button, slot_index: int) -> void:
	var character: Character = null
	if GameState.party and slot_index < GameState.party.size():
		character = GameState.party.get_member_at(slot_index)

	if character:
		btn.text = "%s\nL%d %s" % [
			character.character_name,
			character.level,
			CharEnum.get_class_name(character.character_class)
		]
		if character.is_dead:
			btn.modulate = Color(0.7, 0.3, 0.3)
		else:
			btn.modulate = Color.WHITE
	else:
		btn.text = "(Empty)"
		btn.modulate = Color(0.5, 0.5, 0.5)


func _update_selection() -> void:
	for i in range(slot_buttons.size()):
		var btn := slot_buttons[i]
		if i == current_slot:
			btn.grab_focus()
		if i == selected_index:
			btn.add_theme_color_override("font_color", Color(0, 1, 0))
		else:
			btn.remove_theme_color_override("font_color")

	_update_info()
	_update_help()


func _update_info() -> void:
	var character: Character = null
	if GameState.party and current_slot < GameState.party.size():
		character = GameState.party.get_member_at(current_slot)

	if character:
		var row_name := "Front Row" if current_slot < 3 else "Back Row"
		var text := "[b]%s[/b] (%s)\n" % [character.character_name, row_name]
		text += "Level %d %s %s\n" % [
			character.level,
			CharEnum.get_race_name(character.race),
			CharEnum.get_class_name(character.character_class)
		]
		text += "HP: %d/%d  MP: %d/%d\n" % [
			character.current_hp, character.max_hp,
			character.current_mp, character.max_mp
		]
		text += "AGI: %d (affects turn order)" % character.agility

		if current_slot < 3:
			text += "\n\n[color=yellow]Front row: Can attack with any weapon, targeted first by enemies[/color]"
		else:
			text += "\n\n[color=cyan]Back row: -1 weapon range, protected while front row has members[/color]"

		if character.is_dead:
			text += "\n[color=red]DEAD[/color]"

		info_label.text = text
	else:
		var row_name := "Front Row" if current_slot < 3 else "Back Row"
		info_label.text = "Empty slot (%s)\n\nMove a character here to fill this position." % row_name


func _update_help() -> void:
	var confirm := KeyBindingHelperClass.get_confirm_help()
	var cancel := KeyBindingHelperClass.get_cancel_help()
	var nav := KeyBindingHelperClass.get_arrow_nav_help()

	if selected_index >= 0:
		help_label.text = "Select slot to swap | %s" % cancel
	else:
		help_label.text = "%s | %s to swap | %s" % [nav, confirm.split(":")[0], cancel]


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
			_swap_positions(selected_index, slot_index)
		selected_index = -1
		_update_selection()


func _swap_positions(from_index: int, to_index: int) -> void:
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
	elif from_char != null and to_char == null:
		_move_to_empty_slot(from_index, to_index)
	elif from_char == null and to_char != null:
		_move_to_empty_slot(to_index, from_index)

	_refresh_display()


func _move_to_empty_slot(from_index: int, to_index: int) -> void:
	if to_index >= GameState.party.size():
		return

	var moves_needed := to_index - from_index
	if moves_needed > 0:
		for i in range(moves_needed):
			GameState.party.swap_positions(from_index + i, from_index + i + 1)
	else:
		for i in range(-moves_needed):
			GameState.party.swap_positions(from_index - i, from_index - i - 1)


func _refresh_display() -> void:
	for i in range(slot_buttons.size()):
		_update_slot_button(slot_buttons[i], i)
	_update_selection()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		if selected_index >= 0:
			selected_index = -1
			_update_selection()
		else:
			_on_back_pressed()
		return

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


func _on_back_pressed() -> void:
	SceneManager.go_to_town()
