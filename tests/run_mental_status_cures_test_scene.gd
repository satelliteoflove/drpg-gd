extends Node

const BASE_SEED := 20000
const NUM_RUNS := 100
const PARTY_LEVEL := 10

var results_no_cures: Dictionary = {}
var results_with_cures: Dictionary = {}


func _ready() -> void:
	_run_test()
	get_tree().quit()


func _run_test() -> void:
	print("=" .repeat(70))
	print("Mental Status Effects: Cure Comparison Test")
	print("=" .repeat(70))
	print("")
	print("Configuration:")
	print("  Runs: %d per scenario | Party level: %d" % [NUM_RUNS, PARTY_LEVEL])
	print("  Monsters: Mind Flayer (confuse), Siren (charm), Rage Demon (berserk)")
	print("  Scenario A: Fighter-heavy (no mental cure spells)")
	print("  Scenario B: Balanced (priest + bishop with cure spells)")
	print("")

	print("--- Running Scenario A: Fighter-Heavy (no mental cure spells) ---")
	results_no_cures = _run_scenario(false)
	print("")

	print("--- Running Scenario B: Balanced (with cure spells) ---")
	results_with_cures = _run_scenario(true)
	print("")

	_print_comparison()


func _run_scenario(with_cures: bool) -> Dictionary:
	var data := {
		"victories": 0,
		"defeats": 0,
		"total_turns": 0,
		"mental_turns_player": 0,
		"mental_turns_monster": 0,
		"berserk_attacks": 0,
		"berserk_damage": 0,
		"confused_defends": 0,
		"confused_dazes": 0,
		"mental_attacks": 0,
		"friendly_fire_damage": 0,
		"monster_friendly_fire": 0,
		"snap_outs_confused": 0,
		"snap_outs_charmed": 0,
		"cures_cast": 0,
		"normal_turns": 0,
		"ally_deaths": 0,
	}

	for i in range(NUM_RUNS):
		_run_single_combat(BASE_SEED + i, with_cures, data)
		if (i + 1) % 25 == 0:
			print("  ...completed %d/%d runs" % [i + 1, NUM_RUNS])

	return data


func _run_single_combat(seed_value: int, with_cures: bool, data: Dictionary) -> void:
	CombatRNG.set_seed(seed_value)

	var party: Party
	if with_cures:
		party = TestFixtures.create_balanced_party(PARTY_LEVEL)
	else:
		party = TestFixtures.create_fighter_heavy_party(PARTY_LEVEL)
	var enemies := _create_mental_status_enemies()

	var sim := CombatSimulator.new()
	sim.setup(party, enemies, seed_value)

	var turn_count := 0
	var max_sim_turns := 80

	while sim._combat_active and turn_count < max_sim_turns:
		var turn_data := sim.step()
		if turn_data.is_empty():
			break
		turn_count += 1
		_analyze_turn(turn_data, data)

	data["total_turns"] += turn_count
	var all_dead := true
	for e in sim.enemies:
		if not e.is_dead:
			all_dead = false
			break
	if all_dead:
		data["victories"] += 1
	else:
		data["defeats"] += 1


func _create_party_no_cures() -> Party:
	var party := Party.new()
	var fighter1 := _make_char("Fighter1", CharacterEnums.CharacterClass.FIGHTER)
	var fighter2 := _make_char("Fighter2", CharacterEnums.CharacterClass.FIGHTER)
	var fighter3 := _make_char("Fighter3", CharacterEnums.CharacterClass.FIGHTER)
	var thief := _make_char("Thief", CharacterEnums.CharacterClass.THIEF)
	var mage := _make_char("Mage", CharacterEnums.CharacterClass.MAGE)
	var ranger := _make_char("Ranger", CharacterEnums.CharacterClass.RANGER)
	party.add_member(fighter1)
	party.add_member(fighter2)
	party.add_member(fighter3)
	party.add_member(thief)
	party.add_member(mage)
	party.add_member(ranger)
	return party


func _create_party_with_cures() -> Party:
	var party := Party.new()
	var fighter1 := _make_char("Fighter1", CharacterEnums.CharacterClass.FIGHTER)
	var fighter2 := _make_char("Fighter2", CharacterEnums.CharacterClass.FIGHTER)
	var priest := _make_char("Priest", CharacterEnums.CharacterClass.PRIEST)
	var bishop := _make_char("Bishop", CharacterEnums.CharacterClass.BISHOP)
	var mage := _make_char("Mage", CharacterEnums.CharacterClass.MAGE)
	var psionic := _make_char("Psionic", CharacterEnums.CharacterClass.PSIONIC)
	party.add_member(fighter1)
	party.add_member(fighter2)
	party.add_member(priest)
	party.add_member(bishop)
	party.add_member(mage)
	party.add_member(psionic)
	return party


func _make_char(char_name: String, char_class: CharacterEnums.CharacterClass) -> Character:
	var stats := {
		"strength": 12, "intelligence": 12, "piety": 12,
		"vitality": 12, "agility": 12, "luck": 12
	}
	match char_class:
		CharacterEnums.CharacterClass.FIGHTER:
			stats["strength"] = 16
			stats["vitality"] = 14
		CharacterEnums.CharacterClass.MAGE, CharacterEnums.CharacterClass.PSIONIC:
			stats["intelligence"] = 16
		CharacterEnums.CharacterClass.PRIEST:
			stats["piety"] = 16
		CharacterEnums.CharacterClass.THIEF:
			stats["agility"] = 16
			stats["luck"] = 14
		CharacterEnums.CharacterClass.BISHOP:
			stats["intelligence"] = 14
			stats["piety"] = 14
		CharacterEnums.CharacterClass.RANGER:
			stats["strength"] = 14
			stats["agility"] = 14

	var character := Character.create_new(
		char_name, CharacterEnums.Race.HUMAN, char_class,
		CharacterEnums.Alignment.NEUTRAL, CharacterEnums.Gender.MALE, stats)

	var sword := ShopItems.get_item("short_sword")
	var armor := ShopItems.get_item("leather_armor")
	if sword:
		character.equip_item(sword.duplicate())
	if armor:
		character.equip_item(armor.duplicate())

	for i in range(PARTY_LEVEL - 1):
		character.level += 1
		character._recalculate_derived_stats()
		SpellLearning.try_learn_spells_on_level_up(character)

	var learnable := SpellLearning.get_learnable_spells(character)
	for spell in learnable:
		if not character.known_spells.has(spell.id):
			character.known_spells.append(spell.id)

	character.current_hp = character.max_hp
	character.current_mp = character.max_mp
	return character


func _create_mental_status_enemies() -> Array[Monster]:
	var monsters: Array[Monster] = []

	var confuser := Monster.new()
	confuser.monster_name = "Mind Flayer"
	confuser.max_hp = 100
	confuser.strength = 12
	confuser.agility = 12
	confuser.defense = 3
	confuser.evasion = 2
	confuser.level = 8
	confuser.intelligence = 14
	confuser.piety = 10
	confuser.vitality = 10
	confuser.luck = 10
	confuser.exp_reward = 50
	confuser.gold_reward_dice = "2d10"
	confuser.attacks = [
		MonsterAttack.create_with_effect(
			"Mind Blast", "1d6", 3,
			CharacterEnums.StatusEffect.CONFUSED, 0.60,
			"3+1d4", "mental", 4
		),
		MonsterAttack.create_basic("Tentacle Slap", "1d6", 2),
	]
	confuser.grid_position = Vector2i(1, 0)
	confuser.init_combat()
	monsters.append(confuser)

	var charmer := Monster.new()
	charmer.monster_name = "Siren"
	charmer.max_hp = 100
	charmer.strength = 10
	charmer.agility = 14
	charmer.defense = 2
	charmer.evasion = 3
	charmer.level = 8
	charmer.intelligence = 16
	charmer.piety = 12
	charmer.vitality = 10
	charmer.luck = 12
	charmer.exp_reward = 55
	charmer.gold_reward_dice = "2d10"
	charmer.max_mp = 30
	charmer.spells = ["m1_spark", "p1_minor_heal"]
	charmer.attacks = [
		MonsterAttack.create_with_effect(
			"Charming Gaze", "1d6", 3,
			CharacterEnums.StatusEffect.CHARMED, 0.60,
			"4+1d4", "mental", 4
		),
		MonsterAttack.create_basic("Claw", "1d6", 3),
	]
	charmer.grid_position = Vector2i(0, 0)
	charmer.init_combat()
	monsters.append(charmer)

	var enrager := Monster.new()
	enrager.monster_name = "Rage Demon"
	enrager.max_hp = 120
	enrager.strength = 14
	enrager.agility = 10
	enrager.defense = 4
	enrager.evasion = 1
	enrager.level = 8
	enrager.intelligence = 8
	enrager.piety = 8
	enrager.vitality = 10
	enrager.luck = 10
	enrager.exp_reward = 60
	enrager.gold_reward_dice = "3d10"
	enrager.max_mp = 20
	enrager.spells = ["a2_rage_draught"]
	enrager.attacks = [
		MonsterAttack.create_basic("Fiery Claw", "2d4", 4),
		MonsterAttack.create_basic("Slam", "1d8", 3),
	]
	enrager.grid_position = Vector2i(2, 0)
	enrager.init_combat()
	monsters.append(enrager)

	return monsters


func _analyze_turn(turn_data: Dictionary, data: Dictionary) -> void:
	var action: String = turn_data.get("action", "")
	var is_player: bool = turn_data.get("is_player", false)
	var skipped: bool = turn_data.get("skipped", false)

	var is_mental := action.begins_with("mental") or action.begins_with("berserk")

	if is_mental:
		if is_player:
			data["mental_turns_player"] += 1
		else:
			data["mental_turns_monster"] += 1

		match action:
			"mental_attack":
				data["mental_attacks"] += 1
				if is_player and turn_data.get("hit", false):
					data["friendly_fire_damage"] += turn_data.get("damage", 0)
				elif not is_player:
					var target_name: String = turn_data.get("target", "")
					if target_name in ["Mind Flayer", "Siren", "Rage Demon"]:
						data["monster_friendly_fire"] += 1
			"mental_defend":
				data["confused_defends"] += 1
			"mental_daze":
				data["confused_dazes"] += 1
			"berserk_attack":
				data["berserk_attacks"] += 1
				if turn_data.get("hit", false):
					data["berserk_damage"] += turn_data.get("damage", 0)
	elif not skipped:
		data["normal_turns"] += 1

	var reasoning: String = turn_data.get("reasoning", "")
	if "cure mentally controlled" in reasoning or "cure affliction" in reasoning:
		if "CONFUSED" in reasoning or "CHARMED" in reasoning or "BERSERK" in reasoning or "mentally controlled" in reasoning:
			data["cures_cast"] += 1

	if action == "spell" and not is_mental:
		var spell_id: String = turn_data.get("spell_id", "")
		if spell_id in ["p3_purify", "s3_mind_cleanse"]:
			data["cures_cast"] += 1

	_check_snap_outs(turn_data.get("tick_messages", []), data)
	_check_snap_outs(turn_data.get("messages", []), data)


func _check_snap_outs(messages: Variant, data: Dictionary) -> void:
	if messages is Array:
		for msg in messages:
			if msg is String:
				if "snaps out of confusion" in msg:
					data["snap_outs_confused"] += 1
				elif "breaks free from the charm" in msg:
					data["snap_outs_charmed"] += 1


func _print_comparison() -> void:
	var ra := results_no_cures
	var rb := results_with_cures

	print("=" .repeat(70))
	print("COMPARISON RESULTS")
	print("=" .repeat(70))
	print("")
	print("%-35s %12s %12s" % ["Metric", "No Cures", "With Cures"])
	print("-" .repeat(70))

	_row("Victories", ra["victories"], rb["victories"])
	_row("Defeats", ra["defeats"], rb["defeats"])
	_rowf("Win Rate %%",
		float(ra["victories"]) / NUM_RUNS * 100.0,
		float(rb["victories"]) / NUM_RUNS * 100.0)
	_rowf("Avg Turns",
		float(ra["total_turns"]) / NUM_RUNS,
		float(rb["total_turns"]) / NUM_RUNS)
	print("")

	_row("Player Mental Turns", ra["mental_turns_player"], rb["mental_turns_player"])
	_row("Normal Player Turns", ra["normal_turns"], rb["normal_turns"])
	print("")

	_row("Berserk Attacks", ra["berserk_attacks"], rb["berserk_attacks"])
	_row("Total Berserk Damage", ra["berserk_damage"], rb["berserk_damage"])
	_row("Confused Defends", ra["confused_defends"], rb["confused_defends"])
	_row("Confused Dazes", ra["confused_dazes"], rb["confused_dazes"])
	_row("Mental Attacks (FF)", ra["mental_attacks"], rb["mental_attacks"])
	print("")

	_row("Friendly Fire Damage", ra["friendly_fire_damage"], rb["friendly_fire_damage"])
	_row("Monster Friendly Fire", ra["monster_friendly_fire"], rb["monster_friendly_fire"])
	print("")

	_row("Snap-outs (Confused)", ra["snap_outs_confused"], rb["snap_outs_confused"])
	_row("Snap-outs (Charmed)", ra["snap_outs_charmed"], rb["snap_outs_charmed"])
	_row("Cure Spells Cast", ra["cures_cast"], rb["cures_cast"])
	print("")
	print("=" .repeat(70))
	print("A: Fighter-heavy (3 fighters, samurai, priest, thief)")
	print("B: Balanced (2 fighters, priest, thief, mage, bishop)")
	print("Berserk is now a BUFF - not cured by either party")
	print("=" .repeat(70))


func _row(label: String, a: int, b: int) -> void:
	var delta := b - a
	var delta_str := ""
	if delta > 0:
		delta_str = " (+%d)" % delta
	elif delta < 0:
		delta_str = " (%d)" % delta
	print("%-35s %12d %12d%s" % [label, a, b, delta_str])


func _rowf(label: String, a: float, b: float) -> void:
	var delta := b - a
	var delta_str := ""
	if abs(delta) > 0.1:
		delta_str = " (%+.1f)" % delta
	print("%-35s %12.1f %12.1f%s" % [label, a, b, delta_str])
