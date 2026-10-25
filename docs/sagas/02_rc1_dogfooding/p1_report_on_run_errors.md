# P1: Report on run errors

## Finding

A run that ends in an error (a usage error, a failed health check, a flaky test, `DID_NOT_REPRODUCE`) returns `passed == false` with `report == ""`. `HegelResult._errored` and `_from_native` set no report, and `Hegel._drive` builds `report` from failures only (`hegel.gd:186`). The documented gdUnit4 idiom, `assert_bool(result.passed).override_failure_message(result.report).is_true()` (README:63, guide:323, `examples/gdunit4/inventory_test.gd:27,36`), then fails with an empty message. The error reaches only `push_error`, which gdUnit4 ignores by default.

## Change

D1: whenever `error_kind != NONE`, `report` is `Hegel run error (<KIND>): <message>`, the line `_announced` pushes today (P3.8). Set it in one place that every path passes through: `_announced` is called for the nested-run error, the empty replay blob, and every `_guarded` result. It sets the report before its `_silent` check, so silent runs get it too, then pushes `result.report`. The pushed text is unchanged, so `tests/approvals/run_error.approved.txt` should stay as it is.

## Steps

1. Write the regression tests in `tests/report_test.gd`: an unsatisfiable run (`tc.assume(false)`), a usage error (`Gs.sampled_from([])`), a nested run, `Hegel.replay("")`, and a stale replay each have `report == "Hegel run error (<KIND>): " + error`. A passing run's report stays `""`. Watch them go red.
2. Change `test_report_is_empty_unless_the_run_failed` (`report_test.gd:61`) and the `is_empty()` assert at `:219`: they pinned the old behaviour on purpose. Note it in `progress.md`.
3. Implement in `hegel.gd`'s `_announced`.
4. Update `HegelResult.report`'s doc comment: it explains any result that didn't pass. Update the guide's `HegelResult` sentence ("…and the `report`"), the gdUnit4 paragraph under Running the tests, and `CHANGELOG.md` (`Changed`).

## Completion

- [x] The new tests are red on `b0e6a87`'s `hegel.gd` and green after.
- [x] Break it (set the report after the `_silent` return): the silent tests go red. Restore it.
- [x] `run_error.approved.txt` unchanged.
- [x] `just check` green.

## Non-goals

- Changing what is printed or pushed for a failure or an error.
- A gdUnit4 assert helper (P8.3 still holds).
