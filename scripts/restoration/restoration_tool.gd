class_name RestorationTool
extends Node3D
## One bench tool prop plus a 2D info panel below it (a SubViewport rendered onto a
## MeshInstance3D quad "layer") showing the tool's durability bar and small labelled
## image boxes of the conditions it can clean, with each condition's cleaning power.
##
## Both the info layer (InfoPanel) and the per-tool props are authored in
## restoration_tool.tscn so they are visible/editable in the editor — each tool's
## geometry is a Node3D under Geometry named after its tool id (soft_cloth, rust_brush,
## solvent, ...), which artists can replace with real models. configure() reveals the
## matching prop; any tool id without authored geometry falls back to the procedural
## placeholder built by build_geometry() below.
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
	_show_tool(tool_id)
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


## Reveals the authored prop whose node name matches `tool_id` (so artists model each
## tool directly in restoration_tool.tscn) and hides the rest, collecting its materials
## for the selection highlight. A tool id without authored geometry falls back to the
## procedural placeholder so it still appears on the bench.
func _show_tool(tool_id: String) -> void:
	_materials.clear()
	# Drop any procedural fallback built for a previous configure() call.
	var prior := _geometry.get_node_or_null("_fallback")
	if prior != null:
		prior.free()
	var matched: Node3D = null
	for child in _geometry.get_children():
		var is_match: bool = String(child.name) == tool_id
		(child as Node3D).visible = is_match
		if is_match:
			matched = child as Node3D
	if matched != null:
		_collect_materials(matched)
		return
	# No authored prop for this id yet — build it procedurally (also keeps the static
	# build_geometry() path that storage previews rely on).
	var holder := build_geometry(tool_id, _materials)
	holder.name = "_fallback"
	_geometry.add_child(holder)


## Gathers the StandardMaterial3D overrides under `root` so set_selected() can toggle
## their emission. Authored placeholders set surface_material_override/0; imported
## models may not, in which case the selection glow is simply a no-op for that tool.
func _collect_materials(root: Node) -> void:
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		var mat: Material = mi.get_surface_override_material(0)
		if mat == null:
			mat = mi.material_override
		if mat is StandardMaterial3D:
			_materials.append(mat)
	for child in root.get_children():
		_collect_materials(child)


## Builds a tool's distinct prop geometry under a fresh Node3D. Static so previews
## elsewhere (e.g. Storage) can show the same 3D tool. Each mesh's material is appended
## to `materials_out` so the caller (the bench prop) can toggle the selection emission.
static func build_geometry(tool_id: String, materials_out: Array = []) -> Node3D:
	var holder := Node3D.new()
	var preset: Dictionary = PRESENTATION.get(tool_id, PRESENTATION["_default"])
	match String(preset.get("shape", "block")):
		"cloth":
			_static_cloth(holder, preset, materials_out)
		"brush":
			_static_brush(holder, preset, materials_out)
		"bottle":
			_static_bottle(holder, preset, materials_out)
		_:
			_static_block(holder, preset, materials_out)
	return holder


static func _static_cloth(holder: Node3D, preset: Dictionary, mats: Array) -> void:
	var color: Color = preset.get("color", Color(0.88, 0.84, 0.68))
	var pad := _static_mesh(holder, BoxMesh.new(), color, 0.95, mats)
	(pad.mesh as BoxMesh).size = Vector3(0.32, 0.05, 0.24)
	var fold := _static_mesh(holder, BoxMesh.new(), color.darkened(0.08), 0.95, mats)
	(fold.mesh as BoxMesh).size = Vector3(0.22, 0.045, 0.16)
	fold.position = Vector3(0.04, 0.045, -0.02)
	fold.rotation = Vector3(0.0, deg_to_rad(12.0), 0.0)


static func _static_brush(holder: Node3D, preset: Dictionary, mats: Array) -> void:
	var handle := _static_mesh(holder, BoxMesh.new(), preset.get("handle", Color(0.6, 0.45, 0.28)), 0.7, mats)
	(handle.mesh as BoxMesh).size = Vector3(0.08, 0.05, 0.3)
	var bristles := _static_mesh(
		holder, BoxMesh.new(), preset.get("bristle", Color(0.2, 0.18, 0.14)), 0.85, mats
	)
	(bristles.mesh as BoxMesh).size = Vector3(0.1, 0.08, 0.12)
	bristles.position = Vector3(0.0, -0.02, -0.2)


static func _static_bottle(holder: Node3D, preset: Dictionary, mats: Array) -> void:
	var color: Color = preset.get("color", Color(0.62, 0.78, 0.55))
	var body := _static_mesh(holder, CylinderMesh.new(), color, 0.4, mats)
	var body_mesh := body.mesh as CylinderMesh
	body_mesh.top_radius = 0.08
	body_mesh.bottom_radius = 0.09
	body_mesh.height = 0.22
	var cap := _static_mesh(holder, CylinderMesh.new(), color.darkened(0.35), 0.6, mats)
	var cap_mesh := cap.mesh as CylinderMesh
	cap_mesh.top_radius = 0.04
	cap_mesh.bottom_radius = 0.04
	cap_mesh.height = 0.06
	cap.position = Vector3(0.0, 0.14, 0.0)


static func _static_block(holder: Node3D, preset: Dictionary, mats: Array) -> void:
	var block := _static_mesh(holder, BoxMesh.new(), preset.get("color", Color(0.72, 0.72, 0.74)), 0.7, mats)
	(block.mesh as BoxMesh).size = Vector3(0.2, 0.1, 0.2)


## A MeshInstance3D child with a matte material (tracked in `mats` for the highlight).
static func _static_mesh(
	holder: Node3D, mesh: Mesh, color: Color, roughness: float, mats: Array
) -> MeshInstance3D:
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
	mats.append(mat)
	holder.add_child(node)
	return node
