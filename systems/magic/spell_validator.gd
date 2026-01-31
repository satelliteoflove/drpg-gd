## Validates spell casting requirements and calculates fizzle chances.
class_name SpellValidator
extends RefCounted


## Checks if a character can cast a specific spell.
## [param caster]: The character attempting to cast.
## [param spell]: The spell to cast.
## [param in_combat]: Whether in combat or exploration context.
## [return]: Dictionary with "can_cast" (bool) and "reason" (String) if failed.
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


## Calculates the percentage chance that a spell will fizzle.
## [param caster]: The character casting the spell.
## [param spell]: The spell being cast.
## [return]: Fizzle chance 0-95%.
static func calculate_fizzle_chance(caster: Character, spell: Spell) -> float:
	var base := maxf(0, (spell.level - caster.level / 2.0) * 10)
	base += maxf(0, 18 - caster.intelligence) * 2

	var class_modifier := _get_class_fizzle_modifier(caster.character_class)
	base += class_modifier

	base += spell.fizzle_modifier

	base += (18 - caster.luck) * 0.5

	return clampf(base, 0, 95)


static func _get_class_fizzle_modifier(char_class: CharacterEnums.CharacterClass) -> float:
	match char_class:
		CharacterEnums.CharacterClass.MAGE, \
		CharacterEnums.CharacterClass.PRIEST, \
		CharacterEnums.CharacterClass.ALCHEMIST, \
		CharacterEnums.CharacterClass.PSIONIC:
			return 0
		CharacterEnums.CharacterClass.BISHOP:
			return 5
		CharacterEnums.CharacterClass.BARD, \
		CharacterEnums.CharacterClass.RANGER, \
		CharacterEnums.CharacterClass.LORD, \
		CharacterEnums.CharacterClass.VALKYRIE, \
		CharacterEnums.CharacterClass.MONK, \
		CharacterEnums.CharacterClass.SAMURAI:
			return 10
		_:
			return 20


## Rolls to check if a spell fizzles.
## [param caster]: The character casting the spell.
## [param spell]: The spell being cast.
## [return]: True if the spell fizzles.
static func check_fizzle(caster: Character, spell: Spell) -> bool:
	var chance := calculate_fizzle_chance(caster, spell)
	return CombatRNG.randf() * 100 < chance


## Returns all spells the character can currently cast.
## [param caster]: The character to check.
## [param in_combat]: Whether to filter for combat or exploration spells.
## [return]: Array of castable Spell objects.
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


## Returns known spells organized by spell level.
## [param caster]: The character to check.
## [param in_combat]: Whether to filter for combat or exploration spells.
## [return]: Dictionary mapping level (1-7) to Array of Spell objects.
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
