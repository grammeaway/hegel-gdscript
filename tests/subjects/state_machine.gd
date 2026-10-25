extends "res://tests/support/subject.gd"


## The Counter of upstream's test_stateful.cpp, with its overflow as an invariant.
class _Counter:
	extends HegelStateMachine
	var count := 0

	func rule_add(tc: HegelTestCase) -> void:
		count += tc.draw(Gs.integers(1, 9), "amount")

	func invariant_below_12(tc: HegelTestCase) -> void:
		tc.check(count < 12, "count < 12")


func _run() -> void:
	Hegel.run(func(tc: HegelTestCase) -> void: _Counter.new().run(tc, 5), _settings())
