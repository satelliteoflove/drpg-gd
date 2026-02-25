class_name CharacterEnums
extends RefCounted

enum Race {
	HUMAN,
	ELF,
	DWARF,
	GNOME,
	HOBBIT,
	FAERIE,
	LIZMAN,
	DRACON,
	RAWULF,
	MOOK,
	FELPURR
}

enum CharacterClass {
	FIGHTER,
	MAGE,
	PRIEST,
	THIEF,
	ALCHEMIST,
	BISHOP,
	BARD,
	RANGER,
	PSIONIC,
	VALKYRIE,
	SAMURAI,
	LORD,
	MONK,
	NINJA
}

enum Alignment {
	GOOD,
	NEUTRAL,
	EVIL
}

enum Gender {
	MALE,
	FEMALE
}

enum SpellSchool {
	NONE,
	MAGE,
	PRIEST,
	ALCHEMIST,
	PSIONIC
}

enum ArmorCategory {
	NONE,
	CLOTH,
	LEATHER,
	CHAIN,
	PLATE
}

enum ShieldCategory {
	NONE,
	LIGHT,
	HEAVY
}

enum StatusEffect {
	NONE,
	POISONED,
	PARALYZED,
	ASLEEP,
	STONED,
	CONFUSED,
	SILENCED,
	BLINDED,
	AFRAID,
	CHARMED,
	BERSERK,
	CURSED,
	BLESSED,
	DEAD,
	ASHED,
	LOST
}

enum SaveType {
	PHYSICAL,
	MENTAL,
	MAGICAL,
	DEATH
}

enum SpellTargetType {
	SELF,
	SINGLE_ALLY,
	SINGLE_ENEMY,
	ALL_ALLIES,
	ALL_ENEMIES,
	DEAD_ALLY,
	SPLASH,
	ROW,
	COLUMN
}

enum Element {
	NONE,
	FIRE,
	ICE,
	LIGHTNING,
	HOLY,
	DARK,
	PHYSICAL,
	PSYCHIC,
	ACID
}

enum ClassTier {
	BASIC,
	ADVANCED,
	ELITE
}

enum CreatureType {
	HUMANOID,
	BEAST,
	UNDEAD,
	DEMON,
	DRAGON,
	ELEMENTAL,
	CONSTRUCT,
	PLANT,
	INSECT,
	AQUATIC
}

const RACE_NAMES: Dictionary = {
	Race.HUMAN: "Human",
	Race.ELF: "Elf",
	Race.DWARF: "Dwarf",
	Race.GNOME: "Gnome",
	Race.HOBBIT: "Hobbit",
	Race.FAERIE: "Faerie",
	Race.LIZMAN: "Lizman",
	Race.DRACON: "Dracon",
	Race.RAWULF: "Rawulf",
	Race.MOOK: "Mook",
	Race.FELPURR: "Felpurr"
}

const CLASS_NAMES: Dictionary = {
	CharacterClass.FIGHTER: "Fighter",
	CharacterClass.MAGE: "Mage",
	CharacterClass.PRIEST: "Priest",
	CharacterClass.THIEF: "Thief",
	CharacterClass.ALCHEMIST: "Alchemist",
	CharacterClass.BISHOP: "Bishop",
	CharacterClass.BARD: "Bard",
	CharacterClass.RANGER: "Ranger",
	CharacterClass.PSIONIC: "Psionic",
	CharacterClass.VALKYRIE: "Valkyrie",
	CharacterClass.SAMURAI: "Samurai",
	CharacterClass.LORD: "Lord",
	CharacterClass.MONK: "Monk",
	CharacterClass.NINJA: "Ninja"
}

const ALIGNMENT_NAMES: Dictionary = {
	Alignment.GOOD: "Good",
	Alignment.NEUTRAL: "Neutral",
	Alignment.EVIL: "Evil"
}

const STATUS_NAMES: Dictionary = {
	StatusEffect.NONE: "OK",
	StatusEffect.POISONED: "Poisoned",
	StatusEffect.PARALYZED: "Paralyzed",
	StatusEffect.ASLEEP: "Asleep",
	StatusEffect.STONED: "Petrified",
	StatusEffect.CONFUSED: "Confused",
	StatusEffect.SILENCED: "Silenced",
	StatusEffect.BLINDED: "Blinded",
	StatusEffect.AFRAID: "Afraid",
	StatusEffect.CHARMED: "Charmed",
	StatusEffect.BERSERK: "Berserk",
	StatusEffect.CURSED: "Cursed",
	StatusEffect.BLESSED: "Blessed",
	StatusEffect.DEAD: "Dead",
	StatusEffect.ASHED: "Ashed",
	StatusEffect.LOST: "Lost"
}

const STATUS_NOUN_NAMES: Dictionary = {
	StatusEffect.NONE: "nothing",
	StatusEffect.POISONED: "poison",
	StatusEffect.PARALYZED: "paralysis",
	StatusEffect.ASLEEP: "sleep",
	StatusEffect.STONED: "petrification",
	StatusEffect.CONFUSED: "confusion",
	StatusEffect.SILENCED: "silence",
	StatusEffect.BLINDED: "blindness",
	StatusEffect.AFRAID: "fear",
	StatusEffect.CHARMED: "charm",
	StatusEffect.BERSERK: "frenzy",
	StatusEffect.CURSED: "a curse",
	StatusEffect.BLESSED: "a blessing",
	StatusEffect.DEAD: "death",
	StatusEffect.ASHED: "incineration",
	StatusEffect.LOST: "banishment"
}

const STATUS_ABBREVIATIONS: Dictionary = {
	StatusEffect.NONE: "OK",
	StatusEffect.POISONED: "PSN",
	StatusEffect.PARALYZED: "PAR",
	StatusEffect.ASLEEP: "SLP",
	StatusEffect.STONED: "STN",
	StatusEffect.CONFUSED: "CNF",
	StatusEffect.SILENCED: "SIL",
	StatusEffect.BLINDED: "BLD",
	StatusEffect.AFRAID: "AFR",
	StatusEffect.CHARMED: "CHM",
	StatusEffect.BERSERK: "BRK",
	StatusEffect.CURSED: "CRS",
	StatusEffect.BLESSED: "BLS",
	StatusEffect.DEAD: "DEAD",
	StatusEffect.ASHED: "ASH",
	StatusEffect.LOST: "LOST"
}

const DISABLING_STATUSES: Array[StatusEffect] = [
	StatusEffect.ASLEEP,
	StatusEffect.PARALYZED,
	StatusEffect.STONED
]

const MENTAL_STATUSES: Array[StatusEffect] = [
	StatusEffect.CONFUSED,
	StatusEffect.CHARMED,
	StatusEffect.BERSERK,
	StatusEffect.AFRAID
]

const DEATH_STATUSES: Array[StatusEffect] = [
	StatusEffect.DEAD,
	StatusEffect.ASHED,
	StatusEffect.LOST
]

const BENEFICIAL_STATUSES: Array[StatusEffect] = [
	StatusEffect.BLESSED,
]

const RACIAL_IMMUNITIES: Dictionary = {
	Race.ELF: [StatusEffect.ASLEEP],
	Race.DWARF: [StatusEffect.POISONED],
	Race.HOBBIT: [StatusEffect.PARALYZED, StatusEffect.STONED],
	Race.DRACON: [StatusEffect.PARALYZED, StatusEffect.STONED]
}

const ELEMENT_NAMES: Dictionary = {
	Element.NONE: "None",
	Element.FIRE: "Fire",
	Element.ICE: "Ice",
	Element.LIGHTNING: "Lightning",
	Element.HOLY: "Holy",
	Element.DARK: "Dark",
	Element.PHYSICAL: "Physical",
	Element.PSYCHIC: "Psychic",
	Element.ACID: "Acid"
}

const CREATURE_TYPE_NAMES: Dictionary = {
	CreatureType.HUMANOID: "Humanoid",
	CreatureType.BEAST: "Beast",
	CreatureType.UNDEAD: "Undead",
	CreatureType.DEMON: "Demon",
	CreatureType.DRAGON: "Dragon",
	CreatureType.ELEMENTAL: "Elemental",
	CreatureType.CONSTRUCT: "Construct",
	CreatureType.PLANT: "Plant",
	CreatureType.INSECT: "Insect",
	CreatureType.AQUATIC: "Aquatic"
}

const RACE_STAT_RANGES: Dictionary = {
	Race.HUMAN: {
		"strength": Vector2i(9, 19),
		"intelligence": Vector2i(8, 18),
		"piety": Vector2i(8, 18),
		"vitality": Vector2i(9, 19),
		"agility": Vector2i(8, 18),
		"luck": Vector2i(8, 18)
	},
	Race.ELF: {
		"strength": Vector2i(7, 17),
		"intelligence": Vector2i(10, 20),
		"piety": Vector2i(10, 20),
		"vitality": Vector2i(7, 17),
		"agility": Vector2i(9, 19),
		"luck": Vector2i(8, 18)
	},
	Race.DWARF: {
		"strength": Vector2i(11, 21),
		"intelligence": Vector2i(6, 16),
		"piety": Vector2i(10, 20),
		"vitality": Vector2i(12, 22),
		"agility": Vector2i(7, 17),
		"luck": Vector2i(7, 17)
	},
	Race.GNOME: {
		"strength": Vector2i(10, 20),
		"intelligence": Vector2i(7, 17),
		"piety": Vector2i(13, 23),
		"vitality": Vector2i(10, 20),
		"agility": Vector2i(6, 16),
		"luck": Vector2i(7, 17)
	},
	Race.HOBBIT: {
		"strength": Vector2i(8, 18),
		"intelligence": Vector2i(7, 17),
		"piety": Vector2i(6, 16),
		"vitality": Vector2i(9, 19),
		"agility": Vector2i(10, 20),
		"luck": Vector2i(11, 21)
	},
	Race.FAERIE: {
		"strength": Vector2i(5, 15),
		"intelligence": Vector2i(11, 21),
		"piety": Vector2i(6, 16),
		"vitality": Vector2i(6, 16),
		"agility": Vector2i(14, 24),
		"luck": Vector2i(11, 21)
	},
	Race.LIZMAN: {
		"strength": Vector2i(12, 22),
		"intelligence": Vector2i(5, 15),
		"piety": Vector2i(5, 15),
		"vitality": Vector2i(14, 24),
		"agility": Vector2i(9, 19),
		"luck": Vector2i(7, 17)
	},
	Race.DRACON: {
		"strength": Vector2i(10, 20),
		"intelligence": Vector2i(7, 17),
		"piety": Vector2i(6, 16),
		"vitality": Vector2i(12, 22),
		"agility": Vector2i(8, 18),
		"luck": Vector2i(8, 18)
	},
	Race.RAWULF: {
		"strength": Vector2i(8, 18),
		"intelligence": Vector2i(6, 16),
		"piety": Vector2i(12, 22),
		"vitality": Vector2i(10, 20),
		"agility": Vector2i(8, 18),
		"luck": Vector2i(9, 19)
	},
	Race.MOOK: {
		"strength": Vector2i(10, 20),
		"intelligence": Vector2i(10, 20),
		"piety": Vector2i(6, 16),
		"vitality": Vector2i(10, 20),
		"agility": Vector2i(7, 17),
		"luck": Vector2i(8, 18)
	},
	Race.FELPURR: {
		"strength": Vector2i(7, 17),
		"intelligence": Vector2i(10, 20),
		"piety": Vector2i(7, 17),
		"vitality": Vector2i(7, 17),
		"agility": Vector2i(12, 22),
		"luck": Vector2i(10, 20)
	}
}

const RACE_BASE_AGE: Dictionary = {
	Race.HUMAN: 18,
	Race.ELF: 75,
	Race.DWARF: 35,
	Race.GNOME: 50,
	Race.HOBBIT: 25,
	Race.FAERIE: 100,
	Race.LIZMAN: 15,
	Race.DRACON: 20,
	Race.RAWULF: 12,
	Race.MOOK: 10,
	Race.FELPURR: 14
}


static func get_race_name(race: Race) -> String:
	return RACE_NAMES.get(race, "Unknown")


static func get_class_name(char_class: CharacterClass) -> String:
	return CLASS_NAMES.get(char_class, "Unknown")


static func get_alignment_name(alignment: Alignment) -> String:
	return ALIGNMENT_NAMES.get(alignment, "Unknown")


static func get_stat_range(race: Race, stat: String) -> Vector2i:
	var ranges: Dictionary = RACE_STAT_RANGES.get(race, {})
	return ranges.get(stat, Vector2i(8, 18))


static func roll_stat(race: Race, stat: String) -> int:
	var range_vec: Vector2i = get_stat_range(race, stat)
	return randi_range(range_vec.x, range_vec.y)


static func get_base_age(race: Race) -> int:
	return RACE_BASE_AGE.get(race, 18)


static func get_status_name(status: StatusEffect) -> String:
	return STATUS_NAMES.get(status, "Unknown")


static func get_status_noun(status: StatusEffect) -> String:
	return STATUS_NOUN_NAMES.get(status, "the effect")


static func get_status_abbreviation(status: StatusEffect) -> String:
	return STATUS_ABBREVIATIONS.get(status, "???")


static func get_element_name(element: Element) -> String:
	return ELEMENT_NAMES.get(element, "Unknown")


static func get_creature_type_name(creature_type: CreatureType) -> String:
	return CREATURE_TYPE_NAMES.get(creature_type, "Unknown")


static func is_undead(creature_type: CreatureType) -> bool:
	return creature_type == CreatureType.UNDEAD


static func is_disabling_status(status: StatusEffect) -> bool:
	return status in DISABLING_STATUSES


static func is_mental_status(status: StatusEffect) -> bool:
	return status in MENTAL_STATUSES


static func is_death_status(status: StatusEffect) -> bool:
	return status in DEATH_STATUSES


static func has_racial_immunity(race: Race, status: StatusEffect) -> bool:
	var immunities: Array = RACIAL_IMMUNITIES.get(race, [])
	return status in immunities


static func get_exclusive_group(status: StatusEffect) -> Array[StatusEffect]:
	if status in DISABLING_STATUSES:
		return DISABLING_STATUSES
	if status in MENTAL_STATUSES:
		return MENTAL_STATUSES
	if status in DEATH_STATUSES:
		return DEATH_STATUSES
	return []
