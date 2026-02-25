extends Node


func _ready() -> void:
	GameState.new_game()

	var roster_chars: Array[Character] = GameState.roster.get_all()
	for character in roster_chars:
		if GameState.party.get_members().size() >= 6:
			break
		GameState.party.add_member(character)

	var monsters: Array[Monster] = []
	var monster_ids := ["slime", "goblin", "skeleton"]
	for i in range(monster_ids.size()):
		var monster := MonsterDatabase.get_monster(monster_ids[i])
		if monster:
			monster.grid_position = Vector2i(i % 3, i / 3)
			monster.init_combat()
			monsters.append(monster)

	var encounter := {"enemies": monsters, "is_boss": false}
	GameState.start_combat(encounter)
	SceneManager.go_to_combat()
