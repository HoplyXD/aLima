class_name QuestEntry
extends PanelContainer
## One quest row inside the QuestTracker. Each active quest is its own scene node so
## the quest UI composes as a node tree rather than procedural labels. Clicking a
## row makes its quest the tracked TARGET (highlighted; Q cycles it outside).

## The player clicked this row to target its quest.
signal clicked(quest_id: String)

var quest_id: String = ""
var _tracked: bool = false

@onready var _title: Label = $Margin/VBox/Title
@onready var _objective: Label = $Margin/VBox/Objective


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not quest_id.is_empty():
			clicked.emit(quest_id)
			accept_event()


## Populates the row. `done`/`failed` recolour the title and swap the status glyph.
func set_quest(
	display_name: String, objective: String, done: bool = false, failed: bool = false
) -> void:
	if _title == null:
		return
	var glyph := "◆ "
	var color := UiPalette.BONE
	if done:
		glyph = "✓ "
		color = UiPalette.RARITY_GREEN
	elif failed:
		glyph = "✗ "
		color = Color(0.82, 0.38, 0.36)  # readable wine for failed titles
	if _tracked:
		glyph = "➤ " + glyph
		color = Color(0.95, 0.83, 0.45)  # tracked target reads gold, like the header
	_title.text = glyph + display_name
	_title.add_theme_color_override("font_color", color)
	_objective.text = objective
	_objective.visible = not objective.is_empty()


## Marks this row as the tracked quest target (call before set_quest).
func set_tracked(on: bool) -> void:
	_tracked = on
	self_modulate = Color(1.25, 1.2, 1.0) if on else Color.WHITE
