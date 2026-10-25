# P2: Database key per test

## Finding

`Hegel._caller_key()` (`hegel.gd:245`) keys the database on `get_stack()[2]`, the function that called `run` or `replay`. When a project helper wraps `Hegel.run`, every test that uses it shares the helper's key. Each test then replays the others' saved failures, decoded against its own generators: the source saw `Falsified after 1 test case` on a test whose property held, and both reports were headed `::_wrapped`. Parameterized gdUnit4 tests share one key across parameter sets too. Wrapping `Hegel.run` is the first thing a gdUnit4 suite does, to keep the assert in one place.

The planning probe found that under gdUnit4 the test's own frame is `test_<name>`, that none of gdUnit4's frames start with `test_`, and that a parameterized test shows the same frame for every parameter set. The plain runner runs `test_*` methods too. Upstream C++ keys on the framework's test name, and lets `Settings::database_key` override it (`frontends/cpp/src/hegel.cpp:168`).

## Change

D2:
- The derived key is `<source>::<function>` of the innermost frame, from `run` outwards, whose function starts with `test_`. Without one, it falls back to `run`'s direct caller (today's behaviour, which the subjects in `tests/subjects/` rely on). Without a stack, it is `""`.
- `HegelSettings.database_key: String`, default `""`: when set, it is the key. It has a `##` doc that names the parameterized-test case.
- The report header (`--- Failure: <key> ---`) names the key in use.

The native `set_database_key` already exists, so this plan changes no Rust.

## Steps

1. Write the regression tests in `tests/report_test.gd`, with a database under `user://` that each test removes:
   - Two tests running different properties through one helper get different keys. Read the keys from the report headers (`_settings()` is silent, but `report` is filled). Then test the replay itself: store a failure through the helper from test A, run a passing property through the same helper from test B on the same database, and assert that B passes.
   - The header names the `test_*` function when the call goes through a helper.
   - `settings.database_key = "x"` gives header `--- Failure: x ---`, and two runs with different overrides from one test don't replay into each other.
   Watch them go red.
2. Implement the derivation in `_caller_key` and the override where `_guarded` gets its key. Keep the snapshot subjects' headers unchanged: they call from `_run`, with no `test_` frame.
3. Add `database_key` to `HegelSettings`, with its doc. `_init` leaves it `""`; the engine profile has no key.
4. Docs: the guide's Failures paragraph on the database ("keyed by the calling script and function") and its header sentence; the settings field list in Writing properties; `AGENTS.md`'s Run loop line on the key; `CHANGELOG.md`.

## Completion

- [ ] The helper tests are red on `b0e6a87` and green after.
- [ ] Break the derivation (`stack[2]` again): the helper tests go red. Break the override (ignore it): its test goes red. Restore both.
- [ ] All approved snapshots unchanged.
- [ ] `just check` green.

## Non-goals

- Reading gdUnit4's own test or parameter names: the `test_` frame keeps the addon free of gdUnit4.
- `hegel_settings_set_test_location` (P3.9 stands).
