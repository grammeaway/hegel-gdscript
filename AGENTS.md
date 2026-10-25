# hegel-gdscript

A property-based testing addon for GDScript, built on [Hegel](https://hegel.dev)'s engine, libhegel. Pre-release: work is planned in `docs/sagas/`, and progress, decisions and findings are logged in each saga's `progress.md`.

This file is the single source of truth for commands, layout and architecture. Update it in the same change whenever one of these moves.

## Commands

Run everything through `just`. Godot 4.7.2 is `godot` on PATH; set `GODOT` to use another binary.

- `just build`: `cargo build --release`, then copy the library into `addons/hegel/bin/` under its platform name. Always the release profile: a debug build is 150 MB.
- `just import`: the headless Godot import. Run it on a fresh checkout and after adding or renaming a `class_name`, or tests can't see the class.
- `just test`: every gdUnit4 suite under `tests/`, headless. Exit 0 is green. The two `Remote Debugger` errors at the start are expected: `runtest.sh` points the debugger at port 0 on purpose.
- `just lint`: `cargo fmt --check`, `cargo clippy -- -D warnings`, and `gdlint` (gdtoolkit through `uvx`) over `addons/hegel`, `tests` and `examples`.
- `just check`: lint, build, import, test. It passes at the end of every change.
- `just package [version]`: zip `addons/hegel/`, with whatever libraries `bin/` holds plus `LICENSE`, `README.md` and `CHANGELOG.md`, into `dist/hegel-gdscript-<version>.zip`. The version defaults to `rust/Cargo.toml`'s.
- `just smoke-package [zip]`: unzip a package into a fresh project under `dist/smoke/`, import it, and run `tests/package/smoke.gd` through the plain runner.

The Rust toolchain is pinned in `rust-toolchain.toml`.

## CI and releases

- `.github/workflows/ci.yml`, on every push and pull request: `lint`; `test` on ubuntu-latest, windows-latest and macos-15 (build, import, test, then package and smoke-test); `floor`, the suite on Godot 4.5.2, the `compatibility_minimum`.
- `.github/workflows/release.yml`, on a `v*` tag: builds the three libraries (the dylib signed ad hoc), packages them, smoke-tests the zip on all three platforms, and publishes a GitHub release with it. Its notes are CHANGELOG.md's section for the version; a pre-release tag (`v0.1.0-rc.1`) takes `Unreleased` and is marked a pre-release.
- To release: move `Unreleased` to `## [<version>] - <date>` in CHANGELOG.md, set the version in `rust/Cargo.toml`, commit, then tag `v<version>` and push the tag.
- Shared setup lives in `.github/actions/`: `setup-rust`, `setup-just` and `setup-godot`. Actions are pinned to commit SHAs with a version comment; downloaded tools (just, Godot) are pinned and checked against their release checksums. Each action's description says how to bump it.

## Layout

```
project.godot        dev project for tests and examples; not shipped
addons/hegel/        the shipped addon
  hegel.gdextension  one library per platform, under debug and release keys
  bin/               built libraries (gitignored)
  cli/run.gd         the plain headless runner, for projects without a test framework
addons/gdUnit4/      vendored test framework, dev-only
rust/                the gdext crate over libhegel (`hegeltest-c`, linked statically)
tests/               gdUnit4 suites, mirroring addons/hegel/; tests/native/ drives the native classes
  cli/fixtures/      scripts the plain runner's tests run it on
  subjects/          one-scenario SceneTree scripts, run in a fresh process by report_snapshot_test.gd
  support/           helpers; error_scenarios.gd holds error_capture_test.gd's scenarios
  approvals/         each subject's approved, scrubbed output
  package/smoke.gd   the property `just smoke-package` runs
examples/            a gdUnit4 suite and a plain-runner script, each failing on purpose
.github/             CI and release workflows, and their shared setup actions
dist/                `just package` output (gitignored)
docs/guide.md        the user guide; README.md is the front door
docs/sagas/          plans and their progress logs
```

## Architecture

**The native layer is thin.** `rust/src/` exposes one `RefCounted` class per libhegel handle (`HegelNativeSettings`, `HegelNativeRun`, `HegelNativeTestCase`, `HegelNativeRunResult`, `HegelNativeCollection`, `HegelNativeStringGenerator`, `HegelNativeStateMachine`), plus `HegelNative` for result codes, labels and the version. Native classes are internal and undocumented for users.

- Each `#[func]` makes one `hegel_*` call, or a fixed sequence that frees a handle. It converts arguments and stores the result code in `last_result` and the message in `last_error`. Methods with no value return the result code.
- Policy, retries and formatting live in GDScript.
- Nothing panics across the FFI boundary: no `unwrap` on fallible paths.
- libhegel's u64 labels and seeds cross into GDScript bit-cast to `int`.
- Each thread gets its own libhegel context, as in upstream's Python frontend.

**The GDScript layer** in `addons/hegel/` is the user API. Only `hegel.gd`, `settings.gd`, `result.gd` and `test_case.gd` touch native classes; generators go through `HegelTestCase`'s `_draw_*` / `_collection` / `_start_span` / `_stop_span` primitives, and `state_machine.gd` through `_state_machine`. Two exceptions in `generators.gd`: `HegelNative`'s label functions, and `text` and `text_from`, which build their `HegelNativeStringGenerator` once, at construction.

- **Run loop** (`Hegel.run`, and `Hegel.replay` through `start_blob`): `next_test_case`, `body.call(tc)`, `mark_complete` with the case's status, draining engine output after each engine step; then the run result becomes a `HegelResult`. A nested run returns a usage error. The database key is `HegelSettings.database_key` if set, else `<script>::<function>` from `get_stack()`: the innermost `test_*` frame above `run`, falling back to `run`'s caller. The report header names it.
- **Report.** A case records draw lines and notes when the engine stamps it (`should_capture`, not at quiet verbosity) or the run is verbose. Captures are kept per origin, ranked as upstream's Python `_Captured`, and each failure's report is built from its origin's capture. Unless `settings._silent`, a failure prints its report with `printerr` plus a one-line `push_error`, and an error goes through `push_error`; the addon's own in-process tests set `_silent`.
- **Terminal events.** A case ends at its first failed `check` (INTERESTING, origin `check: source:line`), runtime error (INTERESTING, see below), failed `assume` (INVALID), or engine stop-test (OVERRUN). Later events change nothing. `_end` takes a lock, since an error can arrive from another thread. An engine error that isn't stop-test or assume ends the run with a usage or internal error, never a counterexample.
- **Runtime errors.** `error_capture.gd`, a `Logger`, is added for each run and points at the case whose body is running. A script error or an error (`push_error`, engine errors) ends that case, from any thread; warnings don't. The origin is `script error: file:line` or `error: file:line` of the innermost backtrace frame outside the addon, never the message, which carries values. The report line is the message and location, then the backtrace's frames down to the runner. The capture hands each error to the case (`_on_error`), which ends, or collects the error into the innermost open `expect_errors` call when it isn't a script error.
- **Simplest mode.** Once a case has ended, primitives return their simplest value without calling the engine, so the body can run on or return early. A collection then asks for elements only up to its minimum size, and stops at its first rejection. GDScript has no exceptions to unwind it.
- `HegelSettings.new()` reads the engine's resolved profile (`HEGEL_*` env, `ci`), and the run sets every field on a fresh native handle. The database defaults to `user://hegel/` only where the profile leaves it at the engine default.
- **Generators.** Factories live on `HegelGenerators` (`generators.gd`): `integers`, `floats`, `booleans`, `just`, `sampled_from`, `one_of` (variadic), `composite`, `lists`, `tuples` (variadic), `dictionaries`, `text`, `text_from`. `HegelGenerator` (`generator.gd`) adds `map`, `filter`, `flat_map`. Each generator is an inner class of `generators.gd` with a span `label` from `hegel-gdscript.<kind>`, combined with its sources' labels, set once at construction. The engine sizes collections (`HegelTestCase._Collection`, one native collection per draw); `unique` lists and dictionary keys reject duplicates by `Dictionary`-key equality. `text` never draws U+0000, which a Godot `String` can't hold. `tc.draw` opens one span per draw, as Python's frontend does; `filter` adds a `filter.attempt` span per attempt, discarded on rejection. Tests and docs alias the factories as `const Gs := preload("res://addons/hegel/generators.gd")`.
- **State machines.** `HegelStateMachine` (`state_machine.gd`) is a base class: state in member variables, rules as `rule_<name>(tc)` methods and invariants as `invariant_<name>(tc)`, found through `get_method_list()`. `run(tc, steps)` is Python's `_run_sequential`: the engine picks rules (`HegelTestCase._StateMachine`, concurrency 1). Each step and invariant runs through `tc._call_nested`, Python's `_child`: indented, with fresh draw names. A failed `assume` in a rule rejects only the step: `tc._reopen()` undoes the rejection and the runner calls `rule_rejected`. Any other terminal event ends the machine; its closing lines go through `_note_always`, since nothing else is recorded after the terminal event.
- **Invalid arguments** don't raise at construction (a `push_error` in a body would be a counterexample): the factory returns `_Invalid`, and drawing it ends the run with a usage error. So does a draw name that isn't a GDScript identifier. Bounds the engine validates (`min > max`, NaN, empty float ranges) are left to it.

- **Plain runner.** `cli/run.gd` is a `SceneTree` script: it calls each `test_*` method of every `.gd` under its arguments on a new instance, and exits 1 if any failed. A test fails when it logs an error while no run is in progress (`Hegel._in_progress()`): a failed run's `push_error` counts, and errors inside bodies are the run's to judge.

**The engine is the authority.** When libhegel behaves differently from upstream's frontends or Hypothesis, record it in the saga's Found section and ask the owner. Keep workarounds out of the addon.

**Upstream is the reference.** Before designing a behaviour, read how `/tmp/hegel/frontends/python/python/hegel/` and `/tmp/hegel/frontends/cpp/` do it, and read `libhegel/include/hegel.h`. If `/tmp/hegel` is missing, clone `https://github.com/hegeldev/hegel` and check out `5195b0b`, whose `libhegel/` matches tag `libhegel/0.48.0` (the tag itself has no `frontends/cpp/`). Copy their semantics, in GDScript idioms.

## Code style

- Every `.gd` file is statically typed. `project.godot` makes an untyped declaration a parse error for `addons/hegel/` and `tests/` (through `directory_rules`); vendored addons are excluded.
- Naming: `snake_case` files and functions, `PascalCase` for `class_name`, `UPPER_SNAKE_CASE` for constants.
- Public API carries `##` doc comments, since Godot shows them in the editor help. Other comments are one line and explain why. A known shortcut gets `shortcut: <the limit>, <when to upgrade>`.

## Testing

- Every test runs against the real engine, with no mocks. Every public function has a test.
- Seed or derandomize every run, and disable the database, unless the test is about the database.
- There is no GDScript coverage tool, so prove each new test can fail: break the behaviour, watch it go red, restore it.
- `tests/support/quality.gd` holds upstream's `minimal`, `find_any` and `assert_all_examples`, plus `usage_error`; `tests/quality/` ports upstream's shrink and find quality tests per generator, each naming its upstream case; `tests/generators/` holds contract and validation tests per family.
- gdUnit4 adds its own `Logger` and reports script errors during a test as failures; `push_error` only when `gdunit4/settings/report/godot/push_error` is on (off by default). So a scenario that provokes an error on purpose always runs in a fresh process: add it to `tests/support/error_scenarios.gd`, or to `tests/subjects/` for a snapshot.
- **Docs and examples.** `tests/docs_test.gd` runs every ```` ```gdscript ```` block in `README.md` and `docs/guide.md` in a fresh process: gdUnit4 suites under gdUnit4 (`Subprocess.run_gdunit4`), the rest under the plain runner. Each must pass, unless its fence reads ```` ```gdscript fails ````. A block without `const Gs` gets it prepended. `tests/examples_test.gd` runs `examples/` the same way, and both derandomize through `HEGEL_*` variables.
- **Snapshot tests.** `tests/report_snapshot_test.gd` runs every script in `tests/subjects/` with `tests/support/subprocess.gd`, which scrubs the banner, blobs, absolute paths, Godot source locations and the addon's line numbers. A mismatch writes `tests/approvals/<name>.received.txt` (gitignored). Read it; to accept it, rename it over `<name>.approved.txt`.

## Gotchas

- **Error noise.** Godot prints every error to stderr, including each repeat while the engine shrinks an error-caused failure. It's noise, not more failures. It can't be muted while a `Logger` still sees the errors: `Engine.print_error_messages = false` silences both.
- **Cold-import crash.** A `godot --headless --import` with no `.godot/` can segfault on exit (exit 134) once the project has a GDExtension. It's a Godot race between GDExtension doc generation and editor shutdown ([#111048](https://github.com/godotengine/godot/issues/111048)). The import finishes first, so `just import` retries once, warm, and the retry must succeed.
- **Float literals.** Godot parses them loosely: a subnormal like `5e-324` becomes 0.0, some 17-digit literals (and `String.to_float`) land an ulp off, and a `-0.0` in an Array literal becomes 0.0. Build exact floats from bytes or arithmetic.
