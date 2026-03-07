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

var floor_buttons: Array[Button] = []
var strategy_buttons: Array[Button] = []
var encounters_spin: SpinBox = null
var boss_check: CheckBox = null
var return_spin: SpinBox = null
var dives_spin: SpinBox = null
var death_threshold_spin: SpinBox = null
var run_button: Button = null

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
	back_button.pressed.connect(_on_back_pressed)
	tab_bar.tab_changed.connect(_on_tab_changed)
	_populate_config()
	_update_party_info()
	_update_help()


func _update_party_info() -> void:
	if not GameState.has_party():
		party_info_label.text = "No party"
		return
	var members := GameState.party.get_members()
	var avg_level := GameState.party.get_average_level()
	party_info_label.text = "%d members, Avg Lv%d" % [members.size(), avg_level]


func _populate_config() -> void:
	for child in config_list.get_children():
		child.queue_free()
	nav_buttons.clear()
	floor_buttons.clear()
	strategy_buttons.clear()

	if not GameState.has_party():
		var label := Label.new()
		label.text = "Assemble a party at the Guild Hall first."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		config_list.add_child(label)
		message_label.text = "No party available."
		nav = MenuNavigator.new()
		nav.setup([back_button], 0)
		return

	var default_floor := clampi(GameState.current_floor, 1, 6)
	selected_floor = default_floor

	_add_section_label("Floor Level")
	var floor_row := HBoxContainer.new()
	floor_row.add_theme_constant_override("separation", 4)
	for i in range(1, 7):
		var btn := Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(40, 32)
		btn.toggle_mode = true
		btn.button_pressed = (i == selected_floor)
		var floor_num := i
		btn.pressed.connect(_on_floor_selected.bind(floor_num))
		floor_row.add_child(btn)
		floor_buttons.append(btn)
		nav_buttons.append(btn)
	config_list.add_child(floor_row)

	_add_section_label("Encounters")
	encounters_spin = SpinBox.new()
	encounters_spin.min_value = 1
	encounters_spin.max_value = 8
	encounters_spin.value = num_encounters
	encounters_spin.custom_minimum_size = Vector2(200, 32)
	encounters_spin.value_changed.connect(func(val: float) -> void: num_encounters = int(val))
	config_list.add_child(encounters_spin)

	_add_section_label("Include Boss")
	boss_check = CheckBox.new()
	boss_check.text = "Yes"
	boss_check.button_pressed = include_boss
	boss_check.toggled.connect(func(val: bool) -> void: include_boss = val)
	config_list.add_child(boss_check)
	nav_buttons.append(boss_check)

	_add_section_label("Return Encounters")
	return_spin = SpinBox.new()
	return_spin.min_value = 0
	return_spin.max_value = 4
	return_spin.value = return_encounters
	return_spin.custom_minimum_size = Vector2(200, 32)
	return_spin.value_changed.connect(func(val: float) -> void: return_encounters = int(val))
	config_list.add_child(return_spin)

	_add_section_label("Number of Dives")
	dives_spin = SpinBox.new()
	dives_spin.min_value = 1
	dives_spin.max_value = 10
	dives_spin.value = num_dives
	dives_spin.custom_minimum_size = Vector2(200, 32)
	dives_spin.value_changed.connect(func(val: float) -> void: num_dives = int(val))
	config_list.add_child(dives_spin)

	_add_section_label("Stop on N+ Deaths")
	death_threshold_spin = SpinBox.new()
	death_threshold_spin.min_value = 0
	death_threshold_spin.max_value = 6
	death_threshold_spin.value = death_threshold
	death_threshold_spin.custom_minimum_size = Vector2(200, 32)
	death_threshold_spin.suffix = " (0 = never)"
	death_threshold_spin.value_changed.connect(func(val: float) -> void: death_threshold = int(val))
	config_list.add_child(death_threshold_spin)

	_add_section_label("Strategy")
	var strat_row := HBoxContainer.new()
	strat_row.add_theme_constant_override("separation", 4)
	var strat_configs := [
		{"name": "Aggressive", "value": PartyAI.Strategy.AGGRESSIVE},
		{"name": "Balanced", "value": PartyAI.Strategy.BALANCED},
		{"name": "Defensive", "value": PartyAI.Strategy.DEFENSIVE},
	]
	for cfg in strat_configs:
		var btn := Button.new()
		btn.text = cfg["name"]
		btn.custom_minimum_size = Vector2(100, 32)
		btn.toggle_mode = true
		var strat_val: PartyAI.Strategy = cfg["value"] as PartyAI.Strategy
		btn.button_pressed = (strat_val == strategy)
		btn.pressed.connect(_on_strategy_selected.bind(strat_val))
		strat_row.add_child(btn)
		strategy_buttons.append(btn)
		nav_buttons.append(btn)
	config_list.add_child(strat_row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	config_list.add_child(spacer)

	run_button = Button.new()
	run_button.text = "Run Simulation"
	run_button.custom_minimum_size = Vector2(350, 40)
	run_button.pressed.connect(_on_run_pressed)
	config_list.add_child(run_button)
	nav_buttons.append(run_button)

	nav = MenuNavigator.new()
	nav.setup(nav_buttons, 0)


func _add_section_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UIColors.INFO)
	config_list.add_child(label)


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
		message_label.text = "No party to simulate with."
		return
	_run_simulation()


func _run_simulation() -> void:
	is_running = true
	message_label.text = "Simulating..."
	if run_button:
		run_button.disabled = true
	await get_tree().process_frame

	var sim := DiveSimulator.new()
	last_batch_results.clear()

	var party_copy := _copy_party()
	var level_ups: Array[Dictionary] = []
	var death_log: Array[Dictionary] = []
	var dives_completed := 0

	for i in range(num_dives):
		if i > 0:
			_rest_between_dives(party_copy)
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

	last_rewards = {
		"total_xp": total_xp_earned,
		"total_gold": total_gold_earned,
		"level_ups": level_ups,
		"death_log": death_log,
		"loot_items": loot_items,
		"dives_completed": dives_completed,
	}

	_apply_results(party_copy)
	last_batch_summary = _compute_summary(last_batch_results)

	is_running = false
	if run_button:
		run_button.disabled = false
	var msg := "Dive complete! Rewards applied. %d dive(s) finished." % dives_completed
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
		real_member.status_effects = copy_member.status_effects.duplicate()
		real_member.active_statuses = copy_member.active_statuses.duplicate()
		real_member.known_spells = copy_member.known_spells.duplicate()
		real_member.max_spell_level = copy_member.max_spell_level
		real_member._recalculate_derived_stats()
	real_party.gold = copy_party.gold
	real_party.inventory.slots = copy_party.inventory.slots.duplicate(true)


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
		results_label.text = "Run a simulation to see results."
		return

	var s := last_batch_summary
	var text := "[b]SIMULATION RESULTS[/b]\n\n"

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

	results_label.text = text


func _display_detail() -> void:
	if last_batch_results.is_empty():
		results_label.text = "Run a simulation to see encounter details."
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
	var v_nav := KeyBindingHelper.get_nav_help()
	var confirm := KeyBindingHelper.get_confirm_help()
	var cancel := KeyBindingHelper.get_cancel_help()
	var h_nav := KeyBindingHelper.get_horizontal_help()
	help_label.text = "%s | %s | %s: Tabs | %s" % [v_nav, confirm, h_nav.split(":")[0], cancel]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		_on_back_pressed()
		return

	if event.is_action_pressed("menu_left"):
		if tab_bar.current_tab > 0:
			tab_bar.current_tab -= 1
		return
	if event.is_action_pressed("menu_right"):
		if tab_bar.current_tab < tab_bar.tab_count - 1:
			tab_bar.current_tab += 1
		return

	if nav:
		nav.handle_input(event)


func _on_back_pressed() -> void:
	SceneManager.go_to_town()
