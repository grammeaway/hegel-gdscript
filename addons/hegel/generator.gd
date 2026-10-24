class_name HegelGenerator
extends RefCounted
## A source of values for [method HegelTestCase.draw]. Build one with the
## factories on [HegelGenerators], and derive others with [method map],
## [method filter] and [method flat_map].

## Identifies this generator's spans to the shrinker. Set once, when the
## generator is built.
var label: int


## A generator of [code]f.call(value)[/code] for each value this one draws.
## The shrinker works on the drawn value, so the result shrinks towards
## [param f] of this generator's simplest value:
## [codeblock]
## var evens := Gs.integers().map(func(n: int) -> int: return n * 2)
## [/codeblock]
func map(f: Callable) -> HegelGenerator:
	if not f.is_valid():
		return HegelGenerators._Invalid.new("map needs a valid Callable")
	return HegelGenerators._Mapped.new(self, f)


## The values of this generator that satisfy [param predicate]. Each draw
## tries up to three values; when none satisfies it, the test case is
## rejected, as by [method HegelTestCase.assume]. A predicate that rejects
## most values rejects many cases and can fail a health check, so prefer
## generating the values directly: [code]Gs.integers(0)[/code] over
## [code]Gs.integers().filter(func(n: int) -> bool: return n >= 0)[/code].
## Chained filters merge into one.
func filter(predicate: Callable) -> HegelGenerator:
	if not predicate.is_valid():
		return HegelGenerators._Invalid.new("filter needs a valid Callable")
	return HegelGenerators._Filtered.new(self, predicate)


## Draws a value, then draws from the generator [param f] returns for it, for
## a value whose shape depends on another. [param f] returning anything but a
## [HegelGenerator] is a usage error. [method HegelGenerators.composite] often
## reads better:
## [codeblock]
## var sized := Gs.integers(1, 10).flat_map(
##     func(n: int) -> HegelGenerator: return Gs.integers(0, n)
## )
## [/codeblock]
func flat_map(f: Callable) -> HegelGenerator:
	if not f.is_valid():
		return HegelGenerators._Invalid.new("flat_map needs a valid Callable")
	return HegelGenerators._FlatMapped.new(self, f)


## Draws one value from [param tc]. Subclasses override it; tests call
## [method HegelTestCase.draw] instead.
func _draw(tc: HegelTestCase) -> Variant:
	tc._fail_run(HegelResult.ErrorKind.USAGE, "a HegelGenerator subclass does not override _draw")
	return null
