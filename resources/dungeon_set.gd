class_name DungeonSet
extends Resource

## The dungeons open to the guild at one time: four, all open at once, and a
## fifth that appears when they've all collapsed. The story is the first set;
## free play brings further sets. See docs/dungeon-sets.md.

const SIZE := 4
## Names, themes, guardians and masters for a set's four dungeons. "master"
## is a boss in MonsterDatabase and "master_name" is what that boss is
## called. "guardians" are the bosses that seal the way down, by floor.
const DUNGEONS: Array[Dictionary] = [
	{
		"name": "The Drake's Deep", "theme": "stone_catacombs",
		"master": "boss_drake", "master_name": "Vrakthorne the Drake",
		"guardians": {2: "boss_broodmother", 4: "boss_ironjaw", 6: "boss_lich"},
	},
	{
		"name": "The Ashen Halls", "theme": "ashen_halls",
		"master": "boss_ash_wyrm", "master_name": "Morvane the Ash Wyrm",
		"guardians": {2: "boss_cinder_hound", 4: "boss_forgemaster", 6: "boss_pyre_priest"},
	},
	{
		"name": "The Drowned Vaults", "theme": "drowned_vaults",
		"master": "boss_pale_wyrm", "master_name": "Ulthessa the Pale Wyrm",
		"guardians": {2: "boss_brine_mother", 4: "boss_drowned_captain", 6: "boss_tide_witch"},
	},
	{
		"name": "The Verdant Dark", "theme": "mossy_caverns",
		"master": "boss_mire_wyrm", "master_name": "Khaldrun the Mire Wyrm",
		"guardians": {2: "boss_rot_bloom", 4: "boss_bog_troll", 6: "boss_mire_hag"},
	},
]
## What a later set calls its four dungeons, in turn: the second set takes
## the first name in each row, the third the next, and round again.
const LATER_NAMES: Array = [
	["The Wyrm's Rest", "The Cold Barrow", "The Sunless Keep"],
	["The Cinder Pits", "The Smoking Reach", "The Charred Stair"],
	["The Sunken Cloister", "The Weeping Cistern", "The Black Tarn"],
	["The Rotwood Hollow", "The Mossgrave", "The Thorn Cellars"],
]
## A later set's bosses are new ones of the same kinds. Each row is a boss's
## given name in the first set, then the names its like goes by in later ones.
const LATER_BOSS_NAMES: Array = [
	{
		"Vrakthorne": ["Skarnoth", "Orrundel", "Thazzimar"],
		"Ironjaw": ["Redtusk", "Gravelmaw", "Halfear"],
		"Nethris": ["Malveth", "Ossira", "Dreloch"],
	},
	{
		"Morvane": ["Cindrath", "Ashkelor", "Velmyra"],
		"Brakka": ["Hulda", "Gruma", "Torvek"],
		"Serrak": ["Calder", "Maruk", "Tessek"],
	},
	{
		"Ulthessa": ["Nimraeth", "Isvalde", "Corrowyn"],
		"Morrow": ["Vance", "Garrow", "Stroud"],
		"Ysolde": ["Merewen", "Saltha", "Undra"],
	},
	{
		"Khaldrun": ["Gholmur", "Sythrak", "Urdmoss"],
		"Grum": ["Mudge", "Sog", "Brack"],
		"Nettle": ["Hemlock", "Bramble", "Yarrow"],
	},
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
		dungeon.guardians = spec["guardians"].duplicate()
		dungeon.seed_value = randi()
		if p_set_number > 1:
			_name_for_later_set(dungeon, i, p_set_number)
		dungeon_set.dungeons.append(dungeon)
	return dungeon_set


## Free play doesn't send the guild back down the Drake's Deep after
## Vrakthorne a second time: a later set's dungeons and bosses have names of
## their own. The Heart Below and its King are the same every time.
static func _name_for_later_set(dungeon: Dungeon, index: int, p_set_number: int) -> void:
	var turn := p_set_number - 2
	var names: Array = LATER_NAMES[index]
	dungeon.dungeon_name = names[turn % names.size()]
	for old_name in LATER_BOSS_NAMES[index]:
		var new_names: Array = LATER_BOSS_NAMES[index][old_name]
		dungeon.boss_renames[old_name] = new_names[turn % new_names.size()]
	dungeon.master_name = dungeon.renamed(dungeon.master_name)


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
## saved before dungeons had them, its own master for any saved when every
## master was the drake, and its own guardians for any saved before those.
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
	if dungeon.guardians.is_empty() and spec.has("guardians"):
		dungeon.guardians = spec["guardians"].duplicate()


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
