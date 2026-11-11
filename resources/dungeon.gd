class_name Dungeon
extends Resource

## One dungeon of a set: its floors, its slain bosses, and whether it still
## stands. See docs/dungeon-sets.md.

@export var id: String = ""
@export var dungeon_name: String = ""
@export var theme_id: String = ""
@export var master_id: String = ""
## Floors generate from this plus the floor number. 0 means unseeded.
@export var seed_value: int = 0
@export var depth: int = 8
## Floor number to DungeonData, for the floors generated so far.
@export var floors: Dictionary = {}
## Floor numbers whose boss has been slain. Slain bosses stay dead.
@export var bosses_slain: Array[int] = []
## Deepest floor any party has set foot on here.
@export var deepest_floor: int = 0
## Game day the dungeon collapsed, or 0 while it stands.
@export var collapsed_day: int = 0


func is_collapsed() -> bool:
	return collapsed_day > 0


func is_boss_slain(floor_num: int) -> bool:
	return bosses_slain.has(floor_num)
