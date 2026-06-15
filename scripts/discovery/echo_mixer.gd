class_name EchoMixer
## Pure additive band mixer for Cultural Echoes.
##
## Calculates per-band linear gains from normalized proximity and an EchoSet.
## Gains are exposed separately from AudioStreamPlayer application so the mixer
## is testable headlessly. Heartbeat gain is computed but is only authorized when
## the caller confirms the active instance is a carrier (is_carrier == true).
##
## Band shape: ramp up over fade_width from start to peak, hold 1.0 from peak to
## end, then ramp down over fade_width after end. Gains are clamped to the
## EchoSet's authored max gain and converted safely to decibels by EchoAudio.

const BAND_HUM := "hum"
const BAND_MELODY := "melody"
const BAND_VOICE := "voice"
const BAND_HEARTBEAT := "heartbeat"
const SILENCE_DB := -80.0


## Returns a Dictionary of band -> linear gain (0.0..1.0). If echo_set is null,
## all bands are silent. heartbeat_authorized must be true for the active carrier;
## decoys always receive 0.0 heartbeat gain regardless of proximity.
static func calculate_band_gains(
	proximity: float, echo_set: EchoSet, heartbeat_authorized: bool
) -> Dictionary:
	var out := {
		BAND_HUM: 0.0,
		BAND_MELODY: 0.0,
		BAND_VOICE: 0.0,
		BAND_HEARTBEAT: 0.0,
	}
	if echo_set == null:
		return out

	var p := clampf(proximity, 0.0, 1.0)
	out[BAND_HUM] = _band_gain(
		p,
		echo_set.hum_start,
		echo_set.hum_peak,
		echo_set.hum_end,
		echo_set.hum_fade_width,
		echo_set.hum_max_gain_db
	)
	out[BAND_MELODY] = _band_gain(
		p,
		echo_set.melody_start,
		echo_set.melody_peak,
		echo_set.melody_end,
		echo_set.melody_fade_width,
		echo_set.melody_max_gain_db
	)
	out[BAND_VOICE] = _band_gain(
		p,
		echo_set.voice_start,
		echo_set.voice_peak,
		echo_set.voice_end,
		echo_set.voice_fade_width,
		echo_set.voice_max_gain_db
	)
	if heartbeat_authorized:
		out[BAND_HEARTBEAT] = _band_gain(
			p,
			echo_set.heartbeat_start,
			echo_set.heartbeat_peak,
			echo_set.heartbeat_end,
			echo_set.heartbeat_fade_width,
			echo_set.heartbeat_max_gain_db
		)
	else:
		out[BAND_HEARTBEAT] = 0.0
	return out


## Safe linear -> dB conversion. 0.0 maps to SILENCE_DB so players can be muted
## without sending -INF (which some platforms treat inconsistently).
static func linear_to_db(linear: float) -> float:
	linear = clampf(linear, 0.0, 1.0)
	if linear <= 0.0000001:
		return SILENCE_DB
	return clampf(20.0 * log(linear) / log(10.0), SILENCE_DB, 0.0)


## Returns the set of band names whose linear gain is above the audible threshold.
static func active_bands(gains: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for band in [BAND_HUM, BAND_MELODY, BAND_VOICE, BAND_HEARTBEAT]:
		if gains.get(band, 0.0) > 0.001:
			out.append(band)
	return out


## Computes a single band's linear gain with fade-in, hold, fade-out shape.
static func _band_gain(
	p: float, start: float, peak: float, end: float, fade_width: float, max_gain_db: float
) -> float:
	if p < start:
		return 0.0
	var max_linear := db_to_linear(max_gain_db)
	if p >= peak and p <= end:
		return max_linear
	if p > end:
		var after := p - end
		if after >= fade_width:
			return 0.0
		if fade_width <= 0.0:
			return 0.0
		return max_linear * (1.0 - (after / fade_width))
	# p is between start and peak.
	var before := peak - p
	if before >= fade_width:
		return 0.0
	if fade_width <= 0.0:
		return max_linear
	return max_linear * (1.0 - (before / fade_width))


static func db_to_linear(db: float) -> float:
	if db <= SILENCE_DB:
		return 0.0
	return pow(10.0, db / 20.0)
