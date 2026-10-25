extends GdUnitTestSuite
## Drives the native classes directly: one seeded run of `x in [0, 1e6]`
## against the property `x < LIMIT`.

const LIMIT := 1000
const SEED := 1


class Outcome:
	var result: HegelNativeRunResult
	var test_cases := 0
	## x in each failing test case libhegel asked us to capture. The last one
	## is the final replay of the shrunk counterexample.
	var captured_failures: Array[int] = []


func _settings(seed: int) -> HegelNativeSettings:
	var settings := HegelNativeSettings.new()
	assert_int(settings.last_result).is_equal(HegelNative.OK)
	assert_int(settings.set_seed(seed, true)).is_equal(HegelNative.OK)
	assert_int(settings.set_database("")).is_equal(HegelNative.OK)
	return settings


## Runs the property, or replays [param blob] when one is given.
func _run(settings: HegelNativeSettings, blob := "") -> Outcome:
	var run := HegelNativeRun.new()
	var started := run.start_blob(settings, blob) if blob else run.start(settings)
	assert_int(started).is_equal(HegelNative.OK)
	var outcome := Outcome.new()
	var tc := run.next_test_case()
	while tc != null:
		outcome.test_cases += 1
		var capture := tc.should_capture()
		var x := tc.generate_integer(0, 1_000_000)
		var status := HegelNativeTestCase.STATUS_VALID
		if tc.last_result != HegelNative.OK:
			status = HegelNativeTestCase.STATUS_OVERRUN
		elif x >= LIMIT:
			status = HegelNativeTestCase.STATUS_INTERESTING
			if capture:
				outcome.captured_failures.append(x)
		assert_int(tc.mark_complete(status, "x < LIMIT")).is_equal(HegelNative.OK)
		tc = run.next_test_case()
	assert_int(run.last_result).is_equal(HegelNative.OK)
	outcome.result = run.result()
	assert_object(outcome.result).is_not_null()
	return outcome


func test_failing_property_shrinks_to_the_boundary() -> void:
	var outcome := _run(_settings(SEED))
	assert_int(outcome.result.status()).is_equal(HegelNativeRunResult.RUN_STATUS_FAILED)
	assert_array(outcome.captured_failures).is_not_empty()
	assert_int(outcome.captured_failures.back()).is_equal(LIMIT)


func test_failure_carries_its_origin_and_a_blob() -> void:
	var result := _run(_settings(SEED)).result
	assert_int(result.failure_count()).is_equal(1)
	assert_str(result.failure_origin(0)).is_equal("x < LIMIT")
	assert_str(result.failure_blob(0)).is_not_empty()
	assert_str(result.failure_caveat(0)).is_empty()
	assert_int(result.error_kind()).is_equal(HegelNativeRunResult.RUN_ERROR_NONE)
	assert_str(result.error()).is_empty()


func test_start_blob_replays_the_failure() -> void:
	var blob := _run(_settings(SEED)).result.failure_blob(0)
	var replayed := _run(_settings(SEED), blob)
	assert_int(replayed.result.status()).is_equal(HegelNativeRunResult.RUN_STATUS_FAILED)
	assert_int(replayed.captured_failures.back()).is_equal(LIMIT)
	assert_str(replayed.result.failure_blob(0)).is_empty()


func test_start_blob_rejects_a_bad_blob() -> void:
	var run := HegelNativeRun.new()
	assert_int(run.start_blob(_settings(SEED), "not a blob")).is_equal(HegelNative.E_INVALID_ARG)
	assert_str(run.last_error).is_not_empty()


func test_reading_a_missing_failure_fails() -> void:
	var result := _run(_settings(SEED)).result
	assert_str(result.failure_origin(1)).is_empty()
	assert_int(result.last_result).is_not_equal(HegelNative.OK)
	result.failure_origin(-1)
	assert_int(result.last_result).is_equal(HegelNative.E_INVALID_ARG)


func test_same_seed_sees_the_same_number_of_test_cases() -> void:
	assert_int(_run(_settings(SEED)).test_cases).is_equal(_run(_settings(SEED)).test_cases)


func test_passing_run_runs_the_configured_test_cases() -> void:
	var settings := _settings(SEED)
	assert_int(settings.set_test_cases(7)).is_equal(HegelNative.OK)
	var run := HegelNativeRun.new()
	run.start(settings)
	var test_cases := 0
	var tc := run.next_test_case()
	while tc != null:
		test_cases += 1
		tc.generate_integer(0, 10)
		tc.mark_complete(HegelNativeTestCase.STATUS_VALID, "")
		tc = run.next_test_case()
	assert_int(test_cases).is_equal(7)
	assert_int(run.result().status()).is_equal(HegelNativeRunResult.RUN_STATUS_PASSED)


func test_bad_call_records_result_and_message() -> void:
	var run := HegelNativeRun.new()
	run.start(_settings(SEED))
	var tc := run.next_test_case()
	tc.generate_integer(5, 1)
	assert_int(tc.last_result).is_equal(HegelNative.E_INVALID_ARG)
	assert_str(tc.last_error).is_not_empty()
	tc.generate_integer(1, 5)
	assert_int(tc.last_result).is_equal(HegelNative.OK)
	assert_str(tc.last_error).is_empty()
	tc.mark_complete(HegelNativeTestCase.STATUS_VALID, "")


func test_float_and_boolean_draws() -> void:
	var run := HegelNativeRun.new()
	run.start(_settings(SEED))
	var tc := run.next_test_case()
	var x := tc.generate_float(1.0, 2.0, false, false, false, false)
	assert_int(tc.last_result).is_equal(HegelNative.OK)
	assert_float(x).is_between(1.0, 2.0)
	tc.generate_boolean(0.5)
	assert_int(tc.last_result).is_equal(HegelNative.OK)
	assert_bool(tc.generate_boolean(1.0)).is_true()
	tc.generate_float(2.0, 1.0, false, false, false, false)
	assert_int(tc.last_result).is_equal(HegelNative.E_INVALID_ARG)
	tc.generate_boolean(1.5)
	assert_int(tc.last_result).is_equal(HegelNative.E_INVALID_ARG)
	tc.mark_complete(HegelNativeTestCase.STATUS_VALID, "")


func test_out_of_range_arguments_are_rejected() -> void:
	var settings := HegelNativeSettings.new()
	assert_int(settings.set_test_cases(-1)).is_equal(HegelNative.E_INVALID_ARG)
	assert_str(settings.last_error).contains("test_cases")
	assert_int(settings.set_verbosity(99)).is_equal(HegelNative.E_INVALID_ARG)
	assert_int(settings.set_verbosity(HegelNativeSettings.VERBOSITY_QUIET)).is_equal(HegelNative.OK)


func test_malformed_environment_fails_settings_creation() -> void:
	OS.set_environment("HEGEL_TEST_CASES", "many")
	var settings := HegelNativeSettings.new()
	OS.unset_environment("HEGEL_TEST_CASES")
	assert_int(settings.last_result).is_equal(HegelNative.E_INVALID_ARG)
	assert_str(settings.last_error).contains("HEGEL_TEST_CASES")


func test_completing_twice_fails() -> void:
	var run := HegelNativeRun.new()
	run.start(_settings(SEED))
	var tc := run.next_test_case()
	assert_int(tc.mark_complete(HegelNativeTestCase.STATUS_VALID, "")).is_equal(HegelNative.OK)
	assert_int(tc.mark_complete(HegelNativeTestCase.STATUS_VALID, "")).is_equal(
		HegelNative.E_ALREADY_COMPLETE
	)


func test_spans_balance() -> void:
	var run := HegelNativeRun.new()
	run.start(_settings(SEED))
	var tc := run.next_test_case()
	assert_int(tc.start_span(HegelNative.label_from_name("hegel-gdscript.test"))).is_equal(
		HegelNative.OK
	)
	tc.generate_integer(0, 10)
	assert_int(tc.stop_span(false)).is_equal(HegelNative.OK)
	tc.mark_complete(HegelNativeTestCase.STATUS_VALID, "")


func test_labels_are_stable_and_distinct() -> void:
	var a := HegelNative.label_from_name("a")
	var b := HegelNative.label_from_name("b")
	assert_int(HegelNative.label_from_name("a")).is_equal(a)
	assert_int(a).is_not_equal(b)
	assert_int(HegelNative.label_combine(PackedInt64Array([a, b]))).is_not_equal(
		HegelNative.label_combine(PackedInt64Array([b, a]))
	)


func test_version_is_the_pinned_libhegel() -> void:
	assert_str(HegelNative.version()).is_equal("0.48.0")


func test_verbose_run_emits_output_that_drains_once() -> void:
	var settings := _settings(SEED)
	settings.set_verbosity(HegelNativeSettings.VERBOSITY_DEBUG)
	var run := HegelNativeRun.new()
	run.start(settings)
	var tc := run.next_test_case()
	while tc != null:
		tc.mark_complete(HegelNativeTestCase.STATUS_VALID, "")
		tc = run.next_test_case()
	assert_array(Array(run.drain_output())).is_not_empty()
	assert_array(Array(run.drain_output())).is_empty()


func test_collection_draws() -> void:
	var run := HegelNativeRun.new()
	run.start(_settings(SEED))
	var tc := run.next_test_case()
	assert_object(tc.new_collection(-1, 3)).is_null()
	assert_int(tc.last_result).is_equal(HegelNative.E_INVALID_ARG)
	assert_str(tc.last_error).contains("min_size")
	assert_object(tc.new_collection(3, 2)).is_null()
	assert_int(tc.last_result).is_equal(HegelNative.E_INVALID_ARG)
	var collection := tc.new_collection(1, -1)
	assert_int(tc.last_result).is_equal(HegelNative.OK)
	assert_bool(tc.collection_more(collection)).is_true()
	assert_int(tc.collection_reject(collection)).is_equal(HegelNative.OK)
	tc.collection_more(collection)
	assert_int(tc.last_result).is_equal(HegelNative.OK)
	tc.mark_complete(HegelNativeTestCase.STATUS_VALID, "")


func test_string_draws() -> void:
	var generator := HegelNativeStringGenerator.new()
	assert_int(generator.text(-1, 5, 1, 10)).is_equal(HegelNative.E_INVALID_ARG)
	assert_str(generator.last_error).contains("min_size")
	assert_int(generator.text(0, 5, 1, -1)).is_equal(HegelNative.E_INVALID_ARG)
	assert_str(generator.last_error).contains("max_codepoint")
	assert_int(generator.text(5, 3, 1, 10)).is_equal(HegelNative.E_INVALID_ARG)
	assert_int(generator.text(2, 2, 0x41, 0x41)).is_equal(HegelNative.OK)
	var run := HegelNativeRun.new()
	run.start(_settings(SEED))
	var tc := run.next_test_case()
	assert_str(tc.generate_string(generator)).is_equal("AA")
	assert_int(tc.last_result).is_equal(HegelNative.OK)
	tc.mark_complete(HegelNativeTestCase.STATUS_VALID, "")
