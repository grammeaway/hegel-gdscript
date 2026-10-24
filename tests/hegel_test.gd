extends GdUnitTestSuite
## Hegel.run, HegelSettings and HegelResult against the engine.

const Gs := preload("res://addons/hegel/generators.gd")


func _settings(test_cases := 100) -> HegelSettings:
	var settings := HegelSettings.new()
	settings.test_cases = test_cases
	settings.seed = 1
	settings.has_seed = true
	settings.database = ""
	settings._silent = true
	return settings


func test_passing_body_passes_and_runs_test_cases() -> void:
	var calls := [0]
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			calls[0] += 1
			tc.draw(Gs.integers(0, 10)),
		_settings(7)
	)
	assert_bool(result.passed).is_true()
	assert_array(result.failures).is_empty()
	assert_int(result.error_kind).is_equal(HegelResult.ErrorKind.NONE)
	assert_str(result.error).is_empty()
	assert_int(result.test_cases).is_equal(calls[0])
	assert_int(calls[0]).is_between(1, 7)


func test_failing_check_gives_one_failure_with_a_blob() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			var x: int = tc.draw(Gs.integers(0, 1000))
			tc.check(x < 10, "x < 10"),
		_settings()
	)
	assert_bool(result.passed).is_false()
	assert_int(result.error_kind).is_equal(HegelResult.ErrorKind.NONE)
	assert_int(result.failures.size()).is_equal(1)
	assert_str(result.failures[0].origin).starts_with("check: res://tests/hegel_test.gd:")
	assert_str(result.failures[0].blob).is_not_empty()
	assert_str(result.failures[0].caveat).is_empty()
	assert_int(result.test_cases).is_greater(1)


func test_rejecting_every_case_is_unsatisfiable() -> void:
	var result := Hegel.run(func(tc: HegelTestCase) -> void: tc.assume(false), _settings())
	assert_bool(result.passed).is_false()
	assert_array(result.failures).is_empty()
	assert_int(result.error_kind).is_equal(HegelResult.ErrorKind.UNSATISFIABLE)
	assert_str(result.error).is_not_empty()


func test_nested_run_is_a_usage_error() -> void:
	var inner: Array[HegelResult] = []
	var outer := Hegel.run(
		func(tc: HegelTestCase) -> void:
			tc.draw(Gs.integers(0, 10))
			inner.append(Hegel.run(func(_tc: HegelTestCase) -> void: pass, _settings())),
		_settings(3)
	)
	assert_bool(outer.passed).is_true()
	assert_array(inner).is_not_empty()
	for result: HegelResult in inner:
		assert_int(result.error_kind).is_equal(HegelResult.ErrorKind.USAGE)
		assert_str(result.error).contains("inside the body")
	assert_bool(Hegel.run(func(_tc: HegelTestCase) -> void: pass, _settings()).passed).is_true()


func test_invalid_callable_is_a_usage_error() -> void:
	var result := Hegel.run(Callable(), _settings())
	assert_int(result.error_kind).is_equal(HegelResult.ErrorKind.USAGE)


func test_invalid_settings_are_a_usage_error() -> void:
	var settings := _settings()
	settings.test_cases = -1
	var result := Hegel.run(func(_tc: HegelTestCase) -> void: pass, settings)
	assert_int(result.error_kind).is_equal(HegelResult.ErrorKind.USAGE)
	assert_str(result.error).contains("test_cases")


func test_same_seed_gives_the_same_draws() -> void:
	assert_array(_draws(_settings())).is_equal(_draws(_settings()))


func test_derandomize_gives_the_same_draws() -> void:
	var settings := _settings()
	settings.has_seed = false
	settings.derandomize = true
	assert_array(_draws(settings)).is_equal(_draws(settings))


func test_settings_start_from_the_engine_profile() -> void:
	OS.set_environment("HEGEL_DEFAULT_PROFILE", "development")
	OS.set_environment("HEGEL_TEST_CASES", "42")
	OS.set_environment("HEGEL_SEED", "7")
	var settings := HegelSettings.new()
	OS.unset_environment("HEGEL_DEFAULT_PROFILE")
	OS.unset_environment("HEGEL_TEST_CASES")
	OS.unset_environment("HEGEL_SEED")
	assert_int(settings.test_cases).is_equal(42)
	assert_int(settings.seed).is_equal(7)
	assert_bool(settings.has_seed).is_true()
	assert_bool(settings.derandomize).is_false()
	assert_bool(settings.report_multiple_failures).is_false()
	assert_str(settings.database).is_equal(HegelSettings.DEFAULT_DATABASE)
	assert_int(settings.verbosity).is_equal(HegelSettings.Verbosity.NORMAL)
	assert_int(settings.suppress_health_checks).is_equal(0)


func test_engine_database_setting_wins_over_the_default() -> void:
	OS.set_environment("HEGEL_DATABASE", "disabled")
	var settings := HegelSettings.new()
	OS.unset_environment("HEGEL_DATABASE")
	assert_str(settings.database).is_empty()


func test_suppressed_health_check_lets_the_run_continue() -> void:
	var settings := _settings()
	var result := Hegel.run(_mostly_rejected, settings)
	assert_int(result.error_kind).is_equal(HegelResult.ErrorKind.HEALTH_CHECK)
	settings.suppress_health_checks = HegelSettings.HealthCheck.FILTER_TOO_MUCH
	assert_int(Hegel.run(_mostly_rejected, settings).error_kind).is_not_equal(
		HegelResult.ErrorKind.HEALTH_CHECK
	)


func _mostly_rejected(tc: HegelTestCase) -> void:
	tc.assume(tc.draw(Gs.integers(0, 1000)) == 0)


func _draws(settings: HegelSettings) -> Array[int]:
	var draws: Array[int] = []
	Hegel.run(func(tc: HegelTestCase) -> void: draws.append(tc.draw(Gs.integers())), settings)
	return draws
