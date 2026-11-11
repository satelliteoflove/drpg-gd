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

**The energy pools in the deep.** *(Proposed, not yet agreed.)* The strengthening grows with depth. Floors 1 and 2 of every dungeon never change, the middle floors get part of it, and the bottom floors get all of it. That keeps veterans working where it matters while a party of new recruits always has somewhere safe to train, however many dungeons have fallen. Stronger monsters also give more XP, so a new party catches up faster on the middle floors than the first party did. Apprentices are the other way up.

The fifth dungeon is **one great floor**: a single large level with the story's final master at its heart. It appears once all four have collapsed. This is tentative. Dungeon generation is due a rethink after this feature, and the fifth dungeon's shape, or whether it needs one of its own, will be decided then.

## More than one party

Only one party is active at a time, but the guild can have several parties **out** at once, each in its own dungeon or even in the same one. The player can switch between them at will. Most players will run one party at a time, but nothing stops someone keeping a party in each dungeon and rotating between them.

A party that isn't active is **frozen**, as in Wizardry. It doesn't move, fight or age until the player switches back to it. Only the active party's steps move the surface calendar and its own deep-time clock.

Switching away from a party only pauses it. Its expedition hasn't ended, so nothing that happens at an expedition's end (the homecoming, a Legend passing on) is triggered by the switch.

## Wipes and rescue

A party wipe is always a major setback. The party stays where it fell, bodies and gear with it, and another party has to go down and bring them back.

So a wipe can never lock the game, a rescue party must always be able to form and train. New recruits are always available at the guild hall, and the upper floors of every dungeon stay at their original difficulty (see above). A wiped party's gold and gear are below with it, which is one argument for a guild bank.

## Gold: undecided

Whether gold belongs to each character (Wizardry), to the party, or to the guild (Etrian Odyssey) is open, and wants a careful look at what each encourages. Per-character gold makes wipes cost more and gives pooling and the bank a purpose, at the price of bookkeeping on every shop screen. A shared pool is frictionless but means a wipe costs no gold at all. Today the party shares one pool.

## Collapse

When a dungeon's master falls, the dungeon collapses. Every living party inside is cast out to town safely, along with any bodies they carry. Bodies still lying in the dungeon are **lost for good**. The collapse is always the player's choice, since it only happens when the master is defeated, so the game warns before the master's fight if anyone is still lying below.

Each collapse gets a short card: which dungeon fell, who was there, and what it means for the dungeons that remain. The full saga waits for the story's ending.

## Masters and art

Each dungeon needs its own master. Until more art arrives, masters use placeholder art or tinted copies of existing monsters. The same goes for any monster tiers in later sets.

## Aging by depth

Deep time stays as built: every step below ages the party according to the floor it's on, and deeper floors cost far more. Measured (see [deep-time.md](deep-time.md#measured)), a dungeon run costs a fresh party about 16 years and an experienced one about 10, before the inefficiencies of real play, which might push it to 15 to 30. That lands close to the two-to-four-dungeon target.

## Later sets and the great floor's clock

In free play, each new set of four is a tier harder than the last, with stronger monsters and masters, so surviving veterans still have something to push against.

Deep time on the great floor runs gentler than on the deep floors, so the final dungeon isn't also a race against age. Floor 5's rate (about three months per surface day) is a starting point to tune from.

## Build order

1. **The data model.** Per-dungeon state (floors, seals, masters, step clock) and per-party state (where it is, whether it's out), in the save format from the start, even while the UI still drives one party.
2. **Collapse and the set.** Four dungeons open at once, collapse when a master falls, strengthening of the rest, the fifth dungeon, the story ending, and a new set after. Masters start as placeholders or tinted copies.
3. **Parties out.** Several parties out at once, switching between them, wipes that leave the party below, and rescue.
4. **Gold.** Once decided.
5. **Later sets.** Tiers for free play.
6. **The chronicle.** The saga covers every dungeon so far, and the guild hall keeps a record of collapsed dungeons and Legends.
