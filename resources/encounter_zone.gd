class_name EncounterZone
extends Resource

enum ZoneType { SAFE, NORMAL, LOW_SPAWN, HIGH_SPAWN, BOSS, SPECIAL }

const ZONE_CONFIG := {
	ZoneType.SAFE: {respawn_steps = -1, clear_steps = -1, max_groups = 0},
	ZoneType.NORMAL: {respawn_steps = 90, clear_steps = 70, max_groups = 3},
	ZoneType.LOW_SPAWN: {respawn_steps = 80, clear_steps = 100, max_groups = 2},
	ZoneType.HIGH_SPAWN: {respawn_steps = 50, clear_steps = 25, max_groups = 4},
	ZoneType.BOSS: {respawn_steps = 400, clear_steps = 175, max_groups = 1},
	ZoneType.SPECIAL: {respawn_steps = 200, clear_steps = 150, max_groups = 2}
}

@export var id: String = ""
@export var zone_type: ZoneType = ZoneType.NORMAL
@export var tile_positions: Array[Vector2i] = []
@export var monster_pool: Array[String] = []
@export var max_groups: int = 3

var respawn_steps: int = 90
var clear_steps: int = 70
var is_cleared: bool = false
var clear_steps_remaining: int = 0
var steps_since_spawn: int = 0
var current_group_count: int = 0


func _init() -> void:
	_apply_zone_config()


func _apply_zone_config() -> void:
	var config: Dictionary = ZONE_CONFIG.get(zone_type, ZONE_CONFIG[ZoneType.NORMAL])
	respawn_steps = config.respawn_steps
	clear_steps = config.clear_steps
	if max_groups == 3:
		max_groups = config.max_groups


func set_zone_type(p_type: ZoneType) -> void:
	zone_type = p_type
	_apply_zone_config()


func can_spawn() -> bool:
	if zone_type == ZoneType.SAFE:
		return false
	if is_cleared and clear_steps_remaining > 0:
		return false
	if current_group_count >= max_groups:
		return false
	return steps_since_spawn >= respawn_steps


func on_enemy_spawned() -> void:
	current_group_count += 1
	steps_since_spawn = 0


func on_enemy_defeated() -> void:
	current_group_count -= 1
	if current_group_count <= 0:
		current_group_count = 0
		_mark_cleared()


func _mark_cleared() -> void:
	is_cleared = true
	clear_steps_remaining = clear_steps


func on_step() -> void:
	steps_since_spawn += 1
	if is_cleared and clear_steps_remaining > 0:
		clear_steps_remaining -= 1
		if clear_steps_remaining <= 0:
			is_cleared = false


func contains_position(pos: Vector2i) -> bool:
	return pos in tile_positions


func get_random_spawn_position() -> Vector2i:
	if tile_positions.is_empty():
		return Vector2i.ZERO
	return tile_positions[randi() % tile_positions.size()]


func get_center() -> Vector2i:
	if tile_positions.is_empty():
		return Vector2i.ZERO
	var sum := Vector2i.ZERO
	for pos in tile_positions:
		sum += pos
	return Vector2i(sum.x / tile_positions.size(), sum.y / tile_positions.size())


static func create(p_id: String, p_type: ZoneType, p_tiles: Array[Vector2i]) -> EncounterZone:
	var zone := EncounterZone.new()
	zone.id = p_id
	zone.set_zone_type(p_type)
	zone.tile_positions = p_tiles
	return zone


static func create_safe_zone(p_id: String, center: Vector2i, radius: int = 2) -> EncounterZone:
	var tiles: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if abs(dx) + abs(dy) <= radius:
				tiles.append(center + Vector2i(dx, dy))
	return create(p_id, ZoneType.SAFE, tiles)
