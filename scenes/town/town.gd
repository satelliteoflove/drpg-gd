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
	_homecoming = GameState.pending_homecoming
	GameState.pending_homecoming = {}
	if not GameState.intro_seen:
		_show_intro()
	elif not GameState.pending_collapse.is_empty():
		_show_collapse(GameState.pending_collapse)
		GameState.pending_collapse = {}
	else:
		_show_homecoming_if_due()


## The last trip's report, held while a collapse card is up.
var _homecoming: Dictionary = {}


func _show_homecoming_if_due() -> void:
	if _homecoming_worth_showing(_homecoming):
		_show_homecoming.call_deferred(_homecoming)
	_homecoming = {}


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
	var dungeon_set := GameState.dungeon_set
	var total := dungeon_set.dungeons.size()
	var fallen := dungeon_set.collapsed_count()
	var text := ""
	if dungeon_set.final_dungeon and not dungeon_set.final_dungeon.is_collapsed():
		text = "All %d dungeons have collapsed  ·  %s has opened" % [total, dungeon_set.final_dungeon.dungeon_name]
	elif fallen == 0:
		text = "%d dungeons stand  ·  Slay each one's master to bring it down" % total
	else:
		text = "%d of %d dungeons collapsed  ·  Their power has gathered in the rest" % [fallen, total]
	if GameState.has_won():
		text += "  ·  Set %d" % dungeon_set.set_number
	return text


## The opening premise, shown once per campaign on first arrival in town.
func _show_intro() -> void:
	var dungeon_set := GameState.dungeon_set
	var names: Array[String] = []
	for d in dungeon_set.dungeons:
		names.append(d.dungeon_name)
	var name_list := ", ".join(names.slice(0, -1)) + " and " + names[-1]

	var col := _open_modal("The Guild Charter")
	var paragraphs: Array[String] = [
		"%d dungeons have opened beneath the town: %s. Each goes down %d floors, and at the bottom of each a master sleeps, whose servants creep up through the halls above." % [
			names.size(), name_list, dungeon_set.dungeons[0].depth],
		"The council has chartered your guild to end them. Six adventurers have already signed on. Outfit them at the Shop, rest them at the Inn, and go below, into whichever dungeon you choose. Guardians seal the stairs on the way down. Slay a master and its dungeon collapses, but its power pours into the dungeons that remain, deepest first.",
		"One more thing. Time runs faster the deeper you go. A day on the first floor is a day, but the deep halls can take years off a life in a few days, and those who stay in town don't age with them. Choose who you send with care.",
	]
	for text in paragraphs:
		col.add_child(_modal_paragraph(text))
	_add_modal_button(col, "Begin", func() -> void: GameState.intro_seen = true)


## What a master's fall brought down, and what it means for the rest.
func _show_collapse(report: Dictionary) -> void:
	var col := _open_modal("%s Has Collapsed" % report.get("dungeon", "The Dungeon"))
	col.add_child(_modal_paragraph("%s is dead, and the dungeon came down behind the party as it cast them out. Nothing is left of it but a scar in the hillside." % report.get("master", "Its master")))
	var lost: Array = report.get("lost", [])
	if not lost.is_empty():
		var p := _modal_paragraph("%s still lay below when it fell, and won't be seen again." % ", ".join(lost))
		p.add_theme_color_override("font_color", UIColors.TEXT_DANGER)
		col.add_child(p)
	var note := ""
	if report.get("new_set", false):
		note = "The quiet doesn't last. Before the season is out, four new dungeons have opened beneath the town, deeper in malice than the last."
	elif report.get("final_opened", false):
		note = "With the last of the four gone, the ground has opened once more. %s lies beneath them all, a single great hall, and what waits there is what woke the others." % GameState.dungeon_set.final_dungeon.dungeon_name
	else:
		var fallen: int = report.get("collapsed", 0)
		var total: int = report.get("total", 4)
		note = "%d of %d dungeons have collapsed. The power that held this one up has poured into those that remain, and it pools in their depths. Their upper floors are as they were. The deep ones are worse." % [fallen, total]
	var note_label := _modal_paragraph(note)
	note_label.add_theme_color_override("font_color", UIColors.TITLE_GOLD)
	col.add_child(note_label)
	_add_modal_button(col, "Continue", _show_homecoming_if_due)


## Lets the player pick which dungeon to enter.
func _show_dungeon_picker() -> void:
	var open := GameState.dungeon_set.open_dungeons()
	if open.size() <= 1:
		_enter_dungeon(open[0] if not open.is_empty() else null)
		return
	var col := _open_modal("Which Dungeon?")
	var fallen := GameState.dungeon_set.collapsed_count()
	if fallen > 0:
		col.add_child(_modal_paragraph("%d of %d have collapsed, and their power has gathered in the depths of the rest." % [
			fallen, GameState.dungeon_set.dungeons.size()]))
	_choice_buttons.clear()
	for dungeon in open:
		var button := Button.new()
		var reached := "not yet entered" if dungeon.deepest_floor <= 0 \
			else "deepest floor %d of %d" % [dungeon.deepest_floor, dungeon.depth]
		button.text = "%s   ·   %s" % [dungeon.dungeon_name, reached]
		button.custom_minimum_size = Vector2(480, 44)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_dungeon_picked.bind(dungeon))
		col.add_child(button)
		_choice_buttons.append(button)
	var cancel := Button.new()
	cancel.text = "Not yet"
	cancel.custom_minimum_size = Vector2(200, 40)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(_close_modal)
	col.add_child(cancel)
	_choice_buttons.append(cancel)
	_choice_nav = MenuNavigator.new()
	_choice_nav.setup(_choice_buttons, 0)


var _choice_buttons: Array[Button] = []
var _choice_nav: MenuNavigator = null


func _on_dungeon_picked(dungeon: Dungeon) -> void:
	_close_modal()
	_enter_dungeon(dungeon)


func _enter_dungeon(dungeon: Dungeon) -> void:
	if dungeon:
		GameState.destination_dungeon_id = dungeon.id
	SceneManager.go_to_dungeon()


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
	var on_close := _modal_on_close
	_modal_on_close = Callable()
	_choice_buttons.clear()
	_choice_nav = null
	AudioManager.play_ui("confirm")
	_modal.queue_free()
	_modal = null
	if on_close.is_valid():
		on_close.call()
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
		"dungeon": _show_dungeon_picker()
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
	if _modal != null and _choice_nav != null:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu_cancel"):
			get_viewport().set_input_as_handled()
			_close_modal()
		else:
			_choice_nav.handle_input(event)
		return
	if _modal != null:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_modal()
		return
	if nav:
		nav.handle_input(event)
