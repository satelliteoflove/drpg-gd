class_name DungeonTile
extends Resource

enum TileType { SOLID, FLOOR }
enum WallType { NONE, SOLID, DOOR, SECRET, ILLUSORY }
enum SpecialType { NONE, STAIRS_UP, STAIRS_DOWN, TREASURE, TRAP, SHRINE, INSCRIPTION }

@export var x: int = 0
@export var y: int = 0
@export var type: TileType = TileType.SOLID
@export var discovered: bool = false
@export var region: int = -1

@export_group("Walls")
@export var north_wall: WallType = WallType.NONE
@export var south_wall: WallType = WallType.NONE
@export var east_wall: WallType = WallType.NONE
@export var west_wall: WallType = WallType.NONE

@export_group("Wall Properties")
@export var north_door_locked: bool = false
@export var south_door_locked: bool = false
@export var east_door_locked: bool = false
@export var west_door_locked: bool = false

@export_group("Door State")
@export var north_door_open: bool = false
@export var south_door_open: bool = false
@export var east_door_open: bool = false
@export var west_door_open: bool = false

@export_group("Special")
@export var special: SpecialType = SpecialType.NONE
@export var encounter_zone_id: String = ""


func is_walkable() -> bool:
	return type == TileType.FLOOR


func has_wall(direction: String) -> bool:
	match direction:
		"north":
			return north_wall != WallType.NONE
		"south":
			return south_wall != WallType.NONE
		"east":
			return east_wall != WallType.NONE
		"west":
			return west_wall != WallType.NONE
	return false


func get_wall_type(direction: String) -> WallType:
	match direction:
		"north":
			return north_wall
		"south":
			return south_wall
		"east":
			return east_wall
		"west":
			return west_wall
	return WallType.NONE


func set_wall(direction: String, wall_type: WallType) -> void:
	match direction:
		"north":
			north_wall = wall_type
		"south":
			south_wall = wall_type
		"east":
			east_wall = wall_type
		"west":
			west_wall = wall_type


func is_door_open(direction: String) -> bool:
	match direction:
		"north": return north_door_open
		"south": return south_door_open
		"east": return east_door_open
		"west": return west_door_open
	return false


func set_door_open(direction: String, open: bool) -> void:
	match direction:
		"north": north_door_open = open
		"south": south_door_open = open
		"east": east_door_open = open
		"west": west_door_open = open


func is_door_locked(direction: String) -> bool:
	match direction:
		"north": return north_door_locked
		"south": return south_door_locked
		"east": return east_door_locked
		"west": return west_door_locked
	return false


func set_door_locked(direction: String, locked: bool) -> void:
	match direction:
		"north": north_door_locked = locked
		"south": south_door_locked = locked
		"east": east_door_locked = locked
		"west": west_door_locked = locked
