extends TestBase


func _specs() -> Array:
	var specs: Array = DungeonSet.DUNGEONS.duplicate()
	specs.append(DungeonSet.FINAL)
	return specs


func test_every_dungeon_has_its_own_master() -> void:
	var seen := {}
	for spec in _specs():
		var master := MonsterDatabase.get_monster(spec["master"])
		assert_not_null(master, spec["master"])
		assert_eq(master.monster_name, spec["master_name"])
		assert_true(master.is_boss)
		seen[spec["master"]] = true
	assert_eq(seen.size(), DungeonSet.SIZE + 1)


func test_new_set_points_each_dungeon_at_its_master() -> void:
	var dungeon_set := DungeonSet.create()
	for i in DungeonSet.SIZE:
		assert_eq(dungeon_set.dungeons[i].master_id, DungeonSet.DUNGEONS[i]["master"])
	assert_eq(dungeon_set.open_final().master_id, DungeonSet.FINAL["master"])


func test_the_four_masters_share_their_stats() -> void:
	var drake := MonsterDatabase.get_monster("boss_drake")
	for spec in DungeonSet.DUNGEONS:
		var master := MonsterDatabase.get_monster(spec["master"])
		for stat in ["max_hp", "strength", "agility", "defense", "evasion", "level", "exp_reward"]:
			assert_eq(master.get(stat), drake.get(stat), "%s %s" % [spec["master"], stat])
		assert_eq(master.extra_actions, drake.extra_actions)
		assert_eq(master.attacks.size(), drake.attacks.size())


func test_final_master_is_tougher() -> void:
	var drake := MonsterDatabase.get_monster("boss_drake")
	var king := MonsterDatabase.get_monster(DungeonSet.FINAL["master"])
	assert_gt(king.max_hp, drake.max_hp)


func test_master_phases_name_attacks_it_has() -> void:
	for spec in _specs():
		var master := MonsterDatabase.get_monster(spec["master"])
		var names: Array = master.attacks.map(func(a: MonsterAttack) -> String: return a.attack_name)
		assert_eq(master.boss_phases.size(), 4)
		for phase in master.boss_phases:
			var prefs: Dictionary = phase["attack_preferences"]
			for attack_name in prefs["prefer"] + prefs["avoid"]:
				assert_has(names, attack_name, spec["master"])


func test_every_master_has_minions_that_exist() -> void:
	for spec in _specs():
		var minions := MonsterDatabase.get_minions_of(spec["master"])
		assert_not_empty(minions, spec["master"])
		for minion_id in minions:
			assert_not_null(MonsterDatabase.get_monster(minion_id), minion_id)


func test_stock_bosses_keep_their_minions() -> void:
	assert_eq(MonsterDatabase.get_boss_minions(2), ["spider", "spider"] as Array[String])
	assert_eq(MonsterDatabase.get_boss_minions(3), [] as Array[String])


func test_weakness_and_resistance_change_spell_damage() -> void:
	var plain := _fire_damage_to("boss_drake")
	assert_gt(plain, 0)
	assert_eq(_fire_damage_to("boss_ash_wyrm"), plain / 2)
	assert_eq(_fire_damage_to("boss_pale_wyrm"), plain * 3 / 2)


func _fire_damage_to(monster_id: String) -> int:
	var caster: Character = TestFixtures.create_solo_character(CharacterEnums.CharacterClass.MAGE, 5).get_members()[0]
	var target := MonsterDatabase.get_monster(monster_id)
	target.init_combat()
	var effect := SpellEffect.create_damage(CharacterEnums.Element.FIRE, "40d1", 0)
	var result := SpellCaster._process_damage(caster, effect, [target])
	return result["damage"]


func test_older_save_gives_each_dungeon_its_master() -> void:
	var dungeon_set := DungeonSet.create()
	dungeon_set.open_final()
	for d in dungeon_set.dungeons:
		d.master_id = "boss_drake"
	dungeon_set.final_dungeon.master_id = "boss_drake"
	dungeon_set.update_from_older_save()
	for i in DungeonSet.SIZE:
		assert_eq(dungeon_set.dungeons[i].master_id, DungeonSet.DUNGEONS[i]["master"])
	assert_eq(dungeon_set.final_dungeon.master_id, DungeonSet.FINAL["master"])
