extends RefCounted
## One passing and two failing tests, for tests/cli/run_test.gd.

const Gs := preload("res://addons/hegel/generators.gd")
const Sorting := preload("res://tests/cli/fixtures/passing/sorting.gd")


func test_passes() -> void:
	Hegel.run(func(tc: HegelTestCase) -> void: tc.draw(Gs.booleans()), Sorting.settings())


func test_property_fails() -> void:
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			var x: int = tc.draw(Gs.integers(0, 1000))
			tc.check(x < 10, "x < 10"),
		Sorting.settings()
	)


func test_setup_error_fails() -> void:
	var node: Node = null
	node.get_name()
