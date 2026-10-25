extends GdUnitTestSuite
## Contract and validation tests for lists, tuples and dictionaries.

const Gs := preload("res://addons/hegel/generators.gd")
const Q := preload("res://tests/support/quality.gd")


static func _size_in(low: int, high: int) -> Callable:
	return func(x: Variant) -> bool: return x.size() >= low and x.size() <= high


static func _has_size(n: int) -> Callable:
	return func(x: Variant) -> bool: return x.size() == n


static func _at_least(n: int) -> Callable:
	return func(x: Variant) -> bool: return x.size() >= n


static func _distinct(xs: Array) -> bool:
	var seen := {}
	for x: Variant in xs:
		seen[x] = true
	return seen.size() == xs.size()


static func _drawn_by(body: Callable) -> Array:
	var drawn := []
	Hegel.run(func(tc: HegelTestCase) -> void: drawn.append(body.call(tc)), Q._settings(20))
	return drawn


func test_list_sizes_stay_within_bounds() -> void:
	Q.assert_all_examples(Gs.lists(Gs.integers(), 2, 4), _size_in(2, 4))
	Q.assert_all_examples(Gs.lists(Gs.booleans(), 3, 3), _has_size(3))
	Q.assert_all_examples(Gs.lists(Gs.integers(), 0, 0), _has_size(0))


func test_list_elements_come_from_their_generator() -> void:
	Q.assert_all_examples(
		Gs.lists(Gs.integers(-5, 5)),
		func(xs: Array) -> bool: return xs.all(func(x: int) -> bool: return x >= -5 and x <= 5)
	)


func test_list_bounds_are_reachable() -> void:
	Q.find_any(Gs.lists(Gs.integers(), 0, 5), _has_size(0))
	Q.find_any(Gs.lists(Gs.integers(), 0, 5), _has_size(5))
	Q.find_any(Gs.lists(Gs.integers(), 2), _has_size(2))


func test_unique_lists_have_no_duplicates() -> void:
	Q.assert_all_examples(Gs.lists(Gs.integers(0, 3), 0, -1, true), _distinct)
	Q.assert_all_examples(Gs.lists(Gs.integers(0, 2), 3, -1, true), _has_size(3))
	Q.find_any(Gs.lists(Gs.integers(0, 3), 0, -1, true), _has_size(4))


func test_unique_is_dictionary_key_equality() -> void:
	var gen := Gs.lists(Gs.sampled_from([1, 1.0, true, "a", &"a"]), 4, -1, true)
	Q.assert_all_examples(gen, func(xs: Array) -> bool: return xs.size() == 4 and _distinct(xs))


func test_unique_lists_report_only_accepted_elements() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			var xs: Array = tc.draw(Gs.lists(Gs.integers(0, 1), 2, -1, true), "xs")
			tc.check(xs.size() < 2),
		Q._settings(100)
	)
	assert_str(result.report).contains("\n  var xs = [0, 1]\n")


func test_tuples_draw_one_value_per_generator_in_order() -> void:
	var gen := Gs.tuples(Gs.integers(0, 3), Gs.just("x"), Gs.booleans())
	Q.assert_all_examples(
		gen,
		func(t: Array) -> bool:
			return t.size() == 3 and t[0] is int and t[0] <= 3 and t[1] == "x" and t[2] is bool
	)
	Q.assert_all_examples(Gs.tuples(), func(t: Array) -> bool: return t.is_empty())


func test_tuples_shrink_each_part() -> void:
	var gen := Gs.tuples(Gs.integers(), Gs.booleans())
	assert_array(Q.minimal(gen, func(_t: Array) -> bool: return true)).is_equal([0, false])


func test_tuples_with_a_non_generator_are_a_usage_error() -> void:
	assert_str(Q.usage_error(Gs.tuples(Gs.integers(), "x"))).contains("argument 2 is x")


func test_dictionary_sizes_stay_within_bounds() -> void:
	Q.assert_all_examples(Gs.dictionaries(Gs.integers(0, 3), Gs.text()), _size_in(0, 4))
	Q.assert_all_examples(Gs.dictionaries(Gs.integers(0, 3), Gs.booleans(), 2, 3), _size_in(2, 3))
	Q.find_any(Gs.dictionaries(Gs.integers(), Gs.integers(), 0, 3), _has_size(0))
	Q.find_any(Gs.dictionaries(Gs.integers(), Gs.integers(), 0, 3), _has_size(3))


func test_dictionary_keys_and_values_come_from_their_generators() -> void:
	Q.assert_all_examples(
		Gs.dictionaries(Gs.integers(0, 9), Gs.just("v")),
		func(d: Dictionary) -> bool:
			return (
				d.keys().all(func(k: int) -> bool: return k >= 0 and k <= 9)
				and d.values().all(func(v: String) -> bool: return v == "v")
			)
	)


func test_dictionary_needing_every_key_gets_them_all() -> void:
	Q.assert_all_examples(
		Gs.dictionaries(Gs.booleans(), Gs.integers(), 2),
		func(d: Dictionary) -> bool: return d.has(false) and d.has(true)
	)
	var gen := Gs.dictionaries(Gs.integers(), Gs.integers(), 2)
	assert_dict(Q.minimal(gen, func(_d: Dictionary) -> bool: return true)).is_equal({0: 0, 1: 0})


func test_invalid_sizes_are_usage_errors() -> void:
	for gen: HegelGenerator in [
		Gs.lists(Gs.integers(), -1),
		Gs.dictionaries(Gs.integers(), Gs.integers(), -1),
	]:
		assert_str(Q.usage_error(gen)).contains("min_size >= 0, got -1")
	for gen: HegelGenerator in [
		Gs.lists(Gs.integers(), 0, -2),
		Gs.dictionaries(Gs.integers(), Gs.integers(), 0, -2),
	]:
		assert_str(Q.usage_error(gen)).contains("max_size >= 0, or -1 for no bound, got -2")
	for gen: HegelGenerator in [
		Gs.lists(Gs.integers(), 3, 2),
		Gs.dictionaries(Gs.integers(), Gs.integers(), 3, 2),
	]:
		assert_str(Q.usage_error(gen)).contains("min_size <= max_size")


func test_null_generators_are_usage_errors() -> void:
	assert_str(Q.usage_error(Gs.lists(null))).contains("generator of elements")
	assert_str(Q.usage_error(Gs.dictionaries(null, Gs.integers()))).contains("generator of keys")
	assert_str(Q.usage_error(Gs.dictionaries(Gs.integers(), null))).contains("generator of values")


## Python's test_unique_collections_need_enough_distinct_values.
func test_unique_collections_need_enough_distinct_values() -> void:
	var cases := [
		[Gs.lists(Gs.sampled_from([1]), 2, -1, true), "only 1 distinct value"],
		[Gs.lists(Gs.sampled_from([1, 1, 2]), 3, -1, true), "only 2 distinct values"],
		[Gs.lists(Gs.booleans(), 3, -1, true), "only 2 distinct values"],
		[Gs.lists(Gs.just(1), 2, -1, true), "only 1 distinct value"],
		[Gs.lists(Gs.integers(0, 1), 3, -1, true), "only 2 distinct values"],
		[
			Gs.dictionaries(Gs.booleans(), Gs.integers(), 3),
			"3 unique keys from a generator with only 2 distinct values"
		],
	]
	for case: Array in cases:
		assert_str(Q.usage_error(case[0])).ends_with(case[1])


## Python's test_unique_collections_with_enough_distinct_values.
func test_unique_collections_with_enough_distinct_values() -> void:
	Q.assert_all_examples(Gs.lists(Gs.sampled_from([1, 1, 2]), 2, -1, true), _has_size(2))
	Q.assert_all_examples(Gs.lists(Gs.integers(0), 3, -1, true), _at_least(3))
	Q.assert_all_examples(Gs.lists(Gs.integers(), 3, -1, true), _at_least(3))
	Q.assert_all_examples(Gs.lists(Gs.booleans(), 2, -1, true), _has_size(2))
	Q.assert_all_examples(Gs.lists(Gs.just(1), 1, -1, true), func(xs: Array) -> bool: return xs == [1])
	# Not unique, so no distinct-values check applies.
	Q.assert_all_examples(Gs.lists(Gs.just(1), 3), _at_least(3))


func test_collections_give_simplest_values_after_a_terminal_event() -> void:
	var after := _drawn_by(
		func(tc: HegelTestCase) -> Array:
			tc.check(false)
			return [
				tc.draw(Gs.lists(Gs.integers(3, 9))),
				tc.draw(Gs.lists(Gs.integers(3, 9), 2)),
				# A unique list of simplest values stops at its first duplicate.
				tc.draw(Gs.lists(Gs.integers(3, 9), 3, -1, true)),
				tc.draw(Gs.tuples(Gs.booleans(), Gs.integers(1, 2))),
				tc.draw(Gs.dictionaries(Gs.integers(), Gs.just("v"), 2)),
			]
	)
	assert_array(after.back()).is_equal([[], [3, 3], [3], [false, 1], {0: "v"}])


## Sizes and bounds hold across seeds. A nested Hegel.run is a usage error, so
## the seeds come from a seeded RandomNumberGenerator.
func test_list_bounds_hold_across_seeds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i: int in 10:
		var settings := Q._settings(30, true)
		settings.seed = rng.randi()
		var result := Hegel.run(
			func(tc: HegelTestCase) -> void:
				var xs: Array = tc.draw(Gs.lists(Gs.integers(0, 9), 2, 5))
				tc.check(xs.size() >= 2 and xs.size() <= 5)
				tc.check(xs.all(func(x: int) -> bool: return x >= 0 and x <= 9)),
			settings
		)
		assert_bool(result.passed).override_failure_message(result.report).is_true()
