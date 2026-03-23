class_name PartyAI
extends RefCounted

enum Strategy { AGGRESSIVE, DEFENSIVE, BALANCED }

const DEFAULT_CAST_THRESHOLD := 0.2


static func decide_action(
	character: Character,
	party: Party,
	enemies: Array[Monster],
	strategy: Strategy = Strategy.BALANCED,
	cast_threshold: float = DEFAULT_CAST_THRESHOLD
) -> Dictionary:
	if character.is_dead or character.is_disabled():
		return {"action": "skip", "target": null, "spell_id": ""}

	var item_action := _check_emergency_item_use(character, party)
	if not item_action.is_empty():
		return item_action

	var role := _determine_role(character)

	match role:
		"healer":
			return _decide_healer_action(character, party, enemies, strategy, cast_threshold)
		"caster":
			return _decide_caster_action(character, party, enemies, strategy, cast_threshold)
		"support":
			return _decide_support_action(character, party, enemies, strategy, cast_threshold)
		_:
			return _decide_fighter_action(character, party, enemies, strategy)


static func _determine_role(character: Character) -> String:
	match character.character_class:
		CharacterEnums.CharacterClass.PRIEST, CharacterEnums.CharacterClass.BISHOP:
			return "healer"
		CharacterEnums.CharacterClass.MAGE, CharacterEnums.CharacterClass.ALCHEMIST, CharacterEnums.CharacterClass.PSIONIC:
			return "caster"
		CharacterEnums.CharacterClass.BARD:
			return "support"
		_:
			return "fighter"


static func _decide_healer_action(
	character: Character,
	party: Party,
	enemies: Array[Monster],
	strategy: Strategy,
	cast_threshold: float
) -> Dictionary:
	var mp_percent := float(character.current_mp) / float(maxi(1, character.max_mp))

	var emergency := _find_wounded_ally(party, CombatConstants.PARTY_EMERGENCY_HEAL_THRESHOLD)
	if emergency and character.current_mp > 0:
		var heal_spell := _find_best_healing_spell(character)
		if heal_spell != "":
			return {
				"action": "spell",
				"target": emergency,
				"spell_id": heal_spell,
				"reasoning": "emergency heal %s" % emergency.get_display_name()
			}

	var controlled_ally := _find_mentally_controlled_ally(party)
	if controlled_ally and character.current_mp > 0:
		var cure_spell := _find_cure_spell(character, controlled_ally)
		if cure_spell != "":
			return {
				"action": "spell",
				"target": controlled_ally,
				"spell_id": cure_spell,
				"reasoning": "cure mentally controlled ally (%s)" % controlled_ally.get_display_name()
			}

	var disabled_ally := _find_disabled_ally(party)
	if disabled_ally and character.current_mp > 0:
		var cure_spell := _find_cure_spell(character, disabled_ally)
		if cure_spell != "":
			return {
				"action": "spell",
				"target": disabled_ally,
				"spell_id": cure_spell,
				"reasoning": "cure disabled ally (%s)" % disabled_ally.get_display_name()
			}

	var wounded := _find_wounded_ally(party, 0.5)
	if wounded and character.current_mp > 0:
		var heal_spell := _find_best_healing_spell(character)
		if heal_spell != "":
			return {
				"action": "spell",
				"target": wounded,
				"spell_id": heal_spell,
				"reasoning": "heal wounded ally"
			}

	var afflicted_ally := _find_afflicted_ally(party)
	if afflicted_ally and character.current_mp > 0:
		var cure_spell := _find_cure_spell(character, afflicted_ally)
		if cure_spell != "":
			return {
				"action": "spell",
				"target": afflicted_ally,
				"spell_id": cure_spell,
				"reasoning": "cure affliction on %s" % afflicted_ally.get_display_name()
			}

	var party_health := _get_party_health_percent(party)
	if DispelUndead.can_dispel(character):
		if DispelUndead.should_attempt_dispel(character, enemies, party_health):
			var dispel_target := DispelUndead.select_best_target(character, enemies)
			if dispel_target:
				return {
					"action": "dispel",
					"target": dispel_target,
					"spell_id": "",
					"reasoning": "dispel undead"
				}

	var should_cast_offensive := strategy == Strategy.AGGRESSIVE or mp_percent > cast_threshold
	if should_cast_offensive and character.current_mp > 0:
		var damage_spell := _find_best_damage_spell(character)
		if damage_spell != "":
			var spell_target := _select_attack_target(enemies, strategy)
			if spell_target:
				return {
					"action": "spell",
					"target": spell_target,
					"spell_id": damage_spell,
					"reasoning": "offensive spell"
				}

	var target := _select_attack_target(enemies, strategy)
	if target:
		return {"action": "attack", "target": target, "spell_id": "", "reasoning": "basic attack"}

	return {"action": "defend", "target": null, "spell_id": "", "reasoning": "no valid action"}


static func _decide_caster_action(
	character: Character,
	party: Party,
	enemies: Array[Monster],
	strategy: Strategy,
	cast_threshold: float
) -> Dictionary:
	var mp_percent := float(character.current_mp) / float(maxi(1, character.max_mp))

	if character.character_class == CharacterEnums.CharacterClass.PSIONIC and character.current_mp > 0:
		var ward_action := _check_preemptive_mind_ward(character, party, enemies)
		if not ward_action.is_empty():
			return ward_action

	if mp_percent > cast_threshold or strategy == Strategy.AGGRESSIVE:
		var living_enemies := _count_living(enemies)
		if living_enemies >= 2:
			var aoe_spell := _find_best_aoe_spell(character)
			if aoe_spell != "":
				return {
					"action": "spell",
					"target": enemies,
					"spell_id": aoe_spell,
					"reasoning": "aoe damage"
				}

		var damage_spell := _find_best_damage_spell(character)
		if damage_spell != "":
			var spell_target := _select_attack_target(enemies, strategy)
			if spell_target:
				return {
					"action": "spell",
					"target": spell_target,
					"spell_id": damage_spell,
					"reasoning": "single target damage"
				}

	var target := _select_attack_target(enemies, strategy)
	if target:
		return {"action": "attack", "target": target, "spell_id": "", "reasoning": "conserving MP"}

	return {"action": "defend", "target": null, "spell_id": "", "reasoning": "no valid action"}


static func _decide_support_action(
	character: Character,
	party: Party,
	enemies: Array[Monster],
	strategy: Strategy,
	cast_threshold: float
) -> Dictionary:
	var mp_percent := float(character.current_mp) / float(maxi(1, character.max_mp))

	var emergency := _find_wounded_ally(party, CombatConstants.PARTY_EMERGENCY_HEAL_THRESHOLD)
	if emergency and character.current_mp > 0:
		var heal_spell := _find_best_healing_spell(character)
		if heal_spell != "":
			return {
				"action": "spell",
				"target": emergency,
				"spell_id": heal_spell,
				"reasoning": "emergency heal %s" % emergency.get_display_name()
			}

	var wounded := _find_wounded_ally(party, 0.4)
	if wounded and character.current_mp > 0:
		var heal_spell := _find_best_healing_spell(character)
		if heal_spell != "":
			return {
				"action": "spell",
				"target": wounded,
				"spell_id": heal_spell,
				"reasoning": "heal wounded ally"
			}

	var should_use_mp := mp_percent > cast_threshold or strategy == Strategy.AGGRESSIVE
	if should_use_mp and character.current_mp > 0:
		var buff_spell := _find_buff_spell(character)
		if buff_spell:
			var buff_target := _find_buff_target(party)
			if buff_target:
				return {
					"action": "spell",
					"target": buff_target,
					"spell_id": buff_spell,
					"reasoning": "buff ally"
				}

	var target := _select_attack_target(enemies, strategy)
	if target:
		return {"action": "attack", "target": target, "spell_id": "", "reasoning": "basic attack"}

	return {"action": "defend", "target": null, "spell_id": "", "reasoning": "no valid action"}


static func _decide_fighter_action(
	character: Character,
	_party: Party,
	enemies: Array[Monster],
	strategy: Strategy
) -> Dictionary:
	var hp_percent := float(character.current_hp) / float(maxi(1, character.max_hp))
	if hp_percent <= CombatConstants.FIGHTER_DEFEND_HP_THRESHOLD and CombatRNG.randf() < 0.5:
		return {"action": "defend", "target": null, "spell_id": "", "reasoning": "low HP defend"}

	var target := _select_attack_target(enemies, strategy)
	if target:
		return {"action": "attack", "target": target, "spell_id": "", "reasoning": "attack enemy"}

	return {"action": "defend", "target": null, "spell_id": "", "reasoning": "no enemies"}


static func _select_attack_target(enemies: Array[Monster], strategy: Strategy) -> Monster:
	var living: Array[Monster] = []
	for enemy in enemies:
		if not enemy.is_dead:
			living.append(enemy)

	if living.is_empty():
		return null

	var scored: Array = []
	for enemy in living:
		var score := CombatEvaluator.score_monster_target(enemy, living)
		match strategy:
			Strategy.AGGRESSIVE:
				var hp_pct := float(enemy.current_hp) / float(maxi(1, enemy.max_hp))
				score += CombatConstants.FOCUS_FIRE_WOUNDED_BONUS * (1.0 - hp_pct)
			Strategy.DEFENSIVE:
				var threat := float(enemy.strength) + float(enemy.max_mp) * 2.0
				score += threat
		if _monster_has_heal_spell(enemy):
			score += CombatConstants.THREAT_HEALER_WEIGHT
		scored.append({"item": enemy, "weight": score})

	return CombatEvaluator.weighted_random_pick(scored)


static func _find_wounded_ally(party: Party, threshold: float) -> Character:
	var most_wounded: Character = null
	var lowest_percent := threshold

	for member in party.get_alive_members():
		var hp_percent := float(member.current_hp) / float(maxi(1, member.max_hp))
		if hp_percent < lowest_percent:
			lowest_percent = hp_percent
			most_wounded = member

	return most_wounded


static func _find_disabled_ally(party: Party) -> Character:
	var disabling := [
		CharacterEnums.StatusEffect.PARALYZED,
		CharacterEnums.StatusEffect.ASLEEP,
	]
	for member in party.get_alive_members():
		for status in disabling:
			if member.has_status(status):
				return member
	return null


static func _find_mentally_controlled_ally(party: Party) -> Character:
	var best: Character = null
	var best_urgency := 0.0

	for member in party.get_alive_members():
		var urgency := 0.0
		if member.has_status(CharacterEnums.StatusEffect.CHARMED):
			urgency = 10.0 + member.strength
		elif member.has_status(CharacterEnums.StatusEffect.CONFUSED):
			urgency = 5.0 + member.strength * 0.5

		if urgency > best_urgency:
			best_urgency = urgency
			best = member

	return best


static func _find_silenced_healer(party: Party) -> Character:
	for member in party.get_alive_members():
		if member.has_status(CharacterEnums.StatusEffect.SILENCED):
			if member.character_class in [CharacterEnums.CharacterClass.PRIEST, CharacterEnums.CharacterClass.BISHOP]:
				return member
	return null


static func _find_afflicted_ally(party: Party) -> Character:
	var afflictions := [
		CharacterEnums.StatusEffect.POISONED,
		CharacterEnums.StatusEffect.CONFUSED,
		CharacterEnums.StatusEffect.CHARMED,
		CharacterEnums.StatusEffect.SILENCED,
		CharacterEnums.StatusEffect.BLINDED,
	]
	for member in party.get_alive_members():
		for status in afflictions:
			if member.has_status(status):
				return member
	return null


static func _find_buff_target(party: Party) -> Character:
	var members := party.get_alive_members()
	if members.is_empty():
		return null
	return members[CombatRNG.randi() % members.size()]


static func _find_best_healing_spell(character: Character) -> String:
	var best_id := ""
	var best_avg := 0.0

	for spell_id in character.known_spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell == null or not spell.in_combat:
			continue
		if character.current_mp < spell.mp_cost:
			continue
		for effect in spell.effects:
			if effect.effect_type == SpellEffect.EffectType.HEAL:
				var avg := CombatEvaluator.estimate_dice_average(effect.heal_dice)
				avg += effect.heal_per_level * character.level
				if avg > best_avg:
					best_avg = avg
					best_id = spell_id
				break

	return best_id


static func _find_cure_spell(character: Character, target: Character) -> String:
	for spell_id in character.known_spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell == null or not spell.in_combat:
			continue
		if character.current_mp < spell.mp_cost:
			continue
		for effect in spell.effects:
			if effect.effect_type == SpellEffect.EffectType.CURE:
				if _cure_matches_target(effect.cure_group, target):
					return spell_id
	return ""


static func _cure_matches_target(cure_group: String, target: Character) -> bool:
	match cure_group:
		"poison":
			return target.has_status(CharacterEnums.StatusEffect.POISONED)
		"paralysis":
			return target.has_status(CharacterEnums.StatusEffect.PARALYZED)
		"mental":
			return target.has_status(CharacterEnums.StatusEffect.ASLEEP) or \
				target.has_status(CharacterEnums.StatusEffect.CONFUSED) or \
				target.has_status(CharacterEnums.StatusEffect.AFRAID) or \
				target.has_status(CharacterEnums.StatusEffect.CHARMED)
		"blindness":
			return target.has_status(CharacterEnums.StatusEffect.BLINDED)
		"silence":
			return target.has_status(CharacterEnums.StatusEffect.SILENCED)
		"all":
			for status in [
				CharacterEnums.StatusEffect.POISONED,
				CharacterEnums.StatusEffect.PARALYZED,
				CharacterEnums.StatusEffect.ASLEEP,
				CharacterEnums.StatusEffect.CONFUSED,
				CharacterEnums.StatusEffect.AFRAID,
				CharacterEnums.StatusEffect.SILENCED,
				CharacterEnums.StatusEffect.BLINDED,
				CharacterEnums.StatusEffect.CURSED,
			]:
				if target.has_status(status):
					return true
	return false


static func _find_best_damage_spell(character: Character) -> String:
	var best_id := ""
	var best_avg := 0.0

	for spell_id in character.known_spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell == null or not spell.in_combat:
			continue
		if character.current_mp < spell.mp_cost:
			continue
		if spell.target_type != CharacterEnums.SpellTargetType.SINGLE_ENEMY:
			continue
		for effect in spell.effects:
			if effect.effect_type == SpellEffect.EffectType.DAMAGE:
				var avg := CombatEvaluator.estimate_dice_average(effect.damage_dice)
				avg += effect.damage_per_level * character.level
				if avg > best_avg:
					best_avg = avg
					best_id = spell_id
				break

	return best_id


static func _find_best_aoe_spell(character: Character) -> String:
	var best_id := ""
	var best_avg := 0.0

	for spell_id in character.known_spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell == null or not spell.in_combat:
			continue
		if character.current_mp < spell.mp_cost:
			continue
		if spell.target_type != CharacterEnums.SpellTargetType.ALL_ENEMIES:
			continue
		for effect in spell.effects:
			if effect.effect_type == SpellEffect.EffectType.DAMAGE:
				var avg := CombatEvaluator.estimate_dice_average(effect.damage_dice)
				avg += effect.damage_per_level * character.level
				if avg > best_avg:
					best_avg = avg
					best_id = spell_id
				break

	return best_id


static func _find_buff_spell(character: Character) -> String:
	for spell_id in character.known_spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell == null or not spell.in_combat:
			continue
		if character.current_mp < spell.mp_cost:
			continue
		for effect in spell.effects:
			if effect.effect_type == SpellEffect.EffectType.BUFF:
				return spell_id
	return ""


static func _count_living(enemies: Array[Monster]) -> int:
	var count := 0
	for enemy in enemies:
		if not enemy.is_dead:
			count += 1
	return count


static func _get_party_health_percent(party: Party) -> float:
	var total_hp := 0
	var current_hp := 0
	for member in party.get_members():
		total_hp += member.max_hp
		if not member.is_dead:
			current_hp += member.current_hp
	if total_hp == 0:
		return 0.0
	return float(current_hp) / float(total_hp)


static func _check_emergency_item_use(character: Character, party: Party) -> Dictionary:
	var controlled := _find_mentally_controlled_ally(party)
	if controlled != null:
		var item := _find_cure_item(party, controlled)
		if item != null:
			return {
				"action": "item",
				"target": controlled,
				"item": item,
				"spell_id": "",
				"reasoning": "use %s on %s" % [item.item_name, controlled.get_display_name()]
			}

	var silenced_healer := _find_silenced_healer(party)
	if silenced_healer != null and silenced_healer != character:
		var item := _find_cure_item(party, silenced_healer)
		if item != null:
			return {
				"action": "item",
				"target": silenced_healer,
				"item": item,
				"spell_id": "",
				"reasoning": "use %s on silenced %s" % [item.item_name, silenced_healer.get_display_name()]
			}

	return {}


static func _check_preemptive_mind_ward(character: Character, party: Party, enemies: Array[Monster]) -> Dictionary:
	if not character.known_spells.has("s2_mind_ward"):
		return {}

	var spell := SpellDatabase.get_spell("s2_mind_ward")
	if spell == null or character.current_mp < spell.mp_cost:
		return {}

	var has_mental_threat := false
	for enemy in enemies:
		if enemy.is_dead:
			continue
		for attack in enemy.attacks:
			if attack.effect_type in [CharacterEnums.StatusEffect.CONFUSED, CharacterEnums.StatusEffect.CHARMED, CharacterEnums.StatusEffect.AFRAID]:
				if attack.effect_save_type == "mental":
					has_mental_threat = true
					break
		if has_mental_threat:
			break
		for spell_id in enemy.spells:
			var enemy_spell := SpellDatabase.get_spell(spell_id)
			if enemy_spell:
				for effect in enemy_spell.effects:
					if effect.effect_type == SpellEffect.EffectType.STATUS:
						if effect.status_type in [CharacterEnums.StatusEffect.CONFUSED, CharacterEnums.StatusEffect.CHARMED, CharacterEnums.StatusEffect.AFRAID]:
							has_mental_threat = true
							break
			if has_mental_threat:
				break

	if not has_mental_threat:
		return {}

	var ward_target: Character = null
	for member in party.get_alive_members():
		if member.has_status(CharacterEnums.StatusEffect.MIND_WARDED):
			continue
		if member.character_class in [CharacterEnums.CharacterClass.PRIEST, CharacterEnums.CharacterClass.BISHOP]:
			ward_target = member
			break

	if ward_target == null:
		for member in party.get_alive_members():
			if member == character:
				continue
			if not member.has_status(CharacterEnums.StatusEffect.MIND_WARDED):
				ward_target = member
				break

	if ward_target == null:
		return {}

	return {
		"action": "spell",
		"target": ward_target,
		"spell_id": "s2_mind_ward",
		"reasoning": "preemptive Mind Ward on %s" % ward_target.get_display_name()
	}


static func _monster_has_heal_spell(monster: Monster) -> bool:
	for spell_id in monster.spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell == null:
			continue
		for effect in spell.effects:
			if effect.effect_type == SpellEffect.EffectType.HEAL:
				return true
	return false


static func _find_cure_item(party: Party, target: Character) -> Item:
	if party.inventory == null:
		return null

	for item in party.inventory.get_all_items():
		if item.cures_status.is_empty():
			continue
		for status in item.cures_status:
			if target.has_status(status):
				return item

	return null
