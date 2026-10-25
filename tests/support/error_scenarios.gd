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


## A rule that fills one slot per step, and runs out on the third.
class _Slots:
	extends HegelStateMachine
	var slots := [0, 0]
	var count := 0
	var scenarios: Object

	func _init(owner: Object) -> void:
		scenarios = owner

	func rule_fill(_tc: HegelTestCase) -> void:
		scenarios._mark()
		slots[count] = 1
		count += 1


func error_in_a_rule() -> Dictionary:
	return _summary(
		Hegel.run(func(tc: HegelTestCase) -> void: _Slots.new(self).run(tc), _quiet())
	)


## Every case expects the error its input provokes, and checks the message.
func expected_push_error() -> Dictionary:
	return _expecting(
		func(tc: HegelTestCase) -> PackedStringArray:
			var x: int = tc.draw(Gs.integers(0, 10))
			var errors := tc.expect_errors(func() -> void: push_error("bad input ", x))
			tc.check(errors == PackedStringArray(["bad input %d" % x]), "the error is collected")
			return errors
	)


func script_error_in_expect_errors() -> Dictionary:
	return _expecting(
		func(tc: HegelTestCase) -> PackedStringArray:
			var x: int = tc.draw(Gs.integers(0, 10))
			return tc.expect_errors(func() -> void: _inner(x))
	)


func push_error_after_expect_errors() -> Dictionary:
	return _expecting(
		func(tc: HegelTestCase) -> PackedStringArray:
			var errors := tc.expect_errors(func() -> void: push_error("expected"))
			_mark()
			push_error("after ", tc.draw(Gs.integers(0, 10)))
			return errors
	)


func expected_engine_error() -> Dictionary:
	return _expecting(
		func(tc: HegelTestCase) -> PackedStringArray:
			tc.draw(Gs.integers(0, 10))
			var node := Node.new()
			var errors := tc.expect_errors(func() -> void: node.get_node("missing"))
			node.free()
			return errors
	)


func expected_error_from_a_thread() -> Dictionary:
	return _expecting(
		func(tc: HegelTestCase) -> PackedStringArray:
			var x: int = tc.draw(Gs.integers(0, 10))
			return tc.expect_errors(
				func() -> void:
					var thread := Thread.new()
					thread.start(func() -> void: push_error("thread ", x))
					thread.wait_to_finish()
			)
	)


## Returns the outer call's errors, then the inner's.
func nested_expect_errors() -> Dictionary:
	return _expecting(
		func(tc: HegelTestCase) -> PackedStringArray:
			tc.draw(Gs.integers(0, 10))
			var inner: PackedStringArray = []
			var outer := tc.expect_errors(
				func() -> void:
					push_error("outer 1")
					inner.append_array(tc.expect_errors(func() -> void: push_error("inner")))
					push_error("outer 2")
			)
			return outer + inner
	)


## Runs [param body], which returns what its expect_errors collected, and adds
## the last case's to the summary as [code]collected[/code].
func _expecting(body: Callable) -> Dictionary:
	var collected: Array[PackedStringArray] = [PackedStringArray()]
	var outcome := _summary(
		Hegel.run(func(tc: HegelTestCase) -> void: collected[0] = body.call(tc), _quiet())
	)
	outcome.collected = collected[0]
	return outcome


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
