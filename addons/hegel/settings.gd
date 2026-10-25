class_name HegelSettings
extends RefCounted
## Configuration for [method Hegel.run].
##
## A new [HegelSettings] starts from the engine's default profile: the
## [code]development[/code] profile locally, [code]ci[/code] on a CI server, with any
## [code]HEGEL_*[/code] environment variables applied over it. Change the fields you
## need before passing it to [method Hegel.run].
## [codeblock]
## var settings := HegelSettings.new()
## settings.test_cases = 500
## Hegel.run(func(tc: HegelTestCase) -> void: ..., settings)
## [/codeblock]

## How much the engine prints during a run.
enum Verbosity {
	NORMAL = 0,  ## A short summary per run. The default.
	QUIET = 1,  ## Nothing besides the result.
	VERBOSE = 2,  ## Also each test case as it runs.
	DEBUG = 3,  ## Also the shrinker's trace.
}

## Health checks, as bit flags for [member suppress_health_checks].
enum HealthCheck {
	FILTER_TOO_MUCH = 1,  ## Too many test cases are rejected.
	TOO_SLOW = 2,  ## Test cases take too long.
	TEST_CASES_TOO_LARGE = 4,  ## Test cases routinely hit the limit on choices.
	LARGE_INITIAL_TEST_CASE = 8,  ## The smallest test case is already very large.
}

## Where failing examples are stored when the profile leaves the database at
## the engine's default location.
const DEFAULT_DATABASE := "user://hegel/"

## How many valid test cases to run. Rejected test cases don't count.
var test_cases: int
## The seed for a reproducible run. Used only when [member has_seed] is true.
var seed: int
## Whether [member seed] is used. Without a seed each run starts from a fresh one.
var has_seed: bool
## Derive a fixed seed from the test, so every run of it is the same.
var derandomize: bool
## Keep looking for failures after the first, and report each distinct one:
## failures in different places in the code are different bugs. When false,
## only the smallest failure found is shrunk and reported.
var report_multiple_failures: bool
## The directory failing examples are saved to and replayed from, as a
## [code]user://[/code], [code]res://[/code] or absolute path. [code]""[/code]
## disables the database.
var database: String
## The key failures are stored under in [member database]. [code]""[/code], the
## default, derives it from the innermost [code]test_*[/code] function calling
## [method Hegel.run], or the direct caller without one. Set it to keep apart
## runs that share a function, like a parameterized test's parameter sets.
var database_key: String
## How much the engine prints during a run.
var verbosity: Verbosity
## A bitwise OR of [enum HealthCheck] flags not to fail the run on.
var suppress_health_checks: int
# Internal: neither prints the report nor raises push_error, for the addon's own tests.
var _silent := false


func _init() -> void:
	var native := HegelNativeSettings.new()
	test_cases = native.get_test_cases()
	seed = native.get_seed()
	has_seed = native.has_seed()
	derandomize = native.get_derandomize()
	report_multiple_failures = native.get_report_multiple_failures()
	var engine_database: Variant = native.get_database()
	database = DEFAULT_DATABASE if engine_database == null else engine_database
	verbosity = native.get_verbosity() as Verbosity
	suppress_health_checks = native.get_suppress_health_check()


## A native settings handle with every field set, and [param database_key]
## ("" for none). Check its [code]last_result[/code]:
## on failure it holds the first failing call's result and message.
func _to_native(database_key: String) -> HegelNativeSettings:
	var native := HegelNativeSettings.new()
	if native.last_result != HegelNative.OK:
		return native
	var path := ProjectSettings.globalize_path(database) if database else ""
	var steps: Array[Callable] = [
		native.set_test_cases.bind(test_cases),
		native.set_seed.bind(seed, has_seed),
		native.set_derandomize.bind(derandomize),
		native.set_report_multiple_failures.bind(report_multiple_failures),
		native.set_database.bind(path),
		native.set_database_key.bind(database_key),
		native.set_verbosity.bind(verbosity),
		native.set_suppress_health_check.bind(suppress_health_checks),
	]
	for step: Callable in steps:
		if step.call() != HegelNative.OK:
			break
	return native
