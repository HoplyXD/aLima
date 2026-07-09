extends Node3D
class_name ForbiddenZone

## The Forbidden Zone — a sealed-off section of the Dump Site.
## Quest 3: the salakot spawns here. Player enters from the Dump Site on Day 5.

const PLAYER_SCENE := preload("res://scenes/locations/scrapyard/player.tscn")
const DIALOGUE_BOX_SCENE := preload("res://dialogue/dialogue_box.tscn")
const FRAGMENT_FIND_SCENE := preload("res://scenes/locations/scrapyard/fragment_find.tscn")
const ECHO_HUD_SCENE := preload("res://scenes/ui/echo_hud.tscn")

var _player: CharacterBody3D
var _echo_hud: EchoHud
var _hunt_target_id: String = ""
var _finds: Array[FragmentFind] = []

@onready var _hud: ScrapyardHud = $HUD
@onready var _player_spawn: Node3D = $PlayerSpawn
@onready var _return_interactable: Interactable3D = $ReturnInteractable


func _ready() -> void:
	_spawn_player()
	_setup_return()
	_spawn_salakot_if_needed()
	_spawn_fragment_finds()
	_setup_hud()


func _process(_delta: float) -> void:
	_update_hunt_echo()


func _exit_tree() -> void:
	if not _hunt_target_id.is_empty():
		_hunt_target_id = ""
		EchoController.clear_hunt_target()


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	_player.global_position = _player_spawn.global_position
	add_child(_player)


func _setup_return() -> void:
	_return_interactable.activated.connect(_on_return_pressed)


func _on_return_pressed() -> void:
	SpaceManager.go_to_dump_site()


func _spawn_salakot_if_needed() -> void:
	if QuestService.get_progress("alya_quest_line") != "q3_salakot":
		return
	var salakot := _create_quest_item("salakot")
	if salakot != null:
		add_child(salakot)
		salakot.global_position = Vector3(0, 0.3, 0)


const SALAKOT_MODEL_PATH := (
	"res://assets/3d Assets/Artifacts/Orignal Artifacts Assets" + "/Salakot/salakot.glb"
)


func _create_quest_item(template_id: String) -> Node3D:
	var template := DataRepository.singleton().get_template(template_id)
	if template == null:
		return null
	var area := Area3D.new()
	area.collision_layer = 4
	area.collision_mask = 2
	var shape := CollisionShape3D.new()
	shape.shape = CylinderShape3D.new()
	shape.shape.radius = 0.8
	shape.shape.height = 1.0
	area.add_child(shape)
	# Real salakot model; fall back to a simple mesh if the asset is missing.
	var model := _build_salakot_model()
	area.add_child(model if model != null else _fallback_mesh())
	area.script = load("res://scripts/shop/interactable_3d.gd")
	area.set("prompt_text", "Pick up %s" % template.display_name)
	area.activated.connect(_on_salakot_picked_up.bind(template_id))
	return area


## Instances the salakot glb and normalizes it to a pickup-sized model (~0.7m),
## so it looks right regardless of the asset's native export scale.
func _build_salakot_model() -> Node3D:
	var packed := load(SALAKOT_MODEL_PATH) as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	if model == null:
		return null
	var box := _combined_aabb(model, Transform3D.IDENTITY)
	var largest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if largest > 0.001:
		var s := 0.7 / largest
		model.scale = Vector3(s, s, s)
	model.position.y = 0.1
	return model


## Merges the AABBs of every MeshInstance3D under `node`, expressed in `node`'s space.
func _combined_aabb(node: Node, xform: Transform3D) -> AABB:
	var result := AABB()
	var have := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result = xform * (node as MeshInstance3D).get_aabb()
		have = true
	for child in node.get_children():
		var child_xform := xform
		if child is Node3D:
			child_xform = xform * (child as Node3D).transform
		var sub := _combined_aabb(child, child_xform)
		if sub.size != Vector3.ZERO:
			result = sub if not have else result.merge(sub)
			have = true
	return result


func _fallback_mesh() -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.4
	mesh.bottom_radius = 0.9
	mesh.height = 0.6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.65, 0.25)
	mi.material_override = mat
	return mi


func _on_salakot_picked_up(template_id: String) -> void:
	var instance := ObjectInstance.new()
	instance.template_id = template_id
	instance.uid = _make_uid()
	instance.condition = 0.0
	instance.state = ModelEnums.ObjState.DIRTY
	instance.is_quest_item = true
	GameState.save_state.loop.inventory.append(instance.to_dictionary())
	# Canon: the salakot must be sold back to Sam. Selling it to any marketplace
	# buyer (only Mr. Maverick will take a quest item) fails the quest.
	QuestService.track_quest_item(instance.uid, "alya_quest_line", "sam")
	_show_found_dialogue()


func _make_uid() -> String:
	return "salakot_" + str(randi())


func _show_found_dialogue() -> void:
	var box: DialogueBox = DIALOGUE_BOX_SCENE.instantiate()
	add_child(box)
	(
		box
		. start(
			[
				{"name": "inner", "text": "This is it... the salakot Yuyu was wearing."},
				{
					"name": "inner",
					"text": "I should bring this back to Alya. She'll want to see it."
				},
			]
		)
	)
	box.finished.connect(func() -> void: box.queue_free())


func _setup_hud() -> void:
	_hud.visible = true


# --- Hidden-fragment hunt ------------------------------------------------------


func _spawn_fragment_finds() -> void:
	var hunts := HuntService.spots_for_location("forbidden_zone")
	if hunts.is_empty():
		return
	for hunt in hunts:
		var spot: HidingSpot = hunt["spot"]
		var find: FragmentFind = FRAGMENT_FIND_SCENE.instantiate()
		find.set_fragment_id(hunt["fragment_id"])
		find.position = Vector3(spot.x, 0.3, spot.z)
		find.found.connect(_on_fragment_found)
		add_child(find)
		_finds.append(find)
	if _echo_hud == null:
		_echo_hud = ECHO_HUD_SCENE.instantiate()
		add_child(_echo_hud)


func _update_hunt_echo() -> void:
	var nearest: FragmentFind = null
	var best := INF
	for find in _finds:
		if find == null or not is_instance_valid(find) or find.is_queued_for_deletion():
			continue
		var distance := INF
		if _player != null:
			distance = (find.global_position - _player.global_position).length_squared()
		if distance < best:
			best = distance
			nearest = find
	if nearest == null:
		if not _hunt_target_id.is_empty():
			_hunt_target_id = ""
			EchoController.clear_hunt_target()
		return
	if nearest.fragment_id != _hunt_target_id:
		_hunt_target_id = nearest.fragment_id
		EchoController.set_hunt_target(_hunt_target_id)
	EchoController.set_carrier_position(nearest.global_position)
	if _player != null:
		EchoController.set_listener_position(_player.global_position)


func _on_fragment_found(fragment_id: String) -> void:
	if not _hunt_target_id.is_empty():
		_hunt_target_id = ""
		EchoController.clear_hunt_target()
	if _player != null and _player.has_method("set_input_enabled"):
		_player.set_input_enabled(false)
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	PortalFlowController.flow_finished.connect(_on_portal_flow_finished, CONNECT_ONE_SHOT)
	HuntService.mark_found(fragment_id)
	EventBus.fragment_discovered.emit(fragment_id, "")


func _on_portal_flow_finished(_fragment_id: String) -> void:
	if _player != null and _player.has_method("set_input_enabled"):
		_player.set_input_enabled(true)
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
