extends GutTest

## Smoke test for the authored scrapyard scene. Ensures the template scene
## instantiates, exposes the anchors the rest of the game expects, and wires
## the player controller and return-door interactable.

const YARD_SCENE := preload("res://scenes/scrapyard/Scrapyard.tscn")

var _yard: Node3D


func before_each() -> void:
	_yard = YARD_SCENE.instantiate()
	add_child_autofree(_yard)
	await wait_physics_frames(1)


func test_yard_root_has_scrapyard_script() -> void:
	assert_is(_yard, Node3D, "Yard root is a Node3D")
	assert_not_null(_yard.get_script(), "Yard root has a script")


func test_map_root_exists_for_glb_swap() -> void:
	var map_root := _yard.get_node_or_null("MapRoot")
	assert_not_null(map_root, "MapRoot exists for placeholder/GLB art")
	assert_is(map_root, Node3D)


func test_anchors_exist() -> void:
	for anchor_name in ["PlayerSpawn", "AylaAnchor", "DeliveryBay"]:
		var anchor := _yard.get_node_or_null("Anchors/%s" % anchor_name)
		assert_not_null(anchor, "%s anchor should exist" % anchor_name)
		assert_is(anchor, Marker3D, "%s should be a Marker3D" % anchor_name)

	var door_return := _yard.get_node_or_null("Anchors/DoorReturn")
	assert_not_null(door_return, "DoorReturn anchor should exist")
	assert_is(door_return, Interactable3D, "DoorReturn should be the return-door Interactable3D")


func test_player_instance_present() -> void:
	var player := _yard.get_node_or_null("Player")
	assert_not_null(player, "Player node should be instanced")
	assert_is(player, CharacterBody3D, "Player should be a CharacterBody3D")
	assert_not_null(player.get_script(), "Player should have a controller script")


func test_return_door_interactable_exists() -> void:
	var door := _yard.get_node_or_null("Anchors/DoorReturn")
	assert_not_null(door, "Return door interactable should exist")
	assert_is(door, Interactable3D, "Return door should be an Interactable3D")
	assert_true(door.use_proximity, "Return door should use proximity interaction")
	assert_eq(door.proximity_prompt_text, "Press E to enter", "Return door prompt should mention the interact key")


func test_hud_exists() -> void:
	var hud := _yard.get_node_or_null("ScrapyardHud")
	assert_not_null(hud, "ScrapyardHud should be present")
	assert_is(hud, ScrapyardHud, "ScrapyardHud should use the ScrapyardHud script")

	var day_label: Label = hud.get_node_or_null("DayLabel")
	var clock_label: Label = hud.get_node_or_null("ClockLabel")
	assert_not_null(day_label, "DayLabel should exist")
	assert_not_null(clock_label, "ClockLabel should exist")
	assert_true(day_label.visible, "Day label should be visible")
	assert_true(clock_label.visible, "Clock label should be visible")


func test_player_is_in_player_group() -> void:
	var player := _yard.get_node_or_null("Player")
	assert_not_null(player, "Player should be instanced")
	assert_true(player.is_in_group("player"), "Player should be in the 'player' group for proximity detection")


func test_interact_action_registered() -> void:
	assert_true(InputMap.has_action("interact"), "The interact input action should be registered")
	var events := InputMap.action_get_events("interact")
	assert_gt(events.size(), 0, "The interact action should have at least one event bound")



