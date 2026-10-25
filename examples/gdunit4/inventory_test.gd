extends GdUnitTestSuite
## Properties in a gdUnit4 suite: one passes, and two find the bugs in
## examples/inventory.gd, one through a failed check and one through a
## runtime error.

const Gs := preload("res://addons/hegel/generators.gd")
const Inventory := preload("res://examples/inventory.gd")


func test_more_columns_never_need_more_rows() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			var count: int = tc.draw(Gs.integers(0, 1000), "count")
			var columns: int = tc.draw(Gs.integers(1, 20), "columns")
			tc.check(Inventory.rows_for(count, columns + 1) <= Inventory.rows_for(count, columns))
	)
	assert_bool(result.passed).is_true()


func test_rows_fit_every_item() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			var count: int = tc.draw(Gs.integers(0, 1000), "count")
			var columns: int = tc.draw(Gs.integers(1, 20), "columns")
			tc.check(Inventory.rows_for(count, columns) * columns >= count, "the rows fit every item")
	)
	assert_bool(result.passed).override_failure_message(result.report).is_true()


func test_every_stocked_item_has_a_price() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			var item: String = tc.draw(Gs.sampled_from(Inventory.STOCK), "item")
			tc.check(Inventory.price_of(item) > 0, "a positive price")
	)
	assert_bool(result.passed).override_failure_message(result.report).is_true()
