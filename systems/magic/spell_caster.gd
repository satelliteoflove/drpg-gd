## Executes spell casting logic for both player characters and monsters.
class_name SpellCaster
extends RefCounted


## Casts a spell from a character to specified targets.
## [param caster]: The character casting the spell.
## [param spell]: The spell being cast.
## [param targets]: Array of valid targets (Character or Monster).
## [param in_combat]: Whether this is combat or exploration context.
## [return]: Dictionary with success, fizzled, messages, damage, healing, and mp_consumed.
static func cast_spell(
	caster: Character,
	spell: Spell,
	targets: Array,
	in_combat: bool = true
) -> Dictionary:
	var result := {
		"success": false,
		"fizzled": false,
		"messages": [] as Array[String],
		"total_damage": 0,
		"total_healing": 0,
		"mp_consumed": 0
	}

	var validation := SpellValidator.can_cast(caster, spell, in_combat)
	if not validation.can_cast:
		result.messages.append(validation.reason)
		return result

	caster.spend_mp(spell.mp_cost)
	result.mp_consumed = spell.mp_cost

	if SpellValidator.check_fizzle(caster, spell):
		result.fizzled = true
		result.messages.append("%s's %s fizzles!" % [caster.get_display_name(), spell.name])
		return result

	result.messages.append("%s casts %s!" % [caster.get_display_name(), spell.name])

	for effect in spell.effects:
		var effect_result := _process_effect(caster, spell, effect, targets)
		result.messages.append_array(effect_result.messages)
		result.total_damage += effect_result.get("damage", 0)
		result.total_healing += effect_result.get("healing", 0)

	result.success = true
	return result


static func _process_effect(
	caster: Character,
	_spell: Spell,
	effect: SpellEffect,
	targets: Array
) -> Dictionary:
	match effect.effect_type:
		SpellEffect.EffectType.DAMAGE:
			return _process_damage(caster, effect, targets)
		SpellEffect.EffectType.HEAL:
			return _process_healing(caster, effect, targets)
		SpellEffect.EffectType.STATUS:
			return _process_status(caster, effect, targets)
		SpellEffect.EffectType.CURE:
			return _process_cure(effect, targets)
		SpellEffect.EffectType.BUFF:
			return _process_buff(effect, targets)
		SpellEffect.EffectType.DEBUFF:
			return _process_debuff(caster, effect, targets)
		SpellEffect.EffectType.RESURRECTION:
			return _process_resurrection(effect, targets)
		SpellEffect.EffectType.INSTANT_DEATH:
			return _process_instant_death(caster, effect, targets)
		SpellEffect.EffectType.REVEAL_ENEMIES:
			return _process_reveal_enemies(effect)
		_:
			return {"messages": [], "damage": 0, "healing": 0}


static func _process_damage(
	caster: Character,
	effect: SpellEffect,
	targets: Array
) -> Dictionary:
	var result := {"messages": [] as Array[String], "damage": 0}

	var base_damage := DamageCalculator.roll_dice(effect.damage_dice)
	var level_bonus := effect.damage_per_level * caster.level
	var spell_power := _calculate_spell_power(caster)
	var total_base := int((base_damage + level_bonus) * spell_power / 100.0)

	for target in targets:
		if target.is_dead:
			continue

		var damage := maxi(1, total_base)

		var actual: int = target.take_damage(damage)
		result.damage += actual

		var element_name := CharacterEnums.get_element_name(effect.element)
		if target.is_dead:
			result.messages.append("%s takes %d %s damage and is defeated!" % [
				target.get_display_name(), actual, element_name
			])
		else:
			result.messages.append("%s takes %d %s damage." % [
				target.get_display_name(), actual, element_name
			])

	return result


static func _process_healing(
	caster: Character,
	effect: SpellEffect,
	targets: Array
) -> Dictionary:
	var result := {"messages": [] as Array[String], "healing": 0}

	for target in targets:
		if target.is_dead:
			result.messages.append("%s is dead and cannot be healed." % target.get_display_name())
			continue

		var healing: int
		if effect.full_heal:
			healing = target.max_hp - target.current_hp
		else:
			healing = DamageCalculator.roll_dice(effect.heal_dice)
			healing += effect.heal_per_level * caster.level
			var spell_power := _calculate_spell_power(caster)
			healing = int(healing * spell_power / 100.0)

		var actual: int = target.heal(healing)
		result.healing += actual
		result.messages.append("%s is healed for %d HP." % [target.get_display_name(), actual])

	return result


static func _process_status(
	caster: Character,
	effect: SpellEffect,
	targets: Array
) -> Dictionary:
	var result := {"messages": [] as Array[String]}

	var duration := -1
	if effect.duration_dice != "":
		duration = DamageCalculator.roll_dice(effect.duration_dice)

	var dc := 10 + effect.status_power + caster.level / 2
	var is_beneficial := effect.status_type in CharacterEnums.BENEFICIAL_STATUSES

	for target in targets:
		if target.is_dead:
			continue

		if not is_beneficial and StatusEffectSystem.roll_saving_throw(target, effect.save_type, dc):
			result.messages.append("%s resists %s!" % [target.get_display_name(), CharacterEnums.get_status_noun(effect.status_type)])
			continue

		var apply_result := StatusEffectSystem.apply_status(
			target,
			effect.status_type,
			duration,
			"spell",
			effect.status_power,
			is_beneficial
		)
		if apply_result.message != "":
			result.messages.append(apply_result.message)

	return result


static func _process_cure(
	effect: SpellEffect,
	targets: Array
) -> Dictionary:
	var result := {"messages": [] as Array[String]}

	for target in targets:
		if target.is_dead:
			continue

		var cure_messages := StatusEffectSystem.cure_status_group(target, effect.cure_group)
		if cure_messages.is_empty():
			result.messages.append("%s has no ailments to cure." % target.get_display_name())
		else:
			result.messages.append_array(cure_messages)

	return result


static func _process_buff(
	effect: SpellEffect,
	targets: Array
) -> Dictionary:
	var result := {"messages": [] as Array[String]}

	for target in targets:
		if target.is_dead:
			continue

		result.messages.append("%s gains +%d %s." % [
			target.get_display_name(),
			effect.buff_value,
			effect.buff_stat
		])

	return result


static func _process_debuff(
	caster: Character,
	effect: SpellEffect,
	targets: Array
) -> Dictionary:
	var result := {"messages": [] as Array[String]}

	var dc := 10 + caster.level / 2

	for target in targets:
		if target.is_dead:
			continue

		if StatusEffectSystem.roll_saving_throw(target, effect.save_type, dc):
			result.messages.append("%s resists!" % target.get_display_name())
			continue

		result.messages.append("%s suffers %d %s." % [
			target.get_display_name(),
			abs(effect.buff_value),
			effect.buff_stat
		])

	return result


static func _process_resurrection(
	effect: SpellEffect,
	targets: Array
) -> Dictionary:
	var result := {"messages": [] as Array[String]}

	for target in targets:
		if not target.is_dead:
			result.messages.append("%s is not dead." % target.get_display_name())
			continue

		if target.has_status(CharacterEnums.StatusEffect.ASHED):
			if CombatRNG.randf() > effect.resurrection_chance * 0.5:
				result.messages.append("Failed to resurrect %s from ashes!" % target.get_display_name())
				continue

		if target.has_status(CharacterEnums.StatusEffect.LOST):
			result.messages.append("%s is lost forever." % target.get_display_name())
			continue

		if CombatRNG.randf() > effect.resurrection_chance:
			result.messages.append("Failed to resurrect %s!" % target.get_display_name())
			continue

		if target.resurrect(1):
			target.current_hp = maxi(1, int(target.max_hp * effect.restore_hp_percent))
			result.messages.append("%s is resurrected!" % target.get_display_name())
		else:
			result.messages.append("Failed to resurrect %s!" % target.get_display_name())

	return result


static func _process_instant_death(
	caster: Character,
	effect: SpellEffect,
	targets: Array
) -> Dictionary:
	var result := {"messages": [] as Array[String]}

	var dc := 10 + caster.level / 2 + effect.death_save_modifier

	for target in targets:
		if target.is_dead:
			continue

		if StatusEffectSystem.roll_saving_throw(target, CharacterEnums.SaveType.DEATH, dc):
			result.messages.append("%s resists death!" % target.get_display_name())
			continue

		target.take_damage(target.current_hp + 100)
		result.messages.append("%s is slain instantly!" % target.get_display_name())

	return result


static func _process_reveal_enemies(effect: SpellEffect) -> Dictionary:
	var result := {"messages": [] as Array[String]}

	if GameState.floor_tracker != null:
		GameState.floor_tracker.activate_reveal(effect.reveal_duration)
		result.messages.append("All enemies on this floor are revealed for %d steps." % effect.reveal_duration)
	else:
		result.messages.append("No enemies to reveal.")

	return result


static func _calculate_spell_power(caster: Character) -> int:
	var base := CombatConstants.BASE_SPELL_POWER
	var level_bonus := caster.level * CombatConstants.SPELL_LEVEL_BONUS_MULTIPLIER
	var int_bonus := maxi(0, caster.intelligence - CombatConstants.BASE_STAT_VALUE) * CombatConstants.SPELL_INT_BONUS_MULTIPLIER

	var class_bonus := 0
	match caster.character_class:
		CharacterEnums.CharacterClass.MAGE, \
		CharacterEnums.CharacterClass.PRIEST, \
		CharacterEnums.CharacterClass.ALCHEMIST, \
		CharacterEnums.CharacterClass.PSIONIC:
			class_bonus = CombatConstants.PURE_CASTER_SPELL_BONUS
		CharacterEnums.CharacterClass.BISHOP, \
		CharacterEnums.CharacterClass.RANGER, \
		CharacterEnums.CharacterClass.BARD, \
		CharacterEnums.CharacterClass.LORD, \
		CharacterEnums.CharacterClass.VALKYRIE, \
		CharacterEnums.CharacterClass.MONK, \
		CharacterEnums.CharacterClass.SAMURAI:
			class_bonus = CombatConstants.HYBRID_CASTER_SPELL_BONUS

	return base + level_bonus + int_bonus + class_bonus


## Casts a spell from a monster to specified targets.
## [param caster]: The monster casting the spell.
## [param spell]: The spell being cast.
## [param targets]: Array of valid targets (Character or Monster).
## [return]: Dictionary with success, messages, damage, healing, and mp_consumed.
static func cast_spell_by_monster(
	caster: Monster,
	spell: Spell,
	targets: Array
) -> Dictionary:
	var result := {
		"success": false,
		"messages": [] as Array[String],
		"total_damage": 0,
		"total_healing": 0,
		"mp_consumed": 0,
		"statuses_applied": [] as Array[Dictionary],
	}

	if caster.current_mp < spell.mp_cost:
		result.messages.append("%s lacks the power to cast %s!" % [caster.monster_name, spell.name])
		return result

	caster.current_mp -= spell.mp_cost
	result.mp_consumed = spell.mp_cost

	result.messages.append("%s casts %s!" % [caster.monster_name, spell.name])

	for effect in spell.effects:
		var effect_result := _process_monster_effect(caster, spell, effect, targets)
		result.messages.append_array(effect_result.messages)
		result.total_damage += effect_result.get("damage", 0)
		result.total_healing += effect_result.get("healing", 0)
		var applied: Array = effect_result.get("statuses_applied", [])
		result.statuses_applied.append_array(applied)

	result.success = true
	return result


static func _process_monster_effect(
	caster: Monster,
	_spell: Spell,
	effect: SpellEffect,
	targets: Array
) -> Dictionary:
	match effect.effect_type:
		SpellEffect.EffectType.DAMAGE:
			return _process_monster_damage(caster, effect, targets)
		SpellEffect.EffectType.HEAL:
			return _process_monster_healing(caster, effect, targets)
		SpellEffect.EffectType.STATUS:
			return _process_monster_status(caster, effect, targets)
		SpellEffect.EffectType.INSTANT_DEATH:
			return _process_monster_instant_death(caster, effect, targets)
		_:
			return {"messages": [], "damage": 0, "healing": 0}


static func _process_monster_damage(
	caster: Monster,
	effect: SpellEffect,
	targets: Array
) -> Dictionary:
	var result := {"messages": [] as Array[String], "damage": 0}

	var base_damage := DamageCalculator.roll_dice(effect.damage_dice)
	var level_bonus := effect.damage_per_level * caster.level
	var spell_power := _calculate_monster_spell_power(caster)
	var total_base := int((base_damage + level_bonus) * spell_power / 100.0)

	for target in targets:
		if target.is_dead:
			continue

		var damage := maxi(1, total_base)

		var actual: int = target.take_damage(damage)
		result.damage += actual

		var element_name := CharacterEnums.get_element_name(effect.element)
		if target.is_dead:
			result.messages.append("%s takes %d %s damage and is defeated!" % [
				target.get_display_name(), actual, element_name
			])
		else:
			result.messages.append("%s takes %d %s damage." % [
				target.get_display_name(), actual, element_name
			])

	return result


static func _process_monster_healing(
	caster: Monster,
	effect: SpellEffect,
	targets: Array
) -> Dictionary:
	var result := {"messages": [] as Array[String], "healing": 0}

	for target in targets:
		if target.is_dead:
			continue

		var healing: int
		if effect.full_heal:
			healing = target.max_hp - target.current_hp
		else:
			healing = DamageCalculator.roll_dice(effect.heal_dice)
			healing += effect.heal_per_level * caster.level
			var spell_power := _calculate_monster_spell_power(caster)
			healing = int(healing * spell_power / 100.0)

		if target is Monster:
			var healed := mini(healing, target.max_hp - target.current_hp)
			target.current_hp += healed
			result.healing += healed
			result.messages.append("%s is healed for %d HP." % [target.monster_name, healed])
		elif target is Character:
			var actual: int = target.heal(healing)
			result.healing += actual
			result.messages.append("%s is healed for %d HP." % [target.get_display_name(), actual])

	return result


static func _process_monster_status(
	caster: Monster,
	effect: SpellEffect,
	targets: Array
) -> Dictionary:
	var result := {"messages": [] as Array[String], "statuses_applied": [] as Array[Dictionary]}

	var duration := -1
	if effect.duration_dice != "":
		duration = DamageCalculator.roll_dice(effect.duration_dice)

	var dc := 10 + effect.status_power + caster.level / 2
	var is_beneficial := effect.status_type in CharacterEnums.BENEFICIAL_STATUSES

	for target in targets:
		if target.is_dead:
			continue

		if not is_beneficial and StatusEffectSystem.roll_saving_throw(target, effect.save_type, dc):
			result.messages.append("%s resists %s!" % [target.get_display_name(), CharacterEnums.get_status_noun(effect.status_type)])
			continue

		var apply_result := StatusEffectSystem.apply_status(
			target,
			effect.status_type,
			duration,
			"monster_spell",
			effect.status_power,
			is_beneficial
		)
		if apply_result.message != "":
			result.messages.append(apply_result.message)
		if apply_result.get("success", false) and not is_beneficial:
			result.statuses_applied.append({
				"target": target.get_display_name(),
				"status": effect.status_type,
			})

	return result


static func _process_monster_instant_death(
	caster: Monster,
	effect: SpellEffect,
	targets: Array
) -> Dictionary:
	var result := {"messages": [] as Array[String]}

	var dc := 10 + caster.level / 2 + effect.death_save_modifier

	for target in targets:
		if target.is_dead:
			continue

		if StatusEffectSystem.roll_saving_throw(target, CharacterEnums.SaveType.DEATH, dc):
			result.messages.append("%s resists death!" % target.get_display_name())
			continue

		target.take_damage(target.current_hp + 100)
		result.messages.append("%s is slain instantly!" % target.get_display_name())

	return result


static func _calculate_monster_spell_power(caster: Monster) -> int:
	var base := CombatConstants.BASE_SPELL_POWER
	var level_bonus := caster.level * CombatConstants.SPELL_LEVEL_BONUS_MULTIPLIER
	var int_bonus := maxi(0, caster.intelligence - CombatConstants.BASE_STAT_VALUE) * CombatConstants.SPELL_INT_BONUS_MULTIPLIER
	return base + level_bonus + int_bonus
