class_name SpellLearning
extends RefCounted

const CLASS_SPELL_SCHOOLS: Dictionary = {
	CharacterEnums.CharacterClass.MAGE: [CharacterEnums.SpellSchool.MAGE],
	CharacterEnums.CharacterClass.PRIEST: [CharacterEnums.SpellSchool.PRIEST],
	CharacterEnums.CharacterClass.ALCHEMIST: [CharacterEnums.SpellSchool.ALCHEMIST],
	CharacterEnums.CharacterClass.PSIONIC: [CharacterEnums.SpellSchool.PSIONIC],
	CharacterEnums.CharacterClass.BISHOP: [CharacterEnums.SpellSchool.MAGE, CharacterEnums.SpellSchool.PRIEST],
	CharacterEnums.CharacterClass.RANGER: [CharacterEnums.SpellSchool.MAGE, CharacterEnums.SpellSchool.ALCHEMIST],
	CharacterEnums.CharacterClass.BARD: [CharacterEnums.SpellSchool.MAGE],
	CharacterEnums.CharacterClass.LORD: [CharacterEnums.SpellSchool.PRIEST],
	CharacterEnums.CharacterClass.VALKYRIE: [CharacterEnums.SpellSchool.PRIEST],
	CharacterEnums.CharacterClass.MONK: [CharacterEnums.SpellSchool.PSIONIC],
	CharacterEnums.CharacterClass.SAMURAI: [CharacterEnums.SpellSchool.MAGE]
}


static func try_learn_spells_on_level_up(character: Character) -> Array[String]:
	var learned: Array[String] = []

	var schools: Array = CLASS_SPELL_SCHOOLS.get(character.character_class, [])
	if schools.is_empty():
		return learned

	var max_spell_level := character.max_spell_level
	if max_spell_level <= 0:
		return learned

	for school in schools:
		var school_spells := SpellDatabase.get_spells_by_school(school)
		for spell in school_spells:
			if spell.level > max_spell_level:
				continue

			if character.known_spells.has(spell.id):
				continue

			if _try_learn_spell(character, spell):
				character.known_spells.append(spell.id)
				learned.append(spell.name)

	return learned


static func _try_learn_spell(character: Character, spell: Spell) -> bool:
	var base_chance := 55 + (character.intelligence - 10) * 5

	if character.character_class == CharacterEnums.CharacterClass.BISHOP:
		base_chance -= 15

	var luck_bonus := (character.luck - 10) / 2
	base_chance += luck_bonus

	var level_penalty := 0
	if spell.level > character.level / 2:
		level_penalty = (spell.level - character.level / 2) * 5

	var final_chance := clampi(base_chance - level_penalty, 35, 95)

	return CombatRNG.randi() % 100 < final_chance


static func get_learnable_spells(character: Character) -> Array[Spell]:
	var result: Array[Spell] = []

	var schools: Array = CLASS_SPELL_SCHOOLS.get(character.character_class, [])
	if schools.is_empty():
		return result

	var max_spell_level := character.max_spell_level
	if max_spell_level <= 0:
		return result

	for school in schools:
		var school_spells := SpellDatabase.get_spells_by_school(school)
		for spell in school_spells:
			if spell.level > max_spell_level:
				continue
			if not character.known_spells.has(spell.id):
				result.append(spell)

	return result


static func can_learn_spells(character: Character) -> bool:
	var schools: Array = CLASS_SPELL_SCHOOLS.get(character.character_class, [])
	return not schools.is_empty()


static func get_learning_chance(character: Character, spell: Spell) -> int:
	var base_chance := 55 + (character.intelligence - 10) * 5

	if character.character_class == CharacterEnums.CharacterClass.BISHOP:
		base_chance -= 15

	var luck_bonus := (character.luck - 10) / 2
	base_chance += luck_bonus

	var level_penalty := 0
	if spell.level > character.level / 2:
		level_penalty = (spell.level - character.level / 2) * 5

	return clampi(base_chance - level_penalty, 35, 95)


static func get_spell_schools_for_class(char_class: CharacterEnums.CharacterClass) -> Array:
	return CLASS_SPELL_SCHOOLS.get(char_class, [])
