class_name CombatSpellHandler
extends RefCounted

var combat = null


func init(p_combat: Control) -> void:
	combat = p_combat


func on_spell_pressed() -> void:
	if not combat.combat_system or not combat.combat_system.is_player_turn():
		return

	var caster: Character = combat._get_character_by_id(combat.combat_system.current_combatant_id)
	if caster == null:
		return

	if caster.is_silenced():
		combat.message_log.append_text("[color=#aaaaaa]>[/color] %s is silenced and cannot cast spells!\n" % caster.get_display_name())
		return

	if caster.known_spells.is_empty():
		combat.message_log.append_text("[color=#aaaaaa]>[/color] %s doesn't know any spells.\n" % caster.get_display_name())
		return

	combat.available_spells = SpellValidator.get_spells_by_level(caster, true)

	var has_any_spells := false
	for level: int in combat.available_spells:
		if not combat.available_spells[level].is_empty():
			has_any_spells = true
			break

	if not has_any_spells:
		combat.message_log.append_text("[color=#aaaaaa]>[/color] %s has no combat spells available.\n" % caster.get_display_name())
		return

	combat.current_spell_level = _get_first_available_spell_level()
	_update_spell_level_buttons()
	_populate_spell_list_for_level(combat.current_spell_level)

	combat._close_all_modals()
	combat._set_actions_enabled(false)
	combat.modal_overlay.visible = true
	combat.spell_modal.visible = true

	if combat.spell_nav and not combat.spell_buttons.is_empty():
		combat.spell_nav.setup(combat.spell_buttons, 0)


func _get_first_available_spell_level() -> int:
	for level in range(1, 8):
		if combat.available_spells.has(level) and not combat.available_spells[level].is_empty():
			return level
	return 1


func _update_spell_level_buttons() -> void:
	for i in range(combat.spell_level_buttons.size()):
		var level := i + 1
		var btn: Button = combat.spell_level_buttons[i]
		btn.button_pressed = (level == combat.current_spell_level)

		var has_spells: bool = combat.available_spells.has(level) and not combat.available_spells[level].is_empty()
		btn.disabled = not has_spells
		btn.modulate = Color.WHITE if has_spells else UIColors.MODULATE_DISABLED


func on_spell_level_changed(level: int) -> void:
	if not combat.available_spells.has(level) or combat.available_spells[level].is_empty():
		_update_spell_level_buttons()
		return

	combat.current_spell_level = level
	_update_spell_level_buttons()
	_populate_spell_list_for_level(level)


func navigate_spell_level(direction: int) -> void:
	var new_level: int = combat.current_spell_level + direction

	while new_level >= 1 and new_level <= 7:
		if combat.available_spells.has(new_level) and not combat.available_spells[new_level].is_empty():
			on_spell_level_changed(new_level)
			return
		new_level += direction


func _populate_spell_list_for_level(level: int) -> void:
	for child: Node in combat.spell_list.get_children():
		child.queue_free()
	combat.spell_buttons.clear()

	var caster: Character = combat._get_character_by_id(combat.combat_system.current_combatant_id)
	if caster == null:
		return

	var spells: Array = combat.available_spells.get(level, [])

	for spell in spells:
		var btn := Button.new()
		var can_cast: bool = caster.current_mp >= spell.mp_cost
		var fizzle: int = int(SpellValidator.calculate_fizzle_chance(caster, spell))

		btn.text = "%s (%d MP) [%d%% fizzle]" % [spell.name, spell.mp_cost, fizzle]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)

		if not can_cast:
			btn.disabled = true
			btn.modulate = UIColors.MODULATE_DISABLED
			btn.text = "%s (%d MP) - Not enough MP" % [spell.name, spell.mp_cost]

		btn.pressed.connect(_on_spell_selected.bind(spell))
		combat.spell_list.add_child(btn)
		combat.spell_buttons.append(btn)

	combat.spell_nav = MenuNavigator.new()
	if not combat.spell_buttons.is_empty():
		var first_enabled := 0
		for i in range(combat.spell_buttons.size()):
			if not combat.spell_buttons[i].disabled:
				first_enabled = i
				break
		combat.spell_nav.setup(combat.spell_buttons, first_enabled)


func _on_spell_selected(spell: Spell) -> void:
	var caster: Character = combat._get_character_by_id(combat.combat_system.current_combatant_id)
	if caster == null or caster.current_mp < spell.mp_cost:
		return

	combat.selected_spell = spell
	combat.spell_modal.visible = false

	match spell.target_type:
		CharacterEnums.SpellTargetType.SELF:
			_cast_spell_on_targets([caster])
		CharacterEnums.SpellTargetType.SINGLE_ALLY:
			combat.spell_target_mode = "ally"
			_populate_spell_ally_target_list(false)
		CharacterEnums.SpellTargetType.SINGLE_ENEMY:
			combat.spell_target_mode = "enemy"
			_populate_spell_enemy_target_list()
		CharacterEnums.SpellTargetType.ALL_ALLIES:
			var targets: Array = combat.combat_system.get_valid_ally_targets(false)
			var typed_targets: Array = []
			for t in targets:
				typed_targets.append(t)
			_cast_spell_on_targets(typed_targets)
		CharacterEnums.SpellTargetType.ALL_ENEMIES:
			var targets: Array = combat.combat_system.get_living_enemies()
			var typed_targets: Array = []
			for t in targets:
				typed_targets.append(t)
			_cast_spell_on_targets(typed_targets)
		CharacterEnums.SpellTargetType.DEAD_ALLY:
			combat.spell_target_mode = "dead"
			_populate_spell_ally_target_list(true)
		CharacterEnums.SpellTargetType.SPLASH:
			combat.spell_target_mode = "splash"
			_populate_spell_splash_target_list()
		CharacterEnums.SpellTargetType.ROW:
			combat.spell_target_mode = "row"
			_populate_spell_row_target_list()
		CharacterEnums.SpellTargetType.COLUMN:
			combat.spell_target_mode = "column"
			_populate_spell_column_target_list()
		_:
			_cast_spell_on_targets([caster])


func _populate_spell_ally_target_list(dead_only: bool) -> void:
	var targets: Array[Character]
	if dead_only:
		targets = combat.combat_system.get_dead_allies()
	else:
		targets = combat.combat_system.get_valid_ally_targets(false)

	if targets.is_empty():
		var no_target_msg := "No valid targets available"
		if dead_only:
			no_target_msg = "No dead allies to resurrect"
		combat.message_log.append_text("[color=#aaaaaa]>[/color] %s\n" % no_target_msg)
		combat._close_all_modals()
		combat._set_actions_enabled(true)
		combat.selected_spell = null
		return

	# Pick the ally on the battlefield (same overlay flow as enemy targeting).
	combat.ally_target_mode = "spell"
	combat.targeting.populate_ally_targets(targets, _on_spell_ally_target_selected)


func _populate_spell_enemy_target_list() -> void:
	combat.modal_overlay.visible = false
	var enemies: Array = combat.combat_system.get_living_enemies()

	if enemies.is_empty():
		combat.message_log.append_text("[color=#aaaaaa]>[/color] No enemies to target!\n")
		combat._close_all_modals()
		combat._set_actions_enabled(true)
		combat.selected_spell = null
		return

	combat.targeting.clear_grid_target_buttons()
	combat.enemy_target_buttons.clear()

	var buttons_by_pos: Dictionary = {}
	for enemy in enemies:
		if not combat.enemy_panels.has(enemy.combat_id):
			continue
		var ui = combat.enemy_panels[enemy.combat_id]
		var cell: PanelContainer = ui.panel.get_parent()
		var btn: Button = combat.targeting.create_grid_overlay_button(cell)
		btn.pressed.connect(_on_spell_enemy_target_selected.bind(enemy))
		btn.focus_entered.connect(combat.targeting.highlight_enemy_target.bind(enemy))
		combat.enemy_target_buttons.append(btn)
		combat._grid_target_buttons.append(btn)
		buttons_by_pos[enemy.grid_position] = btn

	combat.enemy_target_nav = GridNavigator.new()
	if not combat.enemy_target_buttons.is_empty():
		combat.enemy_target_nav.setup(buttons_by_pos, 0)


func _on_spell_ally_target_selected(character: Character) -> void:
	combat.ally_target_mode = ""
	_cast_spell_on_targets([character])


func _on_spell_enemy_target_selected(enemy: Monster) -> void:
	if combat.spell_target_mode == "splash":
		var targets: Array = combat.combat_system.get_splash_targets(enemy)
		var typed_targets: Array = []
		for t in targets:
			typed_targets.append(t)
		_cast_spell_on_targets(typed_targets)
	else:
		_cast_spell_on_targets([enemy])


func _populate_spell_splash_target_list() -> void:
	combat.modal_overlay.visible = false
	var enemies: Array = combat.combat_system.get_living_enemies()

	if enemies.is_empty():
		combat.message_log.append_text("[color=#aaaaaa]>[/color] No enemies to target!\n")
		combat._close_all_modals()
		combat._set_actions_enabled(true)
		combat.selected_spell = null
		return

	combat.targeting.clear_grid_target_buttons()
	combat.enemy_target_buttons.clear()

	var buttons_by_pos: Dictionary = {}
	for enemy in enemies:
		if not combat.enemy_panels.has(enemy.combat_id):
			continue
		var ui = combat.enemy_panels[enemy.combat_id]
		var cell: PanelContainer = ui.panel.get_parent()
		var btn: Button = combat.targeting.create_grid_overlay_button(cell)
		var splash_targets: Array = combat.combat_system.get_splash_targets(enemy)
		btn.pressed.connect(_on_spell_enemy_target_selected.bind(enemy))
		btn.focus_entered.connect(combat.targeting.highlight_enemy_targets.bind(splash_targets, enemy))
		combat.enemy_target_buttons.append(btn)
		combat._grid_target_buttons.append(btn)
		buttons_by_pos[enemy.grid_position] = btn

	combat.enemy_target_nav = GridNavigator.new()
	if not combat.enemy_target_buttons.is_empty():
		combat.enemy_target_nav.setup(buttons_by_pos, 0)


func _populate_spell_row_target_list() -> void:
	combat.modal_overlay.visible = false
	var available_rows: Array = combat.combat_system.get_available_rows()

	if available_rows.is_empty():
		combat.message_log.append_text("[color=#aaaaaa]>[/color] No enemies to target!\n")
		combat._close_all_modals()
		combat._set_actions_enabled(true)
		combat.selected_spell = null
		return

	combat.targeting.clear_grid_target_buttons()
	combat.enemy_target_buttons.clear()

	var buttons_by_pos: Dictionary = {}
	for row in available_rows:
		var row_targets: Array = combat.combat_system.get_row_targets(row)
		if row_targets.is_empty():
			continue
		var first_enemy: Monster = row_targets[0]
		if not combat.enemy_panels.has(first_enemy.combat_id):
			continue
		var ui = combat.enemy_panels[first_enemy.combat_id]
		var cell: PanelContainer = ui.panel.get_parent()
		var btn: Button = combat.targeting.create_grid_overlay_button(cell)
		btn.pressed.connect(_on_spell_row_selected.bind(row))
		btn.focus_entered.connect(combat.targeting.highlight_enemy_targets.bind(row_targets))
		combat.enemy_target_buttons.append(btn)
		combat._grid_target_buttons.append(btn)
		buttons_by_pos[first_enemy.grid_position] = btn

	combat.enemy_target_nav = GridNavigator.new()
	if not combat.enemy_target_buttons.is_empty():
		combat.enemy_target_nav.setup(buttons_by_pos, 0)


func _on_spell_row_selected(row: int) -> void:
	var targets: Array = combat.combat_system.get_row_targets(row)
	var typed_targets: Array = []
	for t in targets:
		typed_targets.append(t)
	_cast_spell_on_targets(typed_targets)


func _populate_spell_column_target_list() -> void:
	combat.modal_overlay.visible = false
	var available_cols: Array = combat.combat_system.get_available_columns()

	if available_cols.is_empty():
		combat.message_log.append_text("[color=#aaaaaa]>[/color] No enemies to target!\n")
		combat._close_all_modals()
		combat._set_actions_enabled(true)
		combat.selected_spell = null
		return

	combat.targeting.clear_grid_target_buttons()
	combat.enemy_target_buttons.clear()

	var buttons_by_pos: Dictionary = {}
	for col in available_cols:
		var col_targets: Array = combat.combat_system.get_column_targets(col)
		if col_targets.is_empty():
			continue
		var first_enemy: Monster = col_targets[0]
		if not combat.enemy_panels.has(first_enemy.combat_id):
			continue
		var ui = combat.enemy_panels[first_enemy.combat_id]
		var cell: PanelContainer = ui.panel.get_parent()
		var btn: Button = combat.targeting.create_grid_overlay_button(cell)
		btn.pressed.connect(_on_spell_column_selected.bind(col))
		btn.focus_entered.connect(combat.targeting.highlight_enemy_targets.bind(col_targets))
		combat.enemy_target_buttons.append(btn)
		combat._grid_target_buttons.append(btn)
		buttons_by_pos[first_enemy.grid_position] = btn

	combat.enemy_target_nav = GridNavigator.new()
	if not combat.enemy_target_buttons.is_empty():
		combat.enemy_target_nav.setup(buttons_by_pos, 0)


func _on_spell_column_selected(col: int) -> void:
	var targets: Array = combat.combat_system.get_column_targets(col)
	var typed_targets: Array = []
	for t in targets:
		typed_targets.append(t)
	_cast_spell_on_targets(typed_targets)


func _cast_spell_on_targets(targets: Array) -> void:
	if combat.selected_spell == null:
		combat._close_all_modals()
		combat._set_actions_enabled(true)
		return

	combat._close_all_modals()
	combat.combat_system.player_cast_spell(combat.selected_spell.id, targets)
	combat.selected_spell = null
	combat.spell_target_mode = ""


func on_cancel_spell_ally_target() -> void:
	combat._close_all_modals()
	combat.spell_modal.visible = true
	combat.selected_spell = null
	combat.spell_target_mode = ""

	if combat.spell_nav and not combat.spell_buttons.is_empty():
		combat.spell_nav.setup(combat.spell_buttons, 0)


func on_cancel_spell() -> void:
	combat.selected_spell = null
	combat.spell_target_mode = ""
	combat._close_all_modals()
	combat._set_actions_enabled(true)


func on_dispel_pressed() -> void:
	if not combat.combat_system or not combat.combat_system.is_player_turn():
		return

	var character: Character = combat._get_character_by_id(combat.combat_system.current_combatant_id)
	if character == null or not DispelUndead.can_dispel(character):
		return

	var undead_targets := DispelUndead.get_valid_targets(combat.combat_system.get_living_enemies())
	if undead_targets.is_empty():
		combat.message_log.append_text("[color=#aaaaaa]>[/color] No undead to dispel.\n")
		return

	combat._close_all_modals()
	combat._set_actions_enabled(false)
	combat.targeting.clear_grid_target_buttons()
	combat.enemy_target_buttons.clear()

	var buttons_by_pos: Dictionary = {}
	for enemy in undead_targets:
		if not combat.enemy_panels.has(enemy.combat_id):
			continue
		var ui = combat.enemy_panels[enemy.combat_id]
		var cell: PanelContainer = ui.panel.get_parent()
		var btn: Button = combat.targeting.create_grid_overlay_button(cell)
		btn.pressed.connect(on_dispel_target_selected.bind(enemy))
		btn.focus_entered.connect(combat.targeting.highlight_enemy_target.bind(enemy))
		combat.enemy_target_buttons.append(btn)
		combat._grid_target_buttons.append(btn)
		buttons_by_pos[enemy.grid_position] = btn

	combat.enemy_target_nav = GridNavigator.new()
	if not combat.enemy_target_buttons.is_empty():
		combat.enemy_target_nav.setup(buttons_by_pos, 0)

	combat.dispel_target_mode = true


func on_dispel_target_selected(enemy: Monster) -> void:
	combat._close_all_modals()
	combat.dispel_target_mode = false
	combat.combat_system.player_dispel(enemy)


func on_breath_pressed() -> void:
	if not combat.combat_system or not combat.combat_system.is_player_turn():
		return

	var character: Character = combat._get_character_by_id(combat.combat_system.current_combatant_id)
	if character == null or not character.can_use_breath():
		return

	if character.is_breath_aoe():
		combat.combat_system.player_breath()
		return

	var living: Array = combat.combat_system.get_living_enemies()
	combat._close_all_modals()
	combat._set_actions_enabled(false)
	combat.targeting.clear_grid_target_buttons()
	combat.enemy_target_buttons.clear()

	var buttons_by_pos: Dictionary = {}
	for enemy in living:
		if not combat.enemy_panels.has(enemy.combat_id):
			continue
		var ui = combat.enemy_panels[enemy.combat_id]
		var cell: PanelContainer = ui.panel.get_parent()
		var btn: Button = combat.targeting.create_grid_overlay_button(cell)
		btn.pressed.connect(on_breath_target_selected.bind(enemy))
		btn.focus_entered.connect(combat.targeting.highlight_enemy_target.bind(enemy))
		combat.enemy_target_buttons.append(btn)
		combat._grid_target_buttons.append(btn)
		buttons_by_pos[enemy.grid_position] = btn

	combat.enemy_target_nav = GridNavigator.new()
	if not combat.enemy_target_buttons.is_empty():
		combat.enemy_target_nav.setup(buttons_by_pos, 0)

	combat.breath_target_mode = true


func on_breath_target_selected(enemy: Monster) -> void:
	combat._close_all_modals()
	combat.breath_target_mode = false
	combat.combat_system.player_breath(enemy)
