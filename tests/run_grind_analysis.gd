extends SceneTree

const CombatRNG = preload("res://autoload/combat_rng.gd")
const TestFixtures = preload("res://systems/simulation/test_fixtures.gd")
const CombatSimulatorRef = preload("res://systems/simulation/combat_simulator.gd")
const PartyAI = preload("res://systems/simulation/party_ai.gd")
const XPTable = preload("res://resources/experience_table.gd")
const CharEnum = preload("res://resources/character_enums.gd")
const ShopItems = preload("res://data/items/shop_items.gd")

const BASE_SEED := 77777
const CAST_THRESHOLD := 0.5
const TOWN_TRIP_HP_THRESHOLD := 0.4
const TOWN_TRIP_MP_THRESHOLD := 0.2


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("=" .repeat(70))
	print("GRIND ANALYSIS: Battles to Level Up")
	print("=" .repeat(70))
	print("")
	print("Rules:")
	print("  - Return to town when HP < %.0f%% or MP < %.0f%% or anyone dies" % [
		TOWN_TRIP_HP_THRESHOLD * 100, TOWN_TRIP_MP_THRESHOLD * 100
	])
	print("  - Town trip = full HP/MP restore")
	print("  - Full XP to all living members (no split)")
	print("")

	_run_fresh_start_grind()
	print("")
	_run_trained_party_grind()
	print("")
	_run_fighter_only_grind()
	print("")
	_run_level_5_to_6_grind()

	print("")
	print("=" .repeat(70))
	quit(0)


func _run_fresh_start_grind() -> void:
	print("-" .repeat(70))
	print("SCENARIO: Fresh Level 1 Party -> All Level 2 (Floor 1)")
	print("-" .repeat(70))
	print("")

	CombatRNG.set_seed(BASE_SEED)
	var party := _create_level_1_party()

	print("Starting Party:")
	for member in party.get_members():
		var xp_needed := XPTable.get_xp_to_next_level(member.experience, member.level, member.race, member.character_class)
		print("  %s (Lv%d %s) - HP:%d MP:%d - Need %d XP" % [
			member.character_name, member.level,
			CharEnum.get_class_name(member.character_class),
			member.max_hp, member.max_mp, xp_needed
		])
	print("")

	var results := _run_grind_loop(party, 1, 2, BASE_SEED, 500)
	_print_detailed_results(results, party)


func _run_trained_party_grind() -> void:
	print("-" .repeat(70))
	print("SCENARIO: Trained Level 4 Party -> All Level 5 (Floor 1)")
	print("-" .repeat(70))
	print("")

	CombatRNG.set_seed(BASE_SEED + 5000)
	var party := _create_trained_level_4_party()

	print("Starting Party (simulating Training Grounds boost):")
	for member in party.get_members():
		var xp_needed := XPTable.get_xp_to_next_level(member.experience, member.level, member.race, member.character_class)
		print("  %s (Lv%d %s) - HP:%d MP:%d - Need %d XP" % [
			member.character_name, member.level,
			CharEnum.get_class_name(member.character_class),
			member.max_hp, member.max_mp, xp_needed
		])
	print("")

	var results := _run_grind_loop(party, 1, 5, BASE_SEED + 5000, 500)
	_print_detailed_results(results, party)


func _run_fighter_only_grind() -> void:
	print("-" .repeat(70))
	print("SCENARIO: 4x Fighter Level 1 Party -> All Level 2 (Floor 1)")
	print("-" .repeat(70))
	print("")

	CombatRNG.set_seed(BASE_SEED + 7000)
	var party := _create_fighter_only_party()

	print("Starting Party (all fighters, no fragile casters):")
	for member in party.get_members():
		var xp_needed := XPTable.get_xp_to_next_level(member.experience, member.level, member.race, member.character_class)
		print("  %s (Lv%d %s) - HP:%d MP:%d - Need %d XP" % [
			member.character_name, member.level,
			CharEnum.get_class_name(member.character_class),
			member.max_hp, member.max_mp, xp_needed
		])
	print("")

	var results := _run_grind_loop(party, 1, 2, BASE_SEED + 7000, 500)
	_print_detailed_results(results, party)


func _run_level_5_to_6_grind() -> void:
	print("-" .repeat(70))
	print("SCENARIO: Level 5 Party -> All Level 6 (Floor 3)")
	print("-" .repeat(70))
	print("")

	CombatRNG.set_seed(BASE_SEED + 10000)
	var party := TestFixtures.create_balanced_party(5)

	for member in party.get_members():
		member.experience = XPTable.get_required_xp(5, member.race, member.character_class)

	print("Starting Party:")
	for member in party.get_members():
		var xp_needed := XPTable.get_xp_to_next_level(member.experience, member.level, member.race, member.character_class)
		print("  %s (Lv%d %s) - HP:%d MP:%d - Need %d XP" % [
			member.character_name, member.level,
			CharEnum.get_class_name(member.character_class),
			member.max_hp, member.max_mp, xp_needed
		])
	print("")

	var results := _run_grind_loop(party, 3, 6, BASE_SEED + 10000, 2000)
	_print_detailed_results(results, party)


func _create_level_1_party() -> Party:
	var party := Party.new()

	var fighter1 := _create_character("Roland", CharEnum.CharacterClass.FIGHTER, 1)
	var fighter2 := _create_character("Gareth", CharEnum.CharacterClass.FIGHTER, 1)
	var priest := _create_character("Elena", CharEnum.CharacterClass.PRIEST, 1)
	var thief := _create_character("Shade", CharEnum.CharacterClass.THIEF, 1)
	var mage := _create_character("Vance", CharEnum.CharacterClass.MAGE, 1)
	var bishop := _create_character("Aldric", CharEnum.CharacterClass.BISHOP, 1)

	_equip_starter_gear(fighter1)
	_equip_starter_gear(fighter2)
	_equip_starter_gear(priest)
	_equip_starter_gear(thief)
	_equip_starter_gear(mage)
	_equip_starter_gear(bishop)

	party.add_member(fighter1)  # front row - tank
	party.add_member(fighter2)  # front row - tank
	party.add_member(priest)    # front row - healer but can take a hit
	party.add_member(thief)     # back row
	party.add_member(mage)      # back row - protected!
	party.add_member(bishop)    # back row

	return party


func _create_character(char_name: String, char_class: CharEnum.CharacterClass, _level: int) -> Character:
	var stats := {
		"strength": 12, "intelligence": 12, "piety": 12,
		"vitality": 12, "agility": 12, "luck": 12
	}

	match char_class:
		CharEnum.CharacterClass.FIGHTER:
			stats["strength"] = 16
			stats["vitality"] = 14
		CharEnum.CharacterClass.MAGE:
			stats["intelligence"] = 16
		CharEnum.CharacterClass.PRIEST:
			stats["piety"] = 16
		CharEnum.CharacterClass.THIEF:
			stats["agility"] = 16
			stats["luck"] = 14

	var character := Character.create_new(
		char_name, CharEnum.Race.HUMAN, char_class,
		CharEnum.Alignment.NEUTRAL, CharEnum.Gender.MALE, stats
	)

	character.current_hp = character.max_hp
	character.current_mp = character.max_mp

	return character


func _all_members_level_2(party: Party) -> bool:
	for member in party.get_members():
		if member.level < 2:
			return false
	return true


func _all_members_level_6(party: Party) -> bool:
	for member in party.get_members():
		if member.level < 6:
			return false
	return true


func _needs_town_trip(party: Party) -> bool:
	var total_hp := 0
	var total_max_hp := 0
	var total_mp := 0
	var total_max_mp := 0

	for member in party.get_members():
		if member.is_dead:
			return true
		total_hp += member.current_hp
		total_max_hp += member.max_hp
		total_mp += member.current_mp
		total_max_mp += member.max_mp

	var hp_percent := float(total_hp) / float(maxi(1, total_max_hp))
	var mp_percent := float(total_mp) / float(maxi(1, total_max_mp))

	return hp_percent < TOWN_TRIP_HP_THRESHOLD or mp_percent < TOWN_TRIP_MP_THRESHOLD


func _full_restore(party: Party) -> void:
	for member in party.get_members():
		member.is_dead = false
		member.current_hp = member.max_hp
		member.current_mp = member.max_mp
		member.status_effects.clear()
		member.active_statuses.clear()


func _process_level_ups(party: Party) -> void:
	for member in party.get_members():
		while member.pending_level_up:
			if not member.confirm_level_up():
				break


func _create_trained_level_4_party() -> Party:
	var party := Party.new()

	var fighter1 := _create_character("Roland", CharEnum.CharacterClass.FIGHTER, 1)
	var fighter2 := _create_character("Gareth", CharEnum.CharacterClass.FIGHTER, 1)
	var priest := _create_character("Elena", CharEnum.CharacterClass.PRIEST, 1)
	var thief := _create_character("Shade", CharEnum.CharacterClass.THIEF, 1)
	var mage := _create_character("Vance", CharEnum.CharacterClass.MAGE, 1)
	var bishop := _create_character("Aldric", CharEnum.CharacterClass.BISHOP, 1)

	for member in [fighter1, fighter2, priest, thief, mage, bishop]:
		_equip_starter_gear(member)
		member.level = 4
		member.experience = XPTable.get_required_xp(4, member.race, member.character_class)
		member._recalculate_derived_stats()
		member.current_hp = member.max_hp
		member.current_mp = member.max_mp

	party.add_member(fighter1)  # front row - tank
	party.add_member(fighter2)  # front row - tank
	party.add_member(priest)    # front row
	party.add_member(thief)     # back row
	party.add_member(mage)      # back row - protected!
	party.add_member(bishop)    # back row

	return party


func _create_fighter_only_party() -> Party:
	var party := Party.new()

	for i in range(6):
		var fighter := _create_character("Fighter%d" % (i + 1), CharEnum.CharacterClass.FIGHTER, 1)
		party.add_member(fighter)

	return party


func _run_grind_loop(party: Party, floor_level: int, target_level: int, seed_base: int, max_battles: int) -> Dictionary:
	var battles := 0
	var victories := 0
	var losses := 0
	var total_xp_earned := 0
	var town_trips := 0
	var town_trip_reasons := {"hp": 0, "mp": 0, "death": 0}
	var total_enemies_faced := 0
	var total_damage_taken := 0

	while not _all_members_at_level(party, target_level):
		var trip_reason := _get_town_trip_reason(party)
		if trip_reason != "":
			town_trips += 1
			town_trip_reasons[trip_reason] += 1
			_full_restore(party)

		var hp_before := _get_total_hp(party)
		var enemies := TestFixtures.create_floor_encounter(floor_level)
		total_enemies_faced += enemies.size()

		var simulator := CombatSimulatorRef.new()
		simulator.cast_threshold = CAST_THRESHOLD
		simulator.party_strategy = PartyAI.Strategy.BALANCED
		simulator.setup(party, enemies, seed_base + battles * 100)
		var result := simulator.run()

		battles += 1
		var hp_after := _get_total_hp(party)
		total_damage_taken += maxi(0, hp_before - hp_after)

		if result.victory:
			victories += 1
			var xp: int = result.metrics.get("total_xp_earned", 0)
			total_xp_earned += xp
			party.distribute_experience(xp)
			_process_level_ups(party)
		else:
			losses += 1

		if battles >= max_battles:
			break

	return {
		"battles": battles,
		"victories": victories,
		"losses": losses,
		"total_xp": total_xp_earned,
		"town_trips": town_trips,
		"trip_reasons": town_trip_reasons,
		"enemies_faced": total_enemies_faced,
		"damage_taken": total_damage_taken,
		"target_reached": _all_members_at_level(party, target_level)
	}


func _print_detailed_results(results: Dictionary, party: Party) -> void:
	print("Results:")
	print("  Total battles: %d (Won: %d, Lost: %d)" % [
		results["battles"], results["victories"], results["losses"]
	])
	print("  Win rate: %.1f%%" % (100.0 * results["victories"] / maxi(1, results["battles"])))
	print("  Town trips: %d (HP: %d, MP: %d, Death: %d)" % [
		results["town_trips"],
		results["trip_reasons"]["hp"],
		results["trip_reasons"]["mp"],
		results["trip_reasons"]["death"]
	])
	print("  Avg battles per trip: %.1f" % (float(results["battles"]) / float(maxi(1, results["town_trips"] + 1))))
	print("  Total XP earned: %d" % results["total_xp"])
	print("  Avg XP per victory: %.1f" % (float(results["total_xp"]) / float(maxi(1, results["victories"]))))
	print("  Avg enemies per battle: %.1f" % (float(results["enemies_faced"]) / float(maxi(1, results["battles"]))))
	print("  Avg damage taken per battle: %.1f" % (float(results["damage_taken"]) / float(maxi(1, results["battles"]))))
	if not results["target_reached"]:
		print("  WARNING: Target level not reached!")
	print("")
	print("Final Party:")
	for member in party.get_members():
		print("  %s - Level %d, XP: %d" % [member.character_name, member.level, member.experience])


func _all_members_at_level(party: Party, target_level: int) -> bool:
	for member in party.get_members():
		if member.level < target_level:
			return false
	return true


func _get_town_trip_reason(party: Party) -> String:
	var total_hp := 0
	var total_max_hp := 0
	var total_mp := 0
	var total_max_mp := 0

	for member in party.get_members():
		if member.is_dead:
			return "death"
		total_hp += member.current_hp
		total_max_hp += member.max_hp
		total_mp += member.current_mp
		total_max_mp += member.max_mp

	var hp_percent := float(total_hp) / float(maxi(1, total_max_hp))

	if hp_percent < TOWN_TRIP_HP_THRESHOLD:
		return "hp"
	if total_max_mp > 0:
		var mp_percent := float(total_mp) / float(total_max_mp)
		if mp_percent < TOWN_TRIP_MP_THRESHOLD:
			return "mp"
	return ""


func _get_total_hp(party: Party) -> int:
	var total := 0
	for member in party.get_members():
		total += member.current_hp
	return total


func _equip_starter_gear(character: Character) -> void:
	match character.character_class:
		CharEnum.CharacterClass.FIGHTER, CharEnum.CharacterClass.SAMURAI, CharEnum.CharacterClass.LORD:
			character.equip_item(ShopItems.get_item("short_sword").duplicate())
			character.equip_item(ShopItems.get_item("leather_armor").duplicate())
			character.equip_item(ShopItems.get_item("leather_cap").duplicate())
			character.equip_item(ShopItems.get_item("wooden_shield").duplicate())
		CharEnum.CharacterClass.PRIEST:
			character.equip_item(ShopItems.get_item("staff").duplicate())
			character.equip_item(ShopItems.get_item("cloth_armor").duplicate())
			character.equip_item(ShopItems.get_item("wooden_shield").duplicate())
		CharEnum.CharacterClass.THIEF, CharEnum.CharacterClass.NINJA:
			character.equip_item(ShopItems.get_item("dagger").duplicate())
			character.equip_item(ShopItems.get_item("leather_armor").duplicate())
		CharEnum.CharacterClass.MAGE, CharEnum.CharacterClass.ALCHEMIST, CharEnum.CharacterClass.PSIONIC:
			character.equip_item(ShopItems.get_item("staff").duplicate())
			character.equip_item(ShopItems.get_item("cloth_armor").duplicate())
		CharEnum.CharacterClass.BISHOP:
			character.equip_item(ShopItems.get_item("staff").duplicate())
			character.equip_item(ShopItems.get_item("cloth_armor").duplicate())
		_:
			character.equip_item(ShopItems.get_item("short_sword").duplicate())
			character.equip_item(ShopItems.get_item("cloth_armor").duplicate())
