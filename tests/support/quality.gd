extends RefCounted
## Contract and quality helpers, after upstream's
## frontends/cpp/tests/common/utils.h: minimal runs with seed 1, the others
## derandomized, all silent and with the database disabled. They fail cases
## through tc.check alone, so no error reaches gdUnit4's logger.


static func _settings(test_cases: int, seeded := false) -> HegelSettings:
	var settings := HegelSettings.new()
	settings.test_cases = test_cases
	settings.derandomize = not seeded
	settings.seed = 1
	settings.has_seed = seeded
	settings.database = ""
	settings._silent = true
	return settings


## Fails the current test unless every value drawn from [param gen]
## satisfies [param predicate].
static func assert_all_examples(
	gen: HegelGenerator, predicate: Callable, test_cases := 100
) -> void:
	var counterexample := []
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			var value: Variant = tc.draw(gen)
			if not predicate.call(value) and _live(tc):
				counterexample.assign([value])
				tc.check(false),
		_settings(test_cases)
	)
	(
		GdUnitTestSuite
		. assert_bool(result.passed)
		. override_failure_message(
			"%s does not hold for %s (%s)" % [predicate, counterexample, result.error]
		)
		. is_true()
	)


## A value from [param gen] satisfying [param condition], or null after
## failing the current test when none turns up in [param max_attempts] cases.
static func find_any(gen: HegelGenerator, condition: Callable, max_attempts := 300) -> Variant:
	return _first_match(gen, condition, _settings(max_attempts), "find_any")


## The minimal value from [param gen] satisfying [param condition]: the
## shrunk counterexample to "no value satisfies it".
static func minimal(gen: HegelGenerator, condition: Callable, test_cases := 100) -> Variant:
	return _first_match(gen, condition, _settings(test_cases, true), "minimal")


## Fails the run's cases whose value matches, and returns the value from the
## last of them: the final replay of the shrunk counterexample.
static func _first_match(
	gen: HegelGenerator, condition: Callable, settings: HegelSettings, helper: String
) -> Variant:
	var found := []
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			var value: Variant = tc.draw(gen)
			if condition.call(value) and _live(tc):
				found.assign([value])
				tc.check(false),
		settings
	)
	(
		GdUnitTestSuite
		. assert_bool(not found.is_empty() and not result.passed)
		. override_failure_message(
			(
				"%s: no example matched %s in %d test cases %s"
				% [helper, condition, settings.test_cases, result.error]
			)
		)
		. is_true()
	)
	return found.back() if found else null


## The message of the usage error that drawing from [param gen] ends a run
## with, after failing the current test if it ends otherwise.
static func usage_error(gen: HegelGenerator) -> String:
	var result := Hegel.run(func(tc: HegelTestCase) -> void: tc.draw(gen), _settings(10))
	(
		GdUnitTestSuite
		. assert_bool(result.error_kind == HegelResult.ErrorKind.USAGE and result.failures.is_empty())
		. override_failure_message(
			(
				"expected a usage error, got kind %d (%s), %d failures"
				% [result.error_kind, result.error, result.failures.size()]
			)
		)
		. is_true()
	)
	return result.error


## Whether the case is still running: once it has ended, draws return
## simplest values that the helpers mustn't record.
static func _live(tc: HegelTestCase) -> bool:
	return not tc._ended
