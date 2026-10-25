# rc.1 dogfooding fixes (2026-10-25)

**Goal:** fix what the first dogfooding round of `v0.1.0-rc.1` found, ahead of the next release candidate: three bugs and five gaps, met while a Godot game's gdUnit4 suite adopted the addon (20 properties, four of them state machines).

**Must not regress:** every existing behaviour not named in a decision below; the native layer stays thin (one `#[func]` per `hegel_*` call); every test runs against the real engine; `just check` is green at the end of every pass.

**Inputs:** the dogfooding report, kept locally under `docs/reports/` (gitignored), items numbered as below; the Hegel monorepo at `5195b0b`, whose `libhegel/` matches tag `libhegel/0.48.0`; probes run during planning (below); the owner's answers in conversation (2026-10-25).

**Baseline:** `b0e6a87`.

## Probes run during planning

All in this project, under gdUnit4, Godot 4.7.2, release build.

- **Stack under gdUnit4:** from a test, `get_stack()` reads `test_<name>` and then gdUnit4's own frames (`_execute_test_case`, `execute`, `_execute`, …); none of gdUnit4's start with `test_`. A parameterized test (`test_parameters`) shows the same `test_<name>` frame for every parameter set.
- **Typed arrays:** `var xs: Array[String] = tc.draw(Gs.lists(Gs.text(), 1))` fails the first case with `Script error: Trying to assign an array of type "Array" to a variable of type "Array[String]"`. Both `.map(func(a: Array) -> Array[String]: return Array(a, TYPE_STRING, &"", null))` and `ys.assign(tc.draw(...))` pass.
- **Text distribution:** of 1000 `Gs.text()` draws, 726 held an ASCII character, 190 an ASCII punctuation character, 7 an `=`.
- **Failure noise:** a failing run under gdUnit4 prints its report, then the one-line `push_error` with a 21-frame GDScript backtrace, of which 17 frames are gdUnit4's.
- **Identifiers:** `"good lines".is_valid_unicode_identifier()` is false; `"good_lines"` and `"émoji"` are true.

## Verdicts

| # | Source item | Verdict | Plan |
|---|---|---|---|
| 1 | A helper wrapping `Hegel.run` makes every test share one database key, and their failures replay into each other; parameterized tests share one key too | **Confirmed:** `_caller_key()` takes `get_stack()[2]` (`hegel.gd:249`), the direct caller of `run`. Upstream C++ keys on the framework's test name, with an explicit `Settings::database_key` override (`frontends/cpp/src/hegel.cpp:168`) | p2 (D2) |
| 2 | `HegelResult.report` is empty when the run errors, so the documented gdUnit4 assert fails with no message | **Confirmed:** `HegelResult._errored` and `_from_native` set no report; `_drive` builds it from failures only (`hegel.gd:186`). `report_test.gd:61` and `:219` pin the empty report on purpose. README:63, guide:323 and `examples/gdunit4/inventory_test.gd:27,36` use `override_failure_message(result.report)` | p1 (D1) |
| 3 | Assigning a drawn list to a typed Array is a script error, reported as a counterexample | **Confirmed** by the probe. The counterexample is correct: the body has the bug. The fix is guidance | p6 (D3) |
| 4 | No way to say an error in a body is expected; muting with `Engine.print_error_messages` hides real crashes and is undocumented | **Confirmed:** `error_capture.gd` fails the case on every `ERROR_TYPE_SCRIPT` and `ERROR_TYPE_ERROR`. The mute skipping loggers is saga 01's F2, documented only in `AGENTS.md` Gotchas | p4 (D4) |
| 5 | `text()` rarely draws ASCII punctuation, and has no alphabet parameter | **Partly:** the distribution is the engine's, which is the authority (probe: 19% of draws hold punctuation, 0.7% hold `=`). The missing alphabet is real: libhegel's `hegel_string_generator_text` takes categories and include/exclude characters, and our binding passes none (`rust/src/string_generator.rs`, decision P6.1). Every upstream frontend has a fixed-alphabet option | p5 (D5) |
| 6 | `HEGEL_TEST_CASES` can't scale a suite that sets `test_cases` in code | **Partly:** setters win over the environment by the engine's design (`hegel.h`, `hegel_settings_new`), as in Python. Two answers need no code: scale with `settings.test_cases *= n`, which keeps the profile's value as the base, and a `hegel.toml` profile selected with `HEGEL_DEFAULT_PROFILE` | p6 (D6) |
| 7 | Draw names aren't checked: `"good lines"` shows as `var good lines = []` | **Confirmed:** `HegelTestCase.draw` / `_display_name` take any name. Upstream C++ doesn't check either; Python infers names from identifiers | p3 (D7) |
| 8 | A failed run under gdUnit4 prints a long backtrace after the report | **Confirmed** by the probe. It is Godot's backtrace for the `push_error` that P3.1 and P8.2 rely on, so the fix is a guide line | p6 |
| F1 | **Found:** `AGENTS.md` says to clone upstream at tag `libhegel/0.48.0` and read `frontends/cpp/`, but that tag has only `frontends/python` and `frontends/rust`. Saga 01 read `5195b0b`, whose `libhegel/` is identical | Confirmed: `git checkout libhegel/0.48.0 && ls frontends` | p6 |

## Decisions

| # | Decision | Taken |
|---|---|---|
| D1 | When a run ends in an error (`error_kind != NONE`), `HegelResult.report` holds `Hegel run error (<KIND>): <message>`, the line P3.8 pushes. `push_error` reuses it. A passing run's report stays `""`. | 2026-10-25, owner |
| D2 | The database key, and the report header, are `<script>::<function>` of the innermost stack frame whose function starts with `test_`, falling back to `run`'s direct caller, and `""` without a stack, as now. A new public `HegelSettings.database_key` overrides it, for parameterized tests; it starts `""`, meaning derived. The header names whichever key is used. This revises saga 01's D12. | 2026-10-25, owner |
| D3 | Typed arrays get a guide note and a Limitations line: draw into `Array`, then `assign()` into the typed one, or `map` to a typed Array. No typed-result option on `lists`. | 2026-10-25, owner |
| D4 | `tc.expect_errors(fn: Callable) -> PackedStringArray` calls `fn` and returns the messages of the errors (`push_error` and engine errors, `ERROR_TYPE_ERROR`) logged while it ran, from any thread as the capture already works, instead of failing the case. A script error inside `fn` still fails the case. Godot still prints the collected errors. | 2026-10-25, owner |
| D5 | `Gs.text_from(alphabet: String, min_size := 0, max_size := -1)`: strings drawn only from `alphabet`'s characters, with Python's string-alphabet semantics (categories `[]` plus `include_characters`), and `text`'s label. A separate factory, since GDScript has no keyword arguments and upstream treats an alphabet as exclusive of codepoint bounds. Categories and exclusions stay out (P6.1 still holds for them). | 2026-10-25, planner (delegated by the owner) |
| D6 | Scaling test counts is documented only: `settings.test_cases *= n` rather than `=`, and a `hegel.toml` profile selected with `HEGEL_DEFAULT_PROFILE` for nightly runs. No frontend-only multiplier. | 2026-10-25, owner |
| D7 | A draw name that isn't a GDScript identifier (`String.is_valid_unicode_identifier()`) ends the run with a `USAGE` error naming it, like a generator's invalid arguments. | 2026-10-25, owner |
| D8 | The saga's files and commit messages describe the source as "a game project" and don't name it. | 2026-10-25, owner |

## Plans

| Order | Plan | What | Gate |
|---|---|---|---|
| 1 | [`p1_report_on_run_errors.md`](p1_report_on_run_errors.md) | `HegelResult.report` carries the error line of an errored run | none |
| 2 | [`p2_database_key_per_test.md`](p2_database_key_per_test.md) | Key and header from the `test_*` frame; `HegelSettings.database_key` | none |
| 3 | [`p3_draw_name_validation.md`](p3_draw_name_validation.md) | A non-identifier draw name is a usage error | none |
| 4 | [`p4_expected_errors.md`](p4_expected_errors.md) | `tc.expect_errors(fn)` | none |
| 5 | [`p5_text_alphabet.md`](p5_text_alphabet.md) | `Gs.text_from(alphabet, min_size, max_size)`, through the native text binding | none |
| 6 | [`p6_docs_round.md`](p6_docs_round.md) | Guide: typed arrays, scaling test counts, gdUnit4 noise; `AGENTS.md` upstream reference | none |

**Why this order:** p1 comes first because every documented gdUnit4 assert depends on it, and it is the cheapest. p2 changes the same run path in `hegel.gd` and is the only bug that corrupts other tests' results. p3 is small and touches only `test_case.gd`'s draw. p4 changes the error capture and `test_case.gd`, after p3 so the two `test_case.gd` diffs stay apart. p5 is the only plan that changes the native layer, so its rebuild doesn't sit under unrelated changes. p6 comes last, documenting what doesn't need code once the guide has settled around p1–p5's own doc changes.

## Shared rules

- Each plan is its own commit. Keep plans out of each other's diffs.
- Each plan updates the docs its change touches: the `##` doc comments, `README.md`, `docs/guide.md`, `CHANGELOG.md`'s `Unreleased` section, and `AGENTS.md` whenever commands, layout or architecture move.
- **Bug fixes are test-first:** write the regression test, watch it go red on the baseline code, then fix. A test that pinned the old behaviour on purpose (named in the plan) is changed and the change noted in `progress.md`.
- **The native layer is thin.** Each `#[func]` maps to one `hegel_*` call, or a fixed sequence that frees a handle. Nothing panics across the FFI boundary. `cargo fmt --check` and `cargo clippy -- -D warnings` stay clean.
- **The engine is the authority; upstream is the reference.** Read `/tmp/hegel/frontends/python/python/hegel/` and `/tmp/hegel/frontends/cpp/` before designing a behaviour. If `/tmp/hegel` is missing, clone `https://github.com/hegeldev/hegel` and check out `5195b0b` (F1). Engine behaviour that differs from upstream goes under Found, and to the owner.
- Every `.gd` file is statically typed. Public API carries `##` doc comments; other comments are one line and explain why.
- Every test runs against the real engine, seeded or derandomized, with the database off unless it is about the database. There is no coverage tool, so each plan's completion includes "break it, watch the test go red, restore it".
- A scenario that raises an error on purpose runs in a fresh process (`tests/support/error_scenarios.gd`, or `tests/subjects/` for a snapshot), since gdUnit4's own Logger reports script errors.
- `just check` passes at the end of every pass, and no test is switched off.
