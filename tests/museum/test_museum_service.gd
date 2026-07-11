extends GutTest
## Tests for MuseumService: archive routing, idempotency, persistence, offline
## resilience, and backend integration seams (P16.4, MUS-R1..R3, DISP-R4).

const TEST_SAVE := "user://test_museum_save.json"
const TEST_TEMP := "user://test_museum_save.tmp"


class FakePortalClient:
	extends PortalClient

	var next_record_result: MuseumResult = null
	var next_entries_result: MuseumResult = null
	var requested_records: Array[Dictionary] = []
	var requested_players: Array[String] = []

	func request_museum_record(request: MuseumRecordRequest) -> void:
		requested_records.append(request.to_dictionary())
		if next_record_result != null:
			museum_record_completed.emit(next_record_result)

	func request_museum_entries(player_id: String) -> void:
		requested_players.append(player_id)
		if next_entries_result != null:
			museum_entries_completed.emit(next_entries_result)


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("museum-player")
	GameState.new_run()


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _add_judged_gold(uid: String) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.uid = uid
	inst.template_id = "oton_death_mask"
	inst.condition = 92.0
	inst.state = ModelEnums.ObjState.CLEAN
	inst.authenticity = ModelEnums.Verdict.AUTHENTIC
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	return inst


func _add_judged_purple(uid: String) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.uid = uid
	inst.template_id = "rusted_tin"
	inst.condition = 88.0
	inst.state = ModelEnums.ObjState.CLEAN
	inst.authenticity = ModelEnums.Verdict.AUTHENTIC
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	return inst


func test_gold_preserve_creates_museum_entry_and_posts_to_portal() -> void:
	var inst := _add_judged_gold("g1")
	var template := DataRepository.singleton().get_template(inst.template_id)
	var fake := FakePortalClient.new()
	MuseumService.set_client(fake)

	var received: Array = []
	EventBus.museum_entry_recorded.connect(
		func(entry_id: String, record_id: String, fallback: bool):
			received.append([entry_id, record_id, fallback])
	)

	var entry_id := MuseumService.post_gold_discovery(inst, template)

	assert_eq(entry_id, "entry_oton_death_mask_museum-player")
	assert_true(GameState.save_state.persistent.museum_entries.has(entry_id))
	assert_eq(fake.requested_records.size(), 1)
	assert_eq(fake.requested_records[0]["record_id"], "oton_death_mask")
	assert_eq(fake.requested_records[0]["rarity"], "gold")
	assert_eq(received.size(), 1)
	assert_eq(received[0][0], entry_id)


func test_gold_preserve_is_idempotent() -> void:
	var inst := _add_judged_gold("g1")
	var template := DataRepository.singleton().get_template(inst.template_id)
	var fake := FakePortalClient.new()
	MuseumService.set_client(fake)

	var first := MuseumService.post_gold_discovery(inst, template)
	var second := MuseumService.post_gold_discovery(inst, template)

	assert_eq(first, second)
	assert_eq(GameState.save_state.persistent.museum_entries.size(), 1)
	assert_eq(fake.requested_records.size(), 2, "each call still tries to confirm with the backend")


func test_purple_disposition_does_not_create_museum_entry() -> void:
	_add_judged_purple("c1")

	var result := DispositionRouter.dispose("c1", DispositionRouter.Disposition.PRESERVE)

	assert_false(result.ok, "PRESERVE is rejected for non-Gold items (DISP-R4)")
	assert_true(
		GameState.save_state.persistent.museum_entries.is_empty(),
		"Purple-and-below never enters the museum (§4-F)"
	)


func test_purple_goes_to_journal_not_museum() -> void:
	var inst := _add_judged_purple("c1")
	var result := DispositionRouter.dispose("c1", DispositionRouter.Disposition.JOURNAL)

	assert_true(result.ok)
	assert_true(GameState.save_state.persistent.journal_entries.has("rusted_tin"))
	assert_true(GameState.save_state.persistent.museum_entries.is_empty())


func test_journal_disposition_rejected_for_gold() -> void:
	_add_judged_gold("g1")

	var result := DispositionRouter.dispose("g1", DispositionRouter.Disposition.JOURNAL)

	assert_false(result.ok, "JOURNAL is rejected for Gold items (§4-F)")


func test_offline_post_still_persists_local_record() -> void:
	var inst := _add_judged_gold("g1")
	var template := DataRepository.singleton().get_template(inst.template_id)
	var fake := FakePortalClient.new()
	fake.next_record_result = MuseumResult.new(
		MuseumResult.Status.NETWORK_ERROR, MuseumRecordResponse.new(), [], "backend down"
	)
	MuseumService.set_client(fake)

	var entry_id := MuseumService.post_gold_discovery(inst, template)

	assert_true(GameState.save_state.persistent.museum_entries.has(entry_id))
	var entry: MuseumEntry = GameState.save_state.persistent.museum_entries[entry_id]
	assert_false(entry.fact_card.is_empty())


func test_refresh_gallery_merges_server_records() -> void:
	var fake := FakePortalClient.new()
	var response := MuseumRecordResponse.new()
	response.museum_entry_id = "entry_test_gold_museum-player"
	response.record_id = "test_gold"
	response.fact_card = "Server fact"
	fake.next_entries_result = MuseumResult.new(MuseumResult.Status.SUCCESS, null, [response])
	MuseumService.set_client(fake)

	MuseumService.refresh_gallery()

	assert_true(GameState.save_state.persistent.museum_entries.has("entry_test_gold_museum-player"))
	var entry: MuseumEntry = (
		GameState.save_state.persistent.museum_entries["entry_test_gold_museum-player"]
	)
	assert_eq(entry.fact_card, "Server fact")
