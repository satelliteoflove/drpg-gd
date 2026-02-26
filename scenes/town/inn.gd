extends Control

const GOLD_PER_LEVEL := 10

const MINOR_STATUSES: Array[CharacterEnums.StatusEffect] = [
	CharacterEnums.StatusEffect.POISONED,
	CharacterEnums.StatusEffect.ASLEEP,
	CharacterEnums.StatusEffect.CONFUSED,
	CharacterEnums.StatusEffect.SILENCED,
	CharacterEnums.StatusEffect.AFRAID
]

var nav: MenuNavigator = null
var rest_buttons: Array[Button] = []

@onready var title_label: Label = $MainHBox/LeftPanel/Header/TitleLabel
@onready var gold_label: Label = $MainHBox/LeftPanel/Header/GoldLabel
@onready var options_panel: PanelContainer = $MainHBox/LeftPanel/OptionsPanel
@onready var options_list: VBoxContainer = $MainHBox/LeftPanel/OptionsPanel/ScrollContainer/OptionsList
@onready var message_label: Label = $MainHBox/LeftPanel/MessageLabel
@onready var help_label: Label = $MainHBox/LeftPanel/HelpLabel
@onready var back_button: Button = $MainHBox/LeftPanel/BackButton

@onready var info_panel: PanelContainer = $MainHBox/RightPanel/InfoPanel
@onready var info_label: RichTextLabel = $MainHBox/RightPanel/InfoPanel/InfoLabel
@onready var party_label: Label = $MainHBox/RightPanel/PartyLabel
@onready var party_panel: PanelContainer = $MainHBox/RightPanel/PartyPanel
@onready var party_list: VBoxContainer = $MainHBox/RightPanel/PartyPanel/ScrollContainer/PartyList


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_refresh_display()


func _refresh_display() -> void:
	gold_label.text = "Gold: %d" % GameState.party.gold
	_populate_rest_options()
	_update_party_display()
	_update_info()
	_update_help()

	if GameState.party.is_empty():
		message_label.text = "No party members to rest."
	else:
		message_label.text = "Choose a rest option for your party."


func _populate_rest_options() -> void:
	for child in options_list.get_children():
		child.queue_free()
	rest_buttons.clear()

	if GameState.party.is_empty():
		var label := Label.new()
		label.text = "(No party members)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		options_list.add_child(label)
		return

	if _get_living_party_count() == 0:
		var label := Label.new()
		label.text = "(All party members are dead)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		options_list.add_child(label)
		return

	var total_cost := _get_rest_cost()
	var btn := Button.new()
	btn.text = "Rest - %d gold" % total_cost
	btn.custom_minimum_size = Vector2(350, 36)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_rest_selected)

	if not GameState.party.has_gold(total_cost):
		btn.disabled = true
		btn.modulate = Color(0.6, 0.6, 0.6)
		btn.tooltip_text = "Not enough gold"
	elif not _party_needs_rest():
		btn.disabled = true
		btn.modulate = Color(0.6, 0.6, 0.6)
		btn.tooltip_text = "Party is fully rested"

	options_list.add_child(btn)
	rest_buttons.append(btn)

	nav = MenuNavigator.new()
	if not rest_buttons.is_empty():
		nav.setup(rest_buttons, 0)
		nav.selection_changed.connect(_on_selection_changed)


func _get_living_party_count() -> int:
	var count := 0
	for member in GameState.party.get_members():
		if not member.is_dead:
			count += 1
	return count


func _get_rest_cost() -> int:
	return GameState.party.get_highest_level() * GOLD_PER_LEVEL


func _party_needs_rest() -> bool:
	for member in GameState.party.get_members():
		if member.is_dead:
			continue
		if member.current_hp < member.max_hp:
			return true
		if member.current_mp < member.max_mp:
			return true
		for status in MINOR_STATUSES:
			if member.has_status(status):
				return true
	return false


func _on_selection_changed(_index: int) -> void:
	_update_info()


func _update_info() -> void:
	if rest_buttons.is_empty():
		info_label.text = "Select rest to view details."
		return

	var total_cost := _get_rest_cost()
	var party_level := GameState.party.get_highest_level()

	var text := "[b]Rest[/b]\n"
	text += "Full restoration for the party.\n\n"
	text += "[color=yellow]Cost: %d gold (level %d x %d)[/color]\n\n" % [total_cost, party_level, GOLD_PER_LEVEL]

	text += "[color=cyan]Effects:[/color]\n"
	text += "  HP restored: 100%%\n"
	text += "  MP restored: 100%%\n"
	text += "  Cures: Poison, Sleep, Confusion, Silence, Fear\n"

	text += "\n[color=gray]Preview:[/color]\n"
	for member in GameState.party.get_members():
		if member.is_dead:
			continue
		var hp_gain := _calculate_hp_restore(member, 100)
		var mp_gain := _calculate_mp_restore(member, 100)
		var status_text := ""
		if _has_minor_status(member):
			status_text = " [cured]"
		text += "  %s: +%d HP, +%d MP%s\n" % [member.character_name, hp_gain, mp_gain, status_text]

	info_label.text = text


func _calculate_hp_restore(member: Character, percent: int) -> int:
	var restore_amount := member.max_hp * percent / 100
	return mini(restore_amount, member.max_hp - member.current_hp)


func _calculate_mp_restore(member: Character, percent: int) -> int:
	var restore_amount := member.max_mp * percent / 100
	return mini(restore_amount, member.max_mp - member.current_mp)


func _has_minor_status(member: Character) -> bool:
	for status in MINOR_STATUSES:
		if member.has_status(status):
			return true
	return false


func _update_party_display() -> void:
	for child in party_list.get_children():
		child.queue_free()

	if GameState.party.is_empty():
		var label := Label.new()
		label.text = "(No party members)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		party_list.add_child(label)
		return

	for member in GameState.party.get_members():
		var row := _create_party_row(member)
		party_list.add_child(row)


func _create_party_row(member: Character) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)

	var name_label := Label.new()
	name_label.text = member.character_name
	name_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(name_label)

	var hp_label := Label.new()
	hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if member.is_dead:
		hp_label.text = "[DEAD]"
		hp_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	else:
		var hp_percent := float(member.current_hp) / float(member.max_hp) * 100.0
		hp_label.text = "HP: %d/%d  MP: %d/%d" % [member.current_hp, member.max_hp, member.current_mp, member.max_mp]

		if hp_percent < 25:
			hp_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		elif hp_percent < 50:
			hp_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
		elif hp_percent < 100 or member.current_mp < member.max_mp:
			hp_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
		else:
			hp_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))

	row.add_child(hp_label)

	var status_label := Label.new()
	var statuses := _get_status_text(member)
	status_label.text = statuses
	if statuses != "":
		status_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	row.add_child(status_label)

	return row


func _get_status_text(member: Character) -> String:
	var parts: Array[String] = []
	for status in MINOR_STATUSES:
		if member.has_status(status):
			parts.append(CharacterEnums.get_status_name(status))
	return ", ".join(parts)


func _on_rest_selected() -> void:
	var total_cost := _get_rest_cost()

	if not GameState.party.spend_gold(total_cost):
		message_label.text = "Not enough gold!"
		return

	var total_hp := 0
	var total_mp := 0
	var cured_count := 0
	var level_up_results: Array[Dictionary] = []

	for member in GameState.party.get_members():
		if member.is_dead:
			continue

		total_hp += member.heal(member.max_hp)
		total_mp += member.restore_mp(member.max_mp)

		for status in MINOR_STATUSES:
			if member.has_status(status):
				member.remove_status(status)
				cured_count += 1

		var level_result := _process_level_ups(member)
		if not level_result.is_empty():
			level_up_results.append(level_result)

	var result_text := "Party rested! Restored %d HP, %d MP" % [total_hp, total_mp]
	if cured_count > 0:
		result_text += ", cured %d conditions" % cured_count
	result_text += ". Spent %d gold." % total_cost

	if not level_up_results.is_empty():
		_show_level_up_results(level_up_results)
	else:
		message_label.text = result_text

	_refresh_display()


func _process_level_ups(member: Character) -> Dictionary:
	if not member.pending_level_up:
		return {}

	var old_level := member.level
	var old_hp := member.max_hp
	var old_mp := member.max_mp
	var old_stats := {
		"strength": member.strength,
		"intelligence": member.intelligence,
		"piety": member.piety,
		"vitality": member.vitality,
		"agility": member.agility,
		"luck": member.luck
	}

	var levels_gained := 0
	while member.pending_level_up:
		if member.confirm_level_up():
			levels_gained += 1
		else:
			break

	if levels_gained == 0:
		return {}

	var stat_gains: Array[String] = []
	if member.strength > old_stats["strength"]:
		stat_gains.append("+%d STR" % (member.strength - old_stats["strength"]))
	if member.intelligence > old_stats["intelligence"]:
		stat_gains.append("+%d INT" % (member.intelligence - old_stats["intelligence"]))
	if member.piety > old_stats["piety"]:
		stat_gains.append("+%d PIE" % (member.piety - old_stats["piety"]))
	if member.vitality > old_stats["vitality"]:
		stat_gains.append("+%d VIT" % (member.vitality - old_stats["vitality"]))
	if member.agility > old_stats["agility"]:
		stat_gains.append("+%d AGI" % (member.agility - old_stats["agility"]))
	if member.luck > old_stats["luck"]:
		stat_gains.append("+%d LCK" % (member.luck - old_stats["luck"]))

	return {
		"name": member.character_name,
		"old_level": old_level,
		"new_level": member.level,
		"hp_gain": member.max_hp - old_hp,
		"mp_gain": member.max_mp - old_mp,
		"stat_gains": stat_gains
	}


func _show_level_up_results(results: Array[Dictionary]) -> void:
	var text := "[center][b]LEVEL UP![/b][/center]\n\n"

	for result in results:
		text += "[b]%s[/b] reached Level %d!\n" % [result["name"], result["new_level"]]
		text += "  HP +%d, MP +%d\n" % [result["hp_gain"], result["mp_gain"]]

		var stat_gains: Array = result["stat_gains"]
		if not stat_gains.is_empty():
			text += "  Stats: %s\n" % ", ".join(stat_gains)
		text += "\n"

	info_label.text = text
	message_label.text = "Your party has grown stronger!"


func _update_help() -> void:
	var v_nav := KeyBindingHelper.get_nav_help()
	var confirm := KeyBindingHelper.get_confirm_help()
	var cancel := KeyBindingHelper.get_cancel_help()
	help_label.text = "%s | %s: Rest | %s" % [v_nav, confirm.split(":")[0], cancel]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		_on_back_pressed()
		return

	if nav:
		nav.handle_input(event)


func _on_back_pressed() -> void:
	SceneManager.go_to_town()
