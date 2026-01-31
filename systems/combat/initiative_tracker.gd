class_name InitiativeTracker
extends RefCounted

class CombatantEntry:
	var id: String
	var is_player: bool
	var agility: int
	var ticks: float

	func _init(p_id: String, p_is_player: bool, p_agility: int) -> void:
		id = p_id
		is_player = p_is_player
		agility = p_agility
		ticks = 0.0

var combatants: Array[CombatantEntry] = []


func clear() -> void:
	combatants.clear()


func add_combatant(id: String, is_player: bool, agility: int) -> void:
	var entry := CombatantEntry.new(id, is_player, agility)
	entry.ticks = _calculate_initial_delay(agility)
	combatants.append(entry)


func remove_combatant(id: String) -> void:
	for i in range(combatants.size() - 1, -1, -1):
		if combatants[i].id == id:
			combatants.remove_at(i)
			return


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

	return next_entry


func apply_action_delay(id: String) -> void:
	for entry in combatants:
		if entry.id == id:
			entry.ticks += _calculate_attack_delay(entry.agility)
			return


func _calculate_initial_delay(agility: int) -> float:
	var base_delay := CombatRNG.randi_range(CombatConstants.INITIAL_DELAY_MIN, CombatConstants.INITIAL_DELAY_MAX)
	return base_delay * (CombatConstants.AGILITY_SCALE_FACTOR / (CombatConstants.BASE_STAT_VALUE + agility))


func _calculate_attack_delay(agility: int) -> float:
	return CombatConstants.BASE_ATTACK_DELAY * (CombatConstants.AGILITY_SCALE_FACTOR / (CombatConstants.BASE_STAT_VALUE + agility))
