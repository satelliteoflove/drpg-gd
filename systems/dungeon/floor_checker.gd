class_name FloorChecker
extends RefCounted

## Says whether a generated floor can be played: the party can reach the way
## down and every other tile, and the floor's guardian has a lair it can be
## found in. A locked door counts as a way through, since a key or a thief
## opens it.

const NO_STAIRS_UP := "no stairs up"
const NO_STAIRS_DOWN := "no stairs down"
const STAIRS_DOWN_CUT_OFF := "no way to the stairs down"
const TILES_CUT_OFF := "tiles that can't be reached"
const NO_LAIR := "no lair for the guardian"
const LAIR_CUT_OFF := "the guardian's lair can't be reached"
const WALLS_DISAGREE := "a wall that differs from one side to the other"

const DIRS: Array[String] = ["north", "south", "east", "west"]


## The reasons to refuse the floor. Empty when it's sound.
static func problems(data: DungeonData) -> Array[String]:
	var found: Array[String] = []

	var up := data.stairs_up_pos
	var up_tile := data.get_tile(up.x, up.y)
	if up_tile == null or not up_tile.is_walkable() \
			or up_tile.special != DungeonTile.SpecialType.STAIRS_UP:
		# Nothing else can be judged without a place to start from.
		found.append(NO_STAIRS_UP)
		return found

	var reached := reachable_from(data, up)

	# The last floor has no stairs down, but stairs_down_pos still marks its
	# deepest chamber, which the party has to be able to get to.
	var down := data.stairs_down_pos
	var down_tile := data.get_tile(down.x, down.y)
	var is_last := data.floor_level >= GameState.FINAL_FLOOR
	if down == up or down_tile == null or not down_tile.is_walkable() \
			or (not is_last and down_tile.special != DungeonTile.SpecialType.STAIRS_DOWN):
		found.append(NO_STAIRS_DOWN)
	elif not reached.has(down):
		found.append(STAIRS_DOWN_CUT_OFF)

	var walkable := 0
	var walls_agree := true
	for tile in data.tiles:
		if not tile.is_walkable():
			continue
		walkable += 1
		for dir: String in ["east", "south"]:
			var offset: Vector2i = DungeonData.DIR_OFFSET[dir]
			var other := data.get_tile(tile.x + offset.x, tile.y + offset.y)
			if other == null or not other.is_walkable():
				continue
			var back: String = DungeonData.OPPOSITE_DIR[dir]
			if tile.get_wall_type(dir) != other.get_wall_type(back) \
					or tile.is_door_locked(dir) != other.is_door_locked(back):
				walls_agree = false
	if walkable > reached.size():
		found.append(TILES_CUT_OFF)
	if not walls_agree:
		found.append(WALLS_DISAGREE)

	# The stairs stay sealed until the guardian falls, so a floor whose
	# guardian has nowhere to be, or can't be got to, can never be finished.
	if MonsterDatabase.get_boss_for_floor(data.floor_level) != null:
		var lair: EncounterZone = null
		for zone in data.zones:
			if zone.zone_type == EncounterZone.ZoneType.BOSS:
				lair = zone
				break
		if lair == null or lair.tile_positions.is_empty():
			found.append(NO_LAIR)
		else:
			for pos in lair.tile_positions:
				if not reached.has(pos):
					found.append(LAIR_CUT_OFF)
					break

	return found


static func is_sound(data: DungeonData) -> bool:
	return problems(data).is_empty()


## Every tile a party starting at `start` can walk to, as a set.
static func reachable_from(data: DungeonData, start: Vector2i) -> Dictionary:
	var reached := {}
	if not data.is_walkable(start.x, start.y):
		return reached
	reached[start] = true
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var pos := queue[head]
		head += 1
		var tile := data.get_tile(pos.x, pos.y)
		for dir in DIRS:
			if tile.get_wall_type(dir) == DungeonTile.WallType.SOLID:
				continue
			var to: Vector2i = pos + DungeonData.DIR_OFFSET[dir]
			if reached.has(to) or not data.is_walkable(to.x, to.y):
				continue
			reached[to] = true
			queue.append(to)
	return reached
