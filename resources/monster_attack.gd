class_name MonsterAttack
extends Resource

@export var attack_name: String = "Attack"
@export var damage_dice: String = "1d4"
@export var accuracy_bonus: int = 0
@export var weapon_range: int = 1

@export_group("Status Effect")
@export var effect_type: CharacterEnums.StatusEffect = CharacterEnums.StatusEffect.NONE
@export var effect_chance: float = 0.0
@export var effect_duration_dice: String = ""
@export var effect_save_type: String = ""
@export var effect_power: int = 0

@export_group("Special Properties")
@export var is_magical: bool = false
@export var is_breath_weapon: bool = false
@export var auto_hit: bool = false
@export var element: CharacterEnums.Element = CharacterEnums.Element.NONE
@export var targets_row: bool = false
@export var targets_all: bool = false


static func create_basic(p_name: String, p_dice: String, p_accuracy: int = 0) -> MonsterAttack:
	var attack := MonsterAttack.new()
	attack.attack_name = p_name
	attack.damage_dice = p_dice
	attack.accuracy_bonus = p_accuracy
	return attack


static func create_with_effect(
	p_name: String,
	p_dice: String,
	p_accuracy: int,
	p_effect: CharacterEnums.StatusEffect,
	p_chance: float,
	p_duration: String = "3+1d3",
	p_save: String = "physical",
	p_power: int = 0
) -> MonsterAttack:
	var attack := MonsterAttack.new()
	attack.attack_name = p_name
	attack.damage_dice = p_dice
	attack.accuracy_bonus = p_accuracy
	attack.effect_type = p_effect
	attack.effect_chance = p_chance
	attack.effect_duration_dice = p_duration
	attack.effect_save_type = p_save
	attack.effect_power = p_power
	return attack


static func create_ranged(p_name: String, p_dice: String, p_accuracy: int, p_range: int) -> MonsterAttack:
	var attack := MonsterAttack.new()
	attack.attack_name = p_name
	attack.damage_dice = p_dice
	attack.accuracy_bonus = p_accuracy
	attack.weapon_range = p_range
	return attack


static func create_ability(
	p_name: String,
	p_dice: String,
	p_effect: CharacterEnums.StatusEffect,
	p_chance: float,
	p_duration: String = "3+1d3",
	p_save: String = "mental",
	p_power: int = 0
) -> MonsterAttack:
	var attack := MonsterAttack.new()
	attack.attack_name = p_name
	attack.damage_dice = p_dice
	attack.auto_hit = true
	attack.effect_type = p_effect
	attack.effect_chance = p_chance
	attack.effect_duration_dice = p_duration
	attack.effect_save_type = p_save
	attack.effect_power = p_power
	return attack


static func create_magical(
	p_name: String,
	p_dice: String,
	p_element: CharacterEnums.Element,
	p_accuracy: int = 0
) -> MonsterAttack:
	var attack := MonsterAttack.new()
	attack.attack_name = p_name
	attack.damage_dice = p_dice
	attack.accuracy_bonus = p_accuracy
	attack.is_magical = true
	attack.element = p_element
	return attack
