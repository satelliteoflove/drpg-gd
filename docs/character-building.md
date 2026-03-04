# Character Building Systems

## Vision

Every character should accumulate a story that only they could have, through systems that generate narrative meaning from gameplay moments.

Characters are not stat blocks with names. A veteran Elf Mage who has watched three generations of Human companions age and die is fundamentally different from a fresh Elf Mage with the same stats. The systems described in these documents exist to make that difference visible, mechanical, and narratively rich.

## Character Creation

1. **Pick race** - determines lifespan, stat ranges, XP modifiers, resistances
2. **Pick class** - constrained by stat requirements vs. racial stat ranges + bonus points
3. **Distribute 9 bonus points** across stats (racial min to racial max)
4. **Optional aging trade** - sacrifice 1-3 years of age for 1 bonus point each
5. **Pick one personality trait** to crystallize - player chooses one axis to lock in. A second is randomly crystallized from racial weights. Remaining 2 axes are tendencies.
6. **Receive a backstory mark** - drawn from a mixed pool of generic marks plus race-specific marks

All characters start at Level 1. The old Background system (Veteran/Journeyman/Apprentice/Prodigy) is removed.

## Early Game Experience

The first dungeon floor uses procedural layout with scripted events, ensuring the first run across floors 1-2 triggers a discovery event, at least one combat mark, a micro-event between party members, and a hard choice. By the time the player returns to town, every character has gained new marks and crystallization progress. The pace then settles to the sustainable long-term rate.

## System Overview

Four interconnected systems turn mechanical gameplay into personal character stories:

### Personality Traits

Four axes of personality (Temperament, Social, Outlook, Values) that start as tendencies seeded at character creation (with 1-2 pre-crystallized from backstory) and crystallize into permanent traits through gameplay events. Speech style emerges from the trait combination rather than being tracked separately. See [narrative-systems.md](narrative-systems.md).

### Narrative Events

Hand-authored event structures with pre-written dialogue for major events and LLM-generated dialogue for micro-events. Events cast 1-3 characters from the party into dramatic moments that trigger crystallization, relationship changes, and marks. Separate from combat encounters - these fire during exploration, rest, and between floors. See [narrative-systems.md](narrative-systems.md).

### Relationships

Every character pair accumulates a stack of named modifiers (Crusader Kings style) that represent shared history. The relationship IS its history - the player sees the receipts, not an opaque number. Positive bonds provide mechanical combat bonuses. Negative relationships are narrative only. Three rotation incentives (diminishing returns, guild breadth bonuses, reunion modifiers) prevent the optimal strategy from being "never change the party." See [narrative-systems.md](narrative-systems.md).

### Marks

Permanent transformations that represent a character's history: titles earned, scars suffered, phobias gained, behaviors learned. Rich metadata tracks origin, agency, severity, and optional mechanical effects. Marks replace the existing death_count with something far more expressive. See [narrative-systems.md](narrative-systems.md).

## How Systems Connect

```
Character Creation
  - 1-2 traits pre-crystallized from backstory
  - 1 backstory mark
  - Remaining tendencies seeded from racial weights
  |
  v
Three things generate narrative changes:
  |
  +---> Combat (every fight, evaluated in real time)
  |       +---> Create marks (near-death, kills, status afflictions)
  |       +---> Shift relationships (clutch heals, fighting together)
  |       +---> Player notified immediately via notification cards
  |
  +---> Narrative Events (exploration, rest, between floors)
  |       +---> Crystallize traits
  |       +---> Create marks from choices and scenarios
  |       +---> Shift relationships between event participants
  |
  +---> Town Life (while benched)
          +---> Town events between characters in town
          +---> Relationship nudges and crystallization ticks
          +---> Town roles provide XP trickle and guild benefits
  |
  v
Everything feeds back into gameplay:
  - Combat bonuses (positive relationships = adjacency bonuses)
  - Guild breadth bonuses (total Companion+ relationships)
  - Mark effects (stat modifiers, behavioral triggers)
  - Dialogue (traits, marks, relationships inform speech)
  |
  v
Aging advances through inn rest, dungeon time, resurrection
  |
  +---> Short-lived races burn bright, peak fast, age out
  +---> Long-lived races invest slowly, persist for generations
  +---> Aging marks accumulate ("battle-worn", "graying")
  +---> Death from old age becomes possible in Fragile phase
  |
  v
Retirement and Legacy
  +---> Player chooses when to retire (not automatic)
  +---> Retirement unlocks legacy child creation
  +---> Child gets tendency bias, origin mark, relationship head-start
  +---> Death without retirement = pure loss, no legacy
```

## Racial Strategy Framework

Race choice is the first and most consequential strategic decision. Three viable strategies exist:

1. **Generalist fillers** (Human) - adequate at everything, moderate lifespan, easy to replace
2. **Short-lived sprinters** (Lizman, Rawulf, Felpurr, Mook) - fastest at one role, peak quickly, age out. Narratively intense because every moment matters. Retirement unlocks legacy children.
3. **Long-lived investments** (Elf, Dwarf, Gnome, Faerie, Hobbit, Dracon) - slower to start, eventually hit max level, decades/centuries of service at peak. They watch companions come and go.

See [racial-balance.md](racial-balance.md) for the complete race data and [aging-system.md](aging-system.md) for how aging drives these tradeoffs mechanically.

## Generational Legacy

When a character is **retired** (a deliberate player choice), the player can create a legacy child:

- **Tendency bias**: Child's personality weights are skewed toward the parent's crystallized traits. No traits are pre-crystallized from the parent.
- **Origin mark**: Parent's most significant mark becomes the child's backstory ("Child of Torben, Slayer of the Iron Golem").
- **Relationship head-start**: "Knew your father" modifier with the parent's surviving Companion/Bonded companions.
- **Same race, player's choice of class.** No generational stacking (parent only, not grandparent).
- **Retirement only.** Death without retirement = pure loss. This creates urgency to retire characters before they die and makes retirement a meaningful strategic decision.

## Implementation Priority

These systems should be built in the order that provides the most value with the least coupling:

1. **Aging** - purely mechanical, no LLM dependency, extends existing character resource
2. **Calendar and availability** - global time, recovery, town roles, catch-up/rest bonuses
3. **Racial balance changes** - XP modifier updates, add missing resistances, implement breath weapon
4. **Marks** - data structure on character resource, UI to display them, combat generation
5. **Personality traits** - tendency seeding, backstory crystallization, crystallization logic, storage
6. **Relationships** - modifier stack per character pair, combat bonuses, diminishing returns, breadth bonuses, reunion modifiers
7. **Events** - templates, casting system, scripted first floor, pre-written dialogue for major events
8. **AI dialogue** - LLM integration for micro-events, prompt construction, validation, fallback (prototype mid-stream once personality data exists)
9. **Generational legacy** - retirement flow, child creation, inheritance

## Related Documents

- [racial-balance.md](racial-balance.md) - Race identities, XP modifiers, resistances, abilities
- [narrative-systems.md](narrative-systems.md) - Personality, events, relationships, marks, LLM
- [aging-system.md](aging-system.md) - Life phases, stat decline, death mechanics
