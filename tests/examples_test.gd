extends GdUnitTestSuite
## The examples under examples/, each run in a fresh process the way a user
## would, derandomized and with the database off through HEGEL_* variables.

const Subprocess := preload("res://tests/support/subprocess.gd")
const ENVIRONMENT := {"HEGEL_DERANDOMIZE": "true", "HEGEL_DATABASE": "disabled"}


func before() -> void:
	for name: String in ENVIRONMENT:
		OS.set_environment(name, ENVIRONMENT[name])


func after() -> void:
	for name: String in ENVIRONMENT:
		OS.unset_environment(name)


func test_the_plain_example_finds_the_rounding_bug() -> void:
	var outcome := Subprocess.run("res://addons/hegel/cli/run.gd", ["res://examples/plain/"])
	assert_int(outcome.exit_code).is_equal(1)
	assert_array(outcome.output.split("\n")).contains(
		[
			"FAIL res://examples/plain/inventory_properties.gd::test_rows_fit_every_item",
			"PASS res://examples/plain/inventory_properties.gd::test_more_columns_never_need_more_rows",
			"1 passed, 1 failed",
			"  var count = 1",
			"  var columns = 2",
		]
	)


func test_the_gdunit4_example_fails_its_two_buggy_properties() -> void:
	var outcome := Subprocess.run_gdunit4("res://examples/gdunit4")
	var output := outcome.output
	# gdUnit4's exit code for failed tests.
	assert_int(outcome.exit_code).is_equal(100)
	assert_str(output).contains("test_more_columns_never_need_more_rows PASSED")
	assert_str(output).contains("test_rows_fit_every_item FAILED")
	assert_str(output).contains("test_every_stocked_item_has_a_price FAILED")
	# The report reaches gdUnit4's failure message, not only stderr.
	assert_str(output).contains("Report:\n  --- Failure: res://examples/gdunit4/inventory_test.gd")
	assert_str(output).contains('  var item = "potion"')
