class_name RelationshipManagerClass
extends Node

var relationships: Dictionary = {}
var daily_counts: Dictionary = {}
var last_party_ids: Array[String] = []


func add_modifier(id_a: String, id_b: String, source: String, weight: int, day: int) -> void:
	var pair_key := Relationships.make_pair_key(id_a, id_b)
	if not relationships.has(pair_key):
		relationships[pair_key] = []

	var count: int = daily_counts.get(pair_key, 0)
	var adjusted_weight := weight
	if count > 0:
		var decay := pow(Relationships.DIMINISHING_DECAY, count)
		decay = maxf(decay, Relationships.DIMINISHING_FLOOR)
		adjusted_weight = int(weight * decay)
		if adjusted_weight == 0 and weight != 0:
			adjusted_weight = 1 if weight > 0 else -1

	var modifier := Relationships.create_modifier(source, adjusted_weight, day)
	relationships[pair_key].append(modifier)
	daily_counts[pair_key] = count + 1


func get_total_weight(id_a: String, id_b: String) -> int:
	var pair_key := Relationships.make_pair_key(id_a, id_b)
	var modifiers: Array = relationships.get(pair_key, [])
	var total := 0
	for mod: Dictionary in modifiers:
		total += mod.get("weight", 0)
	return total


func get_tier(id_a: String, id_b: String) -> Relationships.BondTier:
	return Relationships.get_tier(get_total_weight(id_a, id_b))


func get_adjacency_bonus(party_members: Array[Character]) -> Dictionary:
	var bonuses := {}
	for i in range(party_members.size()):
		bonuses[party_members[i].id] = { "accuracy": 0, "evasion": 0 }

	for i in range(party_members.size()):
		for j in [i - 1, i + 1]:
			if j < 0 or j >= party_members.size():
				continue
			var tier := get_tier(party_members[i].id, party_members[j].id)
			var bonus: Dictionary = Relationships.ADJACENCY_BONUSES.get(tier, {})
			var acc: int = bonus.get("accuracy", 0)
			var eva: int = bonus.get("evasion", 0)
			if acc > bonuses[party_members[i].id]["accuracy"]:
				bonuses[party_members[i].id]["accuracy"] = acc
			if eva > bonuses[party_members[i].id]["evasion"]:
				bonuses[party_members[i].id]["evasion"] = eva

	return bonuses


func check_reunion(current_party_ids: Array[String], day: int) -> void:
	for new_id in current_party_ids:
		if last_party_ids.has(new_id):
			continue
		for existing_id in last_party_ids:
			if current_party_ids.has(existing_id):
				add_modifier(new_id, existing_id, "reunion", Relationships.REUNION_WEIGHT, day)
	last_party_ids = current_party_ids.duplicate()


func advance_day() -> void:
	daily_counts.clear()


func get_relationships_for(character_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pair_key: String in relationships.keys():
		var ids := pair_key.split(":")
		if ids.size() != 2:
			continue
		var other_id := ""
		if ids[0] == character_id:
			other_id = ids[1]
		elif ids[1] == character_id:
			other_id = ids[0]
		else:
			continue

		var weight := get_total_weight(character_id, other_id)
		if weight == 0:
			continue
		var tier := Relationships.get_tier(weight)
		result.append({ "other_id": other_id, "weight": weight, "tier": tier })
	return result


func clear() -> void:
	relationships.clear()
	daily_counts.clear()
	last_party_ids.clear()


func get_save_state() -> Dictionary:
	return {
		"relationships": relationships.duplicate(true),
		"last_party_ids": last_party_ids.duplicate(),
	}


func load_save_state(state: Dictionary) -> void:
	relationships = state.get("relationships", {}).duplicate(true)
	var ids: Array = state.get("last_party_ids", [])
	last_party_ids.clear()
	for id: String in ids:
		last_party_ids.append(id)
