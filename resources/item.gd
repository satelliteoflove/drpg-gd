## Represents an item that can be equipped, consumed, or stored in inventory.
class_name Item
extends Resource

const Proficiencies = preload("res://data/equipment/class_proficiencies.gd")

enum ItemType {
	WEAPON,
	ARMOR,
	SHIELD,
	HELMET,
	GLOVES,
	BOOTS,
	ACCESSORY,
	CONSUMABLE,
	QUEST
}

enum WeaponType {
	NONE,
	SWORD,
	AXE,
	MACE,
	DAGGER,
	STAFF,
	BOW,
	SPEAR
}

enum ItemRarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY
}

@export_group("Basic Info")
@export var id: String = ""
@export var item_name: String = "Unknown Item"
@export var description: String = ""
@export var item_type: ItemType = ItemType.CONSUMABLE
@export var weapon_type: WeaponType = WeaponType.NONE
@export var armor_category: CharacterEnums.ArmorCategory = CharacterEnums.ArmorCategory.NONE
@export var shield_category: CharacterEnums.ShieldCategory = CharacterEnums.ShieldCategory.NONE
@export var rarity: ItemRarity = ItemRarity.COMMON

@export_group("Economics")
@export var buy_price: int = 0
@export var sell_price: int = 0
@export var stackable: bool = false
@export var max_stack: int = 99

@export_group("Equipment Stats")
@export var damage_dice: String = ""
@export var weapon_range: int = 1
@export var two_handed: bool = false
@export var accuracy_bonus: int = 0
@export var damage_bonus: int = 0
@export var defense_bonus: int = 0
@export var evasion_bonus: int = 0
@export var hp_bonus: int = 0
@export var mp_bonus: int = 0

@export_group("Stat Bonuses")
@export var strength_bonus: int = 0
@export var intelligence_bonus: int = 0
@export var piety_bonus: int = 0
@export var vitality_bonus: int = 0
@export var agility_bonus: int = 0
@export var luck_bonus: int = 0

@export_group("Requirements")
@export var required_level: int = 1
@export var required_classes: Array[CharacterEnums.CharacterClass] = []
@export var required_alignment: Array[CharacterEnums.Alignment] = []
@export var required_races: Array[CharacterEnums.Race] = []

@export_group("Identification")
@export var is_identified: bool = true
@export var is_cursed: bool = false
@export var curse_effect: String = ""

@export var upgrades: Dictionary = {}

@export_group("Equipment Effects")
@export var grants_status: CharacterEnums.StatusEffect = CharacterEnums.StatusEffect.NONE

@export_group("Consumable Effects")
@export var heal_amount: int = 0
@export var mp_restore: int = 0
@export var cures_status: Array[CharacterEnums.StatusEffect] = []
@export var reveal_duration: int = 0


## Creates a new weapon item with the specified properties.
## [param p_id]: Unique item identifier.
## [param p_name]: Display name.
## [param p_damage]: Damage dice notation (e.g., "1d8").
## [param p_accuracy]: Accuracy bonus.
## [param p_price]: Buy price (sell price is half).
## [param p_weapon_type]: Type of weapon for range defaults.
## [param p_range]: Override weapon range (-1 uses type default).
## [return]: Configured weapon Item.
static func create_weapon(
	p_id: String,
	p_name: String,
	p_damage: String,
	p_accuracy: int,
	p_price: int,
	p_weapon_type: WeaponType = WeaponType.SWORD,
	p_range: int = -1
) -> Item:
	var item := Item.new()
	item.id = p_id
	item.item_name = p_name
	item.item_type = ItemType.WEAPON
	item.weapon_type = p_weapon_type
	item.damage_dice = p_damage
	item.accuracy_bonus = p_accuracy
	item.weapon_range = p_range if p_range > 0 else get_default_weapon_range(p_weapon_type)
	item.buy_price = p_price
	item.sell_price = p_price / 2
	return item


static func get_default_weapon_range(p_weapon_type: WeaponType) -> int:
	match p_weapon_type:
		WeaponType.DAGGER: return 1
		WeaponType.SWORD: return 1
		WeaponType.AXE: return 1
		WeaponType.MACE: return 1
		WeaponType.STAFF: return 2
		WeaponType.SPEAR: return 2
		WeaponType.BOW: return 4
		_: return 1


## Creates a new armor piece (armor, shield, helmet, gloves, or boots).
## [param p_id]: Unique item identifier.
## [param p_name]: Display name.
## [param p_type]: Equipment slot type.
## [param p_defense]: Defense bonus.
## [param p_evasion]: Evasion bonus.
## [param p_price]: Buy price (sell price is half).
## [return]: Configured armor Item.
static func create_armor(
	p_id: String,
	p_name: String,
	p_type: ItemType,
	p_defense: int,
	p_evasion: int,
	p_price: int
) -> Item:
	var item := Item.new()
	item.id = p_id
	item.item_name = p_name
	item.item_type = p_type
	item.defense_bonus = p_defense
	item.evasion_bonus = p_evasion
	item.buy_price = p_price
	item.sell_price = p_price / 2
	return item


## Creates a new consumable item (potion, elixir, etc.).
## [param p_id]: Unique item identifier.
## [param p_name]: Display name.
## [param p_heal]: HP restored on use.
## [param p_mp]: MP restored on use.
## [param p_price]: Buy price (sell price is half).
## [return]: Configured consumable Item.
static func create_consumable(
	p_id: String,
	p_name: String,
	p_heal: int,
	p_mp: int,
	p_price: int
) -> Item:
	var item := Item.new()
	item.id = p_id
	item.item_name = p_name
	item.item_type = ItemType.CONSUMABLE
	item.stackable = true
	item.heal_amount = p_heal
	item.mp_restore = p_mp
	item.buy_price = p_price
	item.sell_price = p_price / 2
	return item


## Returns true if this item can be equipped (weapon, armor, accessory, etc.).
func is_equipment() -> bool:
	return item_type in [
		ItemType.WEAPON,
		ItemType.ARMOR,
		ItemType.SHIELD,
		ItemType.HELMET,
		ItemType.GLOVES,
		ItemType.BOOTS,
		ItemType.ACCESSORY
	]


## Checks if a character meets the requirements to equip this item.
## [param character]: The character attempting to equip.
## [return]: True if all requirements are met.
func can_equip(character: Resource) -> bool:
	var char_class: CharacterEnums.CharacterClass = character.character_class

	if not _check_proficiency(char_class):
		return false

	if not required_classes.is_empty():
		if not (char_class in required_classes):
			return false

	if not required_races.is_empty():
		if not (character.race in required_races):
			return false

	if not required_alignment.is_empty():
		if not (character.alignment in required_alignment):
			return false

	if character.level < required_level:
		return false

	return true


func _check_proficiency(char_class: CharacterEnums.CharacterClass) -> bool:
	match item_type:
		ItemType.WEAPON:
			return Proficiencies.can_use_weapon(char_class, weapon_type)
		ItemType.SHIELD:
			return Proficiencies.can_use_shield(char_class, shield_category)
		ItemType.ARMOR, ItemType.HELMET, ItemType.GLOVES, ItemType.BOOTS:
			return Proficiencies.can_use_armor(char_class, armor_category)
		ItemType.ACCESSORY:
			return true
		_:
			return true


func get_slot_name() -> String:
	match item_type:
		ItemType.WEAPON: return "Weapon"
		ItemType.ARMOR: return "Armor"
		ItemType.SHIELD: return "Shield"
		ItemType.HELMET: return "Helmet"
		ItemType.GLOVES: return "Gloves"
		ItemType.BOOTS: return "Boots"
		ItemType.ACCESSORY: return "Accessory"
		_: return ""


func get_type_name() -> String:
	match item_type:
		ItemType.WEAPON: return "Weapon"
		ItemType.ARMOR: return "Armor"
		ItemType.SHIELD: return "Shield"
		ItemType.HELMET: return "Helmet"
		ItemType.GLOVES: return "Gloves"
		ItemType.BOOTS: return "Boots"
		ItemType.ACCESSORY: return "Accessory"
		ItemType.CONSUMABLE: return "Consumable"
		ItemType.QUEST: return "Quest"
		_: return "Unknown"


func get_stats_text() -> String:
	if not is_identified:
		return "???"

	var parts: Array[String] = []

	if damage_dice != "":
		parts.append("Dmg: %s" % damage_dice)
	if item_type == ItemType.WEAPON and weapon_range > 0:
		parts.append("Rng: %d" % weapon_range)
	if get_effective_accuracy_bonus() != 0:
		parts.append("Acc: %+d" % get_effective_accuracy_bonus())
	if get_effective_damage_bonus() != 0:
		parts.append("Dmg: %+d" % get_effective_damage_bonus())
	if get_effective_defense_bonus() != 0:
		parts.append("Def: %+d" % get_effective_defense_bonus())
	if get_effective_evasion_bonus() != 0:
		parts.append("Eva: %+d" % get_effective_evasion_bonus())
	if get_effective_hp_bonus() != 0:
		parts.append("HP: %+d" % get_effective_hp_bonus())
	if get_effective_mp_bonus() != 0:
		parts.append("MP: %+d" % get_effective_mp_bonus())

	if heal_amount > 0:
		parts.append("Heals %d HP" % heal_amount)
	if mp_restore > 0:
		parts.append("Restores %d MP" % mp_restore)
	if not cures_status.is_empty():
		var cure_names: Array[String] = []
		for status in cures_status:
			cure_names.append(CharacterEnums.get_status_noun(status))
		parts.append("Cures %s" % ", ".join(cure_names))
	if reveal_duration > 0:
		parts.append("Reveals enemies for %d steps" % reveal_duration)

	if is_cursed:
		parts.append("[CURSED]")

	return ", ".join(parts) if not parts.is_empty() else "No special properties"


func get_display_name() -> String:
	if not is_identified:
		return "??? %s" % get_type_name()

	var name := item_name
	var total_points := get_total_upgrade_points()

	if total_points > 0:
		name += " +%d" % total_points
		var upgrade_parts: Array[String] = []
		if upgrades.get("accuracy", 0) > 0:
			upgrade_parts.append("A%d" % upgrades.get("accuracy", 0))
		if upgrades.get("damage", 0) > 0:
			upgrade_parts.append("D%d" % upgrades.get("damage", 0))
		if upgrades.get("defense", 0) > 0:
			upgrade_parts.append("Df%d" % upgrades.get("defense", 0))
		if upgrades.get("evasion", 0) > 0:
			upgrade_parts.append("E%d" % upgrades.get("evasion", 0))
		if upgrades.get("hp", 0) > 0:
			upgrade_parts.append("H%d" % upgrades.get("hp", 0))
		if upgrades.get("mp", 0) > 0:
			upgrade_parts.append("M%d" % upgrades.get("mp", 0))
		if upgrades.get("strength", 0) > 0:
			upgrade_parts.append("S%d" % upgrades.get("strength", 0))
		if upgrades.get("intelligence", 0) > 0:
			upgrade_parts.append("I%d" % upgrades.get("intelligence", 0))
		if upgrades.get("piety", 0) > 0:
			upgrade_parts.append("P%d" % upgrades.get("piety", 0))
		if upgrades.get("vitality", 0) > 0:
			upgrade_parts.append("V%d" % upgrades.get("vitality", 0))
		if upgrades.get("agility", 0) > 0:
			upgrade_parts.append("Ag%d" % upgrades.get("agility", 0))
		if upgrades.get("luck", 0) > 0:
			upgrade_parts.append("L%d" % upgrades.get("luck", 0))

		if not upgrade_parts.is_empty():
			name += " [%s]" % " ".join(upgrade_parts)

	return name


func get_total_upgrade_points() -> int:
	var total := 0
	for stat in upgrades:
		total += upgrades[stat]
	return total


func get_upgrade_cost(stat: String) -> int:
	var current_level: int = upgrades.get(stat, 0)
	return int(pow(2, current_level + 1))


func get_upgradeable_stats() -> Array[String]:
	var stats: Array[String] = []
	match item_type:
		ItemType.WEAPON:
			stats = ["accuracy", "damage"]
		ItemType.ARMOR:
			stats = ["defense"]
		ItemType.SHIELD:
			stats = ["defense", "evasion"]
		ItemType.HELMET:
			stats = ["defense"]
		ItemType.GLOVES:
			stats = ["accuracy"]
		ItemType.BOOTS:
			stats = ["evasion"]
		ItemType.ACCESSORY:
			stats = ["hp", "mp", "strength", "intelligence", "piety", "vitality", "agility", "luck"]
	return stats


const UPGRADE_CAP: int = 5


## Checks if the item can be upgraded in the specified stat.
## [param stat]: Stat name to upgrade (accuracy, damage, defense, etc.).
## [return]: True if upgrade is possible.
func can_upgrade(stat: String) -> bool:
	if is_cursed:
		return false
	if not is_identified:
		return false
	if not stat in get_upgradeable_stats():
		return false
	var current_level: int = upgrades.get(stat, 0)
	return current_level < UPGRADE_CAP


## Applies an upgrade to the specified stat.
## [param stat]: Stat name to upgrade.
func apply_upgrade(stat: String) -> void:
	if not can_upgrade(stat):
		return
	var current: int = upgrades.get(stat, 0)
	upgrades[stat] = current + 1


func get_effective_accuracy_bonus() -> int:
	return accuracy_bonus + upgrades.get("accuracy", 0)


func get_effective_damage_bonus() -> int:
	return damage_bonus + upgrades.get("damage", 0)


func get_effective_defense_bonus() -> int:
	return defense_bonus + upgrades.get("defense", 0)


func get_effective_evasion_bonus() -> int:
	return evasion_bonus + upgrades.get("evasion", 0)


func get_effective_hp_bonus() -> int:
	return hp_bonus + upgrades.get("hp", 0)


func get_effective_mp_bonus() -> int:
	return mp_bonus + upgrades.get("mp", 0)


func get_effective_strength_bonus() -> int:
	return strength_bonus + upgrades.get("strength", 0)


func get_effective_intelligence_bonus() -> int:
	return intelligence_bonus + upgrades.get("intelligence", 0)


func get_effective_piety_bonus() -> int:
	return piety_bonus + upgrades.get("piety", 0)


func get_effective_vitality_bonus() -> int:
	return vitality_bonus + upgrades.get("vitality", 0)


func get_effective_agility_bonus() -> int:
	return agility_bonus + upgrades.get("agility", 0)


func get_effective_luck_bonus() -> int:
	return luck_bonus + upgrades.get("luck", 0)
