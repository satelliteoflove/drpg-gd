extends TestBase


func test_create_weapon() -> void:
	var weapon := Item.create_weapon("sword_1", "Iron Sword", "1d8", 0, 100)
	assert_eq(weapon.item_name, "Iron Sword")
	assert_eq(weapon.item_type, Item.ItemType.WEAPON)


func test_weapon_damage_dice() -> void:
	var weapon := Item.create_weapon("sword_1", "Iron Sword", "1d8", 0, 100)
	assert_eq(weapon.damage_dice, "1d8")


func test_weapon_sell_price_half() -> void:
	var weapon := Item.create_weapon("sword_1", "Iron Sword", "1d8", 0, 100)
	assert_eq(weapon.sell_price, 50)


func test_create_armor() -> void:
	var armor := Item.create_armor("armor_1", "Chain Mail", Item.ItemType.ARMOR, 5, -1, 200)
	assert_eq(armor.item_name, "Chain Mail")
	assert_eq(armor.defense_bonus, 5)


func test_create_consumable() -> void:
	var potion := Item.create_consumable("potion_1", "Health Potion", 50, 0, 25)
	assert_eq(potion.item_type, Item.ItemType.CONSUMABLE)
	assert_eq(potion.heal_amount, 50)


func test_is_equipment_weapon() -> void:
	var weapon := Item.create_weapon("sword_1", "Iron Sword", "1d8", 0, 100)
	assert_true(weapon.is_equipment())


func test_is_equipment_consumable() -> void:
	var potion := Item.create_consumable("potion_1", "Health Potion", 50, 0, 25)
	assert_false(potion.is_equipment())


func test_upgrade_increases_stat() -> void:
	var weapon := Item.create_weapon("sword_1", "Iron Sword", "1d8", 0, 100)
	weapon.apply_upgrade("accuracy")
	assert_eq(weapon.get_effective_accuracy_bonus(), 1)


func test_cannot_upgrade_cursed() -> void:
	var weapon := Item.create_weapon("sword_1", "Cursed Sword", "1d8", 0, 100)
	weapon.is_cursed = true
	assert_false(weapon.can_upgrade("accuracy"))


func test_upgrade_cap() -> void:
	var weapon := Item.create_weapon("sword_1", "Iron Sword", "1d8", 0, 100)
	for i in range(10):
		weapon.apply_upgrade("accuracy")
	assert_eq(weapon.upgrades.get("accuracy", 0), Item.UPGRADE_CAP)
