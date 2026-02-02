class_name DungeonGenerator
extends RefCounted

const MIN_ROOM_SIZE: int = 3
const MAX_ROOM_EXTRA: int = 5
const ROOM_ATTEMPTS: int = 50
const WINDING_PERCENT: int = 60
const EXTRA_CONNECTOR_CHANCE: float = 0.20
const DOOR_CHANCE: float = 0.70

var width: int = 31
var height: int = 31
var floor_level: int = 1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _tiles: Array[DungeonTile] = []
var _rooms: Array[DungeonRoom] = []
var _regions: Array[int] = []
var _current_region: int = -1


func generate(p_width: int, p_height: int, p_floor: int, p_seed: int = 0) -> DungeonData:
	width = _make_odd(p_width)
	height = _make_odd(p_height)
	floor_level = p_floor

	if p_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = p_seed

	_init_tiles()
	_place_rooms()
	_fill_mazes()
	_connect_regions()
	_remove_dead_ends()
	_update_walls()

	var dungeon: DungeonData = DungeonData.new()
	dungeon.width = width
	dungeon.height = height
	dungeon.floor_level = floor_level
	dungeon.seed_value = _rng.seed
	dungeon.tiles = _tiles.duplicate()
	dungeon.rooms = _rooms.duplicate()

	_place_stairs(dungeon)
	_assign_zones(dungeon)

	return dungeon


func _make_odd(value: int) -> int:
	if value % 2 == 0:
		return value + 1
	return value


func _init_tiles() -> void:
	_tiles.clear()
	_regions.clear()
	_tiles.resize(width * height)
	_regions.resize(width * height)

	for y in range(height):
		for x in range(width):
			var tile: DungeonTile = DungeonTile.new()
			tile.x = x
			tile.y = y
			tile.type = DungeonTile.TileType.SOLID
			tile.region = -1
			_tiles[y * width + x] = tile
			_regions[y * width + x] = -1


func _get_tile(x: int, y: int) -> DungeonTile:
	if x < 0 or x >= width or y < 0 or y >= height:
		return null
	return _tiles[y * width + x]


func _set_tile_type(x: int, y: int, type: DungeonTile.TileType) -> void:
	var tile: DungeonTile = _get_tile(x, y)
	if tile:
		tile.type = type
		if type == DungeonTile.TileType.FLOOR:
			tile.region = _current_region
			_regions[y * width + x] = _current_region


func _carve(x: int, y: int) -> void:
	_set_tile_type(x, y, DungeonTile.TileType.FLOOR)


func _is_solid(x: int, y: int) -> bool:
	var tile: DungeonTile = _get_tile(x, y)
	return tile == null or tile.type == DungeonTile.TileType.SOLID


func _place_rooms() -> void:
	_rooms.clear()

	for attempt in range(ROOM_ATTEMPTS):
		var room_width: int = _make_odd(MIN_ROOM_SIZE + _rng.randi() % (MAX_ROOM_EXTRA + 1))
		var room_height: int = _make_odd(MIN_ROOM_SIZE + _rng.randi() % (MAX_ROOM_EXTRA + 1))

		var max_x: int = (width - room_width - 1) / 2
		var max_y: int = (height - room_height - 1) / 2

		if max_x < 1 or max_y < 1:
			continue

		var room_x: int = _rng.randi() % max_x * 2 + 1
		var room_y: int = _rng.randi() % max_y * 2 + 1

		var room: DungeonRoom = DungeonRoom.new()
		room.id = "room_" + str(_rooms.size())
		room.x = room_x
		room.y = room_y
		room.width = room_width
		room.height = room_height

		var overlaps: bool = false
		for existing in _rooms:
			if room.overlaps(existing, 1):
				overlaps = true
				break

		if overlaps:
			continue

		if room_width >= 5 and room_height >= 5:
			room.size_type = DungeonRoom.RoomSize.LARGE
		elif room_width >= 4 or room_height >= 4:
			room.size_type = DungeonRoom.RoomSize.MEDIUM
		else:
			room.size_type = DungeonRoom.RoomSize.SMALL

		_rooms.append(room)
		_current_region += 1

		for ry in range(room.y, room.y + room.height):
			for rx in range(room.x, room.x + room.width):
				_carve(rx, ry)


func _fill_mazes() -> void:
	for y in range(1, height, 2):
		for x in range(1, width, 2):
			if _is_solid(x, y):
				_current_region += 1
				_grow_maze(x, y)


func _grow_maze(start_x: int, start_y: int) -> void:
	var cells: Array[Vector2i] = []
	var last_dir: Vector2i = Vector2i.ZERO

	_carve(start_x, start_y)
	cells.append(Vector2i(start_x, start_y))

	var directions: Array[Vector2i] = [
		Vector2i(0, -2),
		Vector2i(0, 2),
		Vector2i(-2, 0),
		Vector2i(2, 0)
	]

	while cells.size() > 0:
		var cell: Vector2i = cells[-1]
		var unmade: Array[Vector2i] = []

		for dir in directions:
			var nx: int = cell.x + dir.x
			var ny: int = cell.y + dir.y
			if nx > 0 and nx < width - 1 and ny > 0 and ny < height - 1:
				if _is_solid(nx, ny):
					unmade.append(dir)

		if unmade.size() > 0:
			var dir: Vector2i
			if last_dir in unmade and _rng.randi() % 100 < WINDING_PERCENT:
				dir = last_dir
			else:
				dir = unmade[_rng.randi() % unmade.size()]

			var mid_x: int = cell.x + dir.x / 2
			var mid_y: int = cell.y + dir.y / 2
			var end_x: int = cell.x + dir.x
			var end_y: int = cell.y + dir.y

			_carve(mid_x, mid_y)
			_carve(end_x, end_y)

			cells.append(Vector2i(end_x, end_y))
			last_dir = dir
		else:
			cells.pop_back()
			last_dir = Vector2i.ZERO


func _connect_regions() -> void:
	var connectors: Array[Dictionary] = []

	for y in range(1, height - 1):
		for x in range(1, width - 1):
			if not _is_solid(x, y):
				continue

			var adjacent_regions: Array[int] = []
			for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var nx: int = x + dir.x
				var ny: int = y + dir.y
				var region: int = _regions[ny * width + nx] if nx >= 0 and nx < width and ny >= 0 and ny < height else -1
				if region >= 0 and region not in adjacent_regions:
					adjacent_regions.append(region)

			if adjacent_regions.size() >= 2:
				connectors.append({"x": x, "y": y, "regions": adjacent_regions})

	var merged: Array[int] = []
	merged.resize(_current_region + 1)
	for i in range(merged.size()):
		merged[i] = i

	var open_regions: int = _current_region + 1

	connectors.shuffle()

	for conn in connectors:
		var regions: Array = conn["regions"]
		var dest: int = _find_root(merged, regions[0])
		var all_same: bool = true

		for r in regions:
			if _find_root(merged, r) != dest:
				all_same = false
				break

		if all_same:
			if _rng.randf() < EXTRA_CONNECTOR_CHANCE:
				_carve(conn["x"], conn["y"])
			continue

		_carve(conn["x"], conn["y"])

		for r in regions:
			var root: int = _find_root(merged, r)
			if root != dest:
				merged[root] = dest
				open_regions -= 1

		if open_regions <= 1:
			break


func _find_root(merged: Array[int], region: int) -> int:
	while merged[region] != region:
		merged[region] = merged[merged[region]]
		region = merged[region]
	return region


func _remove_dead_ends() -> void:
	var done := false
	while not done:
		done = true
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var tile := _get_tile(x, y)
				if tile == null or tile.type != DungeonTile.TileType.FLOOR:
					continue

				if _is_in_room(x, y):
					continue

				var exits := 0
				if not _is_solid(x, y - 1):
					exits += 1
				if not _is_solid(x, y + 1):
					exits += 1
				if not _is_solid(x - 1, y):
					exits += 1
				if not _is_solid(x + 1, y):
					exits += 1

				if exits <= 1:
					tile.type = DungeonTile.TileType.SOLID
					done = false


func _is_in_room(x: int, y: int) -> bool:
	for room in _rooms:
		if x >= room.x and x < room.x + room.width:
			if y >= room.y and y < room.y + room.height:
				return true
	return false


func _update_walls() -> void:
	for y in range(height):
		for x in range(width):
			var tile: DungeonTile = _get_tile(x, y)
			if tile == null or tile.type == DungeonTile.TileType.SOLID:
				continue

			if y == 0 or _is_solid(x, y - 1):
				tile.north_wall = DungeonTile.WallType.SOLID
			if y == height - 1 or _is_solid(x, y + 1):
				tile.south_wall = DungeonTile.WallType.SOLID
			if x == 0 or _is_solid(x - 1, y):
				tile.west_wall = DungeonTile.WallType.SOLID
			if x == width - 1 or _is_solid(x + 1, y):
				tile.east_wall = DungeonTile.WallType.SOLID


func _place_stairs(dungeon: DungeonData) -> void:
	if _rooms.size() < 2:
		return

	var start_room: DungeonRoom = _rooms[0]
	var stairs_up: Vector2i = start_room.get_center()
	dungeon.stairs_up_pos = stairs_up

	var up_tile: DungeonTile = dungeon.get_tile(stairs_up.x, stairs_up.y)
	if up_tile:
		up_tile.special = DungeonTile.SpecialType.STAIRS_UP

	var farthest_room: DungeonRoom = _rooms[0]
	var max_dist: float = 0.0

	for room in _rooms:
		var center: Vector2i = room.get_center()
		var dist: float = stairs_up.distance_to(center)
		if dist > max_dist:
			max_dist = dist
			farthest_room = room

	var stairs_down: Vector2i = farthest_room.get_center()
	dungeon.stairs_down_pos = stairs_down

	var down_tile: DungeonTile = dungeon.get_tile(stairs_down.x, stairs_down.y)
	if down_tile:
		down_tile.special = DungeonTile.SpecialType.STAIRS_DOWN


func _assign_zones(dungeon: DungeonData) -> void:
	var safe_up := EncounterZone.create_safe_zone("safe_up", dungeon.stairs_up_pos, 2)
	dungeon.add_zone(safe_up)

	var safe_down := EncounterZone.create_safe_zone("safe_down", dungeon.stairs_down_pos, 2)
	dungeon.add_zone(safe_down)

	for room in _rooms:
		var room_center := room.get_center()

		if safe_up.contains_position(room_center) or safe_down.contains_position(room_center):
			continue

		var zone_type := _determine_zone_type(room, dungeon)
		var tiles := _get_room_tiles(room, dungeon, safe_up, safe_down)

		if tiles.is_empty():
			continue

		var zone := EncounterZone.create(
			"zone_%s" % room.id,
			zone_type,
			tiles
		)
		zone.monster_pool = MonsterDatabase.get_monsters_for_floor(floor_level)
		dungeon.add_zone(zone)

	_assign_corridor_zones(dungeon, safe_up, safe_down)


func _determine_zone_type(room: DungeonRoom, dungeon: DungeonData) -> EncounterZone.ZoneType:
	var dist_up := room.get_center().distance_to(dungeon.stairs_up_pos)
	var dist_down := room.get_center().distance_to(dungeon.stairs_down_pos)
	var min_dist := minf(dist_up, dist_down)

	if room.size_type == DungeonRoom.RoomSize.LARGE:
		if min_dist > 15:
			return EncounterZone.ZoneType.BOSS
		return EncounterZone.ZoneType.HIGH_SPAWN

	if min_dist < 8:
		return EncounterZone.ZoneType.LOW_SPAWN

	if min_dist > 15:
		return EncounterZone.ZoneType.HIGH_SPAWN

	return EncounterZone.ZoneType.NORMAL


func _get_room_tiles(
	room: DungeonRoom,
	dungeon: DungeonData,
	safe_up: EncounterZone,
	safe_down: EncounterZone
) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []

	for ry in range(room.y, room.y + room.height):
		for rx in range(room.x, room.x + room.width):
			var pos := Vector2i(rx, ry)

			if safe_up.contains_position(pos) or safe_down.contains_position(pos):
				continue

			var tile := dungeon.get_tile(rx, ry)
			if tile == null or not tile.is_walkable():
				continue

			tiles.append(pos)

	return tiles


func _assign_corridor_zones(
	dungeon: DungeonData,
	safe_up: EncounterZone,
	safe_down: EncounterZone
) -> void:
	var unassigned_tiles: Array[Vector2i] = []

	for y in range(height):
		for x in range(width):
			var tile := dungeon.get_tile(x, y)
			if tile == null or not tile.is_walkable():
				continue

			if tile.encounter_zone_id != "":
				continue

			var pos := Vector2i(x, y)
			if safe_up.contains_position(pos) or safe_down.contains_position(pos):
				continue

			unassigned_tiles.append(pos)

	if unassigned_tiles.is_empty():
		return

	var corridor_zone := EncounterZone.create(
		"corridor_zone",
		EncounterZone.ZoneType.LOW_SPAWN,
		unassigned_tiles
	)
	corridor_zone.monster_pool = MonsterDatabase.get_monsters_for_floor(floor_level)
	dungeon.add_zone(corridor_zone)
