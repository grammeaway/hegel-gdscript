# hegel-gdscript guide

This guide covers writing properties, the generators, reading failures, runtime errors, state machines, recipes for Godot types, running the tests, and the limitations. Every public class is also documented in the editor's help.

Every example assumes the generator factories are aliased at the top of the script:

```gdscript
const Gs := preload("res://addons/hegel/generators.gd")
```

With that line added, every example runs as it is, under gdUnit4 or the plain runner (see [Running the tests](#running-the-tests)); the addon's test suite runs each one.

## Writing properties

`Hegel.run(body)` calls `body` once per test case, each time with a fresh `HegelTestCase`, `tc`. The body draws its inputs from generators with `tc.draw`, and fails the case with `tc.check`:

```gdscript
func test_sorting_puts_the_smallest_first() -> void:
	Hegel.run(func(tc: HegelTestCase) -> void:
		var xs: Array = tc.draw(Gs.lists(Gs.integers(), 1), "xs")
		var sorted := xs.duplicate()
		sorted.sort()
		if not tc.check(sorted[0] == xs.min(), "the smallest comes first"):
			return
		tc.note("sorted: %s" % [sorted])
		tc.check(sorted.size() == xs.size(), "sorting keeps every element")
	)
```

- `tc.draw(generator, name)` returns a value. The name is what the failure report calls it; unnamed draws are `draw_1`, `draw_2`, ….
- `tc.check(condition, message)` fails the case when `condition` is false, and returns `condition`. GDScript has no exceptions to stop the body, so return when it gives false: `if not tc.check(...): return`.
- `tc.assume(condition)` rejects the case when `condition` is false: it is neither a pass nor a failure, and the engine tries another. Return when it gives false, as for `check`.
- `tc.note(message)` adds a line to the failure report.

A case ends at its first failed `check`, failed `assume` or runtime error. From then on, `tc.draw` returns each generator's simplest value (0, `false`, `""`, the shortest list) without generating anything, so a body that carries on past the end runs on harmless values. Only the first event counts.

`Hegel.run` returns a `HegelResult`: `passed`, the `failures`, an `error` if the run itself went wrong, and the `report`. A run with settings other than the defaults takes a `HegelSettings`, and the body can be a method:

```gdscript
func test_with_more_cases() -> void:
	var settings := HegelSettings.new()
	settings.test_cases = 1000
	Hegel.run(_doubling_is_even, settings)


func _doubling_is_even(tc: HegelTestCase) -> void:
	var x: int = tc.draw(Gs.integers(-1000, 1000))
	tc.check((x * 2) % 2 == 0, "x * 2 is even")
```

`HegelSettings.new()` starts from the engine's profile (see [Failures](#failures)), so it has every field set; change what you need. The fields are `test_cases`, `seed` with `has_seed`, `derandomize`, `report_multiple_failures`, `database`, `verbosity` and `suppress_health_checks`.

## Generators

The factories are static functions on `HegelGenerators`, aliased as `Gs`. Each returns a `HegelGenerator`.

| Factory | Draws | Shrinks towards |
|---|---|---|
| `integers(min_value, max_value)` | `int`s in the closed range; both bounds optional | 0, or the bound nearest it |
| `floats(min_value, max_value, allow_nan, allow_infinity, exclude_min, exclude_max)` | `float`s; NaN only without bounds, infinities only at an open end | 0.0, then integers before fractions |
| `booleans()` | `true` or `false` | `false` |
| `just(value)` | always `value`, the same object each time | |
| `sampled_from(elements)` | one of the Array's elements | the first |
| `one_of(a, b, ...)` | a value from one of the generators | the earlier generators |
| `lists(elements, min_size, max_size, unique)` | Arrays; `max_size` -1 is no bound; `unique` compares as Dictionary keys | fewer, simpler elements |
| `tuples(a, b, ...)` | a fixed-length Array, one value from each generator | each element |
| `dictionaries(keys, values, min_size, max_size)` | Dictionaries; `max_size` -1 is no bound | fewer, simpler entries |
| `text(min_size, max_size, min_codepoint, max_codepoint)` | Strings; `max_size` -1 means 100; never U+0000 | shorter strings of `"0"` |
| `composite(fn)` | whatever `fn.call(tc)` returns; `fn` draws from `tc` | each draw it makes |

Every generator also has:

- `map(f)`: `f` of each value. It shrinks as the source does.
- `filter(predicate)`: only the values `predicate` accepts. Each draw tries three values before rejecting the case, so a predicate that rejects most values fails a health check. Generate the values directly where you can.
- `flat_map(f)`: draws a value, then draws from the generator `f` returns for it.

`composite` builds a value from several draws, where later draws can depend on earlier ones:

```gdscript
static func _range(tc: HegelTestCase) -> Array:
	var low: int = tc.draw(Gs.integers(-100, 100))
	var high: int = tc.draw(Gs.integers(low, 100))
	return [low, high]


func test_range_counts_from_low_to_high() -> void:
	Hegel.run(func(tc: HegelTestCase) -> void:
		var bounds: Array = tc.draw(Gs.composite(_range), "bounds")
		var values := range(bounds[0], bounds[1] + 1)
		tc.check(values.size() == bounds[1] - bounds[0] + 1, "one value per step")
	)
```

Invalid arguments, such as `Gs.integers(10, 0)` or `Gs.sampled_from([])`, don't fail where the generator is built. Drawing from it ends the run with a usage error that says what is wrong, in `result.error`.

## Failures

When a case fails, the engine shrinks it to the smallest failing case it can find, then reruns it to build the report:

```text
--- Failure: res://tests/grid_test.gd::test_rows_fit_every_item ---
Falsified after 2 test cases (0 discarded):

  var count = 1
  var columns = 2

Check failed: the rows fit every item (res://tests/grid_test.gd:10)
Reproduce with: Hegel.replay("AAIAAAAACgEAAAABAAoBAAAAAg==", <body>)
```

The header names the script and function that called `Hegel.run`. Then come the draws and notes of the shrunk case, in order, what failed and where, and the blob that replays it. `Hegel.run` prints the report to stderr and pushes a one-line error; the report is also in `result.report`.

To debug a failure, replay its blob with the same body. A replay runs only that case, and reports it again:

```gdscript fails
func test_replaying_a_failure() -> void:
	Hegel.replay("AAIAAAAACgEAAAABAAoBAAAAAg==", func(tc: HegelTestCase) -> void:
		var count: int = tc.draw(Gs.integers(0, 1000), "count")
		var columns: int = tc.draw(Gs.integers(1, 20), "columns")
		@warning_ignore("integer_division")
		tc.check(count / columns * columns >= count, "the rows fit every item")
	)
```

Once the bug is fixed, the replay returns a `DID_NOT_REPRODUCE` error, a reminder to remove it.

**The database.** Failures are saved under `user://hegel/`, keyed by the calling script and function, and replayed first on the next run, so a failure keeps failing until it is fixed. `settings.database` changes the directory; `""` turns it off.

**Settings from the environment.** A new `HegelSettings` starts from the engine's settings profile:

- `development` locally: 100 test cases, a fresh seed each run, the database on.
- `ci` when it detects a CI server (`CI`, `GITHUB_ACTIONS` and the like): derandomized, so every run is the same, with the database off and the `TOO_SLOW` health check suppressed.

`HEGEL_TEST_CASES`, `HEGEL_SEED`, `HEGEL_DERANDOMIZE` and `HEGEL_DATABASE` (a path, or `disabled`) apply over the profile, and a field you set in code wins over all of them. Profiles can also be configured in a `hegel.toml` in the working directory or above it; see Hegel's documentation.

**Several failures.** By default the engine reports only the smallest failure it found. With `settings.report_multiple_failures = true` it reports one per distinct origin: each failed `check` line and each error location is a different bug.

## Runtime errors

A runtime error in the body, or in code it calls, fails the case like a failed `check`: a script error (calling a method on `null`, an index out of range, a missing Dictionary key), a `push_error`, or an error the engine raises (`get_node` on a missing path). Warnings don't. The error is caught from the body's thread, and from threads it starts.

```gdscript fails
const PRICES := {"sword": 10, "shield": 8}


func test_every_item_has_a_price() -> void:
	Hegel.run(func(tc: HegelTestCase) -> void:
		var item: String = tc.draw(Gs.sampled_from(["sword", "shield", "potion"]), "item")
		tc.check(PRICES[item] > 0, "a positive price")
	)
```

The report gives the error's message, where it happened, and the frames down to the body:

```text
  var item = "potion"

Script error: Invalid access to property or key 'potion' on a base object of type 'Dictionary'. (res://tests/shop_test.gd:10)
  at <anonymous lambda> (res://tests/shop_test.gd:10)
```

Failures are grouped by location, not message, since a message carries values: the same line failing with two different values is one bug.

Godot prints every error to stderr as it happens, so a failure caused by an error shows it once per time the engine reran the case while shrinking. That is noise, not more failures. It can't be muted while the addon still sees the errors.

Prefer `tc.check` over `assert()`: a failed `check` names its message in the report, and `assert()` does nothing outside debug builds.

## Determinism

Take every random choice from `tc`, never from `randi()`, `randf()` or an unseeded `RandomNumberGenerator`. The engine replays and shrinks a case by replaying its draws; randomness it doesn't control makes a failure flaky, and the shrunk case may not fail. When the code under test takes a `RandomNumberGenerator`, draw a seeded one (see [Recipes](#recipes)).

The same goes for time, frame counts, and anything else that changes between reruns of the same case.

## State machines

To test something with state, extend `HegelStateMachine`. The state lives in member variables; each method named `rule_<name>` is a step the engine may run, and each `invariant_<name>` is checked along the way. Each takes the test case and draws what it needs. This one has a bug, `damage` lets health go below 0:

```gdscript fails
class Health:
	extends HegelStateMachine
	const MAX := 100
	var health := MAX

	func rule_damage(tc: HegelTestCase) -> void:
		health -= tc.draw(Gs.integers(0, 150), "amount")

	func rule_heal(tc: HegelTestCase) -> void:
		health = mini(health + tc.draw(Gs.integers(0, 150), "amount"), MAX)

	func invariant_in_range(tc: HegelTestCase) -> void:
		tc.check(health >= 0 and health <= MAX, "0 <= health <= MAX")


func test_health_stays_in_range() -> void:
	Hegel.run(func(tc: HegelTestCase) -> void: Health.new().run(tc))
```

`run(tc, steps)` checks the invariants on the initial state, runs up to `steps` rules (50 by default) that the engine chooses, then checks the invariants on the final state. A failure is shrunk to a short sequence of steps, and the report lists them:

```text
  Checking invariants on the initial state.
  Step 1: damage {
    var amount = 101
  }
  Invariant in_range failed:
```

- Make a fresh machine for each test case, inside the body.
- A rule whose `assume` fails is skipped, and the engine tries another; it doesn't count towards `steps`. Reject before changing the state.
- There's no teardown: clean up after `run` returns (free the nodes the machine made, say).
- The rules are methods rather than lambdas because GDScript lambdas capture local variables by value: a lambda rule that did `count += 1` would change its own copy.

## Recipes

Godot's types are built from the factories with `map`:

```gdscript
static func vector2s(limit := 1000.0) -> HegelGenerator:
	return Gs.tuples(Gs.floats(-limit, limit), Gs.floats(-limit, limit)).map(
		func(xy: Array) -> Vector2: return Vector2(xy[0], xy[1])
	)


static func vector2is(limit := 1000) -> HegelGenerator:
	return Gs.tuples(Gs.integers(-limit, limit), Gs.integers(-limit, limit)).map(
		func(xy: Array) -> Vector2i: return Vector2i(xy[0], xy[1])
	)


static func colors() -> HegelGenerator:
	var channel := Gs.floats(0.0, 1.0)
	return Gs.tuples(channel, channel, channel, channel).map(
		func(rgba: Array) -> Color: return Color(rgba[0], rgba[1], rgba[2], rgba[3])
	)


static func rect2s() -> HegelGenerator:
	return Gs.tuples(vector2s(), vector2s().map(func(v: Vector2) -> Vector2: return v.abs())).map(
		func(parts: Array) -> Rect2: return Rect2(parts[0], parts[1])
	)


static func packed_int32s() -> HegelGenerator:
	return Gs.lists(Gs.integers(-2147483648, 2147483647)).map(
		func(xs: Array) -> PackedInt32Array: return PackedInt32Array(xs)
	)


static func rngs() -> HegelGenerator:
	return Gs.integers().map(
		func(rng_seed: int) -> RandomNumberGenerator:
			var rng := RandomNumberGenerator.new()
			rng.seed = rng_seed
			return rng
	)


func test_a_grown_rect_encloses_the_original() -> void:
	Hegel.run(func(tc: HegelTestCase) -> void:
		var rect: Rect2 = tc.draw(rect2s(), "rect")
		tc.check(rect.grow(1.0).encloses(rect), "a grown rect encloses the original")
	)


func test_a_seeded_rng_repeats_itself() -> void:
	Hegel.run(func(tc: HegelTestCase) -> void:
		var rng: RandomNumberGenerator = tc.draw(rngs(), "rng")
		var copy := RandomNumberGenerator.new()
		copy.seed = rng.seed
		tc.check(rng.randi() == copy.randi())
	)
```

A save round trip is a classic property: whatever is saved loads back the same. This one fails, and not because of the save code:

```gdscript fails
static func save(items: Dictionary) -> String:
	return JSON.stringify(items)


static func load_save(text: String) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(text)
	var items := {}
	for item: String in parsed:
		# JSON reads every number back as a float.
		items[item] = int(parsed[item])
	return items


func test_a_save_loads_back_unchanged() -> void:
	Hegel.run(func(tc: HegelTestCase) -> void:
		var counts := Gs.integers(0, 999)
		var items: Dictionary = tc.draw(Gs.dictionaries(Gs.text(1, 20), counts), "items")
		tc.check(load_save(save(items)) == items, "the save loads back unchanged")
	)
```

```text
  var items = {
  "": 0
  }

Error: Parse JSON failed. Error at line 0: Invalid escape sequence (res://tests/save_test.gd:9)
  at load_save (res://tests/save_test.gd:9)
  at <anonymous lambda> (res://tests/save_test.gd:21)
```

The key that looks empty is a single vertical tab, U+000B. `JSON.stringify` writes it as `\v`, an escape JSON doesn't have, and `JSON.parse` rejects it ([godotengine/godot#109482](https://github.com/godotengine/godot/issues/109482); reproduced in Godot 4.7.2). A save in this format fails to load whenever one of its strings holds that character.

## Running the tests

**gdUnit4.** Call `Hegel.run` in a test and assert on the result. gdUnit4 doesn't fail a test on `push_error` unless its `gdunit4/settings/report/godot/push_error` setting is on, so without the assert a failing property only prints its report:

```gdscript
extends GdUnitTestSuite


func test_abs_is_never_negative() -> void:
	var result := Hegel.run(func(tc: HegelTestCase) -> void:
		var x: int = tc.draw(Gs.integers(-1000, 1000))
		tc.check(absi(x) >= 0)
	)
	assert_bool(result.passed).override_failure_message(result.report).is_true()
```

With `override_failure_message(result.report)`, the report shows in gdUnit4's failure message. gdUnit4 watches script errors itself, so a property failing on a script error also gets one gdUnit4 error per rerun while shrinking. [`examples/gdunit4/`](../examples/gdunit4/) has a complete suite.

**The plain runner.** Without a test framework, `addons/hegel/cli/run.gd` runs every `test_*` method in the scripts under the paths it is given, each on a new instance of its script:

```sh
godot --headless --path . -s res://addons/hegel/cli/run.gd -- res://tests/properties/
```

A test fails when it logs an error outside a property body: a failing `Hegel.run` pushes one, and so does a script error in the test itself. The runner prints `PASS` or `FAIL` for each test and a summary, and exits with 1 if any test failed. [`examples/plain/`](../examples/plain/) has an example.

**CI.** Import the project before the tests, since the import registers the addon's classes. With any GDExtension, a first, cold `godot --headless --import` can crash on exit after finishing the import ([godotengine/godot#111048](https://github.com/godotengine/godot/issues/111048)); run it again if it fails, and the second run must succeed. On CI the engine uses the `ci` profile, so runs are derandomized.

## Limitations

- **Synchronous bodies.** A body that `await`s returns to Hegel at its first `await`, and the rest of it runs after its test case is over. Test async code by driving it step by step.
- **One run per thread at a time.** `Hegel.run` inside another run's body is a usage error; draw what the inner run needs in the outer body. Runs on several threads at once see each other's runtime errors.
- **The debugger.** With a debugger attached, Godot breaks at every script error in a body, and the engine reruns a failing case several times while shrinking it. Continue past each break, and the run reports the failure as usual; or turn on **Ignore Error Breaks** in the editor's Debugger panel, and the run doesn't stop at all. A failed `check` and `push_error` don't break.
- **Float literals.** Godot parses some float literals loosely: `5e-324` reads as 0.0, some 17-digit literals land one ulp off, and `-0.0` in an Array literal becomes 0.0. A bound written that way is the value Godot parsed.
- **Text.** `text()` never draws U+0000, which a Godot String can't hold.
- **Reports.** A drawn Dictionary is shown over several lines.
