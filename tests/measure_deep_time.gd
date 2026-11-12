extends Node

## Estimates how many years a dungeon run costs the party under deep time,
## floor by floor. Run headless:
##   godot --headless --path . tests/measure_deep_time.tscn
##
## For each floor it generates several layouts and has a bot explore each one
## fully (a tile counts as seen once the party stands on it or next to it),
## counts the enemy groups a floor starts with, and simulates fights to get XP
## per fight. Steps become years through FloorTracker's deep-time table.

const SEEDS := 12
const FIGHT_SEEDS := 3
const FIGHTS_PER_SIM := 15
## Party level while on each floor of a first descent (index = floor).
const PARTY_LEVEL := [0, 1, 2, 3, 4, 5, 6, 8, 10]
## Level a party needs before each boss, from the boss sims (about 9 in 12
## wins or better). Bosses guard floors 2, 4, 6 and 8.
const BOSS_GATE := {2: 2, 4: 5, 6: 7, 8: 11}
## Expected starting groups per zone type, from EnemyManager.
const START_GROUPS := {
	EncounterZone.ZoneType.SAFE: 0.0,
	EncounterZone.ZoneType.NORMAL: 1.5,
	EncounterZone.ZoneType.LOW_SPAWN: 1.5,
	EncounterZone.ZoneType.HIGH_SPAWN: 2.5,
	EncounterZone.ZoneType.BOSS: 0.0,
	EncounterZone.ZoneType.SPECIAL: 1.0,
}


func _ready() -> void:
	call_deferred("_run")


func _years(steps: float, floor_num: int) -> float:
	return steps * FloorTracker.DEEP_DAYS_PER_DAY[floor_num] / FloorTracker.STEPS_PER_DAY / CharacterEnums.DAYS_PER_YEAR


func _run() -> void:
	var rows: Array[Dictionary] = []
	for f in range(1, 9):
		rows.append(_measure_floor(f))

	print("")
	print("DEEP TIME MEASUREMENT (%d layouts per floor)" % SEEDS)
	print("floor | rate | tiles | explore steps | explore yrs | groups | steps/fight | xp/fight (party L) | yrs per 10 fights")
	for r in rows:
		print("%d | %d | %d | %d | %.2f | %.1f | %.1f | %d (L%d) | %.2f" % [
			r.floor, FloorTracker.DEEP_DAYS_PER_DAY[r.floor], r.tiles, r.explore_steps,
			_years(r.explore_steps, r.floor), r.groups, r.steps_per_fight, r.xp_per_fight,
			PARTY_LEVEL[r.floor], _years(r.steps_per_fight * 10.0, r.floor)])

	_first_descent(rows)
	_veteran_descent(rows)
	print("")
	get_tree().quit()


func _measure_floor(f: int) -> Dictionary:
	var tiles := 0.0
	var steps := 0.0
	var groups := 0.0
	for s in SEEDS:
		var data := DungeonGenerator.new().generate(31, 31, f, 9000 + f * 100 + s)
		var pf := DungeonPathfinding.new()
		pf.initialize(data)
		for y in data.height:
			for x in data.width:
				if data.is_walkable(x, y):
					tiles += 1
		steps += _explore(data, pf)
		for zone in data.zones:
			groups += START_GROUPS.get(zone.zone_type, 1.0)
	tiles /= SEEDS
	steps /= SEEDS
	groups /= SEEDS

	var xp := 0.0
	var won := 0
	for s in FIGHT_SEEDS:
		var party := TestFixtures.create_balanced_party(PARTY_LEVEL[f])
		var result := ExplorationSimulator.new().run_floor_dive(party, f, FIGHTS_PER_SIM, false, 4242 + f * 10 + s)
		xp += result.total_xp
		won += result.encounters_won
	return {
		"floor": f, "tiles": int(tiles), "explore_steps": int(steps), "groups": groups,
		"steps_per_fight": steps / maxf(1.0, groups), "xp_per_fight": int(xp / maxi(1, won)),
	}


## Walks to the nearest unseen tile until every reachable tile has been seen,
## then to the stairs down. Returns the number of moves.
func _explore(data: DungeonData, pf: DungeonPathfinding) -> int:
	var seen := {}
	var pos := data.stairs_up_pos
	var moves := 0
	_see(pos, pf, seen)
	while true:
		var path := _path_to_nearest(pos, pf, func(p: Vector2i) -> bool: return not seen.has(p))
		if path.is_empty():
			break
		var target: Vector2i = path[-1]
		for p: Vector2i in path:
			if seen.has(target):
				break
			pos = p
			moves += 1
			_see(pos, pf, seen)
	var to_stairs := _path_to_nearest(pos, pf, func(p: Vector2i) -> bool: return p == data.stairs_down_pos)
	return moves + to_stairs.size()


func _see(pos: Vector2i, pf: DungeonPathfinding, seen: Dictionary) -> void:
	seen[pos] = true
	for n in pf.get_all_adjacent(pos, false):
		seen[n] = true


## Breadth-first path (excluding the start) to the nearest tile matching
## [param goal], or empty if none is reachable.
func _path_to_nearest(start: Vector2i, pf: DungeonPathfinding, goal: Callable) -> Array[Vector2i]:
	var came := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		if cur != start and goal.call(cur):
			var path: Array[Vector2i] = []
			var p := cur
			while p != start:
				path.push_front(p)
				p = came[p]
			return path
		for n in pf.get_all_adjacent(cur, false):
			if not came.has(n):
				came[n] = cur
				queue.append(n)
	return []


## A fresh party's first trip to the bottom: explore every floor once, and
## grind on the floor above each boss for whatever levels exploring didn't give.
func _first_descent(rows: Array[Dictionary]) -> void:
	print("")
	print("FIRST DESCENT: fresh party from L1, exploring every floor and grinding above each boss")
	var xp_have := 0.0
	var total_years := 0.0
	var explore_years := 0.0
	var grind_years := 0.0
	var level := 1
	for r in rows:
		var f: int = r.floor
		var y_explore := _years(r.explore_steps, f)
		xp_have += r.groups * r.xp_per_fight
		var y_grind := 0.0
		var grind_fights := 0.0
		# Grind on the floor just above a boss, before going down to it.
		if BOSS_GATE.has(f + 1):
			var need := ExperienceTable.get_xp_for_level(BOSS_GATE[f + 1])
			if xp_have < need:
				grind_fights = (need - xp_have) / maxf(1.0, r.xp_per_fight)
				xp_have = need
				y_grind = _years(grind_fights * r.steps_per_fight, f)
		level = ExperienceTable.get_level_for_xp(int(xp_have), CharacterEnums.Race.HUMAN, CharacterEnums.CharacterClass.FIGHTER)
		explore_years += y_explore
		grind_years += y_grind
		total_years += y_explore + y_grind
		print("floor %d: explore %.2f yrs, grind %d fights = %.2f yrs, level after %d, running total %.1f yrs" % [
			f, y_explore, int(grind_fights), y_grind, level, total_years])
	print("total: %.1f years (%.1f exploring, %.1f grinding)" % [total_years, explore_years, grind_years])


## An experienced party in a new dungeon: explore every floor once, no grinding.
func _veteran_descent(rows: Array[Dictionary]) -> void:
	var total := 0.0
	for r in rows:
		total += _years(r.explore_steps, r.floor)
	print("")
	print("VETERAN DESCENT: explore every floor once, no grinding: %.1f years" % total)
