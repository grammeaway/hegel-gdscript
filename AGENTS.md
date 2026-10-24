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
docs/sagas/          plans and their progress logs
```

## Architecture

**The native layer is thin.** `rust/src/` exposes one `RefCounted` class per libhegel handle (`HegelNativeSettings`, `HegelNativeRun`, `HegelNativeTestCase`, `HegelNativeRunResult`), plus `HegelNative` for result codes, labels and the version. Native classes are internal and undocumented for users.

- Each `#[func]` makes one `hegel_*` call, or a fixed sequence that frees a handle. It converts arguments and stores the result code in `last_result` and the message in `last_error`. Methods with no value return the result code.
- Policy, retries and formatting live in GDScript.
- Nothing panics across the FFI boundary: no `unwrap` on fallible paths.
- libhegel's u64 labels and seeds cross into GDScript bit-cast to `int`.
- Each thread gets its own libhegel context, as in upstream's Python frontend.

**The GDScript layer** in `addons/hegel/` is the user API. Only `hegel.gd`, `settings.gd`, `result.gd` and `test_case.gd` touch native classes; generators go through `HegelTestCase`'s `_draw_*` / `_start_span` / `_stop_span` primitives.

- **Run loop** (`Hegel.run`): `next_test_case`, `body.call(tc)`, `mark_complete` with the case's status, draining engine output after each engine step; then the run result becomes a `HegelResult`. A nested `Hegel.run` returns a usage error.
- **Terminal events.** A case ends at its first failed `check` (INTERESTING, origin `check: source:line`), failed `assume` (INVALID), or engine stop-test (OVERRUN). Later events change nothing. An engine error that isn't stop-test or assume ends the run with a usage or internal error, never a counterexample.
- **Simplest mode.** Once a case has ended, primitives return their simplest value without calling the engine, so the body can run on or return early. GDScript has no exceptions to unwind it.
- `HegelSettings.new()` reads the engine's resolved profile (`HEGEL_*` env, `ci`), and the run sets every field on a fresh native handle. The database defaults to `user://hegel/` only where the profile leaves it at the engine default.
- Generator factories live on `HegelGenerators` (`generators.gd`); each generator is a `HegelGenerator` with a span `label` from `hegel-gdscript.<kind>`. Tests and docs alias it as `const Gs := preload("res://addons/hegel/generators.gd")`.

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
- `tests/support/quality.gd` holds upstream's `minimal`, `find_any` and `assert_all_examples`; `tests/quality/` ports upstream's shrink and find quality tests per generator.
- gdUnit4 adds its own `Logger` and reports script errors and `push_error` during a test as failures. A test that provokes an error on purpose has to account for that.

## Gotchas

- **Cold-import crash.** A `godot --headless --import` with no `.godot/` can segfault on exit (exit 134) once the project has a GDExtension. It's a Godot race between GDExtension doc generation and editor shutdown ([#111048](https://github.com/godotengine/godot/issues/111048)). The import finishes first, so `just import` retries once, warm, and the retry must succeed.
