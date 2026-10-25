extends GdUnitTestSuite
## Shrink quality for state machines: a failing sequence shrinks to the
## shortest one, with each step's draws minimal.

const Gs := preload("res://addons/hegel/generators.gd")


class _IncReset:
	extends HegelStateMachine
	var count := 0

	func rule_inc(_tc: HegelTestCase) -> void:
		count += 1

	func rule_reset(_tc: HegelTestCase) -> void:
		count = 0

	func invariant_below_3(tc: HegelTestCase) -> void:
		tc.check(count < 3, "count < 3")


## Overflows at 12, so two steps are the shortest failing sequence.
class _Counter:
	extends HegelStateMachine
	var count := 0

	func rule_add(tc: HegelTestCase) -> void:
		count += tc.draw(Gs.integers(1, 9), "amount")
		tc.check(count < 12, "counter overflowed")


func _settings() -> HegelSettings:
	var settings := HegelSettings.new()
	settings.seed = 1
	settings.has_seed = true
	settings.database = ""
	settings._silent = true
	return settings


static func _lines_starting(report: String, prefix: String) -> Array:
	return Array(report.split("\n")).filter(
		func(line: String) -> bool: return line.begins_with(prefix)
	)


# PLAN item 7: finds the shortest failing action sequence.
func test_inc_reset_shrinks_to_three_increments() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void: _IncReset.new().run(tc), _settings()
	)
	assert_bool(result.passed).is_false()
	assert_array(_lines_starting(result.report, "  Step ")).is_equal(
		["  Step 1: inc {", "  Step 2: inc {", "  Step 3: inc {"]
	)


# Stateful.StatePrintingCanBeDisabled: the Counter machine, 5 steps, seed 1.
func test_counter_overflow_shrinks_to_two_minimal_steps() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void: _Counter.new().run(tc, 5), _settings()
	)
	var lines := result.report.split("\n")
	var body := Array(lines.slice(lines.find("") + 1, lines.rfind("")))
	(
		assert_array(body)
		. is_equal(
			[
				"  Step 1: add {",
				"    var amount = 3",
				"  }",
				"  Step 2: add {",
				"    var amount = 9",
				"  }",
				"  Rule add failed:",
			]
		)
	)
