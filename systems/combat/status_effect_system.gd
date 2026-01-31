class_name StatusEffectSystem
extends RefCounted

const CombatRNG = preload("res://autoload/combat_rng.gd")
const CharEnum = preload("res://resources/character_enums.gd")
const DamageCalculator = preload("res://systems/combat/damage_calculator.gd")

const RESISTANCE_CHANCE: float = 0.5


static func apply_status(
	target: Resource,
	status: CharEnum.StatusEffect,
	duration: int = -1,
	source: String = "",
	power: int = 0,
	ignore_resistance: bool = false
) -> Dictionary:
	var result := {
		"success": false,
		"resisted": false,
		"immune": false,
		"message": ""
	}

	if target.is_dead and status != CharEnum.StatusEffect.DEAD:
		result.message = "%s is dead." % target.get_display_name()
		return result

	if target.has_status(status):
		result.message = "%s already has %s." % [target.get_display_name(), CharEnum.get_status_name(status)]
		return result

	if not ignore_resistance:
		if _has_racial_immunity(target, status):
			result.immune = true
			result.message = "%s is immune to %s!" % [target.get_display_name(), CharEnum.get_status_name(status)]
			return result

		if _check_racial_resistance(target, status):
			result.resisted = true
			result.message = "%s resists %s!" % [target.get_display_name(), CharEnum.get_status_name(status)]
			return result

	var applied: bool = target.add_status(status, duration, source, power)
	if applied:
		result.success = true
		if duration > 0:
			result.message = "%s is %s for %d turns!" % [target.get_display_name(), CharEnum.get_status_name(status).to_lower(), duration]
		else:
			result.message = "%s is %s!" % [target.get_display_name(), CharEnum.get_status_name(status).to_lower()]
	else:
		result.message = "%s was not affected." % target.get_display_name()

	return result


static func remove_status(target: Resource, status: CharEnum.StatusEffect) -> String:
	if not target.has_status(status):
		return ""

	target.remove_status(status)
	return "%s is no longer %s." % [target.get_display_name(), CharEnum.get_status_name(status).to_lower()]


static func tick_effects(target: Resource, context: String = "combat") -> Array[String]:
	var messages: Array[String] = []

	if target.is_dead:
		return messages

	var statuses_to_remove: Array[CharEnum.StatusEffect] = []

	for active in target.active_statuses:
		var tick_result := _process_status_tick(target, active, context)
		if tick_result != "":
			messages.append(tick_result)

		if _check_natural_recovery(target, active.type):
			statuses_to_remove.append(active.type)
			messages.append("%s recovered from %s!" % [target.get_display_name(), CharEnum.get_status_name(active.type).to_lower()])
		elif active.tick():
			statuses_to_remove.append(active.type)
			messages.append("%s's %s wore off." % [target.get_display_name(), CharEnum.get_status_name(active.type).to_lower()])

	for status in statuses_to_remove:
		target.remove_status(status)

	return messages


static func _process_status_tick(target: Resource, active: Character.ActiveStatus, context: String) -> String:
	match active.type:
		CharEnum.StatusEffect.POISONED:
			var damage: int = DamageCalculator.roll_dice("1d4")
			damage = maxi(1, damage)
			var actual: int = target.take_damage(damage)
			if target.is_dead:
				return "%s takes %d poison damage and dies!" % [target.get_display_name(), actual]
			return "%s takes %d poison damage." % [target.get_display_name(), actual]

		CharEnum.StatusEffect.AFRAID:
			if target.current_mp > 0:
				target.current_mp = maxi(0, target.current_mp - 1)
				return "%s loses 1 MP from fear." % target.get_display_name()

		CharEnum.StatusEffect.CURSED:
			if context == "exploration":
				var damage: int = DamageCalculator.roll_dice("1d2")
				damage = maxi(1, damage)
				var actual: int = target.take_damage(damage)
				return "%s takes %d curse damage." % [target.get_display_name(), actual]

	return ""


static func _check_natural_recovery(target: Resource, status: CharEnum.StatusEffect) -> bool:
	var recovery_chance := 0.0

	match status:
		CharEnum.StatusEffect.CONFUSED:
			recovery_chance = 0.15
		CharEnum.StatusEffect.SILENCED:
			recovery_chance = minf(0.6, 0.20 + target.level * 0.02)
		CharEnum.StatusEffect.BLINDED:
			recovery_chance = 0.10
		CharEnum.StatusEffect.AFRAID:
			recovery_chance = 0.10 + target.level * 0.01

	if recovery_chance > 0:
		return CombatRNG.randf() < recovery_chance

	return false


static func is_disabled(target: Resource) -> bool:
	return target.is_disabled()


static func roll_saving_throw(
	target: Resource,
	save_type: CharEnum.SaveType,
	dc: int,
	power_modifier: int = 0
) -> bool:
	var roll: int = CombatRNG.randi_range(1, 20)
	var bonus: int = _get_save_bonus(target, save_type)
	var luck_bonus: int = (target.luck - 10) / 4
	var total: int = roll + bonus + luck_bonus

	var actual_dc := dc + power_modifier

	return total >= actual_dc


static func _get_save_bonus(target: Resource, save_type: CharEnum.SaveType) -> int:
	var level_bonus: int = target.level / 2

	match save_type:
		CharEnum.SaveType.PHYSICAL:
			return level_bonus + (target.vitality - 10) / 4
		CharEnum.SaveType.MENTAL:
			return level_bonus + (target.intelligence - 10) / 4
		CharEnum.SaveType.MAGICAL:
			return level_bonus + (target.piety - 10) / 4
		CharEnum.SaveType.DEATH:
			return level_bonus + (target.luck - 10) / 4

	return level_bonus


static func _has_racial_immunity(target: Resource, status: CharEnum.StatusEffect) -> bool:
	return CharEnum.has_racial_immunity(target.race, status)


static func _check_racial_resistance(target: Resource, status: CharEnum.StatusEffect) -> bool:
	var immunities: Array = CharEnum.RACIAL_IMMUNITIES.get(target.race, [])
	if status in immunities:
		return true

	return false


static func get_status_for_display(target: Resource) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for active in target.active_statuses:
		if active.type == CharEnum.StatusEffect.NONE:
			continue

		result.append({
			"type": active.type,
			"name": CharEnum.get_status_name(active.type),
			"abbreviation": CharEnum.get_status_abbreviation(active.type),
			"duration": active.duration,
			"is_permanent": active.is_permanent()
		})

	return result


static func cure_status_group(target: Resource, group: String) -> Array[String]:
	var messages: Array[String] = []
	var to_cure: Array[CharEnum.StatusEffect] = []

	match group:
		"poison":
			to_cure = [CharEnum.StatusEffect.POISONED]
		"paralysis":
			to_cure = [CharEnum.StatusEffect.PARALYZED]
		"petrification":
			to_cure = [CharEnum.StatusEffect.STONED]
		"mental":
			to_cure = [
				CharEnum.StatusEffect.ASLEEP,
				CharEnum.StatusEffect.CONFUSED,
				CharEnum.StatusEffect.AFRAID,
				CharEnum.StatusEffect.CHARMED,
				CharEnum.StatusEffect.BERSERK
			]
		"blindness":
			to_cure = [CharEnum.StatusEffect.BLINDED]
		"silence":
			to_cure = [CharEnum.StatusEffect.SILENCED]
		"curse":
			to_cure = [CharEnum.StatusEffect.CURSED]
		"all":
			to_cure = [
				CharEnum.StatusEffect.POISONED,
				CharEnum.StatusEffect.PARALYZED,
				CharEnum.StatusEffect.ASLEEP,
				CharEnum.StatusEffect.CONFUSED,
				CharEnum.StatusEffect.SILENCED,
				CharEnum.StatusEffect.BLINDED,
				CharEnum.StatusEffect.AFRAID,
				CharEnum.StatusEffect.CHARMED,
				CharEnum.StatusEffect.BERSERK,
				CharEnum.StatusEffect.CURSED
			]

	for status in to_cure:
		if target.has_status(status):
			var msg := remove_status(target, status)
			if msg != "":
				messages.append(msg)

	return messages


static func wake_on_damage(target: Resource) -> String:
	if target.has_status(CharEnum.StatusEffect.ASLEEP):
		target.remove_status(CharEnum.StatusEffect.ASLEEP)
		return "%s wakes up!" % target.get_display_name()
	return ""


static func get_accuracy_modifier(target: Resource) -> int:
	var modifier := 0

	if target.has_status(CharEnum.StatusEffect.BLINDED):
		modifier -= 4

	if target.has_status(CharEnum.StatusEffect.BLESSED):
		modifier += 2

	if target.has_status(CharEnum.StatusEffect.CURSED):
		modifier -= 2

	return modifier


static func get_evasion_modifier(target: Resource) -> int:
	var modifier := 0

	if target.has_status(CharEnum.StatusEffect.BLESSED):
		modifier += 2

	if target.has_status(CharEnum.StatusEffect.CURSED):
		modifier -= 2

	return modifier


static func should_attack_allies(target: Resource) -> bool:
	return target.has_status(CharEnum.StatusEffect.CHARMED)


static func should_attack_randomly(target: Resource) -> bool:
	return target.has_status(CharEnum.StatusEffect.BERSERK)


static func may_skip_turn_from_fear(target: Resource) -> bool:
	if target.has_status(CharEnum.StatusEffect.AFRAID):
		return CombatRNG.randf() < 0.3
	return false


static func get_damage_multiplier_for_sleeping(target: Resource) -> float:
	if target.has_status(CharEnum.StatusEffect.ASLEEP):
		return 2.0
	return 1.0
