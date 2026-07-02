class_name ArtifactViewer
extends CanvasLayer
## Fullscreen 3D inspection overlay for a RESTORED artifact (shop HUD card
## click). The player drags to spin the piece and wheel-zooms; clicking the
## dimmed area outside the model exits. Viewing only — restoration stays at
## the bench. Built entirely in code (simple, theme-free presentation).

signal closed

const VIEWER_LAYER: int = 90
const ARTIFACT_OBJECT_SCENE := preload("res://scenes/restoration/restoration_artifact.tscn")
const ArtifactScenes := preload("res://scripts/restoration/artifact_scenes.gd")

const CAMERA_REST_Z: float = 2.4
const ZOOM_MIN_Z: float = 0.9
const ZOOM_MAX_Z: float = 5.0
const ZOOM_STEP: float = 0.25
const DRAG_RADIANS_PER_PIXEL: float = 0.012

var _dim: ColorRect
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _camera: Camera3D
var _holder: Node3D
var _object: Node3D
var _dragging: bool = false
var _service: RestorationService


func _ready() -> void:
	layer = VIEWER_LAYER
	visible = false
	_service = RestorationService.new()

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_viewport_container = SubViewportContainer.new()
	_viewport_container.custom_minimum_size = Vector2(640, 640)
	_viewport_container.stretch = true
	_viewport_container.gui_input.connect(_on_view_input)
	center.add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(_viewport)

	var world := Node3D.new()
	_viewport.add_child(world)
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 0.2, CAMERA_REST_Z)
	world.add_child(_camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -140, 0)
	fill.light_energy = 0.5
	world.add_child(fill)
	_holder = Node3D.new()
	world.add_child(_holder)


## Opens the viewer on an owned instance. Pauses shop time while inspecting.
func open(uid: String) -> void:
	var inst := _service.find_instance_by_id(uid)
	if inst == null:
		return
	var template := _service.get_repository().get_template(inst.template_id)
	if template == null:
		return
	for child in _holder.get_children():
		child.queue_free()
	var scene: PackedScene = ArtifactScenes.scene_for(template.id, ARTIFACT_OBJECT_SCENE)
	_object = scene.instantiate()
	_holder.add_child(_object)
	_service.present_object(_object, inst, template, uid.hash())
	_camera.position.z = CAMERA_REST_Z
	visible = true
	DayClock.request_pause(DayClock.PAUSE_SHOWCASE)


func close() -> void:
	if not visible:
		return
	visible = false
	DayClock.release_pause(DayClock.PAUSE_SHOWCASE)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		close()


func _on_dim_input(event: InputEvent) -> void:
	# Clicking outside the artifact view exits inspection.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			close()


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_camera.position.z = maxf(ZOOM_MIN_Z, _camera.position.z - ZOOM_STEP)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_camera.position.z = minf(ZOOM_MAX_Z, _camera.position.z + ZOOM_STEP)
	elif event is InputEventMouseMotion and _dragging and _object != null:
		var motion := event as InputEventMouseMotion
		_object.rotate_y(motion.relative.x * DRAG_RADIANS_PER_PIXEL)
		_object.rotate_x(motion.relative.y * DRAG_RADIANS_PER_PIXEL)
