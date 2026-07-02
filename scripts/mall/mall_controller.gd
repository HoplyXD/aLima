extends Node3D
## Mall exterior controller (travel system / meet-to-sell). A small walkable
## space like the scrapyard: first-person player, a tricycle home, and one
## buyer NPC per pending meet-in-person sale waiting at the "mall" destination.
## Drives the day clock while active (frozen during Day 0 via PAUSE_TUTORIAL).

const PLAYER_SCENE := preload("res://scenes/scrapyard/player.tscn")
const BUYER_NPC_SCENE := preload("res://scenes/mall/buyer_npc.tscn")

const DESTINATION_ID := "mall"

var _player: ScrapyardPlayer
## Day 0 presentation glue (created only while the tutorial runs).
var _tutorial_glue: TutorialGlue

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


func _create_tutorial_glue() -> void:
	_tutorial_glue = TutorialGlue.new()
	_tutorial_glue.setup(
		"MALL",
		{
			"tricycle": _tricycle,
			"buyer": _tricycle,  # re-targeted to the spawned buyer in _spawn_buyers
		}
	)
	add_child(_tutorial_glue)
	# Buyers spawn before the glue exists on _ready order; re-aim now.
	for child in get_children():
		if child is BuyerHandoff:
			_tutorial_glue.update_anchor("buyer", child)
