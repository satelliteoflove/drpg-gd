extends SceneTree

const BASE_SEED := 20000
const NUM_RUNS := 50
const PARTY_LEVEL := 5


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("=" .repeat(70))
	print("COMPREHENSIVE COMBAT TESTS")
	print("=" .repeat(70))
	print("")
	print("Configuration: %d runs per scenario, Party level %d, Seeds %d-%d" % [
		NUM_RUNS, PARTY_LEVEL, BASE_SEED, BASE_SEED + NUM_RUNS - 1
	])
	print("")

	print("=" .repeat(70))
	print("PART 1: FLYING ENEMIES (Harpies)")
	print("=" .repeat(70))
	print("")

	_test_vs_flying()

	print("")
	print("=" .repeat(70))
	print("PART 2: UNDEAD ENEMIES")
	print("=" .repeat(70))
	print("")

	_test_vs_undead()

	print("")
	print("=" .repeat(70))
	print("TESTS COMPLETE")
	print("=" .repeat(70))

	quit(0)


func _test_vs_flying() -> void:
	var harpy_group: Array[String] = ["harpy", "harpy"]
	var harpies := TestFixtures.create_monster_group(harpy_group)

	print("Enemy: 2x Harpy (Flying, Evasion 8 + 8 flying bonus vs melee)")
	print("")

	_run_scenario("Balanced (all melee)", TestFixtures.create_balanced_party(PARTY_LEVEL), harpies)
	_run_scenario("Ranged (2 bows)", TestFixtures.create_ranged_party(PARTY_LEVEL), _recreate_harpies())
	_run_scenario("Caster Heavy", TestFixtures.create_caster_heavy_party(PARTY_LEVEL), _recreate_harpies())
	_run_scenario("Fighter Heavy", TestFixtures.create_fighter_heavy_party(PARTY_LEVEL), _recreate_harpies())


func _test_vs_undead() -> void:
	print("-" .repeat(70))
	print("Test A: vs Zombies (Level 2 Undead, Low evasion)")
	print("-" .repeat(70))
	print("")

	var zombie_group: Array[String] = ["zombie", "zombie"]

	_run_scenario("Balanced (1 Priest)", TestFixtures.create_balanced_party(PARTY_LEVEL), _create_monsters(zombie_group))
	_run_scenario("Fighter Heavy (no Priest)", TestFixtures.create_fighter_heavy_party(PARTY_LEVEL), _create_monsters(zombie_group))
	_run_scenario("Caster Heavy (Priest+Bishop)", TestFixtures.create_caster_heavy_party(PARTY_LEVEL), _create_monsters(zombie_group))

	print("")
	print("-" .repeat(70))
	print("Test B: vs Skeletons (Level 2 Undead)")
	print("-" .repeat(70))
	print("")

	var skeleton_group: Array[String] = ["skeleton", "skeleton", "skeleton"]

	_run_scenario("Balanced (1 Priest)", TestFixtures.create_balanced_party(PARTY_LEVEL), _create_monsters(skeleton_group))
	_run_scenario("Fighter Heavy (no Priest)", TestFixtures.create_fighter_heavy_party(PARTY_LEVEL), _create_monsters(skeleton_group))
	_run_scenario("Caster Heavy (Priest+Bishop)", TestFixtures.create_caster_heavy_party(PARTY_LEVEL), _create_monsters(skeleton_group))

	print("")
	print("-" .repeat(70))
	print("Test C: vs Ghosts (Level 4 Undead, High evasion)")
	print("-" .repeat(70))
	print("")

	var ghost_group: Array[String] = ["ghost", "ghost"]

	_run_scenario("Balanced (1 Priest)", TestFixtures.create_balanced_party(PARTY_LEVEL), _create_monsters(ghost_group))
	_run_scenario("Fighter Heavy (no Priest)", TestFixtures.create_fighter_heavy_party(PARTY_LEVEL), _create_monsters(ghost_group))
	_run_scenario("Caster Heavy (Priest+Bishop)", TestFixtures.create_caster_heavy_party(PARTY_LEVEL), _create_monsters(ghost_group))


func _run_scenario(name: String, party: Party, enemies: Array[Monster]) -> void:
	CombatRNG.set_seed(BASE_SEED)

	var batch := BatchSimulator.new()
	var result := batch.run_batch(party, enemies, NUM_RUNS, BASE_SEED)

	var dispel_attempts := 0
	var dispel_successes := 0
	var xp_from_dispels := 0
	var xp_lost := 0
	var total_xp := 0
	var total_hits: Dictionary = {}
	var total_misses: Dictionary = {}

	for run_result in result.results:
		var metrics_data: Dictionary = run_result.get("metrics", {})

		var attempts: Dictionary = metrics_data.get("dispels_attempted", {})
		var successes: Dictionary = metrics_data.get("dispels_succeeded", {})
		for caster in attempts:
			dispel_attempts += attempts[caster]
		for caster in successes:
			dispel_successes += successes[caster]
		xp_from_dispels += metrics_data.get("xp_from_dispels", 0)
		xp_lost += metrics_data.get("xp_lost_to_dispels", 0)
		total_xp += metrics_data.get("total_xp_earned", 0)

		var hits: Dictionary = metrics_data.get("attacks_hit", {})
		var misses: Dictionary = metrics_data.get("attacks_missed", {})
		for attacker in hits:
			if not total_hits.has(attacker):
				total_hits[attacker] = 0
			total_hits[attacker] += hits[attacker]
		for attacker in misses:
			if not total_misses.has(attacker):
				total_misses[attacker] = 0
			total_misses[attacker] += misses[attacker]

	var party_hits := 0
	var party_total := 0
	var enemy_hits := 0
	var enemy_total := 0

	for attacker in total_hits:
		var h: int = total_hits.get(attacker, 0)
		var m: int = total_misses.get(attacker, 0)
		if _is_party_member(attacker):
			party_hits += h
			party_total += h + m
		else:
			enemy_hits += h
			enemy_total += h + m

	var party_hit_rate := float(party_hits) / float(maxi(1, party_total)) * 100.0
	var enemy_hit_rate := float(enemy_hits) / float(maxi(1, enemy_total)) * 100.0

	var avg_xp := float(total_xp) / float(NUM_RUNS)

	print("  %s:" % name)
	print("    Win: %.0f%% | Turns: %.1f | HP left: %.0f%% | Avg XP: %.1f" % [
		result.win_rate, result.avg_turns, result.avg_hp_remaining_on_victory, avg_xp
	])
	print("    Party hit: %.0f%% | Enemy hit: %.0f%%" % [party_hit_rate, enemy_hit_rate])

	if dispel_attempts > 0:
		var dispel_rate := float(dispel_successes) / float(dispel_attempts) * 100.0
		var avg_xp_lost := float(xp_lost) / float(NUM_RUNS)
		print("    Dispels: %d/%d (%.0f%%) | XP lost to dispel: %.1f/battle" % [
			dispel_successes, dispel_attempts, dispel_rate, avg_xp_lost
		])

	print("")


func _is_party_member(name: String) -> bool:
	var party_names := ["Fighter", "Fighter1", "Fighter2", "Priest", "Mage", "Mage1", "Mage2",
		"Thief", "Samurai", "Bishop", "Ranger"]
	return name in party_names


func _recreate_harpies() -> Array[Monster]:
	var harpy_group: Array[String] = ["harpy", "harpy"]
	return TestFixtures.create_monster_group(harpy_group)


func _create_monsters(ids: Array[String]) -> Array[Monster]:
	return TestFixtures.create_monster_group(ids)
