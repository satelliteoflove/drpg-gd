class_name MetricsCollector
extends RefCounted

var damage_dealt: Dictionary = {}
var damage_taken: Dictionary = {}
var physical_damage_dealt: Dictionary = {}
var spell_damage_dealt: Dictionary = {}
var healing_done: Dictionary = {}
var spells_cast: Dictionary = {}
var status_effects_applied: Dictionary = {}
var deaths: Array[Dictionary] = []
var turn_count: int = 0
var attacks_hit: Dictionary = {}
var attacks_missed: Dictionary = {}
var dispels_attempted: Dictionary = {}
var dispels_succeeded: Dictionary = {}
var dispel_kills: Array[Dictionary] = []
var xp_from_dispels: int = 0
var xp_lost_to_dispels: int = 0
var xp_from_kills: int = 0
var total_xp_earned: int = 0
var mp_spent: Dictionary = {}
var total_mp_spent: int = 0
var starting_party_hp: int = 0
var ending_party_hp: int = 0
var starting_party_mp: int = 0
var ending_party_mp: int = 0


func record_damage(source: String, target: String, amount: int, is_spell: bool = false) -> void:
	if not damage_dealt.has(source):
		damage_dealt[source] = 0
	damage_dealt[source] += amount

	if not damage_taken.has(target):
		damage_taken[target] = 0
	damage_taken[target] += amount

	if is_spell:
		if not spell_damage_dealt.has(source):
			spell_damage_dealt[source] = 0
		spell_damage_dealt[source] += amount
	else:
		if not physical_damage_dealt.has(source):
			physical_damage_dealt[source] = 0
		physical_damage_dealt[source] += amount


func record_healing(source: String, _target: String, amount: int) -> void:
	if not healing_done.has(source):
		healing_done[source] = 0
	healing_done[source] += amount


func record_spell(caster: String, spell_id: String, mp_cost: int = 0) -> void:
	if not spells_cast.has(caster):
		spells_cast[caster] = {}
	if not spells_cast[caster].has(spell_id):
		spells_cast[caster][spell_id] = 0
	spells_cast[caster][spell_id] += 1

	if mp_cost > 0:
		if not mp_spent.has(caster):
			mp_spent[caster] = 0
		mp_spent[caster] += mp_cost
		total_mp_spent += mp_cost


func record_party_state_start(party_hp: int, party_mp: int) -> void:
	starting_party_hp = party_hp
	starting_party_mp = party_mp


func record_party_state_end(party_hp: int, party_mp: int) -> void:
	ending_party_hp = party_hp
	ending_party_mp = party_mp


func get_hp_lost() -> int:
	return maxi(0, starting_party_hp - ending_party_hp)


func get_mp_used() -> int:
	return maxi(0, starting_party_mp - ending_party_mp)


func record_status(source: String, target: String, status: int) -> void:
	var key := "%s->%s" % [source, target]
	if not status_effects_applied.has(key):
		status_effects_applied[key] = []
	status_effects_applied[key].append(status)


func record_death(name: String, turn: int) -> void:
	deaths.append({"name": name, "turn": turn})


func record_attack(attacker: String, hit: bool) -> void:
	if hit:
		if not attacks_hit.has(attacker):
			attacks_hit[attacker] = 0
		attacks_hit[attacker] += 1
	else:
		if not attacks_missed.has(attacker):
			attacks_missed[attacker] = 0
		attacks_missed[attacker] += 1


func record_dispel(caster: String, success: bool) -> void:
	if not dispels_attempted.has(caster):
		dispels_attempted[caster] = 0
	dispels_attempted[caster] += 1

	if success:
		if not dispels_succeeded.has(caster):
			dispels_succeeded[caster] = 0
		dispels_succeeded[caster] += 1


func record_dispel_kill(target_name: String, xp_gained: int, xp_lost: int) -> void:
	dispel_kills.append({"name": target_name, "xp_gained": xp_gained, "xp_lost": xp_lost})
	xp_from_dispels += xp_gained
	xp_lost_to_dispels += xp_lost
	total_xp_earned += xp_gained


func record_kill_xp(xp: int) -> void:
	xp_from_kills += xp
	total_xp_earned += xp


func get_dispel_rate(caster: String) -> float:
	var attempts: int = dispels_attempted.get(caster, 0)
	var successes: int = dispels_succeeded.get(caster, 0)
	if attempts == 0:
		return 0.0
	return float(successes) / float(attempts)


func get_hit_rate(attacker: String) -> float:
	var hits: int = attacks_hit.get(attacker, 0)
	var misses: int = attacks_missed.get(attacker, 0)
	var total := hits + misses
	if total == 0:
		return 0.0
	return float(hits) / float(total)


func get_total_hit_rate() -> float:
	var total_hits := 0
	var total_misses := 0
	for attacker in attacks_hit:
		total_hits += attacks_hit[attacker]
	for attacker in attacks_missed:
		total_misses += attacks_missed[attacker]
	var total := total_hits + total_misses
	if total == 0:
		return 0.0
	return float(total_hits) / float(total)


func increment_turn() -> void:
	turn_count += 1


func get_total_damage_dealt() -> int:
	var total := 0
	for actor in damage_dealt:
		total += damage_dealt[actor]
	return total


func get_total_physical_damage() -> int:
	var total := 0
	for actor in physical_damage_dealt:
		total += physical_damage_dealt[actor]
	return total


func get_total_spell_damage() -> int:
	var total := 0
	for actor in spell_damage_dealt:
		total += spell_damage_dealt[actor]
	return total


func get_total_healing_done() -> int:
	var total := 0
	for actor in healing_done:
		total += healing_done[actor]
	return total


func get_top_damage_dealer() -> String:
	var top_name := ""
	var top_damage := 0
	for actor in damage_dealt:
		if damage_dealt[actor] > top_damage:
			top_damage = damage_dealt[actor]
			top_name = actor
	return top_name


func get_first_death() -> Dictionary:
	if deaths.is_empty():
		return {}
	var earliest: Dictionary = deaths[0]
	for death in deaths:
		if death.turn < earliest.turn:
			earliest = death
	return earliest


func to_dict() -> Dictionary:
	return {
		"turn_count": turn_count,
		"damage_dealt": damage_dealt.duplicate(),
		"damage_taken": damage_taken.duplicate(),
		"physical_damage_dealt": physical_damage_dealt.duplicate(),
		"spell_damage_dealt": spell_damage_dealt.duplicate(),
		"total_physical_damage": get_total_physical_damage(),
		"total_spell_damage": get_total_spell_damage(),
		"healing_done": healing_done.duplicate(),
		"spells_cast": spells_cast.duplicate(true),
		"status_effects_applied": status_effects_applied.duplicate(true),
		"deaths": deaths.duplicate(),
		"total_damage": get_total_damage_dealt(),
		"total_healing": get_total_healing_done(),
		"top_damage_dealer": get_top_damage_dealer(),
		"attacks_hit": attacks_hit.duplicate(),
		"attacks_missed": attacks_missed.duplicate(),
		"total_hit_rate": get_total_hit_rate(),
		"dispels_attempted": dispels_attempted.duplicate(),
		"dispels_succeeded": dispels_succeeded.duplicate(),
		"dispel_kills": dispel_kills.duplicate(),
		"xp_from_dispels": xp_from_dispels,
		"xp_lost_to_dispels": xp_lost_to_dispels,
		"xp_from_kills": xp_from_kills,
		"total_xp_earned": total_xp_earned,
		"mp_spent": mp_spent.duplicate(),
		"total_mp_spent": total_mp_spent,
		"starting_party_hp": starting_party_hp,
		"ending_party_hp": ending_party_hp,
		"starting_party_mp": starting_party_mp,
		"ending_party_mp": ending_party_mp,
		"hp_lost": get_hp_lost(),
		"mp_used": get_mp_used()
	}


func clear() -> void:
	damage_dealt.clear()
	damage_taken.clear()
	physical_damage_dealt.clear()
	spell_damage_dealt.clear()
	healing_done.clear()
	spells_cast.clear()
	status_effects_applied.clear()
	deaths.clear()
	attacks_hit.clear()
	attacks_missed.clear()
	dispels_attempted.clear()
	dispels_succeeded.clear()
	dispel_kills.clear()
	xp_from_dispels = 0
	xp_lost_to_dispels = 0
	xp_from_kills = 0
	total_xp_earned = 0
	turn_count = 0
	mp_spent.clear()
	total_mp_spent = 0
	starting_party_hp = 0
	ending_party_hp = 0
	starting_party_mp = 0
	ending_party_mp = 0
