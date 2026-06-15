extends GutTest
## Tests for EchoProximityService: normalization, clamping, smoothing, and
## invalid-target handling.

const EPSILON := 0.001

var _changed := false


func test_far_radius_maps_to_zero() -> void:
	var svc := EchoProximityService.new(10.0, 0.5, 0.0)
	svc.source_position = Vector3.ZERO
	svc.target_position = Vector3(10.0, 0.0, 0.0)
	svc.update(0.0)
	assert_almost_eq(svc.raw_proximity, 0.0, EPSILON)
	assert_almost_eq(svc.smoothed_proximity, 0.0, EPSILON)


func test_near_radius_maps_to_one() -> void:
	var svc := EchoProximityService.new(10.0, 0.5, 0.0)
	svc.source_position = Vector3.ZERO
	svc.target_position = Vector3(0.5, 0.0, 0.0)
	svc.update(0.0)
	assert_almost_eq(svc.raw_proximity, 1.0, EPSILON)
	assert_almost_eq(svc.smoothed_proximity, 1.0, EPSILON)


func test_values_outside_radii_clamp() -> void:
	var svc := EchoProximityService.new(10.0, 0.5, 0.0)
	svc.source_position = Vector3.ZERO
	svc.target_position = Vector3(100.0, 0.0, 0.0)
	svc.update(0.0)
	assert_almost_eq(svc.raw_proximity, 0.0, EPSILON)

	svc.target_position = Vector3(0.01, 0.0, 0.0)
	svc.update(0.0)
	assert_almost_eq(svc.raw_proximity, 1.0, EPSILON)


func test_midpoint_maps_to_half() -> void:
	var svc := EchoProximityService.new(10.0, 0.0, 0.0)
	svc.source_position = Vector3.ZERO
	svc.target_position = Vector3(5.0, 0.0, 0.0)
	svc.update(0.0)
	assert_almost_eq(svc.raw_proximity, 0.5, EPSILON)


func test_smoothing_prevents_abrupt_jitter() -> void:
	var svc := EchoProximityService.new(10.0, 0.5, 0.25)
	svc.source_position = Vector3.ZERO
	svc.target_position = Vector3(10.0, 0.0, 0.0)
	svc.update(0.0)

	svc.target_position = Vector3(0.5, 0.0, 0.0)
	svc.update(0.01)
	assert_lt(svc.smoothed_proximity, svc.raw_proximity)
	assert_gt(svc.smoothed_proximity, 0.0)


func test_clear_target_resets_proximity() -> void:
	var svc := EchoProximityService.new(10.0, 0.5, 0.0)
	svc.source_position = Vector3.ZERO
	svc.target_position = Vector3(0.5, 0.0, 0.0)
	svc.update(0.0)
	assert_almost_eq(svc.smoothed_proximity, 1.0, EPSILON)

	_changed = false
	svc.proximity_changed.connect(_on_proximity_changed)
	svc.clear_target()
	assert_false(svc.has_valid_target)
	assert_almost_eq(svc.raw_proximity, 0.0, EPSILON)
	assert_almost_eq(svc.smoothed_proximity, 0.0, EPSILON)
	assert_true(_changed)


func _on_proximity_changed(_raw: float, _smoothed: float) -> void:
	_changed = true


func test_invalid_source_marks_target_invalid() -> void:
	var svc := EchoProximityService.new(10.0, 0.5, 0.0)
	svc.source_position = EchoProximityService.INVALID_POSITION
	svc.target_position = Vector3.ZERO
	svc.update(0.0)
	assert_false(svc.has_valid_target)
