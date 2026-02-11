class_name DungeonData
extends Resource

const OPPOSITE_DIR := {"north": "south", "south": "north", "east": "west", "west": "east"}
const DIR_OFFSET := {"north": Vector2i(0, -1), "south": Vector2i(0, 1), "east": Vector2i(1, 0), "west": Vector2i(-1, 0)}

@export var width: int = 31
@export var height: int = 31
@export var floor_level: int = 1
@export var seed_value: int = 0

@export var tiles: Array[DungeonTile] = []
@export var rooms: Array[DungeonRoom] = []
@export var stairs_up_pos: Vector2i = Vector2i.ZERO
@export var stairs_down_pos: Vector2i = Vector2i.ZERO
@export var zones: Array[EncounterZone] = []
@export var enemy_groups: Array[EnemyGroup] = []


func get_tile(x: int, y: int) -> DungeonTile:
	if x < 0 or x >= width or y < 0 or y >= height:
		return null
	var index: int = y * width + x
	if index >= tiles.size():
		return null
	return tiles[index]


func set_tile(x: int, y: int, tile: DungeonTile) -> void:
	if x < 0 or x >= width or y < 0 or y >= height:
		return
	var index: int = y * width + x
	if index < tiles.size():
		tiles[index] = tile


func is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func is_walkable(x: int, y: int) -> bool:
	var tile: DungeonTile = get_tile(x, y)
	return tile != null and tile.is_walkable()


func get_zone_at(x: int, y: int) -> EncounterZone:
	var pos := Vector2i(x, y)
	for zone in zones:
		if zone.contains_position(pos):
			return zone
	return null


func get_zone_by_id(zone_id: String) -> EncounterZone:
	for zone in zones:
		if zone.id == zone_id:
			return zone
	return null


func sync_door_open(x: int, y: int, direction: String, open: bool) -> void:
	var tile := get_tile(x, y)
	if tile != null:
		tile.set_door_open(direction, open)
	var offset: Vector2i = DIR_OFFSET.get(direction, Vector2i.ZERO)
	var neighbor := get_tile(x + offset.x, y + offset.y)
	if neighbor != null:
		neighbor.set_door_open(OPPOSITE_DIR[direction], open)


func sync_door_locked(x: int, y: int, direction: String, locked: bool) -> void:
	var tile := get_tile(x, y)
	if tile != null:
		tile.set_door_locked(direction, locked)
	var offset: Vector2i = DIR_OFFSET.get(direction, Vector2i.ZERO)
	var neighbor := get_tile(x + offset.x, y + offset.y)
	if neighbor != null:
		neighbor.set_door_locked(OPPOSITE_DIR[direction], locked)


func add_zone(zone: EncounterZone) -> void:
	zones.append(zone)
	for pos in zone.tile_positions:
		var tile := get_tile(pos.x, pos.y)
		if tile != null:
			tile.encounter_zone_id = zone.id
