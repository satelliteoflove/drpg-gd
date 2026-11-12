extends Node

## Compares how hard each dungeon's guardians and master are, by simulating
## every fight many times against the same parties. The bosses of one floor
## should come out close, whichever dungeon they're in. HP lost counts healed
## damage too, so it can pass 100%.
## Run headless:
##   godot --headless --path . tests/measure_bosses.tscn
## After "--", any of: "2", "4", "6" or "8" to measure one floor only;
## "surge 1.9" to strengthen the monsters as a surge of that size would;
## "levels 12,13,14" to choose the party levels; and "quick" for the balanced
## party against the boss and its minions only.

const RUNS := 200
const BASE_SEED := 4000
## The bosses of each floor, and the party levels worth trying them at.
const FLOORS := {
	2: {"levels": [2, 3, 4, 5], "bosses": [
		"boss_broodmother", "boss_cinder_hound", "boss_brine_mother", "boss_rot_bloom"]},
	4: {"levels": [4, 5, 6, 7], "bosses": [
		"boss_ironjaw", "boss_forgemaster", "boss_drowned_captain", "boss_bog_troll"]},
	6: {"levels": [6, 7, 8, 9], "bosses": [
		"boss_lich", "boss_pyre_priest", "boss_tide_witch", "boss_mire_hag"]},
	8: {"levels": [9, 10, 11, 12], "bosses": [
		"boss_drake", "boss_ash_wyrm", "boss_pale_wyrm", "boss_mire_wyrm", "boss_hollow_king"]},
}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var only_floor := 0
	var surge := 1.0
	var levels: Array = []
	var quick := false
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] == "surge" and i + 1 < args.size():
			surge = float(args[i + 1])
			i += 1
		elif args[i] == "levels" and i + 1 < args.size():
			for part in args[i + 1].split(","):
				levels.append(int(part))
			i += 1
		elif args[i] == "quick":
			quick = true
		else:
			only_floor = int(args[i])
		i += 1

	var parties := {
		"balanced": TestFixtures.create_balanced_party,
		"fighters": TestFixtures.create_fighter_heavy_party,
		"casters": TestFixtures.create_caster_heavy_party,
	}
	if quick:
		parties = {"balanced": TestFixtures.create_balanced_party}
	for floor_num in FLOORS:
		if only_floor > 0 and floor_num != only_floor:
			continue
		var floor_levels: Array = levels if not levels.is_empty() else FLOORS[floor_num]["levels"]
		for with_minions in [true] if quick else [true, false]:
			print("\nFloor %d, %s, surge x%.2f  (win %% over %d fights, then HP lost as %% of the party's)" % [
				floor_num, "with minions" if with_minions else "boss alone", surge, RUNS])
			for party_name in parties:
				print("  %s party" % party_name)
				var header := "    %-24s" % "level"
				for level in floor_levels:
					header += "%12d" % level
				print(header)
				for boss_id in FLOORS[floor_num]["bosses"]:
					var line := "    %-24s" % boss_id
					for level in floor_levels:
						CombatRNG.set_seed(BASE_SEED)
						var party: Party = parties[party_name].call(level)
						TestFixtures.stock_party_consumables(party, level)
						var ids: Array[String] = [boss_id]
						if with_minions:
							ids.append_array(MonsterDatabase.get_minions_of(boss_id))
						var enemies := TestFixtures.create_monster_group(ids)
						for enemy in enemies:
							DungeonSurge.strengthen(enemy, surge)
						var result := BatchSimulator.new().run_batch(party, enemies, RUNS, BASE_SEED)
						var party_hp := 0
						for member in party.get_members():
							party_hp += member.max_hp
						line += "%7.0f%% %3.0f" % [result.win_rate, 100.0 * result.avg_hp_lost / party_hp]
					print(line)
	get_tree().quit()
