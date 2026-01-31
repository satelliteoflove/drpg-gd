class_name ClassProficiencies
extends RefCounted

# =============================================================================
# CLASS PROFICIENCY TABLES
# =============================================================================
# Edit these tables to control what equipment each class can use.
# Empty array = cannot use any items in that category.
# =============================================================================

# -----------------------------------------------------------------------------
# ARMOR PROFICIENCIES
# -----------------------------------------------------------------------------
# Categories: CLOTH, LEATHER, CHAIN, PLATE
# Classes automatically get all lower categories (e.g., CHAIN includes LEATHER and CLOTH)

const ARMOR: Dictionary = {
	CharacterEnums.CharacterClass.FIGHTER: [
		CharacterEnums.ArmorCategory.CLOTH,
		CharacterEnums.ArmorCategory.LEATHER,
		CharacterEnums.ArmorCategory.CHAIN,
		CharacterEnums.ArmorCategory.PLATE,
	],
	CharacterEnums.CharacterClass.MAGE: [
		CharacterEnums.ArmorCategory.CLOTH,
	],
	CharacterEnums.CharacterClass.PRIEST: [
		CharacterEnums.ArmorCategory.CLOTH,
		CharacterEnums.ArmorCategory.LEATHER,
		CharacterEnums.ArmorCategory.CHAIN,
	],
	CharacterEnums.CharacterClass.THIEF: [
		CharacterEnums.ArmorCategory.CLOTH,
		CharacterEnums.ArmorCategory.LEATHER,
	],
	CharacterEnums.CharacterClass.RANGER: [
		CharacterEnums.ArmorCategory.CLOTH,
		CharacterEnums.ArmorCategory.LEATHER,
		CharacterEnums.ArmorCategory.CHAIN,
	],
	CharacterEnums.CharacterClass.NINJA: [
		CharacterEnums.ArmorCategory.CLOTH,
		CharacterEnums.ArmorCategory.LEATHER,
	],
	CharacterEnums.CharacterClass.VALKYRIE: [
		CharacterEnums.ArmorCategory.CLOTH,
		CharacterEnums.ArmorCategory.LEATHER,
		CharacterEnums.ArmorCategory.CHAIN,
		CharacterEnums.ArmorCategory.PLATE,
	],
	CharacterEnums.CharacterClass.SAMURAI: [
		CharacterEnums.ArmorCategory.CLOTH,
		CharacterEnums.ArmorCategory.LEATHER,
		CharacterEnums.ArmorCategory.CHAIN,
		CharacterEnums.ArmorCategory.PLATE,
	],
	CharacterEnums.CharacterClass.LORD: [
		CharacterEnums.ArmorCategory.CLOTH,
		CharacterEnums.ArmorCategory.LEATHER,
		CharacterEnums.ArmorCategory.CHAIN,
		CharacterEnums.ArmorCategory.PLATE,
	],
	CharacterEnums.CharacterClass.MONK: [
		CharacterEnums.ArmorCategory.CLOTH,
		CharacterEnums.ArmorCategory.LEATHER,
	],
	CharacterEnums.CharacterClass.BARD: [
		CharacterEnums.ArmorCategory.CLOTH,
		CharacterEnums.ArmorCategory.LEATHER,
	],
	CharacterEnums.CharacterClass.BISHOP: [
		CharacterEnums.ArmorCategory.CLOTH,
		CharacterEnums.ArmorCategory.LEATHER,
	],
	CharacterEnums.CharacterClass.PSIONIC: [
		CharacterEnums.ArmorCategory.CLOTH,
	],
	CharacterEnums.CharacterClass.ALCHEMIST: [
		CharacterEnums.ArmorCategory.CLOTH,
		CharacterEnums.ArmorCategory.LEATHER,
	],
}

# -----------------------------------------------------------------------------
# WEAPON PROFICIENCIES
# -----------------------------------------------------------------------------
# Categories: DAGGER, SWORD, AXE, MACE, STAFF, SPEAR, BOW

const WEAPONS: Dictionary = {
	CharacterEnums.CharacterClass.FIGHTER: [
		Item.WeaponType.DAGGER,
		Item.WeaponType.SWORD,
		Item.WeaponType.AXE,
		Item.WeaponType.MACE,
		Item.WeaponType.STAFF,
		Item.WeaponType.SPEAR,
		Item.WeaponType.BOW,
	],
	CharacterEnums.CharacterClass.MAGE: [
		Item.WeaponType.DAGGER,
		Item.WeaponType.STAFF,
	],
	CharacterEnums.CharacterClass.PRIEST: [
		Item.WeaponType.MACE,
		Item.WeaponType.STAFF,
	],
	CharacterEnums.CharacterClass.THIEF: [
		Item.WeaponType.DAGGER,
		Item.WeaponType.SWORD,
		Item.WeaponType.BOW,
	],
	CharacterEnums.CharacterClass.RANGER: [
		Item.WeaponType.SWORD,
		Item.WeaponType.AXE,
		Item.WeaponType.SPEAR,
		Item.WeaponType.BOW,
	],
	CharacterEnums.CharacterClass.NINJA: [
		Item.WeaponType.DAGGER,
		Item.WeaponType.SWORD,
		Item.WeaponType.BOW,
	],
	CharacterEnums.CharacterClass.VALKYRIE: [
		Item.WeaponType.DAGGER,
		Item.WeaponType.SWORD,
		Item.WeaponType.AXE,
		Item.WeaponType.MACE,
		Item.WeaponType.SPEAR,
		Item.WeaponType.BOW,
	],
	CharacterEnums.CharacterClass.SAMURAI: [
		Item.WeaponType.SWORD,
		Item.WeaponType.SPEAR,
		Item.WeaponType.BOW,
	],
	CharacterEnums.CharacterClass.LORD: [
		Item.WeaponType.DAGGER,
		Item.WeaponType.SWORD,
		Item.WeaponType.AXE,
		Item.WeaponType.MACE,
		Item.WeaponType.SPEAR,
		Item.WeaponType.BOW,
	],
	CharacterEnums.CharacterClass.MONK: [
		Item.WeaponType.STAFF,
	],
	CharacterEnums.CharacterClass.BARD: [
		Item.WeaponType.DAGGER,
		Item.WeaponType.SWORD,
		Item.WeaponType.STAFF,
	],
	CharacterEnums.CharacterClass.BISHOP: [
		Item.WeaponType.MACE,
		Item.WeaponType.STAFF,
	],
	CharacterEnums.CharacterClass.PSIONIC: [
		Item.WeaponType.DAGGER,
		Item.WeaponType.STAFF,
	],
	CharacterEnums.CharacterClass.ALCHEMIST: [
		Item.WeaponType.DAGGER,
		Item.WeaponType.STAFF,
	],
}

# -----------------------------------------------------------------------------
# SHIELD PROFICIENCIES
# -----------------------------------------------------------------------------
# Categories: LIGHT, HEAVY
# Empty array = cannot use shields

const SHIELDS: Dictionary = {
	CharacterEnums.CharacterClass.FIGHTER: [
		CharacterEnums.ShieldCategory.LIGHT,
		CharacterEnums.ShieldCategory.HEAVY,
	],
	CharacterEnums.CharacterClass.MAGE: [],
	CharacterEnums.CharacterClass.PRIEST: [
		CharacterEnums.ShieldCategory.LIGHT,
		CharacterEnums.ShieldCategory.HEAVY,
	],
	CharacterEnums.CharacterClass.THIEF: [],
	CharacterEnums.CharacterClass.RANGER: [
		CharacterEnums.ShieldCategory.LIGHT,
		CharacterEnums.ShieldCategory.HEAVY,
	],
	CharacterEnums.CharacterClass.NINJA: [],
	CharacterEnums.CharacterClass.VALKYRIE: [
		CharacterEnums.ShieldCategory.LIGHT,
		CharacterEnums.ShieldCategory.HEAVY,
	],
	CharacterEnums.CharacterClass.SAMURAI: [
		CharacterEnums.ShieldCategory.LIGHT,
		CharacterEnums.ShieldCategory.HEAVY,
	],
	CharacterEnums.CharacterClass.LORD: [
		CharacterEnums.ShieldCategory.LIGHT,
		CharacterEnums.ShieldCategory.HEAVY,
	],
	CharacterEnums.CharacterClass.MONK: [],
	CharacterEnums.CharacterClass.BARD: [],
	CharacterEnums.CharacterClass.BISHOP: [
		CharacterEnums.ShieldCategory.LIGHT,
		CharacterEnums.ShieldCategory.HEAVY,
	],
	CharacterEnums.CharacterClass.PSIONIC: [],
	CharacterEnums.CharacterClass.ALCHEMIST: [],
}


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

static func can_use_armor(char_class: CharacterEnums.CharacterClass, category: CharacterEnums.ArmorCategory) -> bool:
	if category == CharacterEnums.ArmorCategory.NONE:
		return true
	var allowed: Array = ARMOR.get(char_class, [])
	return category in allowed


static func can_use_weapon(char_class: CharacterEnums.CharacterClass, weapon_type: Item.WeaponType) -> bool:
	if weapon_type == Item.WeaponType.NONE:
		return true
	var allowed: Array = WEAPONS.get(char_class, [])
	return weapon_type in allowed


static func can_use_shield(char_class: CharacterEnums.CharacterClass, category: CharacterEnums.ShieldCategory) -> bool:
	if category == CharacterEnums.ShieldCategory.NONE:
		return true
	var allowed: Array = SHIELDS.get(char_class, [])
	return category in allowed
