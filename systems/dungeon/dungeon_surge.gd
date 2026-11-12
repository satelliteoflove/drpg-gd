class_name DungeonSurge
extends RefCounted

## When a dungeon collapses, its evil energies pour into the ones that remain
## and their monsters grow stronger. The energy pools in the deep: the top two
## floors never change, so new recruits always have somewhere to train, and
## the bottom floors get all of it. Later sets add a tier on the same curve.
##
## The numbers come from tests/measure_bosses.tscn. A master at a surge of 1.0
## wants a party of level 10, and each 1.0 more wants about two and a half
## levels more. A party that clears a dungeon gains a level or two from it, so
## 0.30 a collapse keeps the next master about level with the party that
## brought the last one down. A set is five dungeons, so a new set adds 2.0:
## less, and veterans of the last set walk through the next. See
## docs/dungeon-sets.md.

const PER_COLLAPSE := 0.30
const PER_SET := 2.0
## Share of the surge each floor takes. Index 0 is unused.
const DEPTH_SHARE: Array[float] = [0.0, 0.0, 0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.0]


static func depth_share(floor_num: int) -> float:
	return DEPTH_SHARE[clampi(floor_num, 0, DEPTH_SHARE.size() - 1)]


## How much stronger monsters on [param floor_num] are than their stock
## selves: 1.0 is unchanged.
static func multiplier(dungeon_set: DungeonSet, floor_num: int) -> float:
	if dungeon_set == null:
		return 1.0
	var surge := PER_COLLAPSE * dungeon_set.collapsed_count() + PER_SET * (dungeon_set.set_number - 1)
	return 1.0 + surge * depth_share(floor_num)


## Strengthens a combat copy of a monster. Call once per copy.
static func strengthen(monster: Monster, mult: float) -> void:
	if mult <= 1.0:
		return
	var extra := mult - 1.0
	monster.max_hp = int(monster.max_hp * mult)
	monster.current_hp = monster.max_hp
	monster.exp_reward = int(monster.exp_reward * mult)
	monster.level += roundi(extra * 4.0)
	monster.strength += roundi(extra * 6.0)
	monster.defense += roundi(extra * 3.0)
