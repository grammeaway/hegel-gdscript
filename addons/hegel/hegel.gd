class_name Hegel
extends RefCounted
## Property-based testing for GDScript, on Hegel's engine.
##
## [codeblock]
## const Gs := preload("res://addons/hegel/generators.gd")
##
## func test_addition_commutes() -> void:
##     var result := Hegel.run(func(tc: HegelTestCase) -> void:
##         var x: int = tc.draw(Gs.integers())
##         var y: int = tc.draw(Gs.integers())
##         tc.check(x + y == y + x, "x + y == y + x")
##     )
##     assert_bool(result.passed).is_true()
## [/codeblock]

static var _lock := Mutex.new()
## Ids of the threads with a run in progress.
static var _running := {}


## Runs [param body] as a property test: once per test case, each time with a
## fresh [HegelTestCase] to draw values from. A case fails at a failed
## [method HegelTestCase.check], and the engine then shrinks it to a minimal
## failing case. [param settings] defaults to [code]HegelSettings.new()[/code].
## [br][br]
## A run can't start inside another run's body: that inner run returns a
## [constant HegelResult.ErrorKind.USAGE] error.
static func run(body: Callable, settings: HegelSettings = null) -> HegelResult:
	var thread := OS.get_thread_caller_id()
	_lock.lock()
	var nested: bool = _running.has(thread)
	_running[thread] = true
	_lock.unlock()
	if nested:
		return HegelResult._errored(
			HegelResult.ErrorKind.USAGE,
			(
				"Hegel.run was called inside the body of another Hegel.run."
				+ " Draw what it needs in the outer body instead."
			)
		)
	var result := _drive(body, settings if settings else HegelSettings.new())
	_lock.lock()
	_running.erase(thread)
	_lock.unlock()
	return result


static func _drive(body: Callable, settings: HegelSettings) -> HegelResult:
	if not body.is_valid():
		return HegelResult._errored(HegelResult.ErrorKind.USAGE, "Hegel.run needs a valid Callable")
	var native_settings := settings._to_native()
	if native_settings.last_result != HegelNative.OK:
		return HegelResult._errored(HegelResult.ErrorKind.USAGE, native_settings.last_error)
	var run := HegelNativeRun.new()
	if run.start(native_settings) != HegelNative.OK:
		return HegelResult._errored(HegelResult.ErrorKind.USAGE, run.last_error)
	var test_cases := 0
	while true:
		var native_tc := run.next_test_case()
		_print_output(run)
		if native_tc == null:
			break
		var tc := HegelTestCase.new(native_tc)
		body.call(tc)
		test_cases += 1
		if tc._run_error_kind != HegelResult.ErrorKind.NONE:
			return HegelResult._errored(tc._run_error_kind, tc._run_error, test_cases)
		if native_tc.mark_complete(tc._status, tc._origin) != HegelNative.OK:
			return _internal_error("mark_complete", native_tc.last_error, test_cases)
	if run.last_result != HegelNative.OK:
		return _internal_error("next_test_case", run.last_error, test_cases)
	var native_result := run.result()
	_print_output(run)
	if native_result == null:
		return _internal_error("result", run.last_error, test_cases)
	return HegelResult._from_native(native_result, test_cases)


static func _internal_error(call_name: String, message: String, test_cases: int) -> HegelResult:
	return HegelResult._errored(
		HegelResult.ErrorKind.INTERNAL, "%s failed: %s" % [call_name, message], test_cases
	)


static func _print_output(run: HegelNativeRun) -> void:
	for line: String in run.drain_output():
		printerr(line)
