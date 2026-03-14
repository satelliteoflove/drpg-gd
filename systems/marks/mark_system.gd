class_name MarkSystem
extends RefCounted


static func add_ko_mark(character: Character) -> void:
	var context := {
		"floor": GameState.current_floor if GameState.current_floor > 0 else 1,
		"day": GameState.game_day,
	}
	CombatTriggerEvaluator.evaluate_ko(character, context)


static func evaluate_post_combat(
	party: Array[Character],
	enemies: Array[Monster],
	p_is_boss: bool,
	floor_num: int,
	game_day: int,
	combat_log: Array[Dictionary] = []
) -> Array[Dictionary]:
	var context := {
		"party": party,
		"enemies": enemies,
		"is_boss": p_is_boss,
		"floor": floor_num,
		"day": game_day,
		"combat_log": combat_log,
	}
	return CombatTriggerEvaluator.evaluate_post_combat(context)


static func evaluate_relationships(
	party: Array[Character],
	enemies: Array[Monster],
	p_is_boss: bool,
	floor_num: int,
	combat_log: Array[Dictionary] = []
) -> Array[Dictionary]:
	var context := {
		"party": party,
		"enemies": enemies,
		"is_boss": p_is_boss,
		"floor": floor_num,
		"combat_log": combat_log,
	}
	return CombatTriggerEvaluator.evaluate_relationships(context)
