class_name Preview3DCard
extends PanelContainer
## A reusable square card with a rotating 3D object preview and a name underneath.
## Used in Storage to show tools and artifacts as 3D objects the player can read at a
## glance. Presentation only: the caller builds the Node3D to show (tool geometry or a
## configured artifact) and connects `clicked`.

signal clicked

const SPIN_SPEED: float = 0.7  ## Radians/sec auto-spin so all sides/decals show.
## The on-screen size a previewed model is auto-scaled to: its largest visible dimension is
## mapped to this many world units so a tiny 0.1-scaled mask and a big bottle both read at a
## consistent, clearly-visible size in the card. The `fill` arg tunes it.
const FIT_SIZE: float = 1.15

@onready var _holder: Node3D = %MeshHolder
@onready var _name_label: Label = %NameLabel
@onready var _camera: Camera3D = $VBox/PreviewContainer/Preview/Camera3D


## Card-local 2D position where a point in the preview's 3D world projects to (used to line a tool's
## authored CleanPoint up with the mouse). Falls back to the card centre.
func project_to_card(world_pos: Vector3) -> Vector2:
	if _camera == null or not is_instance_valid(_camera):
		return size * 0.5
	return _camera.unproject_position(world_pos)

var _object: Node3D
var _fill: float = 1.0
## When false the preview holds a fixed orientation instead of auto-spinning (used by the
## tool sidebar and the cursor-following held tool, which should not tumble).
var _spin: bool = true


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	set_process(false)


## Enables/disables the idle auto-spin. Disable for a still, readable model.
func set_spin(on: bool) -> void:
	_spin = on


## Orients the model to a fixed in-view angle (radians, about the camera axis) so it can be
## made to "face" a target. Only meaningful while spin is off.
func set_facing_angle(angle: float) -> void:
	if is_instance_valid(_object):
		_object.rotation = Vector3(0.0, 0.0, angle)


## Embeds `obj` for the rotating preview and sets the name label. The model is auto-scaled
## to a consistent size from its visible bounding box (so small models are zoomed up to be
## readable); `fill` is a 0..1 multiplier on that target size.
func set_preview(obj: Node3D, display_name: String, name_color: Color, fill: float) -> void:
	for child in _holder.get_children():
		child.queue_free()
	_fill = fill
	_holder.scale = Vector3.ONE
	_holder.add_child(obj)
	_object = obj
	_name_label.text = display_name
	_name_label.add_theme_color_override("font_color", name_color)
	tooltip_text = display_name
	set_process(true)
	# The authored model builds in its own _ready (next frame), so fit once it has geometry.
	call_deferred("_fit_object")


## Scales the holder so the object's largest visible dimension fills FIT_SIZE * fill, so
## models of any authored scale read at a uniform, clear size.
func _fit_object() -> void:
	if not is_instance_valid(_object):
		return
	var box := _visible_aabb(_object)
	var max_extent := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if max_extent <= 0.0001:
		_holder.scale = Vector3.ONE * _fill
		return
	_holder.scale = Vector3.ONE * (FIT_SIZE / max_extent) * _fill


## Merged AABB of the visible MeshInstance3D descendants, in `root`'s local space (so the
## invisible hit-proxy sphere and decal projectors don't bloat the fit).
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


func _process(delta: float) -> void:
	if _spin and _object != null and is_instance_valid(_object):
		_object.rotate_y(SPIN_SPEED * delta)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			clicked.emit()
			accept_event()
