class_name KeyBindingHelper
extends RefCounted


static func get_action_key(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "?"

	var event := events[0]
	if event is InputEventKey:
		return _key_to_string(event.keycode)
	return "?"


static func _key_to_string(keycode: int) -> String:
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
		_: return OS.get_keycode_string(keycode)


static func get_nav_help() -> String:
	var up := get_action_key("menu_up")
	var down := get_action_key("menu_down")
	return "%s/%s: Navigate" % [up, down]


static func get_horizontal_help() -> String:
	var left := get_action_key("menu_left")
	var right := get_action_key("menu_right")
	return "%s/%s: Switch" % [left, right]


static func get_confirm_help() -> String:
	return "%s: Select" % get_action_key("menu_confirm")


static func get_cancel_help() -> String:
	return "%s: Back" % get_action_key("menu_cancel")


static func get_arrow_nav_help() -> String:
	var up := get_action_key("menu_up")
	var down := get_action_key("menu_down")
	var left := get_action_key("menu_left")
	var right := get_action_key("menu_right")
	return "%s/%s/%s/%s: Navigate" % [up, down, left, right]
