# Changelog

All notable changes to hegel-gdscript are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

The first release: a property-based testing addon for Godot 4.5 and newer, on Hegel's engine (libhegel 0.48.0), for Linux x86_64, Windows x86_64 and macOS arm64.

### Added

- `Hegel.run(body, settings)`: runs a property over many generated test cases, shrinks a failure to a minimal one, and returns a `HegelResult`.
- `HegelTestCase`: `draw`, `check`, `assume` and `note`. After a case's first failure or rejection, draws return simplest values, so the body can return early.
- Generators on `HegelGenerators`: `integers`, `floats`, `booleans`, `just`, `sampled_from`, `one_of`, `composite`, `lists`, `tuples`, `dictionaries` and `text`, plus `map`, `filter` and `flat_map` on every `HegelGenerator`.
- Failure reports with each draw, note and the failed check, and a blob that `Hegel.replay(blob, body)` replays.
- A failure database under `user://hegel/`, replaying past failures first.
- Runtime errors as failures: a script error, a `push_error` or an engine error in the body fails the case, from any thread.
- `HegelSettings`, read from Hegel's settings profile and `HEGEL_*` environment variables, with the `ci` profile on CI servers.
- `HegelStateMachine`: stateful tests from `rule_*` and `invariant_*` methods, shrunk to a short sequence of steps.
- A plain headless runner, `addons/hegel/cli/run.gd`, for projects without a test framework. It exits with 1, and says so, when the platform's native library is missing.
- Release zips holding `addons/hegel/` with the libraries for all three platforms.

### Changed

Since `v0.1.0-rc.1`:

- `HegelResult.report` holds the error line of a run that ended in an error, so `override_failure_message(result.report)` explains it too. It was empty.
