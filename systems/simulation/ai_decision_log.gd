class_name AIDecisionLog
extends RefCounted

var entries: Array[Dictionary] = []


func log_decision(turn: int, actor_name: String, decision: Dictionary) -> void:
	entries.append({
		"turn": turn,
		"actor": actor_name,
		"action": decision.get("action", "unknown"),
		"target": decision.get("target", ""),
		"spell": decision.get("spell", ""),
		"reasoning": decision.get("reasoning", ""),
		"timestamp": Time.get_ticks_msec()
	})


func get_entries() -> Array[Dictionary]:
	return entries


func get_entries_for_actor(actor_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in entries:
		if entry.actor == actor_name:
			result.append(entry)
	return result


func get_entries_for_turn(turn: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in entries:
		if entry.turn == turn:
			result.append(entry)
	return result


func to_json() -> String:
	return JSON.stringify(entries, "\t")


func to_array() -> Array[Dictionary]:
	return entries.duplicate()


func clear() -> void:
	entries.clear()


func size() -> int:
	return entries.size()
