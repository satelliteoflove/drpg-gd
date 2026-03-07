## Represents a playable character with stats, equipment, spells, and status effects.
class_name Character
extends Resource

signal level_up_pending()
signal level_up_completed(new_level: int)
signal spells_learned(spell_names: Array[String])
signal died()
signal revived()
signal status_applied(status: CharacterEnums.StatusEffect)
signal status_removed(status: CharacterEnums.StatusEffect)


class ActiveStatus:
	var type: CharacterEnums.StatusEffect = CharacterEnums.StatusEffect.NONE
	var duration: int = -1
	var source: String = ""
	var power: int = 0

	func _init(p_type: CharacterEnums.StatusEffect = CharacterEnums.StatusEffect.NONE, p_duration: int = -1, p_source: String = "", p_power: int = 0) -> void:
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
@export var race: CharacterEnums.Race = CharacterEnums.Race.HUMAN
@export var character_class: CharacterEnums.CharacterClass = CharacterEnums.CharacterClass.FIGHTER
@export var alignment: CharacterEnums.Alignment = CharacterEnums.Alignment.NEUTRAL
@export var gender: CharacterEnums.Gender = CharacterEnums.Gender.MALE
@export var age_days: int = 6570

@export_group("Base Stats")
@export var base_strength: int = 10
@export var base_intelligence: int = 10
@export var base_piety: int = 10
@export var base_vitality: int = 10
@export var base_agility: int = 10
@export var base_luck: int = 10

@export_group("Peak Stats")
@export var peak_strength: int = 10
@export var peak_intelligence: int = 10
@export var peak_piety: int = 10
@export var peak_vitality: int = 10
@export var peak_agility: int = 10
@export var peak_luck: int = 10

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
@export var status_effects: Array[CharacterEnums.StatusEffect] = []
@export var death_count: int = 0
var is_defending: bool = false
var active_statuses: Array[ActiveStatus] = []

const AVAILABILITY_AVAILABLE: int = 0
const AVAILABILITY_TRAINING: int = 1
const REST_BONUS_MAX: float = 1.5
const REST_BONUS_PER_TOWN_DAY: float = 0.01
const REST_BONUS_DECAY_PER_ENCOUNTER: float = 0.1

const SLOT_MAP: Dictionary = {
	Item.ItemType.WEAPON: "equipped_weapon",
	Item.ItemType.ARMOR: "equipped_armor",
	Item.ItemType.SHIELD: "equipped_shield",
	Item.ItemType.HELMET: "equipped_helmet",
	Item.ItemType.GLOVES: "equipped_gloves",
	Item.ItemType.BOOTS: "equipped_boots",
	Item.ItemType.ACCESSORY: "equipped_accessory",
}

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

@export_group("Availability")
@export var availability: int = 0
@export var available_on_day: int = 0
@export var training_days_total: int = 0
@export var training_target_class: int = -1
@export var town_job: int = -1
@export var town_days_accumulated: int = 0
@export var rest_bonus_xp_multiplier: float = 1.0

@export_group("Marks")
@export var marks: Array[Dictionary] = []

@export_group("Personality")
@export var tendencies: Dictionary = {}
@export var evidence: Dictionary = {}
@export var traits: Dictionary = {}
@export var crystallization_events: Dictionary = {}

@export_group("Spells")
@export var known_spells: Array[String] = []
@export var max_spell_level: int = 0


## Creates a new character with the given attributes.
## [param p_name]: Character's name.
## [param p_race]: Character's race.
## [param p_class]: Character's class.
## [param p_alignment]: Character's alignment.
## [param p_gender]: Character's gender.
## [param p_stats]: Dictionary with strength, intelligence, piety, vitality, agility, luck.
## [return]: Fully initialized Character resource.
static func create_new(
	p_name: String,
	p_race: CharacterEnums.Race,
	p_class: CharacterEnums.CharacterClass,
	p_alignment: CharacterEnums.Alignment,
	p_gender: CharacterEnums.Gender,
	p_stats: Dictionary
) -> Character:
	var character := Character.new()
	character.id = _generate_id()
	character.character_name = p_name
	character.race = p_race
	character.character_class = p_class
	character.alignment = p_alignment
	character.gender = p_gender
	character.age_days = (CharacterEnums.get_base_age(p_race) + CombatRNG.randi_range(0, 5)) * CharacterEnums.DAYS_PER_YEAR

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

	character.peak_strength = character.base_strength
	character.peak_intelligence = character.base_intelligence
	character.peak_piety = character.base_piety
	character.peak_vitality = character.base_vitality
	character.peak_agility = character.base_agility
	character.peak_luck = character.base_luck

	character.level = 1
	character.experience = 0
	character._recalculate_derived_stats()
	character.current_hp = character.max_hp
	character.current_mp = character.max_mp

	return character


## Rolls random stats for a character of the given race.
## [param p_race]: The race to roll stats for.
## [return]: Dictionary with rolled stat values.
static func roll_stats_for_race(p_race: CharacterEnums.Race) -> Dictionary:
	return {
		"strength": CharacterEnums.roll_stat(p_race, "strength"),
		"intelligence": CharacterEnums.roll_stat(p_race, "intelligence"),
		"piety": CharacterEnums.roll_stat(p_race, "piety"),
		"vitality": CharacterEnums.roll_stat(p_race, "vitality"),
		"agility": CharacterEnums.roll_stat(p_race, "agility"),
		"luck": CharacterEnums.roll_stat(p_race, "luck")
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
	var hp_base := ClassData.get_hp_base(character_class)
	var vit_bonus := (vitality - 10) / 2
	var equip_bonus := _get_equipment_hp_bonus()
	max_hp = maxi(1, (hp_base + vit_bonus) * level + equip_bonus)


func _calculate_max_mp() -> void:
	if not ClassData.can_use_magic(character_class):
		max_mp = 0
		return

	var mp_base := ClassData.get_mp_base(character_class)
	var class_data: Dictionary = ClassData.get_class_data(character_class)

	var stat_bonus := 0
	var schools: Array = class_data.get("spell_schools", [])

	if class_data.get("is_multiclass_caster", false):
		stat_bonus = (intelligence - 10) / 4 + (piety - 10) / 4
	elif CharacterEnums.SpellSchool.MAGE in schools or CharacterEnums.SpellSchool.ALCHEMIST in schools:
		stat_bonus = (intelligence - 10) / 4
	elif CharacterEnums.SpellSchool.PRIEST in schools:
		stat_bonus = (piety - 10) / 4
	elif CharacterEnums.SpellSchool.PSIONIC in schools:
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
	max_spell_level = ClassData.get_spell_level_at_character_level(character_class, level)


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


func _set_equipment_slot(slot_type: Item.ItemType, item: Item) -> Item:
	var property: String = SLOT_MAP.get(slot_type, "")
	if property == "":
		return null
	var old_item: Item = get(property)
	set(property, item)
	return old_item


## Checks if an item can be equipped by this character.
## [param item]: The item to check.
## [return]: True if the item can be equipped.
func can_equip_item(item: Item) -> bool:
	if not item.is_equipment():
		return false
	if not item.can_equip(self):
		return false
	if item.item_type == Item.ItemType.SHIELD and equipped_weapon and equipped_weapon.two_handed:
		return false
	return true


## Equips an item in its appropriate slot.
## [param item]: The item to equip.
## [return]: Previously equipped item in that slot, or null.
func equip_item(item: Item) -> Item:
	if not can_equip_item(item):
		return null

	if item.item_type == Item.ItemType.WEAPON and item.two_handed and equipped_shield:
		force_unequip_slot(Item.ItemType.SHIELD)

	var old_item := _set_equipment_slot(item.item_type, item)
	_recalculate_derived_stats()
	return old_item


## Unequips an item from a slot (fails for cursed items).
## [param slot_type]: The equipment slot to unequip.
## [return]: The unequipped item, or null if slot empty or item cursed.
func unequip_slot(slot_type: Item.ItemType) -> Item:
	var item := get_equipped_item(slot_type)
	if item and item.is_cursed:
		return null
	var old_item := _set_equipment_slot(slot_type, null)
	_recalculate_derived_stats()
	return old_item


func force_unequip_slot(slot_type: Item.ItemType) -> Item:
	var old_item := _set_equipment_slot(slot_type, null)
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
	var property: String = SLOT_MAP.get(slot_type, "")
	if property == "":
		return null
	return get(property)


func get_display_name() -> String:
	return character_name if character_name else id


func get_race_name() -> String:
	return CharacterEnums.get_race_name(race)


func get_class_name() -> String:
	return CharacterEnums.get_class_name(character_class)


func get_alignment_name() -> String:
	return CharacterEnums.get_alignment_name(alignment)


func get_age_years() -> int:
	return age_days / CharacterEnums.DAYS_PER_YEAR


func get_life_phase() -> CharacterEnums.LifePhase:
	return CharacterEnums.get_life_phase(race, age_days)


func get_life_phase_name() -> String:
	return CharacterEnums.get_life_phase_name(get_life_phase())


func apply_aging_effects() -> void:
	var phase: CharacterEnums.LifePhase = get_life_phase()

	if phase == CharacterEnums.LifePhase.YOUTH or phase == CharacterEnums.LifePhase.PRIME:
		strength = peak_strength
		intelligence = peak_intelligence
		piety = peak_piety
		vitality = peak_vitality
		agility = peak_agility
		luck = peak_luck
		return

	var physical_stats := ["strength", "vitality", "agility"]
	var mental_stats := ["intelligence", "piety"]
	var ranges: Dictionary = CharacterEnums.RACE_STAT_RANGES.get(race, {})

	if phase == CharacterEnums.LifePhase.DECLINE:
		var decline_start: int = CharacterEnums.get_decline_start_days(race)
		var fragile_start: int = CharacterEnums.get_fragile_start_days(race)
		var decline_duration: int = fragile_start - decline_start
		var progress: float = clampf(float(age_days - decline_start) / float(decline_duration), 0.0, 1.0)

		for stat_name in physical_stats:
			var peak_val: int = get("peak_" + stat_name)
			var penalty: int = roundi(peak_val * 0.4 * progress)
			var range_vec: Vector2i = ranges.get(stat_name, Vector2i(8, 18))
			var floor_val: int = maxi(roundi(range_vec.x * 0.3), 1)
			set(stat_name, maxi(peak_val - penalty, floor_val))

		var mental_progress: float = clampf((progress - 0.5) / 0.5, 0.0, 1.0)
		for stat_name in mental_stats:
			var peak_val: int = get("peak_" + stat_name)
			var penalty: int = roundi(peak_val * 0.2 * mental_progress)
			var range_vec: Vector2i = ranges.get(stat_name, Vector2i(8, 18))
			var floor_val: int = maxi(roundi(range_vec.x * 0.3), 1)
			set(stat_name, maxi(peak_val - penalty, floor_val))

	elif phase == CharacterEnums.LifePhase.FRAGILE:
		var decline_start: int = CharacterEnums.get_decline_start_days(race)
		var fragile_start: int = CharacterEnums.get_fragile_start_days(race)
		var max_age_days: int = CharacterEnums.get_max_age_days(race)
		var fragile_duration: int = max_age_days - fragile_start
		var fragile_progress: float = clampf(float(age_days - fragile_start) / float(fragile_duration), 0.0, 1.0) if fragile_duration > 0 else 1.0

		for stat_name in physical_stats:
			var peak_val: int = get("peak_" + stat_name)
			var decline_penalty: int = roundi(peak_val * 0.4)
			var fragile_penalty: int = roundi(peak_val * 0.3 * pow(fragile_progress, 1.5))
			var range_vec: Vector2i = ranges.get(stat_name, Vector2i(8, 18))
			var floor_val: int = maxi(roundi(range_vec.x * 0.3), 1)
			set(stat_name, maxi(peak_val - decline_penalty - fragile_penalty, floor_val))

		for stat_name in mental_stats:
			var peak_val: int = get("peak_" + stat_name)
			var decline_penalty: int = roundi(peak_val * 0.2)
			var fragile_penalty: int = roundi(peak_val * 0.2 * fragile_progress)
			var range_vec: Vector2i = ranges.get(stat_name, Vector2i(8, 18))
			var floor_val: int = maxi(roundi(range_vec.x * 0.3), 1)
			set(stat_name, maxi(peak_val - decline_penalty - fragile_penalty, floor_val))

	luck = peak_luck


func advance_age(days: int) -> void:
	age_days += days
	apply_aging_effects()
	_recalculate_derived_stats()


func check_old_age_death() -> bool:
	if get_life_phase() != CharacterEnums.LifePhase.FRAGILE:
		return false
	if is_dead:
		return false
	var fragile_start: int = CharacterEnums.get_fragile_start_days(race)
	var max_age_days: int = CharacterEnums.get_max_age_days(race)
	var fragile_duration: int = max_age_days - fragile_start
	var progress: float = clampf(float(age_days - fragile_start) / float(fragile_duration), 0.0, 1.0) if fragile_duration > 0 else 1.0
	var death_chance: float = 0.8 * progress * progress
	if CombatRNG.randf() < death_chance:
		_die()
		return true
	return false


var breath_used: bool = false


func init_combat() -> void:
	if current_hp <= 0 and not is_dead:
		current_hp = max_hp
	is_defending = false
	breath_used = false
	_recalculate_derived_stats()


func can_use_breath() -> bool:
	return race == CharacterEnums.Race.DRACON and not breath_used and not is_dead


func get_breath_damage() -> int:
	return maxi(1, current_hp / 2)


func is_breath_aoe() -> bool:
	return level >= 9


## Applies damage to the character, potentially killing them.
## [param amount]: Raw damage before defense/defending reduction.
## [return]: Actual damage dealt after reductions.
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


## Heals the character (no effect if dead).
## [param amount]: HP to restore.
## [return]: Actual HP restored (capped at max).
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


func add_mark(mark: Dictionary) -> void:
	marks.append(mark)


func get_marks() -> Array[Dictionary]:
	return marks


func get_major_marks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mark in marks:
		if mark.get("severity") == Marks.Severity.MAJOR:
			result.append(mark)
	return result


func count_marks_by_theme(theme: String) -> int:
	var count := 0
	for mark in marks:
		var tags: Array = mark.get("theme_tags", [])
		if tags.has(theme):
			count += 1
	return count


func has_mark_named(mark_name: String) -> bool:
	for mark in marks:
		if mark.get("name") == mark_name:
			return true
	return false


func is_trait_crystallized(axis: Personality.Axis) -> bool:
	return traits.has(axis)


func get_active_trait(axis: Personality.Axis) -> int:
	if traits.has(axis):
		return traits[axis]
	return tendencies.get(axis, -1)


func get_personality_summary() -> String:
	if tendencies.is_empty():
		return ""
	var parts: Array[String] = []
	for axis: int in Personality.Axis.values():
		var option: int = get_active_trait(axis as Personality.Axis)
		if option < 0:
			continue
		var trait_name: String = Personality.get_option_name(axis as Personality.Axis, option)
		if is_trait_crystallized(axis as Personality.Axis):
			parts.append(trait_name)
		else:
			parts.append(trait_name + " (tendency)")
	return ", ".join(parts)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	MarkSystem.add_ko_mark(self)
	add_status(CharacterEnums.StatusEffect.DEAD, -1, "", 0)
	died.emit()


## Resurrects a dead character, restoring them to life with reduced vitality.
## [param vitality_loss]: Amount of vitality to permanently lose.
## [return]: True if resurrection succeeded.
func resurrect(vitality_loss: int = 1) -> bool:
	if not is_dead:
		return false

	if has_status(CharacterEnums.StatusEffect.LOST):
		return false

	peak_vitality = maxi(1, peak_vitality - vitality_loss)
	age_days += CombatRNG.randi_range(1, 5) * CharacterEnums.DAYS_PER_YEAR
	is_dead = false
	remove_status(CharacterEnums.StatusEffect.DEAD)
	remove_status(CharacterEnums.StatusEffect.ASHED)

	apply_aging_effects()
	_recalculate_derived_stats()
	current_hp = maxi(1, int(max_hp * CombatConstants.RESURRECTION_HP_FRACTION))

	revived.emit()
	return true


## Adds experience points and checks for level up eligibility.
## [param amount]: XP to add.
func add_experience(amount: int) -> void:
	if is_dead or level >= ExperienceTable.MAX_LEVEL:
		return

	experience += amount

	var required := ExperienceTable.get_required_xp(level + 1, race, character_class)
	if experience >= required and not pending_level_up:
		pending_level_up = true
		level_up_pending.emit()


## Confirms a pending level up, increasing stats and potentially learning spells.
## [return]: True if level up was processed.
func confirm_level_up() -> bool:
	if not pending_level_up or level >= ExperienceTable.MAX_LEVEL:
		return false

	var old_max_hp := max_hp
	var old_max_mp := max_mp

	level += 1
	pending_level_up = false

	if CombatRNG.randf() < CombatConstants.STAT_GAIN_CHANCE:
		_gain_random_stat()

	apply_aging_effects()
	_recalculate_derived_stats()

	var hp_gain := max_hp - old_max_hp
	var mp_gain := max_mp - old_max_mp
	current_hp += hp_gain
	current_mp += mp_gain

	var learned_spells := SpellLearning.try_learn_spells_on_level_up(self)
	if not learned_spells.is_empty():
		spells_learned.emit(learned_spells)

	var next_required := ExperienceTable.get_required_xp(level + 1, race, character_class)
	if experience >= next_required and level < ExperienceTable.MAX_LEVEL:
		pending_level_up = true
		level_up_pending.emit()

	level_up_completed.emit(level)
	return true


func _gain_random_stat() -> void:
	var stats := ["strength", "intelligence", "piety", "vitality", "agility", "luck"]
	var chosen: String = stats[CombatRNG.randi() % stats.size()]
	var peak_key: String = "peak_" + chosen
	set(peak_key, mini(get(peak_key) + 1, CombatConstants.MAX_STAT_VALUE))


func get_xp_to_next_level() -> int:
	return ExperienceTable.get_xp_to_next_level(experience, level, race, character_class)


func get_xp_progress_percent() -> float:
	if level >= ExperienceTable.MAX_LEVEL:
		return 100.0

	var current_req := ExperienceTable.get_required_xp(level, race, character_class)
	var next_req := ExperienceTable.get_required_xp(level + 1, race, character_class)
	var range_xp := next_req - current_req

	if range_xp <= 0:
		return 100.0

	var progress := experience - current_req
	return clampf(float(progress) / float(range_xp) * 100.0, 0.0, 100.0)


func has_status(effect: CharacterEnums.StatusEffect) -> bool:
	return status_effects.has(effect)


## Adds a status effect to the character.
## [param effect]: The status effect to add.
## [param duration]: Turns until expiry (-1 for permanent).
## [param source]: Source identifier for tracking.
## [param power]: Effect strength for certain statuses.
## [return]: True if the status was applied, false if already present.
func add_status(effect: CharacterEnums.StatusEffect, duration: int = -1, source: String = "", power: int = 0) -> bool:
	if has_status(effect):
		return false

	var exclusive_group := CharacterEnums.get_exclusive_group(effect)
	for existing in exclusive_group:
		if existing != effect and has_status(existing):
			remove_status(existing)

	status_effects.append(effect)
	active_statuses.append(ActiveStatus.new(effect, duration, source, power))
	status_applied.emit(effect)
	return true


func remove_status(effect: CharacterEnums.StatusEffect) -> void:
	status_effects.erase(effect)
	for i in range(active_statuses.size() - 1, -1, -1):
		if active_statuses[i].type == effect:
			active_statuses.remove_at(i)
			break
	status_removed.emit(effect)


func get_active_status(effect: CharacterEnums.StatusEffect) -> ActiveStatus:
	for active in active_statuses:
		if active.type == effect:
			return active
	return null


func get_status_duration(effect: CharacterEnums.StatusEffect) -> int:
	var active := get_active_status(effect)
	return active.duration if active else 0


func clear_status_effects() -> void:
	status_effects.clear()
	active_statuses.clear()
	if is_dead:
		status_effects.append(CharacterEnums.StatusEffect.DEAD)
		active_statuses.append(ActiveStatus.new(CharacterEnums.StatusEffect.DEAD, -1, "", 0))


func is_disabled() -> bool:
	return has_status(CharacterEnums.StatusEffect.ASLEEP) or \
		   has_status(CharacterEnums.StatusEffect.PARALYZED) or \
		   has_status(CharacterEnums.StatusEffect.STONED)


func is_silenced() -> bool:
	return has_status(CharacterEnums.StatusEffect.SILENCED)


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


func is_available() -> bool:
	return availability == AVAILABILITY_AVAILABLE


func is_training() -> bool:
	return availability == AVAILABILITY_TRAINING


func start_training(target_class: int, days: int, current_day: int) -> void:
	availability = AVAILABILITY_TRAINING
	available_on_day = current_day + days
	training_days_total = days
	training_target_class = target_class
	town_job = -1


func complete_training() -> void:
	if training_target_class < 0:
		availability = AVAILABILITY_AVAILABLE
		return
	character_class = training_target_class as CharacterEnums.CharacterClass
	level = 1
	experience = 0
	pending_level_up = false
	apply_aging_effects()
	_recalculate_derived_stats()
	current_hp = max_hp
	current_mp = max_mp
	var learnable := SpellLearning.get_learnable_spells(self)
	known_spells.clear()
	for spell in learnable:
		known_spells.append(spell.id)
	availability = AVAILABILITY_AVAILABLE
	training_target_class = -1
	training_days_total = 0
	available_on_day = 0


func get_training_days_elapsed(current_day: int) -> int:
	var total := get_training_total()
	if total <= 0:
		return 0
	var start_day := available_on_day - total
	return clampi(current_day - start_day, 0, total)


func get_training_total() -> int:
	if training_days_total > 0:
		return training_days_total
	if availability == AVAILABILITY_TRAINING and training_target_class >= 0:
		return ClassData.get_training_days(character_class, training_target_class as CharacterEnums.CharacterClass)
	return 0


func tick_availability(current_day: int) -> bool:
	if availability == AVAILABILITY_TRAINING and current_day >= available_on_day:
		complete_training()
		return true
	return false


func calculate_rest_bonus() -> void:
	if town_days_accumulated > 0:
		rest_bonus_xp_multiplier = minf(REST_BONUS_MAX, rest_bonus_xp_multiplier + town_days_accumulated * REST_BONUS_PER_TOWN_DAY)


func decay_rest_bonus() -> void:
	rest_bonus_xp_multiplier = maxf(1.0, rest_bonus_xp_multiplier - REST_BONUS_DECAY_PER_ENCOUNTER)


func get_xp_multiplier() -> float:
	return rest_bonus_xp_multiplier
