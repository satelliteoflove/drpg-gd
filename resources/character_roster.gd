class_name CharacterRoster
extends Resource

signal character_added(character: Character)
signal character_removed(character: Character)
signal roster_full()

const MAX_SIZE: int = 50

@export var characters: Array[Character] = []


func add_character(character: Character) -> bool:
	if characters.size() >= MAX_SIZE:
		roster_full.emit()
		return false
	if _find_index(character.id) >= 0:
		return false

	characters.append(character)
	character_added.emit(character)
	return true


func remove_character(character_id: String) -> Character:
	var index := _find_index(character_id)
	if index < 0:
		return null

	var character: Character = characters[index]
	characters.remove_at(index)
	character_removed.emit(character)
	return character


func get_character(character_id: String) -> Character:
	var index := _find_index(character_id)
	if index < 0:
		return null
	return characters[index]


func _find_index(character_id: String) -> int:
	for i in range(characters.size()):
		if characters[i].id == character_id:
			return i
	return -1


func size() -> int:
	return characters.size()


func is_full() -> bool:
	return characters.size() >= MAX_SIZE


func is_empty() -> bool:
	return characters.is_empty()


func get_all() -> Array[Character]:
	return characters


func get_available(party: Party) -> Array[Character]:
	var available: Array[Character] = []
	for character in characters:
		if party == null or party.get_member(character.id) == null:
			available.append(character)
	return available


func get_by_class(char_class: int) -> Array[Character]:
	var result: Array[Character] = []
	for character in characters:
		if character.character_class == char_class:
			result.append(character)
	return result


func get_by_race(race: int) -> Array[Character]:
	var result: Array[Character] = []
	for character in characters:
		if character.race == race:
			result.append(character)
	return result


func get_alive() -> Array[Character]:
	var alive: Array[Character] = []
	for character in characters:
		if not character.is_dead:
			alive.append(character)
	return alive


func get_dead() -> Array[Character]:
	var dead: Array[Character] = []
	for character in characters:
		if character.is_dead:
			dead.append(character)
	return dead


func sort_by_level(descending: bool = true) -> void:
	if descending:
		characters.sort_custom(func(a: Character, b: Character) -> bool: return a.level > b.level)
	else:
		characters.sort_custom(func(a: Character, b: Character) -> bool: return a.level < b.level)


func sort_by_name() -> void:
	characters.sort_custom(func(a: Character, b: Character) -> bool:
		return a.character_name.to_lower() < b.character_name.to_lower()
	)


func sort_by_class() -> void:
	characters.sort_custom(func(a: Character, b: Character) -> bool:
		return a.character_class < b.character_class
	)


func clear() -> void:
	characters.clear()
