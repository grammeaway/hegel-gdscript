extends GdUnitTestSuite
## Each script in tests/subjects/ runs in a fresh process, and its scrubbed
## output must equal tests/approvals/<name>.approved.txt. A mismatch writes
## <name>.received.txt beside it; to accept the change, copy it over the approved file.

const Subprocess := preload("res://tests/support/subprocess.gd")
const SUBJECTS := "res://tests/subjects/"
const APPROVALS := "res://tests/approvals/"


func test_subjects_match_their_approved_output() -> void:
	var subjects := Array(DirAccess.get_files_at(SUBJECTS)).filter(
		func(file: String) -> bool: return file.get_extension() == "gd"
	)
	assert_array(subjects).is_not_empty()
	var mismatched: Array[String] = []
	for file: String in subjects:
		var name := file.get_basename()
		var outcome := Subprocess.run(SUBJECTS + file)
		assert_int(outcome.exit_code).override_failure_message(name + " exited non-zero").is_zero()
		var received := APPROVALS + name + ".received.txt"
		if outcome.output == FileAccess.get_file_as_string(APPROVALS + name + ".approved.txt"):
			DirAccess.remove_absolute(received)
			continue
		mismatched.append(name)
		FileAccess.open(received, FileAccess.WRITE).store_string(outcome.output)
	assert_array(mismatched).override_failure_message(
		"Output differs from the approved file, see tests/approvals/*.received.txt: %s" % [mismatched]
	).is_empty()
