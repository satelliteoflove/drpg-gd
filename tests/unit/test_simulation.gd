extends TestBase


func test_simulation_completes() -> void:
	var party := TestFixtures.create_balanced_party(3)
	var enemies := TestFixtures.create_single_monster("slime")

	var simulator := CombatSimulator.new()
	simulator.setup(party, enemies, 99999)
	var result := simulator.run()

	assert_not_empty(result.keys())


func test_simulation_has_victory_field() -> void:
	var party := TestFixtures.create_balanced_party(3)
	var enemies := TestFixtures.create_single_monster("slime")

	var simulator := CombatSimulator.new()
	simulator.setup(party, enemies, 99999)
	var result := simulator.run()

	assert_true(result.has("victory"))


func test_simulation_has_turns_field() -> void:
	var party := TestFixtures.create_balanced_party(3)
	var enemies := TestFixtures.create_single_monster("slime")

	var simulator := CombatSimulator.new()
	simulator.setup(party, enemies, 99999)
	var result := simulator.run()

	assert_true(result.has("turns"))


func test_simulation_positive_turns() -> void:
	var party := TestFixtures.create_balanced_party(3)
	var enemies := TestFixtures.create_single_monster("slime")

	var simulator := CombatSimulator.new()
	simulator.setup(party, enemies, 99999)
	var result := simulator.run()

	assert_gt(result.turns, 0)


func test_simulation_has_metrics() -> void:
	var party := TestFixtures.create_balanced_party(3)
	var enemies := TestFixtures.create_single_monster("slime")

	var simulator := CombatSimulator.new()
	simulator.setup(party, enemies, 99999)
	var result := simulator.run()

	assert_true(result.has("metrics"))


func test_simulation_determinism() -> void:
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

	assert_eq(result_a.victory, result_b.victory)
	assert_eq(result_a.turns, result_b.turns)


func test_batch_simulation_runs() -> void:
	var party := TestFixtures.create_balanced_party(5)
	var enemies := TestFixtures.create_single_monster("slime")

	var batch := BatchSimulator.new()
	var result := batch.run_batch(party, enemies, 10, 11111)

	assert_eq(result.num_runs, 10)


func test_batch_victories_plus_defeats_equals_runs() -> void:
	var party := TestFixtures.create_balanced_party(5)
	var enemies := TestFixtures.create_single_monster("slime")

	var batch := BatchSimulator.new()
	var result := batch.run_batch(party, enemies, 10, 11111)

	assert_eq(result.victories + result.defeats, 10)


func test_batch_win_rate_valid() -> void:
	var party := TestFixtures.create_balanced_party(5)
	var enemies := TestFixtures.create_single_monster("slime")

	var batch := BatchSimulator.new()
	var result := batch.run_batch(party, enemies, 10, 11111)

	assert_between(result.win_rate, 0.0, 100.0)


func test_batch_avg_turns_positive() -> void:
	var party := TestFixtures.create_balanced_party(5)
	var enemies := TestFixtures.create_single_monster("slime")

	var batch := BatchSimulator.new()
	var result := batch.run_batch(party, enemies, 10, 11111)

	assert_gt(result.avg_turns, 0.0)
