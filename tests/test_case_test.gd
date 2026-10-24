extends GdUnitTestSuite
## HegelTestCase: draws, terminal events and simplest mode.

const Gs := preload("res://addons/hegel/generators.gd")


func _settings() -> HegelSettings:
	var settings := HegelSettings.new()
	settings.seed = 1
	settings.has_seed = true
	settings.database = ""
	settings._silent = true
	return settings


func test_draw_respects_the_bounds() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			var x: int = tc.draw(Gs.integers(-3, 5))
			tc.check(x >= -3 and x <= 5),
		_settings()
	)
	assert_bool(result.passed).is_true()


func test_check_and_assume_return_their_condition() -> void:
	var returned: Array[bool] = []
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			returned.assign(
				[tc.check(true), tc.assume(true), tc.check(false), tc.assume(false), tc.check(false)]
			),
		_settings()
	)
	assert_array(returned).is_equal([true, true, false, false, false])


func test_check_origin_is_the_calling_line() -> void:
	var line := [0]
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			line[0] = get_stack()[0].line + 1
			tc.check(false, "the message is not in the origin"),
		_settings()
	)
	assert_str(result.failures[0].origin).is_equal("check: res://tests/test_case_test.gd:%d" % line[0])


func test_report_shows_the_first_failed_check() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			tc.check(false, "first")
			tc.check(false, "second"),
		_settings()
	)
	assert_str(result.report).contains("Check failed: first (res://tests/test_case_test.gd:")
	assert_str(result.report).not_contains("second")


func test_failed_check_then_assume_stays_a_failure() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			tc.check(false)
			tc.assume(false),
		_settings()
	)
	assert_int(result.error_kind).is_equal(HegelResult.ErrorKind.NONE)
	assert_int(result.failures.size()).is_equal(1)


func test_failed_assume_then_check_stays_rejected() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			tc.assume(false)
			tc.check(false),
		_settings()
	)
	assert_array(result.failures).is_empty()
	assert_int(result.error_kind).is_equal(HegelResult.ErrorKind.UNSATISFIABLE)


func test_draws_after_a_terminal_event_are_simplest_values() -> void:
	var after: Array[int] = []
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			if tc.check(tc.draw(Gs.integers(0, 1000)) < 500):
				return
			for i: int in 20:
				after.append(tc.draw(Gs.integers(5, 1_000_000)))
				after.append(tc.draw(Gs.integers(-1_000_000, -5)))
				after.append(tc.draw(Gs.integers(-1_000_000, 1_000_000))),
		_settings()
	)
	assert_array(after).is_not_empty()
	for i: int in after.size():
		assert_int(after[i]).is_equal([5, -5, 0][i % 3])


func test_invalid_draw_is_a_usage_error_not_a_failure() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			var x: int = tc.draw(Gs.integers(5, 1))
			tc.check(x == 5),
		_settings()
	)
	assert_array(result.failures).is_empty()
	assert_int(result.error_kind).is_equal(HegelResult.ErrorKind.USAGE)
	assert_str(result.error).is_not_empty()
	assert_int(result.test_cases).is_equal(1)


func test_notes_are_in_the_report_in_order() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			tc.note("one")
			tc.note("two")
			tc.check(false),
		_settings()
	)
	assert_str(result.report).contains("\n  one\n  two\n")


func test_generator_without_draw_is_a_usage_error() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void: tc.draw(HegelGenerator.new()), _settings()
	)
	assert_int(result.error_kind).is_equal(HegelResult.ErrorKind.USAGE)
	assert_str(result.error).contains("_draw")
