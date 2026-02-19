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
	var is_melee := decision.attack == null or decision.attack.weapon_range <= 1
	var target := _score_and_select_target(party, is_melee)
	decision.targets = [target] if target else []
	decision.message = "attack %s (threat: %.1f)" % [target.get_display_name() if target else "none", _last_target_score]
	return decision


static func _decide_berserker(monster: Monster, party: Party, _allies: Array[Monster]) -> AIDecision:
	var decision := AIDecision.new()
	decision.action_type = ActionType.ATTACK

	var best_attack: MonsterAttack = null
	var highest_damage := 0.0
	for attack in monster.attacks:
		var avg_damage := CombatEvaluator.estimate_dice_average(attack.damage_dice)
		if avg_damage > highest_damage:
			highest_damage = avg_damage
			best_attack = attack

	decision.attack = best_attack if best_attack else monster.get_random_attack()

	var is_melee := decision.attack == null or decision.attack.weapon_range <= 1
	var target := _score_and_select_target(party, is_melee)
	decision.targets = [target] if target else []
	decision.message = "berserker attack %s (threat: %.1f)" % [target.get_display_name() if target else "none", _last_target_score]
	return decision


static func _decide_defensive(monster: Monster, party: Party, _allies: Array[Monster]) -> AIDecision:
	var decision := AIDecision.new()

	var hp_percent := float(monster.current_hp) / float(monster.max_hp)
	if hp_percent < CombatConstants.DEFENSIVE_HP_THRESHOLD and CombatRNG.randf() < CombatConstants.DEFEND_CHANCE:
		decision.action_type = ActionType.DEFEND
		decision.message = "defend (hp: %d%%)" % int(hp_percent * 100)
		return decision

	decision.action_type = ActionType.ATTACK
	decision.attack = _select_best_attack(monster, party)
	var is_melee := decision.attack == null or decision.attack.weapon_range <= 1
	var target := _score_and_select_target(party, is_melee)
	decision.targets = [target] if target else []
	decision.message = "defensive attack %s (threat: %.1f)" % [target.get_display_name() if target else "none", _last_target_score]
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

	var is_melee := decision.attack == null or decision.attack.weapon_range <= 1
	var target := _score_and_select_target(party, is_melee)
	decision.targets = [target] if target else []
	decision.message = "ranged attack %s (threat: %.1f)" % [target.get_display_name() if target else "none", _last_target_score]
	return decision


static func _decide_spellcaster(monster: Monster, party: Party, allies: Array[Monster]) -> AIDecision:
	var decision := AIDecision.new()

	var alive_count := party.get_alive_members().size()
	var cast_chance := CombatEvaluator.calculate_adaptive_cast_chance(monster, alive_count)

	if monster.current_mp > 0 and not monster.spells.is_empty() and CombatRNG.randf() < cast_chance:
		var spell_result := _select_best_spell(monster, party, allies)
		if spell_result.id != "":
			var spell := SpellDatabase.get_spell(spell_result.id)
			if spell and monster.current_mp >= spell.mp_cost:
				decision.action_type = ActionType.SPELL
				decision.spell_id = spell_result.id
				decision.targets = _get_spell_targets_for_monster(spell, party, allies, monster)
				decision.message = "cast %s (score: %.1f, cast_chance: %d%%)" % [spell_result.id, spell_result.score, int(cast_chance * 100)]
				return decision

	decision.action_type = ActionType.ATTACK
	decision.attack = _select_best_attack(monster, party)
	var is_melee := decision.attack == null or decision.attack.weapon_range <= 1
	var target := _score_and_select_target(party, is_melee)
	decision.targets = [target] if target else []
	decision.message = "attack %s (cast_chance was %d%%, fell through)" % [target.get_display_name() if target else "none", int(cast_chance * 100)]
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
				decision.message = "heal %s with %s" % [wounded_ally.monster_name, spell_id]
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
					decision.message = "tactical %s on all (%d targets)" % [attack.attack_name, alive_party.size()]
				else:
					var front := party.get_front_row_alive()
					if front.size() >= 2:
						decision.targets = []
						for member in front:
							decision.targets.append(member)
						decision.message = "tactical %s on front row (%d targets)" % [attack.attack_name, front.size()]
					else:
						var target := _score_and_select_target(party, true)
						decision.targets = [target] if target else []
						decision.message = "tactical %s on %s (threat: %.1f)" % [attack.attack_name, target.get_display_name() if target else "none", _last_target_score]
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

		weighted_attacks.append({"item": attack, "weight": weight})

	return CombatEvaluator.weighted_random_pick(weighted_attacks)


static var _last_target_score: float = 0.0


static func _score_and_select_target(party: Party, is_melee: bool) -> Character:
	var front := party.get_front_row_alive()
	var back: Array[Character] = []
	for member in party.get_back_row():
		if not member.is_dead:
			back.append(member)

	var candidates: Array[Character] = []
	candidates.append_array(front)
	if not is_melee:
		candidates.append_array(back)
	elif front.is_empty():
		candidates.append_array(back)

	if candidates.is_empty():
		_last_target_score = 0.0
		return null

	var scored: Array = []
	for member in candidates:
		var score := CombatEvaluator.score_party_target(member, party, is_melee)
		scored.append({"item": member, "weight": score})

	var pick = CombatEvaluator.weighted_random_pick(scored)
	for entry in scored:
		if entry.item == pick:
			_last_target_score = entry.weight
			break

	return pick


static func _select_best_spell(monster: Monster, party: Party, allies: Array[Monster]) -> Dictionary:
	if monster.spells.is_empty():
		return {"id": "", "score": 0.0}

	var alive := party.get_alive_members()
	var alive_count := alive.size()
	var scored: Array = []

	for spell_id in monster.spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell == null or not spell.in_combat:
			continue
		if monster.current_mp < spell.mp_cost:
			continue

		var score := _score_spell(spell, alive, allies, monster, alive_count)
		if score > 0.0:
			scored.append({"item": {"id": spell_id, "score": score}, "weight": score})

	if scored.is_empty():
		return {"id": "", "score": 0.0}

	var pick = CombatEvaluator.weighted_random_pick(scored)
	return pick if pick else {"id": "", "score": 0.0}


static func _score_spell(spell: Spell, alive_party: Array[Character], allies: Array[Monster], caster: Monster, alive_count: int) -> float:
	var score := 0.0
	var is_aoe := spell.target_type == CharacterEnums.SpellTargetType.ALL_ENEMIES

	for effect in spell.effects:
		match effect.effect_type:
			SpellEffect.EffectType.DAMAGE:
				var avg := CombatEvaluator.estimate_dice_average(effect.damage_dice)
				avg += effect.damage_per_level * caster.level
				if is_aoe:
					score += avg * alive_count
				else:
					score += avg
			SpellEffect.EffectType.STATUS:
				var unaffected := 0
				for member in alive_party:
					if not member.has_status(effect.status_type):
						unaffected += 1
				if is_aoe:
					score += CombatConstants.SPELL_SCORE_STATUS_BASE * unaffected
				else:
					score += CombatConstants.SPELL_SCORE_STATUS_BASE if unaffected > 0 else 0.0
			SpellEffect.EffectType.HEAL:
				var wounded_count := 0
				for ally in allies:
					if not ally.is_dead:
						var hp_pct := float(ally.current_hp) / float(maxi(1, ally.max_hp))
						if hp_pct < CombatConstants.WOUNDED_ALLY_THRESHOLD:
							wounded_count += 1
				var avg_heal := CombatEvaluator.estimate_dice_average(effect.heal_dice)
				score += avg_heal * maxf(1.0, float(wounded_count))
			SpellEffect.EffectType.INSTANT_DEATH:
				var total_hp := 0.0
				for member in alive_party:
					total_hp += float(member.current_hp)
				score += total_hp / maxf(1.0, float(alive_count))

	if is_aoe and alive_count <= 1:
		score *= CombatConstants.SPELL_SCORE_AOE_PENALTY_SINGLE

	return score


static func _get_spell_targets_for_monster(spell: Spell, party: Party, allies: Array[Monster], caster: Monster) -> Array:
	match spell.target_type:
		CharacterEnums.SpellTargetType.SELF:
			return [caster]
		CharacterEnums.SpellTargetType.SINGLE_ALLY:
			if not allies.is_empty():
				return [allies[CombatRNG.randi() % allies.size()]]
			return [caster]
		CharacterEnums.SpellTargetType.SINGLE_ENEMY:
			var target := _score_and_select_target(party, false)
			return [target] if target else []
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
