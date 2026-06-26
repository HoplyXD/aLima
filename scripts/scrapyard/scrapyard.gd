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

@onready var _player_spawn: Marker3D = $Anchors/PlayerSpawn
@onready var _door_return: Interactable3D = $Anchors/DoorReturn
@onready var _map_root: Node3D = $MapRoot


func _ready() -> void:
	# The return door and any future yard interactables need physics picking.
	get_viewport().physics_object_picking = true

	_maybe_swap_map()
	_spawn_player()
	_connect_return_door()

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
