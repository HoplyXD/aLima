extends GutTest

## Regression tests for ValueModel live market-value derivation (REST-FIX-001).

const TEST_SAVE := "user://test_value_model_save.json"
const TEST_TEMP := "user://test_value_model_save.tmp"

var _repo: DataRepository


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("value-model-player")
	GameState.set_debug_seed_override(5555)
	GameState.new_run()
	_repo = DataRepository.singleton()


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _make_locket(uid: String, condition: float, true_value: int) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.template_id = "dusty_locket"
	inst.uid = uid
	inst.condition = condition
	inst.state = ModelEnums.ObjState.DIRTY
	inst.value = 100
	inst.true_value = true_value
	inst.storage_cost = 1
	return inst


func test_value_rises_with_condition_for_non_decal_openable() -> void:
	var template: ScrapObjectTemplate = _repo.get_template("dusty_locket")
	var inst := _make_locket("vm_lock_01", 0.0, 200)

	var v0 := ValueModel.current_value(inst, template, _repo)
	assert_lte(v0, 50, "filthy piece is floored at 25%% of true value")

	inst.condition = 50.0
	var v50 := ValueModel.current_value(inst, template, _repo)
	assert_gt(v50, v0, "value rises as condition improves")
	assert_lt(v50, inst.true_value, "partially-clean piece is worth less than pristine")

	inst.condition = 100.0
	var v100 := ValueModel.current_value(inst, template, _repo)
	assert_eq(v100, inst.true_value, "fully-clean non-decal openable reaches true value")


func test_value_rises_per_tool_stroke_for_gold_locket() -> void:
	GameState.save_state.loop.tool_items.append("soft_cloth")
	var service := RestorationService.new()
	var inst := _make_locket("vm_lock_02", 50.0, 240)
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	var template: ScrapObjectTemplate = _repo.get_template("dusty_locket")

	var before := ValueModel.current_value(
		service.find_instance_by_id("vm_lock_02"), template, _repo
	)
	var result := service.apply_tool("vm_lock_02", "soft_cloth")
	assert_true(result.ok and result.compatible, "compatible stroke succeeds")
	var after := ValueModel.current_value(
		service.find_instance_by_id("vm_lock_02"), template, _repo
	)
	assert_gt(after, before, "one compatible stroke raises the displayed value")

	var guard := 0
	while service.find_instance_by_id("vm_lock_02").state == ModelEnums.ObjState.DIRTY:
		service.apply_tool("vm_lock_02", "soft_cloth")
		guard += 1
		if guard > 20:
			break
	var final := ValueModel.current_value(
		service.find_instance_by_id("vm_lock_02"), template, _repo
	)
	assert_eq(final, inst.true_value, "clean piece reaches its rolled true value")
