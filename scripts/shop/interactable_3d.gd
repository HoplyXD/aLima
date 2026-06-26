class_name Interactable3D
extends Area3D
## Reusable diegetic 3D interactable for the shop and scrapyard.
##
## In the shop it is used as a mouse-hover/click prop: it raises a hover prompt,
## highlights the prop, and emits `activated` on a left-click.
##
## In the scrapyard it can additionally work as a proximity trigger: when
## `use_proximity` is enabled, the player entering the Area3D shows a prompt and
## pressing the `interact` InputMap action (default E / gamepad A) emits
## `activated`. This keeps the shop mouse-only while letting the yard support
## first-person keyboard interaction.
##
## Picking relies on the viewport's `physics_object_picking`; the prop needs a
## CollisionShape3D child (composed in the scene). The highlighted mesh is the
## node named by `highlight_path`, else the first MeshInstance3D child.

signal activated  ## Emitted on a confirmed click or proximity interaction.
signal hover_changed(hovering: bool)  ## Pointer entered/left the prop.
signal prompt_changed(text: String)  ## Proximity prompt should update.

const HOVER_SCALE: float = 1.06
const PLAYER_GROUP := "player"
const INPUT_INTERACT := "interact"

@export_multiline var prompt_text: String = ""  ## Default / hover prompt text.
@export_multiline var proximity_prompt_text: String = ""  ## Optional prompt shown when player is near (e.g. "Press E to enter").
@export var interactable_enabled: bool = true
@export var highlight_path: NodePath
@export var use_proximity: bool = false  ## If true, the player can activate this by standing inside and pressing interact.

var _highlight_mesh: MeshInstance3D
var _base_scale: Vector3 = Vector3.ONE
var _hovering: bool = false
var _player_inside: bool = false


func _ready() -> void:
	input_ray_pickable = true
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	if use_proximity:
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		if not body_exited.is_connected(_on_body_exited):
			body_exited.connect(_on_body_exited)
		# Make sure we can detect the player regardless of the scene's default mask.
		collision_mask |= (1 << 1)

	_resolve_highlight_mesh()
	if _highlight_mesh != null:
		_base_scale = _highlight_mesh.scale


## Enables/disables picking and hover feedback. Used to switch the prop off while
## a full-screen overlay (dialogue, triage, restoration, journal) is open so a
## click can't fall through to the shop behind it.
func set_enabled(value: bool) -> void:
	interactable_enabled = value
	input_ray_pickable = value
	if not value:
		_set_hover(false)
		_set_player_inside(false)
		prompt_changed.emit("")


## Triggers the interactable's behavior. Public so the fallback path/tests can
## drive it directly without simulating a physics pick. Respects enabled state.
func activate() -> void:
	if not interactable_enabled:
		return
	activated.emit()


func is_hovering() -> bool:
	return _hovering


func _input(event: InputEvent) -> void:
	if not use_proximity or not interactable_enabled:
		return
	if not _player_inside:
		return
	if event.is_action_pressed(INPUT_INTERACT):
		activate()


# --- Internals ---------------------------------------------------------------


func _resolve_highlight_mesh() -> void:
	if not highlight_path.is_empty():
		_highlight_mesh = get_node_or_null(highlight_path) as MeshInstance3D
	if _highlight_mesh == null:
		for child in get_children():
			if child is MeshInstance3D:
				_highlight_mesh = child as MeshInstance3D
				break


func _on_input_event(
	_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int
) -> void:
	if not interactable_enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			activate()


func _on_mouse_entered() -> void:
	if not interactable_enabled:
		return
	_set_hover(true)


func _on_mouse_exited() -> void:
	_set_hover(false)


func _set_hover(on: bool) -> void:
	if _hovering == on:
		return
	_hovering = on
	_apply_hover_visual(on)
	hover_changed.emit(on)


func _apply_hover_visual(on: bool) -> void:
	if _highlight_mesh == null:
		return
	_highlight_mesh.scale = _base_scale * (HOVER_SCALE if on else 1.0)
	var mat := _highlight_mesh.material_override
	if mat is StandardMaterial3D:
		(mat as StandardMaterial3D).emission_enabled = on


func _on_body_entered(body: Node3D) -> void:
	if not use_proximity or not body.is_in_group(PLAYER_GROUP):
		return
	_set_player_inside(true)


func _on_body_exited(body: Node3D) -> void:
	if not use_proximity or not body.is_in_group(PLAYER_GROUP):
		return
	_set_player_inside(false)


func _set_player_inside(inside: bool) -> void:
	if _player_inside == inside:
		return
	_player_inside = inside
	if not interactable_enabled:
		return
	var text := ""
	if inside:
		text = proximity_prompt_text if not proximity_prompt_text.is_empty() else prompt_text
	prompt_changed.emit(text)
	_apply_hover_visual(inside)
