extends Control

signal combat_closed(victory: bool)

const ChestModalScene = preload("res://scenes/combat/chest_modal.tscn")
const EventModalScene = preload("res://scenes/events/event_modal.tscn")
const MicroEventScene = preload("res://scenes/events/micro_event_overlay.tscn")

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
var _status_icon_cache: Dictionary = {}

var combat_system: CombatSystem = null
var selected_item: Item = null
var chest_modal: Control = null
var event_modal: Control = null
var current_chest: Chest = null
var pending_loot: Array[Item] = []
var is_boss_encounter: bool = false
var _pending_event: Dictionary = {}
var available_items: Array[Item] = []
var selected_spell: Spell = null
var current_spell_level: int = 1
var available_spells: Dictionary = {}
var spell_target_mode: String = ""
var dispel_target_mode: bool = false
var breath_target_mode: bool = false
var _input_cooldown: float = 0.0
var _active_panel_tween: Tween = null
var _target_highlight_tween: Tween = null
var _target_highlight_style: StyleBoxFlat = null
var _highlighted_panels: Array[PanelContainer] = []
var _display_dirty: bool = false
var _effect_cache: Dictionary = {}
var _turn_order_entries: Array[PanelContainer] = []

var action_nav: MenuNavigator = null
var item_nav: MenuNavigator = null
var target_nav: MenuNavigator = null
var enemy_target_nav: MenuNavigator = null
var spell_nav: MenuNavigator = null
var spell_level_nav: MenuNavigator = null
var spell_ally_nav: MenuNavigator = null
var action_buttons: Array[Button] = []
var item_buttons: Array[Button] = []
var target_buttons: Array[Button] = []
var enemy_target_buttons: Array[Button] = []
var spell_buttons: Array[Button] = []
var spell_level_buttons: Array[Button] = []
var spell_ally_buttons: Array[Button] = []

var party_panels: Dictionary = {}
var enemy_panels: Dictionary = {}

var spell_level_container: HBoxContainer = null
var spell_ally_modal: PanelContainer = null
var spell_ally_list: VBoxContainer = null


class PartyMemberUI:
	var panel: PanelContainer
	var name_label: Label
	var hp_bar: ProgressBar
	var hp_text: Label
	var mp_bar: ProgressBar
	var mp_text: Label
	var status_label: Label
	var status_icons_hbox: HBoxContainer


class EnemyUI:
	var panel: VBoxContainer
	var name_label: Label
	var hp_bar: ProgressBar
	var hp_text: Label
	var status_label: Label
	var status_icons_hbox: HBoxContainer

@onready var enemy_grid: GridContainer = $MainLayout/EnemySection/EnemyMargin/EnemyVBox/EnemyGridHBox/EnemyGrid
@onready var row_labels: VBoxContainer = $MainLayout/EnemySection/EnemyMargin/EnemyVBox/EnemyGridHBox/RowLabels
@onready var back_label: Label = $MainLayout/EnemySection/EnemyMargin/EnemyVBox/EnemyGridHBox/RowLabels/BackLabel
@onready var middle_label: Label = $MainLayout/EnemySection/EnemyMargin/EnemyVBox/EnemyGridHBox/RowLabels/MiddleLabel
@onready var front_label: Label = $MainLayout/EnemySection/EnemyMargin/EnemyVBox/EnemyGridHBox/RowLabels/FrontLabel
@onready var party_front_row: HBoxContainer = $MainLayout/PartySection/PartyMargin/PartyVBox/PartyGridHBox/PartyGrid/FrontRow
@onready var party_back_row: HBoxContainer = $MainLayout/PartySection/PartyMargin/PartyVBox/PartyGridHBox/PartyGrid/BackRow
@onready var turn_order_hbox: HBoxContainer = $MainLayout/TurnOrderBar/TurnOrderMargin/TurnOrderHBox
@onready var message_log: RichTextLabel = $MainLayout/MessageSection/MessageMargin/MessageLog
@onready var active_char_label: Label = $MainLayout/ActionSection/ActionVBox/ActiveCharLabel

@onready var attack_button: Button = $MainLayout/ActionSection/ActionVBox/ActionHBox/AttackButton
@onready var defend_button: Button = $MainLayout/ActionSection/ActionVBox/ActionHBox/DefendButton
@onready var spell_button: Button = $MainLayout/ActionSection/ActionVBox/ActionHBox/SpellButton
@onready var dispel_button: Button = $MainLayout/ActionSection/ActionVBox/ActionHBox/DispelButton
@onready var breath_button: Button = $MainLayout/ActionSection/ActionVBox/ActionHBox/BreathButton
@onready var item_button: Button = $MainLayout/ActionSection/ActionVBox/ActionHBox/ItemButton
@onready var escape_button: Button = $MainLayout/ActionSection/ActionVBox/ActionHBox/EscapeButton

@onready var modal_overlay: ColorRect = $ModalOverlay
@onready var item_modal: PanelContainer = $ItemModal
@onready var item_list: VBoxContainer = $ItemModal/ItemModalVBox/ItemScrollContainer/ItemList
@onready var item_cancel_button: Button = $ItemModal/ItemModalVBox/ItemCancelButton
@onready var spell_modal: PanelContainer = $SpellModal
@onready var spell_list: VBoxContainer = $SpellModal/SpellModalVBox/SpellScrollContainer/SpellList
@onready var spell_cancel_button: Button = $SpellModal/SpellModalVBox/SpellCancelButton
@onready var target_modal: PanelContainer = $TargetModal
@onready var target_list: VBoxContainer = $TargetModal/TargetModalVBox/TargetList
@onready var target_cancel_button: Button = $TargetModal/TargetModalVBox/TargetCancelButton
@onready var enemy_target_modal: PanelContainer = $EnemyTargetModal
@onready var enemy_target_list: VBoxContainer = $EnemyTargetModal/EnemyTargetModalVBox/EnemyTargetScrollContainer/EnemyTargetList
@onready var enemy_target_cancel_button: Button = $EnemyTargetModal/EnemyTargetModalVBox/EnemyTargetCancelButton


func _process(delta: float) -> void:
	if _input_cooldown > 0.0:
		_input_cooldown -= delta


func _ready() -> void:
	attack_button.pressed.connect(_on_attack_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	spell_button.pressed.connect(_on_spell_pressed)
	dispel_button.pressed.connect(_on_dispel_pressed)
	breath_button.pressed.connect(_on_breath_pressed)
	item_button.pressed.connect(_on_item_pressed)
	escape_button.pressed.connect(_on_escape_pressed)
	item_cancel_button.pressed.connect(_on_cancel_item)
	spell_cancel_button.pressed.connect(_on_cancel_spell)
	target_cancel_button.pressed.connect(_on_cancel_target)
	enemy_target_cancel_button.pressed.connect(_on_cancel_enemy_target)

	_setup_action_nav()
	_setup_spell_level_tabs()
	_setup_spell_ally_modal()
	_set_actions_enabled(false)
	_start_combat()


func _setup_action_nav() -> void:
	action_buttons = [attack_button, defend_button, spell_button, dispel_button, breath_button, item_button, escape_button]
	action_nav = MenuNavigator.new()
	action_nav.setup(action_buttons, 0)


func _setup_spell_level_tabs() -> void:
	var spell_vbox := spell_modal.get_node("SpellModalVBox")
	var _header := spell_vbox.get_node("SpellModalHeader")

	spell_level_container = HBoxContainer.new()
	spell_level_container.alignment = BoxContainer.ALIGNMENT_CENTER
	spell_level_container.add_theme_constant_override("separation", 4)
	spell_vbox.add_child(spell_level_container)
	spell_vbox.move_child(spell_level_container, 1)

	for i in range(1, 8):
		var btn := Button.new()
		btn.text = "L%d" % i
		btn.custom_minimum_size = Vector2(40, 28)
		btn.toggle_mode = true
		btn.pressed.connect(_on_spell_level_changed.bind(i))
		spell_level_container.add_child(btn)
		spell_level_buttons.append(btn)

	if not spell_level_buttons.is_empty():
		spell_level_buttons[0].button_pressed = true


func _setup_spell_ally_modal() -> void:
	spell_ally_modal = PanelContainer.new()
	spell_ally_modal.visible = false
	spell_ally_modal.custom_minimum_size = Vector2(300, 250)
	spell_ally_modal.set_anchors_preset(Control.PRESET_CENTER)
	spell_ally_modal.offset_left = -150
	spell_ally_modal.offset_top = -125
	spell_ally_modal.offset_right = 150
	spell_ally_modal.offset_bottom = 125
	add_child(spell_ally_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	spell_ally_modal.add_child(vbox)

	var header := Label.new()
	header.text = "Select Target"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 16)
	vbox.add_child(header)

	spell_ally_list = VBoxContainer.new()
	spell_ally_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spell_ally_list)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_cancel_spell_ally_target)
	vbox.add_child(cancel_btn)


func _start_combat() -> void:
	var encounter: Dictionary = GameState.current_encounter
	if encounter.is_empty():
		push_error("No encounter data found")
		combat_closed.emit(false)
		return

	var encounter_enemies: Array = encounter.get("enemies", [])
	if encounter_enemies.is_empty():
		var single_monster: Monster = encounter.get("monster")
		if single_monster != null:
			single_monster.grid_position = Vector2i(1, 0)
			encounter_enemies = [single_monster]

	if encounter_enemies.is_empty():
		push_error("No enemies in encounter")
		combat_closed.emit(false)
		return

	var typed_enemies: Array[Monster] = []
	for e in encounter_enemies:
		typed_enemies.append(e as Monster)

	if GameState.party == null:
		push_error("No party found")
		combat_closed.emit(false)
		return

	is_boss_encounter = encounter.get("is_boss", false)

	combat_system = CombatSystem.new()
	combat_system.is_boss_encounter = is_boss_encounter
	combat_system.turn_started.connect(_on_turn_started)
	combat_system.action_performed.connect(_on_action_performed)
	combat_system.combat_ended.connect(_on_combat_ended)
	combat_system.target_selection_requested.connect(_on_target_selection_requested)
	combat_system.monster_turn_delay_requested.connect(_on_monster_turn_delay)
	combat_system.layout_changed.connect(_on_layout_changed)

	combat_system.start_combat(GameState.party, typed_enemies)
	GameState.party_member_died.connect(_on_party_member_died_in_combat)
	_build_enemy_display()
	_build_party_display()
	_update_display()


func _build_enemy_display() -> void:
	var children := enemy_grid.get_children()
	for child in children:
		enemy_grid.remove_child(child)
		child.queue_free()
	enemy_panels.clear()

	if combat_system == null:
		return

	var enemy_grid_map: Dictionary = {}
	var occupied_rows: Array[int] = []
	for enemy in combat_system.get_enemies():
		var pos := enemy.grid_position
		enemy_grid_map[pos] = enemy
		if not occupied_rows.has(pos.y):
			occupied_rows.append(pos.y)
	occupied_rows.sort()

	var row_labels_list: Array[Label] = [front_label, middle_label, back_label]
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
				enemy_panels[enemy.combat_id] = ui
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

			enemy_grid.add_child(cell)


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


func _create_enemy_panel(enemy: Monster) -> EnemyUI:
	var ui := EnemyUI.new()

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


func _build_party_display() -> void:
	for child in party_front_row.get_children():
		child.queue_free()
	for child in party_back_row.get_children():
		child.queue_free()
	party_panels.clear()

	if combat_system == null:
		return

	var party := combat_system.get_party_resource()
	var front := party.get_front_row()
	var back := party.get_back_row()

	for character in front:
		var ui := _create_party_member_panel(character, true)
		party_panels[character.id] = ui
		party_front_row.add_child(ui.panel)

	for i in range(3 - front.size()):
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(150, 0)
		party_front_row.add_child(spacer)

	for character in back:
		var ui := _create_party_member_panel(character, false)
		party_panels[character.id] = ui
		party_back_row.add_child(ui.panel)

	for i in range(3 - back.size()):
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(150, 0)
		party_back_row.add_child(spacer)


func _create_party_member_panel(character: Character, _is_front: bool) -> PartyMemberUI:
	var ui := PartyMemberUI.new()

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


func _update_display() -> void:
	if combat_system == null:
		return

	_update_enemy_display()
	_update_party_stats()
	_update_turn_order()


func _schedule_display_update() -> void:
	if not _display_dirty:
		_display_dirty = true
		_deferred_update_display.call_deferred()


func _deferred_update_display() -> void:
	_display_dirty = false
	_update_display()


func _on_layout_changed() -> void:
	_effect_cache.clear()
	_build_enemy_display()
	_build_party_display()


func _update_enemy_display() -> void:
	for enemy in combat_system.get_enemies():
		if not enemy_panels.has(enemy.combat_id):
			continue

		var ui: EnemyUI = enemy_panels[enemy.combat_id]

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
	var living_front := Targeting.get_living_front_row(combat_system.get_enemies())
	var row_labels_list: Array[Label] = [front_label, middle_label, back_label]
	for i in range(3):
		if not row_labels_list[i].visible:
			continue
		var has_living := false
		for enemy in combat_system.get_enemies():
			if not enemy.is_dead and enemy.grid_position.y == i:
				has_living = true
				break
		if not has_living:
			row_labels_list[i].add_theme_color_override("font_color", UIColors.TEXT_DISABLED)
		elif i == living_front:
			row_labels_list[i].add_theme_color_override("font_color", UIColors.TEXT_STATUS)
		else:
			row_labels_list[i].remove_theme_color_override("font_color")


func _update_party_stats() -> void:
	for character in combat_system.get_party():
		if not party_panels.has(character.id):
			continue

		var ui: PartyMemberUI = party_panels[character.id]

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

		var is_active := combat_system.current_combatant_id == character.id and combat_system.is_player_turn()
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
			if _active_panel_tween:
				_active_panel_tween.kill()
			_active_panel_tween = create_tween().set_loops()
			_active_panel_tween.tween_property(active_style, "border_color:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
			_active_panel_tween.tween_property(active_style, "border_color:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
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
	if combat_system == null or combat_system.initiative == null:
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
		var is_current: bool = (entry_id == combat_system.current_combatant_id)
		var is_player: bool = entry.is_player

		if is_player:
			var character := _get_character_by_id(entry.id)
			if character:
				name_text = character.get_display_name()
		else:
			var enemy := _get_enemy_by_combat_id(entry.id)
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
			turn_order_hbox.add_child(panel)
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
		active_char_label.text = "%s's Turn:" % current_name
	else:
		active_char_label.text = ""


func _get_sorted_turn_order() -> Array:
	if combat_system == null or combat_system.initiative == null:
		return []

	var entries: Array = []
	for entry in combat_system.initiative.combatants:
		entries.append(entry)

	entries.sort_custom(func(a, b): return a.ticks < b.ticks)
	return entries


func _get_character_by_id(id: String) -> Character:
	for character in combat_system.get_party():
		if character.id == id:
			return character
	return null


func _get_enemy_by_combat_id(combat_id: String) -> Monster:
	for enemy in combat_system.get_enemies():
		if enemy.combat_id == combat_id:
			return enemy
	return null


func _on_turn_started(_combatant_id: String, is_player: bool) -> void:
	_set_actions_enabled(is_player)
	if is_player:
		_input_cooldown = 0.15
	_schedule_display_update()


func _on_monster_turn_delay(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if combat_system and combat_system.is_active:
		combat_system.execute_delayed_monster_turn()


func _on_action_performed(message: String) -> void:
	message_log.append_text("[color=#aaaaaa]>[/color] " + message + "\n")
	_schedule_display_update()


func _on_party_member_died_in_combat(character: Resource) -> void:
	var living: Array[Character] = []
	for c in combat_system.get_party():
		if not c.is_dead and c.id != character.id:
			living.append(c)
	if living.is_empty():
		return

	var reactor: Character = living[randi() % living.size()]
	var fallen_name: String = character.character_name
	var reactor_name: String = reactor.character_name

	MicroEventSystem._ensure_loaded()
	var line := MicroEventSystem._get_fallback("ally_fallen", reactor)
	if line == "":
		line = "No!"
	message_log.append_text("[color=cyan]%s:[/color] \"%s\"\n" % [reactor_name, line])


func _on_combat_ended(victory: bool, exp_gained: int, gold_gained: int, loot: Array[Item]) -> void:
	_set_actions_enabled(false)
	GameState.end_combat(victory)

	if victory and GameState.party != null:
		GameState.party.distribute_experience(exp_gained)
		GameState.party.distribute_gold(gold_gained)

		var floor_num: int = GameState.current_floor if GameState.current_floor > 0 else 1
		var new_marks := MarkSystem.evaluate_post_combat(
			combat_system.get_party(),
			combat_system.enemies,
			is_boss_encounter,
			floor_num,
			GameState.game_day,
			combat_system.combat_log
		)
		for entry in new_marks:
			entry.character.add_mark(entry.mark)

		var rel_mods := MarkSystem.evaluate_relationships(
			combat_system.get_party(),
			combat_system.enemies,
			is_boss_encounter,
			floor_num,
			combat_system.combat_log
		)
		for mod in rel_mods:
			RelationshipManager.add_modifier(
				mod.id_a, mod.id_b, mod.source, mod.weight, GameState.game_day
			)

		var dead_count := 0
		for c in combat_system.get_party():
			if c.is_dead:
				dead_count += 1
		var event_context := {
			"party": combat_system.get_party(),
			"floor": floor_num,
			"day": GameState.game_day,
			"is_boss": is_boss_encounter,
			"dead_count": dead_count,
		}
		_pending_event = EventManager.check_for_event("post_combat", event_context)

		_show_victory_summary(exp_gained, gold_gained, [], [])

		if not loot.is_empty():
			pending_loot = loot
			if not is_boss_encounter:
				is_boss_encounter = GameState.current_encounter.get("is_boss", false)
			await get_tree().create_timer(1.0).timeout
			_show_chest_modal()
			return

	await get_tree().create_timer(1.5).timeout
	_exit_combat(victory)


func _exit_combat(victory: bool) -> void:
	if not _pending_event.is_empty():
		_show_event_modal(_pending_event)
		_pending_event = {}
		return
	if victory and GameState.party != null:
		var dead_count := 0
		for c in combat_system.get_party():
			if c.is_dead:
				dead_count += 1
		var context_type := "combat_close_call" if dead_count > 0 else "combat_victory"
		MicroEventSystem.try_micro_event(context_type, GameState.get_party_members(), func(data: Dictionary) -> void:
			if not data.is_empty():
				_show_micro_event(data)
			else:
				_finish_exit_combat(victory)
		)
		return
	_finish_exit_combat(victory)


func _finish_exit_combat(victory: bool) -> void:
	if GameState.party_member_died.is_connected(_on_party_member_died_in_combat):
		GameState.party_member_died.disconnect(_on_party_member_died_in_combat)
	if _active_panel_tween:
		_active_panel_tween.kill()
		_active_panel_tween = null
	if combat_closed.get_connections().size() > 0:
		combat_closed.emit(victory)
	else:
		if victory:
			SceneManager.go_to_dungeon()
		else:
			var all_dead := true
			for character in combat_system.get_party():
				if not character.is_dead:
					all_dead = false
					break
			if all_dead:
				SceneManager.go_to_town()
			else:
				SceneManager.go_to_dungeon()


func _show_micro_event(data: Dictionary) -> void:
	$MainLayout.visible = false
	var overlay: CanvasLayer = MicroEventScene.instantiate()
	add_child(overlay)
	overlay.setup(data, GameState.get_party_members())
	overlay.micro_event_closed.connect(func() -> void:
		$MainLayout.visible = true
		_finish_exit_combat(true)
	)


func _show_chest_modal() -> void:
	current_chest = ChestSystem.create_chest_from_loot(pending_loot, is_boss_encounter)

	chest_modal = ChestModalScene.instantiate()
	add_child(chest_modal)
	chest_modal.chest_resolved.connect(_on_chest_resolved)
	chest_modal.combat_triggered.connect(_on_chest_combat_triggered)
	chest_modal.setup(current_chest, GameState.party)

	modal_overlay.visible = true
	chest_modal.visible = true


func _on_chest_resolved(items: Array[Item], left_behind: bool) -> void:
	_cleanup_chest_modal()

	if left_behind:
		message_log.append_text("[color=yellow]You left the chest behind.[/color]\n")
	elif not items.is_empty():
		message_log.append_text("[color=cyan]Items collected:[/color]\n")
		for item in items:
			message_log.append_text("  - %s\n" % item.get_display_name())

	await get_tree().create_timer(1.0).timeout
	_exit_combat(true)


func _on_chest_combat_triggered() -> void:
	_cleanup_chest_modal()
	message_log.append_text("[color=red]An alarm sounds! More enemies approach![/color]\n")

	await get_tree().create_timer(1.0).timeout

	var encounter_data := _generate_alarm_encounter()
	GameState.current_encounter = encounter_data
	_start_combat()


func _generate_alarm_encounter() -> Dictionary:
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


func _cleanup_chest_modal() -> void:
	modal_overlay.visible = false
	if chest_modal:
		chest_modal.queue_free()
		chest_modal = null
	current_chest = null
	pending_loot.clear()
	is_boss_encounter = false


func _show_event_modal(event_data: Dictionary) -> void:
	$MainLayout.visible = false

	var root: Control = EventModalScene.instantiate()
	add_child(root)
	event_modal = root.get_node("EventModal")
	event_modal.event_resolved.connect(_on_event_resolved)

	var floor_num: int = GameState.current_floor if GameState.current_floor > 0 else 1
	var event_context := {
		"floor": floor_num,
		"day": GameState.game_day,
	}
	event_modal.setup(event_data.template, event_data.cast, event_context)


func _on_event_resolved(_choice_id: String) -> void:
	_cleanup_event_modal()
	_finish_exit_combat(true)


func _cleanup_event_modal() -> void:
	if event_modal:
		var root := event_modal.get_parent().get_parent()
		root.queue_free()
		event_modal = null


func _show_victory_summary(xp: int, gold: int, items_added: Array[Item], items_left: Array[Item]) -> void:
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

	message_log.append_text(summary)


func _on_target_selection_requested(reachable_enemies: Array[Monster]) -> void:
	_close_all_modals()
	_set_actions_enabled(false)
	_populate_enemy_target_list(reachable_enemies)
	modal_overlay.visible = true
	enemy_target_modal.visible = true

	if enemy_target_nav and not enemy_target_buttons.is_empty():
		enemy_target_nav.setup(enemy_target_buttons, 0)


func _populate_enemy_target_list(reachable_enemies: Array[Monster]) -> void:
	for child in enemy_target_list.get_children():
		child.queue_free()
	enemy_target_buttons.clear()

	for enemy in reachable_enemies:
		var btn := Button.new()
		var row_names: Array[String] = ["Front", "Middle", "Back"]
		var row_label: String = row_names[enemy.get_row()]
		btn.text = "%s (%s Row) - %d/%d HP" % [
			enemy.monster_name,
			row_label,
			enemy.current_hp,
			enemy.max_hp
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_enemy_target_selected.bind(enemy))
		btn.focus_entered.connect(_highlight_enemy_target.bind(enemy))
		enemy_target_list.add_child(btn)
		enemy_target_buttons.append(btn)

	enemy_target_nav = MenuNavigator.new()
	if not enemy_target_buttons.is_empty():
		enemy_target_nav.setup(enemy_target_buttons, 0)


func _on_enemy_target_selected(enemy: Monster) -> void:
	_close_all_modals()
	combat_system.player_attack(enemy)


func _on_cancel_enemy_target() -> void:
	if dispel_target_mode:
		dispel_target_mode = false
		_close_all_modals()
		_set_actions_enabled(true)
	elif breath_target_mode:
		breath_target_mode = false
		_close_all_modals()
		_set_actions_enabled(true)
	elif spell_target_mode in ["enemy", "splash", "row", "column"]:
		_close_all_modals()
		modal_overlay.visible = true
		spell_modal.visible = true
		selected_spell = null
		spell_target_mode = ""
		if spell_nav and not spell_buttons.is_empty():
			spell_nav.setup(spell_buttons, 0)
	else:
		_close_all_modals()
		combat_system.cancel_target_selection()
		_set_actions_enabled(true)


func _on_attack_pressed() -> void:
	if combat_system and combat_system.is_player_turn():
		combat_system.player_attack()


func _on_defend_pressed() -> void:
	if combat_system and combat_system.is_player_turn():
		combat_system.player_defend()


func _on_spell_pressed() -> void:
	if not combat_system or not combat_system.is_player_turn():
		return

	var caster := _get_character_by_id(combat_system.current_combatant_id)
	if caster == null:
		return

	if caster.is_silenced():
		message_log.append_text("[color=#aaaaaa]>[/color] %s is silenced and cannot cast spells!\n" % caster.get_display_name())
		return

	if caster.known_spells.is_empty():
		message_log.append_text("[color=#aaaaaa]>[/color] %s doesn't know any spells.\n" % caster.get_display_name())
		return

	available_spells = SpellValidator.get_spells_by_level(caster, true)

	var has_any_spells := false
	for level in available_spells:
		if not available_spells[level].is_empty():
			has_any_spells = true
			break

	if not has_any_spells:
		message_log.append_text("[color=#aaaaaa]>[/color] %s has no combat spells available.\n" % caster.get_display_name())
		return

	current_spell_level = _get_first_available_spell_level()
	_update_spell_level_buttons()
	_populate_spell_list_for_level(current_spell_level)

	_close_all_modals()
	_set_actions_enabled(false)
	modal_overlay.visible = true
	spell_modal.visible = true

	if spell_nav and not spell_buttons.is_empty():
		spell_nav.setup(spell_buttons, 0)


func _on_escape_pressed() -> void:
	if combat_system and combat_system.is_player_turn():
		combat_system.player_escape()


func _on_dispel_pressed() -> void:
	if not combat_system or not combat_system.is_player_turn():
		return

	var character := _get_character_by_id(combat_system.current_combatant_id)
	if character == null or not DispelUndead.can_dispel(character):
		return

	var undead_targets := DispelUndead.get_valid_targets(combat_system.get_living_enemies())
	if undead_targets.is_empty():
		message_log.append_text("[color=#aaaaaa]>[/color] No undead to dispel.\n")
		return

	_close_all_modals()
	_set_actions_enabled(false)
	for child in enemy_target_list.get_children():
		child.queue_free()
	enemy_target_buttons.clear()

	for enemy in undead_targets:
		var btn := Button.new()
		var row_names: Array[String] = ["Front", "Middle", "Back"]
		var row_label: String = row_names[enemy.get_row()]
		var chance := int(DispelUndead.calculate_success_chance(character.level, enemy.level) * 100)
		btn.text = "%s (%s Row) - %d%% chance" % [
			enemy.monster_name,
			row_label,
			chance
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_dispel_target_selected.bind(enemy))
		btn.focus_entered.connect(_highlight_enemy_target.bind(enemy))
		enemy_target_list.add_child(btn)
		enemy_target_buttons.append(btn)

	enemy_target_nav = MenuNavigator.new()
	if not enemy_target_buttons.is_empty():
		enemy_target_nav.setup(enemy_target_buttons, 0)

	dispel_target_mode = true
	modal_overlay.visible = true
	enemy_target_modal.visible = true


func _on_dispel_target_selected(enemy: Monster) -> void:
	_close_all_modals()
	dispel_target_mode = false
	combat_system.player_dispel(enemy)


func _on_breath_pressed() -> void:
	if not combat_system or not combat_system.is_player_turn():
		return

	var character := _get_character_by_id(combat_system.current_combatant_id)
	if character == null or not character.can_use_breath():
		return

	if character.is_breath_aoe():
		combat_system.player_breath()
		return

	var living := combat_system.get_living_enemies()
	_close_all_modals()
	_set_actions_enabled(false)
	for child in enemy_target_list.get_children():
		child.queue_free()
	enemy_target_buttons.clear()

	for enemy in living:
		var btn := Button.new()
		var row_names: Array[String] = ["Front", "Middle", "Back"]
		var row_label: String = row_names[enemy.get_row()]
		btn.text = "%s (%s Row) - %d HP" % [enemy.monster_name, row_label, enemy.current_hp]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_breath_target_selected.bind(enemy))
		btn.focus_entered.connect(_highlight_enemy_target.bind(enemy))
		enemy_target_list.add_child(btn)
		enemy_target_buttons.append(btn)

	enemy_target_nav = MenuNavigator.new()
	if not enemy_target_buttons.is_empty():
		enemy_target_nav.setup(enemy_target_buttons, 0)

	breath_target_mode = true
	modal_overlay.visible = true
	enemy_target_modal.visible = true


func _on_breath_target_selected(enemy: Monster) -> void:
	_close_all_modals()
	breath_target_mode = false
	combat_system.player_breath(enemy)


func _on_item_pressed() -> void:
	if not combat_system or not combat_system.is_player_turn():
		return

	_populate_item_list()
	if available_items.is_empty():
		message_log.append_text("[color=#aaaaaa]>[/color] No usable items!\n")
		return

	_close_all_modals()
	_set_actions_enabled(false)
	modal_overlay.visible = true
	item_modal.visible = true

	if item_nav and not item_buttons.is_empty():
		item_nav.setup(item_buttons, 0)


func _populate_item_list() -> void:
	for child in item_list.get_children():
		child.queue_free()
	available_items.clear()
	item_buttons.clear()

	if GameState.party == null or GameState.party.inventory == null:
		return

	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		var qty: int = GameState.party.inventory.get_quantity_at(i)
		if item == null:
			continue
		if item.item_type != Item.ItemType.CONSUMABLE:
			continue
		if item.heal_amount <= 0 and item.mp_restore <= 0 and item.cures_status.is_empty():
			continue

		if not available_items.has(item):
			available_items.append(item)
			var btn := Button.new()
			btn.text = "%s x%d" % [item.item_name, qty]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.custom_minimum_size = Vector2(0, 32)
			btn.pressed.connect(_on_item_selected.bind(item))
			item_list.add_child(btn)
			item_buttons.append(btn)

	item_nav = MenuNavigator.new()
	if not item_buttons.is_empty():
		item_nav.setup(item_buttons, 0)


func _on_item_selected(item: Item) -> void:
	selected_item = item
	item_modal.visible = false
	_populate_target_list()
	target_modal.visible = true

	if target_nav and not target_buttons.is_empty():
		target_nav.setup(target_buttons, 0)


func _populate_target_list() -> void:
	for child in target_list.get_children():
		child.queue_free()
	target_buttons.clear()

	if combat_system == null:
		return

	for character in combat_system.get_party():
		var btn := Button.new()
		var status := ""
		if character.is_dead:
			status = " [DEAD]"
		btn.text = "%s: %d/%d HP%s" % [
			character.get_display_name(),
			character.current_hp,
			character.max_hp,
			status
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)

		var can_use := _can_use_item_on(selected_item, character)
		if not can_use:
			btn.disabled = true
			btn.modulate = UIColors.MODULATE_DISABLED

		btn.pressed.connect(_on_target_selected.bind(character))
		btn.focus_entered.connect(_highlight_party_target.bind(character))
		target_list.add_child(btn)
		target_buttons.append(btn)

	target_nav = MenuNavigator.new()
	if not target_buttons.is_empty():
		target_nav.setup(target_buttons, 0)


func _can_use_item_on(item: Item, character: Character) -> bool:
	if character.is_dead:
		return false

	if item.heal_amount > 0 and character.current_hp < character.max_hp:
		return true

	if item.mp_restore > 0 and character.current_mp < character.max_mp:
		return true

	for status in item.cures_status:
		if character.has_status(status):
			return true

	return false


func _on_target_selected(character: Character) -> void:
	if selected_item == null:
		return

	_close_all_modals()

	var current_char := _get_character_by_id(combat_system.current_combatant_id)
	var user_name := current_char.get_display_name() if current_char else "Party"

	var message := "%s uses %s on %s. " % [
		user_name,
		selected_item.item_name,
		character.get_display_name()
	]

	if selected_item.heal_amount > 0:
		var healed := character.heal(selected_item.heal_amount)
		message += "Restored %d HP. " % healed

	if selected_item.mp_restore > 0:
		var restored := character.restore_mp(selected_item.mp_restore)
		message += "Restored %d MP. " % restored

	for status in selected_item.cures_status:
		if character.has_status(status):
			character.remove_status(status)
			message += "Cured %s. " % _get_status_name(status)

	GameState.party.inventory.remove_item(selected_item.id, 1)
	message_log.append_text("[color=#aaaaaa]>[/color] " + message + "\n")

	selected_item = null

	if combat_system:
		combat_system.end_player_turn()


func _get_status_name(status) -> String:
	match status:
		CharacterEnums.StatusEffect.POISONED: return "Poison"
		CharacterEnums.StatusEffect.PARALYZED: return "Paralysis"
		CharacterEnums.StatusEffect.ASLEEP: return "Sleep"
		CharacterEnums.StatusEffect.CONFUSED: return "Confusion"
		CharacterEnums.StatusEffect.SILENCED: return "Silence"
		CharacterEnums.StatusEffect.BLINDED: return "Blindness"
		_: return "status"


func _get_first_available_spell_level() -> int:
	for level in range(1, 8):
		if available_spells.has(level) and not available_spells[level].is_empty():
			return level
	return 1


func _update_spell_level_buttons() -> void:
	for i in range(spell_level_buttons.size()):
		var level := i + 1
		var btn := spell_level_buttons[i]
		btn.button_pressed = (level == current_spell_level)

		var has_spells: bool = available_spells.has(level) and not available_spells[level].is_empty()
		btn.disabled = not has_spells
		btn.modulate = Color.WHITE if has_spells else UIColors.MODULATE_DISABLED


func _on_spell_level_changed(level: int) -> void:
	if not available_spells.has(level) or available_spells[level].is_empty():
		_update_spell_level_buttons()
		return

	current_spell_level = level
	_update_spell_level_buttons()
	_populate_spell_list_for_level(level)


func _navigate_spell_level(direction: int) -> void:
	var new_level := current_spell_level + direction

	while new_level >= 1 and new_level <= 7:
		if available_spells.has(new_level) and not available_spells[new_level].is_empty():
			_on_spell_level_changed(new_level)
			return
		new_level += direction


func _populate_spell_list_for_level(level: int) -> void:
	for child in spell_list.get_children():
		child.queue_free()
	spell_buttons.clear()

	var caster := _get_character_by_id(combat_system.current_combatant_id)
	if caster == null:
		return

	var spells: Array = available_spells.get(level, [])

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
		spell_list.add_child(btn)
		spell_buttons.append(btn)

	spell_nav = MenuNavigator.new()
	if not spell_buttons.is_empty():
		var first_enabled := 0
		for i in range(spell_buttons.size()):
			if not spell_buttons[i].disabled:
				first_enabled = i
				break
		spell_nav.setup(spell_buttons, first_enabled)


func _on_spell_selected(spell: Spell) -> void:
	var caster := _get_character_by_id(combat_system.current_combatant_id)
	if caster == null or caster.current_mp < spell.mp_cost:
		return

	selected_spell = spell
	spell_modal.visible = false

	match spell.target_type:
		CharacterEnums.SpellTargetType.SELF:
			_cast_spell_on_targets([caster])
		CharacterEnums.SpellTargetType.SINGLE_ALLY:
			spell_target_mode = "ally"
			_populate_spell_ally_target_list(false)
		CharacterEnums.SpellTargetType.SINGLE_ENEMY:
			spell_target_mode = "enemy"
			_populate_spell_enemy_target_list()
		CharacterEnums.SpellTargetType.ALL_ALLIES:
			var targets := combat_system.get_valid_ally_targets(false)
			var typed_targets: Array = []
			for t in targets:
				typed_targets.append(t)
			_cast_spell_on_targets(typed_targets)
		CharacterEnums.SpellTargetType.ALL_ENEMIES:
			var targets := combat_system.get_living_enemies()
			var typed_targets: Array = []
			for t in targets:
				typed_targets.append(t)
			_cast_spell_on_targets(typed_targets)
		CharacterEnums.SpellTargetType.DEAD_ALLY:
			spell_target_mode = "dead"
			_populate_spell_ally_target_list(true)
		CharacterEnums.SpellTargetType.SPLASH:
			spell_target_mode = "splash"
			_populate_spell_splash_target_list()
		CharacterEnums.SpellTargetType.ROW:
			spell_target_mode = "row"
			_populate_spell_row_target_list()
		CharacterEnums.SpellTargetType.COLUMN:
			spell_target_mode = "column"
			_populate_spell_column_target_list()
		_:
			_cast_spell_on_targets([caster])


func _populate_spell_ally_target_list(dead_only: bool) -> void:
	for child in spell_ally_list.get_children():
		child.queue_free()
	spell_ally_buttons.clear()

	var targets: Array[Character]
	if dead_only:
		targets = combat_system.get_dead_allies()
	else:
		targets = combat_system.get_valid_ally_targets(false)

	if targets.is_empty():
		var no_target_msg := "No valid targets available"
		if dead_only:
			no_target_msg = "No dead allies to resurrect"
		message_log.append_text("[color=#aaaaaa]>[/color] %s\n" % no_target_msg)
		_close_all_modals()
		_set_actions_enabled(true)
		selected_spell = null
		return

	for character in targets:
		var btn := Button.new()
		var status := ""
		if character.is_dead:
			status = " [DEAD]"
		btn.text = "%s: %d/%d HP%s" % [
			character.get_display_name(),
			character.current_hp,
			character.max_hp,
			status
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_spell_ally_target_selected.bind(character))
		btn.focus_entered.connect(_highlight_party_target.bind(character))
		spell_ally_list.add_child(btn)
		spell_ally_buttons.append(btn)

	spell_ally_nav = MenuNavigator.new()
	if not spell_ally_buttons.is_empty():
		spell_ally_nav.setup(spell_ally_buttons, 0)

	spell_ally_modal.visible = true


func _populate_spell_enemy_target_list() -> void:
	var enemies := combat_system.get_living_enemies()

	if enemies.is_empty():
		message_log.append_text("[color=#aaaaaa]>[/color] No enemies to target!\n")
		_close_all_modals()
		_set_actions_enabled(true)
		selected_spell = null
		return

	for child in enemy_target_list.get_children():
		child.queue_free()
	enemy_target_buttons.clear()

	for enemy in enemies:
		var btn := Button.new()
		var row_names: Array[String] = ["Front", "Middle", "Back"]
		var row_label: String = row_names[enemy.get_row()]
		btn.text = "%s (%s Row) - %d/%d HP" % [
			enemy.monster_name,
			row_label,
			enemy.current_hp,
			enemy.max_hp
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_spell_enemy_target_selected.bind(enemy))
		btn.focus_entered.connect(_highlight_enemy_target.bind(enemy))
		enemy_target_list.add_child(btn)
		enemy_target_buttons.append(btn)

	enemy_target_nav = MenuNavigator.new()
	if not enemy_target_buttons.is_empty():
		enemy_target_nav.setup(enemy_target_buttons, 0)

	enemy_target_modal.visible = true


func _on_spell_ally_target_selected(character: Character) -> void:
	_cast_spell_on_targets([character])


func _on_spell_enemy_target_selected(enemy: Monster) -> void:
	if spell_target_mode == "splash":
		var targets := combat_system.get_splash_targets(enemy)
		var typed_targets: Array = []
		for t in targets:
			typed_targets.append(t)
		_cast_spell_on_targets(typed_targets)
	else:
		_cast_spell_on_targets([enemy])


func _populate_spell_splash_target_list() -> void:
	var enemies := combat_system.get_living_enemies()

	if enemies.is_empty():
		message_log.append_text("[color=#aaaaaa]>[/color] No enemies to target!\n")
		_close_all_modals()
		_set_actions_enabled(true)
		selected_spell = null
		return

	for child in enemy_target_list.get_children():
		child.queue_free()
	enemy_target_buttons.clear()

	for enemy in enemies:
		var btn := Button.new()
		var splash_targets := combat_system.get_splash_targets(enemy)
		var row_names: Array[String] = ["Front", "Middle", "Back"]
		var row_label: String = row_names[enemy.get_row()]
		btn.text = "%s (%s) - hits %d enemies" % [
			enemy.monster_name,
			row_label,
			splash_targets.size()
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_spell_enemy_target_selected.bind(enemy))
		btn.focus_entered.connect(_highlight_enemy_targets.bind(splash_targets))
		enemy_target_list.add_child(btn)
		enemy_target_buttons.append(btn)

	enemy_target_nav = MenuNavigator.new()
	if not enemy_target_buttons.is_empty():
		enemy_target_nav.setup(enemy_target_buttons, 0)

	enemy_target_modal.visible = true


func _populate_spell_row_target_list() -> void:
	var available_rows := combat_system.get_available_rows()

	if available_rows.is_empty():
		message_log.append_text("[color=#aaaaaa]>[/color] No enemies to target!\n")
		_close_all_modals()
		_set_actions_enabled(true)
		selected_spell = null
		return

	for child in enemy_target_list.get_children():
		child.queue_free()
	enemy_target_buttons.clear()

	var row_names: Array[String] = ["Front Row", "Middle Row", "Back Row"]

	for row in available_rows:
		var btn := Button.new()
		var row_targets := combat_system.get_row_targets(row)
		btn.text = "%s - %d enemies" % [row_names[row], row_targets.size()]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_spell_row_selected.bind(row))
		btn.focus_entered.connect(_highlight_enemy_targets.bind(row_targets))
		enemy_target_list.add_child(btn)
		enemy_target_buttons.append(btn)

	enemy_target_nav = MenuNavigator.new()
	if not enemy_target_buttons.is_empty():
		enemy_target_nav.setup(enemy_target_buttons, 0)

	enemy_target_modal.visible = true


func _on_spell_row_selected(row: int) -> void:
	var targets := combat_system.get_row_targets(row)
	var typed_targets: Array = []
	for t in targets:
		typed_targets.append(t)
	_cast_spell_on_targets(typed_targets)


func _populate_spell_column_target_list() -> void:
	var available_cols := combat_system.get_available_columns()

	if available_cols.is_empty():
		message_log.append_text("[color=#aaaaaa]>[/color] No enemies to target!\n")
		_close_all_modals()
		_set_actions_enabled(true)
		selected_spell = null
		return

	for child in enemy_target_list.get_children():
		child.queue_free()
	enemy_target_buttons.clear()

	var col_names: Array[String] = ["Left Column", "Center Column", "Right Column"]

	for col in available_cols:
		var btn := Button.new()
		var col_targets := combat_system.get_column_targets(col)
		btn.text = "%s - %d enemies" % [col_names[col], col_targets.size()]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_spell_column_selected.bind(col))
		btn.focus_entered.connect(_highlight_enemy_targets.bind(col_targets))
		enemy_target_list.add_child(btn)
		enemy_target_buttons.append(btn)

	enemy_target_nav = MenuNavigator.new()
	if not enemy_target_buttons.is_empty():
		enemy_target_nav.setup(enemy_target_buttons, 0)

	enemy_target_modal.visible = true


func _on_spell_column_selected(col: int) -> void:
	var targets := combat_system.get_column_targets(col)
	var typed_targets: Array = []
	for t in targets:
		typed_targets.append(t)
	_cast_spell_on_targets(typed_targets)


func _cast_spell_on_targets(targets: Array) -> void:
	if selected_spell == null:
		_close_all_modals()
		_set_actions_enabled(true)
		return

	_close_all_modals()
	combat_system.player_cast_spell(selected_spell.id, targets)
	selected_spell = null
	spell_target_mode = ""


func _on_cancel_spell_ally_target() -> void:
	_close_all_modals()
	modal_overlay.visible = true
	spell_modal.visible = true
	selected_spell = null
	spell_target_mode = ""

	if spell_nav and not spell_buttons.is_empty():
		spell_nav.setup(spell_buttons, 0)


func _on_cancel_item() -> void:
	_close_all_modals()
	_set_actions_enabled(true)


func _on_cancel_spell() -> void:
	selected_spell = null
	spell_target_mode = ""
	_close_all_modals()
	_set_actions_enabled(true)


func _on_cancel_target() -> void:
	_close_all_modals()
	modal_overlay.visible = true
	item_modal.visible = true
	selected_item = null


func _close_all_modals() -> void:
	_clear_target_highlights()
	modal_overlay.visible = false
	item_modal.visible = false
	spell_modal.visible = false
	target_modal.visible = false
	enemy_target_modal.visible = false
	if spell_ally_modal:
		spell_ally_modal.visible = false
	if chest_modal:
		chest_modal.visible = false


func _highlight_enemy_target(enemy: Monster) -> void:
	_clear_target_highlights()
	if not enemy_panels.has(enemy.combat_id):
		return
	var ui: EnemyUI = enemy_panels[enemy.combat_id]
	var panel: VBoxContainer = ui.panel
	var cell: PanelContainer = panel.get_parent()
	_target_highlight_style = StyleBoxFlat.new()
	_target_highlight_style.bg_color = Color.TRANSPARENT
	_target_highlight_style.border_color = UIColors.TEXT_DANGER
	_target_highlight_style.border_width_left = 2
	_target_highlight_style.border_width_top = 2
	_target_highlight_style.border_width_right = 2
	_target_highlight_style.border_width_bottom = 2
	_target_highlight_style.corner_radius_top_left = 4
	_target_highlight_style.corner_radius_top_right = 4
	_target_highlight_style.corner_radius_bottom_left = 4
	_target_highlight_style.corner_radius_bottom_right = 4
	cell.add_theme_stylebox_override("panel", _target_highlight_style)
	_highlighted_panels.append(cell)
	if _target_highlight_tween:
		_target_highlight_tween.kill()
	_target_highlight_tween = create_tween().set_loops()
	_target_highlight_tween.tween_property(_target_highlight_style, "border_color:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
	_target_highlight_tween.tween_property(_target_highlight_style, "border_color:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


func _highlight_enemy_targets(enemies: Array[Monster]) -> void:
	_clear_target_highlights()
	_target_highlight_style = StyleBoxFlat.new()
	_target_highlight_style.bg_color = Color.TRANSPARENT
	_target_highlight_style.border_color = UIColors.TEXT_DANGER
	_target_highlight_style.border_width_left = 2
	_target_highlight_style.border_width_top = 2
	_target_highlight_style.border_width_right = 2
	_target_highlight_style.border_width_bottom = 2
	_target_highlight_style.corner_radius_top_left = 4
	_target_highlight_style.corner_radius_top_right = 4
	_target_highlight_style.corner_radius_bottom_left = 4
	_target_highlight_style.corner_radius_bottom_right = 4
	for enemy in enemies:
		if not enemy_panels.has(enemy.combat_id):
			continue
		var ui: EnemyUI = enemy_panels[enemy.combat_id]
		var cell: PanelContainer = ui.panel.get_parent()
		cell.add_theme_stylebox_override("panel", _target_highlight_style)
		_highlighted_panels.append(cell)
	if _highlighted_panels.is_empty():
		return
	if _target_highlight_tween:
		_target_highlight_tween.kill()
	_target_highlight_tween = create_tween().set_loops()
	_target_highlight_tween.tween_property(_target_highlight_style, "border_color:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
	_target_highlight_tween.tween_property(_target_highlight_style, "border_color:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


func _highlight_party_target(character: Character) -> void:
	_clear_target_highlights()
	if not party_panels.has(character.id):
		return
	var ui: PartyMemberUI = party_panels[character.id]
	_target_highlight_style = StyleBoxFlat.new()
	_target_highlight_style.bg_color = Color.TRANSPARENT
	_target_highlight_style.border_color = UIColors.TEXT_DANGER
	_target_highlight_style.border_width_left = 2
	_target_highlight_style.border_width_top = 2
	_target_highlight_style.border_width_right = 2
	_target_highlight_style.border_width_bottom = 2
	_target_highlight_style.corner_radius_top_left = 4
	_target_highlight_style.corner_radius_top_right = 4
	_target_highlight_style.corner_radius_bottom_left = 4
	_target_highlight_style.corner_radius_bottom_right = 4
	ui.panel.add_theme_stylebox_override("panel", _target_highlight_style)
	_highlighted_panels.append(ui.panel)
	if _target_highlight_tween:
		_target_highlight_tween.kill()
	_target_highlight_tween = create_tween().set_loops()
	_target_highlight_tween.tween_property(_target_highlight_style, "border_color:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
	_target_highlight_tween.tween_property(_target_highlight_style, "border_color:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


func _clear_target_highlights() -> void:
	if _target_highlight_tween:
		_target_highlight_tween.kill()
		_target_highlight_tween = null
	for panel in _highlighted_panels:
		if is_instance_valid(panel):
			panel.remove_theme_stylebox_override("panel")
	_highlighted_panels.clear()
	_target_highlight_style = null


func _set_actions_enabled(enabled: bool) -> void:
	var can_attack := enabled
	var can_cast := enabled
	var can_dispel := false
	var can_breath := false
	if enabled and combat_system:
		var current_char := _get_character_by_id(combat_system.current_combatant_id)
		if current_char:
			var party := combat_system.get_party_resource()
			var enemies := combat_system.get_enemies()
			var reachable := Targeting.get_reachable_enemies(current_char, party, enemies)
			can_attack = not reachable.is_empty()
			can_cast = _can_character_cast_spells(current_char)
			can_dispel = DispelUndead.can_dispel(current_char) and \
				not DispelUndead.get_valid_targets(combat_system.get_living_enemies()).is_empty()
			can_breath = current_char.can_use_breath()

	attack_button.disabled = not can_attack
	if not can_attack and enabled:
		attack_button.modulate = UIColors.MODULATE_DISABLED
	else:
		attack_button.modulate = Color.WHITE

	defend_button.disabled = not enabled
	spell_button.disabled = not can_cast
	if not can_cast and enabled:
		spell_button.modulate = UIColors.MODULATE_DISABLED
	else:
		spell_button.modulate = Color.WHITE
	dispel_button.disabled = not can_dispel
	if not can_dispel and enabled:
		dispel_button.modulate = UIColors.MODULATE_DISABLED
	else:
		dispel_button.modulate = Color.WHITE
	breath_button.disabled = not can_breath
	if not can_breath and enabled:
		breath_button.modulate = UIColors.MODULATE_DISABLED
	else:
		breath_button.modulate = Color.WHITE
	item_button.disabled = not enabled
	if is_boss_encounter:
		escape_button.disabled = true
		escape_button.modulate = UIColors.MODULATE_DISABLED
	else:
		escape_button.disabled = not enabled

	if enabled and action_nav:
		var start_index := _get_first_available_action_index(can_attack, can_cast, can_dispel)
		action_nav.setup(action_buttons, start_index)


func _can_character_cast_spells(character: Character) -> bool:
	if character.is_silenced():
		return false
	if character.known_spells.is_empty():
		return false
	var spells_by_level := SpellValidator.get_spells_by_level(character, true)
	for level in spells_by_level:
		for spell in spells_by_level[level]:
			if character.current_mp >= spell.mp_cost:
				return true
	return false


func _get_first_available_action_index(can_attack: bool, can_cast: bool, can_dispel: bool) -> int:
	if can_attack:
		return 0
	if can_cast:
		return 2
	if can_dispel:
		return 3
	return 1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_win"):
		_debug_win_combat()
		return

	if _input_cooldown > 0.0:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				if combat_system and combat_system.is_active:
					_debug_win_with_ornate_chest()
					return
			KEY_2:
				if combat_system and combat_system.is_active:
					_debug_win_with_alarm_trap()
					return
			KEY_3:
				if combat_system and combat_system.is_active:
					_debug_win_with_poison_trap()
					return

	if chest_modal and chest_modal.visible:
		return

	if enemy_target_modal.visible:
		if event.is_action_pressed("menu_cancel"):
			_on_cancel_enemy_target()
		elif enemy_target_nav:
			if event.is_action_pressed("menu_up"):
				enemy_target_nav._move(-1)
			elif event.is_action_pressed("menu_down"):
				enemy_target_nav._move(1)
			elif event.is_action_pressed("menu_confirm"):
				enemy_target_nav._confirm()
		return

	if item_modal.visible:
		if event.is_action_pressed("menu_cancel"):
			_on_cancel_item()
		elif item_nav:
			if event.is_action_pressed("menu_up"):
				item_nav._move(-1)
			elif event.is_action_pressed("menu_down"):
				item_nav._move(1)
			elif event.is_action_pressed("menu_confirm"):
				item_nav._confirm()
		return

	if target_modal.visible:
		if event.is_action_pressed("menu_cancel"):
			_on_cancel_target()
		elif target_nav:
			if event.is_action_pressed("menu_up"):
				target_nav._move(-1)
			elif event.is_action_pressed("menu_down"):
				target_nav._move(1)
			elif event.is_action_pressed("menu_confirm"):
				target_nav._confirm()
		return

	if spell_ally_modal and spell_ally_modal.visible:
		if event.is_action_pressed("menu_cancel"):
			_on_cancel_spell_ally_target()
		elif spell_ally_nav:
			if event.is_action_pressed("menu_up"):
				spell_ally_nav._move(-1)
			elif event.is_action_pressed("menu_down"):
				spell_ally_nav._move(1)
			elif event.is_action_pressed("menu_confirm"):
				spell_ally_nav._confirm()
		return

	if spell_modal.visible:
		if event.is_action_pressed("menu_cancel"):
			_on_cancel_spell()
		elif event.is_action_pressed("menu_left"):
			_navigate_spell_level(-1)
		elif event.is_action_pressed("menu_right"):
			_navigate_spell_level(1)
		elif spell_nav:
			if event.is_action_pressed("menu_up"):
				spell_nav._move(-1)
			elif event.is_action_pressed("menu_down"):
				spell_nav._move(1)
			elif event.is_action_pressed("menu_confirm"):
				spell_nav._confirm()
		return

	if action_nav and not defend_button.disabled:
		if event.is_action_pressed("menu_left"):
			action_nav._move(-1)
		elif event.is_action_pressed("menu_right"):
			action_nav._move(1)
		elif event.is_action_pressed("menu_confirm"):
			action_nav._confirm()


func _debug_win_combat() -> void:
	if not combat_system:
		return
	for enemy in combat_system.get_enemies():
		enemy.current_hp = 0
		enemy.is_dead = true
	combat_system._check_combat_end()


func _debug_win_with_ornate_chest() -> void:
	if not combat_system:
		return
	is_boss_encounter = true
	message_log.append_text("[color=gray][DEBUG] Forcing ornate chest...[/color]\n")
	_debug_win_combat()


func _debug_win_with_alarm_trap() -> void:
	if not combat_system:
		return
	message_log.append_text("[color=gray][DEBUG] Forcing alarm trap...[/color]\n")
	for enemy in combat_system.get_enemies():
		enemy.current_hp = 0
		enemy.is_dead = true

	var alarm_trap := TrapDatabase.get_trap("alarm")
	var loot: Array[Item] = []
	var test_item := Item.new()
	test_item.id = "debug_item"
	test_item.item_name = "Debug Treasure"
	test_item.item_type = Item.ItemType.CONSUMABLE
	loot.append(test_item)

	pending_loot = loot
	is_boss_encounter = false
	current_chest = Chest.create(Chest.ChestType.PLAIN, loot, alarm_trap)

	_set_actions_enabled(false)
	GameState.end_combat(true)
	GameState.party.distribute_experience(10)
	_show_victory_summary(10, 0, [], [])
	await get_tree().create_timer(1.0).timeout
	_show_forced_chest_modal()


func _debug_win_with_poison_trap() -> void:
	if not combat_system:
		return
	message_log.append_text("[color=gray][DEBUG] Forcing poison needle trap...[/color]\n")
	for enemy in combat_system.get_enemies():
		enemy.current_hp = 0
		enemy.is_dead = true

	var poison_trap := TrapDatabase.get_trap("poison_needle")
	var loot: Array[Item] = []
	var test_item := Item.new()
	test_item.id = "debug_item"
	test_item.item_name = "Debug Treasure"
	test_item.item_type = Item.ItemType.CONSUMABLE
	loot.append(test_item)

	pending_loot = loot
	is_boss_encounter = false
	current_chest = Chest.create(Chest.ChestType.PLAIN, loot, poison_trap)

	_set_actions_enabled(false)
	GameState.end_combat(true)
	GameState.party.distribute_experience(10)
	_show_victory_summary(10, 0, [], [])
	await get_tree().create_timer(1.0).timeout
	_show_forced_chest_modal()


func _show_forced_chest_modal() -> void:
	chest_modal = ChestModalScene.instantiate()
	add_child(chest_modal)
	chest_modal.chest_resolved.connect(_on_chest_resolved)
	chest_modal.combat_triggered.connect(_on_chest_combat_triggered)
	chest_modal.setup(current_chest, GameState.party)

	modal_overlay.visible = true
	chest_modal.visible = true
