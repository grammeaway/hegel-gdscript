extends RefCounted
## Run with the plain runner:
##   godot --headless --path . -s res://addons/hegel/cli/run.gd -- res://examples/plain/
## test_rows_fit_every_item fails until rows_for rounds up.

const Gs := preload("res://addons/hegel/generators.gd")
const Inventory := preload("res://examples/inventory.gd")


func test_rows_fit_every_item() -> void:
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			var count: int = tc.draw(Gs.integers(0, 1000), "count")
			var columns: int = tc.draw(Gs.integers(1, 20), "columns")
			tc.check(Inventory.rows_for(count, columns) * columns >= count, "the rows fit every item")
	)


func test_more_columns_never_need_more_rows() -> void:
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			var count: int = tc.draw(Gs.integers(0, 1000), "count")
			var columns: int = tc.draw(Gs.integers(1, 20), "columns")
			tc.check(Inventory.rows_for(count, columns + 1) <= Inventory.rows_for(count, columns))
	)
