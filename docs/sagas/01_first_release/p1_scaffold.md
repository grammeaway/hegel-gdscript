# P1: Scaffold

## Gate

The owner has run `git init` and `just` is on PATH (F8). If either is missing, stop and ask. Ask before installing any tool or Rust toolchain yourself.

## Finding

The repository holds only `PLAN.md`. Nothing builds or loads. The planning spike (README, "Spikes") showed that the native half works: gdext 0.5.5 plus `hegeltest-c` 0.48.0 builds, loads in Godot 4.7.2 headless and shrinks a failing integer correctly. Its code is in `/tmp/spike_native/` if that still exists. A fresh `--import` segfaults on exit whenever any gdext library is present (F1), and CI always imports fresh.

## Change

Lay out the repository, build the native library, and expose the run lifecycle to GDScript. Settle the commands every later pass uses.

Layout:

```
project.godot              dev project for tests and examples; not shipped
addons/hegel/              the shipped addon
  hegel.gdextension
  bin/                     built libraries (gitignored)
addons/gdUnit4/            vendored, dev-only (D9)
rust/                      the gdext crate (Cargo.toml, src/)
tests/                     gdUnit4 suites, mirroring addons/hegel/
docs/sagas/                this saga
justfile  AGENTS.md  README.md  LICENSE  .gitignore  rust-toolchain.toml
```

Native layer (`rust/src/`), one `RefCounted` class per handle kind, freeing its handle in `Drop`:

- `HegelNativeSettings`: `hegel_settings_new` and setters for test cases, seed, derandomize, database (path, or `""` for disabled), database key, verbosity, suppressed health checks.
- `HegelNativeRun`: `start(settings)`, `next_test_case() -> HegelNativeTestCase` (null when done), `result()`, `drain_output() -> PackedStringArray`. The output callback goes into a buffer, as `OutputBuffer` does in `frontends/python/src/lib.rs`.
- `HegelNativeTestCase`: `generate_integer`, `start_span`, `stop_span`, `should_capture`, `mark_complete(status, origin)`.
- `HegelNativeRunResult`: status, error kind, error message, failure count, and the origin, blob and caveat of each failure.
- Static `label_from_name` and `label_combine` (D10). `version()` returns `hegel_version`.
- Every fallible method stores `last_result` (the `hegel_result_t` as an int) and `last_error`. Status and enum values are exposed as constants on the classes.
- One error context per thread, as `with_ctx` does in the Python frontend.

## Steps

1. `.gitignore` (`.godot/`, `addons/hegel/bin/`, `rust/target/`, `*.received.txt`), MIT `LICENSE` (D5), `rust-toolchain.toml` pinned to `1.98.1` (installed locally; above libhegel's MSRV of 1.86), and a minimal `README.md` saying what the project is and that it's pre-release, replacing the 2-line placeholder from the initial commit.
2. `rust/` crate `hegel_gdscript` (cdylib), with the pins from D7. Port the spike, then grow it into the classes above.
3. `addons/hegel/hegel.gdextension`, `entry_symbol = "gdext_rust_init"`, `compatibility_minimum = "4.5"`. One library path per platform under both debug and release keys (D7): `bin/libhegel_gdscript.linux.x86_64.so`, `bin/hegel_gdscript.windows.x86_64.dll`, `bin/libhegel_gdscript.macos.arm64.dylib`.
4. `justfile`, with recipes that work on Linux, Windows (Git Bash) and macOS:
   - `build`: `cargo build --release`, then copy the library into `addons/hegel/bin/` under its platform name;
   - `import`: the Godot import, made safe against F1;
   - `test`: the gdUnit4 suite, headless (Nomu's command: `addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests`);
   - `lint`: `cargo fmt --check`, `cargo clippy -- -D warnings`, and `gdlint` from `gdtoolkit` through `uvx`, if it parses our GDScript (log it if it doesn't);
   - `check`: lint, build, import, test.
5. **F1.** Reproduce the crash, then narrow it down. Try the official 4.7.2 Linux binary from godotengine.org (download it to `/tmp`, don't install it) and gdext's issue tracker. Fix the crash if it is ours. If it isn't, make `just import` reliable: an import that exits 134 but leaves a usable `.godot/` counts, provided a script run afterwards sees `HegelNativeRun`. Record the cause or the workaround under Decisions.
6. Vendor gdUnit4 into `addons/gdUnit4/` and enable it in `project.godot`. Make `debug/gdscript/warnings/untyped_declaration` an error for `addons/hegel/` and `tests/`, but not for `addons/gdUnit4/`. Check whether 4.5+ has per-directory warning rules; if there is only the global `exclude_addons`, record what you chose and why.
7. `tests/native/native_smoke_test.gd`: drive the native classes directly, as in the spike. A seeded run of `x in [0, 1e6]` with property `x < 1000` fails, shrinks to exactly `1000`, has one failure with a non-empty blob, and two runs with the same seed see the same number of test cases. Add a test that reads `last_result` after a bad call, `generate_integer(5, 1)`, and gets `HEGEL_E_INVALID_ARG` with a non-empty `last_error`.
8. `AGENTS.md` (load the `writing-for-agents` skill): what the project is, the commands, the layout, the native/GDScript split, F1's workaround, F7 (gdUnit4's own Logger), the shared rules from the saga README, and a pointer to `/tmp/hegel` as the upstream reference.

## Completion

- [ ] `rm -rf .godot && just check` exits 0 on this machine.
- [ ] `just test` runs `native_smoke_test.gd` green. Changing the property to `x < 999` turns the "shrinks to exactly 1000" test red. Check this, then restore it.
- [ ] `cargo clippy -- -D warnings` and `cargo fmt --check` are clean.
- [ ] `git status --ignored` shows `addons/hegel/bin/`, `.godot/` and `rust/target/` as ignored.
- [ ] `AGENTS.md` names every `just` recipe, and each one runs.

## Non-goals

- Any user-facing GDScript API (p2 onward).
- Native bindings for floats, collections, strings, replay or state machines. The plans that need them add them.
- CI and packaging (p9).
