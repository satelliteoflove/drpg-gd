class_name MonsterDatabase
extends RefCounted

static var _monsters: Dictionary = {}
static var _initialized: bool = false
static var _boss_floor_map: Dictionary = {2: "boss_broodmother", 4: "boss_ironjaw", 6: "boss_lich", 8: "boss_drake"}
static var _boss_minion_map: Dictionary = {2: ["spider", "spider"], 4: ["orc", "bandit"], 6: ["ghost", "skeleton_mage"], 8: ["dark_mage", "troll"]}


static func get_monster(monster_id: String) -> Monster:
	_ensure_initialized()
	if _monsters.has(monster_id):
		var original: Monster = _monsters[monster_id]
		var copy: Monster = original.duplicate(true)
		copy.boss_phases = original.boss_phases.duplicate(true)
		copy.extra_actions = original.extra_actions
		return copy
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
	_create_goblin_shaman()
	_create_orc_warcaster()
	_create_imp()
	_create_fungal_creeper()
	_create_siren()
	_create_naga()
	_create_wraith()
	_create_medusa()
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
	_create_skeleton_mage()
	_create_minotaur()
	_create_boss_broodmother()
	_create_boss_ironjaw()
	_create_boss_lich()
	_create_boss_drake()


static func _create_slime() -> void:
	var monster := Monster.new()
	monster.monster_name = "Slime"
	monster.max_hp = 22
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
	monster.max_hp = 18
	monster.strength = 10
	monster.agility = 12
	monster.defense = 2
	monster.evasion = 4
	monster.level = 2
	monster.luck = 10
	monster.exp_reward = 15
	monster.gold_reward_dice = "1d8"

	var attack1 := MonsterAttack.create_with_effect(
		"Rusty Sword", "1d6", 2,
		CharacterEnums.StatusEffect.POISONED, 0.35, "", "physical", 1
	)
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
	monster.max_hp = 12
	monster.strength = 6
	monster.agility = 14
	monster.defense = 1
	monster.evasion = 6
	monster.level = 2
	monster.luck = 12
	monster.exp_reward = 12
	monster.gold_reward_dice = "2d6"

	var attack1 := MonsterAttack.create_ranged("Throwing Dagger", "1d4", 4, 2)
	var venomous_dart := MonsterAttack.create_with_effect(
		"Venomous Dart", "1d4", 4,
		CharacterEnums.StatusEffect.POISONED, 0.45, "", "physical", 2
	)
	venomous_dart.weapon_range = 2
	var attack2 := MonsterAttack.create_basic("Stab", "1d4", 2)
	monster.attacks = [attack1, venomous_dart, attack2]

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
	monster.max_hp = 36
	monster.strength = 14
	monster.agility = 8
	monster.defense = 4
	monster.evasion = 4
	monster.level = 3
	monster.luck = 8
	monster.exp_reward = 25
	monster.gold_reward_dice = "2d8"

	var attack1 := MonsterAttack.create_basic("Great Axe", "1d12", 2)
	var attack2 := MonsterAttack.create_basic("Heavy Punch", "1d6+2", 0)
	var war_shout := MonsterAttack.create_ability(
		"War Shout", "1d4",
		CharacterEnums.StatusEffect.AFRAID, 0.45, "2+1d3", "mental", 2
	)
	war_shout.targets_row = true
	monster.attacks = [attack1, attack2, war_shout]

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
	monster.max_hp = 21
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
		0.55,
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
	monster.max_hp = 24
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

	var scratch := MonsterAttack.create_basic("Scratch", "1d4", 0)

	monster.attacks = [fire_bolt, fire_bolt, scratch]
	monster.spells = ["m1_fire_bolt", "m1_sleep", "m3_curse"]

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
	monster.max_hp = 15
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
	var bone_claw := MonsterAttack.create_with_effect(
		"Bone Claw", "1d4", 1,
		CharacterEnums.StatusEffect.PARALYZED, 0.35, "", "physical", 1
	)
	monster.attacks = [sword, bone_claw]

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
	monster.max_hp = 30
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
		0.45,
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
	monster.max_hp = 21
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
	var rabid_bite := MonsterAttack.create_with_effect(
		"Rabid Bite", "1d8", 4,
		CharacterEnums.StatusEffect.POISONED, 0.40, "", "physical", 1
	)
	var claw := MonsterAttack.create_basic("Claw", "1d4", 2)
	monster.attacks = [bite, rabid_bite, claw]

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
	monster.max_hp = 24
	monster.strength = 11
	monster.agility = 13
	monster.defense = 3
	monster.evasion = 6
	monster.level = 3
	monster.luck = 14
	monster.exp_reward = 18
	monster.gold_reward_dice = "3d8"

	var dagger := MonsterAttack.create_basic("Stab", "1d8", 3)
	var blackjack := MonsterAttack.create_with_effect(
		"Blackjack", "1d6", 3,
		CharacterEnums.StatusEffect.CONFUSED, 0.40, "3+1d3", "mental", 2
	)
	var throwing := MonsterAttack.create_ranged("Throwing Knife", "1d4", 5, 2)
	monster.attacks = [dagger, blackjack, throwing]

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
	monster.max_hp = 60
	monster.strength = 16
	monster.agility = 8
	monster.defense = 6
	monster.evasion = 4
	monster.level = 5
	monster.vitality = 18
	monster.luck = 6
	monster.exp_reward = 50
	monster.gold_reward_dice = "2d10"

	var club := MonsterAttack.create_basic("Massive Club", "2d10", 0)
	var festering_wound := MonsterAttack.create_with_effect(
		"Festering Wound", "1d12", 2,
		CharacterEnums.StatusEffect.POISONED, 0.50, "", "physical", 3
	)
	monster.attacks = [club, festering_wound]

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
	monster.max_hp = 27
	monster.strength = 6
	monster.agility = 14
	monster.defense = 0
	monster.evasion = 12
	monster.creature_type = CharacterEnums.CreatureType.UNDEAD
	monster.level = 4
	monster.intelligence = 14
	monster.piety = 12
	monster.luck = 14
	monster.max_mp = 15
	monster.exp_reward = 35
	monster.gold_reward_dice = "2d8"

	var drain := MonsterAttack.create_magical("Life Drain", "1d8", CharacterEnums.Element.DARK, 4)

	var touch := MonsterAttack.create_ability(
		"Chilling Touch",
		"1d4",
		CharacterEnums.StatusEffect.PARALYZED,
		0.45,
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
	monster.max_hp = 33
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

	var staff := MonsterAttack.create_basic("Staff Strike", "1d4", 0)

	monster.attacks = [bolt, bolt, staff]
	monster.spells = ["m1_fire_bolt", "m1_sleep", "m2_fear", "m3_silence", "m3_curse"]

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
	monster.max_hp = 52
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

	var stomp := MonsterAttack.create_ability(
		"Ground Stomp", "1d6",
		CharacterEnums.StatusEffect.CONFUSED, 0.35, "2+1d3", "physical", 3
	)
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
	monster.max_hp = 24
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

	var screech := MonsterAttack.create_ability(
		"Terrifying Screech",
		"1d4",
		CharacterEnums.StatusEffect.AFRAID,
		0.55,
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


static func _create_skeleton_mage() -> void:
	var monster := Monster.new()
	monster.monster_name = "Skeleton Mage"
	monster.max_hp = 18
	monster.strength = 6
	monster.agility = 10
	monster.defense = 1
	monster.evasion = 6
	monster.intelligence = 14
	monster.piety = 10
	monster.max_mp = 15
	monster.creature_type = CharacterEnums.CreatureType.UNDEAD
	monster.level = 3
	monster.luck = 8
	monster.exp_reward = 22
	monster.gold_reward_dice = "2d6"

	var shadow_bolt := MonsterAttack.create_magical("Shadow Bolt", "1d6", CharacterEnums.Element.DARK, 3)
	var bone_claw := MonsterAttack.create_with_effect(
		"Bone Claw", "1d4", 1,
		CharacterEnums.StatusEffect.PARALYZED, 0.40, "", "physical", 2
	)
	monster.attacks = [shadow_bolt, bone_claw]
	monster.spells = ["m1_fire_bolt", "m1_sleep"]

	monster.loot_drops = [
		LootDrop.create("staff", 0.10),
		LootDrop.create("mana_potion", 0.12),
		LootDrop.create("healing_potion", 0.10),
	]

	monster.min_floor = 3
	monster.max_floor = 5
	_monsters["skeleton_mage"] = monster


static func _create_minotaur() -> void:
	var monster := Monster.new()
	monster.monster_name = "Minotaur"
	monster.max_hp = 75
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
		LootDrop.create("plate_armor", 0.06),
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
	monster.max_hp = 110
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

	monster.boss_phases = [
		{
			"hp_threshold": 1.0, "min_turns": 0,
			"transition_message": "",
			"behavior_modifiers": {},
			"attack_preferences": {},
		},
		{
			"hp_threshold": 0.50, "min_turns": 2,
			"warning_message": "The Broodmother hisses with growing fury...",
			"transition_message": "The Broodmother screeches in fury!",
			"behavior_modifiers": {"spellcaster": 15.0, "tactical": 10.0},
			"attack_preferences": {"prefer": ["Acidic Spit", "Venomous Fangs"], "avoid": ["Leg Swipe"]},
		},
		{
			"hp_threshold": 0.25, "min_turns": 2,
			"warning_message": "The Broodmother's movements become frantic...",
			"transition_message": "The Broodmother thrashes wildly!",
			"behavior_modifiers": {"aggressive": 20.0, "tactical": 20.0, "defensive": -20.0},
			"attack_preferences": {"prefer": ["Web Spray", "Acidic Spit"], "avoid": []},
		},
	]
	_monsters["boss_broodmother"] = monster


static func _create_boss_ironjaw() -> void:
	var monster := Monster.new()
	monster.monster_name = "Ironjaw the Warchief"
	monster.max_hp = 170
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

	var war_cry := MonsterAttack.create_ability(
		"War Cry",
		"1d4",
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
		LootDrop.create("plate_armor", 0.15),
		LootDrop.create("iron_helm", 0.25),
		LootDrop.create("iron_shield", 0.25),
		LootDrop.create("greater_healing", 0.50),
	]

	monster.min_floor = 99
	monster.max_floor = 99

	monster.boss_phases = [
		{
			"hp_threshold": 1.0, "min_turns": 0,
			"transition_message": "",
			"behavior_modifiers": {},
			"attack_preferences": {},
		},
		{
			"hp_threshold": 0.60, "min_turns": 2,
			"warning_message": "Ironjaw snarls and grips his axe tighter...",
			"transition_message": "Ironjaw roars and raises his axe!",
			"behavior_modifiers": {"tactical": 15.0, "berserker": 10.0},
			"attack_preferences": {"prefer": ["Waraxe Cleave", "Crushing Overhead"], "avoid": ["Shield Bash"]},
		},
		{
			"hp_threshold": 0.30, "min_turns": 2,
			"warning_message": "Blood streams from Ironjaw's wounds...",
			"transition_message": "Ironjaw enters a blood rage!",
			"behavior_modifiers": {"berserker": 30.0, "aggressive": 20.0, "defensive": -20.0},
			"attack_preferences": {"prefer": ["Crushing Overhead", "Battle Axe", "War Cry"], "avoid": []},
		},
	]
	_monsters["boss_ironjaw"] = monster


static func _create_boss_lich() -> void:
	var monster := Monster.new()
	monster.monster_name = "Nethris the Lich"
	monster.max_hp = 140
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

	var wail := MonsterAttack.create_ability(
		"Wail of Despair",
		"1d6",
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
	monster.spells = ["m1_fire_bolt", "m1_sleep", "m2_fear", "m3_fireball", "m3_silence"]

	monster.loot_drops = [
		LootDrop.create("staff", 0.30),
		LootDrop.create("plate_armor", 0.20),
		LootDrop.create("mana_potion", 0.50),
		LootDrop.create("greater_healing", 0.50),
	]

	monster.min_floor = 99
	monster.max_floor = 99

	monster.boss_phases = [
		{
			"hp_threshold": 1.0, "min_turns": 0,
			"transition_message": "",
			"behavior_modifiers": {"spellcaster": 20.0},
			"attack_preferences": {"prefer": ["Soul Rend", "Death Touch"], "avoid": ["Bone Staff"]},
		},
		{
			"hp_threshold": 0.60, "min_turns": 3,
			"warning_message": "Nethris's eyes begin to glow with fury...",
			"transition_message": "Dark energy swirls around Nethris!",
			"on_transition_spell": "m2_fear",
			"behavior_modifiers": {"spellcaster": 30.0, "tactical": 15.0},
			"attack_preferences": {"prefer": ["Soul Rend"], "avoid": ["Bone Staff"]},
		},
		{
			"hp_threshold": 0.30, "min_turns": 3,
			"warning_message": "Nethris begins to chant forbidden words...",
			"transition_message": "Nethris channels forbidden magic!",
			"behavior_modifiers": {"spellcaster": 40.0, "aggressive": -10.0},
			"attack_preferences": {"prefer": ["Soul Rend", "Death Touch"], "avoid": ["Bone Staff", "Wail of Despair"]},
		},
	]
	_monsters["boss_lich"] = monster


static func _create_boss_drake() -> void:
	var monster := Monster.new()
	monster.monster_name = "Vrakthorne the Drake"
	monster.max_hp = 260
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

	var terrifying_roar := MonsterAttack.create_ability(
		"Terrifying Roar",
		"1d4",
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
		LootDrop.create("plate_armor", 0.30),
		LootDrop.create("battle_axe", 0.25),
		LootDrop.create("iron_helm", 0.30),
		LootDrop.create("iron_shield", 0.25),
		LootDrop.create("greater_healing", 0.60),
	]

	monster.min_floor = 99
	monster.max_floor = 99

	monster.boss_phases = [
		{
			"hp_threshold": 1.0, "min_turns": 0,
			"transition_message": "",
			"behavior_modifiers": {"berserker": 10.0},
			"attack_preferences": {"prefer": ["Rending Claws", "Tail Sweep"], "avoid": []},
		},
		{
			"hp_threshold": 0.70, "min_turns": 2,
			"warning_message": "Vrakthorne spreads its wings wide...",
			"transition_message": "Vrakthorne takes to the air!",
			"behavior_modifiers": {"tactical": 25.0, "spellcaster": 15.0, "berserker": -15.0},
			"attack_preferences": {"prefer": ["Fire Breath", "Terrifying Roar"], "avoid": ["Rending Claws"]},
		},
		{
			"hp_threshold": 0.40, "min_turns": 2,
			"warning_message": "Vrakthorne's descent shakes the ground...",
			"transition_message": "Vrakthorne lands with earth-shaking force!",
			"behavior_modifiers": {"berserker": 25.0, "aggressive": 15.0, "tactical": 10.0},
			"attack_preferences": {"prefer": ["Crushing Bite", "Tail Sweep"], "avoid": ["Terrifying Roar"]},
		},
		{
			"hp_threshold": 0.15, "min_turns": 1,
			"warning_message": "Vrakthorne's eyes burn with desperate fury...",
			"transition_message": "Vrakthorne unleashes a desperate fury!",
			"behavior_modifiers": {"tactical": 30.0, "berserker": 20.0, "defensive": -30.0},
			"attack_preferences": {"prefer": ["Fire Breath", "Rending Claws", "Crushing Bite"], "avoid": []},
		},
	]
	_monsters["boss_drake"] = monster


static func _create_goblin_shaman() -> void:
	var monster := Monster.new()
	monster.monster_name = "Goblin Shaman"
	monster.max_hp = 21
	monster.strength = 8
	monster.agility = 12
	monster.defense = 1
	monster.evasion = 6
	monster.intelligence = 14
	monster.piety = 14
	monster.max_mp = 18
	monster.level = 3
	monster.luck = 12
	monster.exp_reward = 22
	monster.gold_reward_dice = "2d8"

	var staff := MonsterAttack.create_basic("Bone Rattle", "1d4", 0)
	var hex := MonsterAttack.create_with_effect(
		"Hex", "1d4", 2,
		CharacterEnums.StatusEffect.CURSED, 0.40,
		"", "magical", 2
	)
	monster.attacks = [staff, hex]
	monster.spells = ["p1_heal", "m1_sleep"]

	monster.loot_drops = [
		LootDrop.create("staff", 0.10),
		LootDrop.create("healing_potion", 0.15),
		LootDrop.create("mana_potion", 0.12),
	]

	monster.min_floor = 3
	monster.max_floor = 5
	_monsters["goblin_shaman"] = monster


static func _create_orc_warcaster() -> void:
	var monster := Monster.new()
	monster.monster_name = "Orc Warcaster"
	monster.max_hp = 33
	monster.strength = 12
	monster.agility = 10
	monster.defense = 3
	monster.evasion = 4
	monster.intelligence = 14
	monster.piety = 16
	monster.max_mp = 25
	monster.level = 5
	monster.luck = 10
	monster.exp_reward = 40
	monster.gold_reward_dice = "3d8"

	var mace := MonsterAttack.create_basic("War Mace", "1d8", 2)
	var war_shout := MonsterAttack.create_with_effect(
		"War Shout", "1d4", 0,
		CharacterEnums.StatusEffect.AFRAID, 0.40,
		"2+1d3", "mental", 3
	)
	war_shout.targets_row = true
	monster.attacks = [mace, war_shout]
	monster.spells = ["p1_heal", "p4_greater_heal", "p1_bless"]

	monster.loot_drops = [
		LootDrop.create("mace", 0.12),
		LootDrop.create("chain_mail", 0.08),
		LootDrop.create("greater_healing", 0.15),
		LootDrop.create("mana_potion", 0.12),
	]

	monster.min_floor = 5
	monster.max_floor = 7
	_monsters["orc_warcaster"] = monster


static func _create_imp() -> void:
	var monster := Monster.new()
	monster.monster_name = "Imp"
	monster.max_hp = 15
	monster.strength = 8
	monster.agility = 16
	monster.defense = 1
	monster.evasion = 10
	monster.intelligence = 12
	monster.max_mp = 10
	monster.creature_type = CharacterEnums.CreatureType.DEMON
	monster.is_flying = true
	monster.level = 3
	monster.luck = 14
	monster.exp_reward = 20
	monster.gold_reward_dice = "2d6"

	var spark := MonsterAttack.create_with_effect(
		"Bewildering Spark", "1d4", 4,
		CharacterEnums.StatusEffect.CONFUSED, 0.45,
		"2+1d3", "mental", 2
	)
	spark.weapon_range = 2
	var scratch := MonsterAttack.create_basic("Scratch", "1d4", 2)
	monster.attacks = [spark, spark, scratch]
	monster.spells = ["m1_fire_bolt"]

	monster.loot_drops = [
		LootDrop.create("mana_potion", 0.15),
		LootDrop.create("healing_potion", 0.12),
	]

	monster.min_floor = 3
	monster.max_floor = 5
	_monsters["imp"] = monster


static func _create_fungal_creeper() -> void:
	var monster := Monster.new()
	monster.monster_name = "Fungal Creeper"
	monster.max_hp = 30
	monster.strength = 10
	monster.agility = 6
	monster.defense = 4
	monster.evasion = 2
	monster.vitality = 14
	monster.creature_type = CharacterEnums.CreatureType.PLANT
	monster.level = 2
	monster.luck = 8
	monster.exp_reward = 16
	monster.gold_reward_dice = "1d8"

	var spore := MonsterAttack.create_ability(
		"Spore Cloud", "1d4",
		CharacterEnums.StatusEffect.CONFUSED, 0.40,
		"2+1d2", "physical", 2
	)
	spore.targets_row = true
	var lash := MonsterAttack.create_with_effect(
		"Poison Lash", "1d6+1", 0,
		CharacterEnums.StatusEffect.POISONED, 0.40,
		"", "physical", 1
	)
	var slam := MonsterAttack.create_basic("Slam", "1d6", -1)
	monster.attacks = [spore, lash, slam]

	monster.loot_drops = [
		LootDrop.create("antidote", 0.15),
		LootDrop.create("healing_potion", 0.10),
	]

	monster.min_floor = 2
	monster.max_floor = 4
	_monsters["fungal_creeper"] = monster


static func _create_siren() -> void:
	var monster := Monster.new()
	monster.monster_name = "Siren"
	monster.max_hp = 27
	monster.strength = 8
	monster.agility = 14
	monster.defense = 2
	monster.evasion = 10
	monster.intelligence = 16
	monster.piety = 12
	monster.max_mp = 15
	monster.creature_type = CharacterEnums.CreatureType.BEAST
	monster.is_flying = true
	monster.level = 5
	monster.luck = 14
	monster.exp_reward = 30
	monster.gold_reward_dice = "2d8"

	var song := MonsterAttack.create_ability(
		"Enchanting Song", "1d4",
		CharacterEnums.StatusEffect.CHARMED, 0.50,
		"3+1d3", "mental", 3
	)
	song.targets_row = true
	var gaze := MonsterAttack.create_ability(
		"Mesmerizing Gaze", "1d4",
		CharacterEnums.StatusEffect.CHARMED, 0.60,
		"2+1d3", "mental", 4
	)
	var talons := MonsterAttack.create_ranged("Talons", "1d6", 4, 2)
	monster.attacks = [song, gaze, talons]
	monster.spells = ["m1_sleep", "m2_fear"]

	monster.loot_drops = [
		LootDrop.create("mana_potion", 0.15),
		LootDrop.create("healing_potion", 0.12),
	]

	monster.min_floor = 5
	monster.max_floor = 7
	_monsters["siren"] = monster


static func _create_naga() -> void:
	var monster := Monster.new()
	monster.monster_name = "Naga"
	monster.max_hp = 42
	monster.strength = 12
	monster.agility = 12
	monster.defense = 4
	monster.evasion = 6
	monster.intelligence = 14
	monster.piety = 14
	monster.max_mp = 20
	monster.creature_type = CharacterEnums.CreatureType.BEAST
	monster.level = 5
	monster.luck = 10
	monster.exp_reward = 40
	monster.gold_reward_dice = "3d8"

	var constrict := MonsterAttack.create_with_effect(
		"Constrict", "1d8+2", 2,
		CharacterEnums.StatusEffect.PARALYZED, 0.35,
		"1+1d2", "physical", 3
	)
	var fangs := MonsterAttack.create_with_effect(
		"Venomous Fangs", "1d6", 3,
		CharacterEnums.StatusEffect.POISONED, 0.45,
		"", "physical", 2
	)
	var hiss := MonsterAttack.create_ability(
		"Silencing Hiss", "1d4",
		CharacterEnums.StatusEffect.SILENCED, 0.50,
		"3+1d4", "mental", 3
	)
	hiss.targets_row = true
	monster.attacks = [constrict, fangs, hiss]
	monster.spells = ["m3_silence"]

	monster.loot_drops = [
		LootDrop.create("antidote", 0.15),
		LootDrop.create("greater_healing", 0.10),
		LootDrop.create("mana_potion", 0.10),
	]

	monster.min_floor = 5
	monster.max_floor = 7
	_monsters["naga"] = monster


static func _create_wraith() -> void:
	var monster := Monster.new()
	monster.monster_name = "Wraith"
	monster.max_hp = 36
	monster.strength = 8
	monster.agility = 14
	monster.defense = 2
	monster.evasion = 12
	monster.intelligence = 16
	monster.piety = 14
	monster.max_mp = 25
	monster.creature_type = CharacterEnums.CreatureType.UNDEAD
	monster.level = 6
	monster.luck = 12
	monster.exp_reward = 55
	monster.gold_reward_dice = "3d10"

	var drain := MonsterAttack.create_magical("Soul Drain", "2d6", CharacterEnums.Element.DARK, 4)
	var wither := MonsterAttack.create_with_effect(
		"Withering Touch", "1d6", 2,
		CharacterEnums.StatusEffect.CURSED, 0.55,
		"", "magical", 4
	)
	wither.is_magical = true
	wither.element = CharacterEnums.Element.DARK
	var dread := MonsterAttack.create_ability(
		"Dread Gaze", "1d4",
		CharacterEnums.StatusEffect.AFRAID, 0.50,
		"2+1d3", "mental", 4
	)
	monster.attacks = [drain, wither, dread]
	monster.spells = ["m2_fear", "m3_silence"]

	monster.loot_drops = [
		LootDrop.create("mana_potion", 0.20),
		LootDrop.create("greater_healing", 0.12),
		LootDrop.create("staff", 0.08),
	]

	monster.min_floor = 6
	monster.max_floor = 8
	_monsters["wraith"] = monster


static func _create_medusa() -> void:
	var monster := Monster.new()
	monster.monster_name = "Medusa"
	monster.max_hp = 48
	monster.strength = 10
	monster.agility = 12
	monster.defense = 4
	monster.evasion = 8
	monster.intelligence = 16
	monster.piety = 14
	monster.max_mp = 20
	monster.creature_type = CharacterEnums.CreatureType.BEAST
	monster.level = 7
	monster.luck = 12
	monster.exp_reward = 75
	monster.gold_reward_dice = "4d10"

	var gaze := MonsterAttack.create_ability(
		"Petrifying Gaze", "1d4",
		CharacterEnums.StatusEffect.STONED, 0.30,
		"", "magical", 5
	)
	gaze.targets_row = true
	var bite := MonsterAttack.create_with_effect(
		"Snake Bite", "1d8", 4,
		CharacterEnums.StatusEffect.POISONED, 0.50,
		"", "physical", 3
	)
	var whip := MonsterAttack.create_basic("Tail Whip", "1d6+2", 2)
	monster.attacks = [gaze, bite, whip]
	monster.spells = ["m3_silence", "m2_fear"]

	monster.loot_drops = [
		LootDrop.create("greater_healing", 0.20),
		LootDrop.create("mana_potion", 0.15),
		LootDrop.create("staff", 0.10),
	]

	monster.min_floor = 7
	monster.max_floor = 8
	_monsters["medusa"] = monster
