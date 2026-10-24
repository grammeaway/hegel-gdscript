extends "res://tests/support/subject.gd"
## Runtime-error scenarios for tests/error_capture_test.gd. Each runs in a
## fresh process, chosen by its function name as the first user argument, so
## the errors it provokes stay out of gdUnit4's logger (F7). It prints its
## outcome as one line: RESULT_PREFIX, then JSON.

const RESULT_PREFIX := "scenario result: "

## The source lines an error was provoked from, as "file:line".
var _sites := {}


func _run() -> void:
	var outcome: Dictionary = call(OS.get_cmdline_user_args()[0])
	outcome.sites = _sites.keys()
	print(RESULT_PREFIX + JSON.stringify(outcome))


func call_on_null() -> Dictionary:
	return _summary(
		Hegel.run(
			func(tc: HegelTestCase) -> void:
				tc.draw(Gs.integers(0, 10))
				var node: Node = null
				_mark()
				node.get_name(),
			_quiet()
		)
	)


func two_calls_deep() -> Dictionary:
	return _summary(
		Hegel.run(func(tc: HegelTestCase) -> void: _outer(tc.draw(Gs.integers(0, 10))), _quiet())
	)


func pushed_error() -> Dictionary:
	return _summary(
		Hegel.run(
			func(tc: HegelTestCase) -> void:
				var x: int = tc.draw(Gs.integers(0, 10))
				if x > 5:
					_mark()
					push_error("x is ", x),
			_quiet()
		)
	)


func pushed_warning() -> Dictionary:
	return _summary(
		Hegel.run(
			func(tc: HegelTestCase) -> void: push_warning("x is ", tc.draw(Gs.integers(0, 10))),
			_quiet()
		)
	)


func failed_assert() -> Dictionary:
	return _summary(
		Hegel.run(
			func(tc: HegelTestCase) -> void:
				var x: int = tc.draw(Gs.integers(0, 10))
				_mark()
				assert(x < 5, "x < 5"),
			_quiet()
		)
	)


func two_sites() -> Dictionary:
	var settings := _quiet()
	settings.report_multiple_failures = true
	return _summary(
		Hegel.run(
			func(tc: HegelTestCase) -> void:
				var x: int = tc.draw(Gs.integers(0, 100))
				if x < 50:
					_mark()
					push_error("low")
				else:
					_mark()
					push_error("high"),
			settings
		)
	)


## Reporting every distinct failure, so values in the origin would show as several.
func same_site_different_values() -> Dictionary:
	var settings := _quiet()
	settings.report_multiple_failures = true
	return _summary(Hegel.run(_index_out_of_bounds, settings))


func check_then_error() -> Dictionary:
	return _summary(
		Hegel.run(
			func(tc: HegelTestCase) -> void:
				tc.check(false, "always")
				push_error("after the check"),
			_quiet()
		)
	)


func error_then_check() -> Dictionary:
	return _summary(
		Hegel.run(
			func(tc: HegelTestCase) -> void:
				_mark()
				push_error("before the check")
				tc.check(false, "always"),
			_quiet()
		)
	)


## The last case of a passing run, unended, is where a capture left attached
## would put a later error.
func between_runs() -> Dictionary:
	var cases: Array[HegelTestCase] = []
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			cases.assign([tc])
			tc.draw(Gs.integers(0, 10)),
		_quiet()
	)
	push_error("between runs")
	var outcome := _summary(result)
	outcome.last_case_ended = cases[0]._ended
	outcome.next_passed = Hegel.run(func(_tc: HegelTestCase) -> void: pass, _quiet()).passed
	return outcome


func in_a_thread() -> Dictionary:
	return _summary(
		Hegel.run(
			func(tc: HegelTestCase) -> void:
				var thread := Thread.new()
				thread.start(_inner.bind(tc.draw(Gs.integers(0, 10))))
				thread.wait_to_finish(),
			_quiet()
		)
	)


func _outer(x: int) -> void:
	_inner(x)


func _inner(x: int) -> void:
	var a := [0]
	_mark()
	a[x] = 1


func _index_out_of_bounds(tc: HegelTestCase) -> void:
	var a := [0]
	var x: int = tc.draw(Gs.integers(0, 100))
	_mark()
	a[x] = 1


## Records the caller's next line as an error site.
func _mark() -> void:
	var frame: Dictionary = get_stack()[1]
	_sites["%s:%d" % [frame.source, frame.line + 1]] = true


func _quiet() -> HegelSettings:
	var settings := _settings()
	settings._silent = true
	return settings


func _summary(result: HegelResult) -> Dictionary:
	var origins: Array[String] = []
	for failure: HegelResult.Failure in result.failures:
		origins.append(failure.origin)
	return {
		passed = result.passed,
		error = result.error,
		origins = origins,
		report = result.report,
	}
