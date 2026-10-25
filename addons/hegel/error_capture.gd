extends Logger
## Internal: hands each error Godot logs while a test body runs to that case,
## which fails on it (D11) or collects it for [method HegelTestCase.expect_errors].
## Script errors and errors ([method @GlobalScope.push_error] and the engine's
## own) count; warnings don't.

# shortcut: an error from any thread counts against the body running at the
# time, so concurrent runs on several threads catch each other's errors; filter
# by thread if parallel runs are ever supported.

## Godot calls [method _log_error] on the thread that raised the error.
var _lock := Mutex.new()
var _case: HegelTestCase
## Frames in these scripts are the addon's, not the user's code.
var _addon_dir: String
## The frame that called the body, where a backtrace leaves the user's code.
var _runner: String


func _init() -> void:
	_addon_dir = (get_script() as Script).resource_path.get_base_dir() + "/"
	_runner = _addon_dir + "hegel.gd"


## Captures errors into [param tc] from now on; null stops capturing.
func capture_into(tc: HegelTestCase) -> void:
	_lock.lock()
	_case = tc
	_lock.unlock()


func _log_error(
	_function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	script_backtraces: Array[ScriptBacktrace]
) -> void:
	if error_type != ERROR_TYPE_SCRIPT and error_type != ERROR_TYPE_ERROR:
		return
	var script_error := error_type == ERROR_TYPE_SCRIPT
	var location := "%s:%d" % [file, line]
	var frames: PackedStringArray = []
	var backtrace := _first_backtrace(script_backtraces)
	if backtrace:
		location = _user_location(backtrace)
		for i: int in backtrace.get_frame_count():
			if backtrace.get_frame_file(i) == _runner:
				break
			frames.append(
				(
					"  at %s (%s:%d)"
					% [
						backtrace.get_frame_function(i),
						backtrace.get_frame_file(i),
						backtrace.get_frame_line(i)
					]
				)
			)
	var message := rationale if rationale else code
	var failure := "%s: %s (%s)" % ["Script error" if script_error else "Error", message, location]
	if frames:
		failure += "\n" + "\n".join(frames)
	# The message stays out of the origin: it carries values, and the same
	# site failing with different values is one bug.
	var origin := ("script error: " if script_error else "error: ") + location
	_lock.lock()
	if _case:
		_case._on_error(script_error, message, origin, failure)
	_lock.unlock()


static func _first_backtrace(backtraces: Array[ScriptBacktrace]) -> ScriptBacktrace:
	for backtrace: ScriptBacktrace in backtraces:
		if not backtrace.is_empty():
			return backtrace
	return null


## [code]file:line[/code] of the innermost frame outside the addon, as
## upstream's Python frontend; the innermost frame if every one is the addon's.
func _user_location(backtrace: ScriptBacktrace) -> String:
	var frame := 0
	for i: int in backtrace.get_frame_count():
		if not backtrace.get_frame_file(i).begins_with(_addon_dir):
			frame = i
			break
	return "%s:%d" % [backtrace.get_frame_file(frame), backtrace.get_frame_line(frame)]
