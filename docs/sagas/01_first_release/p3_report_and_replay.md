# P3: Failure report and replay

## Finding

After p2, a failing run says *that* it failed, and gives an origin and a blob. It doesn't say *with what*. Hegel's frontends print a framed report built from the final replay: the shrunk draws, the notes, the failure, a caveat if one applies, and a line to rerun the failure. PLAN item 5 asks for this and for `Hegel.replay(blob, body)`. The database key (D12) is also still unset, so the engine never replays stored failures.

## Change

- **Capture.** Read `should_capture` once at the start of each case. While the body runs, buffer the case's lines: draw lines, notes, and the failure line. Keep the buffer per origin, ranked as `_Captured.rank` in `frontends/python/python/hegel/runner.py` ranks it: stamped over unstamped, newest at equal rank. At the end, build one report per failure from its origin's capture. A failure whose origin was never captured is an internal error, as in Python.
- **Draw lines.** Each top-level `tc.draw` adds `var <name> = <var_to_str(value)>`. Unnamed draws are `draw_1`, `draw_2`, … in order. A named draw uses its name, and a repeated name gets `_2`, `_3`. Draws inside a generator (nested `tc.draw` from `composite`, say) print nothing. Copy the counting rules from `frontends/python/python/hegel/_draw_names.py` and the C++ `DrawNames` approvals in `frontends/cpp/tests/approvals/`.
- **Report format**, adapted from the C++ approvals (`test_printing.FailureReport.*`):

  ```
  --- Failure: res://tests/foo_test.gd::test_bar ---
  Falsified after 3 test cases (1 discarded):

    var draw_1 = [0, 1]
    xs has 2 elements

  Check failed: sorted output (res://tests/foo_test.gd:14)
  note: <caveat, when there is one>
  Reproduce with: Hegel.replay("<blob>", <body>)
  ```

  "Falsified after N" counts up to the first failing case, as upstream does. Quiet verbosity drops the indented lines. Verbose prints each case's lines live as well.
- **`HegelResult.report: String`.** It holds every failure's report, in the engine's order.
- **Database key** (D12): `<source>::<function>` of the frame calling `Hegel.run`, from `get_stack()`. No key when the stack is empty. The test location goes through `hegel_settings_set_test_location` if `get_stack()` gives what it needs.
- **`Hegel.replay(blob: String, body: Callable, settings: HegelSettings = null) -> HegelResult`**, through a new native `HegelNativeRun.start_blob` (`hegel_run_start_blob`). A replay that passes returns an errored result saying the blob didn't reproduce, with the message from `_drive_blob_replay` in the Python frontend.
- **Who prints the report.** Ask the owner before building this part. The recommendation: `Hegel.run` returns the result *and*, on failure, prints the report to stderr with `printerr` and raises a one-line `push_error`. A user who ignores the result still sees the failure, and gdUnit4 marks the test failed (F7). The quality helpers (p2) then need a quiet path, such as an internal setting that skips both.

## Steps

1. Ask the owner the printing question, and record the answer.
2. Native: `start_blob`. Add `hegel_test_case_from_blob` only if a step below turns out to need it.
3. Capture, draw names and report, test-first, in `tests/report_test.gd`, using results in-process.
4. Snapshot tests in a fresh process (D1c):
   - `tests/subjects/`: small `SceneTree` scripts, one scenario each: a single failure, notes, named and repeated draws, a discarded case counted, quiet verbosity, replay of a blob, a stale blob;
   - `tests/support/subprocess.gd` runs one with `OS.execute(OS.get_executable_path(), ["--headless", "--path", <project>, "-s", <subject>], output, true)` and returns its exit code and its scrubbed output. Scrub blobs to `[blob]`, absolute paths to `[path]`, and the Godot banner;
   - `tests/approvals/<name>.approved.txt` holds the expected output. A mismatch writes `<name>.received.txt` next to it and fails. To accept a change, copy the received file over the approved one; document this in `AGENTS.md`.
5. OVERRUN, deferred from p2: replay a blob with a body that draws more than the blob recorded. The case ends OVERRUN, and the stale-blob message is shown.
6. Database: with a database path in a temp directory, a failing run stores the failure, and the next run with the same key replays it first (it fails in its first case).

## Completion

- [ ] `just check` is green.
- [ ] Every subject's approved file is committed and matches.
- [ ] Changing the draw-line prefix from `var ` to `let ` turns the snapshot tests red with `.received.txt` files. Check this, then restore it.
- [ ] `Hegel.replay(<blob from a failing run>, body)` fails with the same report body, and passes, with the stale-blob error, once the body is fixed.
- [ ] Removing the database key turns the database test red. Check this, then restore it.

## Non-goals

- Runtime-error failures in the report (p4).
- The engine's pretty-printer API (`hegel_printer_*`). Values print with `var_to_str`.
- Reporting several failures at once (`report_multiple_failures`). Keep the engine default, and record if the owner wants it on.
