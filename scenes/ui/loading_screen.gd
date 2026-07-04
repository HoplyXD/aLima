class_name LoadingScreen
extends Control
## Presentation script for res://scenes/ui/loading_screen.tscn.
##
## The scene composes a 3D shop backdrop, a tips panel, and an animated sprite. This script
## only fades the foreground content in/out and exposes a progress hook the transition driver
## (SceneTransition) can feed while the real target scene streams in behind it.
##
## It owns no scene-switching logic — SceneTransition decides when this screen appears and
## when the loaded target replaces it.

## Tips cycled while the screen is up. Replace/extend freely or feed from data.
@export var tips: PackedStringArray = [
	"Drag each find into Keep or Recycle before the day moves on.",
	"A flickering glow plus a heartbeat means a fragment is near.",
	"Clean before you open — a carrier never opens dirty.",
	"Gold finds go to the museum; everything else to the journal.",
]
@export var content_fade_duration: float = 0.35

@onready var _tip_label: Label = $MarginContainer/VBoxContainer/Label2
@onready var _content: MarginContainer = $MarginContainer


func _ready() -> void:
	_pick_tip()


## Fades the foreground tips/sprite in (call after this screen becomes the active scene).
func reveal() -> void:
	if _content == null:
		return
	_content.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_content, "modulate:a", 1.0, content_fade_duration)


## Optional progress hook (0.0–1.0). Wire to a ProgressBar/Label here if the design adds one.
func set_progress(_ratio: float) -> void:
	pass


func _pick_tip() -> void:
	if _tip_label == null or tips.is_empty():
		return
	_tip_label.text = tips[randi() % tips.size()]
