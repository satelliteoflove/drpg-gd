class_name MicroEventSystem
extends RefCounted

const TRIGGER_CHANCE := 0.15
const FALLBACK_PATH := "res://data/fallback_lines.json"

static var _fallback_lines: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	var text := FileAccess.get_file_as_string(FALLBACK_PATH)
	if text == "":
		push_warning("[MicroEventSystem] Could not load %s" % FALLBACK_PATH)
		return

	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_fallback_lines = parsed as Dictionary
	else:
		push_warning("[MicroEventSystem] Failed to parse %s" % FALLBACK_PATH)


static func try_micro_event(context_type: String, party: Array[Character], callback: Callable) -> void:
	if randf() > TRIGGER_CHANCE:
		callback.call({})
		return

	var living: Array[Character] = []
	for c in party:
		if not c.is_dead:
			living.append(c)

	if living.is_empty():
		callback.call({})
		return

	var speaker := _pick_speaker(living)
	var situation := _situation_text(context_type)

	if LLMManager.is_available():
		var prompt := PromptBuilder.build_micro_prompt(speaker, situation)
		var grammar := PromptBuilder.micro_grammar()
		LLMManager.generate(prompt, grammar, func(content: String) -> void:
			var line := _parse_micro_response(content)
			if line != "":
				callback.call({"speaker": speaker, "line": line, "context": context_type})
			else:
				var fallback := _get_fallback(context_type, speaker)
				if fallback != "":
					callback.call({"speaker": speaker, "line": fallback, "context": context_type})
				else:
					callback.call({})
		)
	else:
		var fallback := _get_fallback(context_type, speaker)
		if fallback != "":
			callback.call({"speaker": speaker, "line": fallback, "context": context_type})
		else:
			callback.call({})


static func generate_response(speaker: Character, original_speaker: Character, original_line: String, context_type: String, callback: Callable) -> void:
	var situation := _situation_text(context_type)

	if LLMManager.is_available():
		var prompt := PromptBuilder.build_response_prompt(speaker, original_speaker, original_line, situation)
		var grammar := PromptBuilder.micro_grammar()
		LLMManager.generate(prompt, grammar, func(content: String) -> void:
			var line := _parse_micro_response(content)
			if line != "":
				callback.call(line)
			else:
				callback.call(_get_fallback(context_type, speaker))
		)
	else:
		callback.call(_get_fallback(context_type, speaker))


static func _pick_speaker(party: Array[Character]) -> Character:
	var min_spotlight := 999
	for c in party:
		var count: int = EventManager._spotlight_counts.get(c.id, 0)
		if count < min_spotlight:
			min_spotlight = count

	var candidates: Array[Character] = []
	for c in party:
		var count: int = EventManager._spotlight_counts.get(c.id, 0)
		if count <= min_spotlight + 1:
			candidates.append(c)

	return candidates[randi() % candidates.size()]


static func _parse_micro_response(content: String) -> String:
	if content == "":
		return ""
	var parsed: Variant = JSON.parse_string(content)
	if parsed is Dictionary:
		var line: String = (parsed as Dictionary).get("line", "")
		if line.length() >= 3 and line.length() <= 80:
			return line
	return ""


static func _get_fallback(context_type: String, speaker: Character) -> String:
	_ensure_loaded()

	var context_lines: Dictionary = _fallback_lines.get(context_type, {})
	if context_lines.is_empty():
		return ""

	var dominant_trait := _get_dominant_trait(speaker)
	var lines: Array = context_lines.get(dominant_trait, [])
	if lines.is_empty():
		lines = context_lines.get("default", [])
	if lines.is_empty():
		return ""

	return lines[randi() % lines.size()]


static func _get_dominant_trait(character: Character) -> String:
	for axis: int in [Personality.Axis.TEMPERAMENT, Personality.Axis.SOCIAL]:
		if character.traits.has(axis):
			return Personality.get_option_name(axis as Personality.Axis, character.traits[axis]).to_lower()
	return "default"


static func _situation_text(context_type: String) -> String:
	match context_type:
		"combat_victory": return "The party just won a battle."
		"combat_close_call": return "The party barely survived a fight."
		"floor_descent": return "The party descends deeper into the dungeon."
		"exploration": return "The party is exploring the dungeon corridors."
		"treasure_found": return "The party found treasure."
		"trap_triggered": return "Someone triggered a trap."
		"rest": return "The party is resting."
	return "The party is in the dungeon."
