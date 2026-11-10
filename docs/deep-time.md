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

The target is that a character who goes on every expedition of a full campaign ages about 15–25 years, so an average character lasts two to four campaigns. A human lasts two or three, a Rawulf or Mook about two, a hobbit four or five, and dwarves, gnomes and elves outlast everyone. The spread between races is intended: it's a large part of what makes race choice matter.

The surface calendar keeps its current rules (days below, inn nights), so the date stays human-scaled and the ending can set the two side by side.

Benched characters don't age except on the surface calendar. Resting at the inn ages everyone by a day, which is nothing next to a trip to the deep.

### Measured

`tests/measure_deep_time.tscn` estimates what a dungeon run costs. It generates 12 layouts per floor and has a bot explore each one fully, counting a tile as seen once the party stands on it or next to it. It counts the enemy groups each floor starts with and simulates fights for XP per fight. All floors are 31×31 with about 520 walkable tiles and about 25 starting groups, so a fight comes every 22 steps or so while exploring.

| Floor | Days aged per day | Years to explore once | Years per 10 fights | XP per fight |
|---|---|---|---|---|
| 1 | 1 | 0.01 | 0.00 | 21 |
| 2 | 7 | 0.09 | 0.04 | 29 |
| 3 | 28 | 0.34 | 0.15 | 51 |
| 4 | 56 | 0.70 | 0.29 | 75 |
| 5 | 84 | 1.03 | 0.41 | 120 |
| 6 | 140 | 1.80 | 0.74 | 169 |
| 7 | 196 | 2.46 | 1.01 | 262 |
| 8 | 280 | 3.72 | 1.43 | 217 |

A fresh party that explores every floor once and grinds on the floor above each boss until it reaches the level the boss needs ages about **16 years** by the bottom: 10 from exploring, and 6 from about 60 fights of grinding on floor 7 before the drake. An experienced party that only explores ages about **10 years**. Floors 7 and 8 account for about 60% of the exploring years, and floors 1 to 3 for under 5%.

The bot explores efficiently (its steps barely exceed the tile count), and the estimate leaves out backtracking, retreats, trips to town and fights from respawns. Real play will cost more, maybe one and a half to two times as much. That puts a dungeon run at roughly 15 to 30 years, so a human lasts two or three dungeons and a Rawulf one or two, close to the target.

Where you grind is the big lever. XP per fight rises with depth about as fast as the years per fight do, so through floors 3 to 7 a level costs about the same number of years wherever you earn it, and floor 8 costs more. Floors 1 and 2 are the exception. A level near 10 takes about 475 fights on floor 1 for a quarter of a year, or 345 on floor 2 for about a year, against about 38 fights and four years on floor 7. So the player can trade hours of play for years of life, which seems like a fair choice to offer.

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
| **Youth** | Full | None. The +25% XP bonus was cut, since it lasted far longer for long-lived races |
| **Prime** | Full | None, this is the baseline |
| **Veteran** | STR, VIT and AGI fall gradually | A class veteran trait (below) |
| **Elder** | Physical stats fall faster, max HP shrinks | A stronger class trait, plus **Counsel**: a party-wide bonus while they're in the party (everyone else gets +10% XP, +1 accuracy, and 10 points off their spell fizzle chance) |

Class traits, as built (`systems/aging/age_traits.gd`). Elders keep their Veteran trait.

| Archetype | Veteran | Elder |
|---|---|---|
| Fighter, Samurai, Lord, Valkyrie, Monk, Ranger | +2 damage on every hit | Always acts first in the opening round |
| Thief, Ninja, Bard | A failed disarm doesn't spring the trap | The party can't be surprised |
| Mage, Alchemist, Psionic | +20% max MP | +25% spell damage |
| Priest | +25% healing | Intercession: once per expedition, a dying ally is held at 1 HP |
| Bishop | Everything the party finds is identified | +20% max MP and +25% healing |

These differ a little from the first draft. There's no crit system in the game, so veteran fighters get flat damage instead. Elder priests got Intercession, a passive save, because raising someone in the field would need a new combat action. Trait names show in the character sheet's header, with the full lines in the story overlay (S) and in the homecoming report.

The point is that an Elder in the back row is a force multiplier with a glass body. The player has to choose between carrying that risk and benching the person who makes everyone better.

### 4. Death of old age

Elders can die of old age. It only happens on returning to town, never mid-fight or mid-dungeon, so it's never a cheap shot. The chance on each homecoming rises with how far into Elder they are and with how many years that expedition took off them. The exact number stays hidden, but the homecoming card warns in prose when an Elder is close ("Roland sat down on the stairs on the way up, and it took him a while to stand").

A death from old age is a funeral, not a game over. It brings a scene, a mourning mark for anyone close to them, and their name on the guild wall.

### 5. The way out: retirement and apprentices

Losing characters is only fun if their time leaves something behind. Any Veteran or Elder can retire at the guild hall, and retirement leaves two kinds of legacy.

**A town post.** The retired character takes a job in town, gives a permanent service, and stays visible in that building's screen:

| Class | Post | Service |
|---|---|---|
| Fighter, Samurai, Lord, Valkyrie, Monk, Ranger | Armsmaster | Weapons and armor 15% cheaper |
| Priest | Temple elder | Resurrection 25% cheaper, and ashes come back 75% of the time instead of 50% |
| Mage, Alchemist, Psionic | Archivist | Shop identification is free |
| Thief, Ninja, Bard | Fence | Items sell for 25% more |
| Bishop | Almoner | A night at the inn costs half as much |

As built (`systems/aging/retirement.gd`), posts go by the same archetypes as the phase traits. The Bishop's post changed from monster lore to Almoner, since combat already shows enemy HP. Holders are named in the top bar of the shop, temple and inn.

One holder per post, so a later retiree takes a post over from a predecessor, who stays retired. Over a campaign the town fills up with your old guild members, and that becomes the guild's history.

**An apprentice.** When retiring, the character names an apprentice from the roster. The apprentice jumps to a level close to the mentor's (two below at most), inherits one of the mentor's marks, and starts with a bond to the mentor's closest companions. This is the catch-up valve that keeps the pipeline workable: a fresh 18-year-old can take the old fighter's place at floor 7 without grinding floor 1 again. As built, the apprentice gets the mentor's newest major mark (credited as the mentor's story), a companion-level bond with the mentor, and a third of the mentor's bond with each of the people the mentor knew.

### 6. One Last Descent

An Elder can declare One Last Descent at the guild hall. For one expedition their physical decline is undone, they get their Prime body back plus their Elder trait, and they gain +2 to every stat. When that expedition ends they don't come home. Either they die down there or they pass on at the top of the stairs. Either way they become a **Legend**: the name gets a gold plaque on the guild wall, the apprentice gets the full mentor level instead of two below, and the ending screen gives them their own paragraph.

This is the moment players will remember. It turns the slow sadness of aging into a choice the player makes, and a way to go out well.

As built (`systems/aging/last_descent.gd`), the vow is sworn from the guild hall's Roster tab and can't be taken back. The apprentice is named when the vow is sworn but only trained when the Legend passes, at whatever level they reached on the way down, so swearing the vow and then benching the Elder gets nothing. A Legend passes on whenever the expedition ends, by the stairs, a Recall Stone or the final victory. Everyone who went down with them gets a mark. There's no guild wall screen yet, so the plaque is a gold LEGEND chip on the roster.

### 7. The temple's price

Resurrection costs years: 1d4 years, more for anyone raised more than once. The dead come back older. It connects death and aging, and it makes the temple a real decision for short-lived characters.

As built, each raise rolls 1d4 years per time the character has been raised, so the first costs 1d4, the second 2d4, and so on. That applies at the temple and to resurrection spells. The temple shows the range before you pay and the years taken afterward.

### 8. The ending becomes a saga

The victory screen gets a timeline. The surface calendar runs along the top. Below it, a line for each character who ever served shows their age going in, their age coming out, their phase, and how it ended: still serving, retired to a post, died of age, fell in battle, or Legend. The headline line contrasts the two clocks: *140 days on the surface. 212 years spent below, between them.*

As built, each line is a lifeline instead of a span on the surface calendar: the character's whole lifespan, faintly split into the four phases and fading out at the far end, with the years they served drawn bright. That makes race differences obvious at a glance: an elf's service is a sliver, and a human's can run from Prime into Elder. Legends get their own paragraph above it.

## Race choice under deep time

With the deep-time table above and someone who goes on every expedition:

| Race | Arc over a full campaign |
|---|---|
| Rawulf, Mook | Youth to Elder, probably a Legend or a funeral. Strong, fast and brief |
| Human, Lizman, Felpurr | Prime to Veteran, maybe Elder by floor 8 |
| Hobbit, Faerie, Dracon | Prime throughout, a few gray hairs |
| Dwarf, Gnome, Elf | Unchanged. They're the ones who remember everyone else |

The short-lived races then need something to pay for it. Lean into the existing racial XP modifiers so they level noticeably faster. A Rawulf fighter should feel like a comet.

## What this replaces in the current code

- `advance_game_days` keeps the surface calendar. Personal aging moves to a new per-character deep-time step on homecoming, driven by `FloorTracker` (days below and deepest floor each day).
- Life-phase thresholds stay as they are. The phase names change, and the stat effects change to the table above.
- Old-age death moves from per-rest to per-homecoming.
- Class-change aging and town jobs can stay as they are, but they matter much less. Town jobs could be cut in favor of the retirement posts, which do the same job with more character.
- Inn rest no longer needs to carry aging at all.

## Build order

Each step stands on its own as an improvement:

1. **Deep time plus the homecoming report**, with ages shown on the cards. This alone makes aging visible and gives depth a cost. *Built.* Rough estimate from floor sizes (about 520 walkable tiles each, 120 steps a day): someone who goes on every expedition ages about 20 years over a campaign, inside the 15–25 target. Confirm with a measured campaign.
2. **Phase traits** (Veteran/Elder and Counsel), so aging is something to manage rather than a pure loss. *Built.*
3. **Retirement posts and apprentices**, which make the roster a pipeline and give the town a history. *Built.* Retire from the guild hall's Roster tab. Retirees leave the party list for good, and the ending lists them under "Keeping the Town".
4. **One Last Descent and the saga ending**. *Built.*
5. Resurrection aging, portrait aging, and LLM embellishment. *Built, apart from the LLM.* Characters have class emblems rather than portraits, so the emblem grays in the Veteran and Elder years, and the character sheet's header carries the lifeline from section 2 (the same drawing as the saga). LLM embellishment waits until AI dialogue is back on.

## Risks

- **It punishes slow, careful players.** A cautious player spends more days below and ages more. Counsel and the Veteran traits soften this, and apprentices stop it becoming a death spiral. If it still bites, charge deep time per expedition by deepest floor rather than per day.
- **Grinding floor 8.** Staying at the bottom to grind is expensive in years, but that's intended. It's the pressure that makes the campaign end.
- **Tuning.** The table above is a guess. Step 1 should ship with the campaign sim reporting years aged per character, so the curve can be tuned before anything else is built on it.
