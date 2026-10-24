# gdlint: disable=max-public-methods
extends GdUnitTestSuite
## Integer quality, ported from upstream's
## frontends/cpp/tests/shrink_quality/test_integers.cpp and
## find_quality/test_integers.cpp. The list cases wait for p6.

const Gs := preload("res://addons/hegel/generators.gd")
const Q := preload("res://tests/support/quality.gd")

const MIN := Gs.INT64_MIN
const MAX := Gs.INT64_MAX


static func _any(_x: int) -> bool:
	return true


## |x| as a float, since INT64_MIN has no int magnitude.
static func _magnitude(x: int) -> float:
	return absf(float(x))


# shrink_quality


func test_from_minimizes_leftwards() -> void:
	assert_int(Q.minimal(Gs.integers(101), _any)).is_equal(101)


func test_minimize_bounded_integers_to_zero() -> void:
	assert_int(Q.minimal(Gs.integers(-10, 10), _any)).is_equal(0)


func test_single_element_silly_large_range() -> void:
	(
		assert_int(Q.minimal(Gs.integers(MIN / 2, MAX / 2), func(x: int) -> bool: return x >= MIN / 4))
		. is_equal(0)
	)


func test_can_find_an_int() -> void:
	assert_int(Q.minimal(Gs.integers(), _any)).is_equal(0)


func test_can_find_an_int_above_13() -> void:
	assert_int(Q.minimal(Gs.integers(), func(x: int) -> bool: return x >= 13)).is_equal(13)


# find_quality


func test_can_produce_zero() -> void:
	Q.find_any(Gs.integers(), func(x: int) -> bool: return x == 0)


func test_can_produce_large_magnitude_integers() -> void:
	Q.find_any(Gs.integers(), func(x: int) -> bool: return _magnitude(x) > 1000)


func test_can_produce_large_positive_integers() -> void:
	Q.find_any(Gs.integers(), func(x: int) -> bool: return x > 1000)


func test_can_produce_large_negative_integers() -> void:
	Q.find_any(Gs.integers(), func(x: int) -> bool: return x < -1000)


func test_integers_are_usually_non_zero() -> void:
	Q.find_any(Gs.integers(), func(x: int) -> bool: return x != 0)


func test_integers_are_often_small() -> void:
	Q.find_any(Gs.integers(), func(x: int) -> bool: return _magnitude(x) <= 100)


func test_can_occasionally_be_really_large() -> void:
	Q.find_any(Gs.integers(), func(x: int) -> bool: return x >= MAX / 2)


func test_minimize_negative_int() -> void:
	assert_int(Q.minimal(Gs.integers(), func(x: int) -> bool: return x < 0)).is_equal(-1)
	assert_int(Q.minimal(Gs.integers(), func(x: int) -> bool: return x < -1)).is_equal(-2)


func test_positive_negative_int() -> void:
	assert_int(Q.minimal(Gs.integers(), func(x: int) -> bool: return x > 0)).is_equal(1)
	assert_int(Q.minimal(Gs.integers(), func(x: int) -> bool: return x > 1)).is_equal(2)


func test_minimize_down_to_boundary() -> void:
	var boundaries := [1, 2, 3, 4, 7, 8, 15, 16, 31, 32, 63, 64, 100, 127, 128, 255, 256, 511, 512]
	for n: int in boundaries + [1000, 10000, 100000]:
		assert_int(Q.minimal(Gs.integers(), func(x: int) -> bool: return x >= n)).is_equal(n)


func test_minimize_up_to_boundary() -> void:
	for n: int in [-1, -16, -128, -1000]:
		assert_int(Q.minimal(Gs.integers(), func(x: int) -> bool: return x <= n)).is_equal(n)


func test_from_down_to_boundary() -> void:
	for n: int in [16, 128, 1000]:
		assert_int(Q.minimal(Gs.integers(n - 10), func(x: int) -> bool: return x >= n)).is_equal(n)
		assert_int(Q.minimal(Gs.integers(n), _any)).is_equal(n)


func test_negative_integer_range_upwards() -> void:
	assert_int(Q.minimal(Gs.integers(-10, -1), _any)).is_equal(-1)


func test_integer_range_to_boundary() -> void:
	for n: int in [16, 128]:
		assert_int(Q.minimal(Gs.integers(n, n + 100), _any)).is_equal(n)


func test_single_integer_range_is_range() -> void:
	assert_int(Q.minimal(Gs.integers(1, 1), _any)).is_equal(1)


func test_minimal_small_number_in_large_range() -> void:
	(
		assert_int(Q.minimal(Gs.integers(-(1 << 32), 1 << 32), func(x: int) -> bool: return x >= 101))
		. is_equal(101)
	)


func test_minimal_above_100_is_101() -> void:
	assert_int(Q.minimal(Gs.integers(), func(x: int) -> bool: return x > 100)).is_equal(101)


func test_minimal_from_101_is_101() -> void:
	assert_int(Q.minimal(Gs.integers(101, MAX), _any)).is_equal(101)


func test_all_examples_are_in_bounds() -> void:
	Q.assert_all_examples(Gs.integers(-5, 5), func(x: int) -> bool: return x >= -5 and x <= 5)


# ShrinkIntegers.MinimizeBoundedIntegersToPositive
func test_minimize_bounded_integers_to_positive() -> void:
	var nonzero := Gs.integers(-10, 10).filter(func(x: int) -> bool: return x != 0)
	assert_int(Q.minimal(nonzero, _any)).is_equal(1)
