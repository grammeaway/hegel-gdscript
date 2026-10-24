extends SceneTree
## Base for the scripts in tests/subjects/: each runs one scenario in a fresh
## Godot process, and its output is compared with tests/approvals/.

const Gs := preload("res://addons/hegel/generators.gd")


func _initialize() -> void:
	_run()
	quit()


## The scenario. Subjects override it.
func _run() -> void:
	pass


## Seeded, loud settings with the database disabled.
func _settings() -> HegelSettings:
	var settings := HegelSettings.new()
	settings.seed = 1
	settings.has_seed = true
	settings.database = ""
	return settings


func _fails_from_10(tc: HegelTestCase) -> void:
	var x: int = tc.draw(Gs.integers(0, 1000))
	tc.check(x < 10, "x < 10")
