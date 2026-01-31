extends TestBase


func test_balanced_party_not_null() -> void:
	var party := TestFixtures.create_balanced_party(5)
	assert_not_null(party)


func test_balanced_party_has_six_members() -> void:
	var party := TestFixtures.create_balanced_party(5)
	var members := party.get_members()
	assert_eq(members.size(), 6)


func test_balanced_party_correct_level() -> void:
	var party := TestFixtures.create_balanced_party(7)
	var members := party.get_members()
	for member in members:
		assert_eq(member.level, 7)


func test_balanced_party_has_core_classes() -> void:
	var party := TestFixtures.create_balanced_party(5)
	var members := party.get_members()

	var has_fighter := false
	var has_mage := false
	var has_priest := false
	var has_thief := false
	var has_bishop := false

	for member in members:
		match member.character_class:
			CharacterEnums.CharacterClass.FIGHTER: has_fighter = true
			CharacterEnums.CharacterClass.MAGE: has_mage = true
			CharacterEnums.CharacterClass.PRIEST: has_priest = true
			CharacterEnums.CharacterClass.THIEF: has_thief = true
			CharacterEnums.CharacterClass.BISHOP: has_bishop = true

	assert_true(has_fighter and has_mage and has_priest and has_thief and has_bishop)


func test_single_monster_creates_one() -> void:
	var monsters := TestFixtures.create_single_monster("slime")
	assert_eq(monsters.size(), 1)


func test_single_monster_not_null() -> void:
	var monsters := TestFixtures.create_single_monster("slime")
	assert_not_null(monsters[0])


func test_single_monster_correct_name() -> void:
	var monsters := TestFixtures.create_single_monster("slime")
	assert_eq(monsters[0].monster_name, "Slime")


func test_floor_encounter_not_empty() -> void:
	CombatRNG.set_seed(12345)
	var monsters := TestFixtures.create_floor_encounter(3)
	assert_not_empty(monsters)


func test_floor_encounter_reasonable_size() -> void:
	CombatRNG.set_seed(12345)
	var monsters := TestFixtures.create_floor_encounter(3)
	assert_lte(monsters.size(), 5)


func test_floor_encounter_monsters_have_hp() -> void:
	CombatRNG.set_seed(12345)
	var monsters := TestFixtures.create_floor_encounter(3)
	for monster in monsters:
		assert_gt(monster.current_hp, 0)
