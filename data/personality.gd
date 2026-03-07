class_name Personality
extends RefCounted

enum Axis { TEMPERAMENT, SOCIAL, OUTLOOK, VALUES }
enum Temperament { BRAVE, CAUTIOUS, RECKLESS, CALCULATING }
enum Social { FRIENDLY, GRUFF, SARCASTIC, EARNEST }
enum Outlook { OPTIMISTIC, PESSIMISTIC, STOIC, CURIOUS }
enum Values { MERCIFUL, RUTHLESS, PRINCIPLED, SELF_INTERESTED }

const CRYSTALLIZATION_THRESHOLD := 4

const AXIS_NAMES: Dictionary = {
	Axis.TEMPERAMENT: "Temperament",
	Axis.SOCIAL: "Social",
	Axis.OUTLOOK: "Outlook",
	Axis.VALUES: "Values",
}

const OPTION_NAMES: Dictionary = {
	Axis.TEMPERAMENT: {
		Temperament.BRAVE: "Brave",
		Temperament.CAUTIOUS: "Cautious",
		Temperament.RECKLESS: "Reckless",
		Temperament.CALCULATING: "Calculating",
	},
	Axis.SOCIAL: {
		Social.FRIENDLY: "Friendly",
		Social.GRUFF: "Gruff",
		Social.SARCASTIC: "Sarcastic",
		Social.EARNEST: "Earnest",
	},
	Axis.OUTLOOK: {
		Outlook.OPTIMISTIC: "Optimistic",
		Outlook.PESSIMISTIC: "Pessimistic",
		Outlook.STOIC: "Stoic",
		Outlook.CURIOUS: "Curious",
	},
	Axis.VALUES: {
		Values.MERCIFUL: "Merciful",
		Values.RUTHLESS: "Ruthless",
		Values.PRINCIPLED: "Principled",
		Values.SELF_INTERESTED: "Self-Interested",
	},
}

const AXIS_OPTIONS: Dictionary = {
	Axis.TEMPERAMENT: [Temperament.BRAVE, Temperament.CAUTIOUS, Temperament.RECKLESS, Temperament.CALCULATING],
	Axis.SOCIAL: [Social.FRIENDLY, Social.GRUFF, Social.SARCASTIC, Social.EARNEST],
	Axis.OUTLOOK: [Outlook.OPTIMISTIC, Outlook.PESSIMISTIC, Outlook.STOIC, Outlook.CURIOUS],
	Axis.VALUES: [Values.MERCIFUL, Values.RUTHLESS, Values.PRINCIPLED, Values.SELF_INTERESTED],
}

const RACE_TENDENCY_WEIGHTS: Dictionary = {
	CharacterEnums.Race.HUMAN: {
		Axis.TEMPERAMENT: [[Temperament.BRAVE, 25], [Temperament.CAUTIOUS, 25], [Temperament.RECKLESS, 25], [Temperament.CALCULATING, 25]],
		Axis.SOCIAL: [[Social.FRIENDLY, 20], [Social.GRUFF, 20], [Social.SARCASTIC, 25], [Social.EARNEST, 35]],
		Axis.OUTLOOK: [[Outlook.OPTIMISTIC, 35], [Outlook.PESSIMISTIC, 15], [Outlook.STOIC, 25], [Outlook.CURIOUS, 25]],
		Axis.VALUES: [[Values.MERCIFUL, 25], [Values.RUTHLESS, 25], [Values.PRINCIPLED, 25], [Values.SELF_INTERESTED, 25]],
	},
	CharacterEnums.Race.ELF: {
		Axis.TEMPERAMENT: [[Temperament.BRAVE, 15], [Temperament.CAUTIOUS, 25], [Temperament.RECKLESS, 15], [Temperament.CALCULATING, 45]],
		Axis.SOCIAL: [[Social.FRIENDLY, 10], [Social.GRUFF, 15], [Social.SARCASTIC, 40], [Social.EARNEST, 35]],
		Axis.OUTLOOK: [[Outlook.OPTIMISTIC, 10], [Outlook.PESSIMISTIC, 15], [Outlook.STOIC, 35], [Outlook.CURIOUS, 40]],
		Axis.VALUES: [[Values.MERCIFUL, 15], [Values.RUTHLESS, 10], [Values.PRINCIPLED, 40], [Values.SELF_INTERESTED, 35]],
	},
	CharacterEnums.Race.DWARF: {
		Axis.TEMPERAMENT: [[Temperament.BRAVE, 50], [Temperament.CAUTIOUS, 15], [Temperament.RECKLESS, 10], [Temperament.CALCULATING, 25]],
		Axis.SOCIAL: [[Social.FRIENDLY, 15], [Social.GRUFF, 45], [Social.SARCASTIC, 15], [Social.EARNEST, 25]],
		Axis.OUTLOOK: [[Outlook.OPTIMISTIC, 15], [Outlook.PESSIMISTIC, 20], [Outlook.STOIC, 40], [Outlook.CURIOUS, 25]],
		Axis.VALUES: [[Values.MERCIFUL, 20], [Values.RUTHLESS, 20], [Values.PRINCIPLED, 35], [Values.SELF_INTERESTED, 25]],
	},
	CharacterEnums.Race.GNOME: {
		Axis.TEMPERAMENT: [[Temperament.BRAVE, 15], [Temperament.CAUTIOUS, 40], [Temperament.RECKLESS, 20], [Temperament.CALCULATING, 25]],
		Axis.SOCIAL: [[Social.FRIENDLY, 25], [Social.GRUFF, 10], [Social.SARCASTIC, 25], [Social.EARNEST, 40]],
		Axis.OUTLOOK: [[Outlook.OPTIMISTIC, 20], [Outlook.PESSIMISTIC, 15], [Outlook.STOIC, 25], [Outlook.CURIOUS, 40]],
		Axis.VALUES: [[Values.MERCIFUL, 25], [Values.RUTHLESS, 15], [Values.PRINCIPLED, 35], [Values.SELF_INTERESTED, 25]],
	},
	CharacterEnums.Race.HOBBIT: {
		Axis.TEMPERAMENT: [[Temperament.BRAVE, 15], [Temperament.CAUTIOUS, 40], [Temperament.RECKLESS, 20], [Temperament.CALCULATING, 25]],
		Axis.SOCIAL: [[Social.FRIENDLY, 45], [Social.GRUFF, 10], [Social.SARCASTIC, 20], [Social.EARNEST, 25]],
		Axis.OUTLOOK: [[Outlook.OPTIMISTIC, 40], [Outlook.PESSIMISTIC, 10], [Outlook.STOIC, 25], [Outlook.CURIOUS, 25]],
		Axis.VALUES: [[Values.MERCIFUL, 20], [Values.RUTHLESS, 10], [Values.PRINCIPLED, 35], [Values.SELF_INTERESTED, 35]],
	},
	CharacterEnums.Race.FAERIE: {
		Axis.TEMPERAMENT: [[Temperament.BRAVE, 15], [Temperament.CAUTIOUS, 15], [Temperament.RECKLESS, 45], [Temperament.CALCULATING, 25]],
		Axis.SOCIAL: [[Social.FRIENDLY, 15], [Social.GRUFF, 10], [Social.SARCASTIC, 40], [Social.EARNEST, 35]],
		Axis.OUTLOOK: [[Outlook.OPTIMISTIC, 15], [Outlook.PESSIMISTIC, 10], [Outlook.STOIC, 30], [Outlook.CURIOUS, 45]],
		Axis.VALUES: [[Values.MERCIFUL, 20], [Values.RUTHLESS, 10], [Values.PRINCIPLED, 35], [Values.SELF_INTERESTED, 35]],
	},
	CharacterEnums.Race.LIZMAN: {
		Axis.TEMPERAMENT: [[Temperament.BRAVE, 45], [Temperament.CAUTIOUS, 10], [Temperament.RECKLESS, 20], [Temperament.CALCULATING, 25]],
		Axis.SOCIAL: [[Social.FRIENDLY, 10], [Social.GRUFF, 45], [Social.SARCASTIC, 20], [Social.EARNEST, 25]],
		Axis.OUTLOOK: [[Outlook.OPTIMISTIC, 10], [Outlook.PESSIMISTIC, 20], [Outlook.STOIC, 45], [Outlook.CURIOUS, 25]],
		Axis.VALUES: [[Values.MERCIFUL, 10], [Values.RUTHLESS, 40], [Values.PRINCIPLED, 25], [Values.SELF_INTERESTED, 25]],
	},
	CharacterEnums.Race.DRACON: {
		Axis.TEMPERAMENT: [[Temperament.BRAVE, 45], [Temperament.CAUTIOUS, 10], [Temperament.RECKLESS, 20], [Temperament.CALCULATING, 25]],
		Axis.SOCIAL: [[Social.FRIENDLY, 15], [Social.GRUFF, 40], [Social.SARCASTIC, 20], [Social.EARNEST, 25]],
		Axis.OUTLOOK: [[Outlook.OPTIMISTIC, 15], [Outlook.PESSIMISTIC, 20], [Outlook.STOIC, 40], [Outlook.CURIOUS, 25]],
		Axis.VALUES: [[Values.MERCIFUL, 15], [Values.RUTHLESS, 20], [Values.PRINCIPLED, 40], [Values.SELF_INTERESTED, 25]],
	},
	CharacterEnums.Race.RAWULF: {
		Axis.TEMPERAMENT: [[Temperament.BRAVE, 40], [Temperament.CAUTIOUS, 20], [Temperament.RECKLESS, 15], [Temperament.CALCULATING, 25]],
		Axis.SOCIAL: [[Social.FRIENDLY, 20], [Social.GRUFF, 10], [Social.SARCASTIC, 25], [Social.EARNEST, 45]],
		Axis.OUTLOOK: [[Outlook.OPTIMISTIC, 45], [Outlook.PESSIMISTIC, 10], [Outlook.STOIC, 20], [Outlook.CURIOUS, 25]],
		Axis.VALUES: [[Values.MERCIFUL, 40], [Values.RUTHLESS, 10], [Values.PRINCIPLED, 25], [Values.SELF_INTERESTED, 25]],
	},
	CharacterEnums.Race.MOOK: {
		Axis.TEMPERAMENT: [[Temperament.BRAVE, 15], [Temperament.CAUTIOUS, 20], [Temperament.RECKLESS, 25], [Temperament.CALCULATING, 40]],
		Axis.SOCIAL: [[Social.FRIENDLY, 15], [Social.GRUFF, 40], [Social.SARCASTIC, 20], [Social.EARNEST, 25]],
		Axis.OUTLOOK: [[Outlook.OPTIMISTIC, 15], [Outlook.PESSIMISTIC, 40], [Outlook.STOIC, 20], [Outlook.CURIOUS, 25]],
		Axis.VALUES: [[Values.MERCIFUL, 15], [Values.RUTHLESS, 25], [Values.PRINCIPLED, 35], [Values.SELF_INTERESTED, 25]],
	},
	CharacterEnums.Race.FELPURR: {
		Axis.TEMPERAMENT: [[Temperament.BRAVE, 15], [Temperament.CAUTIOUS, 20], [Temperament.RECKLESS, 40], [Temperament.CALCULATING, 25]],
		Axis.SOCIAL: [[Social.FRIENDLY, 15], [Social.GRUFF, 20], [Social.SARCASTIC, 40], [Social.EARNEST, 25]],
		Axis.OUTLOOK: [[Outlook.OPTIMISTIC, 15], [Outlook.PESSIMISTIC, 20], [Outlook.STOIC, 25], [Outlook.CURIOUS, 40]],
		Axis.VALUES: [[Values.MERCIFUL, 20], [Values.RUTHLESS, 20], [Values.PRINCIPLED, 25], [Values.SELF_INTERESTED, 35]],
	},
}


static func get_axis_name(axis: Axis) -> String:
	return AXIS_NAMES.get(axis, "Unknown")


static func get_option_name(axis: Axis, option: int) -> String:
	var axis_options: Dictionary = OPTION_NAMES.get(axis, {})
	return axis_options.get(option, "Unknown")


static func get_options_for_axis(axis: Axis) -> Array:
	return AXIS_OPTIONS.get(axis, [])
