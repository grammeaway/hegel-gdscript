extends "res://tests/support/subject.gd"


func _run() -> void:
	var settings := _settings()
	settings.test_cases = 3
	settings.verbosity = HegelSettings.Verbosity.VERBOSE
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			tc.note("a note")
			tc.draw(Gs.integers(0, 9)),
		settings
	)
