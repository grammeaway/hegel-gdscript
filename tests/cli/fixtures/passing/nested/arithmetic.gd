extends Node
## A passing property in a subdirectory and on a Node, for tests/cli/run_test.gd.

const Gs := preload("res://addons/hegel/generators.gd")
const Sorting := preload("res://tests/cli/fixtures/passing/sorting.gd")


func test_addition_commutes() -> void:
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			var x: int = tc.draw(Gs.integers(-1000, 1000))
			var y: int = tc.draw(Gs.integers(-1000, 1000))
			tc.check(x + y == y + x),
		Sorting.settings()
	)


func helper_is_not_a_test() -> void:
	push_error("not a test")
