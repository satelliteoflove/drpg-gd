extends Node

const BASE_SEED := 40000
const NUM_RUNS := 100
const PARTY_LEVEL := 7

var victories: int = 0
var defeats: int = 0
var total_turns: int = 0
var behavior_counts: Dictionary = {}
var total_monster_turns: int = 0
var heals_cast: int = 0
var defends_with_healer: int = 0
var defends_without_healer: int = 0
var support_behaviors: int = 0


func _ready() -> void:
	_run_test()
	get_tree().quit()


func _run_test() -> void:
	print("=" .repeat(70))
	print("Support AI + Defend Rework Test")
	print("=" .repeat(70))
	print("")

	var scenarios := [
		{
			"label": "Orc + Orc Warcaster (tank + healer)",
			"monsters": ["orc", "orc", "orc_warcaster"],
		},
		{
			"label": "Goblin x2 + Goblin Shaman (fodder + healer)",
			"monsters": ["goblin", "goblin", "goblin_shaman"],
		},
		{
			"label": "Troll + Orc Warcaster (big tank + healer)",
			"monsters": ["troll", "orc_warcaster"],
		},
		{
			"label": "Minotaur + Orc Warcaster (boss-like + healer)",
			"monsters": ["minotaur", "orc_warcaster"],
		},
		{
			"label": "Orc x3 (no healer control group)",
			"monsters": ["orc", "orc", "orc"],
		},
	]

	for scenario in scenarios:
		_reset_counters()
		print("-" .repeat(70))
		print(scenario.label)
		print("-" .repeat(70))

		var monster_ids: Array[String] = []
		for mid in scenario.monsters:
			monster_ids.append(mid)

		for i in range(NUM_RUNS):
			_run_single_combat(BASE_SEED + i, monster_ids)
			if (i + 1) % 50 == 0:
				print("  ...completed %d/%d runs" % [i + 1, NUM_RUNS])

		_print_results()
		print("")

	print("=" .repeat(70))
	print("Test complete.")
	print("=" .repeat(70))


func _reset_counters() -> void:
	victories = 0
	defeats = 0
	total_turns = 0
	behavior_counts.clear()
	total_monster_turns = 0
	heals_cast = 0
	defends_with_healer = 0
	defends_without_healer = 0
	support_behaviors = 0


func _run_single_combat(seed_value: int, monster_ids: Array[String]) -> void:
	CombatRNG.set_seed(seed_value)
	GameState.current_floor = 6

	var party := TestFixtures.create_balanced_party(PARTY_LEVEL)
	var enemies := TestFixtures.create_monster_group(monster_ids)

	if enemies.is_empty():
		return

	var sim := CombatSimulator.new()
	sim.setup(party, enemies, seed_value)

	var turn_count := 0
	while sim._combat_active and turn_count < 80:
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

	if behavior == "support":
		support_behaviors += 1

	if action == "defend":
		var reasoning: String = turn_data.get("reasoning", "")
		if "healer" in reasoning:
			defends_with_healer += 1
		else:
			defends_without_healer += 1

	if action == "spell":
		var spell_id: String = turn_data.get("spell_id", "")
		if "heal" in spell_id or "greater_heal" in spell_id or "major_heal" in spell_id:
			heals_cast += 1

	var messages: Array = turn_data.get("messages", [])
	for msg in messages:
		if msg is String and "heal" in msg.to_lower():
			pass


func _print_results() -> void:
	print("  Runs: %d | Victories: %d | Defeats: %d | Win Rate: %.1f%%" % [
		NUM_RUNS, victories, defeats, float(victories) / NUM_RUNS * 100.0])
	print("  Avg Turns: %.1f" % (float(total_turns) / maxi(1, NUM_RUNS)))
	print("")

	print("  Behavior Distribution (%d monster turns):" % total_monster_turns)
	var sorted_behaviors := behavior_counts.keys()
	sorted_behaviors.sort()
	for b in sorted_behaviors:
		var count: int = behavior_counts[b]
		var pct := float(count) / maxi(1, total_monster_turns) * 100.0
		print("    %-15s %5d (%5.1f%%)" % [b, count, pct])

	print("")
	print("  Support & Defend Metrics:")
	print("    Support behaviors:    %d" % support_behaviors)
	print("    Heals cast:           %d" % heals_cast)
	print("    Defends (w/ healer):  %d" % defends_with_healer)
	print("    Defends (no healer):  %d" % defends_without_healer)
