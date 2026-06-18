class_name ScreenScaffold extends Control

## The shared chrome every town / party / character screen wears, so they all
## read as one place. Drop it in as the screen's content host:
##
##   var scaffold := ScreenScaffold.create({"title": "INN", "hint": "..."})
##   add_child(scaffold)
##   scaffold.back_pressed.connect(_on_back)
##   scaffold.body.add_child(my_content)   # body is a MarginContainer
##
## It provides: a living arcane backdrop, a top-bar pill (back affordance +
## gold Cinzel screen title + live date + live gold/scrap), a framed body
## region, and a bottom hint line. Gold/scrap track the active party live.

signal back_pressed

# Content is held a consistent gap INSIDE the golden ArcaneFrame corners (which
# sit at inset 16), so the engraved brackets frame the screen rather than
# colliding with the panel edges. Keep these >= the frame inset + a margin.
const TOP_INSET := 30.0
const SIDE_INSET := 30.0
const BODY_TOP := 116.0     # clears the top-bar pill (which spans ~30..102)
const BODY_BOTTOM := 58.0   # clears the hint line and the bottom frame corners

var body: MarginContainer

var _title := ""
var _hint := ""
var _subdued := true
var _hero := false          # full torches/embers backdrop (town/menu feel)
var _show_back := true
var _show_gold := true
var _show_scrap := false

var _title_label: Label
var _gold_value: Label
var _scrap_box: HBoxContainer
var _scrap_value: Label
var _gold_sep: VSeparator
var _date_host: HBoxContainer
var _date_labels: Dictionary = {}
var _hint_label: Label


static func create(opts: Dictionary = {}) -> ScreenScaffold:
	var s := ScreenScaffold.new()
	s._title = opts.get("title", "")
	s._hint = opts.get("hint", "")
	s._subdued = opts.get("subdued", true)
	s._hero = opts.get("hero", false)
	s._show_back = opts.get("show_back", true)
	s._show_gold = opts.get("show_gold", true)
	s._show_scrap = opts.get("show_scrap", false)
	s._build()
	return s


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 1. Living backdrop (behind everything).
	var backdrop := ArcaneBackdrop.new()
	backdrop.subdued = _subdued and not _hero
	add_child(backdrop)

	# 2. Body region — where the screen parents its content.
	body = MarginContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = SIDE_INSET
	body.offset_right = -SIDE_INSET
	body.offset_top = BODY_TOP
	body.offset_bottom = -BODY_BOTTOM
	add_child(body)

	# 3. Top-bar pill.
	add_child(_build_top_bar())

	# 4. Engraved corner frame (on top of content).
	var frame := ArcaneFrame.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	# 5. Bottom hint line.
	_hint_label = Label.new()
	_hint_label.theme_type_variation = &"MutedLabel"
	_hint_label.text = _hint
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_left = SIDE_INSET
	_hint_label.offset_right = -SIDE_INSET
	_hint_label.offset_top = -52.0
	_hint_label.offset_bottom = -30.0
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)


func _build_top_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = SIDE_INSET
	bar.offset_right = -SIDE_INSET
	bar.offset_top = TOP_INSET

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	bar.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	if _show_back:
		var back := Button.new()
		back.text = "‹  Back"
		back.focus_mode = Control.FOCUS_NONE
		back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		back.pressed.connect(func() -> void: back_pressed.emit())
		row.add_child(back)

	_title_label = Label.new()
	_title_label.theme_type_variation = &"HeaderLabel"
	_title_label.text = _title
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	_date_host = HBoxContainer.new()
	_date_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_date_host.add_theme_constant_override("separation", 8)
	row.add_child(_date_host)

	if _show_gold:
		_gold_sep = VSeparator.new()
		row.add_child(_gold_sep)
		row.add_child(_build_coin_box("GOLD", UIColors.GOLD))

	if _show_scrap:
		row.add_child(VSeparator.new())
		_scrap_box = _build_coin_box("SCRAP", UIColors.TEXT_SECONDARY, true)
		row.add_child(_scrap_box)

	return bar


func _build_coin_box(caption: String, value_color: Color, is_scrap: bool = false) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 6)

	var cap := Label.new()
	cap.theme_type_variation = &"MutedLabel"
	cap.text = caption
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(cap)

	var value := Label.new()
	value.add_theme_color_override("font_color", value_color)
	value.add_theme_font_size_override("font_size", 17)
	value.text = "0"
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(value)

	if is_scrap:
		_scrap_value = value
	else:
		_gold_value = value
	return box


func _ready() -> void:
	_init_date()
	_refresh_coins()
	var party := _party()
	if party != null:
		if not party.gold_changed.is_connected(_on_gold_changed):
			party.gold_changed.connect(_on_gold_changed)
		if not party.scrap_changed.is_connected(_on_scrap_changed):
			party.scrap_changed.connect(_on_scrap_changed)


func _exit_tree() -> void:
	var party := _party()
	if party != null:
		if party.gold_changed.is_connected(_on_gold_changed):
			party.gold_changed.disconnect(_on_gold_changed)
		if party.scrap_changed.is_connected(_on_scrap_changed):
			party.scrap_changed.disconnect(_on_scrap_changed)


func _party() -> Party:
	return GameState.party if GameState.party != null else null


func _init_date() -> void:
	if _date_host == null:
		return
	_date_labels = GameCalendar.create_date_grid(GameState.game_day)
	var grid: GridContainer = _date_labels["grid"]
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_date_host.add_child(grid)


func _refresh_coins() -> void:
	var party := _party()
	var has_party := party != null
	if _gold_value != null:
		_gold_value.get_parent().visible = has_party
		if _gold_sep != null:
			_gold_sep.visible = has_party
		if has_party:
			_gold_value.text = str(party.gold)
	if _scrap_value != null and has_party:
		_scrap_value.text = str(party.scrap)


func _on_gold_changed(amount: int) -> void:
	if _gold_value != null:
		_gold_value.text = str(amount)


func _on_scrap_changed(amount: int) -> void:
	if _scrap_value != null:
		_scrap_value.text = str(amount)


# --- Public API -------------------------------------------------------------

func set_title(value: String) -> void:
	_title = value
	if _title_label != null:
		_title_label.text = value


func set_hint(value: String) -> void:
	_hint = value
	if _hint_label != null:
		_hint_label.text = value


## Call after advancing the calendar so the date pill reflects the new day.
func refresh_date() -> void:
	if not _date_labels.is_empty():
		GameCalendar.update_date_labels(_date_labels, GameState.game_day)
