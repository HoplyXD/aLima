class_name ItemInspectionOverlay
extends Control
## Full-screen overlay for inspecting a scrapyard inventory item.
##
## Shows a large 3D rotating preview of the item and a description panel below.
## For scrap items, the description includes a recommendation to give it to Ayla.
## This is a view-only overlay: no cleaning, no opening, just spin and read.

signal closed

const SPIN_SPEED: float = 0.5
const FIT_SIZE: float = 1.0
const DRAG_RADIANS_PER_PIXEL: float = 0.012
const ZOOM_STEP: float = 0.12
const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 2.5

var _dragging: bool = false
var _zoom: float = 1.0
var _base_holder_scale: Vector3 = Vector3.ONE

@onready var _name_label: Label = %NameLabel
@onready var _close_button: Button = %CloseButton
@onready var _preview_container: SubViewportContainer = %PreviewContainer
@onready var _mesh_holder: Node3D = %MeshHolder
@onready var _description_label: RichTextLabel = %DescriptionLabel

var _object: Node3D
var _spin: bool = true


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	gui_input.connect(_on_gui_input)
	# Drag on the preview spins the piece by hand (auto-spin resumes on release);
	# the wheel zooms. View-only — same feel as the bench, no cleaning.
	_preview_container.gui_input.connect(_on_preview_input)
	set_process(false)


func _process(delta: float) -> void:
	if _spin and not _dragging and _object != null and is_instance_valid(_object):
		_object.rotate_y(SPIN_SPEED * delta)


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_set_zoom(_zoom + ZOOM_STEP)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_set_zoom(_zoom - ZOOM_STEP)
			accept_event()
	elif event is InputEventMouseMotion and _dragging and is_instance_valid(_object):
		var motion := event as InputEventMouseMotion
		_object.rotate_y(motion.relative.x * DRAG_RADIANS_PER_PIXEL)
		_object.rotate_x(motion.relative.y * DRAG_RADIANS_PER_PIXEL)
		accept_event()


func _set_zoom(value: float) -> void:
	_zoom = clampf(value, ZOOM_MIN, ZOOM_MAX)
	_mesh_holder.scale = _base_holder_scale * _zoom


func open(data: Dictionary) -> void:
	visible = true
	set_process(true)

	var display_name: String = str(data.get("display_name", "Item"))
	var color: Color = data.get("color", Color.WHITE)
	var description: String = str(data.get("description", ""))
	var is_scrap: bool = data.get("is_scrap", false)
	var preview: Node3D = data.get("preview") as Node3D

	_name_label.text = display_name
	_name_label.add_theme_color_override("font_color", color)

	# Build the description text
	var text := ""
	if not description.is_empty():
		text += description
	else:
		text += "No description available."
	if is_scrap:
		text += "\n\n[i]You should give this to Alya so she can sort it into restorable artifacts.[/i]"
	_description_label.text = text

	# Setup the 3D preview
	for child in _mesh_holder.get_children():
		child.queue_free()
	_object = null

	if preview != null and is_instance_valid(preview):
		var obj := preview.duplicate()
		_mesh_holder.add_child(obj)
		_object = obj
		_fit_object()
	else:
		# No preview: show a placeholder label inside the viewport area
		_spin = false

	# Ensure mouse is visible while inspecting
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close() -> void:
	visible = false
	set_process(false)
	_spin = true
	for child in _mesh_holder.get_children():
		child.queue_free()
	_object = null
	closed.emit()


func _on_close_pressed() -> void:
	close()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# Only close if clicking the background, not the panel
			if not _get_panel_global_rect().has_point(get_global_mouse_position()):
				close()
			accept_event()


func _get_panel_global_rect() -> Rect2:
	var panel := get_node("Panel") as Control
	if panel != null:
		return panel.get_global_rect()
	return Rect2()


func _fit_object() -> void:
	if not is_instance_valid(_object):
		return
	var box := _visible_aabb(_object)
	var max_extent := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if max_extent <= 0.0001:
		_base_holder_scale = Vector3.ONE * FIT_SIZE
	else:
		_base_holder_scale = Vector3.ONE * (FIT_SIZE / max_extent)
	_zoom = 1.0
	_mesh_holder.scale = _base_holder_scale


func _visible_aabb(root: Node3D) -> AABB:
	var acc := AABB()
	var has := false
	var inv := root.global_transform.affine_inverse()
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.visible and mi.mesh != null:
				var local: AABB = (inv * mi.global_transform) * mi.mesh.get_aabb()
				acc = local if not has else acc.merge(local)
				has = true
		for child in node.get_children():
			stack.append(child)
	return acc if has else AABB()
