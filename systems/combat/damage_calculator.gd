## Handles all damage calculations, hit/miss rolls, and dice rolling for combat.
class_name DamageCalculator
extends RefCounted

const HIT_BASE_DC: int = 10
const FLYING_EVASION_BONUS: int = 8
const RANGED_WEAPON_MIN_RANGE: int = 3

static var _dice_regex: RegEx = null


## Rolls dice based on standard notation (e.g., "2d6+3", "1d8", "3d4-1").
## [param dice_string]: Dice notation string.
## [return]: Total result of the roll.
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
	return roll + accuracy >= HIT_BASE_DC + evasion


## Calculates final damage from a hit.
## [param base_dice]: Weapon damage dice notation.
## [param strength]: Attacker's strength stat.
## [param bonus]: Additional damage bonus.
## [param reduction]: Target's damage reduction (defense).
## [return]: Final damage dealt (minimum 1).
static func calculate_damage(base_dice: String, strength: int, bonus: int, reduction: int) -> int:
	var dice_damage := roll_dice(base_dice)
	var str_bonus := strength / 4
	var total := dice_damage + str_bonus + bonus - reduction
	return maxi(1, total)


## Resolves a character's attack against a monster.
## [param attacker]: The attacking character.
## [param target]: The target monster.
## [param accuracy_modifier]: Optional accuracy bonus/penalty from status effects.
## [return]: Dictionary with "hit" (bool) and "damage" (int).
static func calculate_character_attack(attacker: Character, target: Monster, accuracy_modifier: int = 0) -> Dictionary:
	var total_accuracy := attacker.accuracy + accuracy_modifier
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

	var damage := calculate_damage(
		attacker.weapon_dice,
		attacker.strength,
		0,
		target.defense
	)
	return {"hit": true, "damage": damage}


## Resolves a monster's attack against a character.
## [param attacker]: The attacking monster.
## [param attack]: The monster's attack being used.
## [param target]: The target character.
## [param evasion_modifier]: Optional evasion bonus/penalty from status effects.
## [return]: Dictionary with "hit" (bool) and "damage" (int).
static func calculate_monster_attack(attacker: Monster, attack: MonsterAttack, target: Character, evasion_modifier: int = 0) -> Dictionary:
	var total_evasion := target.evasion + evasion_modifier
	var hit := check_hit(attack.accuracy_bonus, total_evasion)
	if not hit:
		return {"hit": false, "damage": 0}

	var damage := calculate_damage(
		attack.damage_dice,
		attacker.strength,
		0,
		target.defense
	)
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
