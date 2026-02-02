class_name DungeonPathfinding
extends RefCounted

var _dungeon: DungeonData
var _astar: AStar2D


func initialize(data: DungeonData) -> void:
	_dungeon = data
	_build_graph()


func _build_graph() -> void:
	_astar = AStar2D.new()

	for y in range(_dungeon.height):
		for x in range(_dungeon.width):
			var tile := _dungeon.get_tile(x, y)
			if tile == null or not tile.is_walkable():
				continue

			var id := _get_point_id(x, y)
			_astar.add_point(id, Vector2(x, y))

	for y in range(_dungeon.height):
		for x in range(_dungeon.width):
			var tile := _dungeon.get_tile(x, y)
			if tile == null or not tile.is_walkable():
				continue

			var id := _get_point_id(x, y)

			if tile.north_wall != DungeonTile.WallType.SOLID:
				_try_connect(id, x, y - 1)
			if tile.south_wall != DungeonTile.WallType.SOLID:
				_try_connect(id, x, y + 1)
			if tile.east_wall != DungeonTile.WallType.SOLID:
				_try_connect(id, x + 1, y)
			if tile.west_wall != DungeonTile.WallType.SOLID:
				_try_connect(id, x - 1, y)


func _get_point_id(x: int, y: int) -> int:
	return y * _dungeon.width + x


func _try_connect(from_id: int, to_x: int, to_y: int) -> void:
	if not _dungeon.is_in_bounds(to_x, to_y):
		return

	var to_tile := _dungeon.get_tile(to_x, to_y)
	if to_tile == null or not to_tile.is_walkable():
		return

	var to_id := _get_point_id(to_x, to_y)
	if not _astar.has_point(to_id):
		return

	if not _astar.are_points_connected(from_id, to_id):
		_astar.connect_points(from_id, to_id)


func get_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	var from_id := _get_point_id(from.x, from.y)
	var to_id := _get_point_id(to.x, to.y)

	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		return result

	var path := _astar.get_point_path(from_id, to_id)
	for point in path:
		result.append(Vector2i(int(point.x), int(point.y)))

	return result


func get_next_step(from: Vector2i, to: Vector2i, avoid_doors: bool = false) -> Vector2i:
	if from == to:
		return from

	var path := get_path(from, to)
	if path.size() < 2:
		return from

	var next := path[1]

	if avoid_doors:
		var from_tile := _dungeon.get_tile(from.x, from.y)
		if from_tile != null:
			var dx := next.x - from.x
			var dy := next.y - from.y

			var wall_type := DungeonTile.WallType.NONE
			if dy < 0:
				wall_type = from_tile.north_wall
			elif dy > 0:
				wall_type = from_tile.south_wall
			elif dx > 0:
				wall_type = from_tile.east_wall
			elif dx < 0:
				wall_type = from_tile.west_wall

			if wall_type == DungeonTile.WallType.DOOR:
				return from

	return next


func get_random_adjacent(pos: Vector2i) -> Vector2i:
	var candidates: Array[Vector2i] = []

	var tile := _dungeon.get_tile(pos.x, pos.y)
	if tile == null:
		return pos

	if tile.north_wall != DungeonTile.WallType.SOLID and _dungeon.is_walkable(pos.x, pos.y - 1):
		candidates.append(Vector2i(pos.x, pos.y - 1))
	if tile.south_wall != DungeonTile.WallType.SOLID and _dungeon.is_walkable(pos.x, pos.y + 1):
		candidates.append(Vector2i(pos.x, pos.y + 1))
	if tile.east_wall != DungeonTile.WallType.SOLID and _dungeon.is_walkable(pos.x + 1, pos.y):
		candidates.append(Vector2i(pos.x + 1, pos.y))
	if tile.west_wall != DungeonTile.WallType.SOLID and _dungeon.is_walkable(pos.x - 1, pos.y):
		candidates.append(Vector2i(pos.x - 1, pos.y))

	if candidates.is_empty():
		return pos

	return candidates[randi() % candidates.size()]


func get_flee_direction(pos: Vector2i, threat_pos: Vector2i) -> Vector2i:
	var tile := _dungeon.get_tile(pos.x, pos.y)
	if tile == null:
		return pos

	var best_pos := pos
	var best_dist := 0

	var candidates: Array[Vector2i] = []

	if tile.north_wall != DungeonTile.WallType.SOLID and _dungeon.is_walkable(pos.x, pos.y - 1):
		candidates.append(Vector2i(pos.x, pos.y - 1))
	if tile.south_wall != DungeonTile.WallType.SOLID and _dungeon.is_walkable(pos.x, pos.y + 1):
		candidates.append(Vector2i(pos.x, pos.y + 1))
	if tile.east_wall != DungeonTile.WallType.SOLID and _dungeon.is_walkable(pos.x + 1, pos.y):
		candidates.append(Vector2i(pos.x + 1, pos.y))
	if tile.west_wall != DungeonTile.WallType.SOLID and _dungeon.is_walkable(pos.x - 1, pos.y):
		candidates.append(Vector2i(pos.x - 1, pos.y))

	for candidate in candidates:
		var dist: int = abs(candidate.x - threat_pos.x) + abs(candidate.y - threat_pos.y)
		if dist > best_dist:
			best_dist = dist
			best_pos = candidate

	return best_pos
