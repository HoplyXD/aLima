extends GutTest

## Headless tests for the ScrapyardHud 5-slot scrap hotbar.

const HUD_SCENE := preload("res://scenes/ui/scrapyard_hud.tscn")


func test_hotbar_maps_five_tier_slots_to_scrap_pool() -> void:
	var hud: ScrapyardHud = HUD_SCENE.instantiate()
	add_child_autofree(hud)

	var pool := {"white": 2, "green": 0, "blue": 5, "purple": 1, "gold": 0}
	hud.set_hotbar(pool)

	for i in ModelEnums.RARITY_NAMES.size():
		var rarity_name: String = ModelEnums.RARITY_NAMES[i]
		var slot: Control = hud.get_node("Hotbar").get_child(i)
		var label: Label = slot.get_child(0)
		assert_eq(
			label.text,
			str(pool.get(rarity_name, 0)),
			"slot %d (%s) should show the carried count" % [i, rarity_name]
		)


func test_hotbar_defaults_to_zero_for_missing_tiers() -> void:
	var hud: ScrapyardHud = HUD_SCENE.instantiate()
	add_child_autofree(hud)

	hud.set_hotbar({"blue": 3})

	for i in ModelEnums.RARITY_NAMES.size():
		var rarity_name: String = ModelEnums.RARITY_NAMES[i]
		var slot: Control = hud.get_node("Hotbar").get_child(i)
		var label: Label = slot.get_child(0)
		var expected := 3 if rarity_name == "blue" else 0
		assert_eq(label.text, str(expected), "missing tiers should default to zero")
