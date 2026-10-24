extends "res://tests/support/subject.gd"


func _run() -> void:
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			tc.draw(Gs.integers(0, 9))
			for i: int in 3:
				tc.draw(Gs.integers(i, 9), "x")
			tc.draw(Gs.integers(0, 9), "count")
			tc.draw(Gs.integers(0, 9))
			tc.check(false, "always"),
		_settings()
	)
