class_name DungeonRoom
extends Resource

enum RoomSize { SMALL, MEDIUM, LARGE }

@export var id: String = ""
@export var x: int = 0
@export var y: int = 0
@export var width: int = 3
@export var height: int = 3
@export var size_type: RoomSize = RoomSize.SMALL


func get_center() -> Vector2i:
	return Vector2i(x + width / 2, y + height / 2)


func contains(px: int, py: int) -> bool:
	return px >= x and px < x + width and py >= y and py < y + height


func overlaps(other: DungeonRoom, buffer: int = 1) -> bool:
	return not (
		x + width + buffer <= other.x or
		other.x + other.width + buffer <= x or
		y + height + buffer <= other.y or
		other.y + other.height + buffer <= y
	)
