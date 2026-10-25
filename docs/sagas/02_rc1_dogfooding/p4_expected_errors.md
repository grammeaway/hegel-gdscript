# P4: Expected errors

## Finding

Code under test often reports bad input with `push_error`. A property over the reject path has to call it, and `error_capture.gd` fails the case on every `ERROR_TYPE_ERROR` and `ERROR_TYPE_SCRIPT`. The only escape is `Engine.print_error_messages = false`, which stops Godot calling loggers at all (saga 01's F2). That escape has three costs: it is documented only in `AGENTS.md`; it hides real script errors in the muted call; and the property can't check that the expected error happened, or what it said. Suites that already mute errors around expected `push_error`s silently stop counting runtime errors inside those calls.

Upstream has no equivalent: Python and C++ raise exceptions, and the test framework expects them (`pytest.raises`). This is GDScript's counterpart.

## Change

D4: `tc.expect_errors(fn: Callable) -> PackedStringArray`.

- It calls `fn` with no arguments and returns the messages of the `ERROR_TYPE_ERROR` errors logged while `fn` ran: `push_error` and the engine's own errors. These are logged instead of failing the case. Each message is the one the report would show (`rationale`, else `code`).
- A script error inside `fn` still fails the case, as anywhere else in the body.
- Errors from any thread count while `fn` runs, as the capture already works (the `shortcut:` in `error_capture.gd`).
- Calls nest: an error belongs to the innermost call.
- After the case has ended, it still calls `fn` and returns what it collected, so a body in simplest mode runs on as before.
- Godot still prints the collected errors to stderr. A gdUnit4 project with `report/godot/push_error` on still has gdUnit4 count them.

**Design hint:** have the capture hand every error to the case, and let the case decide, collecting or ending. That keeps the policy in `test_case.gd` and the native-touching rule intact (`error_capture.gd` already calls `tc._fail_with_error`). The case's `Mutex` guards the collector, since errors arrive from other threads.

## Steps

1. Write the tests first, in fresh processes, since they raise errors on purpose: add scenarios to `tests/support/error_scenarios.gd` and their checks to `tests/error_capture_test.gd`:
   - `push_error` inside `expect_errors`: the run passes, and the returned array holds the message;
   - a script error inside `expect_errors` still fails the case, at its location;
   - a `push_error` after `expect_errors` returns still fails the case;
   - an engine error (`get_node` on a missing path, say) is collected;
   - a `push_error` from a thread started inside `fn` and joined before it returns is collected;
   - nested calls each return their own errors.
   Watch them go red: the method doesn't exist yet, so first confirm each scenario fails for the expected reason.
2. Implement.
3. Docs: the `##` doc with an example; a guide subsection under Runtime errors ("Expected errors") showing a reject-path property that checks the message. It names the `Engine.print_error_messages` trap: muting skips Hegel's capture too, so script errors in the muted call go unseen. Add `CHANGELOG.md` (`Added`), and `AGENTS.md`'s Runtime errors bullet.

## Completion

- [x] Each scenario's check passes, and fails with the feature broken: collect script errors too, then don't collect at all. Restore it.
- [x] The guide snippet runs under `tests/docs_test.gd`.
- [x] `just check` green. CI's floor job (Godot 4.5) is left to the owner's push.

## Non-goals

- Filtering by thread (the existing `shortcut:` stands).
- Muting Godot's printing of collected errors: it can't be done while loggers still see them (F2).
- Expecting warnings, which never fail a case.
