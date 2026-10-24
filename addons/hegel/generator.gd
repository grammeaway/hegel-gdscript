class_name HegelGenerator
extends RefCounted
## A source of values for [method HegelTestCase.draw]. Build one with the
## factories on [HegelGenerators].

## Identifies this generator's spans to the shrinker. Set once, when the
## generator is built.
var label: int


## Draws one value from [param tc]. Subclasses override it; tests call
## [method HegelTestCase.draw] instead.
func _draw(tc: HegelTestCase) -> Variant:
	tc._fail_run(HegelResult.ErrorKind.USAGE, "a HegelGenerator subclass does not override _draw")
	return null
