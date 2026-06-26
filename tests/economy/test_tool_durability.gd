extends GutTest
## Tool durability: tools wear with use and break (are removed) at 0; tools owned
## only via the id-set never wear; ownership reflects usable instances.

const TEST_SAVE := "user://test_durability_save.json"
const TEST_TEMP := "user://test_durability_save.tmp"

const PHOTO := "auntie_photo_faded"

var _repo: DataRepository
var _service: RestorationService
var _tools: ToolService


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()
	GameState.initialize("durability-player")
	GameState.set_debug_seed_override(99)
	GameState.new_run()
	_service = RestorationService.new()
	_tools = ToolService.new(GameState, _repo)


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _add_photo(uid: String) -> void:
	var inst := ObjectInstance.new()
	inst.template_id = PHOTO
	inst.uid = uid
	inst.state = ModelEnums.ObjState.DIRTY
	inst.storage_cost = 1
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func _set_durability(uid: String, value: int) -> void:
	for raw in GameState.save_state.loop.owned_tools:
		if raw is Dictionary and raw.get("uid") == uid:
			raw["durability"] = value
			raw["max_durability"] = maxi(raw.get("max_durability", value), value)


func test_using_a_tool_consumes_one_durability() -> void:
	_add_photo("photo_1")
	var inst := _tools.grant_tool("stain_lifter")  # finite (durability 24)
	var before := inst.durability

	# water_blotch is cleaned by the stain lifter.
	_service.clean_decal("photo_1", "water_blotch", "stain_lifter")

	var after := _tools.get_owned_tools()[0].durability
	assert_eq(after, before - 1, "one use should cost one durability")


## Authored scene-conditions take several strokes each; the tool must wear ONCE PER
## CONDITION removed, not per stroke — otherwise a 12-use tool burned out and vanished
## from the bench AND storage in the middle of a single artifact.
func test_authored_clean_wears_per_condition_not_per_stroke() -> void:
	var uid := "auth_artifact"
	var inst := ObjectInstance.new()
	inst.template_id = "oton_death_mask"
	inst.uid = uid
	inst.state = ModelEnums.ObjState.DIRTY
	inst.storage_cost = 1
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	var tool := _tools.grant_tool("stain_lifter")  # finite durability
	var before := tool.durability

	# Several partial strokes (finished_one = false) cost NO durability.
	for _i in range(4):
		_service.register_authored_clean(uid, "stain_lifter", 2, 0, false)
	assert_eq(
		_tools.get_owned_tools()[0].durability, before, "partial strokes don't wear the tool"
	)

	# The stroke that actually finishes a condition wears it exactly once.
	_service.register_authored_clean(uid, "stain_lifter", 2, 1, true)
	assert_eq(
		_tools.get_owned_tools()[0].durability,
		before - 1,
		"finishing a condition costs one use"
	)


func test_tool_breaks_at_zero_stays_in_storage_but_leaves_bench() -> void:
	_add_photo("photo_1")
	var inst := _tools.grant_tool("stain_lifter")  # auto-equipped onto the bench
	_set_durability(inst.uid, 1)
	watch_signals(EventBus)

	_service.clean_decal("photo_1", "water_blotch", "stain_lifter")

	# A broken tool is NOT deleted from player data — it stays owned at 0 durability so it
	# never "randomly disappears"; it only leaves the bench loadout and becomes unusable.
	assert_eq(_tools.get_owned_tools().size(), 1, "a broken tool stays in storage")
	assert_eq(_tools.get_owned_tools()[0].durability, 0, "and reads as broken (0 durability)")
	assert_false(_service.is_tool_owned("stain_lifter"), "a broken tool is not owned for use")
	assert_false(
		GameState.save_state.loop.workbench_tools.has(inst.uid),
		"a broken tool leaves the bench loadout"
	)
	assert_signal_emitted(EventBus, "tool_broke")


func test_idset_tools_never_wear() -> void:
	_add_photo("photo_1")
	# soft_brush owned only via the id-set (starting-kit style), no instance.
	GameState.save_state.loop.tool_items.append("soft_brush")

	_service.clean_decal("photo_1", "dust_corner", "soft_brush")

	assert_eq(_tools.get_owned_tools().size(), 0, "id-set ownership creates no wearing instance")
	assert_true(_service.is_tool_owned("soft_brush"))


func test_ownership_follows_usable_instances() -> void:
	var inst := _tools.grant_tool("solvent")
	assert_true(_service.is_tool_owned("solvent"))

	_set_durability(inst.uid, 0)  # broken
	assert_false(_service.is_tool_owned("solvent"), "a broken instance is not owned for use")
