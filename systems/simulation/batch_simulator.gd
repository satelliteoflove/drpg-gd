class_name BatchSimulator
extends RefCounted

const CombatSimulatorRef = preload("res://systems/simulation/combat_simulator.gd")
const TestFixturesRef = preload("res://systems/simulation/test_fixtures.gd")
const PartyAIRef = preload("res://systems/simulation/party_ai.gd")

signal batch_progress(current: int, total: int)
signal batch_completed(results: Array[Dictionary])


func run_batch(
	party: Party,
	enemies: Array[Monster],
	num_runs: int,
	base_seed: int = 0,
	cast_threshold: float = PartyAIRef.DEFAULT_CAST_THRESHOLD,
	strategy: PartyAIRef.Strategy = PartyAIRef.Strategy.BALANCED
) -> Dictionary:
	var results: Array[Dictionary] = []
	var victories := 0
	var total_turns := 0
	var total_party_hp_percent := 0.0
	var death_causes: Dictionary = {}
	var total_mp_used := 0
	var total_hp_lost := 0

	for i in range(num_runs):
		var seed_value := base_seed + i
		var party_copy := _duplicate_party(party)
		var enemies_copy := _duplicate_enemies(enemies)

		var simulator := CombatSimulatorRef.new()
		simulator.cast_threshold = cast_threshold
		simulator.party_strategy = strategy
		simulator.setup(party_copy, enemies_copy, seed_value)
		var result := simulator.run()

		results.append(result)

		if result.victory:
			victories += 1
			total_party_hp_percent += result.party_hp_percent
		else:
			var deaths_array: Array = result.metrics.get("deaths", [])
			var first_death: Dictionary = deaths_array[0] if not deaths_array.is_empty() else {}
			var cause: String = first_death.get("name", "unknown")
			if not death_causes.has(cause):
				death_causes[cause] = 0
			death_causes[cause] += 1

		total_turns += result.turns
		total_mp_used += result.metrics.get("mp_used", 0)
		total_hp_lost += result.metrics.get("hp_lost", 0)

		batch_progress.emit(i + 1, num_runs)

	var win_rate := float(victories) / float(num_runs) * 100.0
	var avg_turns := float(total_turns) / float(num_runs)
	var avg_hp_remaining := total_party_hp_percent / float(maxi(1, victories)) if victories > 0 else 0.0

	var most_common_death := ""
	var highest_death_count := 0
	for cause in death_causes:
		if death_causes[cause] > highest_death_count:
			highest_death_count = death_causes[cause]
			most_common_death = cause

	var avg_mp_used := float(total_mp_used) / float(num_runs)
	var avg_hp_lost := float(total_hp_lost) / float(num_runs)

	var aggregated := {
		"num_runs": num_runs,
		"base_seed": base_seed,
		"cast_threshold": cast_threshold,
		"win_rate": win_rate,
		"victories": victories,
		"defeats": num_runs - victories,
		"avg_turns": avg_turns,
		"avg_hp_remaining_on_victory": avg_hp_remaining,
		"avg_mp_used": avg_mp_used,
		"avg_hp_lost": avg_hp_lost,
		"most_common_cause_of_defeat": most_common_death,
		"death_causes": death_causes,
		"results": results
	}

	batch_completed.emit(results)
	return aggregated


func compare_scenarios(
	scenarios: Array[Dictionary],
	num_runs: int
) -> Dictionary:
	var comparison: Array[Dictionary] = []

	for i in range(scenarios.size()):
		var scenario: Dictionary = scenarios[i]
		var party: Party = scenario.get("party")
		var enemies: Array[Monster] = scenario.get("enemies", [])
		var base_seed: int = scenario.get("seed", i * 1000)
		var name: String = scenario.get("name", "Scenario %d" % (i + 1))

		if party == null or enemies.is_empty():
			continue

		var batch_result := run_batch(party, enemies, num_runs, base_seed)
		batch_result["scenario_name"] = name
		comparison.append(batch_result)

	var best_scenario := ""
	var best_win_rate := 0.0
	for result in comparison:
		if result.win_rate > best_win_rate:
			best_win_rate = result.win_rate
			best_scenario = result.scenario_name

	return {
		"scenarios": comparison,
		"best_scenario": best_scenario,
		"best_win_rate": best_win_rate,
		"num_scenarios": comparison.size(),
		"runs_per_scenario": num_runs
	}


func run_balance_test(
	party_level: int,
	floor_level: int,
	num_runs: int
) -> Dictionary:
	var results: Array[Dictionary] = []

	for i in range(num_runs):
		var party := TestFixturesRef.create_balanced_party(party_level)
		var enemies := TestFixturesRef.create_floor_encounter(floor_level)
		var seed_value := i * 7919

		var simulator := CombatSimulatorRef.new()
		simulator.setup(party, enemies, seed_value)
		var result := simulator.run()
		results.append(result)

		batch_progress.emit(i + 1, num_runs)

	var victories := 0
	var total_turns := 0
	var total_damage_taken := 0

	for result in results:
		if result.victory:
			victories += 1
		total_turns += result.turns
		var damage_dict: Dictionary = result.metrics.get("damage_taken", {})
		var damage_values: Array = damage_dict.values()
		for dmg in damage_values:
			total_damage_taken += dmg

	return {
		"party_level": party_level,
		"floor_level": floor_level,
		"num_runs": num_runs,
		"win_rate": float(victories) / float(num_runs) * 100.0,
		"avg_turns": float(total_turns) / float(num_runs),
		"avg_damage_taken": float(total_damage_taken) / float(num_runs),
		"results": results
	}


func run_dps_analysis(
	party: Party,
	enemies: Array[Monster],
	num_runs: int
) -> Dictionary:
	var dps_by_actor: Dictionary = {}
	var total_turns := 0

	for i in range(num_runs):
		var party_copy := _duplicate_party(party)
		var enemies_copy := _duplicate_enemies(enemies)

		var simulator := CombatSimulatorRef.new()
		simulator.setup(party_copy, enemies_copy, i)
		var result := simulator.run()

		total_turns += result.turns

		var damage_dealt: Dictionary = result.metrics.get("damage_dealt", {})
		for actor in damage_dealt:
			if not dps_by_actor.has(actor):
				dps_by_actor[actor] = {"total_damage": 0, "fights": 0}
			dps_by_actor[actor]["total_damage"] += damage_dealt[actor]
			dps_by_actor[actor]["fights"] += 1

	var avg_turns := float(total_turns) / float(num_runs)

	var dps_results: Dictionary = {}
	for actor in dps_by_actor:
		var total_damage: int = dps_by_actor[actor]["total_damage"]
		var fights: int = dps_by_actor[actor]["fights"]
		var avg_damage := float(total_damage) / float(fights)
		var dps := avg_damage / avg_turns if avg_turns > 0 else 0.0
		dps_results[actor] = {
			"avg_damage_per_fight": avg_damage,
			"dps_per_turn": dps,
			"total_damage": total_damage
		}

	return {
		"num_runs": num_runs,
		"avg_turns": avg_turns,
		"dps_by_actor": dps_results
	}


func _duplicate_party(party: Party) -> Party:
	var new_party := Party.new()
	for member in party.get_members():
		var copy := member.duplicate(true) as Character
		copy.current_hp = copy.max_hp
		copy.current_mp = copy.max_mp
		copy.is_dead = false
		copy.status_effects.clear()
		copy.active_statuses.clear()
		new_party.add_member(copy)
	new_party.gold = party.gold
	return new_party


func _duplicate_enemies(enemies: Array[Monster]) -> Array[Monster]:
	var result: Array[Monster] = []
	for enemy in enemies:
		var copy := enemy.duplicate(true) as Monster
		copy.grid_position = enemy.grid_position
		result.append(copy)
	return result
