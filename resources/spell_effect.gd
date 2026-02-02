class_name SpellEffect
extends Resource

enum EffectType {
	DAMAGE,
	HEAL,
	STATUS,
	CURE,
	BUFF,
	DEBUFF,
	RESURRECTION,
	INSTANT_DEATH,
	UTILITY,
	REVEAL_ENEMIES
}

@export var effect_type: EffectType = EffectType.DAMAGE

@export_group("Damage")
@export var element: CharacterEnums.Element = CharacterEnums.Element.FIRE
@export var damage_dice: String = "1d8"
@export var damage_per_level: int = 0
@export var ignore_defense: bool = false

@export_group("Healing")
@export var heal_dice: String = "1d8"
@export var heal_per_level: int = 0
@export var full_heal: bool = false

@export_group("Status")
@export var status_type: CharacterEnums.StatusEffect = CharacterEnums.StatusEffect.NONE
@export var duration_dice: String = "3+1d3"
@export var save_type: CharacterEnums.SaveType = CharacterEnums.SaveType.MENTAL
@export var status_power: int = 0

@export_group("Cure")
@export var cure_group: String = "all"

@export_group("Buff/Debuff")
@export var buff_stat: String = ""
@export var buff_value: int = 0
@export var buff_duration: int = -1

@export_group("Resurrection")
@export var resurrection_chance: float = 1.0
@export var restore_hp_percent: float = 0.25

@export_group("Instant Death")
@export var death_save_modifier: int = 0

@export_group("Reveal")
@export var reveal_duration: int = 40


static func create_damage(p_element: CharacterEnums.Element, p_dice: String, p_per_level: int = 0) -> SpellEffect:
	var effect := SpellEffect.new()
	effect.effect_type = EffectType.DAMAGE
	effect.element = p_element
	effect.damage_dice = p_dice
	effect.damage_per_level = p_per_level
	return effect


static func create_healing(p_dice: String, p_per_level: int = 0) -> SpellEffect:
	var effect := SpellEffect.new()
	effect.effect_type = EffectType.HEAL
	effect.heal_dice = p_dice
	effect.heal_per_level = p_per_level
	return effect


static func create_full_heal() -> SpellEffect:
	var effect := SpellEffect.new()
	effect.effect_type = EffectType.HEAL
	effect.full_heal = true
	return effect


static func create_status(
	p_status: CharacterEnums.StatusEffect,
	p_duration: String,
	p_save: CharacterEnums.SaveType,
	p_power: int = 0
) -> SpellEffect:
	var effect := SpellEffect.new()
	effect.effect_type = EffectType.STATUS
	effect.status_type = p_status
	effect.duration_dice = p_duration
	effect.save_type = p_save
	effect.status_power = p_power
	return effect


static func create_cure(p_group: String) -> SpellEffect:
	var effect := SpellEffect.new()
	effect.effect_type = EffectType.CURE
	effect.cure_group = p_group
	return effect


static func create_buff(p_stat: String, p_value: int, p_duration: int = -1) -> SpellEffect:
	var effect := SpellEffect.new()
	effect.effect_type = EffectType.BUFF
	effect.buff_stat = p_stat
	effect.buff_value = p_value
	effect.buff_duration = p_duration
	return effect


static func create_debuff(p_stat: String, p_value: int, p_duration: int, p_save: CharacterEnums.SaveType) -> SpellEffect:
	var effect := SpellEffect.new()
	effect.effect_type = EffectType.DEBUFF
	effect.buff_stat = p_stat
	effect.buff_value = -p_value
	effect.buff_duration = p_duration
	effect.save_type = p_save
	return effect


static func create_resurrection(p_chance: float = 1.0, p_hp_percent: float = 0.25) -> SpellEffect:
	var effect := SpellEffect.new()
	effect.effect_type = EffectType.RESURRECTION
	effect.resurrection_chance = p_chance
	effect.restore_hp_percent = p_hp_percent
	return effect


static func create_instant_death(p_save_modifier: int = 0) -> SpellEffect:
	var effect := SpellEffect.new()
	effect.effect_type = EffectType.INSTANT_DEATH
	effect.death_save_modifier = p_save_modifier
	effect.save_type = CharacterEnums.SaveType.DEATH
	return effect


static func create_reveal_enemies(p_duration: int = 40) -> SpellEffect:
	var effect := SpellEffect.new()
	effect.effect_type = EffectType.REVEAL_ENEMIES
	effect.reveal_duration = p_duration
	return effect
