class_name EchoFocusController
extends Node
## Minimal focus navigation for Cultural Echo proximity.
##
## The production Shop has no player-character movement. This controller lets the
## player snap their inspection focus to one of the authored placement anchors
## using keyboard or controller input, which updates the Echo listener position
## and makes the proximity bands reachable. It is intentionally small and does not
## implement broad character movement.
##
## Input actions (registered at runtime):
##   echo_focus_left   -> focus pile_left
##   echo_focus_center -> focus pile_center
##   echo_focus_right  -> focus shelf_right
##   echo_focus_clear  -> return focus to camera / no anchor

const FOCUS_DISTANCE := 1.5
const FOCUS_HEIGHT := 1.6

var _bridge: EchoSceneBridge = null
var _anchors: Dictionary = {}


func _ready() -> void:
	_ensure_input_actions()
	_bridge = _find_bridge()
	_discover_anchors()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("echo_focus_left"):
		_focus_anchor("pile_left")
	elif event.is_action_pressed("echo_focus_center"):
		_focus_anchor("pile_center")
	elif event.is_action_pressed("echo_focus_right"):
		_focus_anchor("shelf_right")
	elif event.is_action_pressed("echo_focus_clear"):
		_clear_focus()


func focus_anchor(anchor_id: String) -> void:
	_focus_anchor(anchor_id)


func clear_focus() -> void:
	_clear_focus()


func _focus_anchor(anchor_id: String) -> void:
	if _bridge == null:
		return
	var marker := _anchors.get(anchor_id) as Marker3D
	if marker == null:
		return
	var pos := marker.global_position
	# Offset slightly in front and at eye level to model leaning in to inspect.
	var focus_pos := Vector3(pos.x, pos.y + FOCUS_HEIGHT, pos.z + FOCUS_DISTANCE)
	_bridge.set_focus_position(focus_pos)


func _clear_focus() -> void:
	if _bridge == null:
		return
	_bridge.clear_focus()


func _find_bridge() -> EchoSceneBridge:
	var parent := get_parent()
	if parent != null:
		var bridge := parent.get_node_or_null("EchoSceneBridge")
		if bridge is EchoSceneBridge:
			return bridge
	return null


func _discover_anchors() -> void:
	_anchors.clear()
	if _bridge == null:
		return
	var parent := _bridge.get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child is Marker3D:
			_anchors[child.name] = child


func _ensure_input_actions() -> void:
	_add_action("echo_focus_left", [KEY_1], [JOY_BUTTON_DPAD_LEFT])
	_add_action("echo_focus_center", [KEY_2], [JOY_BUTTON_DPAD_UP])
	_add_action("echo_focus_right", [KEY_3], [JOY_BUTTON_DPAD_RIGHT])
	_add_action("echo_focus_clear", [KEY_0], [JOY_BUTTON_B])


func _add_action(action: String, keys: Array, pads: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for keycode in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)
	for button in pads:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		InputMap.action_add_event(action, ev)
