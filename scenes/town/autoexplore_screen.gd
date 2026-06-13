extends Control

var nav: MenuNavigator = null
var nav_buttons: Array[Button] = []

var selected_floor: int = 1
var num_encounters: int = 5
var include_boss: bool = true
var return_encounters: int = 2
var num_dives: int = 5
var death_threshold: int = 0
var strategy: PartyAI.Strategy = PartyAI.Strategy.BALANCED
var current_tab: int = 0
var last_batch_results: Array[Dictionary] = []
var last_batch_summary: Dictionary = {}
var last_rewards: Dictionary = {}
var is_running: bool = false
var _narrative_log: Array[Dictionary] = []
var _sim_day: int = 0

var floor_buttons: Array[Button] = []
var strategy_buttons: Array[Button] = []
var boss_toggle: Button = null
var run_button: Button = null

var _scaffold: ScreenScaffold = null
var _steppers: Array[Button] = []
var _party_subtitle: Label = null

@onready var title_label: Label = $MainHBox/LeftPanel/Header/TitleLabel
@onready var party_info_label: Label = $MainHBox/LeftPanel/Header/PartyInfoLabel
@onready var config_panel: PanelContainer = $MainHBox/LeftPanel/ConfigPanel
@onready var config_list: VBoxContainer = $MainHBox/LeftPanel/ConfigPanel/ScrollContainer/ConfigList
@onready var message_label: Label = $MainHBox/LeftPanel/MessageLabel
@onready var help_label: Label = $MainHBox/LeftPanel/HelpLabel
@onready var back_button: Button = $MainHBox/LeftPanel/BackButton
@onready var tab_bar: TabBar = $MainHBox/RightPanel/TabBar
@onready var results_label: RichTextLabel = $MainHBox/RightPanel/ResultsPanel/ScrollContainer/ResultsLabel


func _ready() -> void:
	_install_scaffold()
	tab_bar.tab_changed.connect(_on_tab_changed)
	_populate_config()
	_update_party_info()
	_update_help()


## Wrap in the shared scaffold and hide the legacy in-panel header / help / back.
func _install_scaffold() -> void:
	var bg := get_node_or_null("Background")
	if bg != null:
		bg.queue_free()

	$MainHBox/LeftPanel/Header.visible = false
	help_label.visible = false
	back_button.visible = false

	var main: Control = $MainHBox
	remove_child(main)
	_scaffold = ScreenScaffold.create({"title": "AUTOEXPLORE", "hint": ""})
	add_child(_scaffold)
	move_child(_scaffold, 0)
	_scaffold.body.add_child(main)
	_scaffold.back_pressed.connect(_on_back_pressed)


func _update_party_info() -> void:
	if _party_subtitle == null:
		return
	if not GameState.has_party():
		_party_subtitle.text = "No party assembled"
		return
	var members := GameState.party.get_members()
	var avg_level := GameState.party.get_average_level()
	_party_subtitle.text = "Simulating with %d members · Avg Level %d" % [members.size(), avg_level]


func _populate_config() -> void:
	for child in config_list.get_children():
		child.queue_free()
	nav_buttons.clear()
	floor_buttons.clear()
	strategy_buttons.clear()
	_steppers.clear()

	_party_subtitle = Label.new()
	_party_subtitle.theme_type_variation = &"SubtitleLabel"
	_party_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	config_list.add_child(_party_subtitle)

	if not GameState.has_party():
		var label := Label.new()
		label.theme_type_variation = &"MutedLabel"
		label.text = "Assemble a party at the Guild Hall first."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		config_list.add_child(label)
		message_label.text = "No party available."
		nav = MenuNavigator.new()
		return

	selected_floor = clampi(GameState.current_floor, 1, 6)

	_add_section("Floor Level")
	var floor_row := HBoxContainer.new()
	floor_row.add_theme_constant_override("separation", 4)
	for i in range(1, 7):
		var btn := Button.new()
		btn.text = str(i)
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 34)
		btn.button_pressed = (i == selected_floor)
		_style_segment(btn)
		btn.pressed.connect(_on_floor_selected.bind(i))
		floor_row.add_child(btn)
		floor_buttons.append(btn)
		nav_buttons.append(btn)
	config_list.add_child(floor_row)

	_add_section("Strategy")
	var strat_row := HBoxContainer.new()
	strat_row.add_theme_constant_override("separation", 4)
	for cfg in [
		{"name": "Aggressive", "value": PartyAI.Strategy.AGGRESSIVE},
		{"name": "Balanced", "value": PartyAI.Strategy.BALANCED},
		{"name": "Defensive", "value": PartyAI.Strategy.DEFENSIVE},
	]:
		var btn := Button.new()
		btn.text = cfg["name"]
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 34)
		var strat_val: PartyAI.Strategy = cfg["value"] as PartyAI.Strategy
		btn.button_pressed = (strat_val == strategy)
		_style_segment(btn)
		btn.pressed.connect(_on_strategy_selected.bind(strat_val))
		strat_row.add_child(btn)
		strategy_buttons.append(btn)
		nav_buttons.append(btn)
	config_list.add_child(strat_row)

	_add_section("Run Parameters")
	nav_buttons.append(_make_stepper("Encounters", 1, 8, num_encounters,
		func(v: int) -> void: num_encounters = v))
	nav_buttons.append(_make_stepper("Return Encounters", 0, 4, return_encounters,
		func(v: int) -> void: return_encounters = v))
	nav_buttons.append(_make_stepper("Number of Runs", 1, 10, num_dives,
		func(v: int) -> void: num_dives = v))
	nav_buttons.append(_make_stepper("Stop on Deaths", 0, 6, death_threshold,
		func(v: int) -> void: death_threshold = v, "Never"))

	boss_toggle = _make_toggle("Include Boss", include_boss,
		func(v: bool) -> void: include_boss = v)
	nav_buttons.append(boss_toggle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	config_list.add_child(spacer)

	run_button = Button.new()
	run_button.theme_type_variation = &"PrimaryButton"
	run_button.text = "▶  Run AutoExplore"
	run_button.custom_minimum_size = Vector2(0, 46)
	run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_button.pressed.connect(_on_run_pressed)
	config_list.add_child(run_button)
	nav_buttons.append(run_button)

	nav = MenuNavigator.new()
	nav.setup(nav_buttons, 0)


func _add_section(text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"SubheaderLabel"
	label.text = text
	config_list.add_child(label)


# --- Themed config controls -------------------------------------------------

func _style_segment(btn: Button) -> void:
	var flat := StyleBoxFlat.new()
	flat.bg_color = UIColors.SURFACE_BACKGROUND
	flat.set_corner_radius_all(6)
	flat.content_margin_top = 7
	flat.content_margin_bottom = 7
	var hover := flat.duplicate() as StyleBoxFlat
	hover.bg_color = UIColors.SURFACE_HOVER
	var active := flat.duplicate() as StyleBoxFlat
	active.bg_color = UIColors.SURFACE_CARD
	active.border_width_bottom = 3
	active.border_color = UIColors.ACCENT
	var focus := active.duplicate() as StyleBoxFlat
	focus.set_border_width_all(2)
	focus.border_color = UIColors.BORDER_FOCUS
	focus.shadow_color = UIColors.ACCENT_GLOW
	focus.shadow_size = 4
	btn.add_theme_stylebox_override("normal", flat)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", active)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", UIColors.TEXT_PRIMARY)


## A keyboard-navigable numeric stepper: a focusable row showing "Label  ‹ N ›".
## Left/Right adjusts it when focused (handled in _unhandled_input).
func _make_stepper(label_text: String, min_v: int, max_v: int, initial: int,
		cb: Callable, zero_label: String = "") -> Button:
	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 38)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.set_meta("min", min_v)
	btn.set_meta("max", max_v)
	btn.set_meta("val", initial)
	btn.set_meta("label", label_text)
	btn.set_meta("cb", cb)
	btn.set_meta("zero", zero_label)
	_style_row(btn)
	_refresh_stepper_text(btn)
	config_list.add_child(btn)
	_steppers.append(btn)
	return btn


func _refresh_stepper_text(btn: Button) -> void:
	var v: int = btn.get_meta("val")
	var zero: String = btn.get_meta("zero")
	var val_str := zero if (v == 0 and zero != "") else str(v)
	btn.text = "%s          ‹   %s   ›" % [btn.get_meta("label"), val_str]


func _adjust_stepper(btn: Button, dir: int) -> void:
	var v: int = clampi(btn.get_meta("val") + dir, btn.get_meta("min"), btn.get_meta("max"))
	if v == btn.get_meta("val"):
		return
	btn.set_meta("val", v)
	_refresh_stepper_text(btn)
	(btn.get_meta("cb") as Callable).call(v)


func _make_toggle(label_text: String, initial: bool, cb: Callable) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = initial
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 38)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.set_meta("label", label_text)
	_style_row(btn)
	_refresh_toggle_text(btn)
	btn.toggled.connect(func(v: bool) -> void:
		_refresh_toggle_text(btn)
		cb.call(v))
	config_list.add_child(btn)
	return btn


func _refresh_toggle_text(btn: Button) -> void:
	var on := btn.button_pressed
	btn.text = "%s          %s" % [btn.get_meta("label"), "●  On" if on else "○  Off"]
	btn.add_theme_color_override("font_color",
		UIColors.TEXT_HEALTHY if on else UIColors.TEXT_MUTED)


func _style_row(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = UIColors.SURFACE_CARD
	normal.set_corner_radius_all(6)
	normal.set_border_width_all(1)
	normal.border_color = UIColors.BORDER_SUBTLE
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = UIColors.SURFACE_HOVER
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = UIColors.SURFACE_SELECTED
	focus.set_border_width_all(2)
	focus.border_color = UIColors.ACCENT
	focus.shadow_color = UIColors.ACCENT_GLOW
	focus.shadow_size = 5
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", focus)
	btn.add_theme_stylebox_override("focus", focus)


func _on_floor_selected(floor_num: int) -> void:
	selected_floor = floor_num
	for i in range(floor_buttons.size()):
		floor_buttons[i].button_pressed = (i + 1 == selected_floor)


func _on_strategy_selected(strat: PartyAI.Strategy) -> void:
	strategy = strat
	var strat_values := [PartyAI.Strategy.AGGRESSIVE, PartyAI.Strategy.BALANCED, PartyAI.Strategy.DEFENSIVE]
	for i in range(strategy_buttons.size()):
		strategy_buttons[i].button_pressed = (strat_values[i] == strategy)


func _on_run_pressed() -> void:
	if is_running:
		return
	if not GameState.has_party():
		message_label.text = "No party to explore with."
		return
	_run_simulation()


func _run_simulation() -> void:
	is_running = true
	message_label.text = "Exploring..."
	if run_button:
		run_button.disabled = true
	await get_tree().process_frame

	var relationship_snapshot := RelationshipManager.get_save_state()
	var event_snapshot := EventManager.get_save_state()

	var sim := ExplorationSimulator.new()
	last_batch_results.clear()
	_narrative_log.clear()
	_sim_day = GameState.game_day

	var party_copy := _copy_party()
	var level_ups: Array[Dictionary] = []
	var death_log: Array[Dictionary] = []
	var dives_completed := 0

	sim.post_combat_callback = func(p: Party, enemies: Array[Monster], p_is_boss: bool, floor_level: int) -> void:
		_on_sim_post_combat(p, enemies, p_is_boss, floor_level)

	for i in range(num_dives):
		if i > 0:
			_rest_between_dives(party_copy)
			_sim_day += 1
		_clear_consumables(party_copy)
		TestFixtures.stock_party_consumables(party_copy, party_copy.get_average_level())
		var seed_value := randi()
		CombatRNGClass.set_seed(seed_value)

		var result := sim.run_floor_dive(
			party_copy, selected_floor, num_encounters, include_boss,
			seed_value, PartyAI.DEFAULT_CAST_THRESHOLD, strategy,
			return_encounters
		)

		party_copy.distribute_experience(result.total_xp)
		party_copy.add_gold(result.get("total_gold", 0))

		for member in party_copy.get_members():
			if member.pending_level_up:
				var old_level := member.level
				while member.pending_level_up:
					member.confirm_level_up()
				if member.level > old_level:
					level_ups.append({
						"name": member.character_name,
						"old_level": old_level,
						"new_level": member.level,
						"dive": i + 1,
					})

		var dive_deaths: Array = result.get("deaths", [])
		for dname in dive_deaths:
			death_log.append({"name": dname, "dive": i + 1})

		last_batch_results.append(result)
		dives_completed += 1

		if death_threshold > 0:
			var dead_count := 0
			for member in party_copy.get_members():
				if member.is_dead:
					dead_count += 1
			if dead_count >= death_threshold:
				break

	var total_xp_earned := 0
	var total_gold_earned := 0
	var loot_items: Array[String] = []
	for r in last_batch_results:
		total_xp_earned += r.total_xp
		total_gold_earned += r.get("total_gold", 0)
	for slot in party_copy.inventory.slots:
		var item: Item = slot.get("item")
		if item:
			var found := false
			for orig_slot in GameState.party.inventory.slots:
				if orig_slot.get("item_id") == slot.get("item_id"):
					found = true
					break
			if not found:
				loot_items.append(item.item_name if item.item_name != "" else item.id)

	var days_elapsed := _sim_day - GameState.game_day
	last_rewards = {
		"total_xp": total_xp_earned,
		"total_gold": total_gold_earned,
		"level_ups": level_ups,
		"death_log": death_log,
		"loot_items": loot_items,
		"dives_completed": dives_completed,
		"days_elapsed": days_elapsed,
		"narrative_log": _narrative_log.duplicate(true),
	}

	_apply_results(party_copy)
	RelationshipManager.load_save_state(relationship_snapshot)
	EventManager.load_save_state(event_snapshot)
	last_batch_summary = _compute_summary(last_batch_results)

	is_running = false
	if run_button:
		run_button.disabled = false
	var msg := "Exploration complete! Rewards applied. %d dive(s) finished." % dives_completed
	if dives_completed < num_dives:
		msg += " (stopped early: death threshold reached)"
	message_label.text = msg
	_update_party_info()

	_display_current_tab()


func _copy_party() -> Party:
	var source := GameState.party
	var new_party := Party.new()
	for member in source.get_members():
		var copy := member.duplicate(true) as Character
		copy.current_hp = copy.max_hp
		copy.current_mp = copy.max_mp
		copy.is_dead = false
		copy.status_effects.clear()
		copy.active_statuses.clear()
		new_party.add_member(copy)
	new_party.gold = source.gold
	for slot in source.inventory.slots:
		var item: Item = slot.get("item")
		var qty: int = slot.get("quantity", 1)
		if item:
			new_party.inventory.add_item(item.duplicate(), qty)
	return new_party


func _rest_between_dives(party: Party) -> void:
	for member in party.get_members():
		if member.is_dead:
			continue
		member.current_hp = member.max_hp
		member.current_mp = member.max_mp
		var to_remove: Array[CharacterEnums.StatusEffect] = []
		for active in member.active_statuses:
			if active.type == CharacterEnums.StatusEffect.DEAD:
				continue
			if not active.is_permanent():
				to_remove.append(active.type)
		for effect in to_remove:
			member.remove_status(effect)


const RESTOCK_CONSUMABLES: Array[String] = [
	"healing_potion", "greater_healing", "antidote", "mana_potion",
]


func _clear_consumables(party: Party) -> void:
	for item_id in RESTOCK_CONSUMABLES:
		var count := party.inventory.get_item_count(item_id)
		if count > 0:
			party.inventory.remove_item(item_id, count)


func _apply_results(copy_party: Party) -> void:
	var real_party := GameState.party
	for copy_member in copy_party.get_members():
		var real_member := real_party.get_member(copy_member.id)
		if real_member == null:
			continue
		real_member.experience = copy_member.experience
		real_member.level = copy_member.level
		real_member.pending_level_up = copy_member.pending_level_up
		real_member.strength = copy_member.strength
		real_member.intelligence = copy_member.intelligence
		real_member.piety = copy_member.piety
		real_member.vitality = copy_member.vitality
		real_member.agility = copy_member.agility
		real_member.luck = copy_member.luck
		real_member.max_hp = copy_member.max_hp
		real_member.max_mp = copy_member.max_mp
		real_member.current_hp = copy_member.current_hp
		real_member.current_mp = copy_member.current_mp
		real_member.is_dead = copy_member.is_dead
		real_member.death_count = copy_member.death_count
		real_member.marks = copy_member.marks.duplicate(true)
		real_member.tendencies = copy_member.tendencies.duplicate(true)
		real_member.evidence = copy_member.evidence.duplicate(true)
		real_member.traits = copy_member.traits.duplicate(true)
		real_member.crystallization_events = copy_member.crystallization_events.duplicate(true)
		real_member.status_effects = copy_member.status_effects.duplicate()
		real_member.active_statuses = copy_member.active_statuses.duplicate()
		real_member.known_spells = copy_member.known_spells.duplicate()
		real_member.max_spell_level = copy_member.max_spell_level
		real_member._recalculate_derived_stats()
	real_party.gold = copy_party.gold
	real_party.inventory.slots = copy_party.inventory.slots.duplicate(true)


func _on_sim_post_combat(party: Party, enemies: Array[Monster], p_is_boss: bool, floor_level: int) -> void:
	var party_chars: Array[Character] = []
	for member in party.get_members():
		party_chars.append(member)

	var new_marks := MarkSystem.evaluate_post_combat(
		party_chars, enemies, p_is_boss, floor_level, _sim_day
	)
	for entry in new_marks:
		entry.character.add_mark(entry.mark)
		_narrative_log.append({
			"type": "mark",
			"name": entry.character.character_name,
			"mark_name": entry.mark.get("name", ""),
		})

	var rel_mods := MarkSystem.evaluate_relationships(
		party_chars, enemies, p_is_boss, floor_level
	)
	for mod in rel_mods:
		RelationshipManager.add_modifier(mod.id_a, mod.id_b, mod.source, mod.weight, _sim_day)
		var name_a := _get_name_by_id(party, mod.id_a)
		var name_b := _get_name_by_id(party, mod.id_b)
		_narrative_log.append({
			"type": "relationship",
			"char_a": name_a,
			"char_b": name_b,
			"source": mod.source,
			"weight": mod.weight,
		})

	for member in party.get_members():
		if member.is_dead:
			continue
		for axis: int in member.traits.keys():
			var axis_name := _axis_display_name(axis)
			var option: int = member.traits[axis]
			var already_logged := false
			for entry: Dictionary in _narrative_log:
				if entry.get("type") == "crystallization" and entry.get("name") == member.character_name and entry.get("axis") == axis_name:
					already_logged = true
					break
			if already_logged:
				continue
			var ce_entry: Dictionary = member.crystallization_events.get(axis, {})
			if not ce_entry.is_empty() and ce_entry.get("day", 0) == _sim_day:
				_narrative_log.append({
					"type": "crystallization",
					"name": member.character_name,
					"axis": axis_name,
					"trait": _option_display_name(axis, option),
				})


func _get_name_by_id(party: Party, char_id: String) -> String:
	for member in party.get_members():
		if member.id == char_id:
			return member.character_name
	return char_id


func _axis_display_name(axis: int) -> String:
	match axis:
		Personality.Axis.TEMPERAMENT: return "Temperament"
		Personality.Axis.SOCIAL: return "Social"
		Personality.Axis.OUTLOOK: return "Outlook"
		Personality.Axis.VALUES: return "Values"
	return "Unknown"


func _option_display_name(axis: int, option: int) -> String:
	match axis:
		Personality.Axis.TEMPERAMENT:
			match option:
				Personality.Temperament.BRAVE: return "Brave"
				Personality.Temperament.CAUTIOUS: return "Cautious"
				Personality.Temperament.RECKLESS: return "Reckless"
				Personality.Temperament.CALCULATING: return "Calculating"
		Personality.Axis.SOCIAL:
			match option:
				Personality.Social.FRIENDLY: return "Friendly"
				Personality.Social.GRUFF: return "Gruff"
				Personality.Social.SARCASTIC: return "Sarcastic"
				Personality.Social.EARNEST: return "Earnest"
		Personality.Axis.OUTLOOK:
			match option:
				Personality.Outlook.OPTIMISTIC: return "Optimistic"
				Personality.Outlook.PESSIMISTIC: return "Pessimistic"
				Personality.Outlook.STOIC: return "Stoic"
				Personality.Outlook.CURIOUS: return "Curious"
		Personality.Axis.VALUES:
			match option:
				Personality.Values.MERCIFUL: return "Merciful"
				Personality.Values.RUTHLESS: return "Ruthless"
				Personality.Values.PRINCIPLED: return "Principled"
				Personality.Values.SELF_INTERESTED: return "Self-Interested"
	return "Unknown"


func _compute_summary(results: Array[Dictionary]) -> Dictionary:
	var total := results.size()
	var wipes := 0
	var return_wipes := 0
	var total_encounters := 0
	var total_xp := 0
	var total_gold := 0
	var total_deaths := 0
	var total_potions := 0
	var total_healing_potions := 0
	var total_mana_potions := 0
	var total_antidotes := 0
	var retreats := 0
	var final_hp_sum := 0.0
	var final_mp_sum := 0.0
	var final_count := 0

	for r in results:
		total_encounters += r.encounters_won
		total_xp += r.total_xp
		total_gold += r.get("total_gold", 0)
		total_deaths += r.deaths.size()
		total_potions += r.total_potions_used
		total_healing_potions += r.get("healing_potions_used", 0)
		total_mana_potions += r.get("mana_potions_used", 0)
		total_antidotes += r.get("antidotes_used", 0)
		if r.party_wiped:
			wipes += 1
			if r.get("wiped_during_return", false):
				return_wipes += 1
		if r.get("retreated", false):
			retreats += 1

		var ret_snaps: Array = r.get("return_snapshots", [])
		var snaps: Array = r.encounter_snapshots
		if not ret_snaps.is_empty():
			var last: Dictionary = ret_snaps[ret_snaps.size() - 1]
			final_hp_sum += last.get("party_hp_pct", 0.0)
			final_mp_sum += last.get("party_mp_pct", 0.0)
			final_count += 1
		elif not snaps.is_empty():
			var last: Dictionary = snaps[snaps.size() - 1]
			final_hp_sum += last.get("party_hp_pct", 0.0)
			final_mp_sum += last.get("party_mp_pct", 0.0)
			final_count += 1

	var max_enc := num_encounters + (1 if include_boss else 0) + return_encounters
	var survival_rate := float(total - wipes) / float(total) * 100.0

	return {
		"survival_rate": survival_rate,
		"survived": total - wipes,
		"total": total,
		"wipes": wipes,
		"return_wipes": return_wipes,
		"avg_encounters": float(total_encounters) / float(total),
		"max_encounters": max_enc,
		"avg_xp": float(total_xp) / float(total),
		"avg_gold": float(total_gold) / float(total),
		"avg_deaths": float(total_deaths) / float(total),
		"avg_potions": float(total_potions) / float(total),
		"avg_healing_potions": float(total_healing_potions) / float(total),
		"avg_mana_potions": float(total_mana_potions) / float(total),
		"avg_antidotes": float(total_antidotes) / float(total),
		"retreats": retreats,
		"avg_final_hp_pct": final_hp_sum / float(maxi(1, final_count)),
		"avg_final_mp_pct": final_mp_sum / float(maxi(1, final_count)),
	}


func _display_current_tab() -> void:
	if current_tab == 0:
		_display_summary()
	else:
		_display_detail()


func _display_summary() -> void:
	if last_batch_results.is_empty():
		results_label.text = "Press Run to begin exploration."
		return

	var s := last_batch_summary
	var text := "[b]AUTOEXPLORE RESULTS[/b]\n\n"

	text += "[color=gray]Scenario:[/color] Floor %d, %d encounters" % [selected_floor, num_encounters]
	if include_boss:
		text += " + Boss"
	if return_encounters > 0:
		text += ", %d return" % return_encounters
	text += "\n"

	var strat_name := "Balanced"
	match strategy:
		PartyAI.Strategy.AGGRESSIVE: strat_name = "Aggressive"
		PartyAI.Strategy.DEFENSIVE: strat_name = "Defensive"
	text += "[color=gray]Strategy:[/color] %s\n" % strat_name

	text += "[color=gray]Party:[/color] "
	var member_parts: Array[String] = []
	for member in GameState.party.get_members():
		member_parts.append("%s (Lv%d %s)" % [
			member.character_name, member.level,
			CharacterEnums.get_class_name(member.character_class)
		])
	text += ", ".join(member_parts) + "\n\n"

	var surv_color := "green" if s.survival_rate >= 80.0 else ("yellow" if s.survival_rate >= 50.0 else "red")
	text += "[color=%s]Survival Rate: %.0f%%[/color] (%d/%d dives)\n" % [
		surv_color, s.survival_rate, s.survived, s.total
	]
	if s.return_wipes > 0:
		text += "  Lost on return trip: %d\n" % s.return_wipes
	text += "\n"

	text += "Avg Encounters Completed: %.1f / %d\n" % [s.avg_encounters, s.max_encounters]
	text += "Avg HP Remaining: %.0f%%\n" % s.avg_final_hp_pct
	text += "Avg MP Remaining: %.0f%%\n" % s.avg_final_mp_pct
	text += "Avg XP per Dive: %.0f\n" % s.avg_xp
	text += "Avg Gold per Dive: %.0f\n" % s.avg_gold
	text += "Avg Deaths per Dive: %.1f\n" % s.avg_deaths

	if s.retreats > 0:
		text += "Retreats: %d / %d dives\n" % [s.retreats, s.total]

	text += "\n[color=cyan]Consumables per Dive:[/color]\n"
	text += "  Healing Potions: %.1f\n" % s.avg_healing_potions
	text += "  Mana Potions: %.1f\n" % s.avg_mana_potions
	text += "  Antidotes: %.1f\n" % s.avg_antidotes

	text += "\n[color=gray]--- Per-Dive Results ---[/color]\n"
	for i in range(last_batch_results.size()):
		var r: Dictionary = last_batch_results[i]
		var status := "[color=green]SURVIVED[/color]" if not r.party_wiped else "[color=red]WIPED[/color]"
		if r.get("retreated", false):
			status = "[color=yellow]RETREATED[/color]"
		text += "Dive %d: %s - %d encounters, %d XP, %d gold" % [
			i + 1, status, r.encounters_won, r.total_xp, r.get("total_gold", 0)
		]
		if r.deaths.size() > 0:
			text += " (deaths: %s)" % ", ".join(r.deaths)
		text += "\n"

	if not last_rewards.is_empty():
		text += "\n[color=green]--- Rewards Applied ---[/color]\n"
		text += "Total XP Earned: %d\n" % last_rewards.total_xp
		text += "Total Gold Earned: %d\n" % last_rewards.total_gold
		var days: int = last_rewards.get("days_elapsed", 0)
		if days > 0:
			text += "Time Elapsed: %d day(s)\n" % days

		var lvl_ups: Array = last_rewards.get("level_ups", [])
		if not lvl_ups.is_empty():
			text += "\n[color=cyan]Level Ups:[/color]\n"
			for lu in lvl_ups:
				text += "  %s: Lv%d -> Lv%d (dive %d)\n" % [
					lu.name, lu.old_level, lu.new_level, lu.dive
				]

		var loot: Array = last_rewards.get("loot_items", [])
		if not loot.is_empty():
			text += "\n[color=cyan]Loot Found:[/color]\n"
			for item_name in loot:
				text += "  %s\n" % item_name

		var d_log: Array = last_rewards.get("death_log", [])
		if not d_log.is_empty():
			text += "\n[color=red]Deaths:[/color]\n"
			for d in d_log:
				text += "  %s (dive %d)\n" % [d.name, d.dive]

		var narr: Array = last_rewards.get("narrative_log", [])
		if not narr.is_empty():
			var marks: Array[Dictionary] = []
			var rels: Array[Dictionary] = []
			var crystals: Array[Dictionary] = []
			for entry: Dictionary in narr:
				match entry.get("type", ""):
					"mark": marks.append(entry)
					"relationship": rels.append(entry)
					"crystallization": crystals.append(entry)

			if not marks.is_empty():
				text += "\n[color=#cccc44]Marks Earned:[/color]\n"
				for m in marks:
					text += "  %s: %s\n" % [m.get("name", ""), m.get("mark_name", "")]

			if not rels.is_empty():
				text += "\n[color=#88ccee]Relationship Changes:[/color]\n"
				var aggregated: Array[Dictionary] = []
				for r in rels:
					var found := false
					for a in aggregated:
						if a.char_a == r.get("char_a", "") and a.char_b == r.get("char_b", "") and a.source == r.get("source", ""):
							a.weight += int(r.get("weight", 0))
							found = true
							break
					if not found:
						aggregated.append({
							"char_a": r.get("char_a", ""),
							"char_b": r.get("char_b", ""),
							"source": r.get("source", ""),
							"weight": int(r.get("weight", 0)),
						})
				for a in aggregated:
					var sign_str := "+" if a.weight > 0 else ""
					text += "  %s & %s: %s (%s%d)\n" % [a.char_a, a.char_b, a.source, sign_str, a.weight]

			if not crystals.is_empty():
				text += "\n[color=#ffaa00]Trait Crystallizations:[/color]\n"
				for c in crystals:
					text += "  %s's %s crystallized: %s!\n" % [
						c.get("name", ""), c.get("axis", ""), c.get("trait", "")
					]

	results_label.text = text


func _display_detail() -> void:
	if last_batch_results.is_empty():
		results_label.text = "Press Run to begin exploration."
		return

	var text := "[b]ENCOUNTER LOG[/b]\n"

	for di in range(last_batch_results.size()):
		var r: Dictionary = last_batch_results[di]
		var status := "SURVIVED" if not r.party_wiped else "WIPED at E%d" % r.wipe_encounter
		if r.get("wiped_during_return", false):
			status = "WIPED on return R%d" % abs(r.wipe_encounter)
		if r.get("retreated", false):
			status = "RETREATED after E%d (%s)" % [
				r.get("retreat_after_encounter", 0),
				r.get("retreat_reason", "")
			]

		text += "\n[color=yellow]--- Dive %d: %s ---[/color]\n" % [di + 1, status]

		var snapshots: Array = r.encounter_snapshots
		for snap in snapshots:
			var enc_num: int = snap["encounter_num"]
			var is_boss: bool = snap.get("is_boss", false)
			var label := "BOSS" if is_boss else "E%d" % enc_num
			var victory: bool = snap["victory"]
			var victory_str := "[color=green]WIN[/color]" if victory else "[color=red]LOSS[/color]"

			var enemy_names: Array = snap.get("enemy_names", [])
			var enemies_str := ", ".join(enemy_names) if not enemy_names.is_empty() else "unknown"

			text += "\n  [b]%s[/b] vs %s - %s\n" % [label, enemies_str, victory_str]
			text += "    Turns: %d | HP: %.0f%% | MP: %.0f%% | Alive: %d\n" % [
				snap["turns"], snap["party_hp_pct"], snap["party_mp_pct"], snap["survivors"]
			]

			var surprise: String = snap.get("surprise", "none")
			if surprise != "none":
				text += "    Surprise: %s\n" % surprise

			var enc_deaths: Array = snap.get("deaths_this_encounter", [])
			if not enc_deaths.is_empty():
				text += "    [color=red]Deaths: %s[/color]\n" % ", ".join(enc_deaths)

			var healing_hp: int = snap.get("healing_hp", 0)
			var potions: int = snap.get("potions_used", 0)
			if healing_hp > 0 or potions > 0:
				text += "    Healing: %d HP restored" % healing_hp
				if potions > 0:
					text += ", %d potions" % potions
				text += "\n"

			if snap.get("stalemate", false):
				text += "    [color=yellow]Stalemate[/color]\n"

		var return_snaps: Array = r.get("return_snapshots", [])
		if not return_snaps.is_empty():
			text += "\n  [color=gray]-- Return Trip --[/color]\n"
			for snap in return_snaps:
				var enc_num: int = snap["encounter_num"]
				var victory: bool = snap["victory"]
				var victory_str := "[color=green]WIN[/color]" if victory else "[color=red]LOSS[/color]"

				var enemy_names: Array = snap.get("enemy_names", [])
				var enemies_str := ", ".join(enemy_names) if not enemy_names.is_empty() else "unknown"

				text += "\n  [b]R%d[/b] vs %s - %s\n" % [enc_num, enemies_str, victory_str]
				text += "    Turns: %d | HP: %.0f%% | MP: %.0f%% | Alive: %d\n" % [
					snap["turns"], snap["party_hp_pct"], snap["party_mp_pct"], snap["survivors"]
				]

				var enc_deaths: Array = snap.get("deaths_this_encounter", [])
				if not enc_deaths.is_empty():
					text += "    [color=red]Deaths: %s[/color]\n" % ", ".join(enc_deaths)

		if r.get("boss_victory", false):
			text += "  [color=green]Boss defeated![/color]\n"

	results_label.text = text


func _on_tab_changed(tab_index: int) -> void:
	current_tab = tab_index
	_display_current_tab()


func _update_help() -> void:
	if _scaffold == null:
		return
	var v_nav := KeyBindingHelper.get_nav_help()
	var confirm := KeyBindingHelper.get_confirm_help()
	var cancel := KeyBindingHelper.get_cancel_help()
	_scaffold.set_hint("%s   ·   ‹ / › Adjust / Tabs   ·   %s Run   ·   %s" % [
		v_nav, confirm.split(":")[0], cancel])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		_on_back_pressed()
		return

	if event.is_action_pressed("menu_left"):
		var f := get_viewport().gui_get_focus_owner()
		if f is Button and _steppers.has(f):
			_adjust_stepper(f, -1)
		elif tab_bar.current_tab > 0:
			tab_bar.current_tab -= 1
		return
	if event.is_action_pressed("menu_right"):
		var f := get_viewport().gui_get_focus_owner()
		if f is Button and _steppers.has(f):
			_adjust_stepper(f, 1)
		elif tab_bar.current_tab < tab_bar.tab_count - 1:
			tab_bar.current_tab += 1
		return

	if nav:
		nav.handle_input(event)


func _on_back_pressed() -> void:
	SceneManager.go_to_town()
