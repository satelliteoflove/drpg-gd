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
var ally_target_mode: String = ""  # "" / "item" / "spell" — on-field ally targeting
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

# --- Battle-stage controls (built in _build_stage) ---
var stage_root: MarginContainer = null
var banner_label: Label = null
var portrait_texture: TextureRect = null
var portrait_name: Label = null
var enemy_grid: GridContainer = null
var back_label: Label = null
var middle_label: Label = null
var front_label: Label = null
var party_front_row: HBoxContainer = null
var party_back_row: HBoxContainer = null
var turn_order_hbox: HBoxContainer = null
var message_log: RichTextLabel = null
var active_char_label: Label = null

var attack_button: Button = null
var defend_button: Button = null
var spell_button: Button = null
var dispel_button: Button = null
var breath_button: Button = null
var item_button: Button = null
var escape_button: Button = null

var _hint_label: Label = null
var _last_device_gamepad: bool = false

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
	_build_stage()
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


## Builds the entire battle stage in code (the .tscn carries only the root +
## the targeting/spell/item modals). Regions, top to bottom: encounter banner,
## a mid row of [enemy tableau | featured portrait], the turn-order ribbon, the
## active-character command bar, the party rail, and a demoted combat log. The
## opaque ArcaneBackdrop sits behind everything so the dungeon no longer bleeds
## through. Assigns every control the controller/display delegates reference.
func _build_stage() -> void:
	var backdrop := ArcaneBackdrop.new()
	backdrop.subdued = true
	add_child(backdrop)
	move_child(backdrop, 0)

	stage_root = MarginContainer.new()
	stage_root.name = "Stage"
	stage_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_root.add_theme_constant_override("margin_left", 22)
	stage_root.add_theme_constant_override("margin_right", 22)
	stage_root.add_theme_constant_override("margin_top", 12)
	stage_root.add_theme_constant_override("margin_bottom", 10)
	add_child(stage_root)
	move_child(stage_root, 1)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	stage_root.add_child(col)

	# --- Encounter banner (spans the full stage width) ---
	var banner := PanelContainer.new()
	var banner_m := MarginContainer.new()
	_pad(banner_m, 12, 4)
	banner.add_child(banner_m)
	banner_label = Label.new()
	banner_label.theme_type_variation = &"HeaderLabel"
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_color_override("font_color", UIColors.TITLE_GOLD)
	banner_label.text = "Battle"
	banner_m.add_child(banner_label)
	col.add_child(banner)

	# --- Body: main column (left, everything) + featured-portrait rail (right) ---
	# Keeping the enemy tableau, turn ribbon, command bar and party rail in ONE
	# column means they all share a single centered axis; the portrait is a
	# dedicated full-height right rail (A3 fills it with live target info).
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	col.add_child(body)

	var main_col := VBoxContainer.new()
	main_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_col.add_theme_constant_override("separation", 5)
	body.add_child(main_col)

	# Enemy tableau.
	var enemy_section := PanelContainer.new()
	enemy_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_col.add_child(enemy_section)
	var enemy_m := MarginContainer.new()
	_pad(enemy_m, 14, 6)
	enemy_section.add_child(enemy_m)
	var enemy_vbox := VBoxContainer.new()
	enemy_vbox.add_theme_constant_override("separation", 6)
	enemy_m.add_child(enemy_vbox)
	enemy_vbox.add_child(_section_header("ENEMIES", UIColors.DANGER))
	var enemy_grid_hbox := HBoxContainer.new()
	enemy_grid_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_grid_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_grid_hbox.add_theme_constant_override("separation", 10)
	enemy_vbox.add_child(enemy_grid_hbox)
	var er_labels := VBoxContainer.new()
	er_labels.custom_minimum_size = Vector2(42, 0)
	er_labels.add_theme_constant_override("separation", 4)
	enemy_grid_hbox.add_child(er_labels)
	back_label = _row_label("Back", UIColors.BACK_ROW)
	middle_label = _row_label("Mid", UIColors.MID_ROW)
	front_label = _row_label("Front", UIColors.FRONT_ROW)
	for rl: Label in [back_label, middle_label, front_label]:
		rl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		er_labels.add_child(rl)
	enemy_grid = GridContainer.new()
	enemy_grid.columns = 3
	enemy_grid.add_theme_constant_override("h_separation", 8)
	enemy_grid.add_theme_constant_override("v_separation", 8)
	enemy_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	enemy_grid_hbox.add_child(enemy_grid)

	# Turn-order ribbon.
	var turn_bar := PanelContainer.new()
	var turn_m := MarginContainer.new()
	_pad(turn_m, 10, 5)
	turn_bar.add_child(turn_m)
	turn_order_hbox = HBoxContainer.new()
	turn_order_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	turn_order_hbox.add_theme_constant_override("separation", 4)
	turn_m.add_child(turn_order_hbox)
	main_col.add_child(turn_bar)

	# Active-character command bar.
	var command_section := PanelContainer.new()
	main_col.add_child(command_section)
	var command_m := MarginContainer.new()
	_pad(command_m, 10, 8)
	command_section.add_child(command_m)
	var command_vbox := VBoxContainer.new()
	command_vbox.add_theme_constant_override("separation", 6)
	command_m.add_child(command_vbox)
	active_char_label = Label.new()
	active_char_label.theme_type_variation = &"SubheaderLabel"
	active_char_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_char_label.add_theme_color_override("font_color", UIColors.TEXT_ACTIVE)
	command_vbox.add_child(active_char_label)
	var action_hbox := HBoxContainer.new()
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_hbox.add_theme_constant_override("separation", 10)
	command_vbox.add_child(action_hbox)
	attack_button = _command_chip("Attack")
	defend_button = _command_chip("Defend")
	spell_button = _command_chip("Spell")
	dispel_button = _command_chip("Dispel")
	breath_button = _command_chip("Breath")
	item_button = _command_chip("Item")
	escape_button = _command_chip("Escape")
	for b: Button in [attack_button, defend_button, spell_button, dispel_button, breath_button, item_button, escape_button]:
		action_hbox.add_child(b)

	# Party rail.
	var party_section := PanelContainer.new()
	main_col.add_child(party_section)
	var party_m := MarginContainer.new()
	_pad(party_m, 12, 8)
	party_section.add_child(party_m)
	var party_vbox := VBoxContainer.new()
	party_vbox.add_theme_constant_override("separation", 5)
	party_m.add_child(party_vbox)
	party_vbox.add_child(_section_header("PARTY", UIColors.INFO))
	var party_grid_hbox := HBoxContainer.new()
	party_grid_hbox.add_theme_constant_override("separation", 8)
	party_vbox.add_child(party_grid_hbox)
	var pr_labels := VBoxContainer.new()
	pr_labels.custom_minimum_size = Vector2(42, 0)
	pr_labels.add_theme_constant_override("separation", 4)
	party_grid_hbox.add_child(pr_labels)
	var pf := _row_label("Front", UIColors.FRONT_ROW)
	pf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pb := _row_label("Back", UIColors.BACK_ROW)
	pb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pr_labels.add_child(pf)
	pr_labels.add_child(pb)
	var party_grid := VBoxContainer.new()
	party_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_grid.add_theme_constant_override("separation", 5)
	party_grid_hbox.add_child(party_grid)
	party_front_row = HBoxContainer.new()
	party_front_row.add_theme_constant_override("separation", 6)
	party_grid.add_child(party_front_row)
	party_back_row = HBoxContainer.new()
	party_back_row.add_theme_constant_override("separation", 6)
	party_grid.add_child(party_back_row)

	# Featured-portrait rail (right; full body height): foe portrait on top, the
	# demoted combat log filling the rail's lower half. Keeping the log here frees
	# the main column to fit the 720px viewport without clipping the party rail.
	var portrait_section := PanelContainer.new()
	portrait_section.custom_minimum_size = Vector2(288, 0)
	portrait_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(portrait_section)
	var portrait_m := MarginContainer.new()
	_pad(portrait_m, 12, 10)
	portrait_section.add_child(portrait_m)
	var portrait_vbox := VBoxContainer.new()
	portrait_vbox.add_theme_constant_override("separation", 6)
	portrait_m.add_child(portrait_vbox)
	portrait_vbox.add_child(_section_header("FOE", UIColors.DANGER))
	portrait_texture = TextureRect.new()
	portrait_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_vbox.add_child(portrait_texture)
	portrait_name = Label.new()
	portrait_name.theme_type_variation = &"SubheaderLabel"
	portrait_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_vbox.add_child(portrait_name)

	portrait_vbox.add_child(_section_header("COMBAT LOG", UIColors.ACCENT))
	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size = Vector2(0, 150)
	log_panel.add_theme_stylebox_override("panel", _log_box())
	portrait_vbox.add_child(log_panel)
	var log_m := MarginContainer.new()
	_pad(log_m, 8, 6)
	log_panel.add_child(log_m)
	message_log = RichTextLabel.new()
	message_log.bbcode_enabled = true
	message_log.scroll_following = true
	message_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_m.add_child(message_log)

	# --- Control-hint footer (adapts to the last input device) ---
	_hint_label = Label.new()
	_hint_label.theme_type_variation = &"MutedLabel"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint_label)
	_update_hint_footer()


func _update_hint_footer() -> void:
	if _hint_label == null:
		return
	if _last_device_gamepad:
		_hint_label.text = "Stick / D-Pad  Navigate      (A) Confirm      (B) Back"
	else:
		_hint_label.text = "h j k l / Arrows  Navigate      Enter Confirm      Esc Back"


func _note_input_device(event: InputEvent) -> void:
	var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	var is_key := event is InputEventKey
	if not is_pad and not is_key:
		return
	if is_pad != _last_device_gamepad:
		_last_device_gamepad = is_pad
		_update_hint_footer()


func _pad(m: MarginContainer, h: int, v: int) -> void:
	m.add_theme_constant_override("margin_left", h)
	m.add_theme_constant_override("margin_right", h)
	m.add_theme_constant_override("margin_top", v)
	m.add_theme_constant_override("margin_bottom", v)


func _section_header(text_value: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text_value
	l.theme_type_variation = &"SubheaderLabel"
	l.add_theme_color_override("font_color", color)
	return l


func _row_label(text_value: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## A command chip: a focusable themed Button whose face carries a title line and
## a smaller sub-line. The sub-line shows the reason an action is unavailable
## ("out of range", "silenced", "no MP", ...) so the player is never left
## guessing why a greyed command does nothing. `_apply_chip` drives its state.
func _command_chip(title: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(110, 46)
	b.clip_text = true
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(vb)
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.add_theme_font_size_override("font_size", 14)
	vb.add_child(title_lbl)
	var sub_lbl := Label.new()
	sub_lbl.visible = false
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", UIColors.TEXT_DANGER)
	vb.add_child(sub_lbl)
	b.set_meta("title_lbl", title_lbl)
	b.set_meta("sub_lbl", sub_lbl)
	return b


## Drive a command chip's enabled/disabled state. A disabled chip stays visible
## (so the player learns the option exists) but is made non-focusable so the
## cursor never lands on a dead command, and it shows the reason inline.
func _apply_chip(b: Button, on: bool, reason: String = "") -> void:
	b.disabled = not on
	b.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	b.modulate = Color.WHITE if on else UIColors.MODULATE_DISABLED
	var title_lbl: Label = b.get_meta("title_lbl")
	var sub_lbl: Label = b.get_meta("sub_lbl")
	title_lbl.add_theme_color_override(
		"font_color", UIColors.TEXT_PRIMARY if on else UIColors.TEXT_DISABLED)
	var show_reason := not on and not reason.is_empty()
	sub_lbl.text = reason if show_reason else ""
	sub_lbl.visible = show_reason


func _log_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.SURFACE_PANEL.darkened(0.15)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = UIColors.BORDER_SUBTLE
	sb.anti_aliasing = true
	return sb


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
	# Horizontal command bar: rely on the themed focus ring (no glide cursor) and
	# don't replay the entrance fade every turn when the bar rebuilds.
	action_nav.use_cursor = false
	action_nav.animate_entrance = false


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

	banner_label.text = "Boss Battle" if is_boss_encounter else "Battle"


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
		if LLMManager.is_available():
			message_log.append_text("[color=#666666]Generating dialogue...[/color]\n")
		var state := {"resolved": false}
		MicroEventSystem.try_micro_event(context_type, GameState.get_party_members(), func(data: Dictionary) -> void:
			if state.resolved:
				return
			state.resolved = true
			if not data.is_empty():
				event_handler.show_micro_event(data)
			else:
				_finish_exit_combat(victory)
		)
		if LLMManager.is_available():
			await get_tree().create_timer(LLMManager.GENERATE_TIMEOUT_SEC).timeout
			if not is_inside_tree():
				return
			if not state.resolved:
				state.resolved = true
				message_log.append_text("[color=#666666]Skipping dialogue.[/color]\n")
				_finish_exit_combat(victory)
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
	ally_target_mode = ""
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


## Refresh the command card for the active character: each chip shows whether
## its action is available and, when not, WHY (inline reason). Dispel and Breath
## are contextual — shown only when the character can use them at all. Only the
## available chips are handed to the navigator, so the cursor never lands on a
## dead command.
func _set_actions_enabled(enabled: bool) -> void:
	var current_char: Character = null
	if enabled and combat_system:
		current_char = _get_character_by_id(combat_system.current_combatant_id)

	# Enemy turn / combat over: every command inert, no reasons, specials hidden.
	if current_char == null:
		for b: Button in action_buttons:
			_apply_chip(b, false)
		dispel_button.visible = false
		breath_button.visible = false
		return

	var party := combat_system.get_party_resource()
	var enemies := combat_system.get_enemies()

	# Attack — needs a reachable foe (range + row + weapon).
	var reachable := Targeting.get_reachable_enemies(current_char, party, enemies)
	_apply_chip(attack_button, not reachable.is_empty(), "out of range")

	# Defend — always available on your turn.
	_apply_chip(defend_button, true)

	# Spell — surface the specific blocker.
	var spell_reason := _spell_disabled_reason(current_char)
	_apply_chip(spell_button, spell_reason.is_empty(), spell_reason)

	# Item — only if the party actually carries something usable.
	var can_item := _has_usable_items()
	_apply_chip(item_button, can_item, "no items")

	# Dispel — a blessing-caster ability; only shown when relevant.
	var can_dispel_char: bool = DispelUndead.can_dispel(current_char)
	dispel_button.visible = can_dispel_char
	if can_dispel_char:
		var has_undead := not DispelUndead.get_valid_targets(combat_system.get_living_enemies()).is_empty()
		_apply_chip(dispel_button, has_undead, "no undead")

	# Breath — a draconic ability; only shown when the character has it.
	var can_breath: bool = current_char.can_use_breath()
	breath_button.visible = can_breath
	if can_breath:
		_apply_chip(breath_button, true)

	# Escape — barred in boss fights.
	_apply_chip(escape_button, not is_boss_encounter, "trapped")

	# Hand only the live commands to the navigator so focus skips the rest.
	var focusable: Array[Button] = []
	for b: Button in action_buttons:
		if b.visible and not b.disabled:
			focusable.append(b)
	if action_nav and not focusable.is_empty():
		action_nav.setup(focusable, 0)


func _spell_disabled_reason(character: Character) -> String:
	if character.is_silenced():
		return "silenced"
	if character.known_spells.is_empty():
		return "no spells"
	var spells_by_level := SpellValidator.get_spells_by_level(character, true)
	for level in spells_by_level:
		for spell in spells_by_level[level]:
			if character.current_mp >= spell.mp_cost:
				return ""
	return "no MP"


func _has_usable_items() -> bool:
	if GameState.party == null or GameState.party.inventory == null:
		return false
	var inv := GameState.party.inventory
	for i in range(inv.size()):
		var item: Item = inv.get_item_at(i)
		if item == null or item.item_type != Item.ItemType.CONSUMABLE:
			continue
		if item.heal_amount > 0 or item.mp_restore > 0 or not item.cures_status.is_empty():
			return true
	return false


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

	_note_input_device(event)

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
