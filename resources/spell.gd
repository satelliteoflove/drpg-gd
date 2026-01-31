class_name Spell
extends Resource

const CharEnum = preload("res://resources/character_enums.gd")

enum EffectType {
	DAMAGE,
	HEAL,
	STATUS,
	CURE,
	BUFF,
	DEBUFF,
	RESURRECTION,
	INSTANT_DEATH,
	UTILITY
}

@export var id: String = ""
@export var name: String = ""
@export var original_name: String = ""
@export var school: CharEnum.SpellSchool = CharEnum.SpellSchool.MAGE
@export var level: int = 1
@export var mp_cost: int = 3
@export var target_type: CharEnum.SpellTargetType = CharEnum.SpellTargetType.SINGLE_ENEMY
@export var in_combat: bool = true
@export var out_of_combat: bool = false
@export_multiline var description: String = ""
@export var effects: Array[SpellEffect] = []
@export var fizzle_modifier: float = 0.0


static func create(
	p_id: String,
	p_name: String,
	p_original: String,
	p_school: CharEnum.SpellSchool,
	p_level: int,
	p_target: CharEnum.SpellTargetType,
	p_desc: String
) -> Spell:
	var spell := Spell.new()
	spell.id = p_id
	spell.name = p_name
	spell.original_name = p_original
	spell.school = p_school
	spell.level = p_level
	spell.target_type = p_target
	spell.description = p_desc
	spell.mp_cost = _get_mp_cost_for_level(p_level)
	return spell


static func _get_mp_cost_for_level(spell_level: int) -> int:
	match spell_level:
		1: return 3
		2: return 5
		3: return 8
		4: return 12
		5: return 15
		6: return 20
		7: return 30
		_: return 3


func add_damage_effect(element: CharEnum.Element, dice: String, per_level: int = 0) -> Spell:
	var effect := SpellEffect.create_damage(element, dice, per_level)
	effects.append(effect)
	return self


func add_healing_effect(dice: String, per_level: int = 0) -> Spell:
	var effect := SpellEffect.create_healing(dice, per_level)
	effects.append(effect)
	return self


func add_status_effect(
	status: CharEnum.StatusEffect,
	duration_dice: String,
	save_type: CharEnum.SaveType,
	power: int = 0
) -> Spell:
	var effect := SpellEffect.create_status(status, duration_dice, save_type, power)
	effects.append(effect)
	return self


func add_cure_effect(cure_group: String) -> Spell:
	var effect := SpellEffect.create_cure(cure_group)
	effects.append(effect)
	return self


func add_buff_effect(stat: String, value: int, duration: int = -1) -> Spell:
	var effect := SpellEffect.create_buff(stat, value, duration)
	effects.append(effect)
	return self


func set_out_of_combat(enabled: bool) -> Spell:
	out_of_combat = enabled
	return self


func set_in_combat(enabled: bool) -> Spell:
	in_combat = enabled
	return self


func get_school_name() -> String:
	match school:
		CharEnum.SpellSchool.MAGE: return "Mage"
		CharEnum.SpellSchool.PRIEST: return "Priest"
		CharEnum.SpellSchool.ALCHEMIST: return "Alchemist"
		CharEnum.SpellSchool.PSIONIC: return "Psionic"
		_: return "Unknown"


func get_target_description() -> String:
	match target_type:
		CharEnum.SpellTargetType.SELF: return "Self"
		CharEnum.SpellTargetType.SINGLE_ALLY: return "One Ally"
		CharEnum.SpellTargetType.SINGLE_ENEMY: return "One Enemy"
		CharEnum.SpellTargetType.ALL_ALLIES: return "All Allies"
		CharEnum.SpellTargetType.ALL_ENEMIES: return "All Enemies"
		CharEnum.SpellTargetType.DEAD_ALLY: return "Dead Ally"
		CharEnum.SpellTargetType.SPLASH: return "Area (Splash)"
		CharEnum.SpellTargetType.ROW: return "Enemy Row"
		CharEnum.SpellTargetType.COLUMN: return "Enemy Column"
		_: return "Unknown"
