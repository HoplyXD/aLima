class_name ToolCondition
extends Control
## One condition cell in a tool-sidebar row: the condition's icon with its cleaning-power
## number badged on top. Layout authored in tool_condition.tscn so it is editable; configure()
## fills it from a CleaningPower.conditions_for() entry. Presentation only.

@onready var _icon: TextureRect = %Icon
@onready var _power: Label = %Power


func configure(entry: Dictionary) -> void:
	var display_name := String(entry.get("display_name", ""))
	var tex := _condition_texture(display_name)
	if tex != null:
		_icon.texture = tex
	else:
		_icon.self_modulate = entry.get("color", Color.WHITE)
	_icon.tooltip_text = display_name
	_power.text = str(int(entry.get("power", 0)))


func _condition_texture(display_name: String) -> Texture2D:
	if display_name.is_empty():
		return null
	var path := "res://assets/artifact_conditions/%s.png" % display_name
	return load(path) if ResourceLoader.exists(path) else null
