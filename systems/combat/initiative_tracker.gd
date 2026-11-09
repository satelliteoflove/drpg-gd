class_name InitiativeTracker
extends RefCounted

class CombatantEntry:
	var id: String
	var is_player: bool
	var agility: int
	var ticks: float
	var is_extra_action: bool = false
	var accuracy_penalty: int = 0

	func _init(p_id: String, p_is_player: bool, p_agility: int) -> void:
		id = p_id
		is_player = p_is_player
		agility = p_agility
		ticks = 0.0

var combatants: Array[CombatantEntry] = []
## The entry most recently handed out by get_next_combatant. A combatant with
## extra actions has several entries sharing one id, so the delay after acting
## has to land on the entry that actually acted.
var _current: CombatantEntry = null


func clear() -> void:
	combatants.clear()
	_current = null


func add_combatant(id: String, is_player: bool, agility: int) -> void:
	var entry := CombatantEntry.new(id, is_player, agility)
	entry.ticks = _calculate_initial_delay(agility)
	combatants.append(entry)


func remove_combatant(id: String) -> void:
	for i in range(combatants.size() - 1, -1, -1):
		if combatants[i].id == id:
			combatants.remove_at(i)


func add_extra_actions(id: String, is_player: bool, agility: int, count: int) -> void:
	for i in range(count):
		var entry := CombatantEntry.new(id, is_player, agility)
		entry.ticks = _calculate_initial_delay(agility) + (i + 1) * 2.0
		entry.is_extra_action = true
		entry.accuracy_penalty = -2
		combatants.append(entry)


func get_next_combatant() -> CombatantEntry:
	if combatants.is_empty():
		return null

	var lowest_ticks := INF
	var next_entry: CombatantEntry = null

	for entry in combatants:
		if entry.ticks < lowest_ticks:
			lowest_ticks = entry.ticks
			next_entry = entry

	if next_entry:
		for entry in combatants:
			entry.ticks -= lowest_ticks

	_current = next_entry
	return next_entry


func apply_action_delay(id: String) -> void:
	if _current != null and _current.id == id and combatants.has(_current):
		_current.ticks += _calculate_attack_delay(_current.agility)
		return
	for entry in combatants:
		if entry.id == id:
			entry.ticks += _calculate_attack_delay(entry.agility)
			return


func _calculate_initial_delay(agility: int) -> float:
	var base_delay := CombatRNG.randi_range(CombatConstants.INITIAL_DELAY_MIN, CombatConstants.INITIAL_DELAY_MAX)
	return base_delay * (CombatConstants.AGILITY_SCALE_FACTOR / (CombatConstants.BASE_STAT_VALUE + agility))


func _calculate_attack_delay(agility: int) -> float:
	return CombatConstants.BASE_ATTACK_DELAY * (CombatConstants.AGILITY_SCALE_FACTOR / (CombatConstants.BASE_STAT_VALUE + agility))
