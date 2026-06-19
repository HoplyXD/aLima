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
	var inst := _tools.grant_tool("stain_lifter")  # finite (durability 12)
	var before := inst.durability

	# water_blotch is cleaned by the stain lifter.
	_service.clean_decal("photo_1", "water_blotch", "stain_lifter")

	var after := _tools.get_owned_tools()[0].durability
	assert_eq(after, before - 1, "one use should cost one durability")


func test_tool_breaks_and_is_removed_at_zero() -> void:
	_add_photo("photo_1")
	var inst := _tools.grant_tool("stain_lifter")  # auto-equipped onto the bench
	_set_durability(inst.uid, 1)
	watch_signals(EventBus)

	_service.clean_decal("photo_1", "water_blotch", "stain_lifter")

	assert_eq(_tools.get_owned_tools().size(), 0, "a broken tool is removed from owned tools")
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
