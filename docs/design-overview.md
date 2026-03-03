# DRPG-GD Character Systems - Design Overview

**TL;DR:** DRPG-GD is a Wizardry-style dungeon crawler where characters age and eventually die or retire. Race choice determines whether a character peaks in 19 years or 287, and a global calendar means time passes for everyone - even characters sitting in town. On top of the core dungeon crawling (which is already built), I'm designing systems that give characters personality traits, relationship histories, permanent marks from their experiences, and AI-generated dialogue that reflects who they've become. The emotional core of the whole thing: your long-lived characters watch generations of short-lived companions come, contribute, and pass on - and they carry that history with them forever.

## What's This About?

DRPG-GD is a first-person dungeon crawler in the Wizardry tradition. You manage a guild of adventurers, send parties of six into a procedurally generated dungeon, and try not to get everyone killed. Combat is turn-based. Characters level up, learn spells, find gear, and eventually die - sometimes heroically, sometimes because they got old. If they're lucky, they retire instead. That Lizman Fighter who carried your party through the first five floors? You might find him wiping down the bar at the tavern a few years later. The Gnome Priest who kept everyone alive? She's curing people at the temple now.

The dungeon crawling part is already built and working. This document covers what I'm building next: the systems that turn "Level 8 Elf Mage" into a character you actually care about - whether you're losing them or running into them again.

## The Big Idea

Every character should accumulate a story that only they could have.

Two Elf Mages with identical stats are not the same character if one of them watched three generations of Human companions grow old and die while the other just rolled off the creation screen. These systems exist to make that kind of history visible, mechanical, and something the player feels in their gut when things go wrong.

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
| Mage | *(nobody)* | - | Faerie | 0.8 |
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

## Time and Availability

Time is a visible, global resource in DRPG-GD. There's a game calendar, and it moves forward for everyone. When the party spends four days clearing a dungeon floor, four days pass for the entire guild - including the characters sitting at home. This is what ties aging, recovery, and training into a single coherent system.

### Why It Matters

The calendar exists to make roster depth a real strategic concern. You can't just invest in one party of six and ignore everyone else, because characters will be unavailable:

- **Class changes** take a full year of in-game time. The character is locked out while they retrain. For a Rawulf, that's roughly 5% of their entire prime. For an Elf, it's a rounding error. This reinforces the sprinter-vs-investment dynamic - the same decision costs different races very different amounts.
- **Recovery** takes real time. HP and MP regenerate gradually at the inn - not instantly. Gold cost is low (the inn isn't trying to bankrupt you), but the real cost is time. Every day spent recovering is a day everyone in the guild ages. Having a healer at the inn with the recovering group accelerates HP recovery - the priest naturally casts healing spells as their own MP regenerates. Characters recover without a healer too, just slower. This creates a strategic choice: keep the healer at the inn to speed things up, or send them into the dungeon with the B-team who also needs support.
- **The dungeon is always open.** You can always go in with whoever's available. The question isn't "can I play?" - it's "who am I bringing?" Your A-team's fighter is retraining? Time for the backup to get some real experience.

### Life In Town

Characters who aren't in the dungeon aren't sitting idle. They're working.

**Town roles.** Every benched character can be assigned a role in town - the priest works at the temple, the fighter trains recruits at the guild hall, the thief runs the shop. Each role provides a steady trickle of XP and gold, and some provide guild-wide benefits: reduced resurrection costs, better shop prices, small stat bonuses for new recruits. This means the roster isn't a penalty - it's a workforce. The player is managing a guild, not just a party.

This ties directly into the retirement concept. The old Lizman Fighter wiping down the bar at the tavern isn't just flavor - he's earning his keep and contributing to the guild's bottom line. Characters transition naturally from active duty to support roles to full retirement, and the town reflects that history.

**Town events.** Characters in town have their own narrative micro-events. The Dwarf Fighter and the Gnome Priest who are both benched this week might share a quiet scene at the tavern - a relationship nudge, maybe a crystallization tick. Town isn't dead time. It's different time. The narrative systems keep running for everyone in the guild, not just the six characters currently in the dungeon.

**Catch-up XP.** Characters who fall behind the active party's average level get a temporary XP multiplier when they return to the dungeon. Bringing the B-team isn't just necessary - it's efficient. This keeps the roster viable without requiring the player to grind every character equally.

**Rest bonus.** Characters who've been in town for a while come back sharp. They get a temporary XP bonus that decays over time in the dungeon. For a brief window, a well-rested low-level character in a high-level group can gain levels quickly - thrown into the deep end and learning to swim fast. The bonus has caps and fades steadily, so it's a short burst of accelerated growth, not a permanent advantage.

### What This Does To The Game

Players naturally rotate characters, which means more of the roster accumulates marks, builds relationships, and crystallizes personality traits. The narrative systems get more material to work with. The guild hall becomes an active management screen where you're assigning roles, checking availability, and planning who goes in next.

It also prevents the degenerate strategy of picking six long-lived races and ignoring the generational dynamic entirely. Even an all-Elf party needs bench depth when someone's recovering or retraining. And with town roles and events, bench depth isn't a burden - it's an asset.

Time should feel present without being oppressive. The calendar is visible and simple. The guild hall shows availability at a glance - who's ready, who's recovering, who's training, what role they're filling, and when they're back. The player always has agency. The game never locks them out of playing - it just makes them think about who to invest in and when.

## The Five Narrative Systems

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

**Frozen relationships.** When a character dies, their relationships aren't deleted. The full history with every surviving character is preserved as read-only. The player can still browse everything those characters went through together. Surviving characters with close bonds receive a mourning mark. A veteran Elf with a long list of frozen relationships has a biography written entirely in the experiences they shared with people who are gone. That's the story the game is telling.

### 4. Narrative Events

Hand-authored dramatic structures with AI-generated dialogue. I write the scenario, the roles, the choices, and the consequences. The AI fills in what the characters actually say based on who they are.

**Event types:**
- **Discovery events** - found something weird in the dungeon. Are you curious or cautious?
- **Hard choice events** - moral dilemmas. Save the stranger or protect the party?
- **Memory events** - quiet camp moments referencing past marks and relationships.
- **Combat aftermath events** - reacting to what just happened in battle.
- **Micro-events** - the lightest touch. One character says one line. The player picks which party member responds (or dismisses). One line back, a tiny relationship nudge, maybe a tick toward crystallization. One tap, done. These fire frequently and provide the steady personality drip between major events.

When an event fires, the system casts party members into roles based on trait match, who hasn't had screen time recently, whether this could crystallize a pending trait, and relationship relevance. Everyone gets their moment.

### 5. Character Drives

The system watches for situations that collide with a character's personality and surfaces short narrative signals. The Brave character watches the party retreat: "[Name] hesitates at the retreat." The character with "Afraid of Fire" faces a fire-using enemy: "[Name] flinches at the flames." The Bonded ally drops to critical HP: "[Name] shouts [Ally's] name."

These are signals, not commands. The player always makes the tactical call. The system just interprets that call through each character's personality and generates narrative ripples. Follow the drive and the trait deepens. Go against it and there's friction - uncomfortable banter, strained relationships, maybe even a trait shifting if you consistently override it.

The guiding principle: the tail does not wag the dog. Narrative sits on top of tactics. It never overrides them.

## How It Fits Together

```
Character Creation
  - Race determines lifespan, stats, XP speed, resistances
  - Personality tendencies influenced by racial bias + randomness
  |
  v
Three things generate narrative changes:
  |
  +---> Combat (every fight)
  |       - Marks from near-death, kills, status effects
  |       - Relationship shifts from heals, revives, fighting together
  |       - Drive activations from personality clashing with situation
  |       - Player notified immediately via notification cards
  |
  +---> Narrative Events (exploration, rest, between floors)
  |       - Crystallize personality traits
  |       - Create marks from choices and scenarios
  |       - Shift relationships between event participants
  |       - Activate drives through moral and tactical dilemmas
  |
  +---> Town Life (while benched)
  |       - Town events between characters in town
  |       - Relationship nudges and crystallization ticks
  |       - Town roles provide XP trickle and guild benefits
  |
  v
Everything feeds back into gameplay:
  - Positive bonds = combat adjacency bonuses
  - Marks with effects = small stat modifiers or triggers
  - Drives = narrative tension layered on tactical decisions
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
```

## Combat Notifications

Players should never find out about a meaningful change after it already happened. When something matters in combat, they see it right then:

- **Notification cards** for major moments (new marks, significant relationship shifts, drive activations). Temporary overlay, auto-dismiss, queued if multiple fire in one round. Doesn't pause combat.
- **Combat log entries** for the small stuff (adjacency bond ticks). There if you look, not in your face if you don't.
- **Post-combat summary** if anything changed during the fight. Skippable, shown by default.

## AI Dialogue

A local AI model (Wayfarer) generates what characters say. The system is provider-agnostic - swap the model without touching the event or dialogue systems.

I write the events. The AI writes the lines. The tone target is modern and natural. No "forsooth" or "prithee." Characters talk like people. Most lines are 5-15 words. Longer lines are reserved for emotional peaks.

Every generated line goes through validation: correct names, within word limits, not repeating recent dialogue, no anachronisms or fourth-wall breaks. Failed lines retry twice with corrective prompts, then fall back to pre-written generic lines. All failures get logged for analysis.

## Why Any Of This Matters

The generational dynamic is the emotional core of everything I'm designing here.

An Elf Mage will genuinely outlive 12+ generations of Human companions and 17+ generations of Rawulf companions. That's not a flavor text number. It's a mechanical reality that plays out through frozen relationships, mourning marks, and dialogue that references the departed.

The player who recruits a Rawulf Priest knows they're choosing someone who will peak fast, contribute enormously in the early game, and then age out. The bond that Rawulf builds with the party's Dwarf Fighter over dozens of fights becomes a Companion or Bonded relationship - and when the Rawulf dies of old age, the Dwarf carries a mourning mark and a frozen relationship stack that tells the story of everything they went through together. The next Rawulf Priest starts at Neutral. The Dwarf remembers.

That's what these systems are building toward.

## Build Order

1. **Aging** - mechanical foundation, no dependencies
2. **Calendar and availability** - global time, recovery, town roles, catch-up/rest bonuses
3. **Racial balance** - XP modifier changes, resistance updates, breath weapon
4. **Marks** - data structure, combat generation, UI
5. **Personality traits** - tendency seeding, crystallization, storage
6. **Relationships** - modifier stacks, bond tiers, combat bonuses
7. **Events** - templates, casting, dialogue triggers
8. **Character drives** - trigger detection, narrative signals
9. **AI dialogue** - prompt construction, validation, fallback

## Feedback Welcome

If something here doesn't make sense, sounds overcomplicated, or seems like it would be annoying to actually play - I'd like to hear that now rather than after I've built it. The detailed specs live in the companion docs (aging-system.md, racial-balance.md, narrative-systems.md) if you want to dig deeper into any specific system.
