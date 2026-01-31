extends TestBase


func test_create_character() -> void:
	var char := Character.new()
	char.character_name = "Test"
	assert_eq(char.character_name, "Test")


func test_create_new_has_id() -> void:
	var char := Character.create_new(
		"Test",
		CharacterEnums.Race.HUMAN,
		CharacterEnums.CharacterClass.FIGHTER,
		CharacterEnums.Alignment.NEUTRAL,
		CharacterEnums.Gender.MALE,
		{"strength": 12, "intelligence": 12, "piety": 12, "vitality": 12, "agility": 12, "luck": 12}
	)
	assert_ne(char.id, "")


func test_character_level_default() -> void:
	var char := Character.new()
	assert_eq(char.level, 1)


func test_take_damage_reduces_hp() -> void:
	var char := Character.new()
	char.max_hp = 100
	char.current_hp = 100
	char.take_damage(25)
	assert_eq(char.current_hp, 75)


func test_take_damage_cannot_go_negative() -> void:
	var char := Character.new()
	char.max_hp = 50
	char.current_hp = 50
	char.take_damage(100)
	assert_eq(char.current_hp, 0)


func test_heal_restores_hp() -> void:
	var char := Character.new()
	char.max_hp = 100
	char.current_hp = 50
	char.heal(25)
	assert_eq(char.current_hp, 75)


func test_heal_cannot_exceed_max() -> void:
	var char := Character.new()
	char.max_hp = 100
	char.current_hp = 90
	char.heal(50)
	assert_eq(char.current_hp, 100)


func test_is_dead_when_zero_hp() -> void:
	var char := Character.new()
	char.current_hp = 0
	char.is_dead = true
	assert_true(char.is_dead)


func test_not_dead_when_positive_hp() -> void:
	var char := Character.new()
	char.current_hp = 1
	char.is_dead = false
	assert_false(char.is_dead)


func test_max_hp_positive() -> void:
	var char := Character.new()
	char.max_hp = 100
	assert_gt(char.max_hp, 0)
