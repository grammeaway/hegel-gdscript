# rc.1 dogfooding fixes: progress

Live log for `README.md`'s plans. One row per plan; details under Deviations and Found.

## Status

| Plan | Status | Base | Notes |
|---|---|---|---|
| p1 report on run errors | done | `b0e6a87` | `_announced` sets the report before its `_silent` check |
| p2 database key per test | done | `19ab72f` | Tests in a new `tests/database_test.gd` |
| p3 draw name validation | done | `c8f9b2b` | Tests in `tests/test_case_test.gd` |
| p4 expected errors | done | `7a96b8e` | `HegelTestCase._on_error` decides: collect or end |
| p5 text alphabet | planned | | |
| p6 docs round | planned | | |

## Decisions

Decisions taken during passes, with who took them (owner or agent) and when. Planning decisions are D1–D8 in `README.md`.

- **p1, agent, 2026-10-25:** an errored result's report replaces whatever `_drive` built, so a run with both an error and failures reports the error, as D1 reads. The `CHANGELOG.md` entry goes under a new `### Changed` section, prefixed "Since `v0.1.0-rc.1`", since `Unreleased` still describes the whole first release.

- **p2, agent, 2026-10-25:** the override is applied in `_guarded`, so `Hegel.replay` honours it too. The "other test" in the helper tests is a `test_neighbour` method on an inner class, which gdUnit4 doesn't collect; it takes the helper as a Callable, since an inner class can't call its outer script's static functions.

- **p3, agent, 2026-10-25:** the usage error reads `draw names must be GDScript identifiers, but got "<name>"`, with the name `c_escape`d so a newline in it can't split the pushed line. The check runs on every draw, nested ones included, since a generator's inner draws take names too.

- **p4, agent, 2026-10-25:** the capture hands every error to the case's `_on_error(script_error, message, origin, failure)`, which replaces `_fail_with_error`; the case collects under its `Mutex`. Nesting is one `PackedStringArray` and an open-call count: each call returns the slice past where it started, and truncates it back. An error's message is the report's (`rationale`, else `code`). The guide's subsection is a bold-lead paragraph under Runtime errors, as the guide's other subsections are, and also says gdUnit4's `report/godot/push_error` setting still counts expected errors. The `CHANGELOG.md` entry sits in `Added`, marked new since `v0.1.0-rc.1`.

## Deviations

Per plan: where the work differed from the plan, and why.

**p1**

- The four new error scenarios (unsatisfiable, usage, nested run, empty replay blob) share one test, `test_a_run_that_errors_reports_its_error`, with a helper asserting the exact line; the stale replay is asserted in its existing test. Separate tests pushed `report_test.gd` past gdlint's 20 public methods.
- Tests changed because they pinned the old behaviour on purpose, as the plan names: `test_report_is_empty_unless_the_run_failed` is now `test_a_passing_run_has_no_report` plus the error test, and `test_replay_of_a_fixed_failure_did_not_reproduce` asserts the error report instead of an empty one.
- Also updated `Hegel.run`'s doc comment: an errored run's pushed message is its report.

**p2**

- The new tests live in a new suite, `tests/database_test.gd`, not `tests/report_test.gd`: the latter sits at 18 tests, and three more pass gdlint's 20 public methods. `test_database_replays_a_stored_failure_first` and `_remove_tree` moved there with them, and the suite clears its database before and after each test.
- Red on `19ab72f`: all three new tests failed (headers read `::_through_helper`, and the neighbour replayed the helper's stored `x = 10`). With the derivation fixed and the override ignored, only the override test failed. Restored.
- `hegel_test.gd`'s profile test also asserts `database_key` starts `""`.
- The guide also notes that the key seeds a derandomized run (`hegel_settings_set_derandomize` hashes it), so a parameterized test's key changes its `ci` inputs too.

**p3**

- Red on `c8f9b2b`: `test_a_draw_name_that_isnt_an_identifier_is_a_usage_error` failed for all three names (no error, 100 random draws). `test_identifier_draw_names_and_unnamed_draws_are_shown` passed on the old code, as a guard should; it also covers `"émoji"`. Breaking the empty-name guard turned it and four other tests red. Restored.
- `AGENTS.md`'s invalid-arguments bullet names the draw-name check too.

**p4**

- The guide snippet fails under the plain runner with collection broken, and passes with it restored.
- Red against a stub `expect_errors` that only calls `fn` (the method had to exist for the scenario script to parse): five scenarios failed on the error they expected; `script_error_in_expect_errors` passed, as a guard should. With the feature in, all six pass. Collecting script errors too turned `script_error_in_expect_errors` red; collecting nothing turned the other five red. Restored.
- A script error inside `fn` lists the addon's `expect_errors` frame in the report's backtrace, between the user's frames. Left as is: it is where the call went, and the origin still skips addon frames.

## Found

Bugs or debts found during a pass and kept out of its diff.
