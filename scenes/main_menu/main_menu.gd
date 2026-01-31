extends Control

const MenuNavigatorClass = preload("res://systems/ui/menu_navigator.gd")
const CharEnum = preload("res://resources/character_enums.gd")
const ClassData = preload("res://resources/class_data.gd")

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

	nav = MenuNavigatorClass.new()
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
		{"name": "Roland", "race": CharEnum.Race.HUMAN, "class": CharEnum.CharacterClass.FIGHTER, "alignment": CharEnum.Alignment.GOOD, "gender": CharEnum.Gender.MALE},
		{"name": "Elara", "race": CharEnum.Race.ELF, "class": CharEnum.CharacterClass.MAGE, "alignment": CharEnum.Alignment.NEUTRAL, "gender": CharEnum.Gender.FEMALE},
		{"name": "Marcus", "race": CharEnum.Race.HUMAN, "class": CharEnum.CharacterClass.PRIEST, "alignment": CharEnum.Alignment.GOOD, "gender": CharEnum.Gender.MALE},
		{"name": "Pip", "race": CharEnum.Race.HOBBIT, "class": CharEnum.CharacterClass.THIEF, "alignment": CharEnum.Alignment.NEUTRAL, "gender": CharEnum.Gender.MALE},
		{"name": "Gilda", "race": CharEnum.Race.GNOME, "class": CharEnum.CharacterClass.ALCHEMIST, "alignment": CharEnum.Alignment.NEUTRAL, "gender": CharEnum.Gender.FEMALE},
		{"name": "Thorin", "race": CharEnum.Race.DWARF, "class": CharEnum.CharacterClass.FIGHTER, "alignment": CharEnum.Alignment.GOOD, "gender": CharEnum.Gender.MALE},
	]

	for template in party_templates:
		var character := _create_character_from_template(template)
		GameState.roster.add_character(character)
		GameState.party.add_member(character)


func _create_character_from_template(template: Dictionary) -> Character:
	var char_class: CharEnum.CharacterClass = template["class"]
	var race: CharEnum.Race = template["race"]

	var stats := _roll_valid_stats_for_class(race, char_class)

	return Character.create_new(
		template["name"],
		race,
		char_class,
		template["alignment"],
		template["gender"],
		stats
	)


func _roll_valid_stats_for_class(race: CharEnum.Race, char_class: CharEnum.CharacterClass) -> Dictionary:
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
