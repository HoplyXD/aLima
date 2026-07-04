extends GutTest
## DispositionRouter: the four-way SELL/RETURN/PRESERVE/JOURNAL entry point
## (P14.3/P14.7, DISP-R1..R6, CLAUDE.md §4-F/N). Eligibility, rarity routing,
## idempotency, and the formal listing are covered here.

const TEST_SAVE := "user://test_disposition_save.json"
const TEST_TEMP := "user://test_disposition_save.tmp"

var _repo: DataRepository


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()
	GameState.initialize("disposition-player")
	GameState.new_run()
	GameState.save_state.loop.money = 100
	GameState.save_state.loop.current_day = 1


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


# --- Helpers ------------------------------------------------------------------


func _add_judged(
	uid: String, template_id: String, condition: float = 80.0, value: int = 120
) -> void:
	var inst := ObjectInstance.new()
	inst.template_id = template_id
	inst.uid = uid
	inst.condition = condition
	inst.state = ModelEnums.ObjState.CLEAN
	inst.authenticity = ModelEnums.Verdict.AUTHENTIC
	inst.value = value
	inst.storage_cost = 1
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func _add_dirty(uid: String, template_id: String) -> void:
	var inst := ObjectInstance.new()
	inst.template_id = template_id
	inst.uid = uid
	inst.condition = 10.0
	inst.state = ModelEnums.ObjState.DIRTY
	inst.authenticity = ModelEnums.Verdict.UNKNOWN
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func _inventory_has(uid: String) -> bool:
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == uid:
			return true
	return false


# --- Eligibility (DISP-R1) ----------------------------------------------------


func test_dirty_item_is_not_eligible() -> void:
	_add_dirty("d1", "rusted_tin")
	assert_false(DispositionRouter.is_eligible("d1"), "an unrestored item offers no disposition")
	assert_eq(DispositionRouter.eligible_dispositions("d1").size(), 0)


func test_unjudged_item_is_not_eligible() -> void:
	var inst := ObjectInstance.new()
	inst.template_id = "rusted_tin"
	inst.uid = "u1"
	inst.condition = 90.0
	inst.state = ModelEnums.ObjState.CLEAN
	inst.authenticity = ModelEnums.Verdict.UNKNOWN  # restored but not judged
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	assert_false(DispositionRouter.is_eligible("u1"), "judgment is required first")


func test_journal_rarity_offers_journal_not_preserve() -> void:
	_add_judged("c1", "rusted_tin")  # purple-and-below
	var options := DispositionRouter.eligible_dispositions("c1")
	assert_true(options.has(DispositionRouter.Disposition.JOURNAL), "purple-and-below journals")
	assert_false(options.has(DispositionRouter.Disposition.PRESERVE), "not preservable")
	assert_true(options.has(DispositionRouter.Disposition.SELL))


func test_gold_offers_preserve_not_journal() -> void:
	_add_judged("g1", "oton_death_mask")  # gold + historical
	var options := DispositionRouter.eligible_dispositions("g1")
	assert_true(options.has(DispositionRouter.Disposition.PRESERVE), "gold preserves")
	assert_false(options.has(DispositionRouter.Disposition.JOURNAL), "gold does not journal")


func test_invalid_disposition_is_rejected_with_a_reason() -> void:
	_add_judged("c1", "rusted_tin")  # not gold
	var result := DispositionRouter.dispose("c1", DispositionRouter.Disposition.PRESERVE)
	assert_false(result.ok, "preserving a non-gold piece is rejected (DISP-R4)")
	assert_false(str(result.error).is_empty(), "a player-facing reason is given")
	assert_true(_inventory_has("c1"), "a rejected disposition does not remove the item")


# --- JOURNAL routing (DISP-R4, §4-F) -----------------------------------------


func test_journal_disposition_archives_and_removes() -> void:
	_add_judged("c1", "rusted_tin")
	watch_signals(EventBus)
	var result := DispositionRouter.dispose("c1", DispositionRouter.Disposition.JOURNAL)
	assert_true(result.ok)
	assert_false(_inventory_has("c1"), "the journaled item leaves loop inventory")
	assert_true(
		GameState.save_state.persistent.journal_entries.has("rusted_tin"),
		"a journal entry is created/updated (reuses JournalService)"
	)
	assert_signal_emitted(EventBus, "disposition_completed")


# --- PRESERVE routing (DISP-R4, §4-F) ----------------------------------------


func test_preserve_disposition_creates_a_museum_record() -> void:
	_add_judged("g1", "oton_death_mask")
	var result := DispositionRouter.dispose("g1", DispositionRouter.Disposition.PRESERVE)
	assert_true(result.ok)
	assert_false(_inventory_has("g1"), "the preserved item leaves loop inventory")
	assert_true(
		GameState.save_state.persistent.museum_entries.has("preserved_oton_death_mask"),
		"a persistent museum record is created"
	)


# --- SELL via the router + idempotency (DISP-R2, DISP-R5) --------------------


func test_sell_through_router_credits_and_logs() -> void:
	_add_judged("c1", "tarnished_pendant", 90.0, 150)
	var before := GameState.save_state.loop.money
	var result := DispositionRouter.dispose(
		"c1", DispositionRouter.Disposition.SELL, {"price": 150, "buyer_id": "collector"}
	)
	assert_true(result.ok)
	assert_eq(GameState.save_state.loop.money, before + 150)
	assert_false(_inventory_has("c1"))
	assert_eq(GameState.save_state.loop.disposition_log.size(), 1, "the disposition is logged")


func test_cannot_dispose_the_same_instance_twice() -> void:
	_add_judged("c1", "rusted_tin")
	assert_true(DispositionRouter.dispose("c1", DispositionRouter.Disposition.JOURNAL).ok)
	assert_false(
		DispositionRouter.dispose("c1", DispositionRouter.Disposition.JOURNAL).ok,
		"the same instance cannot be archived twice (DISP-R5)"
	)


# --- Formal listing (P14.1) ---------------------------------------------------


func test_listing_is_created_and_resolved_on_sale() -> void:
	_add_judged("c1", "tarnished_pendant", 90.0, 150)
	var listing := MarketplaceService.list_for_sale("c1")
	assert_not_null(listing)
	assert_eq(MarketplaceService.get_active_listings().size(), 1)
	DispositionRouter.complete_sell("c1", 150, "collector")
	assert_eq(
		MarketplaceService.get_active_listings().size(),
		0,
		"the listing is resolved (SOLD) once the sale completes"
	)
