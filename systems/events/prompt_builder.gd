class_name PromptBuilder
extends RefCounted

const SYSTEM_PREFIX := "<|im_start|>system\nYou write short, punchy in-character dialogue for a dungeon crawler RPG. Stay in character. No narration, no actions, no stage directions. Just the spoken line.<|im_end|>\n"


static func build_micro_prompt(speaker: Character, situation: String) -> String:
	var char_desc := _describe_character(speaker)
	return SYSTEM_PREFIX + "<|im_start|>user\n%s\nSituation: %s\nWrite a single short spoken line (5-15 words) as this character. Respond with JSON: {\"line\": \"...\"}<|im_end|>\n<|im_start|>assistant\n" % [char_desc, situation]


static func build_response_prompt(speaker: Character, original_speaker: Character, original_line: String, situation: String) -> String:
	var char_desc := _describe_character(speaker)
	var orig_name := original_speaker.character_name
	return SYSTEM_PREFIX + "<|im_start|>user\n%s\nSituation: %s\n%s just said: \"%s\"\nWrite a short reply (5-15 words) as this character. Respond with JSON: {\"line\": \"...\"}<|im_end|>\n<|im_start|>assistant\n" % [char_desc, situation, orig_name, original_line]


static func build_event_prompt(template: Dictionary, cast: Dictionary, context: Dictionary) -> String:
	var llm_ctx: Dictionary = template.get("llm_context", {})
	var mood: String = llm_ctx.get("scene_mood", "")
	var slot_guidance: Array = llm_ctx.get("slot_guidance", [])

	var cast_lines := ""
	for idx: int in cast.keys():
		var character: Character = cast[idx]
		cast_lines += "Slot %d - %s\n" % [idx, _describe_character(character)]
		for guide: Dictionary in slot_guidance:
			if int(guide.get("slot_index", -1)) == idx:
				cast_lines += "  Direction: %s\n" % guide.get("tone", "")

	var setup: String = template.get("setup_text", "")
	var num_slots := cast.size()

	return SYSTEM_PREFIX + "<|im_start|>user\nScene mood: %s\n%s\nSetup: %s\nWrite %d-4 short dialogue lines between these characters. Each line 5-15 words. Respond with a JSON array: [{\"slot\": 0, \"line\": \"...\"}, ...]<|im_end|>\n<|im_start|>assistant\n" % [mood, cast_lines, setup, num_slots]


static func micro_grammar() -> String:
	return _json_object_grammar(["line"])


static func event_grammar() -> String:
	return ""


static func _describe_character(character: Character) -> String:
	var race_name := CharacterEnums.Race.keys()[character.race].capitalize()
	var class_name_str := CharacterEnums.CharacterClass.keys()[character.character_class].capitalize()
	var trait_parts: PackedStringArray = []
	for axis: int in character.traits.keys():
		var option: int = character.traits[axis]
		trait_parts.append(Personality.get_option_name(axis as Personality.Axis, option))
	var traits_str := ", ".join(trait_parts) if not trait_parts.is_empty() else "unremarkable"
	return "%s, %s %s. Personality: %s." % [character.character_name, race_name, class_name_str, traits_str]


static func _json_object_grammar(keys: Array[String]) -> String:
	if keys.size() == 1:
		return "root ::= \"{\" ws \"\\\"\" \"%s\" \"\\\"\" ws \":\" ws \"\\\"\" [^\"]+ \"\\\"\" ws \"}\" ws\nws ::= [ \\t\\n]*\n" % keys[0]
	return ""
