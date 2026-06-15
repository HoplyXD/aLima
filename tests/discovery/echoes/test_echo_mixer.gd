extends GutTest
## Tests for EchoMixer: additive band gains, threshold boundaries, clamping,
## and heartbeat authorization gate.

const EPSILON := 0.001

var _echo_set: EchoSet


func before_each() -> void:
	_echo_set = EchoSet.new()
	_echo_set.hum_start = 0.0
	_echo_set.hum_peak = 0.15
	_echo_set.hum_end = 0.30
	_echo_set.hum_fade_width = 0.10
	_echo_set.hum_max_gain_db = -12.0

	_echo_set.melody_start = 0.30
	_echo_set.melody_peak = 0.45
	_echo_set.melody_end = 0.60
	_echo_set.melody_fade_width = 0.10
	_echo_set.melody_max_gain_db = -8.0

	_echo_set.voice_start = 0.60
	_echo_set.voice_peak = 0.72
	_echo_set.voice_end = 0.85
	_echo_set.voice_fade_width = 0.10
	_echo_set.voice_max_gain_db = -4.0

	_echo_set.heartbeat_start = 0.85
	_echo_set.heartbeat_peak = 0.93
	_echo_set.heartbeat_end = 1.00
	_echo_set.heartbeat_fade_width = 0.10
	_echo_set.heartbeat_max_gain_db = 0.0


func test_far_silence() -> void:
	var gains := EchoMixer.calculate_band_gains(0.0, _echo_set, true)
	assert_almost_eq(gains[EchoMixer.BAND_HUM], 0.0, EPSILON)
	assert_almost_eq(gains[EchoMixer.BAND_MELODY], 0.0, EPSILON)
	assert_almost_eq(gains[EchoMixer.BAND_VOICE], 0.0, EPSILON)
	assert_almost_eq(gains[EchoMixer.BAND_HEARTBEAT], 0.0, EPSILON)


func test_hum_boundary() -> void:
	var gains := EchoMixer.calculate_band_gains(0.15, _echo_set, true)
	assert_gt(gains[EchoMixer.BAND_HUM], 0.0)
	assert_almost_eq(gains[EchoMixer.BAND_MELODY], 0.0, EPSILON)
	assert_almost_eq(gains[EchoMixer.BAND_VOICE], 0.0, EPSILON)
	assert_almost_eq(gains[EchoMixer.BAND_HEARTBEAT], 0.0, EPSILON)


func test_melody_boundary() -> void:
	var gains := EchoMixer.calculate_band_gains(0.45, _echo_set, true)
	assert_gt(gains[EchoMixer.BAND_MELODY], 0.0)
	assert_almost_eq(gains[EchoMixer.BAND_VOICE], 0.0, EPSILON)
	assert_almost_eq(gains[EchoMixer.BAND_HEARTBEAT], 0.0, EPSILON)


func test_voice_boundary() -> void:
	var gains := EchoMixer.calculate_band_gains(0.72, _echo_set, true)
	assert_gt(gains[EchoMixer.BAND_VOICE], 0.0)
	assert_almost_eq(gains[EchoMixer.BAND_HEARTBEAT], 0.0, EPSILON)


func test_heartbeat_boundary() -> void:
	var gains := EchoMixer.calculate_band_gains(0.93, _echo_set, true)
	assert_gt(gains[EchoMixer.BAND_HEARTBEAT], 0.0)
	assert_gt(gains[EchoMixer.BAND_VOICE], 0.0)


func test_heartbeat_unauthorized_is_zero() -> void:
	# At 0.75, Voice is active but Heartbeat must remain silent without carrier auth.
	var gains := EchoMixer.calculate_band_gains(0.75, _echo_set, false)
	assert_almost_eq(gains[EchoMixer.BAND_HEARTBEAT], 0.0, EPSILON)
	assert_gt(gains[EchoMixer.BAND_VOICE], 0.0)


func test_gains_remain_clamped() -> void:
	var gains := EchoMixer.calculate_band_gains(1.0, _echo_set, true)
	for g in gains.values():
		assert_lte(g, 1.0 + EPSILON)
		assert_gte(g, 0.0)


func test_null_echo_set_is_silent() -> void:
	var gains := EchoMixer.calculate_band_gains(0.5, null, true)
	for g in gains.values():
		assert_almost_eq(g, 0.0, EPSILON)


func test_active_bands_follow_gain() -> void:
	var gains := {
		EchoMixer.BAND_HUM: 0.0,
		EchoMixer.BAND_MELODY: 0.5,
		EchoMixer.BAND_VOICE: 0.0,
		EchoMixer.BAND_HEARTBEAT: 0.0
	}
	var active := EchoMixer.active_bands(gains)
	assert_eq(active.size(), 1)
	assert_eq(active[0], EchoMixer.BAND_MELODY)


func test_db_conversion_is_monotonic_and_clamped() -> void:
	var db0 := EchoMixer.linear_to_db(0.0)
	var db1 := EchoMixer.linear_to_db(1.0)
	var db_mid := EchoMixer.linear_to_db(0.5)
	assert_lt(db0, db_mid)
	assert_lt(db_mid, db1)
	assert_almost_eq(db1, 0.0, EPSILON)
	assert_lte(EchoMixer.linear_to_db(2.0), 0.0)
