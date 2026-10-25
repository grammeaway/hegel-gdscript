# Changelog

All notable changes to hegel-gdscript are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] - 2026-10-25

The first release: a property-based testing addon for Godot 4.5 and newer, on Hegel's engine (libhegel 0.48.0), for Linux x86_64, Windows x86_64 and macOS arm64.

### Added

- `Hegel.run(body, settings)`: runs a property over many generated test cases, shrinks a failure to a minimal one, and returns a `HegelResult`.
- `HegelTestCase`: `draw`, `check`, `assume` and `note`. A draw's name, shown in the report, must be a GDScript identifier. After a case's first failure or rejection, draws return simplest values, so the body can return early.
- Generators on `HegelGenerators`: `integers`, `floats`, `booleans`, `just`, `sampled_from`, `one_of`, `composite`, `lists`, `tuples`, `dictionaries` and `text`, plus `map`, `filter` and `flat_map` on every `HegelGenerator`.
- Failure reports with each draw, note and the failed check, and a blob that `Hegel.replay(blob, body)` replays. `HegelResult.report` holds them, or the error of a run that went wrong, for `override_failure_message(result.report)`.
- A failure database under `user://hegel/`, replaying past failures first. Each test is keyed on the innermost `test_*` function calling `Hegel.run`, so tests sharing a helper that wraps it stay apart; `HegelSettings.database_key` sets the key, for a parameterized test's parameter sets.
- Runtime errors as failures: a script error, a `push_error` or an engine error in the body fails the case, from any thread.
- `HegelTestCase.expect_errors(fn)`: returns the errors logged while `fn` runs instead of failing the case on them, for properties of code that reports bad input with `push_error`. A script error still fails it.
- `HegelGenerators.text_from(alphabet, min_size, max_size)`: strings of `alphabet`'s characters only, shrinking as `text`'s do.
- `HegelSettings`, read from Hegel's settings profile and `HEGEL_*` environment variables, with the `ci` profile on CI servers.
- `HegelStateMachine`: stateful tests from `rule_*` and `invariant_*` methods, shrunk to a short sequence of steps.
- A plain headless runner, `addons/hegel/cli/run.gd`, for projects without a test framework. It exits with 1, and says so, when the platform's native library is missing.
- Release zips holding `addons/hegel/` with the libraries for all three platforms.
