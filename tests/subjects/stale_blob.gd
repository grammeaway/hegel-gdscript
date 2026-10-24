extends "res://tests/support/subject.gd"


func _run() -> void:
	var silent := _settings()
	silent._silent = true
	var blob := Hegel.run(func(tc: HegelTestCase) -> void: tc.check(false), silent).failures[0].blob
	# Drawing more than the blob recorded overruns every replay.
	Hegel.replay(blob, _fails_from_10, _settings())
