class_name CharacterDetailView
extends RefCounted

## The Guild Hall's right-hand detail surface. At any moment it shows EITHER the
## full-height CharacterSheet dossier (crest, vitals meters, attribute bars,
## combat, gear, story) for the character in focus, OR a centered context card
## for guidance text (confirmations, class requirements, the guild summary).
## One or the other — so the space is always either richly filled or a tidy
## card, never a stranded line of text in a cavernous box.
##
##   var detail := CharacterDetailView.new(right_panel_control)
##   detail.show_character(member, party_index, show_row)
##   detail.show_text("[b]Delete Borin?[/b]\n...")
##
## The mount must be a plain Control (not a Container) sized by its own parent;
## the dossier and the card layer both anchor to fill it.

var _dossier: CharacterSheet
var _card_center: CenterContainer
var _card_label: RichTextLabel


func _init(mount: Control) -> void:
	_dossier = CharacterSheet.new()
	_dossier.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dossier.visible = false
	mount.add_child(_dossier)
	# Custom-drawn control: repaint when the layout resizes the panel.
	_dossier.resized.connect(_dossier.queue_redraw)

	_card_center = CenterContainer.new()
	_card_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_center.visible = false
	mount.add_child(_card_center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(500, 0)
	card.add_theme_stylebox_override("panel", _card_style())
	_card_center.add_child(card)

	_card_label = RichTextLabel.new()
	_card_label.bbcode_enabled = true
	_card_label.fit_content = true
	_card_label.scroll_active = false
	_card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_label.custom_minimum_size = Vector2(456, 0)
	card.add_child(_card_label)


## Show the rich dossier for a character. party_index drives the Front/Back row
## chip; pass show_row = false for benched/roster characters where row is moot.
func show_character(character: Character, party_index: int = 0, show_row: bool = true) -> void:
	_card_center.visible = false
	_dossier.set_character(character, maxi(party_index, 0), show_row)
	_dossier.visible = true


## Show a centered context card with bbcode guidance / summary text.
func show_text(text: String) -> void:
	_dossier.visible = false
	_dossier.clear()
	_card_label.text = text
	_card_center.visible = true


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
