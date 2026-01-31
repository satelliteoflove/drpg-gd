class_name GameStateClass
extends Node

const PartyRes = preload("res://resources/party.gd")
const RosterRes = preload("res://resources/character_roster.gd")

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
var encounter_chance: float = 0.0
var dungeon_player_position: Vector2i = Vector2i.ZERO
var dungeon_player_facing: int = 0
var returning_from_combat: bool = false
var combat_speed: int = 5


func clear_dungeon_floors() -> void:
	dungeon_floors.clear()


func get_dungeon_floor(floor_num: int):
	return dungeon_floors.get(floor_num, null)


func store_dungeon_floor(floor_num: int, dungeon_data) -> void:
	dungeon_floors[floor_num] = dungeon_data


func _ready() -> void:
	_initialize_game_data()


func _initialize_game_data() -> void:
	if party == null:
		party = PartyRes.new()
	if roster == null:
		roster = RosterRes.new()


func new_game() -> void:
	party = PartyRes.new()
	party.add_gold(100)
	roster = RosterRes.new()
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


func start_combat(encounter_data: Dictionary) -> void:
	current_encounter = encounter_data
	in_combat = true
	combat_started.emit(encounter_data)


func clear_encounter() -> void:
	current_encounter = {}


func end_combat(victory: bool) -> void:
	in_combat = false
	combat_ended.emit(victory)
