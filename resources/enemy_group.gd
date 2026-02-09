class_name EnemyGroup
extends Resource

enum AIType { WANDERER, PATROLLER, GUARDIAN, BOSS }
enum State { IDLE, PATROL, CHASE, PURSUE, SEARCH, RETURN, FLEE }

const DETECTION_RANGES := {
	AIType.WANDERER: 3,
	AIType.PATROLLER: 4,
	AIType.GUARDIAN: 5,
	AIType.BOSS: 99
}

const CHASE_LEASH := {
	AIType.WANDERER: {min = 6, max = 8},
	AIType.PATROLLER: {min = 10, max = 12},
	AIType.GUARDIAN: 99,
	AIType.BOSS: 99
}

const SEARCH_TURNS := {min = 3, max = 5}

@export var id: String = ""
@export var grid_position: Vector2i = Vector2i.ZERO
@export var home_position: Vector2i = Vector2i.ZERO
@export var ai_type: AIType = AIType.WANDERER
@export var state: State = State.PATROL
@export var monsters: Array[Monster] = []
@export var zone_id: String = ""
@export var patrol_route: Array[Vector2i] = []
@export var patrol_index: int = 0

var last_known_player_pos: Vector2i = Vector2i(-1, -1)
var search_turns_remaining: int = 0
var was_spotted: bool = false
var is_revealed: bool = false
var leash_distance: int = 0
var steps_from_home: int = 0


func _init() -> void:
	_generate_leash_distance()


func _generate_leash_distance() -> void:
	var leash_config = CHASE_LEASH.get(ai_type, {min = 6, max = 8})
	if leash_config is int:
		leash_distance = leash_config
	else:
		leash_distance = randi_range(leash_config.min, leash_config.max)


func get_strongest_monster() -> Monster:
	if monsters.is_empty():
		return null
	var strongest: Monster = monsters[0]
	for monster in monsters:
		if monster.level > strongest.level:
			strongest = monster
	return strongest


func get_detection_range() -> int:
	return DETECTION_RANGES.get(ai_type, 3)


func get_chase_leash() -> int:
	return leash_distance


func get_total_level() -> int:
	var total := 0
	for monster in monsters:
		total += monster.level
	return total


func get_display_name() -> String:
	if monsters.is_empty():
		return "Unknown Group"
	if monsters.size() == 1:
		return monsters[0].monster_name
	var strongest := get_strongest_monster()
	return "%s +%d" % [strongest.monster_name, monsters.size() - 1]


func start_chase(player_pos: Vector2i) -> void:
	state = State.CHASE
	last_known_player_pos = player_pos
	was_spotted = true


func lose_sight(player_pos: Vector2i) -> void:
	state = State.PURSUE
	last_known_player_pos = player_pos


func start_search() -> void:
	state = State.SEARCH
	search_turns_remaining = randi_range(SEARCH_TURNS.min, SEARCH_TURNS.max)


func tick_search() -> bool:
	search_turns_remaining -= 1
	if search_turns_remaining <= 0:
		state = State.RETURN
		return true
	return false


func return_home() -> void:
	state = State.RETURN


func resume_patrol() -> void:
	if ai_type == AIType.GUARDIAN:
		state = State.IDLE
	else:
		state = State.PATROL
	steps_from_home = 0


func is_at_home() -> bool:
	return grid_position == home_position


func is_beyond_leash() -> bool:
	var dist: int = abs(grid_position.x - home_position.x) + abs(grid_position.y - home_position.y)
	return dist > leash_distance


func should_flee(party_power: int) -> bool:
	if ai_type == AIType.BOSS or ai_type == AIType.GUARDIAN:
		return false
	var group_power := get_total_level()
	return party_power > group_power * 5


func get_next_patrol_point() -> Vector2i:
	if patrol_route.is_empty():
		return home_position
	patrol_index = (patrol_index + 1) % patrol_route.size()
	return patrol_route[patrol_index]


func is_alive() -> bool:
	for monster in monsters:
		if not monster.is_dead:
			return true
	return false


func duplicate_for_encounter() -> EnemyGroup:
	var copy := EnemyGroup.new()
	copy.id = id
	copy.grid_position = grid_position
	copy.home_position = home_position
	copy.ai_type = ai_type
	copy.state = state
	copy.zone_id = zone_id
	copy.patrol_route = patrol_route.duplicate()
	copy.patrol_index = patrol_index
	copy.last_known_player_pos = last_known_player_pos
	copy.search_turns_remaining = search_turns_remaining
	copy.was_spotted = was_spotted
	copy.is_revealed = is_revealed
	copy.leash_distance = leash_distance
	copy.steps_from_home = steps_from_home

	for monster in monsters:
		var monster_copy := monster.duplicate_for_combat()
		copy.monsters.append(monster_copy)

	return copy


static func create(
	p_id: String,
	p_position: Vector2i,
	p_ai_type: AIType,
	p_monsters: Array[Monster],
	p_zone_id: String = ""
) -> EnemyGroup:
	var group := EnemyGroup.new()
	group.id = p_id
	group.grid_position = p_position
	group.home_position = p_position
	group.ai_type = p_ai_type
	group.monsters = p_monsters
	group.zone_id = p_zone_id
	group._generate_leash_distance()

	if p_ai_type == AIType.GUARDIAN or p_ai_type == AIType.BOSS:
		group.state = State.IDLE
	else:
		group.state = State.PATROL

	return group
