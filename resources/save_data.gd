class_name SaveData
extends Resource

@export_group("Characters")
@export var roster: CharacterRoster = null

@export_group("Party State")
@export var party_member_ids: Array[String] = []
@export var party_formations: Array[PartyFormation] = []
@export var party_gold: int = 0
@export var party_scrap: int = 0
@export var party_inventory: Inventory = null

@export_group("Dungeon State")
@export var current_floor: int = 1
@export var dungeon_floors: Dictionary = {}
@export var player_position: Vector2i = Vector2i.ZERO
@export var player_facing: int = 0
@export var spawn_at_stairs_up: bool = true

@export_group("World State")
@export var game_day: int = 1
@export var floor_tracker_state: Dictionary = {}

@export_group("Relationships")
@export var relationship_state: Dictionary = {}

@export_group("Events")
@export var event_state: Dictionary = {}

@export_group("Meta")
@export var save_version: int = 5
@export var save_timestamp: int = 0
@export var play_time_seconds: int = 0
