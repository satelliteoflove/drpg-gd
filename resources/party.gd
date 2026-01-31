class_name Party
extends Resource

signal member_added(character: Character, position: int)
signal member_removed(character: Character, position: int)
signal gold_changed(new_amount: int)
signal scrap_changed(new_amount: int)
signal party_wiped()

const MAX_SIZE: int = 6
const FRONT_ROW_SIZE: int = 3

@export var members: Array[Character] = []
@export var gold: int = 0
@export var scrap: int = 0
@export var inventory: Inventory = null


func _init() -> void:
	if inventory == null:
		inventory = Inventory.new()


func add_member(character: Character) -> bool:
	if members.size() >= MAX_SIZE:
		return false
	if _find_member_index(character.id) >= 0:
		return false

	members.append(character)
	member_added.emit(character, members.size() - 1)
	return true


func remove_member(character_id: String) -> Character:
	var index := _find_member_index(character_id)
	if index < 0:
		return null

	var character: Character = members[index]
	members.remove_at(index)
	member_removed.emit(character, index)
	return character


func remove_at(index: int) -> Character:
	if index < 0 or index >= members.size():
		return null

	var character: Character = members[index]
	members.remove_at(index)
	member_removed.emit(character, index)
	return character


func get_member(character_id: String) -> Character:
	var index := _find_member_index(character_id)
	if index < 0:
		return null
	return members[index]


func get_member_at(index: int) -> Character:
	if index < 0 or index >= members.size():
		return null
	return members[index]


func has_member(character: Character) -> bool:
	if character == null:
		return false
	return _find_member_index(character.id) >= 0


func _find_member_index(character_id: String) -> int:
	for i in range(members.size()):
		if members[i].id == character_id:
			return i
	return -1


func size() -> int:
	return members.size()


func is_full() -> bool:
	return members.size() >= MAX_SIZE


func is_empty() -> bool:
	return members.is_empty()


func get_members() -> Array[Character]:
	return members


func get_alive_members() -> Array[Character]:
	var alive: Array[Character] = []
	for member in members:
		if not member.is_dead:
			alive.append(member)
	return alive


func get_dead_members() -> Array[Character]:
	var dead: Array[Character] = []
	for member in members:
		if member.is_dead:
			dead.append(member)
	return dead


func get_front_row() -> Array[Character]:
	var front: Array[Character] = []
	for i in range(mini(FRONT_ROW_SIZE, members.size())):
		front.append(members[i])
	return front


func get_back_row() -> Array[Character]:
	var back: Array[Character] = []
	for i in range(FRONT_ROW_SIZE, members.size()):
		back.append(members[i])
	return back


func is_front_row(character_id: String) -> bool:
	var index := _find_member_index(character_id)
	return index >= 0 and index < FRONT_ROW_SIZE


func is_back_row(character_id: String) -> bool:
	var index := _find_member_index(character_id)
	return index >= FRONT_ROW_SIZE


func is_in_front_row(character: Character) -> bool:
	return is_front_row(character.id)


func is_in_back_row(character: Character) -> bool:
	return is_back_row(character.id)


func swap_positions(index_a: int, index_b: int) -> bool:
	if index_a < 0 or index_a >= members.size():
		return false
	if index_b < 0 or index_b >= members.size():
		return false
	if index_a == index_b:
		return false

	var temp: Character = members[index_a]
	members[index_a] = members[index_b]
	members[index_b] = temp
	return true


func move_to_front(character_id: String) -> bool:
	var index := _find_member_index(character_id)
	if index <= 0:
		return false

	var character: Character = members[index]
	members.remove_at(index)
	members.insert(0, character)
	return true


func move_to_back(character_id: String) -> bool:
	var index := _find_member_index(character_id)
	if index < 0 or index >= members.size() - 1:
		return false

	var character: Character = members[index]
	members.remove_at(index)
	members.append(character)
	return true


func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if amount > gold:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func has_gold(amount: int) -> bool:
	return gold >= amount


func add_scrap(amount: int) -> void:
	scrap = maxi(0, scrap + amount)
	scrap_changed.emit(scrap)


func spend_scrap(amount: int) -> bool:
	if amount > scrap:
		return false
	scrap -= amount
	scrap_changed.emit(scrap)
	return true


func has_scrap(amount: int) -> bool:
	return scrap >= amount


func distribute_experience(total_xp: int) -> void:
	var alive := get_alive_members()
	if alive.is_empty():
		return

	for member in alive:
		member.add_experience(total_xp)


func distribute_gold(total_gold: int) -> void:
	add_gold(total_gold)


func init_combat() -> void:
	for member in members:
		member.init_combat()


func is_wiped() -> bool:
	for member in members:
		if not member.is_dead:
			return false
	return not members.is_empty()


func check_wipe() -> bool:
	if is_wiped():
		party_wiped.emit()
		return true
	return false


func get_average_level() -> int:
	if members.is_empty():
		return 1
	var total := 0
	for member in members:
		total += member.level
	return total / members.size()


func get_average_agility() -> int:
	var alive := get_alive_members()
	if alive.is_empty():
		return 10
	var total := 0
	for member in alive:
		total += member.agility
	return total / alive.size()


func get_average_luck() -> int:
	var alive := get_alive_members()
	if alive.is_empty():
		return 10
	var total := 0
	for member in alive:
		total += member.luck
	return total / alive.size()


func get_highest_level() -> int:
	var highest := 1
	for member in members:
		if member.level > highest:
			highest = member.level
	return highest


func has_living_caster() -> bool:
	for member in members:
		if not member.is_dead and member.max_mp > 0:
			return true
	return false


func has_living_bishop() -> bool:
	const CharEnum = preload("res://resources/character_enums.gd")
	for member in members:
		if not member.is_dead and member.character_class == CharEnum.CharacterClass.BISHOP:
			return true
	return false


func has_living_thief() -> bool:
	const CharEnum = preload("res://resources/character_enums.gd")
	for member in members:
		if not member.is_dead and member.character_class == CharEnum.CharacterClass.THIEF:
			return true
	return false


func get_living_thief() -> Character:
	const CharEnum = preload("res://resources/character_enums.gd")
	for member in members:
		if not member.is_dead and member.character_class == CharEnum.CharacterClass.THIEF:
			return member
	return null


func get_front_row_alive() -> Array[Character]:
	var alive: Array[Character] = []
	for i in range(mini(FRONT_ROW_SIZE, members.size())):
		if not members[i].is_dead:
			alive.append(members[i])
	return alive


func is_front_row_wiped() -> bool:
	for i in range(mini(FRONT_ROW_SIZE, members.size())):
		if not members[i].is_dead:
			return false
	return true


func advance_back_row_if_front_wiped() -> bool:
	if members.size() <= FRONT_ROW_SIZE:
		return false
	if not is_front_row_wiped():
		return false

	var back_row_has_living := false
	for i in range(FRONT_ROW_SIZE, members.size()):
		if not members[i].is_dead:
			back_row_has_living = true
			break

	if not back_row_has_living:
		return false

	var new_order: Array[Character] = []
	for i in range(FRONT_ROW_SIZE, members.size()):
		new_order.append(members[i])
	for i in range(FRONT_ROW_SIZE):
		new_order.append(members[i])

	members = new_order
	return true


func clear() -> void:
	members.clear()
	gold = 0
	scrap = 0
