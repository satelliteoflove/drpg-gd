extends Node

const BASE_SEED := 30000
const NUM_RUNS := 100

var behavior_counts: Dictionary = {}
var fumble_count: int = 0
var total_monster_turns: int = 0
var target_sleeping: int = 0
var target_charmed: int = 0
var target_confused: int = 0
var target_defending: int = 0
var target_paralyzed: int = 0
var target_clean: int = 0
var victories: int = 0
var defeats: int = 0
var total_turns: int = 0
var total_party_hp_pct: float = 0.0


func _ready() -> void:
	_run_test()
	get_tree().quit()


func _run_test() -> void:
	print("=" .repeat(70))
	print("Monster AI Behavior & Targeting Test")
	print("=" .repeat(70))
	print("")

	var floor_tiers := [
		{"floors": [1, 2], "level": 3, "label": "Floors 1-2 (Tutorial)"},
		{"floors": [3, 4], "level": 5, "label": "Floors 3-4 (Synergy)"},
		{"floors": [5, 6], "level": 7, "label": "Floors 5-6 (Specialist)"},
		{"floors": [7, 8], "level": 10, "label": "Floors 7-8 (Elite)"},
	]

	for tier in floor_tiers:
		_reset_counters()
		print("-" .repeat(70))
		print(tier.label)
		print("-" .repeat(70))

		var floor_count: int = tier.floors.size()
		var runs_per_floor: int = NUM_RUNS / floor_count
		for floor_num in tier.floors:
			for i in range(runs_per_floor):
				_run_single_combat(BASE_SEED + floor_num * 1000 + i, floor_num, tier.level)

		_print_tier_results(tier.label, runs_per_floor * tier.floors.size())
		print("")

	_test_encounter_templates()

	print("=" .repeat(70))
	print("Test complete.")
	print("=" .repeat(70))


func _test_encounter_templates() -> void:
	print("=" .repeat(70))
	print("Encounter Template Distribution Test")
	print("=" .repeat(70))
	print("")

	var template_counts: Dictionary = {}
	var random_count: int = 0
	var total_tests: int = 500

	for floor_num in [1, 2, 3, 4, 5, 6, 7, 8]:
		template_counts.clear()
		random_count = 0
		var floor_tests: int = total_tests / 8

		for i in range(floor_tests):
			var monsters := _generate_template_test(floor_num)
			var key := _identify_encounter(monsters)
			if key == "random":
				random_count += 1
			else:
				template_counts[key] = template_counts.get(key, 0) + 1

		var template_total: int = floor_tests - random_count
		print("  Floor %d: %d template (%.0f%%), %d random (%.0f%%)" % [
			floor_num, template_total,
			float(template_total) / floor_tests * 100.0,
			random_count,
			float(random_count) / floor_tests * 100.0])
		var sorted_keys := template_counts.keys()
		sorted_keys.sort()
		for key in sorted_keys:
			print("    %-25s %d" % [key, template_counts[key]])
	print("")


func _generate_template_test(floor_num: int) -> Array[String]:
	var valid_templates: Array[Dictionary] = []
	for template in EnemyManager._encounter_templates:
		if floor_num >= template.min_floor and floor_num <= template.max_floor:
			valid_templates.append(template)

	if valid_templates.is_empty() or randf() >= EnemyManager.TEMPLATE_CHANCE:
		return ["random"]

	var weighted: Array = []
	for template in valid_templates:
		weighted.append({"item": template, "weight": float(template.weight)})
	var picked: Dictionary = CombatEvaluator.weighted_random_pick(weighted)
	if picked.is_empty():
		return ["random"]

	var variants: Array = picked.variants
	if variants.is_empty():
		return ["random"]
	var monster_ids: Array = variants[randi() % variants.size()]
	var result: Array[String] = []
	for mid in monster_ids:
		result.append(mid)
	return result


func _identify_encounter(monsters: Array[String]) -> String:
	if monsters.size() == 1 and monsters[0] == "random":
		return "random"
	var sorted := monsters.duplicate()
	sorted.sort()
	return ", ".join(sorted)


func _reset_counters() -> void:
	behavior_counts.clear()
	fumble_count = 0
	total_monster_turns = 0
	target_sleeping = 0
	target_charmed = 0
	target_confused = 0
	target_defending = 0
	target_paralyzed = 0
	target_clean = 0
	victories = 0
	defeats = 0
	total_turns = 0
	total_party_hp_pct = 0.0


func _run_single_combat(seed_value: int, floor_num: int, party_level: int) -> void:
	CombatRNG.set_seed(seed_value)

	GameState.current_floor = floor_num

	var party := TestFixtures.create_balanced_party(party_level)
	var enemies := TestFixtures.create_floor_encounter(floor_num)

	if enemies.is_empty():
		return

	var sim := CombatSimulator.new()
	sim.setup(party, enemies, seed_value)

	var turn_count := 0
	var max_sim_turns := 80

	while sim._combat_active and turn_count < max_sim_turns:
		var turn_data := sim.step()
		if turn_data.is_empty():
			break
		turn_count += 1
		_analyze_turn(turn_data)

	total_turns += turn_count

	var all_dead := true
	for e in sim.enemies:
		if not e.is_dead:
			all_dead = false
			break
	if all_dead:
		victories += 1
	else:
		defeats += 1

	var hp_remaining := 0.0
	var hp_total := 0.0
	for member in party.get_members():
		hp_total += member.max_hp
		if not member.is_dead:
			hp_remaining += member.current_hp
	if hp_total > 0:
		total_party_hp_pct += hp_remaining / hp_total * 100.0


func _analyze_turn(turn_data: Dictionary) -> void:
	var is_player: bool = turn_data.get("is_player", false)
	if is_player:
		return

	var skipped: bool = turn_data.get("skipped", false)
	if skipped:
		return

	var action: String = turn_data.get("action", "")
	if action.begins_with("mental") or action.begins_with("berserk"):
		return

	total_monster_turns += 1

	var behavior: String = turn_data.get("behavior", "unknown")
	behavior_counts[behavior] = behavior_counts.get(behavior, 0) + 1

	var fumbled: bool = turn_data.get("fumbled", false)
	if fumbled:
		fumble_count += 1

	var target_statuses: Array = turn_data.get("target_statuses", [])
	if target_statuses.is_empty():
		target_clean += 1
	else:
		for status in target_statuses:
			match status:
				"Asleep":
					target_sleeping += 1
				"Charmed":
					target_charmed += 1
				"Confused":
					target_confused += 1
				"Paralyzed", "Stoned":
					target_paralyzed += 1



func _print_tier_results(_label: String, num_runs: int) -> void:
	print("  Runs: %d | Victories: %d | Defeats: %d | Win Rate: %.1f%%" % [
		num_runs, victories, defeats, float(victories) / maxi(1, num_runs) * 100.0])
	print("  Avg Turns: %.1f | Avg Party HP Remaining: %.1f%%" % [
		float(total_turns) / maxi(1, num_runs),
		total_party_hp_pct / maxi(1, num_runs)])
	print("")

	print("  Behavior Distribution (%d monster turns):" % total_monster_turns)
	var sorted_behaviors := behavior_counts.keys()
	sorted_behaviors.sort()
	for b in sorted_behaviors:
		var count: int = behavior_counts[b]
		var pct := float(count) / maxi(1, total_monster_turns) * 100.0
		print("    %-15s %5d (%5.1f%%)" % [b, count, pct])

	if fumble_count > 0:
		print("  Fumbles: %d (%.1f%% of monster turns)" % [
			fumble_count, float(fumble_count) / maxi(1, total_monster_turns) * 100.0])
	else:
		print("  Fumbles: 0")

	print("")
	print("  Target Status When Attacked:")
	var total_targeted := target_sleeping + target_charmed + target_confused + target_paralyzed + target_clean
	if total_targeted > 0:
		print("    Clean (no status): %d (%.1f%%)" % [target_clean, float(target_clean) / total_targeted * 100.0])
		if target_sleeping > 0:
			print("    Sleeping:          %d (%.1f%%)" % [target_sleeping, float(target_sleeping) / total_targeted * 100.0])
		if target_charmed > 0:
			print("    Charmed:           %d (%.1f%%)" % [target_charmed, float(target_charmed) / total_targeted * 100.0])
		if target_confused > 0:
			print("    Confused:          %d (%.1f%%)" % [target_confused, float(target_confused) / total_targeted * 100.0])
		if target_paralyzed > 0:
			print("    Paralyzed/Stoned:  %d (%.1f%%)" % [target_paralyzed, float(target_paralyzed) / total_targeted * 100.0])
	else:
		print("    No targeting data")
