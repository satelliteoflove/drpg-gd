extends Control

var nav: MenuNavigator = null


func _ready() -> void:
	$VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	$VBoxContainer/ContinueButton.pressed.connect(_on_continue_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

	if LLMManager.is_setup_complete():
		_enable_menu_buttons()
	else:
		_disable_menu_buttons()
		LLMManager.setup_finished.connect(_on_llm_setup_finished, CONNECT_ONE_SHOT)

	_setup_navigation()


func _enable_menu_buttons() -> void:
	$VBoxContainer/NewGameButton.disabled = false
	$VBoxContainer/ContinueButton.disabled = not SaveManager.save_exists(SaveManager.AUTOSAVE_SLOT)


func _disable_menu_buttons() -> void:
	$VBoxContainer/NewGameButton.disabled = true
	$VBoxContainer/ContinueButton.disabled = true


func _on_llm_setup_finished() -> void:
	_enable_menu_buttons()


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
