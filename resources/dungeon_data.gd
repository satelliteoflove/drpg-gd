class_name DungeonData
extends Resource

@export var width: int = 31
@export var height: int = 31
@export var floor_level: int = 1
@export var seed_value: int = 0

@export var tiles: Array[DungeonTile] = []
@export var rooms: Array[DungeonRoom] = []
@export var stairs_up_pos: Vector2i = Vector2i.ZERO
@export var stairs_down_pos: Vector2i = Vector2i.ZERO


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
