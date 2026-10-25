extends RefCounted
## Passing properties for tests/cli/run_test.gd.

const Gs := preload("res://addons/hegel/generators.gd")


func test_sorting_is_idempotent() -> void:
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			var once: Array = tc.draw(Gs.lists(Gs.integers()))
			once.sort()
			var twice := once.duplicate()
			twice.sort()
			tc.check(once == twice),
		settings()
	)


func test_errors_after_a_rejection_are_left_to_hegel() -> void:
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			var x: int = tc.draw(Gs.integers(0, 10))
			if not tc.assume(x != 0):
				push_error("ignored: the case is already rejected"),
		settings()
	)


static func settings() -> HegelSettings:
	var settings := HegelSettings.new()
	settings.derandomize = true
	settings.database = ""
	return settings
