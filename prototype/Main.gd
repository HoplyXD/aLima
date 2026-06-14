extends Control

## Temporary harness to exercise the dialogue box. Replace with the shop scene
## once the core slice (see docs/phase-task.md) comes online.

@onready var _box: DialogueBox = $DialogueBox


func _ready() -> void:
	_box.finished.connect(_on_dialogue_finished)
	# Sample lines drawn from the Auntie D1 beat in aLima.twee.
	_box.start([
		{
			"name": "Elderly Auntie",
			"text": "A frail knock. She clutches a [i]cracked photo frame[/i].",
		},
		{
			"name": "You",
			"text": "Let me see it. I can free the photo without tearing the emulsion.",
		},
		"With careful hands you work it loose, whole. She presses your fingers in thanks.",
		"[b]Elderly Auntie Quest 1 complete.[/b]",
	])


func _on_dialogue_finished() -> void:
	print("Dialogue finished.")
