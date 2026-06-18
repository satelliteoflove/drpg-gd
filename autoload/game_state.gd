## Global game state autoload managing party, dungeon, and combat state.
class_name GameStateClass
extends Node

signal floor_changed(new_floor: int)
signal combat_started(encounter_data: Dictionary)
signal combat_ended(victory: bool)
signal party_member_died(character: Resource)
signal game_saved()
signal game_loaded()

enum GameMode { MAIN_MENU, TOWN, DUNGEON, COMBAT }

var current_mode: GameMode = GameMode.MAIN_MENU
var current_floor: int = 1
var in_combat: bool = false
var show_combat_math: bool = true
var debug_verbose: bool = false

var party: Party = null
var roster: CharacterRoster = null
var party_formations: Array[PartyFormation] = []
var dungeon_floors: Dictionary = {}
var dungeon_spawn_at_stairs_up: bool = true
var current_encounter: Dictionary = {}
var encounter_chance: float = 0.15
var dungeon_player_position: Vector2i = Vector2i.ZERO
var dungeon_player_facing: int = 0
var returning_from_combat: bool = false
var combat_speed: int = 5
var game_day: int = 1
var floor_tracker: FloorTracker = null


func clear_dungeon_floors() -> void:
	dungeon_floors.clear()


## Retrieves cached dungeon data for a floor.
## [param floor_num]: Floor number to retrieve.
## [return]: DungeonData or null if not cached.
func get_dungeon_floor(floor_num: int) -> DungeonData:
	return dungeon_floors.get(floor_num, null)


## Caches dungeon data for a floor.
## [param floor_num]: Floor number to store.
## [param dungeon_data]: The dungeon layout data.
func store_dungeon_floor(floor_num: int, dungeon_data: DungeonData) -> void:
	dungeon_floors[floor_num] = dungeon_data


func _ready() -> void:
	_initialize_game_data()


func _initialize_game_data() -> void:
	if party == null:
		party = Party.new()
	if roster == null:
		roster = CharacterRoster.new()
	if floor_tracker == null:
		floor_tracker = FloorTracker.new()
	if party_formations.is_empty():
		party_formations = []


const STARTER_ROSTER: Array[Dictionary] = [
	{"name": "Roland", "race": CharacterEnums.Race.HUMAN, "class": CharacterEnums.CharacterClass.FIGHTER, "alignment": CharacterEnums.Alignment.GOOD, "gender": CharacterEnums.Gender.MALE},
	{"name": "Thorin", "race": CharacterEnums.Race.DWARF, "class": CharacterEnums.CharacterClass.FIGHTER, "alignment": CharacterEnums.Alignment.GOOD, "gender": CharacterEnums.Gender.MALE},
	{"name": "Marcus", "race": CharacterEnums.Race.HUMAN, "class": CharacterEnums.CharacterClass.PRIEST, "alignment": CharacterEnums.Alignment.GOOD, "gender": CharacterEnums.Gender.MALE},
	{"name": "Elara", "race": CharacterEnums.Race.ELF, "class": CharacterEnums.CharacterClass.MAGE, "alignment": CharacterEnums.Alignment.NEUTRAL, "gender": CharacterEnums.Gender.FEMALE},
	{"name": "Celeste", "race": CharacterEnums.Race.HUMAN, "class": CharacterEnums.CharacterClass.BISHOP, "alignment": CharacterEnums.Alignment.GOOD, "gender": CharacterEnums.Gender.FEMALE},
	{"name": "Pip", "race": CharacterEnums.Race.HOBBIT, "class": CharacterEnums.CharacterClass.THIEF, "alignment": CharacterEnums.Alignment.NEUTRAL, "gender": CharacterEnums.Gender.MALE},
]

const STARTER_GEAR: Dictionary = {
	CharacterEnums.CharacterClass.FIGHTER: ["long_sword", "leather_armor", "wooden_shield"],
	CharacterEnums.CharacterClass.PRIEST: ["mace", "leather_armor", "wooden_shield"],
	CharacterEnums.CharacterClass.MAGE: ["staff", "cloth_armor"],
	CharacterEnums.CharacterClass.BISHOP: ["mace", "cloth_armor"],
	CharacterEnums.CharacterClass.THIEF: ["short_bow", "leather_armor"],
}

const STARTER_LEVEL: int = 1


func new_game() -> void:
	party = Party.new()
	party.add_gold(100)
	var starter_torch := ShopItems.get_item("torch")
	if starter_torch:
		party.inventory.add_item(starter_torch.duplicate() as Item, 8)
	roster = CharacterRoster.new()
	party_formations = []
	floor_tracker = FloorTracker.new()
	RelationshipManager.clear()
	EventManager.clear()
	dungeon_floors.clear()
	current_floor = 1
	current_encounter = {}
	game_day = 1
	_populate_starter_roster()
	_create_starter_formation()


func _create_starter_formation() -> void:
	var formation := PartyFormation.new()
	formation.formation_name = "The Default"
	for character in roster.get_all():
		formation.member_ids.append(character.id)
		formation.member_names.append(character.character_name)
	party_formations.append(formation)


func _populate_starter_roster() -> void:
	for template in STARTER_ROSTER:
		var char_class: CharacterEnums.CharacterClass = template["class"]
		var race: CharacterEnums.Race = template["race"]
		var stats := _roll_valid_stats(race, char_class)

		var character := Character.create_new(
			template["name"], race, char_class,
			template["alignment"], template["gender"], stats
		)

		if STARTER_LEVEL > 1:
			var required_xp := ExperienceTable.get_required_xp(STARTER_LEVEL, race, char_class)
			character.add_experience(required_xp)
			while character.pending_level_up:
				character.confirm_level_up()

		var learnable := SpellLearning.get_learnable_spells(character)
		for spell in learnable:
			if not character.known_spells.has(spell.id):
				character.known_spells.append(spell.id)

		var gear_ids: Array = STARTER_GEAR.get(char_class, [])
		for item_id: String in gear_ids:
			var item := ShopItems.get_item(item_id)
			if item:
				var item_copy := item.duplicate()
				if character.can_equip_item(item_copy):
					character.equip_item(item_copy)

		character.current_hp = character.max_hp
		character.current_mp = character.max_mp
		PersonalitySystem.seed_auto_personality(character)
		roster.add_character(character)


func _roll_valid_stats(race: CharacterEnums.Race, char_class: CharacterEnums.CharacterClass) -> Dictionary:
	var stats := Character.roll_stats_for_race(race)
	for i in range(100):
		if ClassData.meets_requirements(char_class, stats):
			return stats
		stats = Character.roll_stats_for_race(race)
	var reqs := ClassData.get_requirements(char_class)
	for stat_name: String in reqs:
		if stats.get(stat_name, 0) < reqs[stat_name]:
			stats[stat_name] = reqs[stat_name]
	return stats


func has_party() -> bool:
	return party != null and not party.is_empty()


func get_party_members() -> Array[Character]:
	if party == null:
		return []
	return party.get_members()


func set_mode(mode: GameMode) -> void:
	current_mode = mode


func set_floor(floor_num: int) -> void:
	current_floor = floor_num
	floor_changed.emit(floor_num)


## Initiates combat with the given encounter configuration.
## [param encounter_data]: Dictionary with "enemies" array and optional flags.
func start_combat(encounter_data: Dictionary) -> void:
	current_encounter = encounter_data
	in_combat = true
	combat_started.emit(encounter_data)


func clear_encounter() -> void:
	current_encounter = {}


## Ends the current combat encounter.
## [param victory]: True if the party won.
func end_combat(victory: bool) -> void:
	in_combat = false
	if party:
		for member in party.get_members():
			if not member.is_dead:
				_clear_combat_only_statuses(member)
	combat_ended.emit(victory)


func _clear_combat_only_statuses(character: Resource) -> void:
	for status in CharacterEnums.BENEFICIAL_STATUSES:
		if character.has_status(status):
			character.remove_status(status)
	character.is_defending = false


func advance_game_days(days: int) -> void:
	for _d in range(days):
		game_day += 1
		RelationshipManager.advance_day()
		for character in roster.get_all():
			character.advance_age(1)
			character.tick_availability(game_day)
			if character.is_available() and not party.has_member(character) and not character.is_dead:
				character.town_days_accumulated += 1
				if character.town_job >= 0:
					var job := TownJobs.get_job(character.town_job)
					character.add_experience(job.get("xp_per_day", 0))
					party.add_gold(job.get("gold_per_day", 0))
