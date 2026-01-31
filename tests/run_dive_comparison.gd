extends SceneTree

const CombatRNG = preload("res://autoload/combat_rng.gd")
const TestFixtures = preload("res://systems/simulation/test_fixtures.gd")
const DiveSimulator = preload("res://systems/simulation/dive_simulator.gd")
const PartyAI = preload("res://systems/simulation/party_ai.gd")

const BASE_SEED := 50000
const PARTY_LEVEL := 5
const FLOOR_LEVEL := 5
const MAX_ENCOUNTERS := 15
const NUM_DIVES := 30
const REST_HP_PERCENT := 0.25
const REST_MP_PERCENT := 0.10


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("=" .repeat(70))
	print("DUNGEON DIVE EFFICIENCY COMPARISON")
	print("=" .repeat(70))
	print("")
	print("Configuration:")
	print("  Party Level: %d | Floor Level: %d" % [PARTY_LEVEL, FLOOR_LEVEL])
	print("  Max Encounters per Dive: %d | Dives per Test: %d" % [MAX_ENCOUNTERS, NUM_DIVES])
	print("  Rest Between Fights: %.0f%% HP, %.0f%% MP" % [REST_HP_PERCENT * 100, REST_MP_PERCENT * 100])
	print("")

	CombatRNG.set_seed(BASE_SEED)
	var party := TestFixtures.create_balanced_party(PARTY_LEVEL)

	print("Party:")
	for member in party.get_members():
		print("  %s (Lv%d) HP:%d MP:%d" % [
			member.character_name, member.level, member.max_hp, member.max_mp
		])
	print("")

	var dive := DiveSimulator.new()

	var thresholds: Array[float] = [0.0, 0.2, 0.5, 0.8, 1.0]

	print("=" .repeat(70))
	print("COMPARING CAST THRESHOLDS")
	print("=" .repeat(70))
	print("")
	print("Threshold = MP%% above which casters use offensive spells")
	print("  0.0 = Always cast (aggressive)")
	print("  0.5 = Cast when MP > 50%% (balanced)")
	print("  1.0 = Never cast offensively (conserve)")
	print("")

	var results: Array[Dictionary] = []

	for threshold in thresholds:
		var party_copy := _duplicate_party(party)
		var result := dive.run_dive_batch(
			party_copy, FLOOR_LEVEL, MAX_ENCOUNTERS, NUM_DIVES,
			BASE_SEED, threshold, PartyAI.Strategy.BALANCED,
			REST_HP_PERCENT, REST_MP_PERCENT
		)
		results.append(result)

		print("-" .repeat(70))
		print("Cast Threshold: %.0f%%" % (threshold * 100))
		print("-" .repeat(70))
		print("  Avg Encounters: %.1f / %d" % [result.avg_encounters_per_dive, MAX_ENCOUNTERS])
		print("  Avg XP per Dive: %.1f" % result.avg_xp_per_dive)
		print("  Survival Rate: %.0f%% (%d wipes)" % [result.survival_rate, result.total_wipes])

		var total_hp_used := 0
		var total_mp_used := 0
		var total_starting_hp := 0
		var total_starting_mp := 0
		for dive_result in result.dive_results:
			total_hp_used += dive_result.hp_used
			total_mp_used += dive_result.mp_used
			total_starting_hp += dive_result.starting_hp
			total_starting_mp += dive_result.starting_mp

		var avg_hp_pct := float(total_hp_used) / float(maxi(1, total_starting_hp)) * 100.0
		var avg_mp_pct := float(total_mp_used) / float(maxi(1, total_starting_mp)) * 100.0
		print("  Avg HP Used: %.0f%% | Avg MP Used: %.0f%%" % [avg_hp_pct, avg_mp_pct])
		print("")

	print("=" .repeat(70))
	print("SUMMARY")
	print("=" .repeat(70))
	print("")
	print("%-12s | %-12s | %-12s | %-12s" % ["Threshold", "Encounters", "XP/Dive", "Survival"])
	print("-" .repeat(56))

	var best_xp := 0.0
	var best_threshold := 0.0
	for result in results:
		var threshold: float = result.cast_threshold
		print("%-12s | %-12.1f | %-12.1f | %-12.0f%%" % [
			"%.0f%%" % (threshold * 100),
			result.avg_encounters_per_dive,
			result.avg_xp_per_dive,
			result.survival_rate
		])
		if result.avg_xp_per_dive > best_xp:
			best_xp = result.avg_xp_per_dive
			best_threshold = threshold

	print("")
	print("Best Threshold: %.0f%% (%.1f XP/dive)" % [best_threshold * 100, best_xp])
	print("")
	print("=" .repeat(70))

	quit(0)


func _duplicate_party(party: Party) -> Party:
	var new_party := Party.new()
	for member in party.get_members():
		var copy := member.duplicate(true) as Character
		copy.current_hp = copy.max_hp
		copy.current_mp = copy.max_mp
		copy.is_dead = false
		copy.status_effects.clear()
		copy.active_statuses.clear()
		new_party.add_member(copy)
	new_party.gold = party.gold
	return new_party
