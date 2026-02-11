class_name EnemyManager
extends RefCounted

signal enemy_group_spawned(group: EnemyGroup)
signal enemy_group_defeated(group: EnemyGroup)
signal zone_cleared(zone: EncounterZone)
signal combat_triggered(group: EnemyGroup)

var dungeon_data: DungeonData
var floor_tracker: FloorTracker
var enemy_groups: Array[EnemyGroup] = []
var _enemy_ai: EnemyAI
var _pathfinding: DungeonPathfinding
var _los_calculator: LOSCalculator
var _next_group_id: int = 0

var allow_spawn_near_stairs: bool = true
var _pending_door_closes: Array[Dictionary] = []
var changed_doors: Array[Dictionary] = []


func initialize(data: DungeonData, tracker: FloorTracker) -> void:
	dungeon_data = data
	floor_tracker = tracker
	enemy_groups.clear()
	_next_group_id = 0

	_enemy_ai = EnemyAI.new()
	_pathfinding = DungeonPathfinding.new()
	_pathfinding.initialize(data)
	_los_calculator = LOSCalculator.new()


func spawn_initial_enemies() -> void:
	for zone in dungeon_data.zones:
		if zone.zone_type == EncounterZone.ZoneType.SAFE:
			continue
		var spawn_count := _calculate_initial_spawn_count(zone)
		for i in range(spawn_count):
			_spawn_enemy_in_zone(zone)


func _calculate_initial_spawn_count(zone: EncounterZone) -> int:
	match zone.zone_type:
		EncounterZone.ZoneType.NORMAL:
			return randi_range(1, 2)
		EncounterZone.ZoneType.LOW_SPAWN:
			return randi_range(1, 2)
		EncounterZone.ZoneType.HIGH_SPAWN:
			return randi_range(2, 3)
		EncounterZone.ZoneType.BOSS:
			return 1
		_:
			return 1


func _spawn_enemy_in_zone(zone: EncounterZone) -> EnemyGroup:
	if zone.current_group_count >= zone.max_groups:
		return null

	var spawn_pos := _find_valid_spawn_position(zone)
	if spawn_pos == Vector2i(-1, -1):
		return null

	var ai_type := _pick_ai_type(zone)
	var monsters := _generate_monsters(zone)

	if monsters.is_empty():
		return null

	var group := EnemyGroup.create(
		_generate_group_id(),
		spawn_pos,
		ai_type,
		monsters,
		zone.id
	)

	if ai_type == EnemyGroup.AIType.PATROLLER:
		group.patrol_route = _generate_patrol_route(spawn_pos, zone)

	enemy_groups.append(group)
	zone.on_enemy_spawned()
	enemy_group_spawned.emit(group)

	return group


func _find_valid_spawn_position(zone: EncounterZone) -> Vector2i:
	var attempts := 20
	for i in range(attempts):
		var pos := zone.get_random_spawn_position()
		if _is_position_valid_for_spawn(pos):
			return pos
	return Vector2i(-1, -1)


func _is_position_valid_for_spawn(pos: Vector2i) -> bool:
	if not dungeon_data.is_walkable(pos.x, pos.y):
		return false

	var tile := dungeon_data.get_tile(pos.x, pos.y)
	if tile == null:
		return false
	if not allow_spawn_near_stairs:
		if tile.special == DungeonTile.SpecialType.STAIRS_UP:
			return false
		if tile.special == DungeonTile.SpecialType.STAIRS_DOWN:
			return false

	for group in enemy_groups:
		if group.grid_position == pos:
			return false

	return true


func _pick_ai_type(zone: EncounterZone) -> EnemyGroup.AIType:
	if zone.zone_type == EncounterZone.ZoneType.BOSS:
		return EnemyGroup.AIType.BOSS

	var roll := randf()
	if roll < 0.70:
		return EnemyGroup.AIType.WANDERER
	elif roll < 0.90:
		return EnemyGroup.AIType.PATROLLER
	else:
		return EnemyGroup.AIType.GUARDIAN


func _generate_monsters(zone: EncounterZone) -> Array[Monster]:
	if zone.zone_type == EncounterZone.ZoneType.BOSS:
		return _generate_boss_encounter()

	var monsters: Array[Monster] = []
	var count := _roll_enemy_count()

	var available_ids: Array[String] = []
	if not zone.monster_pool.is_empty():
		available_ids.assign(zone.monster_pool)
	else:
		available_ids.assign(MonsterDatabase.get_monsters_for_floor(dungeon_data.floor_level))

	if available_ids.is_empty():
		available_ids.append("slime")

	for i in range(count):
		var monster_id: String = available_ids[randi() % available_ids.size()]
		var monster := MonsterDatabase.get_monster(monster_id)
		if monster != null:
			monster.init_combat()
			monsters.append(monster)

	return monsters


func _generate_boss_encounter() -> Array[Monster]:
	var monsters: Array[Monster] = []
	var boss := MonsterDatabase.get_boss_for_floor(dungeon_data.floor_level)
	if boss == null:
		var fallback_ids := MonsterDatabase.get_monsters_for_floor(dungeon_data.floor_level)
		if fallback_ids.is_empty():
			fallback_ids = ["slime"]
		var monster := MonsterDatabase.get_monster(fallback_ids[randi() % fallback_ids.size()])
		if monster != null:
			monster.init_combat()
			monsters.append(monster)
		return monsters

	boss.init_combat()
	monsters.append(boss)

	var minion_ids := MonsterDatabase.get_boss_minions(dungeon_data.floor_level)
	for minion_id in minion_ids:
		var minion := MonsterDatabase.get_monster(minion_id)
		if minion != null:
			minion.init_combat()
			monsters.append(minion)

	return monsters


func _roll_enemy_count() -> int:
	var roll := randf()
	if roll < 0.4:
		return 1
	elif roll < 0.7:
		return 2
	elif roll < 0.9:
		return 3
	else:
		return 4


func _generate_group_id() -> String:
	var id := "group_%d_%d" % [dungeon_data.floor_level, _next_group_id]
	_next_group_id += 1
	return id


func _generate_patrol_route(start: Vector2i, zone: EncounterZone) -> Array[Vector2i]:
	var route: Array[Vector2i] = [start]
	var current := start
	var route_length := randi_range(3, 6)

	for i in range(route_length):
		var next := _find_patrol_destination(current, zone, route)
		if next == Vector2i(-1, -1):
			break
		route.append(next)
		current = next

	return route


func _find_patrol_destination(from: Vector2i, zone: EncounterZone, exclude: Array[Vector2i]) -> Vector2i:
	var candidates: Array[Vector2i] = []

	for pos in zone.tile_positions:
		if pos in exclude:
			continue
		if not dungeon_data.is_walkable(pos.x, pos.y):
			continue
		var dist: int = abs(pos.x - from.x) + abs(pos.y - from.y)
		if dist >= 3 and dist <= 8:
			candidates.append(pos)

	if candidates.is_empty():
		return Vector2i(-1, -1)

	return candidates[randi() % candidates.size()]


func on_player_move(new_pos: Vector2i, facing: int) -> EnemyGroup:
	floor_tracker.increment_step()

	var combat_group: EnemyGroup = null

	for group in enemy_groups:
		if group.grid_position == new_pos:
			combat_group = group
			break

	if combat_group != null:
		combat_triggered.emit(combat_group)
		return combat_group

	_update_all_enemies(new_pos, facing)

	for group in enemy_groups:
		if group.grid_position == new_pos:
			combat_group = group
			break

	if combat_group != null:
		combat_triggered.emit(combat_group)

	_process_respawns()

	return combat_group


func _update_all_enemies(player_pos: Vector2i, player_facing: int) -> void:
	_pending_door_closes.clear()
	changed_doors.clear()
	for group in enemy_groups:
		var action: Dictionary = _enemy_ai.decide_action(group, player_pos, dungeon_data, floor_tracker)
		_execute_action(group, action, player_pos)
	_apply_pending_door_closes()


func _execute_action(group: EnemyGroup, action: Dictionary, player_pos: Vector2i) -> void:
	var action_type: String = action.get("type", "idle")

	if action_type != "chase":
		group.door_wait_turns = 0
		group.door_wait_direction = ""
		group.door_wait_position = Vector2i.ZERO

	match action_type:
		"move":
			var target: Vector2i = action.get("target", group.grid_position)
			_move_group(group, target)
		"chase":
			group.start_chase(player_pos)
			var move_target: Vector2i = action.get("target", group.grid_position)
			_move_group_chase(group, move_target)
			floor_tracker.register_spotted(group.id)
		"pursue":
			var move_target: Vector2i = action.get("target", group.grid_position)
			_move_group(group, move_target)
		"search":
			if action.get("start_search", false):
				group.start_search()
			else:
				group.tick_search()
		"return":
			var move_target: Vector2i = action.get("target", group.grid_position)
			_move_group(group, move_target)
			if group.is_at_home():
				group.resume_patrol()
		"flee":
			var move_target: Vector2i = action.get("target", group.grid_position)
			_move_group(group, move_target)


func _move_group(group: EnemyGroup, target: Vector2i) -> void:
	if target == group.grid_position:
		return

	if _is_position_valid_for_move(target, group):
		group.grid_position = target
		group.steps_from_home = abs(target.x - group.home_position.x) + abs(target.y - group.home_position.y)
		return

	var alternatives := _pathfinding.get_all_adjacent(group.grid_position)
	alternatives.shuffle()
	for alt in alternatives:
		if _is_position_valid_for_move(alt, group):
			group.grid_position = alt
			group.steps_from_home = abs(alt.x - group.home_position.x) + abs(alt.y - group.home_position.y)
			return


func _move_group_chase(group: EnemyGroup, target: Vector2i) -> void:
	if target == group.grid_position:
		return

	var blocked_dir := _is_blocked_by_closed_door(group.grid_position, target)
	if blocked_dir != "":
		_handle_enemy_door_wait(group, target, blocked_dir)
		return

	var old_pos := group.grid_position
	if _is_position_valid_for_move(target, group):
		group.grid_position = target
		group.steps_from_home = abs(target.x - group.home_position.x) + abs(target.y - group.home_position.y)
		_maybe_schedule_door_close(old_pos, target)
		return

	var alternatives := _pathfinding.get_all_adjacent(group.grid_position)
	alternatives.shuffle()
	for alt in alternatives:
		if _is_position_valid_for_move(alt, group):
			group.grid_position = alt
			group.steps_from_home = abs(alt.x - group.home_position.x) + abs(alt.y - group.home_position.y)
			_maybe_schedule_door_close(old_pos, alt)
			return


func _is_blocked_by_closed_door(from: Vector2i, to: Vector2i) -> String:
	var dir := _get_direction_between(from, to)
	if dir == "":
		return ""
	var tile := dungeon_data.get_tile(from.x, from.y)
	if tile == null:
		return ""
	if tile.get_wall_type(dir) == DungeonTile.WallType.DOOR and not tile.is_door_open(dir):
		return dir
	return ""


func _get_direction_between(from: Vector2i, to: Vector2i) -> String:
	var dx := to.x - from.x
	var dy := to.y - from.y
	if dy < 0: return "north"
	if dy > 0: return "south"
	if dx > 0: return "east"
	if dx < 0: return "west"
	return ""


func _handle_enemy_door_wait(group: EnemyGroup, target: Vector2i, direction: String) -> void:
	if group.door_wait_position == group.grid_position and group.door_wait_direction == direction:
		group.door_wait_turns += 1
	else:
		group.door_wait_turns = 1
		group.door_wait_direction = direction
		group.door_wait_position = group.grid_position

	var threshold := randi_range(1, 2)
	if group.door_wait_turns >= threshold:
		dungeon_data.sync_door_open(group.grid_position.x, group.grid_position.y, direction, true)
		_record_door_change(group.grid_position.x, group.grid_position.y, direction)
		group.door_wait_turns = 0
		group.door_wait_direction = ""
		group.door_wait_position = Vector2i.ZERO

		var old_pos := group.grid_position
		if _is_position_valid_for_move(target, group):
			group.grid_position = target
			group.steps_from_home = abs(target.x - group.home_position.x) + abs(target.y - group.home_position.y)
			_maybe_schedule_door_close(old_pos, target)


func _maybe_schedule_door_close(old_pos: Vector2i, new_pos: Vector2i) -> void:
	var dir := _get_direction_between(old_pos, new_pos)
	if dir == "":
		return
	var tile := dungeon_data.get_tile(old_pos.x, old_pos.y)
	if tile == null:
		return
	if tile.get_wall_type(dir) == DungeonTile.WallType.DOOR and tile.is_door_open(dir):
		_pending_door_closes.append({"x": old_pos.x, "y": old_pos.y, "direction": dir})


func _apply_pending_door_closes() -> void:
	for close_data in _pending_door_closes:
		dungeon_data.sync_door_open(close_data.x, close_data.y, close_data.direction, false)
		_record_door_change(close_data.x, close_data.y, close_data.direction)
	_pending_door_closes.clear()


func _record_door_change(x: int, y: int, direction: String) -> void:
	changed_doors.append({"x": x, "y": y, "direction": direction})
	var offset: Vector2i = DungeonData.DIR_OFFSET[direction]
	changed_doors.append({"x": x + offset.x, "y": y + offset.y, "direction": DungeonData.OPPOSITE_DIR[direction]})


func _is_position_valid_for_move(pos: Vector2i, moving_group: EnemyGroup) -> bool:
	if not dungeon_data.is_walkable(pos.x, pos.y):
		return false

	var tile := dungeon_data.get_tile(pos.x, pos.y)
	if tile == null:
		return false
	if tile.special == DungeonTile.SpecialType.STAIRS_UP:
		return false
	if tile.special == DungeonTile.SpecialType.STAIRS_DOWN:
		return false

	for group in enemy_groups:
		if group == moving_group:
			continue
		if group.grid_position == pos:
			return false

	return true


func _process_respawns() -> void:
	for zone in dungeon_data.zones:
		zone.on_step()

		if zone.can_spawn():
			_spawn_enemy_in_zone(zone)


func get_visible_groups(player_pos: Vector2i, player_facing: int) -> Array[EnemyGroup]:
	var visible: Array[EnemyGroup] = []
	var view_range := 8

	for group in enemy_groups:
		var dist: int = abs(group.grid_position.x - player_pos.x) + abs(group.grid_position.y - player_pos.y)

		if dist > view_range:
			continue

		if not _los_calculator.has_line_of_sight(dungeon_data, player_pos, group.grid_position):
			continue

		visible.append(group)

	return visible


func get_minimap_data() -> Dictionary:
	var data := {
		"groups": [],
		"cleared_zones": []
	}

	for group in enemy_groups:
		var group_data := {
			"id": group.id,
			"position": group.grid_position,
			"spotted": floor_tracker.is_spotted(group.id),
			"revealed": floor_tracker.is_revealed()
		}
		data.groups.append(group_data)

	for zone in dungeon_data.zones:
		if zone.is_cleared:
			data.cleared_zones.append(zone.id)

	return data


func remove_defeated_group(group: EnemyGroup) -> void:
	var idx := enemy_groups.find(group)
	if idx >= 0:
		enemy_groups.remove_at(idx)
		enemy_group_defeated.emit(group)

		for zone in dungeon_data.zones:
			if zone.id == group.zone_id:
				zone.on_enemy_defeated()
				if zone.current_group_count <= 0:
					zone_cleared.emit(zone)
				break


func get_group_at(pos: Vector2i) -> EnemyGroup:
	for group in enemy_groups:
		if group.grid_position == pos:
			return group
	return null


func get_party_power() -> int:
	if GameState.party == null:
		return 1
	var power := 0
	for member in GameState.party.members:
		if not member.is_dead:
			power += member.level
	return maxi(1, power)
