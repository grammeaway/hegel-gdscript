extends GdUnitTestSuite
## The plain runner, addons/hegel/cli/run.gd, run in a fresh process on the
## fixtures beside this suite.

const Subprocess := preload("res://tests/support/subprocess.gd")
const RUNNER := "res://addons/hegel/cli/run.gd"
const FIXTURES := "res://tests/cli/fixtures/"
const SCRATCH := "user://cli_run_test/"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH)


func after_test() -> void:
	for file: String in DirAccess.get_files_at(SCRATCH):
		DirAccess.remove_absolute(SCRATCH + file)
	DirAccess.remove_absolute(SCRATCH)


func test_a_passing_directory_exits_0() -> void:
	var outcome := Subprocess.run(RUNNER, [FIXTURES + "passing"])
	assert_int(outcome.exit_code).is_zero()
	var lines := outcome.output.split("\n")
	assert_array(lines).contains(
		[
			"PASS res://tests/cli/fixtures/passing/nested/arithmetic.gd::test_addition_commutes",
			"PASS res://tests/cli/fixtures/passing/sorting.gd::test_sorting_is_idempotent",
			(
				"PASS res://tests/cli/fixtures/passing/sorting.gd"
				+ "::test_errors_after_a_rejection_are_left_to_hegel"
			),
			"3 passed, 0 failed",
		]
	)
	assert_str(outcome.output).not_contains("helper_is_not_a_test").not_contains("leaked")


func test_a_failing_property_exits_1_with_its_report() -> void:
	var outcome := Subprocess.run(RUNNER, [FIXTURES + "failing"])
	assert_int(outcome.exit_code).is_equal(1)
	var lines := outcome.output.split("\n")
	assert_array(lines).contains(
		[
			"PASS res://tests/cli/fixtures/failing/properties.gd::test_passes",
			"FAIL res://tests/cli/fixtures/failing/properties.gd::test_property_fails",
			"FAIL res://tests/cli/fixtures/failing/properties.gd::test_setup_error_fails",
			"1 passed, 2 failed",
			"  var draw_1 = 10",
		]
	)
	assert_str(outcome.output).contains("Check failed: x < 10")


func test_a_file_runs_on_its_own() -> void:
	var outcome := Subprocess.run(RUNNER, [FIXTURES + "passing/sorting.gd"])
	assert_int(outcome.exit_code).is_zero()
	assert_array(outcome.output.split("\n")).contains(["2 passed, 0 failed"])


func test_several_paths_run_together() -> void:
	var outcome := Subprocess.run(RUNNER, [FIXTURES + "passing", FIXTURES + "failing"])
	assert_int(outcome.exit_code).is_equal(1)
	assert_array(outcome.output.split("\n")).contains(["4 passed, 2 failed"])


func test_an_empty_directory_exits_0_and_says_so() -> void:
	var outcome := Subprocess.run(RUNNER, [SCRATCH])
	assert_int(outcome.exit_code).is_zero()
	assert_str(outcome.output).contains("No tests found in " + SCRATCH)


func test_a_script_that_does_not_load_fails() -> void:
	FileAccess.open(SCRATCH + "broken.gd", FileAccess.WRITE).store_string(
		"func test_broken() -> void\n\tpass\n"
	)
	var outcome := Subprocess.run(RUNNER, [SCRATCH])
	assert_int(outcome.exit_code).is_equal(1)
	assert_array(outcome.output.split("\n")).contains(
		["FAIL %sbroken.gd: the script does not load" % SCRATCH, "0 passed, 1 failed"]
	)


func test_a_missing_path_exits_1() -> void:
	var outcome := Subprocess.run(RUNNER, [FIXTURES + "missing"])
	assert_int(outcome.exit_code).is_equal(1)
	assert_str(outcome.output).contains("No such file or directory: " + FIXTURES + "missing")


func test_no_paths_exits_1_with_usage() -> void:
	var outcome := Subprocess.run(RUNNER)
	assert_int(outcome.exit_code).is_equal(1)
	assert_str(outcome.output).contains("Usage:")
