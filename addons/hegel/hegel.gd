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

const _STALE_BLOB := (
	"Hegel.replay: the blob did not reproduce a failure. The failure may have been"
	+ " fixed, or, for a nondeterministic blob, it may not have recurred within the"
	+ " replay budget (a bug failing 10% of the time escapes it about 5% of the time)."
	+ " Re-run to retry, or remove the replay once the failure is fixed."
)

static var _lock := Mutex.new()
## Ids of the threads with a run in progress.
static var _running := {}


## One origin's report material, captured as its case ran. Ranked as upstream:
## a case the engine stamped beats one that wasn't, and at equal rank the
## newest wins, so the final replay is what gets reported.
class _Capture:
	extends RefCounted
	var lines: PackedStringArray
	var failure: String
	var rank: int

	func _init(tc: HegelTestCase, stamped: bool) -> void:
		lines = tc._lines
		failure = tc._failure
		rank = 2 if stamped else (1 if lines else 0)


## Runs [param body] as a property test: once per test case, each time with a
## fresh [HegelTestCase] to draw values from. A case fails at a failed
## [method HegelTestCase.check], and the engine then shrinks it to a minimal
## failing case. [param settings] defaults to [code]HegelSettings.new()[/code].
## [br][br]
## On a failure, the report ([member HegelResult.report]) is printed to stderr
## and a one-line error is pushed, so a test framework that watches errors,
## like gdUnit4, fails the test. A run that ends in an error pushes its message.
## [br][br]
## Failures are saved in the database ([member HegelSettings.database]) under
## the script and function calling [method run], and replayed first next time.
## [br][br]
## A run can't start inside another run's body: that inner run returns a
## [constant HegelResult.ErrorKind.USAGE] error.
static func run(body: Callable, settings: HegelSettings = null) -> HegelResult:
	return _guarded(body, settings, "", _caller_key())


## Replays the failure [param blob] encodes, from a report's
## [code]Reproduce with[/code] line, and reports it as [method run] does. A blob
## that no longer fails gives a [constant HegelResult.ErrorKind.DID_NOT_REPRODUCE]
## error.
static func replay(blob: String, body: Callable, settings: HegelSettings = null) -> HegelResult:
	if not blob:
		return _announced(
			HegelResult._errored(
				HegelResult.ErrorKind.USAGE, "Hegel.replay needs the blob from a failure report"
			),
			settings if settings else HegelSettings.new()
		)
	return _guarded(body, settings, blob, _caller_key())


## Runs [method _drive] unless a run is already in progress on this thread.
## An empty [param blob] starts a fresh run.
static func _guarded(
	body: Callable, settings: HegelSettings, blob: String, key: String
) -> HegelResult:
	var resolved := settings if settings else HegelSettings.new()
	var thread := OS.get_thread_caller_id()
	_lock.lock()
	var nested: bool = _running.has(thread)
	_running[thread] = true
	_lock.unlock()
	if nested:
		return _announced(
			HegelResult._errored(
				HegelResult.ErrorKind.USAGE,
				(
					"Hegel.run was called inside the body of another Hegel.run."
					+ " Draw what it needs in the outer body instead."
				)
			),
			resolved
		)
	var result := _drive(body, resolved, blob, key)
	_lock.lock()
	_running.erase(thread)
	_lock.unlock()
	return _announced(result, resolved)


static func _drive(
	body: Callable, settings: HegelSettings, blob: String, key: String
) -> HegelResult:
	if not body.is_valid():
		return HegelResult._errored(HegelResult.ErrorKind.USAGE, "Hegel.run needs a valid Callable")
	var native_settings := settings._to_native(key)
	if native_settings.last_result != HegelNative.OK:
		return HegelResult._errored(HegelResult.ErrorKind.USAGE, native_settings.last_error)
	var run := HegelNativeRun.new()
	var started := run.start_blob(native_settings, blob) if blob else run.start(native_settings)
	if started != HegelNative.OK:
		return HegelResult._errored(HegelResult.ErrorKind.USAGE, run.last_error)
	var quiet := settings.verbosity == HegelSettings.Verbosity.QUIET
	var verbose := settings.verbosity >= HegelSettings.Verbosity.VERBOSE
	var captures := {}
	var test_cases := 0
	# Counted up to the first failure, as upstream does.
	var falsified_after := 0
	var discarded := 0
	var seen_failure := false
	while true:
		var native_tc := run.next_test_case()
		_print_output(run)
		if native_tc == null:
			break
		var stamped := native_tc.should_capture()
		if native_tc.last_result != HegelNative.OK:
			return _internal_error("should_capture", native_tc.last_error, test_cases)
		var tc := HegelTestCase.new(
			native_tc, (stamped and not quiet) or verbose, verbose and not settings._silent
		)
		body.call(tc)
		test_cases += 1
		if tc._run_error_kind != HegelResult.ErrorKind.NONE:
			return HegelResult._errored(tc._run_error_kind, tc._run_error, test_cases)
		if not seen_failure:
			match tc._status:
				HegelNativeTestCase.STATUS_VALID:
					falsified_after += 1
				HegelNativeTestCase.STATUS_INTERESTING:
					falsified_after += 1
					seen_failure = true
				HegelNativeTestCase.STATUS_INVALID:
					discarded += 1
		if tc._status == HegelNativeTestCase.STATUS_INTERESTING:
			var capture := _Capture.new(tc, stamped)
			var stored: _Capture = captures.get(tc._origin)
			if stored == null or capture.rank >= stored.rank:
				captures[tc._origin] = capture
		if native_tc.mark_complete(tc._status, tc._origin) != HegelNative.OK:
			return _internal_error("mark_complete", native_tc.last_error, test_cases)
	if run.last_result != HegelNative.OK:
		return _internal_error("next_test_case", run.last_error, test_cases)
	var native_result := run.result()
	_print_output(run)
	if native_result == null:
		return _internal_error("result", run.last_error, test_cases)
	var result := HegelResult._from_native(native_result, test_cases)
	if blob and result.passed:
		return HegelResult._errored(HegelResult.ErrorKind.DID_NOT_REPRODUCE, _STALE_BLOB, test_cases)
	var reports: PackedStringArray = []
	for failure: HegelResult.Failure in result.failures:
		var capture: _Capture = captures.get(failure.origin)
		if capture == null:
			return _internal_error(
				"result", "failure %s was never seen by the test" % failure.origin, test_cases
			)
		# A replay's failure has no blob of its own: the caller already holds it.
		if not failure.blob:
			failure.blob = blob
		reports.append(_report(key, falsified_after, discarded, capture, failure))
	result.report = "\n\n".join(reports)
	return result


## The framed failure report, after upstream's C++ frontend.
static func _report(
	key: String,
	falsified_after: int,
	discarded: int,
	capture: _Capture,
	failure: HegelResult.Failure
) -> String:
	var lines: PackedStringArray = [
		"--- Failure: %s ---" % key if key else "--- Failure ---",
		(
			"Falsified after %d test case%s (%d discarded):"
			% [falsified_after, "" if falsified_after == 1 else "s", discarded]
		),
	]
	if capture.lines:
		lines.append("")
		for line: String in capture.lines:
			for part: String in line.split("\n"):
				lines.append("  " + part)
		lines.append("")
	lines.append(capture.failure)
	if failure.caveat:
		lines.append("note: " + failure.caveat)
	if failure.blob:
		lines.append('Reproduce with: Hegel.replay("%s", <body>)' % failure.blob)
	return "\n".join(lines)


## Makes [param result] loud, unless the settings silence it.
static func _announced(result: HegelResult, settings: HegelSettings) -> HegelResult:
	if settings._silent:
		return result
	if result.error_kind != HegelResult.ErrorKind.NONE:
		var kind: String = HegelResult.ErrorKind.find_key(result.error_kind)
		push_error("Hegel run error (%s): %s" % [kind, result.error])
	elif not result.passed:
		printerr(result.report)
		var origins: PackedStringArray = []
		for failure: HegelResult.Failure in result.failures:
			origins.append(failure.origin)
		push_error("Hegel: property failed at %s; the report is above" % ", ".join(origins))
	return result


## [code]<script>::<function>[/code] of the code calling the caller of this
## function, or "" without a stack (in a release build, say).
static func _caller_key() -> String:
	var stack := get_stack()
	if stack.size() < 3:
		return ""
	return "%s::%s" % [stack[2].source, stack[2].function]


static func _internal_error(call_name: String, message: String, test_cases: int) -> HegelResult:
	return HegelResult._errored(
		HegelResult.ErrorKind.INTERNAL, "%s failed: %s" % [call_name, message], test_cases
	)


static func _print_output(run: HegelNativeRun) -> void:
	for line: String in run.drain_output():
		printerr(line)
