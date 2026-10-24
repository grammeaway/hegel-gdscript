extends "res://tests/support/subject.gd"


func _run() -> void:
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			var xs: Array[int] = [tc.draw(Gs.integers(0, 9)), tc.draw(Gs.integers(0, 9))]
			tc.note("xs has %d elements" % xs.size())
			tc.note("first line\nsecond line")
			tc.check(xs[0] >= xs[1], "sorted output"),
		_settings()
	)
