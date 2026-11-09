# Deep Time: aging as the cost of going deep

A proposal to replace the aging model in [aging-system.md](aging-system.md). That design assumed a campaign lasting decades of game time. The game is now a 10–15 hour campaign that covers a few hundred days, so nobody ages enough for it to matter. Stretching the calendar won't fix that by itself, because a number going up in the background isn't a mechanic. This design ties aging to the one decision the player makes over and over: how deep to go and how long to stay.

## The pitch

**Time runs faster the deeper you go.** The dungeon is old, and time pools at the bottom of it like cold air. A day on floor 1 is a day. A day on floor 8 is most of a year. On the surface the calendar barely moves: the party comes back up a week after they left, but the people who come back are years older than the ones who went down.

That one rule does a lot of work:

- Aging becomes the price of depth. Pushing deeper or staying longer earns more XP and loot, and costs years of your characters' lives. Every expedition becomes a push-your-luck call.
- Race choice finally matters inside a short campaign. By the final fight your humans are gray veterans, and your elf looks exactly as she did on day one.
- Only the people who go down age. Reserves in town stay young, so the roster turns into a pipeline: who goes down this time, and who's being saved?
- It gives the game an identity. "The dungeon steals years" is a hook a player can describe to a friend.

I also considered the reverse, where the surface ages while the party is below (the Rip Van Winkle homecoming). It's evocative, but the active party wouldn't age, so it misses the point. This version keeps the eerie homecoming and still puts the cost on the characters you're playing.

## How it feels in play

Floors 1 and 2 cost almost nothing, so a new player learns the game without losing anyone to time. Around floor 4 the town report starts saying things like "Roland came back two years older," and Roland's card picks up a few gray hairs. By floor 6 the player is planning around it. Thorin the dwarf can stay down as long as he likes. Marcus the human priest is 48 now and has entered his Veteran years. His heals are better than ever, but his body is slowing down, so he moves to the back row.

Somewhere around floor 7, Roland becomes an Elder. He's the best fighter the guild has ever had and also the most fragile, and every trip down might be his last. The player has three choices: retire him to train the guild's armsmaster, take an apprentice under him, or send him on One Last Descent against Vrakthorne. Whatever happens, the ending screen tells his story: *Roland went down the stairs at 22 and came back up for the last time at 64. On the surface, 140 days had passed.*

## The mechanics

### 1. Deep time

Every day spent below ages each party member according to the deepest floor reached that day. These are starting values to tune with the sim:

| Floor | Personal time per day below |
|---|---|
| 1 | 1 day |
| 2 | 1 week |
| 3 | 1 month |
| 4 | 2 months |
| 5 | 3 months |
| 6 | 5 months |
| 7 | 7 months |
| 8 | 10 months |

The target is that a character who goes on every expedition of a full campaign ages about 35–45 years. That takes a 20-year-old human to the edge of Elder by the final fight. A Rawulf or Mook goes through their whole life, an elf ages a little, and dwarves and gnomes barely notice.

The surface calendar keeps its current rules (days below, inn nights), so the date stays human-scaled and the ending can set the two side by side.

Benched characters don't age except on the surface calendar. Resting at the inn ages everyone by a day, which is nothing next to a trip to the deep.

### 2. Seeing it

Aging has to be visible every time it happens, not just recorded on a character sheet.

- **The homecoming report.** On returning to town, a short card lists who aged and by how much ("Roland: 41 → 44"), plus any life-phase changes, written as a moment rather than a statistic. This screen is the beating heart of the system.
- **Age on every party card.** Show age next to the name in the HUD and the town party list, along with a small life-phase badge.
- **A lifeline on the character sheet.** A horizontal bar for the character's whole lifespan, split into the four phases, with a marker for where they are now. The maximum age stays hidden (the bar fades out at the far end), but the player can see a character crossing into Veteran.
- **Phase changes are scenes.** Entering a new life phase triggers a short authored scene and a mark ("Graying at the temples", "Old hands, steady hands"). These have to work with no LLM, since AI dialogue is off for now. The LLM can embellish them later.
- **Portraits.** A cheap tint or desaturation by phase now. Aged portrait variants could go on the art list for later.

### 3. Aging changes how a character plays

This is the biggest change from the old design. In the old design, old age was pure loss: stats drop and eventually you die. Under this proposal, characters trade body for skill. An old character is worth bringing, just in a different way.

The phases get new names. The old Decline and Fragile frame aging as failure, and this proposal treats it as a change of role.

| Phase | Body | Gains |
|---|---|---|
| **Youth** | Full | +25% XP (they learn fast) |
| **Prime** | Full | None, this is the baseline |
| **Veteran** | STR, VIT and AGI fall gradually | A class veteran trait (below) |
| **Elder** | Physical stats fall faster, max HP shrinks | A stronger class trait, plus **Counsel**: a party-wide bonus while they're in the party (+1 accuracy and +10% XP for everyone else) |

Class traits, as built (`systems/aging/age_traits.gd`). Elders keep their Veteran trait.

| Archetype | Veteran | Elder |
|---|---|---|
| Fighter, Samurai, Lord, Valkyrie, Monk, Ranger | +2 damage on every hit | Always acts first in the opening round |
| Thief, Ninja, Bard | A failed disarm doesn't spring the trap | Never misreads a chest (inspection always succeeds) |
| Mage, Alchemist, Psionic | +20% max MP | +25% spell damage |
| Priest | +25% healing | Intercession: once per expedition, a dying ally is held at 1 HP |
| Bishop | Everything the party finds is identified | +20% max MP and +25% healing |

These differ a little from the first draft. There's no crit system in the game, so veteran fighters get flat damage instead. Surprise only exists in the simulator, so elder thieves got sure inspection. Elder priests got Intercession, a passive save, because raising someone in the field would need a new combat action. Trait names show in the character sheet's header, with the full lines in the story overlay (S) and in the homecoming report.

The point is that an Elder in the back row is a force multiplier with a glass body. The player has to choose between carrying that risk and benching the person who makes everyone better.

### 4. Death of old age

Elders can die of old age. It only happens on returning to town, never mid-fight or mid-dungeon, so it's never a cheap shot. The chance on each homecoming rises with how far into Elder they are and with how many years that expedition took off them. The exact number stays hidden, but the homecoming card warns in prose when an Elder is close ("Roland sat down on the stairs on the way up, and it took him a while to stand").

A death from old age is a funeral, not a game over. It brings a scene, a mourning mark for anyone close to them, and their name on the guild wall.

### 5. The way out: retirement and apprentices

Losing characters is only fun if their time leaves something behind. Any Veteran or Elder can retire at the guild hall, and retirement leaves two kinds of legacy.

**A town post.** The retired character takes a job in town, gives a permanent service, and stays visible in that building's screen:

| Class | Post | Service |
|---|---|---|
| Fighter, Samurai, Lord | Armsmaster | Weapons and armor 15% cheaper |
| Priest | Temple elder | Resurrection cheaper, and less chance of ending up LOST |
| Mage | Archivist | Shop identification is free |
| Thief, Ninja | Fence | Items sell for 25% more |
| Bishop | Keeper of the guild wall | Monster lore: show enemy HP and weaknesses in combat |

One post per class, so a later retiree can take a post over from a predecessor. Over a campaign the town fills up with your old guild members, and that becomes the guild's history.

**An apprentice.** When retiring, the character names an apprentice from the roster. The apprentice jumps to a level close to the mentor's (two below at most), inherits one of the mentor's marks, and starts with a bond to the mentor's closest companions. This is the catch-up valve that keeps the pipeline workable: a fresh 18-year-old can take the old fighter's place at floor 7 without grinding floor 1 again.

### 6. One Last Descent

An Elder can declare One Last Descent at the guild hall. For one expedition their physical decline is undone, they get their Prime body back plus their Elder trait, and they gain +2 to every stat. When that expedition ends they don't come home. Either they die down there or they pass on at the top of the stairs. Either way they become a **Legend**: the name gets a gold plaque on the guild wall, the apprentice gets the full mentor level instead of two below, and the ending screen gives them their own paragraph.

This is the moment players will remember. It turns the slow sadness of aging into a choice the player makes, and a way to go out well.

### 7. The temple's price

Resurrection costs years: 1d4 years, more for anyone raised more than once. The dead come back older. It connects death and aging, and it makes the temple a real decision for short-lived characters.

### 8. The ending becomes a saga

The victory screen gets a timeline. The surface calendar runs along the top. Below it, a line for each character who ever served shows their age going in, their age coming out, their phase, and how it ended: still serving, retired to a post, died of age, fell in battle, or Legend. The headline line contrasts the two clocks: *140 days on the surface. 212 years spent below, between them.*

## Race choice under deep time

With the deep-time table above and someone who goes on every expedition:

| Race | Arc over a full campaign |
|---|---|
| Rawulf, Mook | Youth to Elder, probably a Legend or a funeral. Strong, fast and brief |
| Human, Lizman, Felpurr | Prime to Veteran, maybe Elder by floor 8 |
| Hobbit, Faerie, Dracon | Prime throughout, a few gray hairs |
| Dwarf, Gnome, Elf | Unchanged. They're the ones who remember everyone else |

The short-lived races then need something to pay for it. Lean into the existing racial XP modifiers so they level noticeably faster, and give them the best Youth bonus. A Rawulf fighter should feel like a comet.

## What this replaces in the current code

- `advance_game_days` keeps the surface calendar. Personal aging moves to a new per-character deep-time step on homecoming, driven by `FloorTracker` (days below and deepest floor each day).
- Life-phase thresholds stay as they are. The phase names change, and the stat effects change to the table above.
- Old-age death moves from per-rest to per-homecoming.
- Class-change aging and town jobs can stay as they are, but they matter much less. Town jobs could be cut in favor of the retirement posts, which do the same job with more character.
- Inn rest no longer needs to carry aging at all.

## Build order

Each step stands on its own as an improvement:

1. **Deep time plus the homecoming report**, with ages shown on the cards. This alone makes aging visible and gives depth a cost. *Built.* Rough estimate from floor sizes (about 520 walkable tiles each, 120 steps a day): someone who goes on every expedition ages about 20 years over a campaign, short of the 35–45 target. Tune with real play data before raising the table.
2. **Phase traits** (Veteran/Elder and Counsel), so aging is something to manage rather than a pure loss. *Built.*
3. **Retirement posts and apprentices**, which make the roster a pipeline and give the town a history.
4. **One Last Descent and the saga ending**.
5. Resurrection aging, portrait aging, and LLM embellishment.

## Risks

- **It punishes slow, careful players.** A cautious player spends more days below and ages more. Counsel and the Veteran traits soften this, and apprentices stop it becoming a death spiral. If it still bites, charge deep time per expedition by deepest floor rather than per day.
- **Grinding floor 8.** Staying at the bottom to grind is expensive in years, but that's intended. It's the pressure that makes the campaign end.
- **Tuning.** The table above is a guess. Step 1 should ship with the campaign sim reporting years aged per character, so the curve can be tuned before anything else is built on it.
