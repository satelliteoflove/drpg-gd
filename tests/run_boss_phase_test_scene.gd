extends Node

const BASE_SEED := 50000
const NUM_RUNS := 50

var phase_transitions: Dictionary = {}
var phase_turn_counts: Dictionary = {}
var warnings_seen: int = 0
var victories: int = 0
var defeats: int = 0
var total_turns: int = 0


func _ready() -> void:
	_run_test()
	get_tree().quit()


func _run_test() -> void:
	print("=" .repeat(70))
	print("Boss Phase System Test")
	print("=" .repeat(70))
	print("")

	var bosses := [
		{"id": "boss_broodmother", "label": "Broodmother (Floor 2)", "level": 3, "minions": ["spider", "spider"]},
		{"id": "boss_ironjaw", "label": "Ironjaw (Floor 4)", "level": 5, "minions": ["orc", "bandit"]},
		{"id": "boss_lich", "label": "Nethris the Lich (Floor 6)", "level": 7, "minions": ["ghost", "skeleton_mage"]},
		{"id": "boss_drake", "label": "Vrakthorne the Drake (Floor 8)", "level": 9, "minions": ["dark_mage", "troll"]},
	]

	for boss_data in bosses:
		_reset_counters()
		print("-" .repeat(70))
		print(boss_data.label)
		print("-" .repeat(70))

		var minion_ids: Array[String] = []
		for mid in boss_data.minions:
			minion_ids.append(mid)

		for i in range(NUM_RUNS):
			_run_boss_fight(BASE_SEED + i, boss_data.id, minion_ids, boss_data.level)

		_print_results(boss_data.label)
		print("")

	print("=" .repeat(70))
	print("Test complete.")
	print("=" .repeat(70))


func _reset_counters() -> void:
	phase_transitions.clear()
	phase_turn_counts.clear()
	warnings_seen = 0
	victories = 0
	defeats = 0
	total_turns = 0


func _run_boss_fight(seed_value: int, boss_id: String, minion_ids: Array[String], party_level: int) -> void:
	CombatRNG.set_seed(seed_value)
	GameState.current_floor = 8

	var party := TestFixtures.create_balanced_party(party_level)
	var monster_ids: Array[String] = [boss_id]
	monster_ids.append_array(minion_ids)
	var enemies := TestFixtures.create_monster_group(monster_ids)

	if enemies.is_empty():
		return

	var sim := CombatSimulator.new()
	sim.setup(party, enemies, seed_value)

	var boss: Monster = null
	for e in sim.enemies:
		if e.is_boss:
			boss = e
			break

	var turn_count := 0
	var last_phase := 0

	while sim._combat_active and turn_count < 100:
		var turn_data := sim.step()
		if turn_data.is_empty():
			break
		turn_count += 1

		var phase_msgs: Array = turn_data.get("phase_messages", [])
		for msg in phase_msgs:
			if msg is String and not msg.begins_with("__"):
				if "warning" in msg.to_lower() or "..." in msg:
					warnings_seen += 1

		var bp: int = turn_data.get("boss_phase", -1)
		if bp > last_phase and boss != null:
			var key := "Phase %d -> %d" % [last_phase, bp]
			phase_transitions[key] = phase_transitions.get(key, 0) + 1
			phase_turn_counts[key] = phase_turn_counts.get(key, 0) + turn_count
			last_phase = bp

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


func _print_results(_label: String) -> void:
	print("  Runs: %d | Victories: %d | Defeats: %d | Win Rate: %.1f%%" % [
		NUM_RUNS, victories, defeats, float(victories) / NUM_RUNS * 100.0])
	print("  Avg Turns: %.1f" % (float(total_turns) / maxi(1, NUM_RUNS)))
	print("")

	print("  Phase Transitions:")
	if phase_transitions.is_empty():
		print("    None (boss died before phase change)")
	else:
		var sorted_keys := phase_transitions.keys()
		sorted_keys.sort()
		for key in sorted_keys:
			var count: int = phase_transitions[key]
			var avg_turn := float(phase_turn_counts[key]) / maxi(1, count)
			print("    %-20s %3d times (avg turn: %.1f)" % [key, count, avg_turn])

	print("  Warnings telegraphed: %d" % warnings_seen)
