# Dungeon sets: the shape of the story

A proposal for how the game's story is structured: several procedurally generated dungeons, a final one, an ending, and free play after. It builds on [deep-time.md](deep-time.md), which made aging the cost of going deep, and on the racial strategies in [racial-balance.md](racial-balance.md).

## The shape

The story is a **set of four dungeons** and a **fifth**. Each dungeon is generated fresh and goes down to a master. Defeating the master collapses that dungeon for good. When all four have collapsed, a fifth dungeon appears. Defeating its master ends the story and shows the ending. After that the game goes on in free play: a new set of four appears, and the cycle starts again.

There are no campaigns with gaps between them. Time is continuous, and the unit of play is the dungeon run. The roster works the way it does in Wizardry: party members are interchangeable. Whoever is in the party goes down. Everyone else stays in town, working a job, training, earning a little, and aging slowly on the surface calendar.

## Characters and dungeons

An average character lasts through two to four dungeons before age takes them, and that number varies a lot by race:

- **Short-lived races** (Rawulf, Mook, Lizman, Felpurr) level fastest in their best classes and peak early. They might see two dungeons.
- **Humans** see two or three.
- **Long-lived races** (Hobbit, Faerie, Dracon, Dwarf, Gnome, Elf) start slower but can outlive everyone and keep getting stronger the whole time. An elf could see the whole story and go well into free play, but only if the dungeon doesn't kill them first.

The story takes five dungeons, so most of the guild turns over before it ends. That's the race trade-off at character creation. Sprinters get you through the early dungeons fast, while long-lived characters, kept alive, carry the guild through the end and outperform anyone who came and went.

Already done in support of this:

- **Levels are uncapped.** Past 20, each level costs a flat 68,000 XP before race and class modifiers, as in Wizardry.
- **The Youth XP bonus is gone.** It lasted 7% of a race's lifespan, which favored long-lived races. Short-lived races keep their speed through the race and class XP modifiers.
- **Raising by spell is a gamble.** A failed Resurrect leaves ashes, and a failed raise from ashes loses the character for good. The temple always raises a body.

## The four and the fifth

All four dungeons in a set are open at once, and the player clears them in whatever order they like. The four start alike in depth and difficulty, eight floors each, and differ in theme and master. The choice of order is the player's.

**Each collapse makes the rest harder.** When a dungeon collapses, its evil energies pour into the ones that remain, and their monsters grow stronger. The town screen and the dungeon entrance say how many have collapsed, so the player always knows what they're walking into.

**The energy pools in the deep.** The strengthening grows with depth. Floors 1 and 2 of every dungeon never change, the middle floors get part of it, and the bottom floors get all of it. That keeps veterans working where it matters while a party of new recruits always has somewhere safe to train, however many dungeons have fallen. Stronger monsters also give more XP, so a new party catches up faster on the middle floors than the first party did. Apprentices are the other way up.

As built (`systems/dungeon/dungeon_surge.gd`), each collapse adds 30% and each set after the first adds 100%, scaled by depth: nothing on floors 1 and 2, then 20%, 40%, 60% and 80% on floors 3 to 6, and all of it on 7 and 8. The multiplier applies to a monster's HP and XP, with smaller bumps to level, strength and defense. These are first guesses to tune in play.

The fifth dungeon is **one great floor**: a single large level with the story's final master at its heart. It appears once all four have collapsed. For now it's a single 41×41 floor that plays by floor 8's rules, with floor 5's deep-time rate. This is tentative. Dungeon generation is due a rethink after this feature, and the fifth dungeon's shape, or whether it needs one of its own, will be decided then.

## More than one party

Only one party is active at a time, but the guild can have several parties **out** at once, each in its own dungeon or even in the same one. The player can switch between them at will. Most players will run one party at a time, but nothing stops someone keeping a party in each dungeon and rotating between them.

A party that isn't active is **frozen**, as in Wizardry. It doesn't move, fight or age until the player switches back to it. Only the active party's steps move the surface calendar and its own deep-time clock.

As built: a party below can **Camp** (C), which leaves it where it stands and returns the player to town. The town's Parties entry lists the guild's other parties and where they are, and picking one puts the player back with it, at the spot it camped. Continuing a save made below also resumes below. The guild hall won't offer anyone who's already in a party, and the roster marks who is camped or fallen below.

Switching away from a party only pauses it. Its expedition hasn't ended, so nothing that happens at an expedition's end (the homecoming, a Legend passing on) is triggered by the switch.

## Entering a dungeon

A party always enters a dungeon at the top, as in any dungeon RPG, however deep it or anyone else has been before. A way to make the return trip easier, such as an elevator unlocked at a certain depth, is an idea for later and isn't built.

## Guild storage

Passing items between characters was always a chore in Wizardry. Here the guild hall has a Storage tab: the party in town can leave items in the guild's storage or take them out, so two characters never need to share a party to hand gear along. Storage holds 200 stacks. *Built.*

## Wipes and rescue

A party wipe is always a major setback. The party stays where it fell, bodies and gear with it, and another party has to go down and bring them back.

As built: the town reports the wipe and where they lie. When another party reaches that floor it's told they're there, and the map marks the spot. Walking onto it gathers up as many bodies as the party has room for, with their gold and whatever of their gear fits. Anyone left waits for another trip. On a master's floor the game warns that the collapse will take whoever still lies below.

So a wipe can never lock the game, a rescue party must always be able to form and train. New recruits are always available at the guild hall, and the upper floors of every dungeon stay at their original difficulty (see above). A wiped party's gold and gear are below with it, which is one argument for a guild bank.

## Gold

The guild's gold is communal in town: one pool for shops, the inn and the temple. Gold found below is carried by the party that found it and only joins the pool when they walk back into town. So a lost party lies there with its takings and its loot, worth going back for, without per-character purses on every shop screen. *Built.* The homecoming report says how much came up.

## Collapse

When a dungeon's master falls, the dungeon collapses. Every living party inside is cast out to town safely, along with any bodies they carry. Bodies still lying in the dungeon are **lost for good**. The collapse is always the player's choice, since it only happens when the master is defeated, so the game warns before the master's fight if anyone is still lying below.

Each collapse gets a short card: which dungeon fell, who was there, and what it means for the dungeons that remain. The full saga waits for the story's ending.

## Masters and art

Each dungeon needs its own master. Until more art arrives, every master is the drake under a new name and a tint, and the fifth dungeon's has half again its HP. The guardians on floors 2, 4 and 6 are the same in every dungeon for now. The same placeholder approach goes for monster tiers in later sets.

## Aging by depth

Deep time stays as built: every step below ages the party according to the floor it's on, and deeper floors cost far more. Measured (see [deep-time.md](deep-time.md#measured)), a dungeon run costs a fresh party about 16 years and an experienced one about 10, before the inefficiencies of real play, which might push it to 15 to 30. That lands close to the two-to-four-dungeon target.

## Later sets and the great floor's clock

In free play, each new set of four is a tier harder than the last, with stronger monsters and masters, so surviving veterans still have something to push against.

Deep time on the great floor runs gentler than on the deep floors, so the final dungeon isn't also a race against age. Floor 5's rate (about three months per surface day) is a starting point to tune from.

## Data model

Today the game assumes one dungeon and one party. `GameState` holds a single `party`, `current_floor`, `dungeon_floors`, `bosses_slain`, `deepest_floor` and `floor_tracker`, and about 300 call sites across 40 files read them. The model below splits that state three ways (world, dungeon, party) and keeps those `GameState` names working as views onto the active party and its dungeon, so most of the code doesn't change.

### World

Lives on `GameState` and is saved once.

| Field | Meaning |
|---|---|
| `game_day` | The surface calendar. One for the whole guild |
| `roster` | Every character, as now |
| `parties: Array[Party]` | Every party that exists, in town or out |
| `active_party_id` | The party the player is driving |
| `dungeon_set: DungeonSet` | The current set of dungeons |
| `story_won_day` | Day the fifth dungeon fell, or 0. Replaces `victory_day` |

### DungeonSet and Dungeon (new resources)

`DungeonSet` holds `set_number` (1 for the story, 2 and up in free play, which gives the tier), `dungeons: Array[Dungeon]` (the four), and `final_dungeon: Dungeon` (created when the fourth collapses).

| `Dungeon` field | Meaning |
|---|---|
| `id` | Stable string id |
| `dungeon_name`, `theme_id`, `master_id` | What makes it this dungeon and not another |
| `seed` | Floors generate from this plus the floor number |
| `depth` | Number of floors. Replaces the `FINAL_FLOOR` constant |
| `floors: Dictionary` | Floor number to `DungeonData`: layout, doors, zones, enemy groups. Replaces `GameState.dungeon_floors` |
| `bosses_slain: Array[int]` | Replaces `GameState.bosses_slain` |
| `deepest_floor` | Deepest floor anyone has reached here, for the seals and the map |
| `collapsed_day` | 0 while it stands |

How much the remaining dungeons have strengthened isn't stored. It's worked out when an encounter is built, from the number of collapsed dungeons in the set, the set number, and the floor.

Enemy groups and zone timers already live inside each floor's `DungeonData`, so a dungeon nobody is walking is frozen for free: nothing ticks unless the active party steps there. Two parties in the same dungeon share its floors, so what one kills stays dead for the other.

### Party (extended)

A party is a persistent thing with an identity, wherever it is.

| New field | Meaning |
|---|---|
| `id`, `party_name` | So the player can tell parties apart |
| `dungeon_id` | The dungeon it's in, or "" for town |
| `floor`, `position`, `facing`, `spawn_at_stairs_up` | Where it stands. Replaces `GameState.current_floor`, `dungeon_player_position` and friends |
| `tracker: FloorTracker` | Its own expedition clock: steps not yet turned into days, deep time accrued, reveal and spotted state. Replaces the single `GameState.floor_tracker` |

`members`, `inventory`, `torch_steps_remaining`, `gold` and `scrap` stay where they are. Whether a party is out, paused or wiped is derived: out means `dungeon_id` isn't empty, paused means out and not active, and wiped means out with nobody alive. A wiped party needs no special record. It's a party lying at a place in a dungeon, and rescue is a living party reaching that place.

A character belongs to at most one party. The guild hall's available list leaves out members of every party, not just the active one.

**Gold.** `Party.gold` reads the guild's pool while the party is in town and the party's own `carried_gold` while it's out, so existing code keeps calling `add_gold` and `spend_gold` unchanged. Carried gold is banked on reaching town. Scrap works the same way. Items belong to the party carrying them.

### The calendar

Today the surface calendar only moves when a party comes home, which breaks once parties can be paused below. Instead:

- The surface calendar advances as the active party walks, a day per 120 steps, and at the inn as now.
- A surface day ages everyone in town and the active party by one day. Members of paused and wiped parties are skipped. They're frozen.
- Deep time is applied as it accrues too. Each surface day the active party walks below, its members age by that day's deep time for the floors they walked, so characters gray, change phase and gain or lose traits in the dungeon itself. The homecoming report becomes a summary of what the trip cost, not the moment it's charged.
- Death of old age still only happens on reaching town, never below.

### GameState as a view

These keep their names and become thin accessors, so existing code keeps working:

- `GameState.party` returns the active party.
- `GameState.current_floor`, `dungeon_player_position`, `dungeon_player_facing`, `dungeon_spawn_at_stairs_up` read and write the active party.
- `GameState.floor_tracker` returns the active party's tracker.
- `GameState.get_dungeon_floor`, `store_dungeon_floor`, `is_boss_slain`, `mark_boss_slain`, `deepest_floor` go to the active party's dungeon.

New code asks for `GameState.active_dungeon()` or a specific party directly.

### Saving

The save format goes to version 6: `parties` (each with member ids, not copies of the characters, as the single party is saved now), `active_party_id`, `dungeon_set`, and `story_won_day`. A version 5 save loads as one party and a set whose first dungeon takes the old floors and slain bosses, with the other three fresh. If the old save had already beaten floor 8, that dungeon loads as collapsed.

### Order of work

*All five are built.* Each step left the game playing as before, with the tests passing:

1. `Dungeon` and `DungeonSet`, with floors and bosses moved in behind the `GameState` accessors. Still one dungeon in play.
2. Location and tracker moved onto `Party`, behind the accessors.
3. `parties` and `active_party_id`, with one party.
4. The live calendar.
5. Save version 6 and the version 5 migration.

After that, the set, collapse and parties-out are features built on a model that already fits them.

## Build order

1. **The data model.** *Built.* Per-dungeon state (floors, seals, masters, step clock) and per-party state (where it is, whether it's out), in the save format from the start, even while the UI still drives one party.
2. **Collapse and the set.** *Built.* Four dungeons open at once, collapse when a master falls, strengthening of the rest, the fifth dungeon, the story ending, and a new set after. Masters start as placeholders or tinted copies.
3. **Parties out.** *Built.* Several parties out at once, switching between them, wipes that leave the party below, and rescue.
4. **Gold.** *Built*, as carried gold.
5. **Later sets.** Tiers for free play.
6. **The chronicle.** *Built.* The guild hall has a Chronicle tab: which dungeons stand or fell and when, the Legends, who holds a town post, and a dated record of collapses, wipes, rescues, retirements and deaths.
