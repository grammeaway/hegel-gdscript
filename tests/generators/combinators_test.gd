extends GdUnitTestSuite
## Contract and validation tests for just, sampled_from, one_of, map, filter,
## flat_map and composite.

const Gs := preload("res://addons/hegel/generators.gd")
const Q := preload("res://tests/support/quality.gd")


static func _equals(expected: Variant) -> Callable:
	return func(x: Variant) -> bool: return is_same(x, expected)


static func _pair(tc: HegelTestCase, limit: int) -> Array:
	var a: int = tc.draw(Gs.integers(0, limit))
	return [a, tc.draw(Gs.integers(a, limit))]


static func _drawn_by(body: Callable) -> Array:
	var drawn := []
	Hegel.run(func(tc: HegelTestCase) -> void: drawn.append(body.call(tc)), Q._settings(20))
	return drawn


func test_just_always_gives_its_value() -> void:
	var value := {"a": [1, 2]}
	Q.assert_all_examples(Gs.just(value), func(x: Dictionary) -> bool: return is_same(x, value))


func test_just_draws_nothing() -> void:
	var result := Hegel.run(func(tc: HegelTestCase) -> void: tc.draw(Gs.just(1)), Q._settings(100))
	assert_bool(result.passed).is_true()
	assert_int(result.test_cases).is_equal(1)


func test_sampled_from_reaches_every_element() -> void:
	var elements := ["a", 2, Vector2.ONE, null]
	for element: Variant in elements:
		Q.find_any(Gs.sampled_from(elements), _equals(element))
	Q.assert_all_examples(Gs.sampled_from(elements), func(x: Variant) -> bool: return x in elements)


func test_sampled_from_copies_its_elements() -> void:
	var elements := [1, 2]
	var gen := Gs.sampled_from(elements)
	elements.clear()
	Q.assert_all_examples(gen, func(x: int) -> bool: return x in [1, 2])


func test_empty_sampled_from_is_a_usage_error() -> void:
	assert_str(Q.usage_error(Gs.sampled_from([]))).contains("sampled_from")


func test_one_of_reaches_every_branch() -> void:
	var gen := Gs.one_of(Gs.just("a"), Gs.integers(10, 20), Gs.booleans())
	Q.find_any(gen, _equals("a"))
	Q.find_any(gen, func(x: Variant) -> bool: return x is int and x >= 10 and x <= 20)
	Q.find_any(gen, func(x: Variant) -> bool: return x is bool)
	Q.assert_all_examples(gen, func(x: Variant) -> bool: return x is String or x is int or x is bool)


func test_one_of_flattens_and_passes_a_single_generator_through() -> void:
	var single := Gs.integers()
	assert_object(Gs.one_of(single)).is_same(single)
	var nested := Gs.one_of(Gs.just(0), Gs.one_of(Gs.just(1), Gs.just(2)))
	assert_int((nested.get("_branches") as Array).size()).is_equal(3)


func test_invalid_one_of_is_a_usage_error() -> void:
	assert_str(Q.usage_error(Gs.one_of())).contains("at least one")
	assert_str(Q.usage_error(Gs.one_of(Gs.just(1), 5))).contains("argument 2 is 5")


func test_map_applies_its_function() -> void:
	var gen := Gs.integers(0, 10).map(func(x: int) -> String: return str(x * 2))
	Q.assert_all_examples(gen, func(s: String) -> bool: return int(s) % 2 == 0 and int(s) <= 20)


func test_filter_keeps_satisfying_values() -> void:
	var gen := Gs.integers(0, 100).filter(func(x: int) -> bool: return x % 2 == 0)
	Q.assert_all_examples(gen, func(x: int) -> bool: return x % 2 == 0)


func test_chained_filters_all_apply_and_merge() -> void:
	var gen := (
		Gs
		. integers(0, 100)
		. filter(func(x: int) -> bool: return x % 2 == 0)
		. filter(func(x: int) -> bool: return x % 3 == 0)
	)
	Q.assert_all_examples(gen, func(x: int) -> bool: return x % 6 == 0)
	assert_int((gen.get("_predicates") as Array).size()).is_equal(2)


func test_unsatisfiable_filter_rejects_every_case() -> void:
	var body := func(tc: HegelTestCase) -> void:
		tc.draw(Gs.integers().filter(func(_x: int) -> bool: return false))
	var settings := Q._settings(100)
	assert_int(Hegel.run(body, settings).error_kind).is_equal(HegelResult.ErrorKind.HEALTH_CHECK)
	settings.suppress_health_checks = HegelSettings.HealthCheck.FILTER_TOO_MUCH
	assert_int(Hegel.run(body, settings).error_kind).is_equal(HegelResult.ErrorKind.UNSATISFIABLE)


func test_filter_tries_three_values_per_draw() -> void:
	var attempts: Array[int] = []
	var settings := Q._settings(5)
	settings.suppress_health_checks = HegelSettings.HealthCheck.FILTER_TOO_MUCH
	var rejects := func(_x: int) -> bool:
		attempts[-1] += 1
		return false
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			attempts.append(0)
			tc.draw(Gs.integers().filter(rejects)),
		settings
	)
	assert_array(attempts).is_not_empty()
	for count: int in attempts:
		assert_int(count).is_equal(3)


func test_flat_map_draws_from_the_generator_it_returns() -> void:
	var gen := Gs.integers(0, 10).flat_map(
		func(n: int) -> HegelGenerator: return Gs.integers(0, n).map(func(k: int) -> Array: return [n, k])
	)
	Q.assert_all_examples(gen, func(p: Array) -> bool: return p[1] <= p[0])
	Q.find_any(gen, func(p: Array) -> bool: return p[0] == 10 and p[1] == 10)


func test_flat_map_returning_a_non_generator_is_a_usage_error() -> void:
	var gen := Gs.integers().flat_map(func(n: int) -> Variant: return n)
	assert_str(Q.usage_error(gen)).contains("not a HegelGenerator")


func test_composite_values_depend_on_earlier_draws() -> void:
	var gen := Gs.composite(_pair.bind(100))
	Q.assert_all_examples(gen, func(p: Array) -> bool: return p[0] <= p[1] and p[1] <= 100)
	Q.find_any(gen, func(p: Array) -> bool: return p[0] > 50)


func test_composite_draws_show_as_one_value_in_the_report() -> void:
	var result := Hegel.run(
		func(tc: HegelTestCase) -> void:
			var p: Array = tc.draw(Gs.composite(_pair.bind(100)))
			tc.check(p[1] < 10),
		Q._settings(100)
	)
	assert_str(result.report).contains("\n  var draw_1 = [0, 10]\n\n")


func test_invalid_callables_are_usage_errors() -> void:
	assert_str(Q.usage_error(Gs.composite(Callable()))).contains("composite")
	assert_str(Q.usage_error(Gs.integers().map(Callable()))).contains("map")
	assert_str(Q.usage_error(Gs.integers().filter(Callable()))).contains("filter")
	assert_str(Q.usage_error(Gs.integers().flat_map(Callable()))).contains("flat_map")


func test_combinators_give_simplest_values_after_a_terminal_event() -> void:
	var after := _drawn_by(
		func(tc: HegelTestCase) -> Array:
			tc.check(false)
			return [
				tc.draw(Gs.sampled_from(["first", "second"])),
				tc.draw(Gs.one_of(Gs.integers(5, 9), Gs.just("b"))),
				tc.draw(Gs.integers(3, 9).map(func(x: int) -> int: return x * 2)),
				tc.draw(Gs.integers(3, 9).filter(func(x: int) -> bool: return x > 3)),
				tc.draw(Gs.just(4).flat_map(func(n: int) -> HegelGenerator: return Gs.integers(n))),
				tc.draw(Gs.composite(_pair.bind(5))),
			]
	)
	assert_array(after.back()).is_equal(["first", 5, 6, 3, 4, [0, 0]])
