class_name ModalCard
extends RefCounted

## A titled card over a dimmed screen, for announcements and short choices.
## [method open] adds it to [param host] and returns the layer; put content in
## [method body], and free the layer to close it.


static func open(host: Node, title_text: String) -> CanvasLayer:
	# A CanvasLayer keeps the card above menu cursors and their effects.
	var layer := CanvasLayer.new()
	layer.layer = 10
	host.add_child(layer)

	var dim := ColorRect.new()
	dim.color = UIColors.SURFACE_MODAL_OVERLAY
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Controls under a CanvasLayer don't inherit the root window's theme.
	center.theme = host.get_tree().root.theme
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var divider := ArcaneDivider.new()
	divider.custom_minimum_size = Vector2(320, 14)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(divider)

	layer.set_meta("body", col)
	return layer


static func body(layer: CanvasLayer) -> VBoxContainer:
	return layer.get_meta("body")


static func paragraph(text: String) -> Label:
	var p := Label.new()
	p.theme_type_variation = &"SubtitleLabel"
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.custom_minimum_size = Vector2(560, 0)
	p.text = text
	return p


static func choice_button(text: String, width: float = 240.0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return button
