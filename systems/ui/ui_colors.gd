class_name UIColors extends RefCounted

# Surface colors - depth system (darker = further back)
const SURFACE_BACKGROUND := Color(0.08, 0.07, 0.10)
const SURFACE_PANEL := Color(0.14, 0.13, 0.17)
const SURFACE_CARD := Color(0.17, 0.16, 0.20)
const SURFACE_SELECTED := Color(0.20, 0.19, 0.25)
const SURFACE_HOVER := Color(0.22, 0.21, 0.27)
const SURFACE_PRESSED := Color(0.10, 0.09, 0.13)
const SURFACE_DISABLED := Color(0.11, 0.10, 0.13)
const SURFACE_MODAL_OVERLAY := Color(0.0, 0.0, 0.0, 0.6)
const SURFACE_BAR_BG := Color(0.18, 0.17, 0.22)

# Border colors
const BORDER_SUBTLE := Color(0.25, 0.24, 0.30)
const BORDER_DEFAULT := Color(0.32, 0.30, 0.38)
const BORDER_HOVER := Color(0.42, 0.40, 0.50)
const BORDER_FOCUS := Color(0.45, 0.55, 0.85)
const BORDER_ACCENT := Color(0.35, 0.50, 0.80)

# Text colors
const TEXT_PRIMARY := Color(0.88, 0.86, 0.82)
const TEXT_SECONDARY := Color(0.65, 0.63, 0.60)
const TEXT_MUTED := Color(0.45, 0.43, 0.40)
const TEXT_DISABLED := Color(0.35, 0.33, 0.30)
const TEXT_TITLE := Color(0.95, 0.93, 0.88)

# Semantic colors - game systems
const HP_GREEN := Color(0.20, 0.70, 0.30)
const MP_BLUE := Color(0.30, 0.50, 0.90)
const GOLD := Color(0.90, 0.75, 0.25)
const DANGER := Color(0.85, 0.25, 0.25)
const WARNING := Color(0.90, 0.70, 0.20)
const SUCCESS := Color(0.30, 0.80, 0.40)
const INFO := Color(0.40, 0.70, 0.90)

# Formation row colors
const FRONT_ROW := Color(0.90, 0.45, 0.35)
const BACK_ROW := Color(0.35, 0.65, 0.90)
const MID_ROW := Color(0.70, 0.70, 0.40)

# Status tints
const DEAD_TINT := Color(0.40, 0.40, 0.40)
const DISABLED_TINT := Color(0.50, 0.50, 0.50, 0.30)

# Modulate tints (applied to node.modulate for visual state)
const MODULATE_DISABLED := Color(0.6, 0.6, 0.6)
const MODULATE_DEAD := Color(0.7, 0.3, 0.3)

# Screen backgrounds
const BG_SCREEN := Color(0.12, 0.10, 0.14)
const BG_DIALOG := Color(0.15, 0.12, 0.18)

# Saturated status text (for add_theme_color_override on labels)
const TEXT_DANGER := Color(1.0, 0.3, 0.3)
const TEXT_WARNING := Color(1.0, 0.8, 0.3)
const TEXT_HEALTHY := Color(0.4, 1.0, 0.4)
const TEXT_ACTIVE := Color(0.3, 1.0, 0.3)
const TEXT_STATUS := Color(1.0, 0.6, 0.2)
const TEXT_IN_PARTY := Color(0.3, 0.7, 1.0)
const TEXT_LOST := Color(0.5, 0.2, 0.2)

# Font sizes
const FONT_SIZE_TITLE := 24
const FONT_SIZE_HEADER := 18
const FONT_SIZE_BODY := 16
const FONT_SIZE_SMALL := 14
const FONT_SIZE_TINY := 12

# Spacing
const MARGIN_SCREEN := 20
const SEPARATION_MAIN := 16
const SEPARATION_PANEL := 8
