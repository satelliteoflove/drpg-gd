extends Control

const CharEnum = preload("res://resources/character_enums.gd")
const ClassDataRef = preload("res://resources/class_data.gd")

enum Step { RACE, STATS, CLASS, ALIGNMENT, GENDER, NAME, CONFIRM }

var current_step: Step = Step.RACE
var selected_race: CharEnum.Race = CharEnum.Race.HUMAN
var selected_class: CharEnum.CharacterClass = CharEnum.CharacterClass.FIGHTER
var selected_alignment: CharEnum.Alignment = CharEnum.Alignment.NEUTRAL
var selected_gender: CharEnum.Gender = CharEnum.Gender.MALE
var character_name: String = ""
var rolled_stats: Dictionary = {}

@onready var step_label: Label = $VBoxContainer/StepLabel
@onready var content_panel: PanelContainer = $VBoxContainer/ContentPanel
@onready var content_container: VBoxContainer = $VBoxContainer/ContentPanel/ContentContainer
@onready var nav_container: HBoxContainer = $VBoxContainer/NavContainer
@onready var back_button: Button = $VBoxContainer/NavContainer/BackButton
@onready var next_button: Button = $VBoxContainer/NavContainer/NextButton
@onready var cancel_button: Button = $VBoxContainer/NavContainer/CancelButton


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


func _update_nav_buttons() -> void:
	back_button.visible = current_step != Step.RACE
	next_button.text = "Create" if current_step == Step.CONFIRM else "Next"


func _show_race_step() -> void:
	step_label.text = "Step 1: Choose Race"

	var grid := GridContainer.new()
	grid.columns = 3
	content_container.add_child(grid)

	for race_id: int in CharEnum.Race.values():
		var race: CharEnum.Race = race_id as CharEnum.Race
		var btn := Button.new()
		btn.text = CharEnum.get_race_name(race)
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

	var ranges: Dictionary = CharEnum.RACE_STAT_RANGES.get(selected_race, {})
	var text := "[b]%s[/b]\n" % CharEnum.get_race_name(selected_race)
	text += "STR: %d-%d  INT: %d-%d  PIE: %d-%d\n" % [
		ranges.get("strength", Vector2i(8,18)).x, ranges.get("strength", Vector2i(8,18)).y,
		ranges.get("intelligence", Vector2i(8,18)).x, ranges.get("intelligence", Vector2i(8,18)).y,
		ranges.get("piety", Vector2i(8,18)).x, ranges.get("piety", Vector2i(8,18)).y
	]
	text += "VIT: %d-%d  AGI: %d-%d  LCK: %d-%d" % [
		ranges.get("vitality", Vector2i(8,18)).x, ranges.get("vitality", Vector2i(8,18)).y,
		ranges.get("agility", Vector2i(8,18)).x, ranges.get("agility", Vector2i(8,18)).y,
		ranges.get("luck", Vector2i(8,18)).x, ranges.get("luck", Vector2i(8,18)).y
	]
	info.text = text
	content_container.add_child(info)


func _on_race_selected(race: CharEnum.Race) -> void:
	selected_race = race
	rolled_stats = {}
	_show_step()


func _show_stats_step() -> void:
	step_label.text = "Step 2: Roll Stats"

	if rolled_stats.is_empty():
		_roll_stats()

	var stats_label := Label.new()
	stats_label.text = "Strength: %d\nIntelligence: %d\nPiety: %d\nVitality: %d\nAgility: %d\nLuck: %d" % [
		rolled_stats.get("strength", 10),
		rolled_stats.get("intelligence", 10),
		rolled_stats.get("piety", 10),
		rolled_stats.get("vitality", 10),
		rolled_stats.get("agility", 10),
		rolled_stats.get("luck", 10)
	]
	content_container.add_child(stats_label)

	var total := 0
	for stat: String in rolled_stats:
		total += rolled_stats[stat]
	var total_label := Label.new()
	total_label.text = "\nTotal: %d" % total
	content_container.add_child(total_label)

	var reroll_btn := Button.new()
	reroll_btn.text = "Reroll"
	reroll_btn.custom_minimum_size = Vector2(100, 40)
	reroll_btn.pressed.connect(_on_reroll_pressed)
	content_container.add_child(reroll_btn)


func _roll_stats() -> void:
	rolled_stats = Character.roll_stats_for_race(selected_race)


func _on_reroll_pressed() -> void:
	_roll_stats()
	_show_step()


func _show_class_step() -> void:
	step_label.text = "Step 3: Choose Class"

	var grid := GridContainer.new()
	grid.columns = 3
	content_container.add_child(grid)

	for class_id: int in CharEnum.CharacterClass.values():
		var char_class: CharEnum.CharacterClass = class_id as CharEnum.CharacterClass
		var btn := Button.new()
		btn.text = CharEnum.get_class_name(char_class)
		btn.custom_minimum_size = Vector2(120, 40)

		var meets_reqs := ClassDataRef.meets_requirements(char_class, rolled_stats)
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

	var data: Dictionary = ClassDataRef.get_class_data(selected_class)
	var reqs: Dictionary = ClassDataRef.get_requirements(selected_class)

	var text := "[b]%s[/b]\n" % CharEnum.get_class_name(selected_class)
	text += "HP Base: %d  MP Base: %d\n" % [data.get("hp_base", 0), data.get("mp_base", 0)]

	if not reqs.is_empty():
		text += "Requires: "
		var req_parts: Array[String] = []
		for stat: String in reqs:
			req_parts.append("%s %d" % [stat.capitalize(), reqs[stat]])
		text += ", ".join(req_parts)

	info.text = text
	content_container.add_child(info)


func _on_class_selected(char_class: CharEnum.CharacterClass) -> void:
	selected_class = char_class
	_show_step()


func _show_alignment_step() -> void:
	step_label.text = "Step 4: Choose Alignment"

	var vbox := VBoxContainer.new()
	content_container.add_child(vbox)

	for align_id: int in CharEnum.Alignment.values():
		var alignment: CharEnum.Alignment = align_id as CharEnum.Alignment
		var btn := Button.new()
		btn.text = CharEnum.get_alignment_name(alignment)
		btn.custom_minimum_size = Vector2(150, 40)
		btn.toggle_mode = true
		btn.button_pressed = (alignment == selected_alignment)
		btn.pressed.connect(_on_alignment_selected.bind(alignment))
		vbox.add_child(btn)


func _on_alignment_selected(alignment: CharEnum.Alignment) -> void:
	selected_alignment = alignment
	_show_step()


func _show_gender_step() -> void:
	step_label.text = "Step 5: Choose Gender"

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_container.add_child(hbox)

	for gender_id: int in CharEnum.Gender.values():
		var gender: CharEnum.Gender = gender_id as CharEnum.Gender
		var btn := Button.new()
		btn.text = "Male" if gender == CharEnum.Gender.MALE else "Female"
		btn.custom_minimum_size = Vector2(120, 40)
		btn.toggle_mode = true
		btn.button_pressed = (gender == selected_gender)
		btn.pressed.connect(_on_gender_selected.bind(gender))
		hbox.add_child(btn)


func _on_gender_selected(gender: CharEnum.Gender) -> void:
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
	step_label.text = "Confirm Character"

	var summary := Label.new()
	summary.text = """Name: %s
Race: %s
Class: %s
Alignment: %s
Gender: %s

Strength: %d
Intelligence: %d
Piety: %d
Vitality: %d
Agility: %d
Luck: %d""" % [
		character_name if character_name else "(unnamed)",
		CharEnum.get_race_name(selected_race),
		CharEnum.get_class_name(selected_class),
		CharEnum.get_alignment_name(selected_alignment),
		"Male" if selected_gender == CharEnum.Gender.MALE else "Female",
		rolled_stats.get("strength", 10),
		rolled_stats.get("intelligence", 10),
		rolled_stats.get("piety", 10),
		rolled_stats.get("vitality", 10),
		rolled_stats.get("agility", 10),
		rolled_stats.get("luck", 10)
	]
	content_container.add_child(summary)


func _on_back_pressed() -> void:
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
		if not ClassDataRef.meets_requirements(selected_class, rolled_stats):
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

	if GameState.roster.add_character(new_char):
		print("Created character: ", new_char.character_name)
		SceneManager.go_to_town()
	else:
		push_error("Failed to add character to roster (roster full?)")


func _on_cancel_pressed() -> void:
	SceneManager.go_to_town()
