extends Node3D
class_name ArcheologistHouse

## Controller for Sam's archeologist house.
## Quest 3 finale: Sam reveals the truth about Yuyu and releases the archeologist
## fragment (fragment_04) into a dirty carrier the player must clean and open.

## The archeologist's authored fragment (case slot 3, real fact card fragment_04_fact).
const FRAGMENT_CARRIER_ID := "fragment_04"
## Alya's bag is the openable carrier the fragment is sewn into.
const FRAGMENT_CARRIER_TEMPLATE := "cute_bag"
## Sam buys the salakot back (canon). Paid when the finale completes.
const SALAKOT_TEMPLATE := "salakot"
const SALAKOT_BUYBACK := 3000

const PLAYER_SCENE := preload("res://scenes/locations/scrapyard/player.tscn")
const DIALOGUE_BOX_SCENE := preload("res://dialogue/dialogue_box.tscn")
const SAM_PORTRAIT := preload("res://assets/Characters/Archeologist.png")
const ALYA_PORTRAIT := preload("res://assets/Characters/Scavenger.png")

@onready var _sam_npc: Sprite3D = $Anchors/SamNpc
@onready var _alya_npc: Sprite3D = $Anchors/AylaNpc
@onready var _door_interactable: Interactable3D = $Interactables/DoorInteractable
@onready var _player_spawn: Marker3D = $Anchors/PlayerSpawn

var _player: ScrapyardPlayer
var _dialogue_box: DialogueBox
var _pending_dialogue_action: String = ""


func _ready() -> void:
	get_viewport().physics_object_picking = true
	_spawn_player()
	_door_interactable.activated.connect(_on_exit_pressed)
	_setup_dialogue_box()
	if QuestService.is_completed("alya_quest_line"):
		_play_welcome_back()
	else:
		_play_quest_finale()


func _play_welcome_back() -> void:
	(
		_dialogue_box
		. start(
			[
				{
					"name": "Sam",
					"text": "Welcome back, %s. Feel free to look around." % _player_name()
				},
			]
		)
	)
	_pending_dialogue_action = "welcome_back"
	if _player != null:
		_player.set_input_enabled(false)
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	if _player_spawn != null:
		_player.global_position = _player_spawn.global_position
		_player.face_like(_player_spawn)


func _setup_dialogue_box() -> void:
	_dialogue_box = DIALOGUE_BOX_SCENE.instantiate()
	_dialogue_box.finished.connect(_on_dialogue_finished)
	add_child(_dialogue_box)


func _play_quest_finale() -> void:
	# Sam's dialogue
	(
		_dialogue_box
		. start(
			[
				{
					"name": "Sam",
					"text": "Yuyu and I were investigating the master artifact together."
				},
				{"name": "Sam", "text": "We were ambushed in the Dump Site."},
				{
					"name": "Alya",
					"text": "I remember you! You were with Tito Yuyu before he disappeared!"
				},
				{
					"name": "Alya",
					"text":
					"The bag…! I still have it! There's something heavy sewn into the lining — I never opened it."
				},
				{
					"name": "Sam",
					"text": "Give it to %s. But it's filthy after all these years." % _player_name()
				},
				{
					"name": "Sam",
					"text": "Take it home, clean it, then open it. What's inside belongs in your journal."
				},
			]
		)
	)
	_pending_dialogue_action = "quest_finale"
	if _player != null:
		_player.set_input_enabled(false)
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _player_name() -> String:
	var name := GameState.save_state.persistent.player_name
	if name.is_empty():
		return "{player}"
	return name


func _on_dialogue_finished() -> void:
	if _pending_dialogue_action == "quest_finale":
		_pending_dialogue_action = ""
		_hand_fragment_carrier()
		if _player != null:
			_player.set_input_enabled(true)
		if DisplayServer.get_name() != "headless":
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif _pending_dialogue_action == "welcome_back":
		_pending_dialogue_action = ""
		if _player != null:
			_player.set_input_enabled(true)
		if DisplayServer.get_name() != "headless":
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _hand_fragment_carrier() -> void:
	# §4-B/§4-D: no character hands a fragment directly, and a carrier must be
	# cleaned before it can be opened. Sam's Day-5 encounter RELEASES the archeologist
	# fragment into a dirty, openable carrier (Alya's bag). The player carries it back
	# to the shop, cleans it at the workbench, then opens it — only then does the
	# normal fragment_discovered -> Portal -> seat pipeline run.
	# Sam buys the salakot back — remove it from the bag and pay the player (the sale).
	_buy_back_salakot()

	FragmentService.release_fragment(FRAGMENT_CARRIER_ID, "sam_quest")

	var carrier := ObjectInstance.new()
	carrier.template_id = FRAGMENT_CARRIER_TEMPLATE
	carrier.uid = "fragment_carrier_%d" % Time.get_ticks_usec()
	carrier.condition = 0.0
	carrier.state = ModelEnums.ObjState.DIRTY
	carrier.is_carrier = true
	carrier.fragment_id = FRAGMENT_CARRIER_ID
	carrier.contents = ModelEnums.OpenResult.FRAGMENT
	carrier.is_quest_item = true
	GameState.save_state.loop.inventory.append(carrier.to_dictionary())

	# Complete the quest (persists across loops per §4-A).
	QuestService.complete_quest("alya_quest_line")
	SaveService.save_game()


## Removes the salakot from the player's inventory and credits Sam's payment.
func _buy_back_salakot() -> void:
	var inventory: Array = GameState.save_state.loop.inventory
	for i in range(inventory.size()):
		var inst := ObjectInstance.from_dictionary(inventory[i])
		if inst.template_id == SALAKOT_TEMPLATE:
			inventory.remove_at(i)
			GameState.save_state.loop.money += SALAKOT_BUYBACK
			return


func _on_exit_pressed() -> void:
	SpaceManager.go_to_shop()
