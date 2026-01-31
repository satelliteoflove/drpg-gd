class_name ChestSystem
extends RefCounted

const CombatRNG = preload("res://autoload/combat_rng.gd")
const ChestClass = preload("res://resources/chest.gd")
const TrapClass = preload("res://resources/trap.gd")
const TrapDatabase = preload("res://data/traps/trap_database.gd")
const DamageCalc = preload("res://systems/combat/damage_calculator.gd")
const CharEnum = preload("res://resources/character_enums.gd")
const ItemClass = preload("res://resources/item.gd")

const PLAIN_TRAP_CHANCE: float = 0.10
const ORNATE_TRAP_CHANCE: float = 0.70

const BASE_INSPECT_CHANCE: float = 0.30
const THIEF_INSPECT_CHANCE: float = 0.70

const BASE_DISARM_CHANCE: float = 0.40
const THIEF_DISARM_CHANCE: float = 0.85


static func create_chest_from_loot(loot: Array[Item], is_boss: bool) -> ChestClass:
	var chest_type := _determine_chest_type(loot, is_boss)
	var trap := _maybe_generate_trap(chest_type)
	return ChestClass.create(chest_type, loot, trap)


static func _determine_chest_type(loot: Array[Item], is_boss: bool) -> ChestClass.ChestType:
	if is_boss:
		return ChestClass.ChestType.ORNATE

	for item in loot:
		if item.rarity == ItemClass.ItemRarity.LEGENDARY:
			return ChestClass.ChestType.ORNATE

	return ChestClass.ChestType.PLAIN


static func _maybe_generate_trap(chest_type: ChestClass.ChestType) -> TrapClass:
	var trap_chance := PLAIN_TRAP_CHANCE if chest_type == ChestClass.ChestType.PLAIN else ORNATE_TRAP_CHANCE

	if CombatRNG.randf() < trap_chance:
		if chest_type == ChestClass.ChestType.PLAIN:
			return TrapDatabase.get_random_trap_excluding_alarm()
		else:
			return TrapDatabase.get_random_trap()

	return null


static func attempt_inspect(chest: ChestClass, inspector: Character) -> Dictionary:
	var is_thief := inspector.character_class == CharEnum.CharacterClass.THIEF
	var success_chance := THIEF_INSPECT_CHANCE if is_thief else BASE_INSPECT_CHANCE

	success_chance += inspector.luck * 0.01
	success_chance = clampf(success_chance, 0.05, 0.95)

	var roll := CombatRNG.randf()
	var success := roll < success_chance

	if success and chest.is_trapped and chest.trap != null:
		chest.trap_identified = true
		return {
			"success": true,
			"found_trap": true,
			"trap_name": chest.trap.trap_name,
			"message": "%s carefully inspects the chest... A %s trap!" % [inspector.get_display_name(), chest.trap.trap_name]
		}
	elif success:
		return {
			"success": true,
			"found_trap": false,
			"trap_name": "",
			"message": "%s inspects the chest... It appears to be safe." % inspector.get_display_name()
		}
	else:
		return {
			"success": false,
			"found_trap": false,
			"trap_name": "",
			"message": "%s inspects the chest... Unable to determine if it's trapped." % inspector.get_display_name()
		}


static func attempt_disarm(chest: ChestClass, disarmer: Character) -> Dictionary:
	if not chest.is_trapped or chest.trap == null:
		return {
			"success": true,
			"message": "%s attempts to disarm... There was no trap." % disarmer.get_display_name()
		}

	if chest.trap_disarmed:
		return {
			"success": true,
			"message": "The trap has already been disarmed."
		}

	var is_thief := disarmer.character_class == CharEnum.CharacterClass.THIEF
	var success_chance := THIEF_DISARM_CHANCE if is_thief else BASE_DISARM_CHANCE

	success_chance += disarmer.agility * 0.01
	success_chance = clampf(success_chance, 0.05, 0.95)

	var roll := CombatRNG.randf()
	var success := roll < success_chance

	if success:
		chest.trap_disarmed = true
		return {
			"success": true,
			"message": "%s attempts to disarm the trap... Success!" % disarmer.get_display_name()
		}
	else:
		return {
			"success": false,
			"message": "%s attempts to disarm the trap... Failed!" % disarmer.get_display_name()
		}


static func trigger_trap(chest: ChestClass, opener: Character, party: Party) -> Dictionary:
	if not chest.is_trapped or chest.trap == null or chest.trap_disarmed:
		return {
			"triggered": false,
			"messages": [],
			"combat_triggered": false,
			"party_wiped": false
		}

	var trap: TrapClass = chest.trap
	var messages: Array[String] = []
	var targets: Array[Character] = []
	var combat_triggered := false

	if trap.triggers_combat:
		messages.append("You triggered an %s! Guards are alerted!" % trap.trap_name)
		return {
			"triggered": true,
			"messages": messages,
			"combat_triggered": true,
			"party_wiped": false
		}

	match trap.damage_target:
		TrapClass.DamageTarget.OPENER:
			targets = [opener]
		TrapClass.DamageTarget.PARTY:
			targets = party.get_alive_members()
		TrapClass.DamageTarget.FRONT_ROW:
			targets = party.get_front_row_alive()

	if trap.damage_dice != "":
		for target in targets:
			var damage := DamageCalc.roll_dice(trap.damage_dice)
			var actual_damage := target.take_damage(damage)
			messages.append("%s takes %d damage from the %s!" % [target.get_display_name(), actual_damage, trap.trap_name])

	if trap.status_effect != CharEnum.StatusEffect.NONE:
		for target in targets:
			if not target.is_dead:
				target.add_status(trap.status_effect, trap.status_duration, "trap", 0)
				var status_name := CharEnum.get_status_name(trap.status_effect)
				messages.append("%s is now %s!" % [target.get_display_name(), status_name])

	var party_wiped := party.is_wiped()

	return {
		"triggered": true,
		"messages": messages,
		"combat_triggered": combat_triggered,
		"party_wiped": party_wiped
	}


static func quick_open(chest: ChestClass, thief: Character, party: Party) -> Dictionary:
	if chest.chest_type != ChestClass.ChestType.PLAIN:
		return {
			"success": false,
			"items": [],
			"messages": ["Cannot quick open an ornate chest."]
		}

	if chest.is_trapped and not chest.trap_disarmed:
		var inspect_result := attempt_inspect(chest, thief)
		if inspect_result.found_trap:
			var disarm_result := attempt_disarm(chest, thief)
			if not disarm_result.success:
				var trap_result := trigger_trap(chest, thief, party)
				var all_messages: Array[String] = [inspect_result.message, disarm_result.message]
				all_messages.append_array(trap_result.messages)
				return {
					"success": false,
					"items": [],
					"messages": all_messages,
					"combat_triggered": trap_result.get("combat_triggered", false),
					"party_wiped": trap_result.get("party_wiped", false)
				}

	chest.trap_disarmed = true
	var item_names: Array[String] = []
	for item in chest.contents:
		item_names.append(item.get_display_name())

	return {
		"success": true,
		"items": chest.contents,
		"messages": ["%s quickly opens the chest safely." % thief.get_display_name()],
		"combat_triggered": false,
		"party_wiped": false
	}


static func open_chest(chest: ChestClass, opener: Character, party: Party) -> Dictionary:
	var messages: Array[String] = []
	var combat_triggered := false
	var party_wiped := false

	if chest.is_trapped and not chest.trap_disarmed:
		var trap_result := trigger_trap(chest, opener, party)
		messages.append_array(trap_result.messages)
		combat_triggered = trap_result.get("combat_triggered", false)
		party_wiped = trap_result.get("party_wiped", false)

		if combat_triggered or party_wiped:
			return {
				"success": false,
				"items": [],
				"messages": messages,
				"combat_triggered": combat_triggered,
				"party_wiped": party_wiped
			}

	var item_names: Array[String] = []
	for item in chest.contents:
		item_names.append(item.get_display_name())

	if not item_names.is_empty():
		messages.append("You found: %s" % ", ".join(item_names))
	else:
		messages.append("The chest is empty.")

	return {
		"success": true,
		"items": chest.contents,
		"messages": messages,
		"combat_triggered": false,
		"party_wiped": party_wiped
	}
