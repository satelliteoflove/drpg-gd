## Handles all damage calculations, hit/miss rolls, and dice rolling for combat.
class_name DamageCalculator
extends RefCounted

const HIT_BASE_DC: int = 10
const FLYING_EVASION_BONUS: int = 8
const RANGED_WEAPON_MIN_RANGE: int = 3

static var _dice_regex: RegEx = null
static var last_hit_detail: String = ""
static var last_damage_detail: String = ""
static var last_save_detail: String = ""


static func roll_dice(dice_string: String) -> int:
	if _dice_regex == null:
		_dice_regex = RegEx.new()
		_dice_regex.compile("(\\d+)d(\\d+)([+-]\\d+)?")
	var result := _dice_regex.search(dice_string)
	if not result:
		return 1

	var count := int(result.get_string(1))
	var sides := int(result.get_string(2))
	var modifier := 0
	if result.get_string(3):
		modifier = int(result.get_string(3))

	var total := 0
	for i in range(count):
		total += CombatRNG.randi_range(1, sides)
	return total + modifier


## Rolls a single d20.
## [return]: Random number 1-20.
static func roll_d20() -> int:
	return CombatRNG.randi_range(1, 20)


## Determines if an attack hits based on accuracy vs evasion.
## [param accuracy]: Attacker's accuracy bonus.
## [param evasion]: Target's evasion value.
## [return]: True if the attack hits.
static func check_hit(accuracy: int, evasion: int) -> bool:
	var roll := roll_d20()
	var needed := HIT_BASE_DC + evasion
	var total := roll + accuracy
	var hit := total >= needed
	last_hit_detail = "d20(%d) + acc(%d) = %d vs DC %d (10+eva%d) -> %s" % [roll, accuracy, total, needed, evasion, "HIT" if hit else "MISS"]
	return hit


## Calculates final damage from a hit.
## [param base_dice]: Weapon damage dice notation.
## [param strength]: Attacker's strength stat.
## [param bonus]: Additional damage bonus.
## [param reduction]: Target's damage reduction (defense).
## [return]: Final damage dealt (minimum 1).
static func calculate_damage(base_dice: String, strength: int, bonus: int, reduction: int) -> int:
	var dice_damage := roll_dice(base_dice)
	var str_bonus := strength / CombatConstants.STR_DAMAGE_DIVISOR
	var raw := dice_damage + str_bonus + bonus
	var total := raw - reduction
	var final_dmg := maxi(1, total)
	last_damage_detail = "%s(%d) + str(%d) + bon(%d) - def(%d) = %d" % [base_dice, dice_damage, str_bonus, bonus, reduction, final_dmg]
	return final_dmg


## Resolves a character's attack against a monster.
## [param attacker]: The attacking character.
## [param target]: The target monster.
## [param accuracy_modifier]: Optional accuracy bonus/penalty from status effects.
## [return]: Dictionary with "hit" (bool) and "damage" (int).
static func calculate_character_attack(attacker: Character, target: Monster, accuracy_modifier: int = 0) -> Dictionary:
	var total_accuracy := attacker.accuracy + accuracy_modifier + AgeTraits.counsel_accuracy(attacker)
	var effective_evasion := target.evasion

	if target.is_flying:
		var weapon_range := 1
		if attacker.equipped_weapon:
			weapon_range = attacker.equipped_weapon.weapon_range
		if weapon_range < RANGED_WEAPON_MIN_RANGE:
			effective_evasion += FLYING_EVASION_BONUS

	var hit := check_hit(total_accuracy, effective_evasion)
	if not hit:
		return {"hit": false, "damage": 0}

	# Equipment damage bonuses (the "+2" on a weapon) and experience both add
	# to a hit. Without the level term, armored late-game foes shrug off
	# fighters entirely.
	var damage := calculate_damage(
		attacker.weapon_dice,
		attacker.strength,
		attacker.damage_bonus + attacker.level / 2 + AgeTraits.melee_damage_bonus(attacker),
		target.defense
	)
	var critical := CombatRNG.randf() < character_critical_chance(attacker, target)
	if critical:
		# Enough to kill even through a defending halve.
		damage = target.current_hp * 2
		last_damage_detail += "  CRITICAL"
		if GameState.party and GameState.party.has_member(attacker):
			CombatNotes.add("A critical hit! %s cuts down the %s." % [attacker.get_display_name(), target.monster_name])
	return {"hit": true, "damage": damage, "critical": critical}


## Resolves a monster's attack against a character.
## [param attacker]: The attacking monster.
## [param attack]: The monster's attack being used.
## [param target]: The target character.
## [param evasion_modifier]: Optional evasion bonus/penalty from status effects.
## [return]: Dictionary with "hit" (bool) and "damage" (int).
static func calculate_monster_attack(attacker: Monster, attack: MonsterAttack, target: Character, evasion_modifier: int = 0) -> Dictionary:
	var hit: bool
	if attack.auto_hit:
		hit = true
		last_hit_detail = "AUTO-HIT (creature ability)"
	else:
		var total_evasion := target.evasion + evasion_modifier
		hit = check_hit(attack.accuracy_bonus, total_evasion)
	if not hit:
		return {"hit": false, "damage": 0}

	var damage := calculate_damage(
		attack.damage_dice,
		attacker.strength,
		0,
		target.defense
	)
	var critical := CombatRNG.randf() < monster_critical_chance(attacker, attack, target)
	if critical:
		damage = target.current_hp * 2
		last_damage_detail += "  CRITICAL"
		if GameState.party and GameState.party.has_member(target):
			CombatNotes.add("A critical hit! The %s's %s finds %s's throat." % [
				attacker.monster_name, attack.attack_name.to_lower(), target.get_display_name()])
	return {"hit": true, "damage": damage, "critical": critical}


# --- Critical hits ---------------------------------------------------------------
#
# As in Wizardry I-V: a critical hit kills outright. Ninjas can land them on
# monsters, with the chance from the NES disassembly (taotao54321's Wiz1
# analysis): level x 2% up to 50%, then (24 - monster level) / 35 for it to
# take, so very high-level foes shrug it off. Guardians never fall to one.
#
# Some monsters can land them on the party. Characters resist with the
# Wizardry I-III critical save (class, race, level and luck), and the
# monster's level scales the chance as in the NES version.

const CRIT_LEVEL_CAP := 25
const CRIT_IMMUNE_MONSTER_LEVEL := 24


static func can_critical(c: Character) -> bool:
	return c.character_class == CharacterEnums.CharacterClass.NINJA


static func character_critical_chance(attacker: Character, target: Monster) -> float:
	if not can_critical(attacker) or target.is_boss:
		return 0.0
	var land := mini(attacker.level, CRIT_LEVEL_CAP) / 50.0
	var take := maxf(0.0, float(CRIT_IMMUNE_MONSTER_LEVEL - target.level) / 35.0)
	return land * minf(1.0, take)


static func monster_critical_chance(attacker: Monster, attack: MonsterAttack, target: Character) -> float:
	if not attacker.can_critical or attack.is_magical or attack.is_breath_weapon \
			or attack.targets_all or attack.targets_row:
		return 0.0
	# Failing the save, a character still has level x 2% (up to 50%) to slip it.
	var slip := minf(0.5, target.level * 0.02)
	return (1.0 - critical_resistance(target)) * (1.0 - slip) * (attacker.level + 1) / 50.0


## The Wizardry I-III save against critical hits, poison and paralysis.
static func critical_resistance(c: Character) -> float:
	var r := 0.0
	match c.character_class:
		CharacterEnums.CharacterClass.FIGHTER, CharacterEnums.CharacterClass.NINJA:
			r += 0.15
		CharacterEnums.CharacterClass.SAMURAI, CharacterEnums.CharacterClass.LORD:
			r += 0.10
	if c.race == CharacterEnums.Race.HUMAN:
		r += 0.05
	r += 0.05 * (c.level / 5)
	if c.luck >= 18:
		r += 0.15
	elif c.luck >= 12:
		r += 0.10
	elif c.luck >= 6:
		r += 0.05
	return minf(r, 0.95)


## Resolves a generic attack using raw stats. Used for friendly-fire from mental statuses.
## [param accuracy]: Attacker's accuracy value.
## [param evasion]: Target's evasion value.
## [param damage_dice]: Weapon damage dice string.
## [param strength]: Attacker's strength stat.
## [param defense]: Target's defense stat.
## [return]: Dictionary with "hit" (bool) and "damage" (int).
static func calculate_generic_attack(accuracy: int, evasion: int, damage_dice: String, strength: int, defense: int) -> Dictionary:
	var hit := check_hit(accuracy, evasion)
	if not hit:
		return {"hit": false, "damage": 0}
	var damage := calculate_damage(damage_dice, strength, 0, defense)
	return {"hit": true, "damage": damage}


## Calculates the chance of successfully escaping combat.
## [param party_agility]: Average agility of the party.
## [return]: Escape probability between 0.1 and 0.9.
static func calculate_escape_chance(party_agility: int) -> float:
	return clampf(CombatConstants.ESCAPE_BASE_CHANCE + (party_agility - CombatConstants.BASE_STAT_VALUE) * CombatConstants.ESCAPE_AGILITY_MODIFIER, CombatConstants.ESCAPE_MIN_CHANCE, CombatConstants.ESCAPE_MAX_CHANCE)


## Attempts to escape from combat.
## [param party_agility]: Average agility of the party.
## [return]: True if escape succeeds.
static func try_escape(party_agility: int) -> bool:
	var chance := calculate_escape_chance(party_agility)
	return CombatRNG.randf() < chance
