extends GutTest
## Tests for decal-based restoration (photos/frames) and the join step, plus the
## authored Auntie quest data (3 quest templates + new tools + route beats).

const TEST_SAVE := "user://test_decal_save.json"
const TEST_TEMP := "user://test_decal_save.tmp"

const PHOTO := "auntie_photo_faded"
const FRAME := "auntie_frame_portrait"
const HALF := "auntie_halfphoto_torn"

var _repo: DataRepository
var _service: RestorationService


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()
	GameState.initialize("decal-test-player")
	GameState.set_debug_seed_override(4242)
	GameState.new_run()
	_service = RestorationService.new()
	_grant_tools()


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _grant_tools() -> void:
	var tools := [
		"soft_brush",
		"damp_cloth",
		"stain_lifter",
		"photo_kit",
		"polishing_cloth",
		"consolidant",
		"solvent",
		"archival_tape"
	]
	for t in tools:
		GameState.save_state.loop.tool_items.append(t)


func _add_quest_object(uid: String, template_id: String) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.template_id = template_id
	inst.uid = uid
	inst.condition = 0.0
	inst.state = ModelEnums.ObjState.DIRTY
	inst.value = 0
	inst.storage_cost = 1
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	return inst


func _reload(uid: String) -> ObjectInstance:
	return _service.find_instance_by_id(uid)


# --- Authored data ----------------------------------------------------------


func test_quest_templates_load_with_decals() -> void:
	assert_true(_repo.is_loaded(), "repository should load with new data")
	for template_id in [PHOTO, FRAME, HALF]:
		var template := _repo.get_template(template_id)
		assert_not_null(template, "missing template %s" % template_id)
		assert_false(template.decals.is_empty(), "%s should have decals" % template_id)
		assert_false(template.deliverable, "%s should be excluded from delivery" % template_id)


func test_new_tools_and_join_tool_exist() -> void:
	for tool_id in [
		"soft_brush", "damp_cloth", "stain_lifter", "photo_kit", "solvent", "archival_tape"
	]:
		assert_not_null(_repo.get_tool(tool_id), "missing tool %s" % tool_id)
	var half := _repo.get_template(HALF)
	assert_true(half.requires_join)
	assert_eq(half.join_tool, "archival_tape")


func test_auntie_route_has_three_beats() -> void:
	var route := _repo.get_route("auntie")
	assert_not_null(route)
	assert_eq(route.beats.size(), 3)
	var days: Array = []
	for beat in route.beats:
		days.append(ModelUtils.as_int(beat.get("day")))
	assert_eq(days, [1, 3, 5])


func test_quest_items_excluded_from_delivery_pool() -> void:
	var generator := DeliveryGenerator.new(_repo, GameState)
	var groups := generator._group_templates_by_rarity()
	for rarity_name in groups.keys():
		for template in groups[rarity_name]:
			assert_false(
				(template as ScrapObjectTemplate).id.begins_with("auntie_"),
				"quest item leaked into delivery pool"
			)


# --- Decal cleaning ---------------------------------------------------------


func test_correct_tool_removes_decal_and_raises_condition() -> void:
	_add_quest_object("photo_1", PHOTO)

	var result := _service.clean_decal("photo_1", "dust_corner", "soft_brush")

	assert_true(result.ok)
	assert_true(result.compatible)
	assert_true(result.removed)
	assert_gt(result.condition_after, 0.0)
	var inst := _reload("photo_1")
	assert_true(inst.removed_decals.has("dust_corner"))


func test_wrong_tool_damages_and_leaves_decal() -> void:
	_add_quest_object("photo_1", PHOTO)

	var result := _service.clean_decal("photo_1", "dust_corner", "solvent")

	assert_true(result.ok)
	assert_false(result.compatible)
	assert_false(result.removed)
	assert_gt(result.recorded_damage, 0)
	var inst := _reload("photo_1")
	assert_false(inst.removed_decals.has("dust_corner"))


func test_cleaning_all_decals_reaches_clean_and_emits() -> void:
	_add_quest_object("photo_1", PHOTO)
	watch_signals(EventBus)
	var template := _repo.get_template(PHOTO)

	var last: RestorationService.DecalResult = null
	for decal in template.decals:
		last = _service.clean_decal("photo_1", decal.id, decal.required_tool)

	assert_true(last.reached_clean)
	assert_eq(last.remaining_decals, 0)
	var inst := _reload("photo_1")
	assert_eq(inst.state, ModelEnums.ObjState.CLEAN)
	assert_signal_emitted(EventBus, "restoration_completed")


func test_already_clean_decal_is_idempotent() -> void:
	_add_quest_object("photo_1", PHOTO)
	_service.clean_decal("photo_1", "dust_corner", "soft_brush")

	var again := _service.clean_decal("photo_1", "dust_corner", "soft_brush")

	assert_false(again.removed)
	var inst := _reload("photo_1")
	assert_eq(inst.removed_decals.count("dust_corner"), 1)


# --- Join step --------------------------------------------------------------


func test_join_rejected_until_clean() -> void:
	_add_quest_object("half_1", HALF)

	var early := _service.join_object("half_1", "archival_tape")

	assert_false(early.ok)
	assert_false(early.joined)


func test_join_requires_correct_tool() -> void:
	_add_quest_object("half_1", HALF)
	var template := _repo.get_template(HALF)
	for decal in template.decals:
		_service.clean_decal("half_1", decal.id, decal.required_tool)

	var wrong := _service.join_object("half_1", "soft_brush")

	assert_false(wrong.ok)
	assert_false(_reload("half_1").is_joined)


func test_join_succeeds_when_clean_with_archival_tape() -> void:
	_add_quest_object("half_1", HALF)
	var template := _repo.get_template(HALF)
	for decal in template.decals:
		_service.clean_decal("half_1", decal.id, decal.required_tool)

	var joined := _service.join_object("half_1", "archival_tape")

	assert_true(joined.ok)
	assert_true(joined.joined)
	assert_true(_reload("half_1").is_joined)

	# Idempotent: a second join is a no-op success.
	var again := _service.join_object("half_1", "archival_tape")
	assert_true(again.ok)
	assert_true(again.joined)
