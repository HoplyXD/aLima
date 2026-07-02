extends GutTest

## Headless tests for the ScrapyardHud 5-slot carry inventory (3D preview
## cards): unsorted scrap bundles into one slot, restored artifacts fill the
## rest, and each filled slot carries inspection data for the overlay.

const HUD_SCENE := preload("res://scenes/ui/scrapyard_hud.tscn")


func _make_hud() -> ScrapyardHud:
	var hud: ScrapyardHud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	return hud


func _slot_name(hud: ScrapyardHud, index: int) -> String:
	var card: Preview3DCard = hud.get_node("Hotbar").get_child(index)
	return card.get_node("%NameLabel").text


func test_scrap_pool_bundles_into_one_slot() -> void:
	var hud := _make_hud()
	hud.set_inventory(8, [] as Array[Dictionary])
	assert_eq(_slot_name(hud, 0), "Scrap x8", "All unsorted scrap counts as one item")
	for i in range(1, ScrapyardHud.INVENTORY_SLOTS):
		assert_eq(_slot_name(hud, i), "", "Remaining slots stay empty")
	assert_true(bool(hud._slot_data[0].get("is_scrap", false)))
	assert_not_null(hud._slot_data[0].get("preview"), "The scrap slot carries a 3D preview")


func test_restored_artifacts_fill_remaining_slots() -> void:
	var hud := _make_hud()
	var restored: Array[Dictionary] = [
		{"display_name": "Gold Locket", "color": Color.GOLD, "preview": Node3D.new()},
		{"display_name": "Cup", "color": Color.WHITE, "preview": Node3D.new()},
	]
	hud.set_inventory(1, restored)
	assert_eq(_slot_name(hud, 0), "Scrap x1")
	assert_eq(_slot_name(hud, 1), "Gold Locket")
	assert_eq(_slot_name(hud, 2), "Cup")
	assert_eq(_slot_name(hud, 3), "")


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
	assert_eq((hud.get_node("QuestLabel") as Label).text, "Quest: 2")
	assert_not_null(hud.get_node("QuickActions"))
