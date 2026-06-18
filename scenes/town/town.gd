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
		"desc": "Simulate dungeon runs to test your party", "needs_party": true},
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


func _ready() -> void:
	_build_rows()
	_update_states()
	_setup_navigation()
	_setup_date_display()


func _build_rows() -> void:
	for d in DESTS:
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
	if nav:
		nav.handle_input(event)
