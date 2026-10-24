class_name HegelGenerators
extends RefCounted
## Factories for the built-in generators. Alias them for short calls:
## [codeblock]
## const Gs := preload("res://addons/hegel/generators.gd")
##
## var x: int = tc.draw(Gs.integers(0, 10))
## [/codeblock]

const INT64_MIN := -9223372036854775807 - 1
const INT64_MAX := 9223372036854775807


## Integers in [code][min_value, max_value][/code], both inclusive. They shrink
## towards 0, or towards the bound nearest to it.
static func integers(min_value := INT64_MIN, max_value := INT64_MAX) -> HegelGenerator:
	return _Integers.new(min_value, max_value)


class _Integers:
	extends HegelGenerator
	var _min: int
	var _max: int

	func _init(min_value: int, max_value: int) -> void:
		label = HegelTestCase._label("integers")
		_min = min_value
		_max = max_value

	func _draw(tc: HegelTestCase) -> Variant:
		return tc._draw_integer(_min, _max)
