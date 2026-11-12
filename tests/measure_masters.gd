extends Node

## Compares how hard each dungeon's master is, by simulating the fight many
## times against the same parties. The four of a set should come out close.
## Run headless:
##   godot --headless --path . tests/measure_masters.tscn

const RUNS := 200
const BASE_SEED := 4000
const LEVELS := [9, 10, 11, 12]
const MASTERS := ["boss_drake", "boss_ash_wyrm", "boss_pale_wyrm", "boss_mire_wyrm", "boss_hollow_king"]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var parties := {
		"balanced": TestFixtures.create_balanced_party,
		"fighters": TestFixtures.create_fighter_heavy_party,
		"casters": TestFixtures.create_caster_heavy_party,
	}
	for with_minions in [true, false]:
		print("\n%s  (win %% over %d fights, then average rounds)" % [
			"With minions" if with_minions else "Master alone", RUNS])
		for party_name in parties:
			print("  %s party" % party_name)
			var header := "    %-24s" % "level"
			for level in LEVELS:
				header += "%12d" % level
			print(header)
			for master_id in MASTERS:
				var line := "    %-24s" % master_id
				for level in LEVELS:
					CombatRNG.set_seed(BASE_SEED)
					var party: Party = parties[party_name].call(level)
					TestFixtures.stock_party_consumables(party, level)
					var ids: Array[String] = [master_id]
					if with_minions:
						ids.append_array(MonsterDatabase.get_minions_of(master_id))
					var enemies := TestFixtures.create_monster_group(ids)
					var result := BatchSimulator.new().run_batch(party, enemies, RUNS, BASE_SEED)
					line += "%7.0f%% %3.0f" % [result.win_rate, result.avg_turns]
				print(line)
	get_tree().quit()
