class_name DialogueBox
extends Control

## A self-contained dialogue box with a typewriter reveal.
##
## Ported to Godot 4.6 from the design described in worldeater-dev's
## "A simple dialogue system in Godot" devlog and ericdsw/dialogue_system_test
## (both Godot 3.x). The reference splits Dialogue (typing one message) and
## DialogueManager (queue + input); here they are consolidated into one node.
##
## Usage:
##   dialogue_box.start([
##       {"name": "Grandma", "text": "A [i]cracked photo frame[/i]..."},
##       "A line with no speaker.",
##   ])
## Lines may be a String, or a Dictionary with "name" and "text" keys.
## BBCode is supported in the text via the RichTextLabel.

## Emitted each time a new line begins typing, with its index in the queue.
signal line_started(index: int)
## Emitted when the whole queue has been shown and the box closes.
signal finished

## Characters revealed per second during the typewriter effect.
@export var characters_per_second: float = 35.0

var _lines: Array = []
var _index: int = 0
var _is_typing: bool = false
var _blink_tween: Tween

@onready var _name_label: Label = %NameLabel
@onready var _text_label: RichTextLabel = %TextLabel
@onready var _continue_indicator: Label = %ContinueIndicator
@onready var _type_timer: Timer = %TypeTimer


func _ready() -> void:
	_type_timer.timeout.connect(_on_type_timer_timeout)
	_continue_indicator.hide()
	hide()


## Queue and begin showing a list of lines. Ignored if the queue is empty.
func start(lines: Array) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	show()
	_show_line()


## True while the current line is still revealing characters.
func is_typing() -> bool:
	return _is_typing


func _show_line() -> void:
	var line: Variant = _lines[_index]
	var speaker := ""
	var body := ""
	if typeof(line) == TYPE_DICTIONARY:
		speaker = str(line.get("name", ""))
		body = str(line.get("text", ""))
	else:
		body = str(line)

	_name_label.text = speaker
	_name_label.visible = speaker != ""

	_text_label.text = body
	_text_label.visible_characters = 0

	_stop_blink()
	_continue_indicator.hide()

	_is_typing = true
	_type_timer.wait_time = 1.0 / maxf(characters_per_second, 1.0)
	_type_timer.start()
	line_started.emit(_index)


func _on_type_timer_timeout() -> void:
	_text_label.visible_characters += 1
	if _text_label.visible_characters >= _text_label.get_total_character_count():
		_finish_typing()


func _finish_typing() -> void:
	_type_timer.stop()
	_text_label.visible_characters = -1  # -1 shows all characters
	_is_typing = false
	_continue_indicator.show()
	_start_blink()


# Uses _input (not _unhandled_input) so a click on the box itself still counts —
# the panel's mouse_filter would otherwise consume the click first.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var advance := false
	if event.is_action_pressed("ui_accept"):
		advance = true
	elif (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	):
		advance = true
	if advance:
		_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	if _is_typing:
		# First press skips the typewriter to the full line.
		_finish_typing()
		return
	if _index < _lines.size() - 1:
		_index += 1
		_show_line()
	else:
		_close()


func _close() -> void:
	_stop_blink()
	hide()
	_lines = []
	finished.emit()


func _start_blink() -> void:
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_continue_indicator, "modulate:a", 0.2, 0.5)
	_blink_tween.tween_property(_continue_indicator, "modulate:a", 1.0, 0.5)


func _stop_blink() -> void:
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = null
	_continue_indicator.modulate.a = 1.0
