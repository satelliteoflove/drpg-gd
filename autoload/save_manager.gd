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
		print_debug("[SaveManager] Game saved to: ", save_path)
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

	print_debug("[SaveManager] Game loaded from: ", save_path)
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

	for p in GameState.parties:
		var member_ids: Array[String] = []
		for member in p.get_members():
			member_ids.append(member.id)
		data.parties.append({
			"id": p.id,
			"name": p.party_name,
			"member_ids": member_ids,
			"inventory": p.inventory.duplicate(true) if p.inventory else null,
			"torch": p.torch_steps_remaining,
			"dungeon_id": p.dungeon_id,
			"floor": p.floor_num,
			"position": p.position,
			"facing": p.facing,
			"spawn_at_stairs_up": p.spawn_at_stairs_up,
			"carried_gold": p.carried_gold,
			"carried_scrap": p.carried_scrap,
			"tracker": p.tracker.save_state(),
		})
	data.active_party_id = GameState.party.id
	data.guild_gold = GameState.guild_gold
	data.guild_scrap = GameState.guild_scrap
	data.guild_storage = GameState.guild_storage.duplicate(true)
	data.chronicle = GameState.chronicle.duplicate(true)
	data.party_formations = GameState.party_formations.duplicate(true)
	data.dungeon_set = _copy_dungeon_set(GameState.dungeon_set)
	data.destination_dungeon_id = GameState.destination_dungeon_id

	# Summary fields the load screen reads.
	for member in GameState.party.get_members():
		data.party_member_ids.append(member.id)
	data.party_gold = GameState.guild_gold + GameState.party.carried_gold
	data.current_floor = GameState.current_floor

	data.game_day = GameState.game_day

	data.relationship_state = RelationshipManager.get_save_state()
	data.event_state = EventManager.get_save_state()

	data.victory_day = GameState.victory_day
	data.intro_seen = GameState.intro_seen

	data.save_timestamp = int(Time.get_unix_time_from_system())
	data.play_time_seconds = _get_total_play_time()

	return data


## A copy that shares nothing with the original. Resource.duplicate(true)
## doesn't reach the floors, which sit inside a Dictionary.
func _copy_dungeon_set(source: DungeonSet) -> DungeonSet:
	var copy := DungeonSet.new()
	copy.set_number = source.set_number
	for d in source.dungeons:
		copy.dungeons.append(_copy_dungeon(d))
	if source.final_dungeon:
		copy.final_dungeon = _copy_dungeon(source.final_dungeon)
	return copy


func _copy_dungeon(source: Dungeon) -> Dungeon:
	var copy: Dungeon = source.duplicate()
	copy.bosses_slain = source.bosses_slain.duplicate()
	copy.floors = {}
	for floor_num in source.floors.keys():
		var floor_data = source.floors[floor_num]
		if floor_data:
			copy.floors[floor_num] = floor_data.duplicate(true)
	return copy


func _apply_save_data(data) -> void:
	GameState.roster = data.roster.duplicate(true)

	for character in GameState.roster.get_all():
		character.restore_active_statuses()

	GameState.parties.clear()
	GameState._active_party = null
	GameState.pending_collapse = {}
	GameState.pending_wipe = {}
	GameState.pending_camp = {}
	GameState.guild_storage = data.guild_storage.duplicate(true) if data.guild_storage else GameState._new_guild_storage()
	_deduplicate_inventory_items(GameState.guild_storage)
	GameState.chronicle = data.chronicle.duplicate(true)
	if data.dungeon_set != null:
		_apply_guild(data)
	else:
		_apply_version_5(data)

	GameState.party_formations = data.party_formations.duplicate(true) if data.party_formations else []
	GameState.game_day = data.game_day if data.game_day else 1

	if data.relationship_state:
		RelationshipManager.load_save_state(data.relationship_state)

	GameState.victory_day = data.victory_day
	GameState.intro_seen = data.intro_seen

	var event_data: Dictionary = data.get("event_state")
	if event_data and not event_data.is_empty():
		EventManager.load_save_state(event_data)


func _apply_guild(data) -> void:
	GameState.dungeon_set = _copy_dungeon_set(data.dungeon_set)
	GameState.dungeon_set.update_from_older_save()
	GameState.destination_dungeon_id = data.destination_dungeon_id
	GameState.guild_gold = data.guild_gold
	GameState.guild_scrap = data.guild_scrap
	for record: Dictionary in data.parties:
		var p := Party.new()
		p.id = record.get("id", "")
		p.party_name = record.get("name", "")
		for char_id in record.get("member_ids", []):
			var character: Character = GameState.roster.get_character(char_id)
			if character:
				p.add_member(character)
		var inventory: Inventory = record.get("inventory")
		if inventory:
			p.inventory = inventory.duplicate(true)
			_deduplicate_inventory_items(p.inventory)
		p.torch_steps_remaining = record.get("torch", 0)
		p.dungeon_id = record.get("dungeon_id", "")
		p.floor_num = record.get("floor", 1)
		p.position = record.get("position", Vector2i.ZERO)
		p.facing = record.get("facing", 0)
		p.spawn_at_stairs_up = record.get("spawn_at_stairs_up", true)
		p.carried_gold = record.get("carried_gold", 0)
		p.carried_scrap = record.get("carried_scrap", 0)
		p.tracker.load_state(record.get("tracker", {}))
		GameState.parties.append(p)
	GameState._active_party = GameState.get_party(data.active_party_id)
	if GameState._active_party == null:
		if GameState.parties.is_empty():
			GameState.party = Party.new()
		else:
			GameState._active_party = GameState.parties[0]


## A version 5 save had one party and one dungeon. It loads as a party in
## town and a fresh set whose first dungeon takes the old floors and slain
## bosses. If that save had already won, the first dungeon has collapsed.
func _apply_version_5(data) -> void:
	GameState.dungeon_set = DungeonSet.create()
	GameState.destination_dungeon_id = ""
	var dungeon: Dungeon = GameState.dungeon_set.dungeons[0]
	for floor_num in data.dungeon_floors.keys():
		var floor_data = data.dungeon_floors[floor_num]
		if floor_data:
			dungeon.floors[floor_num] = floor_data.duplicate(true)
	dungeon.bosses_slain.assign(data.bosses_slain if data.bosses_slain else [])
	# Saves from before deepest_floor existed: infer it from the floors visited.
	var deepest: int = data.deepest_floor
	for floor_num in dungeon.floors.keys():
		deepest = maxi(deepest, int(floor_num))
	dungeon.deepest_floor = deepest
	if data.victory_day > 0:
		dungeon.collapsed_day = data.victory_day
		dungeon.floors.clear()
		data.victory_day = 0

	GameState.guild_gold = data.party_gold
	GameState.guild_scrap = data.party_scrap
	var p := Party.new()
	for char_id in data.party_member_ids:
		var character: Character = GameState.roster.get_character(char_id)
		if character:
			p.add_member(character)
	if data.party_inventory:
		p.inventory = data.party_inventory.duplicate(true)
		_deduplicate_inventory_items(p.inventory)
	p.floor_num = data.current_floor
	p.position = data.player_position
	p.facing = data.player_facing
	p.spawn_at_stairs_up = data.spawn_at_stairs_up
	if not data.floor_tracker_state.is_empty():
		p.tracker.load_state(data.floor_tracker_state)
	GameState.party = p


func get_play_time_seconds() -> int:
	return _get_total_play_time()


func _get_total_play_time() -> int:
	var current_session := int(Time.get_unix_time_from_system()) - play_start_time
	return accumulated_play_time + current_session


func _deduplicate_inventory_items(inventory: Inventory) -> void:
	var seen_items: Array = []
	for slot in inventory.slots:
		var item = slot.get("item")
		if item == null:
			continue
		if item in seen_items:
			slot["item"] = item.duplicate() as Item
		else:
			seen_items.append(item)
