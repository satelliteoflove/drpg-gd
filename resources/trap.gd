class_name Trap
extends Resource

const CharEnum = preload("res://resources/character_enums.gd")

enum DamageTarget {
	OPENER,
	PARTY,
	FRONT_ROW
}

@export var trap_id: String = ""
@export var trap_name: String = ""
@export var damage_dice: String = ""
@export var damage_target: DamageTarget = DamageTarget.OPENER
@export var status_effect: CharEnum.StatusEffect = CharEnum.StatusEffect.NONE
@export var status_duration: int = 5
@export var triggers_combat: bool = false


static func create(
	p_id: String,
	p_name: String,
	p_damage_dice: String,
	p_target: DamageTarget,
	p_status: CharEnum.StatusEffect = CharEnum.StatusEffect.NONE,
	p_status_duration: int = 5,
	p_triggers_combat: bool = false
) -> Trap:
	var trap := Trap.new()
	trap.trap_id = p_id
	trap.trap_name = p_name
	trap.damage_dice = p_damage_dice
	trap.damage_target = p_target
	trap.status_effect = p_status
	trap.status_duration = p_status_duration
	trap.triggers_combat = p_triggers_combat
	return trap
