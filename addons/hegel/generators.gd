class_name HegelGenerators
extends RefCounted
## Factories for the built-in generators. Alias them for short calls:
## [codeblock]
## const Gs := preload("res://addons/hegel/generators.gd")
##
## var x: int = tc.draw(Gs.integers(0, 10))
## [/codeblock]
## A factory given invalid arguments still returns a generator; drawing from
## it ends the run with a [constant HegelResult.ErrorKind.USAGE] error that
## says what is wrong.

const INT64_MIN := -9223372036854775807 - 1
const INT64_MAX := 9223372036854775807


## Integers in [code][min_value, max_value][/code], both inclusive. They shrink
## towards 0, or towards the bound nearest to it.
static func integers(min_value := INT64_MIN, max_value := INT64_MAX) -> HegelGenerator:
	return _Integers.new(min_value, max_value)


## Floats in [code][min_value, max_value][/code]; an infinite bound leaves
## that end open, and [param exclude_min] and [param exclude_max] make a bound
## exclusive. They shrink towards 0.0, and towards integers before fractions.
## [br][br]
## [param allow_nan] and [param allow_infinity] allow what the bounds permit:
## NaN only when both ends are open, and an infinity only at an open end. By
## default, [code]floats()[/code] draws any float, NaN and both infinities
## included. NaN bounds, or bounds leaving no floats, are a usage error.
static func floats(
	min_value := -INF,
	max_value := INF,
	allow_nan := true,
	allow_infinity := true,
	exclude_min := false,
	exclude_max := false
) -> HegelGenerator:
	return _Floats.new(min_value, max_value, allow_nan, allow_infinity, exclude_min, exclude_max)


## [code]true[/code] or [code]false[/code], equally likely, shrinking towards
## [code]false[/code].
static func booleans() -> HegelGenerator:
	return _Booleans.new()


## Always [param value], drawing nothing. Every draw returns the same
## [param value], so changes to an Array or Object drawn in one test case show
## in the next.
static func just(value: Variant) -> HegelGenerator:
	return _Just.new(value)


## One of [param elements], shrinking towards the first. The Array is copied,
## so later changes to it don't affect the generator. An empty Array is a
## usage error.
static func sampled_from(elements: Array) -> HegelGenerator:
	if elements.is_empty():
		return _Invalid.new("sampled_from needs at least one element")
	return _SampledFrom.new(elements.duplicate())


## A value from one of [param generators], shrinking towards the earlier ones:
## [code]Gs.one_of(Gs.integers(), Gs.just(null))[/code]. Nested
## [code]one_of[/code]s are flattened, and a single generator is returned as
## it is. No generators, or an argument that isn't a [HegelGenerator], is a
## usage error.
static func one_of(...generators: Array) -> HegelGenerator:
	var branches: Array[HegelGenerator] = []
	for i: int in generators.size():
		var generator: Variant = generators[i]
		if generator is _OneOf:
			branches.append_array((generator as _OneOf)._branches)
		elif generator is HegelGenerator:
			branches.append(generator)
		else:
			return _Invalid.new(
				"one_of takes HegelGenerators, but argument %d is %s" % [i + 1, generator]
			)
	if branches.is_empty():
		return _Invalid.new("one_of needs at least one generator")
	if branches.size() == 1:
		return branches[0]
	return _OneOf.new(branches)


## A generator defined by a function: each draw calls [param fn] with the test
## case, and the value is what it returns. [param fn] draws with
## [method HegelTestCase.draw], so later draws can depend on earlier ones;
## the report shows the value, not these draws. Bind extra arguments with
## [method Callable.bind]:
## [codeblock]
## static func _sorted_pair(tc: HegelTestCase, limit: int) -> Array:
##     var a: int = tc.draw(Gs.integers(0, limit))
##     var b: int = tc.draw(Gs.integers(a, limit))
##     return [a, b]
##
## var pair: Array = tc.draw(Gs.composite(_sorted_pair.bind(100)))
## [/codeblock]
static func composite(fn: Callable) -> HegelGenerator:
	if not fn.is_valid():
		return _Invalid.new("composite needs a valid Callable")
	return _Composite.new(fn)


## The span label for [param kind] combined with [param parts], in order.
static func _combined(kind: String, parts: Array[int]) -> int:
	var labels := PackedInt64Array([HegelTestCase._label(kind)])
	labels.append_array(parts)
	return HegelNative.label_combine(labels)


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


class _Floats:
	extends HegelGenerator
	var _min: float
	var _max: float
	var _allow_nan: bool
	var _allow_infinity: bool
	var _exclude_min: bool
	var _exclude_max: bool

	func _init(
		min_value: float,
		max_value: float,
		allow_nan: bool,
		allow_infinity: bool,
		exclude_min: bool,
		exclude_max: bool
	) -> void:
		label = HegelTestCase._label("floats")
		_allow_nan = allow_nan and min_value == -INF and max_value == INF
		_allow_infinity = allow_infinity and not (is_finite(min_value) and is_finite(max_value))
		_min = min_value
		_max = max_value
		_exclude_min = exclude_min
		_exclude_max = exclude_max

	func _draw(tc: HegelTestCase) -> Variant:
		return tc._draw_float(
			_min, _max, _allow_nan, _allow_infinity, _exclude_min, _exclude_max
		)


class _Booleans:
	extends HegelGenerator

	func _init() -> void:
		label = HegelTestCase._label("booleans")

	func _draw(tc: HegelTestCase) -> Variant:
		return tc._draw_boolean()


class _Just:
	extends HegelGenerator
	var _value: Variant

	func _init(value: Variant) -> void:
		label = HegelTestCase._label("just")
		_value = value

	func _draw(_tc: HegelTestCase) -> Variant:
		return _value


class _SampledFrom:
	extends HegelGenerator
	var _elements: Array

	func _init(elements: Array) -> void:
		label = HegelTestCase._label("sampled_from")
		_elements = elements

	func _draw(tc: HegelTestCase) -> Variant:
		return _elements[tc._draw_integer(0, _elements.size() - 1)]


class _OneOf:
	extends HegelGenerator
	var _branches: Array[HegelGenerator]

	func _init(branches: Array[HegelGenerator]) -> void:
		var labels := PackedInt64Array()
		for branch: HegelGenerator in branches:
			labels.append(branch.label)
		label = HegelGenerators._combined("one_of", [HegelNative.label_combine(labels)])
		_branches = branches

	func _draw(tc: HegelTestCase) -> Variant:
		return tc.draw(_branches[tc._draw_integer(0, _branches.size() - 1)])


class _Mapped:
	extends HegelGenerator
	var _source: HegelGenerator
	var _f: Callable

	func _init(source: HegelGenerator, f: Callable) -> void:
		label = HegelGenerators._combined("map", [source.label])
		_source = source
		_f = f

	func _draw(tc: HegelTestCase) -> Variant:
		return _f.call(tc.draw(_source))


class _Filtered:
	extends HegelGenerator
	const _ATTEMPTS := 3
	var _source: HegelGenerator
	var _predicates: Array[Callable]
	var _attempt_label: int

	## Chained filters merge into one, so a chain costs one set of attempts.
	func _init(source: HegelGenerator, predicate: Callable) -> void:
		if source is _Filtered:
			var filtered := source as _Filtered
			_source = filtered._source
			_predicates = filtered._predicates.duplicate()
		else:
			_source = source
		_predicates.append(predicate)
		label = HegelGenerators._combined("filter", [_source.label])
		_attempt_label = HegelTestCase._label("filter.attempt")

	func _draw(tc: HegelTestCase) -> Variant:
		var value: Variant = null
		for attempt: int in _ATTEMPTS:
			tc._start_span(_attempt_label)
			value = tc.draw(_source)
			var accepted := _accepts(value)
			# A discarded attempt tells the shrinker its draws were thrown away.
			tc._stop_span(not accepted)
			if accepted:
				return value
		tc.assume(false)
		return value

	func _accepts(value: Variant) -> bool:
		for predicate: Callable in _predicates:
			if not predicate.call(value):
				return false
		return true


class _FlatMapped:
	extends HegelGenerator
	var _source: HegelGenerator
	var _f: Callable

	func _init(source: HegelGenerator, f: Callable) -> void:
		label = HegelGenerators._combined("flat_map", [source.label])
		_source = source
		_f = f

	func _draw(tc: HegelTestCase) -> Variant:
		var next: Variant = _f.call(tc.draw(_source))
		if next is HegelGenerator:
			return tc.draw(next)
		tc._fail_run(
			HegelResult.ErrorKind.USAGE,
			"flat_map's function returned %s, not a HegelGenerator" % [next]
		)
		return null


class _Composite:
	extends HegelGenerator
	var _fn: Callable

	func _init(fn: Callable) -> void:
		label = HegelGenerators._combined(
			"composite", [HegelNative.label_from_name(fn.get_method())]
		)
		_fn = fn

	func _draw(tc: HegelTestCase) -> Variant:
		return _fn.call(tc)


## Stands in for a generator built with invalid arguments: drawing from it
## ends the run with a usage error.
class _Invalid:
	extends HegelGenerator
	var _message: String

	func _init(message: String) -> void:
		_message = message

	func _draw(tc: HegelTestCase) -> Variant:
		tc._fail_run(HegelResult.ErrorKind.USAGE, _message)
		return null
