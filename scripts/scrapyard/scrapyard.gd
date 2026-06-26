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
##
## RV2-B adds scrap pickups and Ayla hand-off: scrap items scatter in the yard
## under the non-art ScrapItems node; Ayla has a proximity interactable that
## opens the hand-off UI, which moves scrap into a pending sort. AylaService
## knocks at the shop door ~1 in-game hour later with the sorted batch.

const PLAYER_SCENE := preload("res://scenes/scrapyard/player.tscn")
const SCRAP_ITEM_SCENE := preload("res://scenes/scrapyard/scrap_item.tscn")
const AYLA_HANDOFF_SCENE := preload("res://scenes/scrapyard/ayla_handoff_screen.tscn")
const DIALOGUE_BOX_SCENE := preload("res://dialogue/dialogue_box.tscn")
const INTERACTABLE_SCRIPT := preload("res://scripts/shop/interactable_3d.gd")

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
@onready var _ayla_anchor: Marker3D = $Anchors/AylaAnchor
@onready var _map_root: Node3D = $MapRoot
@onready var _hud: ScrapyardHud = $ScrapyardHud
@onready var _sun: DirectionalLight3D = $DirectionalLight3D
@onready var _world_env: WorldEnvironment = $WorldEnvironment

var _player: ScrapyardPlayer
var _handoff_screen: AylaHandoffScreen
var _ayla_interactable: Interactable3D
var _scrap_items_root: Node3D
var _dialogue_box: DialogueBox
var _overlay_open: bool = false

const SUNRISE_HOUR: float = 6.0
const SUNSET_HOUR: float = 20.0
const SUN_NOON_ENERGY: float = 3.0
const SUN_HORIZON_ENERGY: float = 1.2
const SUN_NOON_COLOR := Color(1.0, 0.97, 0.88, 1.0)
const SUN_HORIZON_COLOR := Color(1.0, 0.75, 0.45, 1.0)

const SKY_NOON_TOP := Color(0.384, 0.643, 0.906, 1.0)
const SKY_NOON_HORIZON := Color(0.624, 0.78, 0.906, 1.0)
const SKY_SUNSET_TOP := Color(0.18, 0.24, 0.42, 1.0)
const SKY_SUNSET_HORIZON := Color(0.95, 0.55, 0.32, 1.0)


func _ready() -> void:
	# The return door and any future yard interactables need physics picking.
	get_viewport().physics_object_picking = true

	_maybe_swap_map()
	if generate_map_collision:
		_generate_map_collision()
	_spawn_player()
	_connect_return_door()
	_connect_hud()
	_setup_handoff_screen()
	_setup_dialogue_box()
	_setup_ayla_interaction()
	_setup_scrap_items_root()
	_spawn_scrap_items()
	EventBus.day_changed.connect(_on_yard_day_changed)

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
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	if _player_spawn != null:
		_player.global_position = _player_spawn.global_position


func _connect_return_door() -> void:
	if _door_return == null:
		return
	_door_return.activated.connect(SpaceManager.go_to_shop)


func _connect_hud() -> void:
	if _hud == null or _door_return == null:
		return
	_door_return.prompt_changed.connect(_hud.set_prompt)


func _setup_handoff_screen() -> void:
	_handoff_screen = AYLA_HANDOFF_SCENE.instantiate()
	_handoff_screen.closed.connect(_on_handoff_closed)
	add_child(_handoff_screen)


func _setup_dialogue_box() -> void:
	_dialogue_box = DIALOGUE_BOX_SCENE.instantiate()
	_dialogue_box.finished.connect(_on_dialogue_finished)
	add_child(_dialogue_box)


func _setup_ayla_interaction() -> void:
	var area := Area3D.new()
	area.name = "AylaInteractable"
	area.collision_layer = 1
	area.collision_mask = 1

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 2.2, 1.2)
	shape.shape = box
	shape.position = Vector3(0, 1.1, 0)
	area.add_child(shape)

	area.set_script(INTERACTABLE_SCRIPT)
	_ayla_interactable = area as Interactable3D
	_ayla_interactable.prompt_text = "Hand scrap to Ayla"
	_ayla_interactable.proximity_prompt_text = "Press E to hand scrap to Ayla"
	_ayla_interactable.use_proximity = true
	_ayla_interactable.activated.connect(_open_handoff)
	if _hud != null:
		_ayla_interactable.prompt_changed.connect(_hud.set_prompt)

	_ayla_anchor.add_child(area)


func _setup_scrap_items_root() -> void:
	_scrap_items_root = Node3D.new()
	_scrap_items_root.name = "ScrapItems"
	add_child(_scrap_items_root)


func _open_handoff() -> void:
	if AylaService.is_sort_active() and not AylaService.is_sort_ready():
		var route := DataRepository.singleton().get_route("scavenger")
		var lines: Array = []
		if route != null:
			lines = route.dialogue_for("yard_sorting")
		if lines.is_empty():
			lines = ["Ayla: Busy pa ko ga-sort sang imo scrap. Balik lang after a while, ha?"]
		_dialogue_box.start(lines)
		_enter_overlay()
		return
	if _total_scrap_count() == 0:
		var route := DataRepository.singleton().get_route("scavenger")
		var lines: Array = []
		if route != null:
			lines = route.dialogue_for("yard_empty")
		if lines.is_empty():
			lines = ["Ayla shrugs. 'Balik kon may dala ka, ha?'"]
		_dialogue_box.start(lines)
		_enter_overlay()
	else:
		if _handoff_screen != null:
			_handoff_screen.open()
		_enter_overlay()


func _spawn_scrap_items() -> void:
	var scrap_cfg := DataRepository.singleton().get_scrap_config()
	var rng := GameState.make_rng("scrap_scatter_day_%d" % DayClock.get_day())

	var desired_count := scrap_cfg.base_scatter_count
	var bonus_key := str(DayClock.get_day())
	desired_count += int(scrap_cfg.per_day_scatter_bonus.get(bonus_key, 0))
	desired_count += rng.randi_range(0, 1)

	var loop := GameState.save_state.loop
	if loop.yard_scrap_remaining < 0:
		loop.yard_scrap_remaining = desired_count

	var count := maxi(loop.yard_scrap_remaining, 0)
	if count <= 0:
		return

	var rarity_names := ModelEnums.RARITY_NAMES
	var weights: Array[float] = []
	for rarity_name in rarity_names:
		weights.append(float(scrap_cfg.yard_scatter_rarity_weights.get(rarity_name, 0.0)))

	var bounds := scrap_cfg.scatter_bounds
	var center_x := float(bounds.get("center_x", 0.0))
	var center_z := float(bounds.get("center_z", -7.0))
	var size_x := float(bounds.get("size_x", 40.0))
	var size_z := float(bounds.get("size_z", 34.0))

	for i in count:
		var rarity := _pick_rarity(rng, rarity_names, weights)
		var pos := Vector3(
			center_x + rng.randf_range(-size_x * 0.5, size_x * 0.5),
			0.3,
			center_z + rng.randf_range(-size_z * 0.5, size_z * 0.5)
		)
		var item: ScrapItem = SCRAP_ITEM_SCENE.instantiate()
		item.set_rarity(rarity)
		item.position = pos
		item.collected.connect(_on_scrap_collected)
		_scrap_items_root.add_child(item)


func _pick_rarity(
	rng: RandomNumberGenerator, names: Array[String], weights: Array[float]
) -> String:
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return names[0]
	var roll := rng.randf() * total
	for i in names.size():
		roll -= weights[i]
		if roll <= 0.0:
			return names[i]
	return names[names.size() - 1]


func _update_hud() -> void:
	if _hud == null:
		return
	_hud.set_day(DayClock.get_day(), DayClock.TOTAL_DAYS)
	_hud.set_time(DayClock.get_hour(), DayClock.get_minute())


## Rotates the directional sun light based on the in-game clock so the yard
## lighting matches the time of day (sunrise -> noon -> sunset).
## Uses the fractional hour so movement is smooth, not snapping once per minute.
func _update_sun() -> void:
	if _sun == null:
		return
	var hour := DayClock.get_fractional_hour()
	var progress := clampf((hour - SUNRISE_HOUR) / (SUNSET_HOUR - SUNRISE_HOUR), 0.0, 1.0)

	# Elevation: low at horizon at sunrise/sunset, high at noon.
	var elevation := deg_to_rad(90.0 * sin(progress * PI) - 10.0)
	# Azimuth: east (90°) at sunrise to west (-90°) at sunset.
	var azimuth := deg_to_rad(90.0 - progress * 180.0)

	# Default directional light points -Z. Rotate so -Z aligns with the sun direction:
	# yaw by -azimuth (east -> west), pitch by -elevation (horizon -> noon).
	_sun.rotation = Vector3(-elevation, -azimuth, 0.0)

	# Warm/dim near the horizon, bright/white at noon.
	var noon_weight := sin(progress * PI)
	_sun.light_energy = lerp(SUN_HORIZON_ENERGY, SUN_NOON_ENERGY, noon_weight)
	_sun.light_color = SUN_HORIZON_COLOR.lerp(SUN_NOON_COLOR, noon_weight)

	# Shift the sky colors so sunrise/sunset look warm and noon looks bright blue.
	_update_sky(noon_weight)


func _update_sky(noon_weight: float) -> void:
	if _world_env == null or _world_env.environment == null:
		return
	var sky: Sky = _world_env.environment.sky
	if sky == null:
		return
	var mat := sky.sky_material
	if mat == null or not mat is ProceduralSkyMaterial:
		return
	var proc := mat as ProceduralSkyMaterial
	proc.sky_top_color = SKY_SUNSET_TOP.lerp(SKY_NOON_TOP, noon_weight)
	proc.sky_horizon_color = SKY_SUNSET_HORIZON.lerp(SKY_NOON_HORIZON, noon_weight)


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
		print(
			(
				"Scrapyard: merged %d faces into one map collision body (skipped %d small meshes)"
				% [faces.size() / 3, skipped]
			)
		)
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


func _on_scrap_collected(_rarity: String) -> void:
	GameState.save_state.loop.yard_scrap_remaining = maxi(
		GameState.save_state.loop.yard_scrap_remaining - 1, 0
	)
	_refresh_hud_hotbar()


func _refresh_hud_hotbar() -> void:
	if _hud == null:
		return
	_hud.set_hotbar(GameState.save_state.loop.scrap_pool)


func _total_scrap_count() -> int:
	var pool: Dictionary = GameState.save_state.loop.scrap_pool
	var total := 0
	for count in pool.values():
		total += int(count)
	return total


func _on_yard_day_changed(_day: int) -> void:
	GameState.save_state.loop.yard_scrap_remaining = -1
	for child in _scrap_items_root.get_children():
		child.queue_free()
	_spawn_scrap_items()


func _on_handoff_closed() -> void:
	_exit_overlay()


func _on_dialogue_finished() -> void:
	_exit_overlay()


func _enter_overlay() -> void:
	if _overlay_open:
		return
	_overlay_open = true
	if _player != null:
		_player.set_input_enabled(false)
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_yard_interactables_enabled(false)


func _exit_overlay() -> void:
	if not _overlay_open:
		return
	_overlay_open = false
	if _player != null:
		_player.set_input_enabled(true)
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_set_yard_interactables_enabled(true)


func _set_yard_interactables_enabled(enabled: bool) -> void:
	if _door_return != null:
		_door_return.set_enabled(enabled)
	if _ayla_interactable != null:
		_ayla_interactable.set_enabled(enabled)
	if _scrap_items_root != null:
		for child in _scrap_items_root.get_children():
			var interactable := child as Interactable3D
			if interactable != null:
				interactable.set_enabled(enabled)
