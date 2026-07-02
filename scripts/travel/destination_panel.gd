class_name DestinationPanel
extends CanvasLayer
## "Where to go?" tricycle destination chooser (travel system).
##
## Built from TravelService's data-driven destination list: one button per
## reachable destination, with a "(!)" recommendation mark when a buyer waits
## there or the tutorial points there. Choosing a destination rides the
## tricycle (SpaceManager.go_to); Cancel/back closes. Controller/keyboard
## friendly: buttons take focus and "back" closes (§4-P).

signal closed

const PANEL_LAYER: int = 60

var _travel: TravelService

@onready var _buttons_box: VBoxContainer = %DestinationButtons
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	layer = PANEL_LAYER
	visible = false
	_cancel_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		close()


## Opens the chooser for the current space. `travel` may be injected for tests.
func open(travel: TravelService = null) -> void:
	_travel = travel if travel != null else TravelService.new()
	_rebuild_buttons()
	visible = true
	if _buttons_box.get_child_count() > 0:
		(_buttons_box.get_child(0) as Button).grab_focus()
	else:
		_cancel_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _rebuild_buttons() -> void:
	for child in _buttons_box.get_children():
		child.queue_free()
	for raw in _travel.available_from(SpaceManager.current_space):
		var destination: Dictionary = raw
		var destination_id := str(destination.get("id"))
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 56)
		button.focus_mode = Control.FOCUS_ALL
		var label := str(destination.get("display_name", destination_id))
		if _travel.is_recommended(destination_id):
			label += "  (!)"
		button.text = label
		button.pressed.connect(_on_destination_pressed.bind(destination_id))
		_buttons_box.add_child(button)


func _on_destination_pressed(destination_id: String) -> void:
	var space := _travel.space_for(destination_id)
	close()
	if space >= 0:
		SpaceManager.go_to(space as SpaceManager.Space)
