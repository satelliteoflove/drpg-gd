class_name PromptBuilder
extends RefCounted

const SYSTEM_PREFIX := "<|im_start|>system\nYou write short, punchy in-character dialogue for a dungeon crawler RPG. Stay in character. No narration, no actions, no stage directions. Just the spoken line. Each character has a distinct voice shaped by their personality and history.<|im_end|>\n"

const MAX_MARKS_IN_PROMPT := 3
const MAX_RELATIONSHIPS_IN_PROMPT := 2


static func build_micro_prompt(speaker: Character, situation: String) -> String:
	var char_desc := _describe_character_full(speaker)
	return SYSTEM_PREFIX + "<|im_start|>user\n%s\nSituation: %s\nWrite a single short spoken line (5-15 words) as this character. Their history and personality should color what they say. Respond with JSON: {\"line\": \"...\"}<|im_end|>\n<|im_start|>assistant\n" % [char_desc, situation]


static func build_response_prompt(speaker: Character, original_speaker: Character, original_line: String, situation: String) -> String:
	var char_desc := _describe_character_full(speaker)
	var orig_name := original_speaker.character_name
	var rel_line := _describe_relationship_between(speaker, original_speaker)
	var rel_ctx := ""
	if rel_line != "":
		rel_ctx = "\nRelationship: %s" % rel_line
	return SYSTEM_PREFIX + "<|im_start|>user\n%s%s\nSituation: %s\n%s just said: \"%s\"\nWrite a short reply (5-15 words) as this character. Respond with JSON: {\"line\": \"...\"}<|im_end|>\n<|im_start|>assistant\n" % [char_desc, rel_ctx, situation, orig_name, original_line]


static func build_event_prompt(template: Dictionary, cast: Dictionary, context: Dictionary) -> String:
	var llm_ctx: Dictionary = template.get("llm_context", {})
	var mood: String = llm_ctx.get("scene_mood", "")
	var slot_guidance: Array = llm_ctx.get("slot_guidance", [])

	var cast_lines := ""
	for idx: int in cast.keys():
		var character: Character = cast[idx]
		cast_lines += "Slot %d - %s\n" % [idx, _describe_character_full(character)]
		var rel_lines := _describe_relationships_with_cast(character, cast, idx)
		if rel_lines != "":
			cast_lines += "  Relationships: %s\n" % rel_lines
		for guide: Dictionary in slot_guidance:
			if int(guide.get("slot_index", -1)) == idx:
				cast_lines += "  Direction: %s\n" % guide.get("tone", "")

	var setup: String = template.get("setup_text", "")
	var num_slots := cast.size()

	return SYSTEM_PREFIX + "<|im_start|>user\nScene mood: %s\n%s\nSetup: %s\nWrite %d-4 short dialogue lines between these characters. Their history and relationships should shape what they say and how they say it. Each line 5-15 words. Respond with a JSON array: [{\"slot\": 0, \"line\": \"...\"}, ...]<|im_end|>\n<|im_start|>assistant\n" % [mood, cast_lines, setup, num_slots]


static func micro_grammar() -> String:
	return _json_object_grammar(["line"])


static func event_grammar() -> String:
	return ""


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
		return "root ::= \"{\" ws \"\\\"\" \"%s\" \"\\\"\" ws \":\" ws \"\\\"\" [^\"]+ \"\\\"\" ws \"}\" ws\nws ::= [ \\t\\n]*\n" % keys[0]
	return ""
