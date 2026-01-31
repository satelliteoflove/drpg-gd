extends Control

const MenuNavigatorClass = preload("res://systems/ui/menu_navigator.gd")

var nav: MenuNavigator = null


func _ready() -> void:
	$VBoxContainer/TavernButton.pressed.connect(_on_tavern_pressed)
	$VBoxContainer/ShopButton.pressed.connect(_on_shop_pressed)
	$VBoxContainer/PartyButton.pressed.connect(_on_party_pressed)
	$VBoxContainer/InnButton.pressed.connect(_on_inn_pressed)
	$VBoxContainer/TempleButton.pressed.connect(_on_temple_pressed)
	$VBoxContainer/TrainingButton.pressed.connect(_on_training_pressed)
	$VBoxContainer/DungeonButton.pressed.connect(_on_dungeon_pressed)
	$VBoxContainer/TestCombatButton.pressed.connect(_on_test_combat_pressed)
	$VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)

	_setup_navigation()


func _setup_navigation() -> void:
	var buttons: Array[Button] = [
		$VBoxContainer/TavernButton,
		$VBoxContainer/ShopButton,
		$VBoxContainer/PartyButton,
		$VBoxContainer/InnButton,
		$VBoxContainer/TempleButton,
		$VBoxContainer/TrainingButton,
		$VBoxContainer/DungeonButton,
		$VBoxContainer/TestCombatButton,
		$VBoxContainer/MainMenuButton
	]

	nav = MenuNavigatorClass.new()
	nav.setup(buttons, 0)


func _unhandled_input(event: InputEvent) -> void:
	if nav:
		nav.handle_input(event)


func _on_tavern_pressed() -> void:
	SceneManager.go_to_tavern()


func _on_shop_pressed() -> void:
	SceneManager.go_to_shop()


func _on_party_pressed() -> void:
	SceneManager.go_to_party_menu()


func _on_inn_pressed() -> void:
	SceneManager.go_to_inn()


func _on_temple_pressed() -> void:
	SceneManager.go_to_temple()


func _on_training_pressed() -> void:
	SceneManager.go_to_training_grounds()


func _on_dungeon_pressed() -> void:
	SceneManager.go_to_dungeon()


func _on_test_combat_pressed() -> void:
	var slime_resource := load("res://data/monsters/slime.tres") as Monster
	if slime_resource == null:
		push_error("Could not load slime monster")
		return

	var enemies: Array[Monster] = []
	var positions: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(1, 1),
		Vector2i(0, 2), Vector2i(2, 2)
	]
	var enemy_count := 3

	for i in range(enemy_count):
		var enemy := slime_resource.duplicate() as Monster
		enemy.grid_position = positions[i]
		enemies.append(enemy)

	var encounter := {"enemies": enemies}
	GameState.start_combat(encounter)
	SceneManager.go_to_combat()


func _on_main_menu_pressed() -> void:
	SceneManager.go_to_main_menu()
