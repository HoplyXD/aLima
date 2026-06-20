class_name BookViewport
extends CanvasLayer

## A self-contained journal viewer. It renders Book.tscn inside its own SubViewport
## so it can sit on top of any scene — the shop or the restoration bench — exactly
## the way the restoration view embeds its 3D object in a 2D layer. Both hosts open
## this same component (each with its own instance) instead of duplicating book code.
##
## Reading controls (camera dolly): the mouse wheel zooms the book camera toward the
## cursor so text is crisp; left-drag pans while zoomed; page turns happen only at
## the default zoom (so a zoomed reader can drag freely without flipping pages).
## Closing — Esc, the Close button, or clicking off the book at default zoom — always
## restores the camera to its default framing.

signal closed

const ZOOM_MIN: float = 1.0
const ZOOM_MAX: float = 4.0
const ZOOM_STEP: float = 1.2
const PAGE_HALF_WIDTH: float = 1.3  ## book-local x within which a click counts as on a page
const PAGE_HALF_HEIGHT: float = 1.0

var _zoom: float = 1.0
var _panning: bool = false
var _base_cam_xform: Transform3D
var _plane_z: float = 0.0  ## the page plane sits at the book's local z = 0
var _owns_pause: bool = false

@onready var _subviewport: SubViewport = $ViewportContainer/SubViewport
@onready var _book: JournalBook = $ViewportContainer/SubViewport/Book
@onready var _camera: Camera3D = $ViewportContainer/SubViewport/Camera3D
@onready var _input_catcher: Control = $InputCatcher
@onready var _close_button: Button = $CloseButton


func _ready() -> void:
	visible = false
	_base_cam_xform = _camera.transform
	# We ray-pick the book ourselves, so the SubViewport doesn't need physics picking.
	_subviewport.physics_object_picking = false
	_input_catcher.gui_input.connect(_on_catcher_input)
	_close_button.pressed.connect(close)
	set_process_input(false)


## Shows the journal at default framing and pauses the shop clock.
func open() -> void:
	_reset_camera()
	if not _owns_pause:
		DayClock.request_pause(DayClock.PAUSE_JOURNAL)
		_owns_pause = true
	_book.refresh_content()
	visible = true
	set_process_input(true)


## Hides the journal and restores the camera. Safe to call when already closed.
func close() -> void:
	if not visible:
		return
	_reset_camera()
	visible = false
	set_process_input(false)
	_release_pause_if_owned()
	closed.emit()


func is_open() -> bool:
	return visible


func _exit_tree() -> void:
	_release_pause_if_owned()


func _release_pause_if_owned() -> void:
	if _owns_pause and DayClock.has_pause_owner(DayClock.PAUSE_JOURNAL):
		DayClock.release_pause(DayClock.PAUSE_JOURNAL)
	_owns_pause = false


func _reset_camera() -> void:
	_zoom = 1.0
	_panning = false
	_camera.transform = _base_cam_xform


# Uses _input (not _unhandled_input) so Backspace closes the journal before the host
# scene (e.g. the restoration bench) can act on it. Esc is reserved for the pause menu.
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("back"):
		close()
		get_viewport().set_input_as_handled()


## Test seam: true when this viewer currently owns the journal pause.
func owns_pause() -> bool:
	return _owns_pause


# --- Pointer: zoom / pan / page-turn -----------------------------------------


func _on_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, ZOOM_STEP)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / ZOOM_STEP)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _zoom > ZOOM_MIN:
					_panning = true  # zoomed in -> drag pans, page turning disabled
				else:
					_handle_page_click(mb.position)
			else:
				_panning = false
		_input_catcher.accept_event()
	elif event is InputEventMouseMotion:
		if _panning:
			_pan((event as InputEventMouseMotion).relative)
		_input_catcher.accept_event()


# Camera looks straight down -Z at the page plane (no tilt), so projection onto the
# plane is a simple scale of the field of view by the camera's distance.
func _tan_half_fov() -> float:
	return tan(deg_to_rad(_camera.fov) * 0.5)


func _aspect() -> float:
	var sv := Vector2(_subviewport.size)
	return sv.x / sv.y if sv.y != 0.0 else 1.0


func _ndc(screen_pos: Vector2) -> Vector2:
	var s := _input_catcher.size
	return Vector2((screen_pos.x / s.x) * 2.0 - 1.0, -((screen_pos.y / s.y) * 2.0 - 1.0))


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var new_zoom: float = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(new_zoom, _zoom):
		return
	var ndc := _ndc(screen_pos)
	var th := _tan_half_fov()
	var a := _aspect()
	var pos := _camera.position
	# World point on the page plane currently under the cursor.
	var h_cur := (pos.z - _plane_z) * th
	var w_x := pos.x + ndc.x * h_cur * a
	var w_y := pos.y + ndc.y * h_cur
	# Dolly the camera in/out, then move it so that same point stays under the cursor.
	_zoom = new_zoom
	var cz := _plane_z + (_base_cam_xform.origin.z - _plane_z) / _zoom
	var h_new := (cz - _plane_z) * th
	_camera.position = Vector3(w_x - ndc.x * h_new * a, w_y - ndc.y * h_new, cz)


func _pan(relative: Vector2) -> void:
	var s := _input_catcher.size
	var th := _tan_half_fov()
	var a := _aspect()
	var h := (_camera.position.z - _plane_z) * th
	var dx := -(relative.x / s.x) * 2.0 * h * a
	var dy := (relative.y / s.y) * 2.0 * h
	_camera.position += Vector3(dx, dy, 0.0)


func _handle_page_click(screen_pos: Vector2) -> void:
	var s := _input_catcher.size
	var vp_pos := screen_pos * (Vector2(_subviewport.size) / s)
	var o := _camera.project_ray_origin(vp_pos)
	var d := _camera.project_ray_normal(vp_pos)
	if is_zero_approx(d.z):
		return
	var t := (_plane_z - o.z) / d.z
	if t < 0.0:
		return
	var local := _book.to_local(o + d * t)
	if absf(local.x) <= PAGE_HALF_WIDTH and absf(local.y) <= PAGE_HALF_HEIGHT:
		_book.click_at_local_x(local.x)
	else:
		# Clicking off the book at default zoom closes the journal.
		close()
