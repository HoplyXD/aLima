extends Node3D
## Mall exterior controller (travel system / meet-to-sell). A small walkable
## space like the scrapyard: first-person player, a tricycle home, and one
## buyer NPC per pending meet-in-person sale waiting at the "mall" destination.
## Drives the day clock while active (frozen during Day 0 via PAUSE_TUTORIAL).

const PLAYER_SCENE := preload("res://scenes/locations/scrapyard/player.tscn")
const BUYER_NPC_SCENE := preload("res://scenes/locations/mall/buyer_npc.tscn")
const INTERACTABLE_SCRIPT := preload("res://scripts/shop/interactable_3d.gd")

const DESTINATION_ID := "mall"
## Where the tool-shop door stands: beside the storefront, facing the plaza.
const TOOL_SHOP_DOOR := Vector3(5.0, 0.0, -9.5)

var _player: ScrapyardPlayer
## Day 0 presentation glue (created only while the tutorial runs).
var _tutorial_glue: TutorialGlue
var _tool_shop: MallToolShop
## Tools bought in person THIS mall trip — shown in the carry hotbar going home.
var _bought_tool_ids: Array[String] = []

@onready var _player_spawn: Marker3D = $Anchors/PlayerSpawn
@onready var _tricycle: TricycleInteractable = $Anchors/Tricycle
@onready var _buyer_spawns: Node3D = $Anchors/BuyerSpawns
@onready var _hud: ScrapyardHud = $MallHud


func _ready() -> void:
	get_viewport().physics_object_picking = true
	# Safe re-entry point (idempotent): a mid-tutorial save can resume here.
	LoopController.begin_session()
	_spawn_player()
	_spawn_buyers()
	if _hud != null and _tricycle != null:
		_tricycle.prompt_changed.connect(_hud.set_prompt)
	if TutorialService.is_tutorial_active():
		_create_tutorial_glue()
	else:
		DayClock.running = true
	# The sun tracks the clock (or the Day 0 scripted phases — noon at the mall).
	SunController.attach(self, get_node_or_null("DirectionalLight3D") as DirectionalLight3D)
	_setup_tool_shop()


func _process(delta: float) -> void:
	if DayClock.running:
		DayClock.tick(delta)
	_update_hud()


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	if _player_spawn != null:
		_player.global_position = _player_spawn.global_position
		_player.face_like(_player_spawn)


## One buyer per pending meet at this destination, placed on the spawn markers
## round-robin. Interacting hands over the item (BuyerHandoff owns the flow).
func _spawn_buyers() -> void:
	if _buyer_spawns == null:
		return
	var markers: Array = []
	for child in _buyer_spawns.get_children():
		if child is Marker3D:
			markers.append(child)
	if markers.is_empty():
		return
	var meets: Array = MarketplaceService.pending_meets_for(DESTINATION_ID)
	for i in meets.size():
		var meet: Dictionary = meets[i]
		var buyer: BuyerHandoff = BUYER_NPC_SCENE.instantiate()
		add_child(buyer)
		var marker: Marker3D = markers[i % markers.size()]
		buyer.global_position = marker.global_position
		buyer.setup(str(meet.get("uid")), str(meet.get("buyer_id")))
		if _hud != null:
			buyer.prompt_changed.connect(_hud.set_prompt)
		if _tutorial_glue != null:
			_tutorial_glue.update_anchor("buyer", buyer)


func _update_hud() -> void:
	if _hud == null:
		return
	if TutorialService.is_tutorial_active():
		_hud.set_day_zero()
		return
	_hud.set_day(DayClock.get_day(), DayClock.TOTAL_DAYS)
	_hud.set_time(DayClock.get_hour(), DayClock.get_minute())


# --- Mall tool shop (in-person purchases; different stock from the phone) ------


func _setup_tool_shop() -> void:
	_tool_shop = MallToolShop.new()
	add_child(_tool_shop)
	_tool_shop.closed.connect(_on_tool_shop_closed)
	_tool_shop.tool_bought.connect(_on_tool_bought)
	# The shop door: a proximity interactable beside the storefront glass.
	var door := Area3D.new()
	door.name = "ToolShopDoor"
	door.collision_layer = 4
	door.collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 4.0, 2.0)
	shape.shape = box
	shape.position = Vector3(0, 2, 0)
	door.add_child(shape)
	door.set_script(INTERACTABLE_SCRIPT)
	door.set("prompt_text", "Tool Shop")
	door.set("proximity_prompt_text", "Press E to browse tools")
	door.set("use_proximity", true)
	add_child(door)
	door.position = TOOL_SHOP_DOOR
	door.connect("activated", _on_tool_shop_door)
	if _hud != null:
		door.connect("prompt_changed", _hud.set_prompt)


func _on_tool_shop_door() -> void:
	if _tool_shop == null:
		return
	if _player != null:
		_player.set_input_enabled(false)
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_tool_shop.open()


func _on_tool_shop_closed() -> void:
	if _player != null:
		_player.set_input_enabled(true)
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## A tool bought in person rides home in the carry hotbar (slots 2..5).
func _on_tool_bought(tool_id: String) -> void:
	_bought_tool_ids.append(tool_id)
	_refresh_carry_hotbar()


func _refresh_carry_hotbar() -> void:
	if _hud == null:
		return
	var entries: Array[Dictionary] = []
	var repo := DataRepository.singleton()
	for tool_id in _bought_tool_ids:
		var def := repo.get_tool(tool_id)
		if def == null:
			continue
		(
			entries
			. append(
				{
					"preview": RestorationTool.build_tool_model(tool_id),
					"display_name": def.display_name,
					"color": Color(0.75, 0.8, 0.88),
					"description": "Bought at the mall tool shop. Already yours — carry it home.",
				}
			)
		)
	_hud.set_inventory(0, entries)


func _create_tutorial_glue() -> void:
	_tutorial_glue = TutorialGlue.new()
	(
		_tutorial_glue
		. setup(
			"MALL",
			{
				"tricycle": _tricycle,
				"buyer": _tricycle,  # re-targeted to the spawned buyer in _spawn_buyers
			}
		)
	)
	add_child(_tutorial_glue)
	# Buyers spawn before the glue exists on _ready order; re-aim now.
	for child in get_children():
		if child is BuyerHandoff:
			_tutorial_glue.update_anchor("buyer", child)
