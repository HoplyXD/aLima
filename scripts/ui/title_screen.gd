extends Control
## Main-menu title screen.
##
## First scene the game boots into. Pure presentation wiring: "Play" enters the
## shop (the actual game), "Options" opens the global PauseMenu settings overlay,
## and "Quit" exits. The layout lives in title_screen.tscn; this script only
## connects buttons and changes scenes.

const SHOP_SCENE: String = "res://scenes/Shop.tscn"

@onready var _play_button: Button = $VBoxContainer/Play
@onready var _options_button: Button = $VBoxContainer/Options
@onready var _quit_button: Button = $VBoxContainer/Quit


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_play_button.grab_focus()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(SHOP_SCENE)


func _on_options_pressed() -> void:
	PauseMenu.open()


func _on_quit_pressed() -> void:
	get_tree().quit()
