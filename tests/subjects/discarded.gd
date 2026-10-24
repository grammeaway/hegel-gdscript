extends "res://tests/support/subject.gd"


func _run() -> void:
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			var x: int = tc.draw(Gs.integers(0, 1000))
			if not tc.assume(x % 2 == 1):
				return
			tc.check(x < 10, "x < 10"),
		_settings()
	)
