class_name MenuListRow
extends Button

## A focusable, card-styled list row for menu lists: a color-coded badge, a
## title + subtitle, and a cluster of right-aligned chips. Drop it where a plain
## text Button used to live — it keeps Button focus/press behaviour (so
## MenuNavigator still drives it) but reads like the character dossier.
##
## Build with `MenuListRow.create(cfg)` where cfg is a Dictionary:
##   badge: String            short 1-2 char glyph (optional)
##   badge_color: Color       crest tint for the badge
##   title: String            primary line
##   title_color: Color       optional override
##   subtitle: String         muted secondary line (optional)
##   chips: Array             of {text, fg, bg} dictionaries (optional)
##   dim: bool                render recessed (unavailable/locked)

const ROW_HEIGHT := 46


static func create(cfg: Dictionary) -> MenuListRow:
	var row := MenuListRow.new()
	row._build(cfg)
	return row


func _build(cfg: Dictionary) -> void:
	text = ""
	custom_minimum_size = Vector2(0, ROW_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true

	var dim: bool = cfg.get("dim", false)

	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_right = -12
	box.offset_top = 4
	box.offset_bottom = -4
	box.add_theme_constant_override("separation", 11)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var badge: String = cfg.get("badge", "")
	if badge != "":
		box.add_child(_make_badge(badge, cfg.get("badge_color", UIColors.ACCENT), dim))

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)

	var title := Label.new()
	title.text = cfg.get("title", "")
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_color: Color = cfg.get("title_color", UIColors.TEXT_DISABLED if dim else UIColors.TEXT_PRIMARY)
	title.add_theme_color_override("font_color", title_color)
	col.add_child(title)

	var subtitle: String = cfg.get("subtitle", "")
	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sub.theme_type_variation = &"MutedLabel"
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(sub)

	var chips: Array = cfg.get("chips", [])
	if not chips.is_empty():
		var chip_box := HBoxContainer.new()
		chip_box.add_theme_constant_override("separation", 5)
		chip_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for chip in chips:
			var c: Dictionary = chip
			chip_box.add_child(_make_pill(
				c.get("text", ""),
				c.get("fg", UIColors.TEXT_PRIMARY),
				c.get("bg", UIColors.SURFACE_SELECTED)))
		box.add_child(chip_box)


func _make_badge(glyph: String, color: Color, dim: bool) -> Label:
	var b := Label.new()
	b.text = glyph
	b.custom_minimum_size = Vector2(32, 32)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", (color.lightened(0.45) if not dim else UIColors.TEXT_MUTED))
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.55) if not dim else UIColors.SURFACE_PRESSED
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = color if not dim else UIColors.BORDER_DEFAULT
	b.add_theme_stylebox_override("normal", sb)
	return b


func _make_pill(text_value: String, fg: Color, bg: Color) -> Label:
	var p := Label.new()
	p.text = text_value
	p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_font_size_override("font_size", 12)
	p.add_theme_color_override("font_color", fg)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	sb.set_border_width_all(1)
	sb.border_color = UIColors.BORDER_SUBTLE
	p.add_theme_stylebox_override("normal", sb)
	return p
