extends Control

enum Step { RACE, STATS, CLASS, ALIGNMENT, GENDER, PERSONALITY, NAME, CONFIRM }

const STAT_NAMES: Array[String] = ["strength", "intelligence", "piety", "vitality", "agility", "luck"]
const STAT_LABELS: Array[String] = ["STR", "INT", "PIE", "VIT", "AGI", "LCK"]
const BASE_BONUS_POINTS: int = 9
const MAX_AGING_TRADE: int = 3

var current_step: Step = Step.RACE
var selected_race: CharacterEnums.Race = CharacterEnums.Race.HUMAN
var selected_class: CharacterEnums.CharacterClass = CharacterEnums.CharacterClass.FIGHTER
var selected_alignment: CharacterEnums.Alignment = CharacterEnums.Alignment.NEUTRAL
var selected_gender: CharacterEnums.Gender = CharacterEnums.Gender.MALE
var selected_personality_axis: Personality.Axis = Personality.Axis.TEMPERAMENT
var selected_personality_option: int = -1
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
var grid_nav: MenuNavigator = null
var grid_buttons: Array[Button] = []
var grid_columns: int = 3
var stat_focus_index: int = 0
var stat_row_labels: Array = []
var stat_focus_buttons: Array = []

# Personality step (master/detail: axis column | trait column).
var _pers_axis_buttons: Array[Button] = []
var _pers_trait_buttons: Array[Button] = []
var _pers_focus_col: int = 0  # 0 = axis column, 1 = trait column
var _pers_axis_index: int = 0
var _pers_trait_index: int = -1
var _pers_trait_box: VBoxContainer = null
var _pers_trait_header: Label = null
var _pers_leaning_label: Label = null
var _pers_result_label: Label = null

var _scaffold: ScreenScaffold = null
var _preview_label: RichTextLabel = null
var _quick_btn: Button = null

const QUICK_NAMES: Array[String] = [
	"Aldric", "Brenna", "Caspian", "Dahlia", "Eamon", "Fenwick", "Gwendolyn",
	"Halvard", "Isolde", "Joran", "Kestrel", "Lyra", "Magnus", "Nadia",
	"Orin", "Perrin", "Quill", "Rowan", "Sable", "Thorne", "Ulric", "Vesper",
]


func _ready() -> void:
	_install_scaffold()
	back_button.pressed.connect(_on_back_pressed)
	next_button.pressed.connect(_on_next_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	next_button.theme_type_variation = &"PrimaryButton"
	_show_step()


## Wrap the wizard in the shared scaffold and add a live character-preview panel
## on the right that updates as choices are made — turning the most-broken screen
## into the showpiece. The center column keeps the existing step content.
func _install_scaffold() -> void:
	var bg := get_node_or_null("Background")
	if bg != null:
		bg.queue_free()

	$VBoxContainer/Title.visible = false

	_scaffold = ScreenScaffold.create({
		"title": "CREATE CHARACTER", "show_gold": false,
		"hint": "↑/↓ ←/→  Choose      ·      Enter  Next      ·      Esc  Back",
	})
	add_child(_scaffold)
	move_child(_scaffold, 0)
	_scaffold.back_pressed.connect(_on_scaffold_back)

	# Lay out as: step label (full width) / [ race box | preview ] (tops aligned)
	# / footer (full width). Pulling the step label and footer out of the column
	# makes the preview panel start level with the choice box.
	var old_vbox: Control = $VBoxContainer
	old_vbox.remove_child(step_label)
	old_vbox.remove_child(content_panel)
	old_vbox.remove_child(nav_container)
	old_vbox.queue_free()

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 12)
	_scaffold.body.add_child(outer)

	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(step_label)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 18)
	outer.add_child(split)

	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(content_panel)
	split.add_child(_build_preview_panel())

	outer.add_child(nav_container)

	_quick_btn = Button.new()
	_quick_btn.theme_type_variation = &"PrimaryButton"
	_quick_btn.text = "⚡  Quick Create"
	_quick_btn.custom_minimum_size = Vector2(160, 42)
	_quick_btn.pressed.connect(_quick_create)
	nav_container.add_child(_quick_btn)

	# Proper wizard footer: Back / Cancel on the left, Quick / Next on the right,
	# split by a flexible spacer — not a cluster in the middle.
	nav_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	nav_container.add_theme_constant_override("separation", 10)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav_container.add_child(footer_spacer)
	nav_container.move_child(back_button, 0)
	nav_container.move_child(cancel_button, 1)
	nav_container.move_child(footer_spacer, 2)
	nav_container.move_child(_quick_btn, 3)
	nav_container.move_child(next_button, 4)
	for b in [back_button, cancel_button, next_button]:
		b.custom_minimum_size = Vector2(120, 42)


## Card-styled, width-filling choice button used for race/class/alignment/etc.
## The toggled (selected) state shows the arcane accent; focus adds the glow.
func _style_choice_button(btn: Button) -> void:
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 48)
	btn.clip_text = true

	var normal := StyleBoxFlat.new()
	normal.bg_color = UIColors.SURFACE_CARD
	normal.set_corner_radius_all(6)
	normal.set_border_width_all(1)
	normal.border_color = UIColors.BORDER_DEFAULT
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = UIColors.SURFACE_HOVER
	hover.border_color = UIColors.BORDER_HOVER

	var active := normal.duplicate() as StyleBoxFlat
	active.bg_color = UIColors.SURFACE_SELECTED
	active.set_border_width_all(2)
	active.border_color = UIColors.ACCENT

	var focus := active.duplicate() as StyleBoxFlat
	focus.shadow_color = UIColors.ACCENT_GLOW
	focus.shadow_size = 5

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = UIColors.SURFACE_DISABLED
	disabled.border_color = UIColors.BORDER_SUBTLE

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", active)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", UIColors.TEXT_DISABLED)


func _build_preview_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(310, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	var header := Label.new()
	header.theme_type_variation = &"SubheaderLabel"
	header.text = "PREVIEW"
	col.add_child(header)

	_preview_label = RichTextLabel.new()
	_preview_label.bbcode_enabled = true
	_preview_label.fit_content = true
	_preview_label.scroll_active = false
	_preview_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_preview_label)

	return panel


func _on_scaffold_back() -> void:
	if current_step == Step.RACE:
		_on_cancel_pressed()
	else:
		_on_back_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if current_step == Step.NAME:
		return

	if current_step == Step.PERSONALITY:
		_handle_personality_input(event)
		return

	if event.is_action_pressed("menu_cancel"):
		if current_step == Step.RACE:
			_on_cancel_pressed()
		else:
			_on_back_pressed()
		return

	if event.is_action_pressed("menu_confirm"):
		if current_step == Step.STATS:
			_stat_focus_confirm()
		elif grid_nav and grid_nav.current_index >= 0 and grid_nav.current_index < grid_buttons.size() and grid_buttons[grid_nav.current_index].disabled:
			return
		else:
			_on_next_pressed()
		return

	if current_step == Step.STATS:
		if event.is_action_pressed("menu_up"):
			_stat_focus_move(-1)
		elif event.is_action_pressed("menu_down"):
			_stat_focus_move(1)
		elif event.is_action_pressed("menu_left"):
			_stat_focus_action(-1)
		elif event.is_action_pressed("menu_right"):
			_stat_focus_action(1)
		return

	if grid_nav and not grid_buttons.is_empty():
		if event.is_action_pressed("menu_left"):
			_grid_move(-1)
		elif event.is_action_pressed("menu_right"):
			_grid_move(1)
		elif event.is_action_pressed("menu_up"):
			_grid_move(-grid_columns)
		elif event.is_action_pressed("menu_down"):
			_grid_move(grid_columns)


func _grid_move(offset: int) -> void:
	var new_index := grid_nav.current_index + offset
	if new_index < 0 or new_index >= grid_buttons.size():
		return
	grid_nav.select(new_index)
	if not grid_buttons[new_index].disabled:
		grid_buttons[new_index].pressed.emit()


func _stat_focus_move(offset: int) -> void:
	var total := stat_row_labels.size()
	if total == 0:
		return
	var new_index := stat_focus_index + offset
	if new_index < 0 or new_index >= total:
		return
	stat_focus_index = new_index
	_update_stat_focus_highlight()


func _stat_focus_action(direction: int) -> void:
	if stat_focus_index < STAT_NAMES.size():
		var stat_name: String = STAT_NAMES[stat_focus_index]
		if direction > 0:
			_on_stat_plus(stat_name)
		else:
			_on_stat_minus(stat_name)
	elif stat_focus_index == STAT_NAMES.size():
		if direction > 0:
			_on_aging_plus()
		else:
			_on_aging_minus()


func _stat_focus_confirm() -> void:
	if stat_focus_index < stat_focus_buttons.size() and stat_focus_buttons[stat_focus_index] != null:
		stat_focus_buttons[stat_focus_index].pressed.emit()
		return
	_on_next_pressed()


func _update_stat_focus_highlight() -> void:
	for i in range(stat_row_labels.size()):
		var lbl = stat_row_labels[i]
		if lbl != null:
			if i == stat_focus_index:
				lbl.add_theme_color_override("font_color", UIColors.TEXT_HIGHLIGHT)
			else:
				lbl.remove_theme_color_override("font_color")
	for i in range(stat_focus_buttons.size()):
		var btn = stat_focus_buttons[i]
		if btn != null:
			if i == stat_focus_index:
				btn.add_theme_color_override("font_color", UIColors.TEXT_HIGHLIGHT)
			else:
				btn.remove_theme_color_override("font_color")


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
		Step.PERSONALITY:
			_show_personality_step()
		Step.NAME:
			_show_name_step()
		Step.CONFIRM:
			_show_confirm_step()

	_update_preview()


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
	grid_nav = null
	grid_buttons.clear()
	stat_row_labels.clear()
	stat_focus_buttons.clear()
	_pers_axis_buttons.clear()
	_pers_trait_buttons.clear()
	_pers_trait_box = null
	_pers_trait_header = null
	_pers_leaning_label = null
	_pers_result_label = null


func _update_nav_buttons() -> void:
	nav_container.visible = current_step != Step.STATS
	back_button.visible = current_step != Step.RACE
	cancel_button.visible = true
	if _quick_btn != null:
		_quick_btn.visible = (current_step == Step.RACE)
	if current_step == Step.CONFIRM:
		next_button.text = "Create"
	else:
		next_button.text = "Next"

	# Next is gated only on the personality step (until a trait is chosen);
	# every other step keeps it enabled and restores the default hint.
	if current_step != Step.PERSONALITY:
		next_button.disabled = false
		next_button.modulate = Color.WHITE
		if _scaffold != null:
			_scaffold.set_hint("↑/↓ ←/→  Choose        ·        Enter  Next        ·        Esc  Back")


## The right-hand live dossier: reflects every choice as it is made so the player
## sees the character take shape. Shows what's known so far and whether the
## current class is actually qualified by the rolled attributes.
func _update_preview() -> void:
	if _preview_label == null:
		return

	var nm := character_name if character_name != "" else "New Adventurer"
	var gender_name := "Male" if selected_gender == CharacterEnums.Gender.MALE else "Female"
	var t := "[b][color=#debc78]%s[/color][/b]\n" % nm
	t += "[color=#8da0c8]%s %s  ·  %s[/color]\n" % [
		gender_name,
		CharacterEnums.get_race_name(selected_race),
		CharacterEnums.get_class_name(selected_class)]
	t += "[color=#9a96a0]%s[/color]\n" % CharacterEnums.get_alignment_name(selected_alignment)

	var base_age: int = CharacterEnums.get_base_age(selected_race) + aging_years_spent
	t += "[color=#9a96a0]Age %d[/color]\n\n" % base_age

	if not rolled_stats.is_empty():
		t += "[b]Attributes[/b]\n"
		for i in range(STAT_NAMES.size()):
			t += "[color=#9a96a0]%s[/color]  [color=#e0ddd6]%d[/color]    " % [
				STAT_LABELS[i], rolled_stats.get(STAT_NAMES[i], 0)]
			if i % 2 == 1:
				t += "\n"
		t += "\n"
		var data: Dictionary = ClassData.get_class_data(selected_class)
		t += "[color=#9a96a0]HP base %d  ·  MP base %d[/color]\n\n" % [
			data.get("hp_base", 0), data.get("mp_base", 0)]
		if ClassData.meets_requirements(selected_class, rolled_stats):
			t += "[color=#5cc46a]✓ Qualifies as %s[/color]" % CharacterEnums.get_class_name(selected_class)
		else:
			t += "[color=#d65656]✗ Does not yet meet %s requirements[/color]" % CharacterEnums.get_class_name(selected_class)
	else:
		t += "[color=#9a96a0]Pick a race to roll attributes.[/color]"

	if selected_personality_option >= 0:
		t += "\n\n[color=#c39ae8]%s: %s[/color]" % [
			Personality.get_axis_name(selected_personality_axis),
			Personality.get_option_name(selected_personality_axis, selected_personality_option)]

	_preview_label.text = t


## One-click "give me a solid character": random race, a class its rolled stats
## can actually support (bonus points auto-spent to meet requirements, remainder
## scattered), random alignment / gender / personality, random name.
func _quick_create() -> void:
	selected_race = CharacterEnums.Race.values().pick_random() as CharacterEnums.Race
	_init_stats_for_race()
	bonus_points = BASE_BONUS_POINTS
	bonus_remaining = bonus_points

	var ranges: Dictionary = CharacterEnums.RACE_STAT_RANGES.get(selected_race, {})

	var achievable: Array = []
	for class_id: int in CharacterEnums.CharacterClass.values():
		if _class_achievable(class_id as CharacterEnums.CharacterClass, ranges):
			achievable.append(class_id)
	selected_class = (achievable.pick_random() if not achievable.is_empty()
		else CharacterEnums.CharacterClass.FIGHTER) as CharacterEnums.CharacterClass

	# Spend bonus points to satisfy the chosen class's requirements first.
	var reqs: Dictionary = ClassData.get_requirements(selected_class)
	for stat_name: String in reqs:
		while rolled_stats[stat_name] < reqs[stat_name] and bonus_remaining > 0:
			rolled_stats[stat_name] += 1
			bonus_remaining -= 1
	# Scatter whatever is left, respecting per-stat maxima.
	var guard := 0
	while bonus_remaining > 0 and guard < 300:
		guard += 1
		var stat_name: String = STAT_NAMES.pick_random()
		var range_vec: Vector2i = ranges.get(stat_name, Vector2i(8, 18))
		if rolled_stats[stat_name] < range_vec.y:
			rolled_stats[stat_name] += 1
			bonus_remaining -= 1

	selected_alignment = CharacterEnums.Alignment.values().pick_random() as CharacterEnums.Alignment
	selected_gender = CharacterEnums.Gender.values().pick_random() as CharacterEnums.Gender
	selected_personality_axis = Personality.Axis.values().pick_random() as Personality.Axis
	var options: Array = Personality.get_options_for_axis(selected_personality_axis)
	selected_personality_option = options.pick_random() if not options.is_empty() else -1
	character_name = QUICK_NAMES.pick_random()

	_create_character()


func _class_achievable(char_class: CharacterEnums.CharacterClass, ranges: Dictionary) -> bool:
	var reqs: Dictionary = ClassData.get_requirements(char_class)
	if reqs.is_empty():
		return true
	var bp_needed := 0
	for stat_name: String in reqs:
		var range_vec: Vector2i = ranges.get(stat_name, Vector2i(8, 18))
		if reqs[stat_name] > range_vec.y:
			return false
		bp_needed += maxi(0, reqs[stat_name] - range_vec.x)
	return bp_needed <= BASE_BONUS_POINTS


func _show_race_step() -> void:
	step_label.text = "Step 1: Choose Race"

	var grid := GridContainer.new()
	grid.columns = 3
	grid_columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content_container.add_child(grid)

	var initial_index := 0
	grid_buttons.clear()
	for race_id: int in CharacterEnums.Race.values():
		var race: CharacterEnums.Race = race_id as CharacterEnums.Race
		var btn := Button.new()
		btn.text = CharacterEnums.get_race_name(race)
		btn.toggle_mode = true
		btn.button_pressed = (race == selected_race)
		_style_choice_button(btn)
		btn.pressed.connect(_on_race_selected.bind(race))
		if race == selected_race:
			initial_index = grid_buttons.size()
		grid.add_child(btn)
		grid_buttons.append(btn)

	grid_nav = MenuNavigator.new()
	grid_nav.setup(grid_buttons, initial_index)

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
		stat_row_labels.append(name_lbl)
		stat_focus_buttons.append(null)

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
	stat_row_labels.append(aging_title)
	stat_focus_buttons.append(null)

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
	stat_row_labels.append(null)
	stat_focus_buttons.append(reset_btn)

	var stat_back_btn := Button.new()
	stat_back_btn.text = "Back"
	stat_back_btn.custom_minimum_size = Vector2(80, 40)
	stat_back_btn.pressed.connect(_on_back_pressed)
	btn_row.add_child(stat_back_btn)
	stat_row_labels.append(null)
	stat_focus_buttons.append(stat_back_btn)

	var stat_next_btn := Button.new()
	stat_next_btn.text = "Next"
	stat_next_btn.theme_type_variation = &"PrimaryButton"
	stat_next_btn.custom_minimum_size = Vector2(90, 40)
	stat_next_btn.pressed.connect(_on_next_pressed)
	btn_row.add_child(stat_next_btn)
	stat_row_labels.append(null)
	stat_focus_buttons.append(stat_next_btn)

	var stat_cancel_btn := Button.new()
	stat_cancel_btn.text = "Cancel"
	stat_cancel_btn.custom_minimum_size = Vector2(80, 40)
	stat_cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_row.add_child(stat_cancel_btn)
	stat_row_labels.append(null)
	stat_focus_buttons.append(stat_cancel_btn)

	content_container.add_child(btn_row)
	_update_stat_focus_highlight()


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
	grid_columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content_container.add_child(grid)

	var initial_index := 0
	grid_buttons.clear()
	for class_id: int in CharacterEnums.CharacterClass.values():
		var char_class: CharacterEnums.CharacterClass = class_id as CharacterEnums.CharacterClass
		var btn := Button.new()
		btn.text = CharacterEnums.get_class_name(char_class)

		var meets_reqs := ClassData.meets_requirements(char_class, rolled_stats)
		btn.disabled = not meets_reqs
		btn.toggle_mode = true
		btn.button_pressed = (char_class == selected_class and meets_reqs)
		_style_choice_button(btn)

		if meets_reqs:
			btn.pressed.connect(_on_class_selected.bind(char_class))

		if char_class == selected_class and meets_reqs:
			initial_index = grid_buttons.size()
		grid.add_child(btn)
		grid_buttons.append(btn)

	grid_nav = MenuNavigator.new()
	grid_nav.setup(grid_buttons, initial_index)

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
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	content_container.add_child(vbox)

	var initial_index := 0
	grid_buttons.clear()
	grid_columns = 1
	for align_id: int in CharacterEnums.Alignment.values():
		var alignment: CharacterEnums.Alignment = align_id as CharacterEnums.Alignment
		var btn := Button.new()
		btn.text = CharacterEnums.get_alignment_name(alignment)
		btn.toggle_mode = true
		btn.button_pressed = (alignment == selected_alignment)
		_style_choice_button(btn)
		btn.pressed.connect(_on_alignment_selected.bind(alignment))
		if alignment == selected_alignment:
			initial_index = grid_buttons.size()
		vbox.add_child(btn)
		grid_buttons.append(btn)

	grid_nav = MenuNavigator.new()
	grid_nav.setup(grid_buttons, initial_index)


func _on_alignment_selected(alignment: CharacterEnums.Alignment) -> void:
	selected_alignment = alignment
	_show_step()


func _show_gender_step() -> void:
	step_label.text = "Step 5: Choose Gender"

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)
	content_container.add_child(hbox)

	var initial_index := 0
	grid_buttons.clear()
	grid_columns = 2
	for gender_id: int in CharacterEnums.Gender.values():
		var gender: CharacterEnums.Gender = gender_id as CharacterEnums.Gender
		var btn := Button.new()
		btn.text = "Male" if gender == CharacterEnums.Gender.MALE else "Female"
		btn.toggle_mode = true
		btn.button_pressed = (gender == selected_gender)
		_style_choice_button(btn)
		btn.pressed.connect(_on_gender_selected.bind(gender))
		if gender == selected_gender:
			initial_index = grid_buttons.size()
		hbox.add_child(btn)
		grid_buttons.append(btn)

	grid_nav = MenuNavigator.new()
	grid_nav.setup(grid_buttons, initial_index)


func _on_gender_selected(gender: CharacterEnums.Gender) -> void:
	selected_gender = gender
	_show_step()


## Master/detail: an AXIS column (which facet to crystallize) beside a TRAIT
## column (that axis's four traits, rebuilt live). Up/Down navigates the active
## column and live-selects; →/Enter drills axes→traits; ← returns; Enter on a
## trait advances. Keeps the two groups independent so both axis AND trait are
## selectable — the single-list version made that impossible.
func _show_personality_step() -> void:
	step_label.text = "Step 6: Choose a Defining Trait"

	# Restore from the current selection (e.g. when returning via Back).
	var axes := Personality.Axis.values()
	_pers_axis_index = maxi(axes.find(selected_personality_axis), 0)
	selected_personality_axis = axes[_pers_axis_index] as Personality.Axis
	_pers_focus_col = 0
	_pers_trait_index = Personality.get_options_for_axis(selected_personality_axis).find(selected_personality_option)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	content_container.add_child(root)

	var headline := Label.new()
	headline.theme_type_variation = &"SubheaderLabel"
	headline.text = "What is your adventurer known for?"
	root.add_child(headline)

	var subline := Label.new()
	subline.theme_type_variation = &"MutedLabel"
	subline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subline.text = "Crystallize a single defining trait now. The other three facets stay fluid — they emerge through the choices your adventurer makes in play."
	root.add_child(subline)

	var cols := HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 18)
	root.add_child(cols)

	# Axis column (master).
	var axis_col := VBoxContainer.new()
	axis_col.custom_minimum_size = Vector2(210, 0)
	axis_col.add_theme_constant_override("separation", 8)
	cols.add_child(axis_col)

	var axis_head := Label.new()
	axis_head.theme_type_variation = &"SubheaderLabel"
	axis_head.text = "DEFINING FACET"
	axis_col.add_child(axis_head)

	_pers_axis_buttons.clear()
	for i in range(axes.size()):
		var axis: Personality.Axis = axes[i] as Personality.Axis
		var btn := Button.new()
		btn.text = Personality.get_axis_name(axis)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 46)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_pers_axis_pressed.bind(i))
		axis_col.add_child(btn)
		_pers_axis_buttons.append(btn)

	# Trait column (detail) — rebuilt per axis.
	var trait_col := VBoxContainer.new()
	trait_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trait_col.add_theme_constant_override("separation", 8)
	cols.add_child(trait_col)

	_pers_trait_header = Label.new()
	_pers_trait_header.theme_type_variation = &"SubheaderLabel"
	trait_col.add_child(_pers_trait_header)

	_pers_trait_box = VBoxContainer.new()
	_pers_trait_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pers_trait_box.add_theme_constant_override("separation", 8)
	trait_col.add_child(_pers_trait_box)

	# The one-line "this is what we're committing to" readout — keeps the single
	# defining choice front-and-center.
	_pers_result_label = Label.new()
	_pers_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_pers_result_label)

	_pers_leaning_label = Label.new()
	_pers_leaning_label.theme_type_variation = &"MutedLabel"
	_pers_leaning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_pers_leaning_label)

	_rebuild_pers_traits()
	_refresh_pers_styles()
	_update_personality_next()


## Rebuild just the trait column for the selected axis — no full step rebuild,
## so the master/detail selection never thrashes.
func _rebuild_pers_traits() -> void:
	if _pers_trait_box == null:
		return
	for c in _pers_trait_box.get_children():
		c.queue_free()
	_pers_trait_buttons.clear()

	_pers_trait_header.text = "KNOWN FOR  ·  %s" % Personality.get_axis_name(selected_personality_axis)

	var opts := Personality.get_options_for_axis(selected_personality_axis)
	for i in range(opts.size()):
		var option: int = opts[i]
		var btn := Button.new()
		btn.text = Personality.get_option_name(selected_personality_axis, option)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 46)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_pers_trait_pressed.bind(i))
		_pers_trait_box.add_child(btn)
		_pers_trait_buttons.append(btn)

	_update_pers_leaning()


## The race's weighting across this axis's traits — context for the choice.
func _update_pers_leaning() -> void:
	if _pers_leaning_label == null:
		return
	var weights: Dictionary = Personality.RACE_TENDENCY_WEIGHTS.get(selected_race, {})
	var axis_weights: Array = weights.get(selected_personality_axis, [])
	if axis_weights.is_empty():
		_pers_leaning_label.text = ""
		return
	var parts: Array[String] = []
	for pair in axis_weights:
		parts.append("%s %d%%" % [Personality.get_option_name(selected_personality_axis, pair[0]), pair[1]])
	_pers_leaning_label.text = "%s leanings on this axis —  %s" % [
		CharacterEnums.get_race_name(selected_race), "    ".join(parts)]


func _refresh_pers_styles() -> void:
	for i in range(_pers_axis_buttons.size()):
		var sel := i == _pers_axis_index
		_style_pers_button(_pers_axis_buttons[i], sel, sel and _pers_focus_col == 0)
	for i in range(_pers_trait_buttons.size()):
		var sel := i == _pers_trait_index
		_style_pers_button(_pers_trait_buttons[i], sel, sel and _pers_focus_col == 1)
	_update_pers_summary()


## The single-line readout that keeps the ONE-trait commitment explicit: it names
## the chosen trait once picked, and otherwise prompts for the single choice.
func _update_pers_summary() -> void:
	if _pers_result_label == null:
		return
	if selected_personality_option >= 0:
		_pers_result_label.add_theme_color_override("font_color", UIColors.ACCENT)
		_pers_result_label.text = "✦  Known for being %s  —  their one defining %s trait." % [
			Personality.get_option_name(selected_personality_axis, selected_personality_option),
			Personality.get_axis_name(selected_personality_axis)]
	else:
		_pers_result_label.add_theme_color_override("font_color", UIColors.TEXT_MUTED)
		_pers_result_label.text = "Pick the one trait your adventurer will be known for."


## Selected = filled accent. Focused = accent border + glow (the cursor),
## marking which column is currently live.
func _style_pers_button(btn: Button, selected: bool, focused: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.set_border_width_all(1)
	sb.border_color = UIColors.BORDER_DEFAULT
	sb.bg_color = UIColors.SURFACE_CARD
	if selected:
		sb.bg_color = UIColors.SURFACE_SELECTED
		sb.set_border_width_all(2)
		sb.border_color = UIColors.ACCENT
	if focused:
		sb.set_border_width_all(2)
		sb.border_color = UIColors.ACCENT
		sb.shadow_color = UIColors.ACCENT_GLOW
		sb.shadow_size = 5
	var hover := sb.duplicate() as StyleBoxFlat
	if not selected and not focused:
		hover.bg_color = UIColors.SURFACE_HOVER
		hover.border_color = UIColors.BORDER_HOVER
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", Color.WHITE if (selected or focused) else UIColors.TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)


func _handle_personality_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		_on_back_pressed()
	elif event.is_action_pressed("menu_confirm"):
		if _pers_focus_col == 0:
			_pers_enter_traits()
		elif _pers_trait_index >= 0:
			_on_next_pressed()
	elif event.is_action_pressed("menu_right"):
		if _pers_focus_col == 0:
			_pers_enter_traits()
	elif event.is_action_pressed("menu_left"):
		if _pers_focus_col == 1:
			_pers_focus_col = 0
			_refresh_pers_styles()
			_update_personality_next()
	elif event.is_action_pressed("menu_up"):
		_pers_move(-1)
	elif event.is_action_pressed("menu_down"):
		_pers_move(1)


## Move focus from the axis column into the trait column, auto-picking the first
## trait if none is chosen yet, so a trait is always selected once you arrive.
func _pers_enter_traits() -> void:
	if _pers_trait_buttons.is_empty():
		return
	_pers_focus_col = 1
	if _pers_trait_index < 0:
		_pers_select_trait(0)
	else:
		_refresh_pers_styles()
		_update_personality_next()


func _pers_move(dir: int) -> void:
	if _pers_focus_col == 0:
		var n := _pers_axis_buttons.size()
		if n > 0:
			_pers_select_axis(wrapi(_pers_axis_index + dir, 0, n))
	else:
		var n := _pers_trait_buttons.size()
		if n > 0:
			var start := _pers_trait_index if _pers_trait_index >= 0 else 0
			_pers_select_trait(wrapi(start + dir, 0, n))


func _pers_select_axis(i: int) -> void:
	_pers_axis_index = i
	selected_personality_axis = Personality.Axis.values()[i] as Personality.Axis
	# Changing axis clears the trait — the player picks one deliberately.
	selected_personality_option = -1
	_pers_trait_index = -1
	_rebuild_pers_traits()
	_refresh_pers_styles()
	_update_personality_next()
	_update_preview()
	AudioManager.play_ui("nav")


func _pers_select_trait(i: int) -> void:
	var opts := Personality.get_options_for_axis(selected_personality_axis)
	if i < 0 or i >= opts.size():
		return
	_pers_trait_index = i
	selected_personality_option = opts[i]
	_refresh_pers_styles()
	_update_personality_next()
	_update_preview()
	AudioManager.play_ui("nav")


func _update_personality_next() -> void:
	var ok := selected_personality_option >= 0
	next_button.disabled = not ok
	next_button.modulate = Color.WHITE if ok else UIColors.MODULATE_DISABLED
	if _scaffold != null:
		if _pers_focus_col == 0:
			_scaffold.set_hint("↑/↓  Axis        ·        →  Pick its trait        ·        Esc  Back")
		else:
			_scaffold.set_hint("↑/↓  Trait        ·        ←  Axes        ·        Enter  Confirm        ·        Esc  Back")


func _on_pers_axis_pressed(i: int) -> void:
	_pers_focus_col = 0
	_pers_select_axis(i)


func _on_pers_trait_pressed(i: int) -> void:
	_pers_focus_col = 1
	_pers_select_trait(i)


func _show_name_step() -> void:
	step_label.text = "Step 7: Enter Name"

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
	step_label.text = "Step 8: Confirm Character"

	var base_age: int = CharacterEnums.get_base_age(selected_race)
	var final_age: int = base_age + aging_years_spent
	var preview_days: int = final_age * CharacterEnums.DAYS_PER_YEAR
	var phase_name: String = CharacterEnums.get_life_phase_name(CharacterEnums.get_life_phase(selected_race, preview_days))

	var summary := Label.new()
	var personality_text := ""
	if selected_personality_option >= 0:
		personality_text = "%s: %s" % [
			Personality.get_axis_name(selected_personality_axis),
			Personality.get_option_name(selected_personality_axis, selected_personality_option)]

	summary.text = "Name: %s\nRace: %s\nClass: %s\nAlignment: %s\nGender: %s\nAge: %d (%s)\nPersonality: %s\nLevel: 1\n\nStrength: %d\nIntelligence: %d\nPiety: %d\nVitality: %d\nAgility: %d\nLuck: %d" % [
		character_name if character_name else "(unnamed)",
		CharacterEnums.get_race_name(selected_race),
		CharacterEnums.get_class_name(selected_class),
		CharacterEnums.get_alignment_name(selected_alignment),
		"Male" if selected_gender == CharacterEnums.Gender.MALE else "Female",
		final_age, phase_name,
		personality_text,
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

	if current_step == Step.PERSONALITY and selected_personality_option < 0:
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

	PersonalitySystem.seed_backstory_personality(new_char, selected_personality_axis, selected_personality_option)

	_finalize_character(new_char)


func _finalize_character(new_char: Character) -> void:
	if GameState.roster.add_character(new_char):
		print_debug("Created character: ", new_char.character_name)
		SceneManager.go_to_guild_hall()
	else:
		push_error("Failed to add character to roster (roster full?)")


func _on_cancel_pressed() -> void:
	SceneManager.go_to_guild_hall()
