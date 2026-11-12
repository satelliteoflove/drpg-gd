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

# Campaign progress
@export var bosses_slain: Array[int] = []
@export var victory_day: int = 0
@export var deepest_floor: int = 0
@export var intro_seen: bool = true

@export_group("Guild")
## Version 6 on. Each party is {id, name, member_ids, inventory, torch,
## dungeon_id, floor, position, facing, spawn_at_stairs_up, carried_gold,
## carried_scrap, tracker}. The Party State and Dungeon State groups above
## are what version 5 saved; only the summary fields are still written.
@export var parties: Array[Dictionary] = []
@export var active_party_id: String = ""
@export var dungeon_set: DungeonSet = null
@export var destination_dungeon_id: String = ""
@export var guild_gold: int = 0
@export var guild_scrap: int = 0
@export var guild_storage: Inventory = null
@export var chronicle: Array[Dictionary] = []

@export_group("Meta")
@export var save_version: int = 6
@export var save_timestamp: int = 0
@export var play_time_seconds: int = 0
