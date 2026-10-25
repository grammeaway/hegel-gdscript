extends RefCounted
## The property `just smoke-package` runs in a fresh project with the packaged addon.

const Gs := preload("res://addons/hegel/generators.gd")


func test_reversing_twice_gives_the_original() -> void:
	var settings := HegelSettings.new()
	settings.derandomize = true
	settings.database = ""
	Hegel.run(
		func(tc: HegelTestCase) -> void:
			var xs: Array = tc.draw(Gs.lists(Gs.integers()))
			var twice := xs.duplicate()
			twice.reverse()
			twice.reverse()
			tc.check(twice == xs),
		settings
	)
