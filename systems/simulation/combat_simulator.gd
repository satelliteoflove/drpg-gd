class_name CombatSimulator
extends RefCounted

signal turn_completed(turn_data: Dictionary)
signal combat_completed(result: Dictionary)

enum SurpriseResult { NONE, PARTY_SURPRISE, ENEMY_SURPRISE }

const STALEMATE_THRESHOLD: int = 30
const SURPRISE_BASE_CHANCE: float = 0.12
const SURPRISE_AGI_FACTOR: float = 0.02
const SURPRISE_MIN_CHANCE: float = 0.05
const SURPRISE_MAX_CHANCE: float = 0.25

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
var _stalemate_counter: int = 0
var _surprise: SurpriseResult = SurpriseResult.NONE
var _surprise_results: Array[Dictionary] = []


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
		if enemy.extra_actions > 0:
			_initiative.add_extra_actions(enemy.combat_id, false, enemy.agility, enemy.extra_actions)

	metrics.record_party_state_start(_get_total_party_hp(), _get_total_party_mp())


func run() -> Dictionary:
	_roll_surprise()
	if _surprise != SurpriseResult.NONE:
		_execute_surprise_round()

	while _combat_active and _current_turn < max_turns:
		var turn_result := step()
		if not _combat_active:
			break
		_track_stalemate(turn_result)
		if _stalemate_counter >= STALEMATE_THRESHOLD:
			_combat_active = false
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

	if StatusEffectSystem.is_mentally_controlled(character):
		var result := _execute_mental_player_turn(character)
		result["turn"] = _current_turn
		result["actor"] = character.get_display_name()
		result["is_player"] = true
		result["tick_messages"] = tick_messages
		return result

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

	var tick_messages := StatusEffectSystem.tick_effects(monster, "combat")

	if monster.is_dead:
		_initiative.remove_combatant(monster_id)
		return {"skipped": true, "reason": "died from status", "messages": tick_messages}

	if StatusEffectSystem.is_disabled(monster):
		return {"skipped": true, "reason": "disabled", "messages": tick_messages}

	if StatusEffectSystem.may_skip_turn_from_fear(monster):
		return {"skipped": true, "reason": "afraid", "messages": tick_messages}

	if StatusEffectSystem.is_mentally_controlled(monster):
		var result := _execute_mental_monster_turn(monster)
		result["turn"] = _current_turn
		result["actor"] = monster.monster_name
		result["is_player"] = false
		result["tick_messages"] = tick_messages
		return result

	var phase_messages := MonsterAI.check_boss_phase(monster)
	for phase_msg in phase_messages:
		if phase_msg.begins_with("__cast_spell:"):
			var spell_id := phase_msg.substr(13)
			var spell := SpellDatabase.get_spell(spell_id)
			if spell and monster.current_mp >= spell.mp_cost:
				var spell_targets := MonsterAI._get_spell_targets_for_monster(spell, party, enemies, monster)
				var spell_result := SpellCaster.cast_spell_by_monster(monster, spell, spell_targets)
				tick_messages.append_array(spell_result.messages)

	var decision := MonsterAI.decide_action(monster, party, enemies, ai_log)

	var decision_dict := {
		"action": _action_type_to_string(decision.action_type),
		"target": _get_decision_target_name(decision),
		"spell": decision.spell_id,
		"reasoning": decision.message if decision.message != "" else "AI behavior"
	}
	ai_log.log_decision(_current_turn, monster.monster_name, decision_dict)

	var target_statuses: Array[String] = []
	if not decision.targets.is_empty() and decision.targets[0] is Character:
		var t: Character = decision.targets[0]
		for active in t.active_statuses:
			target_statuses.append(CharacterEnums.get_status_name(active.type))

	var result := _execute_monster_action(monster, decision)
	result["turn"] = _current_turn
	result["actor"] = monster.monster_name
	result["is_player"] = false
	result["behavior"] = _behavior_to_string(decision.behavior)
	result["fumbled"] = decision.fumbled
	result["target_statuses"] = target_statuses
	result["phase_messages"] = phase_messages
	result["boss_phase"] = monster.current_phase if monster.is_boss else -1

	return result


func _execute_mental_player_turn(character: Character) -> Dictionary:
	if character.has_status(CharacterEnums.StatusEffect.BERSERK):
		var living: Array[Monster] = []
		for e in enemies:
			if not e.is_dead:
				living.append(e)
		if living.is_empty():
			return {"action": "berserk", "skipped": true, "reason": "no enemies"}
		var target: Monster = living[CombatRNG.randi() % living.size()]
		var accuracy_mod := StatusEffectSystem.get_accuracy_modifier(character)
		var result := DamageCalculator.calculate_character_attack(character, target, accuracy_mod)
		if result.hit:
			var damage := int(result.damage * CombatConstants.BERSERK_DAMAGE_MULTIPLIER)
			var actual := target.take_damage(damage)
			if target.is_dead:
				_initiative.remove_combatant(target.combat_id)
			return {"action": "berserk_attack", "hit": true, "damage": actual, "target": target.monster_name}
		return {"action": "berserk_attack", "hit": false, "target": target.monster_name}

	var roll := CombatRNG.randf()
	var is_confused := character.has_status(CharacterEnums.StatusEffect.CONFUSED)

	if roll < CombatConstants.CONFUSED_ACTION_ATTACK:
		var all_targets: Array = []
		for c in party.get_members():
			if c != character and not c.is_dead:
				all_targets.append(c)
		for e in enemies:
			if not e.is_dead:
				all_targets.append(e)
		if all_targets.is_empty():
			return {"action": "confused" if is_confused else "charmed", "skipped": true}
		var target = all_targets[CombatRNG.randi() % all_targets.size()] if is_confused else _sim_get_weakest_ally(character)
		if target == null:
			return {"action": "charmed", "skipped": true}
		if target is Monster:
			var accuracy_mod := StatusEffectSystem.get_accuracy_modifier(character)
			var result := DamageCalculator.calculate_character_attack(character, target, accuracy_mod)
			if result.hit:
				var actual: int = target.take_damage(result.damage)
				if target.is_dead:
					_initiative.remove_combatant(target.combat_id)
				return {"action": "mental_attack", "hit": true, "damage": actual, "target": target.monster_name}
			return {"action": "mental_attack", "hit": false, "target": target.monster_name}
		elif target is Character:
			var result := DamageCalculator.calculate_generic_attack(
				character.accuracy, target.evasion, character.weapon_dice, character.strength, target.defense)
			if result.hit:
				var actual: int = target.take_damage(result.damage)
				if target.is_dead:
					_initiative.remove_combatant(target.id)
				return {"action": "mental_attack", "hit": true, "damage": actual, "target": target.get_display_name()}
			return {"action": "mental_attack", "hit": false, "target": target.get_display_name()}

	elif roll < CombatConstants.CONFUSED_ACTION_DEFEND:
		character.is_defending = true
		return {"action": "mental_defend"}

	return {"action": "mental_daze"}


func _execute_mental_monster_turn(monster: Monster) -> Dictionary:
	if monster.has_status(CharacterEnums.StatusEffect.BERSERK):
		var alive_party := party.get_alive_members()
		if alive_party.is_empty():
			return {"action": "berserk", "skipped": true}
		var target: Character = alive_party[CombatRNG.randi() % alive_party.size()]
		var attack: MonsterAttack = monster.get_random_attack()
		if attack == null:
			return {"action": "berserk", "skipped": true, "reason": "no attack"}
		var evasion_mod := StatusEffectSystem.get_evasion_modifier(target)
		var result := DamageCalculator.calculate_monster_attack(monster, attack, target, evasion_mod)
		if result.hit:
			var damage := int(result.damage * CombatConstants.BERSERK_DAMAGE_MULTIPLIER)
			var actual := target.take_damage(damage)
			if target.is_dead:
				_initiative.remove_combatant(target.id)
			return {"action": "berserk_attack", "hit": true, "damage": actual, "target": target.get_display_name()}
		return {"action": "berserk_attack", "hit": false, "target": target.get_display_name()}

	var roll := CombatRNG.randf()
	var is_confused := monster.has_status(CharacterEnums.StatusEffect.CONFUSED)

	if roll < CombatConstants.CONFUSED_ACTION_ATTACK:
		var all_targets: Array = []
		for c in party.get_members():
			if not c.is_dead:
				all_targets.append(c)
		for e in enemies:
			if e != monster and not e.is_dead:
				all_targets.append(e)
		if all_targets.is_empty():
			return {"action": "mental", "skipped": true}
		var target
		if is_confused:
			target = all_targets[CombatRNG.randi() % all_targets.size()]
		else:
			target = _sim_get_weakest_monster_ally(monster)
		if target == null:
			return {"action": "mental", "skipped": true}
		var attack: MonsterAttack = monster.get_random_attack()
		if attack == null:
			return {"action": "mental", "skipped": true}
		if target is Character:
			var evasion_mod := StatusEffectSystem.get_evasion_modifier(target)
			var result := DamageCalculator.calculate_monster_attack(monster, attack, target, evasion_mod)
			if result.hit:
				var actual: int = target.take_damage(result.damage)
				if target.is_dead:
					_initiative.remove_combatant(target.id)
				return {"action": "mental_attack", "hit": true, "damage": actual, "target": target.get_display_name()}
			return {"action": "mental_attack", "hit": false, "target": target.get_display_name()}
		elif target is Monster:
			var result := DamageCalculator.calculate_generic_attack(
				attack.accuracy_bonus, target.evasion, attack.damage_dice, monster.strength, target.defense)
			if result.hit:
				var actual_damage := mini(result.damage, target.current_hp)
				target.current_hp -= actual_damage
				if target.current_hp <= 0:
					target.current_hp = 0
					target.is_dead = true
					_initiative.remove_combatant(target.combat_id)
				return {"action": "mental_attack", "hit": true, "damage": actual_damage, "target": target.monster_name}
			return {"action": "mental_attack", "hit": false, "target": target.monster_name}

	elif roll < CombatConstants.CONFUSED_ACTION_DEFEND:
		monster.is_defending = true
		return {"action": "mental_defend"}

	return {"action": "mental_daze"}


func _sim_get_weakest_ally(character: Character) -> Character:
	var weakest: Character = null
	var lowest_hp := 999999
	for c in party.get_members():
		if c != character and not c.is_dead and c.current_hp < lowest_hp:
			lowest_hp = c.current_hp
			weakest = c
	return weakest


func _sim_get_weakest_monster_ally(monster: Monster) -> Monster:
	var weakest: Monster = null
	var lowest_hp := 999999
	for e in enemies:
		if e != monster and not e.is_dead and e.current_hp < lowest_hp:
			lowest_hp = e.current_hp
			weakest = e
	return weakest


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
		"item":
			return _execute_item_use(decision)
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

		var snap_msgs := StatusEffectSystem.snap_out_on_damage(target)

		if target.is_dead:
			_initiative.remove_combatant(target.combat_id)
			metrics.record_death(target.monster_name, _current_turn)
			metrics.record_kill_xp(target.exp_reward)

		return {
			"action": "attack",
			"hit": true,
			"damage": actual,
			"target": target.monster_name,
			"target_killed": target.is_dead,
			"messages": snap_msgs
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


func _execute_item_use(decision: Dictionary) -> Dictionary:
	var item: Item = decision.get("item")
	var target: Character = decision.get("target")
	if item == null or target == null:
		return {"action": "item", "success": false}

	var cured: Array[String] = []
	for status in item.cures_status:
		if target.has_status(status):
			target.remove_status(status)
			cured.append(CharacterEnums.get_status_name(status))

	if party.inventory:
		party.inventory.remove_item(item.id, 1)

	return {
		"action": "item",
		"item_name": item.item_name,
		"target": target.get_display_name(),
		"success": not cured.is_empty(),
		"cured": cured,
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
	var snap_messages: Array[String] = []

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

			var snap_msgs := StatusEffectSystem.snap_out_on_damage(char_target)

			if not char_target.is_dead:
				_try_apply_attack_effect(monster, attack, char_target)

			if char_target.is_dead:
				_initiative.remove_combatant(char_target.id)
				metrics.record_death(char_target.get_display_name(), _current_turn)

			snap_messages.append_array(snap_msgs)
		else:
			misses.append(char_target.get_display_name())

	return {
		"action": "attack",
		"attack_name": attack.attack_name,
		"damage": total_damage,
		"hits": hits,
		"misses": misses,
		"messages": snap_messages,
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

	var applied: Array = result.get("statuses_applied", [])
	for entry in applied:
		metrics.record_status(monster.monster_name, entry["target"], entry["status"])

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

	var surprise_str := "none"
	match _surprise:
		SurpriseResult.PARTY_SURPRISE: surprise_str = "party"
		SurpriseResult.ENEMY_SURPRISE: surprise_str = "enemy"

	var stalemate := _stalemate_counter >= STALEMATE_THRESHOLD

	return {
		"seed": rng_seed,
		"result": "victory" if victory else "defeat",
		"victory": victory,
		"turns": _current_turn,
		"party_survivors": party_survivors,
		"party_hp_remaining": party_hp_remaining,
		"party_hp_percent": float(party_hp_remaining) / float(maxi(1, party_hp_total)) * 100.0,
		"surprise": surprise_str,
		"stalemate": stalemate,
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


func _behavior_to_string(behavior: MonsterAI.AIBehavior) -> String:
	match behavior:
		MonsterAI.AIBehavior.AGGRESSIVE: return "aggressive"
		MonsterAI.AIBehavior.DEFENSIVE: return "defensive"
		MonsterAI.AIBehavior.SPELLCASTER: return "spellcaster"
		MonsterAI.AIBehavior.SUPPORT: return "support"
		MonsterAI.AIBehavior.RANGED: return "ranged"
		MonsterAI.AIBehavior.BERSERKER: return "berserker"
		MonsterAI.AIBehavior.TACTICAL: return "tactical"
	return "unknown"


func _try_apply_attack_effect(monster: Monster, attack: MonsterAttack, target: Character) -> void:
	if attack.effect_type < 0 or attack.effect_chance <= 0:
		return
	if attack.effect_type in CharacterEnums.BENEFICIAL_STATUSES:
		return
	if CombatRNG.randf() > attack.effect_chance:
		return
	var duration := -1
	if attack.effect_duration_dice != "":
		duration = DamageCalculator.roll_dice(attack.effect_duration_dice)
	var save_type := _get_save_type_from_string(attack.effect_save_type)
	var dc := 10 + attack.effect_power
	if save_type >= 0:
		if StatusEffectSystem.roll_saving_throw(target, save_type, dc):
			return
	var effect_result := StatusEffectSystem.apply_status(target, attack.effect_type, duration, "monster_attack", attack.effect_power)
	if effect_result.get("success", false):
		metrics.record_status(monster.monster_name, target.get_display_name(), attack.effect_type)


func _get_save_type_from_string(save_str: String) -> CharacterEnums.SaveType:
	match save_str.to_lower():
		"physical": return CharacterEnums.SaveType.PHYSICAL
		"mental": return CharacterEnums.SaveType.MENTAL
		"magical": return CharacterEnums.SaveType.MAGICAL
		"death": return CharacterEnums.SaveType.DEATH
	return -1 as CharacterEnums.SaveType


func _get_decision_target_name(decision: MonsterAI.AIDecision) -> String:
	if decision.targets.is_empty():
		return ""
	var target = decision.targets[0]
	if target is Character:
		return target.get_display_name()
	elif target is Monster:
		return target.monster_name
	return ""


func _roll_surprise() -> void:
	var party_avg_agi := 0.0
	var party_count := 0
	for member in party.get_members():
		if not member.is_dead:
			party_avg_agi += member.agility
			party_count += 1
	if party_count > 0:
		party_avg_agi /= party_count

	var enemy_avg_agi := 0.0
	var enemy_count := 0
	for enemy in enemies:
		if not enemy.is_dead:
			enemy_avg_agi += enemy.agility
			enemy_count += 1
	if enemy_count > 0:
		enemy_avg_agi /= enemy_count

	var agi_diff := party_avg_agi - enemy_avg_agi
	var party_chance := clampf(SURPRISE_BASE_CHANCE + agi_diff * SURPRISE_AGI_FACTOR, SURPRISE_MIN_CHANCE, SURPRISE_MAX_CHANCE)
	var enemy_chance := clampf(SURPRISE_BASE_CHANCE - agi_diff * SURPRISE_AGI_FACTOR, SURPRISE_MIN_CHANCE, SURPRISE_MAX_CHANCE)

	var roll := CombatRNG.randf()
	if roll < party_chance:
		_surprise = SurpriseResult.PARTY_SURPRISE
	elif roll < party_chance + enemy_chance:
		_surprise = SurpriseResult.ENEMY_SURPRISE
	else:
		_surprise = SurpriseResult.NONE


func _execute_surprise_round() -> void:
	if _surprise == SurpriseResult.PARTY_SURPRISE:
		for member in party.get_members():
			if not _combat_active:
				break
			if member.is_dead or member.is_disabled():
				continue
			var target := _get_first_living_enemy()
			if target == null:
				break
			var result := _execute_character_attack(member, target)
			result["surprise"] = true
			result["actor"] = member.get_display_name()
			_surprise_results.append(result)
			_check_combat_end()

	elif _surprise == SurpriseResult.ENEMY_SURPRISE:
		for enemy in enemies:
			if not _combat_active:
				break
			if enemy.is_dead:
				continue
			var attack := enemy.get_random_attack()
			if attack == null:
				continue
			var target := _get_random_living_party_member()
			if target == null:
				break
			var result := _execute_monster_attack(enemy, attack, [target])
			result["surprise"] = true
			result["actor"] = enemy.monster_name
			_surprise_results.append(result)
			_check_combat_end()


func _get_first_living_enemy() -> Monster:
	for enemy in enemies:
		if not enemy.is_dead:
			return enemy
	return null


func _get_random_living_party_member() -> Character:
	var alive := party.get_alive_members()
	if alive.is_empty():
		return null
	return alive[CombatRNG.randi() % alive.size()]


func _track_stalemate(turn_data: Dictionary) -> void:
	var had_progress := false

	if turn_data.get("damage", 0) > 0:
		had_progress = true
	elif turn_data.get("hit", false):
		had_progress = true
	elif turn_data.get("target_killed", false):
		had_progress = true
	elif turn_data.get("healing", 0) > 0:
		had_progress = true
	elif not turn_data.get("hits", [] as Array[String]).is_empty():
		had_progress = true

	if had_progress:
		_stalemate_counter = 0
	else:
		_stalemate_counter += 1
