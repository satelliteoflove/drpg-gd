extends Node

## Generates many floors and reports what the generator actually produces:
## how big and how connected a floor is, where the stairs, the locked door,
## the boss and the narrative tiles land, and how far a party has to walk.
## Run headless:
##   godot --headless --path . tests/measure_floors.tscn
## After "--", any of: "runs 200" for the number of floors per case;
## "json <path>" to also write every floor's numbers to a file; and
## "maps <n>" to print the first n floors of each case as text maps, and the
## first n floors the checker refuses; and "checked" to measure the floors the
## game keeps, with the refused ones already replaced, instead of every floor
## the generator makes.

const DIRS := ["north", "south", "east", "west"]
## The cases worth telling apart: a floor with a guardian, one without, the
## deepest floor, and the fifth dungeon's great floor.
const CASES := [
	{"name": "floor 2 (guardian), 31x31", "size": 31, "floor": 2},
	{"name": "floor 5 (no boss), 31x31", "size": 31, "floor": 5},
	{"name": "floor 8 (master), 31x31", "size": 31, "floor": 8},
	{"name": "great floor, 41x41", "size": 41, "floor": 8},
]

var _data: DungeonData


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var runs := 200
	var json_path := ""
	var maps := 0
	var checked := false
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] == "runs" and i + 1 < args.size():
			runs = int(args[i + 1])
			i += 1
		elif args[i] == "json" and i + 1 < args.size():
			json_path = args[i + 1]
			i += 1
		elif args[i] == "maps" and i + 1 < args.size():
			maps = int(args[i + 1])
			i += 1
		elif args[i] == "checked":
			checked = true
		i += 1

	var everything := {}
	var broken_shown := 0
	for case in CASES:
		var rows: Array = []
		for s in range(runs):
			var seed_value: int = 1000 + s
			# Straight from the generator unless asked otherwise, so the floors
			# the game would throw away are counted too.
			if checked:
				_data = DungeonGenerator.new().generate(case["size"], case["size"], case["floor"], seed_value)
			else:
				_data = DungeonGenerator.new().generate_unchecked(case["size"], case["size"], case["floor"], seed_value)
			var row := _measure()
			row["problems"] = FloorChecker.problems(_data)
			row["refused"] = not row["problems"].is_empty()
			if s < 20:
				row["same_seed_same_floor"] = _same_as(DungeonGenerator.new().generate_unchecked(
					case["size"], case["size"], case["floor"], _data.seed_value))
			rows.append(row)
			if row["refused"] and broken_shown < maps:
				broken_shown += 1
				print("\n--- %s, seed %d: refused (%s) ---" % [case["name"], seed_value, ", ".join(row["problems"])])
				print(_text_map())
			if s < maps:
				print("\n--- %s, seed %d ---" % [case["name"], seed_value])
				print(_text_map())
		everything[case["name"]] = rows
		_report(case["name"], rows)

	if not json_path.is_empty():
		var file := FileAccess.open(json_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(everything))
		file.close()
		print("\nWrote %s" % json_path)
	get_tree().quit()


# --- The floor as a graph ------------------------------------------------

func _can_step(from: Vector2i, dir: String) -> bool:
	var tile := _data.get_tile(from.x, from.y)
	if tile == null or not tile.is_walkable():
		return false
	if tile.get_wall_type(dir) == DungeonTile.WallType.SOLID:
		return false
	var to: Vector2i = from + DungeonData.DIR_OFFSET[dir]
	return _data.is_walkable(to.x, to.y)


func _neighbors(pos: Vector2i, blocked: Dictionary = {}) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in DIRS:
		if _can_step(pos, dir):
			var to: Vector2i = pos + DungeonData.DIR_OFFSET[dir]
			if not blocked.has(to):
				result.append(to)
	return result


## Steps from start to every tile it can reach, without entering `blocked`.
func _distances(start: Vector2i, blocked: Dictionary = {}) -> Dictionary:
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var pos := queue[head]
		head += 1
		for to in _neighbors(pos, blocked):
			if not dist.has(to):
				dist[to] = dist[pos] + 1
				queue.append(to)
	return dist


func _room_at(pos: Vector2i) -> int:
	for r in range(_data.rooms.size()):
		if _data.rooms[r].contains(pos.x, pos.y):
			return r
	return -1


func _room_tiles(room: DungeonRoom) -> Dictionary:
	var tiles := {}
	for y in range(room.y, room.y + room.height):
		for x in range(room.x, room.x + room.width):
			tiles[Vector2i(x, y)] = true
	return tiles


# --- One floor's numbers -------------------------------------------------

func _measure() -> Dictionary:
	var row := {}
	var walkable: Array[Vector2i] = []
	var room_of := {}
	for y in range(_data.height):
		for x in range(_data.width):
			if _data.is_walkable(x, y):
				var pos := Vector2i(x, y)
				walkable.append(pos)
				room_of[pos] = _room_at(pos)

	var room_tiles := 0
	var dead_ends := 0
	var junctions := 0
	var doors := 0
	var locked := 0
	var openings: Array[int] = []
	openings.resize(_data.rooms.size())
	openings.fill(0)
	var doorless: Array[int] = []
	doorless.resize(_data.rooms.size())
	doorless.fill(0)
	for pos in walkable:
		var tile := _data.get_tile(pos.x, pos.y)
		var degree := 0
		for dir in DIRS:
			if not _can_step(pos, dir):
				continue
			degree += 1
			var to: Vector2i = pos + DungeonData.DIR_OFFSET[dir]
			var is_door := tile.get_wall_type(dir) == DungeonTile.WallType.DOOR
			if is_door:
				doors += 1
				if tile.is_door_locked(dir):
					locked += 1
			if room_of[pos] >= 0 and room_of[to] != room_of[pos]:
				openings[room_of[pos]] += 1
				if not is_door:
					doorless[room_of[pos]] += 1
		if room_of[pos] >= 0:
			room_tiles += 1
		else:
			if degree <= 1:
				dead_ends += 1
			if degree >= 3:
				junctions += 1
	doors /= 2
	locked /= 2

	var up := _data.stairs_up_pos
	var down := _data.stairs_down_pos
	var from_up := _distances(up)
	var from_down := _distances(down)

	row["rooms"] = _data.rooms.size()
	row["walkable"] = walkable.size()
	row["walkable_share"] = float(walkable.size()) / float(_data.width * _data.height)
	row["room_tiles"] = room_tiles
	row["corridor_tiles"] = walkable.size() - room_tiles
	row["corridor_dead_ends"] = dead_ends
	row["corridor_junctions"] = junctions
	row["doors"] = doors
	row["locked_doors"] = locked
	# Loops in the layout, counting a room as one place: the number of
	# openings or corridor links that could be walled up without cutting
	# anything off.
	var places := {}
	var links := 0
	for pos in from_up:
		places[room_of[pos] if room_of[pos] >= 0 else pos] = true
		for to in _neighbors(pos):
			if room_of[pos] < 0 or room_of[to] != room_of[pos]:
				links += 1
	row["loops"] = links / 2 - places.size() + 1
	row["unreachable_tiles"] = walkable.size() - from_up.size()

	var sizes := {}
	for room in _data.rooms:
		var key := "%dx%d" % [mini(room.width, room.height), maxi(room.width, room.height)]
		sizes[key] = sizes.get(key, 0) + 1
	row["room_sizes"] = sizes

	var leaf_rooms := 0
	var sealed_rooms := 0
	var opening_total := 0
	var doorless_total := 0
	var opening_max := 0
	for r in range(_data.rooms.size()):
		opening_total += openings[r]
		doorless_total += doorless[r]
		opening_max = maxi(opening_max, openings[r])
		if openings[r] == 1:
			leaf_rooms += 1
		if openings[r] == 0:
			sealed_rooms += 1
	row["leaf_rooms"] = leaf_rooms
	row["rooms_with_no_way_in"] = sealed_rooms
	row["openings_per_room"] = float(opening_total) / maxf(1.0, float(_data.rooms.size()))
	row["openings_max"] = opening_max
	row["doorless_openings"] = doorless_total

	# The stairs.
	row["path_up_to_down"] = from_up.get(down, -1)
	row["straight_up_to_down"] = Vector2(up).distance_to(Vector2(down))
	var edge_gap := mini(mini(up.x, up.y), mini(_data.width - 1 - up.x, _data.height - 1 - up.y))
	row["up_stairs_from_edge"] = edge_gap
	row["farthest_tile_from_up"] = from_up.values().max()

	# Which rooms does every route from the way in to the way down go through?
	var up_room := _room_at(up)
	var down_room := _room_at(down)
	var must_pass := 0
	for r in range(_data.rooms.size()):
		if r == up_room or r == down_room:
			continue
		if not _distances(up, _room_tiles(_data.rooms[r])).has(down):
			must_pass += 1
	row["must_pass_rooms"] = must_pass

	# Rooms a shortest route touches, and how much of the floor that route sees.
	var on_route := {}
	var route_rooms := {}
	if from_up.has(down):
		for pos in from_up:
			if from_down.has(pos) and from_up[pos] + from_down[pos] == from_up[down]:
				on_route[pos] = true
				if room_of[pos] >= 0:
					route_rooms[room_of[pos]] = true
	row["rooms_on_a_shortest_route"] = route_rooms.size()

	# The boss.
	var boss_zone := _data.get_zone_by_id("boss_zone")
	row["has_boss_zone"] = boss_zone != null
	if boss_zone != null:
		var outside := _distances(up, _room_tiles(_data.rooms[down_room]) if down_room >= 0 else {})
		var in_stairs_room := 0
		var reachable_outside := 0
		var cut_off := 0
		var far: Array[int] = []
		for pos in boss_zone.tile_positions:
			if down_room >= 0 and _data.rooms[down_room].contains(pos.x, pos.y):
				in_stairs_room += 1
			elif outside.has(pos):
				reachable_outside += 1
			else:
				cut_off += 1
			far.append(from_down.get(pos, -1))
		row["boss_tiles"] = boss_zone.tile_positions.size()
		row["boss_tiles_in_stairs_room"] = in_stairs_room
		row["boss_tiles_outside"] = reachable_outside
		row["boss_tiles_cut_off"] = cut_off
		row["boss_walk_to_stairs_max"] = far.max()
		row["boss_walk_to_stairs_min"] = far.min()
		var where := "mixed"
		if in_stairs_room == boss_zone.tile_positions.size():
			where = "behind the locked door"
		elif in_stairs_room == 0:
			where = "outside the locked door"
		row["boss_where"] = where
		# Outside the stairs room, can a party walk round the boss?
		var on_only_route := 0
		for pos in boss_zone.tile_positions:
			if not _distances(up, {pos: true}).has(down):
				on_only_route += 1
		row["boss_tiles_that_block_the_way"] = on_only_route

	if down_room >= 0:
		var room := _data.rooms[down_room]
		row["stairs_room_size"] = "%dx%d" % [mini(room.width, room.height), maxi(room.width, room.height)]
		row["stairs_room_openings"] = openings[down_room]

	# Zones and the monsters a fresh floor starts with.
	var zone_counts := {}
	var groups := 0.0
	for zone in _data.zones:
		var name: String = EncounterZone.ZoneType.keys()[zone.zone_type]
		zone_counts[name] = zone_counts.get(name, 0) + 1
		match zone.zone_type:
			EncounterZone.ZoneType.NORMAL, EncounterZone.ZoneType.LOW_SPAWN:
				groups += 1.5
			EncounterZone.ZoneType.HIGH_SPAWN:
				groups += 2.5
			EncounterZone.ZoneType.BOSS:
				groups += 1.0
	row["zones"] = zone_counts
	row["starting_groups"] = groups
	row["tiles_per_group"] = float(walkable.size()) / maxf(1.0, groups)

	# Shrines and inscriptions.
	var special := 0
	var special_off_route: Array[int] = []
	for pos in walkable:
		var tile := _data.get_tile(pos.x, pos.y)
		if tile.special == DungeonTile.SpecialType.SHRINE or tile.special == DungeonTile.SpecialType.INSCRIPTION:
			special += 1
			var nearest := 9999
			var there := _distances(pos)
			for route_pos in on_route:
				nearest = mini(nearest, there.get(route_pos, 9999))
			special_off_route.append(nearest)
	row["narrative_tiles"] = special
	row["narrative_steps_off_route"] = special_off_route

	row["steps_to_walk_everything"] = _walk_everything(up, from_up.size())
	return row


## Steps for a party that always heads for the nearest tile it hasn't stood
## on, until it has stood on all of them. More than a player needs, since a
## room can be seen from its door, but it scales with the floor.
func _walk_everything(start: Vector2i, total: int) -> int:
	var seen := {start: true}
	var pos := start
	var steps := 0
	while seen.size() < total:
		var dist := {pos: 0}
		var queue: Array[Vector2i] = [pos]
		var head := 0
		var found := false
		while head < queue.size() and not found:
			var at := queue[head]
			head += 1
			for to in _neighbors(at):
				if dist.has(to):
					continue
				dist[to] = dist[at] + 1
				if not seen.has(to):
					seen[to] = true
					steps += dist[to]
					pos = to
					found = true
					break
				queue.append(to)
		if not found:
			break
	return steps


func _same_as(other: DungeonData) -> bool:
	if _data.stairs_up_pos != other.stairs_up_pos or _data.stairs_down_pos != other.stairs_down_pos \
			or _data.zones.size() != other.zones.size():
		return false
	for i in range(_data.tiles.size()):
		var a := _data.tiles[i]
		var b := other.tiles[i]
		if a.type != b.type or a.special != b.special or a.encounter_zone_id != b.encounter_zone_id:
			return false
		for dir in DIRS:
			if a.get_wall_type(dir) != b.get_wall_type(dir) or a.is_door_locked(dir) != b.is_door_locked(dir):
				return false
	return true


# --- A floor as text -----------------------------------------------------

## Two characters a tile across, so a thin wall or a door between two tiles
## can be drawn. # solid, . corridor, a space for a room's floor, + door,
## L locked door, | - a wall between two open tiles, < up, > down, B boss
## zone, s shrine, i inscription.
func _text_map() -> String:
	var lines: PackedStringArray = []
	var boss_zone := _data.get_zone_by_id("boss_zone")
	for y in range(_data.height):
		var line := ""
		var below := ""
		for x in range(_data.width):
			var tile := _data.get_tile(x, y)
			var pos := Vector2i(x, y)
			var glyph := "#"
			if tile.is_walkable():
				glyph = " " if _room_at(pos) >= 0 else "."
				if boss_zone != null and boss_zone.contains_position(pos):
					glyph = "B"
				match tile.special:
					DungeonTile.SpecialType.STAIRS_UP: glyph = "<"
					DungeonTile.SpecialType.STAIRS_DOWN: glyph = ">"
					DungeonTile.SpecialType.SHRINE: glyph = "s"
					DungeonTile.SpecialType.INSCRIPTION: glyph = "i"
				if pos == _data.stairs_down_pos and glyph != ">":
					glyph = "X"
			line += glyph + _edge_glyph(tile, "east", "|")
			below += _edge_glyph(tile, "south", "-") + ("#" if not tile.is_walkable() else " ")
		lines.append(line)
		lines.append(below)
	return "\n".join(lines)


func _edge_glyph(tile: DungeonTile, dir: String, wall: String) -> String:
	if not tile.is_walkable():
		return "#"
	var offset: Vector2i = DungeonData.DIR_OFFSET[dir]
	if not _data.is_walkable(tile.x + offset.x, tile.y + offset.y):
		return "#"
	match tile.get_wall_type(dir):
		DungeonTile.WallType.DOOR:
			return "L" if tile.is_door_locked(dir) else "+"
		DungeonTile.WallType.SOLID:
			return wall
	return " " if _room_at(Vector2i(tile.x, tile.y)) >= 0 and _room_at(Vector2i(tile.x, tile.y) + offset) >= 0 else "."


# --- The report ----------------------------------------------------------

func _report(case_name: String, rows: Array) -> void:
	print("\n=== %s, %d floors ===" % [case_name, rows.size()])
	for key in ["rooms", "walkable", "walkable_share", "room_tiles", "corridor_tiles",
			"corridor_dead_ends", "corridor_junctions", "doors", "doorless_openings",
			"openings_per_room", "openings_max", "leaf_rooms", "rooms_with_no_way_in",
			"loops", "unreachable_tiles", "locked_doors", "stairs_room_openings",
			"path_up_to_down", "straight_up_to_down", "farthest_tile_from_up",
			"up_stairs_from_edge", "must_pass_rooms", "rooms_on_a_shortest_route",
			"starting_groups", "tiles_per_group", "narrative_tiles",
			"steps_to_walk_everything", "boss_tiles", "boss_tiles_cut_off",
			"boss_walk_to_stairs_min", "boss_walk_to_stairs_max",
			"boss_tiles_that_block_the_way"]:
		var values: Array[float] = []
		for row in rows:
			if row.has(key):
				values.append(float(row[key]))
		if values.is_empty():
			continue
		values.sort()
		var total := 0.0
		for v in values:
			total += v
		print("  %-30s mean %8.2f   min %7.2f   median %7.2f   max %7.2f" % [
			key, total / values.size(), values[0], values[values.size() / 2], values[-1]])

	var refused := 0
	var reasons := {}
	for row in rows:
		if row["refused"]:
			refused += 1
		for reason in row["problems"]:
			reasons[reason] = reasons.get(reason, 0) + 1
	print("  %-30s %d of %d   %s" % ["refused by the checker", refused, rows.size(), reasons])

	for key in ["boss_where", "stairs_room_size", "same_seed_same_floor"]:
		var counts := {}
		for row in rows:
			if row.has(key):
				counts[str(row[key])] = counts.get(str(row[key]), 0) + 1
		if not counts.is_empty():
			print("  %-30s %s" % [key, counts])

	var sizes := {}
	var zones := {}
	var off_route: Array[int] = []
	for row in rows:
		for k in row["room_sizes"]:
			sizes[k] = sizes.get(k, 0) + row["room_sizes"][k]
		for k in row["zones"]:
			zones[k] = zones.get(k, 0) + row["zones"][k]
		off_route.append_array(row["narrative_steps_off_route"])
	print("  %-30s %s" % ["room_sizes (all floors)", sizes])
	print("  %-30s %s" % ["zones (all floors)", zones])
	if not off_route.is_empty():
		off_route.sort()
		print("  %-30s min %d   median %d   max %d" % ["narrative_steps_off_route",
			off_route[0], off_route[off_route.size() / 2], off_route[-1]])
