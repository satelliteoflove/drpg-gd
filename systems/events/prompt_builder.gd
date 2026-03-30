class_name PromptBuilder
extends RefCounted

const SYSTEM_MESSAGE := "You write casual, natural-sounding dialogue for RPG party members. They talk like real people — not fantasy novels. No thee/thou, no dramatic monologues, no narration or stage directions. Just the spoken line. Short, conversational, sometimes funny. Each character has a distinct voice shaped by their personality."

const MAX_MARKS_IN_PROMPT := 3
const MAX_RELATIONSHIPS_IN_PROMPT := 2

const VOICE_DIRECTION: Dictionary = {
	"Brave": "confident, doesn't overthink it",
	"Cautious": "nervous, second-guesses things",
	"Reckless": "cocky, thinks they're invincible",
	"Calculating": "always has an angle, thinks out loud",
	"Friendly": "genuinely nice, checks on people",
	"Gruff": "short sentences, hates small talk",
	"Sarcastic": "dry, says the opposite of what they mean",
	"Earnest": "honest to a fault, wears their heart on their sleeve",
	"Optimistic": "glass half full, annoyingly cheerful",
	"Pessimistic": "assumes the worst, complains",
	"Stoic": "unfazed, barely reacts",
	"Curious": "nosy, always poking at things",
	"Merciful": "soft-hearted, worries about everyone",
	"Ruthless": "pragmatic, uncomfortable to be around",
	"Principled": "has strong opinions about right and wrong",
	"Self-Interested": "always thinking about what's in it for them",
}


static func build_micro_conversation_prompt(speaker: Character, responder: Character, situation: String, recent_lines: Array[String] = [], purpose: String = "") -> Dictionary:
	var speaker_desc := _describe_character_with_voice(speaker)
	var responder_desc := _describe_character_with_voice(responder)
	var rel_line := _describe_relationship_between(speaker, responder)
	var rel_ctx := ""
	if rel_line != "":
		rel_ctx = "\nRelationship: %s." % rel_line
	var avoid := ""
	if not recent_lines.is_empty():
		avoid = "\nAvoid repeating: %s" % "; ".join(recent_lines)
	var direction := ""
	if purpose != "":
		direction = " " + purpose
	var user_msg := "Speaker: %s\nResponder: %s%s\nSituation: %s%s\nWrite two lines: first %s speaks (5-20 words), then %s replies to what they said (5-20 words).%s Respond with JSON array: [{\"name\": \"%s\", \"line\": \"...\"}, {\"name\": \"%s\", \"line\": \"...\"}]" % [speaker_desc, responder_desc, rel_ctx, situation, avoid, speaker.character_name, responder.character_name, direction, speaker.character_name, responder.character_name]
	return {"system": SYSTEM_MESSAGE, "user": user_msg}


static func build_micro_solo_prompt(speaker: Character, situation: String, recent_lines: Array[String] = [], purpose: String = "") -> Dictionary:
	var char_desc := _describe_character_with_voice(speaker)
	var avoid := ""
	if not recent_lines.is_empty():
		avoid = "\nAvoid repeating: %s" % "; ".join(recent_lines)
	var direction := ""
	if purpose != "":
		direction = " " + purpose
	var user_msg := "%s\nSituation: %s%s\nWrite one short spoken line (5-20 words).%s Respond with JSON: {\"line\": \"...\"}" % [char_desc, situation, avoid, direction]
	return {"system": SYSTEM_MESSAGE, "user": user_msg}


static func build_event_prompt(template: Dictionary, cast: Dictionary, context: Dictionary) -> Dictionary:
	var llm_ctx: Dictionary = template.get("llm_context", {})
	var mood: String = llm_ctx.get("scene_mood", "")
	var slot_guidance: Array = llm_ctx.get("slot_guidance", [])

	var cast_lines := ""
	for idx: int in cast.keys():
		var character: Character = cast[idx]
		cast_lines += "Slot %d - %s\n" % [idx, _describe_character_with_voice(character)]
		var rel_lines := _describe_relationships_with_cast(character, cast, idx)
		if rel_lines != "":
			cast_lines += "  Relationships: %s\n" % rel_lines
		for guide: Dictionary in slot_guidance:
			if int(guide.get("slot_index", -1)) == idx:
				cast_lines += "  Direction: %s\n" % guide.get("tone", "")

	var setup: String = template.get("setup_text", "")
	var num_slots := cast.size()

	var user_msg := "Scene mood: %s\n%s\nSetup: %s\nWrite %d-4 short dialogue lines between these characters. Their history and relationships should shape what they say and how they say it. Each line 5-15 words. Respond with a JSON array: [{\"slot\": 0, \"line\": \"...\"}, ...]" % [mood, cast_lines, setup, num_slots]
	return {"system": SYSTEM_MESSAGE, "user": user_msg}


static func micro_grammar() -> String:
	return _json_object_grammar(["line"])


static func micro_conversation_grammar() -> String:
	return ""


static func event_grammar() -> String:
	return ""


static func _describe_character_with_voice(character: Character) -> String:
	var parts: PackedStringArray = []
	parts.append(_describe_identity(character))

	var personality_and_voice := _describe_personality_with_voice(character)
	parts.append(personality_and_voice)

	var history := _describe_marks(character)
	if history != "":
		parts.append(history)

	var bonds := _describe_notable_bonds(character)
	if bonds != "":
		parts.append(bonds)

	return " ".join(parts)


static func _describe_character_full(character: Character) -> String:
	var parts: PackedStringArray = []
	parts.append(_describe_identity(character))
	parts.append(_describe_personality(character))

	var history := _describe_marks(character)
	if history != "":
		parts.append(history)

	var bonds := _describe_notable_bonds(character)
	if bonds != "":
		parts.append(bonds)

	return " ".join(parts)


static func _describe_identity(character: Character) -> String:
	var race_name: String = CharacterEnums.Race.keys()[character.race]
	race_name = race_name.capitalize()
	var class_name_str: String = CharacterEnums.CharacterClass.keys()[character.character_class]
	class_name_str = class_name_str.capitalize()
	return "%s, %s %s." % [character.character_name, race_name, class_name_str]


static func _describe_personality(character: Character) -> String:
	var crystallized: PackedStringArray = []
	for axis: int in character.traits.keys():
		var option: int = character.traits[axis]
		crystallized.append(Personality.get_option_name(axis as Personality.Axis, option))

	var tendencies_only: PackedStringArray = []
	for axis: int in character.tendencies.keys():
		if character.traits.has(axis):
			continue
		var option: int = character.tendencies[axis]
		var name := Personality.get_option_name(axis as Personality.Axis, option)
		var evidence_count := _get_evidence_count(character, axis, option)
		if evidence_count >= 3:
			tendencies_only.append("%s (strongly developing)" % name)
		elif evidence_count >= 1:
			tendencies_only.append("%s (developing)" % name)
		else:
			tendencies_only.append("%s (tendency)" % name)

	var all_parts: PackedStringArray = []
	all_parts.append_array(crystallized)
	all_parts.append_array(tendencies_only)

	if all_parts.is_empty():
		return "Personality: unremarkable."
	return "Personality: %s." % ", ".join(all_parts)


static func _describe_personality_with_voice(character: Character) -> String:
	var trait_names: PackedStringArray = []
	var voice_parts: PackedStringArray = []

	for axis: int in character.traits.keys():
		var option: int = character.traits[axis]
		var name := Personality.get_option_name(axis as Personality.Axis, option)
		trait_names.append(name)
		var direction: String = VOICE_DIRECTION.get(name, "")
		if direction != "":
			voice_parts.append(direction)

	for axis: int in character.tendencies.keys():
		if character.traits.has(axis):
			continue
		var option: int = character.tendencies[axis]
		var name := Personality.get_option_name(axis as Personality.Axis, option)
		var evidence_count := _get_evidence_count(character, axis, option)
		if evidence_count >= 3:
			trait_names.append("%s (strongly developing)" % name)
		elif evidence_count >= 1:
			trait_names.append("%s (developing)" % name)
		else:
			trait_names.append("%s (tendency)" % name)
		if voice_parts.size() < 3:
			var direction: String = VOICE_DIRECTION.get(name, "")
			if direction != "":
				voice_parts.append(direction)

	var result := ""
	if trait_names.is_empty():
		result = "Personality: unremarkable."
	else:
		result = "Personality: %s." % ", ".join(trait_names)

	if not voice_parts.is_empty():
		result += " Voice: %s." % "; ".join(voice_parts)

	return result


static func _describe_marks(character: Character) -> String:
	if character.marks.is_empty():
		return "No notable history yet."

	var sorted_marks := character.marks.duplicate()
	sorted_marks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("created_at", 0)) > int(b.get("created_at", 0))
	)

	var lines: PackedStringArray = []
	var count := 0
	for mark: Dictionary in sorted_marks:
		if count >= MAX_MARKS_IN_PROMPT:
			break
		var name: String = mark.get("name", "")
		var origin: String = mark.get("origin", "")
		var agency: int = mark.get("agency", 0)
		var agency_word := "Did"
		if agency == 1:
			agency_word = "Experienced"
		elif agency == 2:
			agency_word = "Witnessed"
		if origin != "":
			lines.append("%s: %s" % [agency_word, origin])
		elif name != "":
			lines.append(name)
		count += 1

	var remaining := character.marks.size() - count
	var prefix := "History: %s." % "; ".join(lines)
	if remaining > 0:
		prefix += " (%d more experiences.)" % remaining
	return prefix


static func _describe_notable_bonds(character: Character) -> String:
	var rels := RelationshipManager.get_relationships_for(character.id)
	if rels.is_empty():
		return ""

	rels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return abs(int(a.get("weight", 0))) > abs(int(b.get("weight", 0)))
	)

	var lines: PackedStringArray = []
	var count := 0
	for rel: Dictionary in rels:
		if count >= MAX_RELATIONSHIPS_IN_PROMPT:
			break
		var other := GameState.roster.get_character(rel.other_id)
		if not other:
			continue
		var tier: int = rel.tier
		var tier_name := Relationships.get_tier_name(tier as Relationships.BondTier)
		if tier == Relationships.BondTier.NEUTRAL:
			continue
		lines.append("%s with %s" % [tier_name, other.character_name])
		count += 1

	if lines.is_empty():
		return ""
	return "Bonds: %s." % ", ".join(lines)


static func _describe_relationship_between(a: Character, b: Character) -> String:
	var weight := RelationshipManager.get_total_weight(a.id, b.id)
	if weight == 0:
		return ""
	var tier := RelationshipManager.get_tier(a.id, b.id)
	var tier_name := Relationships.get_tier_name(tier)
	if tier == Relationships.BondTier.NEUTRAL:
		if weight > 0:
			return "Slight familiarity with %s" % b.character_name
		return ""
	return "%s with %s" % [tier_name, b.character_name]


static func _describe_relationships_with_cast(character: Character, cast: Dictionary, own_idx: int) -> String:
	var lines: PackedStringArray = []
	for idx: int in cast.keys():
		if idx == own_idx:
			continue
		var other: Character = cast[idx]
		var desc := _describe_relationship_between(character, other)
		if desc != "":
			lines.append(desc)
	if lines.is_empty():
		return ""
	return ", ".join(lines)


static func _get_evidence_count(character: Character, axis: int, option: int) -> int:
	var axis_evidence: Dictionary = character.evidence.get(axis, {})
	return int(axis_evidence.get(option, 0))


static func _json_object_grammar(keys: Array[String]) -> String:
	if keys.size() == 1:
		return "root ::= \"{\" ws \"\\\"\" \"%s\" \"\\\"\" ws \":\" ws \"\\\"\" [^\"]+ \"\\\"\" ws \"}\" ws\nws ::= [ \\t]*\n" % keys[0]
	return ""
