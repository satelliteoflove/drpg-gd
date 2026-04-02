class_name CombatChestHandler
extends RefCounted

var combat = null


func init(p_combat: Control) -> void:
	combat = p_combat


func show_chest_modal() -> void:
	combat.current_chest = ChestSystem.create_chest_from_loot(combat.pending_loot, combat.is_boss_encounter)

	combat.chest_modal = combat.ChestModalScene.instantiate()
	combat.add_child(combat.chest_modal)
	combat.chest_modal.chest_resolved.connect(on_chest_resolved)
	combat.chest_modal.combat_triggered.connect(on_chest_combat_triggered)
	combat.chest_modal.setup(combat.current_chest, GameState.party)

	combat.modal_overlay.visible = true
	combat.chest_modal.visible = true


func show_forced_chest_modal() -> void:
	combat.chest_modal = combat.ChestModalScene.instantiate()
	combat.add_child(combat.chest_modal)
	combat.chest_modal.chest_resolved.connect(on_chest_resolved)
	combat.chest_modal.combat_triggered.connect(on_chest_combat_triggered)
	combat.chest_modal.setup(combat.current_chest, GameState.party)

	combat.modal_overlay.visible = true
	combat.chest_modal.visible = true


func on_chest_resolved(items: Array[Item], left_behind: bool) -> void:
	cleanup_chest_modal()

	if left_behind:
		combat.message_log.append_text("[color=yellow]You left the chest behind.[/color]\n")
	elif not items.is_empty():
		combat.message_log.append_text("[color=cyan]Items collected:[/color]\n")
		for item in items:
			combat.message_log.append_text("  - %s\n" % item.get_display_name())

	await combat.get_tree().create_timer(1.0).timeout
	if not combat.is_inside_tree(): return
	combat._exit_combat(true)


func on_chest_combat_triggered() -> void:
	cleanup_chest_modal()
	combat.message_log.append_text("[color=red]An alarm sounds! More enemies approach![/color]\n")

	await combat.get_tree().create_timer(1.0).timeout
	if not combat.is_inside_tree(): return

	var encounter_data := generate_alarm_encounter()
	GameState.current_encounter = encounter_data
	combat._start_combat()


func generate_alarm_encounter() -> Dictionary:
	var monsters: Array[Monster] = []

	var floor_num := GameState.current_floor if GameState.current_floor > 0 else 1
	var available_monsters := MonsterDatabase.get_monsters_for_floor(floor_num)

	var num_enemies := randi_range(2, 4)
	for i in range(num_enemies):
		if available_monsters.is_empty():
			break
		var monster_id: String = available_monsters[randi() % available_monsters.size()]
		var monster := MonsterDatabase.get_monster(monster_id)
		if monster:
			monster.grid_position = Vector2i(i % 3, i / 3)
			monsters.append(monster)

	return {
		"enemies": monsters,
		"is_boss": false,
		"is_alarm": true
	}


func cleanup_chest_modal() -> void:
	combat.modal_overlay.visible = false
	if combat.chest_modal:
		combat.chest_modal.queue_free()
		combat.chest_modal = null
	combat.current_chest = null
	combat.pending_loot.clear()
	combat.is_boss_encounter = false


func debug_win_with_ornate_chest() -> void:
	if not combat.combat_system:
		return
	combat.is_boss_encounter = true
	combat.message_log.append_text("[color=gray][DEBUG] Forcing ornate chest...[/color]\n")
	combat._debug_win_combat()


func debug_win_with_alarm_trap() -> void:
	if not combat.combat_system:
		return
	combat.message_log.append_text("[color=gray][DEBUG] Forcing alarm trap...[/color]\n")
	for enemy in combat.combat_system.get_enemies():
		enemy.current_hp = 0
		enemy.is_dead = true

	var alarm_trap := TrapDatabase.get_trap("alarm")
	var loot: Array[Item] = []
	var test_item := Item.new()
	test_item.id = "debug_item"
	test_item.item_name = "Debug Treasure"
	test_item.item_type = Item.ItemType.CONSUMABLE
	loot.append(test_item)

	combat.pending_loot = loot
	combat.is_boss_encounter = false
	combat.current_chest = Chest.create(Chest.ChestType.PLAIN, loot, alarm_trap)

	combat._set_actions_enabled(false)
	GameState.end_combat(true)
	GameState.party.distribute_experience(10)
	combat.display.show_victory_summary(10, 0, [], [])
	await combat.get_tree().create_timer(1.0).timeout
	if not combat.is_inside_tree(): return
	show_forced_chest_modal()


func debug_win_with_poison_trap() -> void:
	if not combat.combat_system:
		return
	combat.message_log.append_text("[color=gray][DEBUG] Forcing poison needle trap...[/color]\n")
	for enemy in combat.combat_system.get_enemies():
		enemy.current_hp = 0
		enemy.is_dead = true

	var poison_trap := TrapDatabase.get_trap("poison_needle")
	var loot: Array[Item] = []
	var test_item := Item.new()
	test_item.id = "debug_item"
	test_item.item_name = "Debug Treasure"
	test_item.item_type = Item.ItemType.CONSUMABLE
	loot.append(test_item)

	combat.pending_loot = loot
	combat.is_boss_encounter = false
	combat.current_chest = Chest.create(Chest.ChestType.PLAIN, loot, poison_trap)

	combat._set_actions_enabled(false)
	GameState.end_combat(true)
	GameState.party.distribute_experience(10)
	combat.display.show_victory_summary(10, 0, [], [])
	await combat.get_tree().create_timer(1.0).timeout
	if not combat.is_inside_tree(): return
	show_forced_chest_modal()
