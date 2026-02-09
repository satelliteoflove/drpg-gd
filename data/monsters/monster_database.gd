class_name MonsterDatabase
extends RefCounted

static var _monsters: Dictionary = {}
static var _initialized: bool = false
static var _boss_floor_map: Dictionary = {2: "boss_broodmother", 4: "boss_ironjaw", 6: "boss_lich", 8: "boss_drake"}
static var _boss_minion_map: Dictionary = {2: ["spider", "spider"], 4: ["orc", "bandit"], 6: ["ghost", "skeleton"], 8: ["dark_mage", "troll"]}


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
	for monster_id in _monsters.keys():
		var monster: Monster = _monsters[monster_id]
		if floor_num >= monster.min_floor and floor_num <= monster.max_floor:
			result.append(monster_id)
	return result


static func get_boss_for_floor(floor_num: int) -> Monster:
	_ensure_initialized()
	var boss_id: String = _boss_floor_map.get(floor_num, "")
	if boss_id != "" and _monsters.has(boss_id):
		return _monsters[boss_id].duplicate(true)
	return null


static func get_boss_minions(floor_num: int) -> Array[String]:
	var result: Array[String] = []
	var minions: Array = _boss_minion_map.get(floor_num, [])
	for m in minions:
		result.append(m)
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
	_create_boss_broodmother()
	_create_boss_ironjaw()
	_create_boss_lich()
	_create_boss_drake()


static func _create_slime() -> void:
	var monster := Monster.new()
	monster.monster_name = "Slime"
	monster.max_hp = 15
	monster.strength = 8
	monster.agility = 8
	monster.defense = 0
	monster.evasion = 0
	monster.creature_type = CharacterEnums.CreatureType.CONSTRUCT
	monster.level = 1
	monster.luck = 8
	monster.exp_reward = 10
	monster.gold_reward_dice = "1d6"

	var attack := MonsterAttack.create_basic("Slime Tackle", "1d4", 0)
	monster.attacks = [attack]

	monster.loot_drops = [
		LootDrop.create("healing_potion", 0.08),
	]

	monster.min_floor = 1
	monster.max_floor = 2
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
		LootDrop.create("dagger", 0.12),
		LootDrop.create("short_sword", 0.06),
		LootDrop.create("leather_cap", 0.08),
		LootDrop.create("leather_boots", 0.06),
		LootDrop.create("healing_potion", 0.10),
	]

	monster.min_floor = 1
	monster.max_floor = 3
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
		LootDrop.create("dagger", 0.15),
		LootDrop.create("leather_gloves", 0.08),
		LootDrop.create("healing_potion", 0.12),
		LootDrop.create("mana_potion", 0.06),
	]

	monster.min_floor = 3
	monster.max_floor = 4
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
		LootDrop.create("battle_axe", 0.08),
		LootDrop.create("mace", 0.10),
		LootDrop.create("chain_mail", 0.05),
		LootDrop.create("iron_helm", 0.06),
		LootDrop.create("iron_shield", 0.05),
		LootDrop.create("greater_healing", 0.08),
	]

	monster.min_floor = 4
	monster.max_floor = 5
	_monsters["orc"] = monster


static func _create_spider() -> void:
	var monster := Monster.new()
	monster.monster_name = "Giant Spider"
	monster.max_hp = 14
	monster.strength = 10
	monster.agility = 12
	monster.defense = 2
	monster.evasion = 6
	monster.creature_type = CharacterEnums.CreatureType.INSECT
	monster.level = 3
	monster.luck = 10
	monster.exp_reward = 18
	monster.gold_reward_dice = "1d10"

	var poison_bite := MonsterAttack.create_with_effect(
		"Poison Bite",
		"1d6",
		3,
		CharacterEnums.StatusEffect.POISONED,
		0.35,
		"",
		"physical",
		2
	)

	var attack := MonsterAttack.create_basic("Leg Strike", "1d4", 1)
	monster.attacks = [poison_bite, poison_bite, attack]

	monster.loot_drops = [
		LootDrop.create("antidote", 0.15),
		LootDrop.create("healing_potion", 0.10),
		LootDrop.create("leather_armor", 0.06),
	]

	monster.min_floor = 3
	monster.max_floor = 4
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

	var fire_bolt := MonsterAttack.create_magical("Fire Bolt", "2d6", CharacterEnums.Element.FIRE, 4)
	fire_bolt.is_magical = true

	var curse := MonsterAttack.create_with_effect(
		"Curse",
		"1d4",
		2,
		CharacterEnums.StatusEffect.CURSED,
		0.50,
		"",
		"magical",
		4
	)

	var scratch := MonsterAttack.create_basic("Scratch", "1d4", 0)

	monster.attacks = [fire_bolt, fire_bolt, curse, scratch]
	monster.spells = ["m1_fire_bolt"]

	monster.loot_drops = [
		LootDrop.create("staff", 0.12),
		LootDrop.create("cloth_armor", 0.10),
		LootDrop.create("mana_potion", 0.15),
		LootDrop.create("greater_healing", 0.08),
	]

	monster.min_floor = 5
	monster.max_floor = 6
	_monsters["witch"] = monster


static func _create_skeleton() -> void:
	var monster := Monster.new()
	monster.monster_name = "Skeleton"
	monster.max_hp = 10
	monster.strength = 10
	monster.agility = 10
	monster.defense = 2
	monster.evasion = 6
	monster.creature_type = CharacterEnums.CreatureType.UNDEAD
	monster.level = 2
	monster.luck = 6
	monster.exp_reward = 12
	monster.gold_reward_dice = "1d8"

	var sword := MonsterAttack.create_basic("Rusty Blade", "1d6", 1)
	monster.attacks = [sword]

	monster.loot_drops = [
		LootDrop.create("short_sword", 0.10),
		LootDrop.create("iron_shield", 0.06),
		LootDrop.create("healing_potion", 0.08),
	]

	monster.min_floor = 1
	monster.max_floor = 2
	_monsters["skeleton"] = monster


static func _create_zombie() -> void:
	var monster := Monster.new()
	monster.monster_name = "Zombie"
	monster.max_hp = 20
	monster.strength = 12
	monster.agility = 4
	monster.defense = 3
	monster.evasion = 0
	monster.creature_type = CharacterEnums.CreatureType.UNDEAD
	monster.level = 2
	monster.vitality = 14
	monster.luck = 4
	monster.exp_reward = 15
	monster.gold_reward_dice = "1d6"

	var slam := MonsterAttack.create_with_effect(
		"Rotting Slam",
		"1d6+1",
		-1,
		CharacterEnums.StatusEffect.POISONED,
		0.25,
		"",
		"physical",
		1
	)
	monster.attacks = [slam]

	monster.loot_drops = [
		LootDrop.create("antidote", 0.15),
		LootDrop.create("healing_potion", 0.10),
	]

	monster.min_floor = 2
	monster.max_floor = 2
	_monsters["zombie"] = monster


static func _create_wolf() -> void:
	var monster := Monster.new()
	monster.monster_name = "Dire Wolf"
	monster.max_hp = 14
	monster.strength = 12
	monster.agility = 16
	monster.defense = 1
	monster.evasion = 8
	monster.creature_type = CharacterEnums.CreatureType.BEAST
	monster.level = 2
	monster.luck = 12
	monster.exp_reward = 14
	monster.gold_reward_dice = "1d4"

	var bite := MonsterAttack.create_basic("Vicious Bite", "1d8", 4)
	var claw := MonsterAttack.create_basic("Claw", "1d4", 2)
	monster.attacks = [bite, bite, claw]

	monster.loot_drops = [
		LootDrop.create("leather_armor", 0.08),
		LootDrop.create("healing_potion", 0.10),
	]

	monster.min_floor = 2
	monster.max_floor = 3
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
		LootDrop.create("dagger", 0.15),
		LootDrop.create("short_sword", 0.08),
		LootDrop.create("leather_armor", 0.10),
		LootDrop.create("leather_boots", 0.08),
		LootDrop.create("healing_potion", 0.12),
		LootDrop.create("mana_potion", 0.06),
	]

	monster.min_floor = 3
	monster.max_floor = 4
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
		LootDrop.create("battle_axe", 0.10),
		LootDrop.create("mace", 0.12),
		LootDrop.create("chain_mail", 0.06),
		LootDrop.create("greater_healing", 0.15),
	]

	monster.min_floor = 6
	monster.max_floor = 99
	_monsters["troll"] = monster


static func _create_ghost() -> void:
	var monster := Monster.new()
	monster.monster_name = "Ghost"
	monster.max_hp = 18
	monster.strength = 6
	monster.agility = 14
	monster.defense = 0
	monster.evasion = 20
	monster.creature_type = CharacterEnums.CreatureType.UNDEAD
	monster.level = 4
	monster.intelligence = 14
	monster.piety = 12
	monster.luck = 14
	monster.max_mp = 15
	monster.exp_reward = 35
	monster.gold_reward_dice = "2d8"

	var drain := MonsterAttack.create_magical("Life Drain", "1d8", CharacterEnums.Element.DARK, 4)

	var touch := MonsterAttack.create_with_effect(
		"Chilling Touch",
		"1d4",
		2,
		CharacterEnums.StatusEffect.PARALYZED,
		0.20,
		"1+1d2",
		"magical",
		3
	)
	touch.is_magical = true
	touch.element = CharacterEnums.Element.ICE

	monster.attacks = [drain, touch]
	monster.spells = ["m2_fear"]

	monster.loot_drops = [
		LootDrop.create("mana_potion", 0.15),
		LootDrop.create("staff", 0.08),
	]

	monster.min_floor = 5
	monster.max_floor = 8
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

	var bolt := MonsterAttack.create_magical("Shadow Bolt", "2d6", CharacterEnums.Element.DARK, 4)

	var curse := MonsterAttack.create_with_effect(
		"Curse",
		"1d4",
		2,
		CharacterEnums.StatusEffect.CURSED,
		0.40,
		"",
		"magical",
		4
	)

	var staff := MonsterAttack.create_basic("Staff Strike", "1d4", 0)

	monster.attacks = [bolt, bolt, curse, staff]
	monster.spells = ["m1_fire_bolt", "m1_sleep", "m2_fear"]

	monster.loot_drops = [
		LootDrop.create("staff", 0.15),
		LootDrop.create("cloth_armor", 0.10),
		LootDrop.create("mana_potion", 0.20),
		LootDrop.create("greater_healing", 0.10),
	]

	monster.min_floor = 6
	monster.max_floor = 99
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
		LootDrop.create("battle_axe", 0.12),
		LootDrop.create("chain_mail", 0.08),
		LootDrop.create("iron_helm", 0.08),
		LootDrop.create("greater_healing", 0.12),
	]

	monster.min_floor = 5
	monster.max_floor = 8
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
	monster.creature_type = CharacterEnums.CreatureType.BEAST
	monster.level = 3
	monster.luck = 14
	monster.exp_reward = 25
	monster.gold_reward_dice = "2d6"

	var talon := MonsterAttack.create_ranged("Diving Talon", "1d8", 4, 2)

	var screech := MonsterAttack.create_with_effect(
		"Terrifying Screech",
		"1d4",
		2,
		CharacterEnums.StatusEffect.AFRAID,
		0.35,
		"2+1d3",
		"mental",
		2
	)
	screech.targets_row = true

	monster.attacks = [talon, talon, screech]

	monster.loot_drops = [
		LootDrop.create("leather_armor", 0.08),
		LootDrop.create("healing_potion", 0.12),
		LootDrop.create("mana_potion", 0.08),
	]

	monster.min_floor = 4
	monster.max_floor = 5
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
		LootDrop.create("battle_axe", 0.15),
		LootDrop.create("plate_mail", 0.06),
		LootDrop.create("iron_helm", 0.10),
		LootDrop.create("iron_shield", 0.08),
		LootDrop.create("greater_healing", 0.15),
	]

	monster.min_floor = 7
	monster.max_floor = 99
	_monsters["minotaur"] = monster


static func _create_boss_broodmother() -> void:
	var monster := Monster.new()
	monster.monster_name = "Broodmother"
	monster.max_hp = 55
	monster.strength = 12
	monster.agility = 10
	monster.defense = 4
	monster.evasion = 4
	monster.creature_type = CharacterEnums.CreatureType.INSECT
	monster.level = 4
	monster.luck = 10
	monster.is_boss = true
	monster.exp_reward = 120
	monster.gold_reward_dice = "4d10"

	var venomous_fangs := MonsterAttack.create_with_effect(
		"Venomous Fangs",
		"1d8+2",
		0,
		CharacterEnums.StatusEffect.POISONED,
		0.50,
		"3+1d3",
		"physical",
		3
	)

	var web_spray := MonsterAttack.create_with_effect(
		"Web Spray",
		"1d4",
		0,
		CharacterEnums.StatusEffect.PARALYZED,
		0.35,
		"1+1d2",
		"physical",
		2
	)
	web_spray.targets_row = true

	var leg_swipe := MonsterAttack.create_basic("Leg Swipe", "1d6+1", 0)

	var acidic_spit := MonsterAttack.create_magical("Acidic Spit", "2d6", CharacterEnums.Element.ACID, 0)
	acidic_spit.weapon_range = 2

	monster.attacks = [venomous_fangs, venomous_fangs, web_spray, leg_swipe, acidic_spit]

	monster.loot_drops = [
		LootDrop.create("long_sword", 0.25),
		LootDrop.create("chain_mail", 0.20),
		LootDrop.create("greater_healing", 0.50),
		LootDrop.create("antidote", 0.40),
	]

	monster.min_floor = 99
	monster.max_floor = 99
	_monsters["boss_broodmother"] = monster


static func _create_boss_ironjaw() -> void:
	var monster := Monster.new()
	monster.monster_name = "Ironjaw the Warchief"
	monster.max_hp = 85
	monster.strength = 18
	monster.agility = 10
	monster.defense = 7
	monster.evasion = 4
	monster.creature_type = CharacterEnums.CreatureType.HUMANOID
	monster.level = 6
	monster.luck = 10
	monster.is_boss = true
	monster.exp_reward = 250
	monster.gold_reward_dice = "6d10"

	var waraxe_cleave := MonsterAttack.create_basic("Waraxe Cleave", "2d8+3", 2)
	waraxe_cleave.targets_row = true

	var crushing_overhead := MonsterAttack.create_basic("Crushing Overhead", "2d10+2", 0)

	var shield_bash := MonsterAttack.create_with_effect(
		"Shield Bash",
		"1d6+2",
		2,
		CharacterEnums.StatusEffect.PARALYZED,
		0.25,
		"1+1d2",
		"physical",
		3
	)

	var war_cry := MonsterAttack.create_with_effect(
		"War Cry",
		"1d4",
		0,
		CharacterEnums.StatusEffect.AFRAID,
		0.40,
		"2+1d3",
		"mental",
		3
	)
	war_cry.targets_all = true

	var battle_axe := MonsterAttack.create_basic("Battle Axe", "1d10+3", 2)

	monster.attacks = [waraxe_cleave, crushing_overhead, shield_bash, war_cry, battle_axe]

	monster.loot_drops = [
		LootDrop.create("battle_axe", 0.30),
		LootDrop.create("plate_mail", 0.15),
		LootDrop.create("iron_helm", 0.25),
		LootDrop.create("iron_shield", 0.25),
		LootDrop.create("greater_healing", 0.50),
	]

	monster.min_floor = 99
	monster.max_floor = 99
	_monsters["boss_ironjaw"] = monster


static func _create_boss_lich() -> void:
	var monster := Monster.new()
	monster.monster_name = "Nethris the Lich"
	monster.max_hp = 70
	monster.strength = 8
	monster.agility = 12
	monster.defense = 5
	monster.evasion = 12
	monster.creature_type = CharacterEnums.CreatureType.UNDEAD
	monster.level = 8
	monster.intelligence = 20
	monster.piety = 16
	monster.max_mp = 40
	monster.luck = 14
	monster.is_boss = true
	monster.exp_reward = 500
	monster.gold_reward_dice = "8d10"

	var soul_rend := MonsterAttack.create_magical("Soul Rend", "3d6", CharacterEnums.Element.DARK, 4)

	var death_touch := MonsterAttack.create_with_effect(
		"Death Touch",
		"2d4",
		2,
		CharacterEnums.StatusEffect.PARALYZED,
		0.30,
		"1+1d2",
		"magical",
		4
	)
	death_touch.is_magical = true
	death_touch.element = CharacterEnums.Element.DARK

	var wail := MonsterAttack.create_with_effect(
		"Wail of Despair",
		"1d6",
		0,
		CharacterEnums.StatusEffect.AFRAID,
		0.45,
		"2+1d3",
		"mental",
		4
	)
	wail.targets_all = true
	wail.is_magical = true
	wail.element = CharacterEnums.Element.DARK

	var bone_staff := MonsterAttack.create_basic("Bone Staff", "1d6", 0)

	monster.attacks = [soul_rend, soul_rend, death_touch, wail, bone_staff]
	monster.spells = ["m1_fire_bolt", "m1_sleep", "m2_fear", "m3_fireball"]

	monster.loot_drops = [
		LootDrop.create("staff", 0.30),
		LootDrop.create("plate_mail", 0.20),
		LootDrop.create("mana_potion", 0.50),
		LootDrop.create("greater_healing", 0.50),
	]

	monster.min_floor = 99
	monster.max_floor = 99
	_monsters["boss_lich"] = monster


static func _create_boss_drake() -> void:
	var monster := Monster.new()
	monster.monster_name = "Vrakthorne the Drake"
	monster.max_hp = 130
	monster.strength = 22
	monster.agility = 12
	monster.defense = 10
	monster.evasion = 6
	monster.creature_type = CharacterEnums.CreatureType.DRAGON
	monster.level = 10
	monster.vitality = 20
	monster.luck = 10
	monster.is_flying = true
	monster.is_boss = true
	monster.exp_reward = 1000
	monster.gold_reward_dice = "10d12"

	var fire_breath := MonsterAttack.create_magical("Fire Breath", "4d6", CharacterEnums.Element.FIRE, 0)
	fire_breath.targets_all = true
	fire_breath.is_breath_weapon = true

	var tail_sweep := MonsterAttack.create_basic("Tail Sweep", "2d8+4", 2)
	tail_sweep.targets_row = true

	var rending_claws := MonsterAttack.create_basic("Rending Claws", "3d8+3", 4)

	var terrifying_roar := MonsterAttack.create_with_effect(
		"Terrifying Roar",
		"1d4",
		0,
		CharacterEnums.StatusEffect.AFRAID,
		0.50,
		"2+1d3",
		"mental",
		5
	)
	terrifying_roar.targets_all = true

	var crushing_bite := MonsterAttack.create_with_effect(
		"Crushing Bite",
		"2d10+4",
		4,
		CharacterEnums.StatusEffect.PARALYZED,
		0.20,
		"1+1d2",
		"physical",
		4
	)

	monster.attacks = [fire_breath, tail_sweep, rending_claws, terrifying_roar, crushing_bite]

	monster.loot_drops = [
		LootDrop.create("plate_mail", 0.30),
		LootDrop.create("battle_axe", 0.25),
		LootDrop.create("iron_helm", 0.30),
		LootDrop.create("iron_shield", 0.25),
		LootDrop.create("greater_healing", 0.60),
	]

	monster.min_floor = 99
	monster.max_floor = 99
	_monsters["boss_drake"] = monster
