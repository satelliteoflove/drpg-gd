extends SceneTree

const BASE_SEED := 30000
const NUM_RUNS := 50


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("=" .repeat(70))
	print("UNDEAD SCENARIO TESTS")
	print("=" .repeat(70))
	print("")
	print("Party: 2 Fighters, Priest, Mage, Bishop, Thief")
	print("Enemies: Mixed Skeletons + Ghosts")
	print("Runs per scenario: %d" % NUM_RUNS)
	print("")

	print("=" .repeat(70))
	print("SCENARIO 1: Early Game (Party Lv3 vs Floor 2 Undead)")
	print("=" .repeat(70))
	print("")
	_run_level_scenario(3, ["skeleton", "skeleton", "ghost"])

	print("")
	print("=" .repeat(70))
	print("SCENARIO 2: Mid Game (Party Lv5 vs Floor 4 Undead)")
	print("=" .repeat(70))
	print("")
	_run_level_scenario(5, ["skeleton", "skeleton", "ghost", "ghost"])

	print("")
	print("=" .repeat(70))
	print("SCENARIO 3: Mid-Late Game (Party Lv7 vs Floor 6 Undead)")
	print("=" .repeat(70))
	print("")
	_run_level_scenario(7, ["ghost", "ghost", "ghost"])

	print("")
	print("=" .repeat(70))
	print("SCENARIO 4: Challenging (Party Lv5 vs Floor 6 Undead)")
	print("=" .repeat(70))
	print("")
	_run_level_scenario(5, ["ghost", "ghost", "ghost"])

	print("")
	print("=" .repeat(70))
	print("SCENARIO 5: Swarm (Party Lv5 vs Many Weak Undead)")
	print("=" .repeat(70))
	print("")
	_run_level_scenario(5, ["skeleton", "skeleton", "skeleton", "skeleton", "zombie", "zombie"])

	print("")
	print("=" .repeat(70))
	print("TESTS COMPLETE")
	print("=" .repeat(70))

	quit(0)


func _run_level_scenario(party_level: int, monster_ids: Array) -> void:
	var party := _create_standard_party(party_level)

	var typed_ids: Array[String] = []
	for id in monster_ids:
		typed_ids.append(id)
	var enemies := TestFixtures.create_monster_group(typed_ids)

	var enemy_desc := ""
	var enemy_counts: Dictionary = {}
	for id in monster_ids:
		if not enemy_counts.has(id):
			enemy_counts[id] = 0
		enemy_counts[id] += 1
	for id in enemy_counts:
		if enemy_desc != "":
			enemy_desc += ", "
		enemy_desc += "%dx %s" % [enemy_counts[id], id.capitalize()]

	print("Party Level: %d" % party_level)
	print("Enemies: %s" % enemy_desc)
	print("")

	_run_and_report(party, enemies)


func _create_standard_party(level: int) -> Party:
	var party := Party.new()

	var fighter1 := _create_char("Fighter1", CharacterEnums.CharacterClass.FIGHTER, level)
	var fighter2 := _create_char("Fighter2", CharacterEnums.CharacterClass.FIGHTER, level)
	var priest := _create_char("Priest", CharacterEnums.CharacterClass.PRIEST, level)
	var mage := _create_char("Mage", CharacterEnums.CharacterClass.MAGE, level)
	var bishop := _create_char("Bishop", CharacterEnums.CharacterClass.BISHOP, level)
	var thief := _create_char("Thief", CharacterEnums.CharacterClass.THIEF, level)

	party.add_member(fighter1)
	party.add_member(fighter2)
	party.add_member(priest)
	party.add_member(mage)
	party.add_member(bishop)
	party.add_member(thief)

	return party


func _create_char(char_name: String, char_class: CharacterEnums.CharacterClass, level: int) -> Character:
	var stats := {
		"strength": 12,
		"intelligence": 12,
		"piety": 12,
		"vitality": 12,
		"agility": 12,
		"luck": 12
	}

	match char_class:
		CharacterEnums.CharacterClass.FIGHTER:
			stats["strength"] = 16
			stats["vitality"] = 14
		CharacterEnums.CharacterClass.MAGE:
			stats["intelligence"] = 16
		CharacterEnums.CharacterClass.PRIEST:
			stats["piety"] = 16
		CharacterEnums.CharacterClass.THIEF:
			stats["agility"] = 16
			stats["luck"] = 14
		CharacterEnums.CharacterClass.BISHOP:
			stats["intelligence"] = 14
			stats["piety"] = 14

	var character := Character.create_new(
		char_name,
		CharacterEnums.Race.HUMAN,
		char_class,
		CharacterEnums.Alignment.NEUTRAL,
		CharacterEnums.Gender.MALE,
		stats
	)

	for i in range(level - 1):
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


func _run_and_report(party: Party, enemies: Array[Monster]) -> void:
	CombatRNG.set_seed(BASE_SEED)

	var batch := BatchSimulator.new()
	var result := batch.run_batch(party, enemies, NUM_RUNS, BASE_SEED)

	var dispel_by_caster: Dictionary = {}
	var dispel_success_by_caster: Dictionary = {}
	var total_xp := 0
	var xp_lost := 0
	var total_hits: Dictionary = {}
	var total_misses: Dictionary = {}
	var spells_cast_by_caster: Dictionary = {}
	var physical_damage_by_actor: Dictionary = {}
	var spell_damage_by_actor: Dictionary = {}
	var total_physical := 0
	var total_spell := 0

	for run_result in result.results:
		var metrics_data: Dictionary = run_result.get("metrics", {})

		var attempts: Dictionary = metrics_data.get("dispels_attempted", {})
		var successes: Dictionary = metrics_data.get("dispels_succeeded", {})
		for caster in attempts:
			if not dispel_by_caster.has(caster):
				dispel_by_caster[caster] = 0
			dispel_by_caster[caster] += attempts[caster]
		for caster in successes:
			if not dispel_success_by_caster.has(caster):
				dispel_success_by_caster[caster] = 0
			dispel_success_by_caster[caster] += successes[caster]

		total_xp += metrics_data.get("total_xp_earned", 0)
		xp_lost += metrics_data.get("xp_lost_to_dispels", 0)

		var hits: Dictionary = metrics_data.get("attacks_hit", {})
		var misses: Dictionary = metrics_data.get("attacks_missed", {})
		for attacker in hits:
			if not total_hits.has(attacker):
				total_hits[attacker] = 0
			total_hits[attacker] += hits[attacker]
		for attacker in misses:
			if not total_misses.has(attacker):
				total_misses[attacker] = 0
			total_misses[attacker] += misses[attacker]

		var spells: Dictionary = metrics_data.get("spells_cast", {})
		for caster in spells:
			if not spells_cast_by_caster.has(caster):
				spells_cast_by_caster[caster] = {}
			var caster_spells: Dictionary = spells[caster]
			for spell_id in caster_spells:
				if not spells_cast_by_caster[caster].has(spell_id):
					spells_cast_by_caster[caster][spell_id] = 0
				spells_cast_by_caster[caster][spell_id] += caster_spells[spell_id]

		var phys_dmg: Dictionary = metrics_data.get("physical_damage_dealt", {})
		var spell_dmg: Dictionary = metrics_data.get("spell_damage_dealt", {})
		for actor in phys_dmg:
			if not physical_damage_by_actor.has(actor):
				physical_damage_by_actor[actor] = 0
			physical_damage_by_actor[actor] += phys_dmg[actor]
		for actor in spell_dmg:
			if not spell_damage_by_actor.has(actor):
				spell_damage_by_actor[actor] = 0
			spell_damage_by_actor[actor] += spell_dmg[actor]
		total_physical += metrics_data.get("total_physical_damage", 0)
		total_spell += metrics_data.get("total_spell_damage", 0)

	var avg_xp := float(total_xp) / float(NUM_RUNS)
	var avg_xp_lost := float(xp_lost) / float(NUM_RUNS)

	print("RESULTS:")
	print("  Win Rate: %.0f%% (%d victories, %d defeats)" % [
		result.win_rate, result.victories, result.defeats
	])
	print("  Avg Turns: %.1f | Avg HP Remaining: %.0f%%" % [
		result.avg_turns, result.avg_hp_remaining_on_victory
	])
	print("  Avg XP Earned: %.1f | Avg XP Lost to Dispel: %.1f" % [avg_xp, avg_xp_lost])
	print("")

	if result.defeats > 0:
		print("  Defeat Analysis:")
		print("    Most common cause: %s" % result.most_common_cause_of_defeat)
		for cause in result.death_causes:
			var count: int = result.death_causes[cause]
			print("    - %s: %d deaths" % [cause, count])
		print("")

	print("  Hit Rates by Character:")
	var party_names := ["Fighter1", "Fighter2", "Priest", "Mage", "Bishop", "Thief"]
	for name in party_names:
		var h: int = total_hits.get(name, 0)
		var m: int = total_misses.get(name, 0)
		var total := h + m
		if total > 0:
			var rate := float(h) / float(total) * 100.0
			print("    %s: %.0f%% (%d/%d)" % [name, rate, h, total])
	print("")

	print("  Hit Rates by Enemy:")
	for attacker in total_hits:
		if attacker in party_names:
			continue
		var h: int = total_hits.get(attacker, 0)
		var m: int = total_misses.get(attacker, 0)
		var total := h + m
		if total > 0:
			var rate := float(h) / float(total) * 100.0
			print("    %s: %.0f%% (%d/%d)" % [attacker, rate, h, total])
	print("")

	var total_dmg := total_physical + total_spell
	if total_dmg > 0:
		var phys_pct := float(total_physical) / float(total_dmg) * 100.0
		var spell_pct := float(total_spell) / float(total_dmg) * 100.0
		print("  Damage Breakdown: Physical %.0f%% (%d) | Spell %.0f%% (%d)" % [
			phys_pct, total_physical, spell_pct, total_spell
		])
		print("")

	if not physical_damage_by_actor.is_empty() or not spell_damage_by_actor.is_empty():
		print("  Damage by Character:")
		for name in party_names:
			var phys: int = physical_damage_by_actor.get(name, 0)
			var spell: int = spell_damage_by_actor.get(name, 0)
			var char_total := phys + spell
			if char_total > 0:
				if spell > 0 and phys > 0:
					print("    %s: %d total (Physical: %d, Spell: %d)" % [name, char_total, phys, spell])
				elif spell > 0:
					print("    %s: %d (Spell only)" % [name, spell])
				else:
					print("    %s: %d (Physical only)" % [name, phys])
		print("")

	if not spells_cast_by_caster.is_empty():
		print("  Spells Cast:")
		for caster in spells_cast_by_caster:
			var spell_list: Array[String] = []
			var caster_spells: Dictionary = spells_cast_by_caster[caster]
			for spell_id in caster_spells:
				spell_list.append("%s x%d" % [spell_id, caster_spells[spell_id]])
			print("    %s: %s" % [caster, ", ".join(spell_list)])
		print("")

	if not dispel_by_caster.is_empty():
		print("  Dispel Performance:")
		for caster in dispel_by_caster:
			var att: int = dispel_by_caster.get(caster, 0)
			var suc: int = dispel_success_by_caster.get(caster, 0)
			var rate := float(suc) / float(att) * 100.0 if att > 0 else 0.0
			print("    %s: %.0f%% success (%d/%d)" % [caster, rate, suc, att])
		print("")
