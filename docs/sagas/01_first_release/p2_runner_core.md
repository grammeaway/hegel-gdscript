# P2: Runner core

## Finding

After p1, GDScript can drive the engine only through the raw native classes. There's no `Hegel.run`, no test-case API, no generator protocol, and no way to fail a case without exceptions. Every later plan, and every quality test, needs these.

## Change

The user-facing core, in `addons/hegel/`:

- **`HegelSettings`** (`settings.gd`, RefCounted): `test_cases`, `seed` (with `has_seed`), `derandomize`, `database` (default `user://hegel/`, globalized; `""` disables it, D12), `verbosity`, `suppress_health_checks`. Unset fields keep the engine's defaults, so `HEGEL_*` environment variables and the `ci` profile still apply (`hegel_settings_new`). Mirror `frontends/python/python/hegel/settings.py` for names and defaults.
- **`HegelResult`** (`result.gd`): `passed: bool`, `error: String`, `error_kind: int`, `failures: Array` (each with its origin, blob and caveat), `test_cases: int`. p3 adds the report.
- **`HegelTestCase`** (`test_case.gd`):
  - user API: `draw(generator, name := "") -> Variant`, `assume(condition) -> bool`, `check(condition, message := "") -> bool`, `note(message)`. `draw` wraps each generator's draw in a span with its label, as `TestCase.draw_silent` does in the Python frontend;
  - internal primitives for generators: `_draw_integer`, `_start_span`, `_stop_span`. Later plans add floats, collections and strings here. These are the only callers of the native test case;
  - **terminal events and simplest mode (D8).** The first terminal event sets the status and the origin. After it, every primitive returns its simplest value without calling the engine. A primitive whose call returns `HEGEL_E_STOP_TEST` is itself a terminal event (OVERRUN), and `HEGEL_E_ASSUME` is one too (INVALID). Any other error code ends the run with a usage or internal error, never a counterexample;
  - `check` failure origin: `check:` plus the caller's `source:line` from `get_stack()` (D11's rule: the message never goes into the origin).
- **`HegelGenerator`** (`generator.gd`): base class with `label: int` and a virtual `_draw(tc) -> Variant`. `HegelGenerators.integers(min_value, max_value)` (`generators.gd`), defaulting to the full int64 range, with label `hegel-gdscript.integers`.
- **`Hegel`** (`hegel.gd`): `static func run(body: Callable, settings: HegelSettings = null) -> HegelResult`. The loop: `next_test_case`, call `body.call(tc)`, then `mark_complete` with the status from the terminal event (VALID if there was none). Drain engine output after each call and print it. Then read the result: PASSED, FAILED, or ERROR with its kind and message (health check, unsatisfiable, flaky, usage, internal).
- **Nested runs.** A `Hegel.run` inside a running body is a usage error: the inner run returns an errored `HegelResult` and engine state is untouched. Keep run state per run, not in globals, so lifting this later is cheap.

## Steps

1. Read `frontends/python/python/hegel/runner.py` (`_run_test_case`, `_drive_run`), `test_case.py` and `settings.py`, and `frontends/cpp/src/hegel.cpp`, for the loop and the status mapping.
2. Write `tests/support/quality.gd`, after `frontends/cpp/tests/common/utils.h`:
   - `assert_all_examples(gen, predicate, test_cases := 100)`;
   - `find_any(gen, predicate, max_attempts := 300)`;
   - `minimal(gen, predicate, test_cases := 100)`: derandomized, database disabled; returns the shrunk value, captured from the final failing case.
   - Note on F7: these helpers make cases fail on purpose through `tc.check` alone, so gdUnit4's Logger sees no errors.
3. Test-first, `tests/hegel_test.gd` and `tests/test_case_test.gd`:
   - lifecycle: a passing body passes and runs `test_cases` cases; a failing `check` fails with one failure and a blob; `assume(false)` everywhere gives an ERROR result of kind unsatisfiable. The OVERRUN mapping is tested in p3, where replaying a blob with a body that draws past its recording is a cheap stop-test trigger. The other route, drawing past the 2^20-choice limit, costs about a million native calls per case;
   - terminal events: the first one wins (a failed `check` then `assume(false)` stays INTERESTING); after a terminal event, draws return simplest values with no engine calls;
   - nested `Hegel.run` returns a usage error;
   - settings: the same seed gives the same draws; `test_cases = 7` runs at most 7 valid cases.
4. Port the integer quality tests from `frontends/cpp/tests/shrink_quality/test_integers.cpp` and `find_quality/test_integers.cpp` into `tests/quality/integers_test.gd`. Skip the ones needing lists; p6 ports those.
5. `##` doc comments on every public member. Update `AGENTS.md`'s architecture section: the run loop, terminal events, simplest mode.

## Completion

- [ ] `just check` is green.
- [ ] `minimal(integers(), x > 100)` returns `101`, `minimal(integers(101, max), true)` returns `101`, and `minimal(integers(), true)` returns `0`.
- [ ] Making simplest mode call the engine anyway turns a test red. A failed `check` enters simplest mode the same way a stop-test does, so it can stand in for one here. Check this, then restore it.
- [ ] Making the last terminal event win instead of the first turns a test red. Check this, then restore it.
- [ ] `grep -rn "HegelNative" addons/hegel/ --include=*.gd` lists only `hegel.gd`, `settings.gd`, `result.gd` and `test_case.gd`.

## Non-goals

- The failure report, draw names, database key, replay (p3).
- Runtime-error capture (p4).
- Generators beyond `integers` (p5, p6).
- `target`, events and statistics, explicit examples: upstream has them, and they're out of this saga.
