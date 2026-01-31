extends Control

const CharEnum = preload("res://resources/character_enums.gd")
const ClassDataRef = preload("res://resources/class_data.gd")
const MenuNavigatorClass = preload("res://systems/ui/menu_navigator.gd")
const KeyBindingHelperClass = preload("res://systems/ui/key_binding_helper.gd")

enum Mode { MAIN_MENU, VIEW_ROSTER, SELECT_CHARACTER, CONFIRM_DELETE, RENAME_CHARACTER, CHANGE_CLASS }

const MAIN_OPTIONS: Array[Dictionary] = [
	{"id": "create", "name": "Create Character", "description": "Create a new adventurer to add to your roster."},
	{"id": "view", "name": "View Roster", "description": "View all characters in the roster with their stats and status."},
	{"id": "manage", "name": "Manage Character", "description": "Rename, change class, or delete an existing character."}
]

const MANAGE_OPTIONS: Array[Dictionary] = [
	{"id": "rename", "name": "Rename", "description": "Change the character's name."},
	{"id": "change_class", "name": "Change Class", "description": "Change the character's class. Level will reset to 1."},
	{"id": "delete", "name": "Delete", "description": "Permanently remove the character from the roster."}
]

var current_mode: Mode = Mode.MAIN_MENU
var selected_character: Character = null
var selected_manage_action: String = ""

var nav: MenuNavigator = null
var buttons: Array[Button] = []

@onready var title_label: Label = $MainHBox/LeftPanel/Header/TitleLabel
@onready var count_label: Label = $MainHBox/LeftPanel/Header/CountLabel
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

@onready var rename_edit: LineEdit = null


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_refresh_display()


func _refresh_display() -> void:
	count_label.text = "Roster: %d/%d" % [GameState.roster.size(), GameState.roster.MAX_SIZE]
	_update_roster_display()

	match current_mode:
		Mode.MAIN_MENU:
			_populate_main_menu()
			message_label.text = "Welcome to the Training Grounds."
		Mode.VIEW_ROSTER:
			_populate_roster_view()
			message_label.text = "Viewing all characters in roster."
		Mode.SELECT_CHARACTER:
			_populate_character_select()
			message_label.text = "Select a character to manage."
		Mode.CONFIRM_DELETE:
			_populate_delete_confirm()
			message_label.text = "Are you sure you want to delete this character?"
		Mode.RENAME_CHARACTER:
			_populate_rename_screen()
			message_label.text = "Enter a new name for the character."
		Mode.CHANGE_CLASS:
			_populate_class_change()
			message_label.text = "Select a new class. Level will reset to 1."

	_update_info()
	_update_help()


func _populate_main_menu() -> void:
	_clear_options()

	for option in MAIN_OPTIONS:
		var btn := Button.new()
		btn.text = option["name"]
		btn.custom_minimum_size = Vector2(350, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if option["id"] == "create" and GameState.roster.is_full():
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6)
			btn.tooltip_text = "Roster is full"

		if (option["id"] == "view" or option["id"] == "manage") and GameState.roster.size() == 0:
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6)
			btn.tooltip_text = "No characters in roster"

		btn.pressed.connect(_on_main_option_selected.bind(option["id"]))
		options_list.add_child(btn)
		buttons.append(btn)

	_setup_nav()


func _populate_roster_view() -> void:
	_clear_options()

	for character in GameState.roster.get_all():
		var btn := Button.new()
		btn.text = "%s - L%d %s %s" % [
			character.character_name,
			character.level,
			CharEnum.get_race_name(character.race),
			CharEnum.get_class_name(character.character_class)
		]
		btn.custom_minimum_size = Vector2(350, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if character.is_dead:
			btn.modulate = Color(0.7, 0.3, 0.3)
		elif GameState.party.has_member(character):
			btn.modulate = Color(0.5, 0.8, 1.0)

		btn.pressed.connect(_on_roster_character_selected.bind(character))
		options_list.add_child(btn)
		buttons.append(btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(350, 36)
	back_btn.pressed.connect(_on_mode_back)
	options_list.add_child(back_btn)
	buttons.append(back_btn)

	_setup_nav()


func _populate_character_select() -> void:
	_clear_options()

	for character in GameState.roster.get_all():
		var btn := Button.new()
		var in_party: bool = GameState.party.has_member(character)
		btn.text = "%s - L%d %s%s" % [
			character.character_name,
			character.level,
			CharEnum.get_class_name(character.character_class),
			" [IN PARTY]" if in_party else ""
		]
		btn.custom_minimum_size = Vector2(350, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if character.is_dead:
			btn.modulate = Color(0.7, 0.3, 0.3)
		elif in_party:
			btn.modulate = Color(0.5, 0.8, 1.0)

		btn.pressed.connect(_on_manage_character_selected.bind(character))
		options_list.add_child(btn)
		buttons.append(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(350, 36)
	cancel_btn.pressed.connect(_on_mode_back)
	options_list.add_child(cancel_btn)
	buttons.append(cancel_btn)

	_setup_nav()


func _populate_delete_confirm() -> void:
	_clear_options()

	if selected_character == null:
		_on_mode_back()
		return

	var confirm_btn := Button.new()
	confirm_btn.text = "Yes, delete %s" % selected_character.character_name
	confirm_btn.custom_minimum_size = Vector2(350, 36)
	confirm_btn.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	confirm_btn.pressed.connect(_on_delete_confirmed)
	options_list.add_child(confirm_btn)
	buttons.append(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "No, keep character"
	cancel_btn.custom_minimum_size = Vector2(350, 36)
	cancel_btn.pressed.connect(_on_mode_back)
	options_list.add_child(cancel_btn)
	buttons.append(cancel_btn)

	_setup_nav()
	if nav:
		nav._move(1)


func _populate_rename_screen() -> void:
	_clear_options()

	if selected_character == null:
		_on_mode_back()
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
	cancel_btn.pressed.connect(_on_mode_back)
	options_list.add_child(cancel_btn)
	buttons.append(cancel_btn)


func _populate_class_change() -> void:
	_clear_options()

	if selected_character == null:
		_on_mode_back()
		return

	var stats := {
		"strength": selected_character.strength,
		"intelligence": selected_character.intelligence,
		"piety": selected_character.piety,
		"vitality": selected_character.vitality,
		"agility": selected_character.agility,
		"luck": selected_character.luck
	}

	for class_id: int in CharEnum.CharacterClass.values():
		var char_class: CharEnum.CharacterClass = class_id as CharEnum.CharacterClass
		var meets_reqs := ClassDataRef.meets_requirements(char_class, stats)

		var btn := Button.new()
		btn.text = CharEnum.get_class_name(char_class)
		btn.custom_minimum_size = Vector2(350, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if char_class == selected_character.character_class:
			btn.text += " (current)"
			btn.disabled = true
			btn.modulate = Color(0.7, 0.7, 0.7)
		elif not meets_reqs:
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5)
			btn.tooltip_text = "Does not meet stat requirements"
		else:
			btn.pressed.connect(_on_class_change_selected.bind(char_class))

		options_list.add_child(btn)
		buttons.append(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(350, 36)
	cancel_btn.pressed.connect(_on_mode_back)
	options_list.add_child(cancel_btn)
	buttons.append(cancel_btn)

	_setup_nav()


func _clear_options() -> void:
	for child in options_list.get_children():
		child.queue_free()
	buttons.clear()
	nav = null
	rename_edit = null


func _setup_nav() -> void:
	if buttons.is_empty():
		return

	nav = MenuNavigatorClass.new()
	nav.setup(buttons, 0)
	nav.selection_changed.connect(_on_selection_changed)


func _on_selection_changed(_index: int) -> void:
	_update_info()


func _update_info() -> void:
	if nav == null:
		info_label.text = "Select an option."
		return

	var idx := nav.get_current_index()

	match current_mode:
		Mode.MAIN_MENU:
			_update_main_menu_info(idx)
		Mode.VIEW_ROSTER, Mode.SELECT_CHARACTER:
			_update_character_info(idx)
		Mode.CONFIRM_DELETE:
			_update_delete_info()
		Mode.RENAME_CHARACTER:
			_update_rename_info()
		Mode.CHANGE_CLASS:
			_update_class_change_info(idx)


func _update_main_menu_info(idx: int) -> void:
	if idx < 0 or idx >= MAIN_OPTIONS.size():
		info_label.text = "Select an option."
		return

	var option: Dictionary = MAIN_OPTIONS[idx]
	var text := "[b]%s[/b]\n\n" % option["name"]
	text += "%s\n\n" % option["description"]

	match option["id"]:
		"create":
			text += "[color=cyan]Roster capacity:[/color] %d/%d\n\n" % [
				GameState.roster.size(),
				GameState.roster.MAX_SIZE
			]
			if GameState.roster.is_full():
				text += "[color=red]Roster is full! Delete a character to make room.[/color]"
			else:
				text += "Create a new character by selecting race, rolling\nstats, choosing class, alignment, and name."
		"view":
			text += "[color=cyan]Total characters:[/color] %d\n" % GameState.roster.size()
			var in_party := 0
			var dead := 0
			for c in GameState.roster.get_all():
				if GameState.party.has_member(c):
					in_party += 1
				if c.is_dead:
					dead += 1
			text += "[color=cyan]In party:[/color] %d\n" % in_party
			if dead > 0:
				text += "[color=red]Dead:[/color] %d\n" % dead
		"manage":
			text += "Select a character to:\n"
			text += "  - [color=yellow]Rename[/color]: Change their name\n"
			text += "  - [color=yellow]Change Class[/color]: Switch to a different class\n"
			text += "    (Level resets to 1)\n"
			text += "  - [color=red]Delete[/color]: Remove from roster permanently"

	info_label.text = text


func _update_character_info(idx: int) -> void:
	var characters: Array[Character] = GameState.roster.get_all()
	if idx < 0 or idx >= characters.size():
		info_label.text = "Press Enter to go back."
		return

	var c: Character = characters[idx]
	var text := "[b]%s[/b]\n" % c.character_name
	text += "Level %d %s %s\n" % [c.level, CharEnum.get_race_name(c.race), CharEnum.get_class_name(c.character_class)]
	text += "Alignment: %s\n\n" % CharEnum.get_alignment_name(c.alignment)

	text += "[color=cyan]Stats:[/color]\n"
	text += "  STR: %d  INT: %d  PIE: %d\n" % [c.strength, c.intelligence, c.piety]
	text += "  VIT: %d  AGI: %d  LCK: %d\n\n" % [c.vitality, c.agility, c.luck]

	text += "[color=cyan]Combat:[/color]\n"
	text += "  HP: %d/%d  MP: %d/%d\n" % [c.current_hp, c.max_hp, c.current_mp, c.max_mp]
	text += "  XP: %d\n\n" % c.experience

	if c.is_dead:
		if c.has_status(CharEnum.StatusEffect.LOST):
			text += "[color=red]Status: LOST FOREVER[/color]\n"
		elif c.has_status(CharEnum.StatusEffect.ASHED):
			text += "[color=orange]Status: ASHED[/color]\n"
		else:
			text += "[color=red]Status: DEAD[/color]\n"
	elif GameState.party.has_member(c):
		text += "[color=cyan]Currently in party[/color]\n"

	info_label.text = text


func _update_delete_info() -> void:
	if selected_character == null:
		info_label.text = "No character selected."
		return

	var text := "[b]Delete %s?[/b]\n\n" % selected_character.character_name
	text += "Level %d %s %s\n\n" % [
		selected_character.level,
		CharEnum.get_race_name(selected_character.race),
		CharEnum.get_class_name(selected_character.character_class)
	]
	text += "[color=red]WARNING: This action cannot be undone![/color]\n\n"
	text += "The character will be permanently removed\nfrom the roster."

	if GameState.party.has_member(selected_character):
		text += "\n\n[color=orange]This character is currently in your party\nand will be removed from it.[/color]"

	info_label.text = text


func _update_rename_info() -> void:
	if selected_character == null:
		info_label.text = "No character selected."
		return

	var text := "[b]Rename %s[/b]\n\n" % selected_character.character_name
	text += "Level %d %s %s\n\n" % [
		selected_character.level,
		CharEnum.get_race_name(selected_character.race),
		CharEnum.get_class_name(selected_character.character_class)
	]
	text += "Enter a new name in the text field.\n"
	text += "Maximum 20 characters."

	info_label.text = text


func _update_class_change_info(idx: int) -> void:
	if selected_character == null:
		info_label.text = "No character selected."
		return

	var class_count := CharEnum.CharacterClass.values().size()
	if idx < 0 or idx >= class_count:
		info_label.text = "Press Enter to cancel."
		return

	var char_class: CharEnum.CharacterClass = idx as CharEnum.CharacterClass
	var data: Dictionary = ClassDataRef.get_class_data(char_class)
	var reqs: Dictionary = ClassDataRef.get_requirements(char_class)

	var text := "[b]%s[/b]\n\n" % CharEnum.get_class_name(char_class)
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
		text += "[color=orange]Changing class will reset level to 1![/color]\n"
		text += "Stats and known spells will be preserved."

	info_label.text = text


func _update_roster_display() -> void:
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
	class_label.text = "L%d %s" % [c.level, CharEnum.get_class_name(c.character_class)]
	class_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(class_label)

	var status_label := Label.new()
	if c.has_status(CharEnum.StatusEffect.LOST):
		status_label.text = "[LOST]"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.2, 0.2))
	elif c.is_dead:
		status_label.text = "[DEAD]"
		status_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	elif GameState.party.has_member(c):
		status_label.text = "[PARTY]"
		status_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	else:
		status_label.text = ""
	row.add_child(status_label)

	return row


func _on_main_option_selected(option_id: String) -> void:
	match option_id:
		"create":
			SceneManager.go_to_character_creation()
		"view":
			current_mode = Mode.VIEW_ROSTER
			_refresh_display()
		"manage":
			current_mode = Mode.SELECT_CHARACTER
			_refresh_display()


func _on_roster_character_selected(character: Character) -> void:
	selected_character = character
	_update_info()


func _on_manage_character_selected(character: Character) -> void:
	selected_character = character
	_show_manage_actions()


func _show_manage_actions() -> void:
	_clear_options()

	if selected_character == null:
		_on_mode_back()
		return

	var header := Label.new()
	header.text = "Managing: %s" % selected_character.character_name
	options_list.add_child(header)

	for option in MANAGE_OPTIONS:
		var btn := Button.new()
		btn.text = option["name"]
		btn.custom_minimum_size = Vector2(350, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if option["id"] == "delete":
			btn.add_theme_color_override("font_color", Color(1, 0.5, 0.5))

		btn.pressed.connect(_on_manage_action_selected.bind(option["id"]))
		options_list.add_child(btn)
		buttons.append(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(350, 36)
	cancel_btn.pressed.connect(_on_mode_back)
	options_list.add_child(cancel_btn)
	buttons.append(cancel_btn)

	_setup_nav()
	_update_info()


func _on_manage_action_selected(action_id: String) -> void:
	selected_manage_action = action_id

	match action_id:
		"rename":
			current_mode = Mode.RENAME_CHARACTER
		"change_class":
			current_mode = Mode.CHANGE_CLASS
		"delete":
			current_mode = Mode.CONFIRM_DELETE

	_refresh_display()


func _on_delete_confirmed() -> void:
	if selected_character == null:
		_on_mode_back()
		return

	if GameState.party.has_member(selected_character):
		GameState.party.remove_member(selected_character.id)

	GameState.roster.remove_character(selected_character.id)
	message_label.text = "%s has been deleted." % selected_character.character_name
	selected_character = null
	current_mode = Mode.MAIN_MENU
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
		_on_mode_back()
		return

	var old_name := selected_character.character_name
	selected_character.character_name = new_name
	message_label.text = "%s has been renamed to %s." % [old_name, new_name]
	selected_character = null
	current_mode = Mode.MAIN_MENU
	_refresh_display()


func _on_class_change_selected(new_class: CharEnum.CharacterClass) -> void:
	if selected_character == null:
		_on_mode_back()
		return

	var old_class := selected_character.character_class
	selected_character.character_class = new_class
	selected_character.level = 1
	selected_character.experience = 0

	var class_data: Dictionary = ClassDataRef.get_class_data(new_class)
	selected_character.max_hp = class_data.get("hp_base", 10) + selected_character.vitality
	selected_character.current_hp = selected_character.max_hp
	selected_character.max_mp = class_data.get("mp_base", 0) + (selected_character.intelligence + selected_character.piety) / 4
	selected_character.current_mp = selected_character.max_mp

	message_label.text = "%s changed class from %s to %s (now Level 1)." % [
		selected_character.character_name,
		CharEnum.get_class_name(old_class),
		CharEnum.get_class_name(new_class)
	]
	selected_character = null
	current_mode = Mode.MAIN_MENU
	_refresh_display()


func _on_mode_back() -> void:
	match current_mode:
		Mode.VIEW_ROSTER, Mode.SELECT_CHARACTER:
			current_mode = Mode.MAIN_MENU
			selected_character = null
		Mode.CONFIRM_DELETE, Mode.RENAME_CHARACTER, Mode.CHANGE_CLASS:
			current_mode = Mode.SELECT_CHARACTER
	_refresh_display()


func _update_help() -> void:
	var v_nav := KeyBindingHelperClass.get_nav_help()
	var confirm := KeyBindingHelperClass.get_confirm_help()
	var cancel := KeyBindingHelperClass.get_cancel_help()

	match current_mode:
		Mode.MAIN_MENU:
			help_label.text = "%s | %s: Select | %s" % [v_nav, confirm.split(":")[0], cancel]
		Mode.RENAME_CHARACTER:
			help_label.text = "Type name | Enter: Confirm | %s: Cancel" % cancel.split(":")[0]
		_:
			help_label.text = "%s | %s: Select | %s: Back" % [v_nav, confirm.split(":")[0], cancel.split(":")[0]]


func _unhandled_input(event: InputEvent) -> void:
	if current_mode == Mode.RENAME_CHARACTER:
		if event.is_action_pressed("menu_cancel"):
			_on_mode_back()
		return

	if event.is_action_pressed("menu_cancel"):
		if current_mode == Mode.MAIN_MENU:
			_on_back_pressed()
		else:
			_on_mode_back()
		return

	if nav:
		if event.is_action_pressed("menu_up"):
			nav._move(-1)
			_update_info()
		elif event.is_action_pressed("menu_down"):
			nav._move(1)
			_update_info()
		elif event.is_action_pressed("menu_confirm"):
			nav._confirm()


func _on_back_pressed() -> void:
	SceneManager.go_to_town()
