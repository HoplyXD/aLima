extends Control
## Main-menu title screen.
##
## First scene the game boots into. Pure presentation wiring: "Play" enters the
## shop (the actual game), "Options" opens the global PauseMenu settings overlay,
## and "Quit" exits. The layout lives in title_screen.tscn; this script only
## connects buttons and changes scenes.

# Shop.tscn is the playable gameplay scene; Antique Shop.tscn is the menu backdrop
# (instanced behind this title screen). Both share the same room + controller, which
# detects the backdrop role and stays inert there. Play loads the live shop.
const SHOP_SCENE: String = "res://scenes/Shop.tscn"

# The 3D camera that frames the backdrop room. The idle sway and mouse parallax are
# layered on top of its authored transform so the menu feels alive without drifting
# the framing away from where the artist set it.
const BACKDROP_CAM_PATH: NodePath = ^"Backdrop/SubViewport/AntiqueShop/Title Screen cam"

@export_group("Idle Sway")
## How far the camera drifts (metres, along its own right/up axes) while idle.
@export var idle_move_amount: float = 0.035
## How far the camera tilts (radians) while idle.
@export var idle_tilt_amount: float = 0.012
## Speed of the idle "breathing" drift.
@export var idle_speed: float = 0.35

@export_group("Mouse Parallax")
## How far the camera shifts (metres) toward the cursor.
@export var parallax_move_amount: float = 0.06
## How far the camera turns (radians) toward the cursor.
@export var parallax_tilt_amount: float = 0.018
## Easing toward the cursor — higher follows faster, lower feels heavier.
@export var parallax_smooth: float = 4.0

@onready var _play_button: Button = $VBoxContainer/Play
@onready var _options_button: Button = $VBoxContainer/Options
@onready var _quit_button: Button = $VBoxContainer/Quit
@onready var _backdrop_cam: Camera3D = get_node_or_null(BACKDROP_CAM_PATH) as Camera3D

# Authored camera transform; all motion is an offset from this so framing is preserved.
var _cam_base_position: Vector3
var _cam_base_basis: Basis
var _time: float = 0.0
var _parallax: Vector2 = Vector2.ZERO


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_play_button.grab_focus()

	if _backdrop_cam != null:
		_cam_base_position = _backdrop_cam.transform.origin
		_cam_base_basis = _backdrop_cam.transform.basis
	else:
		# No backdrop camera (e.g. headless tests) — nothing to animate.
		set_process(false)


func _process(delta: float) -> void:
	_time += delta

	# Ease the parallax toward the cursor's position in the window; screen centre
	# reads as zero so the framing rests where the artist placed it.
	var target := Vector2.ZERO
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		var mouse: Vector2 = get_viewport().get_mouse_position()
		target = ((mouse / viewport_size) * 2.0 - Vector2.ONE).clamp(-Vector2.ONE, Vector2.ONE)
	_parallax = _parallax.lerp(target, clampf(parallax_smooth * delta, 0.0, 1.0))

	# Idle breathing: two out-of-phase sines so the drift never traces a circle.
	var sway := Vector2(sin(_time * idle_speed), sin(_time * idle_speed * 1.3 + 1.7))

	# Combine idle + parallax into local right/up offsets and a matching tilt.
	var right: Vector3 = _cam_base_basis.x
	var up: Vector3 = _cam_base_basis.y
	var offset_x: float = sway.x * idle_move_amount + _parallax.x * parallax_move_amount
	var offset_y: float = sway.y * idle_move_amount - _parallax.y * parallax_move_amount
	var yaw: float = sway.x * idle_tilt_amount - _parallax.x * parallax_tilt_amount
	var pitch: float = sway.y * idle_tilt_amount + _parallax.y * parallax_tilt_amount

	var new_basis: Basis = _cam_base_basis * Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var new_origin: Vector3 = _cam_base_position + right * offset_x + up * offset_y
	_backdrop_cam.transform = Transform3D(new_basis, new_origin)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(SHOP_SCENE)


func _on_options_pressed() -> void:
	PauseMenu.open()


func _on_quit_pressed() -> void:
	get_tree().quit()
