extends GdUnitTestSuite
## Contract and validation tests for text.

const Gs := preload("res://addons/hegel/generators.gd")
const Q := preload("res://tests/support/quality.gd")


static func _length_in(low: int, high: int) -> Callable:
	return func(s: String) -> bool: return s.length() >= low and s.length() <= high


static func _codepoints_in(low: int, high: int) -> Callable:
	return func(s: String) -> bool:
		for i: int in s.length():
			if s.unicode_at(i) < low or s.unicode_at(i) > high:
				return false
		return true


static func _any(_s: String) -> bool:
	return true


func test_text_defaults_to_at_most_100_characters() -> void:
	Q.assert_all_examples(Gs.text(), _length_in(0, 100))
	Q.find_any(Gs.text(), func(s: String) -> bool: return s.length() > 20)


func test_text_lengths_stay_within_bounds() -> void:
	Q.assert_all_examples(Gs.text(3, 5), _length_in(3, 5))
	Q.assert_all_examples(Gs.text(150), _length_in(150, 250), 5)
	Q.find_any(Gs.text(0, 4), func(s: String) -> bool: return s.is_empty())
	Q.find_any(Gs.text(0, 4), func(s: String) -> bool: return s.length() == 4)


func test_text_stays_within_its_codepoints() -> void:
	Q.assert_all_examples(Gs.text(1, -1, 65, 70), _codepoints_in(65, 70))
	Q.assert_all_examples(Gs.text(1, -1, 0x1F600, 0x1F64F), _codepoints_in(0x1F600, 0x1F64F))


func test_text_never_draws_surrogates() -> void:
	var outside := func(s: String) -> bool:
		for i: int in s.length():
			if s.unicode_at(i) >= 0xD800 and s.unicode_at(i) <= 0xDFFF:
				return false
		return true
	Q.assert_all_examples(Gs.text(1, 20, 0xD000, 0xE0FF), outside)


## A Godot String can't hold U+0000 (F5): asked for codepoints 0 and 1, text
## draws only U+0001.
func test_text_never_draws_u0000() -> void:
	Q.assert_all_examples(
		Gs.text(1, 5, 0, 1),
		func(s: String) -> bool: return s.length() >= 1 and s == char(1).repeat(s.length()),
		200
	)


func test_text_shrinks_towards_zero_or_the_nearest_codepoint() -> void:
	assert_str(Q.minimal(Gs.text(), _any)).is_equal("")
	assert_str(Q.minimal(Gs.text(1), _any)).is_equal("0")
	assert_str(Q.minimal(Gs.text(2, -1, 0x41, 0x5A), _any)).is_equal("AA")
	assert_str(Q.minimal(Gs.text(2, -1, 0x20, 0x2F), _any)).is_equal("//")


func test_text_gives_its_simplest_value_after_a_terminal_event() -> void:
	var drawn := []
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			tc.check(false)
			drawn.append(
				[
					tc.draw(Gs.text()),
					tc.draw(Gs.text(1)),
					tc.draw(Gs.text(2, -1, 0x41, 0x5A)),
					tc.draw(Gs.text(2, -1, 0x20, 0x2F)),
				]
			),
		Q._settings(10)
	)
	assert_array(drawn.back()).is_equal(["", "0", "AA", "//"])


func test_invalid_text_arguments_are_usage_errors() -> void:
	assert_str(Q.usage_error(Gs.text(-1))).contains("min_size >= 0, got -1")
	assert_str(Q.usage_error(Gs.text(0, -2))).contains("max_size >= 0, or -1 for no bound, got -2")
	assert_str(Q.usage_error(Gs.text(3, 2))).contains("min_size <= max_size")
	assert_str(Q.usage_error(Gs.text(0, -1, -1))).contains("got -1 and 1114111")
	assert_str(Q.usage_error(Gs.text(0, -1, 1, 0x110000))).contains("got 1 and 1114112")
	assert_str(Q.usage_error(Gs.text(0, -1, 70, 65))).contains("got 70 and 65")
	assert_str(Q.usage_error(Gs.text(0, -1, 0, 0))).contains("U+0000")
	assert_str(Q.usage_error(Gs.text(1, -1, 0xD800, 0xDFFF))).contains("No valid characters")
