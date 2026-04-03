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
}

var current_scene_name: String = ""
var is_transitioning: bool = false


func _ready() -> void:
	pass


func change_scene(scene_name: String) -> void:
	if is_transitioning:
		return

	if not SCENES.has(scene_name):
		push_error("Unknown scene: " + scene_name)
		return

	is_transitioning = true
	transition_started.emit()

	var scene_path: String = SCENES[scene_name]
	var error: Error = get_tree().change_scene_to_file(scene_path)

	if error != OK:
		push_error("Failed to load scene: " + scene_path)
		is_transitioning = false
		return

	current_scene_name = scene_name
	is_transitioning = false
	transition_finished.emit()
	scene_changed.emit(scene_name)


func go_to_main_menu() -> void:
	GameState.set_mode(GameState.GameMode.MAIN_MENU)
	change_scene("main_menu")


func go_to_town() -> void:
	if GameState.current_mode == GameState.GameMode.DUNGEON:
		var dungeon_days: int = GameState.floor_tracker.consume_dungeon_days()
		if dungeon_days > 0:
			GameState.advance_game_days(dungeon_days)
	GameState.set_mode(GameState.GameMode.TOWN)
	if GameState.has_party():
		SaveManager.autosave()
	change_scene("town")


func go_to_dungeon(floor_num: int = -1, spawn_at_stairs_up: bool = true) -> void:
	GameState.party.prepare_for_dungeon()
	if floor_num > 0:
		GameState.set_floor(floor_num)
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
