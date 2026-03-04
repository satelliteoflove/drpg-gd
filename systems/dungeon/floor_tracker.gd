class_name FloorTracker
extends RefCounted

signal enemy_spotted(group_id: String)
signal reveal_expired
signal step_taken(total_steps: int)

const STEPS_PER_DAY: int = 120

var global_step_count: int = 0
var accumulated_steps: int = 0
var spotted_groups: Dictionary = {}
var reveal_active: bool = false
var reveal_steps_remaining: int = 0
var current_floor: int = 0


func increment_step() -> void:
	global_step_count += 1
	accumulated_steps += 1
	if reveal_active:
		reveal_steps_remaining -= 1
		if reveal_steps_remaining <= 0:
			reveal_active = false
			reveal_expired.emit()
	step_taken.emit(global_step_count)


func register_spotted(group_id: String) -> void:
	if not spotted_groups.has(group_id):
		spotted_groups[group_id] = true
		enemy_spotted.emit(group_id)


func is_spotted(group_id: String) -> bool:
	return spotted_groups.has(group_id)


func clear_spotted_for_floor() -> void:
	spotted_groups.clear()


func activate_reveal(duration: int) -> void:
	reveal_active = true
	reveal_steps_remaining = duration


func is_revealed() -> bool:
	return reveal_active


func toggle_debug_reveal() -> bool:
	if reveal_active and reveal_steps_remaining == 999999:
		reveal_active = false
		reveal_steps_remaining = 0
		return false
	else:
		reveal_active = true
		reveal_steps_remaining = 999999
		return true


func get_reveal_remaining() -> int:
	if not reveal_active:
		return 0
	return reveal_steps_remaining


func set_floor(floor_num: int) -> void:
	if floor_num != current_floor:
		current_floor = floor_num
		clear_spotted_for_floor()


func consume_dungeon_days() -> int:
	var days: int = accumulated_steps / STEPS_PER_DAY
	accumulated_steps = accumulated_steps % STEPS_PER_DAY
	return days


func save_state() -> Dictionary:
	return {
		"global_step_count": global_step_count,
		"accumulated_steps": accumulated_steps,
		"spotted_groups": spotted_groups.duplicate(),
		"reveal_active": reveal_active,
		"reveal_steps_remaining": reveal_steps_remaining,
		"current_floor": current_floor
	}


func load_state(data: Dictionary) -> void:
	global_step_count = data.get("global_step_count", 0)
	accumulated_steps = data.get("accumulated_steps", 0)
	spotted_groups = data.get("spotted_groups", {}).duplicate()
	reveal_active = data.get("reveal_active", false)
	reveal_steps_remaining = data.get("reveal_steps_remaining", 0)
	current_floor = data.get("current_floor", 0)
