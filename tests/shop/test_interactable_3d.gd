extends GutTest

## Unit tests for the reusable diegetic Interactable3D component (shop conversion).
## Driven through the public API and the Area3D signals the engine would fire,
## rather than real physics picking — the same presentation-boundary approach the
## restoration view tests use. No game state is involved; the component owns none.

var _node: Interactable3D
var _mesh: MeshInstance3D
var _material: StandardMaterial3D


func before_each() -> void:
	_node = Interactable3D.new()
	_node.prompt_text = "Do the thing"
	_mesh = MeshInstance3D.new()
	_mesh.mesh = BoxMesh.new()
	_material = StandardMaterial3D.new()
	_mesh.material_override = _material
	_node.add_child(_mesh)
	add_child_autofree(_node)
	await wait_physics_frames(1)


func _left_click() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


# --- Activation --------------------------------------------------------------


func test_activate_emits_activated() -> void:
	watch_signals(_node)
	_node.activate()
	assert_signal_emitted(_node, "activated", "activate() fires the activated signal")


func test_left_click_input_event_activates() -> void:
	watch_signals(_node)
	_node.input_event.emit(null, _left_click(), Vector3.ZERO, Vector3.ZERO, 0)
	assert_signal_emitted(_node, "activated", "A left click on the prop activates it")


func test_disabled_blocks_activation() -> void:
	_node.set_enabled(false)
	watch_signals(_node)
	_node.activate()
	_node.input_event.emit(null, _left_click(), Vector3.ZERO, Vector3.ZERO, 0)
	assert_signal_not_emitted(_node, "activated", "A disabled prop cannot be activated")


# --- Hover -------------------------------------------------------------------


func test_hover_toggles_state_signal_and_highlight() -> void:
	watch_signals(_node)
	_node.mouse_entered.emit()
	assert_true(_node.is_hovering(), "Pointer entering marks the prop hovered")
	assert_signal_emitted_with_parameters(_node, "hover_changed", [true])
	assert_true(_material.emission_enabled, "Hover highlights the prop")

	_node.mouse_exited.emit()
	assert_false(_node.is_hovering(), "Pointer leaving clears hover")
	assert_false(_material.emission_enabled, "Leaving removes the highlight")


func test_disabled_prop_does_not_hover() -> void:
	_node.set_enabled(false)
	watch_signals(_node)
	_node.mouse_entered.emit()
	assert_false(_node.is_hovering(), "A disabled prop does not respond to hover")
	assert_false(_material.emission_enabled)


func test_disabling_while_hovered_clears_hover() -> void:
	_node.mouse_entered.emit()
	assert_true(_node.is_hovering())
	_node.set_enabled(false)
	assert_false(_node.is_hovering(), "Disabling mid-hover clears the hover state")
	assert_false(_material.emission_enabled)
