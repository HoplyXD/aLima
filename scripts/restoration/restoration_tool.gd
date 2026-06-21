class_name RestorationTool
extends Node3D
## One bench tool prop plus a 2D info panel below it (a SubViewport rendered onto a
## MeshInstance3D quad "layer") showing the tool's durability bar and small labelled
## image boxes of the conditions it can clean, with each condition's cleaning power.
##
## The info layer (InfoPanel) is authored in restoration_tool.tscn so it is visible/
## editable in the editor; the tool body is distinct per-tool development geometry
## built here (a folded cloth, a bristle brush, a solvent bottle, ...). Authored
## models replace it later.
##
## Presentation only: the durability/condition data is handed in by the tool tray —
## this node never reads GameState/SaveService.

## Per-tool prop presets (shape + colours), with a `_default` so any future tool still
## gets a distinct, readable prop.
const PRESENTATION := {
	"soft_cloth": {"shape": "cloth", "color": Color(0.88, 0.84, 0.68)},
	"damp_cloth": {"shape": "cloth", "color": Color(0.55, 0.68, 0.82)},
	"soft_brush":
	{"shape": "brush", "handle": Color(0.74, 0.6, 0.36), "bristle": Color(0.86, 0.78, 0.5)},
	"rust_brush":
	{"shape": "brush", "handle": Color(0.5, 0.36, 0.24), "bristle": Color(0.22, 0.2, 0.16)},
	"polishing_cloth": {"shape": "cloth", "color": Color(0.8, 0.78, 0.6)},
	"solvent": {"shape": "bottle", "color": Color(0.62, 0.78, 0.55)},
	"stain_lifter": {"shape": "bottle", "color": Color(0.78, 0.7, 0.5)},
	"consolidant": {"shape": "bottle", "color": Color(0.7, 0.62, 0.82)},
	"_default": {"shape": "block", "color": Color(0.72, 0.72, 0.74)},
}

@onready var _geometry: Node3D = $Geometry
@onready var _info_panel: MeshInstance3D = $InfoPanel
@onready var _viewport: SubViewport = $InfoPanel/InfoViewport
@onready var _tool_name_label: Label = %ToolNameLabel
@onready var _durability_bar: ProgressBar = %DurabilityBar
@onready var _durability_label: Label = %DurabilityLabel
## A 2-row grid: row 1 is the condition images, row 2 the cleaning powers. Columns
## grow with the number of conditions the tool cleans.
@onready var _conditions_grid: GridContainer = %Conditions
## Authored, editable template for a condition image (size/expand set in the .tscn);
## the script clones it per condition. Hidden at runtime (shown in the editor so you
## can size it).
@onready var _condition_image: TextureRect = %ConditionImage

var _materials: Array = []  ## tool geometry materials (for the selection highlight).


func _ready() -> void:
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
	_build_geometry(tool_id)
	_tool_name_label.text = _tool_display_name(tool_id)
	_set_durability(int(durability.get("current", 0)), int(durability.get("max", 0)))
	_build_conditions(conditions)


## The tool's display name from the catalog (falls back to the id).
func _tool_display_name(tool_id: String) -> String:
	var tool := DataRepository.singleton().get_tool(tool_id)
	return tool.display_name if tool != null else tool_id


## Updates just the durability bar/label live (between full rebuilds).
func update_durability(current: int, max_uses: int) -> void:
	_set_durability(current, max_uses)


## Highlights the prop while it is the selected tool.
func set_selected(on: bool) -> void:
	for mat in _materials:
		if mat is StandardMaterial3D:
			(mat as StandardMaterial3D).emission_enabled = on


## Pointer-hover feedback: the geometry grows slightly (like the shop interactables).
func set_hovered(on: bool) -> void:
	_geometry.scale = Vector3.ONE * (1.08 if on else 1.0)


# --- Info panel --------------------------------------------------------------


func _set_durability(current: int, max_uses: int) -> void:
	# Always show a bar so the player can read tool wear at a glance. An infinite
	# (never-wears) tool shows a full bar with an ∞ label.
	_durability_bar.visible = true
	if max_uses <= 0:
		_durability_bar.max_value = 1
		_durability_bar.value = 1
		_durability_label.text = "Durability ∞"
		return
	_durability_bar.max_value = max_uses
	_durability_bar.value = current
	_durability_label.text = "Durability %d / %d" % [current, max_uses]


func _build_conditions(conditions: Array) -> void:
	# The template is shown in the editor for sizing, but never at runtime.
	_condition_image.visible = false
	# Clear previously built cells but keep the authored image template.
	for child in _conditions_grid.get_children():
		if child != _condition_image:
			child.queue_free()
	if conditions.is_empty():
		_conditions_grid.columns = 1
		var none := Label.new()
		none.text = "General use"
		none.add_theme_font_size_override("font_size", 16)
		none.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_conditions_grid.add_child(none)
		return
	# One column per condition: row 1 is the images, row 2 the powers. The player
	# learns each image's meaning from the journal, so no name text here.
	_conditions_grid.columns = conditions.size()
	for entry in conditions:
		_conditions_grid.add_child(_make_condition_image(entry))
	for entry in conditions:
		_conditions_grid.add_child(_make_power_label(entry))


## A clone of the editable ConditionImage template (so its size is tweakable in the
## .tscn) showing the condition's picture.
func _make_condition_image(entry: Dictionary) -> TextureRect:
	var image: TextureRect = _condition_image.duplicate()
	image.unique_name_in_owner = false  # only the template keeps the % name
	image.visible = true
	var tex := _condition_texture(str(entry.get("display_name", "")))
	if tex != null:
		image.texture = tex
	else:
		image.self_modulate = entry.get("color", Color.WHITE)
	return image


## The tool's cleaning power against the condition above it.
func _make_power_label(entry: Dictionary) -> Label:
	var power := Label.new()
	power.text = "+%d" % int(entry.get("power", 0))
	power.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power.add_theme_font_size_override("font_size", 16)
	power.add_theme_color_override("font_color", Color(0.95, 0.92, 0.7))
	return power


func _condition_texture(display_name: String) -> Texture2D:
	if display_name.is_empty():
		return null
	var path := "res://assets/artifact_conditions/%s.png" % display_name
	return load(path) if ResourceLoader.exists(path) else null


# --- Geometry (distinct placeholder development props) ------------------------


func _build_geometry(tool_id: String) -> void:
	for child in _geometry.get_children():
		child.queue_free()
	_materials.clear()
	var preset: Dictionary = PRESENTATION.get(tool_id, PRESENTATION["_default"])
	match String(preset.get("shape", "block")):
		"cloth":
			_build_cloth(preset)
		"brush":
			_build_brush(preset)
		"bottle":
			_build_bottle(preset)
		_:
			_build_block(preset)


func _build_cloth(preset: Dictionary) -> void:
	var color: Color = preset.get("color", Color(0.88, 0.84, 0.68))
	var pad := _mesh(BoxMesh.new(), color, 0.95)
	(pad.mesh as BoxMesh).size = Vector3(0.32, 0.05, 0.24)
	_geometry.add_child(pad)
	var fold := _mesh(BoxMesh.new(), color.darkened(0.08), 0.95)
	(fold.mesh as BoxMesh).size = Vector3(0.22, 0.045, 0.16)
	fold.position = Vector3(0.04, 0.045, -0.02)
	fold.rotation = Vector3(0.0, deg_to_rad(12.0), 0.0)
	_geometry.add_child(fold)


func _build_brush(preset: Dictionary) -> void:
	var handle := _mesh(BoxMesh.new(), preset.get("handle", Color(0.6, 0.45, 0.28)), 0.7)
	(handle.mesh as BoxMesh).size = Vector3(0.08, 0.05, 0.3)
	_geometry.add_child(handle)
	var bristles := _mesh(BoxMesh.new(), preset.get("bristle", Color(0.2, 0.18, 0.14)), 0.85)
	(bristles.mesh as BoxMesh).size = Vector3(0.1, 0.08, 0.12)
	bristles.position = Vector3(0.0, -0.02, -0.2)
	_geometry.add_child(bristles)


func _build_bottle(preset: Dictionary) -> void:
	var color: Color = preset.get("color", Color(0.62, 0.78, 0.55))
	var body := _mesh(CylinderMesh.new(), color, 0.4)
	var body_mesh := body.mesh as CylinderMesh
	body_mesh.top_radius = 0.08
	body_mesh.bottom_radius = 0.09
	body_mesh.height = 0.22
	_geometry.add_child(body)
	var cap := _mesh(CylinderMesh.new(), color.darkened(0.35), 0.6)
	var cap_mesh := cap.mesh as CylinderMesh
	cap_mesh.top_radius = 0.04
	cap_mesh.bottom_radius = 0.04
	cap_mesh.height = 0.06
	cap.position = Vector3(0.0, 0.14, 0.0)
	_geometry.add_child(cap)


func _build_block(preset: Dictionary) -> void:
	var block := _mesh(BoxMesh.new(), preset.get("color", Color(0.72, 0.72, 0.74)), 0.7)
	(block.mesh as BoxMesh).size = Vector3(0.2, 0.1, 0.2)
	_geometry.add_child(block)


## A MeshInstance3D with a matte, tracked-for-highlight material.
func _mesh(mesh: Mesh, color: Color, roughness: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = 0.2 if roughness < 0.9 else 0.0
	mat.emission = color.lightened(0.45)
	mat.emission_energy_multiplier = 0.6
	mat.emission_enabled = false  # toggled on while selected
	node.material_override = mat
	_materials.append(mat)
	return node
