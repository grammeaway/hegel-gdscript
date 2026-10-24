class_name HegelTestCase
extends RefCounted
## One test case: the object a test body draws values from, and fails or
## rejects the case through.
##
## [method Hegel.run] passes one to the body per test case. A case ends at its
## first failed [method check], failed [method assume], or when the engine
## abandons it. From then on, draws return each generator's simplest value
## without generating anything, so the body can return early:
## [codeblock]
## var x: int = tc.draw(Gs.integers())
## if not tc.check(x * 2 >= x, "doubling doesn't shrink"):
##     return
## [/codeblock]

const _LABEL_PREFIX := "hegel-gdscript."

var _native: HegelNativeTestCase
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
		_end(HegelNativeTestCase.STATUS_INTERESTING, "check: " + location)
		_failure = (
			"Check failed: %s (%s)" % [message, location]
			if message
			else "Check failed (%s)" % location
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


## Marks the case's terminal event. Only the first one counts.
func _end(status: int, origin: String) -> void:
	if _ended:
		return
	_ended = true
	_status = status
	_origin = origin


## Ends the case, and the run with it, with an error rather than a verdict.
func _fail_run(kind: HegelResult.ErrorKind, message: String) -> void:
	if _ended:
		return
	_end(HegelNativeTestCase.STATUS_INVALID, "")
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


func _start_span(label: int) -> void:
	if not _ended:
		_native.start_span(label)
		_call_ok("start_span")


func _stop_span(discard := false) -> void:
	if not _ended:
		_native.stop_span(discard)
		_call_ok("stop_span")


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
