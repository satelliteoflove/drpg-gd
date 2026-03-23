## Represents an enemy monster in combat with stats, attacks, and loot drops.
class_name Monster
extends Resource

@export var monster_name: String = "Monster"
@export var max_hp: int = 10
@export var strength: int = 10
@export var agility: int = 10
@export var defense: int = 0
@export var evasion: int = 0
@export var is_flying: bool = false
@export var creature_type: CharacterEnums.CreatureType = CharacterEnums.CreatureType.HUMANOID
@export var exp_reward: int = 10
@export var gold_reward_dice: String = "1d10"
@export var attacks: Array[MonsterAttack] = []
@export var max_mp: int = 0
@export var spells: Array[String] = []
@export var level: int = 1
@export var luck: int = 10
@export var intelligence: int = 10
@export var piety: int = 10
@export var vitality: int = 10
@export var race: CharacterEnums.Race = CharacterEnums.Race.HUMAN
@export var loot_drops: Array[LootDrop] = []
@export var is_boss: bool = false

@export_group("Spawn Info")
@export var min_floor: int = 1
@export var max_floor: int = 99

var current_hp: int = 0
var current_mp: int = 0
var is_dead: bool = false
var is_defending: bool = false
var grid_position: Vector2i = Vector2i.ZERO
var combat_id: String = ""
var status_effects: Array[CharacterEnums.StatusEffect] = []
var active_statuses: Array = []

var boss_phases: Array[Dictionary] = []
var current_phase: int = 0
var _phase_turn_count: int = 0
var _phase_warned: bool = false
var extra_actions: int = 0


class ActiveStatus:
	var type: CharacterEnums.StatusEffect = CharacterEnums.StatusEffect.NONE
	var duration: int = -1
	var source: String = ""
	var power: int = 0

	func _init(p_type: CharacterEnums.StatusEffect = CharacterEnums.StatusEffect.NONE, p_duration: int = -1, p_source: String = "", p_power: int = 0) -> void:
		type = p_type
		duration = p_duration
		source = p_source
		power = p_power

	func is_permanent() -> bool:
		return duration < 0

	func tick() -> bool:
		if duration > 0:
			duration -= 1
		return duration == 0


## Initializes the monster for combat, resetting HP/MP and generating combat ID.
func init_combat() -> void:
	current_hp = max_hp
	current_mp = max_mp
	is_dead = false
	is_defending = false
	status_effects.clear()
	active_statuses.clear()
	if combat_id == "":
		combat_id = _generate_combat_id()


static func _generate_combat_id() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	var result := ""
	for i in range(8):
		result += chars[CombatRNG.randi() % chars.length()]
	return result


## Applies damage to the monster, potentially killing it.
## [param amount]: Raw damage before defense/defending reduction.
## [return]: Actual damage dealt.
func take_damage(amount: int) -> int:
	var reduced_amount := amount
	if is_defending:
		reduced_amount = amount / 2
	var actual := mini(reduced_amount, current_hp)
	current_hp -= actual
	if current_hp <= 0:
		current_hp = 0
		is_dead = true
	return actual


func get_random_attack() -> MonsterAttack:
	if attacks.is_empty():
		return null
	return attacks[CombatRNG.randi() % attacks.size()]


## Creates a combat-ready copy of this monster template.
## [return]: New Monster instance initialized for combat.
func duplicate_for_combat() -> Monster:
	var copy := duplicate(true) as Monster
	copy.grid_position = grid_position
	copy.boss_phases = boss_phases.duplicate(true)
	copy.current_phase = 0
	copy._phase_turn_count = 0
	copy._phase_warned = false
	copy.extra_actions = extra_actions
	copy.init_combat()
	return copy


func get_row() -> int:
	return grid_position.y


func get_column() -> int:
	return grid_position.x


func get_display_name() -> String:
	return monster_name


func has_status(effect: CharacterEnums.StatusEffect) -> bool:
	return status_effects.has(effect)


func add_status(effect: CharacterEnums.StatusEffect, duration: int = -1, source: String = "", power: int = 0) -> bool:
	if has_status(effect):
		return false

	var exclusive_group := CharacterEnums.get_exclusive_group(effect)
	for existing in exclusive_group:
		if existing != effect and has_status(existing):
			remove_status(existing)

	status_effects.append(effect)
	active_statuses.append(ActiveStatus.new(effect, duration, source, power))
	return true


func remove_status(effect: CharacterEnums.StatusEffect) -> void:
	status_effects.erase(effect)
	for i in range(active_statuses.size() - 1, -1, -1):
		if active_statuses[i].type == effect:
			active_statuses.remove_at(i)
			break


func get_active_status(effect: CharacterEnums.StatusEffect) -> ActiveStatus:
	for active in active_statuses:
		if active.type == effect:
			return active
	return null


func is_disabled() -> bool:
	return has_status(CharacterEnums.StatusEffect.ASLEEP) or \
		   has_status(CharacterEnums.StatusEffect.PARALYZED) or \
		   has_status(CharacterEnums.StatusEffect.STONED)


func can_act() -> bool:
	return not is_dead and not is_disabled()


func is_undead() -> bool:
	return creature_type == CharacterEnums.CreatureType.UNDEAD
