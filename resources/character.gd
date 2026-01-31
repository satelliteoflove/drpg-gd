class_name Character
extends Resource

const CombatRNG = preload("res://autoload/combat_rng.gd")
const CharEnum = preload("res://resources/character_enums.gd")
const ClassDataRef = preload("res://resources/class_data.gd")
const XPTable = preload("res://resources/experience_table.gd")
const SpellLearning = preload("res://systems/magic/spell_learning.gd")

signal level_up_pending()
signal level_up_completed(new_level: int)
signal spells_learned(spell_names: Array[String])
signal died()
signal revived()
signal status_applied(status: CharEnum.StatusEffect)
signal status_removed(status: CharEnum.StatusEffect)


class ActiveStatus:
	var type: CharEnum.StatusEffect = CharEnum.StatusEffect.NONE
	var duration: int = -1
	var source: String = ""
	var power: int = 0

	func _init(p_type: CharEnum.StatusEffect = CharEnum.StatusEffect.NONE, p_duration: int = -1, p_source: String = "", p_power: int = 0) -> void:
		type = p_type
		duration = p_duration
		source = p_source
		power = p_power

	func is_permanent() -> bool:
		return duration < 0

	func tick() -> bool:
		if duration > 0:
			duration -= 1
		return duration == 0

@export_group("Identity")
@export var id: String = ""
@export var character_name: String = "Adventurer"
@export var race: CharEnum.Race = CharEnum.Race.HUMAN
@export var character_class: CharEnum.CharacterClass = CharEnum.CharacterClass.FIGHTER
@export var alignment: CharEnum.Alignment = CharEnum.Alignment.NEUTRAL
@export var gender: CharEnum.Gender = CharEnum.Gender.MALE
@export var age: int = 18

@export_group("Base Stats")
@export var base_strength: int = 10
@export var base_intelligence: int = 10
@export var base_piety: int = 10
@export var base_vitality: int = 10
@export var base_agility: int = 10
@export var base_luck: int = 10

@export_group("Current Stats")
@export var strength: int = 10
@export var intelligence: int = 10
@export var piety: int = 10
@export var vitality: int = 10
@export var agility: int = 10
@export var luck: int = 10

@export_group("Progression")
@export var level: int = 1
@export var experience: int = 0
@export var pending_level_up: bool = false

@export_group("Combat Stats")
@export var current_hp: int = 0
@export var max_hp: int = 0
@export var current_mp: int = 0
@export var max_mp: int = 0

@export_group("Status")
@export var is_dead: bool = false
@export var status_effects: Array[CharEnum.StatusEffect] = []
@export var death_count: int = 0
var is_defending: bool = false
var active_statuses: Array[ActiveStatus] = []

@export_group("Equipment Slots")
@export var equipped_weapon: Item = null
@export var equipped_armor: Item = null
@export var equipped_shield: Item = null
@export var equipped_helmet: Item = null
@export var equipped_gloves: Item = null
@export var equipped_boots: Item = null
@export var equipped_accessory: Item = null

@export_group("Derived Combat Stats")
@export var weapon_dice: String = "1d4"
@export var accuracy: int = 0
@export var defense: int = 0
@export var evasion: int = 0
@export var damage_bonus: int = 0

@export_group("Spells")
@export var known_spells: Array[String] = []
@export var max_spell_level: int = 0


static func create_new(
	p_name: String,
	p_race: CharEnum.Race,
	p_class: CharEnum.CharacterClass,
	p_alignment: CharEnum.Alignment,
	p_gender: CharEnum.Gender,
	p_stats: Dictionary
) -> Character:
	var character := Character.new()
	character.id = _generate_id()
	character.character_name = p_name
	character.race = p_race
	character.character_class = p_class
	character.alignment = p_alignment
	character.gender = p_gender
	character.age = CharEnum.get_base_age(p_race) + CombatRNG.randi_range(0, 5)

	character.base_strength = p_stats.get("strength", 10)
	character.base_intelligence = p_stats.get("intelligence", 10)
	character.base_piety = p_stats.get("piety", 10)
	character.base_vitality = p_stats.get("vitality", 10)
	character.base_agility = p_stats.get("agility", 10)
	character.base_luck = p_stats.get("luck", 10)

	character.strength = character.base_strength
	character.intelligence = character.base_intelligence
	character.piety = character.base_piety
	character.vitality = character.base_vitality
	character.agility = character.base_agility
	character.luck = character.base_luck

	character.level = 1
	character.experience = 0
	character._recalculate_derived_stats()
	character.current_hp = character.max_hp
	character.current_mp = character.max_mp

	return character


static func roll_stats_for_race(p_race: CharEnum.Race) -> Dictionary:
	return {
		"strength": CharEnum.roll_stat(p_race, "strength"),
		"intelligence": CharEnum.roll_stat(p_race, "intelligence"),
		"piety": CharEnum.roll_stat(p_race, "piety"),
		"vitality": CharEnum.roll_stat(p_race, "vitality"),
		"agility": CharEnum.roll_stat(p_race, "agility"),
		"luck": CharEnum.roll_stat(p_race, "luck")
	}


static func _generate_id() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	var result := ""
	for i in range(12):
		result += chars[CombatRNG.randi() % chars.length()]
	return result


func _recalculate_derived_stats() -> void:
	_calculate_max_hp()
	_calculate_max_mp()
	_calculate_combat_stats()
	_update_spell_level()


func _calculate_max_hp() -> void:
	var hp_base := ClassDataRef.get_hp_base(character_class)
	var vit_bonus := (vitality - 10) / 2
	var equip_bonus := _get_equipment_hp_bonus()
	max_hp = maxi(1, (hp_base + vit_bonus) * level + equip_bonus)


func _calculate_max_mp() -> void:
	if not ClassDataRef.can_use_magic(character_class):
		max_mp = 0
		return

	var mp_base := ClassDataRef.get_mp_base(character_class)
	var class_data: Dictionary = ClassDataRef.get_class_data(character_class)

	var stat_bonus := 0
	var schools: Array = class_data.get("spell_schools", [])

	if class_data.get("is_multiclass_caster", false):
		stat_bonus = (intelligence - 10) / 4 + (piety - 10) / 4
	elif CharEnum.SpellSchool.MAGE in schools or CharEnum.SpellSchool.ALCHEMIST in schools:
		stat_bonus = (intelligence - 10) / 4
	elif CharEnum.SpellSchool.PRIEST in schools:
		stat_bonus = (piety - 10) / 4
	elif CharEnum.SpellSchool.PSIONIC in schools:
		stat_bonus = (intelligence - 10) / 4

	var equip_bonus := _get_equipment_mp_bonus()

	if class_data.get("is_hybrid_caster", false) or class_data.get("is_late_caster", false):
		max_mp = maxi(0, (2 + stat_bonus) * level + equip_bonus)
	else:
		max_mp = maxi(0, (mp_base + stat_bonus) * level + equip_bonus)


func _calculate_combat_stats() -> void:
	accuracy = level + level / 2 + agility / 4 + _get_equipment_accuracy_bonus()
	evasion = agility / 3 + _get_equipment_evasion_bonus()
	defense = _get_equipment_defense_bonus()
	damage_bonus = _get_equipment_damage_bonus()
	weapon_dice = _get_weapon_dice()


func _update_spell_level() -> void:
	max_spell_level = ClassDataRef.get_spell_level_at_character_level(character_class, level)


func _get_all_equipment() -> Array[Item]:
	var items: Array[Item] = []
	if equipped_weapon: items.append(equipped_weapon)
	if equipped_armor: items.append(equipped_armor)
	if equipped_shield: items.append(equipped_shield)
	if equipped_helmet: items.append(equipped_helmet)
	if equipped_gloves: items.append(equipped_gloves)
	if equipped_boots: items.append(equipped_boots)
	if equipped_accessory: items.append(equipped_accessory)
	return items


func _get_equipment_hp_bonus() -> int:
	var total := 0
	for item in _get_all_equipment():
		total += item.get_effective_hp_bonus()
	return total


func _get_equipment_mp_bonus() -> int:
	var total := 0
	for item in _get_all_equipment():
		total += item.get_effective_mp_bonus()
	return total


func _get_equipment_accuracy_bonus() -> int:
	var total := 0
	for item in _get_all_equipment():
		total += item.get_effective_accuracy_bonus()
	return total


func _get_equipment_evasion_bonus() -> int:
	var total := 0
	for item in _get_all_equipment():
		total += item.get_effective_evasion_bonus()
	return total


func _get_equipment_defense_bonus() -> int:
	var total := 0
	for item in _get_all_equipment():
		total += item.get_effective_defense_bonus()
	return total


func _get_equipment_damage_bonus() -> int:
	var total := 0
	for item in _get_all_equipment():
		total += item.get_effective_damage_bonus()
	return total


func _get_weapon_dice() -> String:
	if equipped_weapon and equipped_weapon.damage_dice != "":
		return equipped_weapon.damage_dice
	return "1d4"


func equip_item(item: Item) -> Item:
	if not item.is_equipment():
		return null
	if not item.can_equip(self):
		return null

	var old_item: Item = null

	match item.item_type:
		Item.ItemType.WEAPON:
			old_item = equipped_weapon
			equipped_weapon = item
		Item.ItemType.ARMOR:
			old_item = equipped_armor
			equipped_armor = item
		Item.ItemType.SHIELD:
			old_item = equipped_shield
			equipped_shield = item
		Item.ItemType.HELMET:
			old_item = equipped_helmet
			equipped_helmet = item
		Item.ItemType.GLOVES:
			old_item = equipped_gloves
			equipped_gloves = item
		Item.ItemType.BOOTS:
			old_item = equipped_boots
			equipped_boots = item
		Item.ItemType.ACCESSORY:
			old_item = equipped_accessory
			equipped_accessory = item

	_recalculate_derived_stats()
	return old_item


func unequip_slot(slot_type: Item.ItemType) -> Item:
	var item := get_equipped_item(slot_type)
	if item and item.is_cursed:
		return null

	var old_item: Item = null

	match slot_type:
		Item.ItemType.WEAPON:
			old_item = equipped_weapon
			equipped_weapon = null
		Item.ItemType.ARMOR:
			old_item = equipped_armor
			equipped_armor = null
		Item.ItemType.SHIELD:
			old_item = equipped_shield
			equipped_shield = null
		Item.ItemType.HELMET:
			old_item = equipped_helmet
			equipped_helmet = null
		Item.ItemType.GLOVES:
			old_item = equipped_gloves
			equipped_gloves = null
		Item.ItemType.BOOTS:
			old_item = equipped_boots
			equipped_boots = null
		Item.ItemType.ACCESSORY:
			old_item = equipped_accessory
			equipped_accessory = null

	_recalculate_derived_stats()
	return old_item


func force_unequip_slot(slot_type: Item.ItemType) -> Item:
	var old_item: Item = null

	match slot_type:
		Item.ItemType.WEAPON:
			old_item = equipped_weapon
			equipped_weapon = null
		Item.ItemType.ARMOR:
			old_item = equipped_armor
			equipped_armor = null
		Item.ItemType.SHIELD:
			old_item = equipped_shield
			equipped_shield = null
		Item.ItemType.HELMET:
			old_item = equipped_helmet
			equipped_helmet = null
		Item.ItemType.GLOVES:
			old_item = equipped_gloves
			equipped_gloves = null
		Item.ItemType.BOOTS:
			old_item = equipped_boots
			equipped_boots = null
		Item.ItemType.ACCESSORY:
			old_item = equipped_accessory
			equipped_accessory = null

	_recalculate_derived_stats()
	return old_item


func has_cursed_equipment() -> bool:
	for item in _get_all_equipment():
		if item.is_cursed:
			return true
	return false


func get_cursed_slots() -> Array[Item.ItemType]:
	var slots: Array[Item.ItemType] = []
	var slot_types: Array[Item.ItemType] = [
		Item.ItemType.WEAPON,
		Item.ItemType.ARMOR,
		Item.ItemType.SHIELD,
		Item.ItemType.HELMET,
		Item.ItemType.GLOVES,
		Item.ItemType.BOOTS,
		Item.ItemType.ACCESSORY
	]
	for slot_type in slot_types:
		var item := get_equipped_item(slot_type)
		if item and item.is_cursed:
			slots.append(slot_type)
	return slots


func get_equipped_item(slot_type: Item.ItemType) -> Item:
	match slot_type:
		Item.ItemType.WEAPON: return equipped_weapon
		Item.ItemType.ARMOR: return equipped_armor
		Item.ItemType.SHIELD: return equipped_shield
		Item.ItemType.HELMET: return equipped_helmet
		Item.ItemType.GLOVES: return equipped_gloves
		Item.ItemType.BOOTS: return equipped_boots
		Item.ItemType.ACCESSORY: return equipped_accessory
	return null


func get_display_name() -> String:
	return character_name if character_name else id


func get_race_name() -> String:
	return CharEnum.get_race_name(race)


func get_class_name() -> String:
	return CharEnum.get_class_name(character_class)


func get_alignment_name() -> String:
	return CharEnum.get_alignment_name(alignment)


func init_combat() -> void:
	if current_hp <= 0 and not is_dead:
		current_hp = max_hp
	is_defending = false
	_recalculate_derived_stats()


func take_damage(amount: int) -> int:
	var reduced_amount := amount
	if is_defending:
		reduced_amount = amount / 2
	var actual := mini(reduced_amount, current_hp)
	current_hp -= actual
	if current_hp <= 0:
		current_hp = 0
		_die()
	return actual


func heal(amount: int) -> int:
	if is_dead:
		return 0
	var actual := mini(amount, max_hp - current_hp)
	current_hp += actual
	return actual


func restore_mp(amount: int) -> int:
	var actual := mini(amount, max_mp - current_mp)
	current_mp += actual
	return actual


func spend_mp(amount: int) -> bool:
	if current_mp < amount:
		return false
	current_mp -= amount
	return true


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	death_count += 1
	add_status(CharEnum.StatusEffect.DEAD, -1, "", 0)
	died.emit()


func resurrect(vitality_loss: int = 1) -> bool:
	if not is_dead:
		return false

	if has_status(CharEnum.StatusEffect.LOST):
		return false

	vitality = maxi(1, vitality - vitality_loss)
	age += CombatRNG.randi_range(1, 5)
	is_dead = false
	remove_status(CharEnum.StatusEffect.DEAD)
	remove_status(CharEnum.StatusEffect.ASHED)

	_recalculate_derived_stats()
	current_hp = maxi(1, max_hp / 4)

	revived.emit()
	return true


func add_experience(amount: int) -> void:
	if is_dead or level >= XPTable.MAX_LEVEL:
		return

	experience += amount

	var required := XPTable.get_required_xp(level + 1, race, character_class)
	if experience >= required and not pending_level_up:
		pending_level_up = true
		level_up_pending.emit()


func confirm_level_up() -> bool:
	if not pending_level_up or level >= XPTable.MAX_LEVEL:
		return false

	var old_max_hp := max_hp
	var old_max_mp := max_mp

	level += 1
	pending_level_up = false

	if CombatRNG.randf() < 0.3:
		_gain_random_stat()

	_recalculate_derived_stats()

	var hp_gain := max_hp - old_max_hp
	var mp_gain := max_mp - old_max_mp
	current_hp += hp_gain
	current_mp += mp_gain

	var learned_spells := SpellLearning.try_learn_spells_on_level_up(self)
	if not learned_spells.is_empty():
		spells_learned.emit(learned_spells)

	var next_required := XPTable.get_required_xp(level + 1, race, character_class)
	if experience >= next_required and level < XPTable.MAX_LEVEL:
		pending_level_up = true
		level_up_pending.emit()

	level_up_completed.emit(level)
	return true


func _gain_random_stat() -> void:
	var stats := ["strength", "intelligence", "piety", "vitality", "agility", "luck"]
	var chosen: String = stats[CombatRNG.randi() % stats.size()]

	match chosen:
		"strength":
			strength = mini(strength + 1, 25)
		"intelligence":
			intelligence = mini(intelligence + 1, 25)
		"piety":
			piety = mini(piety + 1, 25)
		"vitality":
			vitality = mini(vitality + 1, 25)
		"agility":
			agility = mini(agility + 1, 25)
		"luck":
			luck = mini(luck + 1, 25)


func get_xp_to_next_level() -> int:
	return XPTable.get_xp_to_next_level(experience, level, race, character_class)


func get_xp_progress_percent() -> float:
	if level >= XPTable.MAX_LEVEL:
		return 100.0

	var current_req := XPTable.get_required_xp(level, race, character_class)
	var next_req := XPTable.get_required_xp(level + 1, race, character_class)
	var range_xp := next_req - current_req

	if range_xp <= 0:
		return 100.0

	var progress := experience - current_req
	return clampf(float(progress) / float(range_xp) * 100.0, 0.0, 100.0)


func has_status(effect: CharEnum.StatusEffect) -> bool:
	return status_effects.has(effect)


func add_status(effect: CharEnum.StatusEffect, duration: int = -1, source: String = "", power: int = 0) -> bool:
	if has_status(effect):
		return false

	var exclusive_group := CharEnum.get_exclusive_group(effect)
	for existing in exclusive_group:
		if existing != effect and has_status(existing):
			remove_status(existing)

	status_effects.append(effect)
	active_statuses.append(ActiveStatus.new(effect, duration, source, power))
	status_applied.emit(effect)
	return true


func remove_status(effect: CharEnum.StatusEffect) -> void:
	status_effects.erase(effect)
	for i in range(active_statuses.size() - 1, -1, -1):
		if active_statuses[i].type == effect:
			active_statuses.remove_at(i)
			break
	status_removed.emit(effect)


func get_active_status(effect: CharEnum.StatusEffect) -> ActiveStatus:
	for active in active_statuses:
		if active.type == effect:
			return active
	return null


func get_status_duration(effect: CharEnum.StatusEffect) -> int:
	var active := get_active_status(effect)
	return active.duration if active else 0


func clear_status_effects() -> void:
	status_effects.clear()
	active_statuses.clear()
	if is_dead:
		status_effects.append(CharEnum.StatusEffect.DEAD)
		active_statuses.append(ActiveStatus.new(CharEnum.StatusEffect.DEAD, -1, "", 0))


func is_disabled() -> bool:
	return has_status(CharEnum.StatusEffect.ASLEEP) or \
		   has_status(CharEnum.StatusEffect.PARALYZED) or \
		   has_status(CharEnum.StatusEffect.STONED)


func is_silenced() -> bool:
	return has_status(CharEnum.StatusEffect.SILENCED)


func can_act() -> bool:
	return not is_dead and not is_disabled()


func get_stats_dict() -> Dictionary:
	return {
		"strength": strength,
		"intelligence": intelligence,
		"piety": piety,
		"vitality": vitality,
		"agility": agility,
		"luck": luck
	}


func can_learn_spell_level(spell_level: int) -> bool:
	return spell_level <= max_spell_level


func get_attack_power() -> int:
	return level / 2 + (strength - 10) / 2 + damage_bonus
