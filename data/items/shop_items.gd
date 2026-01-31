class_name ShopItems
extends RefCounted

const CharEnum = preload("res://resources/character_enums.gd")

static var _items: Dictionary = {}
static var _initialized: bool = false

const HEAVY_MELEE_CLASSES: Array[CharEnum.CharacterClass] = [
	CharEnum.CharacterClass.FIGHTER,
	CharEnum.CharacterClass.VALKYRIE,
	CharEnum.CharacterClass.SAMURAI,
	CharEnum.CharacterClass.LORD,
	CharEnum.CharacterClass.RANGER
]

const STAFF_CLASSES: Array[CharEnum.CharacterClass] = [
	CharEnum.CharacterClass.MAGE,
	CharEnum.CharacterClass.PRIEST,
	CharEnum.CharacterClass.PSIONIC,
	CharEnum.CharacterClass.ALCHEMIST,
	CharEnum.CharacterClass.BISHOP,
	CharEnum.CharacterClass.BARD,
	CharEnum.CharacterClass.MONK
]

const HEAVY_ARMOR_CLASSES: Array[CharEnum.CharacterClass] = [
	CharEnum.CharacterClass.FIGHTER,
	CharEnum.CharacterClass.VALKYRIE,
	CharEnum.CharacterClass.SAMURAI,
	CharEnum.CharacterClass.LORD
]

const MEDIUM_ARMOR_CLASSES: Array[CharEnum.CharacterClass] = [
	CharEnum.CharacterClass.FIGHTER,
	CharEnum.CharacterClass.RANGER,
	CharEnum.CharacterClass.THIEF,
	CharEnum.CharacterClass.NINJA,
	CharEnum.CharacterClass.VALKYRIE,
	CharEnum.CharacterClass.SAMURAI,
	CharEnum.CharacterClass.LORD,
	CharEnum.CharacterClass.MONK,
	CharEnum.CharacterClass.BARD
]

const SHIELD_CLASSES: Array[CharEnum.CharacterClass] = [
	CharEnum.CharacterClass.FIGHTER,
	CharEnum.CharacterClass.RANGER,
	CharEnum.CharacterClass.BISHOP,
	CharEnum.CharacterClass.VALKYRIE,
	CharEnum.CharacterClass.SAMURAI,
	CharEnum.CharacterClass.LORD
]

const LARGE_RACES: Array[CharEnum.Race] = [
	CharEnum.Race.HUMAN,
	CharEnum.Race.ELF,
	CharEnum.Race.DWARF,
	CharEnum.Race.LIZMAN,
	CharEnum.Race.DRACON,
	CharEnum.Race.RAWULF,
	CharEnum.Race.MOOK,
	CharEnum.Race.FELPURR
]


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_create_items()


static func _create_items() -> void:
	_items["dagger"] = Item.create_weapon("dagger", "Dagger", "1d4", 0, 10, Item.WeaponType.DAGGER)

	_items["short_sword"] = Item.create_weapon("short_sword", "Short Sword", "1d6", 0, 30, Item.WeaponType.SWORD)
	_items["short_sword"].required_classes.assign(HEAVY_MELEE_CLASSES)

	_items["long_sword"] = Item.create_weapon("long_sword", "Long Sword", "1d8", 1, 100, Item.WeaponType.SWORD)
	_items["long_sword"].required_classes.assign(HEAVY_MELEE_CLASSES)
	_items["long_sword"].required_races.assign(LARGE_RACES)

	_items["battle_axe"] = Item.create_weapon("battle_axe", "Battle Axe", "1d10", 0, 150, Item.WeaponType.AXE)
	_items["battle_axe"].required_classes.assign(HEAVY_MELEE_CLASSES)
	_items["battle_axe"].required_races.assign(LARGE_RACES)

	_items["mace"] = Item.create_weapon("mace", "Mace", "1d6", 1, 50, Item.WeaponType.MACE)
	_items["mace"].required_classes.assign(HEAVY_MELEE_CLASSES)

	_items["staff"] = Item.create_weapon("staff", "Staff", "1d4", 0, 15, Item.WeaponType.STAFF)
	_items["staff"].required_classes.assign(STAFF_CLASSES)

	_items["spear"] = Item.create_weapon("spear", "Spear", "1d8", 0, 80, Item.WeaponType.SPEAR)
	_items["spear"].required_classes.assign(HEAVY_MELEE_CLASSES)
	_items["spear"].required_races.assign(LARGE_RACES)

	_items["short_bow"] = Item.create_weapon("short_bow", "Short Bow", "1d6", 0, 50, Item.WeaponType.BOW)
	_items["short_bow"].required_classes.assign(HEAVY_MELEE_CLASSES)

	_items["long_bow"] = Item.create_weapon("long_bow", "Long Bow", "1d8", 1, 120, Item.WeaponType.BOW)
	_items["long_bow"].required_classes.assign(HEAVY_MELEE_CLASSES)
	_items["long_bow"].required_races.assign(LARGE_RACES)

	_items["cloth_armor"] = Item.create_armor("cloth_armor", "Cloth Armor", Item.ItemType.ARMOR, 1, 0, 20)

	_items["leather_armor"] = Item.create_armor("leather_armor", "Leather Armor", Item.ItemType.ARMOR, 2, 0, 50)
	_items["leather_armor"].required_classes.assign(MEDIUM_ARMOR_CLASSES)

	_items["chain_mail"] = Item.create_armor("chain_mail", "Chain Mail", Item.ItemType.ARMOR, 4, -1, 150)
	_items["chain_mail"].required_classes.assign(HEAVY_ARMOR_CLASSES)
	_items["chain_mail"].required_races.assign(LARGE_RACES)

	_items["plate_armor"] = Item.create_armor("plate_armor", "Plate Armor", Item.ItemType.ARMOR, 6, -2, 400)
	_items["plate_armor"].required_classes.assign(HEAVY_ARMOR_CLASSES)
	_items["plate_armor"].required_races.assign(LARGE_RACES)

	_items["wooden_shield"] = Item.create_armor("wooden_shield", "Wooden Shield", Item.ItemType.SHIELD, 1, 0, 15)
	_items["wooden_shield"].required_classes.assign(SHIELD_CLASSES)

	_items["iron_shield"] = Item.create_armor("iron_shield", "Iron Shield", Item.ItemType.SHIELD, 2, 0, 60)
	_items["iron_shield"].required_classes.assign(SHIELD_CLASSES)
	_items["iron_shield"].required_races.assign(LARGE_RACES)

	_items["leather_cap"] = Item.create_armor("leather_cap", "Leather Cap", Item.ItemType.HELMET, 1, 0, 25)

	_items["iron_helm"] = Item.create_armor("iron_helm", "Iron Helm", Item.ItemType.HELMET, 2, 0, 80)
	_items["iron_helm"].required_classes.assign(HEAVY_ARMOR_CLASSES)
	_items["iron_helm"].required_races.assign(LARGE_RACES)

	_items["leather_gloves"] = Item.create_armor("leather_gloves", "Leather Gloves", Item.ItemType.GLOVES, 0, 0, 20)
	_items["leather_gloves"].accuracy_bonus = 1

	_items["leather_boots"] = Item.create_armor("leather_boots", "Leather Boots", Item.ItemType.BOOTS, 0, 1, 30)

	_items["iron_boots"] = Item.create_armor("iron_boots", "Iron Boots", Item.ItemType.BOOTS, 1, 0, 70)
	_items["iron_boots"].required_classes.assign(HEAVY_ARMOR_CLASSES)
	_items["iron_boots"].required_races.assign(LARGE_RACES)

	_items["healing_potion"] = Item.create_consumable("healing_potion", "Healing Potion", 20, 0, 25)
	_items["greater_healing"] = Item.create_consumable("greater_healing", "Greater Healing Potion", 50, 0, 75)
	_items["mana_potion"] = Item.create_consumable("mana_potion", "Mana Potion", 0, 15, 30)
	_items["antidote"] = Item.create_consumable("antidote", "Antidote", 0, 0, 20)
	_items["antidote"].cures_status.append(CharEnum.StatusEffect.POISONED)


static func get_item(item_id: String) -> Item:
	_ensure_initialized()
	return _items.get(item_id)


static func get_shop_inventory() -> Array[Item]:
	_ensure_initialized()
	var items: Array[Item] = []
	for item in _items.values():
		items.append(item)
	return items


static func get_weapons() -> Array[Item]:
	_ensure_initialized()
	var items: Array[Item] = []
	for item: Item in _items.values():
		if item.item_type == Item.ItemType.WEAPON:
			items.append(item)
	return items


static func get_armor() -> Array[Item]:
	_ensure_initialized()
	var items: Array[Item] = []
	for item: Item in _items.values():
		if item.item_type in [Item.ItemType.ARMOR, Item.ItemType.SHIELD, Item.ItemType.HELMET, Item.ItemType.GLOVES, Item.ItemType.BOOTS]:
			items.append(item)
	return items


static func get_consumables() -> Array[Item]:
	_ensure_initialized()
	var items: Array[Item] = []
	for item: Item in _items.values():
		if item.item_type == Item.ItemType.CONSUMABLE:
			items.append(item)
	return items
