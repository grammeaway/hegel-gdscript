# P3: Draw name validation

## Finding

`tc.draw(gen, "good lines")` reports `var good lines = []`, which isn't GDScript. `HegelTestCase.draw` (`test_case.gd:55`) passes any name to `_display_name`. Upstream C++ doesn't check names; Python infers them from assignment targets, so they are always identifiers.

## Change

D7: a non-empty name that fails `String.is_valid_unicode_identifier()` ends the run through `tc._fail_run(HegelResult.ErrorKind.USAGE, …)`, with a message naming the name, as `_Invalid` does for generator arguments. Check it at the top of `draw`, before any engine call, so a bad name fails on the first draw whether or not the case records. Godot 4.5, the `compatibility_minimum`, has the method; CI's `floor` job confirms it.

## Steps

1. Write the tests in `tests/report_test.gd`, or `tests/test_case_test.gd` if the draw tests live there: `"good lines"`, `"1x"` and `"a-b"` give a `USAGE` result whose `error` names the name; `"x"`, `"_x"` and `"x_2"` still work, and unnamed draws are unaffected. Watch them go red.
2. Implement in `draw`. The usage error ends the run; the body then runs on in simplest mode, so `draw` still returns the generator's simplest value.
3. Update `draw`'s `##` doc, the guide's `tc.draw` bullet, and `CHANGELOG.md`.

## Completion

- [ ] The tests are red before and green after.
- [ ] Break it (drop the check): red. Restore it.
- [ ] `just check` green; CI's floor job green on push.

## Non-goals

- Sanitizing names, or checking that a name isn't a GDScript keyword.
