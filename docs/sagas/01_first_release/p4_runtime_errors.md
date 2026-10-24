# P4: Runtime errors fail the case

## Finding

GDScript has no exceptions. A runtime error in the code under test (calling a method on null, an index out of bounds, a failed `assert`, a `push_error`) aborts only the innermost function, which returns `null`, and execution carries on. The planning spike confirmed this in Godot 4.7.2 headless. After p3, such an error doesn't fail the case, so properties miss real bugs. The same spike showed that a `Logger` added with `OS.add_logger` receives each error, with a `ScriptBacktrace` giving file:line, from any thread. Godot always prints these errors to stderr too: muting them (`Engine.print_error_messages = false`) also stops loggers (F2).

## Change

- **`addons/hegel/error_capture.gd`**, an internal `Logger` subclass, guarded by a `Mutex` because `_log_error` can run on any thread. It is added at the start of `Hegel.run` / `Hegel.replay` and removed at the end, and it records errors only while a test body is running.
- **Policy (D11).** `ERROR_TYPE_SCRIPT` and `ERROR_TYPE_ERROR` (`push_error`, engine errors) are terminal events with status INTERESTING; `ERROR_TYPE_WARNING` and `ERROR_TYPE_SHADER` are ignored. The first terminal event still wins (D8): an error after a failed `check` changes nothing, and an error after a stop-test stays OVERRUN.
- **Origin.** `<error type>:<file>:<line>`, taken from the innermost frame of the first `ScriptBacktrace`. Without a backtrace, it falls back to the `file`/`line` arguments. The message stays out of the origin, since it carries values ("index '5'"). Errors at different lines are different bugs. The same line with different values is one bug, and shrinks to one report.
- **Report line**: `Error: <message> (<file>:<line>)` in place of `Check failed: …`, plus the backtrace's script frames, indented.
- **Engine-side error.** When the case also called `tc.check` before the error, the check's origin wins (it came first).

## Steps

1. Test-first, `tests/error_capture_test.gd`, running bodies through the in-process API:
   - a call on null in the body fails the case, and the report names the line;
   - an error two calls deep in code under test fails it, with the origin at the innermost frame;
   - `push_error` fails it; `push_warning` doesn't;
   - an `assert(false)` fails it;
   - two error sites give two different origins; the same site with different values gives one;
   - an error raised outside any body, between runs, isn't captured.
   gdUnit4's own Logger flags these errors too (F7). Run these scenarios as fresh-process subjects (p3's `subprocess.gd`) so the gdUnit4 test that drives them stays clean. Note in `AGENTS.md` that error scenarios always go in subjects.
2. Implement `error_capture.gd` and wire it into the run loop.
3. Thread case: an error raised from a `Thread` started by the body, and joined inside it, is captured. Check this works; if Godot doesn't deliver it, record what it does instead.
4. A snapshot subject for an error-caused failure.
5. Document F2 in `AGENTS.md`, and note it for p8's user docs: while shrinking an error-caused failure, Godot prints every repeat of the error to stderr. It is noise, not more failures.

## Completion

- [x] `just check` is green.
- [x] Removing `ERROR_TYPE_ERROR` from the policy turns the `push_error` test red. Check this, then restore it.
- [x] Putting the message into the origin turns the "same site, different values, one origin" test red. Check this, then restore it.
- [x] A subject whose property fails only through a runtime error shrinks it: for example `var a := [0]; a[x]` with `x` from `integers(0, 100)` reports `var draw_1 = 1`.

## Non-goals

- Muting Godot's stderr output (F2). The options (redirecting file descriptors in the native layer, a custom build) cost more than the noise. Record it if the owner wants it later.
- In-editor runs where the debugger breaks on errors. p8 checks and documents them.
