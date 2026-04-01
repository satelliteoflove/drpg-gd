class_name PartyMenuSpellsTab
extends RefCounted

enum SpellPanel { PARTY, LIST, TARGETS }

var spell_party_nav: MenuNavigator = null
var spell_list_nav: MenuNavigator = null
var spell_target_nav: MenuNavigator = null
var spell_party_buttons: Array[Button] = []
var spell_list_buttons: Array[Button] = []
var spell_target_buttons: Array[Button] = []
var selected_character: Character = null
var selected_spell: Spell = null
var current_level: int = 1
var all_spells: Dictionary = {}
var panel: SpellPanel = SpellPanel.PARTY

var spell_party_list: VBoxContainer
var spell_level_tabs: HBoxContainer
var spell_list: VBoxContainer
var spell_target_panel: PanelContainer
var spell_target_list: VBoxContainer
var info_label: RichTextLabel


func init(p_spell_party_list: VBoxContainer, p_spell_level_tabs: HBoxContainer, p_spell_list: VBoxContainer, p_spell_target_panel: PanelContainer, p_spell_target_list: VBoxContainer, p_info_label: RichTextLabel) -> void:
	spell_party_list = p_spell_party_list
	spell_level_tabs = p_spell_level_tabs
	spell_list = p_spell_list
	spell_target_panel = p_spell_target_panel
	spell_target_list = p_spell_target_list
	info_label = p_info_label


func refresh() -> void:
	_refresh_spell_party()
	_refresh_spell_level_tabs()
	_refresh_spell_list()
	_refresh_spell_targets()
	_update_spell_info()


func _refresh_spell_party() -> void:
	for child in spell_party_list.get_children():
		child.queue_free()
	spell_party_buttons.clear()

	if GameState.party == null or GameState.party.is_empty():
		var label := Label.new()
		label.text = "(No party)"
		spell_party_list.add_child(label)
		return

	for i in range(GameState.party.size()):
		var member: Character = GameState.party.get_member_at(i)
		var btn := Button.new()
		var status_text := ""
		if member.is_dead:
			status_text = " [DEAD]"
		elif member.is_silenced():
			status_text = " [SIL]"
		btn.text = "%s - MP: %d/%d%s" % [member.character_name, member.current_mp, member.max_mp, status_text]
		btn.custom_minimum_size = Vector2(180, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if member.is_dead:
			btn.modulate = UIColors.MODULATE_DEAD
		elif member.is_silenced():
			btn.modulate = UIColors.MODULATE_DISABLED
		btn.pressed.connect(_on_spell_party_selected.bind(member))
		spell_party_list.add_child(btn)
		spell_party_buttons.append(btn)

	spell_party_nav = MenuNavigator.new()
	spell_party_nav.setup(spell_party_buttons, 0)
	spell_party_nav.selection_changed.connect(_on_spell_party_nav_changed)

	if panel == SpellPanel.PARTY:
		spell_party_nav.update_focus()


func _on_spell_party_selected(character: Character) -> void:
	selected_character = character
	current_level = 1
	panel = SpellPanel.LIST
	_load_character_spells()
	_auto_select_first_level()
	refresh()


func _on_spell_party_nav_changed(_index: int) -> void:
	_update_spell_info()


func _load_character_spells() -> void:
	all_spells.clear()
	if selected_character == null:
		return
	for i in range(1, 8):
		all_spells[i] = []
	for spell_id in selected_character.known_spells:
		var spell: Spell = SpellDatabase.get_spell(spell_id)
		if spell == null:
			continue
		if all_spells.has(spell.level):
			all_spells[spell.level].append(spell)


func _auto_select_first_level() -> void:
	for lvl in range(1, 8):
		if all_spells.has(lvl) and not all_spells[lvl].is_empty():
			current_level = lvl
			return
	current_level = 1


func _refresh_spell_level_tabs() -> void:
	for child in spell_level_tabs.get_children():
		child.queue_free()

	if selected_character == null:
		return

	for lvl in range(1, 8):
		var btn := Button.new()
		btn.text = "L%d" % lvl
		btn.custom_minimum_size = Vector2(36, 24)
		btn.toggle_mode = true
		btn.button_pressed = (lvl == current_level)
		var has_spells: bool = all_spells.has(lvl) and not all_spells[lvl].is_empty()
		if not has_spells:
			btn.modulate = UIColors.MODULATE_DISABLED
		btn.pressed.connect(_on_spell_level_selected.bind(lvl))
		spell_level_tabs.add_child(btn)


func _on_spell_level_selected(lvl: int) -> void:
	current_level = lvl
	_refresh_spell_level_tabs()
	_refresh_spell_list()
	_update_spell_info()


func _refresh_spell_list() -> void:
	for child in spell_list.get_children():
		child.queue_free()
	spell_list_buttons.clear()

	if selected_character == null:
		var label := Label.new()
		label.text = "Select a character"
		spell_list.add_child(label)
		return

	var spells_at_level: Array = all_spells.get(current_level, [])
	if spells_at_level.is_empty():
		var label := Label.new()
		label.text = "(No spells at this level)"
		spell_list.add_child(label)
		return

	for spell: Spell in spells_at_level:
		var btn := Button.new()
		btn.text = "%s  (%d MP)" % [spell.name, spell.mp_cost]
		btn.custom_minimum_size = Vector2(200, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if not spell.out_of_combat:
			btn.modulate = UIColors.MODULATE_DISABLED
		elif selected_character.current_mp < spell.mp_cost:
			btn.modulate = UIColors.MODULATE_DISABLED
		elif selected_character.is_dead or selected_character.is_silenced() or selected_character.is_disabled():
			btn.modulate = UIColors.MODULATE_DISABLED

		btn.pressed.connect(_on_spell_selected.bind(spell))
		spell_list.add_child(btn)
		spell_list_buttons.append(btn)

	spell_list_nav = MenuNavigator.new()
	spell_list_nav.setup(spell_list_buttons, 0)
	spell_list_nav.selection_changed.connect(_on_spell_list_nav_changed)

	if panel == SpellPanel.LIST:
		spell_list_nav.update_focus()


func _on_spell_list_nav_changed(_index: int) -> void:
	_update_spell_info()


func _on_spell_selected(spell: Spell) -> void:
	if not spell.out_of_combat:
		info_label.text = "[b]%s[/b]\nCan only be cast in combat." % spell.name
		return

	var validation := SpellValidator.can_cast(selected_character, spell, false)
	if not validation.can_cast:
		info_label.text = "[b]%s[/b]\n%s" % [spell.name, validation.reason]
		return

	match spell.target_type:
		CharacterEnums.SpellTargetType.SELF:
			_cast_spell_on_targets(spell, [selected_character])
		CharacterEnums.SpellTargetType.ALL_ALLIES:
			_cast_spell_on_targets(spell, _get_living_party_members())
		_:
			selected_spell = spell
			panel = SpellPanel.TARGETS
			refresh()


func _refresh_spell_targets() -> void:
	for child in spell_target_list.get_children():
		child.queue_free()
	spell_target_buttons.clear()

	spell_target_panel.visible = (panel == SpellPanel.TARGETS)

	if panel != SpellPanel.TARGETS or selected_spell == null:
		return

	var is_dead_target := selected_spell.target_type == CharacterEnums.SpellTargetType.DEAD_ALLY

	for member in GameState.party.get_members():
		var btn := Button.new()
		var hp_text := "%d/%d HP" % [member.current_hp, member.max_hp]
		var status := ""
		if member.is_dead:
			status = " [DEAD]"
		btn.text = "%s: %s%s" % [member.character_name, hp_text, status]
		btn.custom_minimum_size = Vector2(200, 28)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var valid_target := false
		if is_dead_target:
			valid_target = member.is_dead
		else:
			valid_target = not member.is_dead

		if not valid_target:
			btn.disabled = true
			btn.modulate = UIColors.MODULATE_DISABLED

		btn.pressed.connect(_on_spell_target_selected.bind(member))
		spell_target_list.add_child(btn)
		spell_target_buttons.append(btn)

	spell_target_nav = MenuNavigator.new()
	spell_target_nav.setup(spell_target_buttons, 0)
	spell_target_nav.update_focus()


func _on_spell_target_selected(target: Character) -> void:
	if selected_spell == null:
		return
	_cast_spell_on_targets(selected_spell, [target])


func _cast_spell_on_targets(spell: Spell, targets: Array) -> void:
	var result := SpellCaster.cast_spell(selected_character, spell, targets, false)
	var msg := "\n".join(result.messages)
	info_label.text = msg

	selected_spell = null
	if panel == SpellPanel.TARGETS:
		panel = SpellPanel.LIST
	refresh()


func _get_living_party_members() -> Array:
	var members: Array = []
	for member in GameState.party.get_members():
		if not member.is_dead:
			members.append(member)
	return members


func _update_spell_info() -> void:
	match panel:
		SpellPanel.PARTY:
			if spell_party_nav and not spell_party_buttons.is_empty():
				var idx := spell_party_nav.get_current_index()
				var members := GameState.party.get_members()
				if idx >= 0 and idx < members.size():
					var m: Character = members[idx]
					var class_name_str := CharacterEnums.get_class_name(m.character_class)
					var spell_count := m.known_spells.size()
					var text := "[b]%s[/b]\nL%d %s\nMP: %d/%d\nKnown spells: %d" % [m.character_name, m.level, class_name_str, m.current_mp, m.max_mp, spell_count]
					if m.is_dead:
						text += "\n[color=red]DEAD[/color]"
					elif m.is_silenced():
						text += "\n[color=yellow]SILENCED - Cannot cast[/color]"
					info_label.text = text
					return
			info_label.text = "Select a party member to view spells."
		SpellPanel.LIST:
			if spell_list_nav and not spell_list_buttons.is_empty():
				var idx := spell_list_nav.get_current_index()
				var spells_at_level: Array = all_spells.get(current_level, [])
				if idx >= 0 and idx < spells_at_level.size():
					var spell: Spell = spells_at_level[idx]
					var text := "[b]%s[/b] (L%d %s)\n" % [spell.name, spell.level, spell.get_school_name()]
					text += "MP Cost: %d  |  Target: %s\n" % [spell.mp_cost, spell.get_target_description()]
					text += "%s" % spell.description
					if not spell.out_of_combat:
						text += "\n[color=gray]Combat only[/color]"
					else:
						var fizzle := SpellValidator.calculate_fizzle_chance(selected_character, spell)
						text += "\nFizzle: %d%%" % int(fizzle)
					info_label.text = text
					return
			info_label.text = "No spells at this level."
		SpellPanel.TARGETS:
			if selected_spell:
				info_label.text = "Select target for [b]%s[/b]." % selected_spell.name


func handle_input(event: InputEvent) -> void:
	var active_nav: MenuNavigator = null
	match panel:
		SpellPanel.PARTY:
			active_nav = spell_party_nav
		SpellPanel.LIST:
			active_nav = spell_list_nav
		SpellPanel.TARGETS:
			active_nav = spell_target_nav

	if active_nav == null:
		return

	active_nav.handle_input(event)


func handle_back() -> bool:
	if panel == SpellPanel.TARGETS:
		panel = SpellPanel.LIST
		selected_spell = null
		refresh()
		return true
	elif panel == SpellPanel.LIST:
		panel = SpellPanel.PARTY
		selected_character = null
		all_spells.clear()
		refresh()
		return true
	return false


func cycle_level(direction: int) -> void:
	var new_level := current_level + direction
	if new_level < 1:
		new_level = 7
	elif new_level > 7:
		new_level = 1
	current_level = new_level
	_refresh_spell_level_tabs()
	_refresh_spell_list()
	_update_spell_info()
