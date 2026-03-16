class_name EventManagerClass
extends Node

var _templates: Array[Dictionary] = []
var _loaded := false
var _cooldowns: Dictionary = {}
var _spotlight_counts: Dictionary = {}
var _last_event_day: int = 0
var _event_history: Array[Dictionary] = []


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_templates.clear()

	var dir := DirAccess.open("res://data/events/")
	if dir == null:
		push_warning("[EventManager] Could not open res://data/events/")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var path := "res://data/events/" + file_name
			var json_text := FileAccess.get_file_as_string(path)
			if json_text != "":
				var parsed: Variant = JSON.parse_string(json_text)
				if parsed is Dictionary:
					_templates.append(parsed as Dictionary)
				else:
					push_warning("[EventManager] Failed to parse: " + path)
		file_name = dir.get_next()

	print("[EventManager] Loaded %d event templates" % _templates.size())


func check_for_event(context_type: String, context: Dictionary) -> Dictionary:
	_ensure_loaded()

	var day: int = context.get("day", 0)
	var eligible: Array[Dictionary] = []

	for template in _templates:
		var trigger: Dictionary = template.get("trigger", {})
		if trigger.get("context", "") != context_type:
			continue

		var conditions: Dictionary = trigger.get("conditions", {})
		if not _evaluate_conditions(conditions, context):
			continue

		var template_id: String = template.get("id", "")
		var cooldown_until: int = _cooldowns.get(template_id, 0)
		if day < cooldown_until:
			continue

		var min_days: int = conditions.get("min_days_since_last_event", 0)
		if _last_event_day > 0 and min_days > 0 and (day - _last_event_day) < min_days:
			continue

		var party: Array = context.get("party", [])
		var living: Array[Character] = []
		for c: Character in party:
			if not c.is_dead:
				living.append(c)

		var cast := _cast_slots(template, living)
		if cast.is_empty() and not template.get("slots", []).is_empty():
			continue

		eligible.append({"template": template, "cast": cast})

	if eligible.is_empty():
		return {}

	var total_weight := 0.0
	for entry in eligible:
		total_weight += float(entry.template.get("weight", 10))

	var roll := randf() * total_weight
	var cumulative := 0.0
	for entry in eligible:
		cumulative += float(entry.template.get("weight", 10))
		if roll <= cumulative:
			return entry

	return eligible[eligible.size() - 1]


func _evaluate_conditions(conditions: Dictionary, context: Dictionary) -> bool:
	var floor_num: int = context.get("floor", 1)
	var party: Array = context.get("party", [])
	var is_boss: bool = context.get("is_boss", false)
	var dead_count: int = context.get("dead_count", 0)

	var alive_count := 0
	for c: Character in party:
		if not c.is_dead:
			alive_count += 1

	if conditions.has("min_floor") and floor_num < int(conditions.min_floor):
		return false
	if conditions.has("max_floor") and floor_num > int(conditions.max_floor):
		return false
	if conditions.has("min_party_alive") and alive_count < int(conditions.min_party_alive):
		return false
	if conditions.has("requires_boss_kill") and bool(conditions.requires_boss_kill) and not is_boss:
		return false
	if conditions.has("requires_party_dead_count_gte") and dead_count < int(conditions.requires_party_dead_count_gte):
		return false

	return true


func _cast_slots(template: Dictionary, party: Array[Character]) -> Dictionary:
	var slots: Array = template.get("slots", [])
	var cast: Dictionary = {}
	var used_ids: Array[String] = []

	for slot_idx in range(slots.size()):
		var slot: Dictionary = slots[slot_idx]
		var best_score := -999.0
		var best_char: Character = null

		for character in party:
			if used_ids.has(character.id):
				continue

			var score := _score_character_for_slot(character, slot, cast)
			if score > best_score:
				best_score = score
				best_char = character

		if best_char != null:
			cast[slot_idx] = best_char
			used_ids.append(best_char.id)
		elif not slot.get("fallback_allowed", true):
			return {}

	return cast


func _score_character_for_slot(character: Character, slot: Dictionary, cast_so_far: Dictionary) -> float:
	var score := 0.0
	var reqs: Dictionary = slot.get("requirements", {})

	if reqs.has("trait_match") and reqs.trait_match != null:
		var trait_req: Dictionary = reqs.trait_match
		var axis := _parse_axis(trait_req.get("axis", ""))
		var option := _parse_option(axis, trait_req.get("option", ""))
		if axis >= 0 and option >= 0:
			if character.traits.has(axis) and character.traits[axis] == option:
				score += 10.0
			elif _has_tendency(character, axis, option):
				score += 5.0
			elif _has_crystallization_opportunity(character, axis, option):
				score += 4.0

	if reqs.has("mark_theme") and reqs.mark_theme != null:
		var theme: String = reqs.mark_theme
		for mark: Dictionary in character.marks:
			var tags: Array = mark.get("theme_tags", [])
			if tags.has(theme):
				score += 3.0
				break

	if reqs.has("min_marks"):
		var threshold: int = int(reqs.min_marks)
		if character.marks.size() >= threshold:
			score += 3.0
		else:
			score -= 10.0

	if reqs.has("max_marks"):
		var threshold: int = int(reqs.max_marks)
		if character.marks.size() <= threshold:
			score += 3.0
		else:
			score -= 10.0

	if reqs.has("exclude_mark_theme") and reqs.exclude_mark_theme != null:
		var theme: String = reqs.exclude_mark_theme
		for mark: Dictionary in character.marks:
			var tags: Array = mark.get("theme_tags", [])
			if tags.has(theme):
				score -= 100.0
				break

	if reqs.has("exclude_traits") and reqs.exclude_traits != null:
		var excluded: Array = reqs.exclude_traits
		for entry: Dictionary in excluded:
			var axis := _parse_axis(entry.get("axis", ""))
			var option := _parse_option(axis, entry.get("option", ""))
			if axis >= 0 and option >= 0:
				if character.traits.has(axis) and character.traits[axis] == option:
					score -= 100.0
				elif _has_tendency(character, axis, option):
					score -= 50.0

	if reqs.has("relationship_with_slot") and reqs.relationship_with_slot != null:
		var ref_slot: int = int(reqs.relationship_with_slot)
		if cast_so_far.has(ref_slot):
			var other: Character = cast_so_far[ref_slot]
			var tier := RelationshipManager.get_tier(character.id, other.id)
			if tier >= Relationships.BondTier.COMPANION:
				score += 3.0

	var spotlight: int = _spotlight_counts.get(character.id, 0)
	score -= spotlight * 2.0

	score += randf_range(0.0, 2.0)
	return score


func _has_tendency(character: Character, axis: Personality.Axis, option: int) -> bool:
	var tendencies: Dictionary = character.tendencies
	if not tendencies.has(axis):
		return false
	return int(tendencies[axis]) == option


func _has_crystallization_opportunity(character: Character, axis: Personality.Axis, option: int) -> bool:
	if character.traits.has(axis):
		return false
	var axis_evidence: Dictionary = character.evidence.get(axis, {})
	var current: int = axis_evidence.get(option, 0)
	return current >= 2


func apply_consequences(template: Dictionary, choice_id: String, cast: Dictionary, context: Dictionary) -> Array[Dictionary]:
	var summary: Array[Dictionary] = []
	var choices: Array = template.get("choices", [])
	var chosen: Dictionary = {}

	for c: Dictionary in choices:
		if c.get("id", "") == choice_id:
			chosen = c
			break

	if chosen.is_empty():
		return summary

	var consequences: Dictionary = chosen.get("consequences", {})
	var day: int = context.get("day", 1)

	var mark_defs: Array = consequences.get("marks", [])
	for mark_def: Dictionary in mark_defs:
		var slot_idx: int = int(mark_def.get("target_slot", 0))
		if not cast.has(slot_idx):
			continue
		var character: Character = cast[slot_idx]

		var mark_name: String = mark_def.get("name", "Unknown mark")
		mark_name = _substitute_vars(mark_name, cast, context)

		var origin: String = mark_def.get("origin", "")
		origin = _substitute_vars(origin, cast, context)

		var raw_tags: Array = mark_def.get("theme_tags", [])
		var theme_tags: Array[String] = []
		for t: String in raw_tags:
			theme_tags.append(t)

		var agency: Marks.Agency = Marks.Agency.ACTOR
		match mark_def.get("agency", "actor"):
			"subject": agency = Marks.Agency.SUBJECT
			"witness": agency = Marks.Agency.WITNESS

		var severity: Marks.Severity = Marks.Severity.MINOR
		if mark_def.get("severity", "minor") == "major":
			severity = Marks.Severity.MAJOR

		var involved: Array[String] = []
		for idx: int in cast.keys():
			involved.append((cast[idx] as Character).id)

		var mark := Marks.create_mark(mark_name, origin, theme_tags, agency, severity, involved, day)
		character.add_mark(mark)
		summary.append({"type": "mark", "name": character.character_name, "mark_name": mark_name})

	var rel_defs: Array = consequences.get("relationship_modifiers", [])
	for rel_def: Dictionary in rel_defs:
		var slot_a: int = int(rel_def.get("slot_a", 0))
		var slot_b: int = int(rel_def.get("slot_b", 1))
		if not cast.has(slot_a) or not cast.has(slot_b):
			continue
		var char_a: Character = cast[slot_a]
		var char_b: Character = cast[slot_b]
		var source: String = rel_def.get("source", "event")
		var weight: int = int(rel_def.get("weight", 0))
		RelationshipManager.add_modifier(char_a.id, char_b.id, source, weight, day)
		summary.append({
			"type": "relationship",
			"char_a": char_a.character_name,
			"char_b": char_b.character_name,
			"source": source,
			"weight": weight,
		})

	var evidence_defs: Array = consequences.get("evidence", [])
	for ev_def: Dictionary in evidence_defs:
		var slot_idx: int = int(ev_def.get("target_slot", 0))
		if not cast.has(slot_idx):
			continue
		var character: Character = cast[slot_idx]
		var axis := _parse_axis(ev_def.get("axis", ""))
		var option := _parse_option(axis, ev_def.get("option", ""))
		var amount: int = int(ev_def.get("amount", 1))

		if axis >= 0 and option >= 0:
			var crystallized := PersonalitySystem.add_evidence(character, axis as Personality.Axis, option, amount)
			var option_name: String = ev_def.get("option", "")
			summary.append({
				"type": "evidence",
				"name": character.character_name,
				"trait": option_name.to_lower().replace("_", " "),
				"axis": ev_def.get("axis", ""),
			})
			if crystallized:
				summary.append({
					"type": "crystallization",
					"name": character.character_name,
					"axis": ev_def.get("axis", ""),
					"trait": option_name.to_lower().replace("_", " "),
				})

	var template_id: String = template.get("id", "")
	var cooldown_days: int = int(template.get("cooldown_days", 10))
	_cooldowns[template_id] = day + cooldown_days
	_last_event_day = day

	for idx: int in cast.keys():
		var character: Character = cast[idx]
		_spotlight_counts[character.id] = _spotlight_counts.get(character.id, 0) + 1

	var slot_names: Dictionary = {}
	for idx: int in cast.keys():
		slot_names[idx] = (cast[idx] as Character).character_name

	_event_history.append({
		"template_id": template_id,
		"day": day,
		"slot_assignments": slot_names,
		"choice_id": choice_id,
	})

	return summary


func _substitute_vars(text: String, cast: Dictionary, context: Dictionary) -> String:
	for idx: int in cast.keys():
		var character: Character = cast[idx]
		text = text.replace("{slot_%d}" % idx, character.character_name)
	text = text.replace("{floor}", str(context.get("floor", 1)))
	text = text.replace("{day}", str(context.get("day", 1)))
	return text


func _parse_axis(axis_name: String) -> int:
	match axis_name.to_upper():
		"TEMPERAMENT": return Personality.Axis.TEMPERAMENT
		"SOCIAL": return Personality.Axis.SOCIAL
		"OUTLOOK": return Personality.Axis.OUTLOOK
		"VALUES": return Personality.Axis.VALUES
	return -1


func _parse_option(_axis: int, option_name: String) -> int:
	match option_name.to_upper():
		"BRAVE": return Personality.Temperament.BRAVE
		"CAUTIOUS": return Personality.Temperament.CAUTIOUS
		"RECKLESS": return Personality.Temperament.RECKLESS
		"CALCULATING": return Personality.Temperament.CALCULATING
		"FRIENDLY": return Personality.Social.FRIENDLY
		"GRUFF": return Personality.Social.GRUFF
		"SARCASTIC": return Personality.Social.SARCASTIC
		"EARNEST": return Personality.Social.EARNEST
		"OPTIMISTIC": return Personality.Outlook.OPTIMISTIC
		"PESSIMISTIC": return Personality.Outlook.PESSIMISTIC
		"STOIC": return Personality.Outlook.STOIC
		"CURIOUS": return Personality.Outlook.CURIOUS
		"MERCIFUL": return Personality.Values.MERCIFUL
		"RUTHLESS": return Personality.Values.RUTHLESS
		"PRINCIPLED": return Personality.Values.PRINCIPLED
		"SELF_INTERESTED": return Personality.Values.SELF_INTERESTED
	return -1


func get_save_state() -> Dictionary:
	return {
		"cooldowns": _cooldowns.duplicate(),
		"spotlight_counts": _spotlight_counts.duplicate(),
		"last_event_day": _last_event_day,
		"event_history": _event_history.duplicate(true),
	}


func load_save_state(state: Dictionary) -> void:
	_cooldowns = state.get("cooldowns", {}).duplicate()
	_spotlight_counts = state.get("spotlight_counts", {}).duplicate()
	_last_event_day = int(state.get("last_event_day", 0))
	var history: Array = state.get("event_history", [])
	_event_history.clear()
	for entry: Dictionary in history:
		_event_history.append(entry)


func clear() -> void:
	_cooldowns.clear()
	_spotlight_counts.clear()
	_last_event_day = 0
	_event_history.clear()
