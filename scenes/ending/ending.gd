extends Control

## The victory screen, shown once when the final boss falls. It reads the
## campaign back to the player: how long it took, who finished it, and who
## didn't make it. Afterward the guild returns to town and can keep delving.

const MUSIC_PATH := "res://audio/music/music_town.ogg"

var _scaffold: ScreenScaffold
var _continue_btn: Button


func _ready() -> void:
	_scaffold = ScreenScaffold.create({
		"title": "VICTORY",
		"hint": "Enter — return to town",
		"hero": true,
		"show_back": false,
	})
	add_child(_scaffold)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scaffold.body.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(820, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	_build(col)

	var stream: AudioStream = load(MUSIC_PATH)
	if stream:
		AudioManager.crossfade_music(stream, 2.0)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.2)
	_continue_btn.grab_focus.call_deferred()


func _build(col: VBoxContainer) -> void:
	var boss := MonsterDatabase.get_boss_for_floor(GameState.FINAL_FLOOR)
	var boss_name := boss.monster_name if boss else "the master of the depths"

	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "%s Has Fallen" % boss_name.get_slice(" ", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var divider := ArcaneDivider.new()
	divider.custom_minimum_size = Vector2(420, 14)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(divider)

	var days := maxi(1, GameState.victory_day)
	var epilogue := Label.new()
	epilogue.theme_type_variation = &"SubtitleLabel"
	epilogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	epilogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	epilogue.text = _epilogue_text(boss_name, days)
	col.add_child(epilogue)

	var below_days := _total_days_below()
	if below_days >= CharacterEnums.DAYS_PER_YEAR:
		var clocks := Label.new()
		clocks.theme_type_variation = &"SubheaderLabel"
		clocks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clocks.add_theme_color_override("font_color", UIColors.TITLE_GOLD)
		clocks.text = "%d days on the surface. %d years spent below, between them." % [
			days, below_days / CharacterEnums.DAYS_PER_YEAR]
		col.add_child(clocks)

	col.add_child(_stats_row(days))

	var party := GameState.get_party_members()
	if not party.is_empty():
		col.add_child(_section_header("The Party"))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		for member in party:
			grid.add_child(_member_card(member))
		col.add_child(grid)

	var retired: Array[String] = []
	for c in GameState.roster.get_all():
		if c.is_retired():
			var post := Retirement.post_title(c.town_post)
			retired.append("%s, %s" % [c.character_name, post if post else "retired"])
	if not retired.is_empty():
		col.add_child(_section_header("Keeping the Town"))
		var posts := Label.new()
		posts.theme_type_variation = &"MutedLabel"
		posts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		posts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		posts.text = "  ·  ".join(retired)
		col.add_child(posts)

	var fallen := _fallen_characters()
	if not fallen.is_empty():
		col.add_child(_section_header("In Memory"))
		var names: Array[String] = []
		for c in fallen:
			names.append("%s, %s %s" % [c.character_name, c.get_race_name(), c.get_class_name()])
		var memorial := Label.new()
		memorial.theme_type_variation = &"MutedLabel"
		memorial.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		memorial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		memorial.text = "  ·  ".join(names)
		col.add_child(memorial)

	var after := Label.new()
	after.theme_type_variation = &"MutedLabel"
	after.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	after.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	after.text = "The dungeon isn't empty. Its upper halls still stir, and the guild can keep delving for as long as it likes."
	col.add_child(after)

	_continue_btn = Button.new()
	_continue_btn.text = "Return to Town"
	_continue_btn.theme_type_variation = &"PrimaryButton"
	_continue_btn.custom_minimum_size = Vector2(260, 48)
	_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_btn.pressed.connect(_on_continue)
	col.add_child(_continue_btn)


func _epilogue_text(boss_name: String, days: int) -> String:
	var date := GameCalendar.format_date(GameState.victory_day)
	var day_word := "day" if days == 1 else "days"
	return ("On %s, %d %s after the guild was founded, the party cut down %s in the deepest chamber of the dungeon. "
		+ "They carried the news up every one of its stairs, and for the first time in living memory the lowest halls went quiet.") \
		% [date, days, day_word, boss_name]


func _stats_row(days: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(_stat_chip("Days", str(days)))
	row.add_child(_stat_chip("Bosses Slain", str(GameState.bosses_slain.size())))
	row.add_child(_stat_chip("Highest Level", str(_highest_level())))
	row.add_child(_stat_chip("Deaths", str(_total_deaths())))
	var play_secs := SaveManager.get_play_time_seconds()
	if play_secs >= 60:
		row.add_child(_stat_chip("Play Time", "%d:%02d" % [floori(play_secs / 3600.0), floori(play_secs / 60.0) % 60]))
	return row


func _stat_chip(caption: String, value: String) -> Control:
	var panel := PanelContainer.new()
	var sb := _stylebox(UIColors.SURFACE_CARD, 1, UIColors.BORDER_SUBTLE, 6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	panel.add_child(v)
	var value_label := Label.new()
	value_label.theme_type_variation = &"HeaderLabel"
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(value_label)
	var caption_label := Label.new()
	caption_label.theme_type_variation = &"MutedLabel"
	caption_label.text = caption.to_upper()
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(caption_label)
	return panel


func _section_header(text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"SubheaderLabel"
	l.text = text.to_upper()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", UIColors.TITLE_GOLD)
	return l


func _member_card(c: Character) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var border := UIColors.BORDER_SUBTLE if c.is_dead else UIColors.TITLE_GOLD_DIM
	var sb := _stylebox(UIColors.SURFACE_CARD, 1, border, 8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)

	var name_label := Label.new()
	name_label.theme_type_variation = &"SubheaderLabel"
	name_label.text = c.character_name + ("  (fallen)" if c.is_dead else "")
	if c.is_dead:
		name_label.add_theme_color_override("font_color", UIColors.TEXT_MUTED)
	v.add_child(name_label)

	var line := Label.new()
	line.theme_type_variation = &"MutedLabel"
	line.text = "Level %d %s %s  ·  age %d" % [c.level, c.get_race_name(), c.get_class_name(), c.get_age_years()]
	var below_years := c.days_below / CharacterEnums.DAYS_PER_YEAR
	if below_years >= 1:
		line.text += ", %d below" % below_years
	v.add_child(line)

	var mark := _signature_mark(c)
	if mark != "":
		var mark_label := Label.new()
		mark_label.theme_type_variation = &"SubtitleLabel"
		mark_label.text = "“%s”" % mark
		mark_label.add_theme_color_override("font_color", UIColors.TITLE_GOLD)
		mark_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(mark_label)
	return panel


## The mark that best sums up a character: the newest major mark, else the
## newest mark of any kind.
func _signature_mark(c: Character) -> String:
	var majors := c.get_major_marks()
	if not majors.is_empty():
		return str(majors[majors.size() - 1].get("name", ""))
	var all := c.get_marks()
	if not all.is_empty():
		return str(all[all.size() - 1].get("name", ""))
	return ""


## Characters gone for good: lost beyond resurrection.
func _fallen_characters() -> Array[Character]:
	var result: Array[Character] = []
	if GameState.roster == null:
		return result
	for c in GameState.roster.get_all():
		if c.has_status(CharacterEnums.StatusEffect.LOST):
			result.append(c)
	return result


func _total_days_below() -> int:
	var total := 0
	if GameState.roster:
		for c in GameState.roster.get_all():
			total += c.days_below
	return total


func _total_deaths() -> int:
	var total := 0
	if GameState.roster:
		for c in GameState.roster.get_all():
			total += c.death_count
	return total


func _highest_level() -> int:
	var best := 1
	if GameState.roster:
		for c in GameState.roster.get_all():
			best = maxi(best, c.level)
	return best


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_continue()


func _on_continue() -> void:
	AudioManager.play_ui("confirm")
	SceneManager.go_to_town()


func _stylebox(bg: Color, border_width: int, border_color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border_width)
	sb.border_color = border_color
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb
