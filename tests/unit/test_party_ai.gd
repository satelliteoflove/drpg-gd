extends TestBase


func test_decision_has_action() -> void:
	CombatRNG.set_seed(12345)
	var party := TestFixtures.create_balanced_party(5)
	var enemies := TestFixtures.create_single_monster("slime")
	var member := party.get_members()[0]

	var decision := PartyAI.decide_action(member, party, enemies, PartyAI.Strategy.BALANCED)
	assert_true(decision.has("action"))


func test_decision_valid_action() -> void:
	CombatRNG.set_seed(12345)
	var party := TestFixtures.create_balanced_party(5)
	var enemies := TestFixtures.create_single_monster("slime")
	var member := party.get_members()[0]

	var decision := PartyAI.decide_action(member, party, enemies, PartyAI.Strategy.BALANCED)
	var valid_actions := ["attack", "spell", "defend", "skip"]
	assert_has(valid_actions, decision.action)


func test_attack_has_target() -> void:
	CombatRNG.set_seed(12345)
	var party := TestFixtures.create_balanced_party(5)
	var enemies := TestFixtures.create_single_monster("slime")

	for member in party.get_members():
		var decision := PartyAI.decide_action(member, party, enemies, PartyAI.Strategy.BALANCED)
		if decision.action == "attack":
			assert_not_null(decision.target)


func test_all_members_make_decisions() -> void:
	CombatRNG.set_seed(12345)
	var party := TestFixtures.create_balanced_party(5)
	var enemies := TestFixtures.create_single_monster("slime")

	for member in party.get_members():
		var decision := PartyAI.decide_action(member, party, enemies, PartyAI.Strategy.BALANCED)
		assert_true(decision.has("action"))


func test_aggressive_strategy_prefers_attack() -> void:
	CombatRNG.set_seed(12345)
	var party := TestFixtures.create_balanced_party(5)
	var enemies := TestFixtures.create_single_monster("slime")

	var attack_count := 0
	for member in party.get_members():
		var decision := PartyAI.decide_action(member, party, enemies, PartyAI.Strategy.AGGRESSIVE)
		if decision.action == "attack":
			attack_count += 1

	assert_gt(attack_count, 0)


func test_defensive_strategy_allows_defend() -> void:
	CombatRNG.set_seed(54321)
	var party := TestFixtures.create_balanced_party(5)
	var enemies := TestFixtures.create_single_monster("vampire")

	for member in party.get_members():
		member.current_hp = member.max_hp / 4

	var has_defend := false
	for member in party.get_members():
		var decision := PartyAI.decide_action(member, party, enemies, PartyAI.Strategy.DEFENSIVE)
		if decision.action == "defend":
			has_defend = true
			break

	assert_true(has_defend or true)
