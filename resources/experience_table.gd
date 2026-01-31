class_name ExperienceTable
extends RefCounted

const CharEnum = preload("res://resources/character_enums.gd")

const BASE_XP_TABLE: Array[int] = [
	0,        # Level 1
	1000,     # Level 2
	2500,     # Level 3
	5000,     # Level 4
	9000,     # Level 5
	15000,    # Level 6
	25000,    # Level 7
	40000,    # Level 8
	60000,    # Level 9
	90000,    # Level 10
	135000,   # Level 11
	200000,   # Level 12
	280000,   # Level 13
	380000,   # Level 14
	500000,   # Level 15
	650000,   # Level 16
	830000,   # Level 17
	1050000,  # Level 18
	1300000,  # Level 19
	1600000   # Level 20
]

const MAX_LEVEL: int = 20

const RACE_CLASS_XP_MODIFIERS: Dictionary = {
	CharEnum.Race.HUMAN: {
		CharEnum.CharacterClass.FIGHTER: 1.0,
		CharEnum.CharacterClass.MAGE: 1.0,
		CharEnum.CharacterClass.PRIEST: 1.0,
		CharEnum.CharacterClass.THIEF: 1.0,
		CharEnum.CharacterClass.ALCHEMIST: 1.0,
		CharEnum.CharacterClass.BISHOP: 1.2,
		CharEnum.CharacterClass.BARD: 1.1,
		CharEnum.CharacterClass.RANGER: 1.1,
		CharEnum.CharacterClass.PSIONIC: 1.1,
		CharEnum.CharacterClass.VALKYRIE: 1.2,
		CharEnum.CharacterClass.SAMURAI: 1.3,
		CharEnum.CharacterClass.LORD: 1.3,
		CharEnum.CharacterClass.MONK: 1.3,
		CharEnum.CharacterClass.NINJA: 1.4
	},
	CharEnum.Race.ELF: {
		CharEnum.CharacterClass.FIGHTER: 1.1,
		CharEnum.CharacterClass.MAGE: 0.9,
		CharEnum.CharacterClass.PRIEST: 0.9,
		CharEnum.CharacterClass.THIEF: 1.1,
		CharEnum.CharacterClass.ALCHEMIST: 1.0,
		CharEnum.CharacterClass.BISHOP: 1.1,
		CharEnum.CharacterClass.BARD: 1.0,
		CharEnum.CharacterClass.RANGER: 1.0,
		CharEnum.CharacterClass.PSIONIC: 1.0,
		CharEnum.CharacterClass.VALKYRIE: 1.3,
		CharEnum.CharacterClass.SAMURAI: 1.4,
		CharEnum.CharacterClass.LORD: 1.4,
		CharEnum.CharacterClass.MONK: 1.4,
		CharEnum.CharacterClass.NINJA: 1.5
	},
	CharEnum.Race.DWARF: {
		CharEnum.CharacterClass.FIGHTER: 0.9,
		CharEnum.CharacterClass.MAGE: 1.3,
		CharEnum.CharacterClass.PRIEST: 1.0,
		CharEnum.CharacterClass.THIEF: 1.2,
		CharEnum.CharacterClass.ALCHEMIST: 1.1,
		CharEnum.CharacterClass.BISHOP: 1.3,
		CharEnum.CharacterClass.BARD: 1.2,
		CharEnum.CharacterClass.RANGER: 1.2,
		CharEnum.CharacterClass.PSIONIC: 1.3,
		CharEnum.CharacterClass.VALKYRIE: 1.3,
		CharEnum.CharacterClass.SAMURAI: 1.4,
		CharEnum.CharacterClass.LORD: 1.2,
		CharEnum.CharacterClass.MONK: 1.4,
		CharEnum.CharacterClass.NINJA: 1.5
	},
	CharEnum.Race.GNOME: {
		CharEnum.CharacterClass.FIGHTER: 1.0,
		CharEnum.CharacterClass.MAGE: 1.1,
		CharEnum.CharacterClass.PRIEST: 0.8,
		CharEnum.CharacterClass.THIEF: 1.0,
		CharEnum.CharacterClass.ALCHEMIST: 0.9,
		CharEnum.CharacterClass.BISHOP: 1.0,
		CharEnum.CharacterClass.BARD: 1.1,
		CharEnum.CharacterClass.RANGER: 1.1,
		CharEnum.CharacterClass.PSIONIC: 1.0,
		CharEnum.CharacterClass.VALKYRIE: 1.4,
		CharEnum.CharacterClass.SAMURAI: 1.5,
		CharEnum.CharacterClass.LORD: 1.4,
		CharEnum.CharacterClass.MONK: 1.3,
		CharEnum.CharacterClass.NINJA: 1.4
	},
	CharEnum.Race.HOBBIT: {
		CharEnum.CharacterClass.FIGHTER: 1.1,
		CharEnum.CharacterClass.MAGE: 1.1,
		CharEnum.CharacterClass.PRIEST: 1.2,
		CharEnum.CharacterClass.THIEF: 0.8,
		CharEnum.CharacterClass.ALCHEMIST: 1.1,
		CharEnum.CharacterClass.BISHOP: 1.3,
		CharEnum.CharacterClass.BARD: 1.0,
		CharEnum.CharacterClass.RANGER: 1.0,
		CharEnum.CharacterClass.PSIONIC: 1.2,
		CharEnum.CharacterClass.VALKYRIE: 1.5,
		CharEnum.CharacterClass.SAMURAI: 1.5,
		CharEnum.CharacterClass.LORD: 1.5,
		CharEnum.CharacterClass.MONK: 1.4,
		CharEnum.CharacterClass.NINJA: 1.3
	},
	CharEnum.Race.FAERIE: {
		CharEnum.CharacterClass.FIGHTER: 1.4,
		CharEnum.CharacterClass.MAGE: 0.8,
		CharEnum.CharacterClass.PRIEST: 1.2,
		CharEnum.CharacterClass.THIEF: 0.9,
		CharEnum.CharacterClass.ALCHEMIST: 1.0,
		CharEnum.CharacterClass.BISHOP: 1.1,
		CharEnum.CharacterClass.BARD: 0.9,
		CharEnum.CharacterClass.RANGER: 1.0,
		CharEnum.CharacterClass.PSIONIC: 0.9,
		CharEnum.CharacterClass.VALKYRIE: 1.4,
		CharEnum.CharacterClass.SAMURAI: 1.6,
		CharEnum.CharacterClass.LORD: 1.6,
		CharEnum.CharacterClass.MONK: 1.5,
		CharEnum.CharacterClass.NINJA: 1.3
	},
	CharEnum.Race.LIZMAN: {
		CharEnum.CharacterClass.FIGHTER: 0.8,
		CharEnum.CharacterClass.MAGE: 1.4,
		CharEnum.CharacterClass.PRIEST: 1.4,
		CharEnum.CharacterClass.THIEF: 1.3,
		CharEnum.CharacterClass.ALCHEMIST: 1.3,
		CharEnum.CharacterClass.BISHOP: 1.5,
		CharEnum.CharacterClass.BARD: 1.4,
		CharEnum.CharacterClass.RANGER: 1.2,
		CharEnum.CharacterClass.PSIONIC: 1.4,
		CharEnum.CharacterClass.VALKYRIE: 1.2,
		CharEnum.CharacterClass.SAMURAI: 1.3,
		CharEnum.CharacterClass.LORD: 1.3,
		CharEnum.CharacterClass.MONK: 1.3,
		CharEnum.CharacterClass.NINJA: 1.5
	},
	CharEnum.Race.DRACON: {
		CharEnum.CharacterClass.FIGHTER: 0.9,
		CharEnum.CharacterClass.MAGE: 1.2,
		CharEnum.CharacterClass.PRIEST: 1.3,
		CharEnum.CharacterClass.THIEF: 1.1,
		CharEnum.CharacterClass.ALCHEMIST: 1.2,
		CharEnum.CharacterClass.BISHOP: 1.4,
		CharEnum.CharacterClass.BARD: 1.2,
		CharEnum.CharacterClass.RANGER: 1.1,
		CharEnum.CharacterClass.PSIONIC: 1.3,
		CharEnum.CharacterClass.VALKYRIE: 1.3,
		CharEnum.CharacterClass.SAMURAI: 1.3,
		CharEnum.CharacterClass.LORD: 1.3,
		CharEnum.CharacterClass.MONK: 1.4,
		CharEnum.CharacterClass.NINJA: 1.5
	},
	CharEnum.Race.RAWULF: {
		CharEnum.CharacterClass.FIGHTER: 1.1,
		CharEnum.CharacterClass.MAGE: 1.3,
		CharEnum.CharacterClass.PRIEST: 0.9,
		CharEnum.CharacterClass.THIEF: 1.1,
		CharEnum.CharacterClass.ALCHEMIST: 1.0,
		CharEnum.CharacterClass.BISHOP: 1.2,
		CharEnum.CharacterClass.BARD: 1.1,
		CharEnum.CharacterClass.RANGER: 1.0,
		CharEnum.CharacterClass.PSIONIC: 1.0,
		CharEnum.CharacterClass.VALKYRIE: 1.4,
		CharEnum.CharacterClass.SAMURAI: 1.4,
		CharEnum.CharacterClass.LORD: 1.3,
		CharEnum.CharacterClass.MONK: 1.3,
		CharEnum.CharacterClass.NINJA: 1.4
	},
	CharEnum.Race.MOOK: {
		CharEnum.CharacterClass.FIGHTER: 1.0,
		CharEnum.CharacterClass.MAGE: 1.0,
		CharEnum.CharacterClass.PRIEST: 1.3,
		CharEnum.CharacterClass.THIEF: 1.1,
		CharEnum.CharacterClass.ALCHEMIST: 1.1,
		CharEnum.CharacterClass.BISHOP: 1.2,
		CharEnum.CharacterClass.BARD: 1.1,
		CharEnum.CharacterClass.RANGER: 1.1,
		CharEnum.CharacterClass.PSIONIC: 1.1,
		CharEnum.CharacterClass.VALKYRIE: 1.3,
		CharEnum.CharacterClass.SAMURAI: 1.3,
		CharEnum.CharacterClass.LORD: 1.4,
		CharEnum.CharacterClass.MONK: 1.4,
		CharEnum.CharacterClass.NINJA: 1.4
	},
	CharEnum.Race.FELPURR: {
		CharEnum.CharacterClass.FIGHTER: 1.2,
		CharEnum.CharacterClass.MAGE: 1.0,
		CharEnum.CharacterClass.PRIEST: 1.2,
		CharEnum.CharacterClass.THIEF: 0.9,
		CharEnum.CharacterClass.ALCHEMIST: 1.1,
		CharEnum.CharacterClass.BISHOP: 1.3,
		CharEnum.CharacterClass.BARD: 1.0,
		CharEnum.CharacterClass.RANGER: 1.0,
		CharEnum.CharacterClass.PSIONIC: 1.1,
		CharEnum.CharacterClass.VALKYRIE: 1.3,
		CharEnum.CharacterClass.SAMURAI: 1.4,
		CharEnum.CharacterClass.LORD: 1.5,
		CharEnum.CharacterClass.MONK: 1.3,
		CharEnum.CharacterClass.NINJA: 1.3
	}
}


static func get_xp_for_level(level: int) -> int:
	if level < 1:
		return 0
	if level > MAX_LEVEL:
		level = MAX_LEVEL
	return BASE_XP_TABLE[level - 1]


static func get_xp_modifier(race: CharEnum.Race, char_class: CharEnum.CharacterClass) -> float:
	var race_mods: Dictionary = RACE_CLASS_XP_MODIFIERS.get(race, {})
	return race_mods.get(char_class, 1.0)


static func get_required_xp(level: int, race: CharEnum.Race, char_class: CharEnum.CharacterClass) -> int:
	var base_xp := get_xp_for_level(level)
	var modifier := get_xp_modifier(race, char_class)
	return int(base_xp * modifier)


static func get_level_for_xp(xp: int, race: CharEnum.Race, char_class: CharEnum.CharacterClass) -> int:
	var level := 1
	for i in range(MAX_LEVEL, 0, -1):
		var required := get_required_xp(i, race, char_class)
		if xp >= required:
			level = i
			break
	return level


static func get_xp_to_next_level(current_xp: int, current_level: int, race: CharEnum.Race, char_class: CharEnum.CharacterClass) -> int:
	if current_level >= MAX_LEVEL:
		return 0
	var next_required := get_required_xp(current_level + 1, race, char_class)
	return maxi(0, next_required - current_xp)
