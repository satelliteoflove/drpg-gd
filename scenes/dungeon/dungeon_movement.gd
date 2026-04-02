class_name DungeonMovement
extends RefCounted

const CELL_SIZE: float = 2.0
const CAMERA_HEIGHT: float = 1.6
const MOVE_DURATION: float = 0.40
const TURN_DURATION: float = 0.32
const HEAD_BOB_AMOUNT: float = 0.02
const HEAD_BOB_SPEED: float = 2.0

var dungeon


func init(p_dungeon: Node3D) -> void:
	dungeon = p_dungeon


func move_forward() -> void:
	var direction: Vector2i = get_facing_vector()
	var new_pos: Vector2i = dungeon.grid_position + direction

	if can_move_to(dungeon.grid_position, new_pos):
		dungeon.previous_grid_position = dungeon.grid_position
		dungeon.grid_position = new_pos
		_animate_move_to(new_pos)


func move_backward() -> void:
	var direction: Vector2i = get_facing_vector()
	var new_pos: Vector2i = dungeon.grid_position - direction

	if can_move_to(dungeon.grid_position, new_pos):
		dungeon.previous_grid_position = dungeon.grid_position
		dungeon.grid_position = new_pos
		_animate_move_to(new_pos)


func strafe_left() -> void:
	var direction: Vector2i = get_strafe_vector(-1)
	var new_pos: Vector2i = dungeon.grid_position + direction

	if can_move_to(dungeon.grid_position, new_pos):
		dungeon.previous_grid_position = dungeon.grid_position
		dungeon.grid_position = new_pos
		_animate_move_to(new_pos)


func strafe_right() -> void:
	var direction: Vector2i = get_strafe_vector(1)
	var new_pos: Vector2i = dungeon.grid_position + direction

	if can_move_to(dungeon.grid_position, new_pos):
		dungeon.previous_grid_position = dungeon.grid_position
		dungeon.grid_position = new_pos
		_animate_move_to(new_pos)


func turn_left() -> void:
	var old_facing = dungeon.facing
	dungeon.facing = ((dungeon.facing - 1 + 4) % 4)
	_animate_turn(old_facing, -1)


func turn_right() -> void:
	var old_facing = dungeon.facing
	dungeon.facing = ((dungeon.facing + 1) % 4)
	_animate_turn(old_facing, 1)


func update_camera_transform() -> void:
	dungeon.camera.position = Vector3(
		dungeon.grid_position.x * CELL_SIZE + CELL_SIZE / 2.0,
		CAMERA_HEIGHT,
		dungeon.grid_position.y * CELL_SIZE + CELL_SIZE / 2.0
	)
	dungeon.camera.rotation_degrees.y = -dungeon.facing * 90.0


func get_facing_vector() -> Vector2i:
	match dungeon.facing:
		0: return Vector2i(0, -1)
		1: return Vector2i(1, 0)
		2: return Vector2i(0, 1)
		3: return Vector2i(-1, 0)
	return Vector2i.ZERO


func get_strafe_vector(direction: int) -> Vector2i:
	match dungeon.facing:
		0: return Vector2i(direction, 0)
		1: return Vector2i(0, direction)
		2: return Vector2i(-direction, 0)
		3: return Vector2i(0, -direction)
	return Vector2i.ZERO


func can_move_to(from: Vector2i, to: Vector2i) -> bool:
	if not dungeon.dungeon_data.is_walkable(to.x, to.y):
		return false

	var from_tile: DungeonTile = dungeon.dungeon_data.get_tile(from.x, from.y)
	if from_tile == null:
		return false

	var dx: int = to.x - from.x
	var dy: int = to.y - from.y

	var dir := ""
	if dy < 0: dir = "north"
	elif dy > 0: dir = "south"
	elif dx < 0: dir = "west"
	elif dx > 0: dir = "east"

	if dir != "" and _is_wall_blocking(from_tile, dir):
		return false

	var to_tile: DungeonTile = dungeon.dungeon_data.get_tile(to.x, to.y)
	if to_tile != null and dir != "":
		var opposite: String = DungeonData.OPPOSITE_DIR[dir]
		if _is_wall_blocking(to_tile, opposite):
			return false

	return true


func _animate_move_to(target_grid: Vector2i) -> void:
	dungeon.is_moving = true

	var target_pos := Vector3(
		target_grid.x * CELL_SIZE + CELL_SIZE / 2.0,
		CAMERA_HEIGHT,
		target_grid.y * CELL_SIZE + CELL_SIZE / 2.0
	)

	if dungeon.move_tween:
		dungeon.move_tween.kill()

	dungeon.move_tween = dungeon.create_tween()
	dungeon.move_tween.set_ease(Tween.EASE_OUT)
	dungeon.move_tween.set_trans(Tween.TRANS_SINE)
	dungeon.move_tween.set_parallel(true)
	dungeon.move_tween.tween_property(dungeon.camera, "position", target_pos, MOVE_DURATION)
	dungeon.move_tween.tween_method(_apply_head_bob, 0.0, 1.0, MOVE_DURATION)
	dungeon.move_tween.set_parallel(false)
	dungeon.move_tween.tween_callback(dungeon._on_move_complete)


func _apply_head_bob(t: float) -> void:
	var bob := sin(t * HEAD_BOB_SPEED * PI) * HEAD_BOB_AMOUNT
	dungeon.camera.position.y = CAMERA_HEIGHT + bob


func _animate_turn(from_facing: int, direction: int) -> void:
	dungeon.is_moving = true

	var _from_rotation := -from_facing * 90.0
	var to_rotation := -int(dungeon.facing) * 90.0

	if direction > 0 and from_facing == 3 and int(dungeon.facing) == 0:
		to_rotation = -360.0
	elif direction < 0 and from_facing == 0 and int(dungeon.facing) == 3:
		to_rotation = 90.0

	if dungeon.move_tween:
		dungeon.move_tween.kill()

	dungeon.move_tween = dungeon.create_tween()
	dungeon.move_tween.set_ease(Tween.EASE_OUT)
	dungeon.move_tween.set_trans(Tween.TRANS_SINE)
	dungeon.move_tween.tween_property(dungeon.camera, "rotation_degrees:y", to_rotation, TURN_DURATION)
	dungeon.move_tween.tween_callback(dungeon._on_turn_complete)


func _is_wall_blocking(tile: DungeonTile, direction: String) -> bool:
	var wall_type := tile.get_wall_type(direction)
	if wall_type == DungeonTile.WallType.SOLID:
		return true
	if wall_type == DungeonTile.WallType.DOOR and not tile.is_door_open(direction):
		return true
	return false
