extends GutTest
## Tests for EchoController lifecycle, gates, and event reactions.

const TEST_SAVE := "user://test_phase6_save.json"
const TEST_TEMP := "user://test_phase6_save.tmp"

var _repo: DataRepository


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()
	GameState.initialize("phase6-test-player")
	GameState.set_debug_seed_override(4242)
	GameState.new_run()
	_grant_starting_kit()
	# fragment_01 is the active carrier these echo tests exercise. It now starts
	# LOCKED in authored data (released by the Auntie route at runtime, Phase 10), so
	# release it here; the EchoController gates echoes on persistent RELEASED state.
	GameState.save_state.persistent.fragments["fragment_01"].state = (
		ModelEnums.FragmentState.RELEASED
	)
	EchoController.clear_active_target()


func after_each() -> void:
	EchoController.clear_active_target()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _grant_starting_kit() -> void:
	for technique_id in _repo.starting_kit.get("technique_ids", []):
		if not GameState.save_state.persistent.techniques_learned.has(technique_id):
			GameState.save_state.persistent.techniques_learned.append(technique_id)
	for tool_id in _repo.starting_kit.get("tool_ids", []):
		var tool := _repo.get_tool(tool_id)
		if tool == null:
			continue
		if tool.is_legacy:
			if not GameState.save_state.persistent.legacy_items.has(tool_id):
				GameState.save_state.persistent.legacy_items.append(tool_id)
		if not GameState.save_state.loop.tool_items.has(tool_id):
			GameState.save_state.loop.tool_items.append(tool_id)


func test_no_active_target_means_silence() -> void:
	var state := EchoController.get_state()
	assert_false(state.get("valid", true))
	assert_almost_eq(state.get("proximity", 1.0), 0.0, 0.001)


func test_locked_fragment_remains_silent() -> void:
	var fragment: Fragment = GameState.save_state.persistent.fragments.get("fragment_02")
	fragment.state = ModelEnums.FragmentState.LOCKED
	var inst := _make_carrier("fragment_02", "carrier_locked")
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	_activate(inst)
	var state := EchoController.get_state()
	assert_false(state.get("valid", true))


func test_seated_fragment_remains_silent() -> void:
	var fragment: Fragment = GameState.save_state.persistent.fragments.get("fragment_01")
	fragment.state = ModelEnums.FragmentState.SEATED
	var inst := _make_carrier("fragment_01", "carrier_seated")
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	_activate(inst)
	var state := EchoController.get_state()
	assert_false(state.get("valid", true))


func test_decoy_produces_silence_and_no_heartbeat() -> void:
	var inst := _make_decoy("decoy_01")
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	_activate(inst)
	EchoController.set_listener_position(Vector3.ZERO)
	EchoController.set_carrier_position(Vector3(0.5, 0.0, 0.0))
	EchoController.update(0.0)
	# Decoys are not valid echo targets; heartbeat is structurally impossible.
	assert_false(EchoController.is_heartbeat_authorized(inst.uid))
	var state := EchoController.get_state()
	assert_false(state.get("valid", true))
	assert_almost_eq(state["gains"][EchoMixer.BAND_HEARTBEAT], 0.0, 0.001)


func test_forced_maximum_proximity_cannot_authorize_decoy_heartbeat() -> void:
	var inst := _make_decoy("decoy_02")
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	_activate(inst)
	EchoController.set_listener_position(Vector3.ZERO)
	EchoController.set_carrier_position(Vector3.ZERO)
	EchoController.update(0.0)
	assert_false(EchoController.is_heartbeat_authorized(inst.uid))


func test_carrier_authorizes_heartbeat_and_hides_flicker_below_reveal() -> void:
	var inst := _make_carrier("fragment_01", "carrier_auth")
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	_activate(inst)
	EchoController.set_listener_position(Vector3.ZERO)
	# Distance ~3.9 yields proximity ~0.55, below GLOW_REVEAL_AT.
	EchoController.set_carrier_position(Vector3(3.9, 0.0, 0.0))
	_converge()
	assert_true(EchoController.is_heartbeat_authorized(inst.uid))
	assert_false(EchoController.is_flicker_authorized(inst.uid))


func test_flicker_hidden_below_threshold() -> void:
	var inst := _make_carrier("fragment_01", "carrier_below")
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	_activate(inst)
	EchoController.set_listener_position(Vector3.ZERO)
	# Choose a distance that yields ~0.55 proximity.
	EchoController.set_carrier_position(Vector3(4.0, 0.0, 0.0))
	_converge()
	assert_lt(EchoController.get_state().get("proximity", 0.0), GlowMapper.GLOW_REVEAL_AT)
	assert_false(EchoController.is_flicker_authorized(inst.uid))


func test_flicker_appears_at_threshold() -> void:
	var inst := _make_carrier("fragment_01", "carrier_above")
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	_activate(inst)
	EchoController.set_listener_position(Vector3.ZERO)
	EchoController.set_carrier_position(Vector3(0.5, 0.0, 0.0))
	_converge()
	assert_gte(EchoController.get_state().get("proximity", 0.0), GlowMapper.GLOW_REVEAL_AT)
	assert_true(EchoController.is_flicker_authorized(inst.uid))


func test_discovery_stops_echo() -> void:
	var inst := _make_carrier("fragment_01", "carrier_found")
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	_activate(inst)
	EventBus.fragment_discovered.emit("fragment_01", inst.uid)
	var state := EchoController.get_state()
	assert_false(state.get("valid", true))


func test_loop_reset_clears_target() -> void:
	var inst := _make_carrier("fragment_01", "carrier_reset")
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	_activate(inst)
	EventBus.loop_reset.emit(2)
	assert_false(EchoController.get_state().get("valid", true))


func test_recycled_carrier_clears_target() -> void:
	var inst := _make_carrier("fragment_01", "carrier_recycled")
	GameState.save_state.loop.current_delivery_ids.append(inst.uid)
	_activate(inst)
	EventBus.triage_completed.emit([], [inst.uid])
	assert_false(EchoController.get_state().get("valid", true))


func test_opened_carrier_stops_echo() -> void:
	var inst := _make_carrier("fragment_01", "carrier_opened")
	inst.state = ModelEnums.ObjState.OPEN
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	_activate(inst)
	var state := EchoController.get_state()
	assert_false(state.get("valid", true))


func test_muted_mode_still_exposes_meter_and_captions() -> void:
	var inst := _make_carrier("fragment_01", "carrier_muted")
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	_activate(inst)
	EchoController.set_listener_position(Vector3.ZERO)
	# Distance ~2.6 places the voice band near its peak.
	EchoController.set_carrier_position(Vector3(2.6, 0.0, 0.0))
	_converge()
	var state := EchoController.get_state()
	assert_true(state.get("valid", false))
	assert_gt(state.get("proximity", 0.0), 0.0)
	assert_true(state["active_bands"].size() > 0)
	assert_ne(state.get("voice_caption", ""), "")


func test_ordinary_and_promoted_instances_identical_below_threshold() -> void:
	var carrier := _make_carrier("fragment_01", "carrier_glow")
	var decoy := _make_decoy("decoy_glow")
	carrier.assigned_anchor_id = "pile_left"
	decoy.assigned_anchor_id = "pile_left"
	GameState.save_state.loop.inventory.append(carrier.to_dictionary())
	GameState.save_state.loop.inventory.append(decoy.to_dictionary())
	_activate(carrier)
	EchoController.set_listener_position(Vector3.ZERO)
	EchoController.set_carrier_position(Vector3(4.0, 0.0, 0.0))
	_converge()
	assert_false(EchoController.is_flicker_authorized(carrier.uid))
	assert_false(EchoController.is_flicker_authorized(decoy.uid))


func _activate(inst: ObjectInstance) -> void:
	EchoController.clear_active_target()
	EventBus.carrier_activated.emit(inst.uid, inst.fragment_id)


func _converge() -> void:
	for i in range(30):
		EchoController.update(0.05)


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
