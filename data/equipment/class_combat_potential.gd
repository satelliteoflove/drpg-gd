class_name ClassCombatPotential
extends RefCounted

const MAX_POTENTIAL: Dictionary = {
	CharacterEnums.CharacterClass.FIGHTER: {
		"tank": 35.0,
		"eva": 12.0,
		"acc": 18.0,
		"dmg": 20.0,
		"spd": 20.0,
		"mag": 8.0,
	},
	CharacterEnums.CharacterClass.MAGE: {
		"tank": 10.0,
		"eva": 15.0,
		"acc": 12.0,
		"dmg": 8.0,
		"spd": 18.0,
		"mag": 35.0,
	},
	CharacterEnums.CharacterClass.PRIEST: {
		"tank": 20.0,
		"eva": 10.0,
		"acc": 14.0,
		"dmg": 12.0,
		"spd": 15.0,
		"mag": 30.0,
	},
	CharacterEnums.CharacterClass.THIEF: {
		"tank": 12.0,
		"eva": 25.0,
		"acc": 22.0,
		"dmg": 14.0,
		"spd": 25.0,
		"mag": 6.0,
	},
	CharacterEnums.CharacterClass.RANGER: {
		"tank": 18.0,
		"eva": 18.0,
		"acc": 22.0,
		"dmg": 18.0,
		"spd": 20.0,
		"mag": 10.0,
	},
	CharacterEnums.CharacterClass.NINJA: {
		"tank": 10.0,
		"eva": 28.0,
		"acc": 24.0,
		"dmg": 16.0,
		"spd": 28.0,
		"mag": 8.0,
	},
	CharacterEnums.CharacterClass.VALKYRIE: {
		"tank": 30.0,
		"eva": 14.0,
		"acc": 18.0,
		"dmg": 18.0,
		"spd": 18.0,
		"mag": 15.0,
	},
	CharacterEnums.CharacterClass.SAMURAI: {
		"tank": 25.0,
		"eva": 16.0,
		"acc": 20.0,
		"dmg": 22.0,
		"spd": 22.0,
		"mag": 10.0,
	},
	CharacterEnums.CharacterClass.LORD: {
		"tank": 32.0,
		"eva": 12.0,
		"acc": 18.0,
		"dmg": 18.0,
		"spd": 16.0,
		"mag": 18.0,
	},
	CharacterEnums.CharacterClass.MONK: {
		"tank": 15.0,
		"eva": 22.0,
		"acc": 20.0,
		"dmg": 14.0,
		"spd": 24.0,
		"mag": 12.0,
	},
	CharacterEnums.CharacterClass.BARD: {
		"tank": 12.0,
		"eva": 18.0,
		"acc": 16.0,
		"dmg": 10.0,
		"spd": 20.0,
		"mag": 20.0,
	},
	CharacterEnums.CharacterClass.BISHOP: {
		"tank": 12.0,
		"eva": 12.0,
		"acc": 14.0,
		"dmg": 10.0,
		"spd": 14.0,
		"mag": 35.0,
	},
	CharacterEnums.CharacterClass.PSIONIC: {
		"tank": 8.0,
		"eva": 14.0,
		"acc": 12.0,
		"dmg": 6.0,
		"spd": 16.0,
		"mag": 32.0,
	},
	CharacterEnums.CharacterClass.ALCHEMIST: {
		"tank": 10.0,
		"eva": 14.0,
		"acc": 14.0,
		"dmg": 8.0,
		"spd": 16.0,
		"mag": 28.0,
	},
}


static func get_max(char_class: CharacterEnums.CharacterClass, stat: String) -> float:
	var class_data: Dictionary = MAX_POTENTIAL.get(char_class, {})
	return class_data.get(stat, 20.0)
