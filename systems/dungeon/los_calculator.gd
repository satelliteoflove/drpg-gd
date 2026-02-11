class_name LOSCalculator
extends RefCounted


func has_line_of_sight(dungeon: DungeonData, from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return true

	var dx := to.x - from.x
	var dy := to.y - from.y
	var steps := maxi(abs(dx), abs(dy))

	if steps == 0:
		return true

	var x_inc := float(dx) / float(steps)
	var y_inc := float(dy) / float(steps)

	var current_x := float(from.x) + 0.5
	var current_y := float(from.y) + 0.5

	for i in range(steps):
		var check_x := int(current_x)
		var check_y := int(current_y)

		if Vector2i(check_x, check_y) == to:
			return true

		if not _can_see_through(dungeon, check_x, check_y, from, to):
			return false

		current_x += x_inc
		current_y += y_inc

	return true


func _can_see_through(dungeon: DungeonData, x: int, y: int, from: Vector2i, to: Vector2i) -> bool:
	var tile := dungeon.get_tile(x, y)
	if tile == null:
		return false

	if not tile.is_walkable():
		return false

	var prev_x := from.x if x == from.x else (x - 1 if to.x > from.x else x + 1)
	var prev_y := from.y if y == from.y else (y - 1 if to.y > from.y else y + 1)

	if x > prev_x and _wall_blocks_los(tile, "west"):
		return false
	if x < prev_x and _wall_blocks_los(tile, "east"):
		return false
	if y > prev_y and _wall_blocks_los(tile, "north"):
		return false
	if y < prev_y and _wall_blocks_los(tile, "south"):
		return false

	return true


func _wall_blocks_los(tile: DungeonTile, direction: String) -> bool:
	var wall_type := tile.get_wall_type(direction)
	if wall_type == DungeonTile.WallType.SOLID:
		return true
	if wall_type == DungeonTile.WallType.DOOR and not tile.is_door_open(direction):
		return true
	return false


func get_distance(from: Vector2i, to: Vector2i) -> int:
	return abs(to.x - from.x) + abs(to.y - from.y)


func is_in_front(player_pos: Vector2i, player_facing: int, target_pos: Vector2i) -> bool:
	var dx := target_pos.x - player_pos.x
	var dy := target_pos.y - player_pos.y

	match player_facing:
		0:
			return dy < 0
		1:
			return dx > 0
		2:
			return dy > 0
		3:
			return dx < 0

	return false


func get_visible_tiles(dungeon: DungeonData, from: Vector2i, max_range: int) -> Array[Vector2i]:
	var visible: Array[Vector2i] = []

	for dy in range(-max_range, max_range + 1):
		for dx in range(-max_range, max_range + 1):
			var pos := from + Vector2i(dx, dy)

			if abs(dx) + abs(dy) > max_range:
				continue

			if not dungeon.is_in_bounds(pos.x, pos.y):
				continue

			if has_line_of_sight(dungeon, from, pos):
				visible.append(pos)

	return visible
