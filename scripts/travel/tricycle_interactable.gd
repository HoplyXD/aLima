class_name TricycleInteractable
extends Interactable3D
## The rideable tricycle (travel system). One sits in every walkable map;
## interacting opens the "Where to go?" destination panel. Composition only —
## the destination logic lives in TravelService/DestinationPanel.

const DESTINATION_PANEL_SCENE := preload("res://scenes/travel/destination_panel.tscn")

var _panel: DestinationPanel


func _ready() -> void:
	super()
	if prompt_text.is_empty():
		prompt_text = "Ride the tricycle"
	if proximity_prompt_text.is_empty():
		proximity_prompt_text = "Press E to ride the tricycle"
	use_proximity = true
	if not activated.is_connected(_on_activated):
		activated.connect(_on_activated)


func _on_activated() -> void:
	if _panel == null:
		_panel = DESTINATION_PANEL_SCENE.instantiate()
		add_child(_panel)
	_panel.open()
