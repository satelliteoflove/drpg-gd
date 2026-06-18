class_name ItemDetailView
extends RefCounted

## The Shop's right-hand detail surface (reusable by the Inventory tab later).
## At any moment it shows EITHER a rich item dossier — rarity crest + name,
## description, stats, requirements, the mode-specific transaction line, and a
## "who can use this" party-fit list for equipment, all in one card — OR a
## centered context card for guidance ("Select an item to buy."). One or the
## other, so the space is always either richly filled or a tidy card, never a
## stranded line of text in a cavernous grey box.
##
##   var detail := ItemDetailView.new(right_panel_control)
##   detail.show_item(item, body_bbcode, fit_rows)   # fit_rows: Array[Control]
##   detail.show_text("[b]Buy[/b]\n\nSelect an item to view its details.")
##
## The mount must be a plain Control (not a Container) sized by its own parent;
## the scrolling dossier and the centered card both anchor to fill it.

var _scroll: ScrollContainer
var _badge: Label
var _name: Label
var _type: Label
var _body: RichTextLabel
var _fit_wrap: VBoxContainer
var _fit_list: VBoxContainer
var _card_center: CenterContainer
var _card_label: RichTextLabel


func _init(mount: Control) -> void:
	# --- Dossier layer (scrolls when an item is selected) -------------------
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.visible = false
	mount.add_child(_scroll)

	# Fill + center so a short dossier (a consumable with no party-fit list)
	# rides the vertical centre instead of hugging the top over a void; a tall
	# one (a full equipment comparison) outgrows the viewport, so the scroll
	# container falls back to top-aligned scrolling.
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_scroll.add_child(column)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style())
	column.add_child(card)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	card.add_child(body)

	# Header band: rarity crest + name / type.
	var band := HBoxContainer.new()
	band.add_theme_constant_override("separation", 12)
	body.add_child(band)

	_badge = Label.new()
	_badge.custom_minimum_size = Vector2(34, 34)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge.add_theme_font_size_override("font_size", 15)
	band.add_child(_badge)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_theme_constant_override("separation", 1)
	band.add_child(titles)

	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 18)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_name)

	_type = Label.new()
	_type.theme_type_variation = &"MutedLabel"
	titles.add_child(_type)

	body.add_child(_rule())

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_body)

	# Party-fit section — shown only for equipment.
	_fit_wrap = VBoxContainer.new()
	_fit_wrap.add_theme_constant_override("separation", 8)
	_fit_wrap.visible = false
	body.add_child(_fit_wrap)

	_fit_wrap.add_child(_rule())

	var fit_header := Label.new()
	fit_header.theme_type_variation = &"MutedLabel"
	fit_header.text = "WHO CAN USE THIS"
	_fit_wrap.add_child(fit_header)

	_fit_list = VBoxContainer.new()
	_fit_list.add_theme_constant_override("separation", 4)
	_fit_wrap.add_child(_fit_list)

	# --- Centered context-card layer (guidance / empty state) ---------------
	_card_center = CenterContainer.new()
	_card_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_center.visible = false
	mount.add_child(_card_center)

	var ccard := PanelContainer.new()
	ccard.custom_minimum_size = Vector2(420, 0)
	ccard.add_theme_stylebox_override("panel", _card_style())
	_card_center.add_child(ccard)

	_card_label = RichTextLabel.new()
	_card_label.bbcode_enabled = true
	_card_label.fit_content = true
	_card_label.scroll_active = false
	_card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_label.custom_minimum_size = Vector2(376, 0)
	ccard.add_child(_card_label)


## Show the rich item dossier. body_bbcode carries description/stats/requirements
## plus the mode's transaction line; fit_rows are pre-built party-comparison rows
## (empty for non-equipment, which hides the "who can use this" section).
func show_item(item: Item, body_bbcode: String, fit_rows: Array = []) -> void:
	_card_center.visible = false

	var b := ItemView.badge(item)
	_badge.text = b["text"]
	_apply_badge_tint(b["color"])
	_name.text = item.get_display_name()
	_name.add_theme_color_override("font_color", ItemView.name_color(item))
	_type.text = item.get_type_name()
	_body.text = body_bbcode

	for child in _fit_list.get_children():
		child.queue_free()
	if fit_rows.is_empty():
		_fit_wrap.visible = false
	else:
		for row in fit_rows:
			_fit_list.add_child(row)
		_fit_wrap.visible = true

	_scroll.scroll_vertical = 0
	_scroll.visible = true


## Show a centered context card with bbcode guidance text.
func show_text(text: String) -> void:
	_scroll.visible = false
	_card_label.text = text
	_card_center.visible = true


func _apply_badge_tint(tint: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint.darkened(0.55)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = tint
	_badge.add_theme_stylebox_override("normal", sb)
	_badge.add_theme_color_override("font_color", tint.lightened(0.4))


func _rule() -> HSeparator:
	var sep := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = UIColors.BORDER_SUBTLE
	line.thickness = 1
	sep.add_theme_stylebox_override("separator", line)
	return sep


func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.SURFACE_PANEL
	sb.set_corner_radius_all(UITheme.RADIUS_PANEL)
	sb.set_border_width_all(1)
	sb.border_color = UIColors.BORDER_SUBTLE
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	sb.shadow_color = UIColors.SHADOW
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.anti_aliasing = true
	return sb
