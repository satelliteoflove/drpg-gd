class_name MarkSystem
extends RefCounted


static func add_ko_mark(character: Character) -> void:
	var floor_num: int = GameState.current_floor if GameState.current_floor > 0 else 1
	var day: int = GameState.game_day

	var mark_name := "Fell on Floor %d" % floor_num
	var mark := Marks.create_mark(
		mark_name,
		"Knocked out in combat",
		[Marks.THEME_KO, Marks.THEME_COMBAT] as Array[String],
		Marks.Agency.SUBJECT,
		Marks.Severity.MINOR,
		[character.character_name] as Array[String],
		day
	)
	character.add_mark(mark)

	var ko_count := character.count_marks_by_theme(Marks.THEME_KO)
	if ko_count >= Marks.KO_UPGRADE_THRESHOLD and not character.has_mark_named("Thrice-Dead"):
		var upgrade := Marks.create_mark(
			"Thrice-Dead",
			"Fell too many times",
			[Marks.THEME_KO, Marks.THEME_COMBAT] as Array[String],
			Marks.Agency.SUBJECT,
			Marks.Severity.MAJOR,
			[character.character_name] as Array[String],
			day
		)
		character.add_mark(upgrade)


static func evaluate_post_combat(
	party: Array[Character],
	enemies: Array[Monster],
	p_is_boss: bool,
	floor_num: int,
	game_day: int
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var dead_count := 0
	for c in party:
		if c.is_dead:
			dead_count += 1

	for character in party:
		if character.is_dead:
			continue

		var near_death := _check_near_death(character, floor_num, game_day)
		if not near_death.is_empty():
			results.append(near_death)

		if dead_count >= 2:
			var sole := _check_sole_survivor(character, dead_count, floor_num, game_day)
			if not sole.is_empty():
				results.append(sole)

	if p_is_boss:
		var boss_marks := _check_boss_kill(party, enemies, floor_num, game_day)
		results.append_array(boss_marks)

	return results


static func _check_near_death(character: Character, floor_num: int, game_day: int) -> Dictionary:
	if character.current_hp >= character.max_hp * 0.25:
		return {}

	var near_death_count := character.count_marks_by_theme(Marks.THEME_NEAR_DEATH)

	if near_death_count >= Marks.NEAR_DEATH_UPGRADE_THRESHOLD - 1 and not character.has_mark_named("Death-Defier"):
		return {
			"character": character,
			"mark": Marks.create_mark(
				"Death-Defier",
				"Survived near-death too many times to count",
				[Marks.THEME_NEAR_DEATH, Marks.THEME_TRIUMPH] as Array[String],
				Marks.Agency.ACTOR,
				Marks.Severity.MAJOR,
				[character.character_name] as Array[String],
				game_day
			)
		}

	return {
		"character": character,
		"mark": Marks.create_mark(
			"Brushed with death on Floor %d" % floor_num,
			"Survived combat with critical wounds",
			[Marks.THEME_NEAR_DEATH, Marks.THEME_COMBAT] as Array[String],
			Marks.Agency.ACTOR,
			Marks.Severity.MINOR,
			[character.character_name] as Array[String],
			game_day
		)
	}


static func _check_boss_kill(
	party: Array[Character],
	enemies: Array[Monster],
	floor_num: int,
	game_day: int
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var boss_name := ""
	for enemy in enemies:
		if enemy.is_boss and enemy.current_hp <= 0:
			boss_name = enemy.monster_name
			break

	if boss_name == "":
		return results

	for character in party:
		if character.is_dead:
			continue
		var mark_name := "Slayer of %s" % boss_name
		if character.has_mark_named(mark_name):
			continue
		results.append({
			"character": character,
			"mark": Marks.create_mark(
				mark_name,
				"Defeated %s on Floor %d" % [boss_name, floor_num],
				[Marks.THEME_TRIUMPH, Marks.THEME_COMBAT] as Array[String],
				Marks.Agency.ACTOR,
				Marks.Severity.MAJOR,
				[character.character_name] as Array[String],
				game_day
			)
		})

	return results


static func _check_sole_survivor(
	character: Character,
	dead_count: int,
	floor_num: int,
	game_day: int
) -> Dictionary:
	if dead_count < 2:
		return {}

	var mark_name := "Sole Survivor of Floor %d" % floor_num
	if character.has_mark_named(mark_name):
		return {}

	return {
		"character": character,
		"mark": Marks.create_mark(
			mark_name,
			"Last one standing after %d allies fell" % dead_count,
			[Marks.THEME_LOSS, Marks.THEME_COMBAT] as Array[String],
			Marks.Agency.WITNESS,
			Marks.Severity.MAJOR,
			[character.character_name] as Array[String],
			game_day
		)
	}
