extends GutTest

## Verifies that the shop door wires into SpaceManager when no visitor is pending,
## without triggering a real scene load.

const SHOP_SCENE := preload("res://scenes/Shop.tscn")

var _shop: Node3D
var _loaded_paths: Array[String]


func before_each() -> void:
	GameState.initialize("door-wiring-test")
	GameState.save_state.loop.last_delivery_day = GameState.save_state.loop.current_day
	SpaceManager.current_space = SpaceManager.Space.SHOP
	SpaceManager._on_title = false
	SpaceManager.set_loader(_record_load)
	_loaded_paths.clear()

	DayClock.reset()
	DayClock.seconds_per_hour = 1.0


func after_each() -> void:
	SpaceManager.set_loader(Callable())
	SpaceManager.current_space = SpaceManager.Space.SHOP
	SpaceManager._on_title = true
	DayClock.reset()


func test_door_prop_steps_outside_when_no_visitor() -> void:
	_shop = SHOP_SCENE.instantiate()
	add_child_autofree(_shop)
	await wait_physics_frames(1)

	var door: Interactable3D = _shop.get_node("Interactables/DoorInteractable")
	door.activate()
	await wait_physics_frames(1)

	assert_eq(SpaceManager.current_space, SpaceManager.Space.YARD, "door opens the yard")
	assert_eq(_loaded_paths.size(), 1, "exactly one scene load was requested")
	assert_eq(_loaded_paths[0], SpaceManager.YARD_SCENE, "requested scene is the yard")


func _record_load(path: String) -> void:
	_loaded_paths.append(path)
