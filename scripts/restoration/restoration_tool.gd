class_name RestorationTool
extends Node3D
## One bench tool prop plus a 2D info panel below it (a SubViewport rendered onto a
## MeshInstance3D quad "layer") showing the tool's durability bar and small image
## boxes of the conditions it can clean, with each condition's cleaning power.
##
## Both the tool body (Geometry/Body) and the info layer (InfoPanel) are authored in
## restoration_tool.tscn so they are visible/editable in the editor; this script only
## tints the body per tool, fills the info panel, and toggles the selection highlight.
##
## Presentation only: the geometry is placeholder development geometry (authored models
## replace it later) and the durability/condition data is handed in by the tool tray —
## this node never reads GameState/SaveService.

## Per-tool tint colours, with a `_default` so any future tool still reads distinctly.
const TOOL_COLORS := {
	"soft_cloth": Color(0.86, 0.82, 0.66),
	"rust_brush": Color(0.5, 0.36, 0.24),
	"soft_brush": Color(0.74, 0.62, 0.4),
	"damp_cloth": Color(0.55, 0.68, 0.78),
	"solvent": Color(0.7, 0.78, 0.6),
	"_default": Color(0.72, 0.72, 0.74),
}

@onready var _body: MeshInstance3D = $Geometry/Body
@onready var _viewport: SubViewport = $InfoViewport
@onready var _info_panel: MeshInstance3D = $InfoPanel
@onready var _durability_bar: ProgressBar = %DurabilityBar
@onready var _durability_label: Label = %DurabilityLabel
@onready var _conditions_row: HBoxContainer = %ConditionsRow

var _body_material: StandardMaterial3D


func _ready() -> void:
	_body_material = StandardMaterial3D.new()
	_body_material.roughness = 0.8
	_body.material_override = _body_material
	# Show the SubViewport's live render on the info-panel quad. The material draws
	# unshaded and ignores depth so the panel overlays the bench/object behind it.
	var info_mat := StandardMaterial3D.new()
	info_mat.albedo_texture = _viewport.get_texture()
	info_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	info_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	info_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	info_mat.no_depth_test = true
	info_mat.render_priority = 2
	info_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	info_mat.billboard_keep_scale = true
	info_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_info_panel.material_override = info_mat


## Builds the prop for `tool_id` and fills its info panel.
## `durability` is {current, max} (max <= 0 means infinite); `conditions` is the list
## from CleaningPower.conditions_for() ([{id, display_name, color, power}]).
func configure(tool_id: String, durability: Dictionary, conditions: Array) -> void:
	var color: Color = TOOL_COLORS.get(tool_id, TOOL_COLORS["_default"])
	_body_material.albedo_color = color
	_body_material.emission = color.lightened(0.4)
	_body_material.emission_energy_multiplier = 0.6
	_body_material.emission_enabled = false
	_set_durability(int(durability.get("current", 0)), int(durability.get("max", 0)))
	_build_conditions(conditions)


## Highlights the prop while it is the selected tool.
func set_selected(on: bool) -> void:
	if _body_material != null:
		_body_material.emission_enabled = on


# --- Info panel --------------------------------------------------------------


func _set_durability(current: int, max_uses: int) -> void:
	if max_uses <= 0:
		_durability_bar.visible = false
		_durability_label.text = "Durability ∞"
		return
	_durability_bar.visible = true
	_durability_bar.max_value = max_uses
	_durability_bar.value = current
	_durability_label.text = "Durability %d / %d" % [current, max_uses]


func _build_conditions(conditions: Array) -> void:
	for child in _conditions_row.get_children():
		child.queue_free()
	for entry in conditions:
		_conditions_row.add_child(_make_condition_box(entry))


## A small image box: the condition's picture (or a colour swatch fallback) with its
## cleaning power below.
func _make_condition_box(entry: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)

	var tex := _condition_texture(str(entry.get("display_name", "")))
	if tex != null:
		var image := TextureRect.new()
		image.custom_minimum_size = Vector2(30, 30)
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture = tex
		box.add_child(image)
	else:
		var swatch := StyleBoxFlat.new()
		swatch.bg_color = entry.get("color", Color.WHITE)
		swatch.set_corner_radius_all(4)
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(30, 30)
		panel.add_theme_stylebox_override("panel", swatch)
		box.add_child(panel)

	var power := Label.new()
	power.text = str(int(entry.get("power", 0)))
	power.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power.add_theme_font_size_override("font_size", 16)
	power.add_theme_color_override("font_color", Color(0.95, 0.92, 0.7))
	box.add_child(power)
	return box


func _condition_texture(display_name: String) -> Texture2D:
	if display_name.is_empty():
		return null
	var path := "res://assets/artifact_conditions/%s.png" % display_name
	return load(path) if ResourceLoader.exists(path) else null
