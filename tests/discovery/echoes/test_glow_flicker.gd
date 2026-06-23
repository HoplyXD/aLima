extends GutTest
## Tests for glow flicker authorization via GlowMapper + EchoController.

const TEST_SAVE := "user://test_phase6_glow_save.json"
const TEST_TEMP := "user://test_phase6_glow_save.tmp"


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	var repo := DataRepository.singleton()
	repo.load_from_filesystem()
	GameState.initialize("phase6-glow-player")
	GameState.set_debug_seed_override(4242)
	GameState.new_run()
	_grant_starting_kit()
	# fragment_01 (the carrier under test) now starts LOCKED in authored data (released
	# by the Auntie route at runtime, Phase 10); release it so flicker is authorized.
	GameState.save_state.persistent.fragments["fragment_01"].state = (
		ModelEnums.FragmentState.RELEASED
	)
	EchoController.clear_active_target()


func after_each() -> void:
	EchoController.clear_active_target()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _grant_starting_kit() -> void:
	var repo := DataRepository.singleton()
	for technique_id in repo.starting_kit.get("technique_ids", []):
		if not GameState.save_state.persistent.techniques_learned.has(technique_id):
			GameState.save_state.persistent.techniques_learned.append(technique_id)
	for tool_id in repo.starting_kit.get("tool_ids", []):
		var tool := repo.get_tool(tool_id)
		if tool == null:
			continue
		if tool.is_legacy:
			if not GameState.save_state.persistent.legacy_items.has(tool_id):
				GameState.save_state.persistent.legacy_items.append(tool_id)
		if not GameState.save_state.loop.tool_items.has(tool_id):
			GameState.save_state.loop.tool_items.append(tool_id)


func test_only_active_carrier_receives_flicker_authorization() -> void:
	var active := _make_carrier("fragment_01", "active_carrier")
	var other := _make_carrier("fragment_01", "other_carrier")
	GameState.save_state.loop.inventory.append(active.to_dictionary())
	GameState.save_state.loop.inventory.append(other.to_dictionary())
	EchoController.clear_active_target()
	EventBus.carrier_activated.emit(active.uid, active.fragment_id)
	EchoController.set_listener_position(Vector3.ZERO)
	EchoController.set_carrier_position(Vector3(0.5, 0.0, 0.0))
	EchoController.update(0.0)

	assert_true(EchoController.is_flicker_authorized(active.uid))
	assert_false(EchoController.is_flicker_authorized(other.uid))


func test_carrier_glow_is_ordinary_below_reveal() -> void:
	var inst := _make_carrier("fragment_01", "carrier_ordinary_glow")
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	EchoController.clear_active_target()
	EventBus.carrier_activated.emit(inst.uid, inst.fragment_id)
	EchoController.set_listener_position(Vector3.ZERO)
	EchoController.set_carrier_position(Vector3(4.0, 0.0, 0.0))
	EchoController.update(0.0)

	var template: ScrapObjectTemplate = DataRepository.singleton().get_template(inst.template_id)
	var authorized := EchoController.is_flicker_authorized(inst.uid)
	assert_false(authorized)
	var state := GlowMapper.resolve_glow_state(template.base_rarity, inst.is_carrier, authorized)
	assert_eq(state, GlowMapper.rarity_to_glow_state(template.base_rarity))


func test_carrier_glow_becomes_flickering_at_reveal() -> void:
	var inst := _make_carrier("fragment_01", "carrier_flicker_glow")
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	EchoController.clear_active_target()
	EventBus.carrier_activated.emit(inst.uid, inst.fragment_id)
	EchoController.set_listener_position(Vector3.ZERO)
	EchoController.set_carrier_position(Vector3(0.5, 0.0, 0.0))
	EchoController.update(0.0)

	var template: ScrapObjectTemplate = DataRepository.singleton().get_template(inst.template_id)
	var authorized := EchoController.is_flicker_authorized(inst.uid)
	assert_true(authorized)
	var state := GlowMapper.resolve_glow_state(template.base_rarity, inst.is_carrier, authorized)
	assert_eq(state, ModelEnums.GlowState.FLICKERING)


func test_decoy_remains_ordinary_glow_at_max_proximity() -> void:
	var inst := _make_decoy("decoy_glow")
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	EchoController.clear_active_target()
	EventBus.carrier_activated.emit(inst.uid, "")
	EchoController.set_listener_position(Vector3.ZERO)
	EchoController.set_carrier_position(Vector3.ZERO)
	EchoController.update(0.0)

	var template: ScrapObjectTemplate = DataRepository.singleton().get_template(inst.template_id)
	var authorized := EchoController.is_flicker_authorized(inst.uid)
	assert_false(authorized)
	var state := GlowMapper.resolve_glow_state(template.base_rarity, inst.is_carrier, authorized)
	assert_eq(state, GlowMapper.rarity_to_glow_state(template.base_rarity))


func test_target_loss_restores_ordinary_glow() -> void:
	var inst := _make_carrier("fragment_01", "carrier_loss")
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	EchoController.clear_active_target()
	EventBus.carrier_activated.emit(inst.uid, inst.fragment_id)
	EchoController.set_listener_position(Vector3.ZERO)
	EchoController.set_carrier_position(Vector3(0.5, 0.0, 0.0))
	EchoController.update(0.0)
	assert_true(EchoController.is_flicker_authorized(inst.uid))

	EchoController.clear_active_target()
	var template: ScrapObjectTemplate = DataRepository.singleton().get_template(inst.template_id)
	var state := GlowMapper.resolve_glow_state(template.base_rarity, inst.is_carrier, false)
	assert_eq(state, GlowMapper.rarity_to_glow_state(template.base_rarity))


func _make_carrier(fragment_id: String, uid: String) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.template_id = "tarnished_pendant"
	inst.uid = uid
	inst.is_carrier = true
	inst.fragment_id = fragment_id
	inst.contents = ModelEnums.OpenResult.FRAGMENT
	inst.state = ModelEnums.ObjState.DIRTY
	inst.assigned_anchor_id = "pile_center"
	return inst


func _make_decoy(uid: String) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.template_id = "tarnished_pendant"
	inst.uid = uid
	inst.is_carrier = false
	inst.fragment_id = ""
	inst.contents = ModelEnums.OpenResult.EMPTY
	inst.state = ModelEnums.ObjState.DIRTY
	inst.assigned_anchor_id = "pile_center"
	return inst
