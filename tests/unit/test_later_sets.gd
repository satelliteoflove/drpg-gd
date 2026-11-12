extends TestBase


func _boss_ids(spec: Dictionary) -> Array:
	var ids: Array = spec["guardians"].values()
	ids.append(spec["master"])
	return ids


func test_first_set_keeps_the_stock_names() -> void:
	var dungeon_set := DungeonSet.create()
	for i in DungeonSet.SIZE:
		var dungeon := dungeon_set.dungeons[i]
		assert_eq(dungeon.dungeon_name, DungeonSet.DUNGEONS[i]["name"])
		assert_eq(dungeon.master_name, DungeonSet.DUNGEONS[i]["master_name"])
		assert_true(dungeon.boss_renames.is_empty())
		var master := MonsterDatabase.get_monster(dungeon.master_id)
		dungeon.name_boss(master)
		assert_eq(master.monster_name, DungeonSet.DUNGEONS[i]["master_name"])


func test_later_sets_have_names_of_their_own() -> void:
	var seen := {}
	for set_number in [1, 2, 3, 4]:
		var dungeon_set := DungeonSet.create(set_number)
		for dungeon in dungeon_set.dungeons:
			assert_false(seen.has(dungeon.dungeon_name), dungeon.dungeon_name)
			assert_false(seen.has(dungeon.master_name), dungeon.master_name)
			seen[dungeon.dungeon_name] = true
			seen[dungeon.master_name] = true


func test_later_set_keeps_themes_bosses_and_ids_apart() -> void:
	var first := DungeonSet.create(1)
	var second := DungeonSet.create(2)
	for i in DungeonSet.SIZE:
		assert_eq(second.dungeons[i].theme_id, first.dungeons[i].theme_id)
		assert_eq(second.dungeons[i].master_id, first.dungeons[i].master_id)
		assert_eq(second.dungeons[i].guardians, first.dungeons[i].guardians)
		assert_ne(second.dungeons[i].id, first.dungeons[i].id)


func test_names_come_round_again_past_the_end_of_the_list() -> void:
	var turns: int = DungeonSet.LATER_NAMES[0].size()
	assert_eq(DungeonSet.create(2 + turns).dungeons[0].dungeon_name, DungeonSet.create(2).dungeons[0].dungeon_name)


func test_every_later_name_belongs_to_one_of_that_dungeons_bosses() -> void:
	for i in DungeonSet.SIZE:
		var boss_names: Array = _boss_ids(DungeonSet.DUNGEONS[i]).map(
			func(id: String) -> String: return MonsterDatabase.get_monster(id).monster_name)
		for old_name in DungeonSet.LATER_BOSS_NAMES[i]:
			var owners := boss_names.filter(func(n: String) -> bool: return n.contains(old_name))
			assert_eq(owners.size(), 1, old_name)
			assert_eq(DungeonSet.LATER_BOSS_NAMES[i][old_name].size(), DungeonSet.LATER_NAMES[i].size(), old_name)


func test_later_set_names_its_bosses_and_what_they_say() -> void:
	var dungeon := DungeonSet.create(2).dungeons[1]
	var old_name: String = DungeonSet.DUNGEONS[1]["master_name"]
	var master := MonsterDatabase.get_monster(dungeon.master_id)
	dungeon.name_boss(master)
	assert_eq(master.monster_name, dungeon.master_name)
	assert_ne(master.monster_name, old_name)
	assert_true(master.monster_name.ends_with("the Ash Wyrm"))
	for phase in master.boss_phases:
		for key in ["warning_message", "transition_message"]:
			assert_false(str(phase.get(key, "")).contains("Morvane"), phase.get(key, ""))
	# The stock monster is left as it was.
	assert_eq(MonsterDatabase.get_monster(dungeon.master_id).monster_name, old_name)


func test_renamed_boss_keeps_its_art() -> void:
	var dungeon := DungeonSet.create(2).dungeons[0]
	var guardian := MonsterDatabase.get_monster(dungeon.guardians[4])
	var art := guardian.get_art_name()
	dungeon.name_boss(guardian)
	assert_ne(guardian.monster_name, art)
	assert_eq(guardian.get_art_name(), art)
	# A boss with no given name is the same in every set.
	var broodmother := MonsterDatabase.get_monster(dungeon.guardians[2])
	dungeon.name_boss(broodmother)
	assert_eq(broodmother.monster_name, "Broodmother")


func test_top_floors_never_surge() -> void:
	var late := DungeonSet.create(3)
	for d in late.dungeons.slice(0, 3):
		d.collapsed_day = 1
	assert_eq(DungeonSurge.multiplier(late, 1), 1.0)
	assert_eq(DungeonSurge.multiplier(late, 2), 1.0)
	assert_gt(DungeonSurge.multiplier(late, 3), 1.0)


func test_a_new_set_starts_harder_than_the_last_one_ended() -> void:
	var first := DungeonSet.create(1)
	for d in first.dungeons:
		d.collapsed_day = 1
	# All four down: this is what the fifth dungeon's master fights at.
	assert_gt(DungeonSurge.multiplier(DungeonSet.create(2), 8), DungeonSurge.multiplier(first, 8))
