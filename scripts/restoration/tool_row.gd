class_name ToolRow
extends PanelContainer
## One editable tool-sidebar row (layout authored in tool_row.tscn).
##
## Shows the slot number + tool name, a still 3D model of the tool, a column of the surface
## conditions it cleans (each with its cleaning power), and a durability bar. Clicking the
## row selects the tool. Presentation only — the sidebar hands it its data; the layout/styling
## live in the .tscn so they can be edited in the editor. The 3D model preview is dropped into
## the authored `ModelHolder` at runtime (it is a live SubViewport, not an editable node).

signal clicked(tool_id: String)

const PREVIEW_CARD_SCENE := preload("res://scenes/restoration/preview_3d_card.tscn")
const CONDITION_SCENE := preload("res://scenes/restoration/tool_condition.tscn")
const MODEL_SIZE := 46

var _tool_id: String = ""
var _model: Preview3DCard

@onready var _highlight: Control = %Highlight
@onready var _number: Label = %NumberLabel
@onready var _name: Label = %NameLabel
@onready var _model_holder: Control = %ModelHolder
@onready var _conditions: HFlowContainer = %Conditions
@onready var _durability_bar: ProgressBar = %DurabilityBar
## Optional: the row may show wear as just the bar (no text). Resolved leniently so the label
## can be removed from tool_row.tscn without breaking.
@onready var _durability_label: Label = get_node_or_null("%DurabilityLabel")


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	_highlight.visible = false
	_build_model()


## Drops a compact, still (non-spinning) tool preview into the authored ModelHolder. The
## Preview3DCard is sized for big cards, so its min sizes are trimmed to fit the small holder.
func _build_model() -> void:
	_model = PREVIEW_CARD_SCENE.instantiate()
	_model.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_model.custom_minimum_size = Vector2.ZERO
	_model.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_model_holder.add_child(_model)
	_set_subtree_ignore_mouse(_model)  # never eat clicks meant for the row
	var preview_container := _model.find_child("PreviewContainer", true, false)
	if preview_container is Control:
		(preview_container as Control).custom_minimum_size = Vector2(MODEL_SIZE, MODEL_SIZE)
	var name_label := _model.find_child("NameLabel", true, false)
	if name_label is Control:
		(name_label as Control).visible = false
		(name_label as Control).custom_minimum_size = Vector2.ZERO
	_model.set_spin(false)


## Fills the row for `tool_id`. `conditions` is `CleaningPower.conditions_for()` output.
func configure(
	number: int,
	tool_id: String,
	display_name: String,
	durability: Dictionary,
	conditions: Array
) -> void:
	_tool_id = tool_id
	_number.text = str(number)
	_name.text = display_name
	_model.set_preview(
		RestorationTool.build_tool_model(tool_id),
		"",
		Color.WHITE,
		RestorationTool.display_fill(tool_id)
	)
	_model.set_spin(false)
	_build_conditions(conditions)
	update_durability(int(durability.get("current", 0)), int(durability.get("max", 0)))


func tool_id() -> String:
	return _tool_id


func set_selected(on: bool) -> void:
	_highlight.visible = on


func update_durability(current: int, max_uses: int) -> void:
	var text := "Durability ∞" if max_uses <= 0 else "Durability %d / %d" % [current, max_uses]
	if max_uses <= 0:
		_durability_bar.max_value = 1
		_durability_bar.value = 1
	else:
		_durability_bar.max_value = max_uses
		_durability_bar.value = current
	_durability_bar.tooltip_text = text
	if _durability_label != null:
		_durability_label.text = text


func _build_conditions(conditions: Array) -> void:
	for child in _conditions.get_children():
		child.queue_free()
	if conditions.is_empty():
		var general := Label.new()
		general.text = "General use"
		general.add_theme_font_size_override("font_size", 12)
		general.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
		_conditions.add_child(general)
		return
	for entry in conditions:
		var cell: ToolCondition = CONDITION_SCENE.instantiate()
		_conditions.add_child(cell)
		cell.configure(entry)


## Recursively makes a subtree mouse-transparent so it never intercepts the row's clicks.
func _set_subtree_ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_subtree_ignore_mouse(child)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			clicked.emit(_tool_id)
			accept_event()
