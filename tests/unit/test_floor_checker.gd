extends TestBase

## Floor 1 has no guardian and floor 2 has one.
const PLAIN_FLOOR := 1
const GUARDIAN_FLOOR := 2

## A seed whose first floor has no way to the stairs down, found with
## tests/measure_floors.tscn. If the generator changes, find another there.
const REFUSED_SEED := 1091
const REFUSED_SIZE := 31
const REFUSED_FLOOR := 2


## A floor from rows of text: # solid, . open, < stairs up, > stairs down.
func _floor(rows: Array[String], floor_level: int = PLAIN_FLOOR) -> DungeonData:
	var data := DungeonData.new()
	data.width = rows[0].length()
	data.height = rows.size()
	data.floor_level = floor_level
	for y in range(data.height):
		for x in range(data.width):
			var tile := DungeonTile.new()
			tile.x = x
			tile.y = y
			var glyph := rows[y][x]
			tile.type = DungeonTile.TileType.SOLID if glyph == "#" else DungeonTile.TileType.FLOOR
			if glyph == "<":
				tile.special = DungeonTile.SpecialType.STAIRS_UP
				data.stairs_up_pos = Vector2i(x, y)
			elif glyph == ">":
				tile.special = DungeonTile.SpecialType.STAIRS_DOWN
				data.stairs_down_pos = Vector2i(x, y)
			data.tiles.append(tile)
	return data


func _set_edge(data: DungeonData, pos: Vector2i, dir: String, wall: DungeonTile.WallType) -> void:
	var offset: Vector2i = DungeonData.DIR_OFFSET[dir]
	data.get_tile(pos.x, pos.y).set_wall(dir, wall)
	data.get_tile(pos.x + offset.x, pos.y + offset.y).set_wall(DungeonData.OPPOSITE_DIR[dir], wall)


func _add_lair(data: DungeonData, tiles: Array[Vector2i]) -> void:
	data.add_zone(EncounterZone.create("boss_zone", EncounterZone.ZoneType.BOSS, tiles))


func _same_floor(a: DungeonData, b: DungeonData) -> bool:
	if a.stairs_up_pos != b.stairs_up_pos or a.stairs_down_pos != b.stairs_down_pos:
		return false
	if a.tiles.size() != b.tiles.size() or a.zones.size() != b.zones.size():
		return false
	for i in range(a.tiles.size()):
		var s := a.tiles[i]
		var t := b.tiles[i]
		if s.type != t.type or s.special != t.special or s.encounter_zone_id != t.encounter_zone_id:
			return false
		for dir in FloorChecker.DIRS:
			if s.get_wall_type(dir) != t.get_wall_type(dir) or s.is_door_locked(dir) != t.is_door_locked(dir):
				return false
	return true


# --- The checker ---------------------------------------------------------

func test_a_floor_with_a_way_through_is_sound() -> void:
	var data := _floor([
		"#######",
		"#<...>#",
		"#######",
	])
	assert_empty(FloorChecker.problems(data))
	assert_true(FloorChecker.is_sound(data))


func test_a_floor_without_stairs_up_is_refused() -> void:
	var data := _floor([
		"#######",
		"#....>#",
		"#######",
	])
	assert_eq(FloorChecker.problems(data), [FloorChecker.NO_STAIRS_UP])


func test_a_floor_without_stairs_down_is_refused() -> void:
	var data := _floor([
		"#######",
		"#<....#",
		"#######",
	])
	assert_has(FloorChecker.problems(data), FloorChecker.NO_STAIRS_DOWN)


func test_the_last_floor_needs_no_stairs_down() -> void:
	var data := _floor([
		"#######",
		"#<....#",
		"#######",
	], GameState.FINAL_FLOOR)
	data.stairs_down_pos = Vector2i(5, 1)
	_add_lair(data, [Vector2i(4, 1)])
	assert_empty(FloorChecker.problems(data))


func test_a_wall_across_the_only_way_down_is_refused() -> void:
	var data := _floor([
		"#######",
		"#<...>#",
		"#######",
	])
	_set_edge(data, Vector2i(3, 1), "east", DungeonTile.WallType.SOLID)
	var problems := FloorChecker.problems(data)
	assert_has(problems, FloorChecker.STAIRS_DOWN_CUT_OFF)
	assert_has(problems, FloorChecker.TILES_CUT_OFF)


func test_a_sealed_pocket_is_refused() -> void:
	var data := _floor([
		"#######",
		"#<...>#",
		"###.###",
		"###.###",
		"#######",
	])
	_set_edge(data, Vector2i(3, 1), "south", DungeonTile.WallType.SOLID)
	assert_eq(FloorChecker.problems(data), [FloorChecker.TILES_CUT_OFF])


func test_a_solid_tile_in_the_way_is_refused() -> void:
	var data := _floor([
		"#######",
		"#<.#.>#",
		"#######",
	])
	assert_has(FloorChecker.problems(data), FloorChecker.STAIRS_DOWN_CUT_OFF)


func test_a_locked_door_is_a_way_through() -> void:
	var data := _floor([
		"#######",
		"#<...>#",
		"#######",
	])
	_set_edge(data, Vector2i(3, 1), "east", DungeonTile.WallType.DOOR)
	data.sync_door_locked(3, 1, "east", true)
	assert_empty(FloorChecker.problems(data))


func test_a_wall_on_one_side_only_is_refused() -> void:
	var data := _floor([
		"#######",
		"#<...>#",
		"#######",
	])
	data.get_tile(3, 1).set_wall("east", DungeonTile.WallType.DOOR)
	assert_has(FloorChecker.problems(data), FloorChecker.WALLS_DISAGREE)


func test_a_guardian_floor_needs_a_lair() -> void:
	var data := _floor([
		"#######",
		"#<...>#",
		"#######",
	], GUARDIAN_FLOOR)
	assert_eq(FloorChecker.problems(data), [FloorChecker.NO_LAIR])
	_add_lair(data, [Vector2i(3, 1), Vector2i(4, 1)])
	assert_empty(FloorChecker.problems(data))


func test_a_lair_the_party_cant_reach_is_refused() -> void:
	var data := _floor([
		"#######",
		"#<...>#",
		"###.###",
		"###.###",
		"#######",
	], GUARDIAN_FLOOR)
	_set_edge(data, Vector2i(3, 1), "south", DungeonTile.WallType.SOLID)
	_add_lair(data, [Vector2i(3, 1), Vector2i(3, 2)])
	assert_has(FloorChecker.problems(data), FloorChecker.LAIR_CUT_OFF)


func test_reachable_from_stops_at_walls() -> void:
	var data := _floor([
		"#######",
		"#<...>#",
		"#######",
	])
	_set_edge(data, Vector2i(2, 1), "east", DungeonTile.WallType.SOLID)
	var reached := FloorChecker.reachable_from(data, data.stairs_up_pos)
	assert_eq(reached.size(), 2)
	assert_true(reached.has(Vector2i(2, 1)))
	assert_false(reached.has(Vector2i(3, 1)))


# --- The generator -------------------------------------------------------

func test_the_same_seed_gives_the_same_floor() -> void:
	for case in [[31, 2], [31, 5], [31, 8], [41, 8]]:
		for seed_value in [7, 1234, 987654321]:
			var first := DungeonGenerator.new().generate(case[0], case[0], case[1], seed_value)
			var second := DungeonGenerator.new().generate(case[0], case[0], case[1], seed_value)
			assert_true(_same_floor(first, second), "size %d floor %d seed %d" % [case[0], case[1], seed_value])
			assert_eq(first.seed_value, second.seed_value)


func test_one_generator_can_make_floor_after_floor() -> void:
	var generator := DungeonGenerator.new()
	generator.generate(31, 31, 5, 99)
	var again := generator.generate(31, 31, 2, 7)
	assert_true(_same_floor(again, DungeonGenerator.new().generate(31, 31, 2, 7)))


func test_different_seeds_give_different_floors() -> void:
	var first := DungeonGenerator.new().generate(31, 31, 5, 7)
	var second := DungeonGenerator.new().generate(31, 31, 5, 8)
	assert_false(_same_floor(first, second))


func test_generated_floors_are_sound() -> void:
	for case in [[31, 1], [31, 2], [31, 5], [31, 8], [41, 8]]:
		for s in range(25):
			var data := DungeonGenerator.new().generate(case[0], case[0], case[1], 5000 + s)
			assert_empty(FloorChecker.problems(data), "size %d floor %d seed %d" % [case[0], case[1], 5000 + s])


func test_a_refused_floor_is_replaced() -> void:
	var raw := DungeonGenerator.new().generate_unchecked(REFUSED_SIZE, REFUSED_SIZE, REFUSED_FLOOR, REFUSED_SEED)
	assert_has(FloorChecker.problems(raw), FloorChecker.STAIRS_DOWN_CUT_OFF)

	var kept := DungeonGenerator.new().generate(REFUSED_SIZE, REFUSED_SIZE, REFUSED_FLOOR, REFUSED_SEED)
	assert_empty(FloorChecker.problems(kept))
	assert_ne(kept.seed_value, REFUSED_SEED)
	var again := DungeonGenerator.new().generate(REFUSED_SIZE, REFUSED_SIZE, REFUSED_FLOOR, REFUSED_SEED)
	assert_true(_same_floor(kept, again))
	# The floor that was kept can be made again from the seed it records.
	var remade := DungeonGenerator.new().generate_unchecked(REFUSED_SIZE, REFUSED_SIZE, REFUSED_FLOOR, kept.seed_value)
	assert_true(_same_floor(kept, remade))


func test_a_random_floor_records_a_seed_that_remakes_it() -> void:
	var data := DungeonGenerator.new().generate(31, 31, 5)
	assert_ne(data.seed_value, 0)
	var remade := DungeonGenerator.new().generate_unchecked(31, 31, 5, data.seed_value)
	assert_true(_same_floor(data, remade))
