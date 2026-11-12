class_name ExperienceTable
extends RefCounted

# Tuned for a campaign of roughly 10-15 hours: about a dozen fights to reach
# level 2 and ~190 to reach level 10, the level the floor 8 boss expects.
# (The original Wizardry-scale table needed ~600 fights to reach level 10.)
const BASE_XP_TABLE: Array[int] = [
	0,       # Level 1
	300,     # Level 2
	800,     # Level 3
	1600,    # Level 4
	2800,    # Level 5
	4600,    # Level 6
	7200,    # Level 7
	11000,   # Level 8
	16500,   # Level 9
	24000,   # Level 10
	34000,   # Level 11
	48000,   # Level 12
	66000,   # Level 13
	88000,   # Level 14
	115000,  # Level 15
	148000,  # Level 16
	188000,  # Level 17
	236000,  # Level 18
	292000,  # Level 19
	360000   # Level 20
]

## Levels aren't capped. Past the end of the table, each level costs the same
## as the last step in it, as in Wizardry, so a long-lived character keeps
## growing across campaigns.
const FLAT_XP_PER_LEVEL: int = 68000

const RACE_CLASS_XP_MODIFIERS: Dictionary = {
	CharacterEnums.Race.HUMAN: {
		CharacterEnums.CharacterClass.FIGHTER: 1.0,
		CharacterEnums.CharacterClass.MAGE: 1.0,
		CharacterEnums.CharacterClass.PRIEST: 1.0,
		CharacterEnums.CharacterClass.THIEF: 1.0,
		CharacterEnums.CharacterClass.ALCHEMIST: 1.0,
		CharacterEnums.CharacterClass.BISHOP: 1.2,
		CharacterEnums.CharacterClass.BARD: 1.1,
		CharacterEnums.CharacterClass.RANGER: 1.1,
		CharacterEnums.CharacterClass.PSIONIC: 1.1,
		CharacterEnums.CharacterClass.VALKYRIE: 1.2,
		CharacterEnums.CharacterClass.SAMURAI: 1.3,
		CharacterEnums.CharacterClass.LORD: 1.3,
		CharacterEnums.CharacterClass.MONK: 1.3,
		CharacterEnums.CharacterClass.NINJA: 1.4
	},
	CharacterEnums.Race.ELF: {
		CharacterEnums.CharacterClass.FIGHTER: 1.1,
		CharacterEnums.CharacterClass.MAGE: 0.9,
		CharacterEnums.CharacterClass.PRIEST: 0.9,
		CharacterEnums.CharacterClass.THIEF: 1.1,
		CharacterEnums.CharacterClass.ALCHEMIST: 1.0,
		CharacterEnums.CharacterClass.BISHOP: 1.1,
		CharacterEnums.CharacterClass.BARD: 1.0,
		CharacterEnums.CharacterClass.RANGER: 1.0,
		CharacterEnums.CharacterClass.PSIONIC: 1.0,
		CharacterEnums.CharacterClass.VALKYRIE: 1.3,
		CharacterEnums.CharacterClass.SAMURAI: 1.4,
		CharacterEnums.CharacterClass.LORD: 1.4,
		CharacterEnums.CharacterClass.MONK: 1.4,
		CharacterEnums.CharacterClass.NINJA: 1.5
	},
	CharacterEnums.Race.DWARF: {
		CharacterEnums.CharacterClass.FIGHTER: 0.9,
		CharacterEnums.CharacterClass.MAGE: 1.3,
		CharacterEnums.CharacterClass.PRIEST: 1.0,
		CharacterEnums.CharacterClass.THIEF: 1.2,
		CharacterEnums.CharacterClass.ALCHEMIST: 1.1,
		CharacterEnums.CharacterClass.BISHOP: 1.3,
		CharacterEnums.CharacterClass.BARD: 1.2,
		CharacterEnums.CharacterClass.RANGER: 1.2,
		CharacterEnums.CharacterClass.PSIONIC: 1.3,
		CharacterEnums.CharacterClass.VALKYRIE: 1.3,
		CharacterEnums.CharacterClass.SAMURAI: 1.4,
		CharacterEnums.CharacterClass.LORD: 1.2,
		CharacterEnums.CharacterClass.MONK: 1.4,
		CharacterEnums.CharacterClass.NINJA: 1.5
	},
	CharacterEnums.Race.GNOME: {
		CharacterEnums.CharacterClass.FIGHTER: 1.0,
		CharacterEnums.CharacterClass.MAGE: 1.1,
		CharacterEnums.CharacterClass.PRIEST: 0.8,
		CharacterEnums.CharacterClass.THIEF: 1.0,
		CharacterEnums.CharacterClass.ALCHEMIST: 0.9,
		CharacterEnums.CharacterClass.BISHOP: 1.0,
		CharacterEnums.CharacterClass.BARD: 1.1,
		CharacterEnums.CharacterClass.RANGER: 1.1,
		CharacterEnums.CharacterClass.PSIONIC: 1.0,
		CharacterEnums.CharacterClass.VALKYRIE: 1.4,
		CharacterEnums.CharacterClass.SAMURAI: 1.5,
		CharacterEnums.CharacterClass.LORD: 1.4,
		CharacterEnums.CharacterClass.MONK: 1.3,
		CharacterEnums.CharacterClass.NINJA: 1.4
	},
	CharacterEnums.Race.HOBBIT: {
		CharacterEnums.CharacterClass.FIGHTER: 1.1,
		CharacterEnums.CharacterClass.MAGE: 1.1,
		CharacterEnums.CharacterClass.PRIEST: 1.2,
		CharacterEnums.CharacterClass.THIEF: 0.8,
		CharacterEnums.CharacterClass.ALCHEMIST: 1.1,
		CharacterEnums.CharacterClass.BISHOP: 1.3,
		CharacterEnums.CharacterClass.BARD: 1.0,
		CharacterEnums.CharacterClass.RANGER: 1.0,
		CharacterEnums.CharacterClass.PSIONIC: 1.2,
		CharacterEnums.CharacterClass.VALKYRIE: 1.5,
		CharacterEnums.CharacterClass.SAMURAI: 1.5,
		CharacterEnums.CharacterClass.LORD: 1.5,
		CharacterEnums.CharacterClass.MONK: 1.4,
		CharacterEnums.CharacterClass.NINJA: 1.3
	},
	CharacterEnums.Race.FAERIE: {
		CharacterEnums.CharacterClass.FIGHTER: 1.4,
		CharacterEnums.CharacterClass.MAGE: 0.8,
		CharacterEnums.CharacterClass.PRIEST: 1.2,
		CharacterEnums.CharacterClass.THIEF: 0.9,
		CharacterEnums.CharacterClass.ALCHEMIST: 1.0,
		CharacterEnums.CharacterClass.BISHOP: 1.1,
		CharacterEnums.CharacterClass.BARD: 0.9,
		CharacterEnums.CharacterClass.RANGER: 1.0,
		CharacterEnums.CharacterClass.PSIONIC: 0.9,
		CharacterEnums.CharacterClass.VALKYRIE: 1.4,
		CharacterEnums.CharacterClass.SAMURAI: 1.6,
		CharacterEnums.CharacterClass.LORD: 1.6,
		CharacterEnums.CharacterClass.MONK: 1.5,
		CharacterEnums.CharacterClass.NINJA: 1.3
	},
	CharacterEnums.Race.LIZMAN: {
		CharacterEnums.CharacterClass.FIGHTER: 0.7,
		CharacterEnums.CharacterClass.MAGE: 1.4,
		CharacterEnums.CharacterClass.PRIEST: 1.4,
		CharacterEnums.CharacterClass.THIEF: 1.3,
		CharacterEnums.CharacterClass.ALCHEMIST: 1.3,
		CharacterEnums.CharacterClass.BISHOP: 1.5,
		CharacterEnums.CharacterClass.BARD: 1.4,
		CharacterEnums.CharacterClass.RANGER: 1.2,
		CharacterEnums.CharacterClass.PSIONIC: 1.4,
		CharacterEnums.CharacterClass.VALKYRIE: 1.2,
		CharacterEnums.CharacterClass.SAMURAI: 1.3,
		CharacterEnums.CharacterClass.LORD: 1.3,
		CharacterEnums.CharacterClass.MONK: 1.3,
		CharacterEnums.CharacterClass.NINJA: 1.5
	},
	CharacterEnums.Race.DRACON: {
		CharacterEnums.CharacterClass.FIGHTER: 0.9,
		CharacterEnums.CharacterClass.MAGE: 1.2,
		CharacterEnums.CharacterClass.PRIEST: 1.3,
		CharacterEnums.CharacterClass.THIEF: 1.1,
		CharacterEnums.CharacterClass.ALCHEMIST: 1.2,
		CharacterEnums.CharacterClass.BISHOP: 1.4,
		CharacterEnums.CharacterClass.BARD: 1.2,
		CharacterEnums.CharacterClass.RANGER: 1.1,
		CharacterEnums.CharacterClass.PSIONIC: 1.3,
		CharacterEnums.CharacterClass.VALKYRIE: 1.3,
		CharacterEnums.CharacterClass.SAMURAI: 1.3,
		CharacterEnums.CharacterClass.LORD: 1.3,
		CharacterEnums.CharacterClass.MONK: 1.4,
		CharacterEnums.CharacterClass.NINJA: 1.5
	},
	CharacterEnums.Race.RAWULF: {
		CharacterEnums.CharacterClass.FIGHTER: 1.1,
		CharacterEnums.CharacterClass.MAGE: 1.3,
		CharacterEnums.CharacterClass.PRIEST: 0.7,
		CharacterEnums.CharacterClass.THIEF: 1.1,
		CharacterEnums.CharacterClass.ALCHEMIST: 1.0,
		CharacterEnums.CharacterClass.BISHOP: 1.2,
		CharacterEnums.CharacterClass.BARD: 1.1,
		CharacterEnums.CharacterClass.RANGER: 1.0,
		CharacterEnums.CharacterClass.PSIONIC: 1.0,
		CharacterEnums.CharacterClass.VALKYRIE: 1.4,
		CharacterEnums.CharacterClass.SAMURAI: 1.4,
		CharacterEnums.CharacterClass.LORD: 1.3,
		CharacterEnums.CharacterClass.MONK: 1.3,
		CharacterEnums.CharacterClass.NINJA: 1.4
	},
	CharacterEnums.Race.MOOK: {
		CharacterEnums.CharacterClass.FIGHTER: 1.0,
		CharacterEnums.CharacterClass.MAGE: 1.0,
		CharacterEnums.CharacterClass.PRIEST: 1.3,
		CharacterEnums.CharacterClass.THIEF: 1.1,
		CharacterEnums.CharacterClass.ALCHEMIST: 1.1,
		CharacterEnums.CharacterClass.BISHOP: 1.2,
		CharacterEnums.CharacterClass.BARD: 1.1,
		CharacterEnums.CharacterClass.RANGER: 0.7,
		CharacterEnums.CharacterClass.PSIONIC: 1.1,
		CharacterEnums.CharacterClass.VALKYRIE: 1.3,
		CharacterEnums.CharacterClass.SAMURAI: 1.3,
		CharacterEnums.CharacterClass.LORD: 1.4,
		CharacterEnums.CharacterClass.MONK: 1.4,
		CharacterEnums.CharacterClass.NINJA: 1.4
	},
	CharacterEnums.Race.FELPURR: {
		CharacterEnums.CharacterClass.FIGHTER: 1.2,
		CharacterEnums.CharacterClass.MAGE: 1.0,
		CharacterEnums.CharacterClass.PRIEST: 1.2,
		CharacterEnums.CharacterClass.THIEF: 0.7,
		CharacterEnums.CharacterClass.ALCHEMIST: 1.1,
		CharacterEnums.CharacterClass.BISHOP: 1.3,
		CharacterEnums.CharacterClass.BARD: 1.0,
		CharacterEnums.CharacterClass.RANGER: 1.0,
		CharacterEnums.CharacterClass.PSIONIC: 1.1,
		CharacterEnums.CharacterClass.VALKYRIE: 1.3,
		CharacterEnums.CharacterClass.SAMURAI: 1.4,
		CharacterEnums.CharacterClass.LORD: 1.5,
		CharacterEnums.CharacterClass.MONK: 1.3,
		CharacterEnums.CharacterClass.NINJA: 1.3
	}
}


static func get_xp_for_level(level: int) -> int:
	if level < 1:
		return 0
	if level <= BASE_XP_TABLE.size():
		return BASE_XP_TABLE[level - 1]
	return BASE_XP_TABLE[-1] + (level - BASE_XP_TABLE.size()) * FLAT_XP_PER_LEVEL


static func get_xp_modifier(race: CharacterEnums.Race, char_class: CharacterEnums.CharacterClass) -> float:
	var race_mods: Dictionary = RACE_CLASS_XP_MODIFIERS.get(race, {})
	return race_mods.get(char_class, 1.0)


static func get_required_xp(level: int, race: CharacterEnums.Race, char_class: CharacterEnums.CharacterClass) -> int:
	var base_xp := get_xp_for_level(level)
	var modifier := get_xp_modifier(race, char_class)
	return int(base_xp * modifier)


static func get_level_for_xp(xp: int, race: CharacterEnums.Race, char_class: CharacterEnums.CharacterClass) -> int:
	var level := 1
	while xp >= get_required_xp(level + 1, race, char_class):
		level += 1
	return level


static func get_xp_to_next_level(current_xp: int, current_level: int, race: CharacterEnums.Race, char_class: CharacterEnums.CharacterClass) -> int:
	var next_required := get_required_xp(current_level + 1, race, char_class)
	return maxi(0, next_required - current_xp)
