extends GdUnitTestSuite
## The failure database and its key.

const Gs := preload("res://addons/hegel/generators.gd")
const DATABASE := "user://database_test_database"
const SCRIPT := "res://tests/database_test.gd"


## Another test, calling the same helper. gdUnit4 doesn't collect inner classes.
class _Neighbour:
	extends RefCounted

	func test_neighbour(helper: Callable, body: Callable, settings: HegelSettings) -> HegelResult:
		return helper.call(body, settings)


func before_test() -> void:
	_remove_tree(DATABASE)


func after_test() -> void:
	_remove_tree(DATABASE)


func _settings() -> HegelSettings:
	var settings := HegelSettings.new()
	settings.test_cases = 100
	settings.seed = 1
	settings.has_seed = true
	settings.database = DATABASE
	settings._silent = true
	return settings


## A project's wrapper around Hegel.run, as a suite writes to keep its assert in one place.
static func _through_helper(body: Callable, settings: HegelSettings) -> HegelResult:
	return Hegel.run(body, settings)


static func _fails_from_10(tc: HegelTestCase) -> void:
	var x: int = tc.draw(Gs.integers(0, 1000))
	tc.check(x < 10, "x < 10")


## Holds, unless the database replays the failure _fails_from_10 shrinks to.
static func _fails_at_10(tc: HegelTestCase) -> void:
	var x: int = tc.draw(Gs.integers(0, 1000))
	tc.check(x != 10, "x != 10")


static func _header(result: HegelResult) -> String:
	return result.report.get_slice("\n", 0)


func test_database_replays_a_stored_failure_first() -> void:
	var settings := _settings()
	var stored := Hegel.run(_fails_from_10, settings)
	settings.seed = 2
	var firsts: Array[int] = []
	var replayed := Hegel.run(
		func(tc: HegelTestCase) -> void:
			var x: int = tc.draw(Gs.integers(0, 1000))
			if firsts.is_empty():
				firsts.append(x)
			tc.check(x < 10),
		settings
	)
	assert_bool(stored.passed).is_false()
	assert_bool(replayed.passed).is_false()
	assert_array(firsts).is_equal([10])


func test_the_key_is_the_test_calling_through_a_helper() -> void:
	var here := _through_helper(_fails_from_10, _settings())
	var there := _Neighbour.new().test_neighbour(_through_helper, _fails_from_10, _settings())
	assert_str(_header(here)).is_equal(
		"--- Failure: %s::test_the_key_is_the_test_calling_through_a_helper ---" % SCRIPT
	)
	assert_str(_header(there)).is_equal("--- Failure: %s::test_neighbour ---" % SCRIPT)


func test_a_test_does_not_replay_another_tests_failure_through_a_helper() -> void:
	var settings := _settings()
	assert_bool(_through_helper(_fails_from_10, settings).passed).is_false()
	var neighbour := _Neighbour.new().test_neighbour(_through_helper, _fails_at_10, settings)
	assert_bool(neighbour.passed).override_failure_message(neighbour.report).is_true()


func test_database_key_overrides_the_derived_key() -> void:
	var settings := _settings()
	settings.database_key = "x"
	var stored := Hegel.run(_fails_from_10, settings)
	assert_str(_header(stored)).is_equal("--- Failure: x ---")
	settings.database_key = "y"
	var other := Hegel.run(_fails_at_10, settings)
	assert_bool(other.passed).override_failure_message(other.report).is_true()


static func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	for file: String in dir.get_files():
		dir.remove(file)
	for sub: String in dir.get_directories():
		_remove_tree(path.path_join(sub))
	DirAccess.remove_absolute(path)
