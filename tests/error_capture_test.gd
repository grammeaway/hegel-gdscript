extends GdUnitTestSuite
## Runtime errors in a test body fail the case (D11). The scenarios provoke
## real errors, so they run in a fresh process: tests/support/error_scenarios.gd.

const Subprocess := preload("res://tests/support/subprocess.gd")
const SCENARIOS := "res://tests/support/error_scenarios.gd"
const Scenarios := preload(SCENARIOS)


## Runs [param scenario] and returns the outcome it printed.
func _scenario(scenario: String) -> Dictionary:
	var outcome := Subprocess.run(SCENARIOS, [scenario])
	for line: String in outcome.output.split("\n"):
		if line.begins_with(Scenarios.RESULT_PREFIX):
			return JSON.parse_string(line.trim_prefix(Scenarios.RESULT_PREFIX))
	fail("%s printed no result:\n%s" % [scenario, outcome.output])
	return {}


## The one error site [param outcome] marked.
func _site(outcome: Dictionary) -> String:
	assert_array(outcome.sites).has_size(1)
	return outcome.sites[0] if outcome.sites else ""


func test_call_on_null_fails_and_the_report_names_the_line() -> void:
	var outcome := _scenario("call_on_null")
	var site := _site(outcome)
	assert_bool(outcome.passed).is_false()
	assert_array(outcome.origins).is_equal(["script error: " + site])
	assert_str(outcome.report).contains(
		"Script error: Cannot call method 'get_name' on a null value. (%s)" % site
	)


func test_error_deep_in_the_code_under_test_has_the_innermost_origin() -> void:
	var outcome := _scenario("two_calls_deep")
	var site := _site(outcome)
	assert_array(outcome.origins).is_equal(["script error: " + site])
	var lines: PackedStringArray = outcome.report.split("\n")
	var message := "Invalid assignment of index '1' (on base: 'Array') with value of type 'int'."
	var error_line := lines.find("Script error: %s (%s)" % [message, site])
	assert_int(error_line).is_not_negative()
	if error_line < 0:
		return
	assert_str(lines[error_line + 1]).is_equal("  at _inner (%s)" % site)
	assert_str(lines[error_line + 2]).starts_with("  at _outer (" + SCENARIOS)
	assert_str(lines[error_line + 3]).starts_with("  at <anonymous lambda> (")


func test_push_error_fails_the_case() -> void:
	var outcome := _scenario("pushed_error")
	var site := _site(outcome)
	assert_array(outcome.origins).is_equal(["error: " + site])
	assert_str(outcome.report).contains("var draw_1 = 6").contains("Error: x is 6 (%s)" % site)


func test_push_warning_does_not_fail_the_case() -> void:
	var outcome := _scenario("pushed_warning")
	assert_bool(outcome.passed).is_true()
	assert_str(outcome.error).is_empty()


func test_failed_assert_fails_the_case() -> void:
	var outcome := _scenario("failed_assert")
	var site := _site(outcome)
	assert_array(outcome.origins).is_equal(["script error: " + site])
	assert_str(outcome.report).contains("var draw_1 = 5")


func test_two_error_sites_are_two_failures() -> void:
	var outcome := _scenario("two_sites")
	var expected: Array = outcome.sites.map(func(site: String) -> String: return "error: " + site)
	assert_array(outcome.sites).has_size(2)
	assert_array(outcome.origins).contains_exactly_in_any_order(expected)


func test_one_site_with_different_values_is_one_failure() -> void:
	var outcome := _scenario("same_site_different_values")
	assert_array(outcome.origins).is_equal(["script error: " + _site(outcome)])
	assert_str(outcome.report).contains("var draw_1 = 1")


func test_failed_check_before_an_error_wins() -> void:
	var outcome := _scenario("check_then_error")
	assert_int(outcome.origins.size()).is_equal(1)
	assert_str(outcome.origins[0]).starts_with("check: ")


func test_error_before_a_failed_check_wins() -> void:
	var outcome := _scenario("error_then_check")
	assert_array(outcome.origins).is_equal(["error: " + _site(outcome)])


func test_error_between_runs_is_not_captured() -> void:
	var outcome := _scenario("between_runs")
	assert_bool(outcome.passed).is_true()
	assert_bool(outcome.last_case_ended).is_false()
	assert_bool(outcome.next_passed).is_true()


func test_expect_errors_collects_a_push_error_instead_of_failing() -> void:
	var outcome := _scenario("expected_push_error")
	assert_bool(outcome.passed).is_true()
	assert_str(outcome.error).is_empty()
	assert_int(outcome.collected.size()).is_equal(1)
	assert_str(outcome.collected[0] if outcome.collected else "").starts_with("bad input ")


func test_script_error_inside_expect_errors_still_fails_the_case() -> void:
	var outcome := _scenario("script_error_in_expect_errors")
	var site := _site(outcome)
	assert_array(outcome.origins).is_equal(["script error: " + site])
	assert_array(outcome.collected).is_empty()


func test_push_error_after_expect_errors_returns_fails_the_case() -> void:
	var outcome := _scenario("push_error_after_expect_errors")
	assert_array(outcome.origins).is_equal(["error: " + _site(outcome)])
	assert_array(outcome.collected).is_equal(["expected"])


func test_expect_errors_collects_an_engine_error() -> void:
	var outcome := _scenario("expected_engine_error")
	assert_bool(outcome.passed).is_true()
	assert_int(outcome.collected.size()).is_equal(1)
	assert_str(outcome.collected[0] if outcome.collected else "").contains("missing")


func test_expect_errors_collects_an_error_from_a_joined_thread() -> void:
	var outcome := _scenario("expected_error_from_a_thread")
	assert_bool(outcome.passed).is_true()
	assert_int(outcome.collected.size()).is_equal(1)
	assert_str(outcome.collected[0] if outcome.collected else "").starts_with("thread ")


func test_nested_expect_errors_each_return_their_own() -> void:
	var outcome := _scenario("nested_expect_errors")
	assert_bool(outcome.passed).is_true()
	assert_array(outcome.collected).is_equal(["outer 1", "outer 2", "inner"])


func test_error_in_a_thread_the_body_joins_fails_the_case() -> void:
	var outcome := _scenario("in_a_thread")
	var site := _site(outcome)
	assert_array(outcome.origins).is_equal(["script error: " + site])
	assert_str(outcome.report).contains("  at _inner (%s)" % site)
