extends CanvasLayer

signal micro_event_closed

var _speaker: Character = null
var _line: String = ""
var _context_type: String = ""
var _responders: Array[Character] = []

@onready var panel: PanelContainer = %Panel
@onready var speaker_label: Label = %SpeakerLabel
@onready var line_label: Label = %LineLabel
@onready var response_container: VBoxContainer = %ResponseContainer
@onready var dismiss_button: Button = %DismissButton


func setup(data: Dictionary, party: Array[Character]) -> void:
	_speaker = data.speaker
	_line = data.line
	_context_type = data.get("context", "")

	speaker_label.text = _speaker.character_name
	line_label.text = "\"%s\"" % _line

	var living: Array[Character] = []
	for c in party:
		if not c.is_dead and c.id != _speaker.id:
			living.append(c)

	_responders = _pick_responders(living, 2)

	for responder in _responders:
		var btn := Button.new()
		btn.text = responder.character_name
		btn.pressed.connect(_on_responder_picked.bind(responder))
		response_container.add_child(btn)

	dismiss_button.pressed.connect(_on_dismiss)

	var all_buttons: Array[Button] = []
	for child in response_container.get_children():
		if child is Button:
			all_buttons.append(child as Button)
	all_buttons.append(dismiss_button)

	for i in range(all_buttons.size()):
		var prev_path := all_buttons[(i - 1 + all_buttons.size()) % all_buttons.size()].get_path()
		var next_path := all_buttons[(i + 1) % all_buttons.size()].get_path()
		all_buttons[i].focus_neighbor_top = prev_path
		all_buttons[i].focus_neighbor_bottom = next_path

	if not all_buttons.is_empty():
		all_buttons[0].grab_focus()


func _pick_responders(candidates: Array[Character], count: int) -> Array[Character]:
	var shuffled := candidates.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var temp: Character = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp

	var result: Array[Character] = []
	for i in range(mini(count, shuffled.size())):
		result.append(shuffled[i])
	return result


func _on_responder_picked(responder: Character) -> void:
	_set_buttons_disabled(true)
	MicroEventSystem.generate_response(
		responder, _speaker, _line, _context_type,
		func(response_line: String) -> void:
			if response_line != "":
				_show_response(responder, response_line)
			else:
				_show_response(responder, "...")
	)


func _show_response(responder: Character, response_line: String) -> void:
	RelationshipManager.add_modifier(
		_speaker.id, responder.id,
		"Shared a moment", 1, GameState.game_day
	)

	for child in response_container.get_children():
		child.queue_free()

	var response_label := Label.new()
	response_label.text = "%s: \"%s\"" % [responder.character_name, response_line]
	response_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	response_container.add_child(response_label)

	dismiss_button.text = "Continue"
	dismiss_button.disabled = false
	dismiss_button.grab_focus()


func _on_dismiss() -> void:
	micro_event_closed.emit()
	queue_free()


func _set_buttons_disabled(disabled: bool) -> void:
	dismiss_button.disabled = disabled
	for child in response_container.get_children():
		if child is Button:
			child.disabled = disabled


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		_on_dismiss()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_up"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused:
			var prev := focused.find_valid_focus_neighbor(SIDE_TOP)
			if prev:
				prev.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_down"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused:
			var next := focused.find_valid_focus_neighbor(SIDE_BOTTOM)
			if next:
				next.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_confirm"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and not (focused as Button).disabled:
			(focused as Button).emit_signal("pressed")
		get_viewport().set_input_as_handled()
