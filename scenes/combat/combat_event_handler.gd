class_name CombatEventHandler
extends RefCounted

var combat = null


func init(p_combat: Control) -> void:
	combat = p_combat


func pregenerate_event_dialogue() -> void:
	if combat._pending_event.is_empty():
		return
	var template: Dictionary = combat._pending_event.get("template", {})
	var cast: Dictionary = combat._pending_event.get("cast", {})
	if not LLMManager.is_available() or not template.has("llm_context"):
		return
	var floor_num: int = GameState.current_floor if GameState.current_floor > 0 else 1
	var context := {"floor": floor_num, "day": GameState.game_day}
	var prompt := PromptBuilder.build_event_prompt(template, cast, context)
	var grammar := PromptBuilder.event_grammar()
	combat._dialogue_ready = false
	combat._dialogue_prefiring = true
	combat._pregenerated_dialogue = ""
	LLMManager.generate(prompt, grammar, func(content: String) -> void:
		combat._dialogue_prefiring = false
		if combat.event_modal:
			combat.event_modal.deliver_dialogue(content)
		else:
			combat._pregenerated_dialogue = content
			combat._dialogue_ready = true
	)


func show_event_modal(event_data: Dictionary) -> void:
	combat.get_node("MainLayout").visible = false

	var root: Control = combat.EventModalScene.instantiate()
	combat.add_child(root)
	combat.event_modal = root.get_node("EventModal")
	combat.event_modal.event_resolved.connect(on_event_resolved)

	var floor_num: int = GameState.current_floor if GameState.current_floor > 0 else 1
	var event_context := {
		"floor": floor_num,
		"day": GameState.game_day,
	}
	var cached: String = combat._pregenerated_dialogue if combat._dialogue_ready else ""
	var awaiting := combat._dialogue_prefiring and not combat._dialogue_ready
	combat._pregenerated_dialogue = ""
	combat._dialogue_ready = false
	combat.event_modal.setup(event_data.template, event_data.cast, event_context, cached, awaiting)


func on_event_resolved(_choice_id: String) -> void:
	cleanup_event_modal()
	combat._finish_exit_combat(true)


func cleanup_event_modal() -> void:
	if combat.event_modal:
		var root := combat.event_modal.get_parent().get_parent()
		root.queue_free()
		combat.event_modal = null


func show_micro_event(data: Dictionary) -> void:
	combat.get_node("MainLayout").visible = false
	var overlay: CanvasLayer = combat.MicroEventScene.instantiate()
	combat.add_child(overlay)
	overlay.setup(data, GameState.get_party_members())
	overlay.micro_event_closed.connect(func() -> void:
		combat.get_node("MainLayout").visible = true
		combat._finish_exit_combat(true)
	)
