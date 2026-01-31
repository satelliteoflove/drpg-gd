class_name DiveSimulator
extends RefCounted

signal encounter_completed(encounter_num: int, result: Dictionary)
signal dive_completed(result: Dictionary)


func run_dive(
	party: Party,
	floor_level: int,
	max_encounters: int,
	base_seed: int = 0,
	cast_threshold: float = PartyAI.DEFAULT_CAST_THRESHOLD,
	strategy: PartyAI.Strategy = PartyAI.Strategy.BALANCED,
	rest_hp_percent: float = 0.0,
	rest_mp_percent: float = 0.0
) -> Dictionary:
	var encounters_won := 0
	var total_turns := 0
	var total_xp := 0
	var encounter_results: Array[Dictionary] = []
	var total_hp_restored := 0
	var total_mp_restored := 0

	var starting_hp := _get_party_total_hp(party)
	var starting_mp := _get_party_total_mp(party)

	for i in range(max_encounters):
		if _party_wiped(party):
			break

		var seed_value := base_seed + i * 100
		var enemies := TestFixtures.create_floor_encounter(floor_level)

		var simulator := CombatSimulator.new()
		simulator.cast_threshold = cast_threshold
		simulator.party_strategy = strategy
		simulator.setup(party, enemies, seed_value)
		var result := simulator.run()

		encounter_results.append(result)
		total_turns += result.turns
		total_xp += result.metrics.get("total_xp_earned", 0)

		if result.victory:
			encounters_won += 1
			encounter_completed.emit(i + 1, result)

			if rest_hp_percent > 0.0 or rest_mp_percent > 0.0:
				var restored := _rest_party(party, rest_hp_percent, rest_mp_percent)
				total_hp_restored += restored.hp
				total_mp_restored += restored.mp
		else:
			encounter_completed.emit(i + 1, result)
			break

	var ending_hp := _get_party_total_hp(party)
	var ending_mp := _get_party_total_mp(party)
	var survivors := _count_survivors(party)

	var dive_result := {
		"floor_level": floor_level,
		"max_encounters": max_encounters,
		"encounters_completed": encounters_won,
		"total_turns": total_turns,
		"total_xp": total_xp,
		"xp_per_encounter": float(total_xp) / float(maxi(1, encounters_won)),
		"starting_hp": starting_hp,
		"ending_hp": ending_hp,
		"hp_used": starting_hp - ending_hp,
		"hp_restored": total_hp_restored,
		"net_hp_cost": (starting_hp - ending_hp) + total_hp_restored,
		"starting_mp": starting_mp,
		"ending_mp": ending_mp,
		"mp_used": starting_mp - ending_mp,
		"mp_restored": total_mp_restored,
		"net_mp_cost": (starting_mp - ending_mp) + total_mp_restored,
		"survivors": survivors,
		"party_wiped": _party_wiped(party),
		"cast_threshold": cast_threshold,
		"rest_hp_percent": rest_hp_percent,
		"rest_mp_percent": rest_mp_percent,
		"encounters": encounter_results
	}

	dive_completed.emit(dive_result)
	return dive_result


func run_dive_batch(
	party: Party,
	floor_level: int,
	max_encounters: int,
	num_dives: int,
	base_seed: int = 0,
	cast_threshold: float = PartyAI.DEFAULT_CAST_THRESHOLD,
	strategy: PartyAI.Strategy = PartyAI.Strategy.BALANCED,
	rest_hp_percent: float = 0.0,
	rest_mp_percent: float = 0.0
) -> Dictionary:
	var total_encounters := 0
	var total_xp := 0
	var total_wipes := 0
	var total_net_hp := 0
	var total_net_mp := 0
	var dive_results: Array[Dictionary] = []

	for i in range(num_dives):
		var party_copy := _duplicate_party(party)
		var seed_value := base_seed + i * 10000

		var result := run_dive(
			party_copy, floor_level, max_encounters, seed_value,
			cast_threshold, strategy, rest_hp_percent, rest_mp_percent
		)

		dive_results.append(result)
		total_encounters += result.encounters_completed
		total_xp += result.total_xp
		total_net_hp += result.net_hp_cost
		total_net_mp += result.net_mp_cost
		if result.party_wiped:
			total_wipes += 1

	var avg_encounters := float(total_encounters) / float(num_dives)
	var avg_xp := float(total_xp) / float(num_dives)
	var avg_net_hp := float(total_net_hp) / float(num_dives)
	var avg_net_mp := float(total_net_mp) / float(num_dives)
	var wipe_rate := float(total_wipes) / float(num_dives) * 100.0
	var survival_rate := 100.0 - wipe_rate

	return {
		"num_dives": num_dives,
		"floor_level": floor_level,
		"max_encounters": max_encounters,
		"cast_threshold": cast_threshold,
		"rest_hp_percent": rest_hp_percent,
		"rest_mp_percent": rest_mp_percent,
		"avg_encounters_per_dive": avg_encounters,
		"avg_xp_per_dive": avg_xp,
		"avg_net_hp_cost": avg_net_hp,
		"avg_net_mp_cost": avg_net_mp,
		"survival_rate": survival_rate,
		"wipe_rate": wipe_rate,
		"total_wipes": total_wipes,
		"dive_results": dive_results
	}


func compare_thresholds(
	party: Party,
	floor_level: int,
	max_encounters: int,
	num_dives: int,
	thresholds: Array[float],
	base_seed: int = 0
) -> Dictionary:
	var comparison: Array[Dictionary] = []

	for threshold in thresholds:
		var party_copy := _duplicate_party(party)
		var result := run_dive_batch(
			party_copy, floor_level, max_encounters, num_dives,
			base_seed, threshold
		)
		result["threshold"] = threshold
		comparison.append(result)

	var best_threshold := 0.0
	var best_xp := 0.0
	for result in comparison:
		if result.avg_xp_per_dive > best_xp:
			best_xp = result.avg_xp_per_dive
			best_threshold = result.threshold

	return {
		"comparison": comparison,
		"best_threshold": best_threshold,
		"best_avg_xp": best_xp
	}


func _get_party_total_hp(party: Party) -> int:
	var total := 0
	for member in party.get_members():
		if not member.is_dead:
			total += member.current_hp
	return total


func _get_party_total_mp(party: Party) -> int:
	var total := 0
	for member in party.get_members():
		if not member.is_dead:
			total += member.current_mp
	return total


func _party_wiped(party: Party) -> bool:
	for member in party.get_members():
		if not member.is_dead:
			return false
	return true


func _count_survivors(party: Party) -> int:
	var count := 0
	for member in party.get_members():
		if not member.is_dead:
			count += 1
	return count


func _rest_party(party: Party, hp_percent: float, mp_percent: float) -> Dictionary:
	var total_hp_restored := 0
	var total_mp_restored := 0

	for member in party.get_members():
		if member.is_dead:
			continue

		var hp_to_restore := int(float(member.max_hp) * hp_percent)
		var mp_to_restore := int(float(member.max_mp) * mp_percent)

		var actual_hp := member.heal(hp_to_restore)
		var actual_mp := member.restore_mp(mp_to_restore)

		total_hp_restored += actual_hp
		total_mp_restored += actual_mp

	return {"hp": total_hp_restored, "mp": total_mp_restored}


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
