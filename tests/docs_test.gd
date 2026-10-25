extends GdUnitTestSuite
## Every ```gdscript block in the README and the guide runs, in a fresh
## process, derandomized and with the database off: gdUnit4 suites under
## gdUnit4, the rest under the plain runner. Each must pass, unless its fence
## reads ```gdscript fails, when each of its tests must fail. A block that
## doesn't declare Gs gets the guide's alias at the top, after any extends.

const Subprocess := preload("res://tests/support/subprocess.gd")
const DOCS: Array[String] = ["res://README.md", "res://docs/guide.md"]
const SNIPPETS := "user://doc_snippets/"
const KINDS: Array[String] = ["passing", "failing", "gdunit4"]
const PRELUDE := 'const Gs := preload("res://addons/hegel/generators.gd")'
const ENVIRONMENT := {"HEGEL_DERANDOMIZE": "true", "HEGEL_DATABASE": "disabled"}
const RUNNER := "res://addons/hegel/cli/run.gd"


func before() -> void:
	for name: String in ENVIRONMENT:
		OS.set_environment(name, ENVIRONMENT[name])
	for kind: String in KINDS:
		DirAccess.make_dir_recursive_absolute(SNIPPETS + kind)
		for file: String in DirAccess.get_files_at(SNIPPETS + kind):
			DirAccess.remove_absolute(SNIPPETS + kind + "/" + file)
	for doc: String in DOCS:
		_extract(doc)


func after() -> void:
	for name: String in ENVIRONMENT:
		OS.unset_environment(name)


func test_the_docs_have_snippets_of_each_kind() -> void:
	for kind: String in KINDS:
		assert_array(DirAccess.get_files_at(SNIPPETS + kind)).override_failure_message(
			"no %s snippets" % kind
		).is_not_empty()


func test_plain_snippets_pass() -> void:
	var outcome := Subprocess.run(RUNNER, [SNIPPETS + "passing"])
	assert_int(outcome.exit_code).override_failure_message(outcome.output).is_zero()


func test_failing_snippets_fail_in_their_tests() -> void:
	var outcome := Subprocess.run(RUNNER, [SNIPPETS + "failing"])
	assert_int(outcome.exit_code).override_failure_message(outcome.output).is_equal(1)
	assert_str(outcome.output).not_contains("PASS ").not_contains("does not load")


func test_gdunit4_snippets_pass() -> void:
	var outcome := Subprocess.run_gdunit4(SNIPPETS + "gdunit4")
	assert_int(outcome.exit_code).override_failure_message(outcome.output).is_zero()
	assert_str(outcome.output).contains(" PASSED")


## Writes each gdscript block in [param doc] to SNIPPETS/<kind>/<doc>_<line>.gd.
static func _extract(doc: String) -> void:
	var lines := FileAccess.get_file_as_string(doc).split("\n")
	var fence := -1
	for i: int in lines.size():
		if fence < 0 and lines[i].begins_with("```gdscript"):
			fence = i
		elif fence >= 0 and lines[i] == "```":
			var block := lines.slice(fence + 1, i)
			var kind := "failing" if lines[fence] == "```gdscript fails" else "passing"
			if block[0] == "extends GdUnitTestSuite":
				kind = "gdunit4"
			if not Array(block).any(func(line: String) -> bool: return line.begins_with("const Gs ")):
				# Lines as in a script that starts with the alias, so reports match the docs'.
				var at := 2 if block[0].begins_with("extends ") else 0
				for line: String in ["", "", PRELUDE]:
					block.insert(at, line)
			var path := "%s%s/%s_%d.gd" % [SNIPPETS, kind, doc.get_file().get_basename(), fence + 1]
			FileAccess.open(path, FileAccess.WRITE).store_string("\n".join(block) + "\n")
			fence = -1
