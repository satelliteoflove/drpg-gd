# DRPG-GD Character Systems - Design Overview

**TL;DR:** DRPG-GD is a Wizardry-style dungeon crawler where characters feel alive. They develop personalities through play, form relationships with each other, accumulate permanent marks from their experiences, grow old, and eventually die or retire. A global calendar and aging system mean that time is always passing and race choice has real strategic weight. On top of the core dungeon crawling (which is already built), I'm designing the systems that make a Level 12 Dwarf Fighter feel like a person with a history - not just a stat block with a name.

## What's This About?

DRPG-GD is a first-person dungeon crawler in the Wizardry tradition. You manage a guild of adventurers, send parties of six into a procedurally generated dungeon, and try not to get everyone killed. Combat is turn-based. Characters level up, learn spells, find gear, and eventually die - sometimes heroically, sometimes because they got old. If they're lucky, they retire instead. That Lizman Fighter who carried your party through the first five floors? You might find him wiping down the bar at the tavern a few years later. The Gnome Priest who kept everyone alive? She's curing people at the temple now.

The dungeon crawling part is already built and working. This document covers what I'm building next: the systems that turn "Level 8 Elf Mage" into a character you actually care about - whether you're losing them or running into them again.

## The Big Idea

Every character should accumulate a story that only they could have.

Take two Dwarf Fighters created on the same day with the same stats. Ten years later, they're completely different people:

**Torben** rolled typical Dwarf tendencies - Brave, Gruff, Stoic, Principled. He went straight into the front row alongside a Rawulf Priest named Wick. Year 2, he got KO'd by a fire elemental on Floor 3. Mark: "Fell on Floor 3." Next fight, Wick healed him from 2 HP. Relationship modifier: "Saved my life on Floor 3." By Year 5, a discovery event on Floor 4 - strange noise behind a collapsed wall - and the player chose to investigate instead of backing off. That plus consistently choosing to fight over flee when things got ugly crystallized his Brave tendency into a permanent trait. He killed the Iron Golem boss that same year. Mark: "Slayer of the Iron Golem." Year 8, Wick entered Decline and died of old age at the inn. Torben got a mourning mark and a frozen relationship - six years of shared history, read-only, permanent. By Year 10, he's the veteran with a Companion bond with the party's Elf Mage, a dead friend's history in his record, and a reputation built from actual gameplay.

**Renna** rolled against the grain - Calculating, Sarcastic, Curious, Self-Interested. The A-team already had a Lizman Fighter, so Renna got benched. Years 1-4, she worked a town role at the guild hall training recruits - XP trickle, gold income, and town events with a Gnome Priest named Dalla who was also waiting for her shot. They bonded over shared downtime. Year 5, the Lizman entered Decline and Renna got called up. Rest bonus helped her close the level gap. She got poisoned twice on her first real floor. Mark: "Scarred by Poison." Year 7, a hard choice event fired - and the player picked the option that benefited Renna at the group's expense. The party's Principled Elf Priest took issue. Relationship modifier: "Disagreed over the tomb on Floor 6." That choice, plus a pattern of risky calls, crystallized Reckless over her original Calculating tendency. By Year 10, her closest bond is Dalla the Gnome - built over years of town life before they ever fought together.

Same race, same class, same starting stats. Different people, different histories, different relationships. These systems exist to make that kind of divergence visible, mechanical, and something the player actually feels.

## Race Choice Matters (A Lot)

There are 11 playable races. Picking one is the most consequential decision at character creation, because it determines how long the character lives, how fast they level, and what built-in advantages they carry. Three strategies emerge:

**Generalist fillers.** Humans are fine at everything (1.0 XP modifier across the board), live a moderate lifespan, and are easy to replace. The Honda Civic of adventurers.

**Short-lived sprinters.** Lizman, Rawulf, Felpurr, and Mook each have one class where they're the fastest in the game (0.7 XP modifier - they need 30% less XP to level). They hit key milestones before anyone else: healing spells, combat thresholds, trap skills. The tradeoff is they age out fast. A Rawulf Priest gets about 19 years of prime before the decline starts. You *will* lose these characters to old age in a normal playthrough. That's the point.

**Long-lived investments.** Elf, Dwarf, Gnome, Faerie, Hobbit, and Dracon level slower but stick around. A Dwarf Fighter at level 20 will still be in the front row when the Lizman Fighter's grandchildren have retired. An Elf Mage gets 287 years of prime. These characters become your guild's backbone - they watch everyone else come and go.

The tension between "burn bright and fast" and "invest for the long haul" is the foundation everything else is built on.

### Who's Fastest At What

| Class | Sprinter | XP Mod | Long-Term Pick | XP Mod |
|---|---|---|---|---|
| Fighter | Lizman | 0.7 | Dwarf | 0.9 |
| Priest | Rawulf | 0.7 | Gnome | 0.8 |
| Thief | Felpurr | 0.7 | Hobbit | 0.8 |
| Mage | *(nobody)*  | - | Faerie | 0.8 |
| Ranger | Mook | 0.7 | Elf | 1.0 |

Mage is the only class with no short-lived sprinter, which makes Faerie the obvious pick from day one. That's intentional.

### Racial Extras

Most races compete on stats and leveling speed alone. A few get something extra:

- **Dracon** have a breath weapon: acid damage equal to half their current HP, once per fight, costs no MP. Single target before level 9, group target after. Early on it's free damage when MP is scarce. Later it becomes a reliable opening salvo against entire groups.
- **Elf, Dwarf, Hobbit, Dracon** resist certain status effects (75% chance to shrug off Sleep, Poison, Paralysis, or Petrification depending on race).
- **Rawulf, Mook, Felpurr** (the furry races) have 50% cold resistance.

## Aging

Characters age through gameplay. Time passes globally - in the dungeon, at the inn, and while characters train or recover. Resurrection artificially ages the character on top of that (the process is brutal on the body). This is what makes race choice *actually* matter instead of just being a number on a spreadsheet.

### Life Phases

Every character moves through four phases. The thresholds calculate automatically from just two numbers per race (starting age and max age), so tuning is painless:

**Youth** (first 7% of career) - Fresh recruit. Slightly below peak stats, with a small bonus to stat growth. Over quickly.

**Prime** (7-50% of career) - Peak performance. No modifiers. This is the good stuff. The duration is the whole ballgame: 19 years for a Rawulf, 287 years for an Elf.

**Decline** (50-80% of career) - Physical stats start dropping. Strength, Vitality, and Agility lose roughly 40% of peak value over this phase. Mental stats hold up longer (Intelligence and Piety don't start declining until halfway through). Luck is immune to aging because luck isn't about how old you are. The character is still useful, just noticeably past their best.

**Fragile** (80-100% of career) - Everything accelerates. Each rest at the inn carries a hidden, increasing probability of death from old age. The player never sees the number. They see their stats dropping, the aging marks piling up, and the dialogue changing. Then one day they rest at the inn and someone doesn't wake up.

### Death From Old Age

It always happens during rest, not mid-combat. The event system generates a farewell moment. Surviving companions react based on their relationships. Close bonds get frozen as permanent records. Characters who were Companions or Bonded receive a mourning mark. The deceased's history becomes part of the guild's permanent record.

This isn't a punishment. It's supposed to land.

### One Hard Rule

Nothing in the game slows or reverses aging. No items, no spells, no secret techniques. If you could counter aging, it would stop being a real cost, and the whole sprinter-vs-investment framework falls apart. Some curses and resurrection can *accelerate* aging, but the clock only moves in one direction.

## Character Creation

Character creation combines race/class selection with personality and stat investment:

1. **Pick race** - determines lifespan, stat ranges, XP modifiers, resistances
2. **Pick class** - constrained by stat requirements vs. racial stat ranges + bonus points
3. **Distribute 9 bonus points** across stats (racial min to racial max)
4. **Optional aging trade** - sacrifice 1-3 years of age for 1 bonus point each. Opens elite classes for well-suited races, but costs real time from a sprinter's limited prime.
5. **Pick one personality trait** to crystallize - the player chooses one axis (Temperament, Social, Outlook, or Values) to lock in. A second trait is randomly crystallized from racial weights. Remaining 2 axes are tendencies.
6. **Receive a backstory mark** - drawn from a mixed pool of generic marks plus race-specific marks.

The old Background system (Veteran/Journeyman/Apprentice/Prodigy) is removed. All characters start at Level 1.

### Stat Point Balance

With 9 base points, all basic and advanced classes are accessible to nearly every race. Elite classes (Valkyrie, Lord, Monk, Ninja, Samurai) require either a well-suited race, aging trade, or class-changing after stat growth through leveling. Samurai is the aspirational class-change target - only Dwarf can access it at creation (with 3 years aging). This is intentional: elite classes are earned.

## Time and Availability

Time is a visible, global resource in DRPG-GD. The base unit of game time is **days**. A game calendar tracks the current date, visible in town and the guild hall. Character ages and life phases are shown on character sheets. When the party spends four days clearing a dungeon floor, four days pass for the entire guild - including the characters sitting at home. This is what ties aging, recovery, and training into a single coherent system.

### Why It Matters

The calendar exists to make roster depth a real strategic concern. You can't just invest in one party of six and ignore everyone else, because characters will be unavailable:

- **Class changes** cost time scaled by tier: 30 days (basic-to-basic), 90 days (basic-to-advanced), 365 days (any-to-elite). The character is locked out while they retrain. For a Rawulf, even 90 days is significant. For an Elf, a year is a rounding error. This reinforces the sprinter-vs-investment dynamic - the same decision costs different races very different amounts.
- **Recovery** takes real time. The player chooses how many days to rest at the inn, with a clear UI showing the tradeoff: more days = more HP/MP recovered, but more time passing for the entire guild. Gold cost is low (the inn isn't trying to bankrupt you), but the real cost is time. Every day spent recovering is a day everyone ages.
- **The dungeon is always open.** You can always go in with whoever's available. The question isn't "can I play?" - it's "who am I bringing?" Your A-team's fighter is retraining? Time for the backup to get some real experience.

### Life In Town

Characters who aren't in the dungeon aren't sitting idle. They're working.

**Town jobs.** Every benched character can be assigned a job in town. All jobs provide the same standard XP trickle and gold income - no job is mechanically optimal. The job title is narrative flavor that informs town events and personality development. Any character can hold any job: a Psionic bartender is as valid as a Fighter in the militia.

Jobs also provide **crystallization evidence** over time. A bartender slowly trends toward Friendly or Gruff. A militia fighter trends toward Brave. A gardener trends toward Stoic or Curious. Benched characters aren't narratively frozen - they evolve through daily life. Each job carries a personality bias tag indicating which trait option it nudges toward.

The job list is open-ended and expandable. Class-themed options exist (militia for fighters, temple work for priests, locksmithing for thieves) alongside class-neutral options (innkeeper, bartender, gardener, blacksmith, groundskeeper, bailiff). Each job has a limited number of slots (1-3), which forces variety in job assignments and creates a small management decision about town composition.

This ties directly into the retirement concept. The old Lizman Fighter wiping down the bar at the tavern isn't just flavor - he's earning his keep. Characters transition naturally from active duty to town jobs to full retirement, and the town reflects that history.

**Town events.** Characters in town have their own narrative micro-events. The Dwarf Fighter and the Gnome Priest who are both benched this week might share a quiet scene at the tavern - a relationship nudge, maybe a crystallization tick. Town isn't dead time. It's different time. The narrative systems keep running for everyone in the guild, not just the six characters currently in the dungeon.

**Catch-up XP.** Characters who fall behind the active party's average level get a gentle XP multiplier (1.25-1.5x) when they return to the dungeon. Bringing the B-team isn't just necessary - it's efficient. This keeps the roster viable without requiring the player to grind every character equally.

**Rest bonus.** Characters who've been in town for a while come back sharp. They get a temporary XP bonus that decays over time in the dungeon. For a brief window, a well-rested low-level character in a high-level group can gain levels quickly - thrown into the deep end and learning to swim fast. The bonus has caps and fades steadily, so it's a short burst of accelerated growth, not a permanent advantage.

### What This Does To The Game

Players naturally rotate characters, which means more of the roster accumulates marks, builds relationships, and crystallizes personality traits. The narrative systems get more material to work with. The guild hall becomes an active management screen where you're assigning roles, checking availability, and planning who goes in next.

It also prevents the degenerate strategy of picking six long-lived races and ignoring the generational dynamic entirely. Even an all-Elf party needs bench depth when someone's recovering or retraining. And with town roles and events, bench depth isn't a burden - it's an asset.

Time should feel present without being oppressive. The calendar is visible and simple. The guild hall shows availability at a glance - who's ready, who's recovering, who's training, what role they're filling, and when they're back. The player always has agency. The game never locks them out of playing - it just makes them think about who to invest in and when.

## Early Game Experience

The narrative systems described below are all slow-burn by nature. Marks accumulate over fights. Relationships build over dozens of encounters. Crystallization takes multiple events. Aging takes years. None of this helps a new player in their first 30 minutes.

Two design decisions address this directly:

### Characters Arrive With Backstory

No character starts as a blank slate. Every character created at the guild hall comes with:
- 1-2 crystallized personality traits representing their life before adventuring
- 1 mark from their past ("Apprentice Blacksmith," "Survived the Frostmarch," "Ran from Home")
- A one-line personality hook visible on creation ("Brave and sarcastic, with something to prove")

This means the player sees differentiated characters from the moment they open the guild roster. Two axes are still uncrystallized, leaving room for the player to shape who the character becomes through gameplay.

### Scripted First Floor

Floor 1 is not procedurally generated. It is a hand-designed character forge that ensures the player's first dungeon run triggers:
- A discovery event (tests Curiosity vs. Caution)
- A combat encounter that generates at least one mark
- A micro-event between two party members
- A hard choice event (tests Values axis)

By the time the player returns to town after Floor 1, every character has gained at least one new mark and at least one crystallization tick. The pace then settles to the sustainable long-term rate. The first floor front-loads the "this game is different" signal without permanently inflating event frequency.

## The Four Narrative Systems

These are listed in the order I plan to build them. Each one adds a layer on top of the previous ones.

### 1. Marks

Marks are permanent records of what happened to a character. They replace the current "you've died 3 times" counter with something that actually tells a story.

Some examples:
- "Scarred by Flame" - took critical fire damage on Floor 5
- "Dragonslayer" - landed the killing blow on a dragon boss
- "Haunted" - witnessed three companions die
- "Twice-Dead" - has been resurrected twice
- "Graying at the temples" - entered the Decline life phase

Each mark carries metadata: where and when it happened, whether the character was the actor ("I killed the dragon"), the subject ("the dragon almost killed me"), or a witness ("I watched the dragon kill Marcus"). Major marks are always visible on the character sheet. Minor marks collapse until you expand them.

Most marks are narrative-only - they exist for the story and for the AI dialogue system to reference. A few carry small mechanical effects: "Afraid of Fire" might impose a small penalty against fire enemies, "Dragonslayer" might give a small bonus against dragons. These are exceptions, not the norm.

Marks come from combat (automatically generated from near-death experiences, knockouts, kills, status afflictions) and from narrative events (moral choices, discoveries, pivotal moments). Some are cumulative - a character who keeps getting knocked out accumulates a history that tells a story ("Won't Stay Down"). Realistically, that kind of punishment takes a toll on the body. But stat penalties from bad outcomes create death spirals that discourage using vulnerable characters, and we couldn't find a way to make that fun. So hardship marks are narrative-only - they make the character more interesting without making them worse at their job. Mechanical effects are reserved for achievements and player choices.

### 2. Personality Traits

Each character has four personality axes with four options each:

| Axis | Options |
|---|---|
| Temperament | Brave, Cautious, Reckless, Calculating |
| Social | Friendly, Gruff, Sarcastic, Earnest |
| Outlook | Optimistic, Pessimistic, Stoic, Curious |
| Values | Merciful, Ruthless, Principled, Self-Interested |

That's 256 possible combinations. Speech style isn't tracked separately - it emerges from the mix. A Brave+Sarcastic+Optimistic character quips under fire. A Cautious+Earnest+Pessimistic one worries out loud. The AI dialogue system figures out the voice from the trait profile.

At character creation, each race has weighted probabilities that seed initial **tendencies**. Dwarves lean Brave/Gruff/Stoic/Principled. Faeries lean different. But any individual can roll against the grain. The player sees tendencies right away (displayed dimmed and italic) - they know which way the wind is blowing, but nothing is locked yet.

**Crystallization** is how tendencies become permanent traits. A simple counter tracks evidence: every time gameplay pushes a character toward "Brave" (they're in a fight, they charge ahead), the Brave counter ticks up. Hit 4 ticks and the tendency locks in as a permanent trait (displayed solid and bold). Some major events skip the counter entirely and let the player make a direct choice - "this is who your character becomes, right now."

Once crystallized, traits almost never change. If they do, something dramatic happened.

### 3. Relationships

Every pair of characters builds a stack of named modifiers that represent their shared history. Inspired by Crusader Kings: you don't see "Affection: 47." You see the receipts.

- "Saved my life on Floor 3" (+positive)
- "Fought side by side against the Minotaur" (+small positive)
- "Argued over the chalice" (-negative)
- "Survived the Dragon together" (+positive)

These accumulate into bond tiers:

| Tier | Name | Combat Effect |
|---|---|---|
| 0 | Neutral | Nothing. Default. |
| 1 | Companion | Small accuracy/defense bonus when adjacent in combat |
| 2 | Bonded | Bigger adjacency bonus |

Reaching a tier is a milestone the player sees. Losing a Bonded companion hurts mechanically - the replacement starts at Neutral and you can't speed-run the bond back.

**Negative relationships are narrative only.** No combat penalties. The penalty is missing out on the bonuses everyone else has. This is intentional. Punishing players mechanically for narrative outcomes feels bad and makes people disengage from the system. Positive-only rewards encourage investment without punishment.

**Growth is slow on purpose.** The "fought side by side" modifier is tiny per fight. You need dozens of fights together to reach Companion. Clutch moments (healing someone from the brink, reviving a downed ally) are worth more but happen rarely. It should feel like trust earned over a long career, not instant BFFs. This slowness is exactly what makes losing someone to old age sting - that bond took real time to build and the new recruit starts from zero.

**Rotation incentives.** Three mechanics prevent the optimal strategy from being "never change the party":

- *Diminishing returns*: The "fought side by side" modifier gets smaller the more times it fires between the same pair consecutively. Fresh pairings generate full-weight modifiers. The player isn't punished for stability - they just gain less per fight. Swapping in a bench character creates new pairings at full weight.
- *Guild breadth bonuses*: The game tracks total unique Companion+ relationships across the entire guild. Hitting thresholds unlocks guild-wide benefits (better shop prices, faster recovery, XP bonuses). This rewards broad relationship building across the roster, not just deep bonds within one party.
- *Reunion modifiers*: When two characters with existing positive relationships are reunited in a party after time apart, they receive a one-time "Good to see you again" modifier. Separation creates reunion value. Rotation stops feeling like breaking up the team and starts feeling like setting up future reunions.

**Frozen relationships.** When a character dies, their relationships aren't deleted. The full history with every surviving character is preserved as read-only. The player can still browse everything those characters went through together. Surviving characters with close bonds receive a mourning mark. A veteran Elf with a list of frozen relationships carries that history alongside their marks, their traits, and their active bonds. It's all part of the same record.

### 4. Narrative Events

Hand-authored dramatic structures with AI-generated dialogue. I write the scenario, the roles, the choices, and the consequences. The AI fills in what the characters actually say based on who they are.

**Event types:**
- **Discovery events** - found something weird in the dungeon. Are you curious or cautious?
- **Hard choice events** - moral dilemmas. Save the stranger or protect the party?
- **Memory events** - quiet camp moments referencing past marks and relationships.
- **Combat aftermath events** - reacting to what just happened in battle.
- **Micro-events** - the lightest touch. One character says one line. The player picks which party member responds (or dismisses). One line back, a tiny relationship nudge, maybe a tick toward crystallization. One tap, done. These fire frequently and provide the steady personality drip between major events.

When an event fires, the system casts party members into roles based on trait match, who hasn't had screen time recently, whether this could crystallize a pending trait, and relationship relevance. Everyone gets their moment.

## How It Fits Together

```
Character Creation
  - Race determines lifespan, stats, XP speed, resistances
  - 1-2 personality traits pre-crystallized (backstory)
  - 1 mark from life before adventuring
  - Remaining tendencies influenced by racial bias + randomness
  |
  v
Three things generate narrative changes:
  |
  +---> Combat (every fight)
  |       - Marks from near-death, kills, status effects
  |       - Relationship shifts from heals, revives, fighting together
  |       - Player notified immediately via notification cards
  |
  +---> Narrative Events (exploration, rest, between floors)
  |       - Crystallize personality traits
  |       - Create marks from choices and scenarios
  |       - Shift relationships between event participants
  |
  +---> Town Life (while benched)
  |       - Town events between characters in town
  |       - Relationship nudges and crystallization ticks
  |       - Town roles provide XP trickle and guild benefits
  |
  v
Everything feeds back into gameplay:
  - Positive bonds = combat adjacency bonuses
  - Guild breadth bonuses from total Companion+ relationships
  - Marks with effects = small stat modifiers or triggers
  - All of it informs AI dialogue
  |
  v
Aging advances through dungeon time and inn rest
  - Resurrection artificially ages the individual (not time passing)
  - Sprinters burn bright, peak fast, age out or retire
  - Investments build slowly, persist for generations
  - Aging marks accumulate
  - Death from old age hits during rest in the Fragile phase
  - Frozen relationships carry the legacy forward
  |
  v
Retirement and Legacy
  - Player chooses when to retire a character
  - Retired characters work town roles, become guild NPCs
  - Retirement (not death) unlocks legacy: create a child character
  - Child gets tendency bias from parent, "Knew your father" bonds
  - Death without retirement = pure loss, no legacy
```

## Combat Notifications

Players should never find out about a meaningful change after it already happened. When something matters in combat, they see it right then:

- **Notification cards** for major moments (new marks, significant relationship shifts). Temporary overlay, auto-dismiss, queued if multiple fire in one round. Doesn't pause combat.
- **Combat log entries** for the small stuff (adjacency bond ticks). There if you look, not in your face if you don't.
- **Post-combat summary** if anything changed during the fight. Skippable, shown by default.

## AI Dialogue

A hybrid approach splits dialogue responsibility by stakes:

**Major narrative events** (discovery, hard choice, combat aftermath, memory) use **pre-written dialogue** tagged by trait combination. These are the moments that define characters and create lasting marks. Every word is authored during development. Quality is fully controlled.

**Micro-events and combat quips** use **LLM generation** with pre-written fallback. These are high-volume, low-stakes moments where personality flavor matters more than precision. A mediocre line here is quickly forgotten. A great line is a bonus.

The LLM system is provider-agnostic - swap the model without touching the event or dialogue systems. The tone target is modern and natural. No "forsooth" or "prithee." Characters talk like people. Most lines are 5-15 words. Longer lines are reserved for emotional peaks.

Every generated line goes through validation: correct names, within word limits, not repeating recent dialogue, no anachronisms or fourth-wall breaks. Failed lines retry twice with corrective prompts, then fall back to pre-written lines tagged by trait combination. All failures get logged for analysis.

## Why Any Of This Matters

The goal is that after a few hours of play, the player stops thinking about stat blocks and starts thinking about people. Not because the game told them to care, but because the systems made it unavoidable. Marks give characters a past. Personality gives them a voice. Relationships give them connections to each other. Aging gives them a timeline that's always moving.

None of these systems are remarkable on their own. A mark is just a label. A relationship modifier is just a number with a name. A tendency is just a weighted random roll. But layered together over hours of gameplay, they accumulate into something that feels like a real history - and that history is different for every character in the guild.

One consequence of all this is the generational dynamic. An Elf Mage who outlives 12+ generations of Human companions carries a record of every one of those relationships. That's powerful. But it's one thread. The Rawulf Priest who only lived 19 years of prime but crystallized as Brave, earned "Slayer of the Iron Golem," and built a Bonded relationship with the party's Dwarf - that character's story is just as complete. It's just shorter.

The systems don't care how long a character lives. They care about what happens while they're here.

## Generational Legacy

When a character is **retired** (not killed - retirement is a deliberate player choice), the player can create a legacy child. This turns the loss of a sprinter from wasted investment into a down payment on the next generation.

### What the Child Inherits

- **Tendency bias**: The child's personality tendency weights are skewed toward the parent's crystallized traits. No traits are pre-crystallized from the parent - the child develops their own personality, but the apple doesn't fall far from the tree.
- **Origin mark**: The parent's most significant mark becomes the child's backstory ("Child of Torben, Slayer of the Iron Golem"). Narrative continuity without mechanical power.
- **Relationship head-start**: A "Knew your father" named modifier with the parent's surviving companions who had Companion or Bonded tier relationships. Small positive weight - not enough to skip the bond-building process, but enough that they're not strangers.

### Constraints

- **Retirement only.** Death from old age, combat death, or any other loss does not qualify. This makes retirement a meaningful strategic decision with a tangible reward, and creates real urgency to retire characters before they die.
- **Same race.** The child is the same race as the parent. Cross-race inheritance doesn't make narrative sense and would create optimization incentives that undermine race identity.
- **Class is the player's choice.** The child follows their own path.
- **No generational stacking.** Legacy bonuses come from the parent only, not the grandparent. This prevents breeding-program optimization.

## Build Order

1. **Aging** - mechanical foundation, no dependencies
2. **Calendar and availability** - global time, recovery, town roles, catch-up/rest bonuses
3. **Racial balance** - XP modifier changes, resistance updates, breath weapon
4. **Marks** - data structure, combat generation, UI
5. **Personality traits** - tendency seeding, backstory crystallization, crystallization logic, storage
6. **Relationships** - modifier stacks, bond tiers, combat bonuses, diminishing returns, breadth bonuses, reunion modifiers
7. **Events** - templates, casting, scripted first floor, pre-written dialogue for major events
8. **AI dialogue** - LLM integration for micro-events, prompt construction, validation, fallback (prototype mid-stream once personality data exists)
9. **Generational legacy** - retirement flow, child creation, inheritance

## Retirement

Retirement is always available and **permanent**. A retired character leaves the active roster and becomes a permanent town NPC - they still exist, still fill town roles, still show up in the guild's history. They cannot be un-retired. This gives the decision real weight, especially since retirement is the gate to legacy children.

**Equipment stays with the retiree.** If the player wants gear back, they strip the character before retiring. This creates a natural "prepare for retirement" ritual.

**Legacy children** require the retiring character to have reached Prime phase or later. Youth retirements are just roster cleanup - no legacy. This prevents farming legacy children from throwaway characters while keeping retirement accessible for roster management.

**The retirement screen** shows a summary of the character's history: their marks, crystallized traits, and top relationships. If the character has Companion or Bonded relationships, 1-2 templated companion lines reference real relationship data ("We survived the Iron Golem together. I won't forget that."). Characters with no close bonds get a quieter exit. The ceremony scales with investment automatically because it's a presentation layer on existing data, not a new system.

## Roster Management

### Guild Cap

The active (non-retired) roster is capped at 25 characters. This gives room for two active parties, a group of swap-ins, and town role coverage without drowning in management overhead. Retired characters don't count against the cap.

### Total Party Kill

When the active party is wiped out in the dungeon, the bodies stay where they fell. The player assembles a rescue team from the bench to recover them. This turns a TPK from a game-over screen into a new gameplay scenario:

- Bench characters with lower levels and weaker bonds are suddenly the A-team
- The rescue run generates marks and relationships for the rescuers
- Senior/declining characters on the bench become critical - past their prime but the most capable rescue team available
- Bodies degrade on the game calendar: unrecovered bodies eventually become ashed (harder to resurrect, more aging penalty on resurrection)
- Every day spent preparing the rescue team is a day the bodies are degrading AND the entire guild is aging

The body degradation timer ties into the same calendar system that drives everything else, creating natural urgency without artificial failure limits.

## Target Playtime

A full playthrough targets **80-120 real-world hours**. This gives the generational dynamics room to breathe:
- Multiple cycles of sprinters aging out and being replaced
- Long-lived races becoming guild anchors in the second half
- Relationships building, freezing, and accumulating across generations
- The full retirement/legacy cycle playing out multiple times

All system pacing (event frequency, aging rate, relationship growth speed, crystallization thresholds) should be calibrated against this target.

## Save Compatibility

These systems represent a fundamental redesign of the character model. Existing save files from before these systems are implemented will not be migrated. Players start fresh. This ensures every player experiences the full system from character creation onward.

## Feedback Welcome

If something here doesn't make sense, sounds overcomplicated, or seems like it would be annoying to actually play - I'd like to hear that now rather than after I've built it. The detailed specs live in the companion docs (aging-system.md, racial-balance.md, narrative-systems.md) if you want to dig deeper into any specific system.
