extends Control

const GOLD_PER_LEVEL_PER_DAY := 10
const HP_RECOVERY_PER_DAY := 0.25
const MP_RECOVERY_PER_DAY := 0.25
const MAX_REST_DAYS := 30

const MINOR_STATUSES: Array[CharacterEnums.StatusEffect] = [
	CharacterEnums.StatusEffect.POISONED,
	CharacterEnums.StatusEffect.ASLEEP,
	CharacterEnums.StatusEffect.CONFUSED,
	CharacterEnums.StatusEffect.SILENCED,
	CharacterEnums.StatusEffect.AFRAID
]

var selected_days: int = 1
var minus_btn: Button = null
var plus_btn: Button = null
var day_label: Label = null

@onready var title_label: Label = $MainHBox/LeftPanel/Header/TitleLabel
@onready var gold_label: Label = $MainHBox/LeftPanel/Header/GoldLabel
var _date_labels: Dictionary = {}
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
	_build_date_grid()
	selected_days = _calculate_default_days()
	_refresh_display()


func _build_date_grid() -> void:
	var header: HBoxContainer = title_label.get_parent()
	_date_labels = GameCalendar.create_date_grid(GameState.game_day)
	var grid: GridContainer = _date_labels["grid"]
	grid.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(grid)


func _refresh_display() -> void:
	gold_label.text = "Gold: %d" % GameState.party.gold
	_populate_rest_options()
	_update_party_display()
	_update_info()
	_update_help()

	if not _date_labels.is_empty():
		GameCalendar.update_date_labels(_date_labels, GameState.game_day)
	if GameState.party.is_empty():
		message_label.text = "No party members to rest."
	else:
		message_label.text = "Choose how many days to rest."


func _calculate_default_days() -> int:
	var max_needed := 1
	for member in GameState.party.get_members():
		if member.is_dead:
			continue
		if member.max_hp > 0:
			var hp_missing: float = float(member.max_hp - member.current_hp) / float(member.max_hp)
			var hp_days: int = ceili(hp_missing / HP_RECOVERY_PER_DAY)
			max_needed = maxi(max_needed, hp_days)
		if member.max_mp > 0:
			var mp_missing: float = float(member.max_mp - member.current_mp) / float(member.max_mp)
			var mp_days: int = ceili(mp_missing / MP_RECOVERY_PER_DAY)
			max_needed = maxi(max_needed, mp_days)
	return clampi(max_needed, 1, MAX_REST_DAYS)


func _populate_rest_options() -> void:
	for child in options_list.get_children():
		child.queue_free()
	minus_btn = null
	plus_btn = null
	day_label = null

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

	var day_col := VBoxContainer.new()
	day_col.alignment = BoxContainer.ALIGNMENT_CENTER
	day_col.add_theme_constant_override("separation", 2)
	day_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	plus_btn = Button.new()
	plus_btn.text = "▲"
	plus_btn.custom_minimum_size = Vector2(60, 32)
	plus_btn.focus_mode = Control.FOCUS_NONE
	plus_btn.pressed.connect(_on_days_plus)
	day_col.add_child(plus_btn)

	day_label = Label.new()
	day_label.text = "%d Day%s" % [selected_days, "s" if selected_days != 1 else ""]
	day_label.custom_minimum_size = Vector2(60, 0)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_col.add_child(day_label)

	minus_btn = Button.new()
	minus_btn.text = "▼"
	minus_btn.custom_minimum_size = Vector2(60, 32)
	minus_btn.focus_mode = Control.FOCUS_NONE
	minus_btn.pressed.connect(_on_days_minus)
	day_col.add_child(minus_btn)

	options_list.add_child(day_col)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	options_list.add_child(spacer)

	var rest_btn := Button.new()
	rest_btn.text = "Rest"
	rest_btn.custom_minimum_size = Vector2(120, 36)
	rest_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rest_btn.focus_mode = Control.FOCUS_NONE
	rest_btn.pressed.connect(_on_rest_selected)
	options_list.add_child(rest_btn)

	_update_day_buttons()


func _update_day_buttons() -> void:
	if minus_btn:
		minus_btn.disabled = (selected_days <= 1)
	if plus_btn:
		plus_btn.disabled = (selected_days >= MAX_REST_DAYS)
	if day_label:
		day_label.text = "%d Day%s" % [selected_days, "s" if selected_days != 1 else ""]


func _on_days_minus() -> void:
	if selected_days > 1:
		selected_days -= 1
		_refresh_display()


func _on_days_plus() -> void:
	if selected_days < MAX_REST_DAYS:
		selected_days += 1
		_refresh_display()


func _get_living_party_count() -> int:
	var count := 0
	for member in GameState.party.get_members():
		if not member.is_dead:
			count += 1
	return count


func _get_rest_cost() -> int:
	return GameState.party.get_highest_level() * GOLD_PER_LEVEL_PER_DAY * selected_days


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


func _update_info() -> void:
	if GameState.party.is_empty() or _get_living_party_count() == 0:
		info_label.text = ""
		return

	var total_cost := _get_rest_cost()
	var party_level := GameState.party.get_highest_level()

	var text := "[b]Rest - %d Day%s[/b]\n" % [selected_days, "s" if selected_days != 1 else ""]
	text += "[color=yellow]Cost: %d gold (%d/day x %d)[/color]\n" % [total_cost, party_level * GOLD_PER_LEVEL_PER_DAY, selected_days]
	var from_date := GameCalendar.get_date(GameState.game_day)
	var to_date := GameCalendar.get_date(GameState.game_day + selected_days)
	text += "[color=yellow]Day %d, Month %d, Year %d -> Day %d, Month %d, Year %d[/color]\n\n" % [
		from_date["day"], from_date["month"], from_date["year"],
		to_date["day"], to_date["month"], to_date["year"]]

	text += "Restores %d%% of max HP/MP per day\n" % int(HP_RECOVERY_PER_DAY * 100)
	if selected_days >= 1:
		text += "Cures: Poison, Sleep, Confusion, Silence, Fear\n"

	var has_aging_warning := false
	for member in GameState.party.get_members():
		if member.is_dead:
			continue
		var phase: CharacterEnums.LifePhase = member.get_life_phase()
		if phase == CharacterEnums.LifePhase.DECLINE or phase == CharacterEnums.LifePhase.FRAGILE:
			has_aging_warning = true
			break

	if has_aging_warning:
		text += "\n[color=orange]Warning: Aging characters in party![/color]\n"

	info_label.text = text


func _calculate_hp_restore(member: Character, days: int) -> int:
	var total := 0
	var current := member.current_hp
	for i in range(days):
		var gain: int = maxi(1, roundi(member.max_hp * HP_RECOVERY_PER_DAY))
		gain = mini(gain, member.max_hp - current)
		current += gain
		total += gain
	return total


func _calculate_mp_restore(member: Character, days: int) -> int:
	var total := 0
	var current := member.current_mp
	for i in range(days):
		var gain: int = maxi(1, roundi(member.max_mp * MP_RECOVERY_PER_DAY)) if member.max_mp > 0 else 0
		gain = mini(gain, member.max_mp - current)
		current += gain
		total += gain
	return total


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
		hp_label.add_theme_color_override("font_color", UIColors.DANGER)
	else:
		var hp_percent := float(member.current_hp) / float(member.max_hp) * 100.0
		hp_label.text = "HP: %d/%d  MP: %d/%d" % [member.current_hp, member.max_hp, member.current_mp, member.max_mp]

		if hp_percent < 25:
			hp_label.add_theme_color_override("font_color", UIColors.TEXT_DANGER)
		elif hp_percent < 50:
			hp_label.add_theme_color_override("font_color", UIColors.TEXT_WARNING)
		elif hp_percent < 100 or member.current_mp < member.max_mp:
			hp_label.add_theme_color_override("font_color", UIColors.TEXT_WARNING)
		else:
			hp_label.add_theme_color_override("font_color", UIColors.TEXT_HEALTHY)

	row.add_child(hp_label)

	var status_label := Label.new()
	var statuses := _get_status_text(member)
	status_label.text = statuses
	if statuses != "":
		status_label.add_theme_color_override("font_color", UIColors.TEXT_STATUS)
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
	var old_age_deaths: Array[String] = []

	for day in range(selected_days):
		GameState.advance_game_days(1)

		for member in GameState.party.get_members():
			if member.is_dead:
				continue
			var hp_gain: int = maxi(1, roundi(member.max_hp * HP_RECOVERY_PER_DAY))
			total_hp += member.heal(hp_gain)
			if member.max_mp > 0:
				var mp_gain: int = maxi(1, roundi(member.max_mp * MP_RECOVERY_PER_DAY))
				total_mp += member.restore_mp(mp_gain)

		if day == 0:
			for member in GameState.party.get_members():
				if member.is_dead:
					continue
				for status in MINOR_STATUSES:
					if member.has_status(status):
						member.remove_status(status)
						cured_count += 1

		for character in GameState.roster.get_all():
			if character.is_dead:
				continue
			if character.get_life_phase() == CharacterEnums.LifePhase.FRAGILE:
				if character.check_old_age_death():
					old_age_deaths.append(character.character_name)

	var level_up_results: Array[Dictionary] = []
	for member in GameState.party.get_members():
		if member.is_dead:
			continue
		var level_result := _process_level_ups(member)
		if not level_result.is_empty():
			level_up_results.append(level_result)

	var result_text := "Rested %d day%s. Restored %d HP, %d MP." % [selected_days, "s" if selected_days != 1 else "", total_hp, total_mp]
	if cured_count > 0:
		result_text += " Cured %d conditions." % cured_count
	result_text += " Spent %d gold." % total_cost

	if not old_age_deaths.is_empty():
		_show_old_age_deaths(old_age_deaths)
	elif not level_up_results.is_empty():
		_show_level_up_results(level_up_results)
	else:
		message_label.text = result_text

	_refresh_display()


func _show_old_age_deaths(names: Array[String]) -> void:
	var text := "[center][b]Passage of Time[/b][/center]\n\n"
	for char_name in names:
		text += "[color=gray]%s has passed away of old age.[/color]\n" % char_name
	text += "\n[color=gray]Their adventures have come to a peaceful end.[/color]"
	info_label.text = text
	message_label.text = "The passage of time claims all."


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
	var confirm := KeyBindingHelper.get_confirm_help()
	var cancel := KeyBindingHelper.get_cancel_help()
	help_label.text = "k/Up: +Day | j/Down: -Day | %s: Rest | %s" % [confirm.split(":")[0], cancel]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		_on_back_pressed()
		return

	if event.is_action_pressed("menu_up"):
		_on_days_plus()
		return
	if event.is_action_pressed("menu_down"):
		_on_days_minus()
		return

	if event.is_action_pressed("menu_confirm"):
		_on_rest_selected()


func _on_back_pressed() -> void:
	SceneManager.go_to_town()
