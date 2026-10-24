extends "res://tests/support/subject.gd"


func _run() -> void:
	Hegel.run(func(tc: HegelTestCase) -> void: tc.draw(Gs.integers(5, 1)), _settings())
