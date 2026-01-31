extends Control

enum Mode { PARTY, ROSTER, REORDER }

var current_mode: Mode = Mode.PARTY
var reorder_index: int = -1
var party_nav: MenuNavigator = null
var roster_nav: MenuNavigator = null
var party_buttons: Array[Button] = []
var roster_buttons: Array[Button] = []

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var party_panel: PanelContainer = $VBoxContainer/HBoxContainer/PartyPanel
@onready var party_list: VBoxContainer = $VBoxContainer/HBoxContainer/PartyPanel/PartyList
@onready var roster_panel: PanelContainer = $VBoxContainer/HBoxContainer/RosterPanel
@onready var roster_list: VBoxContainer = $VBoxContainer/HBoxContainer/RosterPanel/RosterList
@onready var info_panel: PanelContainer = $VBoxContainer/InfoPanel
@onready var info_label: RichTextLabel = $VBoxContainer/InfoPanel/InfoLabel
@onready var help_label: Label = $VBoxContainer/HelpLabel
@onready var back_button: Button = $VBoxContainer/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_refresh_lists()
	_setup_navigation()
	_update_mode_display()


func _setup_navigation() -> void:
	party_nav = MenuNavigator.new()
	roster_nav = MenuNavigator.new()

	if not party_buttons.is_empty():
		party_nav.setup(party_buttons, 0)
	if not roster_buttons.is_empty():
		roster_nav.setup(roster_buttons, 0)

	_update_info()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		if current_mode == Mode.REORDER:
			_exit_reorder_mode()
		else:
			_on_back_pressed()
		return

	if current_mode == Mode.REORDER:
		_handle_reorder_input(event)
		return

	if event.is_action_pressed("menu_left") or event.is_action_pressed("menu_right"):
		_switch_mode()
		return

	var nav: MenuNavigator = party_nav if current_mode == Mode.PARTY else roster_nav
	if nav and nav.items.size() > 0:
		if event.is_action_pressed("menu_up"):
			nav._move(-1)
			_update_info()
		elif event.is_action_pressed("menu_down"):
			nav._move(1)
			_update_info()
		elif event.is_action_pressed("menu_confirm"):
			if current_mode == Mode.PARTY:
				nav._confirm()
			else:
				nav._confirm()

	if current_mode == Mode.PARTY and GameState.party.size() > 1:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_F or event.keycode == KEY_R:
				_enter_reorder_mode()


func _enter_reorder_mode() -> void:
	if GameState.party.size() < 2:
		return

	current_mode = Mode.REORDER
	reorder_index = party_nav.get_current_index() if party_nav else 0
	_refresh_party_list()
	_update_mode_display()
	_update_info()


func _exit_reorder_mode() -> void:
	current_mode = Mode.PARTY
	reorder_index = -1
	_refresh_party_list()
	_setup_navigation()
	_update_mode_display()
	_update_info()


func _handle_reorder_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_up"):
		_move_party_member(-1)
	elif event.is_action_pressed("menu_down"):
		_move_party_member(1)
	elif event.is_action_pressed("menu_confirm"):
		_exit_reorder_mode()


func _move_party_member(direction: int) -> void:
	var new_index := reorder_index + direction
	if new_index < 0 or new_index >= GameState.party.size():
		return

	if GameState.party.swap_positions(reorder_index, new_index):
		reorder_index = new_index
		_refresh_party_list()
		_update_info()


func _switch_mode() -> void:
	if current_mode == Mode.PARTY and not roster_buttons.is_empty():
		current_mode = Mode.ROSTER
	elif current_mode == Mode.ROSTER and not party_buttons.is_empty():
		current_mode = Mode.PARTY

	_update_mode_display()
	_update_info()


func _update_mode_display() -> void:
	match current_mode:
		Mode.PARTY:
			if party_nav and party_nav.items.size() > 0:
				party_nav._update_focus()
		Mode.ROSTER:
			if roster_nav and roster_nav.items.size() > 0:
				roster_nav._update_focus()
		Mode.REORDER:
			pass

	_update_help_text()


func _update_help_text() -> void:
	match current_mode:
		Mode.PARTY:
			if GameState.party.is_empty():
				help_label.text = "Left/Right: Switch to Roster | Escape: Back to Town"
			elif GameState.party.size() > 1:
				help_label.text = "Enter: Remove | R: Reorder | Left/Right: Roster | Escape: Back"
			else:
				help_label.text = "Enter: Remove | Left/Right: Switch to Roster | Escape: Back"
		Mode.ROSTER:
			if GameState.party.is_full():
				help_label.text = "Party Full | Left/Right: Switch to Party | Escape: Back"
			else:
				help_label.text = "Enter: Add to Party | Left/Right: Switch to Party | Escape: Back"
		Mode.REORDER:
			help_label.text = "Up/Down: Move | Enter: Done | Escape: Cancel"


func _refresh_lists() -> void:
	_refresh_party_list()
	_refresh_roster_list()


func _refresh_party_list() -> void:
	for child in party_list.get_children():
		child.queue_free()
	party_buttons.clear()

	var header_text := "PARTY (%d/6)" % GameState.party.size()
	if current_mode == Mode.REORDER:
		header_text += " [REORDERING]"
	var party_header := Label.new()
	party_header.text = header_text
	party_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	party_list.add_child(party_header)

	for i in range(GameState.party.size()):
		var member: Character = GameState.party.get_member_at(i)
		var btn := _create_character_button(member, i < 3)

		if current_mode == Mode.REORDER:
			if i == reorder_index:
				btn.add_theme_color_override("font_color", Color(1, 1, 0.3))
				btn.text = "> " + btn.text + " <"
		else:
			btn.pressed.connect(_on_party_member_pressed.bind(member))

		party_list.add_child(btn)
		party_buttons.append(btn)

	if party_buttons.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(Empty)"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.modulate = Color(0.5, 0.5, 0.5)
		party_list.add_child(empty_label)


func _refresh_roster_list() -> void:
	for child in roster_list.get_children():
		child.queue_free()
	roster_buttons.clear()

	var available := GameState.roster.get_available(GameState.party)

	var roster_label := Label.new()
	roster_label.text = "ROSTER (%d available)" % available.size()
	roster_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roster_list.add_child(roster_label)

	for character in available:
		var btn := _create_character_button(character, false)
		btn.pressed.connect(_on_roster_character_pressed.bind(character))
		roster_list.add_child(btn)
		roster_buttons.append(btn)

	if roster_buttons.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(No characters)"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.modulate = Color(0.5, 0.5, 0.5)
		roster_list.add_child(empty_label)


func _create_character_button(character: Character, front_row: bool) -> Button:
	var btn := Button.new()
	var row_marker := "[F]" if front_row else "[B]"
	var _status := ""
	if character.is_dead:
		_status = " (DEAD)"
	btn.text = "%s %s - L%d %s" % [
		row_marker if GameState.party.get_member(character.id) else "",
		character.character_name,
		character.level,
		CharacterEnums.get_class_name(character.character_class)
	]
	btn.text = btn.text.strip_edges()
	btn.custom_minimum_size = Vector2(200, 30)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if character.is_dead:
		btn.modulate = Color(0.7, 0.3, 0.3)
	return btn


func _on_party_member_pressed(character: Character) -> void:
	GameState.party.remove_member(character.id)
	_refresh_lists()
	_setup_navigation()
	if party_buttons.is_empty():
		current_mode = Mode.ROSTER
	_update_mode_display()
	_update_info()


func _on_roster_character_pressed(character: Character) -> void:
	if GameState.party.is_full():
		return
	GameState.party.add_member(character)
	_refresh_lists()
	_setup_navigation()
	_update_mode_display()
	_update_info()


func _update_info() -> void:
	var character: Character = null

	match current_mode:
		Mode.PARTY:
			if party_nav and party_nav.items.size() > 0:
				var idx := party_nav.get_current_index()
				if idx >= 0 and idx < GameState.party.size():
					character = GameState.party.get_member_at(idx)
		Mode.ROSTER:
			if roster_nav and roster_nav.items.size() > 0:
				var idx := roster_nav.get_current_index()
				var available := GameState.roster.get_available(GameState.party)
				if idx >= 0 and idx < available.size():
					character = available[idx]
		Mode.REORDER:
			if reorder_index >= 0 and reorder_index < GameState.party.size():
				character = GameState.party.get_member_at(reorder_index)
				_show_reorder_info(character, reorder_index)
				return

	if character:
		_show_character_info(character)
	else:
		info_label.text = "Select a character to view details"


func _show_reorder_info(character: Character, slot_position: int) -> void:
	var row := "Front Row" if slot_position < 3 else "Back Row"
	var text := "[b]REORDERING: %s[/b]\n\n" % character.character_name
	text += "Current Position: %d (%s)\n\n" % [slot_position + 1, row]
	text += "[color=cyan]Formation Info:[/color]\n"
	text += "  Positions 1-3: Front Row (melee range)\n"
	text += "  Positions 4-6: Back Row (ranged/protected)\n\n"
	text += "[color=yellow]Use Up/Down to move this character.[/color]\n"
	text += "[color=yellow]Press Enter when done.[/color]"
	info_label.text = text


func _show_character_info(character: Character) -> void:
	var text := "[b]%s[/b]\n" % character.character_name
	text += "Level %d %s %s\n" % [
		character.level,
		CharacterEnums.get_race_name(character.race),
		CharacterEnums.get_class_name(character.character_class)
	]
	text += "Alignment: %s\n\n" % CharacterEnums.get_alignment_name(character.alignment)

	text += "[color=cyan]Stats:[/color]\n"
	text += "HP: %d/%d  MP: %d/%d\n" % [
		character.current_hp, character.max_hp,
		character.current_mp, character.max_mp
	]
	text += "STR: %d  INT: %d  PIE: %d\n" % [
		character.strength, character.intelligence, character.piety
	]
	text += "VIT: %d  AGI: %d  LCK: %d\n" % [
		character.vitality, character.agility, character.luck
	]
	text += "XP: %d" % character.experience
	if character.pending_level_up:
		text += " [color=yellow](Level up ready!)[/color]"
	text += "\n\n"

	text += "[color=cyan]Equipment:[/color]\n"
	text += _format_equipment(character)

	if character.max_spell_level > 0:
		text += "\n[color=cyan]Spell Book:[/color]\n"
		text += _format_spell_book(character)

	if character.is_dead:
		text += "\n[color=red]STATUS: DEAD[/color]"

	info_label.text = text


func _format_equipment(character: Character) -> String:
	var text := ""
	var slots: Array[Dictionary] = [
		{"type": Item.ItemType.WEAPON, "name": "Weapon"},
		{"type": Item.ItemType.ARMOR, "name": "Armor"},
		{"type": Item.ItemType.SHIELD, "name": "Shield"},
		{"type": Item.ItemType.HELMET, "name": "Helmet"},
		{"type": Item.ItemType.GLOVES, "name": "Gloves"},
		{"type": Item.ItemType.BOOTS, "name": "Boots"},
		{"type": Item.ItemType.ACCESSORY, "name": "Accessory"}
	]

	for slot_info in slots:
		var item: Item = character.get_equipped_item(slot_info["type"])
		var slot_name: String = slot_info["name"]
		if item:
			var item_name := item.get_display_name()
			if item.is_cursed and item.is_identified:
				text += "  %s: [color=red]%s[/color]\n" % [slot_name, item_name]
			else:
				text += "  %s: %s\n" % [slot_name, item_name]
		else:
			text += "  %s: [color=gray](empty)[/color]\n" % slot_name

	return text


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


func _on_back_pressed() -> void:
	SceneManager.go_to_town()
