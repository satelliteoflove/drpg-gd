class_name DispelUndead
extends RefCounted

const BASE_SUCCESS_CHANCE: float = 0.5
const LEVEL_MODIFIER: float = 0.05
const DISPEL_XP_MULTIPLIER: float = 0.25


static func can_dispel(character: Character) -> bool:
	if character.is_dead or character.is_disabled():
		return false
	return character.character_class == CharacterEnums.CharacterClass.PRIEST or \
		   character.character_class == CharacterEnums.CharacterClass.BISHOP


static func get_valid_targets(enemies: Array[Monster]) -> Array[Monster]:
	var targets: Array[Monster] = []
	for enemy in enemies:
		if not enemy.is_dead and enemy.is_undead():
			targets.append(enemy)
	return targets


static func calculate_success_chance(priest_level: int, undead_level: int) -> float:
	var level_diff := priest_level - undead_level
	var chance := BASE_SUCCESS_CHANCE + (level_diff * LEVEL_MODIFIER)
	return clampf(chance, 0.1, 0.9)


static func attempt_dispel(character: Character, target: Monster) -> Dictionary:
	if not can_dispel(character):
		return {
			"success": false,
			"reason": "cannot_dispel",
			"message": "%s cannot dispel undead." % character.get_display_name()
		}

	if not target.is_undead():
		return {
			"success": false,
			"reason": "not_undead",
			"message": "%s is not undead." % target.monster_name
		}

	if target.is_dead:
		return {
			"success": false,
			"reason": "already_dead",
			"message": "%s is already defeated." % target.monster_name
		}

	var success_chance := calculate_success_chance(character.level, target.level)
	var roll := CombatRNG.randf()
	var success := roll < success_chance

	if success:
		var reduced_xp := int(target.exp_reward * DISPEL_XP_MULTIPLIER)
		target.current_hp = 0
		target.is_dead = true
		return {
			"success": true,
			"target": target.monster_name,
			"xp_gained": reduced_xp,
			"xp_lost": target.exp_reward - reduced_xp,
			"message": "%s dispels %s! (XP: %d)" % [
				character.get_display_name(),
				target.monster_name,
				reduced_xp
			]
		}
	else:
		return {
			"success": false,
			"reason": "failed",
			"target": target.monster_name,
			"message": "%s fails to dispel %s." % [
				character.get_display_name(),
				target.monster_name
			]
		}


static func select_best_target(character: Character, enemies: Array[Monster]) -> Monster:
	var valid := get_valid_targets(enemies)
	if valid.is_empty():
		return null

	var best_target: Monster = null
	var best_score: float = -1.0

	for target in valid:
		var success_chance := calculate_success_chance(character.level, target.level)
		var threat := float(target.current_hp) + float(target.strength) * 2.0
		var score := success_chance * threat

		if score > best_score:
			best_score = score
			best_target = target

	return best_target


static func should_attempt_dispel(character: Character, enemies: Array[Monster], party_health_percent: float) -> bool:
	if not can_dispel(character):
		return false

	var valid := get_valid_targets(enemies)
	if valid.is_empty():
		return false

	var undead_count := valid.size()
	var total_enemies := 0
	for e in enemies:
		if not e.is_dead:
			total_enemies += 1

	var undead_ratio := float(undead_count) / float(maxi(1, total_enemies))

	if undead_ratio >= 0.5:
		return true

	if party_health_percent < 0.4 and undead_count > 0:
		return true

	var best := select_best_target(character, enemies)
	if best:
		var chance := calculate_success_chance(character.level, best.level)
		if chance >= 0.6:
			return true

	return false
