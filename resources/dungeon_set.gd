class_name DungeonSet
extends Resource

## The dungeons open to the guild at one time. The story is the first set;
## free play brings further sets. See docs/dungeon-sets.md.

## 1 for the story, 2 and up in free play.
@export var set_number: int = 1
@export var dungeons: Array[Dungeon] = []
## Appears once every dungeon in the set has collapsed.
@export var final_dungeon: Dungeon = null


## A set with a single unnamed dungeon, which is how the game plays until
## sets are built out.
static func create_single() -> DungeonSet:
	var dungeon_set := DungeonSet.new()
	var dungeon := Dungeon.new()
	dungeon.id = "dungeon_1"
	dungeon_set.dungeons.append(dungeon)
	return dungeon_set


func get_dungeon(dungeon_id: String) -> Dungeon:
	for d in dungeons:
		if d.id == dungeon_id:
			return d
	if final_dungeon and final_dungeon.id == dungeon_id:
		return final_dungeon
	return null


func collapsed_count() -> int:
	var count := 0
	for d in dungeons:
		if d.is_collapsed():
			count += 1
	return count
