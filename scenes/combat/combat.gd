extends Control

signal combat_closed(victory: bool)

const ChestModalScene = preload("res://scenes/combat/chest_modal.tscn")
const EventModalScene = preload("res://scenes/events/event_modal.tscn")
const MicroEventScene = preload("res://scenes/events/micro_event_overlay.tscn")

var combat_system: CombatSystem = null
var selected_item: Item = null
var chest_modal: Control = null
var event_modal: Control = null
var current_chest: Chest = null
var pending_loot: Array[Item] = []
var is_boss_encounter: bool = false
var _pending_event: Dictionary = {}
var _pregenerated_dialogue: String = ""
var _dialogue_ready := false
var _dialogue_prefiring := false
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
var _grid_target_buttons: Array[Button] = []

var action_nav: MenuNavigator = null
var item_nav: MenuNavigator = null
var target_nav: MenuNavigator = null
var enemy_target_nav: GridNavigator = null
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

var display: CombatDisplay = null
var targeting: CombatTargetingUI = null
var chest_handler: CombatChestHandler = null
var event_handler: CombatEventHandler = null
var item_handler: CombatItemHandler = null
var spell_handler: CombatSpellHandler = null


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

@onready var portrait_texture: TextureRect = $MainLayout/PortraitSection/PortraitMargin/PortraitVBox/PortraitTexture
@onready var portrait_name: Label = $MainLayout/PortraitSection/PortraitMargin/PortraitVBox/PortraitName
@onready var enemy_grid: GridContainer = $MainLayout/RightColumn/EnemySection/EnemyMargin/EnemyVBox/EnemyGridHBox/EnemyGrid
@onready var row_labels: VBoxContainer = $MainLayout/RightColumn/EnemySection/EnemyMargin/EnemyVBox/EnemyGridHBox/RowLabels
@onready var back_label: Label = $MainLayout/RightColumn/EnemySection/EnemyMargin/EnemyVBox/EnemyGridHBox/RowLabels/BackLabel
@onready var middle_label: Label = $MainLayout/RightColumn/EnemySection/EnemyMargin/EnemyVBox/EnemyGridHBox/RowLabels/MiddleLabel
@onready var front_label: Label = $MainLayout/RightColumn/EnemySection/EnemyMargin/EnemyVBox/EnemyGridHBox/RowLabels/FrontLabel
@onready var party_front_row: HBoxContainer = $MainLayout/RightColumn/PartySection/PartyMargin/PartyVBox/PartyGridHBox/PartyGrid/FrontRow
@onready var party_back_row: HBoxContainer = $MainLayout/RightColumn/PartySection/PartyMargin/PartyVBox/PartyGridHBox/PartyGrid/BackRow
@onready var turn_order_hbox: HBoxContainer = $MainLayout/RightColumn/TurnOrderBar/TurnOrderMargin/TurnOrderHBox
@onready var message_log: RichTextLabel = $MainLayout/RightColumn/MessageSection/MessageMargin/MessageLog
@onready var active_char_label: Label = $MainLayout/RightColumn/ActionSection/ActionVBox/ActiveCharLabel

@onready var attack_button: Button = $MainLayout/RightColumn/ActionSection/ActionVBox/ActionHBox/AttackButton
@onready var defend_button: Button = $MainLayout/RightColumn/ActionSection/ActionVBox/ActionHBox/DefendButton
@onready var spell_button: Button = $MainLayout/RightColumn/ActionSection/ActionVBox/ActionHBox/SpellButton
@onready var dispel_button: Button = $MainLayout/RightColumn/ActionSection/ActionVBox/ActionHBox/DispelButton
@onready var breath_button: Button = $MainLayout/RightColumn/ActionSection/ActionVBox/ActionHBox/BreathButton
@onready var item_button: Button = $MainLayout/RightColumn/ActionSection/ActionVBox/ActionHBox/ItemButton
@onready var escape_button: Button = $MainLayout/RightColumn/ActionSection/ActionVBox/ActionHBox/EscapeButton

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
		if _input_cooldown <= 0.0:
			set_process(false)


func _ready() -> void:
	set_process(false)
	_init_delegates()

	attack_button.pressed.connect(_on_attack_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	spell_button.pressed.connect(spell_handler.on_spell_pressed)
	dispel_button.pressed.connect(spell_handler.on_dispel_pressed)
	breath_button.pressed.connect(spell_handler.on_breath_pressed)
	item_button.pressed.connect(item_handler.on_item_pressed)
	escape_button.pressed.connect(_on_escape_pressed)
	item_cancel_button.pressed.connect(_on_cancel_item)
	spell_cancel_button.pressed.connect(spell_handler.on_cancel_spell)
	target_cancel_button.pressed.connect(_on_cancel_target)
	enemy_target_cancel_button.pressed.connect(targeting.on_cancel_enemy_target)

	display.style_modal(spell_modal)
	display.style_modal(item_modal)

	_setup_action_nav()
	_setup_spell_level_tabs()
	_setup_spell_ally_modal()
	_set_actions_enabled(false)
	_start_combat()


func _init_delegates() -> void:
	display = CombatDisplay.new()
	display.init(self)
	targeting = CombatTargetingUI.new()
	targeting.init(self)
	chest_handler = CombatChestHandler.new()
	chest_handler.init(self)
	event_handler = CombatEventHandler.new()
	event_handler.init(self)
	item_handler = CombatItemHandler.new()
	item_handler.init(self)
	spell_handler = CombatSpellHandler.new()
	spell_handler.init(self)


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
		btn.pressed.connect(spell_handler.on_spell_level_changed.bind(i))
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
	cancel_btn.pressed.connect(spell_handler.on_cancel_spell_ally_target)
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
	combat_system.target_selection_requested.connect(targeting.on_target_selection_requested)
	combat_system.monster_turn_delay_requested.connect(_on_monster_turn_delay)
	combat_system.layout_changed.connect(display.on_layout_changed)

	combat_system.start_combat(GameState.party, typed_enemies)
	GameState.party_member_died.connect(_on_party_member_died_in_combat)
	display.build_enemy_display()
	display.build_party_display()
	display.update_display()


func _on_turn_started(_combatant_id: String, is_player: bool) -> void:
	_set_actions_enabled(is_player)
	if is_player:
		_input_cooldown = 0.15
		set_process(true)
	display.schedule_display_update()


func _on_monster_turn_delay(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree(): return
	if combat_system and combat_system.is_active:
		combat_system.execute_delayed_monster_turn()


func _on_action_performed(message: String) -> void:
	message_log.append_text("[color=#aaaaaa]>[/color] " + message + "\n")
	display.schedule_display_update()


func _on_party_member_died_in_combat(character: Resource) -> void:
	var living: Array[Character] = []
	for c in combat_system.get_party():
		if not c.is_dead and c.id != character.id:
			living.append(c)
	if living.is_empty():
		return

	var reactor: Character = living[randi() % living.size()]
	var reactor_name: String = reactor.character_name

	MicroEventSystem._ensure_loaded()
	var line := MicroEventSystem._get_fallback("ally_fallen", reactor)
	if line == "":
		line = "No!"
	var reaction_text := "[color=cyan]%s:[/color] \"%s\"\n" % [reactor_name, line]
	message_log.call_deferred("append_text", reaction_text)


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
		event_handler.pregenerate_event_dialogue()

		display.show_victory_summary(exp_gained, gold_gained, [], [])

		if not loot.is_empty():
			pending_loot = loot
			if not is_boss_encounter:
				is_boss_encounter = GameState.current_encounter.get("is_boss", false)
			await get_tree().create_timer(1.0).timeout
			if not is_inside_tree(): return
			chest_handler.show_chest_modal()
			return

	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree(): return
	_exit_combat(victory)


func _exit_combat(victory: bool) -> void:
	if not _pending_event.is_empty():
		event_handler.show_event_modal(_pending_event)
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
				event_handler.show_micro_event(data)
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


func _on_attack_pressed() -> void:
	if combat_system and combat_system.is_player_turn():
		combat_system.player_attack()


func _on_defend_pressed() -> void:
	if combat_system and combat_system.is_player_turn():
		combat_system.player_defend()


func _on_escape_pressed() -> void:
	if combat_system and combat_system.is_player_turn():
		combat_system.player_escape()


func _on_cancel_item() -> void:
	_close_all_modals()
	_set_actions_enabled(true)


func _on_cancel_target() -> void:
	_close_all_modals()
	item_modal.visible = true
	selected_item = null


func _close_all_modals() -> void:
	targeting.clear_target_highlights()
	targeting.clear_grid_target_buttons()
	modal_overlay.visible = false
	item_modal.visible = false
	spell_modal.visible = false
	target_modal.visible = false
	enemy_target_modal.visible = false
	if spell_ally_modal:
		spell_ally_modal.visible = false
	if chest_modal:
		chest_modal.visible = false


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
					chest_handler.debug_win_with_ornate_chest()
					return
			KEY_2:
				if combat_system and combat_system.is_active:
					chest_handler.debug_win_with_alarm_trap()
					return
			KEY_3:
				if combat_system and combat_system.is_active:
					chest_handler.debug_win_with_poison_trap()
					return

	if chest_modal and chest_modal.visible:
		return

	if not _grid_target_buttons.is_empty():
		if event.is_action_pressed("menu_cancel"):
			targeting.on_cancel_enemy_target()
		elif enemy_target_nav:
			enemy_target_nav.handle_input(event)
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
			spell_handler.on_cancel_spell_ally_target()
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
			spell_handler.on_cancel_spell()
		elif event.is_action_pressed("menu_left"):
			spell_handler.navigate_spell_level(-1)
		elif event.is_action_pressed("menu_right"):
			spell_handler.navigate_spell_level(1)
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
