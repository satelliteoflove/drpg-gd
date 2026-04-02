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
	change_scene("dungeon")


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
