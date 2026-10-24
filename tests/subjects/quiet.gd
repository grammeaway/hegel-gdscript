extends "res://tests/support/subject.gd"


func _run() -> void:
	var settings := _settings()
	settings.verbosity = HegelSettings.Verbosity.QUIET
	Hegel.run(_fails_from_10, settings)
