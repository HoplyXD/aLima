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

const PLAYER_SCENE := preload("res://scenes/locations/scrapyard/player.tscn")
const SCRAP_ITEM_SCENE := preload("res://scenes/locations/scrapyard/scrap_item.tscn")
const QUEST_ITEM_SCENE := preload("res://scenes/locations/scrapyard/quest_item.tscn")
const FRAGMENT_FIND_SCENE := preload("res://scenes/locations/scrapyard/fragment_find.tscn")
const ECHO_HUD_SCENE := preload("res://scenes/ui/echo_hud.tscn")
const AYLA_HANDOFF_SCENE := preload("res://scenes/locations/scrapyard/ayla_handoff_screen.tscn")
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
@onready var _player_door_exit: Marker3D = $Anchors/PlayerDoorExit
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
var _quest_item_spawned: Dictionary = {}
var _pending_dialogue_action: String = ""
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
## Hidden-fragment hunt state for this space: the spawned finds, the echo HUD,
## and which fragment currently drives the EchoController hunt target.
var _echo_hud: EchoHud
var _hunt_target_id: String = ""

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
	_spawn_pending_quest_items()
	_spawn_fragment_finds()
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
	_update_hunt_echo()


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
	# Leaving the SHOP always drops the player at the door exit (even during the Day 0 tutorial), so
	# stepping out is consistent. Any other arrival (from the title / another location) uses the gate.
	var spawn_point := _player_spawn
	if SpaceManager.previous_space == SpaceManager.Space.SHOP and _player_door_exit != null:
		spawn_point = _player_door_exit
	if spawn_point != null:
		_player.global_position = spawn_point.global_position
		# The spawn marker's yaw decides where the player faces on arrival, so the
		# designer can aim the Day 0 opening shot at Yuyu/the yard in the editor.
		# Must go through set_look_yaw so the mouse-look target matches (otherwise
		# the controller snaps back to facing -Z on the first physics frame).
		_player.face_like(spawn_point)


func _create_tutorial_glue() -> TutorialGlue:
	var glue := TutorialGlue.new()
	(
		glue
		. setup(
			"YARD",
			{
				"ayla": _ayla_anchor,
				"door": _door_return,
				"scrap": _ayla_anchor,  # re-targeted per frame to the nearest scrap
				"tricycle": get_node_or_null("Anchors/Tricycle"),
			}
		)
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
	_door_return.activated.connect(_on_return_door_activated)


func _on_return_door_activated() -> void:
	# Day 0 tutorial: the door is locked until the player hands scrap to Ayla.
	# The "intro_greeting" step completes on scrap_submitted; after that, "head_inside"
	# tells the player to go inside. Until scrap is submitted, the door stays locked.
	if TutorialService.is_tutorial_active():
		var step_id := TutorialService.current_step_id()
		if step_id == "intro_greeting":
			if _hud != null:
				_hud.set_prompt("Find scrap and hand it to Ayla first.")
			return
	SpaceManager.go_to_shop()


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
	var quest_progress := QuestService.get_progress("alya_quest_line")

	# The Manong's Keeping (fragment_03): Ayla's post-questline lunchbox arc runs
	# through daily contact. Checked before the welcome-back line so her story
	# can continue past the first questline.
	if _handle_lunchbox_dialogue():
		return

	# Next-loop welcome: Alya greets returning players who completed the quest line
	if QuestService.is_completed("alya_quest_line"):
		_dialogue_box.start(
			_ayla_lines(
				"yard_welcome_back",
				"Ayla: Welcome back! The Dump Site is open if you want to visit."
			)
		)
		_pending_dialogue_action = "yard_welcome_back"
		_enter_overlay()
		return

	# Quest 1: Start dialogue when Day 1 intro is complete
	if quest_progress.is_empty() and GameState.save_state.persistent.day1_intro_completed:
		if not QuestService.is_completed("alya_quest_line"):
			_dialogue_box.start(
				_ayla_lines("q1_start", "Ayla: Hey, can I tell you something about Yuyu?")
			)
			_pending_dialogue_action = "q1_start"
			_enter_overlay()
			return

	# Quest 1: Player found Yuyu's glasses
	if quest_progress == "q1_glasses" and _has_quest_item_in_inventory("yuyu_glasses"):
		_dialogue_box.start(
			_ayla_lines("q1_glasses_found", "Ayla: These are Tito's glasses! Thank you so much!")
		)
		_pending_dialogue_action = "q1_glasses_found"
		_enter_overlay()
		return

	# Existing scrap handoff logic
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


## The Manong's Keeping (fragment_03) dialogue chain, keyed on quest progress.
## Gated on Alya's questline being done and Sam's excavation tools being owned
## (the ROUTE-R8 cross-route gate). Returns true when it presented dialogue.
func _handle_lunchbox_dialogue() -> bool:
	var progress := QuestService.get_progress("ayla_lunchbox")
	if progress == "completed" or progress == "failed":
		return false
	if progress.is_empty():
		if not QuestService.is_completed("alya_quest_line"):
			return false
		if not GameState.save_state.persistent.legacy_items.has("excavation_tools"):
			return false
		if FragmentService.get_state("fragment_03") != ModelEnums.FragmentState.LOCKED:
			return false
		_dialogue_box.start(
			_ayla_lines(
				"lunchbox_start",
				"Ayla: My Tatay's lunchbox is still out there. Dig it out for me, ha?"
			)
		)
		_pending_dialogue_action = "lunchbox_start"
		_enter_overlay()
		return true
	# progress == "lb_dig": the arc advances by what the player is carrying.
	var lunchbox := _find_quest_item_in_inventory("ayla_lunchbox")
	if lunchbox == null:
		_dialogue_box.start(
			_ayla_lines(
				"lunchbox_remind",
				"Ayla: The lunchbox is deep in the Dump Site heaps — Days 3 and 4, ha?"
			)
		)
		_pending_dialogue_action = "lunchbox_remind"
	elif lunchbox.state == ModelEnums.ObjState.DIRTY:
		_dialogue_box.start(
			_ayla_lines("lunchbox_dirty", "Ayla: Not like this, ha? Clean it first.")
		)
		_pending_dialogue_action = "lunchbox_dirty"
	else:
		_dialogue_box.start(_ayla_lines("lunchbox_show", "Ayla: ...That's my Tatay's initials."))
		_pending_dialogue_action = "lunchbox_show"
	_enter_overlay()
	return true


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
	var progress: float
	if TutorialService.is_tutorial_active():
		# Day 0 is clockless: the sun is scripted by tutorial step instead — sunrise
		# through the cleaning lesson, noon for the sell/mall trip, sunset heading home.
		progress = float(SunController.DAY0_PHASES.get(TutorialService.current_step_id(), 0.06))
	else:
		var hour := DayClock.get_fractional_hour()
		progress = clampf((hour - SUNRISE_HOUR) / (SUNSET_HOUR - SUNRISE_HOUR), 0.0, 1.0)

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
		# Include quest items regardless of restoration state
		if (
			not inst.is_quest_item
			and inst.state != ModelEnums.ObjState.CLEAN
			and inst.state != ModelEnums.ObjState.OPEN
		):
			continue
		var template := repo.get_template(inst.template_id)
		var rarity: int = template.base_rarity if template != null else 0
		var color := GlowMapper.get_instance_glow_color(
			rarity, inst.is_carrier, false, inst.is_quest_item
		)
		var preview := _create_preview_for_instance(inst)
		(
			out
			. append(
				{
					"preview": preview,
					"display_name": template.display_name if template != null else inst.template_id,
					"color": color,
					"description": template.description if template != null else "",
					"is_scrap": false,
					"is_quest": inst.is_quest_item,
				}
			)
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
## Also hides her during Day 0 sunset (she is not at the gate when the player returns).
func _refresh_ayla_presence() -> void:
	var present := not AylaService.is_sort_ready()
	# Day 0 sunset: Alya is not at the gate when the player returns from the mall.
	if TutorialService.is_tutorial_active():
		var step_id := TutorialService.current_step_id()
		if step_id == "enter_the_shop" or step_id == "journal_finale":
			present = false
	if _ayla_sprite != null:
		_ayla_sprite.visible = present
	if _ayla_interactable != null:
		_ayla_interactable.set_enabled(present)
		if not present and _hud != null:
			_hud.set_prompt("")


func _on_yard_day_changed(_day: int) -> void:
	GameState.save_state.loop.yard_scrap_remaining = -1
	for child in _scrap_items_root.get_children():
		if child is ScrapItem:
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
	# The scrap the player handed to Ayla left the pool, so the carry inventory
	# must drop it from the hotbar.
	_refresh_hud_hotbar()


func _on_item_inspected(_slot_index: int, data: Dictionary) -> void:
	_open_inspection_overlay(data)


func _open_inspection_overlay(data: Dictionary) -> void:
	if _inspection_overlay != null:
		_inspection_overlay.open(data)
		_enter_overlay()


func _on_dialogue_finished() -> void:
	match _pending_dialogue_action:
		"q1_start":
			QuestService.start_quest("alya_quest_line")
			QuestService.advance_quest("alya_quest_line", "q1_glasses")
			_spawn_quest_item("yuyu_glasses", _get_scrap_bounds())
			_pending_dialogue_action = ""
			_exit_overlay()
		"q1_glasses_found":
			_remove_quest_item_from_inventory("yuyu_glasses")
			QuestService.advance_quest("alya_quest_line", "q1_completed")
			QuestService.unlock_location("dump_site")
			_pending_dialogue_action = ""
			_exit_overlay()
		"lunchbox_start":
			QuestService.start_quest("ayla_lunchbox")
			QuestService.advance_quest("ayla_lunchbox", "lb_dig")
			# The dig item lives in the Dump Site; if that's this scene, spawn now.
			_spawn_pending_quest_items()
			_pending_dialogue_action = ""
			_exit_overlay()
		"lunchbox_show":
			_complete_lunchbox_quest()
			_pending_dialogue_action = ""
			_exit_overlay()
		"yard_welcome_back":
			_pending_dialogue_action = ""
			_exit_overlay()
		_:
			_pending_dialogue_action = ""
			_exit_overlay()
	_refresh_hud_hotbar()


## Showing Ayla the restored lunchbox completes her arc: the lunchbox becomes a
## permanent keepsake (never sold) and her fragment RELEASES into the hunt.
func _complete_lunchbox_quest() -> void:
	_remove_quest_item_from_inventory("ayla_lunchbox")
	if not GameState.save_state.persistent.legacy_items.has("ayla_lunchbox"):
		GameState.save_state.persistent.legacy_items.append("ayla_lunchbox")
	QuestService.ensure_active("ayla_lunchbox")
	QuestService.complete_quest("ayla_lunchbox")
	FragmentService.release_fragment("fragment_03", "ayla_lunchbox")
	var save_result := SaveService.save_game()
	if not save_result.ok:
		push_error("Scrapyard: lunchbox save failed: %s" % save_result.get("error", ""))


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


# --- Hidden-fragment hunt ------------------------------------------------------
#
# Team decision 2026-07-07: RELEASED fragments hide at Spawn-Director-planned
# hiding spots in the walkable spaces. The player tracks the spot by Cultural
# Echoes (EchoController hunt mode + EchoHud); picking the find up fires the
# existing Found -> Portal -> seat chain directly.


## The hiding-spot location key this space serves. DumpSite overrides.
func _hunt_location_id() -> String:
	return "yard"


func _spawn_fragment_finds() -> void:
	# Day 0 has no released fragments and no hunt; skip the HUD entirely.
	if TutorialService.is_tutorial_active():
		return
	var hunts := HuntService.spots_for_location(_hunt_location_id())
	if hunts.is_empty():
		return
	var space := get_world_3d().direct_space_state
	for hunt in hunts:
		var spot: HidingSpot = hunt["spot"]
		var find: FragmentFind = FRAGMENT_FIND_SCENE.instantiate()
		find.set_fragment_id(hunt["fragment_id"])
		find.position = _ground_snap(spot.x, spot.z, space)
		find.found.connect(_on_fragment_found)
		_scrap_items_root.add_child(find)
	_setup_echo_hud()


func _setup_echo_hud() -> void:
	if _echo_hud != null:
		return
	_echo_hud = ECHO_HUD_SCENE.instantiate()
	add_child(_echo_hud)


## Drives the EchoController hunt target: the nearest unfound find in this
## space. Silence rules stay in the controller; this only feeds positions.
func _update_hunt_echo() -> void:
	var nearest := _nearest_fragment_find()
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


func _nearest_fragment_find() -> FragmentFind:
	if _scrap_items_root == null:
		return null
	var best: FragmentFind = null
	var best_distance := INF
	for child in _scrap_items_root.get_children():
		var find := child as FragmentFind
		if find == null or find.is_queued_for_deletion():
			continue
		var distance := INF
		if _player != null:
			distance = (find.global_position - _player.global_position).length_squared()
		if distance < best_distance:
			best_distance = distance
			best = find
	return best


func _on_fragment_found(fragment_id: String) -> void:
	# Free the mouse and freeze the player for the Found -> Unlock overlay; the
	# portal flow signals back when it ends (unlocked or backed out).
	_enter_overlay()
	PortalFlowController.flow_finished.connect(_on_portal_flow_finished, CONNECT_ONE_SHOT)
	if not _hunt_target_id.is_empty():
		_hunt_target_id = ""
		EchoController.clear_hunt_target()
	HuntService.mark_found(fragment_id)
	EventBus.fragment_discovered.emit(fragment_id, "")


func _on_portal_flow_finished(_fragment_id: String) -> void:
	_exit_overlay()
	_refresh_hud_hotbar()


## Raycasts down to sit the find on the actual ground at the authored x/z.
func _ground_snap(x: float, z: float, space: PhysicsDirectSpaceState3D) -> Vector3:
	var query := PhysicsRayQueryParameters3D.new()
	query.from = Vector3(x, 50.0, z)
	query.to = Vector3(x, -10.0, z)
	query.collision_mask = 1
	var result := space.intersect_ray(query)
	if result.is_empty():
		return Vector3(x, 0.3, z)
	var pos: Vector3 = result.position
	pos.y += 0.1
	return pos


func _exit_tree() -> void:
	if not _hunt_target_id.is_empty():
		_hunt_target_id = ""
		EchoController.clear_hunt_target()


# --- Quest helpers -----------------------------------------------------------


func _has_quest_item_in_inventory(template_id: String) -> bool:
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("template_id") == template_id:
			return true
	return false


func _find_quest_item_in_inventory(template_id: String) -> ObjectInstance:
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("template_id") == template_id:
			return ObjectInstance.from_dictionary(raw)
	return null


func _remove_quest_item_from_inventory(template_id: String) -> void:
	var inventory := GameState.save_state.loop.inventory
	for i in range(inventory.size()):
		var raw = inventory[i]
		if raw is Dictionary and raw.get("template_id") == template_id:
			inventory.remove_at(i)
			return


func _get_scrap_bounds() -> Dictionary:
	var scrap_cfg := DataRepository.singleton().get_scrap_config()
	var bounds := scrap_cfg.scatter_bounds
	return {
		"center_x": float(bounds.get("center_x", 0.0)),
		"center_z": float(bounds.get("center_z", -7.0)),
		"size_x": float(bounds.get("size_x", 40.0)),
		"size_z": float(bounds.get("size_z", 34.0)),
	}


func _spawn_quest_item(template_id: String, bounds: Dictionary) -> void:
	if _quest_item_spawned.get(template_id, false):
		return
	var template := DataRepository.singleton().get_template(template_id)
	if template == null:
		return
	_quest_item_spawned[template_id] = true

	var rng := GameState.make_rng("quest_item_%s_day_%d" % [template_id, DayClock.get_day()])
	var space := get_world_3d().direct_space_state
	var placed: Array[Vector3] = []
	var pos := _find_scrap_spawn_position(rng, bounds, space, placed)

	var item: QuestItem = QUEST_ITEM_SCENE.instantiate()
	item.set_template_id(template_id)
	item.position = pos
	item.collected.connect(_on_quest_item_collected)
	_scrap_items_root.add_child(item)


func _on_quest_item_collected(template_id: String) -> void:
	# The lunchbox is quest-essential: selling it to anyone fails the quest
	# (it can only be shown to Ayla, never traded).
	if template_id == "ayla_lunchbox":
		var lunchbox := _find_quest_item_in_inventory("ayla_lunchbox")
		if lunchbox != null:
			QuestService.track_quest_item(lunchbox.uid, "ayla_lunchbox", "ayla")
	_refresh_hud_hotbar()


func _spawn_pending_quest_items() -> void:
	var progress := QuestService.get_progress("alya_quest_line")
	if progress == "q1_glasses" and not _has_quest_item_in_inventory("yuyu_glasses"):
		_spawn_quest_item("yuyu_glasses", _get_scrap_bounds())
