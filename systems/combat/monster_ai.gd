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
	var behavior: AIBehavior = AIBehavior.AGGRESSIVE
	var fumbled: bool = false


static var _round_applied_statuses: Dictionary = {}
static var _silence_cooldowns: Dictionary = {}
static var _last_initiative_tick: float = -1.0


static func reset_round_state() -> void:
	_round_applied_statuses.clear()


static func notify_turn_start(initiative_tick: float) -> void:
	if initiative_tick < _last_initiative_tick:
		_round_applied_statuses.clear()
		tick_silence_cooldowns()
	_last_initiative_tick = initiative_tick


static func record_status_applied(monster_name: String, target_id: String, status: CharacterEnums.StatusEffect) -> void:
	var key := "%s_%d" % [target_id, status]
	_round_applied_statuses[key] = monster_name


static func _was_status_applied_this_round(target_id: String, status: CharacterEnums.StatusEffect, by_species: String, monster: Monster) -> bool:
	var key := "%s_%d" % [target_id, status]
	if not _round_applied_statuses.has(key):
		return false
	if CombatRNG.randf() > CombatConstants.COORDINATION_CHANCE:
		return false
	var applier: String = _round_applied_statuses[key]
	return applier == monster.monster_name or applier == by_species


static func _check_silence_cooldown(target_id: String) -> bool:
	if not _silence_cooldowns.has(target_id):
		return false
	return _silence_cooldowns[target_id] > 0


static func _record_silence_attempt(target_id: String) -> void:
	_silence_cooldowns[target_id] = CombatConstants.SILENCE_RETRY_COOLDOWN


static func tick_silence_cooldowns() -> void:
	var to_remove: Array[String] = []
	for key in _silence_cooldowns:
		_silence_cooldowns[key] -= 1
		if _silence_cooldowns[key] <= 0:
			to_remove.append(key)
	for key in to_remove:
		_silence_cooldowns.erase(key)


static func decide_action(monster: Monster, party: Party, allies: Array[Monster], _log: RefCounted = null) -> AIDecision:
	var floor_num := _get_current_floor()
	var fumble_chance: float = CombatConstants.AI_FUMBLE_CHANCE.get(floor_num, 0.0)
	if fumble_chance > 0.0 and CombatRNG.randf() < fumble_chance:
		var decision := _decide_fumble(monster, party)
		decision.fumbled = true
		return decision

	var behavior := _select_behavior(monster, party, allies)

	var decision: AIDecision
	match behavior:
		AIBehavior.SPELLCASTER:
			decision = _decide_spellcaster(monster, party, allies)
		AIBehavior.SUPPORT:
			decision = _decide_support(monster, party, allies)
		AIBehavior.DEFENSIVE:
			decision = _decide_defensive(monster, party, allies)
		AIBehavior.BERSERKER:
			decision = _decide_berserker(monster, party, allies)
		AIBehavior.RANGED:
			decision = _decide_ranged(monster, party, allies)
		AIBehavior.TACTICAL:
			decision = _decide_tactical(monster, party, allies)
		_:
			decision = _decide_aggressive(monster, party, allies)
	decision.behavior = behavior
	return decision


static func _get_current_floor() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("GameState"):
		return GameState.current_floor
	return 99


static func _select_behavior(monster: Monster, party: Party, allies: Array[Monster]) -> AIBehavior:
	var scores: Array = []
	var hp_percent := float(monster.current_hp) / float(maxi(1, monster.max_hp))
	var alive_count := party.get_alive_members().size()

	scores.append({"item": AIBehavior.AGGRESSIVE, "weight": 10.0})

	if monster.max_mp > 0 and not monster.spells.is_empty() and monster.current_mp > 0:
		scores.append({"item": AIBehavior.SPELLCASTER, "weight": CombatConstants.BEHAVIOR_SPELLCASTER_WEIGHT})

	if monster.max_mp > 0 and not monster.spells.is_empty():
		var has_heal := false
		for spell_id in monster.spells:
			var spell := SpellDatabase.get_spell(spell_id)
			if spell and _is_healing_spell(spell):
				has_heal = true
				break
		if has_heal and _has_living_allies(allies, monster):
			var support_weight := CombatConstants.BEHAVIOR_SUPPORT_WEIGHT * 0.5
			var wounded_ally := _find_wounded_ally(allies, monster)
			if wounded_ally != null:
				support_weight = CombatConstants.BEHAVIOR_SUPPORT_WEIGHT
				var w_hp_pct := float(wounded_ally.current_hp) / float(maxi(1, wounded_ally.max_hp))
				if w_hp_pct < CombatConstants.DEFENSIVE_HP_THRESHOLD:
					support_weight *= 1.5
			scores.append({"item": AIBehavior.SUPPORT, "weight": support_weight})

	if monster.strength >= CombatConstants.BERSERKER_STRENGTH_THRESHOLD:
		var weight := CombatConstants.BEHAVIOR_BERSERKER_WEIGHT
		if hp_percent < CombatConstants.DEFENSIVE_HP_THRESHOLD:
			weight += CombatConstants.BEHAVIOR_LOW_HP_AGGRO_PENALTY
		scores.append({"item": AIBehavior.BERSERKER, "weight": maxf(1.0, weight)})
		scores[0].weight += CombatConstants.BEHAVIOR_AGGRESSIVE_BONUS

	if monster.defense >= 6 or monster.vitality >= 14:
		var weight := CombatConstants.BEHAVIOR_DEFENSIVE_WEIGHT
		if hp_percent < CombatConstants.DEFENSIVE_HP_THRESHOLD:
			weight += CombatConstants.BEHAVIOR_LOW_HP_DEFENSIVE_BONUS
		scores.append({"item": AIBehavior.DEFENSIVE, "weight": weight})

	var has_ranged := false
	for attack in monster.attacks:
		if attack.weapon_range > 1:
			has_ranged = true
			break
	if has_ranged:
		scores.append({"item": AIBehavior.RANGED, "weight": CombatConstants.BEHAVIOR_RANGED_WEIGHT})

	var has_aoe := false
	for attack in monster.attacks:
		if attack.targets_row or attack.targets_all:
			has_aoe = true
			break
	if has_aoe and alive_count >= 3:
		var weight := CombatConstants.BEHAVIOR_TACTICAL_WEIGHT
		if monster.is_boss:
			weight += CombatConstants.BEHAVIOR_BOSS_TACTICAL_BONUS
		scores.append({"item": AIBehavior.TACTICAL, "weight": weight})

	if hp_percent < CombatConstants.DEFENSIVE_HP_THRESHOLD:
		for entry in scores:
			if entry.item == AIBehavior.AGGRESSIVE:
				entry.weight = maxf(1.0, entry.weight + CombatConstants.BEHAVIOR_LOW_HP_AGGRO_PENALTY)

	var phase_mods := get_phase_behavior_modifiers(monster)
	if not phase_mods.is_empty():
		for entry in scores:
			var key: String = _behavior_to_key(entry.item)
			if phase_mods.has(key):
				entry.weight = maxf(1.0, entry.weight + float(phase_mods[key]))

	return CombatEvaluator.weighted_random_pick(scores)


static func _behavior_to_key(behavior: AIBehavior) -> String:
	match behavior:
		AIBehavior.AGGRESSIVE: return "aggressive"
		AIBehavior.DEFENSIVE: return "defensive"
		AIBehavior.SPELLCASTER: return "spellcaster"
		AIBehavior.SUPPORT: return "support"
		AIBehavior.RANGED: return "ranged"
		AIBehavior.BERSERKER: return "berserker"
		AIBehavior.TACTICAL: return "tactical"
	return ""


static func _decide_fumble(monster: Monster, party: Party) -> AIDecision:
	var decision := AIDecision.new()
	decision.action_type = ActionType.ATTACK
	decision.attack = monster.get_random_attack()
	var front := party.get_front_row_alive()
	if front.is_empty():
		front = party.get_alive_members()
	if front.is_empty():
		decision.targets = []
	else:
		decision.targets = [front[CombatRNG.randi() % front.size()]]
	decision.message = "fumble attack"
	return decision


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

	decision.attack = _select_best_attack(monster, party, 3.0)

	if decision.attack == null:
		decision.attack = monster.get_random_attack()

	var is_melee := decision.attack == null or decision.attack.weapon_range <= 1
	var target := _score_and_select_target(party, is_melee)
	decision.targets = [target] if target else []
	decision.message = "berserker attack %s (threat: %.1f)" % [target.get_display_name() if target else "none", _last_target_score]
	return decision


static func _decide_defensive(monster: Monster, party: Party, allies: Array[Monster]) -> AIDecision:
	var decision := AIDecision.new()

	var hp_percent := float(monster.current_hp) / float(monster.max_hp)
	if hp_percent < CombatConstants.DEFENSIVE_HP_THRESHOLD:
		var has_healer_ally := _has_healer_ally(allies, monster)
		if has_healer_ally and CombatRNG.randf() < CombatConstants.DEFEND_CHANCE:
			decision.action_type = ActionType.DEFEND
			decision.message = "defend with healer backup (hp: %d%%)" % int(hp_percent * 100)
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
				var is_silence := _spell_applies_silence(spell)
				if is_silence and not decision.targets.is_empty() and decision.targets[0] is Character:
					_record_silence_attempt(decision.targets[0].id)
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

	if monster.current_mp > 0:
		var heal_spell_id := _find_heal_spell(monster)
		if heal_spell_id != "":
			var defending_wounded := _find_defending_wounded_ally(allies, monster)
			if defending_wounded != null:
				var spell := SpellDatabase.get_spell(heal_spell_id)
				if spell and monster.current_mp >= spell.mp_cost:
					decision.action_type = ActionType.SPELL
					decision.spell_id = heal_spell_id
					decision.targets = [defending_wounded]
					decision.message = "heal defending %s with %s" % [defending_wounded.monster_name, heal_spell_id]
					return decision

			var wounded_ally := _find_wounded_ally(allies, monster)
			if wounded_ally != null:
				var spell := SpellDatabase.get_spell(heal_spell_id)
				if spell and monster.current_mp >= spell.mp_cost:
					decision.action_type = ActionType.SPELL
					decision.spell_id = heal_spell_id
					decision.targets = [wounded_ally]
					decision.message = "heal %s with %s" % [wounded_ally.monster_name, heal_spell_id]
					return decision

		var buff_spell_id := _find_buff_spell(monster, allies)
		if buff_spell_id != "":
			var spell := SpellDatabase.get_spell(buff_spell_id)
			if spell and monster.current_mp >= spell.mp_cost:
				decision.action_type = ActionType.SPELL
				decision.spell_id = buff_spell_id
				decision.targets = _get_spell_targets_for_monster(spell, party, allies, monster)
				decision.message = "support buff %s" % buff_spell_id
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


static func _select_best_attack(monster: Monster, party: Party, damage_bias: float = 1.0) -> MonsterAttack:
	if monster.attacks.is_empty():
		return null

	var alive := party.get_alive_members()
	var alive_count := alive.size()
	var weighted_attacks: Array = []
	var phase_prefs := get_phase_attack_preferences(monster)
	var preferred_attacks: Array = phase_prefs.get("prefer", [])
	var avoided_attacks: Array = phase_prefs.get("avoid", [])

	for attack in monster.attacks:
		var weight := 10.0

		var avg_damage := CombatEvaluator.estimate_dice_average(attack.damage_dice)
		weight += avg_damage * damage_bias

		if attack.effect_type != CharacterEnums.StatusEffect.NONE:
			var unaffected := 0
			for member in alive:
				if not member.has_status(attack.effect_type):
					unaffected += 1
			if unaffected > 0:
				var fraction := float(unaffected) / float(maxi(1, alive_count))
				weight += 15.0 * fraction * attack.effect_chance

		if attack.attack_name in preferred_attacks:
			weight *= 2.0
		if attack.attack_name in avoided_attacks:
			weight *= 0.2

		if attack.targets_row and party.get_front_row_alive().size() >= 2:
			weight += 8.0

		if attack.targets_all and alive_count >= 3:
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
	var is_status_spell := false
	var is_damage_spell := false

	var healthy_count := 0
	for member in alive_party:
		var hp_pct := float(member.current_hp) / float(maxi(1, member.max_hp))
		if hp_pct > 0.5:
			healthy_count += 1
	var healthy_fraction := float(healthy_count) / float(maxi(1, alive_count))

	for effect in spell.effects:
		match effect.effect_type:
			SpellEffect.EffectType.DAMAGE:
				is_damage_spell = true
				var avg := CombatEvaluator.estimate_dice_average(effect.damage_dice)
				avg += effect.damage_per_level * caster.level
				if is_aoe:
					score += avg * alive_count
				else:
					score += avg
			SpellEffect.EffectType.STATUS:
				is_status_spell = true
				var unaffected := 0
				for member in alive_party:
					if not member.has_status(effect.status_type):
						unaffected += 1
				if is_aoe:
					score += CombatConstants.SPELL_SCORE_STATUS_BASE * unaffected
				else:
					score += CombatConstants.SPELL_SCORE_STATUS_BASE if unaffected > 0 else 0.0

				if effect.status_type == CharacterEnums.StatusEffect.SILENCED:
					var has_healer_target := false
					for member in alive_party:
						if not member.has_status(CharacterEnums.StatusEffect.SILENCED):
							if member.character_class in [CharacterEnums.CharacterClass.PRIEST, CharacterEnums.CharacterClass.BISHOP]:
								if not _check_silence_cooldown(member.id):
									has_healer_target = true
									break
					if has_healer_target:
						score += CombatConstants.SILENCE_HEALER_BONUS
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

	if is_status_spell and not is_damage_spell:
		if healthy_fraction >= CombatConstants.SPELL_SEQUENCE_STATUS_THRESHOLD:
			score *= 1.3
		elif healthy_fraction < CombatConstants.SPELL_SEQUENCE_DAMAGE_THRESHOLD:
			score *= 0.5
	elif is_damage_spell and not is_status_spell:
		if healthy_fraction < CombatConstants.SPELL_SEQUENCE_DAMAGE_THRESHOLD:
			score *= 1.3
		elif healthy_fraction >= CombatConstants.SPELL_SEQUENCE_STATUS_THRESHOLD:
			score *= 0.8

	return score


static func _get_spell_targets_for_monster(spell: Spell, party: Party, allies: Array[Monster], caster: Monster) -> Array:
	match spell.target_type:
		CharacterEnums.SpellTargetType.SELF:
			return [caster]
		CharacterEnums.SpellTargetType.SINGLE_ALLY:
			var best := _pick_best_ally_target(spell, allies, caster)
			return [best] if best else [caster]
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


static func _spell_applies_silence(spell: Spell) -> bool:
	for effect in spell.effects:
		if effect.effect_type == SpellEffect.EffectType.STATUS and effect.status_type == CharacterEnums.StatusEffect.SILENCED:
			return true
	return false


static func check_boss_phase(monster: Monster) -> Array[String]:
	var messages: Array[String] = []
	if monster.boss_phases.is_empty():
		return messages

	monster._phase_turn_count += 1
	var hp_pct := float(monster.current_hp) / float(maxi(1, monster.max_hp))

	var next_phase := monster.current_phase + 1
	if next_phase >= monster.boss_phases.size():
		return messages

	var phase_data: Dictionary = monster.boss_phases[next_phase]
	var threshold: float = phase_data.get("hp_threshold", 0.0)
	var min_turns: int = phase_data.get("min_turns", 0)
	var warn_threshold: float = threshold + 0.10

	if not monster._phase_warned and hp_pct <= warn_threshold and hp_pct > threshold:
		var warn_msg: String = phase_data.get("warning_message", "")
		if warn_msg != "":
			monster._phase_warned = true
			messages.append(warn_msg)

	if hp_pct <= threshold and monster._phase_turn_count >= min_turns:
		monster.current_phase = next_phase
		monster._phase_turn_count = 0
		monster._phase_warned = false
		var transition_msg: String = phase_data.get("transition_message", "")
		if transition_msg != "":
			messages.append(transition_msg)

		var on_transition_spell: String = phase_data.get("on_transition_spell", "")
		if on_transition_spell != "":
			messages.append("__cast_spell:" + on_transition_spell)

	return messages


static func get_phase_attack_preferences(monster: Monster) -> Dictionary:
	if monster.boss_phases.is_empty() or monster.current_phase >= monster.boss_phases.size():
		return {}
	return monster.boss_phases[monster.current_phase].get("attack_preferences", {})


static func get_phase_behavior_modifiers(monster: Monster) -> Dictionary:
	if monster.boss_phases.is_empty() or monster.current_phase >= monster.boss_phases.size():
		return {}
	return monster.boss_phases[monster.current_phase].get("behavior_modifiers", {})


static func _has_living_allies(allies: Array[Monster], exclude: Monster) -> bool:
	for ally in allies:
		if ally != exclude and not ally.is_dead:
			return true
	return false


static func _has_healer_ally(allies: Array[Monster], exclude: Monster) -> bool:
	for ally in allies:
		if ally == exclude or ally.is_dead:
			continue
		for spell_id in ally.spells:
			var spell := SpellDatabase.get_spell(spell_id)
			if spell and _is_healing_spell(spell) and ally.current_mp >= spell.mp_cost:
				return true
	return false


static func _find_defending_wounded_ally(allies: Array[Monster], exclude: Monster) -> Monster:
	var best: Monster = null
	var lowest_pct := 1.0
	for ally in allies:
		if ally == exclude or ally.is_dead or not ally.is_defending:
			continue
		var hp_pct := float(ally.current_hp) / float(maxi(1, ally.max_hp))
		if hp_pct < CombatConstants.WOUNDED_ALLY_THRESHOLD and hp_pct < lowest_pct:
			lowest_pct = hp_pct
			best = ally
	return best


static func _find_buff_spell(monster: Monster, allies: Array[Monster]) -> String:
	for spell_id in monster.spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell == null or monster.current_mp < spell.mp_cost:
			continue
		for effect in spell.effects:
			if effect.effect_type == SpellEffect.EffectType.STATUS and effect.status_type in CharacterEnums.BENEFICIAL_STATUSES:
				var has_unbuffed := false
				for ally in allies:
					if not ally.is_dead and not ally.has_status(effect.status_type):
						has_unbuffed = true
						break
				if has_unbuffed:
					return spell_id
	return ""


static func _find_heal_spell(monster: Monster) -> String:
	for spell_id in monster.spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell and _is_healing_spell(spell) and monster.current_mp >= spell.mp_cost:
			return spell_id
	return ""


static func _pick_best_ally_target(spell: Spell, allies: Array[Monster], caster: Monster) -> Monster:
	var is_heal := _is_healing_spell(spell)
	var is_buff := false
	for effect in spell.effects:
		if effect.effect_type == SpellEffect.EffectType.STATUS and effect.status_type in CharacterEnums.BENEFICIAL_STATUSES:
			is_buff = true
			break

	var alive_allies: Array[Monster] = []
	for ally in allies:
		if not ally.is_dead:
			alive_allies.append(ally)
	if alive_allies.is_empty():
		return caster

	if is_heal:
		var most_wounded: Monster = null
		var lowest_pct := 1.0
		for ally in alive_allies:
			var hp_pct := float(ally.current_hp) / float(maxi(1, ally.max_hp))
			if ally.is_defending and hp_pct < CombatConstants.WOUNDED_ALLY_THRESHOLD:
				return ally
			if hp_pct < lowest_pct:
				lowest_pct = hp_pct
				most_wounded = ally
		return most_wounded if most_wounded else alive_allies[0]

	if is_buff:
		var strongest: Monster = null
		var highest_str := 0
		for ally in alive_allies:
			if ally.strength > highest_str:
				highest_str = ally.strength
				strongest = ally
		return strongest if strongest else alive_allies[0]

	return alive_allies[CombatRNG.randi() % alive_allies.size()]
