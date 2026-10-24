extends GdUnitTestSuite
## Combinator quality, ported from upstream's
## frontends/cpp/tests/shrink_quality/test_flatmap.cpp, test_mixed_types.cpp and
## find_quality/test_one_of.cpp; each test names its upstream case. Cases
## needing lists or text wait for p6.

const Gs := preload("res://addons/hegel/generators.gd")
const Q := preload("res://tests/support/quality.gd")


static func _any(_x: Variant) -> bool:
	return true


static func _is(target: int) -> Callable:
	return func(x: int) -> bool: return x == target


static func _doubled(gen: HegelGenerator) -> HegelGenerator:
	return gen.map(func(x: int) -> int: return x * 2)


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


# shrink_quality/test_mixed_types.cpp


# ShrinkMixed.OneOfIntegers, once: upstream's ten repeats share seed 1.
func test_one_of_integers() -> void:
	assert_int(Q.minimal(Gs.one_of(Gs.integers(), Gs.integers(100, 200)), _any)).is_equal(0)


# ShrinkMixed.OneOfSlip
func test_one_of_slip() -> void:
	assert_int(Q.minimal(Gs.one_of(Gs.integers(101, 200), Gs.integers(0, 100)), _any)).is_equal(101)


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
