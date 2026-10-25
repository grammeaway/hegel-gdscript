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


## Arrays of values from [param elements], with [param min_size] to
## [param max_size] of them; -1 is no upper bound, and the engine keeps sizes
## modest. They shrink towards fewer elements, each shrinking as
## [param elements] does.
## [br][br]
## With [param unique], no two elements are equal as [Dictionary] keys: so
## [code]1[/code], [code]1.0[/code] and [code]true[/code] are distinct, and a
## duplicate is discarded and another drawn. Negative sizes, a
## [param max_size] below [param min_size], or a unique [param min_size] above
## the distinct values [param elements] is known to have, are a usage error.
static func lists(
	elements: HegelGenerator, min_size := 0, max_size := -1, unique := false
) -> HegelGenerator:
	var invalid := _check_collection("lists", "elements", elements, min_size, max_size, unique)
	return invalid if invalid else _Lists.new(elements, min_size, max_size, unique)


## Fixed-length Arrays with one value from each of [param generators], in
## order: [code]Gs.tuples(Gs.integers(), Gs.text())[/code] draws pairs like
## [code][0, ""][/code]. With no generators it draws only [code][][/code]. An
## argument that isn't a [HegelGenerator] is a usage error.
static func tuples(...generators: Array) -> HegelGenerator:
	var parts: Array[HegelGenerator] = []
	for i: int in generators.size():
		if not generators[i] is HegelGenerator:
			return _Invalid.new(
				"tuples takes HegelGenerators, but argument %d is %s" % [i + 1, generators[i]]
			)
		parts.append(generators[i])
	return _Tuples.new(parts)


## Dictionaries with keys from [param keys] and values from [param values],
## with [param min_size] to [param max_size] entries; -1 is no upper bound. A
## duplicate key is discarded and another drawn. Sizes are validated as for
## [method lists], with the keys unique.
static func dictionaries(
	keys: HegelGenerator, values: HegelGenerator, min_size := 0, max_size := -1
) -> HegelGenerator:
	if values == null:
		return _Invalid.new("dictionaries needs a generator of values")
	var invalid := _check_collection("dictionaries", "keys", keys, min_size, max_size, true)
	return invalid if invalid else _Dictionaries.new(keys, values, min_size, max_size)


## Strings of [param min_size] to [param max_size] characters, drawn from the
## codepoints [code][min_codepoint, max_codepoint][/code], surrogates excluded.
## [param max_size] -1 means 100, or [code]min_size + 100[/code] when
## [param min_size] is larger. They shrink towards shorter strings, and
## towards [code]"0"[/code] for each character.
## [br][br]
## U+0000 is never drawn, since a Godot [String] can't hold it: a
## [param min_codepoint] of 0 means 1, and a [param max_codepoint] below 1 is
## a usage error, as are negative sizes, a [param max_size] below
## [param min_size], and codepoints outside [code][0, 0x10FFFF][/code] or out of
## order.
static func text(
	min_size := 0, max_size := -1, min_codepoint := 1, max_codepoint := 0x10FFFF
) -> HegelGenerator:
	var invalid := _check_sizes("text", min_size, max_size)
	if invalid:
		return invalid
	if max_size == -1:
		max_size = min_size + 100 if min_size > 100 else 100
	if min_codepoint < 0 or max_codepoint > 0x10FFFF or min_codepoint > max_codepoint:
		return _Invalid.new(
			(
				"text needs 0 <= min_codepoint <= max_codepoint <= 0x10FFFF, got %d and %d"
				% [min_codepoint, max_codepoint]
			)
		)
	if max_codepoint < 1:
		return _Invalid.new("text can't draw U+0000, which a Godot String can't hold")
	min_codepoint = maxi(min_codepoint, 1)
	var native := HegelNativeStringGenerator.new()
	if native.text(min_size, max_size, min_codepoint, max_codepoint) != HegelNative.OK:
		return _Invalid.new(native.last_error)
	# The engine's simplest character: "0" when it's in range, else the nearest bound.
	# shortcut: a min_codepoint among the surrogates gives one here, where the engine
	# skips them; fix it if anyone bounds text there.
	return _Text.new(native, char(clampi(0x30, min_codepoint, max_codepoint)).repeat(min_size))


## Strings of [param min_size] to [param max_size] characters, each one of
## [param alphabet]'s: [code]Gs.text_from("=[]\";#")[/code] draws strings
## of config syntax. [param max_size] -1 means 100, or
## [code]min_size + 100[/code] when [param min_size] is larger. They shrink as
## [method text]'s do: towards shorter strings, and for each character towards
## the alphabet's lowest at or above [code]"0"[/code], else its highest.
## [br][br]
## An empty [param alphabet] draws only [code]""[/code], and is a usage error
## with a positive [param min_size], as are negative sizes and a
## [param max_size] below [param min_size].
static func text_from(alphabet: String, min_size := 0, max_size := -1) -> HegelGenerator:
	var invalid := _check_sizes("text_from", min_size, max_size)
	if invalid:
		return invalid
	if max_size == -1:
		max_size = min_size + 100 if min_size > 100 else 100
	# The engine rejects an empty alphabet unless max_size is 0; Python's text spells "" from it.
	if alphabet.is_empty() and min_size == 0:
		max_size = 0
	var native := HegelNativeStringGenerator.new()
	if native.text_from(alphabet, min_size, max_size) != HegelNative.OK:
		return _Invalid.new(native.last_error)
	if alphabet.is_empty():
		return _Text.new(native, "")
	# The engine's simplest character: the lowest at or above "0", else the highest.
	var simplest := -1
	for i: int in alphabet.length():
		var c := alphabet.unicode_at(i)
		if simplest < 0x30:
			simplest = maxi(simplest, c)
		elif c >= 0x30:
			simplest = mini(simplest, c)
	return _Text.new(native, char(simplest).repeat(min_size))


## A usage error for a collection's arguments, or null when they are valid.
static func _check_collection(
	factory: String,
	what: String,
	elements: HegelGenerator,
	min_size: int,
	max_size: int,
	unique: bool
) -> _Invalid:
	if elements == null:
		return _Invalid.new("%s needs a generator of %s" % [factory, what])
	var invalid := _check_sizes(factory, min_size, max_size)
	if invalid:
		return invalid
	var distinct := _distinct_values(elements)
	if unique and distinct >= 0 and distinct < min_size:
		return _Invalid.new(
			(
				"%s can't draw %d unique %s from a generator with only %d distinct value%s"
				% [factory, min_size, what, distinct, "" if distinct == 1 else "s"]
			)
		)
	return null


## The engine checks [code]max_size < min_size[/code] itself, but can't see
## negative sizes, which the native layer takes as unsigned.
static func _check_sizes(factory: String, min_size: int, max_size: int) -> _Invalid:
	if min_size < 0:
		return _Invalid.new("%s needs min_size >= 0, got %d" % [factory, min_size])
	if max_size < -1:
		return _Invalid.new(
			"%s needs max_size >= 0, or -1 for no bound, got %d" % [factory, max_size]
		)
	return null


## How many distinct values [param generator] can draw, when its definition
## says; -1 when it doesn't.
static func _distinct_values(generator: HegelGenerator) -> int:
	if generator is _Just:
		return 1
	if generator is _Booleans:
		return 2
	if generator is _SampledFrom:
		var seen := {}
		for element: Variant in (generator as _SampledFrom)._elements:
			seen[element] = true
		return seen.size()
	if generator is _Integers:
		var integers := generator as _Integers
		# A range too wide for an int wraps to <= 0, as does an empty one the engine reports.
		var count := integers._max - integers._min + 1
		return count if count > 0 else -1
	return -1


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


class _Lists:
	extends HegelGenerator
	var _elements: HegelGenerator
	var _min_size: int
	var _max_size: int
	var _unique: bool

	func _init(elements: HegelGenerator, min_size: int, max_size: int, unique: bool) -> void:
		label = HegelGenerators._combined("lists", [elements.label])
		_elements = elements
		_min_size = min_size
		_max_size = max_size
		_unique = unique

	func _draw(tc: HegelTestCase) -> Variant:
		var collection := tc._collection(_min_size, _max_size)
		var result := []
		var seen := {}
		while collection.more():
			var element: Variant = tc.draw(_elements)
			if _unique:
				if seen.has(element):
					collection.reject()
					continue
				seen[element] = true
			result.append(element)
		return result


class _Tuples:
	extends HegelGenerator
	var _parts: Array[HegelGenerator]

	func _init(parts: Array[HegelGenerator]) -> void:
		var labels: Array[int] = []
		for part: HegelGenerator in parts:
			labels.append(part.label)
		label = HegelGenerators._combined("tuples", labels)
		_parts = parts

	func _draw(tc: HegelTestCase) -> Variant:
		var result := []
		for part: HegelGenerator in _parts:
			result.append(tc.draw(part))
		return result


class _Dictionaries:
	extends HegelGenerator
	var _keys: HegelGenerator
	var _values: HegelGenerator
	var _min_size: int
	var _max_size: int

	func _init(keys: HegelGenerator, values: HegelGenerator, min_size: int, max_size: int) -> void:
		label = HegelGenerators._combined("dictionaries", [keys.label, values.label])
		_keys = keys
		_values = values
		_min_size = min_size
		_max_size = max_size

	func _draw(tc: HegelTestCase) -> Variant:
		var collection := tc._collection(_min_size, _max_size)
		var result := {}
		while collection.more():
			var key: Variant = tc.draw(_keys)
			if result.has(key):
				collection.reject()
				continue
			result[key] = tc.draw(_values)
		return result


class _Text:
	extends HegelGenerator
	var _native: HegelNativeStringGenerator
	var _simplest: String

	func _init(native: HegelNativeStringGenerator, simplest: String) -> void:
		label = HegelTestCase._label("text")
		_native = native
		_simplest = simplest

	func _draw(tc: HegelTestCase) -> Variant:
		return tc._draw_string(_native, _simplest)


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
