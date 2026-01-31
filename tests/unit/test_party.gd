extends TestBase


func test_new_party_empty() -> void:
	var party := Party.new()
	assert_true(party.is_empty())


func test_add_member() -> void:
	var party := Party.new()
	var char := Character.new()
	char.character_name = "Fighter"
	party.add_member(char)
	assert_eq(party.get_members().size(), 1)


func test_remove_member() -> void:
	var party := Party.new()
	var char := Character.new()
	party.add_member(char)
	party.remove_member(char.id)
	assert_true(party.is_empty())


func test_get_members_returns_all() -> void:
	var party := Party.new()
	for i in range(4):
		var char := Character.create_new(
			"Char%d" % i,
			CharacterEnums.Race.HUMAN,
			CharacterEnums.CharacterClass.FIGHTER,
			CharacterEnums.Alignment.NEUTRAL,
			CharacterEnums.Gender.MALE,
			{"strength": 12, "intelligence": 12, "piety": 12, "vitality": 12, "agility": 12, "luck": 12}
		)
		party.add_member(char)
	assert_eq(party.get_members().size(), 4)


func test_starting_gold_zero() -> void:
	var party := Party.new()
	assert_eq(party.gold, 0)


func test_add_gold() -> void:
	var party := Party.new()
	party.add_gold(100)
	assert_eq(party.gold, 100)


func test_spend_gold_success() -> void:
	var party := Party.new()
	party.add_gold(100)
	var success := party.spend_gold(50)
	assert_true(success)
	assert_eq(party.gold, 50)


func test_spend_gold_insufficient() -> void:
	var party := Party.new()
	party.add_gold(30)
	var success := party.spend_gold(50)
	assert_false(success)
	assert_eq(party.gold, 30)


func test_get_alive_members() -> void:
	var party := Party.new()
	var alive := Character.new()
	alive.current_hp = 50
	alive.is_dead = false
	var dead := Character.new()
	dead.current_hp = 0
	dead.is_dead = true

	party.add_member(alive)
	party.add_member(dead)

	var living: Array[Character] = party.get_alive_members()
	assert_eq(living.size(), 1)


func test_is_wiped_when_all_dead() -> void:
	var party := Party.new()
	var char1 := Character.new()
	char1.current_hp = 0
	char1.is_dead = true
	var char2 := Character.new()
	char2.current_hp = 0
	char2.is_dead = true

	party.add_member(char1)
	party.add_member(char2)

	assert_true(party.is_wiped())
