class_name MenuNavigator
extends RefCounted

signal selection_changed(index: int)
signal item_confirmed(index: int)
signal cancelled()

var items: Array[Button] = []
var current_index: int = 0
var wrap_around: bool = true

# Polish toggles (set before setup() to override)
var use_cursor: bool = true
var use_sound: bool = true
var animate_entrance: bool = true

var cursor: MenuCursor = null
var _cursor_tween: Tween = null


func setup(buttons: Array[Button], initial_index: int = 0) -> void:
	items = buttons
	current_index = clampi(initial_index, 0, items.size() - 1)

	for i in items.size():
		var btn := items[i]
		var callable := _on_button_focus_entered.bind(btn)
		if not btn.focus_entered.is_connected(callable):
			btn.focus_entered.connect(callable)
		var prev := items[wrapi(i - 1, 0, items.size())]
		var next := items[wrapi(i + 1, 0, items.size())]
		btn.focus_neighbor_top = prev.get_path()
		btn.focus_neighbor_bottom = next.get_path()
		btn.focus_neighbor_left = btn.get_path()
		btn.focus_neighbor_right = btn.get_path()

	if animate_entrance:
		for b in items:
			b.modulate.a = 0.0

	if use_cursor:
		_create_cursor()

	_update_focus()
	_async_init()


func handle_input(event: InputEvent) -> bool:
	if items.is_empty():
		return false

	if event.is_action_pressed("menu_up"):
		_move(-1)
		return true
	elif event.is_action_pressed("menu_down"):
		_move(1)
		return true
	elif event.is_action_pressed("menu_confirm"):
		_confirm()
		return true
	elif event.is_action_pressed("menu_cancel"):
		_play("back")
		cancelled.emit()
		return true

	return false


func _move(direction: int) -> void:
	var new_index := current_index + direction

	if wrap_around:
		if new_index < 0:
			new_index = items.size() - 1
		elif new_index >= items.size():
			new_index = 0
	else:
		new_index = clampi(new_index, 0, items.size() - 1)

	if new_index != current_index:
		current_index = new_index
		_play("nav")
		_update_focus()
		_move_cursor(true)
		selection_changed.emit(current_index)


func _confirm() -> void:
	if current_index >= 0 and current_index < items.size():
		var btn := items[current_index]
		if not btn.disabled:
			_play("confirm")
			_pulse(btn)
			btn.pressed.emit()
			item_confirmed.emit(current_index)
		else:
			_play("denied")


func _update_focus() -> void:
	if current_index >= 0 and current_index < items.size():
		items[current_index].grab_focus()


func _on_button_focus_entered(btn: Button) -> void:
	var index := items.find(btn)
	if index >= 0 and index != current_index:
		current_index = index
		_play("hover")
		_move_cursor(true)
		selection_changed.emit(current_index)


func update_focus() -> void:
	_update_focus()


func select(index: int) -> void:
	if index >= 0 and index < items.size():
		current_index = index
		_update_focus()
		_move_cursor(true)
		selection_changed.emit(current_index)


func get_current_index() -> int:
	return current_index


func get_current_item() -> Button:
	if current_index >= 0 and current_index < items.size():
		return items[current_index]
	return null


# --- Polish internals -------------------------------------------------------

func _async_init() -> void:
	if items.is_empty():
		return
	var tree := items[0].get_tree()
	if tree == null:
		return
	await tree.process_frame
	await tree.process_frame
	_snap_cursor()
	if animate_entrance:
		_play_entrance()


func _create_cursor() -> void:
	if items.is_empty():
		return
	var host := items[0].get_parent()
	if host == null:
		return
	cursor = MenuCursor.new()
	cursor.modulate.a = 0.0
	host.add_child(cursor)


func _snap_cursor() -> void:
	if cursor == null:
		return
	var b := get_current_item()
	if b == null:
		return
	cursor.size = Vector2(22, b.size.y)
	cursor.global_position = _cursor_target(b)
	var tw := b.create_tween()
	tw.tween_property(cursor, "modulate:a", 1.0, 0.25)


func _cursor_target(b: Button) -> Vector2:
	return Vector2(b.global_position.x - cursor.size.x - 6.0, b.global_position.y)


func _move_cursor(animated: bool) -> void:
	if cursor == null:
		return
	var b := get_current_item()
	if b == null:
		return
	cursor.size.y = b.size.y
	if _cursor_tween != null and _cursor_tween.is_valid():
		_cursor_tween.kill()
	if not animated:
		cursor.global_position = _cursor_target(b)
		return
	_cursor_tween = b.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_cursor_tween.tween_property(cursor, "global_position", _cursor_target(b), 0.16)


func _play_entrance() -> void:
	for i in items.size():
		var b := items[i]
		b.pivot_offset = b.size * 0.5
		b.modulate.a = 0.0
		b.scale = Vector2(1.0, 0.82)
		var tw := b.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "modulate:a", 1.0, 0.30).set_delay(float(i) * 0.06)
		tw.tween_property(b, "scale", Vector2.ONE, 0.36) \
			.set_delay(float(i) * 0.06).set_trans(Tween.TRANS_BACK)


func _pulse(b: Button) -> void:
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween().set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2(1.04, 1.04), 0.07)
	tw.tween_property(b, "scale", Vector2.ONE, 0.12)


func _play(sound_name: String) -> void:
	if use_sound:
		AudioManager.play_ui(sound_name)
