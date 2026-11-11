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

## The deepest floor. Its boss is the final foe; slaying it wins the game.
const FINAL_FLOOR: int = 8

var current_mode: GameMode = GameMode.MAIN_MENU
var current_floor: int = 1
var in_combat: bool = false
var show_combat_math: bool = true
var debug_verbose: bool = false

var party: Party = null
var roster: CharacterRoster = null
var party_formations: Array[PartyFormation] = []
## The dungeons open to the guild. Until sets are built out there is one.
var dungeon_set: DungeonSet = null
## Views onto the active dungeon, kept so older code reads as before.
var dungeon_floors: Dictionary:
	get: return active_dungeon().floors
	set(value): active_dungeon().floors = value
var dungeon_spawn_at_stairs_up: bool = true
var current_encounter: Dictionary = {}
var dungeon_player_position: Vector2i = Vector2i.ZERO
var dungeon_player_facing: int = 0
var returning_from_combat: bool = false
var combat_speed: int = 5
var game_day: int = 1
var floor_tracker: FloorTracker = null
var bosses_slain: Array[int]:
	get: return active_dungeon().bosses_slain
	set(value): active_dungeon().bosses_slain.assign(value)
## Game day the final boss fell, or 0 if the game hasn't been won yet.
var victory_day: int = 0
var deepest_floor: int:
	get: return active_dungeon().deepest_floor
	set(value): active_dungeon().deepest_floor = value
## Whether the opening premise has been shown for this campaign.
var intro_seen: bool = true
## What the last trip below did to the party, for the town to show once.
## Empty when there's nothing to report. Not saved.
var pending_homecoming: Dictionary = {}


## The dungeon the active party is in, or would enter from town.
func active_dungeon() -> Dungeon:
	if dungeon_set == null:
		dungeon_set = DungeonSet.create_single()
	return dungeon_set.dungeons[0]


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
	var starter_recall := ShopItems.get_item("recall_stone")
	if starter_recall:
		party.inventory.add_item(starter_recall.duplicate() as Item, 2)
	roster = CharacterRoster.new()
	party_formations = []
	floor_tracker = FloorTracker.new()
	RelationshipManager.clear()
	EventManager.clear()
	dungeon_set = DungeonSet.create_single()
	current_floor = 1
	current_encounter = {}
	game_day = 1
	victory_day = 0
	intro_seen = false
	pending_homecoming = {}
	_populate_starter_roster()
	_create_starter_formation()
	# The starters begin as the active party so a new player's first choice
	# can be the dungeon, not a roster screen.
	for character in roster.get_all():
		if not party.is_full():
			party.add_member(character)


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
	deepest_floor = maxi(deepest_floor, floor_num)
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


func is_boss_slain(floor_num: int) -> bool:
	return active_dungeon().is_boss_slain(floor_num)


## Records a boss kill. Returns true if this kill wins the game.
func record_boss_slain(floor_num: int) -> bool:
	if not bosses_slain.has(floor_num):
		bosses_slain.append(floor_num)
	if floor_num == FINAL_FLOOR and victory_day == 0:
		victory_day = game_day
		return true
	return false


func has_won() -> bool:
	return victory_day > 0


## Floors that have a boss, in descending order.
func get_boss_floors() -> Array[int]:
	var floors: Array[int] = []
	for f in range(1, FINAL_FLOOR + 1):
		if MonsterDatabase.get_boss_for_floor(f) != null:
			floors.append(f)
	return floors


## Settles the time an expedition took. The surface calendar moves by
## [param surface_days] for everyone; the party, who were below where time
## runs fast, age by [param deep_days] in total. Elders face the old-age roll
## here, once per homecoming, rather than at the inn.
func process_homecoming(surface_days: int, deep_days: int) -> Dictionary:
	var before := {}
	for member in party.get_members():
		if not member.is_dead:
			before[member.id] = {"age": member.age_days, "phase": member.get_life_phase()}

	if surface_days > 0:
		advance_game_days(surface_days)

	var rows: Array[Dictionary] = []
	for member in party.get_members():
		if not before.has(member.id):
			continue
		var extra := maxi(0, deep_days - surface_days)
		if extra > 0:
			member.advance_age(extra)
		member.days_below += maxi(deep_days, surface_days)
		var phase_before: CharacterEnums.LifePhase = before[member.id]["phase"]
		var phase_after := member.get_life_phase()
		if phase_after != phase_before:
			_add_phase_mark(member, phase_after)
		var died := false
		if phase_after == CharacterEnums.LifePhase.FRAGILE and not member.last_descent:
			died = member.check_old_age_death()
			if died:
				member.end_service("old_age", game_day)
		rows.append({
			"character": member,
			"age_before": before[member.id]["age"],
			"age_after": member.age_days,
			"phase_before": phase_before,
			"phase_after": phase_after,
			"died_of_age": died,
			"legend": member.last_descent,
		})

	# Anyone sworn to a last descent passes on now, whether they fell below
	# or made it back up.
	var legends: Array[Dictionary] = []
	for member in party.get_members().duplicate():
		if member.last_descent:
			legends.append({"character": member, "lines": LastDescent.pass_on(member, party)})
	return {"surface_days": surface_days, "deep_days": deep_days, "members": rows, "legends": legends}


const PHASE_MARKS: Dictionary = {
	CharacterEnums.LifePhase.PRIME: "Came into their own",
	CharacterEnums.LifePhase.DECLINE: "Graying at the temples",
	CharacterEnums.LifePhase.FRAGILE: "An elder of the guild",
}


func _add_phase_mark(member: Character, phase: CharacterEnums.LifePhase) -> void:
	var mark_name: String = PHASE_MARKS.get(phase, "")
	if mark_name == "":
		return
	var severity := Marks.Severity.MINOR if phase == CharacterEnums.LifePhase.PRIME else Marks.Severity.MAJOR
	var tags: Array[String] = ["aging"]
	var involved: Array[String] = []
	member.add_mark(Marks.create_mark(mark_name, "deep_time", tags, Marks.Agency.SUBJECT,
		severity, involved, game_day))


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
