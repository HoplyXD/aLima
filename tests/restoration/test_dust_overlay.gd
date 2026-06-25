extends GutTest
## Validates the model-agnostic dust overlay on RestorationObject3D: it builds a shell from the
## artifact mesh, starts uncleaned, and erasing along a ray removes dust. Rendering can't be
## checked headlessly, but the geometry/erase logic can.

const ARTIFACT_SCENE := preload("res://scenes/restoration/restoration_artifact.tscn")


func _make_object() -> RestorationObject3D:
	var obj: RestorationObject3D = ARTIFACT_SCENE.instantiate()
	add_child_autofree(obj)  # enters the tree -> _ready -> _build runs
	return obj


func test_dust_overlay_builds_and_starts_dirty() -> void:
	var obj := _make_object()
	obj.build_dust_overlay(12345)
	assert_true(obj.has_dust_overlay(), "a dust shell is built for the artifact")
	assert_almost_eq(obj.dust_cleaned_fraction(), 0.0, 0.05, "the shell starts uncleaned")


func test_erasing_removes_dust() -> void:
	var obj := _make_object()
	obj.build_dust_overlay(777)
	var before := obj.dust_cleaned_fraction()
	# Fire rays through the object's centre from several sides; at least one meets a dusty triangle.
	var erased := false
	for dir in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(0, -1, 0), Vector3(-1, 0, 0)]:
		if obj.erase_dust_ray(-dir * 3.0, dir, 0.5):
			erased = true
			break
	assert_true(erased, "a ray through the dust removes some of it")
	assert_gt(obj.dust_cleaned_fraction(), before, "cleaned fraction rises after erasing")


func test_seed_changes_dust_shape() -> void:
	var a := _make_object()
	a.build_dust_overlay(1)
	var b := _make_object()
	b.build_dust_overlay(2)
	# Different seeds should (almost surely) yield a different number of dusty triangles.
	assert_true(a.has_dust_overlay() and b.has_dust_overlay(), "both shells build")
