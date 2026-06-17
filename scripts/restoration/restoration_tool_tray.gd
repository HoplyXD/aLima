class_name RestorationToolTray
extends Node3D
## Presentation-only 3D tool props for the focused restoration view (REST-R8).
##
## The cleaning tools are physical things on the workbench: one selectable 3D
## prop per owned tool, laid out along the front of the bench. Selecting a prop
## is how the player chooses a cleaning tool (the 2D HUD buttons are a labelled
## accessibility/fallback path). The selected prop is highlighted and posed as if
## picked up ("in hand"); the others rest flat on the bench.
##
## Like RestorationObject3D, this node carries NO game rules: it never reads
## is_carrier/contents, never touches RestorationService/GameState/SaveService,
## and never decides whether a tool is correct. It is built data-driven from the
## owned ToolDefinitions the view hands it, so it stays artifact-agnostic. The
## geometry is original placeholder development geometry; authored tool models
## replace it later (Phase 13/20).

## Resting position tuning (object space, on the bench top in front of the object).
const BENCH_Y: float = -0.7
const FRONT_Z: float = 0.55
const SLOT_SPACING: float = 1.0

## Selection pose: the chosen tool lifts off the bench and leans toward the object.
const SELECT_LIFT: float = 0.12
const SELECT_FORWARD: float = 0.08
const SELECT_TILT_DEG: float = -22.0

## Analytic pick radius around each prop (matches the simple development geometry).
const PICK_RADIUS: float = 0.32
const PICK_CENTER_OFFSET: Vector3 = Vector3(0.0, 0.06, 0.0)

## Narrowly-scoped presentation adapter keyed by tool id, with a `_default` so any
## future tool still gets a prop without code changes. Presentation only.
const PRESENTATION := {
	"soft_cloth": {"shape": "cloth", "color": Color(0.86, 0.82, 0.66)},
	"rust_brush":
	{
		"shape": "brush",
		"handle_color": Color(0.62, 0.45, 0.28),
		"bristle_color": Color(0.2, 0.18, 0.14)
	},
	"_default": {"shape": "block", "color": Color(0.7, 0.7, 0.72)},
}

var _order: Array[String] = []
var _props: Dictionary = {}  ## tool_id -> Node3D
var _materials: Dictionary = {}  ## tool_id -> Array[StandardMaterial3D]
var _rest_pos: Dictionary = {}  ## tool_id -> Vector3
var _selected: String = ""


## Rebuilds the tool props from the owned tools. Clears any previous props first.
func build_tools(tools: Array[ToolDefinition]) -> void:
	_clear()
	var n := tools.size()
	for i in n:
		var tool := tools[i]
		var x := (float(i) - float(n - 1) / 2.0) * SLOT_SPACING
		var rest := Vector3(x, BENCH_Y, FRONT_Z)
		var prop := _build_prop(tool.id)
		prop.name = "ToolProp_%s" % tool.id
		prop.position = rest
		add_child(prop)
		_props[tool.id] = prop
		_rest_pos[tool.id] = rest
		_order.append(tool.id)
	# Reset any prior selection that no longer exists.
	if not _props.has(_selected):
		_selected = ""
	_apply_poses()


## Highlights/poses the selected prop and rests the rest. Pass "" to deselect all.
func set_selected(tool_id: String) -> void:
	_selected = tool_id if _props.has(tool_id) else ""
	_apply_poses()


## Analytic ray->prop test. Returns the hit tool_id, or "" on a miss. Uses
## ray-sphere math (deterministic, headless-testable) like RestorationObject3D.
func ray_pick(origin: Vector3, direction: Vector3) -> String:
	var best_id := ""
	var best_t := INF
	for id in _order:
		var prop: Node3D = _props[id]
		var center: Vector3 = prop.global_position + PICK_CENTER_OFFSET
		var hit := _ray_sphere(origin, direction, center, PICK_RADIUS)
		if hit.get("hit", false) and float(hit["t"]) < best_t:
			best_t = float(hit["t"])
			best_id = id
	return best_id


func get_tool_ids() -> Array[String]:
	return _order.duplicate()


func get_prop(tool_id: String) -> Node3D:
	return _props.get(tool_id)


func is_selected(tool_id: String) -> bool:
	return _selected == tool_id and not tool_id.is_empty()


func selected_tool_id() -> String:
	return _selected


# --- Poses / highlight -------------------------------------------------------


func _apply_poses() -> void:
	for id in _props.keys():
		var prop: Node3D = _props[id]
		var rest: Vector3 = _rest_pos[id]
		if id == _selected:
			prop.position = rest + Vector3(0.0, SELECT_LIFT, SELECT_FORWARD)
			prop.rotation = Vector3(deg_to_rad(SELECT_TILT_DEG), 0.0, 0.0)
		else:
			prop.position = rest
			prop.rotation = Vector3.ZERO
		_set_prop_highlight(id, id == _selected)


func _set_prop_highlight(tool_id: String, on: bool) -> void:
	var mats: Array = _materials.get(tool_id, [])
	for mat in mats:
		if mat is StandardMaterial3D:
			(mat as StandardMaterial3D).emission_enabled = on


# --- Construction ------------------------------------------------------------


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_order.clear()
	_props.clear()
	_materials.clear()
	_rest_pos.clear()


func _build_prop(tool_id: String) -> Node3D:
	var preset: Dictionary = PRESENTATION.get(tool_id, PRESENTATION["_default"])
	_materials[tool_id] = []
	match String(preset.get("shape", "block")):
		"cloth":
			return _build_cloth(tool_id, preset)
		"brush":
			return _build_brush(tool_id, preset)
		_:
			return _build_block(tool_id, preset)


## A soft folded cleaning cloth: a flat pad with a smaller folded layer on top.
func _build_cloth(tool_id: String, preset: Dictionary) -> Node3D:
	var root := Node3D.new()
	var color: Color = preset.get("color", Color(0.86, 0.82, 0.66))

	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(0.34, 0.05, 0.26)
	var pad := MeshInstance3D.new()
	pad.name = "Pad"
	pad.mesh = pad_mesh
	pad.material_override = _make_cloth_material(tool_id, color)
	root.add_child(pad)

	var fold_mesh := BoxMesh.new()
	fold_mesh.size = Vector3(0.24, 0.045, 0.18)
	var fold := MeshInstance3D.new()
	fold.name = "Fold"
	fold.mesh = fold_mesh
	fold.position = Vector3(0.04, 0.045, -0.02)
	fold.rotation = Vector3(0.0, deg_to_rad(12.0), 0.0)
	fold.material_override = _make_cloth_material(tool_id, color.darkened(0.06))
	root.add_child(fold)
	return root


## A wire/rust brush: a wooden handle with a darker bristle block at one end.
func _build_brush(tool_id: String, preset: Dictionary) -> Node3D:
	var root := Node3D.new()
	var handle_color: Color = preset.get("handle_color", Color(0.62, 0.45, 0.28))
	var bristle_color: Color = preset.get("bristle_color", Color(0.2, 0.18, 0.14))

	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.08, 0.05, 0.3)
	var handle := MeshInstance3D.new()
	handle.name = "Handle"
	handle.mesh = handle_mesh
	handle.material_override = _make_matte_material(tool_id, handle_color)
	root.add_child(handle)

	var bristle_mesh := BoxMesh.new()
	bristle_mesh.size = Vector3(0.1, 0.08, 0.12)
	var bristles := MeshInstance3D.new()
	bristles.name = "Bristles"
	bristles.mesh = bristle_mesh
	bristles.position = Vector3(0.0, -0.02, -0.2)
	bristles.material_override = _make_matte_material(tool_id, bristle_color)
	root.add_child(bristles)
	return root


## Generic placeholder prop for any unmapped tool.
func _build_block(tool_id: String, preset: Dictionary) -> Node3D:
	var root := Node3D.new()
	var color: Color = preset.get("color", Color(0.7, 0.7, 0.72))
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 0.1, 0.22)
	var block := MeshInstance3D.new()
	block.name = "Block"
	block.mesh = mesh
	block.material_override = _make_matte_material(tool_id, color)
	root.add_child(block)
	return root


func _make_cloth_material(tool_id: String, color: Color) -> StandardMaterial3D:
	var mat := _base_material(tool_id, color)
	mat.roughness = 0.95
	mat.metallic = 0.0
	return mat


func _make_matte_material(tool_id: String, color: Color) -> StandardMaterial3D:
	var mat := _base_material(tool_id, color)
	mat.roughness = 0.7
	mat.metallic = 0.2
	return mat


func _base_material(tool_id: String, color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	# Pre-wired highlight: toggled on only while this tool is the selected one.
	mat.emission = color.lightened(0.45)
	mat.emission_energy_multiplier = 0.6
	mat.emission_enabled = false
	var mats: Array = _materials[tool_id]
	mats.append(mat)
	return mat


func _ray_sphere(origin: Vector3, direction: Vector3, center: Vector3, radius: float) -> Dictionary:
	var dir := direction.normalized()
	var oc := origin - center
	var b := oc.dot(dir)
	var c := oc.dot(oc) - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return {"hit": false}
	var sqrt_disc := sqrt(disc)
	var t := -b - sqrt_disc
	if t < 0.0:
		t = -b + sqrt_disc
		if t < 0.0:
			return {"hit": false}
	return {"hit": true, "t": t}
