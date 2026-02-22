extends Control

var nav: MenuNavigator = null


func _ready() -> void:
	var continue_button: Button = $VBoxContainer/ContinueButton
	continue_button.disabled = not SaveManager.save_exists(SaveManager.AUTOSAVE_SLOT)

	$VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	$VBoxContainer/ContinueButton.pressed.connect(_on_continue_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

	_setup_navigation()


func _setup_navigation() -> void:
	var buttons: Array[Button] = [
		$VBoxContainer/NewGameButton,
		$VBoxContainer/ContinueButton,
		$VBoxContainer/QuitButton
	]

	nav = MenuNavigator.new()
	nav.setup(buttons, 0)


func _unhandled_input(event: InputEvent) -> void:
	if nav:
		nav.handle_input(event)


func _on_new_game_pressed() -> void:
	GameState.new_game()
	SceneManager.go_to_town()


func _on_continue_pressed() -> void:
	if SaveManager.load_game(SaveManager.AUTOSAVE_SLOT):
		SceneManager.go_to_town()


func _on_quit_pressed() -> void:
	get_tree().quit()
