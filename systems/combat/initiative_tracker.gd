class_name InitiativeTracker
extends RefCounted

class CombatantEntry:
	var id: String
	var is_player: bool
	var agility: int
	var ticks: float
	var is_extra_action: bool = false
	## A free action from a surprise round; it costs no initiative.
	var is_surprise: bool = false
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
## Free actions owed to the side that sprang a surprise, taken before the
## normal order begins.
var _surprise_queue: Array[CombatantEntry] = []


func clear() -> void:
	combatants.clear()
	_surprise_queue.clear()
	_current = null


func add_combatant(id: String, is_player: bool, agility: int) -> void:
	var entry := CombatantEntry.new(id, is_player, agility)
	entry.ticks = _calculate_initial_delay(agility)
	combatants.append(entry)


## Puts a combatant ahead of everyone for their next turn.
func move_to_front(id: String) -> void:
	for entry in combatants:
		if entry.id == id and not entry.is_extra_action:
			entry.ticks = -1.0
			return


func remove_combatant(id: String) -> void:
	for i in range(combatants.size() - 1, -1, -1):
		if combatants[i].id == id:
			combatants.remove_at(i)
	for i in range(_surprise_queue.size() - 1, -1, -1):
		if _surprise_queue[i].id == id:
			_surprise_queue.remove_at(i)


func add_extra_actions(id: String, is_player: bool, agility: int, count: int) -> void:
	for i in range(count):
		var entry := CombatantEntry.new(id, is_player, agility)
		entry.ticks = _calculate_initial_delay(agility) + (i + 1) * 2.0
		entry.is_extra_action = true
		entry.accuracy_penalty = -2
		combatants.append(entry)


## Gives every combatant on one side a free action, in initiative order,
## before anyone on the other side moves.
func grant_surprise_round(players: bool) -> void:
	var side: Array[CombatantEntry] = []
	for entry in combatants:
		if entry.is_player == players and not entry.is_extra_action:
			side.append(entry)
	side.sort_custom(func(a: CombatantEntry, b: CombatantEntry) -> bool: return a.ticks < b.ticks)
	for entry in side:
		var free := CombatantEntry.new(entry.id, entry.is_player, entry.agility)
		free.is_surprise = true
		_surprise_queue.append(free)


func get_next_combatant() -> CombatantEntry:
	if not _surprise_queue.is_empty():
		_current = _surprise_queue.pop_front()
		return _current

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
	if _current != null and _current.is_surprise and _current.id == id:
		return
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
