class_name ShopItems
extends RefCounted

static var _items: Dictionary = {}
static var _initialized: bool = false

const LARGE_RACES: Array[CharacterEnums.Race] = [
	CharacterEnums.Race.HUMAN,
	CharacterEnums.Race.ELF,
	CharacterEnums.Race.DWARF,
	CharacterEnums.Race.LIZMAN,
	CharacterEnums.Race.DRACON,
	CharacterEnums.Race.RAWULF,
	CharacterEnums.Race.MOOK,
	CharacterEnums.Race.FELPURR
]


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_create_items()


static func _create_items() -> void:
	# -------------------------------------------------------------------------
	# WEAPONS
	# -------------------------------------------------------------------------
	# Proficiency is determined by weapon_type via ClassProficiencies.WEAPONS
	# Only set required_races for size restrictions on large weapons

	_items["dagger"] = Item.create_weapon("dagger", "Dagger", "1d4", 0, 10, Item.WeaponType.DAGGER)

	_items["short_sword"] = Item.create_weapon("short_sword", "Short Sword", "1d6", 0, 30, Item.WeaponType.SWORD)

	_items["long_sword"] = Item.create_weapon("long_sword", "Long Sword", "1d8", 1, 100, Item.WeaponType.SWORD)
	_items["long_sword"].required_races.assign(LARGE_RACES)

	_items["berserker_sword"] = Item.create_weapon("berserker_sword", "Berserker's Longsword", "1d10", 2, 250, Item.WeaponType.SWORD)
	_items["berserker_sword"].required_races.assign(LARGE_RACES)
	_items["berserker_sword"].grants_status = CharacterEnums.StatusEffect.BERSERK
	_items["berserker_sword"].description = "A blood-red blade that fills its wielder with uncontrollable fury. Grants permanent berserk in combat."

	_items["battle_axe"] = Item.create_weapon("battle_axe", "Battle Axe", "1d10", 0, 150, Item.WeaponType.AXE)
	_items["battle_axe"].required_races.assign(LARGE_RACES)
	_items["battle_axe"].two_handed = true

	_items["mace"] = Item.create_weapon("mace", "Mace", "1d6", 1, 50, Item.WeaponType.MACE)

	_items["staff"] = Item.create_weapon("staff", "Staff", "1d4", 0, 15, Item.WeaponType.STAFF)
	_items["staff"].two_handed = true

	_items["spear"] = Item.create_weapon("spear", "Spear", "1d8", 0, 80, Item.WeaponType.SPEAR)
	_items["spear"].required_races.assign(LARGE_RACES)
	_items["spear"].two_handed = true

	_items["short_bow"] = Item.create_weapon("short_bow", "Short Bow", "1d6", 0, 50, Item.WeaponType.BOW)
	_items["short_bow"].two_handed = true

	_items["long_bow"] = Item.create_weapon("long_bow", "Long Bow", "1d8", 1, 120, Item.WeaponType.BOW)
	_items["long_bow"].required_races.assign(LARGE_RACES)
	_items["long_bow"].two_handed = true

	# -------------------------------------------------------------------------
	# ARMOR
	# -------------------------------------------------------------------------
	# Proficiency is determined by armor_category via ClassProficiencies.ARMOR
	# Only set required_races for size restrictions on heavy armor

	_items["cloth_armor"] = Item.create_armor("cloth_armor", "Cloth Armor", Item.ItemType.ARMOR, 1, 0, 20)
	_items["cloth_armor"].armor_category = CharacterEnums.ArmorCategory.CLOTH

	_items["leather_armor"] = Item.create_armor("leather_armor", "Leather Armor", Item.ItemType.ARMOR, 2, 0, 50)
	_items["leather_armor"].armor_category = CharacterEnums.ArmorCategory.LEATHER

	_items["chain_mail"] = Item.create_armor("chain_mail", "Chain Mail", Item.ItemType.ARMOR, 4, -1, 150)
	_items["chain_mail"].armor_category = CharacterEnums.ArmorCategory.CHAIN
	_items["chain_mail"].required_races.assign(LARGE_RACES)

	_items["plate_armor"] = Item.create_armor("plate_armor", "Plate Armor", Item.ItemType.ARMOR, 6, -2, 400)
	_items["plate_armor"].armor_category = CharacterEnums.ArmorCategory.PLATE
	_items["plate_armor"].required_races.assign(LARGE_RACES)

	# -------------------------------------------------------------------------
	# SHIELDS
	# -------------------------------------------------------------------------
	# Proficiency is determined by shield_category via ClassProficiencies.SHIELDS

	_items["wooden_shield"] = Item.create_armor("wooden_shield", "Wooden Shield", Item.ItemType.SHIELD, 1, 0, 15)
	_items["wooden_shield"].shield_category = CharacterEnums.ShieldCategory.LIGHT

	_items["iron_shield"] = Item.create_armor("iron_shield", "Iron Shield", Item.ItemType.SHIELD, 2, 0, 60)
	_items["iron_shield"].shield_category = CharacterEnums.ShieldCategory.HEAVY
	_items["iron_shield"].required_races.assign(LARGE_RACES)

	# -------------------------------------------------------------------------
	# HELMETS
	# -------------------------------------------------------------------------
	# Proficiency uses armor_category

	_items["leather_cap"] = Item.create_armor("leather_cap", "Leather Cap", Item.ItemType.HELMET, 1, 0, 25)
	_items["leather_cap"].armor_category = CharacterEnums.ArmorCategory.LEATHER

	_items["iron_helm"] = Item.create_armor("iron_helm", "Iron Helm", Item.ItemType.HELMET, 2, 0, 80)
	_items["iron_helm"].armor_category = CharacterEnums.ArmorCategory.PLATE
	_items["iron_helm"].required_races.assign(LARGE_RACES)

	# -------------------------------------------------------------------------
	# GLOVES
	# -------------------------------------------------------------------------

	_items["leather_gloves"] = Item.create_armor("leather_gloves", "Leather Gloves", Item.ItemType.GLOVES, 0, 0, 20)
	_items["leather_gloves"].armor_category = CharacterEnums.ArmorCategory.LEATHER
	_items["leather_gloves"].accuracy_bonus = 1

	# -------------------------------------------------------------------------
	# BOOTS
	# -------------------------------------------------------------------------

	_items["leather_boots"] = Item.create_armor("leather_boots", "Leather Boots", Item.ItemType.BOOTS, 0, 1, 30)
	_items["leather_boots"].armor_category = CharacterEnums.ArmorCategory.LEATHER

	_items["iron_boots"] = Item.create_armor("iron_boots", "Iron Boots", Item.ItemType.BOOTS, 1, 0, 70)
	_items["iron_boots"].armor_category = CharacterEnums.ArmorCategory.PLATE
	_items["iron_boots"].required_races.assign(LARGE_RACES)

	# -------------------------------------------------------------------------
	# CONSUMABLES
	# -------------------------------------------------------------------------

	_items["healing_potion"] = Item.create_consumable("healing_potion", "Healing Potion", 20, 0, 25)
	_items["greater_healing"] = Item.create_consumable("greater_healing", "Greater Healing Potion", 50, 0, 75)
	_items["mana_potion"] = Item.create_consumable("mana_potion", "Mana Potion", 0, 15, 15)
	_items["antidote"] = Item.create_consumable("antidote", "Antidote", 0, 0, 20)
	_items["antidote"].cures_status.append(CharacterEnums.StatusEffect.POISONED)

	_items["throat_salve"] = Item.create_consumable("throat_salve", "Throat Salve", 0, 0, 30)
	_items["throat_salve"].cures_status.append(CharacterEnums.StatusEffect.SILENCED)

	_items["eye_drops"] = Item.create_consumable("eye_drops", "Clear Sight Drops", 0, 0, 30)
	_items["eye_drops"].cures_status.append(CharacterEnums.StatusEffect.BLINDED)

	_items["smelling_salts"] = Item.create_consumable("smelling_salts", "Smelling Salts", 0, 0, 25)
	_items["smelling_salts"].cures_status.append(CharacterEnums.StatusEffect.CONFUSED)

	_items["clarity_draught"] = Item.create_consumable("clarity_draught", "Clarity Draught", 0, 0, 40)
	_items["clarity_draught"].cures_status.append(CharacterEnums.StatusEffect.CONFUSED)
	_items["clarity_draught"].cures_status.append(CharacterEnums.StatusEffect.CHARMED)
	_items["clarity_draught"].cures_status.append(CharacterEnums.StatusEffect.AFRAID)

	_items["courage_tonic"] = Item.create_consumable("courage_tonic", "Courage Tonic", 0, 0, 25)
	_items["courage_tonic"].cures_status.append(CharacterEnums.StatusEffect.AFRAID)

	_items["wake_dust"] = Item.create_consumable("wake_dust", "Wake Dust", 0, 0, 15)
	_items["wake_dust"].cures_status.append(CharacterEnums.StatusEffect.ASLEEP)

	_items["muscle_relaxant"] = Item.create_consumable("muscle_relaxant", "Muscle Relaxant", 0, 0, 75)
	_items["muscle_relaxant"].cures_status.append(CharacterEnums.StatusEffect.PARALYZED)

	_items["stone_salve"] = Item.create_consumable("stone_salve", "Stone Salve", 0, 0, 150)
	_items["stone_salve"].cures_status.append(CharacterEnums.StatusEffect.STONED)

	_items["holy_water"] = Item.create_consumable("holy_water", "Holy Water", 0, 0, 100)
	_items["holy_water"].cures_status.append(CharacterEnums.StatusEffect.CURSED)

	_items["scroll_revelation"] = Item.create_consumable("scroll_revelation", "Scroll of Revelation", 0, 0, 150)
	_items["scroll_revelation"].reveal_duration = 40
	_items["scroll_revelation"].description = "Reveals all enemies on the floor for 40 steps."

	_items["torch"] = Item.create_consumable("torch", "Torch", 0, 0, 8)
	_items["torch"].burn_duration = 150
	_items["torch"].description = "A pitch-soaked brand. Lights the way for about 150 steps before it gutters out. The dungeon is lightless without one."

	var dungeon_key := Item.new()
	dungeon_key.id = "dungeon_key"
	dungeon_key.item_name = "Dungeon Key"
	dungeon_key.description = "Unlocks a locked door in the dungeon."
	dungeon_key.item_type = Item.ItemType.QUEST
	dungeon_key.stackable = true
	dungeon_key.max_stack = 99
	dungeon_key.buy_price = 0
	dungeon_key.sell_price = 0
	_items["dungeon_key"] = dungeon_key


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
