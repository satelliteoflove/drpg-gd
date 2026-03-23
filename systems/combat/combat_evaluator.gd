class_name CombatEvaluator
extends RefCounted


static func score_party_target(member: Character, party: Party, is_melee: bool = true) -> float:
	var score := 10.0

	var role := _get_role_weight(member)
	score += role

	var hp_percent := float(member.current_hp) / float(maxi(1, member.max_hp))
	score += CombatConstants.FOCUS_FIRE_WOUNDED_BONUS * (1.0 - hp_percent)

	if hp_percent <= CombatConstants.FOCUS_FIRE_KILL_THRESHOLD:
		score += CombatConstants.FOCUS_FIRE_KILL_BONUS

	if member.has_status(CharacterEnums.StatusEffect.ASLEEP):
		score += CombatConstants.TARGET_SLEEPING_BONUS
	if member.has_status(CharacterEnums.StatusEffect.PARALYZED) or member.has_status(CharacterEnums.StatusEffect.STONED):
		score += CombatConstants.TARGET_DISABLED_PENALTY
	if member.is_defending:
		score += CombatConstants.TARGET_DEFENDING_PENALTY
	if member.has_status(CharacterEnums.StatusEffect.CHARMED):
		score += CombatConstants.TARGET_CHARMED_PENALTY
	if member.has_status(CharacterEnums.StatusEffect.CONFUSED):
		score += CombatConstants.TARGET_CONFUSED_PENALTY

	if is_melee and party.is_back_row(member.id):
		score *= CombatConstants.THREAT_BACK_ROW_MULTIPLIER

	return maxf(1.0, score)


static func score_monster_target(monster: Monster, _all_enemies: Array[Monster]) -> float:
	var score := 10.0

	score += monster.strength * CombatConstants.MONSTER_THREAT_STR_WEIGHT
	score += monster.max_mp * CombatConstants.MONSTER_THREAT_MP_WEIGHT

	var best_avg := 0.0
	for attack in monster.attacks:
		var avg := estimate_dice_average(attack.damage_dice)
		if avg > best_avg:
			best_avg = avg
	score += best_avg * CombatConstants.MONSTER_THREAT_ATTACK_WEIGHT

	var hp_percent := float(monster.current_hp) / float(maxi(1, monster.max_hp))
	score += CombatConstants.FOCUS_FIRE_WOUNDED_BONUS * (1.0 - hp_percent)

	if hp_percent <= CombatConstants.FOCUS_FIRE_KILL_THRESHOLD:
		score += CombatConstants.FOCUS_FIRE_KILL_BONUS

	return score


static func calculate_adaptive_cast_chance(monster: Monster, alive_target_count: int) -> float:
	var chance := CombatConstants.CAST_CHANCE_BASE

	var hp_percent := float(monster.current_hp) / float(maxi(1, monster.max_hp))
	if hp_percent < 0.5:
		chance += CombatConstants.CAST_CHANCE_HP_BONUS

	if alive_target_count >= 3:
		chance += CombatConstants.CAST_CHANCE_TARGETS_BONUS

	var mp_percent := float(monster.current_mp) / float(maxi(1, monster.max_mp))
	if mp_percent < 0.3:
		chance -= CombatConstants.CAST_CHANCE_LOW_MP_PENALTY

	if alive_target_count <= 1:
		chance -= CombatConstants.CAST_CHANCE_FEW_TARGETS_PENALTY

	return clampf(chance, 0.1, 0.9)


static func estimate_dice_average(dice_string: String) -> float:
	if not "d" in dice_string:
		return float(dice_string) if dice_string.is_valid_int() else 0.0

	var parts := dice_string.split("d")
	var num_dice := int(parts[0]) if parts[0] != "" else 1
	var remainder := parts[1]
	var die_size := 0
	var bonus := 0

	if "+" in remainder:
		var sub := remainder.split("+")
		die_size = int(sub[0])
		bonus = int(sub[1])
	elif remainder.count("-") > 0:
		var idx := remainder.find("-")
		die_size = int(remainder.substr(0, idx))
		bonus = -int(remainder.substr(idx + 1))
	else:
		die_size = int(remainder)

	return float(num_dice) * float(die_size + 1) / 2.0 + float(bonus)


static func weighted_random_pick(scored_items: Array) -> Variant:
	if scored_items.is_empty():
		return null

	var total := 0.0
	for entry in scored_items:
		total += entry.weight

	if total <= 0.0:
		return scored_items[0].item

	var roll := CombatRNG.randf() * total
	var cumulative := 0.0
	for entry in scored_items:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.item

	return scored_items[scored_items.size() - 1].item


static func _get_role_weight(member: Character) -> float:
	match member.character_class:
		CharacterEnums.CharacterClass.PRIEST, CharacterEnums.CharacterClass.BISHOP:
			return CombatConstants.THREAT_HEALER_WEIGHT
		CharacterEnums.CharacterClass.MAGE, CharacterEnums.CharacterClass.ALCHEMIST, CharacterEnums.CharacterClass.PSIONIC:
			return CombatConstants.THREAT_CASTER_WEIGHT
		CharacterEnums.CharacterClass.BARD:
			return CombatConstants.THREAT_SUPPORT_WEIGHT
		_:
			return CombatConstants.THREAT_FIGHTER_WEIGHT
