class_name MonsterDatabase
extends RefCounted

const DRAKE_NAME := "Vrakthorne the Drake"

static var _monsters: Dictionary = {}
static var _initialized: bool = false
static var _boss_floor_map: Dictionary = {2: "boss_broodmother", 4: "boss_ironjaw", 6: "boss_lich", 8: "boss_drake"}
## Who stands with each boss and each dungeon's master.
static var _boss_minion_map: Dictionary = {
	"boss_broodmother": ["spider", "spider"],
	"boss_ironjaw": ["orc", "bandit"],
	"boss_lich": ["ghost", "skeleton_mage"],
	"boss_cinder_hound": ["wolf", "wolf"],
	"boss_forgemaster": ["orc", "kobold"],
	"boss_pyre_priest": ["goblin_shaman", "skeleton_mage"],
	"boss_brine_mother": ["slime", "slime", "zombie"],
	"boss_drowned_captain": ["bandit", "bandit"],
	"boss_tide_witch": ["ghost", "ghost"],
	"boss_rot_bloom": ["fungal_creeper", "spider"],
	"boss_bog_troll": ["orc", "fungal_creeper"],
	"boss_mire_hag": ["witch", "fungal_creeper"],
	"boss_drake": ["dark_mage", "troll"],
	"boss_ash_wyrm": ["dark_mage", "troll"],
	"boss_pale_wyrm": ["siren", "ghost"],
	"boss_mire_wyrm": ["witch", "troll"],
	"boss_hollow_king": ["wraith", "ghost"],
}


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


## The stock boss of [param floor_num], or "". A dungeon's deepest floor has
## its own master instead: see GameState.floor_boss_id.
static func get_boss_id_for_floor(floor_num: int) -> String:
	return _boss_floor_map.get(floor_num, "")


static func get_boss_for_floor(floor_num: int) -> Monster:
	_ensure_initialized()
	var boss_id := get_boss_id_for_floor(floor_num)
	if boss_id == "":
		return null
	# get_monster carries over boss_phases and extra_actions, which a plain
	# duplicate() drops because they aren't exported properties.
	return get_monster(boss_id)


static func get_boss_minions(floor_num: int) -> Array[String]:
	return get_minions_of(get_boss_id_for_floor(floor_num))


static func get_minions_of(boss_id: String) -> Array[String]:
	var result: Array[String] = []
	for m in _boss_minion_map.get(boss_id, []):
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
	_create_boss_cinder_hound()
	_create_boss_forgemaster()
	_create_boss_pyre_priest()
	_create_boss_brine_mother()
	_create_boss_drowned_captain()
	_create_boss_tide_witch()
	_create_boss_rot_bloom()
	_create_boss_bog_troll()
	_create_boss_mire_hag()
	_create_boss_drake()
	_create_boss_ash_wyrm()
	_create_boss_pale_wyrm()
	_create_boss_mire_wyrm()
	_create_boss_hollow_king()


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
	monster.can_critical = true
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
		LootDrop.create("cutthroats_dirk", 0.02),
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
	monster.can_critical = true
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
		LootDrop.create("headsmans_axe", 0.03),
	]

	monster.min_floor = 7
	monster.max_floor = 99
	_monsters["minotaur"] = monster


static func _create_boss_broodmother() -> void:
	var monster := _new_guardian(2, "Broodmother")
	monster.creature_type = CharacterEnums.CreatureType.INSECT

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
	var monster := _new_guardian(4, "Ironjaw the Warchief")
	monster.creature_type = CharacterEnums.CreatureType.HUMANOID

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
	var monster := _new_guardian(6, "Nethris the Lich")
	monster.creature_type = CharacterEnums.CreatureType.UNDEAD

	var soul_rend := MonsterAttack.create_magical("Soul Rend", "4d6+2", CharacterEnums.Element.DARK, 4)

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
		"2d6",
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


## What the guardians of one floor have in common in every dungeon, so that
## no dungeon's second, fourth or sixth floor is the hard one. Each adds its
## own attacks, phases, loot and weaknesses.
static func _new_guardian(floor_num: int, p_name: String) -> Monster:
	var monster := Monster.new()
	monster.monster_name = p_name
	monster.is_boss = true
	monster.min_floor = 99
	monster.max_floor = 99
	monster.agility = 10
	monster.evasion = 4
	monster.luck = 10
	match floor_num:
		2:
			monster.max_hp = 110
			monster.strength = 12
			monster.defense = 4
			monster.level = 4
			monster.exp_reward = 120
			monster.gold_reward_dice = "4d10"
		4:
			monster.max_hp = 170
			monster.strength = 18
			monster.defense = 7
			monster.level = 6
			monster.exp_reward = 250
			monster.gold_reward_dice = "6d10"
		_:
			# The sixth floor's guardian is a caster. It acts twice a round: a
			# lone caster acting once against six adventurers fell over long
			# before the floor 4 guardian did.
			monster.max_hp = 170
			monster.extra_actions = 1
			monster.strength = 8
			monster.agility = 12
			monster.defense = 5
			monster.evasion = 12
			monster.level = 8
			monster.intelligence = 20
			monster.piety = 16
			monster.max_mp = 40
			monster.luck = 14
			monster.exp_reward = 500
			monster.gold_reward_dice = "8d10"
	return monster


## One phase of a guardian's fight.
static func _phase(threshold: float, min_turns: int, warning: String, transition: String,
		modifiers: Dictionary, prefer: Array, avoid: Array = []) -> Dictionary:
	return {
		"hp_threshold": threshold, "min_turns": min_turns,
		"warning_message": warning, "transition_message": transition,
		"behavior_modifiers": modifiers,
		"attack_preferences": {"prefer": prefer, "avoid": avoid} if not prefer.is_empty() or not avoid.is_empty() else {},
	}


## The three phases of a second-floor guardian's fight. [param lines] holds a
## warning and a transition message for each of the last two, and
## [param prefer] the attacks favoured in each of those.
static func _floor_2_phases(lines: Array, prefer: Array, avoid: Array) -> Array[Dictionary]:
	return [
		_phase(1.0, 0, "", "", {}, []),
		_phase(0.50, 2, lines[0][0], lines[0][1], {"spellcaster": 15.0, "tactical": 10.0}, prefer[0], avoid),
		_phase(0.25, 2, lines[1][0], lines[1][1],
			{"aggressive": 20.0, "tactical": 20.0, "defensive": -20.0}, prefer[1]),
	]


static func _floor_4_phases(lines: Array, prefer: Array, avoid: Array) -> Array[Dictionary]:
	return [
		_phase(1.0, 0, "", "", {}, []),
		_phase(0.60, 2, lines[0][0], lines[0][1], {"tactical": 15.0, "berserker": 10.0}, prefer[0], avoid),
		_phase(0.30, 2, lines[1][0], lines[1][1],
			{"berserker": 30.0, "aggressive": 20.0, "defensive": -20.0}, prefer[1]),
	]


## A sixth-floor guardian casts [param opening_spell] as it enters its second
## phase. [param prefer] has an entry for each of the three phases, and
## [param avoid] is its weak staff blow, which it never favours.
static func _floor_6_phases(lines: Array, prefer: Array, avoid: Array, opening_spell: String) -> Array[Dictionary]:
	var second := _phase(0.60, 3, lines[0][0], lines[0][1], {"spellcaster": 30.0, "tactical": 15.0}, prefer[1], avoid)
	second["on_transition_spell"] = opening_spell
	return [
		_phase(1.0, 0, "", "", {"spellcaster": 20.0}, prefer[0], avoid),
		second,
		_phase(0.30, 3, lines[1][0], lines[1][1], {"spellcaster": 40.0, "aggressive": -10.0}, prefer[2], avoid),
	]


# The Ashen Halls, floor 2. A hound of the burnt halls: it bites hard and its
# breath blinds. Fire does little to it.
static func _create_boss_cinder_hound() -> void:
	var monster := _new_guardian(2, "The Cinder Hound")
	monster.art_name = "Dire Wolf"
	monster.tint = Color(1.0, 0.62, 0.42)
	monster.creature_type = CharacterEnums.CreatureType.BEAST
	monster.element_resist = {CharacterEnums.Element.FIRE: 0.5, CharacterEnums.Element.ICE: -0.5}

	var searing_bite := MonsterAttack.create_basic("Searing Bite", "1d10+2", 0)

	var ash_breath := MonsterAttack.create_with_effect(
		"Ash Breath", "1d4", 0, CharacterEnums.StatusEffect.BLINDED, 0.35, "2+1d2", "physical", 2)
	ash_breath.targets_row = true

	var raking_claws := MonsterAttack.create_basic("Raking Claws", "1d6+1", 0)

	var ember_spit := MonsterAttack.create_magical("Ember Spit", "2d6", CharacterEnums.Element.FIRE, 0)
	ember_spit.weapon_range = 2

	monster.attacks = [searing_bite, searing_bite, ash_breath, raking_claws, ember_spit]
	monster.loot_drops = [
		LootDrop.create("long_sword", 0.25),
		LootDrop.create("chain_mail", 0.20),
		LootDrop.create("greater_healing", 0.50),
		LootDrop.create("eye_drops", 0.40),
	]
	monster.boss_phases = _floor_2_phases([
		["Smoke curls from the Cinder Hound's jaws...", "The Cinder Hound howls, and the embers flare!"],
		["The Cinder Hound's flanks begin to glow...", "The Cinder Hound burns like a coal!"],
	], [["Ember Spit", "Searing Bite"], ["Ash Breath", "Ember Spit"]], ["Raking Claws"])
	_monsters["boss_cinder_hound"] = monster


# The Ashen Halls, floor 4. The smith who keeps the forges lit: hammer blows,
# thrown slag that blinds, and a furnace blast that leaves casters choking.
static func _create_boss_forgemaster() -> void:
	var monster := _new_guardian(4, "Brakka the Forgemaster")
	monster.art_name = "Orc"
	monster.tint = Color(1.0, 0.7, 0.55)
	monster.creature_type = CharacterEnums.CreatureType.HUMANOID
	monster.element_resist = {CharacterEnums.Element.FIRE: 0.5, CharacterEnums.Element.ICE: -0.5}

	var hammer_sweep := MonsterAttack.create_basic("Hammer Sweep", "2d8+3", 2)
	hammer_sweep.targets_row = true

	var molten_hammer := MonsterAttack.create_basic("Molten Hammer", "2d10+2", 0)

	var slag_throw := MonsterAttack.create_with_effect(
		"Slag Throw", "1d6+2", 2, CharacterEnums.StatusEffect.BLINDED, 0.25, "2+1d2", "physical", 3)

	var furnace_blast := MonsterAttack.create_ability(
		"Furnace Blast", "1d4", CharacterEnums.StatusEffect.SILENCED, 0.30, "2+1d3", "physical", 3)
	furnace_blast.targets_all = true

	var forge_hammer := MonsterAttack.create_basic("Forge Hammer", "1d10+3", 2)

	monster.attacks = [hammer_sweep, molten_hammer, slag_throw, furnace_blast, forge_hammer]
	monster.loot_drops = [
		LootDrop.create("battle_axe", 0.30),
		LootDrop.create("plate_armor", 0.15),
		LootDrop.create("iron_helm", 0.25),
		LootDrop.create("iron_boots", 0.25),
		LootDrop.create("greater_healing", 0.50),
	]
	monster.boss_phases = _floor_4_phases([
		["Brakka spits and hefts her hammer...", "Brakka kicks the furnace doors wide!"],
		["Brakka's apron is slick with blood...", "Brakka swings as if the anvil were under you!"],
	], [["Hammer Sweep", "Molten Hammer"], ["Molten Hammer", "Forge Hammer", "Furnace Blast"]], ["Slag Throw"])
	_monsters["boss_forgemaster"] = monster


# The Ashen Halls, floor 6. A priest of the pyres: flame, brands that blind,
# and smoke that silences. Fire does little to him, cold a lot.
static func _create_boss_pyre_priest() -> void:
	var monster := _new_guardian(6, "Serrak the Pyre-Priest")
	monster.creature_type = CharacterEnums.CreatureType.HUMANOID
	monster.element_resist = {CharacterEnums.Element.FIRE: 0.5, CharacterEnums.Element.ICE: -0.5}

	var flame_lash := MonsterAttack.create_magical("Flame Lash", "4d6+2", CharacterEnums.Element.FIRE, 4)

	var searing_brand := MonsterAttack.create_with_effect(
		"Searing Brand", "2d4", 2, CharacterEnums.StatusEffect.BLINDED, 0.30, "2+1d2", "magical", 4)
	searing_brand.is_magical = true
	searing_brand.element = CharacterEnums.Element.FIRE

	var smoke := MonsterAttack.create_ability(
		"Smothering Smoke", "2d6", CharacterEnums.StatusEffect.SILENCED, 0.35, "2+1d3", "physical", 4)
	smoke.targets_all = true
	smoke.is_magical = true
	smoke.element = CharacterEnums.Element.FIRE

	var charred_staff := MonsterAttack.create_basic("Charred Staff", "1d6", 0)

	monster.attacks = [flame_lash, flame_lash, searing_brand, smoke, charred_staff]
	monster.spells = ["m1_fire_bolt", "m2_fire_wave", "m3_fireball", "m3_curse", "m3_silence"]
	monster.loot_drops = [
		LootDrop.create("staff", 0.30),
		LootDrop.create("plate_armor", 0.20),
		LootDrop.create("mana_potion", 0.50),
		LootDrop.create("greater_healing", 0.50),
	]
	monster.boss_phases = _floor_6_phases([
		["Serrak's brands begin to glow...", "Smoke pours from Serrak's censer!"],
		["Serrak begins the rite of the pyre...", "Serrak sets himself alight!"],
	], [
		["Flame Lash", "Searing Brand"], ["Flame Lash"], ["Flame Lash", "Searing Brand"],
	], ["Charred Staff"], "m3_silence")
	_monsters["boss_pyre_priest"] = monster


# The Drowned Vaults, floor 2. A great cold jelly from the flooded cellars:
# its touch numbs and its spray sends the front rank to sleep. Fire hurts it.
static func _create_boss_brine_mother() -> void:
	var monster := _new_guardian(2, "The Brine Mother")
	monster.art_name = "Slime"
	monster.tint = Color(0.62, 0.86, 1.0)
	monster.creature_type = CharacterEnums.CreatureType.AQUATIC
	monster.element_resist = {CharacterEnums.Element.ICE: 0.5, CharacterEnums.Element.FIRE: -0.5}

	var numbing_clutch := MonsterAttack.create_with_effect(
		"Numbing Clutch", "1d8+3", 0, CharacterEnums.StatusEffect.PARALYZED, 0.25, "1+1d2", "physical", 3)

	var brine_spray := MonsterAttack.create_with_effect(
		"Brine Spray", "1d4", 0, CharacterEnums.StatusEffect.ASLEEP, 0.35, "1+1d2", "physical", 2)
	brine_spray.targets_row = true

	var pseudopod := MonsterAttack.create_basic("Pseudopod", "1d6+1", 0)

	var frigid_spit := MonsterAttack.create_magical("Frigid Spit", "2d6", CharacterEnums.Element.ICE, 0)
	frigid_spit.weapon_range = 2

	monster.attacks = [numbing_clutch, numbing_clutch, brine_spray, pseudopod, frigid_spit]
	monster.loot_drops = [
		LootDrop.create("long_sword", 0.25),
		LootDrop.create("chain_mail", 0.20),
		LootDrop.create("greater_healing", 0.50),
		LootDrop.create("wake_dust", 0.40),
	]
	monster.boss_phases = _floor_2_phases([
		["The Brine Mother shudders and swells...", "The Brine Mother bursts into a cold spray!"],
		["The Brine Mother's body clouds over...", "The Brine Mother surges across the floor!"],
	], [["Frigid Spit", "Numbing Clutch"], ["Brine Spray", "Frigid Spit"]], ["Pseudopod"])
	_monsters["boss_brine_mother"] = monster


# The Drowned Vaults, floor 4. A captain who went down with the vaults and
# hasn't left: cutlass, a grip that numbs, and a bell that sends the party to
# sleep. Holy magic hurts him.
static func _create_boss_drowned_captain() -> void:
	var monster := _new_guardian(4, "Captain Morrow the Drowned")
	monster.art_name = "Zombie"
	monster.tint = Color(0.62, 0.9, 0.95)
	monster.creature_type = CharacterEnums.CreatureType.UNDEAD
	monster.element_resist = {CharacterEnums.Element.ICE: 0.5, CharacterEnums.Element.HOLY: -0.5}

	var cutlass_sweep := MonsterAttack.create_basic("Cutlass Sweep", "2d8+3", 2)
	cutlass_sweep.targets_row = true

	var anchor_blow := MonsterAttack.create_basic("Anchor Blow", "2d10+2", 0)

	var cold_grasp := MonsterAttack.create_with_effect(
		"Cold Grasp", "1d6+2", 2, CharacterEnums.StatusEffect.PARALYZED, 0.25, "1+1d2", "physical", 3)

	var drowned_bell := MonsterAttack.create_ability(
		"Drowned Bell", "1d4", CharacterEnums.StatusEffect.ASLEEP, 0.40, "1+1d2", "mental", 3)
	drowned_bell.targets_all = true

	var rusted_cutlass := MonsterAttack.create_basic("Rusted Cutlass", "1d10+3", 2)

	monster.attacks = [cutlass_sweep, anchor_blow, cold_grasp, drowned_bell, rusted_cutlass]
	monster.loot_drops = [
		LootDrop.create("spear", 0.30),
		LootDrop.create("plate_armor", 0.15),
		LootDrop.create("iron_helm", 0.25),
		LootDrop.create("iron_shield", 0.25),
		LootDrop.create("greater_healing", 0.50),
	]
	monster.boss_phases = _floor_4_phases([
		["Water runs from Morrow's coat...", "Morrow rings the drowned bell!"],
		["Morrow's eyes go white as salt...", "Morrow fights like a man going under!"],
	], [["Cutlass Sweep", "Anchor Blow"], ["Anchor Blow", "Rusted Cutlass", "Drowned Bell"]], ["Cold Grasp"])
	_monsters["boss_drowned_captain"] = monster


# The Drowned Vaults, floor 6. A witch of the cold tide: lances of ice, a
# touch that numbs, and a song that sends the party to sleep. Cold does
# little to her, fire a lot.
static func _create_boss_tide_witch() -> void:
	var monster := _new_guardian(6, "Ysolde the Tide Witch")
	monster.creature_type = CharacterEnums.CreatureType.HUMANOID
	monster.element_resist = {CharacterEnums.Element.ICE: 0.5, CharacterEnums.Element.FIRE: -0.5}

	var ice_lance := MonsterAttack.create_magical("Ice Lance", "4d6+2", CharacterEnums.Element.ICE, 4)

	var numbing_touch := MonsterAttack.create_with_effect(
		"Numbing Touch", "2d4", 2, CharacterEnums.StatusEffect.PARALYZED, 0.30, "1+1d2", "magical", 4)
	numbing_touch.is_magical = true
	numbing_touch.element = CharacterEnums.Element.ICE

	var song := MonsterAttack.create_ability(
		"Song of the Deep", "2d6", CharacterEnums.StatusEffect.ASLEEP, 0.35, "1+1d2", "mental", 4)
	song.targets_all = true
	song.is_magical = true
	song.element = CharacterEnums.Element.ICE

	var coral_staff := MonsterAttack.create_basic("Coral Staff", "1d6", 0)

	monster.attacks = [ice_lance, ice_lance, numbing_touch, song, coral_staff]
	monster.spells = ["m1_sleep", "m2_fear", "m3_curse", "m3_silence", "m4_freeze"]
	monster.loot_drops = [
		LootDrop.create("staff", 0.30),
		LootDrop.create("plate_armor", 0.20),
		LootDrop.create("mana_potion", 0.50),
		LootDrop.create("greater_healing", 0.50),
	]
	monster.boss_phases = _floor_6_phases([
		["Ysolde begins to hum under her breath...", "The water rises around Ysolde!"],
		["Frost creeps out across the floor...", "Ysolde calls the cold tide in!"],
	], [
		["Ice Lance", "Numbing Touch"], ["Ice Lance"], ["Ice Lance", "Numbing Touch"],
	], ["Coral Staff"], "m1_sleep")
	_monsters["boss_tide_witch"] = monster


# The Verdant Dark, floor 2. A flowering rot the size of a cart: poison
# thorns, and spores that turn the front rank on each other. Fire hurts it.
static func _create_boss_rot_bloom() -> void:
	var monster := _new_guardian(2, "The Rot Bloom")
	monster.art_name = "Fungal Creeper"
	monster.tint = Color(0.86, 1.0, 0.72)
	monster.creature_type = CharacterEnums.CreatureType.PLANT
	monster.element_resist = {CharacterEnums.Element.FIRE: -0.5}

	var toxic_thorns := MonsterAttack.create_with_effect(
		"Toxic Thorns", "1d8+2", 0, CharacterEnums.StatusEffect.POISONED, 0.50, "3+1d3", "physical", 3)

	var spore_burst := MonsterAttack.create_with_effect(
		"Spore Burst", "1d4", 0, CharacterEnums.StatusEffect.CONFUSED, 0.35, "1+1d2", "mental", 2)
	spore_burst.targets_row = true

	var vine_lash := MonsterAttack.create_basic("Vine Lash", "1d6+1", 0)

	var acid_sap := MonsterAttack.create_magical("Acid Sap", "2d6", CharacterEnums.Element.ACID, 0)
	acid_sap.weapon_range = 2

	monster.attacks = [toxic_thorns, toxic_thorns, spore_burst, vine_lash, acid_sap]
	monster.loot_drops = [
		LootDrop.create("long_sword", 0.25),
		LootDrop.create("chain_mail", 0.20),
		LootDrop.create("greater_healing", 0.50),
		LootDrop.create("antidote", 0.40),
	]
	monster.boss_phases = _floor_2_phases([
		["The Rot Bloom's petals peel back...", "The Rot Bloom bursts open in a cloud of spores!"],
		["Sap runs from the Rot Bloom's wounds...", "The Rot Bloom lashes out in every direction!"],
	], [["Acid Sap", "Toxic Thorns"], ["Spore Burst", "Acid Sap"]], ["Vine Lash"])
	_monsters["boss_rot_bloom"] = monster


# The Verdant Dark, floor 4. A troll that has lain in the bog longer than the
# guild has stood: a club, filthy claws, and a belch that addles the party.
# Fire hurts it.
static func _create_boss_bog_troll() -> void:
	var monster := _new_guardian(4, "Old Grum the Bog Troll")
	monster.creature_type = CharacterEnums.CreatureType.HUMANOID
	monster.element_resist = {CharacterEnums.Element.FIRE: -0.5}

	var club_sweep := MonsterAttack.create_basic("Club Sweep", "2d8+3", 2)
	club_sweep.targets_row = true

	var trunk_smash := MonsterAttack.create_basic("Tree-Trunk Smash", "2d10+2", 0)

	var filthy_claws := MonsterAttack.create_with_effect(
		"Filthy Claws", "1d6+2", 2, CharacterEnums.StatusEffect.POISONED, 0.40, "3+1d3", "physical", 3)

	var fetid_belch := MonsterAttack.create_ability(
		"Fetid Belch", "1d4", CharacterEnums.StatusEffect.CONFUSED, 0.35, "1+1d2", "mental", 3)
	fetid_belch.targets_all = true

	var knotted_club := MonsterAttack.create_basic("Knotted Club", "1d10+3", 2)

	monster.attacks = [club_sweep, trunk_smash, filthy_claws, fetid_belch, knotted_club]
	monster.loot_drops = [
		LootDrop.create("mace", 0.30),
		LootDrop.create("plate_armor", 0.15),
		LootDrop.create("iron_helm", 0.25),
		LootDrop.create("iron_shield", 0.25),
		LootDrop.create("greater_healing", 0.50),
	]
	monster.boss_phases = _floor_4_phases([
		["Old Grum grunts and drags his club up...", "Old Grum bellows, and the bog shakes!"],
		["Old Grum's wounds bubble and stink...", "Old Grum goes berserk!"],
	], [["Club Sweep", "Tree-Trunk Smash"], ["Tree-Trunk Smash", "Knotted Club", "Fetid Belch"]], ["Filthy Claws"])
	_monsters["boss_bog_troll"] = monster


# The Verdant Dark, floor 6. A hag of the mire: hexes that eat like acid, a
# touch that rots, and a cackle that turns the party on itself. Lightning
# hurts her, as it does her master.
static func _create_boss_mire_hag() -> void:
	var monster := _new_guardian(6, "Mother Nettle the Mire Hag")
	monster.creature_type = CharacterEnums.CreatureType.HUMANOID
	monster.element_resist = {CharacterEnums.Element.LIGHTNING: -0.5}

	var hex_bolt := MonsterAttack.create_magical("Hex Bolt", "4d6+2", CharacterEnums.Element.ACID, 4)

	var rotting_touch := MonsterAttack.create_with_effect(
		"Rotting Touch", "2d4", 2, CharacterEnums.StatusEffect.POISONED, 0.50, "3+1d3", "magical", 4)
	rotting_touch.is_magical = true
	rotting_touch.element = CharacterEnums.Element.ACID

	var cackle := MonsterAttack.create_ability(
		"Maddening Cackle", "2d6", CharacterEnums.StatusEffect.CONFUSED, 0.35, "1+1d2", "mental", 4)
	cackle.targets_all = true
	cackle.is_magical = true
	cackle.element = CharacterEnums.Element.PSYCHIC

	var gnarled_staff := MonsterAttack.create_basic("Gnarled Staff", "1d6", 0)

	monster.attacks = [hex_bolt, hex_bolt, rotting_touch, cackle, gnarled_staff]
	monster.spells = ["m1_fire_bolt", "m1_sleep", "m3_curse", "m3_dread", "m3_silence"]
	monster.loot_drops = [
		LootDrop.create("staff", 0.30),
		LootDrop.create("plate_armor", 0.20),
		LootDrop.create("mana_potion", 0.50),
		LootDrop.create("greater_healing", 0.50),
	]
	monster.boss_phases = _floor_6_phases([
		["Mother Nettle starts to mutter...", "Mother Nettle spits a curse!"],
		["Mother Nettle's laughter rises...", "Mother Nettle shrieks with laughter!"],
	], [
		["Hex Bolt", "Rotting Touch"], ["Hex Bolt"], ["Hex Bolt", "Rotting Touch"],
	], ["Gnarled Staff"], "m3_curse")
	_monsters["boss_mire_hag"] = monster


## What every dungeon's master has in common, so that the four of a set are
## as hard as each other. Each adds its own attacks, phases and weaknesses.
## Until they have art of their own they borrow the drake's, under a tint.
static func _new_master(p_name: String, p_tint: Color = Color.WHITE) -> Monster:
	var monster := Monster.new()
	monster.monster_name = p_name
	monster.art_name = DRAKE_NAME
	monster.tint = p_tint
	monster.max_hp = 260
	# Acts twice a round, as befits the last thing in the dungeon.
	monster.extra_actions = 1
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
	monster.loot_drops = [
		LootDrop.create("plate_armor", 0.30),
		LootDrop.create("battle_axe", 0.25),
		LootDrop.create("iron_helm", 0.30),
		LootDrop.create("iron_shield", 0.25),
		LootDrop.create("greater_healing", 0.60),
	]
	monster.min_floor = 99
	monster.max_floor = 99
	return monster


## The four phases every master's fight moves through. [param lines] holds a
## warning and a transition message for each of the last three, and
## [param prefer] the attacks favoured in each of the four.
static func _master_phases(lines: Array, prefer: Array) -> Array[Dictionary]:
	return [
		{
			"hp_threshold": 1.0, "min_turns": 0,
			"transition_message": "",
			"behavior_modifiers": {"berserker": 10.0},
			"attack_preferences": {"prefer": prefer[0], "avoid": []},
		},
		{
			"hp_threshold": 0.70, "min_turns": 2,
			"warning_message": lines[0][0],
			"transition_message": lines[0][1],
			"behavior_modifiers": {"tactical": 25.0, "spellcaster": 15.0, "berserker": -15.0},
			# It leaves off its opening attack once it has pulled back.
			"attack_preferences": {"prefer": prefer[1], "avoid": prefer[0].slice(0, 1)},
		},
		{
			"hp_threshold": 0.40, "min_turns": 2,
			"warning_message": lines[1][0],
			"transition_message": lines[1][1],
			"behavior_modifiers": {"berserker": 25.0, "aggressive": 15.0, "tactical": 10.0},
			# Back in the thick of it, it has no time for the second phase's cloud or roar.
			"attack_preferences": {"prefer": prefer[2], "avoid": prefer[1].slice(1, 2)},
		},
		{
			"hp_threshold": 0.15, "min_turns": 1,
			"warning_message": lines[2][0],
			"transition_message": lines[2][1],
			"behavior_modifiers": {"tactical": 30.0, "berserker": 20.0, "defensive": -30.0},
			"attack_preferences": {"prefer": prefer[3], "avoid": []},
		},
	]


# The Drake's Deep. Fire and fear: it burns the whole party from the air and
# its roar sends them running.
static func _create_boss_drake() -> void:
	var monster := _new_master(DRAKE_NAME)

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
	monster.boss_phases = _master_phases([
		["Vrakthorne spreads its wings wide...", "Vrakthorne takes to the air!"],
		["Vrakthorne's descent shakes the ground...", "Vrakthorne lands with earth-shaking force!"],
		["Vrakthorne's eyes burn with desperate fury...", "Vrakthorne unleashes a desperate fury!"],
	], [
		["Rending Claws", "Tail Sweep"],
		["Fire Breath", "Terrifying Roar"],
		["Crushing Bite", "Tail Sweep"],
		["Fire Breath", "Rending Claws", "Crushing Bite"],
	])
	_monsters["boss_drake"] = monster


# The Ashen Halls. Smoke and cinders: its ash chokes off spells and its
# embers blind. It shrugs off fire and hates the cold.
static func _create_boss_ash_wyrm() -> void:
	var monster := _new_master("Morvane the Ash Wyrm", Color(1.0, 0.72, 0.55))
	monster.element_resist = {CharacterEnums.Element.FIRE: 0.5, CharacterEnums.Element.ICE: -0.5}

	var cinder_breath := MonsterAttack.create_magical("Cinder Breath", "4d6", CharacterEnums.Element.FIRE, 0)
	cinder_breath.targets_all = true
	cinder_breath.is_breath_weapon = true

	var ember_lash := MonsterAttack.create_with_effect(
		"Ember Lash", "2d8+4", 2, CharacterEnums.StatusEffect.BLINDED, 0.25, "2+1d3", "physical", 4)
	ember_lash.targets_row = true

	var searing_claws := MonsterAttack.create_basic("Searing Claws", "3d8+3", 4)

	var choking_ash := MonsterAttack.create_ability(
		"Choking Ash", "1d4", CharacterEnums.StatusEffect.SILENCED, 0.45, "2+1d3", "physical", 5)
	choking_ash.targets_all = true

	var crushing_bite := MonsterAttack.create_basic("Crushing Bite", "2d10+4", 4)

	monster.attacks = [cinder_breath, ember_lash, searing_claws, choking_ash, crushing_bite]
	monster.boss_phases = _master_phases([
		["Ash begins to pour from Morvane's jaws...", "Morvane rises on a pillar of smoke!"],
		["The smoke thins as Morvane drops...", "Morvane crashes down in a storm of embers!"],
		["Morvane's hide glows like a banked fire...", "Morvane burns white with fury!"],
	], [
		["Searing Claws", "Ember Lash"],
		["Cinder Breath", "Choking Ash"],
		["Crushing Bite", "Ember Lash"],
		["Cinder Breath", "Searing Claws", "Crushing Bite"],
	])
	_monsters["boss_ash_wyrm"] = monster


# The Drowned Vaults. Cold water: its breath is frost, its mist puts the party
# to sleep and its coils hold them under. Cold does little to it, fire a lot.
static func _create_boss_pale_wyrm() -> void:
	var monster := _new_master("Ulthessa the Pale Wyrm", Color(0.62, 0.86, 1.0))
	monster.element_resist = {CharacterEnums.Element.ICE: 0.5, CharacterEnums.Element.FIRE: -0.5}

	var frost_breath := MonsterAttack.create_magical("Frost Breath", "4d6", CharacterEnums.Element.ICE, 0)
	frost_breath.targets_all = true
	frost_breath.is_breath_weapon = true

	var tail_sweep := MonsterAttack.create_basic("Tail Sweep", "2d8+4", 2)
	tail_sweep.targets_row = true

	var rending_claws := MonsterAttack.create_basic("Rending Claws", "3d8+3", 4)

	var numbing_mist := MonsterAttack.create_ability(
		"Numbing Mist", "1d4", CharacterEnums.StatusEffect.ASLEEP, 0.30, "1+1d2", "physical", 5)
	numbing_mist.targets_all = true
	numbing_mist.is_magical = true
	numbing_mist.element = CharacterEnums.Element.ICE

	var drowning_coil := MonsterAttack.create_with_effect(
		"Drowning Coil", "2d10+4", 4, CharacterEnums.StatusEffect.PARALYZED, 0.20, "1+1d2", "physical", 4)

	monster.attacks = [frost_breath, tail_sweep, rending_claws, numbing_mist, drowning_coil]
	monster.boss_phases = _master_phases([
		["Cold mist rises around Ulthessa...", "Ulthessa slides up into the dark above!"],
		["Water streams from above as Ulthessa uncoils...", "Ulthessa drops among you like a falling wave!"],
		["Ulthessa's pale eyes go flat and still...", "Ulthessa thrashes in a killing frenzy!"],
	], [
		["Rending Claws", "Tail Sweep"],
		["Frost Breath", "Numbing Mist"],
		["Drowning Coil", "Tail Sweep"],
		["Frost Breath", "Rending Claws", "Drowning Coil"],
	])
	_monsters["boss_pale_wyrm"] = monster


# The Verdant Dark. Rot and spores: nearly everything it does poisons, and
# its spores turn the party on each other. Lightning is its bane.
static func _create_boss_mire_wyrm() -> void:
	var monster := _new_master("Khaldrun the Mire Wyrm", Color(0.68, 1.0, 0.62))
	monster.element_resist = {CharacterEnums.Element.LIGHTNING: -0.5}

	# Weaker than the other masters' breath, since the poison keeps working.
	var miasma := MonsterAttack.create_with_effect(
		"Miasma", "3d6", 0, CharacterEnums.StatusEffect.POISONED, 0.50, "3+1d3", "physical", 5)
	miasma.targets_all = true
	miasma.is_breath_weapon = true

	var tail_sweep := MonsterAttack.create_basic("Tail Sweep", "2d8+4", 2)
	tail_sweep.targets_row = true

	var rending_claws := MonsterAttack.create_basic("Rending Claws", "3d8+3", 4)

	var spore_cloud := MonsterAttack.create_ability(
		"Spore Cloud", "1d4", CharacterEnums.StatusEffect.CONFUSED, 0.35, "2+1d2", "mental", 5)
	spore_cloud.targets_all = true

	var venomous_bite := MonsterAttack.create_with_effect(
		"Venomous Bite", "2d10+4", 4, CharacterEnums.StatusEffect.POISONED, 0.60, "3+1d3", "physical", 4)

	monster.attacks = [miasma, tail_sweep, rending_claws, spore_cloud, venomous_bite]
	monster.boss_phases = _master_phases([
		["Khaldrun's throat swells with something foul...", "Khaldrun rears up into the canopy of roots!"],
		["Roots crack as Khaldrun bears down...", "Khaldrun drops into the mire and it erupts!"],
		["Black ichor runs from Khaldrun's wounds...", "Khaldrun lashes out in its death throes!"],
	], [
		["Rending Claws", "Tail Sweep"],
		["Miasma", "Spore Cloud"],
		["Venomous Bite", "Tail Sweep"],
		["Miasma", "Rending Claws", "Venomous Bite"],
	])
	_monsters["boss_mire_wyrm"] = monster


# The Heart Below. What woke the others: a dead king, half again as hard to
# kill as a master, who stands his ground. Dark and the mind's arts do little
# to him, and holy power does the most.
static func _create_boss_hollow_king() -> void:
	var monster := _new_master("The Hollow King", Color(0.82, 0.6, 1.0))
	monster.max_hp = 390
	monster.exp_reward = 1500
	monster.creature_type = CharacterEnums.CreatureType.UNDEAD
	# He doesn't fly, so his guard does the work the masters' wings do.
	monster.is_flying = false
	monster.evasion = 12
	monster.defense = 11
	monster.element_resist = {
		CharacterEnums.Element.DARK: 0.5, CharacterEnums.Element.PSYCHIC: 0.5,
		CharacterEnums.Element.HOLY: -0.5,
	}

	var grave_chill := MonsterAttack.create_magical("Grave Chill", "4d6", CharacterEnums.Element.DARK, 0)
	grave_chill.targets_all = true

	var sweeping_blade := MonsterAttack.create_basic("Sweeping Blade", "2d8+4", 2)
	sweeping_blade.targets_row = true

	var kings_blade := MonsterAttack.create_basic("King's Blade", "3d8+3", 4)

	var hollow_gaze := MonsterAttack.create_ability(
		"Hollow Gaze", "1d4", CharacterEnums.StatusEffect.AFRAID, 0.50, "2+1d3", "mental", 5)
	hollow_gaze.targets_all = true

	var withering_touch := MonsterAttack.create_with_effect(
		"Withering Touch", "2d10+4", 4, CharacterEnums.StatusEffect.PARALYZED, 0.20, "1+1d2", "magical", 4)
	withering_touch.is_magical = true
	withering_touch.element = CharacterEnums.Element.DARK

	monster.attacks = [grave_chill, sweeping_blade, kings_blade, hollow_gaze, withering_touch]
	monster.boss_phases = _master_phases([
		["The Hollow King lifts his empty crown...", "The dark gathers to the Hollow King!"],
		["The Hollow King lowers his blade...", "The Hollow King strides in among you!"],
		["Cracks of pale light run through the Hollow King...", "The Hollow King will not go down alone!"],
	], [
		["King's Blade", "Sweeping Blade"],
		["Grave Chill", "Hollow Gaze"],
		["Withering Touch", "Sweeping Blade"],
		["Grave Chill", "King's Blade", "Withering Touch"],
	])
	_monsters["boss_hollow_king"] = monster


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
