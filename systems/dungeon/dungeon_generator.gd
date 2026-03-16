class_name DungeonGenerator
extends RefCounted

const MIN_ROOM_SIZE: int = 3
const MAX_ROOM_EXTRA: int = 3
const ROOM_ATTEMPTS: int = 80
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
	_place_doors()

	var dungeon: DungeonData = DungeonData.new()
	dungeon.width = width
	dungeon.height = height
	dungeon.floor_level = floor_level
	dungeon.seed_value = _rng.seed
	dungeon.tiles = _tiles.duplicate()
	dungeon.rooms = _rooms.duplicate()

	_place_stairs(dungeon)
	_lock_doors(dungeon)
	_assign_zones(dungeon)
	_place_narrative_tiles(dungeon)

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


func _place_doors() -> void:
	var doored_corridors := {}
	for room in _rooms:
		var exits: Array[Dictionary] = []
		for ry in range(room.y, room.y + room.height):
			for rx in range(room.x, room.x + room.width):
				var tile := _get_tile(rx, ry)
				if tile == null or not tile.is_walkable():
					continue
				for dir in ["north", "south", "east", "west"]:
					var offset: Vector2i = DungeonData.DIR_OFFSET[dir]
					var nx := rx + offset.x
					var ny := ry + offset.y
					if _is_in_room(nx, ny):
						continue
					var neighbor := _get_tile(nx, ny)
					if neighbor == null or not neighbor.is_walkable():
						continue
					exits.append({"rx": rx, "ry": ry, "dir": dir, "nx": nx, "ny": ny})

		var groups := _group_exits(exits)
		for group in groups:
			var mid: Dictionary = group[group.size() / 2]
			var corridor_pos := Vector2i(mid.nx, mid.ny)
			if doored_corridors.has(corridor_pos):
				continue
			doored_corridors[corridor_pos] = true
			var door_tile := _get_tile(mid.rx, mid.ry)
			var door_neighbor := _get_tile(mid.nx, mid.ny)
			door_tile.set_wall(mid.dir, DungeonTile.WallType.DOOR)
			door_neighbor.set_wall(DungeonData.OPPOSITE_DIR[mid.dir], DungeonTile.WallType.DOOR)
			for e in group:
				if e.rx == mid.rx and e.ry == mid.ry and e.dir == mid.dir:
					continue
				var wall_tile := _get_tile(e.rx, e.ry)
				var wall_neighbor := _get_tile(e.nx, e.ny)
				wall_tile.set_wall(e.dir, DungeonTile.WallType.SOLID)
				wall_neighbor.set_wall(DungeonData.OPPOSITE_DIR[e.dir], DungeonTile.WallType.SOLID)


func _group_exits(exits: Array[Dictionary]) -> Array:
	if exits.is_empty():
		return []

	var by_dir := {}
	for e in exits:
		if not by_dir.has(e.dir):
			by_dir[e.dir] = []
		by_dir[e.dir].append(e)

	var groups: Array = []
	for dir in by_dir:
		var dir_exits: Array = by_dir[dir]
		var is_horizontal: bool = dir == "north" or dir == "south"
		if is_horizontal:
			dir_exits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rx < b.rx)
		else:
			dir_exits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.ry < b.ry)

		var current_group: Array[Dictionary] = [dir_exits[0]]
		for i in range(1, dir_exits.size()):
			var prev: Dictionary = current_group[current_group.size() - 1]
			var curr: Dictionary = dir_exits[i]
			var contiguous := false
			if is_horizontal:
				contiguous = curr.rx == prev.rx + 1 and curr.ry == prev.ry
			else:
				contiguous = curr.ry == prev.ry + 1 and curr.rx == prev.rx
			if contiguous:
				current_group.append(curr)
			else:
				groups.append(current_group)
				current_group = [curr]
		groups.append(current_group)

	return groups


func _lock_doors(dungeon: DungeonData) -> void:
	var target_room: DungeonRoom = null
	for room in _rooms:
		if room.contains(dungeon.stairs_down_pos.x, dungeon.stairs_down_pos.y):
			target_room = room
			break

	if target_room == null:
		return
	var openings: Array[Dictionary] = []
	var dir_names := ["north", "south", "east", "west"]
	for ry in range(target_room.y, target_room.y + target_room.height):
		for rx in range(target_room.x, target_room.x + target_room.width):
			var tile := dungeon.get_tile(rx, ry)
			if tile == null or not tile.is_walkable():
				continue
			for dir in dir_names:
				var offset: Vector2i = DungeonData.DIR_OFFSET[dir]
				var nx := rx + offset.x
				var ny := ry + offset.y
				if target_room.contains(nx, ny):
					continue
				var wall_type := tile.get_wall_type(dir)
				if wall_type != DungeonTile.WallType.SOLID:
					openings.append({"x": rx, "y": ry, "direction": dir})

	if openings.is_empty():
		return

	var keep_idx := _rng.randi() % openings.size()
	var sealed_neighbors: Array[Vector2i] = []
	for i in range(openings.size()):
		var o: Dictionary = openings[i]
		if i == keep_idx:
			var tile := dungeon.get_tile(o.x, o.y)
			if tile.get_wall_type(o.direction) != DungeonTile.WallType.DOOR:
				var offset: Vector2i = DungeonData.DIR_OFFSET[o.direction]
				var neighbor := dungeon.get_tile(o.x + offset.x, o.y + offset.y)
				tile.set_wall(o.direction, DungeonTile.WallType.DOOR)
				if neighbor:
					neighbor.set_wall(DungeonData.OPPOSITE_DIR[o.direction], DungeonTile.WallType.DOOR)
			dungeon.sync_door_locked(o.x, o.y, o.direction, true)
		else:
			var tile := dungeon.get_tile(o.x, o.y)
			var offset: Vector2i = DungeonData.DIR_OFFSET[o.direction]
			var neighbor := dungeon.get_tile(o.x + offset.x, o.y + offset.y)
			tile.set_wall(o.direction, DungeonTile.WallType.SOLID)
			if neighbor:
				neighbor.set_wall(DungeonData.OPPOSITE_DIR[o.direction], DungeonTile.WallType.SOLID)
			sealed_neighbors.append(Vector2i(o.x + offset.x, o.y + offset.y))

	_remove_new_dead_ends(dungeon, sealed_neighbors)


func _remove_new_dead_ends(dungeon: DungeonData, starting_tiles: Array[Vector2i]) -> void:
	var queue := starting_tiles.duplicate()
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		var tile := dungeon.get_tile(pos.x, pos.y)
		if tile == null or not tile.is_walkable():
			continue
		if _is_in_room(pos.x, pos.y):
			continue
		var exits := 0
		for d in dirs:
			var neighbor := dungeon.get_tile(pos.x + d.x, pos.y + d.y)
			if neighbor != null and neighbor.is_walkable():
				var dir_name := _direction_between(pos, pos + d)
				if dir_name != "" and tile.get_wall_type(dir_name) != DungeonTile.WallType.SOLID:
					exits += 1
		if exits <= 1:
			tile.type = DungeonTile.TileType.SOLID
			tile.north_wall = DungeonTile.WallType.NONE
			tile.south_wall = DungeonTile.WallType.NONE
			tile.east_wall = DungeonTile.WallType.NONE
			tile.west_wall = DungeonTile.WallType.NONE
			for d in dirs:
				var npos := pos + d
				var neighbor := dungeon.get_tile(npos.x, npos.y)
				if neighbor != null and neighbor.is_walkable():
					var neighbor_dir := _direction_between(npos, pos)
					if neighbor_dir != "":
						neighbor.set_wall(neighbor_dir, DungeonTile.WallType.SOLID)
				queue.append(npos)


func _bfs_path(dungeon: DungeonData, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var came_from := {}
	var queue: Array[Vector2i] = [start]
	came_from[start] = start
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		if pos == goal:
			break
		var tile := dungeon.get_tile(pos.x, pos.y)
		if tile == null:
			continue
		for dir in dirs:
			var next := pos + dir
			if came_from.has(next):
				continue
			var next_tile := dungeon.get_tile(next.x, next.y)
			if next_tile == null or not next_tile.is_walkable():
				continue
			var wall_dir := _direction_between(pos, next)
			if wall_dir != "" and tile.get_wall_type(wall_dir) == DungeonTile.WallType.SOLID:
				continue
			came_from[next] = pos
			queue.append(next)

	if not came_from.has(goal):
		return []

	var path: Array[Vector2i] = []
	var current := goal
	while current != start:
		path.append(current)
		current = came_from[current]
	path.append(start)
	path.reverse()
	return path


func _direction_between(from: Vector2i, to: Vector2i) -> String:
	var dx := to.x - from.x
	var dy := to.y - from.y
	if dy < 0: return "north"
	if dy > 0: return "south"
	if dx > 0: return "east"
	if dx < 0: return "west"
	return ""


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
	var safe_up := EncounterZone.create_safe_zone("safe_up", dungeon.stairs_up_pos, 1)
	dungeon.add_zone(safe_up)

	var safe_down := EncounterZone.create_safe_zone("safe_down", dungeon.stairs_down_pos, 1)
	dungeon.add_zone(safe_down)

	var has_boss_zone := false

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
		if zone_type == EncounterZone.ZoneType.BOSS:
			zone.monster_pool = []
			has_boss_zone = true
		else:
			zone.monster_pool = MonsterDatabase.get_monsters_for_floor(floor_level)
		dungeon.add_zone(zone)

	if not has_boss_zone and MonsterDatabase.get_boss_for_floor(floor_level) != null:
		_create_boss_zone_near_stairs_down(dungeon, safe_down)

	_assign_corridor_zones(dungeon, safe_up, safe_down)


func _create_boss_zone_near_stairs_down(dungeon: DungeonData, safe_down: EncounterZone) -> void:
	var walk_distances := _flood_fill_distances(dungeon, dungeon.stairs_down_pos)

	var candidates: Array[Vector2i] = []
	for pos: Vector2i in walk_distances:
		var dist: int = walk_distances[pos]
		if dist < 3 or dist > 6:
			continue
		if safe_down.contains_position(pos):
			continue
		var tile := dungeon.get_tile(pos.x, pos.y)
		if tile.encounter_zone_id != "":
			continue
		candidates.append(pos)

	if candidates.is_empty():
		for pos: Vector2i in walk_distances:
			var dist: int = walk_distances[pos]
			if dist < 3 or dist > 10:
				continue
			if safe_down.contains_position(pos):
				continue
			var tile := dungeon.get_tile(pos.x, pos.y)
			if tile.encounter_zone_id != "":
				continue
			candidates.append(pos)

	if candidates.is_empty():
		return

	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return walk_distances[a] < walk_distances[b]
	)

	var boss_tiles: Array[Vector2i] = []
	for i in range(mini(candidates.size(), 4)):
		boss_tiles.append(candidates[i])

	var zone := EncounterZone.create("boss_zone", EncounterZone.ZoneType.BOSS, boss_tiles)
	zone.monster_pool = []
	dungeon.add_zone(zone)


func _flood_fill_distances(dungeon: DungeonData, start: Vector2i) -> Dictionary:
	var distances := {}
	var queue: Array[Vector2i] = [start]
	distances[start] = 0
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		var dist: int = distances[pos]
		for dir in directions:
			var next := pos + dir
			if distances.has(next):
				continue
			var tile := dungeon.get_tile(next.x, next.y)
			if tile == null or not tile.is_walkable():
				continue
			distances[next] = dist + 1
			queue.append(next)

	return distances


func _determine_zone_type(room: DungeonRoom, dungeon: DungeonData) -> EncounterZone.ZoneType:
	var dist_up := room.get_center().distance_to(dungeon.stairs_up_pos)
	var dist_down := room.get_center().distance_to(dungeon.stairs_down_pos)
	var min_dist := minf(dist_up, dist_down)

	if room.size_type == DungeonRoom.RoomSize.LARGE:
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


func _place_narrative_tiles(dungeon: DungeonData) -> void:
	var candidates: Array[DungeonRoom] = []
	for room in _rooms:
		var center := room.get_center()
		if center == dungeon.stairs_up_pos or center == dungeon.stairs_down_pos:
			continue
		candidates.append(room)

	if candidates.is_empty():
		return

	var shuffled := candidates.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: DungeonRoom = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp

	var placed := 0
	for room in shuffled:
		if placed >= 2:
			break

		var special_type: DungeonTile.SpecialType
		if placed == 0 and floor_level >= 5:
			special_type = DungeonTile.SpecialType.SHRINE
		elif placed == 0 and floor_level >= 3:
			special_type = DungeonTile.SpecialType.INSCRIPTION
		elif placed == 1 and floor_level >= 5:
			special_type = DungeonTile.SpecialType.INSCRIPTION
		else:
			continue

		var pos := _find_room_corner(room, dungeon)
		if pos == Vector2i(-1, -1):
			continue

		var tile := dungeon.get_tile(pos.x, pos.y)
		if tile and tile.special == DungeonTile.SpecialType.NONE:
			tile.special = special_type
			placed += 1


func _find_room_corner(room: DungeonRoom, dungeon: DungeonData) -> Vector2i:
	var corners: Array[Vector2i] = [
		Vector2i(room.x, room.y),
		Vector2i(room.x + room.width - 1, room.y),
		Vector2i(room.x, room.y + room.height - 1),
		Vector2i(room.x + room.width - 1, room.y + room.height - 1),
	]
	for i in range(corners.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := corners[i]
		corners[i] = corners[j]
		corners[j] = tmp
	for pos in corners:
		var tile := dungeon.get_tile(pos.x, pos.y)
		if tile and tile.is_walkable() and tile.special == DungeonTile.SpecialType.NONE:
			return pos
	return Vector2i(-1, -1)
