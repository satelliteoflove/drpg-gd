class_name MicroEventSystem
extends RefCounted

const TRIGGER_CHANCE := 0.15
const FALLBACK_PATH := "res://data/fallback_lines.json"

static var _fallback_lines: Dictionary = {}
static var _loaded := false
static var recent_responders: Array[String] = []
static var recent_lines: Array[String] = []
static var _recent_fallback_lines: Array[String] = []

const MAX_RECENT_RESPONDERS := 3
const MAX_RECENT_LINES := 4
const MAX_RECENT_FALLBACKS := 6

const PURPOSES: Array[String] = [
	"Make it an observation about their surroundings.",
	"Make it a question to the group.",
	"Make it a complaint or grumble.",
	"Make it something about how they're feeling.",
	"Make it something encouraging or rallying.",
	"Make it a memory or reference to the past.",
	"Make it a joke or wry comment.",
	"Make it a warning or concern.",
]


static func record_responder(char_id: String) -> void:
	recent_responders.append(char_id)
	while recent_responders.size() > MAX_RECENT_RESPONDERS:
		recent_responders.pop_front()


static func record_line(line: String) -> void:
	var short := line.substr(0, 40) if line.length() > 40 else line
	recent_lines.append(short)
	while recent_lines.size() > MAX_RECENT_LINES:
		recent_lines.pop_front()


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


static func force_micro_conversation(context_type: String, party: Array[Character], callback: Callable, context: Dictionary = {}) -> void:
	_do_micro_conversation(context_type, party, callback, context)


static func try_micro_conversation(context_type: String, party: Array[Character], callback: Callable, context: Dictionary = {}) -> void:
	if randf() > TRIGGER_CHANCE:
		callback.call({})
		return
	_do_micro_conversation(context_type, party, callback, context)


static func _do_micro_conversation(context_type: String, party: Array[Character], callback: Callable, context: Dictionary) -> void:
	var living: Array[Character] = []
	for c in party:
		if not c.is_dead:
			living.append(c)

	if living.size() < 2:
		var speaker := living[0] if not living.is_empty() else null
		if speaker:
			_try_solo_event(context_type, speaker, callback, context)
		else:
			callback.call({})
		return

	var speaker := _pick_speaker(living)
	var responder := _pick_responder(living, speaker)
	if not responder:
		_try_solo_event(context_type, speaker, callback, context)
		return

	var situation := _build_situation(context_type, context)
	var purpose := _pick_purpose(context_type)

	if LLMManager.is_available():
		var prompt := PromptBuilder.build_micro_conversation_prompt(
			speaker, responder, situation, recent_lines.duplicate(), purpose
		)
		var grammar := PromptBuilder.micro_conversation_grammar()
		LLMManager.generate(prompt, grammar, func(content: String) -> void:
			var result := _parse_conversation_response(content, speaker, responder)
			if not result.is_empty():
				record_line(result.speaker_line)
				record_line(result.responder_line)
				record_responder(responder.id)
				callback.call(result)
			else:
				var fallback := _build_fallback_conversation(context_type, speaker, responder)
				callback.call(fallback)
		)
	else:
		var fallback := _build_fallback_conversation(context_type, speaker, responder)
		callback.call(fallback)


static func _try_solo_event(context_type: String, speaker: Character, callback: Callable, context: Dictionary) -> void:
	var situation := _build_situation(context_type, context)
	var purpose := _pick_purpose(context_type)

	if LLMManager.is_available():
		var prompt := PromptBuilder.build_micro_solo_prompt(
			speaker, situation, recent_lines.duplicate(), purpose
		)
		var grammar := PromptBuilder.micro_grammar()
		LLMManager.generate(prompt, grammar, func(content: String) -> void:
			var line := _parse_micro_response(content)
			if line != "":
				record_line(line)
				callback.call({
					"speaker": speaker, "speaker_line": line,
					"responder": null, "responder_line": "",
					"context": context_type,
				})
			else:
				var fallback := _get_fallback(context_type, speaker)
				if fallback != "":
					record_line(fallback)
					callback.call({
						"speaker": speaker, "speaker_line": fallback,
						"responder": null, "responder_line": "",
						"context": context_type,
					})
				else:
					callback.call({})
		)
	else:
		var fallback := _get_fallback(context_type, speaker)
		if fallback != "":
			record_line(fallback)
			callback.call({
				"speaker": speaker, "speaker_line": fallback,
				"responder": null, "responder_line": "",
				"context": context_type,
			})
		else:
			callback.call({})


static func try_micro_event(context_type: String, party: Array[Character], callback: Callable) -> void:
	try_micro_conversation(context_type, party, func(data: Dictionary) -> void:
		if data.is_empty():
			callback.call({})
			return
		callback.call({
			"speaker": data.speaker,
			"line": data.speaker_line,
			"context": data.get("context", context_type),
		})
	)


static func generate_response(speaker: Character, original_speaker: Character, original_line: String, context_type: String, callback: Callable) -> void:
	var situation := _build_situation(context_type, {})

	if LLMManager.is_available():
		var prompt := PromptBuilder.build_micro_solo_prompt(speaker, situation, recent_lines.duplicate())
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


static func _pick_responder(living: Array[Character], speaker: Character) -> Character:
	var candidates: Array[Character] = []
	for c in living:
		if c.id != speaker.id:
			candidates.append(c)
	if candidates.is_empty():
		return null
	var preferred: Array[Character] = []
	for c in candidates:
		if c.id not in recent_responders:
			preferred.append(c)
	if preferred.is_empty():
		preferred = candidates
	return preferred[randi() % preferred.size()]


static func _pick_purpose(context_type: String) -> String:
	if context_type in ["ally_fallen", "combat_close_call"]:
		return ""
	return PURPOSES[randi() % PURPOSES.size()]


static func _build_situation(context_type: String, context: Dictionary) -> String:
	var floor_num: int = context.get("floor", 0)
	var hp_state: String = context.get("party_hp_state", "")
	var dead_names: Array = context.get("dead_names", [])
	var returning: bool = context.get("returning_from_combat", false)

	var base := _situation_base(context_type)

	var parts: PackedStringArray = []
	if floor_num > 0:
		if floor_num >= 6:
			parts.append("Deep on floor %d" % floor_num)
		else:
			parts.append("On floor %d" % floor_num)

	if returning and context_type == "exploration":
		parts.append("after a recent battle")

	if not dead_names.is_empty():
		parts.append("without %s" % dead_names[0])

	var situation := ""
	if not parts.is_empty():
		situation = ", ".join(parts) + ". "

	situation += base

	if hp_state == "critical":
		situation += " The party is badly hurt."
	elif hp_state == "wounded":
		situation += " The party is worn down."

	return situation


static func _situation_base(context_type: String) -> String:
	match context_type:
		"combat_victory": return "The party just won a battle."
		"combat_close_call": return "The party barely survived a fight."
		"floor_descent": return "The party descends deeper into the dungeon."
		"exploration": return "The party is exploring the dungeon."
		"treasure_found": return "The party found treasure."
		"trap_triggered": return "Someone triggered a trap."
		"ally_fallen": return "An ally has fallen."
		"rest": return "The party is resting."
	return "The party is in the dungeon."


static func _parse_conversation_response(content: String, speaker: Character, responder: Character) -> Dictionary:
	if content == "":
		return {}
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Array:
		return {}
	var arr: Array = parsed as Array
	if arr.size() < 2:
		return {}

	var speaker_line := ""
	var responder_line := ""
	for entry: Variant in arr:
		if not entry is Dictionary:
			return {}
		var d: Dictionary = entry as Dictionary
		var line: String = d.get("line", "")
		if line.length() < 3 or line.length() > 120:
			return {}
		if speaker_line == "":
			speaker_line = line
		elif responder_line == "":
			responder_line = line

	if speaker_line == "" or responder_line == "":
		return {}

	return {
		"speaker": speaker, "speaker_line": speaker_line,
		"responder": responder, "responder_line": responder_line,
		"context": "",
	}


static func _parse_micro_response(content: String) -> String:
	if content == "":
		return ""
	var parsed: Variant = JSON.parse_string(content)
	if parsed is Dictionary:
		var line: String = (parsed as Dictionary).get("line", "")
		if line.length() >= 3 and line.length() <= 120:
			return line
	return ""


static func _build_fallback_conversation(context_type: String, speaker: Character, responder: Character) -> Dictionary:
	var speaker_line := _get_fallback(context_type, speaker)
	var responder_line := _get_fallback(context_type, responder)
	if speaker_line == "":
		return {}
	record_line(speaker_line)
	if responder_line != "":
		record_line(responder_line)
		record_responder(responder.id)
	return {
		"speaker": speaker, "speaker_line": speaker_line,
		"responder": responder if responder_line != "" else null,
		"responder_line": responder_line,
		"context": context_type,
	}


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

	var available: Array = []
	for line: String in lines:
		if line not in _recent_fallback_lines:
			available.append(line)
	if available.is_empty():
		available = lines as Array

	var chosen: String = available[randi() % available.size()]
	_recent_fallback_lines.append(chosen)
	while _recent_fallback_lines.size() > MAX_RECENT_FALLBACKS:
		_recent_fallback_lines.pop_front()
	return chosen


static func _get_dominant_trait(character: Character) -> String:
	for axis: int in [Personality.Axis.TEMPERAMENT, Personality.Axis.SOCIAL, Personality.Axis.OUTLOOK, Personality.Axis.VALUES]:
		if character.traits.has(axis):
			return Personality.get_option_name(axis as Personality.Axis, character.traits[axis]).to_lower().replace("-", "_")
	return "default"


static func _situation_text(context_type: String) -> String:
	return _situation_base(context_type)
