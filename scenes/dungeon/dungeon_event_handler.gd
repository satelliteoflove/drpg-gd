class_name DungeonEventHandler
extends RefCounted

const EventModalScene = preload("res://scenes/events/event_modal.tscn")
const MicroEventScene = preload("res://scenes/events/micro_event_overlay.tscn")
const MICRO_EVENT_COOLDOWN_STEPS := 30

var dungeon
var _steps_since_micro_event := 0


func init(p_dungeon: Node3D) -> void:
	dungeon = p_dungeon


func show_floor_event(event_data: Dictionary, next_floor: int, descending: bool) -> void:
	dungeon.event_open = true
	var root: Control = EventModalScene.instantiate()
	dungeon.get_node("UI").add_child(root)
	var modal: PanelContainer = root.get_node("EventModal")

	var event_context := {
		"floor": GameState.current_floor,
		"day": GameState.game_day,
	}
	modal.setup(event_data.template, event_data.cast, event_context)
	modal.event_resolved.connect(_on_floor_event_resolved.bind(root, next_floor, descending))


func try_exploration_micro_event() -> void:
	_steps_since_micro_event += 1
	if _steps_since_micro_event < MICRO_EVENT_COOLDOWN_STEPS:
		return
	if dungeon.combat_open or dungeon.event_open:
		return
	var context := _build_micro_context()
	MicroEventSystem.try_micro_conversation("exploration", GameState.get_party_members(), func(data: Dictionary) -> void:
		if not data.is_empty() and not dungeon.combat_open:
			_steps_since_micro_event = 0
			_show_exploration_micro_event(data)
	, context)


func show_exploration_micro_event(data: Dictionary) -> void:
	_show_exploration_micro_event(data)


func show_micro_event(data: Dictionary, next_floor: int, descending: bool) -> void:
	dungeon.event_open = true
	var overlay: CanvasLayer = MicroEventScene.instantiate()
	dungeon.get_node("UI").add_child(overlay)
	overlay.setup(data, GameState.get_party_members())
	overlay.micro_event_closed.connect(func() -> void:
		dungeon.event_open = false
		if descending:
			print_debug("Descending to floor ", next_floor)
			SceneManager.go_to_dungeon(next_floor, true)
		else:
			print_debug("Ascending to floor ", next_floor)
			SceneManager.go_to_dungeon(next_floor, false)
	)


func on_party_member_died_in_dungeon(character: Resource) -> void:
	if dungeon.combat_open:
		return
	var context := _build_micro_context()
	context["dead_names"] = [character.character_name]
	MicroEventSystem.try_micro_conversation("ally_fallen", GameState.get_party_members(), func(data: Dictionary) -> void:
		if not data.is_empty():
			_show_exploration_micro_event(data)
	, context)


func show_narrative_event(event_result: Dictionary) -> void:
	var context := {
		"floor": GameState.current_floor,
		"day": GameState.game_day,
	}
	var modal: PanelContainer = preload("res://scenes/events/event_modal.tscn").instantiate()
	dungeon.add_child(modal)
	modal.setup(event_result.template, event_result.cast, context)
	modal.event_resolved.connect(func(_choice_id: String) -> void:
		modal.queue_free()
	)


func check_narrative_tile(tile: DungeonTile) -> void:
	var context_type := ""
	match tile.special:
		DungeonTile.SpecialType.SHRINE:
			context_type = "discovery_shrine"
		DungeonTile.SpecialType.INSCRIPTION:
			context_type = "discovery_inscription"

	var event_context := {
		"party": GameState.get_party_members(),
		"floor": GameState.current_floor,
		"day": GameState.game_day,
		"is_boss": false,
		"dead_count": _count_dead(),
	}
	var event_result := EventManager.check_for_event(context_type, event_context)
	if not event_result.is_empty():
		tile.special = DungeonTile.SpecialType.NONE
		dungeon._render_tile(tile.x, tile.y, tile)
		show_narrative_event(event_result)


func debug_force_micro_event() -> void:
	var context := _build_micro_context()
	MicroEventSystem.force_micro_conversation("exploration", GameState.get_party_members(), func(data: Dictionary) -> void:
		if not data.is_empty():
			_show_exploration_micro_event(data)
		else:
			print_debug("[Debug] No micro event content generated")
	, context)


func _on_floor_event_resolved(_choice_id: String, root: Control, next_floor: int, descending: bool) -> void:
	root.queue_free()
	dungeon.event_open = false
	if descending:
		print_debug("Descending to floor ", next_floor)
		SceneManager.go_to_dungeon(next_floor, true)
	else:
		print_debug("Ascending to floor ", next_floor)
		SceneManager.go_to_dungeon(next_floor, false)


func _show_exploration_micro_event(data: Dictionary) -> void:
	if not dungeon._chat_log:
		return
	var speaker: Character = data.speaker
	var speaker_line: String = data.speaker_line
	dungeon._chat_log.add_line(speaker.character_name, speaker_line)

	var responder: Character = data.get("responder")
	var responder_line: String = data.get("responder_line", "")
	if responder and responder_line != "":
		RelationshipManager.add_modifier(
			speaker.id, responder.id,
			"Shared a moment", 1, GameState.game_day
		)
		dungeon._chat_log.add_response(responder.character_name, responder_line)


func _build_micro_context() -> Dictionary:
	var dead_names: Array[String] = []
	for c in GameState.get_party_members():
		if c.is_dead:
			dead_names.append(c.character_name)
	return {
		"floor": GameState.current_floor,
		"party_hp_state": _get_party_hp_state(),
		"dead_names": dead_names,
		"returning_from_combat": GameState.returning_from_combat,
	}


func _get_party_hp_state() -> String:
	var total_ratio := 0.0
	var count := 0
	for c: Character in GameState.get_party_members():
		if c.is_dead:
			continue
		if c.max_hp > 0:
			total_ratio += float(c.current_hp) / float(c.max_hp)
		count += 1
	if count == 0:
		return "critical"
	var avg: float = total_ratio / float(count)
	if avg < 0.35:
		return "critical"
	elif avg < 0.7:
		return "wounded"
	return "healthy"


func _count_dead() -> int:
	var count := 0
	for c in GameState.get_party_members():
		if c.is_dead:
			count += 1
	return count
