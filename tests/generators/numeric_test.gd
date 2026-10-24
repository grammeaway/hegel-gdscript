extends GdUnitTestSuite
## Contract and validation tests for integers, floats and booleans.

const Gs := preload("res://addons/hegel/generators.gd")
const Q := preload("res://tests/support/quality.gd")

## The smallest positive float. GDScript parses a 5e-324 literal as 0.0, and
## some 17-digit literals an ulp off, so exact floats here are computed.
static var tiny := PackedByteArray([1, 0, 0, 0, 0, 0, 0, 0]).decode_double(0)


static func _in(low: float, high: float) -> Callable:
	return func(x: float) -> bool: return x >= low and x <= high


func test_integer_bounds_are_validated_by_the_engine() -> void:
	assert_str(Q.usage_error(Gs.integers(5, 1))).contains("min_value <= max_value")


func test_float_bounds_hold() -> void:
	Q.assert_all_examples(Gs.floats(-1.5, 2.5), _in(-1.5, 2.5))
	Q.assert_all_examples(Gs.floats(0.0), func(x: float) -> bool: return x >= 0.0)
	Q.assert_all_examples(Gs.floats(-INF, -3.0), func(x: float) -> bool: return x <= -3.0)
	Q.assert_all_examples(Gs.floats(7.25, 7.25), func(x: float) -> bool: return x == 7.25)


func test_excluded_bounds_are_never_drawn() -> void:
	Q.assert_all_examples(
		Gs.floats(0.0, 1.0, true, true, true, true),
		func(x: float) -> bool: return x > 0.0 and x < 1.0
	)
	Q.find_any(Gs.floats(0.0, 1.0, true, true, true), func(x: float) -> bool: return x < 1e-300)


func test_bounded_floats_have_no_nan_or_infinity() -> void:
	Q.assert_all_examples(Gs.floats(0.0, 1.0), func(x: float) -> bool: return is_finite(x))
	Q.assert_all_examples(Gs.floats(0.0), func(x: float) -> bool: return not is_nan(x))
	Q.assert_all_examples(Gs.floats(-INF, 0.0), func(x: float) -> bool: return not is_nan(x))


func test_open_ends_reach_nan_and_infinities() -> void:
	Q.find_any(Gs.floats(), func(x: float) -> bool: return is_nan(x))
	Q.find_any(Gs.floats(), func(x: float) -> bool: return x == INF)
	Q.find_any(Gs.floats(), func(x: float) -> bool: return x == -INF)
	Q.find_any(Gs.floats(0.0), func(x: float) -> bool: return x == INF)
	Q.find_any(Gs.floats(-INF, 0.0), func(x: float) -> bool: return x == -INF)


func test_disallowed_nan_and_infinity_are_never_drawn() -> void:
	Q.assert_all_examples(Gs.floats(-INF, INF, false), func(x: float) -> bool: return not is_nan(x))
	Q.assert_all_examples(
		Gs.floats(-INF, INF, true, false), func(x: float) -> bool: return not is_inf(x)
	)
	Q.find_any(Gs.floats(-INF, INF, true, false), func(x: float) -> bool: return is_nan(x))
	Q.assert_all_examples(
		Gs.floats(0.0, INF, true, false), func(x: float) -> bool: return is_finite(x)
	)


func test_finite_floats_still_reach_large_magnitudes() -> void:
	var finite := Gs.floats(-INF, INF, false, false)
	Q.assert_all_examples(finite, func(x: float) -> bool: return is_finite(x))
	Q.find_any(finite, func(x: float) -> bool: return absf(x) > 1e300)


func test_invalid_float_arguments_are_usage_errors() -> void:
	assert_str(Q.usage_error(Gs.floats(2.0, 1.0))).contains("min_value")
	assert_str(Q.usage_error(Gs.floats(NAN, 1.0))).contains("NaN")
	assert_str(Q.usage_error(Gs.floats(1.0, 1.0, true, true, true))).contains("min_value")
	assert_str(Q.usage_error(Gs.floats(INF, INF, true, false))).contains("allow_infinity")


func test_simplest_floats_respect_excluded_bounds() -> void:
	var after: Array[float] = []
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			tc.check(false)
			after.assign(
				[
					tc.draw(Gs.floats(0.0, 1.0, true, true, true)),
					tc.draw(Gs.floats(-2.0, -1.0, true, true, false, true)),
					tc.draw(Gs.floats(-1.0, 1.0, true, true, true, true)),
					tc.draw(Gs.floats(3.5)),
				]
			),
		Q._settings(1)
	)
	assert_array(after).is_equal([tiny, -1.0 - pow(2.0, -52), 0.0, 3.5])


func test_next_up_steps_to_the_adjacent_float() -> void:
	var steps: Array[float] = []
	# Built from bytes: Godot folds a -0.0 literal in an Array into 0.0.
	var negative_zero := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0x80]).decode_double(0)
	for x: float in [0.0, negative_zero, 1.0, -1.0, -tiny, -INF, INF]:
		steps.append(HegelTestCase._next_up(x))
	var ulp := pow(2.0, -52)
	assert_array(steps).is_equal(
		[tiny, tiny, 1.0 + ulp, -1.0 + ulp / 2.0, -0.0, -1.7976931348623157e308, INF]
	)


func test_booleans_reach_both_values() -> void:
	Q.find_any(Gs.booleans(), func(b: bool) -> bool: return b)
	Q.find_any(Gs.booleans(), func(b: bool) -> bool: return not b)


func test_simplest_boolean_is_false() -> void:
	var after: Array[bool] = []
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			tc.check(false)
			after.assign([tc.draw(Gs.booleans())]),
		Q._settings(1)
	)
	assert_array(after).is_equal([false])


## Bounds hold for many parameter sets. A nested Hegel.run is a usage error,
## so the sets come from a seeded RandomNumberGenerator.
func test_bounds_hold_across_parameter_sets() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i: int in 15:
		var a := rng.randi_range(-1000, 1000)
		var b := a + rng.randi_range(1, 1000)
		Q.assert_all_examples(
			Gs.integers(a, b), func(x: int) -> bool: return x >= a and x <= b, 30
		)
		var low := rng.randf_range(-1e9, 1e9)
		var high := low + rng.randf_range(0.0, 1e9)
		Q.assert_all_examples(Gs.floats(low, high), _in(low, high), 30)
		# Of two consecutive even numbers, one isn't a multiple of 3.
		var evens := Gs.integers(a, b).map(func(x: int) -> int: return x * 2)
		Q.assert_all_examples(
			evens.filter(func(x: int) -> bool: return x % 3 != 0),
			func(x: int) -> bool: return x >= 2 * a and x <= 2 * b and x % 6 != 0 and x % 2 == 0,
			30
		)
	Q.assert_all_examples(
		Gs.integers(Gs.INT64_MAX - 1, Gs.INT64_MAX),
		func(x: int) -> bool: return x >= Gs.INT64_MAX - 1
	)
