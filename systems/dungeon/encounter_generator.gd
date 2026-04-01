class_name EncounterGenerator
extends RefCounted


static func generate_encounter() -> Dictionary:
	var enemy_count := roll_enemy_count()
	var enemies: Array[Monster] = []

	var available_monsters := MonsterDatabase.get_monsters_for_floor(GameState.current_floor)
	if available_monsters.is_empty():
		available_monsters = ["slime"]

	for i in range(enemy_count):
		var monster_id: String = available_monsters[randi() % available_monsters.size()]
		var enemy := MonsterDatabase.get_monster(monster_id)
		if enemy == null:
			enemy = MonsterDatabase.get_monster("slime")
		if enemy != null:
			enemy.init_combat()
			enemies.append(enemy)

	var positions := assign_smart_positions(enemies)
	for i in range(enemies.size()):
		if i < positions.size():
			enemies[i].grid_position = positions[i]

	return {"enemies": enemies}


static func assign_smart_positions(monsters: Array[Monster]) -> Array[Vector2i]:
	if monsters.size() <= 1:
		return [Vector2i(1, 0)]

	var front: Array[int] = []
	var back: Array[int] = []
	for i in range(monsters.size()):
		var m := monsters[i]
		if m.max_mp > 0 and not m.spells.is_empty():
			back.append(i)
		elif m.strength < 10 and m.agility > m.strength:
			back.append(i)
		else:
			front.append(i)

	if front.is_empty():
		front.append(back.pop_front())
	while back.size() > 3:
		front.append(back.pop_front())

	var positions: Array[Vector2i] = []
	positions.resize(monsters.size())
	var col := 0
	for idx in front:
		positions[idx] = Vector2i(col % 3, 0)
		col += 1
	col = 0
	for idx in back:
		positions[idx] = Vector2i(col % 3, 1)
		col += 1
	return positions


static func roll_enemy_count() -> int:
	var roll := randf()
	if roll < 0.4:
		return 1
	elif roll < 0.7:
		return 2
	elif roll < 0.9:
		return 3
	elif roll < 0.97:
		return 4
	else:
		return 5


static func get_formation_positions(count: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []

	match count:
		1:
			positions = [Vector2i(1, 0)]
		2:
			positions = [Vector2i(0, 0), Vector2i(2, 0)]
		3:
			positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
		4:
			positions = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1)]
		5:
			positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1)]
		_:
			for i in range(mini(count, 9)):
				var col := i % 3
				var row := i / 3
				positions.append(Vector2i(col, row))

	return positions


static func get_boss_formation_positions(count: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	match count:
		1:
			positions = [Vector2i(1, 1)]
		2:
			positions = [Vector2i(1, 1), Vector2i(0, 0)]
		3:
			positions = [Vector2i(1, 1), Vector2i(0, 0), Vector2i(2, 0)]
		_:
			positions = [Vector2i(1, 1), Vector2i(0, 0), Vector2i(2, 0)]
			for i in range(3, count):
				var col := (i - 3) % 3
				var row := (i - 3) / 3 + 2
				positions.append(Vector2i(col, row))
	return positions
