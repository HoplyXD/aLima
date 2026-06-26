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

## Meshes with fewer triangles than this are skipped for collision generation.
## Tuning out tiny debris/rocks keeps physics cheap without blocking player movement.
@export var collision_min_triangles: int = 12

## When true, all map mesh collision is merged into a single StaticBody3D +
## ConcavePolygonShape3D. This is much faster for physics broadphase than dozens
## of separate bodies, which matters on low-end devices and the web target.
@export var merge_map_collision: bool = true

@onready var _player_spawn: Marker3D = $Anchors/PlayerSpawn
@onready var _door_return: Interactable3D = $Anchors/DoorReturn
@onready var _map_root: Node3D = $MapRoot
@onready var _hud: ScrapyardHud = $ScrapyardHud
@onready var _sun: DirectionalLight3D = $DirectionalLight3D

const SUNRISE_HOUR: float = 6.0
const SUNSET_HOUR: float = 20.0
const SUN_NOON_ENERGY: float = 3.0
const SUN_HORIZON_ENERGY: float = 1.2
const SUN_NOON_COLOR := Color(1.0, 0.97, 0.88, 1.0)
const SUN_HORIZON_COLOR := Color(1.0, 0.75, 0.45, 1.0)


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
	_update_hud()
	_update_sun()


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


func _update_hud() -> void:
	if _hud == null:
		return
	_hud.set_day(DayClock.get_day(), DayClock.TOTAL_DAYS)
	_hud.set_time(DayClock.get_hour(), DayClock.get_minute())


## Rotates the directional sun light based on the in-game clock so the yard
## lighting matches the time of day (sunrise -> noon -> sunset).
func _update_sun() -> void:
	if _sun == null:
		return
	var hour := DayClock.get_hour() + DayClock.get_minute() / 60.0
	var progress := clampf((hour - SUNRISE_HOUR) / (SUNSET_HOUR - SUNRISE_HOUR), 0.0, 1.0)

	# Elevation: low at horizon at sunrise/sunset, high at noon.
	var elevation := deg_to_rad(90.0 * sin(progress * PI) - 10.0)
	# Azimuth: east (90°) at sunrise to west (-90°) at sunset.
	var azimuth := deg_to_rad(90.0 - progress * 180.0)

	var sun_dir := Vector3(
		cos(elevation) * sin(azimuth),
		sin(elevation),
		-cos(elevation) * cos(azimuth)
	)
	_sun.look_at(_sun.global_position + sun_dir)

	# Warm/dim near the horizon, bright/white at noon.
	var noon_weight := sin(progress * PI)
	_sun.light_energy = lerp(SUN_HORIZON_ENERGY, SUN_NOON_ENERGY, noon_weight)
	_sun.light_color = SUN_HORIZON_COLOR.lerp(SUN_NOON_COLOR, noon_weight)


## Generates trimesh collision for the visual geometry under MapRoot. Keeps the
## authored Collision node intact. Small meshes and excluded names are skipped.
## When merge_map_collision is true, all valid faces are baked into one
## StaticBody3D + ConcavePolygonShape3D under the Collision node for cheap broadphase.
func _generate_map_collision() -> void:
	var skipped := 0
	var faces: PackedVector3Array = PackedVector3Array()
	var xf := _map_root.global_transform.affine_inverse()

	for mesh in _find_mesh_instances(_map_root):
		if mesh.name in collision_exclusions:
			skipped += 1
			continue
		var mesh_data := mesh.mesh
		if mesh_data == null:
			continue
		var local_faces := mesh_data.get_faces()
		if local_faces.size() / 3 < collision_min_triangles:
			skipped += 1
			continue

		if merge_map_collision:
			# Transform face vertices into the Collision node's local space.
			var to_collision := xf * mesh.global_transform
			for v in local_faces:
				faces.append(to_collision * v)
		else:
			# Per-mesh body fallback (expensive broadphase, but fine for small maps).
			var body := StaticBody3D.new()
			body.name = "%s_Collision" % mesh.name
			body.collision_layer = 1
			body.collision_mask = 0
			var shape := CollisionShape3D.new()
			var concave := ConcavePolygonShape3D.new()
			concave.set_faces(local_faces)
			shape.shape = concave
			mesh.add_child(body)
			body.owner = mesh
			shape.owner = mesh

	if merge_map_collision and not faces.is_empty():
		var body := StaticBody3D.new()
		body.name = "MapCollision"
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var concave := ConcavePolygonShape3D.new()
		concave.set_faces(faces)
		shape.shape = concave
		body.add_child(shape)
		$Collision.add_child(body)
		body.owner = self
		shape.owner = self
		print("Scrapyard: merged %d faces into one map collision body (skipped %d small meshes)" % [faces.size() / 3, skipped])
	else:
		print("Scrapyard: generated per-mesh collision (skipped %d small meshes)" % skipped)


## Recursively collects all MeshInstance3D nodes under the given root.
func _find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			result.append(child)
		if child.get_child_count() > 0:
			result.append_array(_find_mesh_instances(child))
	return result
