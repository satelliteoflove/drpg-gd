class_name SceneManagerClass
extends Node

signal scene_changed(scene_name: String)
signal transition_started()
signal transition_finished()

const SCENES: Dictionary = {
	"main_menu": "res://scenes/main_menu/main_menu.tscn",
	"town": "res://scenes/town/town.tscn",
	"dungeon": "res://scenes/dungeon/dungeon.tscn",
	"combat": "res://scenes/combat/combat.tscn",
	"character_creation": "res://scenes/town/character_creation.tscn",
	"guild_hall": "res://scenes/town/guild_hall.tscn",
	"inn": "res://scenes/town/inn.tscn",
	"temple": "res://scenes/town/temple.tscn",
	"shop": "res://scenes/town/shop.tscn",
	"party_menu": "res://scenes/common/party_menu.tscn",
	"autoexplore": "res://scenes/town/autoexplore_screen.tscn",
	"ending": "res://scenes/ending/ending.tscn",
}

## Scenes that share the town theme. The dungeon and ending pick their own music.
const TOWN_MUSIC := "res://audio/music/music_town.ogg"
const TOWN_MUSIC_SCENES: Array[String] = [
	"main_menu", "town", "character_creation", "guild_hall", "inn", "temple",
	"shop", "party_menu", "autoexplore",
]

var current_scene_name: String = ""
var is_transitioning: bool = false

var _transition: SceneTransition = null


func _ready() -> void:
	_transition = SceneTransition.new()
	add_child(_transition)


func change_scene(scene_name: String) -> void:
	if is_transitioning:
		return

	if not SCENES.has(scene_name):
		push_error("Unknown scene: " + scene_name)
		return

	is_transitioning = true
	transition_started.emit()

	# Cover the screen with the arcane veil before swapping scenes.
	if _transition:
		await _transition.play_cover()

	var scene_path: String = SCENES[scene_name]
	var error: Error = get_tree().change_scene_to_file(scene_path)

	if error != OK:
		push_error("Failed to load scene: " + scene_path)
		if _transition:
			await _transition.play_reveal()
		is_transitioning = false
		return

	current_scene_name = scene_name
	if TOWN_MUSIC_SCENES.has(scene_name):
		AudioManager.stop_ambient(1.0)
		AudioManager.crossfade_music(load(TOWN_MUSIC), 1.5)

	# Let the new scene initialise (and start its entrance) under the veil.
	await get_tree().process_frame
	await get_tree().process_frame

	if _transition:
		await _transition.play_reveal()

	is_transitioning = false
	transition_finished.emit()
	scene_changed.emit(scene_name)


func go_to_main_menu() -> void:
	GameState.set_mode(GameState.GameMode.MAIN_MENU)
	change_scene("main_menu")


func go_to_town() -> void:
	_settle_expedition()
	GameState.set_mode(GameState.GameMode.TOWN)
	if GameState.has_party():
		SaveManager.autosave()
	change_scene("town")


## Shows the victory screen. The game mode is left as DUNGEON so the trip's
## days are still counted when the party returns to town afterward.
func go_to_ending() -> void:
	# Settle the final expedition first so the ending shows the party's true
	# ages. The town shows the homecoming report afterward.
	_settle_expedition()
	GameState.set_mode(GameState.GameMode.TOWN)
	SaveManager.autosave()
	change_scene("ending")


## The active party has been wiped out. It stays where it fell, with its
## gear, and the player is back in town to send someone after it.
func party_fell() -> void:
	var fallen := GameState.party
	var names: Array[String] = []
	for member in fallen.get_members():
		names.append(member.character_name)
	GameState.pending_wipe = {
		"names": names, "where": GameState.party_whereabouts(fallen).trim_prefix("lying dead in "),
	}
	GameState.record("wipe", "%s fell in %s." % [GameState._name_list(names), GameState.pending_wipe["where"]])
	GameState.leave_party_below()
	GameState.set_mode(GameState.GameMode.TOWN)
	SaveManager.autosave()
	change_scene("town")


## The active party makes camp below and the player turns to another party.
func camp_party() -> void:
	GameState.leave_party_below()
	GameState.set_mode(GameState.GameMode.TOWN)
	SaveManager.autosave()
	change_scene("town")


## Turns the player's attention to [param p]: back into the dungeon where it
## camped, or to the guild hall's party if it's in town.
func switch_to_party(p: Party) -> void:
	GameState.set_active_party(p)
	if p.is_out():
		GameState.resume_at_position = true
		go_to_dungeon(p.floor_num, p.spawn_at_stairs_up)
	else:
		go_to_town()


## Applies the time an expedition took, once, when the party leaves the
## dungeon by any route.
func _settle_expedition() -> void:
	if GameState.party == null or not GameState.party.is_out():
		return
	GameState.pending_homecoming = GameState.settle_expedition()


func go_to_dungeon(floor_num: int = -1, spawn_at_stairs_up: bool = true) -> void:
	if not GameState.party.is_out():
		GameState.begin_expedition()
	if floor_num > 0:
		GameState.set_floor(floor_num)
	GameState.deepest_floor = maxi(GameState.deepest_floor, GameState.current_floor)
	GameState.dungeon_spawn_at_stairs_up = spawn_at_stairs_up
	GameState.set_mode(GameState.GameMode.DUNGEON)
	if GameState.has_party():
		SaveManager.autosave()
	await _prewarm_dungeon_shaders()
	change_scene("dungeon")


func _prewarm_dungeon_shaders() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2, 2)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.transparent_bg = true
	# Render into an isolated, empty World3D. By default a SubViewport shares its
	# parent viewport's world, which would drag in the *active scene's*
	# WorldEnvironment — and when prewarming between two dungeon floors that env
	# carries the post-FX stack (SSR/SSAO/glow/volumetric fog). Those effects try
	# to allocate mipmap pyramids that are impossible at 2x2, producing a null
	# render-buffer texture. On Vulkan that's a non-fatal warning; on macOS Metal
	# the null uniform set is a hard crash on the next compute dispatch. We only
	# need to compile the material/mesh shaders here, so a bare world is correct.
	viewport.own_world_3d = true
	add_child(viewport)

	var scene := Node3D.new()
	viewport.add_child(scene)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 2)
	scene.add_child(cam)

	var light := DirectionalLight3D.new()
	scene.add_child(light)

	var materials: Array[StandardMaterial3D] = []

	# Wall/floor/ceiling: triplanar + normal map
	var env_mat := StandardMaterial3D.new()
	env_mat.albedo_texture = load("res://textures/stone_brick_wall/diffuse.jpg")
	env_mat.normal_enabled = true
	env_mat.normal_texture = load("res://textures/stone_brick_wall/normal.jpg")
	env_mat.uv1_triplanar = true
	env_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	materials.append(env_mat)

	# Tinted variant (stairs up/down, ceiling)
	var tinted_mat := StandardMaterial3D.new()
	tinted_mat.albedo_texture = load("res://textures/stone_brick_wall/diffuse.jpg")
	tinted_mat.albedo_color = Color(0.7, 0.9, 0.7)
	tinted_mat.normal_enabled = true
	tinted_mat.normal_texture = load("res://textures/stone_brick_wall/normal.jpg")
	tinted_mat.uv1_triplanar = true
	tinted_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	materials.append(tinted_mat)

	# Door material
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_texture = load("res://textures/door/diffuse.png")
	door_mat.normal_enabled = true
	door_mat.normal_texture = load("res://textures/door/normal.png")
	door_mat.uv1_triplanar = true
	door_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	materials.append(door_mat)

	# Simple color material (shrine/inscription tiles)
	var color_mat := StandardMaterial3D.new()
	color_mat.albedo_color = Color(0.6, 0.5, 0.2)
	materials.append(color_mat)

	for i in materials.size():
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = BoxMesh.new()
		mesh_instance.mesh.material = materials[i]
		mesh_instance.position = Vector3(float(i) * 0.5, 0, 0)
		scene.add_child(mesh_instance)

	# Enemy sprite: billboard Sprite3D
	var sprite := Sprite3D.new()
	sprite.texture = load("res://textures/monsters/goblin.png")
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.double_sided = true
	sprite.shaded = false
	sprite.position = Vector3(0, 1, 0)
	scene.add_child(sprite)

	# Render two frames to ensure all pipelines compile
	await get_tree().process_frame
	await get_tree().process_frame

	viewport.queue_free()


func go_to_combat() -> void:
	GameState.set_mode(GameState.GameMode.COMBAT)
	if GameState.has_party():
		SaveManager.autosave()
	change_scene("combat")


func go_to_character_creation() -> void:
	GameState.set_mode(GameState.GameMode.TOWN)
	change_scene("character_creation")


func go_to_guild_hall() -> void:
	GameState.set_mode(GameState.GameMode.TOWN)
	change_scene("guild_hall")


func go_to_inn() -> void:
	GameState.set_mode(GameState.GameMode.TOWN)
	change_scene("inn")


func go_to_temple() -> void:
	GameState.set_mode(GameState.GameMode.TOWN)
	change_scene("temple")


func go_to_shop() -> void:
	GameState.set_mode(GameState.GameMode.TOWN)
	change_scene("shop")


func go_to_party_menu() -> void:
	GameState.set_mode(GameState.GameMode.TOWN)
	change_scene("party_menu")


func go_to_autoexplore() -> void:
	GameState.set_mode(GameState.GameMode.TOWN)
	change_scene("autoexplore")
