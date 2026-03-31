class_name GridNavigator
extends RefCounted

signal selection_changed(index: int)
signal item_confirmed(index: int)
signal cancelled()

var items: Array[Button] = []
var current_index: int = 0
var _positions: Array[Vector2i] = []


func setup(buttons_by_position: Dictionary, initial_index: int = 0) -> void:
	items.clear()
	_positions.clear()

	var sorted_keys: Array = buttons_by_position.keys().duplicate()
	sorted_keys.sort_custom(_sort_grid_order)

	for pos in sorted_keys:
		_positions.append(pos)
		items.append(buttons_by_position[pos])

	current_index = clampi(initial_index, 0, max(items.size() - 1, 0))

	for i in items.size():
		var btn := items[i]
		var callable := _on_button_focus_entered.bind(btn)
		if not btn.focus_entered.is_connected(callable):
			btn.focus_entered.connect(callable)
		btn.focus_neighbor_top = btn.get_path()
		btn.focus_neighbor_bottom = btn.get_path()
		btn.focus_neighbor_left = btn.get_path()
		btn.focus_neighbor_right = btn.get_path()

	_update_focus()


func handle_input(event: InputEvent) -> bool:
	if items.is_empty():
		return false

	if event.is_action_pressed("menu_up"):
		move(Vector2i(0, 1))
		return true
	elif event.is_action_pressed("menu_down"):
		move(Vector2i(0, -1))
		return true
	elif event.is_action_pressed("menu_left"):
		move(Vector2i(-1, 0))
		return true
	elif event.is_action_pressed("menu_right"):
		move(Vector2i(1, 0))
		return true
	elif event.is_action_pressed("menu_confirm"):
		confirm()
		return true
	elif event.is_action_pressed("menu_cancel"):
		cancelled.emit()
		return true

	return false


func move(dir: Vector2i) -> void:
	if items.size() <= 1:
		return
	var from := _positions[current_index]
	var new_index := -1
	if dir.x != 0:
		new_index = _find_horizontal(from, dir.x)
	elif dir.y != 0:
		new_index = _find_vertical(from, dir.y)
	if new_index >= 0 and new_index != current_index:
		current_index = new_index
		_update_focus()
		selection_changed.emit(current_index)


func confirm() -> void:
	if current_index >= 0 and current_index < items.size():
		var btn := items[current_index]
		if not btn.disabled:
			btn.pressed.emit()
			item_confirmed.emit(current_index)


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


func update_focus() -> void:
	_update_focus()


func _find_horizontal(from: Vector2i, dir_x: int) -> int:
	var same_row: Array[int] = []
	for i in _positions.size():
		if _positions[i].y == from.y and i != current_index:
			same_row.append(i)
	if same_row.is_empty():
		return -1
	same_row.sort_custom(func(a: int, b: int) -> bool: return _positions[a].x < _positions[b].x)
	if dir_x > 0:
		for i in same_row:
			if _positions[i].x > from.x:
				return i
		return same_row[0]
	else:
		for i in range(same_row.size() - 1, -1, -1):
			if _positions[same_row[i]].x < from.x:
				return same_row[i]
		return same_row[-1]


func _find_vertical(from: Vector2i, dir_y: int) -> int:
	var forward: Dictionary = {}
	var other_rows: Dictionary = {}
	for i in _positions.size():
		if i == current_index:
			continue
		var pos := _positions[i]
		if (dir_y > 0 and pos.y > from.y) or (dir_y < 0 and pos.y < from.y):
			if not forward.has(pos.y):
				forward[pos.y] = []
			forward[pos.y].append(i)
		if pos.y != from.y:
			if not other_rows.has(pos.y):
				other_rows[pos.y] = []
			other_rows[pos.y].append(i)

	var pool: Dictionary = forward if not forward.is_empty() else other_rows
	if pool.is_empty():
		return -1

	var rows: Array = pool.keys()
	rows.sort()
	var target_row: int
	if not forward.is_empty():
		target_row = rows[0] if dir_y > 0 else rows[-1]
	else:
		target_row = rows[0] if dir_y < 0 else rows[-1]

	var candidates: Array = pool[target_row]
	candidates.sort_custom(func(a: int, b: int) -> bool:
		return abs(_positions[a].x - from.x) < abs(_positions[b].x - from.x))
	return candidates[0]


func _update_focus() -> void:
	if current_index >= 0 and current_index < items.size():
		items[current_index].grab_focus()


func _on_button_focus_entered(btn: Button) -> void:
	var index := items.find(btn)
	if index >= 0 and index != current_index:
		current_index = index
		selection_changed.emit(current_index)


func _sort_grid_order(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y > b.y
	return a.x < b.x
