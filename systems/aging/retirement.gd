class_name Retirement
extends RefCounted

## Veterans and elders can retire. A retiree takes a post in town that gives
## the guild a lasting service, and can name an apprentice who jumps close to
## their level. See docs/deep-time.md.

const POSTS := {
	"armsmaster": {
		"title": "Armsmaster", "place": "shop",
		"effect": "weapons and armor cost 15% less", "short": "arms 15% off",
	},
	"fence": {
		"title": "Fence", "place": "shop",
		"effect": "items sell for 25% more", "short": "sales +25%",
	},
	"archivist": {
		"title": "Archivist", "place": "shop",
		"effect": "identification is free", "short": "free identify",
	},
	"temple_elder": {
		"title": "Temple Elder", "place": "temple",
		"effect": "resurrection costs 25% less, and ashes come back three times in four",
		"short": "raising 25% off, ashes 75%",
	},
	"almoner": {
		"title": "Almoner", "place": "inn",
		"effect": "a night's rest costs half as much", "short": "rest half price",
	},
}

const ARMSMASTER_DISCOUNT := 0.85
const FENCE_MARKUP := 1.25
const TEMPLE_ELDER_DISCOUNT := 0.75
const TEMPLE_ELDER_ASH_SUCCESS := 0.75
const ALMONER_DISCOUNT := 0.5
## How far below the mentor an apprentice lands.
const APPRENTICE_LEVEL_GAP := 2


static func post_for(c: Character) -> String:
	match AgeTraits.archetype(c):
		AgeTraits.Archetype.SKULKER:
			return "fence"
		AgeTraits.Archetype.ARCANE:
			return "archivist"
		AgeTraits.Archetype.DIVINE:
			return "temple_elder"
		AgeTraits.Archetype.BISHOP:
			return "almoner"
	return "armsmaster"


static func post_title(post_id: String) -> String:
	return POSTS.get(post_id, {}).get("title", "")


static func post_effect(post_id: String) -> String:
	return POSTS.get(post_id, {}).get("effect", "")


## Who holds [param post_id], or null if it's vacant.
static func holder(post_id: String) -> Character:
	if GameState.roster == null:
		return null
	for c in GameState.roster.get_all():
		if c.is_retired() and c.town_post == post_id:
			return c
	return null


static func is_held(post_id: String) -> bool:
	return holder(post_id) != null


## One line for a building's top bar, e.g. "Armsmaster Roland: arms 15% off",
## covering every held post at [param place]. Empty if none are held.
static func note_for(place: String) -> String:
	var parts: PackedStringArray = []
	for post_id: String in POSTS:
		if POSTS[post_id]["place"] != place:
			continue
		var h := holder(post_id)
		if h:
			parts.append("%s %s: %s" % [post_title(post_id), h.character_name, POSTS[post_id]["short"]])
	return "  ·  ".join(parts)


static func can_retire(c: Character) -> bool:
	return AgeTraits.is_veteran(c) and not c.is_dead and not GameState.is_away(c) and not c.has_left_service() \
		and not c.last_descent and not c.is_training() and not c.has_status(CharacterEnums.StatusEffect.LOST)


static func apprentice_candidates(mentor: Character) -> Array[Character]:
	var out: Array[Character] = []
	for c in GameState.roster.get_all():
		if c == mentor or c.is_dead or GameState.is_away(c) or c.has_left_service() or c.last_descent or c.is_training():
			continue
		if c.has_status(CharacterEnums.StatusEffect.LOST):
			continue
		out.append(c)
	return out


static func apprentice_level(mentor: Character, apprentice: Character, gap: int = APPRENTICE_LEVEL_GAP) -> int:
	return maxi(apprentice.level, mentor.level - gap)


## Retires [param c] to their post, with an optional apprentice. Returns the
## lines to show the player.
static func retire(c: Character, apprentice: Character) -> Array[String]:
	var lines: Array[String] = []
	var post_id := post_for(c)
	var previous := holder(post_id)
	if previous:
		previous.town_post = ""
		lines.append("%s steps down as %s." % [previous.character_name, post_title(post_id)])

	if GameState.party.has_member(c):
		GameState.party.remove_member(c.id)
	c.town_job = -1
	c.availability = Character.AVAILABILITY_RETIRED
	c.town_post = post_id
	c.end_service("retired", GameState.game_day)
	GameState.record("retired", "%s retired at %d to become the guild's %s." % [
		c.character_name, c.get_age_years(), post_title(post_id)])
	c.add_mark(Marks.create_mark("Retired as the guild's %s" % post_title(post_id), "retirement",
		["retirement"] as Array[String], Marks.Agency.ACTOR, Marks.Severity.MAJOR,
		[] as Array[String], GameState.game_day))
	lines.append("%s retires at %d and becomes the guild's %s: %s." % [
		c.character_name, c.get_age_years(), post_title(post_id), post_effect(post_id)])

	if apprentice:
		lines.append_array(train_apprentice(c, apprentice))
	return lines


## Raises [param apprentice] to [param gap] levels below the mentor and passes
## on a piece of the mentor's story and some of their bonds.
static func train_apprentice(mentor: Character, apprentice: Character,
		gap: int = APPRENTICE_LEVEL_GAP) -> Array[String]:
	var lines: Array[String] = []
	var old_level := apprentice.level
	var target := apprentice_level(mentor, apprentice, gap)
	if target > old_level:
		var needed := ExperienceTable.get_required_xp(target, apprentice.race, apprentice.character_class)
		apprentice.add_experience(maxi(0, needed - apprentice.experience))
		while apprentice.pending_level_up:
			apprentice.confirm_level_up()
		for spell in SpellLearning.get_learnable_spells(apprentice):
			if not apprentice.known_spells.has(spell.id):
				apprentice.known_spells.append(spell.id)
		apprentice.current_hp = apprentice.max_hp
		apprentice.current_mp = apprentice.max_mp

	var involved: Array[String] = [mentor.id]
	apprentice.add_mark(Marks.create_mark("Apprenticed to %s" % mentor.character_name, "apprenticeship",
		["legacy"] as Array[String], Marks.Agency.SUBJECT, Marks.Severity.MAJOR,
		involved, GameState.game_day))
	var inherited := inherited_story(mentor)
	if not inherited.is_empty():
		var copy := inherited.duplicate(true)
		copy["origin"] = "inherited"
		copy["name"] = "%s (%s's story)" % [inherited.get("name", ""), mentor.character_name]
		copy["characters_involved"] = [mentor.id] as Array[String]
		copy["created_at"] = GameState.game_day
		apprentice.add_mark(copy)

	# The apprentice starts out on good terms with the mentor and with the
	# people the mentor was close to.
	RelationshipManager.add_modifier(mentor.id, apprentice.id, "apprenticeship",
		Relationships.COMPANION_THRESHOLD, GameState.game_day)
	for rel: Dictionary in RelationshipManager.get_relationships_for(mentor.id):
		var other_id: String = rel["other_id"]
		var weight: int = rel["weight"]
		if other_id == apprentice.id or weight <= 0:
			continue
		RelationshipManager.add_modifier(apprentice.id, other_id, "mentor's friend",
			weight / 3, GameState.game_day)

	if apprentice.level > old_level:
		lines.append("%s takes %s on as an apprentice. Level %d → %d." % [
			mentor.character_name, apprentice.character_name, old_level, apprentice.level])
	else:
		lines.append("%s takes %s on as an apprentice." % [mentor.character_name, apprentice.character_name])
	if not inherited.is_empty():
		lines.append("%s carries on a piece of %s's story: “%s”." % [
			apprentice.character_name, mentor.character_name, inherited.get("name", "")])
	return lines


## The newest major mark that isn't about aging or retirement itself.
static func inherited_story(mentor: Character) -> Dictionary:
	var marks := mentor.get_major_marks()
	for i in range(marks.size() - 1, -1, -1):
		var origin: String = marks[i].get("origin", "")
		if origin in ["deep_time", "retirement", "apprenticeship", "inherited", "last_descent"]:
			continue
		return marks[i]
	return {}


# --- Post effects ------------------------------------------------------------------

static func buy_price(item: Item) -> int:
	if item.is_equipment() and is_held("armsmaster"):
		return maxi(1, int(item.buy_price * ARMSMASTER_DISCOUNT))
	return item.buy_price


static func sell_price(item: Item) -> int:
	if is_held("fence"):
		return int(item.sell_price * FENCE_MARKUP)
	return item.sell_price


static func identify_cost(item: Item) -> int:
	return 0 if is_held("archivist") else item.buy_price / 2


static func resurrect_cost_multiplier() -> float:
	return TEMPLE_ELDER_DISCOUNT if is_held("temple_elder") else 1.0


static func ash_success_chance() -> float:
	return TEMPLE_ELDER_ASH_SUCCESS if is_held("temple_elder") else 0.5


static func inn_cost_multiplier() -> float:
	return ALMONER_DISCOUNT if is_held("almoner") else 1.0
