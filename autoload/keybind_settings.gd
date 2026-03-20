class_name KeybindSettingsClass
extends Node

const SAVE_PATH := "user://keybindings.cfg"

const BINDABLE_ACTIONS: Dictionary = {
	"menu_up": "Move Forward / Up",
	"menu_down": "Move Back / Down",
	"menu_left": "Turn Left / Left",
	"menu_right": "Turn Right / Right",
	"strafe_left": "Strafe Left",
	"strafe_right": "Strafe Right",
	"menu_confirm": "Confirm / Interact",
	"menu_cancel": "Cancel / Back",
	"toggle_map": "Toggle Map",
	"go_to_menu": "Open Menu",
	"go_to_town": "Return to Town",
}

var _defaults: Dictionary = {}


func _ready() -> void:
	_store_defaults()
	_load_bindings()


func _store_defaults() -> void:
	for action: String in BINDABLE_ACTIONS:
		var events := InputMap.action_get_events(action)
		var keys: Array[Dictionary] = []
		for event in events:
			if event is InputEventKey:
				keys.append(_serialize_key(event as InputEventKey))
		_defaults[action] = keys


func get_default_events(action: String) -> Array[Dictionary]:
	return _defaults.get(action, []) as Array[Dictionary]


func check_conflict(action: String, new_event: InputEventKey) -> String:
	var normalized := _normalize_event(new_event)
	for other_action: String in BINDABLE_ACTIONS:
		if other_action == action:
			continue
		for event in InputMap.action_get_events(other_action):
			if event is InputEventKey and _keys_match(event as InputEventKey, normalized):
				return BINDABLE_ACTIONS[other_action]
	return ""


func rebind_action(action: String, slot: int, new_event: InputEventKey) -> void:
	var normalized := _normalize_event(new_event)

	var key_events: Array[InputEventKey] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			key_events.append(event as InputEventKey)

	if slot < key_events.size():
		key_events[slot] = normalized
	elif slot == key_events.size():
		key_events.append(normalized)
	else:
		key_events.append(normalized)

	InputMap.action_erase_events(action)
	for key_event in key_events:
		InputMap.action_add_event(action, key_event)

	_save_bindings()


func reset_defaults() -> void:
	for action: String in BINDABLE_ACTIONS:
		InputMap.action_erase_events(action)
		var defaults: Array = _defaults.get(action, [])
		for key_data: Dictionary in defaults:
			var event := _deserialize_key(key_data)
			if event:
				InputMap.action_add_event(action, event)

	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("keybindings.cfg"):
		dir.remove("keybindings.cfg")


func get_action_keys(action: String) -> Array[InputEventKey]:
	var result: Array[InputEventKey] = []
	var events := InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			result.append(event as InputEventKey)
	return result


func key_to_label(event: InputEventKey) -> String:
	var parts: Array[String] = []
	if event.shift_pressed:
		parts.append("Shift")
	if event.ctrl_pressed:
		parts.append("Ctrl")
	if event.alt_pressed:
		parts.append("Alt")
	if event.meta_pressed:
		parts.append("Meta")

	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	var key_name := _keycode_to_string(code)
	parts.append(key_name)
	return "+".join(parts)



func _normalize_event(event: InputEventKey) -> InputEventKey:
	var normalized := InputEventKey.new()
	normalized.keycode = event.keycode if event.keycode != 0 else event.physical_keycode
	normalized.shift_pressed = event.shift_pressed
	normalized.ctrl_pressed = event.ctrl_pressed
	normalized.alt_pressed = event.alt_pressed
	normalized.meta_pressed = event.meta_pressed
	return normalized


func _keys_match(a: InputEventKey, b: InputEventKey) -> bool:
	var code_a: int = a.keycode if a.keycode != 0 else a.physical_keycode
	var code_b: int = b.keycode if b.keycode != 0 else b.physical_keycode
	return code_a == code_b and a.shift_pressed == b.shift_pressed and a.ctrl_pressed == b.ctrl_pressed and a.alt_pressed == b.alt_pressed and a.meta_pressed == b.meta_pressed


func _save_bindings() -> void:
	var config := ConfigFile.new()
	for action: String in BINDABLE_ACTIONS:
		var events := InputMap.action_get_events(action)
		var idx := 0
		for event in events:
			if event is InputEventKey:
				var data := _serialize_key(event as InputEventKey)
				config.set_value(action, "key_%d" % idx, data)
				idx += 1
		config.set_value(action, "count", idx)
	config.save(SAVE_PATH)


func _load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	for action: String in BINDABLE_ACTIONS:
		if not config.has_section(action):
			continue
		var count: int = config.get_value(action, "count", 0)
		if count == 0:
			continue

		InputMap.action_erase_events(action)
		for i in range(count):
			var data: Dictionary = config.get_value(action, "key_%d" % i, {})
			var event := _deserialize_key(data)
			if event:
				InputMap.action_add_event(action, event)


func _serialize_key(event: InputEventKey) -> Dictionary:
	return {
		"keycode": event.keycode,
		"shift": event.shift_pressed,
		"ctrl": event.ctrl_pressed,
		"alt": event.alt_pressed,
		"meta": event.meta_pressed,
	}


func _deserialize_key(data: Dictionary) -> InputEventKey:
	if data.is_empty():
		return null
	var event := InputEventKey.new()
	event.keycode = data.get("keycode", 0) as Key
	event.shift_pressed = data.get("shift", false)
	event.ctrl_pressed = data.get("ctrl", false)
	event.alt_pressed = data.get("alt", false)
	event.meta_pressed = data.get("meta", false)
	return event


func _keycode_to_string(keycode: int) -> String:
	match keycode:
		KEY_UP: return "Up"
		KEY_DOWN: return "Down"
		KEY_LEFT: return "Left"
		KEY_RIGHT: return "Right"
		KEY_ENTER: return "Enter"
		KEY_ESCAPE: return "Esc"
		KEY_SPACE: return "Space"
		KEY_TAB: return "Tab"
		KEY_BACKSPACE: return "Backspace"
		KEY_DELETE: return "Del"
		KEY_HOME: return "Home"
		KEY_END: return "End"
		KEY_PAGEUP: return "PgUp"
		KEY_PAGEDOWN: return "PgDn"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_META: return "Meta"
		_: return OS.get_keycode_string(keycode)
