class_name DamageCalculator
extends RefCounted

const CombatRNG = preload("res://autoload/combat_rng.gd")

const HIT_BASE_DC: int = 10
const FLYING_EVASION_BONUS: int = 8
const RANGED_WEAPON_MIN_RANGE: int = 3


static func roll_dice(dice_string: String) -> int:
	var regex := RegEx.new()
	regex.compile("(\\d+)d(\\d+)([+-]\\d+)?")
	var result := regex.search(dice_string)
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


static func roll_d20() -> int:
	return CombatRNG.randi_range(1, 20)


static func check_hit(accuracy: int, evasion: int) -> bool:
	var roll := roll_d20()
	return roll + accuracy >= HIT_BASE_DC + evasion


static func calculate_damage(base_dice: String, strength: int, bonus: int, reduction: int) -> int:
	var dice_damage := roll_dice(base_dice)
	var str_bonus := strength / 4
	var total := dice_damage + str_bonus + bonus - reduction
	return maxi(1, total)


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


static func calculate_escape_chance(party_agility: int) -> float:
	return clampf(0.5 + (party_agility - 10) * 0.02, 0.1, 0.9)


static func try_escape(party_agility: int) -> bool:
	var chance := calculate_escape_chance(party_agility)
	return CombatRNG.randf() < chance
