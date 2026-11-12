class_name Dungeon
extends Resource

## One dungeon of a set: its floors, its slain bosses, its master, and whether
## it still stands. See docs/dungeon-sets.md.

@export var id: String = ""
@export var dungeon_name: String = ""
## Its look and sound on every floor. See FloorThemes.
@export var theme_id: String = ""
## Floors generate from this plus the floor number. 0 means unseeded.
@export var seed_value: int = 0
## The floor the way in from town leads to, and the deepest floor. The four
## of a set run 1 to 8. The fifth is a single floor that plays as floor 8.
@export var entry_floor: int = 1
@export var depth: int = 8
## Floor whose deep-time rate applies throughout, or 0 to use each floor's own.
@export var deep_rate_floor: int = 0
## True for the dungeon that appears once the four have collapsed.
@export var is_final: bool = false

@export_group("Master")
## The master waits on the deepest floor: a boss in MonsterDatabase, and its
## name for the town to speak of.
@export var master_id: String = ""
@export var master_name: String = ""

@export_group("State")
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


## The floor whose deep-time rate applies on [param floor_num].
func deep_time_floor(floor_num: int) -> int:
	return deep_rate_floor if deep_rate_floor > 0 else floor_num
