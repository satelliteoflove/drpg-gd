extends SceneTree

const CombatRNG = preload("res://autoload/combat_rng.gd")
const CombatSimulator = preload("res://systems/simulation/combat_simulator.gd")
const BatchSimulator = preload("res://systems/simulation/batch_simulator.gd")
const TestFixtures = preload("res://systems/simulation/test_fixtures.gd")

const BASE_SEED := 10000
const NUM_RUNS := 100
const PARTY_LEVEL := 5
const FLOOR_LEVEL := 3


func _init() -> void:
	call_deferred("_run_batch")


func _run_batch() -> void:
	print("=" .repeat(60))
	print("Combat Simulator Batch Run")
	print("=" .repeat(60))
	print("")
	print("Configuration:")
	print("  Base seed: %d" % BASE_SEED)
	print("  Seed range: %d - %d" % [BASE_SEED, BASE_SEED + NUM_RUNS - 1])
	print("  Number of runs: %d" % NUM_RUNS)
	print("  Party level: %d" % PARTY_LEVEL)
	print("  Floor level: %d" % FLOOR_LEVEL)
	print("")

	CombatRNG.set_seed(BASE_SEED)
	var party := TestFixtures.create_balanced_party(PARTY_LEVEL)
	var enemies := TestFixtures.create_floor_encounter(FLOOR_LEVEL)

	print("Party composition:")
	for member in party.get_members():
		print("  - %s (Lv%d %s) HP:%d/%d" % [
			member.character_name,
			member.level,
			_get_class_name(member.character_class),
			member.current_hp,
			member.max_hp
		])
	print("")

	print("Enemy composition:")
	for enemy in enemies:
		print("  - %s HP:%d" % [enemy.monster_name, enemy.max_hp])
	print("")

	var batch := BatchSimulator.new()
	print("Running %d simulations..." % NUM_RUNS)
	print("")

	var result := batch.run_batch(party, enemies, NUM_RUNS, BASE_SEED)

	print("=" .repeat(60))
	print("RESULTS")
	print("=" .repeat(60))
	print("")
	print("Overall:")
	print("  Win rate: %.1f%% (%d victories, %d defeats)" % [
		result.win_rate,
		result.victories,
		result.defeats
	])
	print("  Average turns: %.1f" % result.avg_turns)
	print("  Avg party HP remaining (victories): %.1f%%" % result.avg_hp_remaining_on_victory)
	print("")

	if result.defeats > 0:
		print("Defeat analysis:")
		print("  Most common cause: %s" % result.most_common_cause_of_defeat)
		print("  Death causes breakdown:")
		for cause in result.death_causes:
			var count: int = result.death_causes[cause]
			var pct := float(count) / float(result.defeats) * 100.0
			print("    - %s: %d (%.1f%% of defeats)" % [cause, count, pct])
		print("")

	var total_hits: Dictionary = {}
	var total_misses: Dictionary = {}

	for run_result in result.results:
		var metrics_data: Dictionary = run_result.get("metrics", {})
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

	print("Hit rates by combatant:")
	var all_attackers := {}
	for a in total_hits:
		all_attackers[a] = true
	for a in total_misses:
		all_attackers[a] = true

	for attacker in all_attackers:
		var h: int = total_hits.get(attacker, 0)
		var m: int = total_misses.get(attacker, 0)
		var total := h + m
		var rate := float(h) / float(total) * 100.0 if total > 0 else 0.0
		print("  %s: %.1f%% (%d/%d)" % [attacker, rate, h, total])
	print("")

	var grand_total_hits := 0
	var grand_total_misses := 0
	for a in total_hits:
		grand_total_hits += total_hits[a]
	for a in total_misses:
		grand_total_misses += total_misses[a]
	var grand_total := grand_total_hits + grand_total_misses
	var overall_hit_rate := float(grand_total_hits) / float(grand_total) * 100.0 if grand_total > 0 else 0.0
	print("Overall hit rate: %.1f%% (%d/%d)" % [overall_hit_rate, grand_total_hits, grand_total])
	print("")

	var total_dispel_attempts: Dictionary = {}
	var total_dispel_successes: Dictionary = {}
	var total_xp_from_dispels := 0
	var total_xp_lost := 0

	for run_result in result.results:
		var metrics_data: Dictionary = run_result.get("metrics", {})
		var attempts: Dictionary = metrics_data.get("dispels_attempted", {})
		var successes: Dictionary = metrics_data.get("dispels_succeeded", {})
		total_xp_from_dispels += metrics_data.get("xp_from_dispels", 0)
		total_xp_lost += metrics_data.get("xp_lost_to_dispels", 0)
		for caster in attempts:
			if not total_dispel_attempts.has(caster):
				total_dispel_attempts[caster] = 0
			total_dispel_attempts[caster] += attempts[caster]
		for caster in successes:
			if not total_dispel_successes.has(caster):
				total_dispel_successes[caster] = 0
			total_dispel_successes[caster] += successes[caster]

	if not total_dispel_attempts.is_empty():
		print("Dispel statistics:")
		for caster in total_dispel_attempts:
			var att: int = total_dispel_attempts.get(caster, 0)
			var suc: int = total_dispel_successes.get(caster, 0)
			var rate := float(suc) / float(att) * 100.0 if att > 0 else 0.0
			print("  %s: %.1f%% success (%d/%d attempts)" % [caster, rate, suc, att])
		print("  XP from dispels: %d (lost %d to reduced XP)" % [total_xp_from_dispels, total_xp_lost])
		print("")

	var turn_counts: Dictionary = {}
	var min_turns := 999
	var max_turns := 0
	var victory_turns: Array[int] = []
	var defeat_turns: Array[int] = []

	for run_result in result.results:
		var turns: int = run_result.turns
		if not turn_counts.has(turns):
			turn_counts[turns] = 0
		turn_counts[turns] += 1
		min_turns = mini(min_turns, turns)
		max_turns = maxi(max_turns, turns)
		if run_result.victory:
			victory_turns.append(turns)
		else:
			defeat_turns.append(turns)

	print("Turn distribution:")
	print("  Range: %d - %d turns" % [min_turns, max_turns])
	var sorted_turns := turn_counts.keys()
	sorted_turns.sort()
	for t in sorted_turns:
		var bar := "#".repeat(turn_counts[t])
		print("  %2d turns: %s (%d)" % [t, bar, turn_counts[t]])
	print("")

	if not victory_turns.is_empty():
		var avg_victory_turns := 0.0
		for t in victory_turns:
			avg_victory_turns += t
		avg_victory_turns /= victory_turns.size()
		print("  Avg turns to victory: %.1f" % avg_victory_turns)

	if not defeat_turns.is_empty():
		var avg_defeat_turns := 0.0
		for t in defeat_turns:
			avg_defeat_turns += t
		avg_defeat_turns /= defeat_turns.size()
		print("  Avg turns to defeat: %.1f" % avg_defeat_turns)

	print("")
	print("=" .repeat(60))
	print("To reproduce: use seeds %d-%d" % [BASE_SEED, BASE_SEED + NUM_RUNS - 1])
	print("=" .repeat(60))

	quit(0)


func _get_class_name(class_id: int) -> String:
	match class_id:
		0: return "Fighter"
		1: return "Mage"
		2: return "Priest"
		3: return "Thief"
		4: return "Bishop"
		5: return "Samurai"
		6: return "Lord"
		7: return "Ninja"
		8: return "Bard"
		9: return "Alchemist"
		10: return "Psionic"
		11: return "Monk"
		12: return "Ranger"
		_: return "Unknown"
