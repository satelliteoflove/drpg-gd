extends Node

## Central UI theme, applied to the SceneTree root so every Control inherits it.
##
## Design language ("Arcane Tome"): a deep cool-violet stone palette with a
## single luminous arcane-blue interaction accent and warm gold-leaf titles.
## Body/data text uses Inter (highly legible); titles and section headers use
## Cinzel (carved-stone Roman caps) via theme type variations so screens opt in
## with a single `theme_type_variation` property and stay consistent.

const INTER_PATH := "res://fonts/Inter.ttf"
const CINZEL_PATH := "res://fonts/Cinzel.ttf"

# Corner radii / shared metrics
const RADIUS_CONTROL := 6
const RADIUS_PANEL := 8

var theme: Theme

# Font variations (built in _ready once base fonts are loaded)
var _body: Font
var _body_medium: Font
var _body_semibold: Font
var _display_semibold: Font
var _display_bold: Font


func _ready() -> void:
	theme = Theme.new()
	_load_fonts()

	if _body:
		theme.default_font = _body
	theme.default_font_size = 16

	_build_label()
	_build_label_variations()
	_build_rich_text_label()
	_build_panel_container()
	_build_button()
	_build_button_variations()
	_build_tab_bar()
	_build_tab_container()
	_build_scrollbar()
	_build_line_edit()
	_build_progress_bar()
	_build_separators()

	get_tree().root.theme = theme


# --- Fonts ------------------------------------------------------------------

func _load_fonts() -> void:
	var inter := _load_font(INTER_PATH)
	var cinzel := _load_font(CINZEL_PATH)
	if inter:
		_body = _variation(inter, 400)
		_body_medium = _variation(inter, 500)
		_body_semibold = _variation(inter, 600)
	if cinzel:
		_display_semibold = _variation(cinzel, 600)
		_display_bold = _variation(cinzel, 700)


func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Font:
			return res
	push_warning("UITheme: font not found / not imported: %s" % path)
	return null


func _variation(base: Font, weight: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {"wght": weight}
	return fv


# --- Labels -----------------------------------------------------------------

func _build_label() -> void:
	theme.set_color("font_color", "Label", UIColors.TEXT_PRIMARY)
	theme.set_color("font_outline_color", "Label", UIColors.SURFACE_BACKGROUND)


func _build_label_variations() -> void:
	# Big screen title - carved gold-leaf caps with a soft drop shadow.
	theme.set_type_variation("TitleLabel", "Label")
	if _display_bold:
		theme.set_font("font", "TitleLabel", _display_bold)
	theme.set_font_size("font_size", "TitleLabel", 38)
	theme.set_color("font_color", "TitleLabel", UIColors.TITLE_GOLD)
	theme.set_color("font_shadow_color", "TitleLabel", Color(0, 0, 0, 0.55))
	theme.set_constant("shadow_offset_x", "TitleLabel", 0)
	theme.set_constant("shadow_offset_y", "TitleLabel", 3)
	theme.set_constant("shadow_outline_size", "TitleLabel", 1)

	# Section header inside a screen (e.g. "SHOP", "GUILD HALL").
	theme.set_type_variation("HeaderLabel", "Label")
	if _display_semibold:
		theme.set_font("font", "HeaderLabel", _display_semibold)
	theme.set_font_size("font_size", "HeaderLabel", 24)
	theme.set_color("font_color", "HeaderLabel", UIColors.TEXT_TITLE)

	# Smaller header / column heading.
	theme.set_type_variation("SubheaderLabel", "Label")
	if _display_semibold:
		theme.set_font("font", "SubheaderLabel", _display_semibold)
	theme.set_font_size("font_size", "SubheaderLabel", 17)
	theme.set_color("font_color", "SubheaderLabel", UIColors.TEXT_TITLE)

	# Subtitle / tagline under a title.
	theme.set_type_variation("SubtitleLabel", "Label")
	if _body:
		theme.set_font("font", "SubtitleLabel", _body)
	theme.set_font_size("font_size", "SubtitleLabel", 15)
	theme.set_color("font_color", "SubtitleLabel", UIColors.TEXT_SECONDARY)

	# Muted helper / hint text.
	theme.set_type_variation("MutedLabel", "Label")
	if _body:
		theme.set_font("font", "MutedLabel", _body)
	theme.set_font_size("font_size", "MutedLabel", 13)
	theme.set_color("font_color", "MutedLabel", UIColors.TEXT_MUTED)


func _build_rich_text_label() -> void:
	if _body:
		theme.set_font("normal_font", "RichTextLabel", _body)
		theme.set_font("bold_font", "RichTextLabel", _body_semibold)
		theme.set_font("italics_font", "RichTextLabel", _body)
		theme.set_font("bold_italics_font", "RichTextLabel", _body_semibold)
	theme.set_font_size("normal_font_size", "RichTextLabel", 15)
	theme.set_font_size("bold_font_size", "RichTextLabel", 15)
	theme.set_color("default_color", "RichTextLabel", UIColors.TEXT_PRIMARY)


# --- Panels -----------------------------------------------------------------

func _build_panel_container() -> void:
	var panel := make_stylebox(
		UIColors.SURFACE_PANEL, 1, UIColors.BORDER_SUBTLE, RADIUS_PANEL)
	_set_margins(panel, 10, 10, 10, 10)
	panel.shadow_color = UIColors.SHADOW
	panel.shadow_size = 6
	panel.shadow_offset = Vector2(0, 3)
	theme.set_stylebox("panel", "PanelContainer", panel)

	# Generic Panel (non-container) shares the look.
	theme.set_stylebox("panel", "Panel", panel)


# --- Buttons ----------------------------------------------------------------

func _build_button() -> void:
	var normal := make_stylebox(
		UIColors.SURFACE_CARD, 1, UIColors.BORDER_DEFAULT, RADIUS_CONTROL)
	_set_margins(normal, 14, 14, 7, 7)
	theme.set_stylebox("normal", "Button", normal)

	var hover := make_stylebox(
		UIColors.SURFACE_HOVER, 1, UIColors.BORDER_HOVER, RADIUS_CONTROL)
	_set_margins(hover, 14, 14, 7, 7)
	theme.set_stylebox("hover", "Button", hover)

	var pressed := make_stylebox(
		UIColors.SURFACE_PRESSED, 1, UIColors.BORDER_DEFAULT, RADIUS_CONTROL)
	_set_margins(pressed, 14, 14, 7, 7)
	theme.set_stylebox("pressed", "Button", pressed)

	var disabled := make_stylebox(
		UIColors.SURFACE_DISABLED, 1, UIColors.BORDER_SUBTLE, RADIUS_CONTROL)
	_set_margins(disabled, 14, 14, 7, 7)
	theme.set_stylebox("disabled", "Button", disabled)

	# Focus: full accent border + soft accent glow. High-contrast and clearly
	# distinct from hover - this is the primary signal for keyboard/controller.
	var focus := make_stylebox(
		UIColors.SURFACE_SELECTED, 2, UIColors.ACCENT, RADIUS_CONTROL)
	_set_margins(focus, 14, 14, 7, 7)
	focus.shadow_color = UIColors.ACCENT_GLOW
	focus.shadow_size = 5
	theme.set_stylebox("focus", "Button", focus)

	theme.set_color("font_color", "Button", UIColors.TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", UIColors.TEXT_SECONDARY)
	theme.set_color("font_disabled_color", "Button", UIColors.TEXT_DISABLED)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	if _body_medium:
		theme.set_font("font", "Button", _body_medium)
	theme.set_font_size("font_size", "Button", 16)


func _build_button_variations() -> void:
	# Large primary menu buttons (main menu / town destinations).
	theme.set_type_variation("MenuButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBoxFlat = theme.get_stylebox(state, "Button").duplicate()
		_set_margins(sb, 20, 20, 13, 13)
		theme.set_stylebox(state, "MenuButton", sb)
	if _body_medium:
		theme.set_font("font", "MenuButton", _body_medium)
	theme.set_font_size("font_size", "MenuButton", 19)
	theme.set_color("font_color", "MenuButton", UIColors.TEXT_PRIMARY)
	theme.set_color("font_hover_color", "MenuButton", Color.WHITE)
	theme.set_color("font_focus_color", "MenuButton", Color.WHITE)
	theme.set_color("font_pressed_color", "MenuButton", UIColors.TEXT_SECONDARY)
	theme.set_color("font_disabled_color", "MenuButton", UIColors.TEXT_DISABLED)

	# Primary call-to-action - filled arcane accent that reads as the main action
	# in a list of otherwise-neutral options (e.g. "Enter Dungeon").
	theme.set_type_variation("PrimaryButton", "Button")
	var p_normal := make_stylebox(
		Color(0.24, 0.32, 0.55), 1, UIColors.ACCENT, RADIUS_CONTROL)
	_set_margins(p_normal, 16, 16, 11, 11)
	theme.set_stylebox("normal", "PrimaryButton", p_normal)
	var p_hover := make_stylebox(
		Color(0.32, 0.43, 0.72), 1, UIColors.BORDER_FOCUS, RADIUS_CONTROL)
	_set_margins(p_hover, 16, 16, 11, 11)
	theme.set_stylebox("hover", "PrimaryButton", p_hover)
	var p_pressed := make_stylebox(
		Color(0.18, 0.24, 0.44), 1, UIColors.ACCENT, RADIUS_CONTROL)
	_set_margins(p_pressed, 16, 16, 11, 11)
	theme.set_stylebox("pressed", "PrimaryButton", p_pressed)
	var p_disabled := make_stylebox(
		UIColors.SURFACE_DISABLED, 1, UIColors.BORDER_SUBTLE, RADIUS_CONTROL)
	_set_margins(p_disabled, 16, 16, 11, 11)
	theme.set_stylebox("disabled", "PrimaryButton", p_disabled)
	var p_focus := make_stylebox(
		Color(0.30, 0.40, 0.66), 2, UIColors.ACCENT, RADIUS_CONTROL)
	_set_margins(p_focus, 16, 16, 11, 11)
	p_focus.shadow_color = UIColors.ACCENT_GLOW
	p_focus.shadow_size = 6
	theme.set_stylebox("focus", "PrimaryButton", p_focus)
	if _body_semibold:
		theme.set_font("font", "PrimaryButton", _body_semibold)
	theme.set_font_size("font_size", "PrimaryButton", 17)
	theme.set_color("font_color", "PrimaryButton", Color.WHITE)
	theme.set_color("font_hover_color", "PrimaryButton", Color.WHITE)
	theme.set_color("font_focus_color", "PrimaryButton", Color.WHITE)
	theme.set_color("font_pressed_color", "PrimaryButton", Color(0.85, 0.88, 0.95))
	theme.set_color("font_disabled_color", "PrimaryButton", UIColors.TEXT_DISABLED)


# --- Tabs -------------------------------------------------------------------

func _build_tab_bar() -> void:
	var selected := StyleBoxFlat.new()
	selected.bg_color = UIColors.SURFACE_CARD
	selected.border_width_bottom = 3
	selected.border_color = UIColors.ACCENT
	selected.corner_radius_top_left = RADIUS_CONTROL
	selected.corner_radius_top_right = RADIUS_CONTROL
	_set_margins(selected, 16, 16, 9, 9)
	theme.set_stylebox("tab_selected", "TabBar", selected)

	var unselected := StyleBoxFlat.new()
	unselected.bg_color = UIColors.SURFACE_BACKGROUND
	unselected.corner_radius_top_left = RADIUS_CONTROL
	unselected.corner_radius_top_right = RADIUS_CONTROL
	_set_margins(unselected, 16, 16, 9, 9)
	theme.set_stylebox("tab_unselected", "TabBar", unselected)

	var hovered := StyleBoxFlat.new()
	hovered.bg_color = UIColors.SURFACE_HOVER
	hovered.corner_radius_top_left = RADIUS_CONTROL
	hovered.corner_radius_top_right = RADIUS_CONTROL
	_set_margins(hovered, 16, 16, 9, 9)
	theme.set_stylebox("tab_hovered", "TabBar", hovered)

	var tab_focus := StyleBoxFlat.new()
	tab_focus.bg_color = UIColors.SURFACE_SELECTED
	tab_focus.border_width_bottom = 3
	tab_focus.border_color = UIColors.BORDER_FOCUS
	tab_focus.corner_radius_top_left = RADIUS_CONTROL
	tab_focus.corner_radius_top_right = RADIUS_CONTROL
	_set_margins(tab_focus, 16, 16, 9, 9)
	theme.set_stylebox("tab_focus", "TabBar", tab_focus)

	theme.set_color("font_selected_color", "TabBar", Color.WHITE)
	theme.set_color("font_unselected_color", "TabBar", UIColors.TEXT_SECONDARY)
	theme.set_color("font_hovered_color", "TabBar", UIColors.TEXT_PRIMARY)
	if _body_semibold:
		theme.set_font("font", "TabBar", _body_semibold)
	theme.set_font_size("font_size", "TabBar", 15)


func _build_tab_container() -> void:
	var panel := make_stylebox(
		UIColors.SURFACE_PANEL, 1, UIColors.BORDER_SUBTLE, RADIUS_PANEL)
	theme.set_stylebox("panel", "TabContainer", panel)


# --- Scrollbar --------------------------------------------------------------

func _build_scrollbar() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = UIColors.SURFACE_BACKGROUND
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	bg.content_margin_left = 4
	bg.content_margin_right = 4
	theme.set_stylebox("scroll", "VScrollBar", bg)
	theme.set_stylebox("scroll", "HScrollBar", bg)

	for variant in [
		["grabber", UIColors.BORDER_DEFAULT],
		["grabber_highlight", UIColors.BORDER_HOVER],
		["grabber_pressed", UIColors.ACCENT_DIM],
	]:
		var g := StyleBoxFlat.new()
		g.bg_color = variant[1]
		g.corner_radius_top_left = 4
		g.corner_radius_top_right = 4
		g.corner_radius_bottom_left = 4
		g.corner_radius_bottom_right = 4
		g.content_margin_left = 4
		g.content_margin_right = 4
		theme.set_stylebox(variant[0], "VScrollBar", g)
		theme.set_stylebox(variant[0], "HScrollBar", g)


# --- LineEdit ---------------------------------------------------------------

func _build_line_edit() -> void:
	var normal := make_stylebox(
		UIColors.SURFACE_PRESSED, 1, UIColors.BORDER_DEFAULT, RADIUS_CONTROL)
	_set_margins(normal, 10, 10, 6, 6)
	theme.set_stylebox("normal", "LineEdit", normal)

	var focus := make_stylebox(
		UIColors.SURFACE_PRESSED, 2, UIColors.BORDER_FOCUS, RADIUS_CONTROL)
	_set_margins(focus, 10, 10, 6, 6)
	focus.shadow_color = UIColors.ACCENT_GLOW
	focus.shadow_size = 4
	theme.set_stylebox("focus", "LineEdit", focus)

	theme.set_color("font_color", "LineEdit", UIColors.TEXT_PRIMARY)
	theme.set_color("font_placeholder_color", "LineEdit", UIColors.TEXT_MUTED)
	theme.set_color("caret_color", "LineEdit", UIColors.ACCENT)
	theme.set_color("selection_color", "LineEdit", UIColors.ACCENT_DIM)


# --- ProgressBar (HP/MP/XP bars) --------------------------------------------

func _build_progress_bar() -> void:
	var bg := make_stylebox(
		UIColors.SURFACE_BAR_BG, 1, UIColors.BORDER_SUBTLE, 4)
	theme.set_stylebox("background", "ProgressBar", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = UIColors.HP_GREEN
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	theme.set_stylebox("fill", "ProgressBar", fill)

	theme.set_color("font_color", "ProgressBar", UIColors.TEXT_PRIMARY)


# --- Separators -------------------------------------------------------------

func _build_separators() -> void:
	for type in ["HSeparator", "VSeparator"]:
		var line := StyleBoxLine.new()
		line.color = UIColors.BORDER_SUBTLE
		line.thickness = 1
		if type == "VSeparator":
			line.vertical = true
		theme.set_stylebox("separator", type, line)
		theme.set_constant("separation", type, 12)


# --- Helpers ----------------------------------------------------------------

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
	sb.anti_aliasing = true
	return sb


static func _set_margins(
	sb: StyleBoxFlat, left: int, right: int, top: int, bottom: int
) -> void:
	sb.content_margin_left = left
	sb.content_margin_right = right
	sb.content_margin_top = top
	sb.content_margin_bottom = bottom
