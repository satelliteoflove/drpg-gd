## Global game state autoload managing party, dungeon, and combat state.
class_name GameStateClass
extends Node

signal floor_changed(new_floor: int)
signal combat_started(encounter_data: Dictionary)
signal combat_ended(victory: bool)
signal party_member_died(character: Resource)
signal game_saved()
signal game_loaded()
## A party member crossed into a new life phase while below.
signal life_phase_changed(character: Character, phase: CharacterEnums.LifePhase)

enum GameMode { MAIN_MENU, TOWN, DUNGEON, COMBAT }

## The deepest floor. Its boss is the final foe; slaying it wins the game.
const FINAL_FLOOR: int = 8

var current_mode: GameMode = GameMode.MAIN_MENU
var in_combat: bool = false
var show_combat_math: bool = true
var debug_verbose: bool = false

## Every party the guild has, in town or out. One of them is active: the one
## the player is driving. See docs/dungeon-sets.md.
var parties: Array[Party] = []
var _active_party: Party = null
## The active party. Assigning a new party replaces the active one.
var party: Party:
	get: return _active_party
	set(value):
		var index := parties.find(_active_party) if _active_party else -1
		if value != null and value.id.is_empty():
			value.id = _new_party_id()
		if index >= 0 and value != null:
			parties[index] = value
		elif index >= 0:
			parties.remove_at(index)
		elif value != null:
			parties.append(value)
		_active_party = value
## The guild's gold and scrap, shared by everyone in town.
var guild_gold: int = 0
var guild_scrap: int = 0
## Views onto the active party, kept so older code reads as before.
var current_floor: int:
	get: return _active_party.floor_num if _active_party else 1
	set(value): _active_party.floor_num = value
var dungeon_spawn_at_stairs_up: bool:
	get: return _active_party.spawn_at_stairs_up if _active_party else true
	set(value): _active_party.spawn_at_stairs_up = value
var dungeon_player_position: Vector2i:
	get: return _active_party.position if _active_party else Vector2i.ZERO
	set(value): _active_party.position = value
var dungeon_player_facing: int:
	get: return _active_party.facing if _active_party else 0
	set(value): _active_party.facing = value
var floor_tracker: FloorTracker:
	get: return _active_party.tracker if _active_party else null
	set(value): _active_party.tracker = value
var roster: CharacterRoster = null
var party_formations: Array[PartyFormation] = []
## The dungeons open to the guild.
var dungeon_set: DungeonSet = null
## The dungeon a party in town will enter next.
var destination_dungeon_id: String = ""
## Items any party in town can leave or take. See docs/dungeon-sets.md.
var guild_storage: Inventory = null
const GUILD_STORAGE_SLOTS := 200
## The guild's history, oldest first: [{day, kind, text}]. Kinds are
## "collapse", "story", "legend", "retired", "death", "wipe", "rescue".
var chronicle: Array[Dictionary] = []
## What the last collapse was, for the town to show once: {dungeon, master,
## collapsed, total, final_opened, story_end, new_set, lost}. Not saved.
var pending_collapse: Dictionary = {}
## Views onto the active dungeon, kept so older code reads as before.
var dungeon_floors: Dictionary:
	get: return active_dungeon().floors
	set(value): active_dungeon().floors = value
var current_encounter: Dictionary = {}
var returning_from_combat: bool = false
var combat_speed: int = 5
var game_day: int = 1
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
		dungeon_set = DungeonSet.create()
	if _active_party and _active_party.is_out():
		var here := dungeon_set.get_dungeon(_active_party.dungeon_id)
		if here:
			return here
	var chosen := dungeon_set.get_dungeon(destination_dungeon_id)
	if chosen and not chosen.is_collapsed():
		return chosen
	var open := dungeon_set.open_dungeons()
	return open[0] if not open.is_empty() else dungeon_set.dungeons[0]


## Which boss waits on [param floor_num] of the active dungeon, or "". On the
## deepest floor that's the dungeon's master, and above it the dungeon's own
## guardian for that floor.
func floor_boss_id(floor_num: int) -> String:
	var dungeon := active_dungeon()
	if floor_num >= dungeon.depth and not dungeon.master_id.is_empty():
		return dungeon.master_id
	return dungeon.guardians.get(floor_num, MonsterDatabase.get_boss_id_for_floor(floor_num))


func get_floor_boss(floor_num: int) -> Monster:
	var boss := MonsterDatabase.get_monster(floor_boss_id(floor_num))
	if boss:
		active_dungeon().name_boss(boss)
	return boss


func get_floor_boss_minions(floor_num: int) -> Array[String]:
	return MonsterDatabase.get_minions_of(floor_boss_id(floor_num))


## How much stronger than stock the monsters on [param floor_num] are.
func surge_multiplier(floor_num: int) -> float:
	return DungeonSurge.multiplier(dungeon_set, floor_num)


func record(kind: String, text: String) -> void:
	chronicle.append({"day": game_day, "kind": kind, "text": text})


func _new_guild_storage() -> Inventory:
	var storage := Inventory.new()
	storage.max_slots = GUILD_STORAGE_SLOTS
	return storage


func _new_party_id() -> String:
	var n := parties.size() + 1
	while get_party("party_%d" % n) != null:
		n += 1
	return "party_%d" % n


func get_party(party_id: String) -> Party:
	for p in parties:
		if p.id == party_id:
			return p
	return null


## The party [param character] belongs to, or null if they're on the bench.
func party_of(character: Character) -> Party:
	for p in parties:
		if p.has_member(character):
			return p
	return null


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
	if party_formations.is_empty():
		party_formations = []
	if guild_storage == null:
		guild_storage = _new_guild_storage()


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
	parties.clear()
	_active_party = null
	guild_gold = 0
	guild_scrap = 0
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
	RelationshipManager.clear()
	EventManager.clear()
	dungeon_set = DungeonSet.create()
	destination_dungeon_id = ""
	pending_collapse = {}
	pending_wipe = {}
	pending_camp = {}
	guild_storage = _new_guild_storage()
	chronicle = []
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


enum BossOutcome { GUARDIAN, COLLAPSE, STORY_END }

## Records a boss kill in the active dungeon. Killing its master collapses
## the dungeon, and the fifth dungeon's master ends the story.
func record_boss_slain(floor_num: int) -> BossOutcome:
	var dungeon := active_dungeon()
	if not dungeon.bosses_slain.has(floor_num):
		dungeon.bosses_slain.append(floor_num)
	if floor_num < dungeon.depth or dungeon.is_collapsed():
		return BossOutcome.GUARDIAN
	return _collapse(dungeon)


## Brings [param dungeon] down. Every living party inside is cast out to
## town with whatever it carries. A party lying dead in it is lost for good.
func _collapse(dungeon: Dungeon) -> BossOutcome:
	dungeon.collapsed_day = game_day
	dungeon.floors.clear()
	var lost: Array[String] = []
	for p in parties.duplicate():
		if p == _active_party or p.dungeon_id != dungeon.id:
			continue
		if p.is_wiped():
			for member in p.get_members():
				member.add_status(CharacterEnums.StatusEffect.LOST, -1, "", 0)
				lost.append(member.character_name)
			parties.erase(p)
		else:
			p.dungeon_id = ""
			p.bank_carried()

	var who: Array[String] = []
	for member in party.get_members():
		if not member.is_dead:
			who.append(member.character_name)
	var report := {
		"dungeon": dungeon.dungeon_name, "master": dungeon.master_name,
		"total": dungeon_set.dungeons.size(), "lost": lost, "who": who,
		"final_opened": false, "story_end": false, "new_set": false,
	}
	record("collapse", "%s slew %s, and %s collapsed." % [
		name_list(who), dungeon.master_name, dungeon.dungeon_name])
	if not lost.is_empty():
		record("death", "%s still lay in %s when it fell, and were lost." % [name_list(lost), dungeon.dungeon_name])
	var outcome := BossOutcome.COLLAPSE
	if dungeon.is_final:
		report["new_set"] = true
		if victory_day == 0:
			victory_day = game_day
			report["story_end"] = true
			record("story", "With %s gone, the ground beneath the town lay still." % dungeon.dungeon_name)
			outcome = BossOutcome.STORY_END
		dungeon_set = DungeonSet.create(dungeon_set.set_number + 1)
		record("story", "Four new dungeons opened beneath the town.")
	elif dungeon_set.all_collapsed() and dungeon_set.final_dungeon == null:
		dungeon_set.open_final()
		report["final_opened"] = true
		record("story", "The last of the four fell, and %s opened beneath them." % dungeon_set.final_dungeon.dungeon_name)
	report["collapsed"] = dungeon_set.collapsed_count()
	destination_dungeon_id = ""
	pending_collapse = report
	return outcome


func name_list(names: Array) -> String:
	if names.is_empty():
		return "No one"
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, -1)) + " and " + names[-1]


const _COUNT_WORDS := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]

## [param n] as a word for prose ("four"), or digits past twelve.
func count_word(n: int) -> String:
	return _COUNT_WORDS[n] if n >= 0 and n < _COUNT_WORDS.size() else str(n)


## Whether any party lies dead in [param dungeon], to warn before its master.
func bodies_below(dungeon: Dungeon) -> Array[String]:
	var names: Array[String] = []
	for p in parties:
		if p != _active_party and p.dungeon_id == dungeon.id and p.is_wiped():
			for member in p.get_members():
				names.append(member.character_name)
	return names


func has_won() -> bool:
	return victory_day > 0


## Floors that have a boss, in descending order.
func get_boss_floors() -> Array[int]:
	var floors: Array[int] = []
	for f in range(1, FINAL_FLOOR + 1):
		if MonsterDatabase.get_boss_for_floor(f) != null:
			floors.append(f)
	return floors


# --- Several parties ---------------------------------------------------------------

## Set when the dungeon should put the active party back where it stood
## (resuming a camped party, or a save made below) instead of at the stairs.
var resume_at_position: bool = false
## A wipe for the town to report once: {names, dungeon, floor}. Not saved.
var pending_wipe: Dictionary = {}
## A party that just made camp below, for the town to mention once.
var pending_camp: Dictionary = {}


## Makes [param p], which the guild already has, the party the player drives.
func set_active_party(p: Party) -> void:
	if parties.has(p):
		_active_party = p
		_prune_empty_parties()


## Leaves the active party where it stands below, camped or dead, and puts
## the player in town with another party. The party left behind is frozen:
## it doesn't move, fight or age until someone returns to it or fetches it.
func leave_party_below() -> void:
	tick_expedition()
	var town_party: Party = null
	for p in parties:
		if p != _active_party and not p.is_out() and (town_party == null or town_party.is_empty()):
			town_party = p
	if town_party == null:
		town_party = Party.new()
		town_party.id = _new_party_id()
		parties.append(town_party)
	_active_party = town_party
	_prune_empty_parties()


func _prune_empty_parties() -> void:
	for p in parties.duplicate():
		if p != _active_party and p.is_empty() and not p.is_out():
			parties.erase(p)


## Parties other than the active one that the player could switch to.
func other_parties() -> Array[Party]:
	var result: Array[Party] = []
	for p in parties:
		if p != _active_party and not p.is_empty():
			result.append(p)
	return result


## "Roland's party", or the party's own name if it has one.
func party_label(p: Party) -> String:
	if not p.party_name.is_empty():
		return p.party_name
	if p.is_empty():
		return "An empty party"
	return "%s's party" % p.get_members()[0].character_name


## Where a party is, in words.
func party_whereabouts(p: Party) -> String:
	if not p.is_out():
		return "in town"
	var dungeon := dungeon_set.get_dungeon(p.dungeon_id)
	var place := dungeon.dungeon_name if dungeon else "a dungeon"
	if dungeon and not dungeon.is_final:
		place += ", floor %d" % p.floor_num
	return ("lying dead in %s" if p.is_wiped() else "camped in %s") % place


## Dead parties lying on [param floor_num] of the active party's dungeon.
func fallen_parties_on(floor_num: int) -> Array[Party]:
	var result: Array[Party] = []
	if _active_party == null or not _active_party.is_out():
		return result
	for p in parties:
		if p != _active_party and p.is_wiped() and p.dungeon_id == _active_party.dungeon_id \
				and p.floor_num == floor_num:
			result.append(p)
	return result


## The active party gathers up a fallen one: as many bodies as it has room
## for, then their gold and whatever of their gear fits. Returns {recovered:
## [names], left: count, gold: amount}. A party with no bodies left is gone.
func recover_fallen(fallen: Party) -> Dictionary:
	var recovered: Array[String] = []
	for member in fallen.get_members().duplicate():
		if party.is_full():
			break
		fallen.remove_member(member.id)
		party.add_member(member)
		recovered.append(member.character_name)
	var gold := fallen.carried_gold
	party.add_gold(gold)
	fallen.carried_gold = 0
	if fallen.inventory and party.inventory:
		var slots := fallen.inventory.slots
		for i in range(slots.size() - 1, -1, -1):
			var item: Item = slots[i].get("item")
			if item == null:
				continue
			var remaining := party.inventory.add_item(item, slots[i].get("quantity", 1))
			if remaining <= 0:
				slots.remove_at(i)
			else:
				slots[i]["quantity"] = remaining
	var left := fallen.size()
	if left == 0:
		parties.erase(fallen)
	if not recovered.is_empty():
		record("rescue", "%s found %s where they fell in %s." % [
			party_label(party), name_list(recovered), active_dungeon().dungeon_name])
	return {"recovered": recovered, "left": left, "gold": gold}


## Whether [param character] is below with a party the player isn't driving.
func is_away(character: Character) -> bool:
	var their_party := party_of(character)
	return their_party != null and their_party != _active_party and their_party.is_out()


## Starts an expedition: the active party leaves town for a dungeon.
func begin_expedition() -> void:
	var dungeon := active_dungeon()
	# A party always goes in at the top.
	party.floor_num = dungeon.entry_floor
	party.spawn_at_stairs_up = true
	party.prepare_for_dungeon()
	var t := party.tracker
	t.deep_days = 0.0
	t.trip_surface_days = 0
	t.trip_deep_days = 0
	t.trip_start = {}
	for member in party.get_members():
		member.note_first_descent(game_day)
		if not member.is_dead:
			t.trip_start[member.id] = [member.age_days, member.get_life_phase()]
	party.dungeon_id = dungeon.id


## Moves time along as the active party walks below. Deep time lands on the
## party as it accrues, so they age, and change phase, in the dungeon itself.
## Every day's worth of steps moves the surface calendar for everyone else.
func tick_expedition() -> void:
	var t := party.tracker
	var deep := t.consume_deep_days()
	if deep > 0:
		t.trip_deep_days += deep
		for member in party.get_members():
			if member.is_dead:
				continue
			var phase_before := member.get_life_phase()
			member.advance_age(deep)
			member.days_below += deep
			var phase_after := member.get_life_phase()
			if phase_after != phase_before:
				_add_phase_mark(member, phase_after)
				life_phase_changed.emit(member, phase_after)
	while t.accumulated_steps >= FloorTracker.STEPS_PER_DAY:
		t.accumulated_steps -= FloorTracker.STEPS_PER_DAY
		t.trip_surface_days += 1
		advance_game_days(1)


## Ends the active party's expedition as it reaches town. The aging has
## already happened below; this banks what the party carried, gives elders
## their old-age roll, lets Legends pass on, and returns the report for the
## town to show.
func settle_expedition() -> Dictionary:
	if not party.is_out():
		return {}
	tick_expedition()
	var t := party.tracker
	party.dungeon_id = ""
	var banked := party.bank_carried()

	var rows: Array[Dictionary] = []
	for member in party.get_members():
		if not t.trip_start.has(member.id):
			continue
		var start: Array = t.trip_start[member.id]
		var phase_after := member.get_life_phase()
		var died := false
		if phase_after == CharacterEnums.LifePhase.FRAGILE and not member.last_descent and not member.is_dead:
			died = member.check_old_age_death()
			if died:
				member.end_service("old_age", game_day)
				record("death", "%s died of old age at %d, at the top of the stairs." % [
					member.character_name, member.get_age_years()])
		rows.append({
			"character": member,
			"age_before": int(start[0]),
			"age_after": member.age_days,
			"phase_before": int(start[1]),
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

	# The dead come home too, the party's own and any it found below.
	var dead: Array[String] = []
	for member in party.get_members():
		if member.is_dead and not member.has_left_service():
			dead.append(member.character_name)
	var report := {
		"surface_days": t.trip_surface_days, "deep_days": t.trip_deep_days,
		"members": rows, "legends": legends, "gold_banked": banked, "dead": dead,
		"party": party_label(party),
	}
	t.deep_days = 0.0
	t.trip_surface_days = 0
	t.trip_deep_days = 0
	t.trip_start = {}
	return report


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
			# Parties below keep their own time: the active one ages by deep
			# time as it walks, and the rest are frozen until the player
			# returns to them.
			var their_party := party_of(character)
			if their_party and their_party.is_out():
				continue
			character.advance_age(1)
			character.tick_availability(game_day)
			if character.is_available() and their_party == null and not character.is_dead:
				character.town_days_accumulated += 1
				if character.town_job >= 0:
					var job := TownJobs.get_job(character.town_job)
					character.add_experience(job.get("xp_per_day", 0))
					guild_gold += job.get("gold_per_day", 0)
