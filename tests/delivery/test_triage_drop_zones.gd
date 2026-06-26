extends GutTest

## Headless seam test for the 3D triage drop-zone -> Decision mapping.
##
## The mapping lives in TriageController so it can be unit-tested without
## pointer input or a running physics world.

const TRIAGE_SCENE := preload("res://scenes/ui/triage_screen.tscn")

var _controller: TriageController


func before_each() -> void:
	_controller = TRIAGE_SCENE.instantiate()
	add_child_autofree(_controller)


func after_each() -> void:
	_controller = null


func test_keep_zone_maps_to_keep() -> void:
	assert_eq(
		_controller._resolve_drop("item_01", TriageController.KEEP_ZONE_NAME),
		TriageState.Decision.KEEP
	)


func test_recycle_zone_maps_to_recycle() -> void:
	assert_eq(
		_controller._resolve_drop("item_01", TriageController.RECYCLE_ZONE_NAME),
		TriageState.Decision.RECYCLE
	)


func test_unknown_zone_leaves_undecided() -> void:
	assert_eq(_controller._resolve_drop("item_01", ""), TriageState.Decision.UNDECIDED)
	assert_eq(_controller._resolve_drop("item_01", "SomeOtherZone"), TriageState.Decision.UNDECIDED)


func test_zone_constants_match_expected_names() -> void:
	assert_eq(TriageController.KEEP_ZONE_NAME, "KeepZone")
	assert_eq(TriageController.RECYCLE_ZONE_NAME, "RecycleZone")
