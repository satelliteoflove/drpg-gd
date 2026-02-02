class_name EnemyAI
extends RefCounted

var _pathfinding: DungeonPathfinding
var _los_calculator: LOSCalculator


func _init() -> void:
	_pathfinding = DungeonPathfinding.new()
	_los_calculator = LOSCalculator.new()


func decide_action(
	group: EnemyGroup,
	player_pos: Vector2i,
	dungeon: DungeonData,
	_floor_tracker: FloorTracker
) -> Dictionary:
	if _pathfinding._dungeon != dungeon:
		_pathfinding.initialize(dungeon)

	var can_see_player := can_detect_player(group, player_pos, dungeon)
	var party_power := _get_party_power()

	if group.should_flee(party_power):
		return _get_flee_action(group, player_pos, dungeon)

	match group.state:
		EnemyGroup.State.IDLE:
			return _process_idle(group, player_pos, can_see_player)

		EnemyGroup.State.PATROL:
			return _process_patrol(group, player_pos, dungeon, can_see_player)

		EnemyGroup.State.CHASE:
			return _process_chase(group, player_pos, dungeon, can_see_player)

		EnemyGroup.State.PURSUE:
			return _process_pursue(group, dungeon)

		EnemyGroup.State.SEARCH:
			return _process_search(group, dungeon)

		EnemyGroup.State.RETURN:
			return _process_return(group, dungeon)

		EnemyGroup.State.FLEE:
			return _get_flee_action(group, player_pos, dungeon)

	return {"type": "idle"}


func _process_idle(group: EnemyGroup, player_pos: Vector2i, can_see: bool) -> Dictionary:
	if can_see:
		return {
			"type": "chase",
			"target": _get_chase_move(group, player_pos)
		}
	return {"type": "idle"}


func _process_patrol(
	group: EnemyGroup,
	player_pos: Vector2i,
	dungeon: DungeonData,
	can_see: bool
) -> Dictionary:
	if can_see:
		return {
			"type": "chase",
			"target": _get_chase_move(group, player_pos)
		}

	var target: Vector2i
	match group.ai_type:
		EnemyGroup.AIType.WANDERER:
			target = _get_wander_move(group, dungeon)
		EnemyGroup.AIType.PATROLLER:
			target = _get_patrol_move(group, dungeon)
		_:
			target = group.grid_position

	return {"type": "move", "target": target}


func _process_chase(
	group: EnemyGroup,
	player_pos: Vector2i,
	dungeon: DungeonData,
	can_see: bool
) -> Dictionary:
	if not can_see:
		group.lose_sight(player_pos)
		return {"type": "pursue", "target": _get_pursue_move(group, dungeon)}

	if group.is_beyond_leash():
		group.lose_sight(player_pos)
		return {"type": "pursue", "target": _get_pursue_move(group, dungeon)}

	group.last_known_player_pos = player_pos
	return {"type": "chase", "target": _get_chase_move(group, player_pos)}


func _process_pursue(group: EnemyGroup, dungeon: DungeonData) -> Dictionary:
	if group.grid_position == group.last_known_player_pos:
		return {"type": "search", "start_search": true}

	return {"type": "pursue", "target": _get_pursue_move(group, dungeon)}


func _process_search(group: EnemyGroup, dungeon: DungeonData) -> Dictionary:
	if group.tick_search():
		return {"type": "return", "target": _get_return_move(group, dungeon)}

	if randf() < 0.5:
		var random_adjacent := _pathfinding.get_random_adjacent(group.grid_position)
		return {"type": "move", "target": random_adjacent}

	return {"type": "search"}


func _process_return(group: EnemyGroup, dungeon: DungeonData) -> Dictionary:
	if group.is_at_home():
		group.resume_patrol()
		return {"type": "idle"}

	return {"type": "return", "target": _get_return_move(group, dungeon)}


func _get_wander_move(group: EnemyGroup, _dungeon: DungeonData) -> Vector2i:
	if randf() < 0.3:
		return group.grid_position

	return _pathfinding.get_random_adjacent(group.grid_position)


func _get_patrol_move(group: EnemyGroup, dungeon: DungeonData) -> Vector2i:
	if group.patrol_route.is_empty():
		return _get_wander_move(group, dungeon)

	var target := group.patrol_route[group.patrol_index]

	if group.grid_position == target:
		target = group.get_next_patrol_point()

	return _pathfinding.get_next_step(group.grid_position, target, false)


func _get_chase_move(group: EnemyGroup, player_pos: Vector2i) -> Vector2i:
	return _pathfinding.get_next_step(group.grid_position, player_pos, false)


func _get_pursue_move(group: EnemyGroup, _dungeon: DungeonData) -> Vector2i:
	return _pathfinding.get_next_step(group.grid_position, group.last_known_player_pos, false)


func _get_return_move(group: EnemyGroup, _dungeon: DungeonData) -> Vector2i:
	return _pathfinding.get_next_step(group.grid_position, group.home_position, false)


func _get_flee_action(group: EnemyGroup, player_pos: Vector2i, _dungeon: DungeonData) -> Dictionary:
	group.state = EnemyGroup.State.FLEE
	var flee_pos := _pathfinding.get_flee_direction(group.grid_position, player_pos)
	return {"type": "flee", "target": flee_pos}


func can_detect_player(group: EnemyGroup, player_pos: Vector2i, dungeon: DungeonData) -> bool:
	var dist := _los_calculator.get_distance(group.grid_position, player_pos)
	var detection_range := group.get_detection_range()

	if dist > detection_range:
		return false

	return _los_calculator.has_line_of_sight(dungeon, group.grid_position, player_pos)


func should_flee(group: EnemyGroup, party_power: int) -> bool:
	return group.should_flee(party_power)


func _get_party_power() -> int:
	if GameState.party == null:
		return 1
	var power := 0
	for member in GameState.party.members:
		if not member.is_dead:
			power += member.level
	return maxi(1, power)
