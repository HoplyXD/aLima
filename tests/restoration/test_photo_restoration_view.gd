extends GutTest
## Presentation-boundary tests for decal-based photo/frame cleaning in the 3D
## restoration view: photo mode, clicking blemishes to clean them (delegated to
## RestorationService.clean_decal), and the Archival Tape join step. Blemish hits
## are driven through analytic world-space rays aimed at each hotspot's centre, so
## no rendered pixels or fixed screen coordinates are asserted.

const VIEW_SCENE := preload("res://scenes/restoration/restoration_view.tscn")
const TEST_SAVE := "user://test_photo_view_save.json"
const TEST_TEMP := "user://test_photo_view_save.tmp"

const PHOTO := "auntie_photo_faded"
const HALF := "auntie_halfphoto_torn"

var _view: RestorationView


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("photo-view-player")
	GameState.set_debug_seed_override(4242)
	GameState.new_run()
	_grant_photo_tools()
	DayClock.reset()


func after_each() -> void:
	if is_instance_valid(_view):
		_view.close()
		_view.queue_free()
		_view = null
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _grant_photo_tools() -> void:
	for tool_id in ["soft_brush", "damp_cloth", "stain_lifter", "photo_kit", "solvent", "archival_tape"]:
		GameState.save_state.loop.tool_items.append(tool_id)


func _add_photo(uid: String, template_id: String) -> void:
	var inst := ObjectInstance.new()
	inst.template_id = template_id
	inst.uid = uid
	inst.condition = 0.0
	inst.state = ModelEnums.ObjState.DIRTY
	inst.value = 0
	inst.storage_cost = 1
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func _make_view() -> RestorationView:
	var view: RestorationView = VIEW_SCENE.instantiate()
	add_child_autofree(view)
	await wait_physics_frames(1)
	return view


func _required_tool_for(template_id: String, decal_id: String) -> String:
	var template := DataRepository.singleton().get_template(template_id)
	for decal in template.decals:
		if decal.id == decal_id:
			return decal.required_tool
	return ""


# Cleans one blemish by aiming a ray straight at its hotspot centre with the
# correct tool selected.
func _clean_blemish(view: RestorationView, template_id: String, decal_id: String) -> bool:
	view.select_tool(_required_tool_for(template_id, decal_id))
	var obj := view.get_restoration_object()
	var center := obj.get_blemish_global_center(decal_id)
	var origin := center + Vector3(0.0, 0.0, 3.0)
	return view.attempt_clean_blemish_with_ray(origin, Vector3(0.0, 0.0, -1.0))


func _clean_all(view: RestorationView, uid: String, template_id: String) -> void:
	var template := DataRepository.singleton().get_template(template_id)
	for decal in template.decals:
		assert_true(_clean_blemish(view, template_id, decal.id), "should hit blemish %s" % decal.id)


func test_loading_a_photo_enters_photo_mode() -> void:
	_add_photo("photo_1", PHOTO)
	_view = await _make_view()
	_view.open()

	assert_true(_view.get_restoration_object().is_photo_mode(), "photo should use blemish mode")


func test_clicking_a_blemish_with_matching_tool_removes_it() -> void:
	_add_photo("photo_1", PHOTO)
	_view = await _make_view()
	_view.open()
	_view.load_instance("photo_1")

	var acted := _clean_blemish(_view, PHOTO, "dust_corner")

	assert_true(acted, "ray should hit the dust blemish")
	var inst := RestorationService.new().find_instance_by_id("photo_1")
	assert_true(inst.removed_decals.has("dust_corner"))
	assert_false(_view.get_restoration_object().get_visible_blemish_ids().has("dust_corner"))


func test_wrong_tool_does_not_remove_blemish() -> void:
	_add_photo("photo_1", PHOTO)
	_view = await _make_view()
	_view.open()
	_view.load_instance("photo_1")

	# Solvent is wrong for dust (needs the soft brush).
	_view.select_tool("solvent")
	var obj := _view.get_restoration_object()
	var center := obj.get_blemish_global_center("dust_corner")
	_view.attempt_clean_blemish_with_ray(center + Vector3(0, 0, 3), Vector3(0, 0, -1))

	var inst := RestorationService.new().find_instance_by_id("photo_1")
	assert_false(inst.removed_decals.has("dust_corner"))
	assert_true(obj.get_visible_blemish_ids().has("dust_corner"))


func test_cleaning_all_blemishes_reaches_clean() -> void:
	_add_photo("photo_1", PHOTO)
	_view = await _make_view()
	_view.open()
	_view.load_instance("photo_1")

	_clean_all(_view, "photo_1", PHOTO)

	var inst := RestorationService.new().find_instance_by_id("photo_1")
	assert_eq(inst.state, ModelEnums.ObjState.CLEAN)
	assert_false(_view.get_restoration_object().has_visible_blemishes())


func test_join_after_cleaning_torn_halves() -> void:
	_add_photo("half_1", HALF)
	_view = await _make_view()
	_view.open()
	_view.load_instance("half_1")
	_clean_all(_view, "half_1", HALF)

	_view.select_tool("archival_tape")
	var result := _view.try_join()

	assert_true(result.ok)
	assert_true(result.joined)
	assert_true(RestorationService.new().find_instance_by_id("half_1").is_joined)
