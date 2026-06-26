class_name ScrapyardHud
extends CanvasLayer
## Minimal HUD for the walkable scrapyard.
##
## Currently only displays proximity interaction prompts (e.g. "Press E to enter").
## All other UI is intentionally omitted so the yard stays clean and immersive.

@onready var _prompt_label: Label = $PromptLabel


func _ready() -> void:
	set_prompt("")


## Shows a prompt at the bottom-center of the screen. Pass an empty string to hide.
func set_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = not text.is_empty()
