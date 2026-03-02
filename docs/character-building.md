# Character Building Systems

## Vision

Every character should accumulate a story that only they could have, through systems that generate narrative meaning from gameplay moments.

Characters are not stat blocks with names. A veteran Elf Mage who has watched three generations of Human companions age and die is fundamentally different from a fresh Elf Mage with the same stats. The systems described in these documents exist to make that difference visible, mechanical, and narratively rich.

## System Overview

Five interconnected systems turn mechanical gameplay into personal character stories:

### Personality Traits

Four axes of personality (Temperament, Social, Outlook, Values) that start as hidden tendencies seeded at character creation and crystallize into permanent traits through gameplay events. Speech style emerges from the trait combination rather than being tracked separately. See [narrative-systems.md](narrative-systems.md).

### Narrative Events

Hand-authored event structures with LLM-generated dialogue. Events cast 1-3 characters from the party into dramatic moments that trigger crystallization, relationship changes, and marks. Separate from combat encounters - these fire during exploration, rest, and between floors. See [narrative-systems.md](narrative-systems.md).

### Relationships

Every character pair accumulates a stack of named modifiers (Crusader Kings style) that represent shared history. The relationship IS its history - the player sees the receipts, not an opaque number. Positive bonds provide mechanical combat bonuses. Negative relationships are narrative only. See [narrative-systems.md](narrative-systems.md).

### Marks

Permanent transformations that represent a character's history: titles earned, scars suffered, phobias gained, behaviors learned. Rich metadata tracks origin, agency, severity, and optional mechanical effects. Marks replace the existing death_count with something far more expressive. See [narrative-systems.md](narrative-systems.md).

### Character Drives

The system watches for trigger conditions (bonded ally at critical HP, enemy matching a mark's theme, moral dilemma matching values) and surfaces narrative signals. The player acts on them or doesn't. Going against drives has narrative consequences; following them reinforces character identity. See [narrative-systems.md](narrative-systems.md).

## How Systems Connect

```
Character Creation
  |
  v
Tendencies seeded (hidden) -----> LLM uses immediately for dialogue
  |
  v
Two systems generate narrative changes:
  |
  +---> Narrative Events (exploration, rest, between floors)
  |       +---> Crystallize traits
  |       +---> Create marks
  |       +---> Shift relationships
  |       +---> Activate drives
  |
  +---> Combat (every fight, evaluated in real time)
          +---> Create marks (near-death, kills, status afflictions)
          +---> Shift relationships (clutch heals, fighting together)
          +---> Activate drives (bonded ally in danger, fear triggers)
          +---> Player notified immediately via combat log
  |
  v
Marks, relationships, and drives feed back into:
  - Combat bonuses (positive relationships = adjacency bonuses)
  - Mark effects (stat modifiers, behavioral triggers)
  - Narrative tension (drives vs tactical decisions)
  - LLM dialogue (traits, marks, relationships inform speech)
  |
  v
Aging advances through inn rest, dungeon time, resurrection
  |
  +---> Short-lived races burn bright, peak fast, age out
  +---> Long-lived races invest slowly, persist for generations
  +---> Aging marks accumulate ("battle-worn", "graying")
  +---> Death from old age becomes possible in Fragile phase
```

## Racial Strategy Framework

Race choice is the first and most consequential strategic decision. Three viable strategies exist:

1. **Generalist fillers** (Human) - adequate at everything, moderate lifespan, easy to replace
2. **Short-lived sprinters** (Lizman, Rawulf, Felpurr, Mook) - fastest at one role, peak quickly, age out. Narratively intense because every moment matters.
3. **Long-lived investments** (Elf, Dwarf, Gnome, Faerie, Hobbit, Dracon) - slower to start, eventually hit max level, decades/centuries of service at peak. They watch companions come and go.

See [racial-balance.md](racial-balance.md) for the complete race data and [aging-system.md](aging-system.md) for how aging drives these tradeoffs mechanically.

## Implementation Priority

These systems should be built in the order that provides the most value with the least coupling:

1. **Aging** - purely mechanical, no LLM dependency, extends existing character resource
2. **Racial balance changes** - XP modifier updates, add missing resistances, implement breath weapon
3. **Marks** - data structure on character resource, UI to display them, manual test creation
4. **Personality traits** - tendency seeding, crystallization logic, storage on character resource
5. **Relationships** - modifier stack per character pair, combat bonus integration
6. **Events** - template authoring, casting system, crystallization/mark/relationship triggers
7. **Character drives** - trigger detection, narrative signal surfacing
8. **LLM dialogue** - prompt construction, validation, fallback system

## Related Documents

- [racial-balance.md](racial-balance.md) - Race identities, XP modifiers, resistances, abilities
- [narrative-systems.md](narrative-systems.md) - Personality, events, relationships, marks, drives, LLM
- [aging-system.md](aging-system.md) - Life phases, stat decline, death mechanics
