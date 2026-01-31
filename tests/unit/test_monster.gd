extends TestBase


func test_init_combat_sets_hp() -> void:
	var monster := Monster.new()
	monster.max_hp = 50
	monster.init_combat()
	assert_eq(monster.current_hp, 50)


func test_init_combat_sets_mp() -> void:
	var monster := Monster.new()
	monster.max_mp = 20
	monster.init_combat()
	assert_eq(monster.current_mp, 20)


func test_init_combat_not_dead() -> void:
	var monster := Monster.new()
	monster.max_hp = 50
	monster.init_combat()
	assert_false(monster.is_dead)


func test_take_damage_reduces_hp() -> void:
	var monster := Monster.new()
	monster.max_hp = 50
	monster.init_combat()
	monster.take_damage(20)
	assert_eq(monster.current_hp, 30)


func test_take_damage_kills_at_zero() -> void:
	var monster := Monster.new()
	monster.max_hp = 50
	monster.init_combat()
	monster.take_damage(50)
	assert_true(monster.is_dead)


func test_defending_halves_damage() -> void:
	var monster := Monster.new()
	monster.max_hp = 100
	monster.init_combat()
	monster.is_defending = true
	monster.take_damage(40)
	assert_eq(monster.current_hp, 80)


func test_duplicate_for_combat_creates_copy() -> void:
	var monster := Monster.new()
	monster.monster_name = "Goblin"
	monster.max_hp = 30
	var copy := monster.duplicate_for_combat()
	assert_eq(copy.monster_name, "Goblin")
	assert_eq(copy.current_hp, 30)


func test_duplicate_has_different_combat_id() -> void:
	CombatRNG.set_seed(12345)
	var monster := Monster.new()
	monster.max_hp = 30
	var copy1 := monster.duplicate_for_combat()
	var copy2 := monster.duplicate_for_combat()
	assert_ne(copy1.combat_id, copy2.combat_id)


func test_can_act_when_alive() -> void:
	var monster := Monster.new()
	monster.max_hp = 50
	monster.init_combat()
	assert_true(monster.can_act())


func test_cannot_act_when_dead() -> void:
	var monster := Monster.new()
	monster.max_hp = 50
	monster.init_combat()
	monster.take_damage(100)
	assert_false(monster.can_act())
