extends GutTest
## Tests for EchoSet data validation: ordered bands, ranges, references.


func test_valid_echo_set_passes() -> void:
	var echo := _valid_echo_set()
	var result := echo.validate()
	assert_true(result.is_valid())


func test_missing_id_fails() -> void:
	var echo := _valid_echo_set()
	echo.id = ""
	var result := echo.validate()
	assert_false(result.is_valid())


func test_missing_voice_caption_fails() -> void:
	var echo := _valid_echo_set()
	echo.voice_caption = ""
	var result := echo.validate()
	assert_false(result.is_valid())


func test_far_radius_must_exceed_near_radius() -> void:
	var echo := _valid_echo_set()
	echo.far_radius = 1.0
	echo.near_radius = 2.0
	var result := echo.validate()
	assert_false(result.is_valid())


func test_negative_smoothing_time_fails() -> void:
	var echo := _valid_echo_set()
	echo.smoothing_time = -0.1
	var result := echo.validate()
	assert_false(result.is_valid())


func test_out_of_range_threshold_fails() -> void:
	var echo := _valid_echo_set()
	echo.hum_start = -0.1
	var result := echo.validate()
	assert_false(result.is_valid())


func test_band_start_must_be_less_than_end() -> void:
	var echo := _valid_echo_set()
	echo.melody_start = 0.6
	echo.melody_end = 0.3
	var result := echo.validate()
	assert_false(result.is_valid())


func test_peak_must_be_inside_band() -> void:
	var echo := _valid_echo_set()
	echo.voice_peak = 0.5
	var result := echo.validate()
	assert_false(result.is_valid())


func test_overlapping_bands_without_contiguity_fails() -> void:
	var echo := _valid_echo_set()
	echo.melody_start = 0.25
	var result := echo.validate()
	assert_false(result.is_valid())


func test_gap_between_bands_fails() -> void:
	var echo := _valid_echo_set()
	echo.melody_end = 0.55
	var result := echo.validate()
	assert_false(result.is_valid())


func test_max_gain_above_zero_db_fails() -> void:
	var echo := _valid_echo_set()
	echo.heartbeat_max_gain_db = 3.0
	var result := echo.validate()
	assert_false(result.is_valid())


func test_fixture_echo_set_loads_and_validates() -> void:
	var repo := DataRepository.singleton()
	repo.load_from_filesystem()
	var echo := repo.get_echo_set("demo_echo_set")
	assert_not_null(echo)
	var result := echo.validate()
	assert_true(result.is_valid())


func _valid_echo_set() -> EchoSet:
	var echo := EchoSet.new()
	echo.id = "test_echo"
	echo.voice_caption = "Test caption"
	echo.far_radius = 10.0
	echo.near_radius = 0.5
	echo.smoothing_time = 0.25

	echo.hum_start = 0.0
	echo.hum_peak = 0.15
	echo.hum_end = 0.30
	echo.hum_fade_width = 0.10
	echo.hum_max_gain_db = -12.0

	echo.melody_start = 0.30
	echo.melody_peak = 0.45
	echo.melody_end = 0.60
	echo.melody_fade_width = 0.10
	echo.melody_max_gain_db = -8.0

	echo.voice_start = 0.60
	echo.voice_peak = 0.72
	echo.voice_end = 0.85
	echo.voice_fade_width = 0.10
	echo.voice_max_gain_db = -4.0

	echo.heartbeat_start = 0.85
	echo.heartbeat_peak = 0.93
	echo.heartbeat_end = 1.00
	echo.heartbeat_fade_width = 0.10
	echo.heartbeat_max_gain_db = 0.0
	return echo
