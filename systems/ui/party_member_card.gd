class_name PartyMemberCard extends PanelContainer

## The one canonical "who is this party member" card, used wherever a member is
## shown as a row: Inn, Temple, Shop comparison, Party status, Guild Hall.
## A class crest, name + "L<lvl> <race> <class>", live HP/MP bars, and status
## chips (DEAD / FRONT / BACK / afflictions). Display-only.
##
##   var card := PartyMemberCard.create(member, {"show_row": true})
##
## opts:
##   show_bars: bool   HP/MP bars (default true; auto-hidden for the dead)
##   show_row:  bool   FRONT / BACK position chip (default false)
##   index:     int    position used for the FRONT/BACK chip when show_row

const MINOR_STATUSES: Array[CharacterEnums.StatusEffect] = [
	CharacterEnums.StatusEffect.POISONED,
	CharacterEnums.StatusEffect.ASLEEP,
	CharacterEnums.StatusEffect.CONFUSED,
	CharacterEnums.StatusEffect.SILENCED,
	CharacterEnums.StatusEffect.AFRAID,
	CharacterEnums.StatusEffect.PARALYZED,
]

var member: Character


static func create(p_member: Character, opts: Dictionary = {}) -> PartyMemberCard:
	var card := PartyMemberCard.new()
	card.member = p_member
	card._build(opts)
	return card


func _build(opts: Dictionary) -> void:
	var show_bars: bool = opts.get("show_bars", true)
	var show_row: bool = opts.get("show_row", false)
	var index: int = opts.get("index", -1)
	var dead: bool = member.is_dead

	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _card_style(dead))

	var crest_color := UIColors.class_color(member.character_class)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 11)
	margin.add_child(row)

	# Class crest.
	row.add_child(_crest(crest_color, dead))

	# Name / subtitle / bars column.
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)

	# Title line: name + status chips.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	col.add_child(title_row)

	var name_lbl := Label.new()
	name_lbl.text = member.character_name
	name_lbl.add_theme_color_override(
		"font_color", UIColors.TEXT_DANGER if dead else UIColors.TEXT_PRIMARY)
	title_row.add_child(name_lbl)

	var chip_spacer := Control.new()
	chip_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(chip_spacer)

	for chip in _status_chips(dead, show_row, index):
		title_row.add_child(_pill(chip["text"], chip["fg"], chip["bg"]))

	# Subtitle: L<lvl> <race> <class>.
	var sub := Label.new()
	sub.theme_type_variation = &"MutedLabel"
	sub.text = "L%d  %s  %s" % [
		member.level,
		CharacterEnums.get_race_name(member.race),
		CharacterEnums.get_class_name(member.character_class)]
	col.add_child(sub)

	# Resource bars — always rendered (living AND dead, HP AND MP even at 0/0)
	# so every card is exactly the same height and reads consistently across
	# every screen. A dead member shows an empty red HP bar.
	if show_bars:
		var bars := HBoxContainer.new()
		bars.add_theme_constant_override("separation", 10)
		bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(bars)
		var hp_fill := UIColors.DANGER if dead else _hp_color(member)
		var hp_cur := 0 if dead else member.current_hp
		bars.add_child(_resource_bar("HP", hp_cur, member.max_hp, hp_fill))
		bars.add_child(_resource_bar("MP", member.current_mp, member.max_mp, UIColors.MP_BLUE))

	if dead:
		modulate = Color(0.82, 0.78, 0.80)


func _card_style(dead: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.SURFACE_CARD
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = UIColors.DANGER.darkened(0.2) if dead else UIColors.BORDER_SUBTLE
	sb.anti_aliasing = true
	return sb


func _crest(color: Color, dead: bool) -> Label:
	var b := Label.new()
	b.text = CharacterEnums.get_class_name(member.character_class).substr(0, 1).to_upper()
	b.custom_minimum_size = Vector2(34, 34)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override(
		"font_color", UIColors.TEXT_MUTED if dead else color.lightened(0.45))
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.SURFACE_PRESSED if dead else color.darkened(0.55)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = UIColors.BORDER_DEFAULT if dead else color
	b.add_theme_stylebox_override("normal", sb)
	return b


func _resource_bar(caption: String, cur: int, maxv: int, fill: Color) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 11)
	cap.add_theme_color_override("font_color", UIColors.TEXT_MUTED)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(cap)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.min_value = 0
	bar.max_value = maxi(maxv, 1)
	bar.value = cur
	bar.show_percentage = false
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = fill
	fill_sb.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill_sb)

	var val := Label.new()
	val.text = "%d/%d" % [cur, maxv]
	val.add_theme_font_size_override("font_size", 11)
	val.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(val)

	box.add_child(bar)
	return box


func _status_chips(dead: bool, show_row: bool, index: int) -> Array:
	var chips: Array = []
	if dead:
		if member.has_status(CharacterEnums.StatusEffect.LOST):
			chips.append({"text": "LOST", "fg": Color.WHITE, "bg": UIColors.TEXT_LOST})
		elif member.has_status(CharacterEnums.StatusEffect.ASHED):
			chips.append({"text": "ASHED", "fg": Color.WHITE, "bg": UIColors.WARNING.darkened(0.25)})
		else:
			chips.append({"text": "DEAD", "fg": Color.WHITE, "bg": UIColors.DANGER.darkened(0.15)})
	else:
		var afflictions := _affliction_names()
		if not afflictions.is_empty():
			var label := afflictions[0] if afflictions.size() == 1 \
				else "%s +%d" % [afflictions[0], afflictions.size() - 1]
			chips.append({"text": label.to_upper(),
				"fg": UIColors.TEXT_WARNING, "bg": UIColors.SURFACE_SELECTED})
	if show_row and index >= 0:
		if index < Party.FRONT_ROW_SIZE:
			chips.append({"text": "FRONT", "fg": UIColors.FRONT_ROW, "bg": UIColors.SURFACE_SELECTED})
		else:
			chips.append({"text": "BACK", "fg": UIColors.BACK_ROW, "bg": UIColors.SURFACE_SELECTED})
	return chips


func _affliction_names() -> Array[String]:
	var names: Array[String] = []
	for status in MINOR_STATUSES:
		if member.has_status(status):
			names.append(CharacterEnums.get_status_name(status))
	return names


func _hp_color(m: Character) -> Color:
	var pct := float(m.current_hp) / float(maxi(m.max_hp, 1))
	if pct < 0.25:
		return UIColors.DANGER
	if pct < 0.5:
		return UIColors.WARNING
	return UIColors.HP_GREEN


func _pill(text_value: String, fg: Color, bg: Color) -> Label:
	var p := Label.new()
	p.text = text_value
	p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_theme_font_size_override("font_size", 11)
	p.add_theme_color_override("font_color", fg)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
