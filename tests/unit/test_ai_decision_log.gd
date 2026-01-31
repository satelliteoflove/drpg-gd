extends TestBase


func test_log_single_decision() -> void:
	var decision_log := AIDecisionLog.new()
	decision_log.log_decision(1, "Goblin", {"action": "attack", "target": "Fighter"})

	var entries := decision_log.get_entries()
	assert_eq(entries.size(), 1)


func test_log_multiple_decisions() -> void:
	var decision_log := AIDecisionLog.new()
	decision_log.log_decision(1, "Goblin", {"action": "attack", "target": "Fighter"})
	decision_log.log_decision(1, "Slime", {"action": "defend", "target": null})
	decision_log.log_decision(2, "Goblin", {"action": "spell", "target": "Priest"})

	var entries := decision_log.get_entries()
	assert_eq(entries.size(), 3)


func test_entry_data_correct() -> void:
	var decision_log := AIDecisionLog.new()
	decision_log.log_decision(1, "Goblin", {"action": "attack", "target": "Fighter"})

	var entries := decision_log.get_entries()
	assert_eq(entries[0].actor, "Goblin")
	assert_eq(entries[0].turn, 1)
	assert_eq(entries[0].action, "attack")


func test_to_json_not_empty() -> void:
	var decision_log := AIDecisionLog.new()
	decision_log.log_decision(1, "Goblin", {"action": "attack"})

	var json := decision_log.to_json()
	assert_ne(json, "")


func test_clear_removes_all() -> void:
	var decision_log := AIDecisionLog.new()
	decision_log.log_decision(1, "Goblin", {"action": "attack"})
	decision_log.log_decision(2, "Slime", {"action": "defend"})

	decision_log.clear()
	assert_empty(decision_log.get_entries())


func test_empty_log() -> void:
	var decision_log := AIDecisionLog.new()
	assert_empty(decision_log.get_entries())


func test_entries_preserve_order() -> void:
	var decision_log := AIDecisionLog.new()
	decision_log.log_decision(1, "First", {})
	decision_log.log_decision(2, "Second", {})
	decision_log.log_decision(3, "Third", {})

	var entries := decision_log.get_entries()
	assert_eq(entries[0].actor, "First")
	assert_eq(entries[1].actor, "Second")
	assert_eq(entries[2].actor, "Third")
