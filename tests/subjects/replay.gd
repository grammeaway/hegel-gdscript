extends "res://tests/support/subject.gd"


func _run() -> void:
	var silent := _settings()
	silent._silent = true
	var blob := Hegel.run(_fails_from_10, silent).failures[0].blob
	Hegel.replay(blob, _fails_from_10, _settings())
