extends Control

enum Step { RACE, STATS, CLASS, ALIGNMENT, GENDER, NAME, CONFIRM }

const STAT_NAMES: Array[String] = ["strength", "intelligence", "piety", "vitality", "agility", "luck"]
const STAT_LABELS: Array[String] = ["STR", "INT", "PIE", "VIT", "AGI", "LCK"]
const BASE_BONUS_POINTS: int = 9
const MAX_AGING_TRADE: int = 3

var current_step: Step = Step.RACE
var selected_race: CharacterEnums.Race = CharacterEnums.Race.HUMAN
var selected_class: CharacterEnums.CharacterClass = CharacterEnums.CharacterClass.FIGHTER
var selected_alignment: CharacterEnums.Alignment = CharacterEnums.Alignment.NEUTRAL
var selected_gender: CharacterEnums.Gender = CharacterEnums.Gender.MALE
var character_name: String = ""
var rolled_stats: Dictionary = {}
var bonus_points: int = 0
var bonus_remaining: int = 0
var stat_bonus_spent: Dictionary = {}
var stat_value_labels: Dictionary = {}
var aging_years_spent: int = 0

@onready var step_label: Label = $VBoxContainer/StepLabel
@onready var content_panel: PanelContainer = $VBoxContainer/ContentPanel
@onready var content_container: VBoxContainer = $VBoxContainer/ContentPanel/ContentContainer
@onready var nav_container: HBoxContainer = $VBoxContainer/NavContainer
@onready var back_button: Button = $VBoxContainer/NavContainer/BackButton
@onready var next_button: Button = $VBoxContainer/NavContainer/NextButton
@onready var cancel_button: Button = $VBoxContainer/NavContainer/CancelButton

var bonus_label: Label = null
var stat_minus_buttons: Dictionary = {}
var stat_plus_buttons: Dictionary = {}
var aging_label: Label = null
var aging_minus_btn: Button = null
var aging_plus_btn: Button = null


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	next_button.pressed.connect(_on_next_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	_show_step()


func _unhandled_input(event: InputEvent) -> void:
	if current_step == Step.NAME:
		return

	if event.is_action_pressed("menu_cancel"):
		if current_step == Step.RACE:
			_on_cancel_pressed()
		else:
			_on_back_pressed()
	elif event.is_action_pressed("menu_confirm"):
		_on_next_pressed()


func _show_step() -> void:
	_clear_content()
	_update_nav_buttons()

	match current_step:
		Step.RACE:
			_show_race_step()
		Step.STATS:
			_show_stats_step()
		Step.CLASS:
			_show_class_step()
		Step.ALIGNMENT:
			_show_alignment_step()
		Step.GENDER:
			_show_gender_step()
		Step.NAME:
			_show_name_step()
		Step.CONFIRM:
			_show_confirm_step()


func _clear_content() -> void:
	for child in content_container.get_children():
		child.queue_free()
	stat_value_labels.clear()
	stat_minus_buttons.clear()
	stat_plus_buttons.clear()
	bonus_label = null
	aging_label = null
	aging_minus_btn = null
	aging_plus_btn = null


func _update_nav_buttons() -> void:
	back_button.visible = current_step != Step.RACE
	cancel_button.visible = true
	if current_step == Step.CONFIRM:
		next_button.text = "Create"
	else:
		next_button.text = "Next"


func _show_race_step() -> void:
	step_label.text = "Step 1: Choose Race"

	var grid := GridContainer.new()
	grid.columns = 3
	content_container.add_child(grid)

	for race_id: int in CharacterEnums.Race.values():
		var race: CharacterEnums.Race = race_id as CharacterEnums.Race
		var btn := Button.new()
		btn.text = CharacterEnums.get_race_name(race)
		btn.custom_minimum_size = Vector2(120, 40)
		btn.toggle_mode = true
		btn.button_pressed = (race == selected_race)
		btn.pressed.connect(_on_race_selected.bind(race))
		grid.add_child(btn)

	_add_race_info()


func _add_race_info() -> void:
	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.custom_minimum_size = Vector2(0, 100)

	var ranges: Dictionary = CharacterEnums.RACE_STAT_RANGES.get(selected_race, {})
	var base_age: int = CharacterEnums.get_base_age(selected_race)
	var max_age: int = CharacterEnums.get_max_age(selected_race)
	var career: int = CharacterEnums.get_career_years(selected_race)
	var text := "[b]%s[/b]\n" % CharacterEnums.get_race_name(selected_race)
	text += "STR: %d-%d  INT: %d-%d  PIE: %d-%d\n" % [
		ranges.get("strength", Vector2i(8,18)).x, ranges.get("strength", Vector2i(8,18)).y,
		ranges.get("intelligence", Vector2i(8,18)).x, ranges.get("intelligence", Vector2i(8,18)).y,
		ranges.get("piety", Vector2i(8,18)).x, ranges.get("piety", Vector2i(8,18)).y
	]
	text += "VIT: %d-%d  AGI: %d-%d  LCK: %d-%d\n" % [
		ranges.get("vitality", Vector2i(8,18)).x, ranges.get("vitality", Vector2i(8,18)).y,
		ranges.get("agility", Vector2i(8,18)).x, ranges.get("agility", Vector2i(8,18)).y,
		ranges.get("luck", Vector2i(8,18)).x, ranges.get("luck", Vector2i(8,18)).y
	]
	text += "Lifespan: %d-%d years (Career: %d years)" % [base_age, max_age, career]
	info.text = text
	content_container.add_child(info)


func _on_race_selected(race: CharacterEnums.Race) -> void:
	selected_race = race
	rolled_stats = {}
	bonus_points = 0
	bonus_remaining = 0
	stat_bonus_spent.clear()
	aging_years_spent = 0
	_show_step()


func _count_available_classes(race: CharacterEnums.Race, bp: int) -> int:
	var ranges: Dictionary = CharacterEnums.RACE_STAT_RANGES.get(race, {})
	var count := 0

	for class_id: int in CharacterEnums.CharacterClass.values():
		var char_class: CharacterEnums.CharacterClass = class_id as CharacterEnums.CharacterClass
		var reqs: Dictionary = ClassData.get_requirements(char_class)

		if reqs.is_empty():
			count += 1
			continue

		var bp_needed := 0
		var possible := true
		for stat_name: String in reqs:
			var range_vec: Vector2i = ranges.get(stat_name, Vector2i(8, 18))
			var deficit: int = reqs[stat_name] - range_vec.x
			if deficit > 0:
				bp_needed += deficit
			if reqs[stat_name] > range_vec.y:
				possible = false
				break

		if possible and bp_needed <= bp:
			count += 1

	return count


func _init_stats_for_race() -> void:
	var ranges: Dictionary = CharacterEnums.RACE_STAT_RANGES.get(selected_race, {})
	rolled_stats.clear()
	stat_bonus_spent.clear()
	for stat_name in STAT_NAMES:
		var range_vec: Vector2i = ranges.get(stat_name, Vector2i(8, 18))
		rolled_stats[stat_name] = range_vec.x
		stat_bonus_spent[stat_name] = 0


func _show_stats_step() -> void:
	step_label.text = "Step 2: Distribute Bonus Points"

	if rolled_stats.is_empty():
		_init_stats_for_race()
		bonus_points = BASE_BONUS_POINTS + aging_years_spent
		bonus_remaining = bonus_points

	var ranges: Dictionary = CharacterEnums.RACE_STAT_RANGES.get(selected_race, {})

	bonus_label = Label.new()
	bonus_label.text = "Remaining: %d" % bonus_remaining
	bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_label.add_theme_font_size_override("font_size", 18)
	content_container.add_child(bonus_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	content_container.add_child(spacer)

	for i in range(STAT_NAMES.size()):
		var stat_name: String = STAT_NAMES[i]
		var stat_label_text: String = STAT_LABELS[i]
		var range_vec: Vector2i = ranges.get(stat_name, Vector2i(8, 18))
		var current_val: int = rolled_stats[stat_name]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER

		var name_lbl := Label.new()
		name_lbl.text = stat_label_text
		name_lbl.custom_minimum_size = Vector2(40, 0)
		row.add_child(name_lbl)

		var minus_btn := Button.new()
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(36, 36)
		minus_btn.disabled = (stat_bonus_spent[stat_name] <= 0)
		minus_btn.pressed.connect(_on_stat_minus.bind(stat_name))
		row.add_child(minus_btn)
		stat_minus_buttons[stat_name] = minus_btn

		var val_lbl := Label.new()
		val_lbl.text = str(current_val)
		val_lbl.custom_minimum_size = Vector2(30, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(val_lbl)
		stat_value_labels[stat_name] = val_lbl

		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(36, 36)
		plus_btn.disabled = (bonus_remaining <= 0 or current_val >= range_vec.y)
		plus_btn.pressed.connect(_on_stat_plus.bind(stat_name))
		row.add_child(plus_btn)
		stat_plus_buttons[stat_name] = plus_btn

		var range_lbl := Label.new()
		range_lbl.text = "(%d-%d)" % [range_vec.x, range_vec.y]
		range_lbl.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
		row.add_child(range_lbl)

		content_container.add_child(row)

	var total := 0
	for stat_name in STAT_NAMES:
		total += rolled_stats[stat_name]
	var total_label := Label.new()
	total_label.text = "Total: %d" % total
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(total_label)

	var aging_spacer := Control.new()
	aging_spacer.custom_minimum_size = Vector2(0, 8)
	content_container.add_child(aging_spacer)

	var aging_row := HBoxContainer.new()
	aging_row.add_theme_constant_override("separation", 8)
	aging_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var aging_title := Label.new()
	aging_title.text = "Trade Age:"
	aging_row.add_child(aging_title)

	aging_minus_btn = Button.new()
	aging_minus_btn.text = "-"
	aging_minus_btn.custom_minimum_size = Vector2(36, 36)
	aging_minus_btn.disabled = (aging_years_spent <= 0)
	aging_minus_btn.pressed.connect(_on_aging_minus)
	aging_row.add_child(aging_minus_btn)

	aging_label = Label.new()
	aging_label.text = "+%d yr" % aging_years_spent
	aging_label.custom_minimum_size = Vector2(50, 0)
	aging_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aging_row.add_child(aging_label)

	aging_plus_btn = Button.new()
	aging_plus_btn.text = "+"
	aging_plus_btn.custom_minimum_size = Vector2(36, 36)
	aging_plus_btn.disabled = (aging_years_spent >= MAX_AGING_TRADE)
	aging_plus_btn.pressed.connect(_on_aging_plus)
	aging_row.add_child(aging_plus_btn)

	var base_age: int = CharacterEnums.get_base_age(selected_race)
	var preview_age: int = base_age + aging_years_spent
	var preview_days: int = preview_age * CharacterEnums.DAYS_PER_YEAR
	var preview_phase: String = CharacterEnums.get_life_phase_name(CharacterEnums.get_life_phase(selected_race, preview_days))
	var age_preview := Label.new()
	age_preview.text = "(Age: %d, %s)" % [preview_age, preview_phase]
	age_preview.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	aging_row.add_child(age_preview)

	content_container.add_child(aging_row)

	var aging_info := Label.new()
	aging_info.text = "+1 bonus point per year traded"
	aging_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aging_info.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	content_container.add_child(aging_info)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 8)

	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.custom_minimum_size = Vector2(80, 40)
	reset_btn.pressed.connect(_on_reset_pressed)
	btn_row.add_child(reset_btn)

	content_container.add_child(btn_row)


func _on_aging_plus() -> void:
	if aging_years_spent >= MAX_AGING_TRADE:
		return
	aging_years_spent += 1
	bonus_points = BASE_BONUS_POINTS + aging_years_spent
	bonus_remaining += 1
	_refresh_stats_display()
	_show_step()


func _on_aging_minus() -> void:
	if aging_years_spent <= 0:
		return
	if bonus_remaining <= 0:
		return
	aging_years_spent -= 1
	bonus_points = BASE_BONUS_POINTS + aging_years_spent
	bonus_remaining -= 1
	_refresh_stats_display()
	_show_step()


func _on_stat_plus(stat_name: String) -> void:
	if bonus_remaining <= 0:
		return
	var ranges: Dictionary = CharacterEnums.RACE_STAT_RANGES.get(selected_race, {})
	var range_vec: Vector2i = ranges.get(stat_name, Vector2i(8, 18))
	if rolled_stats[stat_name] >= range_vec.y:
		return
	rolled_stats[stat_name] += 1
	stat_bonus_spent[stat_name] += 1
	bonus_remaining -= 1
	_refresh_stats_display()


func _on_stat_minus(stat_name: String) -> void:
	if stat_bonus_spent[stat_name] <= 0:
		return
	rolled_stats[stat_name] -= 1
	stat_bonus_spent[stat_name] -= 1
	bonus_remaining += 1
	_refresh_stats_display()


func _refresh_stats_display() -> void:
	var ranges: Dictionary = CharacterEnums.RACE_STAT_RANGES.get(selected_race, {})

	if bonus_label:
		bonus_label.text = "Remaining: %d" % bonus_remaining

	for stat_name in STAT_NAMES:
		if stat_value_labels.has(stat_name):
			stat_value_labels[stat_name].text = str(rolled_stats[stat_name])
		if stat_minus_buttons.has(stat_name):
			stat_minus_buttons[stat_name].disabled = (stat_bonus_spent[stat_name] <= 0)
		if stat_plus_buttons.has(stat_name):
			var range_vec: Vector2i = ranges.get(stat_name, Vector2i(8, 18))
			stat_plus_buttons[stat_name].disabled = (bonus_remaining <= 0 or rolled_stats[stat_name] >= range_vec.y)


func _on_reset_pressed() -> void:
	var ranges: Dictionary = CharacterEnums.RACE_STAT_RANGES.get(selected_race, {})
	for stat_name in STAT_NAMES:
		var range_vec: Vector2i = ranges.get(stat_name, Vector2i(8, 18))
		rolled_stats[stat_name] = range_vec.x
		stat_bonus_spent[stat_name] = 0
	aging_years_spent = 0
	bonus_points = BASE_BONUS_POINTS
	bonus_remaining = bonus_points
	_show_step()


func _show_class_step() -> void:
	step_label.text = "Step 3: Choose Class"

	var grid := GridContainer.new()
	grid.columns = 3
	content_container.add_child(grid)

	for class_id: int in CharacterEnums.CharacterClass.values():
		var char_class: CharacterEnums.CharacterClass = class_id as CharacterEnums.CharacterClass
		var btn := Button.new()
		btn.text = CharacterEnums.get_class_name(char_class)
		btn.custom_minimum_size = Vector2(120, 40)

		var meets_reqs := ClassData.meets_requirements(char_class, rolled_stats)
		btn.disabled = not meets_reqs
		btn.toggle_mode = true
		btn.button_pressed = (char_class == selected_class and meets_reqs)

		if meets_reqs:
			btn.pressed.connect(_on_class_selected.bind(char_class))

		grid.add_child(btn)

	_add_class_info()


func _add_class_info() -> void:
	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.custom_minimum_size = Vector2(0, 80)

	var data: Dictionary = ClassData.get_class_data(selected_class)
	var reqs: Dictionary = ClassData.get_requirements(selected_class)

	var text := "[b]%s[/b]\n" % CharacterEnums.get_class_name(selected_class)
	text += "HP Base: %d  MP Base: %d\n" % [data.get("hp_base", 0), data.get("mp_base", 0)]

	if not reqs.is_empty():
		text += "Requires: "
		var req_parts: Array[String] = []
		for stat: String in reqs:
			req_parts.append("%s %d" % [stat.capitalize(), reqs[stat]])
		text += ", ".join(req_parts)

	info.text = text
	content_container.add_child(info)


func _on_class_selected(char_class: CharacterEnums.CharacterClass) -> void:
	selected_class = char_class
	_show_step()


func _show_alignment_step() -> void:
	step_label.text = "Step 4: Choose Alignment"

	var vbox := VBoxContainer.new()
	content_container.add_child(vbox)

	for align_id: int in CharacterEnums.Alignment.values():
		var alignment: CharacterEnums.Alignment = align_id as CharacterEnums.Alignment
		var btn := Button.new()
		btn.text = CharacterEnums.get_alignment_name(alignment)
		btn.custom_minimum_size = Vector2(150, 40)
		btn.toggle_mode = true
		btn.button_pressed = (alignment == selected_alignment)
		btn.pressed.connect(_on_alignment_selected.bind(alignment))
		vbox.add_child(btn)


func _on_alignment_selected(alignment: CharacterEnums.Alignment) -> void:
	selected_alignment = alignment
	_show_step()


func _show_gender_step() -> void:
	step_label.text = "Step 5: Choose Gender"

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_container.add_child(hbox)

	for gender_id: int in CharacterEnums.Gender.values():
		var gender: CharacterEnums.Gender = gender_id as CharacterEnums.Gender
		var btn := Button.new()
		btn.text = "Male" if gender == CharacterEnums.Gender.MALE else "Female"
		btn.custom_minimum_size = Vector2(120, 40)
		btn.toggle_mode = true
		btn.button_pressed = (gender == selected_gender)
		btn.pressed.connect(_on_gender_selected.bind(gender))
		hbox.add_child(btn)


func _on_gender_selected(gender: CharacterEnums.Gender) -> void:
	selected_gender = gender
	_show_step()


func _show_name_step() -> void:
	step_label.text = "Step 6: Enter Name"

	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Character Name"
	name_edit.text = character_name
	name_edit.custom_minimum_size = Vector2(200, 40)
	name_edit.max_length = 20
	name_edit.text_changed.connect(_on_name_changed)
	name_edit.text_submitted.connect(_on_name_submitted)
	content_container.add_child(name_edit)
	name_edit.grab_focus()


func _on_name_submitted(_text: String) -> void:
	_on_next_pressed()


func _on_name_changed(new_name: String) -> void:
	character_name = new_name.strip_edges()


func _show_confirm_step() -> void:
	step_label.text = "Step 7: Confirm Character"

	var base_age: int = CharacterEnums.get_base_age(selected_race)
	var final_age: int = base_age + aging_years_spent
	var preview_days: int = final_age * CharacterEnums.DAYS_PER_YEAR
	var phase_name: String = CharacterEnums.get_life_phase_name(CharacterEnums.get_life_phase(selected_race, preview_days))

	var summary := Label.new()
	summary.text = "Name: %s\nRace: %s\nClass: %s\nAlignment: %s\nGender: %s\nAge: %d (%s)\nLevel: 1\n\nStrength: %d\nIntelligence: %d\nPiety: %d\nVitality: %d\nAgility: %d\nLuck: %d" % [
		character_name if character_name else "(unnamed)",
		CharacterEnums.get_race_name(selected_race),
		CharacterEnums.get_class_name(selected_class),
		CharacterEnums.get_alignment_name(selected_alignment),
		"Male" if selected_gender == CharacterEnums.Gender.MALE else "Female",
		final_age, phase_name,
		rolled_stats.get("strength", 10),
		rolled_stats.get("intelligence", 10),
		rolled_stats.get("piety", 10),
		rolled_stats.get("vitality", 10),
		rolled_stats.get("agility", 10),
		rolled_stats.get("luck", 10)
	]
	content_container.add_child(summary)


func _on_back_pressed() -> void:
	if current_step == Step.STATS:
		rolled_stats = {}
		bonus_points = 0
		bonus_remaining = 0
		stat_bonus_spent.clear()

	if current_step > Step.RACE:
		current_step = (current_step - 1) as Step
		_show_step()


func _on_next_pressed() -> void:
	if current_step == Step.CONFIRM:
		_create_character()
		return

	if current_step == Step.NAME and character_name.is_empty():
		return

	if current_step == Step.CLASS:
		if not ClassData.meets_requirements(selected_class, rolled_stats):
			return

	if current_step < Step.CONFIRM:
		current_step = (current_step + 1) as Step
		_show_step()


func _create_character() -> void:
	if character_name.is_empty():
		character_name = "Unnamed"

	var new_char := Character.create_new(
		character_name,
		selected_race,
		selected_class,
		selected_alignment,
		selected_gender,
		rolled_stats
	)

	if aging_years_spent > 0:
		new_char.age_days += aging_years_spent * CharacterEnums.DAYS_PER_YEAR

	_finalize_character(new_char)


func _finalize_character(new_char: Character) -> void:
	if GameState.roster.add_character(new_char):
		print("Created character: ", new_char.character_name)
		SceneManager.go_to_guild_hall()
	else:
		push_error("Failed to add character to roster (roster full?)")


func _on_cancel_pressed() -> void:
	SceneManager.go_to_guild_hall()
