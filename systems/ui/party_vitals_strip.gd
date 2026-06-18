class_name PartyVitalsStrip extends PanelContainer

## At-a-glance party vitals for the dungeon HUD: a carved-stone band along the
## bottom of the screen with one compact cell per member (class crest, name, and
## live HP/MP bars) so the player can read the marching order's health without
## opening the menu. Call `refresh()` whenever party state may have changed
## (each step, on returning from combat).

var _row: HBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _band_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_row)
	refresh()


func refresh() -> void:
	if _row == null:
		return
	for child in _row.get_children():
		child.queue_free()
	if GameState.party == null:
		return
	var members := GameState.party.get_members()
	for i in range(members.size()):
		_row.add_child(_cell(members[i], i))


func _band_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UIColors.SURFACE_PANEL.r, UIColors.SURFACE_PANEL.g, UIColors.SURFACE_PANEL.b, 0.92)
	sb.set_corner_radius_all(UITheme.RADIUS_PANEL)
	sb.border_width_top = 2
	sb.border_color = UIColors.TITLE_GOLD_DIM
	sb.shadow_color = UIColors.SHADOW
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, -2)
	sb.anti_aliasing = true
	return sb


func _cell(member: Character, index: int) -> PanelContainer:
	var dead: bool = member.is_dead
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _cell_style(dead))

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 8)
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_top", 4)
	pad.add_theme_constant_override("margin_bottom", 4)
	card.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	pad.add_child(col)

	# Header: class crest + name.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	head.add_child(_crest(member, dead))

	var name_lbl := Label.new()
	name_lbl.text = member.character_name
	name_lbl.clip_text = true
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override(
		"font_color", UIColors.TEXT_DANGER if dead else UIColors.TEXT_PRIMARY)
	head.add_child(name_lbl)

	# Bars: HP then MP, value overlaid.
	var hp_fill := UIColors.DANGER if dead else _hp_color(member)
	var hp_cur := 0 if dead else member.current_hp
	col.add_child(_bar(hp_cur, member.max_hp, hp_fill, 11))
	col.add_child(_bar(member.current_mp, member.max_mp, UIColors.MP_BLUE, 9))

	if dead:
		card.modulate = Color(0.82, 0.78, 0.80)
	return card


func _cell_style(dead: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.SURFACE_CARD
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = UIColors.DANGER.darkened(0.2) if dead else UIColors.BORDER_SUBTLE
	sb.anti_aliasing = true
	return sb


func _crest(member: Character, dead: bool) -> Label:
	var color := UIColors.class_color(member.character_class)
	var b := Label.new()
	b.text = CharacterEnums.get_class_name(member.character_class).substr(0, 1).to_upper()
	b.custom_minimum_size = Vector2(20, 20)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override(
		"font_color", UIColors.TEXT_MUTED if dead else color.lightened(0.45))
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.SURFACE_PRESSED if dead else color.darkened(0.55)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = UIColors.BORDER_DEFAULT if dead else color
	b.add_theme_stylebox_override("normal", sb)
	return b


func _bar(cur: int, maxv: int, fill: Color, height: int) -> Control:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.min_value = 0
	bar.max_value = maxi(maxv, 1)
	bar.value = cur
	bar.show_percentage = false
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = fill
	fill_sb.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_sb)

	var val := Label.new()
	val.text = "%d/%d" % [cur, maxv]
	val.add_theme_font_size_override("font_size", 10)
	val.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	val.add_theme_color_override("font_outline_color", UIColors.SURFACE_BACKGROUND)
	val.add_theme_constant_override("outline_size", 3)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(val)
	return bar


func _hp_color(m: Character) -> Color:
	var pct := float(m.current_hp) / float(maxi(m.max_hp, 1))
	if pct < 0.25:
		return UIColors.DANGER
	if pct < 0.5:
		return UIColors.WARNING
	return UIColors.HP_GREEN
