class_name PartyAI
extends RefCounted

const CombatRNG = preload("res://autoload/combat_rng.gd")
const CharEnum = preload("res://resources/character_enums.gd")
const SpellDatabase = preload("res://data/spells/spell_database.gd")
const SpellEffect = preload("res://resources/spell_effect.gd")
const ClassDataRef = preload("res://resources/class_data.gd")
const DispelUndead = preload("res://systems/combat/dispel_undead.gd")

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
		CharEnum.CharacterClass.PRIEST, CharEnum.CharacterClass.BISHOP:
			return "healer"
		CharEnum.CharacterClass.MAGE, CharEnum.CharacterClass.ALCHEMIST, CharEnum.CharacterClass.PSIONIC:
			return "caster"
		CharEnum.CharacterClass.BARD:
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

	var wounded := _find_wounded_ally(party, 0.5)
	if wounded and character.current_mp > 0:
		var heal_spell := _find_healing_spell(character)
		if heal_spell:
			return {
				"action": "spell",
				"target": wounded,
				"spell_id": heal_spell,
				"reasoning": "heal wounded ally"
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

	var status_target := _find_ally_with_curable_status(party)
	if status_target and character.current_mp > 0:
		var cure_spell := _find_cure_spell(character, status_target)
		if cure_spell:
			return {
				"action": "spell",
				"target": status_target,
				"spell_id": cure_spell,
				"reasoning": "cure status effect"
			}

	var should_cast_offensive := strategy == Strategy.AGGRESSIVE or mp_percent > cast_threshold
	if should_cast_offensive and character.current_mp > 0:
		var damage_spell := _find_damage_spell(character)
		if damage_spell:
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
	_party: Party,
	enemies: Array[Monster],
	strategy: Strategy,
	cast_threshold: float
) -> Dictionary:
	var mp_percent := float(character.current_mp) / float(maxi(1, character.max_mp))

	if mp_percent > cast_threshold or strategy == Strategy.AGGRESSIVE:
		var aoe_spell := _find_aoe_spell(character)
		var living_enemies := _count_living(enemies)
		if aoe_spell and living_enemies >= 2:
			return {
				"action": "spell",
				"target": enemies,
				"spell_id": aoe_spell,
				"reasoning": "aoe damage"
			}

		var damage_spell := _find_damage_spell(character)
		if damage_spell:
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

	var wounded := _find_wounded_ally(party, 0.4)
	if wounded and character.current_mp > 0:
		var heal_spell := _find_healing_spell(character)
		if heal_spell:
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
	_character: Character,
	_party: Party,
	enemies: Array[Monster],
	strategy: Strategy
) -> Dictionary:
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

	match strategy:
		Strategy.AGGRESSIVE:
			return _select_weakest_enemy(living)
		Strategy.DEFENSIVE:
			return _select_most_dangerous_enemy(living)
		_:
			return living[CombatRNG.randi() % living.size()]


static func _select_weakest_enemy(enemies: Array[Monster]) -> Monster:
	var weakest: Monster = enemies[0]
	for enemy in enemies:
		if enemy.current_hp < weakest.current_hp:
			weakest = enemy
	return weakest


static func _select_most_dangerous_enemy(enemies: Array[Monster]) -> Monster:
	var dangerous: Monster = enemies[0]
	var highest_threat := 0
	for enemy in enemies:
		var threat := enemy.strength + enemy.max_mp * 2
		if threat > highest_threat:
			highest_threat = threat
			dangerous = enemy
	return dangerous


static func _find_wounded_ally(party: Party, threshold: float) -> Character:
	var most_wounded: Character = null
	var lowest_percent := threshold

	for member in party.get_alive_members():
		var hp_percent := float(member.current_hp) / float(maxi(1, member.max_hp))
		if hp_percent < lowest_percent:
			lowest_percent = hp_percent
			most_wounded = member

	return most_wounded


static func _find_ally_with_curable_status(party: Party) -> Character:
	var curable := [
		CharEnum.StatusEffect.POISONED,
		CharEnum.StatusEffect.PARALYZED,
		CharEnum.StatusEffect.BLINDED,
		CharEnum.StatusEffect.SILENCED,
		CharEnum.StatusEffect.CONFUSED
	]

	for member in party.get_alive_members():
		for status in curable:
			if member.has_status(status):
				return member

	return null


static func _find_buff_target(party: Party) -> Character:
	var members := party.get_alive_members()
	if members.is_empty():
		return null
	return members[CombatRNG.randi() % members.size()]


static func _find_healing_spell(character: Character) -> String:
	for spell_id in character.known_spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell == null or not spell.in_combat:
			continue
		if character.current_mp < spell.mp_cost:
			continue
		for effect in spell.effects:
			if effect.effect_type == SpellEffect.EffectType.HEAL:
				return spell_id
	return ""


static func _find_cure_spell(character: Character, _target: Character) -> String:
	for spell_id in character.known_spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell == null or not spell.in_combat:
			continue
		if character.current_mp < spell.mp_cost:
			continue
		for effect in spell.effects:
			if effect.effect_type == SpellEffect.EffectType.CURE:
				return spell_id
	return ""


static func _find_damage_spell(character: Character) -> String:
	for spell_id in character.known_spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell == null or not spell.in_combat:
			continue
		if character.current_mp < spell.mp_cost:
			continue
		if spell.target_type == CharEnum.SpellTargetType.SINGLE_ENEMY:
			for effect in spell.effects:
				if effect.effect_type == SpellEffect.EffectType.DAMAGE:
					return spell_id
	return ""


static func _find_aoe_spell(character: Character) -> String:
	for spell_id in character.known_spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell == null or not spell.in_combat:
			continue
		if character.current_mp < spell.mp_cost:
			continue
		if spell.target_type == CharEnum.SpellTargetType.ALL_ENEMIES:
			for effect in spell.effects:
				if effect.effect_type == SpellEffect.EffectType.DAMAGE:
					return spell_id
	return ""


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
