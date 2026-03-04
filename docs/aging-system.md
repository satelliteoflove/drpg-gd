# Aging System

## Overview

Characters age through gameplay. Time passes during dungeon exploration and inn rest. Aging is the primary mechanism that differentiates short-lived sprinter races from long-lived investment races - it is the cost that makes race choice matter.

## Aging Triggers

### Inn Rest

The player chooses how many days to rest at the inn. The UI displays a clear tradeoff: more days = more HP/MP recovered, at a cost of gold and time. Every rest advances time for every character in the roster (not just the active party). The exact HP/MP recovery rate per day needs calibration against racial lifespans so that short-lived races feel time pressure without aging out before they can meaningfully contribute.

### Dungeon Time

Time passes while exploring the dungeon. Initial model: **5 turns = 1 hour of game time**. Each step, encounter, and action is 1 turn. This means a floor that takes ~500 turns to clear consumes ~100 hours (~4 days) of game time.

This rate needs validation against racial lifespans. At 100 encounters/year (from the balance model), with encounters averaging ~5 turns each, that's ~500 turns/year of combat alone. At 5 turns/hour, combat accounts for 100 hours (~4 days/year). Exploration turns would add significantly more. The total dungeon time per game-year needs to produce aging that feels meaningful but not punishing.

Tuning lever: the turns-per-hour ratio. Increasing it (10 turns/hr) slows aging; decreasing it (3 turns/hr) accelerates it.

### Resurrection

Resurrection ages the target character based on how long they were dead:
- Dead 1-5 years: ages by the time dead (already partially implemented in `character.gd`)
- Dead 10+ years (ashed): ages by the full time plus additional penalty
- This creates real urgency to resurrect quickly, especially for short-lived races

### Class Change

Class changes age the character by a duration scaled to the tier of the target class:
- **Basic-to-basic**: 30 days
- **Basic-to-advanced**: 90 days
- **Any-to-elite**: 365 days (1 year)

The character is locked out of the active roster for the full duration. For short-lived races, even a 90-day advanced class change is a significant career investment. For long-lived races, a year-long elite retraining is a rounding error. This reinforces the sprinter-vs-investment dynamic.

## Life Phases

Every race progresses through four life phases. Thresholds are derived from two inputs per race (start age, max age) using universal percentage breakpoints applied to career length (max_age - start_age):

- **Youth**: 0% to 7% of career
- **Prime**: 7% to 50% of career
- **Decline**: 50% to 80% of career
- **Fragile**: 80% to 100% of career

This means tuning only requires changing two numbers per race or the four global percentages. All thresholds recalculate automatically. See [racial-balance.md](racial-balance.md) for the full derived table.

### Youth (Start Age to Prime Start)

- Character is new to adventuring
- Slightly below peak stats, with a small bonus to stat gains on level up
- Quick growth period
- LLM dialogue can reference inexperience, eagerness, nervousness

### Prime (Prime Start to Prime End)

- Peak physical and mental performance
- No stat modifications
- This is where the character does their best work
- Duration is the key differentiator between races: 19 years for Rawulf vs 287 years for Elf

### Decline (Prime End to Decline End)

- Physical stats (STR, VIT, AGI) begin to drop
- 1 point lost at regular intervals (spread across the Decline phase, not all at once)
- Mental stats (INT, PIE) are more resistant - they decline later and slower
- LCK is unaffected by aging
- Character is still functional but noticeably weaker than their prime
- LLM dialogue can reference aching joints, slower reflexes, experience compensating for physicality
- Marks like "Graying at the temples" appear

### Fragile (Decline End to Max Age)

- Accelerating stat loss across all stats except LCK
- Increasing probability of death from old age on each rest
- The death probability is hidden from the player - they see descriptions but never the number
- Character is a liability in combat but may be invaluable for their marks, relationships, and accumulated narrative
- LLM dialogue references frailty, legacy, wisdom from experience

## Stat Decline Mechanics

### Physical Stats (STR, VIT, AGI)

During the Decline phase, physical stats lose approximately 40% of their peak value, distributed evenly across the phase duration. A Human with 30 years of Decline loses roughly 1 point of each physical stat every 2-3 years.

During the Fragile phase, the remaining 30% of peak value is at risk, with losses accelerating toward max age.

### Mental Stats (INT, PIE)

Mental stats begin declining halfway through the Decline phase (not at the start). They lose approximately 20% of peak value during Decline and another 20% during Fragile. Mental faculties degrade slower than physical ones.

### Luck (LCK)

Luck does not decline with age. It represents fortune, not capability.

### Floor Function

No stat can drop below a race-specific minimum (roughly 30% of starting stat). An ancient Elf does not become weaker than a starting Hobbit. This prevents aged characters from becoming completely non-functional.

## Death From Old Age

### Probability

During the Fragile phase, each rest event has a chance of triggering death from old age. The probability follows a curve:

- Starts near 0% at the beginning of Fragile
- Increases quadratically toward max age
- Caps at approximately 80% per rest near max age
- A character CAN live past their max age but the probability of death per rest makes it increasingly unlikely

### Hidden From Player

The player never sees the death probability number. They see:
- Aging marks ("Fragile bones", "Fading strength")
- LLM dialogue that references mortality ("I wonder how many more of these we'll see together")
- Subtle stat decline in the character sheet
- Eventually, the death itself

This preserves narrative tension. The player knows their veteran is aging but doesn't know exactly when the end comes.

### Announcement

When a character dies of old age, it should be handled with narrative weight:
- Not a combat death - it happens during rest
- The event system generates a farewell moment
- Other characters react based on their relationships with the deceased
- Relationships with the deceased are frozen (see [narrative-systems.md](narrative-systems.md) - Frozen Relationships and Loss)
- Characters with Companion or Bonded tier relationships receive a mourning mark
- Marks on the deceased become part of the guild's history
- The player is not punished mechanically beyond losing the character

### Death vs. Retirement

Death from old age is **pure loss**. The character's history is preserved but no legacy child can be created. Only voluntary retirement (a deliberate player choice made before death) unlocks the generational legacy system, and only if the character has reached Prime phase or later.

Retirement is available at any time. A retired character leaves the active roster and becomes a permanent town NPC. Youth retirements are just roster cleanup with no legacy option. Prime-or-later retirements unlock legacy child creation.

This creates urgency for declining characters: the player watches their veteran's stats decline and knows the hidden death probability is rising. They must decide when to pull the trigger on retirement. Retire too early and they lose a still-useful character. Wait too long and the character dies without leaving a legacy. The tension is between squeezing out one more dungeon run and securing the next generation.

See [design-overview.md](design-overview.md) - Generational Legacy for full details on what children inherit.

## Aging Acceleration

### Marks Can Accelerate Aging

Certain marks can accelerate aging:
- Curses that drain life force
- Traumatic events that age the body
- Resurrection side effects (already built into the resurrection aging mechanic)

### Marks Cannot Slow Aging

No mark, item, or ability should slow or reverse aging. This is a deliberate design constraint. If aging can be countered, it stops being a meaningful cost, and the entire racial balance framework (sprinters vs investments) collapses. The tension between short and long lives is the foundation of strategic race choice.

## Subtle Indicators

Rather than showing raw numbers, aging should be communicated through:

### Visual

- Character portrait annotations (gray hair, wrinkles, scars accumulating)
- Health bar color shifts in late life (subtle, not alarming)

### Narrative

- LLM dialogue references physical state ("My knees aren't what they were")
- Other characters comment on aging companions ("You sure you're up for this, old timer?")
- Veteran characters speak with authority and reference past events
- Young characters defer to or clash with elders

### Mechanical (Visible to Player)

- Stats in character sheet decline (the player sees the numbers go down)
- Life phase label visible somewhere in the UI (Youth/Prime/Decline/Fragile)
- Marks appear that reference aging

### Mechanical (Hidden From Player)

- Death probability during Fragile phase
- Exact stat decline schedule
- Maximum lifespan number

## Interaction With Racial Lifespans

The aging system makes race choice consequential over the entire game:

**Short-lived races (Rawulf, Mook, Lizman, Felpurr, Human)**:
- 19-27 years of prime
- Characters born at game start will be in Decline by mid-game
- The player WILL lose these characters to old age during a normal playthrough
- This creates real attachment and loss - the narrative system should lean into it
- Retiring a character before death unlocks legacy child creation (tendency bias, origin mark, relationship head-start with parent's companions)
- Death without retirement = pure loss, creating urgency around the retirement decision

**Long-lived races (Elf, Dwarf, Gnome, Faerie, Dracon, Hobbit)**:
- 50-325 years of prime
- These characters will outlast the game unless killed in combat
- They accumulate deep relationship stacks with multiple generations of short-lived companions
- An Elf Mage might have "Mourned the loss of Rawulf Priest Grimjaw (Year 12)" and "Mourned the loss of Human Fighter Marcus (Year 31)" as marks
- Their narrative identity becomes defined by longevity and loss

This generational dynamic is the emotional core of the aging system. It is not a bug that short-lived races die - it is the feature that makes long-lived races' stories meaningful.
