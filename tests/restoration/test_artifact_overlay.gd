extends GutTest
## Validates the authored overlay: it builds an editable shell, rolls a random per-instance coverage
## pattern from its min/max range, and cleaning fades it BY 3D POSITION (correct area, UV-independent).
## Rendering can't be checked headlessly, but the build + pattern + erase logic can.

const ARTIFACT_SCENE := preload("res://scenes/restoration/restoration_artifact.tscn")
const OVERLAY_SCENE := preload("res://scenes/restoration/artifact_overlay.tscn")
const DUST_TEX := preload("res://assets/artifact_conditions/Dust.png")


func _make_object(cov_min: float, cov_max: float, seed: int) -> RestorationObject3D:
	var obj: RestorationObject3D = ARTIFACT_SCENE.instantiate()
	var overlay: Node3D = OVERLAY_SCENE.instantiate()
	overlay.condition_texture = DUST_TEX
	overlay.coverage_min = cov_min
	overlay.coverage_max = cov_max
	obj.add_child(overlay)
	add_child_autofree(obj)
	obj.build_overlays(seed)
	return obj


func _overlay(obj: Node) -> Node:
	for child in obj.get_children():
		if child.has_method("cleaned_fraction"):
			return child
	return null


func test_overlay_is_discovered_and_built() -> void:
	var obj := _make_object(100.0, 100.0, 1)
	assert_true(obj.has_overlays(), "the authored overlay is discovered and built")


func test_random_coverage_lands_in_range() -> void:
	var obj := _make_object(40.0, 70.0, 12345)
	var overlay := _overlay(obj)
	var cov: float = overlay.coverage_fraction()
	# Soft-edged pattern, so allow a little slack around the rolled [0.40, 0.70] band.
	assert_between(cov, 0.30, 0.80, "spawn coverage is within the configured range")
	assert_almost_eq(overlay.cleaned_fraction(), 0.0, 0.01, "a fresh overlay reads 0 cleaned")


func test_two_instances_get_different_patterns() -> void:
	var a := _overlay(_make_object(0.0, 100.0, 1))
	var b := _overlay(_make_object(0.0, 100.0, 987654))
	# Different seeds almost surely roll a different coverage amount (the "two pendants differ" goal).
	assert_ne(a.coverage_fraction(), b.coverage_fraction(), "different instances differ")


func test_cleaning_overlay_fades_it_by_3d_position() -> void:
	var obj := _make_object(100.0, 100.0, 1)
	var overlay := _overlay(obj)
	var before: float = overlay.cleaned_fraction()
	var cleaned := obj.clean_overlays_ray(Vector3(0, 0, 3), Vector3(0, 0, -1))
	assert_true(cleaned, "cleaning along a ray that meets the overlay succeeds")
	assert_gt(overlay.cleaned_fraction(), before, "the cleaned area grows where the tool worked")
