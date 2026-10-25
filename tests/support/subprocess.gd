extends RefCounted
## Runs a script in a fresh Godot process, for the report snapshot tests (D1c).


## Regex and replacement pairs for [method scrub].
const _PATTERNS := [
	['Hegel\\.replay\\("[^"]+"', 'Hegel.replay("[blob]"'],
	["at: (\\w+) \\((?!res://)[^)]*\\)", "at: $1 ([godot])"],
	["(res://addons/hegel/[\\w/]+\\.gd):\\d+", "$1"],
	# Godot's Linux and macOS builds indent a SCRIPT ERROR's lines further than Windows does.
	["(?m)^ +(at: |GDScript backtrace)", "   $1"],
	["(?m)^ +(\\[\\d+\\] )", "       $1"],
]


## A finished process: its exit code and its scrubbed, combined output.
class Outcome:
	extends RefCounted
	var exit_code: int
	var output: String


## Runs [param script] headless in this project, and scrubs its output.
## [param user_args] reach the script through [method OS.get_cmdline_user_args].
static func run(script: String, user_args: PackedStringArray = []) -> Outcome:
	var project := ProjectSettings.globalize_path("res://")
	var args: PackedStringArray = ["--headless", "--path", project, "-s", script, "--"]
	args.append_array(user_args)
	var output := []
	var outcome := Outcome.new()
	outcome.exit_code = OS.execute(OS.get_executable_path(), args, output, true)
	outcome.output = scrub("".join(output))
	return outcome


## Runs gdUnit4's command-line tool headless on [param path], a suite or a
## directory of them, with its colour codes and CRs stripped from the output. gdUnit4
## reads its options before [method run]'s "--", so it can't go through it.
static func run_gdunit4(path: String) -> Outcome:
	var args: PackedStringArray = [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"-s",
		"res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
		"--ignoreHeadlessMode",
		"-c",
		"-a",
		path,
		"-rd",
		"user://gdunit4_nested_reports",
	]
	var output := []
	var outcome := Outcome.new()
	outcome.exit_code = OS.execute(OS.get_executable_path(), args, output, true)
	var text := "".join(output).replace("\r\n", "\n")
	outcome.output = RegEx.create_from_string("\u001b\\[[0-9;]*m").sub(text, "", true)
	return outcome


## [param text] without what varies between runs and machines: the banner,
## blobs, absolute paths, Godot's source locations, and the addon's line numbers.
static func scrub(text: String) -> String:
	var lines: PackedStringArray = []
	for line: String in text.replace("\r\n", "\n").split("\n"):
		if not (line.begins_with("Initialize godot-rust") or line.begins_with("Godot Engine v")):
			lines.append(line)
	var scrubbed := "\n".join(lines).strip_edges() + "\n"
	scrubbed = scrubbed.replace(ProjectSettings.globalize_path("res://").trim_suffix("/"), "[path]")
	scrubbed = scrubbed.replace(OS.get_user_data_dir(), "[path]")
	for pattern: Array in _PATTERNS:
		scrubbed = RegEx.create_from_string(pattern[0]).sub(scrubbed, pattern[1], true)
	return scrubbed
