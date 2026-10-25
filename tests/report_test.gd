extends GdUnitTestSuite
## The failure report, draw names and Hegel.replay.

const Gs := preload("res://addons/hegel/generators.gd")


## A generator whose value is made of two nested draws.
class _Pair:
	extends HegelGenerator

	func _draw(tc: HegelTestCase) -> Variant:
		return [tc.draw(Gs.integers(0, 0)), tc.draw(Gs.integers(1, 1))]


func _settings(test_cases := 100) -> HegelSettings:
	var settings := HegelSettings.new()
	settings.test_cases = test_cases
	settings.seed = 1
	settings.has_seed = true
	settings.database = ""
	settings._silent = true
	return settings


## The report's lines between its header and the failure line.
func _body_lines(result: HegelResult) -> PackedStringArray:
	var lines := result.report.split("\n")
	var failure := lines.find("") + 1
	var end := lines.find("", failure)
	return lines.slice(failure, end) if failure > 0 else PackedStringArray()


func _fails_from_10(tc: HegelTestCase) -> void:
	var x: int = tc.draw(Gs.integers(0, 1000))
	tc.check(x < 10, "x < 10")


func test_report_frames_the_shrunk_case() -> void:
	var line := [0]
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			var x: int = tc.draw(Gs.integers(0, 1000))
			line[0] = get_stack()[0].line + 1
			tc.check(x < 10, "x < 10"),
		_settings()
	)
	var lines := result.report.split("\n")
	assert_array(Array(lines)).has_size(7)
	assert_str(lines[0]).is_equal(
		"--- Failure: res://tests/report_test.gd::test_report_frames_the_shrunk_case ---"
	)
	assert_str(lines[1]).starts_with("Falsified after ").ends_with(" test cases (0 discarded):")
	assert_array(Array(lines.slice(2, 5))).is_equal(["", "  var draw_1 = 10", ""])
	assert_str(lines[5]).is_equal("Check failed: x < 10 (res://tests/report_test.gd:%d)" % line[0])
	assert_str(lines[6]).is_equal(
		'Reproduce with: Hegel.replay("%s", <body>)' % result.failures[0].blob
	)


func test_a_passing_run_has_no_report() -> void:
	assert_str(Hegel.run(func(_tc: HegelTestCase) -> void: pass, _settings()).report).is_empty()


## The report of a run that ended in an error is the error line it pushes.
func _assert_error_report(result: HegelResult, kind: HegelResult.ErrorKind) -> void:
	assert_int(result.error_kind).is_equal(kind)
	assert_str(result.error).is_not_empty()
	assert_str(result.report).is_equal(
		"Hegel run error (%s): %s" % [HegelResult.ErrorKind.find_key(kind), result.error]
	)


func test_a_run_that_errors_reports_its_error() -> void:
	_assert_error_report(
		Hegel.run(func(tc: HegelTestCase) -> void: tc.assume(false), _settings()),
		HegelResult.ErrorKind.UNSATISFIABLE
	)
	_assert_error_report(
		Hegel.run(func(tc: HegelTestCase) -> void: tc.draw(Gs.sampled_from([])), _settings()),
		HegelResult.ErrorKind.USAGE
	)
	_assert_error_report(Hegel.replay("", _fails_from_10, _settings()), HegelResult.ErrorKind.USAGE)
	var inner: Array[HegelResult] = []
	Hegel.run(
		func(_tc: HegelTestCase) -> void:
			inner.append(Hegel.run(func(_tc: HegelTestCase) -> void: pass, _settings())),
		_settings(1)
	)
	assert_array(inner).is_not_empty()
	_assert_error_report(inner[0], HegelResult.ErrorKind.USAGE)


func test_report_without_lines_has_no_body() -> void:
	var result := Hegel.run(func(tc: HegelTestCase) -> void: tc.check(false), _settings())
	var lines := result.report.split("\n")
	assert_str(lines[1]).is_equal("Falsified after 1 test case (0 discarded):")
	assert_str(lines[2]).starts_with("Check failed (res://tests/report_test.gd:")


func test_discarded_cases_before_the_failure_are_counted() -> void:
	var calls := [0]
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			calls[0] += 1
			# A body that draws nothing has one possible input, so the engine stops at its rejection.
			tc.draw(Gs.integers(0, 10))
			if not tc.assume(calls[0] > 2):
				return
			tc.check(false),
		_settings()
	)
	assert_str(result.report.split("\n")[1]).is_equal("Falsified after 1 test case (2 discarded):")
	assert_array(Array(_body_lines(result))).has_size(1)


func test_multiple_failures_are_each_shrunk_and_reported() -> void:
	var settings := _settings()
	settings.report_multiple_failures = true
	var result := Hegel.run(_fails_low_and_high, settings)
	assert_int(result.failures.size()).is_equal(2)
	var reports := result.report.split("\n\n--- Failure")
	assert_array(Array(reports)).has_size(2)
	assert_str(result.report).contains("  var draw_1 = 10\n").contains("  var draw_1 = 60\n")
	settings.report_multiple_failures = false
	assert_int(Hegel.run(_fails_low_and_high, settings).failures.size()).is_equal(1)


func _fails_low_and_high(tc: HegelTestCase) -> void:
	var x: int = tc.draw(Gs.integers(0, 100))
	if x < 50:
		tc.check(x < 10, "low")
	else:
		tc.check(x < 60, "high")


func test_unnamed_draws_are_numbered() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			tc.draw(Gs.integers(1, 1))
			tc.draw(Gs.integers(2, 2))
			tc.check(false),
		_settings()
	)
	assert_array(Array(_body_lines(result))).is_equal(["  var draw_1 = 1", "  var draw_2 = 2"])


func test_a_name_shows_bare_then_numbered() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			for i: int in 3:
				tc.draw(Gs.integers(i, i), "x")
			tc.draw(Gs.integers(3, 3), "count")
			tc.check(false),
		_settings()
	)
	assert_array(Array(_body_lines(result))).is_equal(
		["  var x = 0", "  var x_2 = 1", "  var x_3 = 2", "  var count = 3"]
	)


func test_numbered_names_skip_names_already_shown() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			tc.draw(Gs.integers(0, 0), "x_2")
			tc.draw(Gs.integers(1, 1), "x")
			tc.draw(Gs.integers(2, 2), "x")
			tc.check(false),
		_settings()
	)
	assert_array(Array(_body_lines(result))).is_equal(
		["  var x_2 = 0", "  var x = 1", "  var x_3 = 2"]
	)


func test_draws_inside_a_generator_are_part_of_its_value() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			tc.draw(_Pair.new())
			tc.draw(Gs.integers(2, 2))
			tc.check(false),
		_settings()
	)
	assert_array(Array(_body_lines(result))).is_equal(["  var draw_1 = [0, 1]", "  var draw_2 = 2"])


func test_notes_and_draws_interleave_and_multi_line_notes_are_indented() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			tc.note("before")
			tc.draw(Gs.integers(1, 1))
			tc.note("first line\nsecond line")
			tc.check(false),
		_settings()
	)
	assert_array(Array(_body_lines(result))).is_equal(
		["  before", "  var draw_1 = 1", "  first line", "  second line"]
	)


func test_nothing_after_the_terminal_event_is_shown() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			tc.draw(Gs.integers(1, 1))
			tc.check(false)
			tc.draw(Gs.integers(2, 2))
			tc.note("after"),
		_settings()
	)
	assert_array(Array(_body_lines(result))).is_equal(["  var draw_1 = 1"])


func test_quiet_drops_the_drawn_values_and_notes() -> void:
	var settings := _settings()
	settings.verbosity = HegelSettings.Verbosity.QUIET
	var result := Hegel.run(_fails_from_10, settings)
	var lines := result.report.split("\n")
	assert_array(Array(lines)).has_size(4)
	assert_str(lines[2]).starts_with("Check failed: x < 10")
	assert_str(lines[3]).starts_with("Reproduce with: ")


func test_replay_reproduces_the_report_body() -> void:
	var failed := Hegel.run(_fails_from_10, _settings())
	var blob := failed.failures[0].blob
	var replayed := Hegel.replay(blob, _fails_from_10, _settings())
	assert_bool(replayed.passed).is_false()
	assert_int(replayed.failures.size()).is_equal(1)
	assert_str(replayed.failures[0].origin).is_equal(failed.failures[0].origin)
	assert_str(replayed.failures[0].blob).is_equal(blob)
	assert_array(Array(replayed.report.split("\n").slice(2))).is_equal(
		Array(failed.report.split("\n").slice(2))
	)
	assert_str(replayed.report.split("\n")[1]).is_equal("Falsified after 1 test case (0 discarded):")


func test_replay_of_a_fixed_failure_did_not_reproduce() -> void:
	var blob := Hegel.run(_fails_from_10, _settings()).failures[0].blob
	var replayed := Hegel.replay(
		blob, func(tc: HegelTestCase) -> void: tc.draw(Gs.integers(0, 1000)), _settings()
	)
	assert_bool(replayed.passed).is_false()
	assert_int(replayed.error_kind).is_equal(HegelResult.ErrorKind.DID_NOT_REPRODUCE)
	assert_str(replayed.error).starts_with("Hegel.replay: the blob did not reproduce a failure.")
	_assert_error_report(replayed, HegelResult.ErrorKind.DID_NOT_REPRODUCE)


func test_replay_drawing_past_the_blob_overruns_and_did_not_reproduce() -> void:
	var drawless := Hegel.run(func(tc: HegelTestCase) -> void: tc.check(false), _settings())
	var blob := drawless.failures[0].blob
	var statuses: Array[int] = []
	var replayed := Hegel.replay(
		blob,
		func(tc: HegelTestCase) -> void:
			tc.draw(Gs.integers(0, 1000))
			statuses.append(tc._status)
			tc.check(false),
		_settings()
	)
	assert_int(replayed.error_kind).is_equal(HegelResult.ErrorKind.DID_NOT_REPRODUCE)
	assert_array(statuses).is_not_empty()
	assert_array(statuses).contains_same([HegelNativeTestCase.STATUS_OVERRUN])
	assert_array(statuses).not_contains([HegelNativeTestCase.STATUS_VALID])


func test_replay_of_a_bad_blob_is_a_usage_error() -> void:
	for blob: String in ["", "not a blob"]:
		var replayed := Hegel.replay(blob, _fails_from_10, _settings())
		assert_int(replayed.error_kind).is_equal(HegelResult.ErrorKind.USAGE)
		assert_str(replayed.error).is_not_empty()
