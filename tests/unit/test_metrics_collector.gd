extends TestBase


func test_record_damage() -> void:
	var metrics := MetricsCollector.new()
	metrics.record_damage("Fighter", "Goblin", 25)
	metrics.record_damage("Fighter", "Slime", 15)

	var data := metrics.to_dict()
	assert_eq(data.damage_dealt.get("Fighter", 0), 40)


func test_record_damage_multiple_actors() -> void:
	var metrics := MetricsCollector.new()
	metrics.record_damage("Fighter", "Goblin", 25)
	metrics.record_damage("Mage", "Goblin", 30)

	var data := metrics.to_dict()
	assert_eq(data.damage_dealt.get("Fighter", 0), 25)
	assert_eq(data.damage_dealt.get("Mage", 0), 30)


func test_record_healing() -> void:
	var metrics := MetricsCollector.new()
	metrics.record_healing("Priest", "Fighter", 20)
	metrics.record_healing("Priest", "Mage", 15)

	var data := metrics.to_dict()
	assert_eq(data.healing_done.get("Priest", 0), 35)


func test_record_spell() -> void:
	var metrics := MetricsCollector.new()
	metrics.record_spell("Mage", "fireball")
	metrics.record_spell("Mage", "fireball")
	metrics.record_spell("Mage", "ice_bolt")

	var data := metrics.to_dict()
	var mage_spells: Dictionary = data.spells_cast.get("Mage", {})
	assert_eq(mage_spells.get("fireball", 0), 2)
	assert_eq(mage_spells.get("ice_bolt", 0), 1)


func test_record_status() -> void:
	var metrics := MetricsCollector.new()
	metrics.record_status("Goblin", "Fighter", CharacterEnums.StatusEffect.POISONED)

	var data := metrics.to_dict()
	var key := "Goblin->Fighter"
	assert_true(data.status_effects_applied.has(key))


func test_record_death() -> void:
	var metrics := MetricsCollector.new()
	metrics.record_death("Goblin", 3)
	metrics.record_death("Slime", 5)

	var data := metrics.to_dict()
	var deaths_array: Array = data.deaths
	assert_eq(deaths_array.size(), 2)


func test_death_contains_correct_data() -> void:
	var metrics := MetricsCollector.new()
	metrics.record_death("Goblin", 3)

	var data := metrics.to_dict()
	var deaths_array: Array = data.deaths
	var first_death: Dictionary = deaths_array[0]
	assert_eq(first_death.get("name", ""), "Goblin")
	assert_eq(first_death.get("turn", 0), 3)


func test_empty_metrics() -> void:
	var metrics := MetricsCollector.new()
	var data := metrics.to_dict()

	assert_true(data.damage_dealt.is_empty())
	assert_true(data.healing_done.is_empty())
	assert_true(data.spells_cast.is_empty())
	assert_true(data.deaths.is_empty())
