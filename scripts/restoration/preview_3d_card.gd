class_name Preview3DCard
extends PanelContainer
## A reusable square card with a rotating 3D object preview and a name underneath.
## Used in Storage to show tools and artifacts as 3D objects the player can read at a
## glance. Presentation only: the caller builds the Node3D to show (tool geometry or a
## configured artifact) and connects `clicked`.

signal clicked

const SPIN_SPEED: float = 0.7  ## Radians/sec auto-spin so all sides/decals show.

@onready var _holder: Node3D = %MeshHolder
@onready var _name_label: Label = %NameLabel

var _object: Node3D


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	set_process(false)


## Embeds `obj` (scaled by `scale`) for the rotating preview and sets the name label.
func set_preview(obj: Node3D, display_name: String, name_color: Color, scale: float) -> void:
	for child in _holder.get_children():
		child.queue_free()
	_holder.scale = Vector3.ONE * scale
	_holder.add_child(obj)
	_object = obj
	_name_label.text = display_name
	_name_label.add_theme_color_override("font_color", name_color)
	tooltip_text = display_name
	set_process(true)


func _process(delta: float) -> void:
	if _object != null and is_instance_valid(_object):
		_object.rotate_y(SPIN_SPEED * delta)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			clicked.emit()
			accept_event()
