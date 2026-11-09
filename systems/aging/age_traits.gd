class_name AgeTraits
extends RefCounted

## What getting older gives a character, as opposed to what it takes away
## (the stat decline in Character.apply_aging_effects). See docs/deep-time.md.
##
## Youth learn fast. Veterans gain a trait from their class's archetype, and
## Elders gain a stronger one on top of it, plus Counsel: everyone else in
## the party learns faster, strikes truer and casts more surely while an elder
## travels with them.

enum Archetype { MARTIAL, SKULKER, ARCANE, DIVINE, BISHOP }

const YOUTH_XP_MULTIPLIER := 1.25
const COUNSEL_XP_MULTIPLIER := 1.10
const COUNSEL_ACCURACY := 1
const COUNSEL_FIZZLE_REDUCTION := 10.0
const VETERAN_MELEE_BONUS := 2
const ARCANE_MP_MULTIPLIER := 1.2
const ARCANE_SPELL_DAMAGE_MULTIPLIER := 1.25
const DIVINE_HEALING_MULTIPLIER := 1.25

static func archetype(c: Character) -> Archetype:
	match c.character_class:
		CharacterEnums.CharacterClass.THIEF, \
		CharacterEnums.CharacterClass.NINJA, \
		CharacterEnums.CharacterClass.BARD:
			return Archetype.SKULKER
		CharacterEnums.CharacterClass.MAGE, \
		CharacterEnums.CharacterClass.ALCHEMIST, \
		CharacterEnums.CharacterClass.PSIONIC:
			return Archetype.ARCANE
		CharacterEnums.CharacterClass.PRIEST:
			return Archetype.DIVINE
		CharacterEnums.CharacterClass.BISHOP:
			return Archetype.BISHOP
	return Archetype.MARTIAL


static func is_youth(c: Character) -> bool:
	return c.get_life_phase() == CharacterEnums.LifePhase.YOUTH


static func is_veteran(c: Character) -> bool:
	return c.get_life_phase() >= CharacterEnums.LifePhase.DECLINE


static func is_elder(c: Character) -> bool:
	return c.get_life_phase() == CharacterEnums.LifePhase.FRAGILE


static func _has(c: Character, arch: Archetype, needs_elder: bool) -> bool:
	if archetype(c) != arch:
		return false
	return is_elder(c) if needs_elder else is_veteran(c)


# --- Trait queries -------------------------------------------------------------

## Veteran fighters know where to strike.
static func melee_damage_bonus(c: Character) -> int:
	return VETERAN_MELEE_BONUS if _has(c, Archetype.MARTIAL, false) else 0


## Elder fighters move before anyone else in the first round.
static func acts_first(c: Character) -> bool:
	return _has(c, Archetype.MARTIAL, true)


## A veteran thief's failed disarm doesn't set the trap off.
static func safe_disarm(c: Character) -> bool:
	return _has(c, Archetype.SKULKER, false)


## No one catches a party with an elder thief in it off guard.
static func prevents_surprise(c: Character) -> bool:
	return _has(c, Archetype.SKULKER, true)


static func max_mp_multiplier(c: Character) -> float:
	if _has(c, Archetype.ARCANE, false) or _has(c, Archetype.BISHOP, true):
		return ARCANE_MP_MULTIPLIER
	return 1.0


static func spell_damage_multiplier(c: Character) -> float:
	return ARCANE_SPELL_DAMAGE_MULTIPLIER if _has(c, Archetype.ARCANE, true) else 1.0


static func healing_multiplier(c: Character) -> float:
	if _has(c, Archetype.DIVINE, false) or _has(c, Archetype.BISHOP, true):
		return DIVINE_HEALING_MULTIPLIER
	return 1.0


## A veteran bishop names whatever the party finds.
static func identifies_loot(c: Character) -> bool:
	return _has(c, Archetype.BISHOP, false)


static func can_intercede(c: Character) -> bool:
	return _has(c, Archetype.DIVINE, true)


# --- Party-wide effects --------------------------------------------------------

## Whether another living elder is travelling with [param c].
static func is_counseled(c: Character, party: Party) -> bool:
	if party == null or not party.has_member(c):
		return false
	for m in party.get_members():
		if m != c and not m.is_dead and is_elder(m):
			return true
	return false


static func xp_multiplier(c: Character, party: Party) -> float:
	var mult := 1.0
	if is_youth(c):
		mult *= YOUTH_XP_MULTIPLIER
	if is_counseled(c, party):
		mult *= COUNSEL_XP_MULTIPLIER
	return mult


## Accuracy bonus from an elder's counsel. Only the guild's own party gets
## it; simulator parties aren't GameState.party.
static func counsel_accuracy(c: Character) -> int:
	return COUNSEL_ACCURACY if is_counseled(c, GameState.party) else 0


## True if any living member has the given ability.
static func party_has(party: Party, check: Callable) -> bool:
	if party == null:
		return false
	for m in party.get_members():
		if not m.is_dead and check.call(m):
			return true
	return false


## Fizzle chance (percentage points) taken off by an elder's counsel.
static func counsel_fizzle_reduction(c: Character) -> float:
	return COUNSEL_FIZZLE_REDUCTION if is_counseled(c, GameState.party) else 0.0


## Once per expedition, an elder priest's prayer holds a dying ally at 1 HP.
## Returns true if [param dying] was saved.
static func try_intercede(dying: Character) -> bool:
	var party := GameState.party
	if party == null or not party.has_member(dying):
		return false
	for m in party.get_members():
		if m == dying or m.is_dead or m.intercession_used or not can_intercede(m):
			continue
		m.intercession_used = true
		CombatNotes.add("%s cries out a prayer, and %s does not fall." % [
			m.get_display_name(), dying.get_display_name()])
		return true
	return false


# --- Descriptions ----------------------------------------------------------------

## Short lines for the traits [param c] has right now.
static func describe(c: Character) -> Array[String]:
	var lines: Array[String] = []
	if c.last_descent:
		lines.append("Last descent: prime body, +%d all stats, won't come home" % LastDescent.STAT_BONUS)
	if is_youth(c):
		lines.append("Quick study: +25% experience")
	if is_veteran(c):
		lines.append(_veteran_line(archetype(c)))
	if is_elder(c):
		lines.append(_elder_line(archetype(c)))
		lines.append(COUNSEL_LINE)
	return lines


const COUNSEL_LINE := "Counsel: party +10% XP, +1 accuracy, -10% fizzle"


## What a character gains on entering [param phase], for the homecoming report.
static func gained_on(c: Character, phase: CharacterEnums.LifePhase) -> String:
	match phase:
		CharacterEnums.LifePhase.DECLINE:
			return _veteran_line(archetype(c))
		CharacterEnums.LifePhase.FRAGILE:
			return "%s. %s" % [_elder_line(archetype(c)), COUNSEL_LINE]
	return ""


static func _veteran_line(arch: Archetype) -> String:
	match arch:
		Archetype.SKULKER:
			return "Steady hands: failed disarms don't spring traps"
		Archetype.ARCANE:
			return "Deep reserves: +20% max MP"
		Archetype.DIVINE:
			return "Practiced healer: +25% healing"
		Archetype.BISHOP:
			return "Learned eye: identifies all loot"
	return "Knows where to strike: +2 damage"


static func _elder_line(arch: Archetype) -> String:
	match arch:
		Archetype.SKULKER:
			return "Seen it all: the party can't be surprised"
		Archetype.ARCANE:
			return "Decades of study: +25% spell damage"
		Archetype.DIVINE:
			return "Intercession: saves a dying ally once a trip"
		Archetype.BISHOP:
			return "Long devotion: +20% max MP, +25% healing"
	return "Old instincts: acts first in round one"
