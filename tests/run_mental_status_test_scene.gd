extends Node

const BASE_SEED := 20000
const NUM_RUNS := 100
const PARTY_LEVEL := 7

var mental_turns_confused_attack := 0
var mental_turns_confused_spell := 0
var mental_turns_confused_defend := 0
var mental_turns_confused_daze := 0
var mental_turns_charmed_attack := 0
var mental_turns_charmed_spell := 0
var mental_turns_charmed_defend := 0
var mental_turns_berserk_attack := 0
var mental_turns_total := 0
var player_mental_turns := 0
var normal_turns := 0
var snap_outs_confused := 0
var snap_outs_charmed := 0
var friendly_fire_damage := 0
var berserk_damage := 0
var berserk_hits := 0
var berserk_misses := 0
var victories := 0
var defeats := 0
var total_turns := 0
var monster_mental_turns := 0
var monster_confused_ally_hits := 0


func _ready() -> void:
	_run_test()
	get_tree().quit()


func _run_test() -> void:
	print("=" .repeat(70))
	print("Mental Status Effects Stress Test")
	print("=" .repeat(70))
	print("")
	print("Configuration:")
	print("  Runs: %d | Party level: %d | Seed base: %d" % [NUM_RUNS, PARTY_LEVEL, BASE_SEED])
	print("  Monsters: Mind Flayer (80%% confuse), Siren (75%% charm), Rage Demon (70%% berserk)")
	print("")

	for i in range(NUM_RUNS):
		_run_single_combat(BASE_SEED + i)
		if (i + 1) % 25 == 0:
			print("  ...completed %d/%d runs" % [i + 1, NUM_RUNS])

	print("")
	_print_results()


func _run_single_combat(seed_value: int) -> void:
	CombatRNG.set_seed(seed_value)

	var party := TestFixtures.create_balanced_party(PARTY_LEVEL)
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
		_analyze_turn(turn_data)

	total_turns += turn_count
	var all_dead := true
	for e in sim.enemies:
		if not e.is_dead:
			all_dead = false
			break
	if all_dead:
		victories += 1
	else:
		defeats += 1


func _create_mental_status_enemies() -> Array[Monster]:
	var monsters: Array[Monster] = []

	var confuser := Monster.new()
	confuser.monster_name = "Mind Flayer"
	confuser.max_hp = 30
	confuser.strength = 6
	confuser.agility = 10
	confuser.defense = 1
	confuser.evasion = 1
	confuser.level = 3
	confuser.intelligence = 14
	confuser.piety = 10
	confuser.vitality = 10
	confuser.luck = 10
	confuser.exp_reward = 50
	confuser.gold_reward_dice = "2d10"
	confuser.attacks = [
		MonsterAttack.create_with_effect(
			"Mind Blast", "1d2", 1,
			CharacterEnums.StatusEffect.CONFUSED, 1.0,
			"3+1d4", "mental", 12
		),
	]
	confuser.grid_position = Vector2i(1, 0)
	confuser.init_combat()
	monsters.append(confuser)

	var charmer := Monster.new()
	charmer.monster_name = "Siren"
	charmer.max_hp = 30
	charmer.strength = 6
	charmer.agility = 10
	charmer.defense = 1
	charmer.evasion = 1
	charmer.level = 3
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
			"Charming Gaze", "1d2", 1,
			CharacterEnums.StatusEffect.CHARMED, 1.0,
			"4+1d4", "mental", 12
		),
	]
	charmer.grid_position = Vector2i(0, 0)
	charmer.init_combat()
	monsters.append(charmer)

	var enrager := Monster.new()
	enrager.monster_name = "Rage Demon"
	enrager.max_hp = 30
	enrager.strength = 6
	enrager.agility = 10
	enrager.defense = 1
	enrager.evasion = 1
	enrager.level = 3
	enrager.intelligence = 8
	enrager.piety = 8
	enrager.vitality = 10
	enrager.luck = 10
	enrager.exp_reward = 60
	enrager.gold_reward_dice = "3d10"
	enrager.max_mp = 20
	enrager.spells = ["a2_rage_draught"]
	enrager.attacks = [
		MonsterAttack.create_basic("Fiery Claw", "1d4", 2),
	]
	enrager.grid_position = Vector2i(2, 0)
	enrager.init_combat()
	monsters.append(enrager)

	return monsters


func _analyze_turn(turn_data: Dictionary) -> void:
	var action: String = turn_data.get("action", "")
	var is_player: bool = turn_data.get("is_player", false)
	var skipped: bool = turn_data.get("skipped", false)

	var is_mental := action.begins_with("mental") or action.begins_with("berserk")

	if is_mental:
		mental_turns_total += 1
		if is_player:
			player_mental_turns += 1
		else:
			monster_mental_turns += 1

		match action:
			"mental_attack":
				if is_player:
					var damage: int = turn_data.get("damage", 0)
					if turn_data.get("hit", false):
						friendly_fire_damage += damage
				else:
					_check_monster_friendly_fire(turn_data)
			"mental_defend":
				if is_player:
					mental_turns_confused_defend += 1
			"mental_daze":
				if is_player:
					mental_turns_confused_daze += 1
			"berserk_attack":
				if is_player:
					mental_turns_berserk_attack += 1
				var damage: int = turn_data.get("damage", 0)
				if turn_data.get("hit", false):
					berserk_hits += 1
					berserk_damage += damage
				else:
					berserk_misses += 1
	elif not skipped:
		normal_turns += 1

	_check_snap_outs(turn_data.get("tick_messages", []))
	_check_snap_outs(turn_data.get("messages", []))


func _check_snap_outs(messages: Variant) -> void:
	if messages is Array:
		for msg in messages:
			if msg is String:
				if "snaps out of confusion" in msg:
					snap_outs_confused += 1
				elif "breaks free from the charm" in msg:
					snap_outs_charmed += 1


func _check_monster_friendly_fire(turn_data: Dictionary) -> void:
	var target_name: String = turn_data.get("target", "")
	if target_name in ["Mind Flayer", "Siren", "Rage Demon"]:
		monster_confused_ally_hits += 1


func _print_results() -> void:
	print("=" .repeat(70))
	print("RESULTS (%d runs)" % NUM_RUNS)
	print("=" .repeat(70))
	print("")

	print("Combat Outcomes:")
	print("  Victories: %d (%.1f%%)" % [victories, float(victories) / NUM_RUNS * 100.0])
	print("  Defeats:   %d (%.1f%%)" % [defeats, float(defeats) / NUM_RUNS * 100.0])
	print("  Avg turns: %.1f" % (float(total_turns) / NUM_RUNS))
	print("")

	print("-" .repeat(70))
	print("Turn Breakdown:")
	print("-" .repeat(70))
	var all_turns := mental_turns_total + normal_turns
	print("  Normal turns:         %d" % normal_turns)
	print("  Mental status turns:  %d (player: %d, monster: %d)" % [
		mental_turns_total, player_mental_turns, monster_mental_turns])
	if all_turns > 0:
		print("  Mental turn ratio:    %.1f%% of all turns" % (float(mental_turns_total) / float(all_turns) * 100.0))
	print("")

	print("-" .repeat(70))
	print("Player Mental Status Actions:")
	print("-" .repeat(70))
	print("  Berserk attacks:  %d" % mental_turns_berserk_attack)
	if berserk_hits + berserk_misses > 0:
		print("    Hit rate:       %.1f%% (%d/%d)" % [
			float(berserk_hits) / float(berserk_hits + berserk_misses) * 100.0,
			berserk_hits, berserk_hits + berserk_misses])
		if berserk_hits > 0:
			print("    Avg damage:     %.1f per hit" % (float(berserk_damage) / float(berserk_hits)))
	print("  Confused defends: %d" % mental_turns_confused_defend)
	print("  Confused dazes:   %d" % mental_turns_confused_daze)
	var mental_attacks := player_mental_turns - mental_turns_berserk_attack - mental_turns_confused_defend - mental_turns_confused_daze
	print("  Mental attacks:   %d (confused/charmed attack or spell)" % mental_attacks)
	print("")

	print("-" .repeat(70))
	print("Friendly Fire:")
	print("-" .repeat(70))
	print("  Player-on-player damage: %d total" % friendly_fire_damage)
	print("  Monster-on-monster hits:  %d" % monster_confused_ally_hits)
	print("")

	print("-" .repeat(70))
	print("Snap-Out Events (on damage):")
	print("-" .repeat(70))
	print("  Confused snap-outs: %d (expected ~25%% of hits on confused)" % snap_outs_confused)
	print("  Charmed snap-outs:  %d (expected ~15%% of hits on charmed)" % snap_outs_charmed)
	print("")

	print("=" .repeat(70))
	print("Expected Action Distributions (from constants):")
	print("  Confused: 40%% attack, 25%% spell, 20%% defend, 15%% daze")
	print("  Charmed:  50%% attack, 35%% spell, 15%% defend")
	print("  Berserk:  100%% attack with 1.5x damage multiplier")
	print("  Snap-out: 25%% confused, 15%% charmed (per damage hit)")
	print("=" .repeat(70))
