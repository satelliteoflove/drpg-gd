class_name Targeting
extends RefCounted

const CombatRNG = preload("res://autoload/combat_rng.gd")

enum TargetPattern {
	SINGLE,
	ROW,
	COLUMN,
	CROSS,
	X_CROSS,
	SPLASH,
	ALL
}

const GRID_ROWS: int = 3
const GRID_COLS: int = 3


static func get_weapon_range(character: Character) -> int:
	if character.equipped_weapon != null:
		return character.equipped_weapon.weapon_range
	return 1


static func get_effective_range(character: Character, party: Party) -> int:
	var base_range := get_weapon_range(character)
	var in_back_row := party.is_back_row(character.id)
	return base_range - (1 if in_back_row else 0)


static func can_reach_enemy(character: Character, enemy: Monster, party: Party) -> bool:
	var effective_range := get_effective_range(character, party)
	return enemy.get_row() < effective_range


static func get_reachable_enemies(character: Character, party: Party, enemies: Array[Monster]) -> Array[Monster]:
	var reachable: Array[Monster] = []
	var effective_range := get_effective_range(character, party)

	for enemy in enemies:
		if enemy.is_dead:
			continue
		if enemy.get_row() < effective_range:
			reachable.append(enemy)

	return reachable


static func get_living_enemies(enemies: Array[Monster]) -> Array[Monster]:
	var living: Array[Monster] = []
	for enemy in enemies:
		if not enemy.is_dead:
			living.append(enemy)
	return living


static func get_pattern_targets(
	pattern: TargetPattern,
	origin: Vector2i,
	enemies: Array[Monster]
) -> Array[Monster]:
	var targets: Array[Monster] = []
	var target_positions: Array[Vector2i] = _get_pattern_positions(pattern, origin)

	for enemy in enemies:
		if enemy.is_dead:
			continue
		if enemy.grid_position in target_positions:
			targets.append(enemy)

	return targets


static func _get_pattern_positions(pattern: TargetPattern, origin: Vector2i) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []

	match pattern:
		TargetPattern.SINGLE:
			positions.append(origin)

		TargetPattern.ROW:
			for col in range(GRID_COLS):
				positions.append(Vector2i(col, origin.y))

		TargetPattern.COLUMN:
			for row in range(GRID_ROWS):
				positions.append(Vector2i(origin.x, row))

		TargetPattern.CROSS:
			positions.append(origin)
			if origin.y > 0:
				positions.append(Vector2i(origin.x, origin.y - 1))
			if origin.y < GRID_ROWS - 1:
				positions.append(Vector2i(origin.x, origin.y + 1))
			if origin.x > 0:
				positions.append(Vector2i(origin.x - 1, origin.y))
			if origin.x < GRID_COLS - 1:
				positions.append(Vector2i(origin.x + 1, origin.y))

		TargetPattern.X_CROSS:
			positions.append(origin)
			if origin.x > 0 and origin.y > 0:
				positions.append(Vector2i(origin.x - 1, origin.y - 1))
			if origin.x < GRID_COLS - 1 and origin.y > 0:
				positions.append(Vector2i(origin.x + 1, origin.y - 1))
			if origin.x > 0 and origin.y < GRID_ROWS - 1:
				positions.append(Vector2i(origin.x - 1, origin.y + 1))
			if origin.x < GRID_COLS - 1 and origin.y < GRID_ROWS - 1:
				positions.append(Vector2i(origin.x + 1, origin.y + 1))

		TargetPattern.SPLASH:
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var pos := Vector2i(origin.x + dx, origin.y + dy)
					if pos.x >= 0 and pos.x < GRID_COLS and pos.y >= 0 and pos.y < GRID_ROWS:
						positions.append(pos)

		TargetPattern.ALL:
			for col in range(GRID_COLS):
				for row in range(GRID_ROWS):
					positions.append(Vector2i(col, row))

	return positions


static func get_front_row_enemy(enemies: Array[Monster]) -> Monster:
	var front_enemies: Array[Monster] = []

	for row in range(GRID_ROWS):
		for enemy in enemies:
			if enemy.is_dead:
				continue
			if enemy.get_row() == row:
				front_enemies.append(enemy)
		if not front_enemies.is_empty():
			break

	if front_enemies.is_empty():
		return null

	return front_enemies[CombatRNG.randi() % front_enemies.size()]
