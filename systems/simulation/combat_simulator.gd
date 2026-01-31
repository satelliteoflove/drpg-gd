class_name CombatSimulator
extends RefCounted

signal turn_completed(turn_data: Dictionary)
signal combat_completed(result: Dictionary)

var party: Party = null
var enemies: Array[Monster] = []
var rng_seed: int = 0
var max_turns: int = 100
var ai_log: AIDecisionLog = null
var metrics: MetricsCollector = null
var party_strategy: PartyAI.Strategy = PartyAI.Strategy.BALANCED
var cast_threshold: float = PartyAI.DEFAULT_CAST_THRESHOLD

var _initiative: InitiativeTracker = null
var _current_turn: int = 0
var _combat_active: bool = false


func setup(p_party: Party, p_enemies: Array[Monster], seed_value: int) -> void:
	party = p_party
	rng_seed = seed_value
	CombatRNG.set_seed(seed_value)

	enemies = []
	for enemy in p_enemies:
		var combat_enemy := enemy.duplicate_for_combat()
		enemies.append(combat_enemy)

	ai_log = AIDecisionLog.new()
	metrics = MetricsCollector.new()
	_initiative = InitiativeTracker.new()
	_current_turn = 0
	_combat_active = true

	for character in party.get_members():
		if not character.is_dead:
			character.init_combat()
			_initiative.add_combatant(character.id, true, character.agility)

	for enemy in enemies:
		_initiative.add_combatant(enemy.combat_id, false, enemy.agility)

	metrics.record_party_state_start(_get_total_party_hp(), _get_total_party_mp())


func run() -> Dictionary:
	while _combat_active and _current_turn < max_turns:
		var _turn_result := step()
		if not _combat_active:
			break

	metrics.record_party_state_end(_get_total_party_hp(), _get_total_party_mp())
	return _build_result()


func _get_total_party_hp() -> int:
	var total := 0
	for member in party.get_members():
		if not member.is_dead:
			total += member.current_hp
	return total


func _get_total_party_mp() -> int:
	var total := 0
	for member in party.get_members():
		if not member.is_dead:
			total += member.current_mp
	return total


func step() -> Dictionary:
	if not _combat_active:
		return {}

	var entry := _initiative.get_next_combatant()
	if entry == null:
		_combat_active = false
		return {}

	_current_turn += 1
	metrics.increment_turn()

	var turn_data: Dictionary

	if entry.is_player:
		turn_data = _execute_player_turn(entry.id)
	else:
		turn_data = _execute_monster_turn(entry.id)

	_initiative.apply_action_delay(entry.id)
	_check_combat_end()

	turn_completed.emit(turn_data)
	return turn_data


func _execute_player_turn(character_id: String) -> Dictionary:
	var character := _get_character(character_id)
	if character == null or character.is_dead:
		return {"skipped": true, "reason": "dead"}

	var tick_messages := StatusEffectSystem.tick_effects(character, "combat")

	if character.is_dead:
		_initiative.remove_combatant(character_id)
		metrics.record_death(character.get_display_name(), _current_turn)
		return {"skipped": true, "reason": "died from status", "messages": tick_messages}

	if StatusEffectSystem.is_disabled(character):
		return {"skipped": true, "reason": "disabled", "messages": tick_messages}

	if StatusEffectSystem.may_skip_turn_from_fear(character):
		return {"skipped": true, "reason": "afraid", "messages": tick_messages}

	var decision := PartyAI.decide_action(character, party, enemies, party_strategy, cast_threshold)

	ai_log.log_decision(_current_turn, character.get_display_name(), decision)

	var result := _execute_party_action(character, decision)
	result["turn"] = _current_turn
	result["actor"] = character.get_display_name()
	result["is_player"] = true
	result["tick_messages"] = tick_messages

	return result


func _execute_monster_turn(monster_id: String) -> Dictionary:
	var monster := _get_enemy_by_combat_id(monster_id)
	if monster == null or monster.is_dead:
		return {"skipped": true, "reason": "dead"}

	if StatusEffectSystem.is_disabled(monster):
		return {"skipped": true, "reason": "disabled"}

	var decision := MonsterAI.decide_action(monster, party, enemies, ai_log)

	var decision_dict := {
		"action": _action_type_to_string(decision.action_type),
		"target": _get_decision_target_name(decision),
		"spell": decision.spell_id,
		"reasoning": "AI behavior"
	}
	ai_log.log_decision(_current_turn, monster.monster_name, decision_dict)

	var result := _execute_monster_action(monster, decision)
	result["turn"] = _current_turn
	result["actor"] = monster.monster_name
	result["is_player"] = false

	return result


func _execute_party_action(character: Character, decision: Dictionary) -> Dictionary:
	var action: String = decision.get("action", "defend")
	var target = decision.get("target")
	var spell_id: String = decision.get("spell_id", "")

	match action:
		"attack":
			return _execute_character_attack(character, target)
		"spell":
			return _execute_character_spell(character, spell_id, target)
		"dispel":
			return _execute_dispel(character, target)
		"defend":
			character.is_defending = true
			return {"action": "defend"}
		_:
			return {"action": "skip"}


func _execute_character_attack(attacker: Character, target: Monster) -> Dictionary:
	if target == null or target.is_dead:
		return {"action": "attack", "hit": false, "reason": "no target"}

	var accuracy_mod := StatusEffectSystem.get_accuracy_modifier(attacker)
	var result := DamageCalculator.calculate_character_attack(attacker, target, accuracy_mod)
	metrics.record_attack(attacker.get_display_name(), result.hit)

	if result.hit:
		var damage: int = result.damage
		var sleep_mult := StatusEffectSystem.get_damage_multiplier_for_sleeping(target)
		if sleep_mult > 1.0:
			damage = int(damage * sleep_mult)

		var actual := target.take_damage(damage)
		metrics.record_damage(attacker.get_display_name(), target.monster_name, actual)

		if target.is_dead:
			_initiative.remove_combatant(target.combat_id)
			metrics.record_death(target.monster_name, _current_turn)
			metrics.record_kill_xp(target.exp_reward)

		return {
			"action": "attack",
			"hit": true,
			"damage": actual,
			"target": target.monster_name,
			"target_killed": target.is_dead
		}
	else:
		return {"action": "attack", "hit": false, "target": target.monster_name}


func _execute_character_spell(caster: Character, spell_id: String, target) -> Dictionary:
	var spell := SpellDatabase.get_spell(spell_id)
	if spell == null:
		return {"action": "spell", "success": false, "reason": "unknown spell"}

	var targets: Array = []
	if target is Array:
		targets = target
	elif target != null:
		targets = [target]
	else:
		targets = _get_default_spell_targets(spell)

	var result := SpellCaster.cast_spell(caster, spell, targets, true)
	metrics.record_spell(caster.get_display_name(), spell_id, spell.mp_cost)

	if result.total_damage > 0:
		for t in targets:
			if t is Monster:
				metrics.record_damage(caster.get_display_name(), t.monster_name, result.total_damage / targets.size(), true)
	if result.total_healing > 0:
		for t in targets:
			if t is Character:
				metrics.record_healing(caster.get_display_name(), t.get_display_name(), result.total_healing / targets.size())

	for t in targets:
		if t is Monster and t.is_dead:
			_initiative.remove_combatant(t.combat_id)
			metrics.record_death(t.monster_name, _current_turn)
			metrics.record_kill_xp(t.exp_reward)
		elif t is Character and t.is_dead:
			_initiative.remove_combatant(t.id)
			metrics.record_death(t.get_display_name(), _current_turn)

	return {
		"action": "spell",
		"spell_id": spell_id,
		"success": result.success,
		"fizzled": result.fizzled,
		"damage": result.total_damage,
		"healing": result.total_healing,
		"messages": result.messages
	}


func _execute_dispel(character: Character, target: Monster) -> Dictionary:
	if target == null:
		return {"action": "dispel", "success": false, "reason": "no target"}

	var result := DispelUndead.attempt_dispel(character, target)
	metrics.record_dispel(character.get_display_name(), result.success)

	if result.success:
		_initiative.remove_combatant(target.combat_id)
		metrics.record_dispel_kill(target.monster_name, result.xp_gained, result.xp_lost)

	return {
		"action": "dispel",
		"success": result.success,
		"target": result.get("target", ""),
		"xp_gained": result.get("xp_gained", 0),
		"message": result.message
	}


func _execute_monster_action(monster: Monster, decision: MonsterAI.AIDecision) -> Dictionary:
	match decision.action_type:
		MonsterAI.ActionType.DEFEND:
			monster.is_defending = true
			return {"action": "defend"}
		MonsterAI.ActionType.SPELL:
			return _execute_monster_spell(monster, decision.spell_id, decision.targets)
		MonsterAI.ActionType.ATTACK:
			return _execute_monster_attack(monster, decision.attack, decision.targets)
		_:
			return {"action": "unknown"}


func _execute_monster_attack(monster: Monster, attack: MonsterAttack, targets: Array) -> Dictionary:
	if attack == null or targets.is_empty():
		return {"action": "attack", "hit": false, "reason": "no attack/target"}

	var total_damage := 0
	var hits: Array[String] = []
	var misses: Array[String] = []

	for target in targets:
		if target == null or not target is Character:
			continue
		if target.is_dead:
			continue

		var char_target: Character = target as Character
		var evasion_mod := StatusEffectSystem.get_evasion_modifier(char_target)
		var result := DamageCalculator.calculate_monster_attack(monster, attack, char_target, evasion_mod)
		metrics.record_attack(monster.monster_name, result.hit)

		if result.hit:
			var damage: int = result.damage
			var sleep_mult := StatusEffectSystem.get_damage_multiplier_for_sleeping(char_target)
			if sleep_mult > 1.0:
				damage = int(damage * sleep_mult)

			var actual := char_target.take_damage(damage)
			total_damage += actual
			metrics.record_damage(monster.monster_name, char_target.get_display_name(), actual)
			hits.append(char_target.get_display_name())

			if char_target.is_dead:
				_initiative.remove_combatant(char_target.id)
				metrics.record_death(char_target.get_display_name(), _current_turn)
		else:
			misses.append(char_target.get_display_name())

	return {
		"action": "attack",
		"attack_name": attack.attack_name,
		"damage": total_damage,
		"hits": hits,
		"misses": misses
	}


func _execute_monster_spell(monster: Monster, spell_id: String, targets: Array) -> Dictionary:
	var spell := SpellDatabase.get_spell(spell_id)
	if spell == null or monster.current_mp < spell.mp_cost:
		return {"action": "spell", "success": false, "reason": "cannot cast"}

	var result := SpellCaster.cast_spell_by_monster(monster, spell, targets)
	metrics.record_spell(monster.monster_name, spell_id, spell.mp_cost)

	for t in targets:
		if t is Character and t.is_dead:
			_initiative.remove_combatant(t.id)
			metrics.record_death(t.get_display_name(), _current_turn)

	return {
		"action": "spell",
		"spell_id": spell_id,
		"success": result.success,
		"damage": result.total_damage,
		"healing": result.total_healing,
		"messages": result.messages
	}


func _get_default_spell_targets(spell: Spell) -> Array:
	match spell.target_type:
		CharacterEnums.SpellTargetType.ALL_ENEMIES:
			var targets: Array = []
			for enemy in enemies:
				if not enemy.is_dead:
					targets.append(enemy)
			return targets
		CharacterEnums.SpellTargetType.ALL_ALLIES:
			var targets: Array = []
			for member in party.get_alive_members():
				targets.append(member)
			return targets
		CharacterEnums.SpellTargetType.SINGLE_ENEMY:
			for enemy in enemies:
				if not enemy.is_dead:
					return [enemy]
		CharacterEnums.SpellTargetType.SINGLE_ALLY:
			var members := party.get_alive_members()
			if not members.is_empty():
				return [members[0]]
	return []


func _check_combat_end() -> void:
	if _all_enemies_dead() or _all_party_dead():
		_combat_active = false
		var result := _build_result()
		combat_completed.emit(result)


func _all_enemies_dead() -> bool:
	for enemy in enemies:
		if not enemy.is_dead:
			return false
	return true


func _all_party_dead() -> bool:
	for character in party.get_members():
		if not character.is_dead:
			return false
	return true


func _build_result() -> Dictionary:
	var victory := _all_enemies_dead()
	var party_survivors: Array[String] = []
	var party_hp_remaining := 0
	var party_hp_total := 0

	for member in party.get_members():
		party_hp_total += member.max_hp
		if not member.is_dead:
			party_survivors.append(member.get_display_name())
			party_hp_remaining += member.current_hp

	return {
		"seed": rng_seed,
		"result": "victory" if victory else "defeat",
		"victory": victory,
		"turns": _current_turn,
		"party_survivors": party_survivors,
		"party_hp_remaining": party_hp_remaining,
		"party_hp_percent": float(party_hp_remaining) / float(maxi(1, party_hp_total)) * 100.0,
		"metrics": metrics.to_dict(),
		"ai_log": ai_log.to_array()
	}


func _get_character(id: String) -> Character:
	for character in party.get_members():
		if character.id == id:
			return character
	return null


func _get_enemy_by_combat_id(combat_id: String) -> Monster:
	for enemy in enemies:
		if enemy.combat_id == combat_id:
			return enemy
	return null


func _action_type_to_string(action_type: MonsterAI.ActionType) -> String:
	match action_type:
		MonsterAI.ActionType.ATTACK: return "attack"
		MonsterAI.ActionType.SPELL: return "spell"
		MonsterAI.ActionType.DEFEND: return "defend"
		MonsterAI.ActionType.FLEE: return "flee"
	return "unknown"


func _get_decision_target_name(decision: MonsterAI.AIDecision) -> String:
	if decision.targets.is_empty():
		return ""
	var target = decision.targets[0]
	if target is Character:
		return target.get_display_name()
	elif target is Monster:
		return target.monster_name
	return ""
