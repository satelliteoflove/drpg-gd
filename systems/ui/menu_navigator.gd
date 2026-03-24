class_name MenuNavigator
extends RefCounted

signal selection_changed(index: int)
signal item_confirmed(index: int)
signal cancelled()

var items: Array[Button] = []
var current_index: int = 0
var wrap_around: bool = true


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

	_update_focus()


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
		_update_focus()
		selection_changed.emit(current_index)


func _confirm() -> void:
	if current_index >= 0 and current_index < items.size():
		var btn := items[current_index]
		if not btn.disabled:
			btn.pressed.emit()
			item_confirmed.emit(current_index)


func _update_focus() -> void:
	if current_index >= 0 and current_index < items.size():
		items[current_index].grab_focus()


func _on_button_focus_entered(btn: Button) -> void:
	var index := items.find(btn)
	if index >= 0 and index != current_index:
		current_index = index
		selection_changed.emit(current_index)


func update_focus() -> void:
	_update_focus()


func select(index: int) -> void:
	if index >= 0 and index < items.size():
		current_index = index
		_update_focus()
		selection_changed.emit(current_index)


func get_current_index() -> int:
	return current_index


func get_current_item() -> Button:
	if current_index >= 0 and current_index < items.size():
		return items[current_index]
	return null
