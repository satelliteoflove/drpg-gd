extends TestBase

const FLOORS: Array[int] = [2, 4, 6]


func test_every_dungeon_has_its_own_guardians() -> void:
	var seen := {}
	for spec in DungeonSet.DUNGEONS:
		for floor_num in FLOORS:
			var boss_id: String = spec["guardians"].get(floor_num, "")
			var guardian := MonsterDatabase.get_monster(boss_id)
			assert_not_null(guardian, "%s floor %d" % [spec["name"], floor_num])
			assert_true(guardian.is_boss, boss_id)
			seen[boss_id] = true
	assert_eq(seen.size(), DungeonSet.SIZE * FLOORS.size())


func test_first_dungeon_keeps_the_stock_guardians() -> void:
	for floor_num in FLOORS:
		assert_eq(DungeonSet.DUNGEONS[0]["guardians"][floor_num], MonsterDatabase.get_boss_id_for_floor(floor_num))


func test_guardians_of_a_floor_share_their_stats() -> void:
	for floor_num in FLOORS:
		var stock := MonsterDatabase.get_boss_for_floor(floor_num)
		for spec in DungeonSet.DUNGEONS:
			var boss_id: String = spec["guardians"][floor_num]
			var guardian := MonsterDatabase.get_monster(boss_id)
			for stat in ["max_hp", "strength", "agility", "defense", "evasion", "level", "exp_reward",
					"extra_actions", "max_mp", "gold_reward_dice"]:
				assert_eq(guardian.get(stat), stock.get(stat), "%s %s" % [boss_id, stat])
			assert_eq(guardian.attacks.size(), stock.attacks.size(), boss_id)
			assert_eq(guardian.spells.size(), stock.spells.size(), boss_id)


func test_guardian_phases_name_attacks_and_spells_it_has() -> void:
	for spec in DungeonSet.DUNGEONS:
		for floor_num in FLOORS:
			var boss_id: String = spec["guardians"][floor_num]
			var guardian := MonsterDatabase.get_monster(boss_id)
			var names: Array = guardian.attacks.map(func(a: MonsterAttack) -> String: return a.attack_name)
			assert_eq(guardian.boss_phases.size(), 3, boss_id)
			for phase in guardian.boss_phases:
				var prefs: Dictionary = phase["attack_preferences"]
				for attack_name in prefs.get("prefer", []) + prefs.get("avoid", []):
					assert_has(names, attack_name, boss_id)
				if phase.has("on_transition_spell"):
					assert_has(guardian.spells, phase["on_transition_spell"], boss_id)
			for spell_id in guardian.spells:
				assert_not_null(SpellDatabase.get_spell(spell_id), "%s %s" % [boss_id, spell_id])


func test_every_guardian_has_minions_and_loot_that_exist() -> void:
	for spec in DungeonSet.DUNGEONS:
		for floor_num in FLOORS:
			var boss_id: String = spec["guardians"][floor_num]
			var minions := MonsterDatabase.get_minions_of(boss_id)
			assert_not_empty(minions, boss_id)
			for minion_id in minions:
				assert_not_null(MonsterDatabase.get_monster(minion_id), minion_id)
			var guardian := MonsterDatabase.get_monster(boss_id)
			assert_not_empty(guardian.loot_drops, boss_id)
			for drop in guardian.loot_drops:
				assert_not_null(ShopItems.get_item(drop.item_id), "%s %s" % [boss_id, drop.item_id])


func test_new_set_gives_each_dungeon_its_guardians() -> void:
	var dungeon_set := DungeonSet.create()
	for i in DungeonSet.SIZE:
		assert_eq(dungeon_set.dungeons[i].guardians, DungeonSet.DUNGEONS[i]["guardians"])
	assert_true(dungeon_set.open_final().guardians.is_empty())


func test_older_save_gives_each_dungeon_its_guardians() -> void:
	var dungeon_set := DungeonSet.create()
	for d in dungeon_set.dungeons:
		d.guardians = {}
	dungeon_set.update_from_older_save()
	for i in DungeonSet.SIZE:
		assert_eq(dungeon_set.dungeons[i].guardians, DungeonSet.DUNGEONS[i]["guardians"])
