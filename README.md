# hegel-gdscript

[![ci](https://github.com/grammeaway/hegel-gdscript/actions/workflows/ci.yml/badge.svg)](https://github.com/grammeaway/hegel-gdscript/actions/workflows/ci.yml)

Property-based testing for GDScript. You write a property, a statement that should hold for every input, and hegel-gdscript generates inputs to try to break it. When one does, it shrinks the input to a minimal counterexample and prints a report you can replay.

It is built on [Hegel](https://hegel.dev), the property-based testing engine based on [Hypothesis](https://github.com/hypothesisworks/hypothesis). Hegel's engine does the generating, shrinking and bookkeeping; this addon is a thin GDScript frontend over it. It is a community frontend, not part of the Hegel project.

**Status: beta.** The API may still change, and it follows Hegel's 0.x releases. It needs Godot 4.5 or newer, on Linux (x86_64), Windows (x86_64) or macOS (arm64).

## A first property

```gdscript fails
func test_rows_fit_every_item() -> void:
	Hegel.run(func(tc: HegelTestCase) -> void:
		var count: int = tc.draw(Gs.integers(0, 1000), "count")
		var columns: int = tc.draw(Gs.integers(1, 20), "columns")
		@warning_ignore("integer_division")
		var rows := count / columns
		tc.check(rows * columns >= count, "the rows fit every item")
	)
```

`Gs` is the generator factories, `const Gs := preload("res://addons/hegel/generators.gd")`. The integer division rounds down, so the property fails, and Hegel shrinks it to the smallest case:

```text
--- Failure: res://tests/grid_test.gd::test_rows_fit_every_item ---
Falsified after 2 test cases (0 discarded):

  var count = 1
  var columns = 2

Check failed: the rows fit every item (res://tests/grid_test.gd:10)
Reproduce with: Hegel.replay("AAIAAAAACgEAAAABAAoBAAAAAg==", <body>)
```

Runtime errors count as failures too: a script error or a `push_error` in the code under test fails the case, and is shrunk the same way. Stateful code gets state machines: rules the engine runs in sequence, with invariants checked along the way.

## Install

1. Download `hegel-gdscript-<version>.zip` from the [releases](https://github.com/grammeaway/hegel-gdscript/releases) and unzip it into your project, so that you have `addons/hegel/` (the zip holds nothing else). Or build it from source (below).
2. Restart the editor, or run `godot --headless --import` once, so Godot registers the classes.
3. Keep the addon out of your game: in each export preset, under **Resources**, add `addons/hegel/*` to **Filters to exclude files/folders**. It is a test-only addon, and it has no libraries for web or mobile.

The addon needs no plugin to be enabled.

## Running properties

`Hegel.run` works anywhere: in a [gdUnit4](https://github.com/MikeSchulze/gdUnit4) suite, any other framework, or a plain script. In gdUnit4, assert on the result, since gdUnit4 doesn't fail a test on `push_error` by default:

```gdscript
extends GdUnitTestSuite


func test_reversing_twice_gives_the_original() -> void:
	var result := Hegel.run(func(tc: HegelTestCase) -> void:
		var xs: Array = tc.draw(Gs.lists(Gs.integers()))
		var twice := xs.duplicate()
		twice.reverse()
		twice.reverse()
		tc.check(twice == xs, "reversed twice")
	)
	assert_bool(result.passed).override_failure_message(result.report).is_true()
```

Without a framework, the addon's runner calls every `test_*` method in the scripts it is given, and exits with 1 if any failed:

```sh
godot --headless --path . -s res://addons/hegel/cli/run.gd -- res://tests/properties/
```

## Learn more

- [The guide](docs/guide.md): generators, failures and replay, runtime errors, state machines, recipes for Godot types, and the limitations.
- [`examples/`](examples/): a gdUnit4 suite and a plain-runner script, each finding the bugs in a small inventory script.
- The editor's help: every public class (`Hegel`, `HegelTestCase`, `HegelGenerators`, …) is documented.

## Building from source

Building needs Rust (through rustup), [`just`](https://github.com/casey/just), [`uv`](https://docs.astral.sh/uv/) and Godot 4.7. `just build` builds the native library into `addons/hegel/bin/`, and `just check` runs the lints and the test suite. See [CONTRIBUTING.md](CONTRIBUTING.md).

CI builds and tests every push on Linux, Windows and macOS, and on Godot 4.5, the oldest supported version. Releases are built by CI from a version tag: it packages the three libraries, checks that the zip runs a property in a fresh project on each platform, and publishes it.

## License

MIT. See [LICENSE](LICENSE). Hegel is MIT licensed too.
