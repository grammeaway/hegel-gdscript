# gdlint: disable=max-public-methods
extends GdUnitTestSuite
## Float quality, ported from upstream's
## frontends/cpp/tests/shrink_quality/test_floats.cpp and
## find_quality/test_floats.cpp; each test names its upstream case.

const Gs := preload("res://addons/hegel/generators.gd")
const Q := preload("res://tests/support/quality.gd")

const MAX := 1.7976931348623157e308


static func _any(_x: float) -> bool:
	return true


static func _sum(xs: Array) -> float:
	var total := 0.0
	for x: float in xs:
		total += x
	return total


# shrink_quality


# ShrinkFloats.ShrinksToSimpleFloatAbove1
func test_shrinks_to_simple_float_above_1() -> void:
	assert_float(Q.minimal(Gs.floats(), func(x: float) -> bool: return x > 1.0)).is_equal(2.0)


# ShrinkFloats.ShrinksToSimpleFloatAbove0
func test_shrinks_to_simple_float_above_0() -> void:
	assert_float(Q.minimal(Gs.floats(), func(x: float) -> bool: return x > 0.0)).is_equal(1.0)


# ShrinkFloats.CanFindNan, FindFloats.MinimizeNan
func test_can_find_nan() -> void:
	assert_bool(is_nan(Q.minimal(Gs.floats(), func(x: float) -> bool: return is_nan(x)))).is_true()


# find_quality


# FindFloats.PositiveInfinity
func test_positive_infinity() -> void:
	Q.find_any(Gs.floats(), func(x: float) -> bool: return x == INF)


# FindFloats.NegativeInfinity
func test_negative_infinity() -> void:
	Q.find_any(Gs.floats(), func(x: float) -> bool: return x == -INF)


# FindFloats.Nan
func test_nan() -> void:
	Q.find_any(Gs.floats(), func(x: float) -> bool: return is_nan(x))


# FindFloats.NearLeft, NearRight, InMiddle
func test_unit_interval_reaches_both_ends_and_middle() -> void:
	Q.find_any(Gs.floats(0.0, 1.0), func(t: float) -> bool: return t < 0.2)
	Q.find_any(Gs.floats(0.0, 1.0), func(t: float) -> bool: return t > 0.8)
	Q.find_any(Gs.floats(0.0, 1.0), func(t: float) -> bool: return t >= 0.2 and t <= 0.8)


# FindFloats.MostlySensible
func test_mostly_sensible() -> void:
	Q.find_any(Gs.floats(), func(t: float) -> bool: return t + 1.0 > t)


# FindFloats.MostlyLargish
func test_mostly_largish() -> void:
	Q.find_any(Gs.floats(), func(x: float) -> bool: return x > 0.0 and x + 1.0 > 1.0)


# FindFloats.InversionIsImperfect
func test_inversion_is_imperfect() -> void:
	Q.find_any(
		Gs.floats(), func(x: float) -> bool: return x != 0.0 and is_finite(x) and x * (1.0 / x) != 1.0
	)


# FindFloats.DoNotRoundTripThroughStrings, through Godot's str()
func test_do_not_round_trip_through_strings() -> void:
	Q.find_any(
		Gs.floats(),
		func(x: float) -> bool:
			var y := str(x).to_float()
			return x != y and not (is_nan(x) and is_nan(y))
	)


# FindFloats.MinimalFloatIsZero
func test_minimal_float_is_zero() -> void:
	assert_float(Q.minimal(Gs.floats(), _any)).is_equal(0.0)


# FindFloats.MinimalsBoundaryFloats
func test_minimals_boundary_floats() -> void:
	assert_float(Q.minimal(Gs.floats(-1.0, 1.0), _any)).is_equal(0.0)


# FindFloats.MinimalNonBoundaryFloat
func test_minimal_non_boundary_float() -> void:
	assert_float(Q.minimal(Gs.floats(1.0, 9.0), func(v: float) -> bool: return v > 2.0)).is_equal(3.0)


# FindFloats.MinimalAsymmetricBoundedFloat
func test_minimal_asymmetric_bounded_float() -> void:
	assert_float(Q.minimal(Gs.floats(1.1, 1.6), _any)).is_equal(1.5)


# FindFloats.NegativeFloatsSimplifyToZero
func test_negative_floats_simplify_to_zero() -> void:
	assert_float(Q.minimal(Gs.floats(), func(v: float) -> bool: return v <= -1.0)).is_equal(-1.0)


# FindFloats.MinimalInfiniteFloatIsPositive
func test_minimal_infinite_float_is_positive() -> void:
	assert_float(Q.minimal(Gs.floats(), func(v: float) -> bool: return is_inf(v))).is_equal(INF)


# FindFloats.CanMinimalInfiniteNegativeFloat: -inf is rare, so 500 cases.
func test_can_minimal_infinite_negative_float() -> void:
	assert_float(Q.minimal(Gs.floats(), func(v: float) -> bool: return v < -MAX, 500)).is_equal(-INF)


# FindFloats.MinimalFloatOnBoundaryOfRepresentable
func test_minimal_float_on_boundary_of_representable() -> void:
	var x: float = Q.minimal(
		Gs.floats(), func(v: float) -> bool: return v + 1.0 == v and not is_inf(v)
	)
	assert_bool(is_finite(x) and x + 1.0 == x).is_true()


# FindFloats.MinimizeVeryLargeFloat
func test_minimize_very_large_float() -> void:
	var t := MAX / 2.0
	assert_float(Q.minimal(Gs.floats(), func(v: float) -> bool: return v >= t)).is_equal(t)


# FindFloats.MinimalFractionalFloat
func test_minimal_fractional_float() -> void:
	assert_float(Q.minimal(Gs.floats(), func(v: float) -> bool: return v >= 1.5)).is_equal(2.0)


# FindFloats.BoundsAreRespected
func test_bounds_are_respected() -> void:
	assert_float(Q.minimal(Gs.floats(1.0), _any)).is_equal(1.0)
	assert_float(Q.minimal(Gs.floats(-INF, -1.0), _any)).is_equal(-1.0)


# FindFloats.FromZeroHaveReasonableRange_0, _3, _6
func test_from_zero_have_reasonable_range() -> void:
	for n: float in [1.0, 1000.0, 1000000.0]:
		assert_float(Q.minimal(Gs.floats(0.0), func(x: float) -> bool: return x >= n)).is_equal(n)


# FindFloats.ExplicitAllowNan
func test_explicit_allow_nan() -> void:
	var x: float = Q.minimal(Gs.floats(-INF, INF, true), func(v: float) -> bool: return is_nan(v))
	assert_bool(is_nan(x)).is_true()


# FindFloats.OneSidedContainsInfinity
func test_one_sided_contains_infinity() -> void:
	var x: float = Q.minimal(Gs.floats(1.0), func(v: float) -> bool: return is_inf(v))
	assert_bool(is_inf(x)).is_true()


# FindFloats.CanMinimalFloatFarFromIntegral
func test_can_minimal_float_far_from_integral() -> void:
	var x: float = Q.minimal(
		Gs.floats(),
		func(v: float) -> bool:
			if not is_finite(v):
				return false
			var scaled := v * float(1 << 32)
			return fmod(scaled, 1.0) != 0.0
	)
	assert_bool(is_finite(x)).is_true()


# ShrinkFloats.CanShrinkInVariableSizedContext_1, _2, _3, _8, _10
func test_can_shrink_in_variable_sized_context() -> void:
	for n: int in [1, 2, 3, 8, 10]:
		var v: Array = Q.minimal(
			Gs.lists(Gs.floats(), n),
			func(xs: Array) -> bool: return xs.any(func(f: float) -> bool: return f != 0.0)
		)
		assert_int(v.size()).is_equal(n)
		assert_int(v.count(0.0)).is_equal(n - 1)
		assert_bool(v.has(1.0)).is_true()


# ShrinkFloats.CanFindNans
func test_can_find_nans() -> void:
	var v: Array = Q.minimal(Gs.lists(Gs.floats()), func(xs: Array) -> bool: return is_nan(_sum(xs)))
	if v.size() == 1:
		assert_bool(is_nan(v[0])).is_true()
	else:
		assert_int(v.size()).is_between(2, 3)


# FindFloats.MinimalSmallSumFloatList
func test_minimal_small_sum_float_list() -> void:
	var v: Array = Q.minimal(Gs.lists(Gs.floats(), 5), func(xs: Array) -> bool: return _sum(xs) >= 1.0)
	assert_array(v).is_equal([0.0, 0.0, 0.0, 0.0, 1.0])


# FindFloats.ListOfFractionalFloat: every element is 2.0, the only float whose
# bits equal 2.0's.
func test_list_of_fractional_float() -> void:
	var v: Array = Q.minimal(
		Gs.lists(Gs.floats(), 5),
		func(xs: Array) -> bool: return xs.filter(func(t: float) -> bool: return t >= 1.5).size() >= 5
	)
	assert_array(v).is_not_empty()
	assert_array(v.filter(func(f: float) -> bool: return f != 2.0)).is_empty()
