class_name CombatTargetingUI
extends RefCounted

var combat = null


func init(p_combat: Control) -> void:
	combat = p_combat


func on_target_selection_requested(reachable_enemies: Array[Monster]) -> void:
	combat._close_all_modals()
	combat._set_actions_enabled(false)
	populate_enemy_target_list(reachable_enemies)


func populate_enemy_target_list(reachable_enemies: Array[Monster]) -> void:
	clear_grid_target_buttons()
	combat.enemy_target_buttons.clear()

	var buttons_by_pos: Dictionary = {}
	for enemy in reachable_enemies:
		if not combat.enemy_panels.has(enemy.combat_id):
			continue
		var ui = combat.enemy_panels[enemy.combat_id]
		var cell: PanelContainer = ui.panel.get_parent()
		var btn := create_grid_overlay_button(cell)
		btn.pressed.connect(on_enemy_target_selected.bind(enemy))
		btn.focus_entered.connect(highlight_enemy_target.bind(enemy))
		combat.enemy_target_buttons.append(btn)
		combat._grid_target_buttons.append(btn)
		buttons_by_pos[enemy.grid_position] = btn

	combat.enemy_target_nav = GridNavigator.new()
	if not combat.enemy_target_buttons.is_empty():
		combat.enemy_target_nav.setup(buttons_by_pos, 0)


func clear_grid_target_buttons() -> void:
	for btn: Button in combat._grid_target_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	combat._grid_target_buttons.clear()


func create_grid_overlay_button(cell: PanelContainer) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.flat = true
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color.TRANSPARENT
	btn.add_theme_stylebox_override("normal", transparent)
	btn.add_theme_stylebox_override("hover", transparent)
	btn.add_theme_stylebox_override("pressed", transparent)
	btn.add_theme_stylebox_override("focus", transparent)
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	cell.add_child(btn)
	return btn


func on_enemy_target_selected(enemy: Monster) -> void:
	combat._close_all_modals()
	combat.combat_system.player_attack(enemy)


func on_cancel_enemy_target() -> void:
	if combat.ally_target_mode == "item":
		combat.ally_target_mode = ""
		combat._close_all_modals()
		combat.selected_item = null
		combat.item_modal.visible = true
		if combat.item_nav and not combat.item_buttons.is_empty():
			combat.item_nav.setup(combat.item_buttons, 0)
		return
	if combat.ally_target_mode == "spell":
		combat.ally_target_mode = ""
		combat.selected_spell = null
		combat.spell_target_mode = ""
		combat._close_all_modals()
		combat.spell_modal.visible = true
		if combat.spell_nav and not combat.spell_buttons.is_empty():
			combat.spell_nav.setup(combat.spell_buttons, 0)
		return
	if combat.dispel_target_mode:
		combat.dispel_target_mode = false
		combat._close_all_modals()
		combat._set_actions_enabled(true)
	elif combat.breath_target_mode:
		combat.breath_target_mode = false
		combat._close_all_modals()
		combat._set_actions_enabled(true)
	elif combat.spell_target_mode in ["enemy", "splash", "row", "column"]:
		combat._close_all_modals()
		combat.spell_modal.visible = true
		combat.selected_spell = null
		combat.spell_target_mode = ""
		if combat.spell_nav and not combat.spell_buttons.is_empty():
			combat.spell_nav.setup(combat.spell_buttons, 0)
	else:
		combat._close_all_modals()
		combat.combat_system.cancel_target_selection()
		combat._set_actions_enabled(true)


func highlight_enemy_target(enemy: Monster) -> void:
	clear_target_highlights()
	if not combat.enemy_panels.has(enemy.combat_id):
		return
	var ui = combat.enemy_panels[enemy.combat_id]
	var panel: VBoxContainer = ui.panel
	var cell: PanelContainer = panel.get_parent()
	combat.display.update_portrait_for_enemy(enemy)
	combat._target_highlight_style = StyleBoxFlat.new()
	combat._target_highlight_style.bg_color = Color.TRANSPARENT
	combat._target_highlight_style.border_color = UIColors.TEXT_DANGER
	combat._target_highlight_style.border_width_left = 2
	combat._target_highlight_style.border_width_top = 2
	combat._target_highlight_style.border_width_right = 2
	combat._target_highlight_style.border_width_bottom = 2
	combat._target_highlight_style.corner_radius_top_left = 4
	combat._target_highlight_style.corner_radius_top_right = 4
	combat._target_highlight_style.corner_radius_bottom_left = 4
	combat._target_highlight_style.corner_radius_bottom_right = 4
	cell.add_theme_stylebox_override("panel", combat._target_highlight_style)
	combat._highlighted_panels.append(cell)
	if combat._target_highlight_tween:
		combat._target_highlight_tween.kill()
	combat._target_highlight_tween = combat.create_tween().set_loops()
	combat._target_highlight_tween.tween_property(combat._target_highlight_style, "border_color:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
	combat._target_highlight_tween.tween_property(combat._target_highlight_style, "border_color:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


func highlight_enemy_targets(enemies: Array[Monster], origin: Monster = null) -> void:
	clear_target_highlights()
	if origin != null:
		combat.display.update_portrait_for_enemy(origin)
	elif not enemies.is_empty():
		combat.display.update_portrait_for_enemy(enemies[0])
	combat._target_highlight_style = StyleBoxFlat.new()
	combat._target_highlight_style.bg_color = Color.TRANSPARENT
	combat._target_highlight_style.border_color = UIColors.TEXT_DANGER
	combat._target_highlight_style.border_width_left = 2
	combat._target_highlight_style.border_width_top = 2
	combat._target_highlight_style.border_width_right = 2
	combat._target_highlight_style.border_width_bottom = 2
	combat._target_highlight_style.corner_radius_top_left = 4
	combat._target_highlight_style.corner_radius_top_right = 4
	combat._target_highlight_style.corner_radius_bottom_left = 4
	combat._target_highlight_style.corner_radius_bottom_right = 4
	var secondary_style: StyleBoxFlat = null
	if origin != null:
		secondary_style = StyleBoxFlat.new()
		secondary_style.bg_color = Color.TRANSPARENT
		secondary_style.border_color = UIColors.WARNING
		secondary_style.border_width_left = 1
		secondary_style.border_width_top = 1
		secondary_style.border_width_right = 1
		secondary_style.border_width_bottom = 1
		secondary_style.corner_radius_top_left = 4
		secondary_style.corner_radius_top_right = 4
		secondary_style.corner_radius_bottom_left = 4
		secondary_style.corner_radius_bottom_right = 4
	for enemy in enemies:
		if not combat.enemy_panels.has(enemy.combat_id):
			continue
		var ui = combat.enemy_panels[enemy.combat_id]
		var cell: PanelContainer = ui.panel.get_parent()
		var is_origin := origin != null and enemy.combat_id == origin.combat_id
		var style: StyleBoxFlat = combat._target_highlight_style if is_origin or secondary_style == null else secondary_style
		cell.add_theme_stylebox_override("panel", style)
		combat._highlighted_panels.append(cell)
	if combat._highlighted_panels.is_empty():
		return
	if combat._target_highlight_tween:
		combat._target_highlight_tween.kill()
	combat._target_highlight_tween = combat.create_tween().set_loops()
	combat._target_highlight_tween.tween_property(combat._target_highlight_style, "border_color:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
	combat._target_highlight_tween.tween_property(combat._target_highlight_style, "border_color:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


func highlight_party_target(character: Character) -> void:
	clear_target_highlights()
	if not combat.party_panels.has(character.id):
		return
	var ui = combat.party_panels[character.id]
	# Ally highlight: keep the card fill, add a pulsing ARCANE-ACCENT border (vs.
	# the red used for foes) and leave the FOE portrait in place — the rail is
	# the enemy's, not the target ally's.
	combat._target_highlight_style = StyleBoxFlat.new()
	combat._target_highlight_style.bg_color = UIColors.SURFACE_CARD
	combat._target_highlight_style.border_color = UIColors.ACCENT
	combat._target_highlight_style.set_border_width_all(2)
	combat._target_highlight_style.set_corner_radius_all(8)
	ui.panel.add_theme_stylebox_override("panel", combat._target_highlight_style)
	combat._highlighted_panels.append(ui.panel)
	if combat._target_highlight_tween:
		combat._target_highlight_tween.kill()
	combat._target_highlight_tween = combat.create_tween().set_loops()
	combat._target_highlight_tween.tween_property(combat._target_highlight_style, "border_color:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
	combat._target_highlight_tween.tween_property(combat._target_highlight_style, "border_color:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


## On-field ally targeting: drop transparent overlay buttons onto the chosen
## party cards (mirrors the enemy grid-overlay flow) and drive them with a
## GridNavigator so item/heal-spell targets are picked on the battlefield
## instead of a centred pop-up list. `on_select` receives the chosen Character.
func populate_ally_targets(targets: Array, on_select: Callable) -> void:
	clear_grid_target_buttons()
	clear_target_highlights()
	combat.modal_overlay.visible = false  # on-field targeting: show the full battlefield
	combat.enemy_target_buttons.clear()

	var party: Party = combat.combat_system.get_party_resource()
	var front := party.get_front_row()
	var back := party.get_back_row()
	var buttons_by_pos: Dictionary = {}
	for character: Character in targets:
		if not combat.party_panels.has(character.id):
			continue
		var card: PanelContainer = combat.party_panels[character.id].panel
		var btn := create_grid_overlay_button(card)
		btn.pressed.connect(on_select.bind(character))
		btn.focus_entered.connect(highlight_party_target.bind(character))
		combat.enemy_target_buttons.append(btn)
		combat._grid_target_buttons.append(btn)
		var fidx := front.find(character)
		var pos: Vector2i
		if fidx >= 0:
			pos = Vector2i(fidx, 1)  # front row sits visually above the back row
		else:
			pos = Vector2i(maxi(back.find(character), 0), 0)
		buttons_by_pos[pos] = btn

	combat.enemy_target_nav = GridNavigator.new()
	if not combat.enemy_target_buttons.is_empty():
		combat.enemy_target_nav.setup(buttons_by_pos, 0)


func clear_target_highlights() -> void:
	if combat._target_highlight_tween:
		combat._target_highlight_tween.kill()
		combat._target_highlight_tween = null
	for panel: PanelContainer in combat._highlighted_panels:
		if is_instance_valid(panel):
			panel.remove_theme_stylebox_override("panel")
	combat._highlighted_panels.clear()
	combat._target_highlight_style = null
	combat.display.update_portrait_for_active_combatant()


func show_floating_text(character_id: String, text: String, color: Color) -> void:
	if not combat.party_panels.has(character_id):
		return
	var ui = combat.party_panels[character_id]
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_BODY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position.y = -4
	ui.panel.add_child(label)
	var tween: Tween = combat.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 20, 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)
