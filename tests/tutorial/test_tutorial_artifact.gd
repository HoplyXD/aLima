extends GutTest

## Day 0 restoration constraints (TUT): tutorial deliveries carry only the
## allowed grime+dust conditions, the allowed_conditions filter round-trips on
## the instance, and the restoration step can never soft-lock without a
## restorable artifact.

const TEST_SAVE := "user://test_tutorial_artifact_save.json"
const TEST_TEMP := "user://test_tutorial_artifact_save.tmp"


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("tutorial-artifact-test")
	DayClock.reset()
	TutorialService.load_script_file()


func after_each() -> void:
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _arm_fresh_save() -> void:
	GameState.save_state.persistent.tutorial_completed = false
	GameState.new_run(4242)
	LoopController.begin_session()


func test_tutorial_delivery_conditions_are_whitelisted() -> void:
	_arm_fresh_save()
	var repo := DataRepository.singleton()
	var generator := DeliveryGenerator.new(repo, GameState)
	var delivery := generator.generate_day_delivery(1)
	assert_false(delivery.is_empty(), "The tutorial delivery still produces a batch")
	var allowed: Array = TutorialService.get_config().get("allowed_conditions", [])
	for inst in delivery:
		assert_eq(inst.allowed_conditions, ModelUtils.as_string_array(allowed))
		for raw in inst.spawned_decals:
			var decal_type := str((raw as Dictionary).get("type"))
			assert_true(
				allowed.has(decal_type),
				"Spawned condition '%s' must be in the Day 0 whitelist" % decal_type
			)


func test_normal_delivery_has_no_whitelist() -> void:
	GameState.new_run(4242)
	var repo := DataRepository.singleton()
	var generator := DeliveryGenerator.new(repo, GameState)
	var delivery := generator.generate_day_delivery(1)
	for inst in delivery:
		assert_true(inst.allowed_conditions.is_empty())


func test_allowed_conditions_round_trip_on_the_instance() -> void:
	var inst := ObjectInstance.new()
	inst.template_id = "tarnished_pendant"
	inst.uid = "obj_test_1"
	inst.allowed_conditions = ["dust", "dirt"] as Array[String]
	var copy := ObjectInstance.from_dictionary(inst.to_dictionary())
	assert_eq(copy.allowed_conditions, inst.allowed_conditions)


func test_restoration_step_injects_artifact_when_inventory_is_bare() -> void:
	_arm_fresh_save()
	assert_true(GameState.save_state.loop.inventory.is_empty())
	TutorialService.advance_to("restoration_intro")
	assert_false(
		GameState.save_state.loop.inventory.is_empty(),
		"Reaching the restoration step with nothing restorable injects a fallback artifact"
	)
	var inst := ObjectInstance.from_dictionary(GameState.save_state.loop.inventory[0])
	assert_eq(GameState.save_state.loop.restore_target_uid, inst.uid)
	assert_eq(inst.state, ModelEnums.ObjState.DIRTY)
	var template := DataRepository.singleton().get_template(inst.template_id)
	assert_not_null(template)
	assert_eq(inst.allowed_conditions, ["dust", "dirt"] as Array[String])


func test_restoration_step_keeps_existing_dirty_artifact() -> void:
	_arm_fresh_save()
	var existing := ObjectInstance.new()
	existing.template_id = "tarnished_pendant"
	existing.uid = "obj_existing_1"
	existing.state = ModelEnums.ObjState.DIRTY
	GameState.save_state.loop.inventory.append(existing.to_dictionary())
	TutorialService.advance_to("restoration_intro")
	assert_eq(
		GameState.save_state.loop.inventory.size(),
		1,
		"A dirty artifact already in inventory suppresses the fallback injection"
	)
