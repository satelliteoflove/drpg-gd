extends Node

var theme: Theme


func _ready() -> void:
	theme = Theme.new()
	_build_panel_container()
	_build_button()
	_build_tab_bar()
	_build_tab_container()
	_build_scrollbar()
	_build_line_edit()
	_build_label()
	get_tree().root.theme = theme


func _build_panel_container() -> void:
	var panel := make_stylebox(
		UIColors.SURFACE_PANEL, 1, UIColors.BORDER_SUBTLE, 4)
	panel.content_margin_left = 6
	panel.content_margin_right = 6
	panel.content_margin_top = 6
	panel.content_margin_bottom = 6
	theme.set_stylebox("panel", "PanelContainer", panel)


func _build_button() -> void:
	var normal := make_stylebox(
		UIColors.SURFACE_PANEL, 1, UIColors.BORDER_DEFAULT, 4)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	theme.set_stylebox("normal", "Button", normal)

	var hover := make_stylebox(
		UIColors.SURFACE_HOVER, 1, UIColors.BORDER_HOVER, 4)
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6
	theme.set_stylebox("hover", "Button", hover)

	var pressed := make_stylebox(
		UIColors.SURFACE_PRESSED, 1, UIColors.BORDER_DEFAULT, 4)
	pressed.content_margin_left = 12
	pressed.content_margin_right = 12
	pressed.content_margin_top = 6
	pressed.content_margin_bottom = 6
	theme.set_stylebox("pressed", "Button", pressed)

	var disabled := make_stylebox(
		UIColors.SURFACE_DISABLED, 1, UIColors.BORDER_SUBTLE, 4)
	disabled.content_margin_left = 12
	disabled.content_margin_right = 12
	disabled.content_margin_top = 6
	disabled.content_margin_bottom = 6
	theme.set_stylebox("disabled", "Button", disabled)

	var focus := make_stylebox(
		UIColors.SURFACE_SELECTED, 0, Color.TRANSPARENT, 4)
	focus.border_width_left = 3
	focus.border_color = UIColors.BORDER_ACCENT
	focus.content_margin_left = 12
	focus.content_margin_right = 12
	focus.content_margin_top = 6
	focus.content_margin_bottom = 6
	theme.set_stylebox("focus", "Button", focus)

	theme.set_color("font_color", "Button", UIColors.TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", UIColors.TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "Button", UIColors.TEXT_DISABLED)
	theme.set_color("font_focus_color", "Button", UIColors.TEXT_PRIMARY)


func _build_tab_bar() -> void:
	var selected := StyleBoxFlat.new()
	selected.bg_color = UIColors.SURFACE_PANEL
	selected.border_width_bottom = 2
	selected.border_color = UIColors.BORDER_ACCENT
	selected.corner_radius_top_left = 4
	selected.corner_radius_top_right = 4
	selected.content_margin_left = 12
	selected.content_margin_right = 12
	selected.content_margin_top = 8
	selected.content_margin_bottom = 8
	theme.set_stylebox("tab_selected", "TabBar", selected)

	var unselected := StyleBoxFlat.new()
	unselected.bg_color = UIColors.SURFACE_BACKGROUND
	unselected.corner_radius_top_left = 4
	unselected.corner_radius_top_right = 4
	unselected.content_margin_left = 12
	unselected.content_margin_right = 12
	unselected.content_margin_top = 8
	unselected.content_margin_bottom = 8
	theme.set_stylebox("tab_unselected", "TabBar", unselected)

	var hovered := StyleBoxFlat.new()
	hovered.bg_color = UIColors.SURFACE_HOVER
	hovered.corner_radius_top_left = 4
	hovered.corner_radius_top_right = 4
	hovered.content_margin_left = 12
	hovered.content_margin_right = 12
	hovered.content_margin_top = 8
	hovered.content_margin_bottom = 8
	theme.set_stylebox("tab_hovered", "TabBar", hovered)

	var tab_focus := StyleBoxFlat.new()
	tab_focus.bg_color = UIColors.SURFACE_SELECTED
	tab_focus.border_width_bottom = 2
	tab_focus.border_color = UIColors.BORDER_FOCUS
	tab_focus.corner_radius_top_left = 4
	tab_focus.corner_radius_top_right = 4
	tab_focus.content_margin_left = 12
	tab_focus.content_margin_right = 12
	tab_focus.content_margin_top = 8
	tab_focus.content_margin_bottom = 8
	theme.set_stylebox("tab_focus", "TabBar", tab_focus)

	theme.set_color("font_selected_color", "TabBar", UIColors.TEXT_PRIMARY)
	theme.set_color("font_unselected_color", "TabBar", UIColors.TEXT_SECONDARY)
	theme.set_color("font_hovered_color", "TabBar", UIColors.TEXT_PRIMARY)


func _build_tab_container() -> void:
	var panel := make_stylebox(
		UIColors.SURFACE_PANEL, 1, UIColors.BORDER_SUBTLE, 4)
	theme.set_stylebox("panel", "TabContainer", panel)


func _build_scrollbar() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = UIColors.SURFACE_BACKGROUND
	bg.content_margin_left = 4
	bg.content_margin_right = 4
	theme.set_stylebox("scroll", "VScrollBar", bg)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = UIColors.BORDER_SUBTLE
	grabber.corner_radius_top_left = 3
	grabber.corner_radius_top_right = 3
	grabber.corner_radius_bottom_left = 3
	grabber.corner_radius_bottom_right = 3
	grabber.content_margin_left = 4
	grabber.content_margin_right = 4
	theme.set_stylebox("grabber", "VScrollBar", grabber)

	var grabber_highlight := StyleBoxFlat.new()
	grabber_highlight.bg_color = UIColors.BORDER_DEFAULT
	grabber_highlight.corner_radius_top_left = 3
	grabber_highlight.corner_radius_top_right = 3
	grabber_highlight.corner_radius_bottom_left = 3
	grabber_highlight.corner_radius_bottom_right = 3
	grabber_highlight.content_margin_left = 4
	grabber_highlight.content_margin_right = 4
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber_highlight)

	var grabber_pressed := StyleBoxFlat.new()
	grabber_pressed.bg_color = UIColors.BORDER_HOVER
	grabber_pressed.corner_radius_top_left = 3
	grabber_pressed.corner_radius_top_right = 3
	grabber_pressed.corner_radius_bottom_left = 3
	grabber_pressed.corner_radius_bottom_right = 3
	grabber_pressed.content_margin_left = 4
	grabber_pressed.content_margin_right = 4
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber_pressed)


func _build_line_edit() -> void:
	var normal := make_stylebox(
		UIColors.SURFACE_PRESSED, 1, UIColors.BORDER_DEFAULT, 4)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	theme.set_stylebox("normal", "LineEdit", normal)

	var focus := make_stylebox(
		UIColors.SURFACE_PRESSED, 1, UIColors.BORDER_FOCUS, 4)
	focus.content_margin_left = 8
	focus.content_margin_right = 8
	focus.content_margin_top = 4
	focus.content_margin_bottom = 4
	theme.set_stylebox("focus", "LineEdit", focus)

	theme.set_color("font_color", "LineEdit", UIColors.TEXT_PRIMARY)
	theme.set_color("font_placeholder_color", "LineEdit", UIColors.TEXT_MUTED)


func _build_label() -> void:
	theme.set_color("font_color", "Label", UIColors.TEXT_PRIMARY)


static func make_stylebox(
	bg: Color, border_width: int, border_color: Color,
	corner_radius: int
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = border_width
	sb.border_width_top = border_width
	sb.border_width_right = border_width
	sb.border_width_bottom = border_width
	sb.border_color = border_color
	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	return sb
