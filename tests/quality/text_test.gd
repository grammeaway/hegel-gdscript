extends GdUnitTestSuite
## Text quality, ported from upstream's
## frontends/cpp/tests/shrink_quality/test_strings.cpp and
## find_quality/test_strings.cpp; each test names its upstream case. Lengths
## are in characters, where upstream counts UTF-8 codepoints. Not ported:
## FindStrings.CanProduceLargeBinaryStrings, since there is no binary().

const Gs := preload("res://addons/hegel/generators.gd")
const Q := preload("res://tests/support/quality.gd")

## C++'s std::isspace in the C locale.
const ASCII_SPACE := " \t\n\v\f\r"


static func _any(_x: Variant) -> bool:
	return true


static func _trimmed(s: String) -> String:
	var begin := 0
	var end := s.length()
	while begin < end and ASCII_SPACE.contains(s[begin]):
		begin += 1
	while end > begin and ASCII_SPACE.contains(s[end - 1]):
		end -= 1
	return s.substr(begin, end - begin)


static func _ascii_count(s: String) -> int:
	var count := 0
	for i: int in s.length():
		if s.unicode_at(i) <= 127:
			count += 1
	return count


# shrink_quality


# ShrinkStrings.MinimizeStringToEmpty
func test_minimize_string_to_empty() -> void:
	assert_str(Q.minimal(Gs.text(), _any)).is_equal("")


# ShrinkStrings.MinimizeLongerString
func test_minimize_longer_string() -> void:
	var v: String = Q.minimal(Gs.text(), func(x: String) -> bool: return x.length() >= 10)
	assert_str(v).is_equal("0000000000")


# ShrinkStrings.MinimizeLongerListOfStrings
func test_minimize_longer_list_of_strings() -> void:
	var v: Array = Q.minimal(Gs.lists(Gs.text()), func(x: Array) -> bool: return x.size() >= 10)
	assert_array(v).is_equal(["", "", "", "", "", "", "", "", "", ""])


# find_quality


# FindStrings.CanProduceUnstrippedStrings
func test_can_produce_unstripped_strings() -> void:
	Q.find_any(Gs.text(), func(x: String) -> bool: return x != _trimmed(x))


# FindStrings.CanProduceStrippedStrings
func test_can_produce_stripped_strings() -> void:
	Q.find_any(Gs.text(), func(x: String) -> bool: return x == _trimmed(x))


# FindStrings.CanProduceMultiLineStrings
func test_can_produce_multi_line_strings() -> void:
	Q.find_any(Gs.text(), func(x: String) -> bool: return x.contains("\n"))


# FindStrings.CanProduceAsciiStrings
func test_can_produce_ascii_strings() -> void:
	Q.find_any(Gs.text(), func(x: String) -> bool: return _ascii_count(x) == x.length())


# FindStrings.CanProduceLongStringsWithNoAscii
func test_can_produce_long_strings_with_no_ascii() -> void:
	Q.find_any(
		Gs.text(5), func(x: String) -> bool: return not x.is_empty() and _ascii_count(x) == 0
	)


# FindStrings.CanProduceShortStringsWithSomeNonAscii
func test_can_produce_short_strings_with_some_non_ascii() -> void:
	Q.find_any(
		Gs.text(), func(x: String) -> bool: return x.length() <= 3 and _ascii_count(x) < x.length()
	)


# FindStrings.LongDuplicatesStrings
func test_long_duplicates_strings() -> void:
	Q.find_any(
		Gs.tuples(Gs.text(), Gs.text()),
		func(t: Array) -> bool: return t[0].length() >= 5 and t[0] == t[1]
	)
