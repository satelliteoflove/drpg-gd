class_name Marks
extends RefCounted

enum Agency { ACTOR, SUBJECT, WITNESS }
enum Severity { MINOR, MAJOR }

const THEME_COMBAT := "combat"
const THEME_LOSS := "loss"
const THEME_FEAR := "fear"
const THEME_TRIUMPH := "triumph"
const THEME_DEATH := "death"
const THEME_DISCOVERY := "discovery"
const THEME_NEAR_DEATH := "near_death"
const THEME_KO := "ko"

const NEAR_DEATH_UPGRADE_THRESHOLD := 3
const KO_UPGRADE_THRESHOLD := 3


static func create_mark(
	p_name: String,
	p_origin: String,
	p_theme_tags: Array[String],
	p_agency: Agency,
	p_severity: Severity,
	p_characters_involved: Array[String],
	p_created_at: int
) -> Dictionary:
	return {
		"name": p_name,
		"origin": p_origin,
		"theme_tags": p_theme_tags,
		"agency": p_agency,
		"severity": p_severity,
		"characters_involved": p_characters_involved,
		"mechanical_effect": null,
		"created_at": p_created_at
	}
