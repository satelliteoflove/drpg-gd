extends SceneTree

const CombatRNG = preload("res://autoload/combat_rng.gd")
const CombatSimulator = preload("res://systems/simulation/combat_simulator.gd")
const BatchSimulator = preload("res://systems/simulation/batch_simulator.gd")
const TestFixtures = preload("res://systems/simulation/test_fixtures.gd")
const AIDecisionLog = preload("res://systems/simulation/ai_decision_log.gd")
const MetricsCollector = preload("res://systems/simulation/metrics_collector.gd")
const PartyAI = preload("res://systems/simulation/party_ai.gd")

var _tests_passed := 0
var _tests_failed := 0
var _test_errors: Array[String] = []


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("=" .repeat(60))
	print("Combat Simulator Test Suite")
	print("=" .repeat(60))
	print("")

	_test_combat_rng_determinism()
	_test_combat_rng_different_seeds()
	_test_ai_decision_log()
	_test_metrics_collector()
	_test_fixtures_balanced_party()
	_test_fixtures_single_monster()
	_test_fixtures_floor_encounter()
	_test_single_simulation()
	_test_simulation_determinism()
	_test_batch_simulation()
	_test_party_ai_decisions()

	print("")
	print("=" .repeat(60))
	print("Results: %d passed, %d failed" % [_tests_passed, _tests_failed])
	print("=" .repeat(60))

	if not _test_errors.is_empty():
		print("")
		print("Errors:")
		for err in _test_errors:
			print("  - %s" % err)

	quit(0 if _tests_failed == 0 else 1)


func _test_combat_rng_determinism() -> void:
	print("Test: CombatRNG determinism (same seed = same results)")

	CombatRNG.set_seed(12345)
	var results_a: Array[int] = []
	for i in range(10):
		results_a.append(CombatRNG.randi())

	CombatRNG.set_seed(12345)
	var results_b: Array[int] = []
	for i in range(10):
		results_b.append(CombatRNG.randi())

	var all_match := true
	for i in range(10):
		if results_a[i] != results_b[i]:
			all_match = false
			break

	if all_match:
		_pass("Same seed produces identical sequence")
	else:
		_fail("RNG sequences differ with same seed")


func _test_combat_rng_different_seeds() -> void:
	print("Test: CombatRNG different seeds produce different results")

	CombatRNG.set_seed(11111)
	var val_a := CombatRNG.randi()

	CombatRNG.set_seed(22222)
	var val_b := CombatRNG.randi()

	if val_a != val_b:
		_pass("Different seeds produce different values")
	else:
		_fail("Different seeds produced same value (unlikely but possible)")


func _test_ai_decision_log() -> void:
	print("Test: AIDecisionLog records and exports decisions")

	var decision_log := AIDecisionLog.new()
	decision_log.log_decision(1, "Goblin", {"action": "attack", "target": "Fighter"})
	decision_log.log_decision(1, "Slime", {"action": "defend", "target": null})
	decision_log.log_decision(2, "Goblin", {"action": "spell", "target": "Priest", "spell": "fireball"})

	var entries := decision_log.get_entries()
	if entries.size() != 3:
		_fail("Expected 3 entries, got %d" % entries.size())
		return

	if entries[0].actor != "Goblin" or entries[0].turn != 1:
		_fail("First entry has wrong data")
		return

	var json := decision_log.to_json()
	if json.is_empty():
		_fail("JSON export failed")
		return

	decision_log.clear()
	if not decision_log.get_entries().is_empty():
		_fail("Clear didn't empty decision_log")
		return

	_pass("AIDecisionLog works correctly")


func _test_metrics_collector() -> void:
	print("Test: MetricsCollector tracks combat stats")

	var metrics := MetricsCollector.new()
	metrics.record_damage("Fighter", "Goblin", 25)
	metrics.record_damage("Fighter", "Slime", 15)
	metrics.record_damage("Mage", "Goblin", 30)
	metrics.record_healing("Priest", "Fighter", 20)
	metrics.record_spell("Mage", "fireball")
	metrics.record_status("Goblin", "Fighter", 1)
	metrics.record_death("Goblin", 3)

	var data := metrics.to_dict()

	if data.damage_dealt.get("Fighter", 0) != 40:
		_fail("Fighter damage should be 40, got %d" % data.damage_dealt.get("Fighter", 0))
		return

	if data.damage_dealt.get("Mage", 0) != 30:
		_fail("Mage damage should be 30")
		return

	if data.healing_done.get("Priest", 0) != 20:
		_fail("Priest healing should be 20")
		return

	var mage_spells: Dictionary = data.spells_cast.get("Mage", {})
	if mage_spells.get("fireball", 0) != 1:
		_fail("Mage should have 1 fireball cast")
		return

	var deaths_array: Array = data.deaths
	if deaths_array.size() != 1:
		_fail("Expected 1 death, got %d" % deaths_array.size())
		return
	var first_death: Dictionary = deaths_array[0]
	if first_death.get("name", "") != "Goblin":
		_fail("First death should be Goblin")
		return

	_pass("MetricsCollector tracks all stats")


func _test_fixtures_balanced_party() -> void:
	print("Test: TestFixtures creates balanced party")

	var party := TestFixtures.create_balanced_party(5)

	if party == null:
		_fail("Party is null")
		return

	var members := party.get_members()
	if members.size() != 4:
		_fail("Expected 4 members, got %d" % members.size())
		return

	var has_fighter := false
	var has_priest := false
	var has_mage := false
	var has_thief := false

	for member in members:
		if member.level != 5:
			_fail("Member %s has wrong level: %d" % [member.character_name, member.level])
			return
		match member.character_class:
			0: has_fighter = true
			1: has_mage = true
			2: has_priest = true
			3: has_thief = true

	if not (has_fighter and has_priest and has_mage and has_thief):
		_fail("Party missing required classes")
		return

	_pass("Balanced party has 4 members with correct classes and levels")


func _test_fixtures_single_monster() -> void:
	print("Test: TestFixtures creates single monster")

	var monsters := TestFixtures.create_single_monster("slime")

	if monsters.size() != 1:
		_fail("Expected 1 monster, got %d" % monsters.size())
		return

	if monsters[0] == null:
		_fail("Monster is null")
		return

	if monsters[0].monster_name != "Slime":
		_fail("Wrong monster name: %s" % monsters[0].monster_name)
		return

	_pass("Single monster fixture works")


func _test_fixtures_floor_encounter() -> void:
	print("Test: TestFixtures creates floor encounter")

	var monsters := TestFixtures.create_floor_encounter(3)

	if monsters.is_empty():
		_fail("No monsters generated for floor 3")
		return

	if monsters.size() > 5:
		_fail("Too many monsters: %d" % monsters.size())
		return

	for monster in monsters:
		if monster == null:
			_fail("Null monster in encounter")
			return
		if monster.current_hp <= 0:
			_fail("Monster has no HP")
			return

	_pass("Floor encounter creates valid monsters")


func _test_single_simulation() -> void:
	print("Test: Single simulation runs to completion")

	var party := TestFixtures.create_balanced_party(3)
	var enemies := TestFixtures.create_single_monster("slime")

	var simulator := CombatSimulator.new()
	simulator.setup(party, enemies, 99999)
	var result := simulator.run()

	if result.is_empty():
		_fail("Simulation returned empty result")
		return

	if not result.has("victory"):
		_fail("Result missing 'victory' field")
		return

	if not result.has("turns"):
		_fail("Result missing 'turns' field")
		return

	if result.turns <= 0:
		_fail("Simulation had 0 turns")
		return

	if result.turns > 100:
		_fail("Simulation hit max turns limit")
		return

	if not result.has("metrics"):
		_fail("Result missing 'metrics' field")
		return

	_pass("Simulation completed in %d turns, victory=%s" % [result.turns, result.victory])


func _test_simulation_determinism() -> void:
	print("Test: Simulation determinism (same inputs = same outcome)")

	var seed_value := 54321

	CombatRNG.set_seed(11111)
	var party_a := TestFixtures.create_balanced_party(5)
	var enemies_a := TestFixtures.create_floor_encounter(2)

	CombatRNG.set_seed(11111)
	var party_b := TestFixtures.create_balanced_party(5)
	var enemies_b := TestFixtures.create_floor_encounter(2)

	var sim_a := CombatSimulator.new()
	sim_a.setup(party_a, enemies_a, seed_value)
	var result_a := sim_a.run()

	var sim_b := CombatSimulator.new()
	sim_b.setup(party_b, enemies_b, seed_value)
	var result_b := sim_b.run()

	if result_a.victory != result_b.victory:
		_fail("Victory outcome differs: %s vs %s" % [result_a.victory, result_b.victory])
		return

	if result_a.turns != result_b.turns:
		_fail("Turn count differs: %d vs %d" % [result_a.turns, result_b.turns])
		return

	if result_a.party_survivors != result_b.party_survivors:
		_fail("Survivors differ")
		return

	_pass("Identical seeds produce identical combat outcomes")


func _test_batch_simulation() -> void:
	print("Test: Batch simulation runs multiple combats")

	var party := TestFixtures.create_balanced_party(5)
	var enemies := TestFixtures.create_single_monster("slime")

	var batch := BatchSimulator.new()
	var result := batch.run_batch(party, enemies, 10, 11111)

	if result.num_runs != 10:
		_fail("Expected 10 runs, got %d" % result.num_runs)
		return

	if result.victories + result.defeats != 10:
		_fail("Victories + defeats should equal 10")
		return

	if result.win_rate < 0.0 or result.win_rate > 100.0:
		_fail("Win rate out of range: %.1f" % result.win_rate)
		return

	if result.avg_turns <= 0:
		_fail("Average turns should be positive")
		return

	_pass("Batch ran 10 simulations, win rate: %.1f%%, avg turns: %.1f" % [result.win_rate, result.avg_turns])


func _test_party_ai_decisions() -> void:
	print("Test: PartyAI makes valid decisions")

	var party := TestFixtures.create_balanced_party(5)
	var enemies := TestFixtures.create_single_monster("slime")

	for member in party.get_members():
		var decision := PartyAI.decide_action(member, party, enemies, PartyAI.Strategy.BALANCED)

		if not decision.has("action"):
			_fail("Decision missing 'action' for %s" % member.character_name)
			return

		var valid_actions := ["attack", "spell", "defend", "skip"]
		if not decision.action in valid_actions:
			_fail("Invalid action '%s' for %s" % [decision.action, member.character_name])
			return

		if decision.action == "attack" and decision.target == null:
			_fail("Attack with no target for %s" % member.character_name)
			return

	_pass("All party members make valid decisions")


func _pass(msg: String) -> void:
	print("  PASS: %s" % msg)
	_tests_passed += 1


func _fail(msg: String) -> void:
	print("  FAIL: %s" % msg)
	_tests_failed += 1
	_test_errors.append(msg)
