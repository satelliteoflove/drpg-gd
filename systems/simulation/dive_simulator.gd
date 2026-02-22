class_name DiveSimulator
extends RefCounted

signal encounter_completed(encounter_num: int, result: Dictionary)
signal dive_completed(result: Dictionary)

var _dice_regex: RegEx = null


func run_dive(
	party: Party,
	floor_level: int,
	max_encounters: int,
	base_seed: int = 0,
	cast_threshold: float = PartyAI.DEFAULT_CAST_THRESHOLD,
	strategy: PartyAI.Strategy = PartyAI.Strategy.BALANCED,
	rest_hp_percent: float = 0.0,
	rest_mp_percent: float = 0.0
) -> Dictionary:
	var encounters_won := 0
	var total_turns := 0
	var total_xp := 0
	var encounter_results: Array[Dictionary] = []
	var total_hp_restored := 0
	var total_mp_restored := 0

	var starting_hp := _get_party_total_hp(party)
	var starting_mp := _get_party_total_mp(party)

	for i in range(max_encounters):
		if _party_wiped(party):
			break

		var seed_value := base_seed + i * 100
		var enemies := TestFixtures.create_floor_encounter(floor_level)

		var simulator := CombatSimulator.new()
		simulator.cast_threshold = cast_threshold
		simulator.party_strategy = strategy
		simulator.setup(party, enemies, seed_value)
		var result := simulator.run()

		encounter_results.append(result)
		total_turns += result.turns
		total_xp += result.metrics.get("total_xp_earned", 0)

		if result.victory:
			encounters_won += 1
			encounter_completed.emit(i + 1, result)

			if rest_hp_percent > 0.0 or rest_mp_percent > 0.0:
				var restored := _rest_party(party, rest_hp_percent, rest_mp_percent)
				total_hp_restored += restored.hp
				total_mp_restored += restored.mp
		else:
			encounter_completed.emit(i + 1, result)
			break

	var ending_hp := _get_party_total_hp(party)
	var ending_mp := _get_party_total_mp(party)
	var survivors := _count_survivors(party)

	var dive_result := {
		"floor_level": floor_level,
		"max_encounters": max_encounters,
		"encounters_completed": encounters_won,
		"total_turns": total_turns,
		"total_xp": total_xp,
		"xp_per_encounter": float(total_xp) / float(maxi(1, encounters_won)),
		"starting_hp": starting_hp,
		"ending_hp": ending_hp,
		"hp_used": starting_hp - ending_hp,
		"hp_restored": total_hp_restored,
		"net_hp_cost": (starting_hp - ending_hp) + total_hp_restored,
		"starting_mp": starting_mp,
		"ending_mp": ending_mp,
		"mp_used": starting_mp - ending_mp,
		"mp_restored": total_mp_restored,
		"net_mp_cost": (starting_mp - ending_mp) + total_mp_restored,
		"survivors": survivors,
		"party_wiped": _party_wiped(party),
		"cast_threshold": cast_threshold,
		"rest_hp_percent": rest_hp_percent,
		"rest_mp_percent": rest_mp_percent,
		"encounters": encounter_results
	}

	dive_completed.emit(dive_result)
	return dive_result


func run_dive_batch(
	party: Party,
	floor_level: int,
	max_encounters: int,
	num_dives: int,
	base_seed: int = 0,
	cast_threshold: float = PartyAI.DEFAULT_CAST_THRESHOLD,
	strategy: PartyAI.Strategy = PartyAI.Strategy.BALANCED,
	rest_hp_percent: float = 0.0,
	rest_mp_percent: float = 0.0
) -> Dictionary:
	var total_encounters := 0
	var total_xp := 0
	var total_wipes := 0
	var total_net_hp := 0
	var total_net_mp := 0
	var dive_results: Array[Dictionary] = []

	for i in range(num_dives):
		var party_copy := _duplicate_party(party)
		var seed_value := base_seed + i * 10000

		var result := run_dive(
			party_copy, floor_level, max_encounters, seed_value,
			cast_threshold, strategy, rest_hp_percent, rest_mp_percent
		)

		dive_results.append(result)
		total_encounters += result.encounters_completed
		total_xp += result.total_xp
		total_net_hp += result.net_hp_cost
		total_net_mp += result.net_mp_cost
		if result.party_wiped:
			total_wipes += 1

	var avg_encounters := float(total_encounters) / float(num_dives)
	var avg_xp := float(total_xp) / float(num_dives)
	var avg_net_hp := float(total_net_hp) / float(num_dives)
	var avg_net_mp := float(total_net_mp) / float(num_dives)
	var wipe_rate := float(total_wipes) / float(num_dives) * 100.0
	var survival_rate := 100.0 - wipe_rate

	return {
		"num_dives": num_dives,
		"floor_level": floor_level,
		"max_encounters": max_encounters,
		"cast_threshold": cast_threshold,
		"rest_hp_percent": rest_hp_percent,
		"rest_mp_percent": rest_mp_percent,
		"avg_encounters_per_dive": avg_encounters,
		"avg_xp_per_dive": avg_xp,
		"avg_net_hp_cost": avg_net_hp,
		"avg_net_mp_cost": avg_net_mp,
		"survival_rate": survival_rate,
		"wipe_rate": wipe_rate,
		"total_wipes": total_wipes,
		"dive_results": dive_results
	}


func compare_thresholds(
	party: Party,
	floor_level: int,
	max_encounters: int,
	num_dives: int,
	thresholds: Array[float],
	base_seed: int = 0
) -> Dictionary:
	var comparison: Array[Dictionary] = []

	for threshold in thresholds:
		var party_copy := _duplicate_party(party)
		var result := run_dive_batch(
			party_copy, floor_level, max_encounters, num_dives,
			base_seed, threshold
		)
		result["threshold"] = threshold
		comparison.append(result)

	var best_threshold := 0.0
	var best_xp := 0.0
	for result in comparison:
		if result.avg_xp_per_dive > best_xp:
			best_xp = result.avg_xp_per_dive
			best_threshold = result.threshold

	return {
		"comparison": comparison,
		"best_threshold": best_threshold,
		"best_avg_xp": best_xp
	}


func run_floor_dive(
	party: Party,
	floor_level: int,
	num_normal_encounters: int,
	include_boss: bool,
	base_seed: int = 0,
	cast_threshold: float = PartyAI.DEFAULT_CAST_THRESHOLD,
	strategy: PartyAI.Strategy = PartyAI.Strategy.BALANCED,
	return_encounters: int = 0
) -> Dictionary:
	var encounters_won := 0
	var total_turns := 0
	var total_xp := 0
	var encounter_snapshots: Array[Dictionary] = []
	var total_potions_used := 0
	var total_healing_hp := 0
	var total_healing_mp := 0
	var deaths: Array[String] = []
	var wipe_encounter := 0
	var wiped_during_return := false
	var total_gold := 0
	var total_loot_items := 0
	var total_loot_value := 0
	var total_healing_potions := 0
	var total_greater_healing := 0
	var total_mana_potions := 0
	var total_antidotes := 0
	var retreated := false
	var retreat_reason := ""
	var retreat_after_encounter := 0

	for i in range(num_normal_encounters):
		if _party_wiped(party):
			break

		var alive_before: Array[String] = []
		for member in party.get_members():
			if not member.is_dead:
				alive_before.append(member.character_name)

		var seed_value := base_seed + i * 100
		var enemies := TestFixtures.create_floor_encounter(floor_level)

		var enemy_names: Array[String] = []
		var enemy_total_hp := 0
		for e in enemies:
			enemy_names.append(e.monster_name)
			enemy_total_hp += e.max_hp

		var simulator := CombatSimulator.new()
		simulator.cast_threshold = cast_threshold
		simulator.party_strategy = strategy
		simulator.setup(party, enemies, seed_value)
		var result := simulator.run()

		total_turns += result.turns
		total_xp += result.metrics.get("total_xp_earned", 0)

		var encounter_deaths: Array[String] = []
		for cname in alive_before:
			var still_alive := false
			for member in party.get_members():
				if member.character_name == cname and not member.is_dead:
					still_alive = true
					break
			if not still_alive:
				encounter_deaths.append(cname)
				if not deaths.has(cname):
					deaths.append(cname)

		if result.victory:
			encounters_won += 1
			var healing := _heal_between_combats(party)
			total_healing_hp += healing.hp_restored
			total_healing_mp += healing.mp_spent
			total_potions_used += healing.potions_used
			total_healing_potions += healing.healing_potions_used
			total_greater_healing += healing.greater_healing_used
			total_mana_potions += healing.mana_potions_used
			total_antidotes += healing.antidotes_used

			var gold := _roll_encounter_gold(enemies, false)
			total_gold += gold
			var loot := _roll_encounter_loot(enemies, party, floor_level)
			total_loot_items += loot.size()
			for li in loot:
				total_loot_value += li.sell_price

			var snapshot := _take_encounter_snapshot(
				party, i + 1, result, healing, enemy_names, enemy_total_hp
			)
			snapshot["deaths_this_encounter"] = encounter_deaths
			snapshot["surprise"] = result.get("surprise", "none")
			snapshot["stalemate"] = result.get("stalemate", false)
			encounter_snapshots.append(snapshot)

			var retreat := _should_retreat(party)
			if retreat.should_retreat:
				var is_last_enc := (i == num_normal_encounters - 1)
				if not is_last_enc or include_boss:
					retreated = true
					retreat_reason = retreat.reason
					retreat_after_encounter = i + 1
					break
		else:
			wipe_encounter = i + 1
			var snapshot := _take_encounter_snapshot(
				party, i + 1, result, {}, enemy_names, enemy_total_hp
			)
			snapshot["deaths_this_encounter"] = encounter_deaths
			snapshot["surprise"] = result.get("surprise", "none")
			snapshot["stalemate"] = result.get("stalemate", false)
			encounter_snapshots.append(snapshot)
			break

	var boss_result: Dictionary = {}
	if include_boss and not _party_wiped(party) and not retreated:
		var boss := MonsterDatabase.get_boss_for_floor(floor_level)
		if boss:
			var alive_before: Array[String] = []
			for member in party.get_members():
				if not member.is_dead:
					alive_before.append(member.character_name)

			var boss_enemies: Array[Monster] = []
			boss.grid_position = Vector2i(1, 0)
			boss.init_combat()
			boss_enemies.append(boss)

			var enemy_names: Array[String] = [boss.monster_name]
			var enemy_total_hp := boss.max_hp

			var minion_ids := MonsterDatabase.get_boss_minions(floor_level)
			var minion_positions := [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1)]
			for mi in range(minion_ids.size()):
				var minion := MonsterDatabase.get_monster(minion_ids[mi])
				if minion and mi < minion_positions.size():
					minion.grid_position = minion_positions[mi]
					minion.init_combat()
					boss_enemies.append(minion)
					enemy_names.append(minion.monster_name)
					enemy_total_hp += minion.max_hp

			var seed_value := base_seed + num_normal_encounters * 100
			var simulator := CombatSimulator.new()
			simulator.cast_threshold = cast_threshold
			simulator.party_strategy = strategy
			simulator.setup(party, boss_enemies, seed_value)
			boss_result = simulator.run()

			total_turns += boss_result.turns
			total_xp += boss_result.metrics.get("total_xp_earned", 0)

			var encounter_deaths: Array[String] = []
			for cname in alive_before:
				var still_alive := false
				for member in party.get_members():
					if member.character_name == cname and not member.is_dead:
						still_alive = true
						break
				if not still_alive:
					encounter_deaths.append(cname)
					if not deaths.has(cname):
						deaths.append(cname)

			if boss_result.victory:
				encounters_won += 1
				var gold := _roll_encounter_gold(boss_enemies, true)
				total_gold += gold
				var loot := _roll_encounter_loot(boss_enemies, party, floor_level)
				total_loot_items += loot.size()
				for li in loot:
					total_loot_value += li.sell_price
			else:
				wipe_encounter = num_normal_encounters + 1

			var snapshot := _take_encounter_snapshot(
				party, num_normal_encounters + 1, boss_result, {},
				enemy_names, enemy_total_hp
			)
			snapshot["is_boss"] = true
			snapshot["deaths_this_encounter"] = encounter_deaths
			snapshot["surprise"] = boss_result.get("surprise", "none")
			snapshot["stalemate"] = boss_result.get("stalemate", false)
			encounter_snapshots.append(snapshot)

	var return_snapshots: Array[Dictionary] = []
	var return_seed_offset := (num_normal_encounters + 2) * 100
	if return_encounters > 0 and not _party_wiped(party):
		for ri in range(return_encounters):
			if _party_wiped(party):
				break

			var alive_before: Array[String] = []
			for member in party.get_members():
				if not member.is_dead:
					alive_before.append(member.character_name)

			var seed_value := base_seed + return_seed_offset + ri * 100
			var enemies := TestFixtures.create_floor_encounter(floor_level)

			var enemy_names: Array[String] = []
			var enemy_total_hp := 0
			for e in enemies:
				enemy_names.append(e.monster_name)
				enemy_total_hp += e.max_hp

			var simulator := CombatSimulator.new()
			simulator.cast_threshold = cast_threshold
			simulator.party_strategy = strategy
			simulator.setup(party, enemies, seed_value)
			var result := simulator.run()

			total_turns += result.turns

			var encounter_deaths: Array[String] = []
			for cname in alive_before:
				var still_alive := false
				for member in party.get_members():
					if member.character_name == cname and not member.is_dead:
						still_alive = true
						break
				if not still_alive:
					encounter_deaths.append(cname)
					if not deaths.has(cname):
						deaths.append(cname)

			var snapshot := _take_encounter_snapshot(
				party, ri + 1, result, {}, enemy_names, enemy_total_hp
			)
			snapshot["is_return"] = true
			snapshot["deaths_this_encounter"] = encounter_deaths
			snapshot["surprise"] = result.get("surprise", "none")
			snapshot["stalemate"] = result.get("stalemate", false)
			return_snapshots.append(snapshot)

			if result.victory:
				var gold := _roll_encounter_gold(enemies, false)
				total_gold += gold
				var loot := _roll_encounter_loot(enemies, party, floor_level)
				total_loot_items += loot.size()
				for li in loot:
					total_loot_value += li.sell_price
			else:
				wiped_during_return = true
				wipe_encounter = -(ri + 1)
				break

	return {
		"floor_level": floor_level,
		"num_normal_encounters": num_normal_encounters,
		"include_boss": include_boss,
		"return_encounters": return_encounters,
		"encounters_won": encounters_won,
		"total_turns": total_turns,
		"total_xp": total_xp,
		"survivors": _count_survivors(party),
		"party_wiped": _party_wiped(party),
		"wiped_during_return": wiped_during_return,
		"wipe_encounter": wipe_encounter,
		"deaths": deaths,
		"total_healing_hp": total_healing_hp,
		"total_healing_mp": total_healing_mp,
		"total_potions_used": total_potions_used,
		"encounter_snapshots": encounter_snapshots,
		"return_snapshots": return_snapshots,
		"boss_victory": boss_result.get("victory", false) if not boss_result.is_empty() else false,
		"boss_hp_pct_entering": _get_pre_boss_hp_pct(encounter_snapshots, include_boss),
		"total_gold": total_gold,
		"total_loot_items": total_loot_items,
		"total_loot_value": total_loot_value,
		"healing_potions_used": total_healing_potions,
		"greater_healing_used": total_greater_healing,
		"mana_potions_used": total_mana_potions,
		"antidotes_used": total_antidotes,
		"retreated": retreated,
		"retreat_reason": retreat_reason,
		"retreat_after_encounter": retreat_after_encounter,
	}


func _heal_between_combats(party: Party) -> Dictionary:
	var metrics := {
		"hp_restored": 0, "mp_spent": 0, "potions_used": 0,
		"healing_potions_used": 0, "greater_healing_used": 0,
		"mana_potions_used": 0, "antidotes_used": 0,
	}

	_cure_status_effects(party, metrics)

	for healer in party.get_members():
		if healer.is_dead:
			continue
		var healing_spells := _get_out_of_combat_healing_spells(healer)
		if healing_spells.is_empty():
			continue
		var reserve := _get_mp_reserve(healer)

		while true:
			var target := _find_most_hurt_member(party)
			if target == null:
				break
			var spell := _pick_efficient_spell(healer, healing_spells, target)
			if spell == null:
				break
			if healer.current_mp < spell.mp_cost + reserve:
				if not _use_mana_potion(party, healer, metrics):
					break
				if healer.current_mp < spell.mp_cost + reserve:
					break
			var result := SpellCaster.cast_spell(healer, spell, [target], false)
			metrics.hp_restored += result.total_healing
			metrics.mp_spent += result.mp_consumed

	var potion_result := _use_healing_potions(party)
	metrics.hp_restored += potion_result.hp_restored
	metrics.potions_used += potion_result.potions_used
	metrics.healing_potions_used += potion_result.healing_potions_used
	metrics.greater_healing_used += potion_result.greater_healing_used

	return metrics


func _cure_status_effects(party: Party, metrics: Dictionary) -> void:
	for healer in party.get_members():
		if healer.is_dead:
			continue
		var cure_spells := _get_out_of_combat_cure_spells(healer)
		if cure_spells.is_empty():
			continue
		for target in party.get_members():
			if target.is_dead:
				continue
			for spell in cure_spells:
				if healer.current_mp < spell.mp_cost:
					continue
				if not _spell_cures_target(spell, target):
					continue
				var result := SpellCaster.cast_spell(healer, spell, [target], false)
				metrics.mp_spent = metrics.get("mp_spent", 0) + result.mp_consumed
				break

	for member in party.get_members():
		if member.is_dead:
			continue
		if member.has_status(CharacterEnums.StatusEffect.POISONED):
			if party.inventory.has_item("antidote"):
				member.remove_status(CharacterEnums.StatusEffect.POISONED)
				party.inventory.remove_item("antidote", 1)
				metrics.potions_used = metrics.get("potions_used", 0) + 1
				metrics.antidotes_used = metrics.get("antidotes_used", 0) + 1


func _use_healing_potions(party: Party) -> Dictionary:
	var result := {"hp_restored": 0, "potions_used": 0, "healing_potions_used": 0, "greater_healing_used": 0}
	var critical_threshold := 0.4

	var hurt_members: Array[Character] = []
	for member in party.get_members():
		if member.is_dead:
			continue
		if float(member.current_hp) / float(maxi(1, member.max_hp)) < critical_threshold:
			hurt_members.append(member)

	hurt_members.sort_custom(func(a: Character, b: Character) -> bool:
		return float(a.current_hp) / float(maxi(1, a.max_hp)) < float(b.current_hp) / float(maxi(1, b.max_hp))
	)

	for member in hurt_members:
		var potion_id := ""
		if party.inventory.has_item("greater_healing"):
			potion_id = "greater_healing"
		elif party.inventory.has_item("healing_potion"):
			potion_id = "healing_potion"
		else:
			break

		var item := ShopItems.get_item(potion_id)
		if item == null:
			continue

		var healed := member.heal(item.heal_amount)
		party.inventory.remove_item(potion_id, 1)
		result.hp_restored += healed
		result.potions_used += 1
		if potion_id == "greater_healing":
			result.greater_healing_used += 1
		else:
			result.healing_potions_used += 1

	return result


func _get_out_of_combat_healing_spells(character: Character) -> Array[Spell]:
	var healing_spells: Array[Spell] = []
	for spell_id in character.known_spells:
		var spell: Spell = SpellDatabase.get_spell(spell_id)
		if spell == null:
			continue
		if not spell.out_of_combat:
			continue
		var has_heal := false
		for effect in spell.effects:
			if effect.effect_type == SpellEffect.EffectType.HEAL:
				has_heal = true
				break
		if has_heal:
			healing_spells.append(spell)
	healing_spells.sort_custom(func(a: Spell, b: Spell) -> bool:
		return a.mp_cost < b.mp_cost
	)
	return healing_spells


func _get_out_of_combat_cure_spells(character: Character) -> Array[Spell]:
	var cure_spells: Array[Spell] = []
	for spell_id in character.known_spells:
		var spell: Spell = SpellDatabase.get_spell(spell_id)
		if spell == null:
			continue
		if not spell.out_of_combat:
			continue
		var has_cure := false
		for effect in spell.effects:
			if effect.effect_type == SpellEffect.EffectType.CURE:
				has_cure = true
				break
		if has_cure:
			cure_spells.append(spell)
	cure_spells.sort_custom(func(a: Spell, b: Spell) -> bool:
		return a.mp_cost < b.mp_cost
	)
	return cure_spells


func _spell_cures_target(spell: Spell, target: Character) -> bool:
	for effect in spell.effects:
		if effect.effect_type != SpellEffect.EffectType.CURE:
			continue
		match effect.cure_group:
			"poison":
				if target.has_status(CharacterEnums.StatusEffect.POISONED):
					return true
			"paralysis":
				if target.has_status(CharacterEnums.StatusEffect.PARALYZED):
					return true
			"mental":
				if target.has_status(CharacterEnums.StatusEffect.ASLEEP) or \
				   target.has_status(CharacterEnums.StatusEffect.AFRAID) or \
				   target.has_status(CharacterEnums.StatusEffect.CONFUSED):
					return true
			"all":
				for status in [
					CharacterEnums.StatusEffect.POISONED,
					CharacterEnums.StatusEffect.PARALYZED,
					CharacterEnums.StatusEffect.ASLEEP,
					CharacterEnums.StatusEffect.AFRAID,
					CharacterEnums.StatusEffect.CONFUSED,
					CharacterEnums.StatusEffect.CURSED,
				]:
					if target.has_status(status):
						return true
	return false


func _estimate_avg_healing(caster: Character, spell: Spell) -> float:
	for effect in spell.effects:
		if effect.effect_type == SpellEffect.EffectType.HEAL:
			if effect.full_heal:
				return 9999.0
			var avg := _avg_dice(effect.heal_dice)
			avg += effect.heal_per_level * caster.level
			var spell_power := SpellCaster._calculate_spell_power(caster)
			return avg * spell_power / 100.0
	return 0.0


func _avg_dice(dice_str: String) -> float:
	if _dice_regex == null:
		_dice_regex = RegEx.new()
		_dice_regex.compile("(\\d+)d(\\d+)([+-]\\d+)?")
	var result := _dice_regex.search(dice_str)
	if not result:
		return 0.0
	var count := float(result.get_string(1))
	var sides := float(result.get_string(2))
	var modifier := 0.0
	if result.get_string(3) != "":
		modifier = float(result.get_string(3))
	return count * (sides + 1.0) / 2.0 + modifier


func _get_mp_reserve(character: Character) -> int:
	var cheapest_combat_heal_cost := 999
	for spell_id in character.known_spells:
		var spell: Spell = SpellDatabase.get_spell(spell_id)
		if spell == null:
			continue
		if not spell.in_combat:
			continue
		var has_heal := false
		for effect in spell.effects:
			if effect.effect_type == SpellEffect.EffectType.HEAL:
				has_heal = true
				break
		if has_heal and spell.mp_cost < cheapest_combat_heal_cost:
			cheapest_combat_heal_cost = spell.mp_cost
	if cheapest_combat_heal_cost == 999:
		return 0
	return cheapest_combat_heal_cost * 2


func _find_most_hurt_member(party: Party) -> Character:
	var most_hurt: Character = null
	var most_missing := 0
	for member in party.get_members():
		if member.is_dead:
			continue
		var missing := member.max_hp - member.current_hp
		if missing > most_missing:
			most_missing = missing
			most_hurt = member
	return most_hurt


func _pick_efficient_spell(caster: Character, spells: Array[Spell], target: Character) -> Spell:
	var missing_hp := target.max_hp - target.current_hp
	for spell in spells:
		var avg := _estimate_avg_healing(caster, spell)
		if missing_hp >= avg * 0.5:
			return spell
	return null


func _take_encounter_snapshot(
	party: Party,
	encounter_num: int,
	combat_result: Dictionary,
	healing_metrics: Dictionary,
	enemy_names: Array[String],
	enemy_total_hp: int
) -> Dictionary:
	var total_hp := 0
	var total_max_hp := 0
	var total_mp := 0
	var total_max_mp := 0
	var alive := 0

	for member in party.get_members():
		total_max_hp += member.max_hp
		total_max_mp += member.max_mp
		if not member.is_dead:
			total_hp += member.current_hp
			total_mp += member.current_mp
			alive += 1

	var hp_pct := 0.0
	if total_max_hp > 0:
		hp_pct = float(total_hp) / float(total_max_hp) * 100.0
	var mp_pct := 0.0
	if total_max_mp > 0:
		mp_pct = float(total_mp) / float(total_max_mp) * 100.0

	var statuses_applied := _count_statuses_on_party(
		combat_result.get("metrics", {}).get("status_effects_applied", {})
	)

	return {
		"encounter_num": encounter_num,
		"victory": combat_result.victory,
		"turns": combat_result.turns,
		"party_hp_pct": hp_pct,
		"party_mp_pct": mp_pct,
		"survivors": alive,
		"enemy_names": enemy_names,
		"enemy_total_hp": enemy_total_hp,
		"healing_hp": healing_metrics.get("hp_restored", 0),
		"healing_mp_spent": healing_metrics.get("mp_spent", 0),
		"potions_used": healing_metrics.get("potions_used", 0),
		"is_boss": false,
		"deaths_this_encounter": [] as Array[String],
		"statuses_applied": statuses_applied,
	}


func _get_pre_boss_hp_pct(snapshots: Array[Dictionary], include_boss: bool) -> float:
	if not include_boss or snapshots.size() < 2:
		return 0.0
	var last_normal := snapshots[snapshots.size() - 2] if snapshots.size() >= 2 else {}
	return last_normal.get("party_hp_pct", 0.0)


func _use_mana_potion(party: Party, healer: Character, metrics: Dictionary) -> bool:
	if not party.inventory.has_item("mana_potion"):
		return false
	var item := ShopItems.get_item("mana_potion")
	if item == null:
		return false
	healer.restore_mp(item.mp_restore)
	party.inventory.remove_item("mana_potion", 1)
	metrics.mana_potions_used = metrics.get("mana_potions_used", 0) + 1
	metrics.potions_used = metrics.get("potions_used", 0) + 1
	return true


func _should_retreat(party: Party) -> Dictionary:
	if party.inventory.slots.size() >= Inventory.MAX_SLOTS - 2:
		return {"should_retreat": true, "reason": "inventory_full"}

	var any_healer_can_heal := false
	for member in party.get_members():
		if member.is_dead:
			continue
		var spells := _get_out_of_combat_healing_spells(member)
		if spells.is_empty():
			continue
		var reserve := _get_mp_reserve(member)
		if member.current_mp >= spells[0].mp_cost + reserve:
			any_healer_can_heal = true
			break

	if not any_healer_can_heal:
		if not party.inventory.has_item("mana_potion"):
			return {"should_retreat": true, "reason": "healers_exhausted"}

	return {"should_retreat": false, "reason": ""}


func _roll_encounter_gold(enemies: Array, is_boss: bool) -> int:
	var total := 0
	for e in enemies:
		if e is Monster:
			total += DamageCalculator.roll_dice(e.gold_reward_dice)
	if is_boss:
		total = int(total * 2.0)
	return total


func _roll_encounter_loot(enemies: Array, party: Party, floor_level: int) -> Array[Item]:
	var party_luck := party.get_average_luck() if party else 10
	var loot := LootGenerator.generate_combat_loot(enemies, floor_level, party_luck)
	for item in loot:
		party.inventory.add_item(item, 1)
	return loot


func _get_party_total_hp(party: Party) -> int:
	var total := 0
	for member in party.get_members():
		if not member.is_dead:
			total += member.current_hp
	return total


func _get_party_total_mp(party: Party) -> int:
	var total := 0
	for member in party.get_members():
		if not member.is_dead:
			total += member.current_mp
	return total


func _party_wiped(party: Party) -> bool:
	for member in party.get_members():
		if not member.is_dead:
			return false
	return true


func _count_survivors(party: Party) -> int:
	var count := 0
	for member in party.get_members():
		if not member.is_dead:
			count += 1
	return count


func _rest_party(party: Party, hp_percent: float, mp_percent: float) -> Dictionary:
	var total_hp_restored := 0
	var total_mp_restored := 0

	for member in party.get_members():
		if member.is_dead:
			continue

		var hp_to_restore := int(float(member.max_hp) * hp_percent)
		var mp_to_restore := int(float(member.max_mp) * mp_percent)

		var actual_hp := member.heal(hp_to_restore)
		var actual_mp := member.restore_mp(mp_to_restore)

		total_hp_restored += actual_hp
		total_mp_restored += actual_mp

	return {"hp": total_hp_restored, "mp": total_mp_restored}


func _count_statuses_on_party(status_dict: Dictionary) -> Dictionary:
	var counts := {"poison": 0, "paralysis": 0, "other": 0}
	for key in status_dict:
		var statuses: Array = status_dict[key]
		for status_val in statuses:
			match status_val:
				CharacterEnums.StatusEffect.POISONED:
					counts["poison"] += 1
				CharacterEnums.StatusEffect.PARALYZED:
					counts["paralysis"] += 1
				_:
					counts["other"] += 1
	return counts


func _duplicate_party(party: Party) -> Party:
	var new_party := Party.new()
	for member in party.get_members():
		var copy := member.duplicate(true) as Character
		copy.current_hp = copy.max_hp
		copy.current_mp = copy.max_mp
		copy.is_dead = false
		copy.status_effects.clear()
		copy.active_statuses.clear()
		new_party.add_member(copy)
	new_party.gold = party.gold
	for slot in party.inventory.slots:
		var item: Item = slot.get("item")
		var qty: int = slot.get("quantity", 1)
		if item:
			new_party.inventory.add_item(item.duplicate(), qty)
	return new_party
