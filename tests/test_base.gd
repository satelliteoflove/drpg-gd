class_name TestBase
extends RefCounted

var _test_name: String = ""
var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []


func run_all() -> Dictionary:
	var methods := get_method_list()
	for method in methods:
		var name: String = method["name"]
		if name.begins_with("test_"):
			_test_name = name
			print("  Running: %s" % name)
			call(name)
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
