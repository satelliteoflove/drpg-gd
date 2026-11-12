extends Control

var nav: MenuNavigator = null
var _ai_button: Button = null
var _ai_hint: Label = null

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

	_build_ai_toggle()

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
	AudioManager.crossfade_music(load(SceneManager.TOWN_MUSIC), 1.5)


func _setup_navigation(start_index: int = 0) -> void:
	var buttons: Array[Button] = [
		_content.get_node("NewGameButton"),
		_content.get_node("ContinueButton"),
		_ai_button,
		_content.get_node("QuitButton")
	]

	nav = MenuNavigator.new()
	nav.setup(buttons, start_index)
	nav.selection_changed.connect(func(index: int) -> void:
		_ai_hint.modulate.a = 1.0 if buttons[index] == _ai_button else 0.0)


## Optional AI-written party dialogue. It needs a large one-time download, so
## it's off until the player turns it on here.
func _build_ai_toggle() -> void:
	_ai_button = Button.new()
	_ai_button.theme_type_variation = &"MenuButton"
	var quit_btn: Button = _content.get_node("QuitButton")
	_ai_button.custom_minimum_size = quit_btn.custom_minimum_size
	_ai_button.size_flags_horizontal = quit_btn.size_flags_horizontal
	_ai_button.pressed.connect(_on_ai_toggle_pressed)
	_content.add_child(_ai_button)
	_content.move_child(_ai_button, quit_btn.get_index())

	_ai_hint = Label.new()
	_ai_hint.theme_type_variation = &"MutedLabel"
	_ai_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ai_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ai_hint.custom_minimum_size = Vector2(320, 0)
	_ai_hint.text = "Lets a local AI model write your party's banter.\nDownloads about 3 GB the first time. Off uses written lines."
	_ai_hint.modulate.a = 0.0
	_content.add_child(_ai_hint)
	_refresh_ai_toggle()


func _refresh_ai_toggle() -> void:
	_ai_button.text = "AI Dialogue: %s" % ("On" if LLMManager.opted_in else "Off")


func _on_ai_toggle_pressed() -> void:
	LLMManager.set_opted_in(not LLMManager.opted_in)
	_refresh_ai_toggle()


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
		# A save made below resumes below, where the party stood.
		if GameState.party.is_out() and not GameState.party.is_wiped():
			SceneManager.switch_to_party(GameState.party)
		else:
			SceneManager.go_to_town()


func _on_quit_pressed() -> void:
	get_tree().quit()
