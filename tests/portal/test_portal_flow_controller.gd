extends GutTest
## Tests for PortalFlowController signal flow and idempotency.

const PortalFlowControllerScript := preload("res://scripts/shop/portal_flow_controller.gd")

var _controller: PortalFlowController = null
var _mock_client: MockPortalClient = null


class MockPortalClient:
	extends PortalClient

	signal mock_discovery_requested(fragment_id: String, condition: int, context: String)

	var next_result: PortalResult = null

	func request_discovery(fragment_id: String, condition: int, context: String = "") -> void:
		mock_discovery_requested.emit(fragment_id, condition, context)
		if next_result != null:
			discovery_completed.emit(next_result)


func before_each() -> void:
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("test-player")
	SaveService.set_save_paths("user://portal_test_save.json", "user://portal_test_save.tmp")
	SaveService.delete_save_files()
	_controller = PortalFlowControllerScript.new()
	_mock_client = MockPortalClient.new()
	add_child_autofree(_controller)
	_controller.set_client(_mock_client)


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _make_fragment(id: String, slot: int) -> Fragment:
	var fragment := Fragment.new()
	fragment.id = id
	fragment.master_artifact_id = "master_artifact_demo"
	fragment.owning_character_id = "auntie"
	fragment.case_slot_index = slot
	fragment.state = ModelEnums.FragmentState.RELEASED
	fragment.echo_set_ref = "demo_echo_set"
	fragment.historical_fact_ref = ""
	return fragment


func _make_instance(template_id: String, fragment_id: String) -> ObjectInstance:
	var instance := ObjectInstance.new()
	instance.uid = "inst_%s" % template_id
	instance.template_id = template_id
	instance.condition = 88.0
	instance.is_carrier = true
	instance.fragment_id = fragment_id
	instance.contents = ModelEnums.OpenResult.FRAGMENT
	return instance


func test_fragment_discovered_opens_flow_and_requests_discovery() -> void:
	GameState.save_state.persistent.fragments["fragment_01"] = _make_fragment("fragment_01", 0)
	GameState.save_state.loop.inventory.append(_make_instance("tarnished_pendant", "fragment_01"))

	var requested: Array = []
	_mock_client.mock_discovery_requested.connect(
		func(id: String, condition: int, _ctx: String): requested.append([id, condition])
	)

	EventBus.fragment_discovered.emit("fragment_01", "inst_tarnished_pendant")
	_controller._on_found_continue()

	assert_eq(requested.size(), 1)
	assert_eq(requested[0][0], "fragment_01")
	assert_eq(requested[0][1], 88)


func test_success_emits_portal_completed_signal() -> void:
	GameState.save_state.persistent.fragments["fragment_01"] = _make_fragment("fragment_01", 0)
	GameState.save_state.loop.inventory.append(_make_instance("tarnished_pendant", "fragment_01"))

	var response := PortalDiscoveryResponse.new()
	response.ok = true
	response.museum_entry_id = "entry_fragment_01_player"
	response.fragment_index = 1
	response.fact_card = "A gear."
	response.used_fallback = false
	_mock_client.next_result = PortalResult.new(PortalResult.Status.SUCCESS, response)

	var portal_completed: Array = []
	EventBus.portal_completed.connect(
		func(id: String, entry: String, fallback: bool, fact: String):
			portal_completed.append([id, entry, fallback, fact])
	)

	EventBus.fragment_discovered.emit("fragment_01", "inst_tarnished_pendant")
	_controller._on_found_continue()

	assert_eq(portal_completed.size(), 1)
	assert_eq(portal_completed[0][0], "fragment_01")
	assert_eq(portal_completed[0][1], "entry_fragment_01_player")
	assert_eq(portal_completed[0][2], false)
	assert_eq(portal_completed[0][3], "A gear.")


func test_fallback_emits_portal_completed_with_fallback_flag() -> void:
	GameState.save_state.persistent.fragments["fragment_02"] = _make_fragment("fragment_02", 1)
	GameState.save_state.loop.inventory.append(_make_instance("rusted_tin", "fragment_02"))

	var response := PortalDiscoveryResponse.new()
	response.ok = true
	response.museum_entry_id = "entry_fragment_02_player"
	response.fragment_index = 2
	response.fact_card = "A plate."
	response.used_fallback = true
	_mock_client.next_result = PortalResult.new(PortalResult.Status.FALLBACK, response)

	var portal_completed: Array = []
	EventBus.portal_completed.connect(
		func(id: String, entry: String, fallback: bool, _fact: String):
			portal_completed.append([id, entry, fallback])
	)

	EventBus.fragment_discovered.emit("fragment_02", "inst_rusted_tin")
	_controller._on_found_continue()

	assert_eq(portal_completed.size(), 1)
	assert_eq(portal_completed[0][2], true)


func test_failure_does_not_emit_portal_completed() -> void:
	GameState.save_state.persistent.fragments["fragment_03"] = _make_fragment("fragment_03", 2)
	GameState.save_state.loop.inventory.append(_make_instance("cracked_photo_frame", "fragment_03"))

	var err := PortalDiscoveryResponse.new()
	err.ok = false
	err.error = "backend error"
	_mock_client.next_result = PortalResult.new(
		PortalResult.Status.NETWORK_ERROR, err, "backend error"
	)

	var portal_completed: Array = []
	EventBus.portal_completed.connect(
		func(id: String, entry: String, fallback: bool, _fact: String):
			portal_completed.append([id, entry, fallback])
	)

	EventBus.fragment_discovered.emit("fragment_03", "inst_frame")
	_controller._on_found_continue()

	assert_eq(portal_completed.size(), 0)


func test_backend_unavailable_leaves_recoverable_state() -> void:
	## P11.4 resilience: a network/backend failure must not seat the fragment,
	## corrupt save state, or remove the instance. The player can close the screen
	## and retry later.
	GameState.save_state.persistent.fragments["fragment_03"] = _make_fragment("fragment_03", 2)
	GameState.save_state.loop.inventory.append(_make_instance("cracked_photo_frame", "fragment_03"))
	var loop_money_before := GameState.save_state.loop.money

	var err := PortalDiscoveryResponse.new()
	err.ok = false
	err.error = "cannot connect to backend"
	_mock_client.next_result = PortalResult.new(
		PortalResult.Status.NETWORK_ERROR, err, "cannot connect to backend"
	)

	EventBus.fragment_discovered.emit("fragment_03", "inst_frame")
	_controller._on_found_continue()

	assert_eq(
		GameState.save_state.persistent.fragments["fragment_03"].state,
		ModelEnums.FragmentState.RELEASED
	)
	assert_eq(GameState.save_state.loop.inventory.size(), 1)
	assert_eq(GameState.save_state.loop.money, loop_money_before)
	# Closing the error screen releases pause and clears pending state without seating.
	_controller._on_found_closed()
	assert_true(_controller._pending_fragment_id.is_empty())


func test_save_reload_before_and_after_portal_completion() -> void:
	## P11.4 resilience: the fragment stays RELEASED (not seated) before the Portal
	## completes; after a successful Portal response the seated state persists
	## through save/reload.
	GameState.save_state.persistent.fragments["fragment_01"] = _make_fragment("fragment_01", 0)
	GameState.save_state.loop.inventory.append(_make_instance("tarnished_pendant", "fragment_01"))

	# Save before Portal completion: fragment is released but not seated.
	assert_true(SaveService.save_game().ok, "Save before Portal should succeed")
	GameState.initialize("other-player")
	assert_true(SaveService.load_game().ok, "Load before-Portal save should succeed")
	assert_eq(
		GameState.save_state.persistent.fragments["fragment_01"].state,
		ModelEnums.FragmentState.RELEASED
	)
	assert_eq(GameState.save_state.persistent.museum_entries.size(), 0)

	# Complete the Portal flow and save again.
	var response := PortalDiscoveryResponse.new()
	response.ok = true
	response.museum_entry_id = "entry_fragment_01_player"
	response.fragment_index = 1
	response.fact_card = "A gear."
	response.used_fallback = false
	_mock_client.next_result = PortalResult.new(PortalResult.Status.SUCCESS, response)

	EventBus.fragment_discovered.emit("fragment_01", "inst_tarnished_pendant")
	_controller._on_found_continue()

	assert_eq(
		GameState.save_state.persistent.fragments["fragment_01"].state,
		ModelEnums.FragmentState.SEATED
	)
	assert_eq(GameState.save_state.persistent.museum_entries.size(), 1)

	assert_true(SaveService.save_game().ok, "Save after Portal should succeed")
	GameState.initialize("other-player")
	assert_true(SaveService.load_game().ok, "Load after-Portal save should succeed")
	assert_eq(
		GameState.save_state.persistent.fragments["fragment_01"].state,
		ModelEnums.FragmentState.SEATED
	)
	assert_eq(GameState.save_state.persistent.museum_entries.size(), 1)
	assert_true(
		GameState.save_state.persistent.museum_entries.has("entry_fragment_01_player"),
		"Museum entry key survives reload"
	)
