class_name TestBase
extends RefCounted

## Script errors seen so far. A script error stops a test where it stands
## without failing any assertion, so run_all counts one as a failure.
static var script_errors: int = 0

var _test_name: String = ""
var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []


## Add one with OS.add_logger before running tests.
class ScriptErrorCounter extends Logger:
	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			TestBase.script_errors += 1


func run_all() -> Dictionary:
	var methods := get_method_list()
	for method in methods:
		var name: String = method["name"]
		if name.begins_with("test_"):
			_test_name = name
			print("  Running: %s" % name)
			var errors_before := script_errors
			call(name)
			if script_errors > errors_before:
				_failed += 1
				var error := "%s: Stopped by a script error." % name
				_errors.append(error)
				print("    FAIL: %s" % error)
	return {"passed": _passed, "failed": _failed, "errors": _errors}


func assert_true(condition: bool, msg: String = "") -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		var error := "%s: Expected true, got false. %s" % [_test_name, msg]
		_errors.append(error)
		print("    FAIL: %s" % error)


func assert_false(condition: bool, msg: String = "") -> void:
	assert_true(not condition, msg)


func assert_eq(actual, expected, msg: String = "") -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		var error := "%s: Expected %s, got %s. %s" % [_test_name, expected, actual, msg]
		_errors.append(error)
		print("    FAIL: %s" % error)


func assert_ne(actual, not_expected, msg: String = "") -> void:
	if actual != not_expected:
		_passed += 1
	else:
		_failed += 1
		var error := "%s: Expected not %s, got %s. %s" % [_test_name, not_expected, actual, msg]
		_errors.append(error)
		print("    FAIL: %s" % error)


func assert_gt(actual: float, expected: float, msg: String = "") -> void:
	if actual > expected:
		_passed += 1
	else:
		_failed += 1
		var error := "%s: Expected %s > %s. %s" % [_test_name, actual, expected, msg]
		_errors.append(error)
		print("    FAIL: %s" % error)


func assert_gte(actual: float, expected: float, msg: String = "") -> void:
	if actual >= expected:
		_passed += 1
	else:
		_failed += 1
		var error := "%s: Expected %s >= %s. %s" % [_test_name, actual, expected, msg]
		_errors.append(error)
		print("    FAIL: %s" % error)


func assert_lt(actual: float, expected: float, msg: String = "") -> void:
	if actual < expected:
		_passed += 1
	else:
		_failed += 1
		var error := "%s: Expected %s < %s. %s" % [_test_name, actual, expected, msg]
		_errors.append(error)
		print("    FAIL: %s" % error)


func assert_lte(actual: float, expected: float, msg: String = "") -> void:
	if actual <= expected:
		_passed += 1
	else:
		_failed += 1
		var error := "%s: Expected %s <= %s. %s" % [_test_name, actual, expected, msg]
		_errors.append(error)
		print("    FAIL: %s" % error)


func assert_null(value, msg: String = "") -> void:
	if value == null:
		_passed += 1
	else:
		_failed += 1
		var error := "%s: Expected null, got %s. %s" % [_test_name, value, msg]
		_errors.append(error)
		print("    FAIL: %s" % error)


func assert_not_null(value, msg: String = "") -> void:
	if value != null:
		_passed += 1
	else:
		_failed += 1
		var error := "%s: Expected non-null value. %s" % [_test_name, msg]
		_errors.append(error)
		print("    FAIL: %s" % error)


func assert_has(array: Array, value, msg: String = "") -> void:
	if array.has(value):
		_passed += 1
	else:
		_failed += 1
		var error := "%s: Array does not contain %s. %s" % [_test_name, value, msg]
		_errors.append(error)
		print("    FAIL: %s" % error)


func assert_size(array: Array, expected: int, msg: String = "") -> void:
	if array.size() == expected:
		_passed += 1
	else:
		_failed += 1
		var error := "%s: Expected size %d, got %d. %s" % [_test_name, expected, array.size(), msg]
		_errors.append(error)
		print("    FAIL: %s" % error)


func assert_empty(array: Array, msg: String = "") -> void:
	if array.is_empty():
		_passed += 1
	else:
		_failed += 1
		var error := "%s: Expected empty array, got size %d. %s" % [_test_name, array.size(), msg]
		_errors.append(error)
		print("    FAIL: %s" % error)


func assert_not_empty(array: Array, msg: String = "") -> void:
	if not array.is_empty():
		_passed += 1
	else:
		_failed += 1
		var error := "%s: Expected non-empty array. %s" % [_test_name, msg]
		_errors.append(error)
		print("    FAIL: %s" % error)


func assert_between(value: float, min_val: float, max_val: float, msg: String = "") -> void:
	if value >= min_val and value <= max_val:
		_passed += 1
	else:
		_failed += 1
		var error := "%s: Expected %s between %s and %s. %s" % [_test_name, value, min_val, max_val, msg]
		_errors.append(error)
		print("    FAIL: %s" % error)
