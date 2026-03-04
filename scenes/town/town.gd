extends Control

var nav: MenuNavigator = null


func _ready() -> void:
	$VBoxContainer/GuildHallButton.pressed.connect(_on_guild_hall_pressed)
	$VBoxContainer/ShopButton.pressed.connect(_on_shop_pressed)
	$VBoxContainer/PartyButton.pressed.connect(_on_party_pressed)
	$VBoxContainer/InnButton.pressed.connect(_on_inn_pressed)
	$VBoxContainer/TempleButton.pressed.connect(_on_temple_pressed)
	$VBoxContainer/SimulatorButton.pressed.connect(_on_simulator_pressed)
	$VBoxContainer/DungeonButton.pressed.connect(_on_dungeon_pressed)
	$VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)

	_setup_navigation()
	_update_button_states()
	$VBoxContainer/DayLabel.text = "Day %d" % GameState.game_day


func _update_button_states() -> void:
	var has_party := GameState.has_party()
	$VBoxContainer/ShopButton.disabled = not has_party
	$VBoxContainer/PartyButton.disabled = not has_party
	$VBoxContainer/InnButton.disabled = not has_party
	$VBoxContainer/TempleButton.disabled = not has_party
	$VBoxContainer/SimulatorButton.disabled = not has_party
	$VBoxContainer/DungeonButton.disabled = not has_party
	$VBoxContainer/HintLabel.visible = not has_party


func _setup_navigation() -> void:
	var buttons: Array[Button] = [
		$VBoxContainer/GuildHallButton,
		$VBoxContainer/ShopButton,
		$VBoxContainer/PartyButton,
		$VBoxContainer/InnButton,
		$VBoxContainer/TempleButton,
		$VBoxContainer/SimulatorButton,
		$VBoxContainer/DungeonButton,
		$VBoxContainer/MainMenuButton
	]

	nav = MenuNavigator.new()
	nav.setup(buttons, 0)


func _unhandled_input(event: InputEvent) -> void:
	if nav:
		nav.handle_input(event)


func _on_guild_hall_pressed() -> void:
	SceneManager.go_to_guild_hall()


func _on_shop_pressed() -> void:
	SceneManager.go_to_shop()


func _on_party_pressed() -> void:
	SceneManager.go_to_party_menu()


func _on_inn_pressed() -> void:
	SceneManager.go_to_inn()


func _on_temple_pressed() -> void:
	SceneManager.go_to_temple()


func _on_simulator_pressed() -> void:
	SceneManager.go_to_dive_simulator()


func _on_dungeon_pressed() -> void:
	SceneManager.go_to_dungeon()


func _on_main_menu_pressed() -> void:
	SceneManager.go_to_main_menu()
