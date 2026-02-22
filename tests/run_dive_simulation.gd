extends Node

const NUM_DIVES := 5
const BASE_SEED := 70000

var _scenarios := []


func _build_scenarios() -> void:
	for floor_num in range(1, 7):
		for level in range(1, 7):
			var diff: int = level - floor_num
			if diff > 2:
				continue
			_scenarios.append({
				"name": "F%d Lv%d" % [floor_num, level],
				"level": level,
				"floor": floor_num,
				"encounters": 4,
				"boss": false,
				"return": 1,
			})


func _ready() -> void:
	_run()


func _run() -> void:
	_build_scenarios()
	var total_dives := _scenarios.size() * NUM_DIVES
	print("=" .repeat(80))
	print("DIVE SIMULATOR -- Attrition-Based Combat Testing (with return trip)")
	print("%d scenarios x %d dives = %d total dives" % [_scenarios.size(), NUM_DIVES, total_dives])
	print("=" .repeat(80))
	print("")

	var all_scenario_results: Array[Dictionary] = []

	for si in range(_scenarios.size()):
		var scenario: Dictionary = _scenarios[si]
		var scenario_name: String = scenario["name"]
		var level: int = scenario["level"]
		var floor_num: int = scenario["floor"]
		var num_encounters: int = scenario["encounters"]
		var include_boss: bool = scenario["boss"]
		var return_enc: int = scenario["return"]

		print("-" .repeat(80))
		print("Scenario %d/%d: %s (Lv%d, Floor %d, %d fights%s, %d return)" % [
			si + 1, _scenarios.size(), scenario_name, level, floor_num,
			num_encounters, " + Boss" if include_boss else "", return_enc
		])
		print("-" .repeat(80))

		var dive_results: Array[Dictionary] = []
		for di in range(NUM_DIVES):
			var party := TestFixtures.create_balanced_party(level)
			TestFixtures.stock_party_consumables(party, level)
			var seed_value := BASE_SEED + si * 100000 + di * 1000
			CombatRNG.set_seed(seed_value)

			var sim := DiveSimulator.new()
			var result := sim.run_floor_dive(
				party, floor_num, num_encounters, include_boss,
				seed_value, PartyAI.DEFAULT_CAST_THRESHOLD,
				PartyAI.Strategy.BALANCED, return_enc
			)
			dive_results.append(result)

		var summary := _compute_scenario_summary(
			dive_results, num_encounters, include_boss, return_enc, level
		)
		summary["name"] = scenario_name
		summary["level"] = level
		summary["floor"] = floor_num
		all_scenario_results.append(summary)

		_print_scenario_summary(summary)
		print("")

	_print_resource_curve_table(all_scenario_results)
	_print_danger_zones(all_scenario_results)
	_print_wipe_analysis(all_scenario_results)
	_print_return_trip_analysis(all_scenario_results)
	_print_economic_table(all_scenario_results)
	_print_retreat_analysis(all_scenario_results)

	print("=" .repeat(80))
	print("Total dives simulated: %d" % total_dives)
	print("=" .repeat(80))

	get_tree().quit(0)


func _compute_scenario_summary(
	dive_results: Array[Dictionary],
	num_encounters: int,
	include_boss: bool,
	return_enc: int,
	level: int
) -> Dictionary:
	var total := dive_results.size()
	var wipes := 0
	var dive_wipes := 0
	var return_wipes := 0
	var wipe_encounters: Array[int] = []
	var boss_wins := 0
	var boss_attempts := 0
	var total_potions := 0
	var total_encounters_on_wipe := 0
	var wipe_count := 0
	var total_gold := 0
	var total_loot_value := 0
	var total_consumable_cost := 0
	var total_inn_cost := 0
	var total_temple_cost := 0
	var total_profit := 0
	var retreats := 0
	var retreat_reasons: Dictionary = {}
	var total_poison := 0
	var total_paralysis := 0
	var total_other_status := 0
	var total_party_surprises := 0
	var total_enemy_surprises := 0
	var total_stalemates := 0

	var max_encounter_num := num_encounters + (1 if include_boss else 0)
	var hp_by_encounter: Array[Array] = []
	var mp_by_encounter: Array[Array] = []
	for i in range(max_encounter_num):
		hp_by_encounter.append([])
		mp_by_encounter.append([])

	var return_hp_by_enc: Array[Array] = []
	var return_mp_by_enc: Array[Array] = []
	for i in range(return_enc):
		return_hp_by_enc.append([])
		return_mp_by_enc.append([])

	var boss_hp_entering: Array[float] = []
	var pre_return_hp: Array[float] = []

	for result in dive_results:
		total_potions += result.total_potions_used

		for snap in result.encounter_snapshots:
			var statuses: Dictionary = snap.get("statuses_applied", {})
			total_poison += statuses.get("poison", 0)
			total_paralysis += statuses.get("paralysis", 0)
			total_other_status += statuses.get("other", 0)
			var surprise: String = snap.get("surprise", "none")
			if surprise == "party":
				total_party_surprises += 1
			elif surprise == "enemy":
				total_enemy_surprises += 1
			if snap.get("stalemate", false):
				total_stalemates += 1
		for snap in result.get("return_snapshots", []):
			var statuses: Dictionary = snap.get("statuses_applied", {})
			total_poison += statuses.get("poison", 0)
			total_paralysis += statuses.get("paralysis", 0)
			total_other_status += statuses.get("other", 0)
			var surprise: String = snap.get("surprise", "none")
			if surprise == "party":
				total_party_surprises += 1
			elif surprise == "enemy":
				total_enemy_surprises += 1
			if snap.get("stalemate", false):
				total_stalemates += 1

		if result.party_wiped:
			wipes += 1
			wipe_encounters.append(result.wipe_encounter)
			if result.get("wiped_during_return", false):
				return_wipes += 1
			else:
				dive_wipes += 1
				total_encounters_on_wipe += result.encounters_won
				wipe_count += 1

		if include_boss and result.get("boss_victory", false):
			boss_wins += 1
		if include_boss and result.encounter_snapshots.size() > num_encounters:
			boss_attempts += 1

		var snapshots: Array = result.encounter_snapshots
		for snap in snapshots:
			var enc_idx: int = snap["encounter_num"] - 1
			if enc_idx >= 0 and enc_idx < max_encounter_num:
				hp_by_encounter[enc_idx].append(snap["party_hp_pct"])
				mp_by_encounter[enc_idx].append(snap["party_mp_pct"])

		if include_boss and snapshots.size() >= 2:
			var pre_boss: Dictionary = snapshots[snapshots.size() - 2]
			if not pre_boss.get("is_boss", false):
				boss_hp_entering.append(pre_boss["party_hp_pct"])

		var ret_snaps: Array = result.get("return_snapshots", [])
		if not ret_snaps.is_empty():
			var last_dive_snap: Dictionary = snapshots[snapshots.size() - 1] if not snapshots.is_empty() else {}
			if not last_dive_snap.is_empty():
				pre_return_hp.append(last_dive_snap["party_hp_pct"])

		for ri in range(ret_snaps.size()):
			if ri < return_enc:
				return_hp_by_enc[ri].append(ret_snaps[ri]["party_hp_pct"])
				return_mp_by_enc[ri].append(ret_snaps[ri]["party_mp_pct"])

		var cons_cost: int = result.get("healing_potions_used", 0) * 25 \
			+ result.get("greater_healing_used", 0) * 75 \
			+ result.get("mana_potions_used", 0) * 15 \
			+ result.get("antidotes_used", 0) * 20
		total_consumable_cost += cons_cost

		var made_it_home: bool = not result.party_wiped
		if made_it_home:
			total_gold += result.get("total_gold", 0)
			total_loot_value += result.get("total_loot_value", 0)
			var inn_cost: int = level * 10
			total_inn_cost += inn_cost
			var dead_count: int = 6 - result.get("survivors", 6)
			var temple_cost := 0
			if dead_count > 0:
				temple_cost = dead_count * (100 + 25 * level)
			total_temple_cost += temple_cost
			total_profit += result.get("total_gold", 0) + result.get("total_loot_value", 0) - cons_cost - inn_cost - temple_cost
		else:
			var wipe_cost: int = 6 * (100 + 25 * level)
			total_profit += -cons_cost - wipe_cost

		if result.get("retreated", false):
			retreats += 1
			var reason: String = result.get("retreat_reason", "")
			retreat_reasons[reason] = retreat_reasons.get(reason, 0) + 1

	var avg_hp_by_encounter: Array[float] = []
	var avg_mp_by_encounter: Array[float] = []
	for i in range(max_encounter_num):
		avg_hp_by_encounter.append(_safe_avg(hp_by_encounter[i]))
		avg_mp_by_encounter.append(_safe_avg(mp_by_encounter[i]))

	var avg_return_hp: Array[float] = []
	var avg_return_mp: Array[float] = []
	for i in range(return_enc):
		avg_return_hp.append(_safe_avg(return_hp_by_enc[i]))
		avg_return_mp.append(_safe_avg(return_mp_by_enc[i]))

	var avg_boss_hp_entering := _safe_avg(boss_hp_entering)
	var avg_pre_return_hp := _safe_avg(pre_return_hp)

	var survival_rate := float(total - wipes) / float(total) * 100.0
	var dive_survival_rate := float(total - dive_wipes) / float(total) * 100.0
	var avg_encounters_before_wipe := 0.0
	if wipe_count > 0:
		avg_encounters_before_wipe = float(total_encounters_on_wipe) / float(wipe_count)
	var avg_potions := float(total_potions) / float(total)
	var boss_win_rate := 0.0
	if boss_attempts > 0:
		boss_win_rate = float(boss_wins) / float(boss_attempts) * 100.0

	var wipe_encounter_counts: Dictionary = {}
	for enc in wipe_encounters:
		wipe_encounter_counts[enc] = wipe_encounter_counts.get(enc, 0) + 1

	return {
		"total_dives": total,
		"survival_rate": survival_rate,
		"dive_survival_rate": dive_survival_rate,
		"wipes": wipes,
		"dive_wipes": dive_wipes,
		"return_wipes": return_wipes,
		"avg_encounters_before_wipe": avg_encounters_before_wipe,
		"avg_hp_by_encounter": avg_hp_by_encounter,
		"avg_mp_by_encounter": avg_mp_by_encounter,
		"avg_return_hp": avg_return_hp,
		"avg_return_mp": avg_return_mp,
		"avg_pre_return_hp": avg_pre_return_hp,
		"boss_win_rate": boss_win_rate,
		"boss_attempts": boss_attempts,
		"boss_wins": boss_wins,
		"avg_boss_hp_entering": avg_boss_hp_entering,
		"avg_potions": avg_potions,
		"include_boss": include_boss,
		"num_encounters": num_encounters,
		"return_encounters": return_enc,
		"wipe_encounter_counts": wipe_encounter_counts,
		"avg_gold": float(total_gold) / float(total),
		"avg_loot_value": float(total_loot_value) / float(total),
		"avg_consumable_cost": float(total_consumable_cost) / float(total),
		"avg_inn_cost": float(total_inn_cost) / float(total),
		"avg_temple_cost": float(total_temple_cost) / float(total),
		"avg_profit": float(total_profit) / float(total),
		"retreats": retreats,
		"retreat_rate": float(retreats) / float(total) * 100.0,
		"retreat_reasons": retreat_reasons,
		"avg_poison": float(total_poison) / float(total),
		"avg_paralysis": float(total_paralysis) / float(total),
		"avg_other_status": float(total_other_status) / float(total),
		"avg_party_surprises": float(total_party_surprises) / float(total),
		"avg_enemy_surprises": float(total_enemy_surprises) / float(total),
		"total_stalemates": total_stalemates,
	}


func _safe_avg(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var total := 0.0
	for v in arr:
		total += v
	return total / arr.size()


func _print_scenario_summary(summary: Dictionary) -> void:
	print("  Survival rate: %5.1f%% (%d/%d made it home)" % [
		summary.survival_rate,
		summary.total_dives - summary.wipes,
		summary.total_dives,
	])

	if summary.dive_survival_rate != summary.survival_rate:
		print("    Dive survival: %5.1f%%  |  Lost on return trip: %d" % [
			summary.dive_survival_rate, summary.return_wipes
		])

	if summary.dive_wipes > 0:
		print("  Avg encounters before wipe (dive): %.1f" % summary.avg_encounters_before_wipe)

	var hp_arr: Array = summary.avg_hp_by_encounter
	var mp_arr: Array = summary.avg_mp_by_encounter
	var num_enc: int = summary.num_encounters
	var has_boss: bool = summary.include_boss

	print("  Attrition curve (HP%%/MP%% after each encounter):")
	for i in range(hp_arr.size()):
		var label := "Boss" if has_boss and i == num_enc else "E%d" % (i + 1)
		var marker := ""
		if hp_arr[i] < 50.0 and hp_arr[i] > 0.0:
			marker = " << DANGER"
		print("    %-5s  HP: %5.1f%%  MP: %5.1f%%%s" % [label, hp_arr[i], mp_arr[i], marker])

	if has_boss:
		print("  Boss win rate: %5.1f%% (%d/%d)" % [
			summary.boss_win_rate, summary.boss_wins, summary.boss_attempts
		])
		if summary.avg_boss_hp_entering > 0.0:
			print("  Avg HP%% entering boss: %5.1f%%" % summary.avg_boss_hp_entering)

	var ret_hp: Array = summary.avg_return_hp
	var ret_mp: Array = summary.avg_return_mp
	if not ret_hp.is_empty():
		print("  Return trip (no healing between fights):")
		if summary.avg_pre_return_hp > 0.0:
			print("    Start  HP: %5.1f%%" % summary.avg_pre_return_hp)
		for i in range(ret_hp.size()):
			var marker := ""
			if ret_hp[i] < 50.0 and ret_hp[i] > 0.0:
				marker = " << DANGER"
			print("    R%d     HP: %5.1f%%  MP: %5.1f%%%s" % [
				i + 1, ret_hp[i], ret_mp[i], marker
			])

	print("  Statuses: %.1f poison/dive, %.1f paralysis/dive, %.1f other/dive" % [
		summary.avg_poison, summary.avg_paralysis, summary.avg_other_status
	])
	var stalemate_str := ""
	if summary.total_stalemates > 0:
		stalemate_str = " | %d stalemates" % summary.total_stalemates
	print("  Surprise: %.1f party/dive, %.1f enemy/dive%s" % [
		summary.avg_party_surprises, summary.avg_enemy_surprises, stalemate_str
	])
	print("  Avg potions consumed: %.1f per dive" % summary.avg_potions)

	if summary.retreats > 0:
		var reasons: Dictionary = summary.retreat_reasons
		var reason_parts: Array[String] = []
		for reason_key in reasons:
			reason_parts.append("%s: %d" % [reason_key, reasons[reason_key]])
		print("  Retreats: %d (%.0f%%) -- %s" % [
			summary.retreats, summary.retreat_rate, ", ".join(reason_parts)
		])

	print("  Economy: gold %.0fg + loot %.0fg - supplies %.0fg - inn %.0fg - temple %.0fg = net %.0fg" % [
		summary.avg_gold, summary.avg_loot_value, summary.avg_consumable_cost,
		summary.avg_inn_cost, summary.avg_temple_cost, summary.avg_profit
	])


func _print_resource_curve_table(all_results: Array[Dictionary]) -> void:
	print("")
	print("=" .repeat(80))
	print("RESOURCE CURVE TABLE (avg HP%% after each encounter)")
	print("=" .repeat(80))
	print("")

	var header := "%-22s" % "Scenario"
	for i in range(6):
		header += " |  E%d" % (i + 1)
	header += " | Boss"
	header += " |  R1 |  R2 |  R3"
	print(header)
	print("-" .repeat(header.length()))

	for summary in all_results:
		var line := "%-22s" % summary.get("name", "")
		var hp_arr: Array = summary.avg_hp_by_encounter
		var num_enc: int = summary.num_encounters
		var has_boss: bool = summary.include_boss
		var ret_hp: Array = summary.avg_return_hp

		for i in range(6):
			if i < num_enc and i < hp_arr.size():
				line += " |%4.0f" % hp_arr[i]
			else:
				line += " |  --"

		if has_boss and hp_arr.size() > num_enc:
			line += " |%4.0f" % hp_arr[num_enc]
		else:
			line += " |  --"

		for i in range(3):
			if i < ret_hp.size() and ret_hp[i] > 0.0:
				line += " |%4.0f" % ret_hp[i]
			else:
				line += " |  --"

		print(line)
	print("")


func _print_danger_zones(all_results: Array[Dictionary]) -> void:
	print("=" .repeat(80))
	print("DANGER ZONES (first point where avg HP drops below 50%%)")
	print("=" .repeat(80))
	print("")

	for summary in all_results:
		var hp_arr: Array = summary.avg_hp_by_encounter
		var ret_hp: Array = summary.avg_return_hp
		var danger_label := ""
		var danger_hp := 0.0

		for i in range(hp_arr.size()):
			if hp_arr[i] < 50.0 and hp_arr[i] > 0.0:
				var is_boss: bool = summary.include_boss and i == summary.num_encounters
				danger_label = "Boss" if is_boss else "Encounter %d" % (i + 1)
				danger_hp = hp_arr[i]
				break

		if danger_label == "":
			for i in range(ret_hp.size()):
				if ret_hp[i] < 50.0 and ret_hp[i] > 0.0:
					danger_label = "Return %d" % (i + 1)
					danger_hp = ret_hp[i]
					break

		var sname: String = summary.get("name", "")
		if danger_label != "":
			print("  %-22s -> %s (HP: %.1f%%)" % [sname, danger_label, danger_hp])
		else:
			print("  %-22s -> No danger zone (HP stays above 50%%)" % sname)
	print("")


func _print_wipe_analysis(all_results: Array[Dictionary]) -> void:
	print("=" .repeat(80))
	print("WIPE ANALYSIS (where parties died)")
	print("=" .repeat(80))
	print("")

	for summary in all_results:
		var sname: String = summary.get("name", "")
		var wipe_counts: Dictionary = summary.wipe_encounter_counts
		if wipe_counts.is_empty():
			print("  %-22s -> No wipes!" % sname)
			continue

		var parts: Array[String] = []
		var sorted_encounters: Array = wipe_counts.keys()
		sorted_encounters.sort()
		for enc in sorted_encounters:
			var count: int = wipe_counts[enc]
			var label := ""
			if enc < 0:
				label = "R%d" % abs(enc)
			elif summary.include_boss and enc > summary.num_encounters:
				label = "Boss"
			else:
				label = "E%d" % enc
			parts.append("%s: %d" % [label, count])

		print("  %-22s -> %s (total: %d wipes, %d on return)" % [
			sname, ", ".join(parts), summary.wipes, summary.return_wipes
		])
	print("")


func _print_return_trip_analysis(all_results: Array[Dictionary]) -> void:
	print("=" .repeat(80))
	print("RETURN TRIP IMPACT")
	print("=" .repeat(80))
	print("")
	print("  %-22s | Dive OK | Made Home | Lost on Return | Return Death Rate" % "Scenario")
	print("  " + "-" .repeat(76))

	for summary in all_results:
		var sname: String = summary.get("name", "")
		var dive_ok: int = summary.total_dives - summary.dive_wipes
		var made_home: int = summary.total_dives - summary.wipes
		var return_deaths: int = summary.return_wipes
		var return_death_rate := 0.0
		if dive_ok > 0:
			return_death_rate = float(return_deaths) / float(dive_ok) * 100.0

		print("  %-22s | %4d/%2d | %4d/%2d   | %5d          | %5.1f%%" % [
			sname, dive_ok, summary.total_dives,
			made_home, summary.total_dives,
			return_deaths, return_death_rate
		])
	print("")


func _print_economic_table(all_results: Array[Dictionary]) -> void:
	print("=" .repeat(80))
	print("ECONOMICS (avg gold per dive)")
	print("=" .repeat(80))
	print("")
	print("  %-22s |  Gold | Loot | Suppl |  Inn | Temple |  Net" % "Scenario")
	print("  " + "-" .repeat(68))

	for summary in all_results:
		var sname: String = summary.get("name", "")
		print("  %-22s | %5.0f | %4.0f | %5.0f | %4.0f | %6.0f | %5.0f" % [
			sname, summary.avg_gold, summary.avg_loot_value,
			summary.avg_consumable_cost, summary.avg_inn_cost,
			summary.avg_temple_cost, summary.avg_profit
		])
	print("")


func _print_retreat_analysis(all_results: Array[Dictionary]) -> void:
	var any_retreats := false
	for summary in all_results:
		if summary.retreats > 0:
			any_retreats = true
			break
	if not any_retreats:
		return

	print("=" .repeat(80))
	print("RETREAT ANALYSIS")
	print("=" .repeat(80))
	print("")
	print("  %-22s | Retreats | Rate   | Reasons" % "Scenario")
	print("  " + "-" .repeat(60))

	for summary in all_results:
		var sname: String = summary.get("name", "")
		if summary.retreats == 0:
			print("  %-22s |        0 |  0.0%%  | --" % sname)
			continue

		var reasons: Dictionary = summary.retreat_reasons
		var reason_parts: Array[String] = []
		for reason_key in reasons:
			reason_parts.append("%s: %d" % [reason_key, reasons[reason_key]])

		print("  %-22s | %6d   | %5.1f%% | %s" % [
			sname, summary.retreats, summary.retreat_rate,
			", ".join(reason_parts)
		])
	print("")
