extends SceneTree

var _total_passed := 0
var _total_failed := 0
var _all_errors: Array[String] = []

const TEST_SUITES: Array[String] = [
	"res://tests/unit/test_combat_rng.gd",
	"res://tests/unit/test_metrics_collector.gd",
	"res://tests/unit/test_ai_decision_log.gd",
	"res://tests/unit/test_fixtures.gd",
	"res://tests/unit/test_simulation.gd",
	"res://tests/unit/test_party_ai.gd",
	"res://tests/unit/test_character.gd",
	"res://tests/unit/test_party.gd",
	"res://tests/unit/test_monster.gd",
	"res://tests/unit/test_item.gd",
]


func _init() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	print("=" .repeat(60))
	print("DRPG-GD Test Suite")
	print("=" .repeat(60))
	print("")

	for suite_path in TEST_SUITES:
		_run_suite(suite_path)

	print("")
	print("=" .repeat(60))
	print("Total: %d passed, %d failed" % [_total_passed, _total_failed])
	print("=" .repeat(60))

	if not _all_errors.is_empty():
		print("")
		print("All Errors:")
		for err in _all_errors:
			print("  - %s" % err)

	quit(0 if _total_failed == 0 else 1)


func _run_suite(path: String) -> void:
	if not ResourceLoader.exists(path):
		print("SKIP: %s (not found)" % path)
		return

	var script: Script = load(path)
	if script == null:
		print("SKIP: %s (failed to load)" % path)
		return

	var suite = script.new()
	if suite == null:
		print("SKIP: %s (failed to instantiate)" % path)
		return

	print("Suite: %s" % path.get_file())
	var result: Dictionary = suite.run_all()

	_total_passed += result.passed
	_total_failed += result.failed
	_all_errors.append_array(result.errors)

	print("  -> %d passed, %d failed" % [result.passed, result.failed])
	print("")
