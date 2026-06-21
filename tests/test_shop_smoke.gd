extends GutTest

## Phase 0 smoke test for the production Shop entry point and the
## controller <-> presentation-HUD boundary. Runs headless under Godot 4.6.3.
##
## Covers: the HUD is visible, the stray test button is gone, the five action
## buttons exist, the HUD formats clock/day text, and the dialogue lifecycle
## pauses/resumes the placeholder clock and toggles the visitor via both keyboard
## (ui_accept) and left-click advancement. Input is driven through the
## DialogueBox's real `_input` handler, the same entry point Godot calls on a key
## press or click.

const SHOP_SCENE := preload("res://scenes/Shop.tscn")

var _shop: Node3D
var _hud: ShopHud
var _visitor: Sprite3D


func before_each() -> void:
	_shop = SHOP_SCENE.instantiate()
	add_child_autofree(_shop)
	await wait_physics_frames(1)
	_hud = _shop.get_node("HUD")
	_visitor = _shop.get_node("Visitor")


func test_hud_is_visible() -> void:
	assert_true(_hud.visible, "HUD should be visible in the production scene")


func test_no_stray_test_button() -> void:
	var buttons := _collect_buttons(_hud, [])
	assert_gt(buttons.size(), 0, "Expected the action buttons to exist")
	for button in buttons:
		assert_false(String(button.text).contains("AAAAAAAAA"), "Stray test button must be removed")


func test_five_action_buttons_exist() -> void:
	for button_name in [
		"DoorButton", "WorkbenchButton", "JournalButton", "PhoneButton", "MorningDeliveryButton"
	]:
		var button := _hud.get_node_or_null(button_name)
		assert_not_null(button, "%s should exist" % button_name)
		assert_is(button, Button, "%s should be a Button" % button_name)


func test_hud_time_formatting() -> void:
	var clock: Label = _shop.get_node("%ClockLabel")
	_hud.set_time(7)
	assert_eq(clock.text, "7:00 AM")
	_hud.set_time(20)
	assert_eq(clock.text, "8:00 PM")


func test_hud_day_formatting() -> void:
	var day_label: Label = _shop.get_node("%DayLabel")
	_hud.set_day(1, 5)
	assert_eq(day_label.text, "Day 1 of 5")


func test_door_dialogue_pauses_and_resumes_clock_via_keyboard() -> void:
	assert_true(_shop.is_day_running(), "Clock runs when the shop opens")

	_advance_clock_to(1, 12)  # Auntie's visit window (Day 1, 12:00-14:00).
	watch_signals(_hud)
	_hud.door_pressed.emit()  # Identical to clicking the Door button.
	await wait_physics_frames(1)

	var dialogue: DialogueBox = _hud.get_node("DialogueBox")
	assert_false(_shop.is_day_running(), "Clock pauses while a visitor talks")
	assert_true(_visitor.visible, "Visitor appears for the door dialogue")
	assert_true(dialogue.visible, "Dialogue box is shown")

	await _advance_until_closed(dialogue, _make_accept_event)

	assert_false(dialogue.visible, "Dialogue closes after advancing")
	assert_signal_emitted(_hud, "dialogue_finished", "HUD re-emits dialogue_finished")
	assert_true(_shop.is_day_running(), "Clock resumes after dialogue")
	assert_false(_visitor.visible, "Visitor hides after dialogue")


func test_dialogue_advances_via_left_click() -> void:
	_hud.door_pressed.emit()
	await wait_physics_frames(1)

	var dialogue: DialogueBox = _hud.get_node("DialogueBox")
	assert_true(dialogue.visible, "Door opens a dialogue")

	await _advance_until_closed(dialogue, _make_click_event)

	assert_false(dialogue.visible, "Left click advances and closes the dialogue")
	assert_true(_shop.is_day_running(), "Clock resumes after the dialogue")


func test_phone_opens_and_pauses() -> void:
	_hud.phone_pressed.emit()
	await wait_physics_frames(1)

	var phone: Phone = _shop.get_node("Phone")
	assert_true(phone.visible, "Phone button opens the phone")
	assert_eq(phone.get_current_app(), "", "phone opens on its home screen")
	assert_false(_shop.is_day_running(), "Shop time pauses while the phone is open")
	assert_false(_visitor.visible, "No visitor for the phone")

	phone.open_app("marketplace")
	assert_eq(phone.get_current_app(), "marketplace", "Marketplace app opens from the home grid")

	phone.close()
	await wait_physics_frames(1)
	assert_true(_shop.is_day_running(), "Clock resumes after the phone closes")


func test_storage_button_opens_storage_and_pauses() -> void:
	_hud.storage_pressed.emit()
	await wait_physics_frames(1)

	var storage: StorageScreen = _shop.get_node("StorageScreen")
	assert_true(storage.visible, "Storage button opens the Storage screen")
	assert_false(_shop.is_day_running(), "Shop time pauses while Storage is open")

	storage.close()
	await wait_physics_frames(1)
	assert_true(_shop.is_day_running(), "Clock resumes after Storage closes")


# --- Diegetic 3D interactables ------------------------------------------


func test_five_diegetic_interactables_exist() -> void:
	for node_name in [
		"DoorInteractable",
		"WorkbenchInteractable",
		"JournalInteractable",
		"PhoneInteractable",
		"DeliveryInteractable"
	]:
		var prop := _shop.get_node_or_null("Interactables/%s" % node_name)
		assert_not_null(prop, "%s prop should exist in the shop" % node_name)
		assert_is(prop, Interactable3D, "%s should be an Interactable3D" % node_name)


func test_workbench_prop_opens_restoration() -> void:
	var prop: Interactable3D = _shop.get_node("Interactables/WorkbenchInteractable")
	prop.activate()
	await wait_physics_frames(1)
	var view: RestorationView = _shop.get_node("RestorationView")
	assert_true(view.visible, "Clicking the workbench prop opens the restoration view")


func test_delivery_box_prop_opens_storage() -> void:
	# The morning-delivery box is now Storage; the player picks an artifact there and
	# presses Restore to move into the restoration scene.
	var prop: Interactable3D = _shop.get_node("Interactables/DeliveryInteractable")
	prop.activate()
	await wait_physics_frames(1)
	var storage: StorageScreen = _shop.get_node("StorageScreen")
	assert_true(storage.visible, "Clicking the delivery box prop opens storage")


func test_door_prop_opens_dialogue_like_its_button() -> void:
	_advance_clock_to(1, 12)  # Auntie's visit window so a visitor is scheduled.
	var prop: Interactable3D = _shop.get_node("Interactables/DoorInteractable")
	prop.activate()
	await wait_physics_frames(1)
	var dialogue: DialogueBox = _hud.get_node("DialogueBox")
	assert_true(dialogue.visible, "Clicking the door prop opens the visitor dialogue")
	assert_true(_visitor.visible, "The visitor appears for the door prop")


func test_hovering_a_prop_shows_its_prompt() -> void:
	var prop: Interactable3D = _shop.get_node("Interactables/WorkbenchInteractable")
	var prompt: Label = _hud.get_node("PromptLabel")
	prop.mouse_entered.emit()
	assert_eq(prompt.text, prop.prompt_text, "Hovering a prop surfaces its prompt on the HUD")
	prop.mouse_exited.emit()
	assert_eq(prompt.text, "", "Leaving the prop clears the prompt")


func test_overlays_disable_shop_props() -> void:
	var workbench: Interactable3D = _shop.get_node("Interactables/WorkbenchInteractable")
	_hud.door_pressed.emit()  # Opens the visitor dialogue overlay.
	await wait_physics_frames(1)
	assert_false(workbench.interactable_enabled, "Shop props are disabled while an overlay is open")

	var dialogue: DialogueBox = _hud.get_node("DialogueBox")
	await _advance_until_closed(dialogue, _make_accept_event)
	assert_true(workbench.interactable_enabled, "Shop props re-enable after the overlay closes")


# --- Helpers ------------------------------------------------------------


## Drives the shared DayClock to a specific day/hour via its public tick API so a
## scheduled visitor (per data/routes) answers the door deterministically.
func _advance_clock_to(day: int, hour: int) -> void:
	DayClock.seconds_per_hour = 1.0
	DayClock.start_day(day)
	for _i in range(hour - DayClock.DAY_START_HOUR):
		DayClock.tick(1.0)


func _advance_until_closed(dialogue: DialogueBox, event_factory: Callable) -> void:
	var guard := 0
	while dialogue.visible and guard < 20:
		dialogue._input(event_factory.call())
		await wait_physics_frames(1)
		guard += 1


func _make_accept_event() -> InputEvent:
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	return event


func _make_click_event() -> InputEvent:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _collect_buttons(node: Node, acc: Array) -> Array:
	for child in node.get_children():
		if child is Button:
			acc.append(child)
		_collect_buttons(child, acc)
	return acc
