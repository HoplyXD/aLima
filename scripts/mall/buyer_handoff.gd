class_name BuyerHandoff
extends Interactable3D
## A buyer waiting at the meet location (meet-to-sell). Interacting plays a
## short exchange, then completes the deferred sale through
## MarketplaceService.complete_meet_handoff and despawns. Idempotent: the
## handoff pays at most once even on a double-interact.

const DIALOGUE_BOX_SCENE := preload("res://dialogue/dialogue_box.tscn")

var _uid: String = ""
var _buyer_id: String = ""
var _dialogue: DialogueBox
var _handing_off: bool = false


func _ready() -> void:
	super()
	use_proximity = true
	if prompt_text.is_empty():
		prompt_text = "Hand over the artifact"
	if proximity_prompt_text.is_empty():
		proximity_prompt_text = "Press E to hand over the artifact"
	if not activated.is_connected(_on_activated):
		activated.connect(_on_activated)


## Binds this NPC to a pending meet entry (set by the spawner).
func setup(uid: String, buyer_id: String) -> void:
	_uid = uid
	_buyer_id = buyer_id


func _on_activated() -> void:
	if _handing_off or _uid.is_empty():
		return
	_handing_off = true
	set_enabled(false)
	if _dialogue == null:
		_dialogue = DIALOGUE_BOX_SCENE.instantiate()
		var layer := CanvasLayer.new()
		layer.layer = 60
		add_child(layer)
		layer.add_child(_dialogue)
		_dialogue.finished.connect(_on_dialogue_finished)
	_dialogue.start(
		[
			{"name": "Buyer", "text": "You made it. Let's see the piece..."},
			{"name": "Buyer", "text": "Beautiful work. Here — as agreed."},
		]
	)


func _on_dialogue_finished() -> void:
	var result: Dictionary = MarketplaceService.complete_meet_handoff(_uid)
	if result.get("ok", false):
		queue_free()
	else:
		_handing_off = false
		set_enabled(true)
