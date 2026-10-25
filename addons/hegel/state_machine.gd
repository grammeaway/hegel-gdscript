class_name HegelStateMachine
extends RefCounted
## Base class for state machine tests: the engine runs a sequence of rules,
## checking invariants along the way, and shrinks a failing sequence to a
## short one.
##
## Extend it with the machine's state as member variables, rules as methods
## named [code]rule_<name>[/code], and invariants as methods named
## [code]invariant_<name>[/code]. Each takes the [HegelTestCase], draws what it
## needs from it, and fails as a [method Hegel.run] body does: through
## [method HegelTestCase.check] or a runtime error. A rule whose
## [method HegelTestCase.assume] fails stops early, and the engine tries
## another rule; reject before changing the state. Make a fresh machine for
## each test case:
## [codeblock]
## class Counter:
##     extends HegelStateMachine
##     var count := 0
##
##     func rule_add(tc: HegelTestCase) -> void:
##         count += tc.draw(Gs.integers(1, 9), "amount")
##
##     func rule_reset(_tc: HegelTestCase) -> void:
##         count = 0
##
##     func invariant_below_100(tc: HegelTestCase) -> void:
##         tc.check(count < 100, "count < 100")
##
## func test_counter() -> void:
##     var result := Hegel.run(func(tc: HegelTestCase) -> void: Counter.new().run(tc))
##     assert_bool(result.passed).is_true()
## [/codeblock]

const _RULE_PREFIX := "rule_"
const _INVARIANT_PREFIX := "invariant_"


## Runs the machine on [param tc]: the invariants on the initial state, then up
## to [param steps] rules the engine chooses, then the invariants on the final
## state. Between rules the engine samples which invariants to check, each
## about once per test case. The failure report lists each step's rule and
## draws. A machine with no rules, a rule or invariant that doesn't take the
## test case, or [param steps] below 1 ends the run with a
## [constant HegelResult.ErrorKind.USAGE] error.
func run(tc: HegelTestCase, steps := 50) -> void:
	var rules := _methods(_RULE_PREFIX)
	var invariants := _methods(_INVARIANT_PREFIX)
	var usage := _usage_error(rules, invariants)
	if usage:
		var location := HegelTestCase._caller_location()
		tc._fail_run(HegelResult.ErrorKind.USAGE, "HegelStateMachine.run (%s): %s" % [location, usage])
		return
	var machine := tc._state_machine(
		_names(rules, _RULE_PREFIX), _names(invariants, _INVARIANT_PREFIX), steps
	)
	if invariants:
		tc.note("Checking invariants on the initial state.")
	if not _check_invariants(tc, invariants, null):
		return
	var rule_label := HegelTestCase._label("stateful.rule")
	var step := 0
	while true:
		tc._start_span(rule_label)
		if not machine.next_group():
			tc._stop_span()
			break
		var rejected := false
		var rule := machine.next_rule()
		while rule >= 0:
			step += 1
			var method: String = rules[rule]
			var name := method.trim_prefix(_RULE_PREFIX)
			tc.note("Step %d: %s {" % [step, name])
			tc._call_nested(Callable(self, method))
			if tc._reopen():
				machine.rule_rejected()
				rejected = true
				tc.note("  Rule stopped early due to violated assumption.")
			tc._note_always("}")
			if tc._ended:
				if tc._failed():
					tc._note_always("Rule %s failed:" % name)
				return
			rule = machine.next_rule()
		tc._stop_span(rejected)
		if not _check_invariants(tc, invariants, machine):
			return
	if tc._ended:
		return
	if invariants:
		tc.note("Checking invariants on the final state.")
	_check_invariants(tc, invariants, null)


## Runs the invariants the engine samples, or all of them without a
## [param machine], and returns whether the case is still live.
func _check_invariants(
	tc: HegelTestCase, invariants: PackedStringArray, machine: HegelTestCase._StateMachine
) -> bool:
	for index: int in invariants.size():
		if tc._ended:
			return false
		if machine and not machine.should_check_invariant(index):
			continue
		tc._call_nested(Callable(self, invariants[index]))
		if tc._failed():
			tc._note_always("Invariant %s failed:" % invariants[index].trim_prefix(_INVARIANT_PREFIX))
	return not tc._ended


## The names of this machine's methods starting with [param prefix], each once:
## the script's own first, in declaration order, then its base scripts'.
func _methods(prefix: String) -> PackedStringArray:
	var names: PackedStringArray = []
	for method: Dictionary in get_method_list():
		var name: String = method.name
		if name.begins_with(prefix) and not names.has(name):
			names.append(name)
	return names


func _usage_error(rules: PackedStringArray, invariants: PackedStringArray) -> String:
	if rules.is_empty():
		return "the machine has no rules; add a method rule_<name>(tc: HegelTestCase)"
	for method: Dictionary in get_method_list():
		var name: String = method.name
		var takes_tc: bool = (
			method.args.size() >= 1 and method.args.size() - method.default_args.size() <= 1
		)
		if (rules.has(name) or invariants.has(name)) and not takes_tc:
			return "%s must take the test case: func %s(tc: HegelTestCase)" % [name, name]
	return ""


static func _names(methods: PackedStringArray, prefix: String) -> PackedStringArray:
	var names: PackedStringArray = []
	for method: String in methods:
		names.append(method.trim_prefix(prefix))
	return names

