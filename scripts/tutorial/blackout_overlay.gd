class_name BlackoutOverlay
extends CanvasLayer
## Day 0 finale blackout (TUT): an input-blocking fade to black over everything
## (above the pause menu), a beat of full darkness while the caller graduates
## the tutorial and reloads the shop, then a fade back in and self-free.
## Lives under the TutorialService autoload so it survives the scene change.

signal blacked_out

const BLACKOUT_LAYER: int = 130
const FADE_IN_S: float = 1.6
const HOLD_S: float = 0.6
const FADE_OUT_S: float = 1.6

var _rect: ColorRect


func _ready() -> void:
	layer = BLACKOUT_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_rect)


## Fades to black, emits blacked_out at full darkness, and waits for fade_out().
func begin() -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 1.0, FADE_IN_S)
	tween.tween_interval(HOLD_S)
	tween.tween_callback(func() -> void: blacked_out.emit())


## Fades back in and frees the overlay.
func fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 0.0, FADE_OUT_S)
	tween.tween_callback(queue_free)
