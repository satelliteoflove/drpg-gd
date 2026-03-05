class_name ClassData
extends RefCounted

const CLASS_DEFINITIONS: Dictionary = {
	CharacterEnums.CharacterClass.FIGHTER: {
		"tier": CharacterEnums.ClassTier.BASIC,
		"hp_base": 10,
		"mp_base": 0,
		"spell_schools": [],
		"requirements": {},
		"can_use_magic": false
	},
	CharacterEnums.CharacterClass.MAGE: {
		"tier": CharacterEnums.ClassTier.BASIC,
		"hp_base": 4,
		"mp_base": 4,
		"spell_schools": [CharacterEnums.SpellSchool.MAGE],
		"requirements": {"intelligence": 11},
		"can_use_magic": true
	},
	CharacterEnums.CharacterClass.PRIEST: {
		"tier": CharacterEnums.ClassTier.BASIC,
		"hp_base": 6,
		"mp_base": 3,
		"spell_schools": [CharacterEnums.SpellSchool.PRIEST],
		"requirements": {"piety": 11},
		"can_use_magic": true
	},
	CharacterEnums.CharacterClass.THIEF: {
		"tier": CharacterEnums.ClassTier.BASIC,
		"hp_base": 6,
		"mp_base": 0,
		"spell_schools": [],
		"requirements": {"agility": 11},
		"can_use_magic": false
	},
	CharacterEnums.CharacterClass.ALCHEMIST: {
		"tier": CharacterEnums.ClassTier.BASIC,
		"hp_base": 6,
		"mp_base": 3,
		"spell_schools": [CharacterEnums.SpellSchool.ALCHEMIST],
		"requirements": {"intelligence": 10},
		"can_use_magic": true
	},
	CharacterEnums.CharacterClass.BISHOP: {
		"tier": CharacterEnums.ClassTier.ADVANCED,
		"hp_base": 4,
		"mp_base": 4,
		"spell_schools": [CharacterEnums.SpellSchool.MAGE, CharacterEnums.SpellSchool.PRIEST],
		"requirements": {"intelligence": 12, "piety": 12},
		"can_use_magic": true,
		"is_multiclass_caster": true
	},
	CharacterEnums.CharacterClass.BARD: {
		"tier": CharacterEnums.ClassTier.ADVANCED,
		"hp_base": 5,
		"mp_base": 2,
		"spell_schools": [CharacterEnums.SpellSchool.MAGE],
		"requirements": {"intelligence": 10, "agility": 10},
		"can_use_magic": true,
		"is_hybrid_caster": true
	},
	CharacterEnums.CharacterClass.RANGER: {
		"tier": CharacterEnums.ClassTier.ADVANCED,
		"hp_base": 7,
		"mp_base": 2,
		"spell_schools": [CharacterEnums.SpellSchool.PRIEST, CharacterEnums.SpellSchool.ALCHEMIST],
		"requirements": {"strength": 10, "piety": 10, "vitality": 10},
		"can_use_magic": true,
		"is_hybrid_caster": true
	},
	CharacterEnums.CharacterClass.PSIONIC: {
		"tier": CharacterEnums.ClassTier.ADVANCED,
		"hp_base": 3,
		"mp_base": 3,
		"spell_schools": [CharacterEnums.SpellSchool.PSIONIC],
		"requirements": {"intelligence": 11, "piety": 11},
		"can_use_magic": true
	},
	CharacterEnums.CharacterClass.VALKYRIE: {
		"tier": CharacterEnums.ClassTier.ELITE,
		"hp_base": 7,
		"mp_base": 2,
		"spell_schools": [CharacterEnums.SpellSchool.PRIEST],
		"requirements": {"strength": 12, "piety": 12, "vitality": 12},
		"can_use_magic": true,
		"is_hybrid_caster": true
	},
	CharacterEnums.CharacterClass.SAMURAI: {
		"tier": CharacterEnums.ClassTier.ELITE,
		"hp_base": 8,
		"mp_base": 2,
		"spell_schools": [CharacterEnums.SpellSchool.MAGE],
		"requirements": {"strength": 13, "intelligence": 11, "piety": 10, "vitality": 14, "agility": 10},
		"can_use_magic": true,
		"is_hybrid_caster": true
	},
	CharacterEnums.CharacterClass.LORD: {
		"tier": CharacterEnums.ClassTier.ELITE,
		"hp_base": 8,
		"mp_base": 2,
		"spell_schools": [CharacterEnums.SpellSchool.PRIEST],
		"requirements": {"strength": 13, "intelligence": 10, "piety": 12, "vitality": 13},
		"can_use_magic": true,
		"is_hybrid_caster": true
	},
	CharacterEnums.CharacterClass.MONK: {
		"tier": CharacterEnums.ClassTier.ELITE,
		"hp_base": 6,
		"mp_base": 2,
		"spell_schools": [CharacterEnums.SpellSchool.PRIEST, CharacterEnums.SpellSchool.PSIONIC],
		"requirements": {"strength": 10, "piety": 12, "agility": 12},
		"can_use_magic": true,
		"is_late_caster": true
	},
	CharacterEnums.CharacterClass.NINJA: {
		"tier": CharacterEnums.ClassTier.ELITE,
		"hp_base": 6,
		"mp_base": 2,
		"spell_schools": [CharacterEnums.SpellSchool.MAGE, CharacterEnums.SpellSchool.ALCHEMIST],
		"requirements": {"strength": 12, "intelligence": 10, "agility": 14},
		"can_use_magic": true,
		"is_late_caster": true
	}
}

const PURE_CASTER_SPELL_LEVELS: Array[int] = [1, 3, 5, 7, 9, 11, 13, 21]
const HYBRID_CASTER_SPELL_LEVELS: Array[int] = [4, 6, 8, 10, 12, 14, 16, 24]
const BISHOP_SPELL_LEVELS: Array[int] = [1, 5, 9, 13, 17, 21, 25, 33]
const LATE_CASTER_SPELL_LEVELS: Array[int] = [7, 10, 13, 16, 19, 22, 25, 33]


static func get_class_data(char_class: CharacterEnums.CharacterClass) -> Dictionary:
	return CLASS_DEFINITIONS.get(char_class, {})


static func get_hp_base(char_class: CharacterEnums.CharacterClass) -> int:
	var data: Dictionary = get_class_data(char_class)
	return data.get("hp_base", 6)


static func get_mp_base(char_class: CharacterEnums.CharacterClass) -> int:
	var data: Dictionary = get_class_data(char_class)
	return data.get("mp_base", 0)


static func can_use_magic(char_class: CharacterEnums.CharacterClass) -> bool:
	var data: Dictionary = get_class_data(char_class)
	return data.get("can_use_magic", false)


static func get_spell_schools(char_class: CharacterEnums.CharacterClass) -> Array:
	var data: Dictionary = get_class_data(char_class)
	return data.get("spell_schools", [])


static func get_requirements(char_class: CharacterEnums.CharacterClass) -> Dictionary:
	var data: Dictionary = get_class_data(char_class)
	return data.get("requirements", {})


static func get_tier(char_class: CharacterEnums.CharacterClass) -> CharacterEnums.ClassTier:
	var data: Dictionary = get_class_data(char_class)
	return data.get("tier", CharacterEnums.ClassTier.BASIC)


static func meets_requirements(char_class: CharacterEnums.CharacterClass, stats: Dictionary) -> bool:
	var reqs: Dictionary = get_requirements(char_class)
	for stat_name: String in reqs:
		var required: int = reqs[stat_name]
		var actual: int = stats.get(stat_name, 0)
		if actual < required:
			return false
	return true


static func get_spell_level_at_character_level(char_class: CharacterEnums.CharacterClass, char_level: int) -> int:
	var data: Dictionary = get_class_data(char_class)

	if not data.get("can_use_magic", false):
		return 0

	var levels: Array[int]
	if char_class == CharacterEnums.CharacterClass.BISHOP:
		levels = BISHOP_SPELL_LEVELS
	elif data.get("is_late_caster", false):
		levels = LATE_CASTER_SPELL_LEVELS
	elif data.get("is_hybrid_caster", false):
		levels = HYBRID_CASTER_SPELL_LEVELS
	else:
		levels = PURE_CASTER_SPELL_LEVELS

	var spell_level := 0
	for i in range(levels.size()):
		if char_level >= levels[i]:
			spell_level = i + 1
		else:
			break

	return spell_level


static func get_training_days(from_class: CharacterEnums.CharacterClass, to_class: CharacterEnums.CharacterClass) -> int:
	var to_tier: CharacterEnums.ClassTier = get_tier(to_class)
	var from_tier: CharacterEnums.ClassTier = get_tier(from_class)
	if to_tier == CharacterEnums.ClassTier.ELITE:
		return 365
	if to_tier == CharacterEnums.ClassTier.ADVANCED:
		if from_tier == CharacterEnums.ClassTier.BASIC:
			return 90
		return 60
	return 30


static func get_available_classes_for_race(_race: CharacterEnums.Race) -> Array[CharacterEnums.CharacterClass]:
	var available: Array[CharacterEnums.CharacterClass] = []
	for char_class: int in CLASS_DEFINITIONS:
		available.append(char_class as CharacterEnums.CharacterClass)
	return available
