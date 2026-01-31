extends TestBase


func test_determinism_same_seed() -> void:
	CombatRNG.set_seed(12345)
	var results_a: Array[int] = []
	for i in range(10):
		results_a.append(CombatRNG.randi())

	CombatRNG.set_seed(12345)
	var results_b: Array[int] = []
	for i in range(10):
		results_b.append(CombatRNG.randi())

	for i in range(10):
		assert_eq(results_a[i], results_b[i], "Sequence mismatch at index %d" % i)


func test_different_seeds_differ() -> void:
	CombatRNG.set_seed(11111)
	var val_a := CombatRNG.randi()

	CombatRNG.set_seed(22222)
	var val_b := CombatRNG.randi()

	assert_ne(val_a, val_b, "Different seeds should produce different values")


func test_randf_range() -> void:
	CombatRNG.set_seed(99999)
	for i in range(100):
		var val := CombatRNG.randf()
		assert_gte(val, 0.0)
		assert_lt(val, 1.0)


func test_randi_range() -> void:
	CombatRNG.set_seed(88888)
	for i in range(100):
		var val := CombatRNG.randi_range(5, 10)
		assert_gte(val, 5)
		assert_lte(val, 10)


func test_randf_range_bounds() -> void:
	CombatRNG.set_seed(77777)
	for i in range(100):
		var val := CombatRNG.randf_range(2.5, 7.5)
		assert_gte(val, 2.5)
		assert_lte(val, 7.5)


func test_sequence_not_constant() -> void:
	CombatRNG.set_seed(66666)
	var first := CombatRNG.randi()
	var found_different := false
	for i in range(100):
		if CombatRNG.randi() != first:
			found_different = true
			break
	assert_true(found_different, "RNG should produce varying values")
