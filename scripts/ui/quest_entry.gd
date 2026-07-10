class_name QuestEntry
extends PanelContainer
## One quest row inside the QuestTracker. Each active quest is its own scene node so
## the quest UI composes as a node tree rather than procedural labels.

@onready var _title: Label = $Margin/VBox/Title
@onready var _objective: Label = $Margin/VBox/Objective


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
	_title.text = glyph + display_name
	_title.add_theme_color_override("font_color", color)
	_objective.text = objective
	_objective.visible = not objective.is_empty()
