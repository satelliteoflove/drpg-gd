extends PanelContainer

signal event_resolved(choice_id: String)

var _template: Dictionary = {}
var _cast: Dictionary = {}
var _context: Dictionary = {}
var _chosen_choice_id: String = ""
var _choice_nav: MenuNavigator = null
var _choice_buttons: Array[Button] = []
var _continue_mode := false

@onready var _header: Label = $EventVBox/HeaderLabel
@onready var _setup_text: RichTextLabel = $EventVBox/SetupText
@onready var _dialogue_box: RichTextLabel = $EventVBox/DialogueBox
@onready var _choices_vbox: VBoxContainer = $EventVBox/ChoicesVBox
@onready var _continue_button: Button = $EventVBox/ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue)
	_continue_button.visible = false


func setup(template: Dictionary, cast: Dictionary, context: Dictionary) -> void:
	_template = template
	_cast = cast
	_context = context

	_header.text = _format_category(template.get("category", "event"))
	_setup_text.text = _substitute(template.get("setup_text", ""))

	if LLMManager.is_available() and template.has("llm_context"):
		_dialogue_box.text = "[color=#666666]...[/color]"
		var prompt := PromptBuilder.build_event_prompt(template, cast, context)
		var grammar := PromptBuilder.event_grammar()
		LLMManager.generate(prompt, grammar, _on_llm_dialogue_received)
	else:
		_render_static_dialogue()

	_populate_choices()


func _render_static_dialogue() -> void:
	var dialogue_lines: Array = _template.get("dialogue", [])
	var dialogue_text := ""
	for entry: Dictionary in dialogue_lines:
		var slot_idx: int = int(entry.get("slot_index", 0))
		var char_name := _get_cast_name(slot_idx)
		var line: String = entry.get("line", "")
		line = _substitute(line)
		dialogue_text += "[color=#88ccee]%s:[/color] %s\n" % [char_name, line]
	_dialogue_box.text = dialogue_text


func _on_llm_dialogue_received(content: String) -> void:
	if content == "":
		_render_static_dialogue()
		return

	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Array:
		_render_static_dialogue()
		return

	var lines: Array = parsed as Array
	var dialogue_text := ""
	for entry: Variant in lines:
		if not entry is Dictionary:
			_render_static_dialogue()
			return
		var d: Dictionary = entry as Dictionary
		var slot_idx: int = int(d.get("slot", 0))
		var line: String = d.get("line", "")
		if line.length() < 3 or line.length() > 80 or not _cast.has(slot_idx):
			_render_static_dialogue()
			return
		var char_name := _get_cast_name(slot_idx)
		dialogue_text += "[color=#88ccee]%s:[/color] %s\n" % [char_name, line]

	_dialogue_box.text = dialogue_text


func _populate_choices() -> void:
	for child in _choices_vbox.get_children():
		child.queue_free()
	_choice_buttons.clear()

	var choices: Array = _template.get("choices", [])
	for choice: Dictionary in choices:
		var btn := Button.new()
		var label: String = choice.get("label", "???")
		var desc: String = choice.get("description", "")
		btn.text = label if desc == "" else "%s - %s" % [label, desc]
		btn.custom_minimum_size = Vector2(0, 36)
		var choice_id: String = choice.get("id", "")
		btn.pressed.connect(_on_choice_selected.bind(choice_id))
		_choices_vbox.add_child(btn)
		_choice_buttons.append(btn)

	_choice_nav = MenuNavigator.new()
	if not _choice_buttons.is_empty():
		_choice_nav.setup(_choice_buttons, 0)


func _on_choice_selected(choice_id: String) -> void:
	if _continue_mode:
		return
	_chosen_choice_id = choice_id

	var summary := EventManager.apply_consequences(_template, choice_id, _cast, _context)
	_show_consequence_summary(summary)

	for child in _choices_vbox.get_children():
		child.queue_free()
	_choice_buttons.clear()
	_choice_nav = null

	_continue_button.visible = true
	_continue_mode = true
	_continue_button.grab_focus()


func _show_consequence_summary(summary: Array[Dictionary]) -> void:
	var text := "\n"
	for entry: Dictionary in summary:
		match entry.get("type", ""):
			"mark":
				text += "[color=#cccc44]%s earned: %s[/color]\n" % [
					entry.get("name", ""), entry.get("mark_name", "")
				]
			"relationship":
				var sign_str := "+" if int(entry.get("weight", 0)) > 0 else ""
				text += "[color=#88ccee]%s & %s: %s (%s%d)[/color]\n" % [
					entry.get("char_a", ""), entry.get("char_b", ""),
					entry.get("source", ""), sign_str, int(entry.get("weight", 0))
				]
			"evidence":
				text += "[color=#66cc66]%s: growing more %s[/color]\n" % [
					entry.get("name", ""), entry.get("trait", "")
				]
			"crystallization":
				text += "[color=#ffaa00]%s's %s crystallized: %s![/color]\n" % [
					entry.get("name", ""),
					str(entry.get("axis", "")).to_lower(),
					entry.get("trait", "")
				]

	if text.strip_edges() != "":
		_dialogue_box.text = text


func _on_continue() -> void:
	event_resolved.emit(_chosen_choice_id)


func _substitute(text: String) -> String:
	for idx: int in _cast.keys():
		var character: Character = _cast[idx]
		text = text.replace("{slot_%d}" % idx, character.character_name)
	text = text.replace("{floor}", str(_context.get("floor", 1)))
	text = text.replace("{day}", str(_context.get("day", 1)))
	return text


func _get_cast_name(slot_idx: int) -> String:
	if _cast.has(slot_idx):
		return (_cast[slot_idx] as Character).character_name
	return "???"


func _format_category(category: String) -> String:
	return category.replace("_", " ").capitalize()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if _continue_mode:
		if event.is_action_pressed("menu_confirm"):
			_on_continue()
			get_viewport().set_input_as_handled()
		return

	if _choice_nav:
		if event.is_action_pressed("menu_up"):
			_choice_nav._move(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("menu_down"):
			_choice_nav._move(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("menu_confirm"):
			_choice_nav._confirm()
			get_viewport().set_input_as_handled()
