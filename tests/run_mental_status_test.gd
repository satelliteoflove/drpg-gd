extends SceneTree

const BASE_SEED := 20000
const NUM_RUNS := 100
const PARTY_LEVEL := 5

var mental_turns_confused_attack := 0
var mental_turns_confused_spell := 0
var mental_turns_confused_defend := 0
var mental_turns_confused_daze := 0
var mental_turns_charmed_attack := 0
var mental_turns_charmed_spell := 0
var mental_turns_charmed_defend := 0
var mental_turns_berserk_attack := 0
var mental_turns_total := 0
var normal_turns := 0
var snap_outs_confused := 0
var snap_outs_charmed := 0
var statuses_applied_confused := 0
var statuses_applied_charmed := 0
var statuses_applied_berserk := 0
var ally_kills := 0
var friendly_fire_damage := 0
var berserk_damage := 0
var berserk_hits := 0
var berserk_misses := 0
var victories := 0
var defeats := 0
var total_turns := 0
var monster_mental_turns := 0
var monster_confused_ally_hits := 0
var monster_charmed_ally_hits := 0


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	print("=" .repeat(70))
	print("Mental Status Effects Stress Test")
	print("=" .repeat(70))
	print("")
	print("Configuration:")
	print("  Runs: %d | Party level: %d | Seed base: %d" % [NUM_RUNS, PARTY_LEVEL, BASE_SEED])
	print("  Monsters: custom mental-status-heavy enemies")
	print("")

	for i in range(NUM_RUNS):
		_run_single_combat(BASE_SEED + i)

	_print_results()
	quit(0)


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

	var result := sim._build_result()
	total_turns += result.turns
	if result.victory:
		victories += 1
	else:
		defeats += 1


func _create_mental_status_enemies() -> Array[Monster]:
	var monsters: Array[Monster] = []

	var confuser := Monster.new()
	confuser.monster_name = "Mind Flayer"
	confuser.max_hp = 40
	confuser.strength = 10
	confuser.agility = 12
	confuser.defense = 2
	confuser.evasion = 2
	confuser.level = 4
	confuser.intelligence = 14
	confuser.piety = 10
	confuser.vitality = 12
	confuser.luck = 10
	confuser.exp_reward = 50
	confuser.gold_reward_dice = "2d10"
	confuser.attacks = [
		MonsterAttack.create_with_effect(
			"Mind Blast", "1d6", 2,
			CharacterEnums.StatusEffect.CONFUSED, 0.80,
			"3+1d4", "mental", 3
		),
		MonsterAttack.create_basic("Tentacle Slap", "1d4", 1),
	]
	confuser.grid_position = Vector2i(1, 0)
	confuser.init_combat()
	monsters.append(confuser)

	var charmer := Monster.new()
	charmer.monster_name = "Siren"
	charmer.max_hp = 35
	charmer.strength = 8
	charmer.agility = 14
	charmer.defense = 1
	charmer.evasion = 4
	charmer.level = 4
	charmer.intelligence = 16
	charmer.piety = 12
	charmer.vitality = 10
	charmer.luck = 12
	charmer.exp_reward = 55
	charmer.gold_reward_dice = "2d10"
	charmer.max_mp = 20
	charmer.spells = ["m1_spark", "p1_minor_heal"]
	charmer.attacks = [
		MonsterAttack.create_with_effect(
			"Charming Gaze", "1d4", 1,
			CharacterEnums.StatusEffect.CHARMED, 0.75,
			"4+1d4", "mental", 4
		),
		MonsterAttack.create_basic("Claw", "1d6", 2),
	]
	charmer.grid_position = Vector2i(0, 0)
	charmer.init_combat()
	monsters.append(charmer)

	var enrager := Monster.new()
	enrager.monster_name = "Rage Demon"
	enrager.max_hp = 50
	enrager.strength = 14
	enrager.agility = 10
	enrager.defense = 3
	enrager.evasion = 1
	enrager.level = 5
	enrager.intelligence = 8
	enrager.piety = 8
	enrager.vitality = 14
	enrager.luck = 10
	enrager.exp_reward = 60
	enrager.gold_reward_dice = "3d10"
	enrager.attacks = [
		MonsterAttack.create_with_effect(
			"Enraging Howl", "1d6", 3,
			CharacterEnums.StatusEffect.BERSERK, 0.70,
			"4+1d6", "mental", 3
		),
		MonsterAttack.create_basic("Fiery Claw", "2d4", 4),
	]
	enrager.grid_position = Vector2i(2, 0)
	enrager.init_combat()
	monsters.append(enrager)

	return monsters


func _analyze_turn(turn_data: Dictionary) -> void:
	var action: String = turn_data.get("action", "")
	var is_player: bool = turn_data.get("is_player", false)
	var skipped: bool = turn_data.get("skipped", false)

	if action.begins_with("mental") or action.begins_with("berserk") or action.begins_with("confused") or action.begins_with("charmed"):
		mental_turns_total += 1
		if not is_player:
			monster_mental_turns += 1

		match action:
			"mental_attack":
				if is_player:
					var damage: int = turn_data.get("damage", 0)
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
				berserk_damage += turn_data.get("damage", 0)
				if turn_data.get("hit", false):
					berserk_hits += 1
				else:
					berserk_misses += 1
				if is_player:
					mental_turns_berserk_attack += 1
	else:
		if not skipped:
			normal_turns += 1

	var tick_messages: Array = turn_data.get("tick_messages", [])
	for msg in tick_messages:
		if msg is String:
			if "snaps out of confusion" in msg:
				snap_outs_confused += 1
			elif "breaks free from the charm" in msg:
				snap_outs_charmed += 1

	var messages: Array = turn_data.get("messages", [])
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
	print("  Defeats: %d (%.1f%%)" % [defeats, float(defeats) / NUM_RUNS * 100.0])
	print("  Avg turns per combat: %.1f" % (float(total_turns) / NUM_RUNS))
	print("")

	print("-" .repeat(70))
	print("Mental Status Turn Breakdown (player turns):")
	print("-" .repeat(70))
	print("  Total mental status auto-turns: %d" % mental_turns_total)
	print("  Normal player turns: %d" % normal_turns)
	var pct := float(mental_turns_total) / float(maxi(1, mental_turns_total + normal_turns)) * 100.0
	print("  Mental turns as %% of all turns: %.1f%%" % pct)
	print("")

	print("  Berserk attacks: %d" % mental_turns_berserk_attack)
	print("    Berserk hit rate: %.1f%% (%d/%d)" % [
		float(berserk_hits) / float(maxi(1, berserk_hits + berserk_misses)) * 100.0,
		berserk_hits, berserk_hits + berserk_misses])
	print("    Total berserk damage: %d (avg %.1f per hit)" % [
		berserk_damage, float(berserk_damage) / float(maxi(1, berserk_hits))])
	print("")

	print("  Confused/Charmed defends: %d" % mental_turns_confused_defend)
	print("  Confused/Charmed dazes: %d" % mental_turns_confused_daze)
	print("")

	print("-" .repeat(70))
	print("Friendly Fire:")
	print("-" .repeat(70))
	print("  Total friendly fire damage (player on player): %d" % friendly_fire_damage)
	print("  Monster-on-monster hits (confused/charmed): %d" % monster_confused_ally_hits)
	print("  Monster mental status turns: %d" % monster_mental_turns)
	print("")

	print("-" .repeat(70))
	print("Snap-Out Events:")
	print("-" .repeat(70))
	print("  Confused snap-outs (on damage): %d" % snap_outs_confused)
	print("  Charmed snap-outs (on damage): %d" % snap_outs_charmed)
	print("")

	print("=" .repeat(70))
	print("Expected distributions (from constants):")
	print("  Confused: 40%% attack, 25%% spell, 20%% defend, 15%% daze")
	print("  Charmed: 50%% attack, 35%% spell, 15%% defend")
	print("  Berserk: 100%% attack (1.5x damage)")
	print("  Snap-out: 25%% confused, 15%% charmed (on taking damage)")
	print("=" .repeat(70))
