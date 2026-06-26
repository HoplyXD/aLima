extends Node3D
## Root controller for the walkable scrapyard space.
##
## The yard is intentionally split into three concerns:
##   - MapRoot: swappable placeholder or imported Blender-GLB visual geometry.
##   - Collision: Godot-side StaticBody3D floor + perimeter walls.
##   - Anchors: permanent Marker3D/Area3D gameplay points that survive an art swap.
##
## The player is spawned at PlayerSpawn, the return door uses the same
## Interactable3D component as the shop door, and the day clock keeps ticking
## while the yard is loaded.

const PLAYER_SCENE := preload("res://scenes/scrapyard/player.tscn")

## Drop a Blender-exported .glb scene here to replace the placeholder MapRoot
## geometry. The anchors and collision live outside MapRoot and stay intact.
@export var map_scene: PackedScene = null

## When true, generate trimesh collision for every MeshInstance3D under MapRoot.
## Disable if the imported GLB supplies its own -col/-colonly collision meshes.
@export var generate_map_collision: bool = true

## Names of meshes under MapRoot that should NOT receive generated collision.
@export var collision_exclusions: PackedStringArray = []

@onready var _player_spawn: Marker3D = $Anchors/PlayerSpawn
@onready var _door_return: Interactable3D = $Anchors/DoorReturn
@onready var _map_root: Node3D = $MapRoot
@onready var _hud: ScrapyardHud = $ScrapyardHud


func _ready() -> void:
	# The return door and any future yard interactables need physics picking.
	get_viewport().physics_object_picking = true

	_maybe_swap_map()
	if generate_map_collision:
		_generate_map_collision()
	_spawn_player()
	_connect_return_door()
	_connect_hud()

	# Keep the day clock running; the shop will resume driving it on return.
	DayClock.running = true


func _process(delta: float) -> void:
	if DayClock.running:
		DayClock.tick(delta)


func _maybe_swap_map() -> void:
	if map_scene == null:
		return
	# Remove placeholder visual geometry only; anchors and collision survive.
	for child in _map_root.get_children():
		child.queue_free()
	var map := map_scene.instantiate()
	_map_root.add_child(map)


func _spawn_player() -> void:
	var player: ScrapyardPlayer = PLAYER_SCENE.instantiate()
	add_child(player)
	if _player_spawn != null:
		player.global_position = _player_spawn.global_position


func _connect_return_door() -> void:
	if _door_return == null:
		return
	_door_return.activated.connect(SpaceManager.go_to_shop)


func _connect_hud() -> void:
	if _hud == null or _door_return == null:
		return
	_door_return.prompt_changed.connect(_hud.set_prompt)


## Generates StaticBody3D + trimesh collision for every MeshInstance3D found
## under MapRoot. Keeps the authored Collision node intact, so ground/fences/house
## blockers remain. Skips meshes whose names are in collision_exclusions.
func _generate_map_collision() -> void:
	var bodies := 0
	for mesh in _find_mesh_instances(_map_root):
		if mesh.name in collision_exclusions:
			continue
		var mesh_data := mesh.mesh
		if mesh_data == null:
			continue

		var body := StaticBody3D.new()
		body.name = "%s_Collision" % mesh.name
		body.collision_layer = 1
		body.collision_mask = 0

		var shape := CollisionShape3D.new()
		var concave := ConcavePolygonShape3D.new()
		concave.set_faces(mesh_data.get_faces())
		shape.shape = concave
		body.add_child(shape)

		mesh.add_child(body)
		body.owner = mesh
		shape.owner = mesh
		bodies += 1
	print("Scrapyard: generated %d collision bodies from MapRoot meshes" % bodies)


## Recursively collects all MeshInstance3D nodes under the given root.
func _find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			result.append(child)
		if child.get_child_count() > 0:
			result.append_array(_find_mesh_instances(child))
	return result
