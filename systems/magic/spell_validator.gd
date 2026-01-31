class_name SpellValidator
extends RefCounted

const CombatRNG = preload("res://autoload/combat_rng.gd")
const CharEnum = preload("res://resources/character_enums.gd")


static func can_cast(caster: Character, spell: Spell, in_combat: bool = true) -> Dictionary:
	var result := {
		"can_cast": true,
		"reason": ""
	}

	if caster.is_dead:
		result.can_cast = false
		result.reason = "Cannot cast while dead"
		return result

	if caster.is_silenced():
		result.can_cast = false
		result.reason = "Cannot cast while silenced"
		return result

	if caster.is_disabled():
		result.can_cast = false
		result.reason = "Cannot act while incapacitated"
		return result

	if not _knows_spell(caster, spell.id):
		result.can_cast = false
		result.reason = "Spell not known"
		return result

	if caster.current_mp < spell.mp_cost:
		result.can_cast = false
		result.reason = "Not enough MP (%d required)" % spell.mp_cost
		return result

	if in_combat and not spell.in_combat:
		result.can_cast = false
		result.reason = "Cannot cast in combat"
		return result

	if not in_combat and not spell.out_of_combat:
		result.can_cast = false
		result.reason = "Can only cast in combat"
		return result

	return result


static func _knows_spell(caster: Character, spell_id: String) -> bool:
	return caster.known_spells.has(spell_id)


static func calculate_fizzle_chance(caster: Character, spell: Spell) -> float:
	var base := maxf(0, (spell.level - caster.level / 2.0) * 10)
	base += maxf(0, 18 - caster.intelligence) * 2

	var class_modifier := _get_class_fizzle_modifier(caster.character_class)
	base += class_modifier

	base += spell.fizzle_modifier

	base += (18 - caster.luck) * 0.5

	return clampf(base, 0, 95)


static func _get_class_fizzle_modifier(char_class: CharEnum.CharacterClass) -> float:
	match char_class:
		CharEnum.CharacterClass.MAGE, \
		CharEnum.CharacterClass.PRIEST, \
		CharEnum.CharacterClass.ALCHEMIST, \
		CharEnum.CharacterClass.PSIONIC:
			return 0
		CharEnum.CharacterClass.BISHOP:
			return 5
		CharEnum.CharacterClass.BARD, \
		CharEnum.CharacterClass.RANGER, \
		CharEnum.CharacterClass.LORD, \
		CharEnum.CharacterClass.VALKYRIE, \
		CharEnum.CharacterClass.MONK, \
		CharEnum.CharacterClass.SAMURAI:
			return 10
		_:
			return 20


static func check_fizzle(caster: Character, spell: Spell) -> bool:
	var chance := calculate_fizzle_chance(caster, spell)
	return CombatRNG.randf() * 100 < chance


static func get_castable_spells(caster: Character, in_combat: bool = true) -> Array[Spell]:
	var SpellDatabase = load("res://data/spells/spell_database.gd")
	var result: Array[Spell] = []

	for spell_id in caster.known_spells:
		var spell: Spell = SpellDatabase.get_spell(spell_id)
		if spell == null:
			continue

		var validation: Dictionary = can_cast(caster, spell, in_combat)
		if validation.can_cast:
			result.append(spell)

	return result


static func get_spells_by_level(caster: Character, in_combat: bool = true) -> Dictionary:
	var SpellDatabase = load("res://data/spells/spell_database.gd")
	var result := {}

	for i in range(1, 8):
		result[i] = []

	for spell_id in caster.known_spells:
		var spell: Spell = SpellDatabase.get_spell(spell_id)
		if spell == null:
			continue

		if in_combat and not spell.in_combat:
			continue
		if not in_combat and not spell.out_of_combat:
			continue

		if result.has(spell.level):
			result[spell.level].append(spell)

	return result
