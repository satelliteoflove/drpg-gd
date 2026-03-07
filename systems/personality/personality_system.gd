class_name PersonalitySystem
extends RefCounted


static func seed_tendencies(race: CharacterEnums.Race) -> Dictionary:
	var weights: Dictionary = Personality.RACE_TENDENCY_WEIGHTS.get(race, {})
	var result := {}
	for axis: int in Personality.Axis.values():
		var axis_weights: Array = weights.get(axis, [])
		if axis_weights.is_empty():
			var options: Array = Personality.get_options_for_axis(axis)
			result[axis] = options[CombatRNG.randi() % options.size()]
		else:
			result[axis] = weighted_random_pick(axis_weights)
	return result


static func initialize_evidence() -> Dictionary:
	var result := {}
	for axis: int in Personality.Axis.values():
		result[axis] = {}
	return result


static func crystallize_axis(character: Character, axis: Personality.Axis, option: int, event_desc: String) -> void:
	character.traits[axis] = option
	character.crystallization_events[axis] = {
		"option": option,
		"description": event_desc,
		"day": GameState.game_day,
	}


static func add_evidence(character: Character, axis: Personality.Axis, option: int, amount: int = 1) -> bool:
	if character.traits.has(axis):
		return false

	var axis_evidence: Dictionary = character.evidence.get(axis, {})
	axis_evidence[option] = axis_evidence.get(option, 0) + amount
	character.evidence[axis] = axis_evidence

	if axis_evidence[option] >= Personality.CRYSTALLIZATION_THRESHOLD:
		crystallize_axis(character, axis, option, "Proven through actions")
		return true

	return false


static func seed_backstory_personality(character: Character, chosen_axis: Personality.Axis, chosen_option: int) -> void:
	character.tendencies = seed_tendencies(character.race)
	character.evidence = initialize_evidence()
	character.traits = {}
	character.crystallization_events = {}

	crystallize_axis(character, chosen_axis, chosen_option, "Backstory choice")

	var remaining_axes: Array = []
	for axis: int in Personality.Axis.values():
		if axis != chosen_axis:
			remaining_axes.append(axis)

	var second_axis: int = remaining_axes[CombatRNG.randi() % remaining_axes.size()]
	var tendency_value: int = character.tendencies[second_axis]
	crystallize_axis(character, second_axis as Personality.Axis, tendency_value, "Backstory tendency")


static func seed_auto_personality(character: Character) -> void:
	character.tendencies = seed_tendencies(character.race)
	character.evidence = initialize_evidence()
	character.traits = {}
	character.crystallization_events = {}

	var axes: Array = Personality.Axis.values().duplicate()
	var first_idx: int = CombatRNG.randi() % axes.size()
	var first_axis: int = axes[first_idx]
	axes.remove_at(first_idx)
	var second_idx: int = CombatRNG.randi() % axes.size()
	var second_axis: int = axes[second_idx]

	crystallize_axis(character, first_axis as Personality.Axis, character.tendencies[first_axis], "Background")
	crystallize_axis(character, second_axis as Personality.Axis, character.tendencies[second_axis], "Background")


static func weighted_random_pick(weights: Array) -> int:
	var total := 0
	for pair in weights:
		total += pair[1]
	var roll: int = CombatRNG.randi_range(1, total)
	var cumulative := 0
	for pair in weights:
		cumulative += pair[1]
		if roll <= cumulative:
			return pair[0]
	return weights[weights.size() - 1][0]
