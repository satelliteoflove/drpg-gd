extends Node

const RUNS_PER_COMBO := 84
const BASE_SEED := 50000

var _scenarios := [
	{"name": "Lv3 vs Orcs x3", "level": 3, "enemies": ["orc", "orc", "orc"]},
	{"name": "Lv3 vs Dark Mage + Witch x2", "level": 3, "enemies": ["dark_mage", "witch", "witch"]},
	{"name": "Lv3 vs Troll + Goblins x3", "level": 3, "enemies": ["troll", "goblin", "goblin", "goblin"]},
	{"name": "Lv5 vs Boss Ironjaw", "level": 5, "enemies": ["boss_ironjaw"]},
	{"name": "Lv5 vs Ogre x2 + Orc x2", "level": 5, "enemies": ["ogre", "ogre", "orc", "orc"]},
	{"name": "Lv4 vs Minotaur + Skeleton x2", "level": 4, "enemies": ["minotaur", "skeleton", "skeleton"]},
	{"name": "Lv3 vs Ghost x2 + Zombie x2", "level": 3, "enemies": ["ghost", "ghost", "zombie", "zombie"]},
	{"name": "Lv4 vs Dark Mage x2 + Bandit x2", "level": 4, "enemies": ["dark_mage", "dark_mage", "bandit", "bandit"]},
]

var _strategies := {
	"AGGRESSIVE": PartyAI.Strategy.AGGRESSIVE,
	"BALANCED": PartyAI.Strategy.BALANCED,
	"DEFENSIVE": PartyAI.Strategy.DEFENSIVE,
}


func _ready() -> void:
	_run()


func _run() -> void:
	var total_combos := _scenarios.size() * _strategies.size()
	var total_runs := total_combos * RUNS_PER_COMBO

	print("=" .repeat(75))
	print("AI Improvement Simulation: %d runs (%d combos x %d runs)" % [total_runs, total_combos, RUNS_PER_COMBO])
	print("=" .repeat(75))
	print("")

	var combo_idx := 0
	var all_results: Array[Dictionary] = []

	for scenario in _scenarios:
		var enemy_ids: Array[String] = []
		for id in scenario["enemies"]:
			enemy_ids.append(id)
		var level: int = scenario["level"]
		var scenario_name: String = scenario["name"]

		for strat_name in _strategies:
			var strategy: PartyAI.Strategy = _strategies[strat_name]
			combo_idx += 1
			var seed_offset := combo_idx * 1000

			CombatRNG.set_seed(BASE_SEED + seed_offset)
			var party := TestFixtures.create_balanced_party(level)
			var enemies := TestFixtures.create_monster_group(enemy_ids)

			var batch := BatchSimulator.new()
			var result := batch.run_batch(party, enemies, RUNS_PER_COMBO, BASE_SEED + seed_offset, PartyAI.DEFAULT_CAST_THRESHOLD, strategy)

			result["combo_name"] = "%s [%s]" % [scenario_name, strat_name]
			result["strategy"] = strat_name
			result["scenario"] = scenario_name
			all_results.append(result)

			print("[%2d/%d] %-52s  Win: %5.1f%%  Turns: %4.1f  HP: %5.1f%%" % [
				combo_idx, total_combos,
				result["combo_name"],
				result.win_rate,
				result.avg_turns,
				result.avg_hp_remaining_on_victory,
			])

	print("")
	print("=" .repeat(75))
	print("SUMMARY BY PARTY STRATEGY (across all scenarios)")
	print("=" .repeat(75))
	print("")

	for strat_name in _strategies:
		var wins := 0
		var total := 0
		var total_turns := 0.0
		var total_hp := 0.0
		var victory_count := 0

		for r in all_results:
			if r["strategy"] != strat_name:
				continue
			wins += r.victories
			total += r.num_runs
			total_turns += r.avg_turns * r.num_runs
			if r.victories > 0:
				total_hp += r.avg_hp_remaining_on_victory * r.victories
				victory_count += r.victories

		var overall_wr := float(wins) / float(total) * 100.0
		var overall_turns := total_turns / float(total)
		var overall_hp := total_hp / float(maxi(1, victory_count))

		print("  %-12s  Win: %5.1f%% (%3d/%d)  Avg Turns: %5.1f  Avg HP left: %5.1f%%" % [
			strat_name, overall_wr, wins, total, overall_turns, overall_hp
		])

	print("")
	print("=" .repeat(75))
	print("SUMMARY BY SCENARIO (across all strategies)")
	print("=" .repeat(75))
	print("")

	for scenario in _scenarios:
		var sname: String = scenario["name"]
		var wins := 0
		var total := 0
		var total_turns := 0.0

		for r in all_results:
			if r["scenario"] != sname:
				continue
			wins += r.victories
			total += r.num_runs
			total_turns += r.avg_turns * r.num_runs

		var overall_wr := float(wins) / float(total) * 100.0
		var overall_turns := total_turns / float(total)

		print("  %-40s  Win: %5.1f%% (%3d/%d)  Turns: %5.1f" % [
			sname, overall_wr, wins, total, overall_turns
		])

	print("")
	print("=" .repeat(75))
	print("STRATEGY BREAKDOWN PER SCENARIO")
	print("=" .repeat(75))
	print("")

	for scenario in _scenarios:
		var sname: String = scenario["name"]
		print("  %s:" % sname)
		for strat_name in _strategies:
			for r in all_results:
				if r["scenario"] == sname and r["strategy"] == strat_name:
					print("    %-12s  Win: %5.1f%%  Turns: %4.1f  HP: %5.1f%%  Defeats: %d" % [
						strat_name, r.win_rate, r.avg_turns, r.avg_hp_remaining_on_victory, r.defeats
					])
		print("")

	print("=" .repeat(75))
	print("DEFEAT ANALYSIS")
	print("=" .repeat(75))
	print("")

	for r in all_results:
		if r.defeats == 0:
			continue
		print("  %s:" % r["combo_name"])
		for cause in r.death_causes:
			var count: int = r.death_causes[cause]
			print("    - First death: %s (%d times)" % [cause, count])

	print("")
	print("=" .repeat(75))
	print("AI DECISION SAMPLES (monster reasoning from first run)")
	print("=" .repeat(75))
	print("")

	for r in all_results:
		var first_run: Dictionary = r.results[0]
		var ai_entries: Array = first_run.get("ai_log", [])
		var monster_decisions := 0
		var samples: Array[String] = []
		for entry in ai_entries:
			if monster_decisions >= 3:
				break
			var reasoning: String = entry.get("reasoning", "")
			var actor: String = entry.get("actor", "")
			var is_party_member := false
			for role in ["Fighter", "Mage", "Priest", "Thief", "Bishop"]:
				if actor.begins_with(role):
					is_party_member = true
					break
			if is_party_member:
				continue
			if reasoning != "" and reasoning != "AI behavior":
				samples.append("    T%s %s: %s" % [str(entry.get("turn", "?")), actor, reasoning])
				monster_decisions += 1
		if not samples.is_empty():
			print("  %s:" % r["combo_name"])
			for s in samples:
				print(s)
			print("")

	print("=" .repeat(75))
	print("Total simulations: %d" % total_runs)
	print("=" .repeat(75))

	get_tree().quit(0)
