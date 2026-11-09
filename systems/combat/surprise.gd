class_name Surprise
extends RefCounted

## Who, if anyone, is caught off guard when a fight starts. The surprising
## side gets one free action each before normal turn order begins.
##
## Wizardry gives each side a flat 20%. Here the roaming groups are visible,
## so how the fight starts matters: walking into a group that hasn't noticed
## you is an ambush, and so is a group that runs you down from behind.

enum Result { NONE, PARTY, MONSTERS }

## Wizardry's flat chance for either side.
const BASE_CHANCE := 0.20
## Catching the other side unaware or from behind.
const AMBUSH_CHANCE := 0.50
## The side that didn't start the fight rarely gets the jump.
const SLIGHT_CHANCE := 0.10


## [param party_engaged]: the party walked into the group (rather than the
## group catching the party). [param group_aware]: the group had already
## noticed the party. [param from_behind]: the group came at the party from
## behind or the side.
static func roll(party_engaged: bool, group_aware: bool, from_behind: bool,
		is_boss: bool, party: Party) -> Result:
	if is_boss:
		return Result.NONE
	var party_chance: float
	var monster_chance: float
	if party_engaged:
		party_chance = BASE_CHANCE if group_aware else AMBUSH_CHANCE
		monster_chance = SLIGHT_CHANCE
	else:
		party_chance = SLIGHT_CHANCE
		monster_chance = AMBUSH_CHANCE if from_behind else BASE_CHANCE
	if AgeTraits.party_has(party, AgeTraits.prevents_surprise):
		monster_chance = 0.0
	var r := CombatRNG.randf()
	if r < party_chance:
		return Result.PARTY
	if r < party_chance + monster_chance:
		return Result.MONSTERS
	return Result.NONE
