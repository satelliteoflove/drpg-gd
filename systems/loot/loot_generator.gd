class_name LootGenerator
extends RefCounted

const CombatRNG = preload("res://autoload/combat_rng.gd")
const ShopItemsData = preload("res://data/items/shop_items.gd")
const LootDropRes = preload("res://resources/loot_drop.gd")

const BASE_UPGRADE_CHANCE_PER_FLOOR: float = 0.08
const UPGRADE_DECAY_FACTOR: float = 0.4
const MAX_UPGRADE_LEVEL: int = 5
const LUCK_BONUS_PER_POINT: float = 0.005
const MAX_LUCK_BONUS: float = 0.10
const BASE_LUCK: int = 10


static func generate_combat_loot(
	defeated_monsters: Array,
	floor_level: int,
	party_avg_luck: int
) -> Array[Item]:
	var loot: Array[Item] = []
	var luck_bonus := _calculate_luck_bonus(party_avg_luck)

	for monster in defeated_monsters:
		if monster == null:
			continue

		var monster_loot := _generate_monster_loot(monster, floor_level, luck_bonus)
		loot.append_array(monster_loot)

	return loot


static func _generate_monster_loot(
	monster: Monster,
	floor_level: int,
	luck_bonus: float
) -> Array[Item]:
	var loot: Array[Item] = []

	if monster.loot_drops.is_empty():
		return loot

	for drop: LootDropRes in monster.loot_drops:
		var modified_chance: float = drop.chance + luck_bonus
		modified_chance = minf(1.0, modified_chance)

		if CombatRNG.randf() < modified_chance:
			var item := _create_loot_item(drop.item_id, floor_level)
			if item:
				loot.append(item)

	return loot


static func _create_loot_item(item_id: String, floor_level: int) -> Item:
	var base_item: Item = ShopItemsData.get_item(item_id)
	if base_item == null:
		push_error("[LootGenerator] Unknown item_id: " + item_id)
		return null

	var item := base_item.duplicate(true) as Item

	item.is_identified = false

	if item.is_equipment() and not item.is_cursed:
		var upgrade_level := _roll_upgrade_level(floor_level)
		if upgrade_level > 0:
			_apply_upgrade(item, upgrade_level)

	return item


static func _roll_upgrade_level(floor_level: int) -> int:
	var upgrade := 0
	var base_chance := floor_level * BASE_UPGRADE_CHANCE_PER_FLOOR
	var current_chance := base_chance

	while CombatRNG.randf() < current_chance and upgrade < MAX_UPGRADE_LEVEL:
		upgrade += 1
		current_chance *= UPGRADE_DECAY_FACTOR

	return upgrade


static func _apply_upgrade(item: Item, level: int) -> void:
	var upgradeable_stats := item.get_upgradeable_stats()
	if upgradeable_stats.is_empty():
		return

	var points_remaining := level
	while points_remaining > 0:
		var stat: String = upgradeable_stats[CombatRNG.randi() % upgradeable_stats.size()]
		var current: int = item.upgrades.get(stat, 0)
		if current < Item.UPGRADE_CAP:
			item.upgrades[stat] = current + 1
			points_remaining -= 1
		else:
			var can_upgrade := false
			for s in upgradeable_stats:
				if item.upgrades.get(s, 0) < Item.UPGRADE_CAP:
					can_upgrade = true
					break
			if not can_upgrade:
				break


static func _calculate_luck_bonus(party_avg_luck: int) -> float:
	var luck_diff := party_avg_luck - BASE_LUCK
	var bonus := luck_diff * LUCK_BONUS_PER_POINT
	return clampf(bonus, -MAX_LUCK_BONUS, MAX_LUCK_BONUS)
