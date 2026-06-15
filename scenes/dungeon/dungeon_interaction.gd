class_name DungeonInteraction
extends RefCounted

var dungeon


func init(p_dungeon: Node3D) -> void:
	dungeon = p_dungeon


func interact() -> void:
	var dir = dungeon._get_facing_direction_string()
	var tile = dungeon.dungeon_data.get_tile(dungeon.grid_position.x, dungeon.grid_position.y)
	if tile == null:
		return

	if tile.get_wall_type(dir) != DungeonTile.WallType.DOOR:
		return

	if tile.is_door_open(dir):
		return

	if tile.is_door_locked(dir):
		if dungeon._informed_locked_pos != dungeon.grid_position or dungeon._informed_locked_dir != dir:
			dungeon._informed_locked_pos = dungeon.grid_position
			dungeon._informed_locked_dir = dir
			dungeon._show_dungeon_message("The door is locked.")
			return
		_try_unlock_door(dir)
	else:
		_open_door_and_step(dungeon.grid_position.x, dungeon.grid_position.y, dir, "You open the door.")


func open_door_and_step(x: int, y: int, direction: String, message: String) -> void:
	_open_door_and_step(x, y, direction, message)


func close_doors_behind() -> void:
	if dungeon.previous_grid_position == dungeon.grid_position:
		return

	var dx = dungeon.grid_position.x - dungeon.previous_grid_position.x
	var dy = dungeon.grid_position.y - dungeon.previous_grid_position.y

	var move_dir := ""
	if dy < 0: move_dir = "north"
	elif dy > 0: move_dir = "south"
	elif dx > 0: move_dir = "east"
	elif dx < 0: move_dir = "west"

	if move_dir == "":
		return

	var prev_tile = dungeon.dungeon_data.get_tile(dungeon.previous_grid_position.x, dungeon.previous_grid_position.y)
	if prev_tile == null:
		return

	if prev_tile.get_wall_type(move_dir) == DungeonTile.WallType.DOOR and prev_tile.is_door_open(move_dir):
		dungeon.dungeon_data.sync_door_open(dungeon.previous_grid_position.x, dungeon.previous_grid_position.y, move_dir, false)
		dungeon._update_door_visual(dungeon.previous_grid_position.x, dungeon.previous_grid_position.y, move_dir)
		dungeon._update_door_visual(dungeon.grid_position.x, dungeon.grid_position.y, DungeonData.OPPOSITE_DIR[move_dir])


func _open_door_and_step(x: int, y: int, direction: String, message: String) -> void:
	AudioManager.play_sfx_path("res://audio/sfx/door.wav")
	dungeon.dungeon_data.sync_door_open(x, y, direction, true)
	dungeon._update_door_visual(x, y, direction)
	var offset: Vector2i = DungeonData.DIR_OFFSET[direction]
	dungeon._update_door_visual(x + offset.x, y + offset.y, DungeonData.OPPOSITE_DIR[direction])
	dungeon._show_dungeon_message(message)
	dungeon.movement.move_forward()


func _try_unlock_door(direction: String) -> void:
	if GameState.party == null:
		dungeon._show_dungeon_message("The door is locked.")
		return

	# TODO: lockpicking is just a dice roll right now - replace with a mini-game
	if GameState.party.has_living_thief():
		var thief := GameState.party.get_living_thief()
		var pick_chance := 0.25 + (thief.agility * 0.02) + (thief.level * 0.03)
		pick_chance = clampf(pick_chance, 0.10, 0.95)
		if randf() < pick_chance:
			dungeon.dungeon_data.sync_door_locked(dungeon.grid_position.x, dungeon.grid_position.y, direction, false)
			dungeon._informed_locked_pos = Vector2i(-1, -1)
			dungeon._informed_locked_dir = ""
			_open_door_and_step(dungeon.grid_position.x, dungeon.grid_position.y, direction, "%s picks the lock!" % thief.get_display_name())
		else:
			dungeon._show_dungeon_message("%s fails to pick the lock." % thief.get_display_name())
		return

	if GameState.party.inventory.has_item("dungeon_key"):
		GameState.party.inventory.remove_item("dungeon_key", 1)
		dungeon.dungeon_data.sync_door_locked(dungeon.grid_position.x, dungeon.grid_position.y, direction, false)
		dungeon._informed_locked_pos = Vector2i(-1, -1)
		dungeon._informed_locked_dir = ""
		_open_door_and_step(dungeon.grid_position.x, dungeon.grid_position.y, direction, "You use a Dungeon Key.")
		return

	dungeon._show_dungeon_message("The door is locked.")
