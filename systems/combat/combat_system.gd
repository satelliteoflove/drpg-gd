class_name CombatSystem
extends RefCounted

signal turn_started(combatant_id: String, is_player: bool)
signal action_performed(message: String)
signal combat_ended(victory: bool, exp_gained: int, gold_gained: int, loot: Array[Item])
signal target_selection_requested(reachable_enemies: Array[Monster])
signal monster_turn_delay_requested(delay: float)
signal layout_changed

var party_members: Array[Character] = []
var party: Party = null
var enemies: Array[Monster] = []
var initiative: InitiativeTracker = null
var is_active: bool = false
var current_combatant_id: String = ""
var waiting_for_player: bool = false
var waiting_for_target: bool = false
var processing_monster_turn: bool = false
var is_boss_encounter: bool = false
var combat_log: Array[Dictionary] = []
var _combat_id: String = ""
var _turn_count: int = 0


## Initializes and starts a new combat encounter.
## [param p_party]: The player's party participating in combat.
## [param enemy_list]: Array of monsters to fight against.
func _log_action(entry: Dictionary) -> void:
	entry["event_id"] = combat_log.size()
	entry["combat_id"] = _combat_id
	entry["day"] = GameState.game_day
	entry["category"] = "combat"
	combat_log.append(entry)


func start_combat(p_party: Party, enemy_list: Array[Monster]) -> void:
	party = p_party
	party_members = party.get_members()
	enemies = []

	for enemy in enemy_list:
		var combat_enemy := enemy.duplicate_for_combat()
		enemies.append(combat_enemy)

	combat_log.clear()
	_combat_id = "c_%d_%d" % [GameState.game_day, randi() % 10000]
	_turn_count = 0

	initiative = InitiativeTracker.new()
	is_active = true
	waiting_for_player = false
	waiting_for_target = false

	for character in party_members:
		if not character.is_dead:
			character.init_combat()
			initiative.add_combatant(character.id, true, character.agility)

	for enemy in enemies:
		initiative.add_combatant(enemy.combat_id, false, enemy.agility)
		if enemy.extra_actions > 0:
			initiative.add_extra_actions(enemy.combat_id, false, enemy.agility, enemy.extra_actions)

	var party_ids: Array[String] = []
	for m in party_members:
		party_ids.append(m.id)
	var enemy_info: Array[Dictionary] = []
	for e in enemies:
		enemy_info.append({"name": e.monster_name, "level": e.level if "level" in e else 0})
	_log_action({
		"type": "combat_start",
		"floor": GameState.current_floor,
		"is_boss": is_boss_encounter,
		"party_ids": party_ids,
		"enemies": enemy_info,
	})

	var enemy_count := enemies.size()
	if is_boss_encounter:
		var boss_name := ""
		for enemy in enemies:
			if enemy.is_boss:
				boss_name = enemy.monster_name
				break
		if boss_name != "":
			action_performed.emit("A powerful foe bars your path - %s!" % boss_name)
		else:
			action_performed.emit("A powerful foe bars your path!")
	elif enemy_count == 1:
		action_performed.emit("A %s appears!" % enemies[0].monster_name)
	else:
		action_performed.emit("%d enemies appear!" % enemy_count)

	_advance_turn()


func _advance_turn() -> void:
	if not is_active:
		return

	var entry := initiative.get_next_combatant()
	if entry == null:
		return

	_turn_count += 1
	current_combatant_id = entry.id

	if entry.is_player:
		var character := _get_character(entry.id)
		if character == null or character.is_dead:
			initiative.apply_action_delay(entry.id)
			_advance_turn()
			return

		var tick_messages := StatusEffectSystem.tick_effects(character, "combat")
		for msg in tick_messages:
			action_performed.emit(msg)

		if character.is_dead:
			initiative.remove_combatant(entry.id)
			action_performed.emit("%s has died!" % character.get_display_name())
			_check_party_row_advance()
			_check_combat_end()
			return

		if StatusEffectSystem.is_disabled(character):
			var status_name := _get_disabling_status_name(character)
			action_performed.emit("%s is %s and cannot act!" % [character.get_display_name(), status_name])
			initiative.apply_action_delay(entry.id)
			_check_combat_end()
			return

		if StatusEffectSystem.may_skip_turn_from_fear(character):
			action_performed.emit("%s is too afraid to act!" % character.get_display_name())
			initiative.apply_action_delay(entry.id)
			_check_combat_end()
			return

		if character.has_status(CharacterEnums.StatusEffect.CONFUSED):
			character.is_defending = false
			_execute_confused_player_turn(character)
			initiative.apply_action_delay(entry.id)
			_check_combat_end()
			return

		if character.has_status(CharacterEnums.StatusEffect.CHARMED):
			character.is_defending = false
			_execute_charmed_player_turn(character)
			initiative.apply_action_delay(entry.id)
			_check_combat_end()
			return

		if character.has_status(CharacterEnums.StatusEffect.BERSERK):
			character.is_defending = false
			_execute_berserk_player_turn(character)
			initiative.apply_action_delay(entry.id)
			_check_combat_end()
			return

		character.is_defending = false
		waiting_for_player = true
		turn_started.emit(entry.id, entry.is_player)
	else:
		turn_started.emit(entry.id, entry.is_player)
		var delay := _get_combat_delay()
		if delay > 0:
			monster_turn_delay_requested.emit(delay)
		else:
			_execute_monster_turn(entry.id)


## Called after monster turn delay to execute the pending monster action.
func execute_delayed_monster_turn() -> void:
	if not is_active or processing_monster_turn:
		return
	_execute_monster_turn(current_combatant_id)


func _get_combat_delay() -> float:
	var speed: int = GameState.combat_speed
	if speed >= 10:
		return 0.0
	return (11 - speed) * 0.1


func _get_disabling_status_name(character: Character) -> String:
	if character.has_status(CharacterEnums.StatusEffect.ASLEEP):
		return "asleep"
	if character.has_status(CharacterEnums.StatusEffect.PARALYZED):
		return "paralyzed"
	if character.has_status(CharacterEnums.StatusEffect.STONED):
		return "petrified"
	return "incapacitated"


## Executes a player attack action against a target monster.
## [param target]: The monster to attack. If null and only one enemy is reachable, auto-targets.
func player_attack(target: Monster = null) -> void:
	if not waiting_for_player or not is_active:
		return

	var attacker := _get_character(current_combatant_id)
	if attacker == null or attacker.is_dead:
		waiting_for_player = false
		_advance_turn()
		return

	var reachable := Targeting.get_reachable_enemies(attacker, party, enemies)
	if reachable.is_empty():
		return

	if target == null:
		if reachable.size() == 1:
			target = reachable[0]
		else:
			waiting_for_target = true
			target_selection_requested.emit(reachable)
			return

	if not target in reachable:
		action_performed.emit("%s cannot reach that enemy!" % attacker.get_display_name())
		return

	waiting_for_player = false
	waiting_for_target = false
	_execute_player_attack(attacker, target)


func _execute_player_attack(attacker: Character, target: Monster) -> void:
	var accuracy_mod := StatusEffectSystem.get_accuracy_modifier(attacker)
	var rel_bonuses := RelationshipManager.get_adjacency_bonus(GameState.get_party_members())
	accuracy_mod += rel_bonuses.get(attacker.id, {}).get("accuracy", 0)
	var result := DamageCalculator.calculate_character_attack(attacker, target, accuracy_mod)

	var target_hp_before := target.current_hp
	if result.hit:
		var damage: int = result.damage
		var sleep_mult := StatusEffectSystem.get_damage_multiplier_for_sleeping(target)
		if sleep_mult > 1.0:
			damage = int(damage * sleep_mult)

		var actual_damage := target.take_damage(damage)

		_log_action({
			"type": "action", "actor_id": attacker.id, "target_id": target.combat_id,
			"action": "attack", "action_name": attacker.equipped_weapon.item_name if attacker.equipped_weapon else "Unarmed",
			"result": "hit", "damage": actual_damage, "healing": 0,
			"target_hp_before": target_hp_before, "target_hp_after": target.current_hp,
			"target_max_hp": target.max_hp, "is_kill": target.is_dead,
		})

		var damage_msg := "%s attacks %s for %d damage!" % [
			attacker.get_display_name(),
			target.monster_name,
			actual_damage
		]
		if sleep_mult > 1.0:
			damage_msg += " (Critical - target was asleep!)"
		action_performed.emit(damage_msg)

		var wake_msg := StatusEffectSystem.wake_on_damage(target)
		if wake_msg != "":
			action_performed.emit(wake_msg)

		for snap_msg in StatusEffectSystem.snap_out_on_damage(target):
			action_performed.emit(snap_msg)

		if target.is_dead:
			action_performed.emit("%s is defeated!" % target.monster_name)
			initiative.remove_combatant(target.combat_id)
	else:
		_log_action({
			"type": "action", "actor_id": attacker.id, "target_id": target.combat_id,
			"action": "attack", "action_name": attacker.equipped_weapon.item_name if attacker.equipped_weapon else "Unarmed",
			"result": "miss", "damage": 0, "healing": 0,
			"target_hp_before": target_hp_before, "target_hp_after": target.current_hp,
			"target_max_hp": target.max_hp, "is_kill": false,
		})
		action_performed.emit("%s's attack on %s misses!" % [
			attacker.get_display_name(),
			target.monster_name
		])

	initiative.apply_action_delay(current_combatant_id)
	_check_combat_end()


## Executes a player defend action, reducing incoming damage by half until next turn.
func player_defend() -> void:
	if not waiting_for_player or not is_active:
		return

	var defender := _get_character(current_combatant_id)
	if defender == null or defender.is_dead:
		waiting_for_player = false
		_advance_turn()
		return

	defender.is_defending = true
	waiting_for_player = false
	waiting_for_target = false

	_log_action({
		"type": "action", "actor_id": defender.id, "target_id": defender.id,
		"action": "defend", "action_name": "Defend",
		"result": "ok", "damage": 0, "healing": 0,
	})

	action_performed.emit("%s takes a defensive stance." % defender.get_display_name())
	initiative.apply_action_delay(current_combatant_id)
	_check_combat_end()


func player_breath(target: Monster = null) -> void:
	if not waiting_for_player or not is_active:
		return

	var attacker := _get_character(current_combatant_id)
	if attacker == null or not attacker.can_use_breath():
		return

	waiting_for_player = false
	waiting_for_target = false
	attacker.breath_used = true

	var damage := attacker.get_breath_damage()

	if attacker.is_breath_aoe():
		var targets: Array[Monster] = []
		for enemy in enemies:
			if not enemy.is_dead:
				targets.append(enemy)

		action_performed.emit("%s breathes acid!" % attacker.get_display_name())
		for t in targets:
			var hp_before := t.current_hp
			var actual := t.take_damage(damage)
			_log_action({
				"type": "action", "actor_id": attacker.id, "target_id": t.combat_id,
				"action": "breath", "action_name": "Acid Breath (AOE)",
				"result": "hit", "damage": actual, "healing": 0,
				"target_hp_before": hp_before, "target_hp_after": t.current_hp,
				"target_max_hp": t.max_hp, "is_kill": t.is_dead,
			})
			if t.is_dead:
				action_performed.emit("%s takes %d acid damage and is defeated!" % [t.monster_name, actual])
				initiative.remove_combatant(t.combat_id)
			else:
				action_performed.emit("%s takes %d acid damage." % [t.monster_name, actual])
	else:
		if target == null:
			var living := get_living_enemies()
			if living.size() == 1:
				target = living[0]
			else:
				waiting_for_player = true
				waiting_for_target = true
				attacker.breath_used = false
				target_selection_requested.emit(living)
				return

		var hp_before := target.current_hp
		action_performed.emit("%s breathes acid at %s!" % [attacker.get_display_name(), target.monster_name])
		var actual := target.take_damage(damage)
		_log_action({
			"type": "action", "actor_id": attacker.id, "target_id": target.combat_id,
			"action": "breath", "action_name": "Acid Breath",
			"result": "hit", "damage": actual, "healing": 0,
			"target_hp_before": hp_before, "target_hp_after": target.current_hp,
			"target_max_hp": target.max_hp, "is_kill": target.is_dead,
		})
		if target.is_dead:
			action_performed.emit("%s takes %d acid damage and is defeated!" % [target.monster_name, actual])
			initiative.remove_combatant(target.combat_id)
		else:
			action_performed.emit("%s takes %d acid damage." % [target.monster_name, actual])

	initiative.apply_action_delay(current_combatant_id)
	_check_combat_end()


## Attempts to escape from combat. Success chance based on party's average agility.
func player_escape() -> void:
	if not waiting_for_player or not is_active:
		return

	if is_boss_encounter:
		action_performed.emit("There is no escape from this battle!")
		return

	waiting_for_player = false
	waiting_for_target = false
	var avg_agility := party.get_average_agility()

	var escaper := _get_character(current_combatant_id)
	var escape_actor_id := escaper.id if escaper else ""

	if DamageCalculator.try_escape(avg_agility):
		_log_action({
			"type": "action", "actor_id": escape_actor_id, "target_id": "",
			"action": "escape", "action_name": "Escape",
			"result": "ok", "damage": 0, "healing": 0,
		})
		action_performed.emit("The party escapes!")
		_end_combat(false, 0, 0, [])
	else:
		_log_action({
			"type": "action", "actor_id": escape_actor_id, "target_id": "",
			"action": "escape", "action_name": "Escape",
			"result": "fail", "damage": 0, "healing": 0,
		})
		action_performed.emit("Failed to escape!")
		initiative.apply_action_delay(current_combatant_id)
		_advance_turn()


## Casts a spell from the current player character.
## [param spell_id]: The ID of the spell to cast.
## [param targets]: Array of valid targets for the spell (Character or Monster).
func player_dispel(target: Monster) -> void:
	if not waiting_for_player or not is_active:
		return

	var character := _get_character(current_combatant_id)
	if character == null or character.is_dead:
		waiting_for_player = false
		_advance_turn()
		return

	waiting_for_player = false
	waiting_for_target = false

	var hp_before := target.current_hp
	var result := DispelUndead.attempt_dispel(character, target)
	action_performed.emit(result["message"])

	_log_action({
		"type": "action", "actor_id": character.id, "target_id": target.combat_id,
		"action": "dispel", "action_name": "Dispel Undead",
		"result": "hit" if result["success"] else "miss",
		"damage": target.max_hp if result["success"] else 0, "healing": 0,
		"target_hp_before": hp_before, "target_hp_after": target.current_hp,
		"target_max_hp": target.max_hp, "is_kill": result["success"],
	})

	if result["success"]:
		initiative.remove_combatant(target.combat_id)

	initiative.apply_action_delay(current_combatant_id)
	_check_combat_end()


func player_cast_spell(spell_id: String, targets: Array) -> void:
	if not waiting_for_player or not is_active:
		return

	var caster := _get_character(current_combatant_id)
	if caster == null or caster.is_dead:
		waiting_for_player = false
		_advance_turn()
		return

	var spell := SpellDatabase.get_spell(spell_id)
	if spell == null:
		action_performed.emit("Unknown spell!")
		return

	waiting_for_player = false
	waiting_for_target = false

	var snapshots: Array[Dictionary] = []
	for target in targets:
		var tid: String = target.id if target is Character else target.combat_id
		snapshots.append({
			"id": tid, "hp_before": target.current_hp, "max_hp": target.max_hp,
			"was_dead": target.is_dead,
		})

	var result := SpellCaster.cast_spell(caster, spell, targets, true)

	for msg in result.messages:
		action_performed.emit(msg)

	_log_action({
		"type": "action", "actor_id": caster.id, "target_id": "",
		"action": "spell", "action_name": spell.name,
		"result": "fizzle" if result.fizzled else ("ok" if result.success else "fail"),
		"damage": result.total_damage, "healing": result.total_healing,
	})

	for i in range(targets.size()):
		var target = targets[i]
		var snap: Dictionary = snapshots[i]
		var tid: String = snap["id"]
		var hp_before: int = snap["hp_before"]
		var was_dead: bool = snap["was_dead"]
		var healed: int = maxi(0, target.current_hp - hp_before)
		var damaged: int = maxi(0, hp_before - target.current_hp)
		if was_dead and not target.is_dead:
			_log_action({
				"type": "action", "actor_id": caster.id, "target_id": tid,
				"action": "spell_effect", "action_name": spell.name,
				"result": "revive", "damage": 0, "healing": target.current_hp,
				"target_hp_before": 0, "target_hp_after": target.current_hp,
				"target_max_hp": target.max_hp, "is_kill": false,
			})
		elif healed > 0:
			_log_action({
				"type": "action", "actor_id": caster.id, "target_id": tid,
				"action": "spell_effect", "action_name": spell.name,
				"result": "heal", "damage": 0, "healing": healed,
				"target_hp_before": hp_before, "target_hp_after": target.current_hp,
				"target_max_hp": target.max_hp, "is_kill": false,
			})
		elif damaged > 0:
			_log_action({
				"type": "action", "actor_id": caster.id, "target_id": tid,
				"action": "spell_effect", "action_name": spell.name,
				"result": "hit", "damage": damaged, "healing": 0,
				"target_hp_before": hp_before, "target_hp_after": target.current_hp,
				"target_max_hp": target.max_hp, "is_kill": target.is_dead,
			})

	var ally_killed := false
	for target in targets:
		if target is Monster and target.is_dead:
			initiative.remove_combatant(target.combat_id)
		elif target is Character and target.is_dead:
			initiative.remove_combatant(target.id)
			ally_killed = true

	if ally_killed:
		_check_party_row_advance()

	initiative.apply_action_delay(current_combatant_id)
	_check_combat_end()


## Returns auto-selected targets for spells with predetermined targeting.
## [param spell]: The spell to get targets for.
## [return]: Array of targets, empty if manual selection required.
func get_spell_targets(spell: Spell) -> Array:
	match spell.target_type:
		CharacterEnums.SpellTargetType.SELF:
			var caster := _get_character(current_combatant_id)
			return [caster] if caster else []
		CharacterEnums.SpellTargetType.SINGLE_ALLY:
			return []
		CharacterEnums.SpellTargetType.SINGLE_ENEMY:
			return []
		CharacterEnums.SpellTargetType.ALL_ALLIES:
			var result: Array = []
			for member in party_members:
				if not member.is_dead:
					result.append(member)
			return result
		CharacterEnums.SpellTargetType.ALL_ENEMIES:
			var result: Array = []
			for enemy in enemies:
				if not enemy.is_dead:
					result.append(enemy)
			return result
		CharacterEnums.SpellTargetType.DEAD_ALLY:
			return []
		CharacterEnums.SpellTargetType.SPLASH:
			return []
		CharacterEnums.SpellTargetType.ROW:
			return []
		CharacterEnums.SpellTargetType.COLUMN:
			return []
	return []


## Returns all enemies adjacent to the center enemy for splash damage spells.
## [param center_enemy]: The central target of the splash.
## [return]: Array of monsters within 1 tile of the center.
func get_splash_targets(center_enemy: Monster) -> Array[Monster]:
	var result: Array[Monster] = []
	var center_pos := center_enemy.grid_position

	for enemy in enemies:
		if enemy.is_dead:
			continue
		var pos: Vector2i = enemy.grid_position
		var dx: int = abs(pos.x - center_pos.x)
		var dy: int = abs(pos.y - center_pos.y)
		if dx <= 1 and dy <= 1:
			result.append(enemy)

	return result


## Returns all living enemies in the specified row.
## [param row]: Row index (0=front, 1=middle, 2=back).
## [return]: Array of monsters in that row.
func get_row_targets(row: int) -> Array[Monster]:
	var result: Array[Monster] = []
	for enemy in enemies:
		if enemy.is_dead:
			continue
		if enemy.grid_position.y == row:
			result.append(enemy)
	return result


## Returns all living enemies in the specified column.
## [param column]: Column index (0=left, 1=center, 2=right).
## [return]: Array of monsters in that column.
func get_column_targets(column: int) -> Array[Monster]:
	var result: Array[Monster] = []
	for enemy in enemies:
		if enemy.is_dead:
			continue
		if enemy.grid_position.x == column:
			result.append(enemy)
	return result


func get_available_rows() -> Array[int]:
	var rows: Array[int] = []
	for enemy in enemies:
		if enemy.is_dead:
			continue
		var row := enemy.grid_position.y
		if not rows.has(row):
			rows.append(row)
	rows.sort()
	return rows


func get_available_columns() -> Array[int]:
	var cols: Array[int] = []
	for enemy in enemies:
		if enemy.is_dead:
			continue
		var col := enemy.grid_position.x
		if not cols.has(col):
			cols.append(col)
	cols.sort()
	return cols


## Returns party members valid for targeting with ally spells.
## [param include_dead]: If true, includes dead characters (for resurrection spells).
## [return]: Array of valid character targets.
func get_valid_ally_targets(include_dead: bool = false) -> Array[Character]:
	var result: Array[Character] = []
	for member in party_members:
		if include_dead or not member.is_dead:
			result.append(member)
	return result


## Returns all dead party members (for resurrection spell targeting).
## [return]: Array of dead characters.
func get_dead_allies() -> Array[Character]:
	var result: Array[Character] = []
	for member in party_members:
		if member.is_dead:
			result.append(member)
	return result


func _execute_monster_turn(monster_id: String) -> void:
	processing_monster_turn = true

	var monster := _get_enemy_by_combat_id(monster_id)
	if monster == null or monster.is_dead:
		processing_monster_turn = false
		_advance_turn()
		return

	var tick_messages := StatusEffectSystem.tick_effects(monster, "combat")
	for msg in tick_messages:
		action_performed.emit(msg)

	if monster.is_dead:
		initiative.remove_combatant(monster_id)
		processing_monster_turn = false
		_check_combat_end()
		return

	if StatusEffectSystem.is_disabled(monster):
		var status_name := _get_monster_disabling_status_name(monster)
		action_performed.emit("%s is %s and cannot act!" % [monster.monster_name, status_name])
		initiative.apply_action_delay(monster_id)
		processing_monster_turn = false
		_check_combat_end()
		return

	if StatusEffectSystem.may_skip_turn_from_fear(monster):
		action_performed.emit("%s is too afraid to act!" % monster.monster_name)
		initiative.apply_action_delay(monster_id)
		processing_monster_turn = false
		_check_combat_end()
		return

	if monster.has_status(CharacterEnums.StatusEffect.CONFUSED):
		monster.is_defending = false
		_execute_confused_monster_turn(monster)
		initiative.apply_action_delay(monster_id)
		processing_monster_turn = false
		_check_combat_end()
		return

	if monster.has_status(CharacterEnums.StatusEffect.CHARMED):
		monster.is_defending = false
		_execute_charmed_monster_turn(monster)
		initiative.apply_action_delay(monster_id)
		processing_monster_turn = false
		_check_combat_end()
		return

	if monster.has_status(CharacterEnums.StatusEffect.BERSERK):
		monster.is_defending = false
		_execute_berserk_monster_turn(monster)
		initiative.apply_action_delay(monster_id)
		processing_monster_turn = false
		_check_combat_end()
		return

	monster.is_defending = false

	var phase_messages := MonsterAI.check_boss_phase(monster)
	for phase_msg in phase_messages:
		if phase_msg.begins_with("__cast_spell:"):
			var spell_id := phase_msg.substr(13)
			var spell := SpellDatabase.get_spell(spell_id)
			if spell and monster.current_mp >= spell.mp_cost:
				_execute_monster_spell(monster, spell_id, MonsterAI._get_spell_targets_for_monster(spell, party, enemies, monster))
		else:
			action_performed.emit(phase_msg)

	var decision := MonsterAI.decide_action(monster, party, enemies)

	match decision.action_type:
		MonsterAI.ActionType.DEFEND:
			_execute_monster_defend(monster)
		MonsterAI.ActionType.SPELL:
			_execute_monster_spell(monster, decision.spell_id, decision.targets)
		MonsterAI.ActionType.ATTACK:
			_execute_monster_attack(monster, decision.attack, decision.targets)
		_:
			_execute_monster_attack(monster, monster.get_random_attack(), [_get_random_alive_front_party_member()])

	initiative.apply_action_delay(monster_id)
	processing_monster_turn = false
	_check_combat_end()


func _execute_monster_defend(monster: Monster) -> void:
	monster.is_defending = true
	_log_action({
		"type": "action", "actor_id": monster.combat_id, "target_id": monster.combat_id,
		"action": "defend", "action_name": "Defend",
		"result": "ok", "damage": 0, "healing": 0,
	})
	action_performed.emit("%s takes a defensive stance." % monster.monster_name)


func _execute_monster_spell(monster: Monster, spell_id: String, targets: Array) -> void:
	var spell := SpellDatabase.get_spell(spell_id)
	if spell == null or monster.current_mp < spell.mp_cost:
		_execute_monster_attack(monster, monster.get_random_attack(), [_get_random_alive_front_party_member()])
		return

	var snapshots: Array[Dictionary] = []
	for target in targets:
		var tid: String = target.id if target is Character else target.combat_id
		snapshots.append({
			"id": tid, "hp_before": target.current_hp, "max_hp": target.max_hp,
			"was_dead": target.is_dead,
		})

	var result := SpellCaster.cast_spell_by_monster(monster, spell, targets)

	for msg in result.messages:
		action_performed.emit(msg)

	_log_action({
		"type": "action", "actor_id": monster.combat_id, "target_id": "",
		"action": "spell", "action_name": spell.name,
		"result": "ok" if result.success else "fail",
		"damage": result.total_damage, "healing": result.total_healing,
	})

	for i in range(targets.size()):
		var target = targets[i]
		var snap: Dictionary = snapshots[i]
		var tid: String = snap["id"]
		var hp_before: int = snap["hp_before"]
		var damaged: int = maxi(0, hp_before - target.current_hp)
		var healed: int = maxi(0, target.current_hp - hp_before)
		if damaged > 0:
			_log_action({
				"type": "action", "actor_id": monster.combat_id, "target_id": tid,
				"action": "spell_effect", "action_name": spell.name,
				"result": "hit", "damage": damaged, "healing": 0,
				"target_hp_before": hp_before, "target_hp_after": target.current_hp,
				"target_max_hp": target.max_hp, "is_kill": target.is_dead,
			})
		elif healed > 0:
			_log_action({
				"type": "action", "actor_id": monster.combat_id, "target_id": tid,
				"action": "spell_effect", "action_name": spell.name,
				"result": "heal", "damage": 0, "healing": healed,
				"target_hp_before": hp_before, "target_hp_after": target.current_hp,
				"target_max_hp": target.max_hp, "is_kill": false,
			})

	for target in targets:
		if target is Character and target.is_dead:
			initiative.remove_combatant(target.id)
			_check_party_row_advance()


func _execute_monster_attack(monster: Monster, attack: MonsterAttack, targets: Array) -> void:
	if attack == null or targets.is_empty():
		action_performed.emit("%s hesitates..." % monster.monster_name)
		return

	if attack.targets_all:
		_execute_monster_multi_attack(monster, attack, targets)
	elif attack.targets_row and targets.size() > 1:
		_execute_monster_multi_attack(monster, attack, targets)
	else:
		var target = targets[0]
		if target == null:
			return
		_execute_monster_single_attack(monster, attack, target)


func _execute_monster_single_attack(monster: Monster, attack: MonsterAttack, target: Character) -> void:
	var evasion_mod := StatusEffectSystem.get_evasion_modifier(target)
	var rel_bonuses := RelationshipManager.get_adjacency_bonus(GameState.get_party_members())
	evasion_mod += rel_bonuses.get(target.id, {}).get("evasion", 0)
	var result := DamageCalculator.calculate_monster_attack(monster, attack, target, evasion_mod)

	var target_hp_before := target.current_hp
	if result.hit:
		var damage: int = result.damage
		var sleep_mult := StatusEffectSystem.get_damage_multiplier_for_sleeping(target)
		if sleep_mult > 1.0:
			damage = int(damage * sleep_mult)

		var resist_suffix := ""
		if attack.element != CharacterEnums.Element.NONE:
			var resist: float = CharacterEnums.get_elemental_resistance(target.race, attack.element)
			if resist > 0.0:
				damage = maxi(1, int(damage * (1.0 - resist)))
				resist_suffix = " (%s resistant)" % CharacterEnums.get_element_name(attack.element)

		var actual_damage := target.take_damage(damage)

		_log_action({
			"type": "action", "actor_id": monster.combat_id, "target_id": target.id,
			"action": "attack", "action_name": attack.attack_name,
			"result": "hit", "damage": actual_damage, "healing": 0,
			"target_hp_before": target_hp_before, "target_hp_after": target.current_hp,
			"target_max_hp": target.max_hp, "is_kill": target.is_dead,
		})

		var damage_msg := "%s uses %s on %s for %d damage!%s" % [
			monster.monster_name,
			attack.attack_name,
			target.get_display_name(),
			actual_damage,
			resist_suffix
		]
		action_performed.emit(damage_msg)

		var wake_msg := StatusEffectSystem.wake_on_damage(target)
		if wake_msg != "":
			action_performed.emit(wake_msg)

		for snap_msg in StatusEffectSystem.snap_out_on_damage(target):
			action_performed.emit(snap_msg)

		_try_apply_attack_effect(attack, target)

		if target.is_dead:
			action_performed.emit("%s falls!" % target.get_display_name())
			initiative.remove_combatant(target.id)
			_check_party_row_advance()
	else:
		_log_action({
			"type": "action", "actor_id": monster.combat_id, "target_id": target.id,
			"action": "attack", "action_name": attack.attack_name,
			"result": "miss", "damage": 0, "healing": 0,
			"target_hp_before": target_hp_before, "target_hp_after": target.current_hp,
			"target_max_hp": target.max_hp, "is_kill": false,
		})
		action_performed.emit("%s's %s misses %s!" % [
			monster.monster_name,
			attack.attack_name,
			target.get_display_name()
		])


func _execute_monster_multi_attack(monster: Monster, attack: MonsterAttack, targets: Array) -> void:
	var hit_any := false
	var total_damage := 0
	var hit_names: Array[String] = []
	var miss_names: Array[String] = []

	for target in targets:
		if target == null or not target is Character:
			continue
		if target.is_dead:
			continue

		var char_target: Character = target as Character
		var evasion_mod := StatusEffectSystem.get_evasion_modifier(char_target)
		var rel_bonuses_multi := RelationshipManager.get_adjacency_bonus(GameState.get_party_members())
		evasion_mod += rel_bonuses_multi.get(char_target.id, {}).get("evasion", 0)
		var result := DamageCalculator.calculate_monster_attack(monster, attack, char_target, evasion_mod)

		var target_hp_before := char_target.current_hp
		if result.hit:
			hit_any = true
			var damage: int = result.damage
			var sleep_mult := StatusEffectSystem.get_damage_multiplier_for_sleeping(char_target)
			if sleep_mult > 1.0:
				damage = int(damage * sleep_mult)

			if attack.element != CharacterEnums.Element.NONE:
				var resist: float = CharacterEnums.get_elemental_resistance(char_target.race, attack.element)
				if resist > 0.0:
					damage = maxi(1, int(damage * (1.0 - resist)))

			var actual := char_target.take_damage(damage)
			total_damage += actual
			hit_names.append("%s (%d)" % [char_target.get_display_name(), actual])

			_log_action({
				"type": "action", "actor_id": monster.combat_id, "target_id": char_target.id,
				"action": "attack", "action_name": attack.attack_name,
				"result": "hit", "damage": actual, "healing": 0,
				"target_hp_before": target_hp_before, "target_hp_after": char_target.current_hp,
				"target_max_hp": char_target.max_hp, "is_kill": char_target.is_dead,
			})

			var wake_msg := StatusEffectSystem.wake_on_damage(char_target)
			if wake_msg != "":
				action_performed.emit(wake_msg)

			for snap_msg in StatusEffectSystem.snap_out_on_damage(char_target):
				action_performed.emit(snap_msg)

			_try_apply_attack_effect(attack, char_target)
		else:
			_log_action({
				"type": "action", "actor_id": monster.combat_id, "target_id": char_target.id,
				"action": "attack", "action_name": attack.attack_name,
				"result": "miss", "damage": 0, "healing": 0,
				"target_hp_before": target_hp_before, "target_hp_after": char_target.current_hp,
				"target_max_hp": char_target.max_hp, "is_kill": false,
			})
			miss_names.append(char_target.get_display_name())

	if hit_any:
		action_performed.emit("%s uses %s! Hits: %s" % [
			monster.monster_name,
			attack.attack_name,
			", ".join(hit_names)
		])
	if not miss_names.is_empty():
		action_performed.emit("Misses: %s" % ", ".join(miss_names))

	for target in targets:
		if target is Character and target.is_dead:
			action_performed.emit("%s falls!" % target.get_display_name())
			initiative.remove_combatant(target.id)
	_check_party_row_advance()


func _try_apply_attack_effect(attack: MonsterAttack, target: Character) -> void:
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
			action_performed.emit("%s resists %s!" % [target.get_display_name(), CharacterEnums.get_status_noun(attack.effect_type)])
			return

	var effect_result := StatusEffectSystem.apply_status(target, attack.effect_type, duration, "monster_attack", attack.effect_power)
	if effect_result.message != "":
		action_performed.emit(effect_result.message)


func _get_save_type_from_string(save_str: String) -> CharacterEnums.SaveType:
	match save_str.to_lower():
		"physical": return CharacterEnums.SaveType.PHYSICAL
		"mental": return CharacterEnums.SaveType.MENTAL
		"magical": return CharacterEnums.SaveType.MAGICAL
		"death": return CharacterEnums.SaveType.DEATH
	return -1 as CharacterEnums.SaveType


func _get_monster_disabling_status_name(monster: Monster) -> String:
	if monster.has_status(CharacterEnums.StatusEffect.ASLEEP):
		return "asleep"
	if monster.has_status(CharacterEnums.StatusEffect.PARALYZED):
		return "paralyzed"
	if monster.has_status(CharacterEnums.StatusEffect.STONED):
		return "petrified"
	return "incapacitated"


func _execute_confused_player_turn(character: Character) -> void:
	action_performed.emit("%s is confused!" % character.get_display_name())
	var roll := CombatRNG.randf()

	if roll < CombatConstants.CONFUSED_ACTION_ATTACK:
		var all_targets := _get_all_alive_combatants_except(character)
		if all_targets.is_empty():
			action_performed.emit("%s flails wildly at nothing!" % character.get_display_name())
			return
		var target = all_targets[CombatRNG.randi() % all_targets.size()]
		_execute_mental_player_attack(character, target)

	elif roll < CombatConstants.CONFUSED_ACTION_SPELL:
		var spell := _get_random_low_level_spell_for_character(character)
		if spell == null:
			var all_targets := _get_all_alive_combatants_except(character)
			if all_targets.is_empty():
				action_performed.emit("%s stares blankly into space." % character.get_display_name())
				return
			var target = all_targets[CombatRNG.randi() % all_targets.size()]
			_execute_mental_player_attack(character, target)
			return
		var targets := _get_confused_spell_targets(spell, character)
		_execute_mental_player_spell(character, spell, targets)

	elif roll < CombatConstants.CONFUSED_ACTION_DEFEND:
		character.is_defending = true
		action_performed.emit("%s takes a confused defensive stance." % character.get_display_name())

	else:
		action_performed.emit("%s stares blankly into space." % character.get_display_name())


func _execute_charmed_player_turn(character: Character) -> void:
	action_performed.emit("%s is charmed and turns against the party!" % character.get_display_name())
	var roll := CombatRNG.randf()

	if roll < CombatConstants.CHARMED_ACTION_ATTACK:
		var target := _get_weakest_ally(character)
		if target == null:
			action_performed.emit("%s finds no one to attack." % character.get_display_name())
			return
		_execute_mental_player_attack(character, target)

	elif roll < CombatConstants.CHARMED_ACTION_SPELL:
		var spell := _get_random_low_level_spell_for_character(character)
		if spell == null:
			var target := _get_weakest_ally(character)
			if target == null:
				character.is_defending = true
				action_performed.emit("%s takes a defensive stance." % character.get_display_name())
				return
			_execute_mental_player_attack(character, target)
			return
		var targets := _get_charmed_spell_targets(spell, character)
		_execute_mental_player_spell(character, spell, targets)

	else:
		character.is_defending = true
		action_performed.emit("%s takes a defensive stance." % character.get_display_name())


func _execute_berserk_player_turn(character: Character) -> void:
	action_performed.emit("%s attacks in a berserk rage!" % character.get_display_name())
	var living := get_living_enemies()
	if living.is_empty():
		action_performed.emit("%s rages but finds no enemies!" % character.get_display_name())
		return
	var target: Monster = living[CombatRNG.randi() % living.size()]
	var accuracy_mod := StatusEffectSystem.get_accuracy_modifier(character)
	var result := DamageCalculator.calculate_character_attack(character, target, accuracy_mod)

	var target_hp_before := target.current_hp
	if result.hit:
		var damage: int = int(result.damage * CombatConstants.BERSERK_DAMAGE_MULTIPLIER)
		var actual_damage := target.take_damage(damage)
		action_performed.emit("%s savagely strikes %s for %d damage!" % [
			character.get_display_name(), target.monster_name, actual_damage])
		if target.is_dead:
			action_performed.emit("%s is defeated!" % target.monster_name)
			initiative.remove_combatant(target.combat_id)
	else:
		action_performed.emit("%s swings wildly at %s and misses!" % [
			character.get_display_name(), target.monster_name])


func _execute_confused_monster_turn(monster: Monster) -> void:
	action_performed.emit("%s is confused!" % monster.monster_name)
	var roll := CombatRNG.randf()

	if roll < CombatConstants.CONFUSED_ACTION_ATTACK:
		var all_targets := _get_all_alive_combatants_except_monster(monster)
		if all_targets.is_empty():
			action_performed.emit("%s flails wildly!" % monster.monster_name)
			return
		var target = all_targets[CombatRNG.randi() % all_targets.size()]
		_execute_mental_monster_attack(monster, target)

	elif roll < CombatConstants.CONFUSED_ACTION_SPELL:
		var spell := _get_random_low_level_spell_for_monster(monster)
		if spell == null:
			var all_targets := _get_all_alive_combatants_except_monster(monster)
			if all_targets.is_empty():
				action_performed.emit("%s stumbles around in confusion." % monster.monster_name)
				return
			var target = all_targets[CombatRNG.randi() % all_targets.size()]
			_execute_mental_monster_attack(monster, target)
			return
		var targets := _get_confused_monster_spell_targets(spell, monster)
		_execute_mental_monster_spell(monster, spell, targets)

	elif roll < CombatConstants.CONFUSED_ACTION_DEFEND:
		monster.is_defending = true
		action_performed.emit("%s takes a confused defensive stance." % monster.monster_name)

	else:
		action_performed.emit("%s stumbles around in confusion." % monster.monster_name)


func _execute_charmed_monster_turn(monster: Monster) -> void:
	action_performed.emit("%s is charmed and turns against its allies!" % monster.monster_name)
	var roll := CombatRNG.randf()

	if roll < CombatConstants.CHARMED_ACTION_ATTACK:
		var target := _get_weakest_monster_ally(monster)
		if target == null:
			action_performed.emit("%s finds no allies to attack." % monster.monster_name)
			return
		_execute_mental_monster_attack(monster, target)

	elif roll < CombatConstants.CHARMED_ACTION_SPELL:
		var spell := _get_random_low_level_spell_for_monster(monster)
		if spell == null:
			var target := _get_weakest_monster_ally(monster)
			if target == null:
				monster.is_defending = true
				action_performed.emit("%s takes a defensive stance." % monster.monster_name)
				return
			_execute_mental_monster_attack(monster, target)
			return
		var targets := _get_charmed_monster_spell_targets(spell, monster)
		_execute_mental_monster_spell(monster, spell, targets)

	else:
		monster.is_defending = true
		action_performed.emit("%s takes a defensive stance." % monster.monster_name)


func _execute_berserk_monster_turn(monster: Monster) -> void:
	action_performed.emit("%s attacks in a berserk rage!" % monster.monster_name)
	var target := _get_random_alive_front_party_member()
	if target == null:
		action_performed.emit("%s rages but finds no targets!" % monster.monster_name)
		return
	var attack: MonsterAttack = monster.get_random_attack()
	if attack == null:
		action_performed.emit("%s rages but has no attacks!" % monster.monster_name)
		return
	var evasion_mod := StatusEffectSystem.get_evasion_modifier(target)
	var result := DamageCalculator.calculate_monster_attack(monster, attack, target, evasion_mod)

	if result.hit:
		var damage: int = int(result.damage * CombatConstants.BERSERK_DAMAGE_MULTIPLIER)
		var actual_damage := target.take_damage(damage)
		action_performed.emit("%s savagely strikes %s for %d damage!" % [
			monster.monster_name, target.get_display_name(), actual_damage])
		var wake_msg := StatusEffectSystem.wake_on_damage(target)
		if wake_msg != "":
			action_performed.emit(wake_msg)
		for snap_msg in StatusEffectSystem.snap_out_on_damage(target):
			action_performed.emit(snap_msg)
		if target.is_dead:
			action_performed.emit("%s falls!" % target.get_display_name())
			initiative.remove_combatant(target.id)
			_check_party_row_advance()
	else:
		action_performed.emit("%s swings wildly at %s and misses!" % [
			monster.monster_name, target.get_display_name()])


func _execute_mental_player_attack(attacker: Character, target: Variant) -> void:
	if target is Monster:
		var accuracy_mod := StatusEffectSystem.get_accuracy_modifier(attacker)
		var result := DamageCalculator.calculate_character_attack(attacker, target, accuracy_mod)
		if result.hit:
			var actual: int = target.take_damage(result.damage)
			action_performed.emit("%s attacks %s for %d damage!" % [
				attacker.get_display_name(), target.monster_name, actual])
			var wake_msg := StatusEffectSystem.wake_on_damage(target)
			if wake_msg != "":
				action_performed.emit(wake_msg)
			for snap_msg in StatusEffectSystem.snap_out_on_damage(target):
				action_performed.emit(snap_msg)
			if target.is_dead:
				action_performed.emit("%s is defeated!" % target.monster_name)
				initiative.remove_combatant(target.combat_id)
		else:
			action_performed.emit("%s swings at %s and misses!" % [
				attacker.get_display_name(), target.monster_name])
	elif target is Character:
		var result := DamageCalculator.calculate_generic_attack(
			attacker.accuracy, target.evasion, attacker.weapon_dice, attacker.strength, target.defense)
		if result.hit:
			var actual: int = target.take_damage(result.damage)
			action_performed.emit("%s attacks %s for %d damage!" % [
				attacker.get_display_name(), target.get_display_name(), actual])
			var wake_msg := StatusEffectSystem.wake_on_damage(target)
			if wake_msg != "":
				action_performed.emit(wake_msg)
			for snap_msg in StatusEffectSystem.snap_out_on_damage(target):
				action_performed.emit(snap_msg)
			if target.is_dead:
				action_performed.emit("%s falls!" % target.get_display_name())
				initiative.remove_combatant(target.id)
				_check_party_row_advance()
		else:
			action_performed.emit("%s swings at %s and misses!" % [
				attacker.get_display_name(), target.get_display_name()])


func _execute_mental_monster_attack(monster: Monster, target: Variant) -> void:
	var attack: MonsterAttack = monster.get_random_attack()
	if attack == null:
		action_performed.emit("%s flails wildly!" % monster.monster_name)
		return

	if target is Character:
		var evasion_mod := StatusEffectSystem.get_evasion_modifier(target)
		var result := DamageCalculator.calculate_monster_attack(monster, attack, target, evasion_mod)
		if result.hit:
			var actual: int = target.take_damage(result.damage)
			action_performed.emit("%s attacks %s for %d damage!" % [
				monster.monster_name, target.get_display_name(), actual])
			var wake_msg := StatusEffectSystem.wake_on_damage(target)
			if wake_msg != "":
				action_performed.emit(wake_msg)
			for snap_msg in StatusEffectSystem.snap_out_on_damage(target):
				action_performed.emit(snap_msg)
			if target.is_dead:
				action_performed.emit("%s falls!" % target.get_display_name())
				initiative.remove_combatant(target.id)
				_check_party_row_advance()
		else:
			action_performed.emit("%s swings at %s and misses!" % [
				monster.monster_name, target.get_display_name()])
	elif target is Monster:
		var result := DamageCalculator.calculate_generic_attack(
			attack.accuracy_bonus, target.evasion, attack.damage_dice, monster.strength, target.defense)
		if result.hit:
			var actual_damage := mini(result.damage, target.current_hp)
			target.current_hp -= actual_damage
			if target.current_hp <= 0:
				target.current_hp = 0
				target.is_dead = true
			action_performed.emit("%s attacks %s for %d damage!" % [
				monster.monster_name, target.monster_name, actual_damage])
			if target.is_dead:
				action_performed.emit("%s is defeated!" % target.monster_name)
				initiative.remove_combatant(target.combat_id)
		else:
			action_performed.emit("%s swings at %s and misses!" % [
				monster.monster_name, target.monster_name])


func _execute_mental_player_spell(caster: Character, spell: Spell, targets: Array) -> void:
	var result := SpellCaster.cast_spell(caster, spell, targets, true)
	for msg in result.messages:
		action_performed.emit(msg)
	for target in targets:
		if target is Monster and target.is_dead:
			initiative.remove_combatant(target.combat_id)
		elif target is Character and target.is_dead:
			initiative.remove_combatant(target.id)
			_check_party_row_advance()


func _execute_mental_monster_spell(monster: Monster, spell: Spell, targets: Array) -> void:
	var result := SpellCaster.cast_spell_by_monster(monster, spell, targets)
	for msg in result.messages:
		action_performed.emit(msg)
	for target in targets:
		if target is Monster and target.is_dead:
			initiative.remove_combatant(target.combat_id)
		elif target is Character and target.is_dead:
			initiative.remove_combatant(target.id)
			_check_party_row_advance()


func _get_all_alive_combatants_except(character: Character) -> Array:
	var result: Array = []
	for c in party_members:
		if c != character and not c.is_dead:
			result.append(c)
	for e in enemies:
		if not e.is_dead:
			result.append(e)
	return result


func _get_all_alive_combatants_except_monster(monster: Monster) -> Array:
	var result: Array = []
	for c in party_members:
		if not c.is_dead:
			result.append(c)
	for e in enemies:
		if e != monster and not e.is_dead:
			result.append(e)
	return result


func _get_weakest_ally(character: Character) -> Character:
	var weakest: Character = null
	var lowest_hp := 999999
	for c in party_members:
		if c != character and not c.is_dead and c.current_hp < lowest_hp:
			lowest_hp = c.current_hp
			weakest = c
	return weakest


func _get_weakest_monster_ally(monster: Monster) -> Monster:
	var weakest: Monster = null
	var lowest_hp := 999999
	for e in enemies:
		if e != monster and not e.is_dead and e.current_hp < lowest_hp:
			lowest_hp = e.current_hp
			weakest = e
	return weakest


func _get_most_wounded_enemy() -> Monster:
	var most_wounded: Monster = null
	var lowest_pct := 1.0
	for e in enemies:
		if not e.is_dead:
			var pct := float(e.current_hp) / float(maxi(1, e.max_hp))
			if pct < lowest_pct:
				lowest_pct = pct
				most_wounded = e
	return most_wounded


func _get_most_wounded_party_member() -> Character:
	var most_wounded: Character = null
	var lowest_pct := 1.0
	for c in party_members:
		if not c.is_dead:
			var pct := float(c.current_hp) / float(maxi(1, c.max_hp))
			if pct < lowest_pct:
				lowest_pct = pct
				most_wounded = c
	return most_wounded


func _get_random_low_level_spell_for_character(character: Character) -> Spell:
	var valid_spells: Array[Spell] = []
	for spell_id in character.known_spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell and spell.in_combat and spell.level <= CombatConstants.MENTAL_STATUS_MAX_SPELL_LEVEL:
			if character.current_mp >= spell.mp_cost:
				valid_spells.append(spell)
	if valid_spells.is_empty():
		return null
	return valid_spells[CombatRNG.randi() % valid_spells.size()]


func _get_random_low_level_spell_for_monster(monster: Monster) -> Spell:
	var valid_spells: Array[Spell] = []
	for spell_id in monster.spells:
		var spell := SpellDatabase.get_spell(spell_id)
		if spell and spell.in_combat and spell.level <= CombatConstants.MENTAL_STATUS_MAX_SPELL_LEVEL:
			if monster.current_mp >= spell.mp_cost:
				valid_spells.append(spell)
	if valid_spells.is_empty():
		return null
	return valid_spells[CombatRNG.randi() % valid_spells.size()]


func _get_confused_spell_targets(spell: Spell, caster: Character) -> Array:
	var all_alive: Array = []
	for c in party_members:
		if not c.is_dead:
			all_alive.append(c)
	for e in enemies:
		if not e.is_dead:
			all_alive.append(e)

	match spell.target_type:
		CharacterEnums.SpellTargetType.SELF:
			return [caster]
		CharacterEnums.SpellTargetType.SINGLE_ENEMY, CharacterEnums.SpellTargetType.SINGLE_ALLY:
			if all_alive.is_empty():
				return []
			return [all_alive[CombatRNG.randi() % all_alive.size()]]
		CharacterEnums.SpellTargetType.ALL_ENEMIES:
			if CombatRNG.randf() < 0.5:
				var result: Array = []
				for e in enemies:
					if not e.is_dead:
						result.append(e)
				return result
			else:
				var result: Array = []
				for c in party_members:
					if not c.is_dead:
						result.append(c)
				return result
		CharacterEnums.SpellTargetType.ALL_ALLIES:
			if CombatRNG.randf() < 0.5:
				var result: Array = []
				for c in party_members:
					if not c.is_dead:
						result.append(c)
				return result
			else:
				var result: Array = []
				for e in enemies:
					if not e.is_dead:
						result.append(e)
				return result
		_:
			if all_alive.is_empty():
				return []
			return [all_alive[CombatRNG.randi() % all_alive.size()]]


func _get_charmed_spell_targets(spell: Spell, caster: Character) -> Array:
	match spell.target_type:
		CharacterEnums.SpellTargetType.SELF:
			return [caster]
		CharacterEnums.SpellTargetType.SINGLE_ENEMY:
			var target := _get_weakest_ally(caster)
			return [target] if target else []
		CharacterEnums.SpellTargetType.SINGLE_ALLY:
			var target := _get_most_wounded_enemy()
			return [target] if target else []
		CharacterEnums.SpellTargetType.ALL_ENEMIES:
			var result: Array = []
			for c in party_members:
				if not c.is_dead:
					result.append(c)
			return result
		CharacterEnums.SpellTargetType.ALL_ALLIES:
			var result: Array = []
			for e in enemies:
				if not e.is_dead:
					result.append(e)
			return result
		CharacterEnums.SpellTargetType.DEAD_ALLY:
			return []
		_:
			var target := _get_weakest_ally(caster)
			return [target] if target else []


func _get_confused_monster_spell_targets(spell: Spell, caster: Monster) -> Array:
	var all_alive: Array = []
	for c in party_members:
		if not c.is_dead:
			all_alive.append(c)
	for e in enemies:
		if not e.is_dead:
			all_alive.append(e)

	match spell.target_type:
		CharacterEnums.SpellTargetType.SELF:
			return [caster]
		CharacterEnums.SpellTargetType.SINGLE_ENEMY, CharacterEnums.SpellTargetType.SINGLE_ALLY:
			if all_alive.is_empty():
				return []
			return [all_alive[CombatRNG.randi() % all_alive.size()]]
		CharacterEnums.SpellTargetType.ALL_ENEMIES:
			if CombatRNG.randf() < 0.5:
				var result: Array = []
				for c in party_members:
					if not c.is_dead:
						result.append(c)
				return result
			else:
				var result: Array = []
				for e in enemies:
					if not e.is_dead:
						result.append(e)
				return result
		CharacterEnums.SpellTargetType.ALL_ALLIES:
			if CombatRNG.randf() < 0.5:
				var result: Array = []
				for e in enemies:
					if not e.is_dead:
						result.append(e)
				return result
			else:
				var result: Array = []
				for c in party_members:
					if not c.is_dead:
						result.append(c)
				return result
		_:
			if all_alive.is_empty():
				return []
			return [all_alive[CombatRNG.randi() % all_alive.size()]]


func _get_charmed_monster_spell_targets(spell: Spell, caster: Monster) -> Array:
	match spell.target_type:
		CharacterEnums.SpellTargetType.SELF:
			return [caster]
		CharacterEnums.SpellTargetType.SINGLE_ENEMY:
			var target := _get_weakest_monster_ally(caster)
			return [target] if target else []
		CharacterEnums.SpellTargetType.SINGLE_ALLY:
			var target := _get_most_wounded_party_member()
			return [target] if target else []
		CharacterEnums.SpellTargetType.ALL_ENEMIES:
			var result: Array = []
			for e in enemies:
				if e != caster and not e.is_dead:
					result.append(e)
			return result
		CharacterEnums.SpellTargetType.ALL_ALLIES:
			var result: Array = []
			for c in party_members:
				if not c.is_dead:
					result.append(c)
			return result
		_:
			var target := _get_weakest_monster_ally(caster)
			return [target] if target else []


func _check_combat_end() -> void:
	if _all_enemies_dead():
		var total_exp := 0
		var total_gold := 0
		for enemy in enemies:
			total_exp += enemy.exp_reward
			total_gold += DamageCalculator.roll_dice(enemy.gold_reward_dice)

		if is_boss_encounter:
			total_exp = int(total_exp * 1.5)
			total_gold = int(total_gold * 2.0)

		var floor_level: int = GameState.current_floor
		var party_luck: int = party.get_average_luck() if party else 10
		var loot: Array[Item] = LootGenerator.generate_combat_loot(enemies, floor_level, party_luck)

		var loot_msg := ""
		if not loot.is_empty():
			loot_msg = " Found %d item(s)!" % loot.size()
		action_performed.emit("Victory! Gained %d EXP and %d gold.%s" % [total_exp, total_gold, loot_msg])
		_end_combat(true, total_exp, total_gold, loot)
		return

	if _all_party_dead():
		action_performed.emit("The party has been defeated...")
		_end_combat(false, 0, 0, [])
		return

	_advance_turn()


func _all_enemies_dead() -> bool:
	for enemy in enemies:
		if not enemy.is_dead:
			return false
	return true


func _all_party_dead() -> bool:
	for character in party_members:
		if not character.is_dead:
			return false
	return true


func _end_combat(victory: bool, xp: int, gold: int, loot: Array[Item]) -> void:
	var surviving_ids: Array[String] = []
	var dead_ids: Array[String] = []
	for c in party_members:
		if c.is_dead:
			dead_ids.append(c.id)
		else:
			surviving_ids.append(c.id)
	_log_action({
		"type": "combat_end",
		"result": "victory" if victory else "defeat",
		"floor": GameState.current_floor,
		"is_boss": is_boss_encounter,
		"xp_gained": xp, "gold_gained": gold,
		"loot_count": loot.size(),
		"surviving_ids": surviving_ids, "dead_ids": dead_ids,
		"turn_count": _turn_count,
	})

	is_active = false
	waiting_for_player = false
	waiting_for_target = false
	combat_ended.emit(victory, xp, gold, loot)


func _get_character(id: String) -> Character:
	for character in party_members:
		if character.id == id:
			return character
	return null


func _get_enemy_by_combat_id(combat_id: String) -> Monster:
	for enemy in enemies:
		if enemy.combat_id == combat_id:
			return enemy
	return null


func _get_random_alive_front_party_member() -> Character:
	var front := party.get_front_row()
	var alive_front: Array[Character] = []
	for character in front:
		if not character.is_dead:
			alive_front.append(character)

	if not alive_front.is_empty():
		return alive_front[CombatRNG.randi() % alive_front.size()]

	var back := party.get_back_row()
	var alive_back: Array[Character] = []
	for character in back:
		if not character.is_dead:
			alive_back.append(character)

	if not alive_back.is_empty():
		return alive_back[CombatRNG.randi() % alive_back.size()]

	return null


## Returns all enemies in the current combat (including dead ones).
## [return]: Array of all monsters.
func get_enemies() -> Array[Monster]:
	return enemies


## Returns only living enemies in the current combat.
## [return]: Array of living monsters.
func get_living_enemies() -> Array[Monster]:
	return Targeting.get_living_enemies(enemies)


## Returns the enemy at a specific grid position.
## [param pos]: Grid coordinates (x=column, y=row).
## [return]: Monster at that position or null.
func get_enemy_at(pos: Vector2i) -> Monster:
	for enemy in enemies:
		if not enemy.is_dead and enemy.grid_position == pos:
			return enemy
	return null


func get_enemies_in_row(row: int) -> Array[Monster]:
	var result: Array[Monster] = []
	for enemy in enemies:
		if enemy.get_row() == row and not enemy.is_dead:
			result.append(enemy)
	return result


func get_party() -> Array[Character]:
	return party_members


func get_party_resource() -> Party:
	return party


## Returns true if the system is waiting for player input.
## [return]: Whether it's currently a player's turn.
func is_player_turn() -> bool:
	return waiting_for_player


func is_waiting_for_target() -> bool:
	return waiting_for_target


## Cancels the current target selection request.
func cancel_target_selection() -> void:
	waiting_for_target = false


## Ends the current player's turn after item use or other non-standard actions.
func end_player_turn() -> void:
	if not waiting_for_player or not is_active:
		return

	waiting_for_player = false
	waiting_for_target = false
	initiative.apply_action_delay(current_combatant_id)
	_check_combat_end()


func _check_party_row_advance() -> void:
	if party == null:
		return
	if party.advance_back_row_if_front_wiped():
		action_performed.emit("The back row advances to the front!")
		layout_changed.emit()
