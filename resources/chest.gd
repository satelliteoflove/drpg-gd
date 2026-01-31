class_name Chest
extends Resource

enum ChestType {
	PLAIN,
	ORNATE
}

@export var chest_type: ChestType = ChestType.PLAIN
@export var contents: Array[Item] = []
@export var trap: Trap = null
@export var is_trapped: bool = false
@export var trap_identified: bool = false
@export var trap_disarmed: bool = false


static func create(p_type: ChestType, p_contents: Array[Item], p_trap: Trap = null) -> Chest:
	var chest := Chest.new()
	chest.chest_type = p_type
	chest.contents = p_contents
	chest.trap = p_trap
	chest.is_trapped = (p_trap != null)
	return chest


func get_type_name() -> String:
	match chest_type:
		ChestType.PLAIN:
			return "small chest"
		ChestType.ORNATE:
			return "ornate chest"
	return "chest"


func can_quick_open() -> bool:
	return chest_type == ChestType.PLAIN and (not is_trapped or trap_disarmed)


func is_safe_to_open() -> bool:
	return not is_trapped or trap_disarmed
