class_name PartyMenuKeybindingsTab
extends RefCounted

var nav: MenuNavigator = null
var buttons: Array[Button] = []
var actions: Array[String] = []
var selected_action: String = ""
var listening := false
var listen_slot := 0

var action_list: VBoxContainer
var primary_label: Label
var primary_btn: Button
var secondary_label: Label
var secondary_btn: Button
var clear_btn: Button
var reset_btn: Button
var info_label: RichTextLabel


func init(p_action_list: VBoxContainer, p_primary_label: Label, p_primary_btn: Button, p_secondary_label: Label, p_secondary_btn: Button, p_clear_btn: Button, p_reset_btn: Button, p_info_label: RichTextLabel) -> void:
	action_list = p_action_list
	primary_label = p_primary_label
	primary_btn = p_primary_btn
	secondary_label = p_secondary_label
	secondary_btn = p_secondary_btn
	clear_btn = p_clear_btn
	reset_btn = p_reset_btn
	info_label = p_info_label


func is_listening() -> bool:
	return listening


func refresh() -> void:
	for child in action_list.get_children():
		child.queue_free()
	buttons.clear()
	actions.clear()

	for action: String in KeybindSettings.BINDABLE_ACTIONS:
		var label: String = KeybindSettings.BINDABLE_ACTIONS[action]
		var keys := KeybindSettings.get_action_keys(action)
		var key_text := ""
		if keys.size() > 0:
			key_text = KeybindSettings.key_to_label(keys[0])
		if keys.size() > 1:
			key_text += " / " + KeybindSettings.key_to_label(keys[1])

		var btn := Button.new()
		btn.text = "%s  [%s]" % [label, key_text]
		btn.custom_minimum_size = Vector2(300, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_action_selected.bind(action))
		action_list.add_child(btn)
		buttons.append(btn)
		actions.append(action)

	var separator := Label.new()
	separator.text = ""
	action_list.add_child(separator)
	var header := Label.new()
	header.text = "--- Debug Keys (Dungeon) ---"
	header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	action_list.add_child(header)

	var debug_keys := [
		["X", "Force Combat"],
		["Shift+X", "Level Party +1"],
		["Ctrl+X", "Level Party +5"],
		["Shift+C", "Toggle Combat Math"],
		["Shift+F", "Next Floor"],
		["Ctrl+F", "Previous Floor"],
		["G", "Add 1000 Gold"],
		["K", "Add Dungeon Key"],
		["Shift+S", "Run Simulation"],
		["Shift+B", "Run Batch Sim"],
		["Ctrl+L", "Toggle AI Log"],
		["Ctrl+Shift+L", "Toggle LLM Fallback"],
		["Ctrl+E", "Force Micro Event"],
		["Ctrl+V", "Toggle Verbose Debug"],
	]
	for entry in debug_keys:
		var dbtn := Button.new()
		dbtn.text = "%s  [%s]" % [entry[1], entry[0]]
		dbtn.custom_minimum_size = Vector2(300, 32)
		dbtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		dbtn.disabled = true
		dbtn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
		action_list.add_child(dbtn)

	var restore_index := actions.find(selected_action)
	if restore_index < 0:
		restore_index = 0

	nav = MenuNavigator.new()
	nav.setup(buttons, restore_index)
	nav.selection_changed.connect(_on_selection_changed)

	if not clear_btn.pressed.is_connected(_on_clear_secondary):
		clear_btn.pressed.connect(_on_clear_secondary)
		reset_btn.pressed.connect(_on_reset_defaults)
		primary_btn.pressed.connect(_on_primary_pressed)
		secondary_btn.pressed.connect(_on_secondary_pressed)

	if not actions.is_empty():
		selected_action = actions[0]
		_update_detail()

	info_label.text = "Select an action to rebind its key."


func _on_action_selected(action: String) -> void:
	selected_action = action
	_start_listening(0)


func _on_selection_changed(index: int) -> void:
	if index >= 0 and index < actions.size():
		selected_action = actions[index]
		_update_detail()


func _update_detail() -> void:
	if selected_action.is_empty():
		primary_label.text = "Primary: "
		primary_btn.text = "(none)"
		secondary_label.text = "Secondary: "
		secondary_btn.text = "(none)"
		return

	var keys := KeybindSettings.get_action_keys(selected_action)
	primary_label.text = "Primary:"
	secondary_label.text = "Secondary:"

	if keys.size() > 0:
		primary_btn.text = KeybindSettings.key_to_label(keys[0])
	else:
		primary_btn.text = "(none)"

	if keys.size() > 1:
		secondary_btn.text = KeybindSettings.key_to_label(keys[1])
	else:
		secondary_btn.text = "(none)"

	var label: String = KeybindSettings.BINDABLE_ACTIONS.get(selected_action, "")
	info_label.text = "[b]%s[/b]\nEnter: rebind primary | S: rebind secondary" % label


func _on_primary_pressed() -> void:
	_start_listening(0)


func _on_secondary_pressed() -> void:
	_start_listening(1)


func _start_listening(slot: int) -> void:
	listening = true
	listen_slot = slot
	var slot_name := "primary" if slot == 0 else "secondary"
	var label: String = KeybindSettings.BINDABLE_ACTIONS.get(selected_action, "")
	info_label.text = "[b]%s[/b]\nPress any key for %s binding..." % [label, slot_name]
	if slot == 0:
		primary_btn.text = "..."
	else:
		secondary_btn.text = "..."


func apply_listened_key(event: InputEventKey) -> void:
	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if code == KEY_ESCAPE:
		listening = false
		_update_detail()
		return

	if code == KEY_SHIFT or code == KEY_CTRL or code == KEY_ALT or code == KEY_META:
		return

	var conflict := KeybindSettings.check_conflict(selected_action, event)
	if conflict != "":
		var key_label := KeybindSettings.key_to_label(KeybindSettings._normalize_event(event))
		listening = false
		_update_detail()
		info_label.text = "[color=yellow]%s is already bound to %s.[/color]\nClear it there first, then try again." % [key_label, conflict]
		return

	KeybindSettings.rebind_action(selected_action, listen_slot, event)
	listening = false
	refresh()


func _on_clear_secondary() -> void:
	if selected_action.is_empty():
		return
	var keys := KeybindSettings.get_action_keys(selected_action)
	if keys.size() > 1:
		InputMap.action_erase_event(selected_action, keys[1])
		KeybindSettings._save_bindings()
		refresh()


func _on_reset_defaults() -> void:
	KeybindSettings.reset_defaults()
	refresh()
	info_label.text = "All keybindings reset to defaults."


func handle_input(event: InputEvent) -> void:
	if nav == null:
		return

	if event.is_action_pressed("menu_select") and not selected_action.is_empty():
		_start_listening(1)
		return

	if event.is_action_pressed("menu_sort"):
		_on_clear_secondary()
		return

	if event.is_action_pressed("menu_reorder"):
		_on_reset_defaults()
		return

	nav.handle_input(event)


func handle_back() -> bool:
	if listening:
		listening = false
		_update_detail()
		return true
	return false
