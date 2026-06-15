class_name EchoProximityService
## Presentation-independent proximity normalization for Cultural Echoes.
##
## Tracks one authoritative target position and a source/listener position,
## measures Euclidean distance, and maps authored far/near radii to a normalized
## proximity value 0.0..1.0. Smooths movement with an exponential moving average
## to prevent volume and meter jitter. Exposes raw and smoothed values and emits
## changes only when meaningfully different.
##
## This class is pure: it takes Vector3 values through an explicit boundary and
## never holds hard references to scene nodes.

signal proximity_changed(raw: float, smoothed: float)

const INVALID_POSITION := Vector3.INF
const PROXIMITY_EPSILON := 0.001

var far_radius: float = 10.0:
	set(value):
		far_radius = maxf(value, 0.01)
		_recompute()

var near_radius: float = 0.5:
	set(value):
		near_radius = clampf(value, 0.0, far_radius - 0.01)
		_recompute()

## Smoothing time constant in seconds. 0 disables smoothing.
var smoothing_time: float = 0.25:
	set(value):
		smoothing_time = maxf(value, 0.0)

var source_position: Vector3 = Vector3.ZERO:
	set(value):
		source_position = value
		_recompute()

var target_position: Vector3 = INVALID_POSITION:
	set(value):
		target_position = value
		_recompute()

var raw_proximity: float = 0.0
var smoothed_proximity: float = 0.0
var has_valid_target: bool = false


func _init(far: float = 10.0, near: float = 0.5, smooth: float = 0.25) -> void:
	far_radius = maxf(far, 0.01)
	near_radius = clampf(near, 0.0, far_radius - 0.01)
	smoothing_time = maxf(smooth, 0.0)


## Clears the target. Proximity becomes 0 and no signals are emitted until a new
## target is set.
func clear_target() -> void:
	target_position = INVALID_POSITION
	has_valid_target = false
	raw_proximity = 0.0
	smoothed_proximity = 0.0
	proximity_changed.emit(raw_proximity, smoothed_proximity)


## Advances smoothing by delta seconds. Should be called each frame when a target
## is valid. Safe to call with delta = 0.
func update(delta: float) -> void:
	if not has_valid_target:
		return
	if smoothing_time <= 0.0 or delta <= 0.0:
		if not _proximity_equal(smoothed_proximity, raw_proximity):
			smoothed_proximity = raw_proximity
			proximity_changed.emit(raw_proximity, smoothed_proximity)
		return

	# Exponential approach: smooth_time is the time to cover ~63% of the gap.
	var alpha := 1.0 - exp(-delta / smoothing_time)
	var next := lerpf(smoothed_proximity, raw_proximity, alpha)
	if not _proximity_equal(smoothed_proximity, next):
		smoothed_proximity = next
		proximity_changed.emit(raw_proximity, smoothed_proximity)


func _recompute() -> void:
	var previous_valid := has_valid_target
	has_valid_target = target_position != INVALID_POSITION and source_position != INVALID_POSITION
	if not has_valid_target:
		raw_proximity = 0.0
		if previous_valid:
			proximity_changed.emit(raw_proximity, smoothed_proximity)
		return

	var distance := source_position.distance_to(target_position)
	var next_raw := _normalize_distance(distance)
	if not _proximity_equal(raw_proximity, next_raw):
		raw_proximity = next_raw
		if smoothing_time <= 0.0:
			smoothed_proximity = raw_proximity
		proximity_changed.emit(raw_proximity, smoothed_proximity)


## Maps a world distance to normalized proximity 0..1. At or beyond far_radius =
## 0; at or within near_radius = 1.
func _normalize_distance(distance: float) -> float:
	if distance <= near_radius:
		return 1.0
	if distance >= far_radius:
		return 0.0
	var span := far_radius - near_radius
	if span <= 0.0:
		return 1.0
	return clampf(1.0 - ((distance - near_radius) / span), 0.0, 1.0)


func _proximity_equal(a: float, b: float) -> bool:
	return absf(a - b) < PROXIMITY_EPSILON
