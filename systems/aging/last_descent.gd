class_name LastDescent
extends RefCounted

## An Elder can swear One Last Descent at the guild hall. Until the next
## expedition ends they have their prime body back, +2 to every stat, and
## their Elder traits. When it ends they don't come home: they fall below or
## pass on at the top of the stairs, and either way become a Legend. Their
## apprentice, if they named one, rises to the Legend's full level.
## See docs/deep-time.md.

const STAT_BONUS := 2


static func can_declare(c: Character) -> bool:
	return AgeTraits.is_elder(c) and not c.is_dead and not GameState.is_away(c) and not c.last_descent \
		and not c.has_left_service() and not c.is_training() \
		and not c.has_status(CharacterEnums.StatusEffect.LOST)


## Swears [param c] to a last descent. The apprentice is trained when the
## descent ends, at whatever level the Legend has reached by then.
static func declare(c: Character, apprentice: Character) -> Array[String]:
	c.last_descent = true
	c.legacy_apprentice_id = apprentice.id if apprentice else ""
	c.advance_age(0)
	c.current_hp = c.max_hp
	c.current_mp = c.max_mp
	c.add_mark(Marks.create_mark("Swore one last descent", "last_descent",
		["legacy"] as Array[String], Marks.Agency.ACTOR, Marks.Severity.MAJOR,
		[] as Array[String], GameState.game_day))
	var lines: Array[String] = []
	lines.append("%s swears one last descent. The years fall away for now: prime strength back, and %d more to every stat besides." % [
		c.character_name, STAT_BONUS])
	lines.append("When the next expedition ends, %s won't come home. The guild will remember the name." % c.character_name)
	if apprentice:
		lines.append("%s will rise to %s's level when that day comes." % [
			apprentice.character_name, c.character_name])
	return lines


## Ends a last descent. Called on homecoming for each sworn member of the
## party, dead or alive. Returns the lines for the homecoming report.
static func pass_on(c: Character, party: Party) -> Array[String]:
	var fell := c.is_dead
	var lines: Array[String] = []
	if fell:
		lines.append("%s fell in the deep on that last descent, and the guild carried the body home." % c.character_name)
	else:
		lines.append("%s climbed the last stair, looked back down once, and was gone by morning." % c.character_name)

	var witnesses: Array[String] = []
	if party:
		for m in party.get_members():
			if m != c and not m.is_dead:
				witnesses.append(m.id)
				m.add_mark(Marks.create_mark("Went down with %s one last time" % c.character_name,
					"last_descent", ["legacy", "loss"] as Array[String], Marks.Agency.WITNESS,
					Marks.Severity.MAJOR, [c.id] as Array[String], GameState.game_day))
		if party.has_member(c):
			party.remove_member(c.id)

	c.last_descent = false
	c.town_job = -1
	c.availability = Character.AVAILABILITY_LEGEND
	c.end_service("legend", GameState.game_day)
	GameState.record("legend", "%s made a last descent at %d and %s. A Legend of the guild." % [
		c.character_name, c.get_age_years(),
		"fell in the deep" if fell else "passed on at the top of the stairs"])
	c.add_mark(Marks.create_mark("A Legend of the guild", "last_descent",
		["legacy"] as Array[String], Marks.Agency.ACTOR, Marks.Severity.MAJOR,
		witnesses, GameState.game_day))

	var apprentice := _apprentice_of(c)
	if apprentice:
		var old_level := apprentice.level
		var trained := Retirement.train_apprentice(c, apprentice, 0)
		trained[0] = "%s takes up where %s left off." % [apprentice.character_name, c.character_name]
		if apprentice.level > old_level:
			trained[0] += " Level %d → %d." % [old_level, apprentice.level]
		lines.append_array(trained)
	return lines


static func _apprentice_of(c: Character) -> Character:
	if c.legacy_apprentice_id.is_empty() or GameState.roster == null:
		return null
	var a := GameState.roster.get_character(c.legacy_apprentice_id)
	if a == null or a.has_left_service() or a.has_status(CharacterEnums.StatusEffect.LOST):
		return null
	return a


## The ending's paragraph for a Legend.
static func epitaph(c: Character) -> String:
	var text := ""
	var age_in := saga_age_in(c) / CharacterEnums.DAYS_PER_YEAR
	var age_out := saga_age_out(c) / CharacterEnums.DAYS_PER_YEAR
	text = "%s first went down the stairs at %d and made a last descent at %d." % [
		c.character_name, age_in, age_out]
	if c.first_descent_day >= 0 and c.final_day >= c.first_descent_day:
		var days := c.final_day - c.first_descent_day
		text += " On the surface, %d day%s had passed." % [days, "" if days == 1 else "s"]
	if c.is_dead:
		text += " %s fell in the deep and didn't come back up." % c.character_name
	else:
		text += " %s came back up the stairs one last time and passed on at the top." % c.character_name
	var apprentice := GameState.roster.get_character(c.legacy_apprentice_id) if not c.legacy_apprentice_id.is_empty() else null
	if apprentice:
		text += " %s, %s's apprentice, carries on." % [apprentice.character_name, c.character_name]
	return text


## Age on first going down. Older saves didn't record it, so fall back on
## subtracting the time spent below.
static func saga_age_in(c: Character) -> int:
	if c.first_descent_age_days >= 0:
		return c.first_descent_age_days
	return maxi(0, c.age_days - c.days_below)


static func saga_age_out(c: Character) -> int:
	return c.final_age_days if c.final_age_days >= 0 else c.age_days
