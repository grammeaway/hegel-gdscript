# First release: progress

This is the live log for the plans in `README.md`. There is one row per plan; details go under Decisions, Deviations and Found.

## Status

| Plan | Status | Base | Notes |
|---|---|---|---|
| p1 scaffold | done | `53dfbb1` | `rm -rf .godot && just check` green; 13 native smoke tests; F1 root-caused to Godot #111048 |
| p2 runner core | planned | | |
| p3 report and replay | planned | | |
| p4 runtime errors | planned | | |
| p5 scalars and combinators | planned | | |
| p6 collections and text | planned | | |
| p7 state machines | planned | | |
| p8 docs and integration | planned | | |
| p9 ci and release | planned | | |

## Decisions

Decisions taken during passes, with who took each one (owner or agent) and when.

| # | Decision | Taken |
|---|---|---|
| P1.1 | Add the `rustfmt` component to the pinned 1.98.1 toolchain (it was installed without it); `rust-toolchain.toml` lists `clippy` and `rustfmt`. | 2026-10-24, owner |
| P1.2 | Vendor gdUnit4 v6.2.2, the newest 6.x, downloaded from its GitHub release tag (identical to Nomu's copy apart from `.uid` files). Godot's generated `.uid` files are committed with it. | 2026-10-24, owner |
| P1.3 | `just lint` runs `gdlint` through `uvx --from gdtoolkit==4.5.0`. It parses our GDScript (typed `for`, inner classes, `##` docs) and flags real problems. | 2026-10-24, owner (uvx); agent (pin) |
| P1.4 | LICENSE: MIT, `Copyright (c) 2026 Victor Gram`. | 2026-10-24, owner |
| P1.5 | `last_result` / `last_error` are read-only properties on each native object, not a global: libhegel's context message is overwritten by any later call on the thread, including the frees GDScript's refcounting triggers at unpredictable times. Methods with no value return the result code too; value methods return a zero value on failure. | 2026-10-24, agent |
| P1.6 | A non-handle class `HegelNative` (`no_init`) holds the result-code constants (`OK`, `E_STOP_TEST`, …, names without the `HEGEL_` prefix, as upstream's Python constants) and the static `version`, `label_from_name`, `label_combine`. Status constants live on `HegelNativeTestCase`, run status and error kinds on `HegelNativeRunResult`, verbosity and health checks on `HegelNativeSettings`. | 2026-10-24, agent |
| P1.7 | Optional C strings map to `""` both ways: an empty `database_key` or `mark_complete` origin is passed as NULL, and an absent blob, caveat or run error reads as `""`. `set_database("")` keeps libhegel's own meaning (disabled); the engine default (`./.hegel/examples/`) isn't reachable, since D12 always sets a path. | 2026-10-24, agent |
| P1.8 | An `int` argument that doesn't fit its C parameter (negative `test_cases`, an enum beyond u32, a negative failure index) fails the call with `E_INVALID_ARG` and a message naming the argument, rather than wrapping. Labels and seeds are u64 bit-cast to `int`. | 2026-10-24, agent |
| P1.9 | Failures are read by index through `failure_origin(i)`, `failure_blob(i)`, `failure_caveat(i)`; each is one fixed sequence: copy the failure, read the field, free the copy. `RunResult` also has `health_check()`, the second out-parameter of `hegel_run_result_error_kind`. | 2026-10-24, agent |
| P1.10 | `HegelNativeRun` is created with `new()` and started with `start(settings)`, so the start's result code has an object to land on. `HegelNativeTestCase` and `HegelNativeRunResult` are `no_init`: only the run hands them out. `reloadable = false` in `hegel.gdextension`. | 2026-10-24, agent |
| P1.11 | Untyped declarations are errors only in `addons/hegel/` and `tests/`. Godot 4.5+ has per-directory rules: `debug/gdscript/warnings/directory_rules = {"res://addons": 0 (exclude), "res://addons/hegel": 1 (include)}`; the more specific path wins. Checked with a probe file in each directory: `addons/hegel` and `tests` fail to parse, `addons/gdUnit4` loads. | 2026-10-24, agent |
| P1.12 | **F1 cause:** Godot bugs [#111048](https://github.com/godotengine/godot/issues/111048) / [#111645](https://github.com/godotengine/godot/issues/111645), both open. On a cold import, `EditorHelp` queues a deferred `_gen_extensions_docs()` for GDExtension classes; `EditorNode`'s destructor deletes `doc` first, and the final message-queue flush then calls `doc->generate` on null. It's a timing race in Godot, not ours: it reproduces with the official 4.7.2 binary (2/2) and with any gdext crate. **Workaround:** `just import` runs the import and, if it fails, retries once warm; the retry must exit 0. Checked on the spike project (crashes every time): first import 134, retry 0, then a script sees `HegelNativeRun`. Our own project happens not to crash (7/7): the enabled gdUnit4 plugin delays shutdown past the race, so the retry is a safety net here. | 2026-10-24, agent |
| P1.13 | `reports/` (gdUnit4's HTML/XML output) is gitignored. | 2026-10-24, agent |

## Deviations

For each plan: where the work differed from the plan, and why.

**p1**

- The plan said the crash happens "whenever a gdext library is present". In this project it doesn't, because the gdUnit4 plugin changes shutdown timing (P1.12). The retry stays in, since CI and other platforms may time things differently.
- `HegelNative` (P1.6) and `HegelNativeRunResult.health_check()` (P1.9) aren't named in the plan. They hold what the plan places "on the classes" without naming a class.
- `rust-toolchain.toml` lists the `clippy` and `rustfmt` components as well as the channel, so `just lint` works on a fresh rustup.
- `README.md` also names `uv` as a build requirement, for `gdlint`.
- The release library is 9.5 MB on Linux, against 150 MB for a debug build.

## Found

Bugs or debts found during a pass and kept out of its diff.

- **p1, for p8/p9:** users' projects hit F1 too: any CI that runs a cold `--headless --import` on a project with our addon can exit 134 after a successful import (Godot #111048; macOS reports too). p8 should document the retry (or `--frame-delay 800`, also reported to avoid it); p9's CI already gets it through `just import`.
- **p1:** `/tmp/hegel` is checked out at `5195b0b` (as planned), not at the `libhegel/0.48.0` tag (`ef54eff`). `libhegel/` is identical between the two; only the frontends moved on (the Java import, and the C++ frontend's nix flake). Fine for reading semantics, but the tag is the strict reference.
