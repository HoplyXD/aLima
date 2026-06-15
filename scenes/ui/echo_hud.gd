class_name EchoHud
extends CanvasLayer
## Presentation-only Cultural Echo resonance HUD.
##
## Mirrors the EchoController state: normalized proximity, active band names,
## Voice captions, and a non-audio heartbeat pulse. The HUD is fully playable
## with master audio muted. It owns no discovery rules; it only consumes the
## typed state from EchoController.

@onready var _panel: Panel = $Panel
@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _meter: ProgressBar = $Panel/Margin/VBox/Meter
@onready var _meter_label: Label = $Panel/Margin/VBox/MeterLabel
@onready var _bands: Label = $Panel/Margin/VBox/Bands
@onready var _caption: Label = $Panel/Margin/VBox/Caption
@onready var _pulse: ProgressBar = $Panel/Margin/VBox/Pulse
@onready var _loss: Label = $Panel/Margin/VBox/Loss


func _ready() -> void:
	EchoController.state_changed.connect(_on_state_changed)
	_on_state_changed(EchoController.get_state())


func _on_state_changed(state: Dictionary) -> void:
	if not state.get("valid", false):
		_panel.visible = false
		return

	_panel.visible = true
	var proximity: float = state.get("proximity", 0.0)
	_meter.value = proximity
	_meter_label.text = "Resonance %.0f%%" % (proximity * 100.0)

	var bands: Array[String] = state.get("active_bands", [])
	if bands.is_empty():
		_bands.text = "Silent"
	else:
		_bands.text = ", ".join(bands)

	var caption: String = state.get("voice_caption", "")
	_caption.text = caption
	_caption.visible = not caption.is_empty()

	var pulse: float = state.get("heartbeat_pulse", 0.0)
	_pulse.value = pulse
	_pulse.visible = pulse > 0.001

	_loss.visible = false


## Public setter so the controller can also drive the HUD directly.
func set_echo_state(state: Dictionary) -> void:
	_on_state_changed(state)
