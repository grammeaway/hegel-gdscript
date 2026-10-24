class_name HegelResult
extends RefCounted
## The outcome of [method Hegel.run]: it passed, it found failures, or the run
## itself ended in an error.

## Why a run ended in an error.
enum ErrorKind {
	NONE = 0,  ## The run didn't error.
	HEALTH_CHECK = 1,  ## A health check failed. See [enum HegelSettings.HealthCheck].
	FLAKY = 2,  ## The test gave different outcomes for the same input.
	NONDETERMINISTIC = 3,  ## Generation diverged when the same input was replayed.
	UNSATISFIABLE = 4,  ## No valid test case was found: every one was rejected.
	USAGE = 5,  ## Hegel was misused. [member error] says what to fix.
	INTERNAL = 6,  ## A bug in Hegel.
	## [method Hegel.replay]'s blob didn't fail. Unlike the others, this kind
	## comes from hegel-gdscript, not from the engine.
	DID_NOT_REPRODUCE = 7,
}


## One distinct failure the run found, after shrinking.
class Failure:
	extends RefCounted
	## What the failure is grouped by: its kind and where in the code it happened.
	var origin: String
	## Encodes the failing test case, for replaying it.
	var blob: String
	## How reliably the failure reproduced, when it didn't every time; otherwise "".
	var caveat: String


## True when every test case passed.
var passed: bool
## The distinct failures found, in the engine's order. Empty unless the run failed.
var failures: Array[Failure] = []
## Why the run ended in an error. [constant ErrorKind.NONE] unless it did.
var error_kind := ErrorKind.NONE
## What went wrong, when the run ended in an error; otherwise "".
var error: String
## How many times the test body ran, counting rejected cases and shrinking.
var test_cases: int
## The failure report for each of [member failures], in order: the shrunk
## draws and notes, what failed, and how to replay it. "" unless the run failed.
var report: String


static func _errored(kind: ErrorKind, message: String, test_cases_run := 0) -> HegelResult:
	var result := HegelResult.new()
	result.error_kind = kind
	result.error = message
	result.test_cases = test_cases_run
	return result


static func _from_native(native: HegelNativeRunResult, test_cases_run: int) -> HegelResult:
	var result := HegelResult.new()
	result.test_cases = test_cases_run
	result.passed = native.status() == HegelNativeRunResult.RUN_STATUS_PASSED
	result.error_kind = native.error_kind() as ErrorKind
	result.error = native.error()
	for i: int in native.failure_count():
		var failure := Failure.new()
		failure.origin = native.failure_origin(i)
		failure.blob = native.failure_blob(i)
		failure.caveat = native.failure_caveat(i)
		result.failures.append(failure)
	return result
