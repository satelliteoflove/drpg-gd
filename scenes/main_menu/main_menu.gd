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
		{"name": "Thorin", "race": CharacterEnums.Race.DWARF, "class": CharacterEnums.CharacterClass.FIGHTER, "alignment": CharacterEnums.Alignment.GOOD, "gender": CharacterEnums.Gender.MALE},
		{"name": "Marcus", "race": CharacterEnums.Race.HUMAN, "class": CharacterEnums.CharacterClass.PRIEST, "alignment": CharacterEnums.Alignment.GOOD, "gender": CharacterEnums.Gender.MALE},
		{"name": "Elara", "race": CharacterEnums.Race.ELF, "class": CharacterEnums.CharacterClass.MAGE, "alignment": CharacterEnums.Alignment.NEUTRAL, "gender": CharacterEnums.Gender.FEMALE},
		{"name": "Celeste", "race": CharacterEnums.Race.HUMAN, "class": CharacterEnums.CharacterClass.BISHOP, "alignment": CharacterEnums.Alignment.GOOD, "gender": CharacterEnums.Gender.FEMALE},
		{"name": "Pip", "race": CharacterEnums.Race.HOBBIT, "class": CharacterEnums.CharacterClass.THIEF, "alignment": CharacterEnums.Alignment.NEUTRAL, "gender": CharacterEnums.Gender.MALE},
	]

	for template in party_templates:
		var character := _create_character_from_template(template)
		_level_up_character(character, 3)
		_equip_character(character)
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


func _level_up_character(character: Character, target_level: int) -> void:
	character.level = target_level
	character._recalculate_derived_stats()
	character.current_hp = character.max_hp
	character.current_mp = character.max_mp


func _equip_character(character: Character) -> void:
	match character.character_class:
		CharacterEnums.CharacterClass.FIGHTER:
			_try_equip(character, "long_sword")
			_try_equip(character, "chain_mail")
			_try_equip(character, "iron_shield")
			_try_equip(character, "iron_helm")
		CharacterEnums.CharacterClass.PRIEST:
			_try_equip(character, "mace")
			_try_equip(character, "chain_mail")
			_try_equip(character, "wooden_shield")
			_try_equip(character, "leather_cap")
		CharacterEnums.CharacterClass.MAGE:
			_try_equip(character, "staff")
			_try_equip(character, "cloth_armor")
		CharacterEnums.CharacterClass.BISHOP:
			_try_equip(character, "mace")
			_try_equip(character, "cloth_armor")
		CharacterEnums.CharacterClass.THIEF:
			_try_equip(character, "dagger")
			_try_equip(character, "leather_armor")
			_try_equip(character, "leather_cap")
			_try_equip(character, "leather_boots")


func _try_equip(character: Character, item_id: String) -> void:
	var item := ShopItems.get_item(item_id)
	if item == null:
		return
	var item_copy := item.duplicate()
	if character.can_equip_item(item_copy):
		character.equip_item(item_copy)
