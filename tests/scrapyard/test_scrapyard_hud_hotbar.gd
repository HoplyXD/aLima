extends GutTest

## Headless tests for the ScrapyardHud 5-slot carry inventory: the unsorted
## scrap pool bundles into one slot, restored artifacts fill the rest, and
## empty slots stay blank.

const HUD_SCENE := preload("res://scenes/ui/scrapyard_hud.tscn")


func _slot_label(hud: ScrapyardHud, index: int) -> Label:
	return hud.get_node("Hotbar").get_child(index).get_child(0)


func test_scrap_pool_bundles_into_one_slot() -> void:
	var hud: ScrapyardHud = HUD_SCENE.instantiate()
	add_child_autofree(hud)

	hud.set_inventory({"white": 2, "blue": 5, "purple": 1}, [])
	assert_eq(_slot_label(hud, 0).text, "Scrap x8", "All unsorted scrap counts as one item")
	for i in range(1, ScrapyardHud.INVENTORY_SLOTS):
		assert_eq(_slot_label(hud, i).text, "", "Remaining slots stay empty")


func test_restored_artifacts_fill_remaining_slots() -> void:
	var hud: ScrapyardHud = HUD_SCENE.instantiate()
	add_child_autofree(hud)

	hud.set_inventory(
		{"white": 1},
		[
			{"display_name": "Gold Locket", "color": Color.GOLD},
			{"display_name": "Cup", "color": Color.WHITE},
		]
	)
	assert_eq(_slot_label(hud, 0).text, "Scrap x1")
	assert_eq(_slot_label(hud, 1).text, "Gold Locket")
	assert_eq(_slot_label(hud, 2).text, "Cup")
	assert_eq(_slot_label(hud, 3).text, "")


func test_no_scrap_starts_artifacts_at_slot_zero() -> void:
	var hud: ScrapyardHud = HUD_SCENE.instantiate()
	add_child_autofree(hud)

	hud.set_inventory({}, [{"display_name": "Plate", "color": Color.WHITE}])
	assert_eq(_slot_label(hud, 0).text, "Plate")
	assert_eq(_slot_label(hud, 1).text, "")


func test_quest_and_quick_buttons_exist() -> void:
	var hud: ScrapyardHud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	hud.set_quest_count(2)
	assert_eq((hud.get_node("QuestLabel") as Label).text, "Quest: 2")
	assert_not_null(hud.get_node("QuickActions"))
