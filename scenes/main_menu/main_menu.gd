extends Control

var nav: MenuNavigator = null


func _ready() -> void:
	var continue_button: Button = $VBoxContainer/ContinueButton
	continue_button.disabled = not SaveManager.save_exists(SaveManager.AUTOSAVE_SLOT)

	$VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	$VBoxContainer/ContinueButton.pressed.connect(_on_continue_pressed)
	$VBoxContainer/QuickStartButton.pressed.connect(_on_quick_start_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

	_setup_navigation()


func _setup_navigation() -> void:
	var buttons: Array[Button] = [
		$VBoxContainer/NewGameButton,
		$VBoxContainer/ContinueButton,
		$VBoxContainer/QuickStartButton,
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


func _on_quick_start_pressed() -> void:
	GameState.new_game()
	_generate_quick_party()
	SceneManager.go_to_dungeon()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _generate_quick_party() -> void:
	var party_templates: Array[Dictionary] = [
		{"name": "Roland", "race": CharacterEnums.Race.HUMAN, "class": CharacterEnums.CharacterClass.FIGHTER, "alignment": CharacterEnums.Alignment.GOOD, "gender": CharacterEnums.Gender.MALE},
		{"name": "Elara", "race": CharacterEnums.Race.ELF, "class": CharacterEnums.CharacterClass.MAGE, "alignment": CharacterEnums.Alignment.NEUTRAL, "gender": CharacterEnums.Gender.FEMALE},
		{"name": "Marcus", "race": CharacterEnums.Race.HUMAN, "class": CharacterEnums.CharacterClass.PRIEST, "alignment": CharacterEnums.Alignment.GOOD, "gender": CharacterEnums.Gender.MALE},
		{"name": "Pip", "race": CharacterEnums.Race.HOBBIT, "class": CharacterEnums.CharacterClass.THIEF, "alignment": CharacterEnums.Alignment.NEUTRAL, "gender": CharacterEnums.Gender.MALE},
		{"name": "Gilda", "race": CharacterEnums.Race.GNOME, "class": CharacterEnums.CharacterClass.ALCHEMIST, "alignment": CharacterEnums.Alignment.NEUTRAL, "gender": CharacterEnums.Gender.FEMALE},
		{"name": "Thorin", "race": CharacterEnums.Race.DWARF, "class": CharacterEnums.CharacterClass.FIGHTER, "alignment": CharacterEnums.Alignment.GOOD, "gender": CharacterEnums.Gender.MALE},
	]

	for template in party_templates:
		var character := _create_character_from_template(template)
		GameState.roster.add_character(character)
		GameState.party.add_member(character)


func _create_character_from_template(template: Dictionary) -> Character:
	var char_class: CharacterEnums.CharacterClass = template["class"]
	var race: CharacterEnums.Race = template["race"]

	var stats := _roll_valid_stats_for_class(race, char_class)

	return Character.create_new(
		template["name"],
		race,
		char_class,
		template["alignment"],
		template["gender"],
		stats
	)


func _roll_valid_stats_for_class(race: CharacterEnums.Race, char_class: CharacterEnums.CharacterClass) -> Dictionary:
	var stats := Character.roll_stats_for_race(race)
	var max_attempts := 100

	for i in range(max_attempts):
		if ClassData.meets_requirements(char_class, stats):
			return stats
		stats = Character.roll_stats_for_race(race)

	var reqs := ClassData.get_requirements(char_class)
	for stat_name: String in reqs:
		var required: int = reqs[stat_name]
		if stats.get(stat_name, 0) < required:
			stats[stat_name] = required

	return stats
