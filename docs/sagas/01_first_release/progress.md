# First release: progress

This is the live log for the plans in `README.md`. There is one row per plan; details go under Decisions, Deviations and Found.

## Status

| Plan | Status | Base | Notes |
|---|---|---|---|
| p1 scaffold | done | `53dfbb1` | `rm -rf .godot && just check` green; 13 native smoke tests; F1 root-caused to Godot #111048 |
| p2 runner core | done | `5958c47` | 58 tests green; integer quality ported; mutation checks red |
| p3 report and replay | done | `fc05e85` | 77 tests green, 9 approved snapshots; mutation checks red; F: gdUnit4 ignores `push_error` by default |
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
| P2.1 | `HegelSettings.new()` starts from the engine's resolved profile, read through new `HegelNativeSettings.get_*` getters, so its fields show the real values (`HEGEL_*` env, `ci` profile). `Hegel.run` sets every field on a fresh native handle. | 2026-10-24, owner |
| P2.2 | The `user://hegel/` database default (D12) replaces only the engine's *default* location; a profile or `HEGEL_DATABASE` that disables it or names a path wins. `database = ""` disables it. | 2026-10-24, owner |
| P2.3 | Enums with libhegel's values: `HegelSettings.Verbosity`, `HegelSettings.HealthCheck` (bit flags for the `suppress_health_checks` int), `HegelResult.ErrorKind`. | 2026-10-24, owner |
| P2.4 | `HegelResult.failures` is `Array[HegelResult.Failure]`, an inner class with `origin`, `blob`, `caveat`. | 2026-10-24, owner |
| P2.5 | `HegelResult.test_cases` counts every call of the body: rejected cases and shrinking included. | 2026-10-24, owner |
| P2.6 | `check` and `assume` return their condition even after the case has ended, and then change nothing. | 2026-10-24, owner |
| P2.7 | Generators are aliased as `const Gs := preload("res://addons/hegel/generators.gd")` in docs and tests: gdlint rejects a lower-case preload constant (`load-constant-name`). | 2026-10-24, agent |
| P2.8 | `tc.note` appends to a per-case `_notes` buffer for p3's report; libhegel has no note call we need. | 2026-10-24, agent |
| P2.9 | Nesting is detected through a static per-thread set in `Hegel`, the only state outside a run. A generator without `_draw` ends the run with a usage error. | 2026-10-24, agent |
| P2.10 | The quality helpers follow upstream: `minimal` runs with seed 1, `find_any` and `assert_all_examples` derandomized; all disable the database. They only record values from live cases, so a simplest-mode value can't pass for a match. | 2026-10-24, agent |
| P3.1 | `Hegel.run` and `Hegel.replay` return the result and, on a failure, also `printerr` the report (shortened at quiet verbosity) and raise a one-line `push_error`, so gdUnit4 fails the test. An internal `HegelSettings._silent` turns both off; the quality helpers and the addon's in-process tests set it. | 2026-10-24, owner |
| P3.2 | A run that ends in an error is loud too: its message goes out through `push_error`, under the same `_silent` switch. | 2026-10-24, owner |
| P3.3 | A replay whose blob doesn't fail returns `ErrorKind.DID_NOT_REPRODUCE = 7`, a frontend-only kind documented as such. | 2026-10-24, owner |
| P3.4 | Draw names: `tc.draw(gen, name := "")`. Unnamed draws are `draw_1`, `draw_2`, …; a name shows bare, then as `<name>_<count>`, skipping names already shown. That is Python's `_allocate_display_name` with an explicit name treated as non-repeatable: GDScript can't infer names from the source, so an explicit name plays the part of Python's inferred one. C++ prints a reused bare name bare every time; the plan's rule follows Python. | 2026-10-24, agent |
| P3.5 | Nothing is recorded after a case's terminal event (later draws or notes), since upstream's body stops at the failure. | 2026-10-24, agent |
| P3.6 | The report keeps the plan's header (`--- Failure: <key> ---`, unpadded; `--- Failure ---` without a key), counts as the C++ frontend (valid and failing cases up to the first failure; rejected ones before it as discarded), and multi-line notes indent every line. Several failures' reports are joined by a blank line. | 2026-10-24, agent |
| P3.7 | A replay's failure carries the replayed blob in `failures[i].blob` and its report: the engine gives a replay failure no blob, since the caller holds it. `Hegel.replay("")` is a usage error; other bad blobs are the engine's `E_INVALID_ARG`, reported as usage errors. | 2026-10-24, agent |
| P3.8 | An errored run goes out through `push_error` alone, as `Hegel run error (<KIND>): <message>`: `push_error` already writes to stderr, so a `printerr` would duplicate it. A failure's `push_error` reads `Hegel: property failed at <origins>; the report is above`. | 2026-10-24, agent |
| P3.9 | No `hegel_settings_set_test_location`: `get_stack()` gives the call's line, not the test's first line, and the location is only used inside Antithesis, which is out of scope (README item 18). `hegel_test_case_from_blob` wasn't needed either. | 2026-10-24, agent |
| P3.10 | `_silent` doesn't mute engine output: that follows `verbosity`, and the engine's stale-blob line is useful. | 2026-10-24, agent |

## Deviations

For each plan: where the work differed from the plan, and why.

**p1**

- The plan said the crash happens "whenever a gdext library is present". In this project it doesn't, because the gdUnit4 plugin changes shutdown timing (P1.12). The retry stays in, since CI and other platforms may time things differently.
- `HegelNative` (P1.6) and `HegelNativeRunResult.health_check()` (P1.9) aren't named in the plan. They hold what the plan places "on the classes" without naming a class.
- `rust-toolchain.toml` lists the `clippy` and `rustfmt` components as well as the channel, so `just lint` works on a fresh rustup.
- `README.md` also names `uv` as a build requirement, for `gdlint`.
- The release library is 9.5 MB on Linux, against 150 MB for a debug build.

**p2**

- `draw` has no `name` parameter yet: names only matter to p3's report, so p3 adds it.
- Not ported from the integer quality tests: `MinimizeBoundedIntegersToPositive` (needs `filter`, p5), the list cases (p6), and `IntegersAreOftenSmallButNotThatSmall` (xfail upstream, Hypothesis #4624).
- Also tested beyond the plan: settings start from the profile (`HEGEL_TEST_CASES`, `HEGEL_SEED`, `HEGEL_DATABASE`), suppressed health checks, invalid settings and draws as usage errors, the check origin's exact line.
- Mutation checks: simplest mode calling the engine turns `test_draws_after_a_terminal_event_are_simplest_values` red; last event wins turns `test_failed_check_then_assume_stays_a_failure` and `test_failed_assume_then_check_stays_rejected` red; `minimal` keeping its first match turns 8 quality tests red.

**p3**

- Two p2 tests read internals the report replaced (`_failure_message`, `_notes`). They now assert the same behaviour through `result.report`: `test_report_shows_the_first_failed_check` and `test_notes_are_in_the_report_in_order`. They weren't wrong; their fields were removed.
- Snapshot subjects share a base, `tests/support/subject.gd`, with seeded settings and the common `x < 10` body. Beyond the plan's list there are `verbose` and `run_error` (P3.2) subjects. The stale-blob subject overruns (step 5), so it shows the engine's line on where the replay left the recording. A fixed-body stale blob is tested in-process.
- Not tested: the caveat line. It needs a nondeterministic failure the engine confirms, which can't be made reliable in a test.
- Mutation checks: `var ` to `let ` turns 7 report tests and the snapshot test red, writing 6 `.received.txt` files; dropping the database key turns `test_database_replays_a_stored_failure_first` red (plus the header test and snapshots); keeping the first capture instead of the newest stamped one turns 11 tests red; ignoring `_silent` turns the snapshot test red (the replay subjects' setup runs print).
- Completion check "replay fails with the same report body, and passes, with the stale-blob error, once fixed": `test_replay_reproduces_the_report_body`, `test_replay_of_a_fixed_failure_did_not_reproduce`, and the `replay` / `stale_blob` snapshots.

## Found

Bugs or debts found during a pass and kept out of its diff.

- **p1, for p8/p9:** users' projects hit F1 too: any CI that runs a cold `--headless --import` on a project with our addon can exit 134 after a successful import (Godot #111048; macOS reports too). p8 should document the retry (or `--frame-delay 800`, also reported to avoid it); p9's CI already gets it through `just import`.
- **p1:** `/tmp/hegel` is checked out at `5195b0b` (as planned), not at the `libhegel/0.48.0` tag (`ef54eff`). `libhegel/` is identical between the two; only the frontends moved on (the Java import, and the C++ frontend's nix flake). Fine for reading semantics, but the tag is the strict reference.
- **p2:** `hegel_settings_get_seed` rejects a NULL out-parameter for either output, so the native `get_seed` / `has_seed` each pass a scratch variable for the other.
- **p2, for p3:** with the default verbosity a failing run printed nothing through `drain_output` in these tests; p3's report shouldn't count on engine output.
- **p3, for the owner (affects P3.1):** F7 is only half right. gdUnit4 6.2.2 reports script errors as failures, but `push_error` only when `gdunit4/settings/report/godot/push_error` is on, and it defaults to off (`GdUnitSettings.gd:137`). Confirmed: with `_silent` ignored, 171 `push_error`s left the in-process suites green. So by default a gdUnit4 user sees the report and error, but the test doesn't fail on its own; they still need `assert_bool(result.passed).is_true()`. Options: document that setting (p8), or a gdUnit4-specific assert helper. p4's Logger capture doesn't change this. `AGENTS.md` now states it correctly.
- **p3:** under `_silent`, engine output (such as the stale-blob line) still reaches stderr during the addon's tests. It's harmless noise (P3.10).
