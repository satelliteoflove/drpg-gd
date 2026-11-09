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


var _intro: CanvasLayer = null


func _ready() -> void:
	_build_quest_strip()
	_build_rows()
	_update_states()
	_setup_navigation()
	_setup_date_display()
	if not GameState.intro_seen:
		_show_intro()


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

	# A CanvasLayer keeps the charter above the menu cursor and its effects.
	_intro = CanvasLayer.new()
	_intro.layer = 10
	add_child(_intro)

	var dim := ColorRect.new()
	dim.color = UIColors.SURFACE_MODAL_OVERLAY
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.add_child(center)

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
	title.text = "The Guild Charter"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var divider := ArcaneDivider.new()
	divider.custom_minimum_size = Vector2(320, 14)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(divider)

	var paragraphs: Array[String] = [
		"Beneath the town lies a dungeon %d floors deep. In its lowest chamber sleeps %s, and for as long as anyone can remember its servants have crept up through the halls above." % [GameState.FINAL_FLOOR, final_name],
		"The council has chartered your guild to end it. Recruit at the Guild Hall, outfit your party at the Shop, and go below. Guardians wait on floors %s, and the last of them is the drake itself." % floor_list,
		"Time passes with every step underground and every night at the inn, and your adventurers age with it. Choose who you send with care.",
	]
	for text in paragraphs:
		var p := Label.new()
		p.theme_type_variation = &"SubtitleLabel"
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.custom_minimum_size = Vector2(560, 0)
		p.text = text
		col.add_child(p)

	var begin := Button.new()
	begin.text = "Begin"
	begin.theme_type_variation = &"PrimaryButton"
	begin.custom_minimum_size = Vector2(200, 44)
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	begin.pressed.connect(_dismiss_intro)
	col.add_child(begin)
	begin.grab_focus.call_deferred()


func _dismiss_intro() -> void:
	if _intro == null:
		return
	GameState.intro_seen = true
	AudioManager.play_ui("confirm")
	_intro.queue_free()
	_intro = null
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
	if _intro != null:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_dismiss_intro()
		return
	if nav:
		nav.handle_input(event)
