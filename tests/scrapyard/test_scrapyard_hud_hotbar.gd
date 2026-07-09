extends GutTest

## Headless tests for the ScrapyardHud 5-slot carry inventory (3D preview
## cards): each unsorted scrap piece takes its own slot (non-stackable), only
## overflowing into a stacked final slot; restored artifacts keep their slots,
## and each filled slot carries inspection data for the overlay.

const HUD_SCENE := preload("res://scenes/ui/scrapyard_hud.tscn")


func _make_hud() -> ScrapyardHud:
	var hud: ScrapyardHud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	return hud


func _slot_name(hud: ScrapyardHud, index: int) -> String:
	var card: Preview3DCard = hud.get_node("Hotbar").get_child(index)
	return card.get_node("%NameLabel").text


func test_each_scrap_piece_takes_its_own_slot() -> void:
	var hud := _make_hud()
	hud.set_inventory(3, [] as Array[Dictionary], {"white": 2, "gold": 1})
	for i in 3:
		assert_eq(_slot_name(hud, i), "Scrap", "Each scrap piece is its own slot")
		assert_true(bool(hud._slot_data[i].get("is_scrap", false)))
		assert_not_null(hud._slot_data[i].get("preview"), "Each scrap slot carries a 3D preview")
	for i in range(3, ScrapyardHud.INVENTORY_SLOTS):
		assert_eq(_slot_name(hud, i), "", "Remaining slots stay empty")


func test_scrap_overflow_collapses_into_stacked_last_slot() -> void:
	var hud := _make_hud()
	hud.set_inventory(8, [] as Array[Dictionary], {"white": 8})
	for i in range(0, ScrapyardHud.INVENTORY_SLOTS - 1):
		assert_eq(_slot_name(hud, i), "Scrap", "Leading slots hold single pieces")
	# 4 singles + the remaining 4 stacked in the last slot.
	assert_eq(
		_slot_name(hud, ScrapyardHud.INVENTORY_SLOTS - 1),
		"Scrap x4",
		"Overflow stacks into the final scrap slot"
	)


func test_restored_artifacts_keep_their_slots_over_scrap() -> void:
	var hud := _make_hud()
	var restored: Array[Dictionary] = [
		{"display_name": "Gold Locket", "color": Color.GOLD, "preview": Node3D.new()},
		{"display_name": "Cup", "color": Color.WHITE, "preview": Node3D.new()},
	]
	hud.set_inventory(1, restored, {"white": 1})
	assert_eq(_slot_name(hud, 0), "Scrap")
	assert_eq(_slot_name(hud, 1), "Gold Locket")
	assert_eq(_slot_name(hud, 2), "Cup")
	assert_eq(_slot_name(hud, 3), "")


func test_scrap_without_breakdown_still_fills_slots() -> void:
	# Callers that pass no breakdown (legacy signature) still get one slot per piece.
	var hud := _make_hud()
	hud.set_inventory(2, [] as Array[Dictionary])
	assert_eq(_slot_name(hud, 0), "Scrap")
	assert_eq(_slot_name(hud, 1), "Scrap")
	assert_eq(_slot_name(hud, 2), "")


func test_no_scrap_starts_artifacts_at_slot_zero() -> void:
	var hud := _make_hud()
	var restored: Array[Dictionary] = [
		{"display_name": "Plate", "color": Color.WHITE, "preview": Node3D.new()},
	]
	hud.set_inventory(0, restored)
	assert_eq(_slot_name(hud, 0), "Plate")
	assert_eq(_slot_name(hud, 1), "")


func test_slot_click_reports_inspection_data() -> void:
	var hud := _make_hud()
	hud.set_inventory(3, [] as Array[Dictionary])
	watch_signals(hud)
	var card: Preview3DCard = hud.get_node("Hotbar").get_child(0)
	card.clicked.emit()
	assert_signal_emitted(hud, "item_inspected")


func test_quest_and_quick_buttons_exist() -> void:
	var hud := _make_hud()
	hud.set_quest_count(2)
	# The top-right counter now tracks seated fragments; active quests moved to the
	# node-based QuestTracker (see tests/ui/test_quest_tracker.gd).
	assert_eq((hud.get_node("QuestLabel") as Label).text, "Fragments: 2")
	assert_not_null(hud.get_node("QuickActions"))
	assert_not_null(hud.get_node("QuestTracker"))
