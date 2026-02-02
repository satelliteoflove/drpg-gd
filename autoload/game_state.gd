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

var party: Party = null
var roster: CharacterRoster = null
var dungeon_floors: Dictionary = {}
var dungeon_spawn_at_stairs_up: bool = true
var current_encounter: Dictionary = {}
var encounter_chance: float = 0.15
var dungeon_player_position: Vector2i = Vector2i.ZERO
var dungeon_player_facing: int = 0
var returning_from_combat: bool = false
var combat_speed: int = 5
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


## Initializes a fresh game state with empty party and starting gold.
func new_game() -> void:
	party = Party.new()
	party.add_gold(100)
	roster = CharacterRoster.new()
	floor_tracker = FloorTracker.new()
	dungeon_floors.clear()
	current_floor = 1
	current_encounter = {}


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
	combat_ended.emit(victory)
