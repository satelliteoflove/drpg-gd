class_name TrapDatabase
extends RefCounted

const TrapClass = preload("res://resources/trap.gd")
const CharEnum = preload("res://resources/character_enums.gd")

static var _traps: Dictionary = {}
static var _initialized: bool = false


static func _initialize() -> void:
	if _initialized:
		return
	_initialized = true

	_traps["poison_needle"] = TrapClass.create(
		"poison_needle",
		"Poison Needle",
		"1d4",
		TrapClass.DamageTarget.OPENER,
		CharEnum.StatusEffect.POISONED,
		5
	)

	_traps["falling_rock"] = TrapClass.create(
		"falling_rock",
		"Falling Rock",
		"2d6",
		TrapClass.DamageTarget.OPENER
	)

	_traps["gas_trap"] = TrapClass.create(
		"gas_trap",
		"Gas Trap",
		"1d4",
		TrapClass.DamageTarget.PARTY,
		CharEnum.StatusEffect.POISONED,
		5
	)

	_traps["explosive"] = TrapClass.create(
		"explosive",
		"Explosive",
		"3d6",
		TrapClass.DamageTarget.FRONT_ROW
	)

	_traps["alarm"] = TrapClass.create(
		"alarm",
		"Alarm",
		"",
		TrapClass.DamageTarget.OPENER,
		CharEnum.StatusEffect.NONE,
		0,
		true
	)


static func get_trap(trap_id: String) -> TrapClass:
	_initialize()
	return _traps.get(trap_id)


static func get_random_trap() -> TrapClass:
	_initialize()
	var trap_ids := _traps.keys()
	var random_id: String = trap_ids[randi() % trap_ids.size()]
	return _traps[random_id].duplicate()


static func get_random_trap_excluding_alarm() -> TrapClass:
	_initialize()
	var trap_ids := _traps.keys()
	trap_ids.erase("alarm")
	var random_id: String = trap_ids[randi() % trap_ids.size()]
	return _traps[random_id].duplicate()


static func get_all_trap_ids() -> Array:
	_initialize()
	return _traps.keys()
