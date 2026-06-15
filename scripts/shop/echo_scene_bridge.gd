class_name EchoSceneBridge
extends Node3D
## Scene-integration boundary for Cultural Echo proximity.
##
## Reads the active carrier anchor position and the camera/listener position each
## frame and feeds them to the EchoController autoload through an explicit
## Vector3 boundary. This keeps EchoController free of hard scene-node references.
##
## If the Shop scene is not meaningfully navigable, this bridge still reports the
## authored anchor positions so the proximity math and resonance meter can be
## tested. The active carrier is resolved from GameState loop state.
##
## A focus position can be set (e.g. by EchoFocusController) to model the player
## leaning in to inspect a specific anchor. When set, it overrides the camera as
## the listener position.

const INVALID := Vector3.INF

@export var camera_path: NodePath = "../Camera3D"

var _camera: Camera3D = null
var _focus_position: Vector3 = INVALID


func _ready() -> void:
	_camera = get_node_or_null(camera_path)


## Overrides the listener position with a focus point (e.g. near an anchor).
func set_focus_position(pos: Vector3) -> void:
	_focus_position = pos


## Clears the focus override; the camera becomes the listener again.
func clear_focus() -> void:
	_focus_position = INVALID


func _process(_delta: float) -> void:
	var state := EchoController.get_state()
	if not state.get("valid", false):
		EchoController.set_listener_position(_listener_position())
		EchoController.set_carrier_position(INVALID)
		return

	var instance_id: String = state.get("instance_id", "")
	var anchor_pos := _anchor_position_for(instance_id)
	EchoController.set_listener_position(_listener_position())
	EchoController.set_carrier_position(anchor_pos)


func _listener_position() -> Vector3:
	if _focus_position != INVALID:
		return _focus_position
	if _camera == null:
		return INVALID
	return _camera.global_position


func _anchor_position_for(instance_id: String) -> Vector3:
	var inst := _find_instance(instance_id)
	if inst == null:
		return INVALID
	var anchor_id: String = inst.assigned_anchor_id
	if anchor_id.is_empty():
		return INVALID
	var marker := get_node_or_null("../" + anchor_id)
	if marker is Marker3D:
		return marker.global_position
	return INVALID


func _find_instance(instance_id: String) -> ObjectInstance:
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == instance_id:
			return ObjectInstance.from_dictionary(raw)
	for id in GameState.save_state.loop.current_delivery_ids:
		if id == instance_id:
			# Delivery instances are not yet in inventory; look them up from the
			# planned placement instead.
			var placements := GameState.save_state.loop.current_carrier_placements
			for fragment_id in placements.keys():
				var plan: Dictionary = placements[fragment_id]
				if plan.get("carrier_instance_id", "") == instance_id:
					return _instance_from_plan(plan)
	return null


func _instance_from_plan(plan: Dictionary) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.template_id = plan.get("carrier_template_id", "")
	inst.uid = plan.get("carrier_instance_id", "")
	inst.is_carrier = true
	inst.fragment_id = plan.get("fragment_id", "")
	inst.contents = ModelEnums.OpenResult.FRAGMENT
	inst.assigned_anchor_id = plan.get("container_id", "")
	inst.state = ModelEnums.ObjState.DIRTY
	return inst
