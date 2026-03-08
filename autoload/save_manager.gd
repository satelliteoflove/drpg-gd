## Handles saving and loading game state to/from disk.
class_name SaveManagerClass
extends Node

signal save_completed(success: bool)
signal load_completed(success: bool)

const SAVE_DIR: String = "user://saves/"
const SAVE_EXTENSION: String = ".tres"
const AUTOSAVE_SLOT: String = "autosave"

var current_slot: String = ""
var play_start_time: int = 0
var accumulated_play_time: int = 0


func _ready() -> void:
	_ensure_save_directory()
	play_start_time = int(Time.get_unix_time_from_system())


func _ensure_save_directory() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")


func get_save_path(slot: String) -> String:
	return SAVE_DIR + slot + SAVE_EXTENSION


## Checks if a save file exists for the given slot.
## [param slot]: Save slot name.
## [return]: True if the save file exists.
func save_exists(slot: String) -> bool:
	return FileAccess.file_exists(get_save_path(slot))


## Returns a list of all available save slot names.
## [return]: Sorted array of slot names.
func get_save_slots() -> Array[String]:
	var slots: Array[String] = []
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(SAVE_EXTENSION):
				slots.append(file_name.trim_suffix(SAVE_EXTENSION))
			file_name = dir.get_next()
	slots.sort()
	return slots


## Gets metadata about a save file for display in save/load menus.
## [param slot]: Save slot name.
## [return]: Dictionary with timestamp, floor, party_size, highest_level, gold, play_time.
func get_save_info(slot: String) -> Dictionary:
	if not save_exists(slot):
		return {}

	var save_data = ResourceLoader.load(get_save_path(slot))
	if save_data == null:
		return {}

	var party_size: int = save_data.party_member_ids.size()
	var highest_level := 1
	for char_id in save_data.party_member_ids:
		var character: Character = save_data.roster.get_character(char_id)
		if character and character.level > highest_level:
			highest_level = character.level

	return {
		"slot": slot,
		"timestamp": save_data.save_timestamp,
		"floor": save_data.current_floor,
		"party_size": party_size,
		"highest_level": highest_level,
		"gold": save_data.party_gold,
		"play_time": save_data.play_time_seconds
	}


## Saves the current game state to the specified slot.
## [param slot]: Save slot name.
## [return]: True if save succeeded.
func save_game(slot: String) -> bool:
	current_slot = slot
	var save_path: String = get_save_path(slot)

	var save_data = _create_save_data()
	var error: Error = ResourceSaver.save(save_data, save_path)

	var success: bool = error == OK
	if success:
		print("[SaveManager] Game saved to: ", save_path)
		GameState.game_saved.emit()
	else:
		push_error("[SaveManager] Failed to save game to: " + save_path + " Error: " + str(error))

	save_completed.emit(success)
	return success


## Loads game state from the specified slot.
## [param slot]: Save slot name.
## [return]: True if load succeeded.
func load_game(slot: String) -> bool:
	var save_path: String = get_save_path(slot)

	if not save_exists(slot):
		push_error("[SaveManager] Save file not found: " + save_path)
		load_completed.emit(false)
		return false

	var save_data: Resource = ResourceLoader.load(save_path)
	if save_data == null or not save_data is SaveData:
		push_error("[SaveManager] Failed to load save file: " + save_path)
		load_completed.emit(false)
		return false

	if save_data.save_version < 3:
		push_error("[SaveManager] Save version %d is too old (requires v3+)" % save_data.save_version)
		load_completed.emit(false)
		return false

	_apply_save_data(save_data)
	current_slot = slot

	play_start_time = int(Time.get_unix_time_from_system())
	accumulated_play_time = save_data.play_time_seconds

	print("[SaveManager] Game loaded from: ", save_path)
	GameState.game_loaded.emit()
	load_completed.emit(true)
	return true


## Deletes the save file for the specified slot.
## [param slot]: Save slot name.
## [return]: True if deletion succeeded.
func delete_save(slot: String) -> bool:
	if not save_exists(slot):
		return false

	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir:
		var error := dir.remove(slot + SAVE_EXTENSION)
		return error == OK
	return false


## Saves to the autosave slot.
## [return]: True if save succeeded.
func autosave() -> bool:
	return save_game(AUTOSAVE_SLOT)


func _create_save_data() -> Resource:
	var data := SaveData.new()

	data.roster = GameState.roster.duplicate(true)

	data.party_member_ids.clear()
	for member in GameState.party.get_members():
		data.party_member_ids.append(member.id)

	data.party_gold = GameState.party.gold
	data.party_scrap = GameState.party.scrap
	data.party_formations = GameState.party_formations.duplicate(true)
	data.party_inventory = GameState.party.inventory.duplicate(true) if GameState.party.inventory else null

	data.current_floor = GameState.current_floor
	data.dungeon_floors = _duplicate_dungeon_floors()
	data.player_position = GameState.dungeon_player_position
	data.player_facing = GameState.dungeon_player_facing
	data.spawn_at_stairs_up = GameState.dungeon_spawn_at_stairs_up

	data.game_day = GameState.game_day
	data.floor_tracker_state = GameState.floor_tracker.save_state()

	data.relationship_state = RelationshipManager.get_save_state()

	data.save_timestamp = int(Time.get_unix_time_from_system())
	data.play_time_seconds = _get_total_play_time()

	return data


func _duplicate_dungeon_floors() -> Dictionary:
	var result: Dictionary = {}
	for floor_num in GameState.dungeon_floors.keys():
		var dungeon_data = GameState.dungeon_floors[floor_num]
		if dungeon_data:
			result[floor_num] = dungeon_data.duplicate(true)
	return result


func _apply_save_data(data) -> void:
	GameState.roster = data.roster.duplicate(true)

	GameState.party = Party.new()
	for char_id in data.party_member_ids:
		var character: Character = GameState.roster.get_character(char_id)
		if character:
			GameState.party.add_member(character)

	GameState.party.gold = data.party_gold
	GameState.party.scrap = data.party_scrap
	GameState.party_formations = data.party_formations.duplicate(true) if data.party_formations else []
	if data.party_inventory:
		GameState.party.inventory = data.party_inventory.duplicate(true)

	GameState.current_floor = data.current_floor
	GameState.dungeon_floors.clear()
	for floor_num in data.dungeon_floors.keys():
		var dungeon_data = data.dungeon_floors[floor_num]
		if dungeon_data:
			GameState.dungeon_floors[floor_num] = dungeon_data.duplicate(true)

	GameState.dungeon_player_position = data.player_position
	GameState.dungeon_player_facing = data.player_facing
	GameState.dungeon_spawn_at_stairs_up = data.spawn_at_stairs_up

	GameState.game_day = data.game_day if data.game_day else 1
	if not data.floor_tracker_state.is_empty():
		GameState.floor_tracker.load_state(data.floor_tracker_state)

	if data.relationship_state:
		RelationshipManager.load_save_state(data.relationship_state)


func _get_total_play_time() -> int:
	var current_session := int(Time.get_unix_time_from_system()) - play_start_time
	return accumulated_play_time + current_session
