class_name CombatNotes
extends RefCounted

## Extra combat-log lines raised deep inside a calculation (a critical hit,
## an elder's intercession) where there's no signal to emit on. The combat
## and chest screens flush these after each message they show.
##
## Only the guild's own party adds notes, so simulator fights don't leak
## lines into the next real battle.

static var _pending: Array[String] = []


static func add(message: String) -> void:
	_pending.append(message)


static func take() -> Array[String]:
	var out := _pending.duplicate()
	_pending.clear()
	return out


static func clear() -> void:
	_pending.clear()
