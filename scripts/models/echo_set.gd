class_name EchoSet
## Four-band Cultural Echo definition for one fragment.
##
## Audio paths may be empty strings when no approved audio asset exists yet;
## empty paths are treated as intentional placeholders and are valid in Phase 1.
##
## Proximity tuning is fully data-driven. Each band defines a fade-in start, a
## hold/peak center, a fade-out end, a fade width for smooth crossfades, and a
## maximum linear gain. The mixer exposes calculated band gains separately from
## audio-node application so it can be tested headlessly.

const MAX_GAIN_LINEAR := 1.0
const MIN_BAND_WIDTH := 0.001

var id: String = ""
var hum_stream: String = ""  ## Asset ref/path.
var melody_stream: String = ""
var voice_stream: String = ""  ## Kinaray-a phrase audio.
var voice_caption: String = ""  ## Subtitle + translation.
var heartbeat_stream: String = ""

## Proximity radii (world units). Far = silence (0.0), near = full (1.0).
var far_radius: float = 10.0
var near_radius: float = 0.5

## Smoothing time constant in seconds. Larger = slower, smoother proximity
## changes. A value of 0 disables smoothing.
var smoothing_time: float = 0.25

## Band tuning. Each band covers a normalized proximity slice. Fades soften the
## boundaries so layers crossfade rather than switch abruptly.
var hum_start: float = 0.00
var hum_peak: float = 0.15
var hum_end: float = 0.30
var hum_fade_width: float = 0.10
var hum_max_gain_db: float = -12.0
var hum_caption: String = "Hum"

var melody_start: float = 0.30
var melody_peak: float = 0.45
var melody_end: float = 0.60
var melody_fade_width: float = 0.10
var melody_max_gain_db: float = -8.0
var melody_caption: String = "Melody"

var voice_start: float = 0.60
var voice_peak: float = 0.72
var voice_end: float = 0.85
var voice_fade_width: float = 0.10
var voice_max_gain_db: float = -4.0

var heartbeat_start: float = 0.85
var heartbeat_peak: float = 0.93
var heartbeat_end: float = 1.00
var heartbeat_fade_width: float = 0.10
var heartbeat_max_gain_db: float = 0.0
var heartbeat_caption: String = "Heartbeat"


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> EchoSet:
	var e := EchoSet.new()
	e.id = ModelUtils.as_string(data.get("id"))
	e.hum_stream = ModelUtils.as_string(data.get("hum_stream"))
	e.melody_stream = ModelUtils.as_string(data.get("melody_stream"))
	e.voice_stream = ModelUtils.as_string(data.get("voice_stream"))
	e.voice_caption = ModelUtils.as_string(data.get("voice_caption"))
	e.heartbeat_stream = ModelUtils.as_string(data.get("heartbeat_stream"))

	e.far_radius = ModelUtils.as_float(data.get("far_radius", 10.0))
	e.near_radius = ModelUtils.as_float(data.get("near_radius", 0.5))
	e.smoothing_time = ModelUtils.as_float(data.get("smoothing_time", 0.25))

	e.hum_start = ModelUtils.as_float(data.get("hum_start", 0.00))
	e.hum_peak = ModelUtils.as_float(data.get("hum_peak", 0.15))
	e.hum_end = ModelUtils.as_float(data.get("hum_end", 0.30))
	e.hum_fade_width = ModelUtils.as_float(data.get("hum_fade_width", 0.10))
	e.hum_max_gain_db = ModelUtils.as_float(data.get("hum_max_gain_db", -12.0))
	e.hum_caption = ModelUtils.as_string(data.get("hum_caption", "Hum"))

	e.melody_start = ModelUtils.as_float(data.get("melody_start", 0.30))
	e.melody_peak = ModelUtils.as_float(data.get("melody_peak", 0.45))
	e.melody_end = ModelUtils.as_float(data.get("melody_end", 0.60))
	e.melody_fade_width = ModelUtils.as_float(data.get("melody_fade_width", 0.10))
	e.melody_max_gain_db = ModelUtils.as_float(data.get("melody_max_gain_db", -8.0))
	e.melody_caption = ModelUtils.as_string(data.get("melody_caption", "Melody"))

	e.voice_start = ModelUtils.as_float(data.get("voice_start", 0.60))
	e.voice_peak = ModelUtils.as_float(data.get("voice_peak", 0.72))
	e.voice_end = ModelUtils.as_float(data.get("voice_end", 0.85))
	e.voice_fade_width = ModelUtils.as_float(data.get("voice_fade_width", 0.10))
	e.voice_max_gain_db = ModelUtils.as_float(data.get("voice_max_gain_db", -4.0))

	e.heartbeat_start = ModelUtils.as_float(data.get("heartbeat_start", 0.85))
	e.heartbeat_peak = ModelUtils.as_float(data.get("heartbeat_peak", 0.93))
	e.heartbeat_end = ModelUtils.as_float(data.get("heartbeat_end", 1.00))
	e.heartbeat_fade_width = ModelUtils.as_float(data.get("heartbeat_fade_width", 0.10))
	e.heartbeat_max_gain_db = ModelUtils.as_float(data.get("heartbeat_max_gain_db", 0.0))
	e.heartbeat_caption = ModelUtils.as_string(data.get("heartbeat_caption", "Heartbeat"))
	return e


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"hum_stream": hum_stream,
		"melody_stream": melody_stream,
		"voice_stream": voice_stream,
		"voice_caption": voice_caption,
		"heartbeat_stream": heartbeat_stream,
		"far_radius": far_radius,
		"near_radius": near_radius,
		"smoothing_time": smoothing_time,
		"hum_start": hum_start,
		"hum_peak": hum_peak,
		"hum_end": hum_end,
		"hum_fade_width": hum_fade_width,
		"hum_max_gain_db": hum_max_gain_db,
		"hum_caption": hum_caption,
		"melody_start": melody_start,
		"melody_peak": melody_peak,
		"melody_end": melody_end,
		"melody_fade_width": melody_fade_width,
		"melody_max_gain_db": melody_max_gain_db,
		"melody_caption": melody_caption,
		"voice_start": voice_start,
		"voice_peak": voice_peak,
		"voice_end": voice_end,
		"voice_fade_width": voice_fade_width,
		"voice_max_gain_db": voice_max_gain_db,
		"heartbeat_start": heartbeat_start,
		"heartbeat_peak": heartbeat_peak,
		"heartbeat_end": heartbeat_end,
		"heartbeat_fade_width": heartbeat_fade_width,
		"heartbeat_max_gain_db": heartbeat_max_gain_db,
		"heartbeat_caption": heartbeat_caption,
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if id.is_empty():
		result.add_field_error(file_path, id, "id", "required id is missing")
	if voice_caption.is_empty():
		result.add_field_error(
			file_path, id, "voice_caption", "voice caption/subtitle is required for accessibility"
		)

	if far_radius <= near_radius:
		result.add_field_error(
			file_path, id, "far_radius", "far_radius must be greater than near_radius"
		)
	if near_radius < 0.0:
		result.add_field_error(file_path, id, "near_radius", "near_radius must be non-negative")
	if smoothing_time < 0.0:
		result.add_field_error(
			file_path, id, "smoothing_time", "smoothing_time must be non-negative"
		)

	_validate_band(
		result, file_path, "hum", hum_start, hum_peak, hum_end, hum_fade_width, hum_max_gain_db
	)
	_validate_band(
		result,
		file_path,
		"melody",
		melody_start,
		melody_peak,
		melody_end,
		melody_fade_width,
		melody_max_gain_db
	)
	_validate_band(
		result,
		file_path,
		"voice",
		voice_start,
		voice_peak,
		voice_end,
		voice_fade_width,
		voice_max_gain_db
	)
	_validate_band(
		result,
		file_path,
		"heartbeat",
		heartbeat_start,
		heartbeat_peak,
		heartbeat_end,
		heartbeat_fade_width,
		heartbeat_max_gain_db
	)

	# Ordered, contiguous bands: each band's start must equal the previous band's
	# end exactly. Crossfades are handled inside each band's fade_width.
	var eps := 0.0001
	if absf(melody_start - hum_end) > eps:
		result.add_field_error(
			file_path, id, "melody_start", "melody_start must equal hum_end for contiguous bands"
		)
	if absf(voice_start - melody_end) > eps:
		result.add_field_error(
			file_path, id, "voice_start", "voice_start must equal melody_end for contiguous bands"
		)
	if absf(heartbeat_start - voice_end) > eps:
		result.add_field_error(
			file_path,
			id,
			"heartbeat_start",
			"heartbeat_start must equal voice_end for contiguous bands"
		)
	return result


func _validate_band(
	result: ValidationResult,
	file_path: String,
	band: String,
	start: float,
	peak: float,
	end: float,
	fade_width: float,
	max_gain_db: float
) -> void:
	if start < 0.0 or start > 1.0:
		result.add_field_error(file_path, id, band + "_start", "must be within 0.0..1.0")
	if peak < 0.0 or peak > 1.0:
		result.add_field_error(file_path, id, band + "_peak", "must be within 0.0..1.0")
	if end < 0.0 or end > 1.0:
		result.add_field_error(file_path, id, band + "_end", "must be within 0.0..1.0")
	if fade_width < 0.0 or fade_width > 1.0:
		result.add_field_error(file_path, id, band + "_fade_width", "must be within 0.0..1.0")
	if start >= end:
		result.add_field_error(file_path, id, band + "_start", "must be less than " + band + "_end")
	if peak < start or peak > end:
		result.add_field_error(
			file_path, id, band + "_peak", "must be between " + band + "_start and " + band + "_end"
		)
	if end - start < MIN_BAND_WIDTH:
		result.add_field_error(
			file_path, id, band + "_end", "band width must be at least %.4f" % MIN_BAND_WIDTH
		)
	if max_gain_db > MAX_GAIN_LINEAR:
		result.add_field_error(file_path, id, band + "_max_gain_db", "max gain must be <= 0.0 dB")
