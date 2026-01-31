class_name MonsterDatabase
extends RefCounted

const CharEnum = preload("res://resources/character_enums.gd")
const LootDropRes = preload("res://resources/loot_drop.gd")

static var _monsters: Dictionary = {}
static var _initialized: bool = false


static func get_monster(monster_id: String) -> Monster:
	_ensure_initialized()
	if _monsters.has(monster_id):
		return _monsters[monster_id].duplicate(true)
	return null


static func get_all_monster_ids() -> Array[String]:
	_ensure_initialized()
	var ids: Array[String] = []
	for key in _monsters.keys():
		ids.append(key)
	return ids


static func get_monsters_for_floor(floor_num: int) -> Array[String]:
	_ensure_initialized()
	var result: Array[String] = []

	if floor_num <= 1:
		result = ["slime", "goblin", "skeleton"]
	elif floor_num <= 2:
		result = ["slime", "goblin", "skeleton", "zombie", "wolf"]
	elif floor_num <= 3:
		result = ["goblin", "kobold", "spider", "wolf", "bandit"]
	elif floor_num <= 4:
		result = ["kobold", "spider", "orc", "bandit", "harpy"]
	elif floor_num <= 5:
		result = ["orc", "witch", "ghost", "harpy", "ogre"]
	elif floor_num <= 6:
		result = ["witch", "ghost", "dark_mage", "ogre", "troll"]
	elif floor_num <= 8:
		result = ["ghost", "dark_mage", "troll", "ogre", "minotaur"]
	else:
		result = ["dark_mage", "troll", "minotaur"]

	return result


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_create_monsters()


static func _create_monsters() -> void:
	_create_slime()
	_create_goblin()
	_create_kobold()
	_create_orc()
	_create_spider()
	_create_witch()
	_create_skeleton()
	_create_zombie()
	_create_wolf()
	_create_bandit()
	_create_troll()
	_create_ghost()
	_create_dark_mage()
	_create_ogre()
	_create_harpy()
	_create_minotaur()


static func _create_slime() -> void:
	var monster := Monster.new()
	monster.monster_name = "Slime"
	monster.max_hp = 15
	monster.strength = 8
	monster.agility = 8
	monster.defense = 0
	monster.evasion = 0
	monster.creature_type = CharEnum.CreatureType.CONSTRUCT
	monster.level = 1
	monster.luck = 8
	monster.exp_reward = 10
	monster.gold_reward_dice = "1d6"

	var attack := MonsterAttack.create_basic("Slime Tackle", "1d4", 0)
	monster.attacks = [attack]

	monster.loot_drops = [
		LootDropRes.create("healing_potion", 0.08),
	]

	_monsters["slime"] = monster


static func _create_goblin() -> void:
	var monster := Monster.new()
	monster.monster_name = "Goblin"
	monster.max_hp = 12
	monster.strength = 10
	monster.agility = 12
	monster.defense = 2
	monster.evasion = 4
	monster.level = 2
	monster.luck = 10
	monster.exp_reward = 15
	monster.gold_reward_dice = "1d8"

	var attack1 := MonsterAttack.create_basic("Rusty Sword", "1d6", 2)
	var attack2 := MonsterAttack.create_basic("Claw", "1d4", 0)
	monster.attacks = [attack1, attack2]

	monster.loot_drops = [
		LootDropRes.create("dagger", 0.12),
		LootDropRes.create("short_sword", 0.06),
		LootDropRes.create("leather_cap", 0.08),
		LootDropRes.create("leather_boots", 0.06),
		LootDropRes.create("healing_potion", 0.10),
	]

	_monsters["goblin"] = monster


static func _create_kobold() -> void:
	var monster := Monster.new()
	monster.monster_name = "Kobold"
	monster.max_hp = 8
	monster.strength = 6
	monster.agility = 14
	monster.defense = 1
	monster.evasion = 6
	monster.level = 2
	monster.luck = 12
	monster.exp_reward = 12
	monster.gold_reward_dice = "2d6"

	var attack1 := MonsterAttack.create_ranged("Throwing Dagger", "1d4", 4, 2)
	var attack2 := MonsterAttack.create_basic("Stab", "1d4", 2)
	monster.attacks = [attack1, attack1, attack2]

	monster.loot_drops = [
		LootDropRes.create("dagger", 0.15),
		LootDropRes.create("leather_gloves", 0.08),
		LootDropRes.create("healing_potion", 0.12),
		LootDropRes.create("mana_potion", 0.06),
	]

	_monsters["kobold"] = monster


static func _create_orc() -> void:
	var monster := Monster.new()
	monster.monster_name = "Orc"
	monster.max_hp = 24
	monster.strength = 14
	monster.agility = 8
	monster.defense = 4
	monster.evasion = 4
	monster.level = 3
	monster.luck = 8
	monster.exp_reward = 25
	monster.gold_reward_dice = "2d8"

	var attack1 := MonsterAttack.create_basic("Great Axe", "1d10", 2)
	var attack2 := MonsterAttack.create_basic("Heavy Punch", "1d6+2", 0)
	monster.attacks = [attack1, attack2]

	monster.loot_drops = [
		LootDropRes.create("battle_axe", 0.08),
		LootDropRes.create("mace", 0.10),
		LootDropRes.create("chain_mail", 0.05),
		LootDropRes.create("iron_helm", 0.06),
		LootDropRes.create("iron_shield", 0.05),
		LootDropRes.create("greater_healing", 0.08),
	]

	_monsters["orc"] = monster


static func _create_spider() -> void:
	var monster := Monster.new()
	monster.monster_name = "Giant Spider"
	monster.max_hp = 14
	monster.strength = 10
	monster.agility = 12
	monster.defense = 2
	monster.evasion = 6
	monster.creature_type = CharEnum.CreatureType.INSECT
	monster.level = 3
	monster.luck = 10
	monster.exp_reward = 18
	monster.gold_reward_dice = "1d10"

	var poison_bite := MonsterAttack.create_with_effect(
		"Poison Bite",
		"1d6",
		3,
		CharEnum.StatusEffect.POISONED,
		0.35,
		"",
		"physical",
		2
	)

	var attack := MonsterAttack.create_basic("Leg Strike", "1d4", 1)
	monster.attacks = [poison_bite, poison_bite, attack]

	monster.loot_drops = [
		LootDropRes.create("antidote", 0.15),
		LootDropRes.create("healing_potion", 0.10),
		LootDropRes.create("leather_armor", 0.06),
	]

	_monsters["spider"] = monster


static func _create_witch() -> void:
	var monster := Monster.new()
	monster.monster_name = "Witch"
	monster.max_hp = 16
	monster.strength = 6
	monster.agility = 10
	monster.defense = 1
	monster.evasion = 8
	monster.level = 4
	monster.luck = 12
	monster.intelligence = 16
	monster.piety = 14
	monster.max_mp = 20
	monster.exp_reward = 30
	monster.gold_reward_dice = "3d8"

	var fire_bolt := MonsterAttack.create_magical("Fire Bolt", "2d6", CharEnum.Element.FIRE, 4)
	fire_bolt.is_magical = true

	var curse := MonsterAttack.create_with_effect(
		"Curse",
		"1d4",
		2,
		CharEnum.StatusEffect.CURSED,
		0.50,
		"",
		"magical",
		4
	)

	var scratch := MonsterAttack.create_basic("Scratch", "1d4", 0)

	monster.attacks = [fire_bolt, fire_bolt, curse, scratch]
	monster.spells = ["m1_fire_bolt"]

	monster.loot_drops = [
		LootDropRes.create("staff", 0.12),
		LootDropRes.create("cloth_armor", 0.10),
		LootDropRes.create("mana_potion", 0.15),
		LootDropRes.create("greater_healing", 0.08),
	]

	_monsters["witch"] = monster


static func _create_skeleton() -> void:
	var monster := Monster.new()
	monster.monster_name = "Skeleton"
	monster.max_hp = 10
	monster.strength = 10
	monster.agility = 10
	monster.defense = 2
	monster.evasion = 6
	monster.creature_type = CharEnum.CreatureType.UNDEAD
	monster.level = 2
	monster.luck = 6
	monster.exp_reward = 12
	monster.gold_reward_dice = "1d8"

	var sword := MonsterAttack.create_basic("Rusty Blade", "1d6", 1)
	monster.attacks = [sword]

	monster.loot_drops = [
		LootDropRes.create("short_sword", 0.10),
		LootDropRes.create("iron_shield", 0.06),
		LootDropRes.create("healing_potion", 0.08),
	]

	_monsters["skeleton"] = monster


static func _create_zombie() -> void:
	var monster := Monster.new()
	monster.monster_name = "Zombie"
	monster.max_hp = 20
	monster.strength = 12
	monster.agility = 4
	monster.defense = 3
	monster.evasion = 0
	monster.creature_type = CharEnum.CreatureType.UNDEAD
	monster.level = 2
	monster.vitality = 14
	monster.luck = 4
	monster.exp_reward = 15
	monster.gold_reward_dice = "1d6"

	var slam := MonsterAttack.create_with_effect(
		"Rotting Slam",
		"1d6+1",
		-1,
		CharEnum.StatusEffect.POISONED,
		0.25,
		"",
		"physical",
		1
	)
	monster.attacks = [slam]

	monster.loot_drops = [
		LootDropRes.create("antidote", 0.15),
		LootDropRes.create("healing_potion", 0.10),
	]

	_monsters["zombie"] = monster


static func _create_wolf() -> void:
	var monster := Monster.new()
	monster.monster_name = "Dire Wolf"
	monster.max_hp = 14
	monster.strength = 12
	monster.agility = 16
	monster.defense = 1
	monster.evasion = 8
	monster.creature_type = CharEnum.CreatureType.BEAST
	monster.level = 2
	monster.luck = 12
	monster.exp_reward = 14
	monster.gold_reward_dice = "1d4"

	var bite := MonsterAttack.create_basic("Vicious Bite", "1d8", 4)
	var claw := MonsterAttack.create_basic("Claw", "1d4", 2)
	monster.attacks = [bite, bite, claw]

	monster.loot_drops = [
		LootDropRes.create("leather_armor", 0.08),
		LootDropRes.create("healing_potion", 0.10),
	]

	_monsters["wolf"] = monster


static func _create_bandit() -> void:
	var monster := Monster.new()
	monster.monster_name = "Bandit"
	monster.max_hp = 16
	monster.strength = 11
	monster.agility = 13
	monster.defense = 3
	monster.evasion = 6
	monster.level = 3
	monster.luck = 14
	monster.exp_reward = 18
	monster.gold_reward_dice = "3d8"

	var dagger := MonsterAttack.create_basic("Stab", "1d6", 3)
	var throwing := MonsterAttack.create_ranged("Throwing Knife", "1d4", 5, 2)
	monster.attacks = [dagger, dagger, throwing]

	monster.loot_drops = [
		LootDropRes.create("dagger", 0.15),
		LootDropRes.create("short_sword", 0.08),
		LootDropRes.create("leather_armor", 0.10),
		LootDropRes.create("leather_boots", 0.08),
		LootDropRes.create("healing_potion", 0.12),
		LootDropRes.create("mana_potion", 0.06),
	]

	_monsters["bandit"] = monster


static func _create_troll() -> void:
	var monster := Monster.new()
	monster.monster_name = "Troll"
	monster.max_hp = 40
	monster.strength = 16
	monster.agility = 8
	monster.defense = 6
	monster.evasion = 4
	monster.level = 5
	monster.vitality = 18
	monster.luck = 6
	monster.exp_reward = 50
	monster.gold_reward_dice = "2d10"

	var club := MonsterAttack.create_basic("Massive Club", "2d8", 0)
	var claw := MonsterAttack.create_basic("Rending Claw", "1d10", 2)
	monster.attacks = [club, claw]

	monster.loot_drops = [
		LootDropRes.create("battle_axe", 0.10),
		LootDropRes.create("mace", 0.12),
		LootDropRes.create("chain_mail", 0.06),
		LootDropRes.create("greater_healing", 0.15),
	]

	_monsters["troll"] = monster


static func _create_ghost() -> void:
	var monster := Monster.new()
	monster.monster_name = "Ghost"
	monster.max_hp = 18
	monster.strength = 6
	monster.agility = 14
	monster.defense = 0
	monster.evasion = 20
	monster.creature_type = CharEnum.CreatureType.UNDEAD
	monster.level = 4
	monster.intelligence = 14
	monster.piety = 12
	monster.luck = 14
	monster.max_mp = 15
	monster.exp_reward = 35
	monster.gold_reward_dice = "2d8"

	var drain := MonsterAttack.create_magical("Life Drain", "1d8", CharEnum.Element.DARK, 4)

	var touch := MonsterAttack.create_with_effect(
		"Chilling Touch",
		"1d4",
		2,
		CharEnum.StatusEffect.PARALYZED,
		0.20,
		"1+1d2",
		"magical",
		3
	)
	touch.is_magical = true
	touch.element = CharEnum.Element.ICE

	monster.attacks = [drain, touch]
	monster.spells = ["m2_fear"]

	monster.loot_drops = [
		LootDropRes.create("mana_potion", 0.15),
		LootDropRes.create("staff", 0.08),
	]

	_monsters["ghost"] = monster


static func _create_dark_mage() -> void:
	var monster := Monster.new()
	monster.monster_name = "Dark Mage"
	monster.max_hp = 22
	monster.strength = 6
	monster.agility = 10
	monster.defense = 2
	monster.evasion = 8
	monster.level = 5
	monster.intelligence = 18
	monster.piety = 12
	monster.luck = 12
	monster.max_mp = 30
	monster.exp_reward = 45
	monster.gold_reward_dice = "4d8"

	var bolt := MonsterAttack.create_magical("Shadow Bolt", "2d6", CharEnum.Element.DARK, 4)

	var curse := MonsterAttack.create_with_effect(
		"Curse",
		"1d4",
		2,
		CharEnum.StatusEffect.CURSED,
		0.40,
		"",
		"magical",
		4
	)

	var staff := MonsterAttack.create_basic("Staff Strike", "1d4", 0)

	monster.attacks = [bolt, bolt, curse, staff]
	monster.spells = ["m1_fire_bolt", "m1_sleep", "m2_fear"]

	monster.loot_drops = [
		LootDropRes.create("staff", 0.15),
		LootDropRes.create("cloth_armor", 0.10),
		LootDropRes.create("mana_potion", 0.20),
		LootDropRes.create("greater_healing", 0.10),
	]

	_monsters["dark_mage"] = monster


static func _create_ogre() -> void:
	var monster := Monster.new()
	monster.monster_name = "Ogre"
	monster.max_hp = 35
	monster.strength = 18
	monster.agility = 6
	monster.defense = 5
	monster.evasion = 2
	monster.level = 4
	monster.vitality = 16
	monster.luck = 6
	monster.exp_reward = 40
	monster.gold_reward_dice = "2d12"

	var slam := MonsterAttack.create_basic("Crushing Blow", "2d8+2", -2)
	slam.targets_row = true

	var stomp := MonsterAttack.create_basic("Ground Stomp", "1d6", 0)
	stomp.targets_all = true

	var fist := MonsterAttack.create_basic("Massive Fist", "1d10+2", 0)

	monster.attacks = [fist, fist, slam, stomp]

	monster.loot_drops = [
		LootDropRes.create("battle_axe", 0.12),
		LootDropRes.create("chain_mail", 0.08),
		LootDropRes.create("iron_helm", 0.08),
		LootDropRes.create("greater_healing", 0.12),
	]

	_monsters["ogre"] = monster


static func _create_harpy() -> void:
	var monster := Monster.new()
	monster.monster_name = "Harpy"
	monster.max_hp = 16
	monster.strength = 10
	monster.agility = 16
	monster.defense = 2
	monster.evasion = 8
	monster.is_flying = true
	monster.creature_type = CharEnum.CreatureType.BEAST
	monster.level = 3
	monster.luck = 14
	monster.exp_reward = 25
	monster.gold_reward_dice = "2d6"

	var talon := MonsterAttack.create_ranged("Diving Talon", "1d8", 4, 2)

	var screech := MonsterAttack.create_with_effect(
		"Terrifying Screech",
		"1d4",
		2,
		CharEnum.StatusEffect.AFRAID,
		0.35,
		"2+1d3",
		"mental",
		2
	)
	screech.targets_row = true

	monster.attacks = [talon, talon, screech]

	monster.loot_drops = [
		LootDropRes.create("leather_armor", 0.08),
		LootDropRes.create("healing_potion", 0.12),
		LootDropRes.create("mana_potion", 0.08),
	]

	_monsters["harpy"] = monster


static func _create_minotaur() -> void:
	var monster := Monster.new()
	monster.monster_name = "Minotaur"
	monster.max_hp = 50
	monster.strength = 20
	monster.agility = 10
	monster.defense = 8
	monster.evasion = 6
	monster.level = 6
	monster.vitality = 18
	monster.luck = 8
	monster.exp_reward = 80
	monster.gold_reward_dice = "4d10"

	var gore := MonsterAttack.create_basic("Gore", "2d10", 4)

	var charge := MonsterAttack.create_basic("Charging Rush", "3d8", 2)
	charge.targets_row = true

	var axe := MonsterAttack.create_basic("Great Axe", "2d8+3", 2)

	monster.attacks = [axe, axe, gore, charge]

	monster.loot_drops = [
		LootDropRes.create("battle_axe", 0.15),
		LootDropRes.create("plate_mail", 0.06),
		LootDropRes.create("iron_helm", 0.10),
		LootDropRes.create("iron_shield", 0.08),
		LootDropRes.create("greater_healing", 0.15),
	]

	_monsters["minotaur"] = monster
