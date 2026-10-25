class_name HegelTestCase
extends RefCounted
## One test case: the object a test body draws values from, and fails or
## rejects the case through.
##
## [method Hegel.run] passes one to the body per test case. A case ends at its
## first failed [method check], runtime error (a script error or
## [method @GlobalScope.push_error]), failed [method assume], or when the engine
## abandons it. From then on, draws return each generator's simplest value
## without generating anything, so the body can return early:
## [codeblock]
## var x: int = tc.draw(Gs.integers())
## if not tc.check(x * 2 >= x, "doubling doesn't shrink"):
##     return
## [/codeblock]

const _LABEL_PREFIX := "hegel-gdscript."

var _native: HegelNativeTestCase
## Guards [method _end]: an error can end the case from another thread.
var _lock := Mutex.new()
## Whether the case has had its terminal event; see [method _end].
var _ended := false
var _status := HegelNativeTestCase.STATUS_VALID
var _origin := ""
## Set when the case ended the whole run with an error instead.
var _run_error_kind := HegelResult.ErrorKind.NONE
var _run_error := ""
## The failure report's line for the terminal event, when the case failed.
var _failure := ""
## The draw and note lines for the failure report, while [member _recording].
var _lines: PackedStringArray = []
var _recording: bool
## Whether recorded lines are also printed as they happen.
var _echo: bool
var _draw_depth := 0
## Uses of each draw name, and the names already shown, for [method _display_name].
var _name_counts := {}
var _shown_names := {}


func _init(native: HegelNativeTestCase, recording := false, echo := false) -> void:
	_native = native
	_recording = recording
	_echo = echo


## Draws a value from [param generator]. The failure report shows it as
## [code]var <name> = <value>[/code]: unnamed draws are [code]draw_1[/code],
## [code]draw_2[/code], …, and a [param name] used again gets [code]_2[/code],
## [code]_3[/code], …. Draws made inside a generator are part of its value,
## and aren't shown on their own.
func draw(generator: HegelGenerator, name := "") -> Variant:
	_draw_depth += 1
	_start_span(generator.label)
	var value: Variant = generator._draw(self)
	_stop_span()
	_draw_depth -= 1
	if _draw_depth == 0 and _records():
		_record("var %s = %s" % [_display_name(name), var_to_str(value)])
	return value


## Rejects the test case unless [param condition] holds, and returns
## [param condition]. A rejected case is neither a pass nor a failure, and
## doesn't count towards [member HegelSettings.test_cases]. Return from the
## body when it gives false.
func assume(condition: bool) -> bool:
	if not condition:
		_end(HegelNativeTestCase.STATUS_INVALID, "")
	return condition


## Fails the test case unless [param condition] holds, and returns
## [param condition]. [param message] says what was checked, for the failure
## report. Return from the body when it gives false.
func check(condition: bool, message := "") -> bool:
	if not condition and not _ended:
		var location := _caller_location()
		_end(
			HegelNativeTestCase.STATUS_INTERESTING,
			"check: " + location,
			"Check failed: %s (%s)" % [message, location] if message else "Check failed (%s)" % location
		)
	return condition


## Adds [param message] to the failure report, between the drawn values, in
## the order it was made.
func note(message: String) -> void:
	if _records():
		_record(message)


## Nothing is recorded after the terminal event, since upstream's body stops there.
func _records() -> bool:
	return _recording and not _ended


func _record(line: String) -> void:
	_lines.append(line)
	if _echo:
		printerr(line)


## Upstream's draw names: an unnamed draw counts up from [code]draw_1[/code];
## a name shows bare, then numbered from its use count, skipping names shown.
func _display_name(name: String) -> String:
	var base := name if name else "draw"
	var count: int = _name_counts.get(base, 0) + 1
	_name_counts[base] = count
	var shown := base
	if not name or count > 1 or _shown_names.has(base):
		var suffix := count
		shown = "%s_%d" % [base, suffix]
		while _shown_names.has(shown):
			suffix += 1
			shown = "%s_%d" % [base, suffix]
	_shown_names[shown] = true
	return shown


## Marks the case's terminal event, with [param failure] as its report line,
## and returns whether it was the first: only that one counts.
func _end(status: int, origin: String, failure := "") -> bool:
	_lock.lock()
	var first := not _ended
	if first:
		_ended = true
		_status = status
		_origin = origin
		_failure = failure
	_lock.unlock()
	return first


## Fails the case for a runtime error, as its terminal event.
func _fail_with_error(origin: String, failure: String) -> void:
	_end(HegelNativeTestCase.STATUS_INTERESTING, origin, failure)


## Ends the case, and the run with it, with an error rather than a verdict.
func _fail_run(kind: HegelResult.ErrorKind, message: String) -> void:
	if _end(HegelNativeTestCase.STATUS_INVALID, ""):
		_run_error_kind = kind
		_run_error = message


## The [code]source:line[/code] of the code calling the caller of this function.
static func _caller_location() -> String:
	var stack := get_stack()
	if stack.size() < 3:
		return "<unknown>"
	return "%s:%d" % [stack[2].source, stack[2].line]


## The span label for a built-in generator kind.
static func _label(kind: String) -> int:
	return HegelNative.label_from_name(_LABEL_PREFIX + kind)


# Primitives for generators. Once the case has ended they return the simplest
# value without calling the engine.


func _draw_integer(min_value: int, max_value: int) -> int:
	if _ended:
		return clampi(0, min_value, max_value)
	var value := _native.generate_integer(min_value, max_value)
	if not _call_ok("generate_integer"):
		return clampi(0, min_value, max_value)
	return value


func _draw_float(
	min_value: float,
	max_value: float,
	allow_nan: bool,
	allow_infinity: bool,
	exclude_min: bool,
	exclude_max: bool
) -> float:
	if not _ended:
		var value := _native.generate_float(
			min_value, max_value, allow_nan, allow_infinity, exclude_min, exclude_max
		)
		if _call_ok("generate_float"):
			return value
	var low := _next_up(min_value) if exclude_min else min_value
	var high := -_next_up(-max_value) if exclude_max else max_value
	return clampf(0.0, low, high)


func _draw_boolean() -> bool:
	if _ended:
		return false
	var value := _native.generate_boolean(0.5)
	return value if _call_ok("generate_boolean") else false


func _draw_string(generator: HegelNativeStringGenerator, simplest: String) -> String:
	if _ended:
		return simplest
	var value := _native.generate_string(generator)
	return value if _call_ok("generate_string") else simplest


## A collection of [param min_size] to [param max_size] elements; -1 is no
## upper bound. Loop on its [method _Collection.more], drawing one element each.
func _collection(min_size: int, max_size: int) -> _Collection:
	return _Collection.new(self, min_size, max_size)


## The smallest float above [param x], as the engine steps an excluded bound.
static func _next_up(x: float) -> float:
	if is_nan(x) or x == INF:
		return x
	var bytes := PackedByteArray()
	bytes.resize(8)
	# -0.0 steps up as 0.0 does. GDScript can't write the result as a literal:
	# it parses subnormal literals as 0.0.
	bytes.encode_double(0, 0.0 if x == 0.0 else x)
	# Read as a signed int, a positive float's bits grow with it, and a
	# negative float's shrink as it grows.
	var bits := bytes.decode_s64(0)
	bytes.encode_s64(0, bits + 1 if bits >= 0 else bits - 1)
	return bytes.decode_double(0)


func _start_span(label: int) -> void:
	if not _ended:
		_native.start_span(label)
		_call_ok("start_span")


func _stop_span(discard := false) -> void:
	if not _ended:
		_native.stop_span(discard)
		_call_ok("stop_span")


## The engine decides a collection's size. Once the case has ended it asks for
## elements only up to the minimum size, and stops at the first rejection, since
## a unique collection of simplest values would reject forever.
class _Collection:
	var _tc: HegelTestCase
	var _native: HegelNativeCollection
	var _min_size: int
	var _size := 0
	var _done := false

	func _init(tc: HegelTestCase, min_size: int, max_size: int) -> void:
		_tc = tc
		_min_size = min_size
		if not tc._ended:
			_native = tc._native.new_collection(min_size, max_size)
			tc._call_ok("new_collection")

	## Whether to draw another element.
	func more() -> bool:
		if _done:
			return false
		var wanted := _size < _min_size
		if not _tc._ended:
			var engine_wants := _tc._native.collection_more(_native)
			if _tc._call_ok("collection_more"):
				wanted = engine_wants
		if wanted:
			_size += 1
		else:
			_done = true
		return wanted

	## Discards the element just drawn, a duplicate say, so it doesn't count.
	func reject() -> void:
		_size -= 1
		if _tc._ended:
			_done = true
			return
		_tc._native.collection_reject(_native)
		_tc._call_ok("collection_reject")


## Turns a failed engine call into the case's terminal event.
func _call_ok(call_name: String) -> bool:
	match _native.last_result:
		HegelNative.OK:
			return true
		HegelNative.E_STOP_TEST:
			_end(HegelNativeTestCase.STATUS_OVERRUN, "")
		HegelNative.E_ASSUME:
			_end(HegelNativeTestCase.STATUS_INVALID, "")
		HegelNative.E_INVALID_ARG:
			_fail_run(HegelResult.ErrorKind.USAGE, _native.last_error)
		_:
			_fail_run(
				HegelResult.ErrorKind.INTERNAL,
				"%s failed (%d): %s" % [call_name, _native.last_result, _native.last_error]
			)
	return false
