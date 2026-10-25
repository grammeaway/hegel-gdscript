# rc.1 dogfooding fixes: progress

Live log for `README.md`'s plans. One row per plan; details under Deviations and Found.

## Status

| Plan | Status | Base | Notes |
|---|---|---|---|
| p1 report on run errors | done | `b0e6a87` | `_announced` sets the report before its `_silent` check |
| p2 database key per test | planned | | |
| p3 draw name validation | planned | | |
| p4 expected errors | planned | | |
| p5 text alphabet | planned | | |
| p6 docs round | planned | | |

## Decisions

Decisions taken during passes, with who took them (owner or agent) and when. Planning decisions are D1–D8 in `README.md`.

- **p1, agent, 2026-10-25:** an errored result's report replaces whatever `_drive` built, so a run with both an error and failures reports the error, as D1 reads. The `CHANGELOG.md` entry goes under a new `### Changed` section, prefixed "Since `v0.1.0-rc.1`", since `Unreleased` still describes the whole first release.

## Deviations

Per plan: where the work differed from the plan, and why.

**p1**

- The four new error scenarios (unsatisfiable, usage, nested run, empty replay blob) share one test, `test_a_run_that_errors_reports_its_error`, with a helper asserting the exact line; the stale replay is asserted in its existing test. Separate tests pushed `report_test.gd` past gdlint's 20 public methods.
- Tests changed because they pinned the old behaviour on purpose, as the plan names: `test_report_is_empty_unless_the_run_failed` is now `test_a_passing_run_has_no_report` plus the error test, and `test_replay_of_a_fixed_failure_did_not_reproduce` asserts the error report instead of an empty one.
- Also updated `Hegel.run`'s doc comment: an errored run's pushed message is its report.

## Found

Bugs or debts found during a pass and kept out of its diff.
