class_name TrapDatabase
extends RefCounted

static var _traps: Dictionary = {}
static var _initialized: bool = false


static func _initialize() -> void:
	if _initialized:
		return
	_initialized = true

	_traps["poison_needle"] = Trap.create(
		"poison_needle",
		"Poison Needle",
		"1d4",
		Trap.DamageTarget.OPENER,
		CharacterEnums.StatusEffect.POISONED,
		5
	)

	_traps["falling_rock"] = Trap.create(
		"falling_rock",
		"Falling Rock",
		"2d6",
		Trap.DamageTarget.OPENER
	)

	_traps["gas_trap"] = Trap.create(
		"gas_trap",
		"Gas Trap",
		"1d4",
		Trap.DamageTarget.PARTY,
		CharacterEnums.StatusEffect.POISONED,
		5
	)

	_traps["explosive"] = Trap.create(
		"explosive",
		"Explosive",
		"3d6",
		Trap.DamageTarget.FRONT_ROW
	)

	_traps["alarm"] = Trap.create(
		"alarm",
		"Alarm",
		"",
		Trap.DamageTarget.OPENER,
		CharacterEnums.StatusEffect.NONE,
		0,
		true
	)


static func get_trap(trap_id: String) -> Trap:
	_initialize()
	return _traps.get(trap_id)


static func get_random_trap() -> Trap:
	_initialize()
	var trap_ids := _traps.keys()
	var random_id: String = trap_ids[randi() % trap_ids.size()]
	return _traps[random_id].duplicate()


static func get_random_trap_excluding_alarm() -> Trap:
	_initialize()
	var trap_ids := _traps.keys()
	trap_ids.erase("alarm")
	var random_id: String = trap_ids[randi() % trap_ids.size()]
	return _traps[random_id].duplicate()


static func get_all_trap_ids() -> Array:
	_initialize()
	return _traps.keys()
