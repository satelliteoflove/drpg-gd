# Campaign pass (feature/win-state)

Notes from the autonomous pass that gave the game an ending. Covers what changed, the numbers behind the balance, and what's left for a decision.

## The shape of the game now

The guild's goal is to slay Vrakthorne the Drake on floor 8. A new game starts with the six starter characters already in the party, 100 gold, torches and two Recall Stones, and opens with a short "Guild Charter" screen explaining the goal. Town shows a quest strip with the deepest floor reached and how many guardians are down.

The stairs down from floors 2, 4 and 6 stay sealed until that floor's guardian falls (Broodmother, Ironjaw, Nethris). Slain guardians stay dead. Floor 8 has no stairs down. Killing Vrakthorne autosaves and shows a victory screen (days taken, guardians, highest level, deaths, play time, the party with each member's signature mark, and anyone lost for good). After that the guild can keep delving.

Leaving the dungeon now costs a Recall Stone (40 gold in the shop) or a walk back up the stairs. Debug keys, the map's reveal buttons and AutoExplore are only available in debug builds.

## Commits

| Commit | What |
|---|---|
| Add a win state | Final floor, boss tracking, ending screen, quest strip, save fields |
| Rebalance bosses and the XP curve | Lich buffed; XP table cut to roughly a third (L10 at 24,000) |
| Add town and boss music | Promoted two tracks out of the candidate pool |
| Make the descent count | Sealed stairs, Recall Stones, debug-only cheats |
| Make AI dialogue opt-in | Main menu toggle; llama-server doesn't start unless opted in |
| Smooth the opening and close a few holes | Starter party pre-loaded, intro, death_count actually counted, monster area spells actually hit, Dispel can't remove bosses, sim healing loop can't hang |
| Stop combat from ending twice | Double victory re-rolled loot and paid twice, likely the cause of the duplicate chest items in #12 |
| Fix boss phases, extra actions, and melee damage | See below |
| Docs | README and CLAUDE.md |

### Three bugs that had been hiding behind each other

These had been there since early on, and they changed the balance more than any tuning did.

- `get_boss_for_floor` used a plain `duplicate()`, which drops `boss_phases` and `extra_actions`. In real play no boss ever changed phase.
- When a monster with an extra action acted, `InitiativeTracker` delayed the wrong entry, so the extra entry stayed at zero ticks and the monster took every turn from then on. Nothing had an extra action before this pass, so nobody had seen it.
- Player physical attacks passed a damage bonus of 0. Weapon bonuses shown on the character sheet and in the shop never landed, and melee didn't scale with level. A level 11 fighter hit the Drake for 1. Hits now add `damage_bonus + level / 2`.

## Balance numbers

Boss-only fights with the sim's balanced party (two fighters, priest, thief, mage, bishop), 12 runs each, after all fixes:

| Boss | Wins by party level |
|---|---|
| Broodmother (F2) | L1 7, L2 12, L3 12 |
| Ironjaw (F4) | L4 9, L5 11, L6 12 |
| Nethris the Lich (F6) | L6 3, L7 11, L8 12 |
| Vrakthorne (F8), acts twice | L8 0, L9 4, L10 9, L11 10, L12 12 |

XP per fight by floor (party at the level you'd expect there): F1 25, F2 21, F3 79, F4 56, F5 109, F6 190, F7 248, F8 259. With the new XP table that's somewhere around 190 fights to reach level 10, which should land a full campaign in the 10–15 hour range. That last part is an estimate and hasn't been played through.

Gold looks reasonable: about 25 gold a fight (coin plus loot value) on floor 1 and 100 or so on floor 8, against inn costs of 10 gold per level per night and resurrection at 100 + 25 per level. I didn't change it.

The sim party plays worse than a person does. It doesn't retreat to heal between fights the way a player would, so real win rates should run a bit higher.

## Open questions

**Aging (#20).** A campaign now takes something like 200 in-game days, so aging matters even less than before. Options: treat it as flavor and say so, make each expedition cost weeks or months of game time, or shrink lifespans drastically. My lean is the second, since it also gives the inn and recovery times more meaning, but it touches a lot of systems.

**Random encounters (#15).** `_check_random_encounter` is still dead code. Roaming visible groups seem like the better design for this game, so I'd delete it, but that's your call.

**Boss art (#9).** Ironjaw, the Lich and the Drake have no portraits and show the dark silhouette fallback. That's w-p's area, so I left it alone. The final fight would look much better with a real Drake.

**Early difficulty.** Floors 1 and 2 are gentle (parties end fights at 90%+ HP), floor 3 is where it starts to bite. That seemed fine for a first floor, so I didn't tune it.

**#8** can probably be narrowed: all four boss fights now run with phases in the sim, though nobody has played floors 7 and 8 by hand yet.

**#12** is probably fixed by the double-end guard, but I haven't reproduced the original report to be sure.
