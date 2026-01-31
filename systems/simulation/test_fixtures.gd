class_name TestFixtures
extends RefCounted

const CombatRNG = preload("res://autoload/combat_rng.gd")
const CharEnum = preload("res://resources/character_enums.gd")
const MonsterDatabase = preload("res://data/monsters/monster_database.gd")
const ShopItems = preload("res://data/items/shop_items.gd")
const SpellLearning = preload("res://systems/magic/spell_learning.gd")


static func create_balanced_party(level: int, equipped: bool = true) -> Party:
	var party := Party.new()

	var fighter1 := _create_character("Fighter1", CharEnum.CharacterClass.FIGHTER, level, equipped)
	var fighter2 := _create_character("Fighter2", CharEnum.CharacterClass.FIGHTER, level, equipped)
	var priest := _create_character("Priest", CharEnum.CharacterClass.PRIEST, level, equipped)
	var thief := _create_character("Thief", CharEnum.CharacterClass.THIEF, level, equipped)
	var mage := _create_character("Mage", CharEnum.CharacterClass.MAGE, level, equipped)
	var bishop := _create_character("Bishop", CharEnum.CharacterClass.BISHOP, level, equipped)

	party.add_member(fighter1)  # front row - tank
	party.add_member(fighter2)  # front row - tank
	party.add_member(priest)    # front row - can take hits, heals
	party.add_member(thief)     # back row
	party.add_member(mage)      # back row - protected
	party.add_member(bishop)    # back row

	return party


static func create_fighter_heavy_party(level: int, equipped: bool = true) -> Party:
	var party := Party.new()

	var fighter1 := _create_character("Fighter1", CharEnum.CharacterClass.FIGHTER, level, equipped)
	var fighter2 := _create_character("Fighter2", CharEnum.CharacterClass.FIGHTER, level, equipped)
	var fighter3 := _create_character("Fighter3", CharEnum.CharacterClass.FIGHTER, level, equipped)
	var samurai := _create_character("Samurai", CharEnum.CharacterClass.SAMURAI, level, equipped)
	var priest := _create_character("Priest", CharEnum.CharacterClass.PRIEST, level, equipped)
	var thief := _create_character("Thief", CharEnum.CharacterClass.THIEF, level, equipped)

	party.add_member(fighter1)  # front row
	party.add_member(fighter2)  # front row
	party.add_member(fighter3)  # front row
	party.add_member(samurai)   # back row
	party.add_member(priest)    # back row
	party.add_member(thief)     # back row

	return party


static func create_caster_heavy_party(level: int, equipped: bool = true) -> Party:
	var party := Party.new()

	var fighter := _create_character("Fighter", CharEnum.CharacterClass.FIGHTER, level, equipped)
	var priest := _create_character("Priest", CharEnum.CharacterClass.PRIEST, level, equipped)
	var bishop := _create_character("Bishop", CharEnum.CharacterClass.BISHOP, level, equipped)
	var mage1 := _create_character("Mage1", CharEnum.CharacterClass.MAGE, level, equipped)
	var mage2 := _create_character("Mage2", CharEnum.CharacterClass.MAGE, level, equipped)
	var alchemist := _create_character("Alchemist", CharEnum.CharacterClass.ALCHEMIST, level, equipped)

	party.add_member(fighter)   # front row - sole tank
	party.add_member(priest)    # front row - off-tank
	party.add_member(bishop)    # front row
	party.add_member(mage1)     # back row - protected
	party.add_member(mage2)     # back row - protected
	party.add_member(alchemist) # back row - protected

	return party


static func create_ranged_party(level: int, equipped: bool = true) -> Party:
	var party := Party.new()

	var fighter := _create_character("Fighter", CharEnum.CharacterClass.FIGHTER, level, equipped)
	var ranger1 := _create_character("Ranger1", CharEnum.CharacterClass.RANGER, level, equipped)
	var ranger2 := _create_character("Ranger2", CharEnum.CharacterClass.RANGER, level, equipped)
	var priest := _create_character("Priest", CharEnum.CharacterClass.PRIEST, level, equipped)
	var thief := _create_character("Thief", CharEnum.CharacterClass.THIEF, level, equipped)
	var mage := _create_character("Mage", CharEnum.CharacterClass.MAGE, level, equipped)

	var bow := ShopItems.get_item("long_bow")
	if bow:
		ranger1.equip_item(bow.duplicate())
		ranger2.equip_item(bow.duplicate())

	party.add_member(fighter)  # front row
	party.add_member(ranger1)  # front row
	party.add_member(priest)   # front row
	party.add_member(ranger2)  # back row
	party.add_member(thief)    # back row
	party.add_member(mage)     # back row

	return party


static func create_solo_character(class_type: CharEnum.CharacterClass, level: int, equipped: bool = true) -> Party:
	var party := Party.new()
	var character := _create_character("Solo", class_type, level, equipped)
	party.add_member(character)
	return party


static func create_single_monster(monster_id: String, level: int = -1) -> Array[Monster]:
	var monster := MonsterDatabase.get_monster(monster_id)
	if monster == null:
		monster = MonsterDatabase.get_monster("slime")
	if monster == null:
		return []

	if level > 0:
		monster.level = level
		_scale_monster_to_level(monster)

	monster.grid_position = Vector2i(1, 0)
	monster.init_combat()

	return [monster]


static func create_monster_group(monster_ids: Array[String]) -> Array[Monster]:
	var monsters: Array[Monster] = []
	var positions := _get_formation_positions(monster_ids.size())

	for i in range(monster_ids.size()):
		var monster := MonsterDatabase.get_monster(monster_ids[i])
		if monster == null:
			continue
		monster.grid_position = positions[i]
		monster.init_combat()
		monsters.append(monster)

	return monsters


static func create_floor_encounter(floor_num: int) -> Array[Monster]:
	var available := MonsterDatabase.get_monsters_for_floor(floor_num)
	if available.is_empty():
		available = ["slime"]

	var count: int = CombatRNG.randi_range(1, 4)
	var monster_ids: Array[String] = []

	for i in range(count):
		monster_ids.append(available[CombatRNG.randi() % available.size()])

	return create_monster_group(monster_ids)


static func boss_fight_scenario() -> Dictionary:
	var party := create_balanced_party(5)
	var enemies := create_single_monster("dragon", 8)
	if enemies.is_empty():
		enemies = create_single_monster("slime")
		if not enemies.is_empty():
			enemies[0].max_hp = 100
			enemies[0].current_hp = 100
			enemies[0].strength = 15
	return {
		"party": party,
		"enemies": enemies,
		"seed": 12345
	}


static func attrition_scenario() -> Dictionary:
	var party := create_balanced_party(3)
	var monster_ids: Array[String] = ["slime", "slime", "slime", "slime", "slime"]
	var enemies := create_monster_group(monster_ids)
	return {
		"party": party,
		"enemies": enemies,
		"seed": 67890
	}


static func glass_cannon_scenario() -> Dictionary:
	var party := create_caster_heavy_party(4)
	var enemies := create_single_monster("slime")
	if not enemies.is_empty():
		enemies[0].max_hp = 20
		enemies[0].current_hp = 20
		enemies[0].strength = 20
	return {
		"party": party,
		"enemies": enemies,
		"seed": 11111
	}


static func _create_character(char_name: String, char_class: CharEnum.CharacterClass, level: int, equipped: bool = true) -> Character:
	var stats := {
		"strength": 12,
		"intelligence": 12,
		"piety": 12,
		"vitality": 12,
		"agility": 12,
		"luck": 12
	}

	match char_class:
		CharEnum.CharacterClass.FIGHTER, CharEnum.CharacterClass.SAMURAI:
			stats["strength"] = 16
			stats["vitality"] = 14
		CharEnum.CharacterClass.MAGE, CharEnum.CharacterClass.ALCHEMIST:
			stats["intelligence"] = 16
		CharEnum.CharacterClass.PRIEST:
			stats["piety"] = 16
		CharEnum.CharacterClass.THIEF, CharEnum.CharacterClass.NINJA:
			stats["agility"] = 16
			stats["luck"] = 14
		CharEnum.CharacterClass.BISHOP:
			stats["intelligence"] = 14
			stats["piety"] = 14
		CharEnum.CharacterClass.RANGER:
			stats["strength"] = 14
			stats["agility"] = 14

	var character := Character.create_new(
		char_name,
		CharEnum.Race.HUMAN,
		char_class,
		CharEnum.Alignment.NEUTRAL,
		CharEnum.Gender.MALE,
		stats
	)

	if equipped:
		_equip_starter_gear(character)

	for i in range(level - 1):
		character.level += 1
		character._recalculate_derived_stats()
		SpellLearning.try_learn_spells_on_level_up(character)

	_guarantee_core_spells(character)

	character.current_hp = character.max_hp
	character.current_mp = character.max_mp

	return character


static func _equip_starter_gear(character: Character) -> void:
	match character.character_class:
		CharEnum.CharacterClass.FIGHTER, CharEnum.CharacterClass.SAMURAI, CharEnum.CharacterClass.LORD:
			var sword := ShopItems.get_item("short_sword")
			var armor := ShopItems.get_item("leather_armor")
			var cap := ShopItems.get_item("leather_cap")
			var shield := ShopItems.get_item("wooden_shield")
			if sword: character.equip_item(sword.duplicate())
			if armor: character.equip_item(armor.duplicate())
			if cap: character.equip_item(cap.duplicate())
			if shield: character.equip_item(shield.duplicate())
		CharEnum.CharacterClass.PRIEST:
			var staff := ShopItems.get_item("staff")
			var armor := ShopItems.get_item("cloth_armor")
			var shield := ShopItems.get_item("wooden_shield")
			if staff: character.equip_item(staff.duplicate())
			if armor: character.equip_item(armor.duplicate())
			if shield: character.equip_item(shield.duplicate())
		CharEnum.CharacterClass.THIEF, CharEnum.CharacterClass.NINJA:
			var dagger := ShopItems.get_item("dagger")
			var armor := ShopItems.get_item("leather_armor")
			if dagger: character.equip_item(dagger.duplicate())
			if armor: character.equip_item(armor.duplicate())
		CharEnum.CharacterClass.MAGE, CharEnum.CharacterClass.ALCHEMIST, CharEnum.CharacterClass.PSIONIC:
			var staff := ShopItems.get_item("staff")
			var armor := ShopItems.get_item("cloth_armor")
			if staff: character.equip_item(staff.duplicate())
			if armor: character.equip_item(armor.duplicate())
		CharEnum.CharacterClass.BISHOP:
			var staff := ShopItems.get_item("staff")
			var armor := ShopItems.get_item("cloth_armor")
			if staff: character.equip_item(staff.duplicate())
			if armor: character.equip_item(armor.duplicate())
		CharEnum.CharacterClass.RANGER:
			var sword := ShopItems.get_item("short_sword")
			var armor := ShopItems.get_item("leather_armor")
			var cap := ShopItems.get_item("leather_cap")
			if sword: character.equip_item(sword.duplicate())
			if armor: character.equip_item(armor.duplicate())
			if cap: character.equip_item(cap.duplicate())
		_:
			var sword := ShopItems.get_item("short_sword")
			var armor := ShopItems.get_item("cloth_armor")
			if sword: character.equip_item(sword.duplicate())
			if armor: character.equip_item(armor.duplicate())


static func _guarantee_core_spells(character: Character) -> void:
	var learnable := SpellLearning.get_learnable_spells(character)
	for spell in learnable:
		if not character.known_spells.has(spell.id):
			character.known_spells.append(spell.id)


static func _scale_monster_to_level(monster: Monster) -> void:
	var base_hp := monster.max_hp
	var scale_factor := 1.0 + (monster.level - 1) * 0.2
	monster.max_hp = int(base_hp * scale_factor)
	monster.strength = int(monster.strength * scale_factor)


static func _get_formation_positions(count: int) -> Array[Vector2i]:
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
