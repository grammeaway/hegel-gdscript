extends "res://tests/support/subject.gd"


func _run() -> void:
	Hegel.run(_out_of_bounds, _settings())


func _out_of_bounds(tc: HegelTestCase) -> void:
	var a := [0]
	var x: int = tc.draw(Gs.integers(0, 100))
	a[x] = 1
