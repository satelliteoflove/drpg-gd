class_name MonsterAI
extends RefCounted

enum AIBehavior {
	AGGRESSIVE,
	DEFENSIVE,
	SPELLCASTER,
	SUPPORT,
	RANGED,
	BERSERKER,
	TACTICAL
}

enum ActionType {
	ATTACK,
	SPELL,
	DEFEND,
	FLEE
}


class AIDecision:
	var action_type: ActionType = ActionType.ATTACK
	var attack: MonsterAttack = null
	var spell_id: String = ""
	var targets: Array = []
	var message: String = ""


static func decide_action(monster: Monster, party: Party, allies: Array[Monster], _log: RefCounted = null) -> AIDecision:
	var behavior := _get_behavior(monster)

	match behavior:
		AIBehavior.SPELLCASTER:
			return _decide_spellcaster(monster, party, allies)
		AIBehavior.SUPPORT:
			return _decide_support(monster, party, allies)
		AIBehavior.DEFENSIVE:
			return _decide_defensive(monster, party, allies)
		AIBehavior.BERSERKER:
			return _decide_berserker(monster, party, allies)
		AIBehavior.RANGED:
			return _decide_ranged(monster, party, allies)
		AIBehavior.TACTICAL:
			return _decide_tactical(monster, party, allies)
		_:
			return _decide_aggressive(monster, party, allies)


static func _get_behavior(monster: Monster) -> AIBehavior:
	if monster.max_mp > 0 and not monster.spells.is_empty():
		return AIBehavior.SPELLCASTER

	var has_ranged := false
	for attack in monster.attacks:
		if attack.weapon_range > 1:
			has_ranged = true
			break

	if has_ranged and monster.agility > monster.strength:
		return AIBehavior.RANGED

	if monster.strength >= CombatConstants.BERSERKER_STRENGTH_THRESHOLD:
		return AIBehavior.BERSERKER

	if monster.defense >= 6 or monster.vitality >= 14:
		return AIBehavior.DEFENSIVE

	return AIBehavior.AGGRESSIVE


static func _decide_aggressive(monster: Monster, party: Party, _allies: Array[Monster]) -> AIDecision:
	var decision := AIDecision.new()
	decision.action_type = ActionType.ATTACK
	decision.attack = _select_best_attack(monster, party)
	decision.targets = [_select_target(monster, party, decision.attack)]
	return decision


static func _decide_berserker(monster: Monster, party: Party, _allies: Array[Monster]) -> AIDecision:
	var decision := AIDecision.new()
	decision.action_type = ActionType.ATTACK

	var best_attack: MonsterAttack = null
	var highest_damage := 0
	for attack in monster.attacks:
		var avg_damage := _estimate_attack_damage(attack)
		if avg_damage > highest_damage:
			highest_damage = avg_damage
			best_attack = attack

	decision.attack = best_attack if best_attack else monster.get_random_attack()

	var target := _select_weakest_target(party)
	decision.targets = [target] if target else []
	return decision


static func _decide_defensive(monster: Monster, party: Party, _allies: Array[Monster]) -> AIDecision:
	var decision := AIDecision.new()

	var hp_percent := float(monster.current_hp) / float(monster.max_hp)
	if hp_percent < CombatConstants.DEFENSIVE_HP_THRESHOLD and CombatRNG.randf() < CombatConstants.DEFEND_CHANCE:
		decision.action_type = ActionType.DEFEND
		return decision

	decision.action_type = ActionType.ATTACK
	decision.attack = _select_best_attack(monster, party)
	decision.targets = [_select_target(monster, party, decision.attack)]
	return decision


static func _decide_ranged(monster: Monster, party: Party, _allies: Array[Monster]) -> AIDecision:
	var decision := AIDecision.new()
	decision.action_type = ActionType.ATTACK

	var ranged_attacks: Array[MonsterAttack] = []
	for attack in monster.attacks:
		if attack.weapon_range > 1:
			ranged_attacks.append(attack)

	if not ranged_attacks.is_empty():
		decision.attack = ranged_attacks[CombatRNG.randi() % ranged_attacks.size()]
	else:
		decision.attack = monster.get_random_attack()

	var target := _select_caster_target(party)
	if target == null:
		target = _select_target(monster, party, decision.attack)
	decision.targets = [target] if target else []
	return decision


static func _decide_spellcaster(monster: Monster, party: Party, allies: Array[Monster]) -> AIDecision:
	var decision := AIDecision.new()

	if monster.current_mp > 0 and not monster.spells.is_empty() and CombatRNG.randf() < CombatConstants.SPELLCASTER_CAST_CHANCE:
		var spell_id := _select_spell(monster, party, allies)
		if spell_id != "":
			var spell := SpellDatabase.get_spell(spell_id)
			if spell and monster.current_mp >= spell.mp_cost:
				decision.action_type = ActionType.SPELL
				decision.spell_id = spell_id
				decision.targets = _get_spell_targets_for_monster(spell, party, allies, monster)
				return decision

	decision.action_type = ActionType.ATTACK
	decision.attack = _select_best_attack(monster, party)
	decision.targets = [_select_target(monster, party, decision.attack)]
	return decision


static func _decide_support(monster: Monster, party: Party, allies: Array[Monster]) -> AIDecision:
	var decision := AIDecision.new()

	var wounded_ally := _find_wounded_ally(allies, monster)
	if wounded_ally and monster.current_mp > 0:
		for spell_id in monster.spells:
			var spell := SpellDatabase.get_spell(spell_id)
			if spell and _is_healing_spell(spell) and monster.current_mp >= spell.mp_cost:
				decision.action_type = ActionType.SPELL
				decision.spell_id = spell_id
				decision.targets = [wounded_ally]
				return decision

	return _decide_spellcaster(monster, party, allies)


static func _decide_tactical(monster: Monster, party: Party, allies: Array[Monster]) -> AIDecision:
	var decision := AIDecision.new()

	var alive_party := party.get_alive_members()
	if alive_party.size() >= 3:
		for attack in monster.attacks:
			if attack.targets_row or attack.targets_all:
				decision.action_type = ActionType.ATTACK
				decision.attack = attack
				if attack.targets_all:
					decision.targets = []
					for member in alive_party:
						decision.targets.append(member)
				else:
					var front := party.get_front_row_alive()
					if front.size() >= 2:
						decision.targets = []
						for member in front:
							decision.targets.append(member)
					else:
						decision.targets = [_select_target(monster, party, attack)]
				return decision

	return _decide_aggressive(monster, party, allies)


static func _select_best_attack(monster: Monster, party: Party) -> MonsterAttack:
	if monster.attacks.is_empty():
		return null

	var alive := party.get_alive_members()
	var weighted_attacks: Array = []

	for attack in monster.attacks:
		var weight := 10.0

		if attack.effect_type != CharacterEnums.StatusEffect.NONE:
			var any_affected := false
			for member in alive:
				if member.has_status(attack.effect_type):
					any_affected = true
					break
			if not any_affected:
				weight += 5.0

		if attack.targets_row and party.get_front_row_alive().size() >= 2:
			weight += 8.0

		if attack.targets_all and alive.size() >= 3:
			weight += 12.0

		weighted_attacks.append({"attack": attack, "weight": weight})

	var total_weight := 0.0
	for wa in weighted_attacks:
		total_weight += wa.weight

	var roll := CombatRNG.randf() * total_weight
	var cumulative := 0.0
	for wa in weighted_attacks:
		cumulative += wa.weight
		if roll <= cumulative:
			return wa.attack

	return monster.attacks[0]


static func _select_target(_monster: Monster, party: Party, attack: MonsterAttack) -> Character:
	var front := party.get_front_row_alive()
	var back: Array[Character] = []
	for member in party.get_back_row():
		if not member.is_dead:
			back.append(member)

	var can_reach_back := attack != null and attack.weapon_range > 1

	var available: Array[Character] = []
	if not front.is_empty():
		available = front
	elif can_reach_back and not back.is_empty():
		available = back
	elif not back.is_empty():
		available = back

	if available.is_empty():
		return null

	return available[CombatRNG.randi() % available.size()]


static func _select_weakest_target(party: Party) -> Character:
	var alive := party.get_alive_members()
	if alive.is_empty():
		return null

	var weakest: Character = alive[0]
	for member in alive:
		if member.current_hp < weakest.current_hp:
			weakest = member

	return weakest


static func _select_caster_target(party: Party) -> Character:
	var alive := party.get_alive_members()
	var casters: Array[Character] = []

	for member in alive:
		if member.max_mp > 0:
			casters.append(member)

	if casters.is_empty():
		return null

	return casters[CombatRNG.randi() % casters.size()]


static func _select_spell(monster: Monster, party: Party, _allies: Array[Monster]) -> String:
	if monster.spells.is_empty():
		return ""

	var alive_count := party.get_alive_members().size()
	var valid_spells: Array[String] = []

	for spell_id in monster.spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell == null or not spell.in_combat:
			continue
		if monster.current_mp < spell.mp_cost:
			continue

		if spell.target_type == CharacterEnums.SpellTargetType.ALL_ENEMIES and alive_count >= 2:
			return spell_id

		valid_spells.append(spell_id)

	if valid_spells.is_empty():
		return ""

	return valid_spells[CombatRNG.randi() % valid_spells.size()]


static func _get_spell_targets_for_monster(spell: Spell, party: Party, allies: Array[Monster], caster: Monster) -> Array:
	match spell.target_type:
		CharacterEnums.SpellTargetType.SELF:
			return [caster]
		CharacterEnums.SpellTargetType.SINGLE_ALLY:
			if not allies.is_empty():
				return [allies[CombatRNG.randi() % allies.size()]]
			return [caster]
		CharacterEnums.SpellTargetType.SINGLE_ENEMY:
			var alive := party.get_alive_members()
			if not alive.is_empty():
				return [alive[CombatRNG.randi() % alive.size()]]
			return []
		CharacterEnums.SpellTargetType.ALL_ALLIES:
			var result: Array = []
			for ally in allies:
				if not ally.is_dead:
					result.append(ally)
			return result
		CharacterEnums.SpellTargetType.ALL_ENEMIES:
			var result: Array = []
			for member in party.get_alive_members():
				result.append(member)
			return result
		_:
			return []


static func _find_wounded_ally(allies: Array[Monster], exclude: Monster) -> Monster:
	var wounded: Monster = null
	var lowest_percent := CombatConstants.WOUNDED_ALLY_THRESHOLD

	for ally in allies:
		if ally == exclude or ally.is_dead:
			continue
		var hp_percent := float(ally.current_hp) / float(ally.max_hp)
		if hp_percent < lowest_percent:
			lowest_percent = hp_percent
			wounded = ally

	return wounded


static func _is_healing_spell(spell: Spell) -> bool:
	for effect in spell.effects:
		if effect.effect_type == SpellEffect.EffectType.HEAL:
			return true
	return false


static func _estimate_attack_damage(attack: MonsterAttack) -> int:
	var dice := attack.damage_dice
	var avg := 0

	if "d" in dice:
		var parts := dice.split("d")
		var num_dice := int(parts[0]) if parts[0] != "" else 1
		var die_size := 0
		var bonus := 0

		if "+" in parts[1]:
			var sub_parts := parts[1].split("+")
			die_size = int(sub_parts[0])
			bonus = int(sub_parts[1])
		elif "-" in parts[1]:
			var sub_parts := parts[1].split("-")
			die_size = int(sub_parts[0])
			bonus = -int(sub_parts[1])
		else:
			die_size = int(parts[1])

		avg = num_dice * (die_size + 1) / 2 + bonus

	return avg
