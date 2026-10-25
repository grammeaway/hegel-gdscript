extends GdUnitTestSuite
## HegelStateMachine, porting the sequential cases of upstream's
## frontends/cpp/tests/test_stateful.cpp and frontends/rust/tests/test_stateful.rs.

const Gs := preload("res://addons/hegel/generators.gd")
const Subprocess := preload("res://tests/support/subprocess.gd")
const SCENARIOS := "res://tests/support/error_scenarios.gd"
const Scenarios := preload(SCENARIOS)


class _Stack:
	extends HegelStateMachine
	var stack: Array[int] = []

	func rule_push(tc: HegelTestCase) -> void:
		stack.append(tc.draw(Gs.integers()))

	func rule_pop(tc: HegelTestCase) -> void:
		if not tc.assume(not stack.is_empty()):
			return
		stack.pop_back()


class _Empty:
	extends HegelStateMachine

	func invariant_anything(_tc: HegelTestCase) -> void:
		pass


class _NoTestCase:
	extends HegelStateMachine

	func rule_step() -> void:
		pass


class _TwoArguments:
	extends HegelStateMachine

	func rule_step(_tc: HegelTestCase) -> void:
		pass

	func invariant_pair(_tc: HegelTestCase, _other: int) -> void:
		pass


class _BoundedCounter:
	extends HegelStateMachine
	var count := 0

	func rule_inc(_tc: HegelTestCase) -> void:
		count += 1

	func invariant_bounded(tc: HegelTestCase) -> void:
		tc.check(count < 2, "bound violated")


class _StoppingCounter:
	extends HegelStateMachine
	var count := 0

	func rule_inc(tc: HegelTestCase) -> void:
		count += 1
		tc.check(count < 100, "done")


## Counts rule and invariant runs across the whole run.
class _SampledInvariant:
	extends HegelStateMachine
	var runs: Dictionary

	func _init(shared_runs: Dictionary) -> void:
		runs = shared_runs

	func rule_count(_tc: HegelTestCase) -> void:
		runs.rules += 1

	func invariant_count(_tc: HegelTestCase) -> void:
		runs.invariants += 1


class _BrokenFromTheStart:
	extends HegelStateMachine

	func rule_step(_tc: HegelTestCase) -> void:
		pass

	func invariant_never(tc: HegelTestCase) -> void:
		tc.check(false, "never holds")


class _BreakOnce:
	extends HegelStateMachine
	var broken := false

	func rule_break_it(_tc: HegelTestCase) -> void:
		broken = true

	func invariant_not_broken(tc: HegelTestCase) -> void:
		tc.check(not broken, "machine is broken")


## Counts each case's completed rules into the last entry of counts.
class _StepRecorder:
	extends HegelStateMachine
	var counts: Array[int]
	var rejects: bool

	func _init(shared_counts: Array[int], always_rejects: bool) -> void:
		counts = shared_counts
		rejects = always_rejects

	func rule_step(tc: HegelTestCase) -> void:
		counts[-1] += 1
		tc.assume(not rejects)


## Rejects every other attempt, counting the completed ones.
class _Alternating:
	extends HegelStateMachine
	var counts: Array[int]
	var attempts := 0

	func _init(shared_counts: Array[int]) -> void:
		counts = shared_counts

	func rule_step(tc: HegelTestCase) -> void:
		attempts += 1
		if not tc.assume(attempts % 2 == 0):
			return
		counts[-1] += 1


class _AlternatingCounter:
	extends HegelStateMachine
	var attempts := 0
	var count := 0

	func rule_inc(tc: HegelTestCase) -> void:
		attempts += 1
		if not tc.assume(attempts % 2 == 0):
			return
		count += 1

	func invariant_below_2(tc: HegelTestCase) -> void:
		tc.check(count < 2, "count < 2")


class _CoinFlipCounter:
	extends HegelStateMachine
	var count := 0

	func rule_maybe_inc(tc: HegelTestCase) -> void:
		if not tc.assume(tc.draw(Gs.booleans())):
			return
		count += 1

	func invariant_below_5(tc: HegelTestCase) -> void:
		tc.check(count < 5, "count < 5")


class _Picky:
	extends HegelStateMachine
	var n := 0

	func rule_step(_tc: HegelTestCase) -> void:
		n += 1

	func invariant_few(tc: HegelTestCase) -> void:
		tc.assume(n < 3)


class _FailingBase:
	extends HegelStateMachine
	var count := 0

	func rule_fail(tc: HegelTestCase) -> void:
		tc.check(false, "the base rule ran")

	func rule_inc(_tc: HegelTestCase) -> void:
		count += 1


class _FixedSub:
	extends _FailingBase

	func rule_fail(_tc: HegelTestCase) -> void:
		pass

	func invariant_below_3(tc: HegelTestCase) -> void:
		tc.check(count < 3, "count < 3")


func _settings(test_cases := 100) -> HegelSettings:
	var settings := HegelSettings.new()
	settings.test_cases = test_cases
	settings.derandomize = true
	settings.database = ""
	settings._silent = true
	return settings


func _most_are(counts: Array[int], value: int) -> void:
	assert_int(counts.count(value)).override_failure_message(
		"expected most of %d cases to run %d steps: %s" % [counts.size(), value, counts]
	).is_greater(counts.size() / 2)


# BasicRun
func test_a_machine_runs() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void: _Stack.new().run(tc), _settings()
	)
	assert_bool(result.passed).override_failure_message(result.report + result.error).is_true()


# EmptyRulesThrows
func test_a_machine_without_rules_is_a_usage_error() -> void:
	var result := Hegel.run(func(tc: HegelTestCase) -> void: _Empty.new().run(tc), _settings())
	assert_int(result.error_kind).is_equal(HegelResult.ErrorKind.USAGE)
	assert_str(result.error).starts_with("HegelStateMachine.run (res://tests/state_machine_test.gd:")
	assert_str(result.error).contains("the machine has no rules")


func test_a_rule_without_the_test_case_is_a_usage_error() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void: _NoTestCase.new().run(tc), _settings()
	)
	assert_int(result.error_kind).is_equal(HegelResult.ErrorKind.USAGE)
	assert_str(result.error).contains("rule_step must take the test case")


func test_an_invariant_taking_more_than_the_test_case_is_a_usage_error() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void: _TwoArguments.new().run(tc), _settings()
	)
	assert_int(result.error_kind).is_equal(HegelResult.ErrorKind.USAGE)
	assert_str(result.error).contains("invariant_pair must take the test case")


# InvariantViolationReported
func test_an_invariant_violation_is_reported() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void: _BoundedCounter.new().run(tc), _settings()
	)
	assert_bool(result.passed).is_false()
	assert_str(result.report).contains("  Invariant bounded failed:\n\nCheck failed: bound violated")


# StepCountCapsStepsPerCase
func test_steps_caps_the_steps_per_case() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void: _StoppingCounter.new().run(tc, 5), _settings()
	)
	assert_bool(result.passed).override_failure_message(result.report).is_true()


# StepCountBelowOneThrows
func test_steps_below_one_is_a_usage_error() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void: _Stack.new().run(tc, 0), _settings()
	)
	assert_int(result.error_kind).is_equal(HegelResult.ErrorKind.USAGE)


# Rust: test_step_cap_is_50_most_of_the_time
func test_steps_default_to_50_most_of_the_time() -> void:
	var counts: Array[int] = []
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			counts.append(0)
			_StepRecorder.new(counts, false).run(tc),
		_settings()
	)
	assert_int(counts.max()).is_less_equal(50)
	_most_are(counts, 50)


# Rust: test_runner_steps_bounds_steps
func test_steps_bounds_the_steps_per_case() -> void:
	var counts: Array[int] = []
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			counts.append(0)
			_StepRecorder.new(counts, false).run(tc, 7),
		_settings()
	)
	assert_int(counts.min()).is_greater_equal(1)
	assert_int(counts.max()).is_less_equal(7)
	_most_are(counts, 7)


# InvariantsAreSampledRatherThanRunAfterEveryRule
func test_invariants_are_sampled_rather_than_run_after_every_rule() -> void:
	var runs := {"rules": 0, "invariants": 0}
	Hegel.run(
		func(tc: HegelTestCase) -> void: _SampledInvariant.new(runs).run(tc), _settings(20)
	)
	assert_int(runs.invariants).is_greater_equal(2)
	assert_int(runs.invariants).is_less(runs.rules / 4)


# PersistentViolationsAreAlwaysCaughtDespiteSampling
# Every case runs a rule, so every case must fail, through the final check if
# sampling skipped it.
func test_persistent_violations_are_always_caught_despite_sampling() -> void:
	var missed := [0]
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			_BreakOnce.new().run(tc)
			if not tc._ended:
				missed[0] += 1,
		_settings()
	)
	assert_bool(result.passed).is_false()
	assert_int(missed[0]).is_zero()
	assert_str(result.report).contains("Invariant not_broken failed:")


func test_invariants_are_checked_on_the_initial_state() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void: _BrokenFromTheStart.new().run(tc), _settings()
	)
	assert_str(result.report).contains(
		"\n\n  Checking invariants on the initial state.\n  Invariant never failed:\n\n"
	)


# Rust: test_rejected_rules_do_not_consume_the_step_budget
func test_rejected_rules_do_not_consume_the_step_budget() -> void:
	var counts: Array[int] = []
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			counts.append(0)
			_Alternating.new(counts).run(tc, 10),
		_settings()
	)
	assert_int(counts.max()).is_less_equal(10)
	_most_are(counts, 10)


# Rust: test_hopeless_machine_attempts_are_bounded
func test_a_machine_whose_rules_always_reject_is_bounded() -> void:
	var counts: Array[int] = []
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			counts.append(0)
			_StepRecorder.new(counts, true).run(tc),
		_settings(10)
	)
	assert_bool(result.passed).override_failure_message(result.error).is_true()
	assert_int(counts.max()).is_less_equal(1000)
	_most_are(counts, 1000)


func test_rules_rejecting_half_the_time_still_reach_later_states() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void: _CoinFlipCounter.new().run(tc), _settings()
	)
	assert_bool(result.passed).is_false()
	assert_str(result.report).contains("Check failed: count < 5")


# Rust: test_assume_skip_is_reported_as_violated_assumption
func test_a_rejected_step_is_reported_as_stopped_early() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void: _AlternatingCounter.new().run(tc), _settings()
	)
	var lines := result.report.split("\n")
	var body := Array(lines.slice(lines.find("") + 1, lines.rfind("")))
	(
		assert_array(body)
		. is_equal(
			[
				"  Checking invariants on the initial state.",
				"  Step 1: inc {",
				"    Rule stopped early due to violated assumption.",
				"  }",
				"  Step 2: inc {",
				"  }",
				"  Step 3: inc {",
				"    Rule stopped early due to violated assumption.",
				"  }",
				"  Step 4: inc {",
				"  }",
				"  Invariant below_2 failed:",
			]
		)
	)


# Python: test_invariant_may_reject_test_case
func test_an_invariant_may_reject_the_case() -> void:
	var settings := _settings(5)
	settings.suppress_health_checks = 15
	var result := Hegel.run(func(tc: HegelTestCase) -> void: _Picky.new().run(tc), settings)
	assert_bool(result.passed).override_failure_message(result.report + result.error).is_true()


func test_a_machine_inherits_rules_and_overrides_win() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void: _FixedSub.new().run(tc), _settings()
	)
	assert_bool(result.passed).is_false()
	assert_str(result.report).contains("Check failed: count < 3").not_contains("base rule ran")


func test_draws_in_each_step_are_nested_and_named_afresh() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			var stack := _Stack.new()
			stack.run(tc)
			tc.check(stack.stack.size() < 2, "small stack"),
		_settings()
	)
	assert_str(result.report).contains(
		"  Step 1: push {\n    var draw_1 = 0\n  }\n  Step 2: push {\n    var draw_1 = 0\n  }\n"
	)


func test_a_runtime_error_in_a_rule_fails_the_machine_at_its_step() -> void:
	var outcome := Subprocess.run(SCENARIOS, ["error_in_a_rule"])
	var lines := outcome.output.split("\n")
	var found := Array(lines).filter(
		func(line: String) -> bool: return line.begins_with(Scenarios.RESULT_PREFIX)
	)
	assert_array(found).has_size(1)
	var result: Dictionary = JSON.parse_string(found[0].trim_prefix(Scenarios.RESULT_PREFIX))
	var site: String = result.sites[0]
	assert_array(result.origins).is_equal(["script error: " + site])
	assert_str(result.report).contains(
		(
			"  Step 1: fill {\n  }\n  Step 2: fill {\n  }\n  Step 3: fill {\n  }\n"
			+ "  Rule fill failed:\n\nScript error: Invalid assignment of index '2' (on base: 'Array')"
		)
	)
