extends GutTest

## Phase 0 smoke test for the production Shop entry point and the
## controller <-> presentation-HUD boundary. Runs headless under Godot 4.6.3.
##
## Covers: the HUD is visible, the stray test button is gone, the four action
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


func test_four_action_buttons_exist() -> void:
	for button_name in ["DoorButton", "WorkbenchButton", "JournalButton", "PhoneButton"]:
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
	_hud.workbench_pressed.emit()
	await wait_physics_frames(1)

	var dialogue: DialogueBox = _hud.get_node("DialogueBox")
	assert_true(dialogue.visible, "Workbench placeholder opens a dialogue")
	assert_false(_visitor.visible, "No visitor for the workbench placeholder")

	await _advance_until_closed(dialogue, _make_click_event)

	assert_false(dialogue.visible, "Left click advances and closes the dialogue")
	assert_true(_shop.is_day_running(), "Clock resumes after the placeholder dialogue")


# --- Helpers ------------------------------------------------------------


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
