extends Control

const DESTS: Array = [
	{"id": "guild", "badge": RuneBadge.Kind.HEXAGON, "name": "Guild Hall",
		"desc": "Recruit and manage your party", "needs_party": false},
	{"id": "shop", "badge": RuneBadge.Kind.CIRCLE, "name": "Shop",
		"desc": "Buy, sell, and upgrade equipment", "needs_party": true},
	{"id": "party", "badge": RuneBadge.Kind.STAR, "name": "Party",
		"desc": "Status, inventory, formation, and spells", "needs_party": true},
	{"id": "inn", "badge": RuneBadge.Kind.PENTAGON, "name": "Inn",
		"desc": "Rest to restore HP and MP", "needs_party": true},
	{"id": "temple", "badge": RuneBadge.Kind.DIAMOND, "name": "Temple",
		"desc": "Heal afflictions and revive the fallen", "needs_party": true},
	{"id": "autoexplore", "badge": RuneBadge.Kind.TRIANGLE, "name": "AutoExplore",
		"desc": "Simulate dungeon runs to test your party", "needs_party": true,
		"debug_only": true},
	{"id": "dungeon", "badge": RuneBadge.Kind.CHEVRON_DOWN, "name": "Enter Dungeon",
		"desc": "Descend into the depths", "needs_party": true, "primary": true},
	{"id": "menu", "badge": RuneBadge.Kind.ARCH, "name": "Main Menu",
		"desc": "Return to the title screen", "needs_party": false},
]

var nav: MenuNavigator = null
var _rows: Array[Button] = []
var _meta: Array = []

@onready var _content: VBoxContainer = $CenterContainer/Content
@onready var _day_label: Label = $TopBar/Margin/Bar/DateContainer/DayLabel
@onready var _gold_box: HBoxContainer = $TopBar/Margin/Bar/GoldBox
@onready var _gold_sep: VSeparator = $TopBar/Margin/Bar/Sep


## The modal on top of the town menu (the charter or the homecoming report).
var _modal: CanvasLayer = null


func _ready() -> void:
	_build_quest_strip()
	_build_rows()
	_update_states()
	_setup_navigation()
	_setup_date_display()
	if not GameState.intro_seen:
		_show_intro()
	elif _homecoming_worth_showing(GameState.pending_homecoming):
		_show_homecoming(GameState.pending_homecoming)
	GameState.pending_homecoming = {}


## One line under the title that keeps the campaign goal in view.
func _build_quest_strip() -> void:
	var strip := Label.new()
	strip.theme_type_variation = &"SubtitleLabel"
	strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.text = _quest_text()
	strip.add_theme_color_override("font_color", UIColors.TITLE_GOLD)
	_content.add_child(strip)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(gap)


func _quest_text() -> String:
	var final_boss := MonsterDatabase.get_boss_for_floor(GameState.FINAL_FLOOR)
	var final_name := final_boss.monster_name if final_boss else "the master of the depths"
	if GameState.has_won():
		return "%s was slain on %s" % [final_name, GameCalendar.format_date(GameState.victory_day)]
	var boss_floors := GameState.get_boss_floors()
	var slain := 0
	for f in boss_floors:
		if GameState.is_boss_slain(f):
			slain += 1
	var deepest := "Not yet entered" if GameState.deepest_floor <= 0 \
		else "Deepest floor %d of %d" % [GameState.deepest_floor, GameState.FINAL_FLOOR]
	return "Slay %s  ·  %s  ·  Guardians slain %d of %d" % [
		final_name.get_slice(" ", 0), deepest, slain, boss_floors.size()]


## The opening premise, shown once per campaign on first arrival in town.
func _show_intro() -> void:
	var final_boss := MonsterDatabase.get_boss_for_floor(GameState.FINAL_FLOOR)
	var final_name := final_boss.monster_name if final_boss else "a drake"
	var floors: Array[String] = []
	for f in GameState.get_boss_floors():
		floors.append(str(f))
	var floor_list := ", ".join(floors.slice(0, -1)) + " and " + floors[-1] if floors.size() > 1 \
		else ", ".join(floors)

	var col := _open_modal("The Guild Charter")
	var paragraphs: Array[String] = [
		"Beneath the town lies a dungeon %d floors deep. In its lowest chamber sleeps %s, and for as long as anyone can remember its servants have crept up through the halls above." % [GameState.FINAL_FLOOR, final_name],
		"The council has chartered your guild to end it. Six adventurers have already signed on. Outfit them at the Shop, rest them at the Inn, and go below. Guardians wait on floors %s, and the last of them is the drake itself." % floor_list,
		"One more thing. Time runs faster the deeper you go. A day on the first floor is a day, but the deep halls can take years off a life in a few days, and those who stay in town don't age with them. Choose who you send with care.",
	]
	for text in paragraphs:
		col.add_child(_modal_paragraph(text))
	_add_modal_button(col, "Begin", func() -> void: GameState.intro_seen = true)


## Short trips to the shallow floors don't warrant a report.
func _homecoming_worth_showing(report: Dictionary) -> bool:
	if report.is_empty():
		return false
	if int(report.get("deep_days", 0)) >= GameCalendar.DAYS_PER_MONTH:
		return true
	if not report.get("legends", []).is_empty():
		return true
	for row: Dictionary in report.get("members", []):
		if row["died_of_age"] or row["phase_after"] != row["phase_before"]:
			return true
	return false


## What the trip below cost, in years. Shown once on returning to town.
func _show_homecoming(report: Dictionary) -> void:
	var col := _open_modal("Home Again")
	var surface: int = report.get("surface_days", 0)
	var deep: int = report.get("deep_days", 0)
	var lead := "By the town's reckoning the party was gone %s. Below, %s went by." % [
		"less than a day" if surface <= 0 else _span(surface), _span(maxi(deep, surface))]
	col.add_child(_modal_paragraph(lead))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(grid)

	var notes: Array[String] = []
	for row: Dictionary in report.get("members", []):
		var c: Character = row["character"]
		var years_before: int = row["age_before"] / CharacterEnums.DAYS_PER_YEAR
		var years_after: int = row["age_after"] / CharacterEnums.DAYS_PER_YEAR
		var changed: bool = row["phase_after"] != row["phase_before"]

		var name_lbl := Label.new()
		name_lbl.theme_type_variation = &"SubheaderLabel"
		name_lbl.text = c.character_name
		grid.add_child(name_lbl)

		var age_lbl := Label.new()
		age_lbl.text = "%d  →  %d" % [years_before, years_after] if years_after != years_before \
			else "%d" % years_after
		grid.add_child(age_lbl)

		var phase_lbl := Label.new()
		phase_lbl.theme_type_variation = &"MutedLabel"
		phase_lbl.text = CharacterEnums.get_life_phase_name(row["phase_after"])
		if changed or row["died_of_age"]:
			phase_lbl.add_theme_color_override("font_color", UIColors.TITLE_GOLD)
		if row["died_of_age"]:
			phase_lbl.text = "Died"
			name_lbl.add_theme_color_override("font_color", UIColors.TEXT_MUTED)
		if row.get("legend", false):
			phase_lbl.text = "Legend"
			phase_lbl.add_theme_color_override("font_color", UIColors.TITLE_GOLD)
			name_lbl.add_theme_color_override("font_color", UIColors.TITLE_GOLD)
		grid.add_child(phase_lbl)

		if row["died_of_age"]:
			notes.append("%s made it up the last stair and sat down to rest, and didn't get up again. Dead of old age at %d." % [c.character_name, years_after])
		elif changed and not row.get("legend", false):
			var note := _phase_note(c.character_name, row["phase_after"])
			var gained := AgeTraits.gained_on(c, row["phase_after"])
			if gained != "":
				note += " (%s)" % gained
			notes.append(note)

	for legend: Dictionary in report.get("legends", []):
		notes.append(" ".join(legend["lines"]))
	var banked: int = report.get("gold_banked", 0)
	if banked > 0:
		col.add_child(_modal_paragraph("The party brought %d gold up with them, and it's gone into the guild's coffers." % banked))
	for note in notes:
		var p := _modal_paragraph(note)
		p.add_theme_color_override("font_color", UIColors.TITLE_GOLD)
		col.add_child(p)
	_add_modal_button(col, "Continue")


func _phase_note(who: String, phase: CharacterEnums.LifePhase) -> String:
	match phase:
		CharacterEnums.LifePhase.PRIME:
			return "%s has come into the prime of life." % who
		CharacterEnums.LifePhase.DECLINE:
			return "%s came back with gray at the temples. The veteran years have begun, and the body won't be as quick from here on." % who
		CharacterEnums.LifePhase.FRAGILE:
			return "%s came back an elder. There's no telling how many more trips down are left." % who
	return ""


## A length of time in the largest unit that reads naturally.
static func _span(days: int) -> String:
	var year := CharacterEnums.DAYS_PER_YEAR
	var month := GameCalendar.DAYS_PER_MONTH
	if days >= year:
		var y := days / year
		var m := (days % year) / month
		var text := "%d year%s" % [y, "" if y == 1 else "s"]
		if y < 5 and m > 0:
			text += " and %d month%s" % [m, "" if m == 1 else "s"]
		return text
	if days >= month:
		var m := days / month
		return "%d month%s" % [m, "" if m == 1 else "s"]
	if days >= 7:
		var w := days / 7
		return "%d week%s" % [w, "" if w == 1 else "s"]
	return "%d day%s" % [days, "" if days == 1 else "s"]


## Opens a centered modal panel above the menu and returns its column.
func _open_modal(title_text: String) -> VBoxContainer:
	# A CanvasLayer keeps the modal above the menu cursor and its effects.
	_modal = CanvasLayer.new()
	_modal.layer = 10
	add_child(_modal)

	var dim := ColorRect.new()
	dim.color = UIColors.SURFACE_MODAL_OVERLAY
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Controls under a CanvasLayer don't inherit the root window's theme.
	center.theme = get_tree().root.theme
	_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var divider := ArcaneDivider.new()
	divider.custom_minimum_size = Vector2(320, 14)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(divider)
	return col


func _modal_paragraph(text: String) -> Label:
	var p := Label.new()
	p.theme_type_variation = &"SubtitleLabel"
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.custom_minimum_size = Vector2(560, 0)
	p.text = text
	return p


var _modal_on_close: Callable = Callable()


func _add_modal_button(col: VBoxContainer, text: String, on_close: Callable = Callable()) -> void:
	_modal_on_close = on_close
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"PrimaryButton"
	button.custom_minimum_size = Vector2(200, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_close_modal)
	col.add_child(button)
	button.grab_focus.call_deferred()


func _close_modal() -> void:
	if _modal == null:
		return
	if _modal_on_close.is_valid():
		_modal_on_close.call()
	_modal_on_close = Callable()
	AudioManager.play_ui("confirm")
	_modal.queue_free()
	_modal = null
	if nav:
		nav.update_focus()


func _build_rows() -> void:
	for d in DESTS:
		# AutoExplore is a balancing tool: it stocks free test potions and can
		# refight bosses, so it stays out of release builds.
		if d.get("debug_only", false) and not OS.is_debug_build():
			continue
		if d.get("primary", false):
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 10)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_content.add_child(gap)
		var b := _make_row(d)
		b.pressed.connect(_on_dest.bind(d["id"]))
		_content.add_child(b)
		_rows.append(b)
		_meta.append(d)


func _make_row(d: Dictionary) -> Button:
	var primary: bool = d.get("primary", false)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 60)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if primary:
		b.theme_type_variation = &"PrimaryButton"

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18.0
	row.offset_right = -18.0
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)

	var badge := RuneBadge.new()
	badge.custom_minimum_size = Vector2(34, 34)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.kind = d["badge"]
	if primary:
		badge.color = Color(0.97, 0.95, 0.88, 0.95)
	row.add_child(badge)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	var name_lbl := Label.new()
	name_lbl.text = d["name"]
	name_lbl.theme_type_variation = &"SubheaderLabel"
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if primary:
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
	col.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = d["desc"]
	desc_lbl.theme_type_variation = &"MutedLabel"
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if primary:
		desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.96))
	col.add_child(desc_lbl)

	return b


func _on_dest(id: String) -> void:
	match id:
		"guild": SceneManager.go_to_guild_hall()
		"shop": SceneManager.go_to_shop()
		"party": SceneManager.go_to_party_menu()
		"inn": SceneManager.go_to_inn()
		"temple": SceneManager.go_to_temple()
		"autoexplore": SceneManager.go_to_autoexplore()
		"dungeon": SceneManager.go_to_dungeon()
		"menu": SceneManager.go_to_main_menu()


func _update_states() -> void:
	var has_party := GameState.has_party()
	for i in _rows.size():
		var disabled: bool = _meta[i].get("needs_party", false) and not has_party
		_rows[i].disabled = disabled
		_rows[i].modulate = Color(0.5, 0.5, 0.55) if disabled else Color.WHITE

	var has_gold := GameState.party != null
	_gold_box.visible = has_gold
	_gold_sep.visible = has_gold
	if has_gold:
		_gold_box.get_node("GoldValue").text = str(GameState.party.gold)


func _setup_navigation() -> void:
	var buttons: Array[Button] = []
	for b in _rows:
		buttons.append(b)
	nav = MenuNavigator.new()
	nav.setup(buttons, 0)


func _setup_date_display() -> void:
	_day_label.hide()
	var date_info := GameCalendar.create_date_grid(GameState.game_day)
	var grid: GridContainer = date_info["grid"]
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_day_label.get_parent().add_child(grid)
	_day_label.get_parent().move_child(grid, _day_label.get_index())


func _unhandled_input(event: InputEvent) -> void:
	if _modal != null:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_modal()
		return
	if nav:
		nav.handle_input(event)
