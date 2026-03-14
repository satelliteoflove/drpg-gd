class_name CombatTriggerEvaluator
extends RefCounted

static var _mark_triggers: Array = []
static var _relationship_triggers: Array = []
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_mark_triggers = _load_json("res://data/combat_triggers/mark_triggers.json")
	_relationship_triggers = _load_json("res://data/combat_triggers/relationship_triggers.json")
	_loaded = true


static func _load_json(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[CombatTriggerEvaluator] Failed to open: %s" % path)
		return []
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("[CombatTriggerEvaluator] JSON parse error in %s: %s" % [path, json.get_error_message()])
		return []
	return json.data


static func evaluate_post_combat(context: Dictionary) -> Array[Dictionary]:
	_ensure_loaded()
	var results: Array[Dictionary] = []
	var party: Array = context.get("party", [])
	var enemies: Array = context.get("enemies", [])
	var is_boss: bool = context.get("is_boss", false)
	var floor_num: int = context.get("floor", 1)
	var game_day: int = context.get("day", 1)
	var combat_log: Array = context.get("combat_log", [])

	var dead_count := 0
	for c: Character in party:
		if c.is_dead:
			dead_count += 1

	var boss_name := ""
	if is_boss:
		for enemy: Monster in enemies:
			if enemy.is_boss and enemy.current_hp <= 0:
				boss_name = enemy.monster_name
				break

	var vars := {
		"floor": str(floor_num),
		"dead_count": str(dead_count),
		"boss_name": boss_name,
	}

	for trigger_def: Dictionary in _mark_triggers:
		var trigger_type: String = trigger_def.get("trigger", "")

		if trigger_type == "on_ko":
			continue

		if trigger_type == "hp_below_pct":
			var threshold: float = trigger_def.get("threshold", 25) / 100.0
			for character: Character in party:
				if character.is_dead:
					continue
				if character.current_hp >= character.max_hp * threshold:
					continue
				var mark_result := _resolve_mark_with_upgrade(character, trigger_def, vars, game_day)
				if not mark_result.is_empty():
					results.append(mark_result)

		elif trigger_type == "allies_dead_gte":
			var threshold: int = trigger_def.get("threshold", 2)
			if dead_count < threshold:
				continue
			for character: Character in party:
				if character.is_dead:
					continue
				var mark_result := _resolve_mark(character, trigger_def, vars, game_day)
				if not mark_result.is_empty():
					results.append(mark_result)

		elif trigger_type == "boss_killed":
			if boss_name == "":
				continue
			for character: Character in party:
				if character.is_dead:
					continue
				var mark_result := _resolve_mark(character, trigger_def, vars, game_day)
				if not mark_result.is_empty():
					results.append(mark_result)

	return results


static func evaluate_ko(character: Character, context: Dictionary) -> void:
	_ensure_loaded()
	var floor_num: int = context.get("floor", 1)
	var game_day: int = context.get("day", 1)
	var vars := {"floor": str(floor_num)}

	for trigger_def: Dictionary in _mark_triggers:
		if trigger_def.get("trigger", "") != "on_ko":
			continue
		var mark_result := _resolve_mark_with_upgrade(character, trigger_def, vars, game_day)
		if not mark_result.is_empty():
			character.add_mark(mark_result.mark)


static func evaluate_relationships(context: Dictionary) -> Array[Dictionary]:
	_ensure_loaded()
	var results: Array[Dictionary] = []
	var party: Array = context.get("party", [])
	var enemies: Array = context.get("enemies", [])
	var is_boss: bool = context.get("is_boss", false)
	var floor_num: int = context.get("floor", 1)
	var combat_log: Array = context.get("combat_log", [])

	var boss_name := ""
	if is_boss:
		for enemy: Monster in enemies:
			if enemy.is_boss:
				boss_name = enemy.monster_name
				break

	var vars := {
		"floor": str(floor_num),
		"boss_name": boss_name,
	}

	var living_ids: Array[String] = []
	for c: Character in party:
		if not c.is_dead:
			living_ids.append(c.id)

	for trigger_def: Dictionary in _relationship_triggers:
		var trigger_type: String = trigger_def.get("trigger", "")
		var mod_def: Dictionary = trigger_def.get("modifier", {})
		var source: String = _substitute_vars(mod_def.get("source", ""), vars)
		var weight: int = mod_def.get("weight", 0)

		if trigger_type == "adjacent_survive":
			var min_enemies: int = trigger_def.get("min_enemies", 3)
			var enemy_count := 0
			for e: Monster in enemies:
				enemy_count += 1
			if enemy_count < min_enemies:
				continue
			for i in range(party.size()):
				if party[i].is_dead:
					continue
				for j in [i - 1, i + 1]:
					if j < 0 or j >= party.size():
						continue
					if party[j].is_dead:
						continue
					if j > i:
						results.append({"id_a": party[i].id, "id_b": party[j].id, "source": source, "weight": weight})

		elif trigger_type == "healed_below_pct":
			var threshold: float = trigger_def.get("threshold", 25) / 100.0
			for entry: Dictionary in combat_log:
				var healing: int = entry.get("healing", 0)
				if healing <= 0:
					continue
				var hp_before: int = entry.get("target_hp_before", 0)
				var max_hp: int = entry.get("target_max_hp", 1)
				if hp_before >= max_hp * threshold:
					continue
				var healer_id: String = entry.get("actor_id", "")
				var target_id: String = entry.get("target_id", "")
				if healer_id == "" or target_id == "" or healer_id == target_id:
					continue
				if not living_ids.has(healer_id) or not living_ids.has(target_id):
					continue
				results.append({"id_a": healer_id, "id_b": target_id, "source": source, "weight": weight})

		elif trigger_type == "revived":
			for entry: Dictionary in combat_log:
				var result_str: String = entry.get("result", "")
				if result_str != "revive":
					continue
				var reviver_id: String = entry.get("actor_id", "")
				var target_id: String = entry.get("target_id", "")
				if reviver_id == "" or target_id == "":
					continue
				results.append({"id_a": reviver_id, "id_b": target_id, "source": source, "weight": weight})

		elif trigger_type == "boss_survived":
			if not is_boss or boss_name == "":
				continue
			for i in range(living_ids.size()):
				for j in range(i + 1, living_ids.size()):
					results.append({"id_a": living_ids[i], "id_b": living_ids[j], "source": source, "weight": weight})

	return results


static func _resolve_mark(character: Character, trigger_def: Dictionary, vars: Dictionary, game_day: int) -> Dictionary:
	var mark_def: Dictionary = trigger_def.get("mark", {})
	var mark_name := _substitute_vars(mark_def.get("name", ""), vars)

	var unique: bool = trigger_def.get("unique_per_name", false)
	if unique and character.has_mark_named(mark_name):
		return {}

	var mark := _create_mark_from_def(mark_def, vars, character, game_day)
	return {"character": character, "mark": mark}


static func _resolve_mark_with_upgrade(character: Character, trigger_def: Dictionary, vars: Dictionary, game_day: int) -> Dictionary:
	var upgrade: Dictionary = trigger_def.get("upgrade", {})
	if not upgrade.is_empty():
		var count_theme: String = upgrade.get("count_theme", "")
		var count_threshold: int = upgrade.get("count_threshold", 3)
		var prevents_name: String = upgrade.get("prevents_name", "")

		var theme_count := character.count_marks_by_theme(count_theme)
		if theme_count >= count_threshold - 1 and not character.has_mark_named(prevents_name):
			var upgrade_mark := _create_mark_from_def(upgrade.get("mark", {}), vars, character, game_day)
			return {"character": character, "mark": upgrade_mark}

	return _resolve_mark(character, trigger_def, vars, game_day)


static func _create_mark_from_def(mark_def: Dictionary, vars: Dictionary, character: Character, game_day: int) -> Dictionary:
	var name_str := _substitute_vars(mark_def.get("name", ""), vars)
	var origin_str := _substitute_vars(mark_def.get("origin", ""), vars)

	var theme_tags: Array[String] = []
	for tag: String in mark_def.get("theme_tags", []):
		theme_tags.append(tag)

	var agency_str: String = mark_def.get("agency", "subject")
	var agency: Marks.Agency = Marks.Agency.SUBJECT
	match agency_str:
		"actor": agency = Marks.Agency.ACTOR
		"witness": agency = Marks.Agency.WITNESS

	var severity_str: String = mark_def.get("severity", "minor")
	var severity: Marks.Severity = Marks.Severity.MINOR
	if severity_str == "major":
		severity = Marks.Severity.MAJOR

	return Marks.create_mark(
		name_str, origin_str, theme_tags, agency, severity,
		[character.character_name] as Array[String], game_day
	)


static func _substitute_vars(template: String, vars: Dictionary) -> String:
	var result := template
	for key: String in vars.keys():
		result = result.replace("{%s}" % key, vars[key])
	return result
