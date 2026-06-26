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


func _make_object_with_condition(condition: String, seed: int) -> RestorationObject3D:
	var obj: RestorationObject3D = ARTIFACT_SCENE.instantiate()
	var overlay: Node3D = OVERLAY_SCENE.instantiate()
	overlay.condition_texture = DUST_TEX
	overlay.condition_id = condition
	overlay.coverage_min = 100.0
	overlay.coverage_max = 100.0
	obj.add_child(overlay)
	add_child_autofree(obj)
	obj.build_overlays(seed)
	return obj


func test_tool_cleans_only_its_matching_condition() -> void:
	var obj := _make_object_with_condition("dust", 3)
	var ray_o := Vector3(0, 0, 3)
	var ray_d := Vector3(0, 0, -1)
	var ok := obj.clean_overlays_with_tool(ray_o, ray_d, {"dust": 60}, 0.25)
	assert_true(ok.get("cleaned", false), "a dust tool cleans the dust overlay")
	assert_eq(String(ok.get("condition_id", "")), "dust", "and reports the cleaned condition")
	var wrong := obj.clean_overlays_with_tool(ray_o, ray_d, {"tarnish": 60}, 0.25)
	assert_false(wrong.get("cleaned", false), "a tool that can't clean dust does not clean it")
	assert_true(wrong.get("wrong_tool", false), "and reports wrong tool")


func test_condition_id_derives_from_texture_name() -> void:
	var overlay: Node3D = OVERLAY_SCENE.instantiate()
	overlay.condition_texture = preload("res://assets/artifact_conditions/Cracking.png")
	add_child_autofree(overlay)
	assert_eq(String(overlay.get_condition_id()), "crack", "Cracking.png derives the 'crack' condition")
	overlay.condition_texture = preload("res://assets/artifact_conditions/Rust.png")
	assert_eq(String(overlay.get_condition_id()), "rust", "Rust.png derives 'rust'")
	overlay.condition_id = "explicit"
	assert_eq(String(overlay.get_condition_id()), "explicit", "an explicit condition_id wins")


func test_overlay_counts_reflect_cleaning() -> void:
	var obj := _make_object_with_condition("dust", 4)
	assert_eq(int(obj.overlay_counts().get("total", 0)), 1, "one overlay condition")
	assert_eq(int(obj.overlay_counts().get("cleaned", -1)), 0, "starts uncleaned")


func test_clean_percent_and_force_clean() -> void:
	var obj := _make_object_with_condition("dust", 5)
	assert_almost_eq(obj.overlay_clean_percent(), 0.0, 0.02, "a fresh overlay reads 0% cleaned")
	obj.force_clean_overlays([])  # wipe everything
	assert_almost_eq(obj.overlay_clean_percent(), 1.0, 0.02, "force-cleaning reaches 100%")


func test_crack_never_spawns() -> void:
	var obj := _make_object_with_condition("crack", 6)
	# Crack is disabled for now, so even at 100/100 coverage it spawns nothing.
	assert_almost_eq(obj.overlay_clean_percent(), 1.0, 0.02, "crack contributes no dirt to clean")


func test_cleaning_overlay_fades_it_by_3d_position() -> void:
	var obj := _make_object(100.0, 100.0, 1)
	var overlay := _overlay(obj)
	var before: float = overlay.cleaned_fraction()
	var cleaned := obj.clean_overlays_ray(Vector3(0, 0, 3), Vector3(0, 0, -1))
	assert_true(cleaned, "cleaning along a ray that meets the overlay succeeds")
	assert_gt(overlay.cleaned_fraction(), before, "the cleaned area grows where the tool worked")
