class_name DungeonSet
extends Resource

## The dungeons open to the guild at one time: four, all open at once, and a
## fifth that appears when they've all collapsed. The story is the first set;
## free play brings further sets. See docs/dungeon-sets.md.

const SIZE := 4
## Names, themes and masters for a set's four dungeons. "master" is a boss in
## MonsterDatabase and "master_name" is what that boss is called.
const DUNGEONS: Array[Dictionary] = [
	{"name": "The Drake's Deep", "theme": "stone_catacombs", "master": "boss_drake", "master_name": "Vrakthorne the Drake"},
	{"name": "The Ashen Halls", "theme": "ashen_halls", "master": "boss_ash_wyrm", "master_name": "Morvane the Ash Wyrm"},
	{"name": "The Drowned Vaults", "theme": "drowned_vaults", "master": "boss_pale_wyrm", "master_name": "Ulthessa the Pale Wyrm"},
	{"name": "The Verdant Dark", "theme": "mossy_caverns", "master": "boss_mire_wyrm", "master_name": "Khaldrun the Mire Wyrm"},
]
const FINAL := {"name": "The Heart Below", "theme": "profane_crypt", "master": "boss_hollow_king", "master_name": "The Hollow King"}

## 1 for the story, 2 and up in free play.
@export var set_number: int = 1
@export var dungeons: Array[Dungeon] = []
## Appears once every dungeon in the set has collapsed.
@export var final_dungeon: Dungeon = null


static func create(p_set_number: int = 1) -> DungeonSet:
	var dungeon_set := DungeonSet.new()
	dungeon_set.set_number = p_set_number
	for i in SIZE:
		var spec: Dictionary = DUNGEONS[i]
		var dungeon := Dungeon.new()
		dungeon.id = "set%d_dungeon%d" % [p_set_number, i + 1]
		dungeon.dungeon_name = spec["name"]
		dungeon.theme_id = spec["theme"]
		dungeon.master_id = spec["master"]
		dungeon.master_name = spec["master_name"]
		dungeon.seed_value = randi()
		dungeon_set.dungeons.append(dungeon)
	return dungeon_set


## The fifth dungeon: one floor, which plays as the deepest, with the set's
## last master at its heart. Time runs gentler there than on the deep floors.
func open_final() -> Dungeon:
	var dungeon := Dungeon.new()
	dungeon.id = "set%d_final" % set_number
	dungeon.dungeon_name = FINAL["name"]
	dungeon.theme_id = FINAL["theme"]
	dungeon.master_id = FINAL["master"]
	dungeon.master_name = FINAL["master_name"]
	dungeon.entry_floor = dungeons[0].depth if not dungeons.is_empty() else 8
	dungeon.depth = dungeon.entry_floor
	dungeon.deep_rate_floor = 5
	dungeon.is_final = true
	dungeon.seed_value = randi()
	final_dungeon = dungeon
	return dungeon


## Brings a set saved by an older version up to date: a theme for any dungeon
## saved before dungeons had them, and its own master for any saved when every
## master was the drake.
func update_from_older_save() -> void:
	for i in dungeons.size():
		_update_dungeon(dungeons[i], DUNGEONS[i % DUNGEONS.size()])
	if final_dungeon:
		_update_dungeon(final_dungeon, FINAL)


func _update_dungeon(dungeon: Dungeon, spec: Dictionary) -> void:
	if dungeon.theme_id.is_empty():
		dungeon.theme_id = spec["theme"]
	if dungeon.master_name == spec["master_name"]:
		dungeon.master_id = spec["master"]


func get_dungeon(dungeon_id: String) -> Dungeon:
	for d in dungeons:
		if d.id == dungeon_id:
			return d
	if final_dungeon and final_dungeon.id == dungeon_id:
		return final_dungeon
	return null


## The dungeons a party can enter right now.
func open_dungeons() -> Array[Dungeon]:
	var result: Array[Dungeon] = []
	for d in dungeons:
		if not d.is_collapsed():
			result.append(d)
	if final_dungeon and not final_dungeon.is_collapsed():
		result.append(final_dungeon)
	return result


func collapsed_count() -> int:
	var count := 0
	for d in dungeons:
		if d.is_collapsed():
			count += 1
	return count


func all_collapsed() -> bool:
	return collapsed_count() >= dungeons.size()
