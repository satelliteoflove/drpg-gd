## Manages application, removal, and effects of status conditions on combatants.
class_name StatusEffectSystem
extends RefCounted


## Attempts to apply a status effect to a target.
## [param target]: Character or Monster to affect.
## [param status]: The status effect to apply.
## [param duration]: Turns until expiry (-1 for permanent).
## [param source]: Source identifier for tracking.
## [param power]: Effect strength for certain statuses.
## [param ignore_resistance]: If true, bypasses racial immunity/resistance checks.
## [return]: Dictionary with success, resisted, immune, and message fields.
static func apply_status(
	target: Resource,
	status: CharacterEnums.StatusEffect,
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

	if target.is_dead and status != CharacterEnums.StatusEffect.DEAD:
		result.message = "%s is dead." % target.get_display_name()
		return result

	if target.has_status(status):
		result.message = "%s already has %s." % [target.get_display_name(), CharacterEnums.get_status_name(status)]
		return result

	if not ignore_resistance:
		if _check_racial_resistance(target, status):
			result.resisted = true
			result.message = "%s resists %s!" % [target.get_display_name(), CharacterEnums.get_status_noun(status)]
			return result

	var applied: bool = target.add_status(status, duration, source, power)
	if applied:
		result.success = true
		if duration > 0:
			result.message = "%s is %s for %d turns!" % [target.get_display_name(), CharacterEnums.get_status_name(status).to_lower(), duration]
		else:
			result.message = "%s is %s!" % [target.get_display_name(), CharacterEnums.get_status_name(status).to_lower()]
	else:
		result.message = "%s was not affected." % target.get_display_name()

	return result


## Removes a status effect from the target.
## [param target]: Character or Monster to cure.
## [param status]: The status effect to remove.
## [return]: Message describing the removal, or empty string if not present.
static func remove_status(target: Resource, status: CharacterEnums.StatusEffect) -> String:
	if not target.has_status(status):
		return ""

	target.remove_status(status)
	return "%s is no longer %s." % [target.get_display_name(), CharacterEnums.get_status_name(status).to_lower()]


## Processes turn-based effects like poison damage and natural recovery.
## [param target]: Character or Monster to process.
## [param context]: Either "combat" or "exploration" for context-specific effects.
## [return]: Array of messages describing effects that occurred.
static func tick_effects(target: Resource, context: String = "combat") -> Array[String]:
	var messages: Array[String] = []

	if target.is_dead:
		return messages

	var statuses_to_remove: Array[CharacterEnums.StatusEffect] = []

	for active in target.active_statuses:
		var tick_result := _process_status_tick(target, active, context)
		if tick_result != "":
			messages.append(tick_result)

		if _check_natural_recovery(target, active.type):
			statuses_to_remove.append(active.type)
			messages.append("%s recovered from %s!" % [target.get_display_name(), CharacterEnums.get_status_name(active.type).to_lower()])
		elif active.tick():
			statuses_to_remove.append(active.type)
			messages.append("%s's %s wore off." % [target.get_display_name(), CharacterEnums.get_status_name(active.type).to_lower()])

	for status in statuses_to_remove:
		target.remove_status(status)

	if target.has_method("_sync_status_data"):
		target._sync_status_data()

	return messages


static func _process_status_tick(target: Resource, active: Variant, context: String) -> String:
	match active.type:
		CharacterEnums.StatusEffect.POISONED:
			var damage: int
			if context == "exploration":
				damage = CombatConstants.EXPLORATION_POISON_DAMAGE
			else:
				damage = maxi(1, DamageCalculator.roll_dice(CombatConstants.POISON_DAMAGE_DICE))
			var actual: int = target.take_damage(damage, true)
			if target.is_dead:
				return "%s takes %d poison damage and dies!" % [target.get_display_name(), actual]
			return "%s takes %d poison damage." % [target.get_display_name(), actual]

	return ""


static func _check_natural_recovery(target: Resource, status: CharacterEnums.StatusEffect) -> bool:
	var recovery_chance := 0.0

	match status:
		CharacterEnums.StatusEffect.CONFUSED:
			recovery_chance = CombatConstants.CONFUSED_RECOVERY_CHANCE
		CharacterEnums.StatusEffect.SILENCED:
			recovery_chance = minf(CombatConstants.SILENCED_MAX_RECOVERY, CombatConstants.SILENCED_BASE_RECOVERY + target.level * CombatConstants.SILENCED_LEVEL_BONUS)
		CharacterEnums.StatusEffect.BLINDED:
			recovery_chance = CombatConstants.BLINDED_RECOVERY_CHANCE
		CharacterEnums.StatusEffect.AFRAID:
			recovery_chance = CombatConstants.AFRAID_BASE_RECOVERY + target.level * CombatConstants.AFRAID_LEVEL_BONUS

	if recovery_chance > 0:
		return CombatRNG.randf() < recovery_chance

	return false


static func is_disabled(target: Resource) -> bool:
	return target.is_disabled()


## Rolls a saving throw to resist an effect.
## [param target]: Character or Monster making the save.
## [param save_type]: Type of save (PHYSICAL, MENTAL, MAGICAL, DEATH).
## [param dc]: Difficulty class to beat.
## [param power_modifier]: Additional DC modifier.
## [return]: True if the save succeeds.
static func roll_saving_throw(
	target: Resource,
	save_type: CharacterEnums.SaveType,
	dc: int,
	power_modifier: int = 0
) -> bool:
	var roll: int = CombatRNG.randi_range(1, 20)
	var bonus: int = _get_save_bonus(target, save_type)
	var luck_bonus: int = (target.luck - 10) / 4

	if save_type == CharacterEnums.SaveType.MENTAL and target.has_status(CharacterEnums.StatusEffect.MIND_WARDED):
		bonus += CombatConstants.MIND_WARD_SAVE_BONUS

	var total: int = roll + bonus + luck_bonus

	var actual_dc := dc + power_modifier

	return total >= actual_dc


static func _get_save_bonus(target: Resource, save_type: CharacterEnums.SaveType) -> int:
	var level_bonus: int = target.level / 2

	match save_type:
		CharacterEnums.SaveType.PHYSICAL:
			return level_bonus + (target.vitality - 10) / 4
		CharacterEnums.SaveType.MENTAL:
			return level_bonus + (target.intelligence - 10) / 4
		CharacterEnums.SaveType.MAGICAL:
			return level_bonus + (target.piety - 10) / 4
		CharacterEnums.SaveType.DEATH:
			return level_bonus + (target.luck - 10) / 4

	return level_bonus


static func _check_racial_resistance(target: Resource, status: CharacterEnums.StatusEffect) -> bool:
	if not CharacterEnums.has_racial_resistance(target.race, status):
		return false
	return CombatRNG.randf() < CharacterEnums.RACIAL_RESISTANCE_CHANCE


static func get_status_for_display(target: Resource) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for active in target.active_statuses:
		if active.type == CharacterEnums.StatusEffect.NONE:
			continue

		result.append({
			"type": active.type,
			"name": CharacterEnums.get_status_name(active.type),
			"abbreviation": CharacterEnums.get_status_abbreviation(active.type),
			"duration": active.duration,
			"is_permanent": active.is_permanent()
		})

	return result


## Cures all statuses in a category (e.g., "poison", "mental", "all").
## [param target]: Character or Monster to cure.
## [param group]: Status group name.
## [return]: Array of messages for each status cured.
static func cure_status_group(target: Resource, group: String) -> Array[String]:
	var messages: Array[String] = []
	var to_cure: Array[CharacterEnums.StatusEffect] = []

	match group:
		"poison":
			to_cure = [CharacterEnums.StatusEffect.POISONED]
		"paralysis":
			to_cure = [CharacterEnums.StatusEffect.PARALYZED]
		"petrification":
			to_cure = [CharacterEnums.StatusEffect.STONED]
		"mental":
			to_cure = [
				CharacterEnums.StatusEffect.ASLEEP,
				CharacterEnums.StatusEffect.CONFUSED,
				CharacterEnums.StatusEffect.AFRAID,
				CharacterEnums.StatusEffect.CHARMED,
			]
		"blindness":
			to_cure = [CharacterEnums.StatusEffect.BLINDED]
		"silence":
			to_cure = [CharacterEnums.StatusEffect.SILENCED]
		"curse":
			to_cure = [CharacterEnums.StatusEffect.CURSED]
		"all":
			to_cure = [
				CharacterEnums.StatusEffect.POISONED,
				CharacterEnums.StatusEffect.PARALYZED,
				CharacterEnums.StatusEffect.STONED,
				CharacterEnums.StatusEffect.ASLEEP,
				CharacterEnums.StatusEffect.CONFUSED,
				CharacterEnums.StatusEffect.SILENCED,
				CharacterEnums.StatusEffect.BLINDED,
				CharacterEnums.StatusEffect.AFRAID,
				CharacterEnums.StatusEffect.CHARMED,
				CharacterEnums.StatusEffect.CURSED
			]

	for status in to_cure:
		if target.has_status(status):
			var msg := remove_status(target, status)
			if msg != "":
				messages.append(msg)

	return messages


static func wake_on_damage(target: Resource) -> String:
	if target.has_status(CharacterEnums.StatusEffect.ASLEEP):
		target.remove_status(CharacterEnums.StatusEffect.ASLEEP)
		return "%s wakes up!" % target.get_display_name()
	return ""


static func snap_out_on_damage(target: Resource) -> Array[String]:
	var messages: Array[String] = []
	if target.has_status(CharacterEnums.StatusEffect.CONFUSED):
		if CombatRNG.randf() < CombatConstants.CONFUSED_SNAP_OUT_CHANCE:
			target.remove_status(CharacterEnums.StatusEffect.CONFUSED)
			messages.append("%s snaps out of confusion!" % target.get_display_name())
	if target.has_status(CharacterEnums.StatusEffect.CHARMED):
		if CombatRNG.randf() < CombatConstants.CHARMED_SNAP_OUT_CHANCE:
			target.remove_status(CharacterEnums.StatusEffect.CHARMED)
			messages.append("%s breaks free from the charm!" % target.get_display_name())
	return messages


static func is_mentally_controlled(target: Resource) -> bool:
	return (target.has_status(CharacterEnums.StatusEffect.CONFUSED)
		or target.has_status(CharacterEnums.StatusEffect.CHARMED)
		or target.has_status(CharacterEnums.StatusEffect.BERSERK))


## Returns accuracy bonus/penalty from status effects.
## [param target]: Character or Monster to check.
## [return]: Net accuracy modifier.
static func get_accuracy_modifier(target: Resource) -> int:
	var modifier := 0

	if target.has_status(CharacterEnums.StatusEffect.BLINDED):
		modifier += CombatConstants.BLINDED_ACCURACY_PENALTY

	if target.has_status(CharacterEnums.StatusEffect.BLESSED):
		modifier += CombatConstants.BLESSED_ACCURACY_BONUS

	if target.has_status(CharacterEnums.StatusEffect.CURSED):
		modifier += CombatConstants.CURSED_ACCURACY_PENALTY

	return modifier


## Returns evasion bonus/penalty from status effects.
## [param target]: Character or Monster to check.
## [return]: Net evasion modifier.
static func get_evasion_modifier(target: Resource) -> int:
	if target.has_status(CharacterEnums.StatusEffect.ASLEEP) or target.has_status(CharacterEnums.StatusEffect.PARALYZED) or target.has_status(CharacterEnums.StatusEffect.STONED):
		return CombatConstants.DISABLED_EVASION_PENALTY

	var modifier := 0

	if target.has_status(CharacterEnums.StatusEffect.BLESSED):
		modifier += 2

	if target.has_status(CharacterEnums.StatusEffect.CURSED):
		modifier -= 2

	return modifier


static func should_attack_allies(target: Resource) -> bool:
	return target.has_status(CharacterEnums.StatusEffect.CHARMED)


static func should_attack_randomly(target: Resource) -> bool:
	return target.has_status(CharacterEnums.StatusEffect.BERSERK)


static func may_skip_turn_from_fear(target: Resource) -> bool:
	if target.has_status(CharacterEnums.StatusEffect.AFRAID):
		return CombatRNG.randf() < CombatConstants.FEAR_TURN_SKIP_CHANCE
	return false


## Returns damage multiplier for attacks against sleeping targets.
## [param target]: Target being attacked.
## [return]: 2.0 if asleep, 1.0 otherwise.
static func get_damage_multiplier_for_sleeping(target: Resource) -> float:
	if target.has_status(CharacterEnums.StatusEffect.ASLEEP):
		return CombatConstants.SLEEP_DAMAGE_MULTIPLIER
	return 1.0
