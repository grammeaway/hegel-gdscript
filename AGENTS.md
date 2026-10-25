# hegel-gdscript

A property-based testing addon for GDScript, built on [Hegel](https://hegel.dev)'s engine, libhegel. Pre-release: work is planned in `docs/sagas/`, and progress, decisions and findings are logged in each saga's `progress.md`.

This file is the single source of truth for commands, layout and architecture. Update it in the same change whenever one of these moves.

## Commands

Run everything through `just`. Godot 4.7.2 is `godot` on PATH; set `GODOT` to use another binary.

- `just build`: `cargo build --release`, then copy the library into `addons/hegel/bin/` under its platform name. Always the release profile: a debug build is 150 MB.
- `just import`: the headless Godot import. Run it on a fresh checkout and after adding or renaming a `class_name`, or tests can't see the class.
- `just test`: every gdUnit4 suite under `tests/`, headless. Exit 0 is green. The two `Remote Debugger` errors at the start are expected: `runtest.sh` points the debugger at port 0 on purpose.
- `just lint`: `cargo fmt --check`, `cargo clippy -- -D warnings`, and `gdlint` (gdtoolkit through `uvx`) over `addons/hegel` and `tests`.
- `just check`: lint, build, import, test. It passes at the end of every change.

The Rust toolchain is pinned in `rust-toolchain.toml`.

## Layout

```
project.godot        dev project for tests and examples; not shipped
addons/hegel/        the shipped addon
  hegel.gdextension  one library per platform, under debug and release keys
  bin/               built libraries (gitignored)
addons/gdUnit4/      vendored test framework, dev-only
rust/                the gdext crate over libhegel (`hegeltest-c`, linked statically)
tests/               gdUnit4 suites, mirroring addons/hegel/; tests/native/ drives the native classes
  subjects/          one-scenario SceneTree scripts, run in a fresh process by report_snapshot_test.gd
  support/           helpers; error_scenarios.gd holds error_capture_test.gd's scenarios
  approvals/         each subject's approved, scrubbed output
docs/sagas/          plans and their progress logs
```

## Architecture

**The native layer is thin.** `rust/src/` exposes one `RefCounted` class per libhegel handle (`HegelNativeSettings`, `HegelNativeRun`, `HegelNativeTestCase`, `HegelNativeRunResult`, `HegelNativeCollection`, `HegelNativeStringGenerator`), plus `HegelNative` for result codes, labels and the version. Native classes are internal and undocumented for users.

- Each `#[func]` makes one `hegel_*` call, or a fixed sequence that frees a handle. It converts arguments and stores the result code in `last_result` and the message in `last_error`. Methods with no value return the result code.
- Policy, retries and formatting live in GDScript.
- Nothing panics across the FFI boundary: no `unwrap` on fallible paths.
- libhegel's u64 labels and seeds cross into GDScript bit-cast to `int`.
- Each thread gets its own libhegel context, as in upstream's Python frontend.

**The GDScript layer** in `addons/hegel/` is the user API. Only `hegel.gd`, `settings.gd`, `result.gd` and `test_case.gd` touch native classes; generators go through `HegelTestCase`'s `_draw_*` / `_collection` / `_start_span` / `_stop_span` primitives. Two exceptions in `generators.gd`: `HegelNative`'s label functions, and `text`, which builds its `HegelNativeStringGenerator` once, at construction.

- **Run loop** (`Hegel.run`, and `Hegel.replay` through `start_blob`): `next_test_case`, `body.call(tc)`, `mark_complete` with the case's status, draining engine output after each engine step; then the run result becomes a `HegelResult`. A nested run returns a usage error. The database key is `<script>::<function>` of `run`'s caller, from `get_stack()`.
- **Report.** A case records draw lines and notes when the engine stamps it (`should_capture`, not at quiet verbosity) or the run is verbose. Captures are kept per origin, ranked as upstream's Python `_Captured`, and each failure's report is built from its origin's capture. Unless `settings._silent`, a failure prints its report with `printerr` plus a one-line `push_error`, and an error goes through `push_error`; the addon's own in-process tests set `_silent`.
- **Terminal events.** A case ends at its first failed `check` (INTERESTING, origin `check: source:line`), runtime error (INTERESTING, see below), failed `assume` (INVALID), or engine stop-test (OVERRUN). Later events change nothing. `_end` takes a lock, since an error can arrive from another thread. An engine error that isn't stop-test or assume ends the run with a usage or internal error, never a counterexample.
- **Runtime errors.** `error_capture.gd`, a `Logger`, is added for each run and points at the case whose body is running. A script error or an error (`push_error`, engine errors) ends that case, from any thread; warnings don't. The origin is `script error: file:line` or `error: file:line` of the innermost backtrace frame outside the addon, never the message, which carries values. The report line is the message and location, then the backtrace's frames down to the runner.
- **Simplest mode.** Once a case has ended, primitives return their simplest value without calling the engine, so the body can run on or return early. A collection then asks for elements only up to its minimum size, and stops at its first rejection. GDScript has no exceptions to unwind it.
- `HegelSettings.new()` reads the engine's resolved profile (`HEGEL_*` env, `ci`), and the run sets every field on a fresh native handle. The database defaults to `user://hegel/` only where the profile leaves it at the engine default.
- **Generators.** Factories live on `HegelGenerators` (`generators.gd`): `integers`, `floats`, `booleans`, `just`, `sampled_from`, `one_of` (variadic), `composite`, `lists`, `tuples` (variadic), `dictionaries`, `text`. `HegelGenerator` (`generator.gd`) adds `map`, `filter`, `flat_map`. Each generator is an inner class of `generators.gd` with a span `label` from `hegel-gdscript.<kind>`, combined with its sources' labels, set once at construction. The engine sizes collections (`HegelTestCase._Collection`, one native collection per draw); `unique` lists and dictionary keys reject duplicates by `Dictionary`-key equality. `text` never draws U+0000, which a Godot `String` can't hold. `tc.draw` opens one span per draw, as Python's frontend does; `filter` adds a `filter.attempt` span per attempt, discarded on rejection. Tests and docs alias the factories as `const Gs := preload("res://addons/hegel/generators.gd")`.
- **Invalid arguments** don't raise at construction (a `push_error` in a body would be a counterexample): the factory returns `_Invalid`, and drawing it ends the run with a usage error. Bounds the engine validates (`min > max`, NaN, empty float ranges) are left to it.

**The engine is the authority.** When libhegel behaves differently from upstream's frontends or Hypothesis, record it in the saga's Found section and ask the owner. Keep workarounds out of the addon.

**Upstream is the reference.** Before designing a behaviour, read how `/tmp/hegel/frontends/python/python/hegel/` and `/tmp/hegel/frontends/cpp/` do it, and read `libhegel/include/hegel.h`. If `/tmp/hegel` is missing, clone `https://github.com/hegeldev/hegel` at tag `libhegel/0.48.0`. Copy their semantics, in GDScript idioms.

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
- **Snapshot tests.** `tests/report_snapshot_test.gd` runs every script in `tests/subjects/` with `tests/support/subprocess.gd`, which scrubs the banner, blobs, absolute paths, Godot source locations and the addon's line numbers. A mismatch writes `tests/approvals/<name>.received.txt` (gitignored). Read it; to accept it, rename it over `<name>.approved.txt`.

## Gotchas

- **Error noise.** Godot prints every error to stderr, including each repeat while the engine shrinks an error-caused failure. It's noise, not more failures. It can't be muted while a `Logger` still sees the errors: `Engine.print_error_messages = false` silences both.
- **Cold-import crash.** A `godot --headless --import` with no `.godot/` can segfault on exit (exit 134) once the project has a GDExtension. It's a Godot race between GDExtension doc generation and editor shutdown ([#111048](https://github.com/godotengine/godot/issues/111048)). The import finishes first, so `just import` retries once, warm, and the retry must succeed.
- **Float literals.** Godot parses them loosely: a subnormal like `5e-324` becomes 0.0, some 17-digit literals (and `String.to_float`) land an ulp off, and a `-0.0` in an Array literal becomes 0.0. Build exact floats from bytes or arithmetic.
