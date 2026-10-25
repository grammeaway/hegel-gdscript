extends SceneTree
## Runs property tests without a test framework:
## [codeblock]
## godot --headless --path . -s res://addons/hegel/cli/run.gd -- res://tests/properties/
## [/codeblock]
## Each argument is a [code].gd[/code] file or a directory searched for them,
## subdirectories included. Every method named [code]test_*[/code] runs on a
## new instance of its script. A test fails when it logs an error outside a
## property body: a [method Hegel.run] that fails pushes one, and so does a
## script error in the test itself. Prints each test's outcome and a summary,
## then exits with 1 if any test failed, or 0.

const _USAGE := "Usage: godot --headless --path . -s res://addons/hegel/cli/run.gd -- <path>..."


## Counts errors logged while no property runs: those inside a body are the
## run's to judge.
class _Errors:
	extends Logger
	var _lock := Mutex.new()
	var _count := 0

	## The errors counted since the last call.
	func take() -> int:
		_lock.lock()
		var count := _count
		_count = 0
		_lock.unlock()
		return count

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		_code: String,
		_rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type != ERROR_TYPE_SCRIPT and error_type != ERROR_TYPE_ERROR:
			return
		if Hegel._in_progress():
			return
		_lock.lock()
		_count += 1
		_lock.unlock()


func _initialize() -> void:
	quit(_run(OS.get_cmdline_user_args()))


func _run(paths: PackedStringArray) -> int:
	if paths.is_empty():
		printerr(_USAGE)
		return 1
	var files: PackedStringArray = []
	for path: String in paths:
		if path.get_extension() == "gd" and FileAccess.file_exists(path):
			files.append(path)
		elif DirAccess.dir_exists_absolute(path):
			files.append_array(_scripts_in(path))
		else:
			printerr("No such file or directory: " + path)
			return 1
	var errors := _Errors.new()
	OS.add_logger(errors)
	var passed := 0
	var failed := 0
	for file: String in files:
		var script := load(file) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL %s: the script does not load" % file)
			failed += 1
			continue
		for test: String in _tests_of(script):
			errors.take()
			var instance: Object = script.new()
			instance.call(test)
			if not instance is RefCounted:
				instance.free()
			var ok := errors.take() == 0
			print("%s %s::%s" % ["PASS" if ok else "FAIL", file, test])
			if ok:
				passed += 1
			else:
				failed += 1
	OS.remove_logger(errors)
	if passed + failed == 0:
		print("No tests found in " + ", ".join(paths))
	print("%d passed, %d failed" % [passed, failed])
	return 1 if failed else 0


## The [code].gd[/code] files under [param dir], sorted, subdirectories included.
static func _scripts_in(dir: String) -> PackedStringArray:
	var base := dir.trim_suffix("/") + "/"
	var files: PackedStringArray = []
	for file: String in DirAccess.get_files_at(base):
		if file.get_extension() == "gd":
			files.append(base + file)
	for subdir: String in DirAccess.get_directories_at(base):
		files.append_array(_scripts_in(base + subdir))
	files.sort()
	return files


## The script's [code]test_*[/code] methods, each once, in declaration order.
static func _tests_of(script: GDScript) -> PackedStringArray:
	var tests: PackedStringArray = []
	for method: Dictionary in script.get_script_method_list():
		var name: String = method.name
		if name.begins_with("test_") and not tests.has(name):
			tests.append(name)
	return tests
