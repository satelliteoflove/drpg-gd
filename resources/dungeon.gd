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
## Floor number to the boss that seals the way down from it. A floor not
## listed has MonsterDatabase's stock boss for that floor, if any.
@export var guardians: Dictionary = {}
## A boss's given name in MonsterDatabase to the one it goes by here. Empty
## in the first set. Later sets have new bosses of the same kinds.
@export var boss_renames: Dictionary = {}

@export_group("State")
## Floor number to DungeonData, for the floors generated so far.
@export var floors: Dictionary = {}
## Floor numbers whose boss has been slain. Slain bosses stay dead.
@export var bosses_slain: Array[int] = []
## Deepest floor any party has set foot on here.
@export var deepest_floor: int = 0
## Game day the dungeon collapsed, or 0 while it stands.
@export var collapsed_day: int = 0


## [param text] with this dungeon's names for its bosses.
func renamed(text: String) -> String:
	for old_name in boss_renames:
		text = text.replace(old_name, boss_renames[old_name])
	return text


## Gives [param boss] the name it goes by in this dungeon, in its own name
## and in what its fight says of it.
func name_boss(boss: Monster) -> void:
	var new_name := renamed(boss.monster_name)
	if new_name == boss.monster_name:
		return
	# Its art is still filed under the name it has in MonsterDatabase.
	if boss.art_name.is_empty():
		boss.art_name = boss.monster_name
	boss.monster_name = new_name
	for phase in boss.boss_phases:
		for key in ["warning_message", "transition_message"]:
			if phase.has(key):
				phase[key] = renamed(phase[key])


func is_collapsed() -> bool:
	return collapsed_day > 0


func is_boss_slain(floor_num: int) -> bool:
	return bosses_slain.has(floor_num)


## The floor whose deep-time rate applies on [param floor_num].
func deep_time_floor(floor_num: int) -> int:
	return deep_rate_floor if deep_rate_floor > 0 else floor_num
