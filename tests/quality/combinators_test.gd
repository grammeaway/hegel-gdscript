extends GdUnitTestSuite
## Combinator quality, ported from upstream's
## frontends/cpp/tests/shrink_quality/test_flatmap.cpp, test_mixed_types.cpp and
## find_quality/test_one_of.cpp; each test names its upstream case. The
## ShrinkMixed cases run once: upstream's repeats share seed 1.

const Gs := preload("res://addons/hegel/generators.gd")
const Q := preload("res://tests/support/quality.gd")


static func _any(_x: Variant) -> bool:
	return true


static func _is(target: int) -> Callable:
	return func(x: int) -> bool: return x == target


static func _doubled(gen: HegelGenerator) -> HegelGenerator:
	return gen.map(func(x: int) -> int: return x * 2)


static func _filled(size: int, value: Variant) -> Array:
	var result := []
	result.resize(size)
	result.fill(value)
	return result


## A flat_map from a list size k to lists of exactly k booleans.
static func _bound_size(low: int) -> HegelGenerator:
	return Gs.integers(low, 100).flat_map(
		func(k: int) -> HegelGenerator: return Gs.lists(Gs.booleans(), k, k)
	)


static func _nested_one_of() -> HegelGenerator:
	return Gs.one_of(
		Gs.just(0),
		Gs.one_of(
			Gs.just(1),
			Gs.just(2),
			Gs.one_of(Gs.just(3), Gs.just(4), Gs.one_of(Gs.just(5), Gs.just(6), Gs.just(7)))
		)
	)


# shrink_quality/test_flatmap.cpp


# ShrinkFlatmap.AcrossFlatmapOfJust
func test_across_flatmap_of_just() -> void:
	var gen := Gs.integers().flat_map(func(x: int) -> HegelGenerator: return Gs.just(x))
	assert_int(Q.minimal(gen, _any)).is_equal(0)


# ShrinkFlatmap.BoundedLeftHandSize
func test_bounded_left_hand_size() -> void:
	var gen := Gs.booleans().flat_map(func(x: bool) -> HegelGenerator: return Gs.lists(Gs.just(x)))
	var v: Array = Q.minimal(gen, func(x: Array) -> bool: return x.size() >= 10)
	assert_array(v).is_equal(_filled(10, false))


# ShrinkFlatmap.RightHandStrategyOfFlatmap
func test_right_hand_strategy_of_flatmap() -> void:
	var gen := Gs.integers().flat_map(func(x: int) -> HegelGenerator: return Gs.lists(Gs.just(x)))
	assert_array(Q.minimal(gen, _any)).is_empty()


# ShrinkFlatmap.IgnoreLeftHandSide
func test_ignore_left_hand_side() -> void:
	var gen := Gs.integers().flat_map(
		func(_x: int) -> HegelGenerator: return Gs.lists(Gs.integers())
	)
	var v: Array = Q.minimal(gen, func(x: Array) -> bool: return x.size() >= 10)
	assert_array(v).is_equal(_filled(10, 0))


# ShrinkFlatmap.BothSidesOfFlatmap
func test_both_sides_of_flatmap() -> void:
	var gen := Gs.integers().flat_map(func(x: int) -> HegelGenerator: return Gs.lists(Gs.just(x)))
	var v: Array = Q.minimal(gen, func(x: Array) -> bool: return x.size() >= 10)
	assert_array(v).is_equal(_filled(10, 0))


# ShrinkFlatmap.Rectangles
func test_rectangles() -> void:
	var gen := Gs.integers(0, 10).flat_map(
		func(w: int) -> HegelGenerator: return Gs.lists(Gs.lists(Gs.sampled_from(["a", "b"]), w, w))
	)
	var v: Array = Q.minimal(gen, func(x: Array) -> bool: return x.has(["a", "b"]), 2000)
	assert_array(v).is_equal([["a", "b"]])


# ShrinkFlatmap.ShrinkThroughBinding_1, _3, _5, _9: as upstream, only the count
# of trues is minimal; the engine keeps the false padding.
func test_shrink_through_binding() -> void:
	for n: int in [1, 3, 5, 9]:
		var v: Array = Q.minimal(_bound_size(0), func(x: Array) -> bool: return x.count(true) >= n)
		assert_int(v.count(true)).is_equal(n)


# ShrinkFlatmap.DeleteInMiddle_1, _3, _5, _9
func test_delete_in_middle() -> void:
	for n: int in [1, 3, 5, 9]:
		var v: Array = Q.minimal(
			_bound_size(1),
			func(x: Array) -> bool:
				return x.size() >= 2 and x.front() and x.back() and x.count(false) >= n
		)
		assert_array(v).is_equal([true] + _filled(n, false) + [true])


# shrink_quality/test_mixed_types.cpp


# ShrinkMixed.OneOfIntegers, once: upstream's ten repeats share seed 1.
func test_one_of_integers() -> void:
	assert_int(Q.minimal(Gs.one_of(Gs.integers(), Gs.integers(100, 200)), _any)).is_equal(0)


# ShrinkMixed.OneOfSlip
func test_one_of_slip() -> void:
	assert_int(Q.minimal(Gs.one_of(Gs.integers(101, 200), Gs.integers(0, 100)), _any)).is_equal(101)


# ShrinkMixed.OneOfMixed
func test_one_of_mixed() -> void:
	var v: Variant = Q.minimal(Gs.one_of(Gs.integers(), Gs.text(), Gs.booleans()), _any)
	assert_bool(is_same(v, 0) or is_same(v, "") or is_same(v, false)).is_true()


# ShrinkMixed.MixedList
func test_mixed_list() -> void:
	var v: Array = Q.minimal(
		Gs.lists(Gs.one_of(Gs.integers(), Gs.text())), func(x: Array) -> bool: return x.size() >= 10
	)
	assert_int(v.size()).is_equal(10)
	for item: Variant in v:
		assert_bool(is_same(item, 0) or is_same(item, "")).is_true()


# ShrinkMixed.MixedListFlatmap
func test_mixed_list_flatmap() -> void:
	var element := Gs.booleans().flat_map(
		func(b: bool) -> HegelGenerator: return Gs.booleans() if b else Gs.text()
	)
	var v: Array = Q.minimal(
		Gs.lists(element),
		func(x: Array) -> bool:
			var bools := x.filter(func(e: Variant) -> bool: return e is bool).size()
			return bools >= 3 and x.size() - bools >= 3
	)
	assert_int(v.size()).is_equal(6)
	for item: Variant in v:
		assert_bool(is_same(item, false) or is_same(item, "")).is_true()


# ShrinkMixed.BuildsStructShrinksSeparatedFields, as a tuple of the fields.
func test_builds_struct_shrinks_separated_fields() -> void:
	var gen := Gs.tuples(
		Gs.integers(0, 1000), Gs.text(), Gs.booleans(), Gs.integers(), Gs.integers(0, 1000)
	)
	var v: Array = Q.minimal(gen, func(r: Array) -> bool: return r[0] + r[4] > 1000)
	assert_int(v[0]).is_equal(1)
	assert_int(v[4]).is_equal(1000)


# find_quality/test_one_of.cpp


# FindOneOfFlat.Reaches
func test_find_one_of_flat() -> void:
	for target: int in 8:
		Q.find_any(_nested_one_of(), _is(target))


# FindOneOfMap.Reaches
func test_find_one_of_map() -> void:
	var gen := Gs.one_of(
		Gs.just(1),
		Gs.one_of(
			_doubled(Gs.one_of(Gs.just(2), Gs.just(3))),
			_doubled(
				Gs.one_of(
					_doubled(Gs.one_of(Gs.just(4), Gs.just(5))),
					_doubled(Gs.one_of(Gs.just(6), Gs.just(7), Gs.just(8)))
				)
			)
		)
	)
	for target: int in [1, 4, 6, 16, 20, 24, 28, 32]:
		Q.find_any(gen, _is(target))


# FindOneOfFlatmap.Reaches: arrays of 0 to 7 nulls.
func test_find_one_of_flatmap() -> void:
	var sized: Array[HegelGenerator] = []
	for n: int in 8:
		var values := []
		values.resize(n)
		sized.append(Gs.just(values))
	var gen := Gs.just(0).flat_map(
		func(_x: int) -> HegelGenerator:
			return Gs.one_of(
				sized[0],
				sized[1],
				Gs.one_of(
					sized[2],
					sized[3],
					Gs.one_of(sized[4], sized[5], Gs.one_of(sized[6], sized[7]))
				)
			)
	)
	for target: int in 8:
		Q.find_any(gen, func(a: Array) -> bool: return a.size() == target)


# FindOneOfFilter.Reaches
func test_find_one_of_filter() -> void:
	var gen := Gs.one_of(
		Gs.just(0),
		Gs.just(1),
		Gs.one_of(
			Gs.just(2),
			Gs.just(3),
			Gs.one_of(Gs.just(4), Gs.just(5), Gs.one_of(Gs.just(6), Gs.just(7)))
		)
	)
	gen = gen.filter(func(x: int) -> bool: return x % 2 == 0)
	for target: int in [0, 2, 4, 6]:
		Q.find_any(gen, _is(target))
