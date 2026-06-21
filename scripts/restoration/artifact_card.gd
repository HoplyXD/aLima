class_name ArtifactCard
extends PanelContainer
## A square card in the bench's artifact picker: a small rotating 3D preview of the
## artifact (or a rarity-coloured swatch when previews are disabled for performance),
## with the artifact name underneath, coloured by rarity. Clicking it loads that
## artifact onto the bench.
##
## Presentation only — it holds the artifact uid and emits `selected` on click; the
## RestorationView does the loading. The preview mesh is placeholder development
## geometry (a tinted medallion) until real per-artifact models exist.

signal selected(uid: String)

const SPIN_SPEED: float = 0.7  ## Radians/sec; the preview auto-spins so all sides show.
const PREVIEW_SCALE: float = 0.46  ## Shrinks the bench-sized artifact to fit the card.

@onready var _preview_container: SubViewportContainer = %PreviewContainer
@onready var _mesh_holder: Node3D = %MeshHolder
@onready var _swatch: ColorRect = %Swatch
@onready var _name_label: Label = %NameLabel

var _uid: String = ""
var _preview_object: Node3D


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	set_process(false)


## Fills the card. `previews_on` chooses the 3D preview vs the cheap text-only swatch.
## When previews are on the caller follows up with attach_preview() to embed the real
## artifact object (model + condition decals).
func configure(uid: String, display_name: String, rarity_color: Color, previews_on: bool) -> void:
	_uid = uid
	_name_label.text = display_name
	_name_label.add_theme_color_override("font_color", rarity_color)
	tooltip_text = display_name
	_preview_container.visible = previews_on
	_swatch.visible = not previews_on
	if not previews_on:
		_swatch.color = rarity_color
		set_process(false)


## Embeds the real artifact object (built by the view, with its condition decals) into
## the preview viewport. It auto-spins so the player can see every decal — i.e. what
## still needs restoring — before choosing it.
func attach_preview(obj: Node3D) -> void:
	for child in _mesh_holder.get_children():
		child.queue_free()
	# Scale the holder (not the object) — the object resets its own basis when it
	# configures, which would wipe a scale set directly on it.
	_mesh_holder.scale = Vector3.ONE * PREVIEW_SCALE
	_mesh_holder.add_child(obj)
	_preview_object = obj
	set_process(true)


func _process(delta: float) -> void:
	if _preview_object != null and is_instance_valid(_preview_object):
		_preview_object.rotate_y(SPIN_SPEED * delta)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			selected.emit(_uid)
			accept_event()
