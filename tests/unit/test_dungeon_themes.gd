extends TestBase


func test_each_dungeon_in_a_set_has_its_own_theme() -> void:
	var dungeon_set := DungeonSet.create()
	var seen := {}
	for d in dungeon_set.dungeons:
		assert_false(d.theme_id.is_empty())
		seen[FloorThemes.get_theme(d.theme_id).id] = true
	assert_eq(seen.size(), DungeonSet.SIZE)


func test_final_dungeon_has_a_theme_of_its_own() -> void:
	var dungeon_set := DungeonSet.create()
	var final_theme := dungeon_set.open_final().theme_id
	for d in dungeon_set.dungeons:
		assert_ne(d.theme_id, final_theme)


func test_every_theme_file_exists() -> void:
	var ids: Array = [DungeonSet.FINAL["theme"]]
	for spec in DungeonSet.DUNGEONS:
		ids.append(spec["theme"])
	for theme_id in ids:
		var theme := FloorThemes.get_theme(theme_id)
		assert_eq(String(theme.id), theme_id)
		var paths: Array = [theme.ambient_bed, theme.music, theme.door_albedo, theme.door_normal]
		for tex in [theme.floor_textures(), theme.wall_textures(), theme.ceiling_textures()]:
			paths.append_array([tex["albedo"], tex["normal"], tex["ao"], tex["roughness"]])
		for path in paths:
			if path != "":
				assert_true(ResourceLoader.exists(path), "%s: %s" % [theme_id, path])


func test_theme_darkens_and_fogs_with_depth() -> void:
	var top := FloorThemes.get_theme(&"ashen_halls", 1, 8)
	var bottom := FloorThemes.get_theme(&"ashen_halls", 8, 8)
	assert_true(bottom.wall_tint.v < top.wall_tint.v)
	assert_true(bottom.ambient_energy < top.ambient_energy)
	assert_true(bottom.fog_density_lit > top.fog_density_lit)
	# Asking again doesn't darken it further.
	assert_eq(FloorThemes.get_theme(&"ashen_halls", 8, 8).wall_tint, bottom.wall_tint)
	assert_eq(FloorThemes.get_theme(&"ashen_halls", 1, 8).wall_tint, top.wall_tint)


func test_single_floor_dungeon_is_at_full_depth() -> void:
	var great_floor := FloorThemes.get_theme(&"profane_crypt", 8, 8)
	assert_eq(FloorThemes.get_theme(&"profane_crypt", 1, 1).fog_density_lit, great_floor.fog_density_lit)


func test_unknown_theme_falls_back() -> void:
	assert_eq(FloorThemes.get_theme(&"").id, FloorThemes.DEFAULT)


func test_fill_missing_themes_leaves_set_themes_alone() -> void:
	var dungeon_set := DungeonSet.create()
	dungeon_set.dungeons[1].theme_id = ""
	dungeon_set.dungeons[2].theme_id = "profane_crypt"
	dungeon_set.fill_missing_themes()
	assert_eq(dungeon_set.dungeons[1].theme_id, DungeonSet.DUNGEONS[1]["theme"])
	assert_eq(dungeon_set.dungeons[2].theme_id, "profane_crypt")
