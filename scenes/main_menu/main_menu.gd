extends Control

var nav: MenuNavigator = null

@onready var _content: VBoxContainer = $CenterContainer/Content
@onready var _title: Label = $CenterContainer/Content/Title
@onready var _divider: Control = $CenterContainer/Content/Divider
@onready var _subtitle: Label = $CenterContainer/Content/Subtitle


func _ready() -> void:
	var new_game_btn: Button = _content.get_node("NewGameButton")
	var continue_btn: Button = _content.get_node("ContinueButton")
	new_game_btn.pressed.connect(_on_new_game_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	_content.get_node("QuitButton").pressed.connect(_on_quit_pressed)

	var has_save := SaveManager.save_exists(SaveManager.AUTOSAVE_SLOT)
	new_game_btn.disabled = false
	continue_btn.disabled = not has_save

	# Promote the most likely next action to the filled accent CTA, and start
	# focus there: returning players want Continue, newcomers want New Game.
	var primary_index := 0
	if has_save:
		continue_btn.theme_type_variation = &"PrimaryButton"
		primary_index = 1
	else:
		new_game_btn.theme_type_variation = &"PrimaryButton"

	_setup_navigation(primary_index)
	_play_intro()


func _setup_navigation(start_index: int = 0) -> void:
	var buttons: Array[Button] = [
		_content.get_node("NewGameButton"),
		_content.get_node("ContinueButton"),
		_content.get_node("QuitButton")
	]

	nav = MenuNavigator.new()
	nav.setup(buttons, start_index)


func _play_intro() -> void:
	await get_tree().process_frame
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2(1.12, 1.12)

	var tin := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	tin.tween_property(_title, "modulate:a", 1.0, 0.5)
	tin.tween_property(_title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK)

	create_tween().tween_property(_divider, "modulate:a", 1.0, 0.4).set_delay(0.25)
	create_tween().tween_property(_subtitle, "modulate:a", 1.0, 0.4).set_delay(0.4)

	await tin.finished

	# Gentle perpetual gold shimmer on the title.
	var glow := create_tween().set_loops()
	glow.tween_property(_title, "modulate", Color(1.14, 1.07, 0.97, 1.0), 1.9) \
		.set_trans(Tween.TRANS_SINE)
	glow.tween_property(_title, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.9) \
		.set_trans(Tween.TRANS_SINE)


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
