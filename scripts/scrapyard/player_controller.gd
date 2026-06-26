extends CharacterBody3D
## Yard-only first-person walking controller.
##
## Movement is FPS-style: WASD / controller left stick moves the player forward,
## back, left, and right relative to where the player is looking. The mouse rotates
## the view directly (yaw on the player body, pitch on the head camera). All
## movement actions are registered at runtime on the InputMap so a future remap UI
## can override them.

class_name ScrapyardPlayer

signal scrap_prompt_changed(text: String)

@export var walk_speed: float = 3.5
@export var gravity: float = 9.8

@export_group("Mouse Look")
@export var mouse_sensitivity: Vector2 = Vector2(0.003, 0.003)
@export var min_pitch_degrees: float = -89.0
@export var max_pitch_degrees: float = 89.0
@export var look_smooth: float = 0.0

@onready var _camera: Camera3D = $Camera3D

const SCRAP_INTERACT_RANGE := 4.0
const SCRAP_PROMPT := "Press E to grab scrap"

var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
var _min_pitch: float = 0.0
var _max_pitch: float = 0.0
var _input_enabled: bool = true
var _scrap_target: ScrapItem = null


func _ready() -> void:
	_ensure_input_actions()
	add_to_group("player")
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_min_pitch = deg_to_rad(min_pitch_degrees)
	_max_pitch = deg_to_rad(max_pitch_degrees)

	_target_yaw = rotation.y
	if _camera != null:
		_target_pitch = clampf(_camera.rotation.x, _min_pitch, _max_pitch)


func _exit_tree() -> void:
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled


func _input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_target_yaw -= motion.relative.x * mouse_sensitivity.x
		_target_pitch -= motion.relative.y * mouse_sensitivity.y
		_target_pitch = clampf(_target_pitch, _min_pitch, _max_pitch)
	elif event.is_action_pressed("interact"):
		_activate_scrap_target()


func _physics_process(delta: float) -> void:
	if not _input_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y -= gravity * delta
		move_and_slide()
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	input_dir = input_dir.limit_length(1.0)

	# Apply yaw directly for responsive FPS turning.
	rotation.y = _target_yaw
	if _camera != null:
		if look_smooth > 0.0:
			_camera.rotation.x = lerpf(_camera.rotation.x, _target_pitch, look_smooth * delta)
		else:
			_camera.rotation.x = _target_pitch

	# View-relative movement on the horizontal plane.
	var forward := -transform.basis.z
	var right := transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	# Input get_vector returns y = -1 for forward (W) and +1 for back (S),
	# so negate it so W walks forward and S walks back.
	velocity.x = (forward.x * -input_dir.y + right.x * input_dir.x) * walk_speed
	velocity.z = (forward.z * -input_dir.y + right.z * input_dir.x) * walk_speed
	velocity.y -= gravity * delta

	move_and_slide()
	_update_scrap_target()


func _ensure_input_actions() -> void:
	# Keyboard: WASD + arrow keys. Gamepad: left stick (motion) + dpad (digital).
	_add_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_action("move_forward", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_action("move_back", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	# Interaction: keyboard E, gamepad A/cross.
	_add_action("interact", [KEY_E], [JOY_BUTTON_A], JOY_AXIS_INVALID, 0.0)


## Raycasts from the center of the screen and highlights/prompts any ScrapItem
## the player is looking at, even if it is sitting on or partly inside trash.
func _update_scrap_target() -> void:
	if not _input_enabled or _camera == null:
		_set_scrap_target(null)
		return
	var space := get_world_3d().direct_space_state
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * SCRAP_INTERACT_RANGE
	var query := PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collision_mask = 1
	var result := space.intersect_ray(query)
	var item: ScrapItem = null
	if not result.is_empty():
		item = result.collider as ScrapItem
		if item != null and not item.interactable_enabled:
			item = null
	_set_scrap_target(item)


func _set_scrap_target(item: ScrapItem) -> void:
	if item == _scrap_target:
		return
	var had_target := _scrap_target != null
	_scrap_target = item
	if _scrap_target != null:
		scrap_prompt_changed.emit(SCRAP_PROMPT)
	elif had_target:
		scrap_prompt_changed.emit("")


func _activate_scrap_target() -> void:
	if _scrap_target != null and is_instance_valid(_scrap_target):
		_scrap_target.activate()
		get_viewport().set_input_as_handled()


func _add_action(
	action: String,
	keys: Array,
	pads: Array,
	joy_axis: JoyAxis = JOY_AXIS_INVALID,
	joy_axis_sign: float = 0.0
) -> void:
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
	if joy_axis != JOY_AXIS_INVALID:
		var ev := InputEventJoypadMotion.new()
		ev.axis = joy_axis
		ev.axis_value = joy_axis_sign
		InputMap.action_add_event(action, ev)
