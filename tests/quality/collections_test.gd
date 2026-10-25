# gdlint: disable=max-public-methods
extends GdUnitTestSuite
## Collection quality, ported from upstream's
## frontends/cpp/tests/shrink_quality/test_collections.cpp and
## find_quality/test_collections.cpp; each test names its upstream case. Sets
## become unique lists, compared sorted, and maps become dictionaries. Not
## ported: ShrinkCollections.DuplicateContainment, disabled upstream.

const Gs := preload("res://addons/hegel/generators.gd")
const Q := preload("res://tests/support/quality.gd")


static func _any(_x: Variant) -> bool:
	return true


static func _sorted(xs: Array) -> Array:
	var copy := xs.duplicate()
	copy.sort()
	return copy


static func _distinct_count(xs: Array) -> int:
	var seen := {}
	for x: Variant in xs:
		seen[x] = true
	return seen.size()


## The sum, or INT64_MIN when it overflows, as upstream's saturating guard.
static func _sum(xs: Array) -> int:
	var total := 0
	for x: int in xs:
		if (x > 0 and total > Gs.INT64_MAX - x) or (x < 0 and total < Gs.INT64_MIN - x):
			return Gs.INT64_MIN
		total += x
	return total


## C++'s lexicographic < on nested vectors of bools.
static func _lex_less(a: Array, b: Array) -> bool:
	for i: int in mini(a.size(), b.size()):
		if a[i] == b[i]:
			continue
		if a[i] is Array:
			return _lex_less(a[i], b[i])
		return int(a[i]) < int(b[i])
	return a.size() < b.size()


static func _non_empty_count(xs: Array) -> int:
	return xs.filter(func(x: Variant) -> bool: return not x.is_empty()).size()


# shrink_quality


# ShrinkCollections.Minimize3Set
func test_minimize_3_set() -> void:
	var v: Array = Q.minimal(
		Gs.lists(Gs.integers(), 0, -1, true), func(x: Array) -> bool: return x.size() >= 3
	)
	assert_bool(_sorted(v) in [[0, 1, 2], [-1, 0, 1]]).override_failure_message(str(v)).is_true()


# ShrinkCollections.MinimizeSetsSampledFrom
func test_minimize_sets_sampled_from() -> void:
	var gen := Gs.lists(Gs.sampled_from(range(10)), 3, -1, true)
	assert_array(_sorted(Q.minimal(gen, _any))).is_equal([0, 1, 2])


# ShrinkCollections.Minimize3SetOfTuples
func test_minimize_3_set_of_tuples() -> void:
	var gen := Gs.lists(Gs.tuples(Gs.integers()), 0, -1, true)
	var v: Array = Q.minimal(gen, func(x: Array) -> bool: return x.size() >= 2)
	assert_array(_sorted(v)).is_equal([[0], [1]])


# ShrinkCollections.Containment_0, _1, _10, _100, _1000
func test_containment() -> void:
	for n: int in [0, 1, 10, 100, 1000]:
		var v: Array = Q.minimal(
			Gs.tuples(Gs.lists(Gs.integers()), Gs.integers()),
			func(x: Array) -> bool: return x[1] >= n and x[0].has(x[1])
		)
		assert_array(v).is_equal([[n], n])


# ShrinkCollections.ReorderingBytes
func test_reordering_bytes() -> void:
	var v: Array = Q.minimal(
		Gs.lists(Gs.integers(0, 1000)),
		func(x: Array) -> bool: return _sum(x) >= 10 and x.size() >= 3
	)
	assert_array(v).is_equal(_sorted(v))


# ShrinkCollections.MinimizeLongList
func test_minimize_long_list() -> void:
	var v: Array = Q.minimal(
		Gs.lists(Gs.booleans(), 50), func(x: Array) -> bool: return x.size() >= 70
	)
	var expected := []
	expected.resize(70)
	expected.fill(false)
	assert_array(v).is_equal(expected)


# ShrinkCollections.MinimizeListOfLongishLists
func test_minimize_list_of_longish_lists() -> void:
	var v: Array = Q.minimal(
		Gs.lists(Gs.lists(Gs.booleans())),
		func(x: Array) -> bool:
			var longish := x.filter(func(t: Array) -> bool: return t.has(true) and t.size() >= 2)
			return longish.size() >= 5
	)
	var pair := [false, true]
	assert_array(v).is_equal([pair, pair, pair, pair, pair])


# ShrinkCollections.MinimizeListOfFairlyNonUniqueInts
func test_minimize_list_of_fairly_non_unique_ints() -> void:
	var v: Array = Q.minimal(
		Gs.lists(Gs.integers()), func(x: Array) -> bool: return _distinct_count(x) < x.size()
	)
	assert_int(v.size()).is_equal(2)


# ShrinkCollections.ListWithComplexSortingStructure
func test_list_with_complex_sorting_structure() -> void:
	var v: Array = Q.minimal(
		Gs.lists(Gs.lists(Gs.booleans())),
		func(x: Array) -> bool:
			var reversed := x.map(
				func(inner: Array) -> Array:
					var copy := inner.duplicate()
					copy.reverse()
					return copy
			)
			return _lex_less(x, reversed) and x.size() > 3
	)
	assert_int(v.size()).is_equal(4)


# ShrinkCollections.ListWithWideGap
func test_list_with_wide_gap() -> void:
	var v: Array = Q.minimal(
		Gs.lists(Gs.integers()),
		func(x: Array) -> bool:
			if x.is_empty() or x.min() > Gs.INT64_MAX - 10:
				return false
			return x.max() > x.min() + 10 and x.min() + 10 > 0
	)
	assert_int(v.size()).is_equal(2)
	var sorted := _sorted(v)
	assert_int(sorted[1]).is_equal(sorted[0] + 11)


# ShrinkCollections.MinimizeListOfSets
func test_minimize_list_of_sets() -> void:
	var v: Array = Q.minimal(
		Gs.lists(Gs.lists(Gs.booleans(), 0, -1, true)),
		func(x: Array) -> bool: return _non_empty_count(x) >= 3
	)
	assert_array(v).is_equal([[false], [false], [false]])


# ShrinkCollections.MinimizeListOfLists
func test_minimize_list_of_lists() -> void:
	var v: Array = Q.minimal(
		Gs.lists(Gs.lists(Gs.integers())), func(x: Array) -> bool: return _non_empty_count(x) >= 3
	)
	assert_array(v).is_equal([[0], [0], [0]])


# ShrinkCollections.MinimizeListOfTuples
func test_minimize_list_of_tuples() -> void:
	var v: Array = Q.minimal(
		Gs.lists(Gs.tuples(Gs.integers(), Gs.integers())),
		func(x: Array) -> bool: return x.size() >= 2
	)
	assert_array(v).is_equal([[0, 0], [0, 0]])


# ShrinkCollections.MinimizeTupleOfBooleans
func test_minimize_tuple_of_booleans() -> void:
	var v: Array = Q.minimal(
		Gs.tuples(Gs.booleans(), Gs.booleans()), func(x: Array) -> bool: return x[0] or x[1]
	)
	assert_bool(v[0] != v[1]).override_failure_message(str(v)).is_true()


# ShrinkCollections.ListsForcedNearTop_0, _1, _5, _10
func test_lists_forced_near_top() -> void:
	for n: int in [0, 1, 5, 10]:
		var v: Array = Q.minimal(
			Gs.lists(Gs.integers(), n, n + 2), func(x: Array) -> bool: return x.size() == n + 2
		)
		var expected := []
		expected.resize(n + 2)
		expected.fill(0)
		assert_array(v).is_equal(expected)


# ShrinkCollections.MapMinimizesToEmpty
func test_map_minimizes_to_empty() -> void:
	assert_dict(Q.minimal(Gs.dictionaries(Gs.integers(), Gs.text()), _any)).is_empty()


# ShrinkCollections.MapMinimizesValues
func test_map_minimizes_values() -> void:
	var v: Dictionary = Q.minimal(
		Gs.dictionaries(Gs.integers(), Gs.text()), func(x: Dictionary) -> bool: return x.size() >= 3
	)
	assert_int(v.size()).is_greater_equal(3)
	for key: int in v:
		assert_str(v[key]).is_empty()
		if key < 0:
			assert_bool(v.has(key + 1)).is_true()
		if key > 0:
			assert_bool(v.has(key - 1)).is_true()


# ShrinkCollections.MinimizeMultiKeyMaps
func test_minimize_multi_key_maps() -> void:
	var keys := Gs.booleans().map(func(b: bool) -> String: return "true" if b else "false")
	var v: Dictionary = Q.minimal(
		Gs.dictionaries(keys, Gs.booleans()), func(x: Dictionary) -> bool: return not x.is_empty()
	)
	assert_dict(v).is_equal({"false": false})


# ShrinkCollections.FindLargeUnionList
func test_find_large_union_list() -> void:
	var union := func(x: Array) -> Array:
		var seen := {}
		for s: Array in x:
			for e: int in s:
				seen[e] = true
		return seen.keys()
	var v: Array = Q.minimal(
		Gs.lists(Gs.lists(Gs.integers(), 1, -1, true), 1),
		func(x: Array) -> bool: return union.call(x).size() >= 10
	)
	assert_int(v.size()).is_equal(1)
	var all: Array = union.call(v)
	assert_int(all.size()).is_equal(10)
	assert_int(all.max()).is_equal(all.min() + 9)


# ShrinkCollections.FindMap
func test_find_map() -> void:
	var v: Dictionary = Q.minimal(
		Gs.dictionaries(Gs.integers(), Gs.integers()),
		func(x: Dictionary) -> bool: return x.keys().any(func(k: int) -> bool: return k > x[k])
	)
	assert_int(v.size()).is_equal(1)


# ShrinkCollections.CanFindList
func test_can_find_list() -> void:
	var v: Array = Q.minimal(Gs.lists(Gs.integers()), func(x: Array) -> bool: return _sum(x) >= 10)
	assert_int(_sum(v)).is_equal(10)


# ShrinkCollections.CollectivelyMinimizeIntegers
func test_collectively_minimize_integers() -> void:
	var v: Array = Q.minimal(
		Gs.lists(Gs.integers(), 10, 10), func(x: Array) -> bool: return _distinct_count(x) >= 2, 2000
	)
	assert_int(v.size()).is_equal(10)
	assert_int(_distinct_count(v)).is_between(2, 3)


# ShrinkCollections.CollectivelyMinimizeBooleans
func test_collectively_minimize_booleans() -> void:
	var v: Array = Q.minimal(
		Gs.lists(Gs.booleans(), 10, 10), func(x: Array) -> bool: return _distinct_count(x) >= 2, 2000
	)
	assert_int(v.size()).is_equal(10)
	assert_int(_distinct_count(v)).is_equal(2)


# ShrinkCollections.CollectivelyMinimizeText
func test_collectively_minimize_text() -> void:
	var v: Array = Q.minimal(
		Gs.lists(Gs.text(), 10, 10), func(x: Array) -> bool: return _distinct_count(x) >= 2, 2000
	)
	assert_int(v.size()).is_equal(10)
	assert_int(_distinct_count(v)).is_between(2, 3)


# PLAN.md item 7's headline case, after ShrinkCollections.CanFindList: the sum
# lands exactly on the threshold.
func test_minimal_list_summing_above_100() -> void:
	var v: Array = Q.minimal(Gs.lists(Gs.integers()), func(x: Array) -> bool: return _sum(x) > 100)
	assert_int(_sum(v)).is_equal(101)


# find_quality


# FindCollections.CanProduceLongLists
func test_can_produce_long_lists() -> void:
	Q.find_any(Gs.lists(Gs.integers()), func(x: Array) -> bool: return x.size() >= 10)


# FindCollections.CanProduceShortLists
func test_can_produce_short_lists() -> void:
	Q.find_any(Gs.lists(Gs.integers()), func(x: Array) -> bool: return x.size() <= 10)


# FindCollections.CanProduceTheSameIntTwice
func test_can_produce_the_same_int_twice() -> void:
	Q.find_any(Gs.lists(Gs.integers()), func(x: Array) -> bool: return _distinct_count(x) < x.size())


# FindCollections.SampledFromLargeNumberCanMix
func test_sampled_from_large_number_can_mix() -> void:
	Q.find_any(
		Gs.lists(Gs.sampled_from(range(50)), 50),
		func(x: Array) -> bool: return _distinct_count(x) >= 25
	)


# FindCollections.NonEmptySubsetOfTwoIsUsuallyLarge
func test_non_empty_subset_of_two_is_usually_large() -> void:
	Q.find_any(
		Gs.lists(Gs.sampled_from([1, 2]), 0, -1, true), func(x: Array) -> bool: return x.size() == 2
	)


# FindCollections.SubsetOfTenIsSometimesEmpty
func test_subset_of_ten_is_sometimes_empty() -> void:
	Q.find_any(
		Gs.lists(Gs.integers(1, 10), 0, -1, true), func(x: Array) -> bool: return x.is_empty()
	)
