class_name CombatDisplay
extends RefCounted

const STATUS_ICON_PATHS: Dictionary = {
	CharacterEnums.StatusEffect.POISONED: "res://textures/ui/status_icons/poison.png",
	CharacterEnums.StatusEffect.PARALYZED: "res://textures/ui/status_icons/stunned.png",
	CharacterEnums.StatusEffect.ASLEEP: "res://textures/ui/status_icons/sleep.png",
	CharacterEnums.StatusEffect.STONED: "res://textures/ui/status_icons/stone.png",
	CharacterEnums.StatusEffect.CONFUSED: "res://textures/ui/status_icons/confuse.png",
	CharacterEnums.StatusEffect.SILENCED: "res://textures/ui/status_icons/silence.png",
	CharacterEnums.StatusEffect.BLINDED: "res://textures/ui/status_icons/blind.png",
	CharacterEnums.StatusEffect.AFRAID: "res://textures/ui/status_icons/alert.png",
	CharacterEnums.StatusEffect.CHARMED: "res://textures/ui/status_icons/charm.png",
	CharacterEnums.StatusEffect.BERSERK: "res://textures/ui/status_icons/berserk.png",
	CharacterEnums.StatusEffect.CURSED: "res://textures/ui/status_icons/debuff.png",
	CharacterEnums.StatusEffect.BLESSED: "res://textures/ui/status_icons/buff.png",
}

var combat: Control
var _status_icon_cache: Dictionary = {}
var _effect_cache: Dictionary = {}
var _turn_order_entries: Array[PanelContainer] = []
var _monster_texture_cache: Dictionary = {}
var _monster_sheet_cache: Dictionary = {}
var _silhouette_texture: Texture2D = null
var _sprite_sheet_shader: Shader = preload("res://shaders/sprite_sheet_animation.gdshader")
var _display_dirty: bool = false


func init(p_combat: Control) -> void:
	combat = p_combat


func update_display() -> void:
	if combat.combat_system == null:
		return

	_update_enemy_display()
	_update_party_stats()
	_update_turn_order()
	update_portrait_for_active_combatant()


func schedule_display_update() -> void:
	if not _display_dirty:
		_display_dirty = true
		_deferred_update_display.call_deferred()


func _deferred_update_display() -> void:
	_display_dirty = false
	update_display()


func on_layout_changed() -> void:
	_effect_cache.clear()
	build_enemy_display()
	build_party_display()


func _update_enemy_display() -> void:
	for enemy in combat.combat_system.get_enemies():
		if not combat.enemy_panels.has(enemy.combat_id):
			continue

		var ui = combat.enemy_panels[enemy.combat_id]

		ui.hp_bar.max_value = enemy.max_hp
		ui.hp_bar.value = enemy.current_hp
		ui.hp_text.text = "%d" % enemy.current_hp

		_update_status_icons(ui.status_icons_hbox, enemy.status_effects)

		if enemy.is_dead:
			ui.status_label.text = "DEAD"
			ui.panel.modulate = UIColors.DEAD_TINT
		else:
			var hp_percent := float(enemy.current_hp) / float(enemy.max_hp)
			if hp_percent <= 0.25:
				ui.status_label.text = "Critical"
			elif hp_percent <= 0.5:
				ui.status_label.text = "Wounded"
			else:
				ui.status_label.text = ""
			ui.panel.modulate = Color.WHITE

	_update_row_labels()


func _update_row_labels() -> void:
	var living_front := Targeting.get_living_front_row(combat.combat_system.get_enemies())
	var row_labels_list: Array[Label] = [combat.front_label, combat.middle_label, combat.back_label]
	for i in range(3):
		if not row_labels_list[i].visible:
			continue
		var has_living := false
		for enemy in combat.combat_system.get_enemies():
			if not enemy.is_dead and enemy.grid_position.y == i:
				has_living = true
				break
		if not has_living:
			row_labels_list[i].add_theme_color_override("font_color", UIColors.TEXT_DISABLED)
		elif i == living_front:
			row_labels_list[i].add_theme_color_override("font_color", UIColors.TEXT_STATUS)
		else:
			row_labels_list[i].remove_theme_color_override("font_color")


func update_portrait_for_enemy(enemy: Monster) -> void:
	if enemy == null:
		combat.portrait_texture.material = null
		combat.portrait_texture.texture = null
		combat.portrait_name.text = ""
		return
	var sheet := _get_monster_sprite_sheet(enemy.monster_name)
	if sheet != null:
		var mat := ShaderMaterial.new()
		mat.shader = _sprite_sheet_shader
		mat.set_shader_parameter("frame_count", 37)
		mat.set_shader_parameter("columns", 7)
		mat.set_shader_parameter("rows", 6)
		mat.set_shader_parameter("fps", 12.0)
		combat.portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		combat.portrait_texture.texture = sheet
		combat.portrait_texture.material = mat
	else:
		combat.portrait_texture.material = null
		combat.portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		combat.portrait_texture.texture = _get_monster_texture(enemy.monster_name)
	combat.portrait_name.text = enemy.monster_name
	if enemy.is_dead:
		combat.portrait_texture.modulate = UIColors.DEAD_TINT
	else:
		combat.portrait_texture.modulate = Color.WHITE


func update_portrait_for_character(character: Character) -> void:
	if character == null:
		combat.portrait_texture.material = null
		combat.portrait_texture.texture = null
		combat.portrait_name.text = ""
		return
	combat.portrait_texture.material = null
	combat.portrait_texture.texture = null
	combat.portrait_name.text = character.character_name


func update_portrait_for_active_combatant() -> void:
	if combat.combat_system == null:
		return
	var combatant_id: String = combat.combat_system.current_combatant_id
	if combatant_id.is_empty():
		return
	for enemy in combat.combat_system.get_enemies():
		if enemy.combat_id == combatant_id:
			update_portrait_for_enemy(enemy)
			return
	var character := combat._get_character_by_id(combatant_id)
	if character:
		update_portrait_for_character(character)


func _update_party_stats() -> void:
	for character in combat.combat_system.get_party():
		if not combat.party_panels.has(character.id):
			continue

		var ui = combat.party_panels[character.id]

		ui.hp_bar.max_value = character.max_hp
		ui.hp_bar.value = character.current_hp
		ui.hp_text.text = "%d" % character.current_hp

		ui.mp_bar.max_value = max(character.max_mp, 1)
		ui.mp_bar.value = character.current_mp
		ui.mp_text.text = "%d" % character.current_mp

		_update_status_icons(ui.status_icons_hbox, character.status_effects)

		if character.is_dead:
			ui.status_label.text = "DEAD"
			ui.panel.modulate = UIColors.MODULATE_DISABLED
		else:
			var statuses := _get_character_status_text(character)
			ui.status_label.text = statuses
			ui.panel.modulate = Color.WHITE

		var is_active := combat.combat_system.current_combatant_id == character.id and combat.combat_system.is_player_turn()
		if is_active:
			ui.name_label.add_theme_color_override("font_color", UIColors.TEXT_ACTIVE)
			var active_style := StyleBoxFlat.new()
			active_style.bg_color = Color.TRANSPARENT
			active_style.border_color = UIColors.TEXT_ACTIVE
			active_style.border_width_left = 2
			active_style.border_width_top = 2
			active_style.border_width_right = 2
			active_style.border_width_bottom = 2
			active_style.corner_radius_top_left = 4
			active_style.corner_radius_top_right = 4
			active_style.corner_radius_bottom_left = 4
			active_style.corner_radius_bottom_right = 4
			ui.panel.add_theme_stylebox_override("panel", active_style)
			if combat._active_panel_tween:
				combat._active_panel_tween.kill()
			combat._active_panel_tween = combat.create_tween().set_loops()
			combat._active_panel_tween.tween_property(active_style, "border_color:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
			combat._active_panel_tween.tween_property(active_style, "border_color:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
		else:
			ui.name_label.remove_theme_color_override("font_color")
			ui.panel.remove_theme_stylebox_override("panel")


func _get_character_status_text(character: Character) -> String:
	var statuses: Array[String] = []

	if character.is_defending:
		statuses.append("DEF")
	if character.has_status(CharacterEnums.StatusEffect.POISONED):
		statuses.append("PSN")
	if character.has_status(CharacterEnums.StatusEffect.PARALYZED):
		statuses.append("PAR")
	if character.has_status(CharacterEnums.StatusEffect.ASLEEP):
		statuses.append("SLP")
	if character.has_status(CharacterEnums.StatusEffect.CONFUSED):
		statuses.append("CNF")
	if character.has_status(CharacterEnums.StatusEffect.SILENCED):
		statuses.append("SIL")
	if character.has_status(CharacterEnums.StatusEffect.BLINDED):
		statuses.append("BLD")

	return " ".join(statuses)


func _update_status_icons(hbox: HBoxContainer, effects: Array[CharacterEnums.StatusEffect]) -> void:
	var key := hbox.get_instance_id()
	if _effect_cache.has(key) and _effects_match(_effect_cache[key], effects):
		return
	_effect_cache[key] = effects.duplicate()

	var children := hbox.get_children()
	for child in children:
		hbox.remove_child(child)
		child.queue_free()

	for effect in effects:
		if effect == CharacterEnums.StatusEffect.NONE or effect == CharacterEnums.StatusEffect.DEAD:
			continue
		if not STATUS_ICON_PATHS.has(effect):
			continue
		var tex: Texture2D = _get_status_icon(effect)
		if tex == null:
			continue
		var icon := TextureRect.new()
		icon.texture = tex
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(16, 16)
		hbox.add_child(icon)


func _effects_match(cached: Array, current: Array[CharacterEnums.StatusEffect]) -> bool:
	if cached.size() != current.size():
		return false
	for i in range(cached.size()):
		if cached[i] != current[i]:
			return false
	return true


func _get_status_icon(effect: CharacterEnums.StatusEffect) -> Texture2D:
	if _status_icon_cache.has(effect):
		return _status_icon_cache[effect]
	var path: String = STATUS_ICON_PATHS.get(effect, "")
	if path.is_empty():
		return null
	var tex: Texture2D = load(path)
	_status_icon_cache[effect] = tex
	return tex


func _update_turn_order() -> void:
	if combat.combat_system == null or combat.combat_system.initiative == null:
		return

	var entries := _get_sorted_turn_order()
	var max_shown := 9
	var idx := 0

	var current_name := ""

	for i in range(entries.size()):
		if idx >= max_shown:
			break

		var entry = entries[i]
		var name_text := ""
		var entry_id: String = entry.id
		var is_current: bool = (entry_id == combat.combat_system.current_combatant_id)
		var is_player: bool = entry.is_player

		if is_player:
			var character := combat._get_character_by_id(entry.id)
			if character:
				name_text = character.get_display_name()
		else:
			var enemy := combat._get_enemy_by_combat_id(entry.id)
			if enemy:
				name_text = enemy.monster_name

		if name_text == "":
			continue

		if is_current:
			current_name = name_text

		var panel: PanelContainer
		if idx < _turn_order_entries.size():
			panel = _turn_order_entries[idx]
			panel.visible = true
		else:
			panel = PanelContainer.new()
			panel.custom_minimum_size = Vector2(90, 28)
			var new_lbl := Label.new()
			new_lbl.name = "NameLabel"
			new_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			new_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			new_lbl.add_theme_font_size_override("font_size", 12)
			panel.add_child(new_lbl)
			combat.turn_order_hbox.add_child(panel)
			_turn_order_entries.append(panel)

		var lbl: Label = panel.get_node("NameLabel")
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 2
		style.content_margin_bottom = 2

		if is_current:
			lbl.text = "> %s <" % name_text
			style.bg_color = Color(0.15, 0.4, 0.15)
			style.border_color = Color(0.3, 1.0, 0.3)
			style.set_border_width_all(2)
			lbl.add_theme_color_override("font_color", UIColors.TEXT_ACTIVE)
			lbl.add_theme_font_size_override("font_size", 13)
			panel.custom_minimum_size = Vector2(100, 30)
		elif is_player:
			lbl.text = name_text
			style.bg_color = Color(0.1, 0.15, 0.25)
			style.border_color = Color(0.3, 0.5, 0.8, 0.5)
			style.set_border_width_all(1)
			lbl.add_theme_color_override("font_color", UIColors.INFO)
			lbl.add_theme_font_size_override("font_size", 12)
			panel.custom_minimum_size = Vector2(90, 28)
		else:
			lbl.text = name_text
			style.bg_color = Color(0.25, 0.1, 0.1)
			style.border_color = Color(0.8, 0.3, 0.3, 0.5)
			style.set_border_width_all(1)
			lbl.add_theme_color_override("font_color", UIColors.TEXT_DANGER)
			lbl.add_theme_font_size_override("font_size", 12)
			panel.custom_minimum_size = Vector2(90, 28)

		panel.add_theme_stylebox_override("panel", style)
		idx += 1

	for i in range(idx, _turn_order_entries.size()):
		_turn_order_entries[i].visible = false

	if current_name != "":
		combat.active_char_label.text = "%s's Turn:" % current_name
	else:
		combat.active_char_label.text = ""


func _get_sorted_turn_order() -> Array:
	if combat.combat_system == null or combat.combat_system.initiative == null:
		return []

	var entries: Array = []
	for entry in combat.combat_system.initiative.combatants:
		entries.append(entry)

	entries.sort_custom(func(a, b): return a.ticks < b.ticks)
	return entries


func build_enemy_display() -> void:
	var children := combat.enemy_grid.get_children()
	for child in children:
		combat.enemy_grid.remove_child(child)
		child.queue_free()
	combat.enemy_panels.clear()

	if combat.combat_system == null:
		return

	var enemy_grid_map: Dictionary = {}
	var occupied_rows: Array[int] = []
	for enemy in combat.combat_system.get_enemies():
		var pos := enemy.grid_position
		enemy_grid_map[pos] = enemy
		if not occupied_rows.has(pos.y):
			occupied_rows.append(pos.y)
	occupied_rows.sort()

	var row_labels_list: Array[Label] = [combat.front_label, combat.middle_label, combat.back_label]
	for i in range(3):
		row_labels_list[i].visible = occupied_rows.has(i)

	for display_row in range(occupied_rows.size() - 1, -1, -1):
		var actual_row: int = occupied_rows[display_row]
		for col in range(3):
			var pos := Vector2i(col, actual_row)
			var enemy: Monster = enemy_grid_map.get(pos)

			var cell := PanelContainer.new()
			cell.custom_minimum_size = Vector2(100, 50)

			if enemy != null:
				var ui := _create_enemy_panel(enemy)
				combat.enemy_panels[enemy.combat_id] = ui
				cell.add_child(ui.panel)
				if enemy.is_dead:
					ui.panel.modulate = UIColors.DEAD_TINT
			else:
				var empty := Label.new()
				empty.text = "-"
				empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				empty.add_theme_color_override("font_color", UIColors.TEXT_DISABLED)
				cell.add_child(empty)
				cell.modulate = UIColors.DISABLED_TINT

			combat.enemy_grid.add_child(cell)


func _create_enemy_panel(enemy: Monster) -> RefCounted:
	var ui = combat.EnemyUI.new()

	ui.panel = VBoxContainer.new()
	ui.panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui.panel.add_theme_constant_override("separation", 1)

	ui.name_label = Label.new()
	ui.name_label.text = enemy.monster_name
	ui.name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.panel.add_child(ui.name_label)

	var hp_hbox := HBoxContainer.new()
	ui.panel.add_child(hp_hbox)

	ui.hp_bar = ProgressBar.new()
	ui.hp_bar.custom_minimum_size = Vector2(70, 12)
	ui.hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.hp_bar.max_value = enemy.max_hp
	ui.hp_bar.value = enemy.current_hp
	ui.hp_bar.show_percentage = false
	_style_bar(ui.hp_bar, UIColors.DANGER)
	hp_hbox.add_child(ui.hp_bar)

	ui.hp_text = Label.new()
	ui.hp_text.text = "%d" % enemy.current_hp
	ui.hp_text.custom_minimum_size = Vector2(28, 0)
	ui.hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_hbox.add_child(ui.hp_text)

	ui.status_icons_hbox = HBoxContainer.new()
	ui.status_icons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ui.status_icons_hbox.add_theme_constant_override("separation", 2)
	ui.panel.add_child(ui.status_icons_hbox)

	ui.status_label = Label.new()
	ui.status_label.text = ""
	ui.status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.status_label.add_theme_color_override("font_color", UIColors.TEXT_DANGER)
	ui.panel.add_child(ui.status_label)

	return ui


func build_party_display() -> void:
	for child in combat.party_front_row.get_children():
		child.queue_free()
	for child in combat.party_back_row.get_children():
		child.queue_free()
	combat.party_panels.clear()

	if combat.combat_system == null:
		return

	var party := combat.combat_system.get_party_resource()
	var front := party.get_front_row()
	var back := party.get_back_row()

	for character in front:
		var ui := _create_party_member_panel(character, true)
		combat.party_panels[character.id] = ui
		combat.party_front_row.add_child(ui.panel)

	for i in range(3 - front.size()):
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(150, 0)
		combat.party_front_row.add_child(spacer)

	for character in back:
		var ui := _create_party_member_panel(character, false)
		combat.party_panels[character.id] = ui
		combat.party_back_row.add_child(ui.panel)

	for i in range(3 - back.size()):
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(150, 0)
		combat.party_back_row.add_child(spacer)


func _create_party_member_panel(character: Character, _is_front: bool) -> RefCounted:
	var ui = combat.PartyMemberUI.new()

	ui.panel = PanelContainer.new()
	ui.panel.custom_minimum_size = Vector2(100, 50)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	ui.panel.add_child(vbox)

	ui.name_label = Label.new()
	ui.name_label.text = character.get_display_name()
	ui.name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(ui.name_label)

	var hp_hbox := HBoxContainer.new()
	vbox.add_child(hp_hbox)

	ui.hp_bar = ProgressBar.new()
	ui.hp_bar.custom_minimum_size = Vector2(60, 12)
	ui.hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.hp_bar.max_value = character.max_hp
	ui.hp_bar.value = character.current_hp
	ui.hp_bar.show_percentage = false
	_style_bar(ui.hp_bar, UIColors.DANGER)
	hp_hbox.add_child(ui.hp_bar)

	ui.hp_text = Label.new()
	ui.hp_text.text = "%d" % character.current_hp
	ui.hp_text.custom_minimum_size = Vector2(28, 0)
	ui.hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_hbox.add_child(ui.hp_text)

	var mp_hbox := HBoxContainer.new()
	vbox.add_child(mp_hbox)

	ui.mp_bar = ProgressBar.new()
	ui.mp_bar.custom_minimum_size = Vector2(60, 12)
	ui.mp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.mp_bar.max_value = max(character.max_mp, 1)
	ui.mp_bar.value = character.current_mp
	ui.mp_bar.show_percentage = false
	_style_bar(ui.mp_bar, UIColors.MP_BLUE)
	mp_hbox.add_child(ui.mp_bar)

	ui.mp_text = Label.new()
	ui.mp_text.text = "%d" % character.current_mp
	ui.mp_text.custom_minimum_size = Vector2(28, 0)
	ui.mp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mp_hbox.add_child(ui.mp_text)

	ui.status_icons_hbox = HBoxContainer.new()
	ui.status_icons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ui.status_icons_hbox.add_theme_constant_override("separation", 2)
	vbox.add_child(ui.status_icons_hbox)

	ui.status_label = Label.new()
	ui.status_label.text = ""
	ui.status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.status_label.add_theme_color_override("font_color", UIColors.TEXT_DANGER)
	vbox.add_child(ui.status_label)

	return ui


func style_modal(modal: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.13, 1.0)
	style.border_color = Color(0.55, 0.50, 0.65, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	modal.add_theme_stylebox_override("panel", style)


func _style_bar(bar: ProgressBar, fill_color: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = fill_color.darkened(0.7)
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_left = 2
	bg.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill)


func _get_monster_texture(monster_name: String) -> Texture2D:
	if _monster_texture_cache.has(monster_name):
		return _monster_texture_cache[monster_name]
	var path := "res://textures/monsters/%s.png" % monster_name.to_lower().replace(" ", "_")
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_monster_texture_cache[monster_name] = tex
		return tex
	if _silhouette_texture != null:
		_monster_texture_cache[monster_name] = _silhouette_texture
		return _silhouette_texture
	var fallback_path := "res://textures/monsters/goblin.png"
	if not ResourceLoader.exists(fallback_path):
		_monster_texture_cache[monster_name] = null
		return null
	var base_tex: Texture2D = load(fallback_path)
	var img := base_tex.get_image()
	img = img.duplicate()
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var pixel := img.get_pixel(x, y)
			if pixel.a > 0.0:
				img.set_pixel(x, y, Color(0.15, 0.12, 0.20, pixel.a * 0.8))
	_silhouette_texture = ImageTexture.create_from_image(img)
	_monster_texture_cache[monster_name] = _silhouette_texture
	return _silhouette_texture


func _get_monster_sprite_sheet(monster_name: String) -> Texture2D:
	var key := monster_name.to_lower().replace(" ", "_")
	if _monster_sheet_cache.has(key):
		return _monster_sheet_cache[key]
	var path := "res://textures/monsters/animated/%s_sheet.png" % key
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_monster_sheet_cache[key] = tex
		return tex
	_monster_sheet_cache[key] = null
	return null


func show_victory_summary(xp: int, gold: int, items_added: Array[Item], items_left: Array[Item]) -> void:
	var summary := "[color=green]VICTORY![/color]\n"
	summary += "Experience: %d\n" % xp
	summary += "Gold: %d\n" % gold

	if not items_added.is_empty():
		summary += "\n[color=cyan]Items Found:[/color]\n"
		for item in items_added:
			if item.is_identified:
				summary += "  - %s\n" % item.get_display_name()
			else:
				summary += "  - %s\n" % item.get_type_name()

	if not items_left.is_empty():
		summary += "\n[color=yellow]Left Behind (inventory full):[/color]\n"
		for item in items_left:
			if item.is_identified:
				summary += "  - %s\n" % item.get_display_name()
			else:
				summary += "  - %s\n" % item.get_type_name()

	combat.message_log.append_text(summary)
