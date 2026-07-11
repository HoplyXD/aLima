extends GutTest

## Tests for the UiAudio mix policy (the autoloaded UI hover-sound system). Only the
## pure, headless-safe helpers are exercised here — clip selection and the per-kind
## volume mapping — so the suite never needs an audio device or a playing stream.

const UiAudioScript := preload("res://scripts/ui/ui_audio.gd")

const HOVER := UiAudioScript.Kind.HOVER
const PRESSED := UiAudioScript.Kind.PRESSED
const LOCKED := UiAudioScript.Kind.LOCKED
const CLACK := UiAudioScript.Kind.CLACK


func test_pick_next_index_handles_empty_and_single() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	assert_eq(UiAudioScript.pick_next_index(-1, 0, rng), -1, "empty set returns -1")
	assert_eq(UiAudioScript.pick_next_index(-1, 1, rng), 0, "single clip always returns 0")


func test_pick_next_index_never_repeats_back_to_back() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var last := -1
	for i in 200:
		var index := UiAudioScript.pick_next_index(last, 3, rng)
		assert_true(index >= 0 and index < 3, "index stays inside the clip range")
		if last >= 0:
			assert_ne(index, last, "no clip plays twice in a row")
		last = index


func test_pick_next_index_is_deterministic_for_a_seed() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 99
	var b := RandomNumberGenerator.new()
	b.seed = 99
	var last_a := -1
	var last_b := -1
	for i in 50:
		var next_a := UiAudioScript.pick_next_index(last_a, 3, a)
		var next_b := UiAudioScript.pick_next_index(last_b, 3, b)
		assert_eq(next_a, next_b, "same seed yields the same sequence")
		last_a = next_a
		last_b = next_b


func test_hover_volume_sits_in_target_window() -> void:
	var hover := UiAudioScript.volume_db_for(HOVER)
	assert_true(hover >= -18.0 and hover <= -12.0, "hover loudness stays within -18..-12 dB")


func test_press_is_stronger_than_hover() -> void:
	var hover := UiAudioScript.volume_db_for(HOVER)
	var press := UiAudioScript.volume_db_for(PRESSED)
	# Higher (less negative) dB = louder. Press must read as a clear confirmation.
	assert_gt(press, hover, "pressed voice is louder than hover")


func test_locked_is_most_muted() -> void:
	var hover := UiAudioScript.volume_db_for(HOVER)
	var locked := UiAudioScript.volume_db_for(LOCKED)
	assert_lt(locked, hover, "locked voice is quieter than hover")
	assert_lt(locked, -20.0, "locked voice is a muted thud")


func test_clack_is_quieter_than_hover() -> void:
	var hover := UiAudioScript.volume_db_for(HOVER)
	var clack := UiAudioScript.volume_db_for(CLACK)
	assert_lt(clack, hover, "per-keystroke clack is quieter than a hover tick")
	assert_true(clack <= -18.0, "clack stays subtle so fast typing never overwhelms")
