# Narrative Systems

## Combat-Generated Changes

Combat is a primary source of marks and relationship shifts - not just narrative events. Every fight is evaluated in real time for moments that matter.

### Combat Marks

| Trigger | Mark | Severity | Notes |
|---|---|---|---|
| Character drops below 25% HP | "Brushed with death on Floor N" | Minor | Cumulative - multiple near-deaths can upgrade to "Death-Defier" |
| Character is KO'd | "Fell on Floor N" | Minor | Feeds into death_count replacement |
| Character kills a boss/elite | "Slayer of [Enemy Name]" | Major | Actor agency, triumph theme |
| Character deals killing blow on a new enemy type for the first time | "First [Enemy] Kill" | Minor | Only tracked for notable enemy types, not every rat |
| Character afflicted by a status effect | "Scarred by [Element/Status]" | Minor | Cumulative - repeated fire damage becomes "Afraid of Fire" |
| Character survives a fight where 2+ allies were KO'd | "Sole Survivor of Floor N" | Major | Witness agency, loss theme |
| Character is resurrected in combat | "Pulled Back from the Brink" | Minor | Subject agency, death theme |

### Combat Relationship Modifiers

| Trigger | Modifier | Value | Notes |
|---|---|---|---|
| Character heals an ally from below 25% HP | "Saved my life on Floor N" | Positive | Strong bond-builder |
| Character revives a KO'd ally | "Brought me back on Floor N" | Positive | Very strong |
| Two characters in adjacent positions survive a fight with 3+ enemies | "Fought side by side on Floor N" | Positive | Small but frequent - the bread and butter of combat bonding |
| Character is KO'd while an ally with healing spells/items took a different action | *(no modifier)* | - | Intentionally NOT tracked - too complex to infer intent, would feel unfair |
| Characters survive a boss fight together | "Survived [Boss Name] together" | Positive | Shared triumph, scales with fight difficulty |

### Relationship Growth Rate

The "fought side by side" modifier is deliberately weak per occurrence. Combat bonds build slowly over many fights, not a few:

- A single "fought side by side" modifier is worth very little on its own
- It takes dozens of fights together before the accumulated bond reaches a meaningful combat bonus threshold
- This means losing a long-term companion to old age is felt mechanically - the replacement starts with zero bond, and it takes real time to rebuild
- Clutch moments (saves, revives, boss victories) are worth more per instance but are rare enough not to accelerate the curve
- The system should feel like trust earned over a career, not friendship after three fights

### Notification Timing

The player should never discover a mark or relationship change after the fact. Changes are surfaced immediately when they happen, with prominence scaled to significance.

**During combat - notification cards:**

Major moments (marks, significant relationship shifts) are shown as a temporary notification card that overlays the combat UI briefly. This is more prominent than a combat log line - it's a visual callout that something meaningful just happened.

- Mark earned: card shows mark name, icon, and the character it applies to. Auto-dismisses after a few seconds.
- Relationship shift: card shows the two characters, the modifier name, and a positive/negative indicator. Auto-dismisses.
- Cards queue if multiple trigger in the same round - they don't stack or overlap.
- Cards do NOT pause combat. They're informational, not interactive.

Minor moments (small adjacency bond ticks) are logged in the combat log only - no card. The player can see them if they look but they don't interrupt the flow.

**Post-combat summary:**

If any marks or relationship changes occurred during the fight, a summary screen appears after combat resolves. This catches anything the player missed during a hectic fight. The summary is skippable but shown by default.

**Outside combat:**

- Narrative event changes shown inline as the event plays out
- Crystallization is a major moment - shown with its own dedicated UI treatment, not buried in a log or card. This is a defining character moment and should feel like one.
- Aging milestones (entering a new life phase) shown on rest

## Personality Traits

### Four Axes

Each character has four personality axes. Each axis has four possible values:

| Axis | Options | What It Governs |
|---|---|---|
| **Temperament** | Brave, Cautious, Reckless, Calculating | How the character approaches danger and risk |
| **Social** | Friendly, Gruff, Sarcastic, Earnest | How the character interacts with others |
| **Outlook** | Optimistic, Pessimistic, Stoic, Curious | How the character interprets events |
| **Values** | Merciful, Ruthless, Principled, Self-Interested | What the character prioritizes in moral decisions |

This gives 256 possible personality combinations (4^4).

Speech style is NOT a separate axis. It emerges from the trait combination. A Brave+Sarcastic+Optimistic+Principled character speaks differently from a Cautious+Earnest+Pessimistic+Merciful one, and the LLM infers that from the trait profile.

### Tendency Visibility

Tendencies are visible to the player from the start, but visually distinct from crystallized traits. The player can see that a character "seems Brave" but knows it isn't locked in yet.

- **Tendencies**: displayed dimmed/italic - the character leans this way but it could change
- **Crystallized traits**: displayed solid/bold - this is who they are now

This lets the player engage with personality from the beginning and anticipate crystallization moments.

### Crystallization Through Play

Traits start as tendencies and crystallize into permanent traits through a hybrid system:

1. **Creation**: Tendencies are seeded from racial weights with randomness. Character creation stays fast - no personality choices for the player.
2. **Early play**: The LLM uses tendencies immediately for dialogue. No cold-start problem.
3. **Organic accumulation (most events)**: Gameplay events and player tactical decisions generate evidence for or against a tendency. The player makes tactical choices (fight or retreat, help or ignore); the system interprets those through each character's lens. A Brave-tending character in a fight reinforces Brave; the same character in a retreat accumulates counter-evidence. 3-4 events pushing the same direction triggers crystallization.
4. **Pivotal moments (major events)**: Certain hand-authored events (boss aftermath, hard moral choices, floor milestones) present a direct choice that crystallizes a trait immediately. These are rare and dramatic - the player is explicitly deciding who this character becomes.
5. **Crystallization**: When an axis crystallizes (by either path), the trait locks in permanently. Shown with dedicated UI treatment. Stored on the character resource with metadata about the triggering event.
6. **Post-crystallization**: Crystallized traits rarely shift. Extreme events can trigger a re-crystallization, but this should be exceptionally rare and dramatic.

### Backstory Crystallization

Every new character arrives with 2 personality axes already crystallized:
- **Player-chosen**: The player picks one axis (Temperament, Social, Outlook, or Values) and selects which trait to crystallize on that axis.
- **Random**: A second axis is crystallized randomly using the racial tendency weights.
- The remaining 2 axes are uncrystallized tendencies that the player shapes through gameplay.

Each new character also arrives with 1 backstory mark drawn from a mixed pool: 10-15 generic marks available to any race ("Apprentice Blacksmith," "Ran from Home," "Survived a Plague") plus 3-5 race-specific marks per race ("Former Miner" for Dwarves, "Century of Study" for Elves). This ensures characters feel differentiated from the moment they join the guild.

### Tendency Seeding

Tendencies are seeded from **race only** - class does not influence personality. Each race has weighted probabilities per axis, and the system picks randomly from those weights at creation time.

Example - Dwarf tendency weights:
- Temperament: 50% Brave, 25% Calculating, 15% Reckless, 10% Cautious
- Social: 45% Gruff, 25% Earnest, 20% Friendly, 10% Sarcastic
- Outlook: 40% Stoic, 25% Pessimistic, 20% Optimistic, 15% Curious
- Values: 35% Principled, 30% Merciful, 20% Ruthless, 15% Self-Interested

Two Dwarf characters will likely have similar tendencies but can differ. A Dwarf Fighter and a Dwarf Priest start with the same personality distribution - their class shapes what they can do, not who they are.

This requires 11 tendency weight tables (one per race), each defining weights for 4 axes x 4 options = 16 values.

### Crystallization Evidence

Organic crystallization uses a simple counter per axis per option. Each relevant event, tactical decision, or micro-event response ticks the counter for the matching trait option.

Example - Elara's Temperament axis:
- Brave: 3
- Cautious: 1
- Reckless: 0
- Calculating: 0

When any option reaches a threshold (initially 4, tunable), that trait crystallizes. Pivotal events in major hand-authored events bypass the counter and crystallize immediately based on the player's direct choice.

### Storage

On the Character resource, personality data includes:
- `tendencies`: Dictionary of axis -> tendency value (the initial seed)
- `evidence`: Dictionary of axis -> Dictionary of option -> int (counter per option per axis)
- `traits`: Dictionary of axis -> crystallized trait value (post-crystallization)
- `crystallization_events`: Dictionary of axis -> event metadata that triggered crystallization

Pre-crystallization, the LLM reads the tendency. Post-crystallization, it reads the trait. The player sees both states with distinct visual treatment (dim/italic for tendencies, solid/bold for crystallized).

## Event System

### Structure

Events are hand-authored structures with LLM-generated dialogue. Each event defines:

- **Trigger conditions**: When can this event fire? (floor depth, party state, time since last event, etc.)
- **Character slots**: 1-3 roles that party members are cast into (e.g., "the discoverer", "the skeptic", "the witness")
- **Slot requirements**: What traits/marks/relationships make a character eligible for each slot
- **Setup text**: Scene-setting description (hand-authored, not LLM)
- **Choice points**: Player decisions within the event
- **Consequences**: What happens mechanically (trait crystallization, marks, relationship changes)
- **Dialogue prompts**: Context sent to the LLM for each character's lines

### Event Categories

- **Discovery events**: Finding something unusual in the dungeon. Reveals character curiosity/caution.
- **Hard choice events**: Moral dilemmas that test Values. Do you save the stranger or protect the party?
- **Memory events**: Quiet moments that reference past marks or relationships. Camp conversations, rest interactions.
- **Combat aftermath events**: Reactions to what just happened in battle. Near-death experiences, first kills, witnessing allies fall.
- **Micro-events**: Lightweight 1-line character statements with an optional player response. See Micro-Events section below.

### Casting System

When an event fires, the system casts party members into character slots using these priorities (highest first):

1. **Trait match**: Does the character's tendency/trait fit the slot's requirements?
2. **Spotlight balance**: Has this character been underrepresented in recent events?
3. **Crystallization opportunity**: Could this event crystallize an unresolved axis for this character?
4. **Relationship relevance**: Does this character have a meaningful relationship with another cast member?
5. **Randomness**: Tie-breaking and occasional surprise casting.

### Micro-Events

Micro-events sit between full narrative events and pure flavor text. A character says one personality-appropriate line (LLM-generated), and the player chooses which companion responds - or dismisses.

**Flow:**
1. System picks a character to speak based on context and spotlight balance
2. LLM generates a single line from that character's personality profile
3. Player sees the line plus 2 response options (other party members) and a dismiss button
4. Each response is a single line generated from that character's personality
5. Picking a response creates a tiny positive relationship nudge between the two characters
6. If either character has an uncrystallized axis, the content of their line counts as crystallization evidence

**Example - post-combat:**
> **Thorin** *(Gruff, Stoic)*: "Could've been worse."
> - [Elara] "For once, I agree with you."
> - [Grimjaw] "Speak for yourself."
> - [Dismiss]

**Responder selection** uses lightweight casting: spotlight balance, relationship relevance, crystallization opportunity. The two candidates should be different characters each time where possible.

**Triggers:**
- Post-combat (most natural moment for a quip)
- Reaching a new floor
- Finding notable loot
- After resting at the inn
- Chance-based during exploration (every N steps)

**Design constraints:**
- One line in, one tap out. Fast. Never a conversation.
- Nudges are tiny - smaller than combat adjacency bonds
- Dismiss has no penalty
- Frequency starts high (err toward too many) and is tuned down through playtesting
- The same character should not initiate two micro-events in a row

### Event Pacing

Event frequency starts high and will be dialed back through playtesting. Initial target: err toward too frequent rather than too rare. Characters need enough events to crystallize traits and build relationships within the timeframes dictated by racial lifespans - a Rawulf with 19 years of prime cannot wait long between events.

### Template Requirements

The game needs a minimum of 6 event templates to start, with the goal of building to dozens. Templates should cover each event category and provide varied trigger conditions to avoid repetition.

Event templates are JSON data files, one per template, with the structure described above.

## Relationships

### Named Modifier Stacks

Every character pair has a relationship represented as a stack of named modifiers. Relationships are stored in a **separate RelationshipManager** singleton (not on individual Character resources), keyed by character-pair ID. This provides a single source of truth and simplifies freezing relationships when a character dies.

Each modifier records:

- **Name**: What happened ("Saved my life on Floor 3", "Argued over the chalice", "Fought side by side against the Minotaur")
- **Value**: Positive or negative numeric weight
- **Source**: Event or gameplay moment that created it
- **Timestamp**: When it was added (game time)

The relationship IS its history. The player sees the receipts - not an opaque affection score, but a list of specific shared experiences with their individual weights.

### Bond Tiers

Relationships exist in three states based on accumulated positive weight:

| Tier | Name | Combat Bonus | Threshold |
|---|---|---|---|
| 0 | Neutral | None | Default starting state |
| 1 | Companion | Small adjacency accuracy/defense bonus | Moderate positive weight (dozens of fights together or a few clutch moments) |
| 2 | Bonded | Larger adjacency bonus | High positive weight (long shared history, multiple significant events) |

Reaching a tier is a milestone the player sees. Losing a Bonded companion (to death or aging) is mechanically significant - the replacement starts at Neutral and takes real time to rebuild.

**Negative relationships are narrative only:**
- Tense banter, friction in dialogue, reluctance in events
- No mechanical combat penalties
- The implied penalty is the absence of positive bonuses
- A character who hates everyone misses out on all adjacency bonuses

This is deliberate. Penalizing the player mechanically for narrative outcomes feels punitive and discourages engagement with the system. Positive-only mechanics reward investment without punishing story.

### Rotation Incentives

Three mechanics prevent the optimal strategy from being "never change the party":

**Diminishing returns on same-pair bonding.** The "fought side by side" modifier gets smaller the more times it fires between the same pair consecutively. Fresh pairings generate full-weight modifiers. The player isn't punished for stability - they just gain less per fight. Swapping in a bench character creates new pairings at full weight.

**Guild breadth bonuses.** The game tracks total unique Companion+ relationships across the entire guild roster. Hitting thresholds unlocks guild-wide benefits (better shop prices, faster recovery, XP bonuses, reduced resurrection costs). This rewards broad relationship building across the roster rather than deep bonds within one party.

**Reunion modifiers.** When two characters with existing positive relationships are reunited in a party after time apart, they receive a one-time "Good to see you again" modifier. Small positive weight that reframes separation as creating reunion value. Rotation stops feeling like breaking up the team and starts feeling like setting up future reunions.

### Frozen Relationships and Loss

When a character dies (combat or old age), their relationships are NOT deleted:

- **Frozen relationships**: The full modifier stack with every surviving character is preserved as read-only history. The player can still view everything those characters went through together. The relationship can no longer grow.
- **Mourning mark**: Surviving characters with Companion or Bonded tier relationships receive a mark ("Mourning [Name]"). This mark:
  - Informs the LLM for grief-appropriate dialogue
  - Can trigger event casting (seeing an enemy type that killed the fallen companion)
  - Fades naturally over game time (grief diminishes but the frozen relationship record persists forever)
- **Narrative continuity**: A veteran Elf with a list of frozen relationships tells their own story. The UI should make this history accessible - these aren't dead data, they're the character's biography.

### UI

Per-character relationship screen showing:
- List of all characters this character has a relationship with
- Each relationship shows the modifier stack (recent first)
- Color coding: green for positive, red for negative, with intensity indicating magnitude
- Total relationship summary visible at a glance
- Bond level thresholds for mechanical bonuses clearly indicated

### Character Departure

Whether characters can leave the guild due to negative relationships is deferred. This is a significant mechanical decision (losing a leveled character to AI behavior) that needs careful design. For now, negative relationships are narrative flavor only.

## Marks

### What Marks Are

Marks are permanent transformations that represent a character's accumulated history. They replace the existing `death_count` field with a far richer system.

Examples:
- "Scarred by Flame" (took critical fire damage on Floor 5)
- "Dragonslayer" (landed the killing blow on a dragon boss)
- "Haunted" (witnessed three companions die)
- "Mercy-Giver" (chose to spare an enemy in a hard choice event)
- "Twice-Dead" (has been resurrected twice)

### Mark Metadata

Each mark stores:

| Field | Type | Description |
|---|---|---|
| name | String | Display name ("Scarred by Flame") |
| origin | String | Where/when it happened ("Floor 5, Year 3") |
| theme_tags | Array[String] | Categories: combat, loss, fear, triumph, moral_choice, discovery, death, etc. |
| agency | Enum | actor (did something), subject (something happened to them), witness (saw it happen) |
| severity | Enum | major (always displayed, from hand-authored events) or minor (collapsed in UI) |
| characters_involved | Array[String] | IDs of other characters present/relevant |
| mechanical_effect | Optional | Stat modifier, resistance, behavior change, or null |
| created_at | int | Game time when mark was created |

### Severity Tiers

**Major marks** come from hand-authored events and significant gameplay moments. Always visible in the character sheet. Examples: "Dragonslayer", "Oath-Breaker", "Savior of the Lost".

**Minor marks** come from routine gameplay accumulation. Collapsed in the UI unless expanded. Examples: "Battle-Worn", "Floor 7 Veteran", "Twice-Dead".

### Cumulative vs Singular

**Cumulative marks** build up from repeated experiences. Getting knocked unconscious in combat once adds a minor mark. Getting knocked out five times might trigger a crystallization event or upgrade the mark to something like "Glass Jaw" with a mechanical effect.

**Singular marks** come from unique, major events. Finding the cursed chalice, defeating a boss, making a pivotal moral choice. These carry immediate narrative and potentially mechanical weight.

### Mechanical Effects

Mark effects are optional and should be used sparingly:
- "Afraid of Fire" - small penalty against fire enemies, or hesitation dialogue
- "Dragonslayer" - small bonus against dragon-type enemies
- "Twice-Dead" - cosmetic (pale complexion, dialogue references)
- "Oath-Breaker" - relationship penalty with Principled characters

Most marks should be narrative-only. Mechanical effects are the exception for particularly significant marks.

### Aging Marks

The aging system generates marks naturally:
- "Graying at the temples" (entering Decline)
- "Battle-worn veteran" (long career with many combat marks)
- "Ancient eyes" (entering Fragile phase)

These are minor marks that the LLM can reference in dialogue to make aging feel organic rather than just a stat change.

### Replacing death_count

The current `death_count` field on Character should be replaced by marks. Each death becomes:
- "Fell on Floor N" (minor mark, subject, death theme)
- "Raised from the Dead" (minor mark, subject, death theme, includes aging metadata)
- Multiple deaths accumulate into "Twice-Dead", "Thrice-Dead", etc.

This preserves the mechanical information while adding narrative richness.

## LLM Dialogue Generation

### Approach

A hybrid model splits dialogue responsibility by stakes:

**Major narrative events** (discovery, hard choice, combat aftermath, memory) use **pre-written dialogue** tagged by trait combination. These are the defining character moments. Every word is authored during development. Quality is fully controlled.

**Micro-events and combat quips** use **LLM generation** with pre-written fallback. These are high-volume, low-stakes moments where personality flavor matters more than precision. If the LLM is great, micro-events feel alive. If it's mediocre, the player's most important moments are still hand-written.

Hand-authored event structures define WHAT happens. For major events, pre-written dialogue covers HOW characters say things. For micro-events, the LLM generates HOW characters say things with trait-tagged fallback lines as a safety net.

### Language Style

Modern, natural language. No fake medieval prose. Characters speak like real people - the setting is fantasy but the dialogue is contemporary. Brevity is key: most lines should be 5-15 words. Longer lines are reserved for emotional peaks.

### Prompt Structure

Each dialogue generation request includes:

1. **World context**: Current floor, recent events, time of day, party state
2. **Character profile**: Name, race, class, level, personality traits (or tendencies), active marks
3. **Relationship context**: How this character feels about other characters in the scene (modifier stack summary)
4. **Speech guidance**: Derived from trait combination. Not explicit instructions like "speak gruffly" but implicit through trait description ("This character is Gruff and Stoic - they use few words and avoid emotional displays")
5. **Recent dialogue cache**: Last 3-5 lines of dialogue from this character to avoid repetition
6. **Constraints**: Maximum line length, forbidden words/phrases, required references (if the event template demands the character mention a specific thing)

### Validation Pipeline

Every generated line goes through validation:

1. **Name check**: Does the line use correct character/item/location names?
2. **Length check**: Is it within the specified word limit?
3. **Repetition check**: Is it too similar to recent dialogue from this character?
4. **Content check**: Does it contain anything anachronistic, meta, or breaking the fourth wall?

Tone correctness is not validated programmatically - the prompt is responsible for getting tone right. If the prompt is well-constructed with clear trait descriptions and speech guidance, the model should produce appropriate tone. If it doesn't, that's a prompt engineering problem to solve iteratively, not a validation gate.

### Failure Handling

1. **First failure**: Re-generate with a corrective prompt that specifies what went wrong ("Line was too long, maximum 15 words" or "Character name was wrong, use 'Thorin' not 'Thoren'")
2. **Second failure**: Re-generate with tighter constraints
3. **Third failure**: Fall back to pre-written generic lines tagged by trait combination
4. **All failures logged**: Every failed generation is logged with full diagnostic data:
   - The prompt sent
   - The response received
   - Which validation step failed
   - The corrective prompt (if re-generated)
   - The final result (fallback or successful re-generation)
   - Tagged with a unique ID for analysis

### LLM Provider

Local Wayfarer model. The prompt structure should be provider-agnostic so the backend can be swapped without changing the event/dialogue system.

### Context Budget

The LLM context window should not constrain system design. If the full character profile + relationship stack + event context exceeds the context window, the system should summarize/truncate intelligently rather than omitting systems. Priority order for context budget:
1. Character traits and active marks (must include)
2. Event-specific context (must include)
3. Relationship summary with scene partners (should include)
4. Recent dialogue cache (should include)
5. World context (can summarize)
6. Full mark history (can truncate to recent/relevant)
