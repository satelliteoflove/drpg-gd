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

var _scaffold: ScreenScaffold
var _nights_value: Label
var _cost_value: Label
var _rest_btn: Button
var _info_label: RichTextLabel
var _message_label: Label
var _party_list: VBoxContainer


func _ready() -> void:
	_build_ui()
	selected_days = _calculate_default_days()
	_refresh_display()
	_rest_btn.grab_focus()


# --- Construction -----------------------------------------------------------

func _build_ui() -> void:
	_scaffold = ScreenScaffold.create({
		"title": "INN",
		"hint": "▲ / ▼   Nights      ·      Enter   Rest      ·      Esc   Back",
	})
	add_child(_scaffold)
	_scaffold.back_pressed.connect(_on_back_pressed)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	_scaffold.body.add_child(hbox)

	hbox.add_child(_build_left_panel())
	hbox.add_child(_build_right_panel())


func _build_left_panel() -> Control:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(400, 0)
	left.add_theme_constant_override("separation", 12)

	# Rest control card.
	var rest_panel := PanelContainer.new()
	left.add_child(rest_panel)

	var rest_margin := MarginContainer.new()
	rest_margin.add_theme_constant_override("margin_left", 20)
	rest_margin.add_theme_constant_override("margin_right", 20)
	rest_margin.add_theme_constant_override("margin_top", 18)
	rest_margin.add_theme_constant_override("margin_bottom", 18)
	rest_panel.add_child(rest_margin)

	var rest_col := VBoxContainer.new()
	rest_col.add_theme_constant_override("separation", 10)
	rest_col.alignment = BoxContainer.ALIGNMENT_CENTER
	rest_margin.add_child(rest_col)

	var header := Label.new()
	header.theme_type_variation = &"SubheaderLabel"
	header.text = "REST AT THE INN"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rest_col.add_child(header)

	# Prominent nights readout.
	_nights_value = Label.new()
	_nights_value.theme_type_variation = &"TitleLabel"
	_nights_value.add_theme_font_size_override("font_size", 34)
	_nights_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rest_col.add_child(_nights_value)

	var adjust_hint := Label.new()
	adjust_hint.theme_type_variation = &"MutedLabel"
	adjust_hint.text = "‹ ▼   adjust nights   ▲ ›"
	adjust_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rest_col.add_child(adjust_hint)

	_cost_value = Label.new()
	_cost_value.add_theme_color_override("font_color", UIColors.GOLD)
	_cost_value.add_theme_font_size_override("font_size", 17)
	_cost_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rest_col.add_child(_cost_value)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	rest_col.add_child(gap)

	_rest_btn = Button.new()
	_rest_btn.theme_type_variation = &"PrimaryButton"
	_rest_btn.text = "Rest"
	_rest_btn.custom_minimum_size = Vector2(0, 44)
	_rest_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rest_btn.pressed.connect(_on_rest_selected)
	rest_col.add_child(_rest_btn)

	# Details + result message.
	var info_panel := PanelContainer.new()
	info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(info_panel)

	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 14)
	info_margin.add_theme_constant_override("margin_right", 14)
	info_margin.add_theme_constant_override("margin_top", 12)
	info_margin.add_theme_constant_override("margin_bottom", 12)
	info_panel.add_child(info_margin)

	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = true
	_info_label.scroll_active = false
	info_margin.add_child(_info_label)

	_message_label = Label.new()
	_message_label.theme_type_variation = &"MutedLabel"
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_message_label)

	return left


func _build_right_panel() -> Control:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)

	var header := Label.new()
	header.theme_type_variation = &"SubheaderLabel"
	header.text = "PARTY"
	right.add_child(header)

	var party_panel := PanelContainer.new()
	party_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(party_panel)

	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	party_panel.add_child(scroll)

	_party_list = VBoxContainer.new()
	_party_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_party_list)

	return right


# --- Display ----------------------------------------------------------------

func _refresh_display() -> void:
	var living := _get_living_party_count()
	_nights_value.text = "%d night%s" % [selected_days, "s" if selected_days != 1 else ""]
	_cost_value.text = "%d gold" % _get_rest_cost()
	_rest_btn.disabled = living == 0

	_update_party_display()
	_update_info()
	_scaffold.refresh_date()

	if GameState.party.is_empty():
		_message_label.text = "No party members to rest."
	elif living == 0:
		_message_label.text = "All party members are slain. Visit the Temple."
	else:
		_message_label.text = ""


func _update_party_display() -> void:
	for child in _party_list.get_children():
		child.queue_free()

	if GameState.party.is_empty():
		var label := Label.new()
		label.theme_type_variation = &"MutedLabel"
		label.text = "(No party members)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_party_list.add_child(label)
		return

	var members := GameState.party.get_members()
	for i in members.size():
		_party_list.add_child(PartyMemberCard.create(members[i], {"index": i}))


func _update_info() -> void:
	if GameState.party.is_empty() or _get_living_party_count() == 0:
		_info_label.text = ""
		return

	var party_level := GameState.party.get_highest_level()
	var from_date := GameCalendar.get_date(GameState.game_day)
	var to_date := GameCalendar.get_date(GameState.game_day + selected_days)

	var text := "[color=#b9b4ae]Restores %d%% of max HP and MP each night, and cures Poison, Sleep, Confusion, Silence, and Fear.[/color]\n\n" % int(HP_RECOVERY_PER_DAY * 100)
	text += "[color=#8da0c8]Day %d → Day %d[/color]   ·   %d gold per night\n" % [
		from_date["day"], to_date["day"], party_level * GOLD_PER_LEVEL_PER_DAY]

	if _has_aging_warning():
		text += "\n[color=orange]⚠ Aging characters in the party — time passes for everyone.[/color]"

	_info_label.text = text


func _has_aging_warning() -> bool:
	for member in GameState.party.get_members():
		if member.is_dead:
			continue
		var phase: CharacterEnums.LifePhase = member.get_life_phase()
		if phase == CharacterEnums.LifePhase.DECLINE or phase == CharacterEnums.LifePhase.FRAGILE:
			return true
	return false


# --- Rest mechanics (unchanged behaviour) -----------------------------------

func _calculate_default_days() -> int:
	var max_needed := 1
	for member in GameState.party.get_members():
		if member.is_dead:
			continue
		if member.max_hp > 0:
			var hp_missing: float = float(member.max_hp - member.current_hp) / float(member.max_hp)
			max_needed = maxi(max_needed, ceili(hp_missing / HP_RECOVERY_PER_DAY))
		if member.max_mp > 0:
			var mp_missing: float = float(member.max_mp - member.current_mp) / float(member.max_mp)
			max_needed = maxi(max_needed, ceili(mp_missing / MP_RECOVERY_PER_DAY))
	return clampi(max_needed, 1, MAX_REST_DAYS)


func _get_living_party_count() -> int:
	var count := 0
	for member in GameState.party.get_members():
		if not member.is_dead:
			count += 1
	return count


func _get_rest_cost() -> int:
	return GameState.party.get_highest_level() * GOLD_PER_LEVEL_PER_DAY * selected_days


func _on_days_plus() -> void:
	if selected_days < MAX_REST_DAYS:
		selected_days += 1
		_refresh_display()


func _on_days_minus() -> void:
	if selected_days > 1:
		selected_days -= 1
		_refresh_display()


func _on_rest_selected() -> void:
	var total_cost := _get_rest_cost()
	if not GameState.party.spend_gold(total_cost):
		_message_label.text = "Not enough gold!"
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

	var result_text := "Rested %d night%s — restored %d HP and %d MP." % [
		selected_days, "s" if selected_days != 1 else "", total_hp, total_mp]
	if cured_count > 0:
		result_text += " Cured %d condition%s." % [cured_count, "s" if cured_count != 1 else ""]

	selected_days = _calculate_default_days()
	_refresh_display()

	if not old_age_deaths.is_empty():
		_show_old_age_deaths(old_age_deaths)
	elif not level_up_results.is_empty():
		_show_level_up_results(level_up_results)
	else:
		_message_label.text = result_text


func _process_level_ups(member: Character) -> Dictionary:
	if not member.pending_level_up:
		return {}

	var old_level := member.level
	var old_hp := member.max_hp
	var old_mp := member.max_mp
	var old_stats := {
		"strength": member.strength, "intelligence": member.intelligence,
		"piety": member.piety, "vitality": member.vitality,
		"agility": member.agility, "luck": member.luck
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
	for key in [["strength", "STR"], ["intelligence", "INT"], ["piety", "PIE"],
			["vitality", "VIT"], ["agility", "AGI"], ["luck", "LCK"]]:
		var diff: int = member.get(key[0]) - old_stats[key[0]]
		if diff > 0:
			stat_gains.append("+%d %s" % [diff, key[1]])

	return {
		"name": member.character_name, "new_level": member.level,
		"hp_gain": member.max_hp - old_hp, "mp_gain": member.max_mp - old_mp,
		"stat_gains": stat_gains
	}


func _show_old_age_deaths(names: Array[String]) -> void:
	var text := "[b]Passage of Time[/b]\n\n"
	for char_name in names:
		text += "[color=gray]%s has passed away of old age.[/color]\n" % char_name
	_info_label.text = text
	_message_label.text = "The passage of time claims all."


func _show_level_up_results(results: Array[Dictionary]) -> void:
	var text := "[b][color=#debc78]LEVEL UP![/color][/b]\n\n"
	for result in results:
		text += "[b]%s[/b] reached Level %d!\n" % [result["name"], result["new_level"]]
		text += "  HP +%d, MP +%d\n" % [result["hp_gain"], result["mp_gain"]]
		var stat_gains: Array = result["stat_gains"]
		if not stat_gains.is_empty():
			text += "  %s\n" % ", ".join(stat_gains)
		text += "\n"
	_info_label.text = text
	_message_label.text = "Your party has grown stronger!"


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_up"):
		_on_days_plus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_down"):
		_on_days_minus()
		get_viewport().set_input_as_handled()


func _on_back_pressed() -> void:
	SceneManager.go_to_town()
