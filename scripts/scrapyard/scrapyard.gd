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
const PHONE_SCENE := preload("res://scenes/ui/phone.tscn")
const BOOK_SCENE := preload("res://scenes/Book/BookViewport.tscn")
const STORAGE_SCREEN_SCENE := preload("res://scenes/ui/storage_screen.tscn")
const ARTIFACT_OBJECT_SCENE := preload("res://scenes/restoration/restoration_artifact.tscn")
const ArtifactScenes := preload("res://scripts/restoration/artifact_scenes.gd")
const INSPECTION_OVERLAY_SCENE := preload("res://scenes/ui/item_inspection_overlay.tscn")

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
@onready var _ayla_sprite: Sprite3D = $Anchors/AylaAnchor/Ayla
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
## Day 0 (TUT) presentation: the tutorial glue overlay and the placeholder
## Yuyu sprite standing beside Ayla while he teaches the forage step.
var _tutorial_glue: TutorialGlue
var _yuyu_sprite: Sprite3D
## Outdoor quick-action overlays (phone/journal from the yard HUD) and the
## outdoor storage crate the artifacts live in.
var _phone: Phone
var _book_viewport: BookViewport
var _storage_screen: StorageScreen
var _storage_interactable: Interactable3D
var _inspection_overlay: ItemInspectionOverlay

const YUYU_PORTRAIT := preload("res://assets/Characters/Uncle.png")

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

## Minimum horizontal distance (metres) between two foraged scrap spawns, so the
## scatter never stacks two on the same spot.
const MIN_SCRAP_SPACING := 2.5


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
	_refresh_ayla_presence()
	AylaService.sort_ready.connect(_on_ayla_sort_ready_yard)
	_setup_scrap_items_root()
	_spawn_scrap_items()
	_setup_outdoor_storage()
	if _hud != null:
		_hud.phone_pressed.connect(_open_phone_overlay)
		_hud.journal_pressed.connect(_open_journal_overlay)
		_hud.item_inspected.connect(_on_item_inspected)
	EventBus.day_changed.connect(_on_yard_day_changed)

	# A fresh save now opens in the YARD (Day 0 starts at the gate with Yuyu), so
	# the yard must start the session too — begin_session() is idempotent (the
	# DayClock.running guard skips it on ordinary shop->yard round trips).
	LoopController.begin_session()

	# Day 0 (TUT): the yard hosts the forage/hand-off steps with the tutorial
	# glue on top, and the clock stays off (time starts on Day 1). Outside the
	# tutorial the hand-placed Yuyu node stays hidden (he vanished with Day 0).
	if TutorialService.is_tutorial_active():
		_create_tutorial_glue()
	else:
		var yuyu_node := get_node_or_null("Anchors/YuyuNpc") as Sprite3D
		if yuyu_node != null:
			yuyu_node.visible = false
		# Keep the day clock running; the shop will resume driving it on return.
		DayClock.running = true

	_inspection_overlay = INSPECTION_OVERLAY_SCENE.instantiate()
	_inspection_overlay.closed.connect(_on_yard_overlay_closed)
	if _hud != null:
		_hud.add_child(_inspection_overlay)
	else:
		add_child(_inspection_overlay)


func _process(delta: float) -> void:
	if DayClock.running:
		DayClock.tick(delta)
	_update_hud()
	_update_sun()
	_update_tutorial_targets()


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
	if _hud != null:
		_player.scrap_prompt_changed.connect(_hud.set_prompt)
	if _player_spawn != null:
		_player.global_position = _player_spawn.global_position
		# The spawn marker's yaw decides where the player faces on arrival, so the
		# designer can aim the Day 0 opening shot at Yuyu/the yard in the editor.
		_player.global_rotation.y = _player_spawn.global_rotation.y


func _create_tutorial_glue() -> TutorialGlue:
	var glue := TutorialGlue.new()
	glue.setup(
		"YARD",
		{
			"ayla": _ayla_anchor,
			"door": _door_return,
			"scrap": _ayla_anchor,  # re-targeted per frame to the nearest scrap
			"tricycle": get_node_or_null("Anchors/Tricycle"),
		}
	)
	add_child(glue)
	_tutorial_glue = glue
	_create_yuyu_sprite()
	return glue


## Resolves the hand-placed Yuyu node (Anchors/YuyuNpc — move him in the
## editor); falls back to a runtime duplicate beside Ayla when the scene lacks
## one. Presentation only; step data decides when he is visible.
func _create_yuyu_sprite() -> void:
	_yuyu_sprite = get_node_or_null("Anchors/YuyuNpc") as Sprite3D
	if _yuyu_sprite != null:
		_yuyu_sprite.visible = false
		return
	if _ayla_sprite == null:
		return
	_yuyu_sprite = _ayla_sprite.duplicate() as Sprite3D
	_yuyu_sprite.name = "YuyuNpc"
	_yuyu_sprite.texture = YUYU_PORTRAIT
	_yuyu_sprite.visible = false
	_ayla_anchor.add_child(_yuyu_sprite)
	_yuyu_sprite.position = _ayla_sprite.position + Vector3(1.4, 0.0, 0.0)


## Per-frame Day 0 presentation: Yuyu's presence follows the step data, and the
## hint arrow tracks the nearest un-foraged scrap until the player holds some,
## then re-aims at Ayla for the hand-off.
func _update_tutorial_targets() -> void:
	if _tutorial_glue == null:
		return
	var step := TutorialService.current_step()
	if _yuyu_sprite != null:
		_yuyu_sprite.visible = (
			TutorialService.is_tutorial_active()
			and ModelUtils.as_string(step.get("space")) == "YARD"
			and ModelUtils.as_string_array(step.get("npcs")).has("yuyu")
		)
	var holding := false
	for count in GameState.save_state.loop.scrap_pool.values():
		if int(count) > 0:
			holding = true
			break
	if holding:
		_tutorial_glue.update_anchor("scrap", _ayla_anchor)
		return
	var nearest := _nearest_scrap_item()
	_tutorial_glue.update_anchor("scrap", nearest if nearest != null else _ayla_anchor)


func _nearest_scrap_item() -> Node3D:
	if _player == null or _scrap_items_root == null:
		return null
	var best: Node3D = null
	var best_distance := INF
	for child in _scrap_items_root.get_children():
		if child is Node3D and (child as Node3D).visible:
			var offset := (child as Node3D).global_position - _player.global_position
			var distance := offset.length_squared()
			if distance < best_distance:
				best_distance = distance
				best = child
	return best


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
	if AylaService.is_sort_ready():
		_dialogue_box.start(
			_ayla_lines(
				"yard_sort_ready",
				"Ayla: Tapos na ko ga-sort. Ginbutang ko na ang baskit sa imo puertahan."
			)
		)
		_enter_overlay()
		return
	if AylaService.is_sort_active():
		_dialogue_box.start(
			_ayla_lines(
				"yard_sorting",
				"Ayla: Busy pa ko ga-sort sang imo scrap. Balik lang after a while, ha?"
			)
		)
		_enter_overlay()
		return
	if _total_scrap_count() == 0:
		_dialogue_box.start(_ayla_lines("yard_empty", "Ayla shrugs. 'Balik kon may dala ka, ha?'"))
		_enter_overlay()
	else:
		if _handoff_screen != null:
			_handoff_screen.open()
		_enter_overlay()


## Loads an authored Ayla dialogue block from the scavenger route, falling back to
## a single-line string if the route or key is missing.
func _ayla_lines(dialogue_key: String, fallback: String) -> Array:
	var route := DataRepository.singleton().get_route("scavenger")
	if route != null:
		var lines: Array = route.dialogue_for(dialogue_key)
		if not lines.is_empty():
			return lines
	return [fallback]


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
	# Day 0 (TUT): the taught forage only scatters common scrap.
	if TutorialService.is_tutorial_active():
		for i in weights.size():
			weights[i] = 1.0 if i == ModelEnums.Rarity.WHITE else 0.0

	var bounds := scrap_cfg.scatter_bounds
	var center_x := float(bounds.get("center_x", 0.0))
	var center_z := float(bounds.get("center_z", -7.0))
	var size_x := float(bounds.get("size_x", 40.0))
	var size_z := float(bounds.get("size_z", 34.0))

	var space := get_world_3d().direct_space_state
	var placed: Array[Vector3] = []
	for i in count:
		var rarity := _pick_rarity(rng, rarity_names, weights)
		var pos := _find_scrap_spawn_position(rng, bounds, space, placed)
		placed.append(pos)
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


## Raycasts downward to place scrap on the actual yard geometry instead of a flat
## y=0.3 plane, so items don't spawn buried under uneven ground or inside debris.
## Falls back to the old flat position if no collision is hit after a few tries.
func _find_scrap_spawn_position(
	rng: RandomNumberGenerator,
	bounds: Dictionary,
	space: PhysicsDirectSpaceState3D,
	placed: Array[Vector3] = []
) -> Vector3:
	var center_x := float(bounds.get("center_x", 0.0))
	var center_z := float(bounds.get("center_z", -7.0))
	var size_x := float(bounds.get("size_x", 40.0))
	var size_z := float(bounds.get("size_z", 34.0))

	var max_attempts := 18
	for attempt in max_attempts:
		var x := center_x + rng.randf_range(-size_x * 0.5, size_x * 0.5)
		var z := center_z + rng.randf_range(-size_z * 0.5, size_z * 0.5)
		var query := PhysicsRayQueryParameters3D.new()
		query.from = Vector3(x, 50.0, z)
		query.to = Vector3(x, -10.0, z)
		query.collision_mask = 1
		var result := space.intersect_ray(query)
		if result.is_empty():
			continue
		var pos: Vector3 = result.position
		pos.y += 0.1
		if pos.y < 0.0:
			continue
		# Keep foraged scrap spread out so two never stack on the same spot.
		if _too_close_to_placed(pos, placed):
			continue
		return pos

	return Vector3(
		center_x + rng.randf_range(-size_x * 0.5, size_x * 0.5),
		0.3,
		center_z + rng.randf_range(-size_z * 0.5, size_z * 0.5)
	)


## True if pos is within MIN_SCRAP_SPACING (on the ground plane) of any already
## placed scrap, so the spawner can reject clustered/overlapping positions.
func _too_close_to_placed(pos: Vector3, placed: Array[Vector3]) -> bool:
	for other in placed:
		if Vector2(pos.x, pos.z).distance_to(Vector2(other.x, other.z)) < MIN_SCRAP_SPACING:
			return true
	return false


func _update_hud() -> void:
	if _hud == null:
		return
	# Day 0 (tutorial) is clockless: show the day tag only (TUT).
	if TutorialService.is_tutorial_active():
		_hud.set_day_zero()
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
	var scrap_total := _total_scrap_count()
	_hud.set_inventory(scrap_total, _restored_inventory_entries())
	_hud.set_quest_count(_count_seated_fragments())


## Restored artifacts shown in the carry inventory as rich dictionaries with
## a 3D preview, display name, glow color, and description.
func _restored_inventory_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var repo := DataRepository.singleton()
	for raw in GameState.save_state.loop.inventory:
		if not (raw is Dictionary):
			continue
		var inst := ObjectInstance.from_dictionary(raw)
		if inst.state != ModelEnums.ObjState.CLEAN and inst.state != ModelEnums.ObjState.OPEN:
			continue
		var template := repo.get_template(inst.template_id)
		var rarity: int = template.base_rarity if template != null else 0
		var color := GlowMapper.get_instance_glow_color(rarity, inst.is_carrier, false)
		var preview := _create_preview_for_instance(inst)
		out.append(
			{
				"preview": preview,
				"display_name": template.display_name if template != null else inst.template_id,
				"color": color,
				"description": template.description if template != null else "",
				"is_scrap": false,
			}
		)
	return out


func _create_preview_for_instance(inst: ObjectInstance) -> RestorationObject3D:
	var repo := DataRepository.singleton()
	var template := repo.get_template(inst.template_id)
	var scene: PackedScene = ArtifactScenes.scene_for(inst.template_id, ARTIFACT_OBJECT_SCENE)
	var obj: RestorationObject3D = scene.instantiate()
	var service := RestorationService.new()
	var seed := inst.uid.hash() ^ (GameState.loop_index * 104729)
	service.present_object(obj, inst, template, seed)
	return obj


func _count_seated_fragments() -> int:
	var count := 0
	for fragment_id in GameState.save_state.persistent.fragments.keys():
		var fragment: Fragment = GameState.save_state.persistent.fragments[fragment_id]
		if fragment.state == ModelEnums.FragmentState.SEATED:
			count += 1
	return count


func _total_scrap_count() -> int:
	var pool: Dictionary = GameState.save_state.loop.scrap_pool
	var total := 0
	for count in pool.values():
		total += int(count)
	return total


func _on_ayla_sort_ready_yard(_day: int, _hour: int) -> void:
	_refresh_ayla_presence()


## Hides/disables yard Ayla when her sorted batch is ready at the shop door;
## she reappears once the player returns to the yard after the sort is consumed.
func _refresh_ayla_presence() -> void:
	var present := not AylaService.is_sort_ready()
	if _ayla_sprite != null:
		_ayla_sprite.visible = present
	if _ayla_interactable != null:
		_ayla_interactable.set_enabled(present)
		if not present and _hud != null:
			_hud.set_prompt("")


func _on_yard_day_changed(_day: int) -> void:
	GameState.save_state.loop.yard_scrap_remaining = -1
	for child in _scrap_items_root.get_children():
		child.queue_free()
	_spawn_scrap_items()


## Outdoor storage crate beside the shop door: all owned artifacts live here;
## interacting opens the same Storage screen the shop's delivery box uses, so
## the player can pick what to bring to the bench. Scrap can sit in storage too
## but never reaches the bench — Ayla has to sort it first. The crate is a
## hand-placed scene node (Anchors/StorageCrate — move it in the editor).
func _setup_outdoor_storage() -> void:
	_storage_interactable = get_node_or_null("Anchors/StorageCrate") as Interactable3D
	if _storage_interactable == null:
		return
	_storage_interactable.activated.connect(_open_storage_overlay)
	if _hud != null:
		_storage_interactable.prompt_changed.connect(_hud.set_prompt)


func _open_storage_overlay() -> void:
	if _storage_screen == null:
		_storage_screen = STORAGE_SCREEN_SCENE.instantiate()
		add_child(_storage_screen)
		_storage_screen.closed.connect(_on_yard_overlay_closed)
	_enter_overlay()
	_storage_screen.open()


func _open_phone_overlay() -> void:
	if _phone == null:
		_phone = PHONE_SCENE.instantiate()
		add_child(_phone)
		_phone.closed.connect(_on_yard_overlay_closed)
	_enter_overlay()
	_phone.open()


func _open_journal_overlay() -> void:
	if _book_viewport == null:
		_book_viewport = BOOK_SCENE.instantiate()
		add_child(_book_viewport)
		_book_viewport.closed.connect(_on_yard_overlay_closed)
	_enter_overlay()
	_book_viewport.open()


func _on_yard_overlay_closed() -> void:
	_exit_overlay()
	_refresh_hud_hotbar()


func _on_handoff_closed() -> void:
	_exit_overlay()


func _on_item_inspected(_slot_index: int, data: Dictionary) -> void:
	_open_inspection_overlay(data)


func _open_inspection_overlay(data: Dictionary) -> void:
	if _inspection_overlay != null:
		_inspection_overlay.open(data)
		_enter_overlay()


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
	if _storage_interactable != null:
		_storage_interactable.set_enabled(enabled)
	if _scrap_items_root != null:
		for child in _scrap_items_root.get_children():
			var interactable := child as Interactable3D
			if interactable != null:
				interactable.set_enabled(enabled)
