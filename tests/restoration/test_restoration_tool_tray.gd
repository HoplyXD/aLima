extends GutTest

## Unit tests for the presentation-only RestorationToolTray (P4.8): the visible
## 3D cleaning tool props on the workbench. These cover data-driven prop building,
## analytic ray picking, and the selected-prop highlight/pose. Like the rest of the
## restoration view tests they avoid rendered-pixel assertions and drive selection
## through world-space rays. The tray carries no game rules, so no GameState /
## RestorationService / save setup is needed.

const PICK_DISTANCE := 3.0

var _tray: RestorationToolTray


func before_each() -> void:
	_tray = RestorationToolTray.new()
	add_child_autofree(_tray)
	await wait_physics_frames(1)


func _tool(id: String, display_name: String) -> ToolDefinition:
	var t := ToolDefinition.new()
	t.id = id
	t.display_name = display_name
	t.enables = ["pendant_wipe"]
	t.quality = 1
	return t


func _two_tools() -> Array[ToolDefinition]:
	var tools: Array[ToolDefinition] = [
		_tool("soft_cloth", "Soft Cleaning Cloth"),
		_tool("rust_brush", "Wire Brush"),
	]
	return tools


## A ray that strikes a built prop straight down the camera axis.
func _ray_to(tool_id: String) -> Dictionary:
	var prop := _tray.get_prop(tool_id)
	var center: Vector3 = prop.global_position + RestorationToolTray.PICK_CENTER_OFFSET
	var origin := Vector3(center.x, center.y, center.z + PICK_DISTANCE)
	return {"origin": origin, "dir": Vector3(0.0, 0.0, -1.0)}


func _first_material(tool_id: String) -> StandardMaterial3D:
	return _find_mesh_material(_tray.get_prop(tool_id))


## The prop's geometry now lives under a child node, so search recursively for the
## first VISIBLE MeshInstance3D's StandardMaterial3D (the one the highlight toggles).
## Only visible nodes are checked — hidden geometry nodes (tools not active on this prop)
## share materials across instances and would produce false results.
## Matches _collect_materials: checks get_surface_override_material(0) first (authored
## scene props use surface override), then falls back to material_override (procedural).
func _find_mesh_material(node: Node) -> StandardMaterial3D:
	for child in node.get_children():
		if child is Node3D and not (child as Node3D).visible:
			continue
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var mat: Material = mi.get_surface_override_material(0)
			if mat == null:
				mat = mi.material_override
			if mat is StandardMaterial3D:
				return mat as StandardMaterial3D
		var nested := _find_mesh_material(child)
		if nested != null:
			return nested
	return null


# --- Building ----------------------------------------------------------------


func test_builds_one_prop_per_tool() -> void:
	_tray.build_tools(_two_tools())
	assert_eq(
		_tray.get_tool_ids(), ["soft_cloth", "rust_brush"], "One prop per owned tool, in order"
	)
	assert_not_null(_tray.get_prop("soft_cloth"))
	assert_not_null(_tray.get_prop("rust_brush"))


func test_rebuild_clears_previous_props() -> void:
	_tray.build_tools(_two_tools())
	var single: Array[ToolDefinition] = [_tool("soft_cloth", "Soft Cleaning Cloth")]
	_tray.build_tools(single)
	await wait_physics_frames(1)
	assert_eq(_tray.get_tool_ids(), ["soft_cloth"], "Rebuild replaces the prop set")
	assert_null(_tray.get_prop("rust_brush"), "Old prop is removed")


func test_empty_build_clears_all_props() -> void:
	_tray.build_tools(_two_tools())
	_tray.build_tools([] as Array[ToolDefinition])
	assert_eq(_tray.get_tool_ids().size(), 0, "Empty tool list leaves no props")


# --- Ray picking -------------------------------------------------------------


func test_ray_pick_hits_the_aimed_prop() -> void:
	_tray.build_tools(_two_tools())
	var cloth := _ray_to("soft_cloth")
	assert_eq(_tray.ray_pick(cloth["origin"], cloth["dir"]), "soft_cloth", "Aims at the cloth prop")
	var brush := _ray_to("rust_brush")
	assert_eq(_tray.ray_pick(brush["origin"], brush["dir"]), "rust_brush", "Aims at the brush prop")


func test_ray_pick_miss_returns_empty() -> void:
	_tray.build_tools(_two_tools())
	var hit := _tray.ray_pick(Vector3(8.0, 8.0, 3.0), Vector3(0.0, 0.0, -1.0))
	assert_eq(hit, "", "A ray that misses every prop selects nothing")


# --- Selection highlight / pose ----------------------------------------------


func test_set_selected_distinguishes_the_chosen_prop() -> void:
	_tray.build_tools(_two_tools())
	var resting := _tray.get_prop("soft_cloth").position

	_tray.set_selected("soft_cloth")
	assert_true(_tray.is_selected("soft_cloth"), "Tray reports the selection")
	assert_false(_tray.is_selected("rust_brush"))
	assert_ne(
		_tray.get_prop("soft_cloth").position,
		resting,
		"Selected prop is posed differently from rest (lifted/in hand)"
	)
	assert_eq(
		_tray.get_prop("rust_brush").position,
		_tray_rest_for("rust_brush"),
		"Unselected prop stays at rest"
	)

	var cloth_mat := _first_material("soft_cloth")
	var brush_mat := _first_material("rust_brush")
	assert_true(cloth_mat.emission_enabled, "Selected prop is highlighted")
	assert_false(brush_mat.emission_enabled, "Unselected prop is not highlighted")


func test_deselect_returns_props_to_rest() -> void:
	_tray.build_tools(_two_tools())
	_tray.set_selected("soft_cloth")
	_tray.set_selected("")
	assert_false(_tray.is_selected("soft_cloth"))
	assert_eq(_tray.get_prop("soft_cloth").position, _tray_rest_for("soft_cloth"))
	assert_false(_first_material("soft_cloth").emission_enabled, "Deselect clears the highlight")


## Recomputes a prop's resting layout position (mirrors RestorationToolTray's fixed
## slots: build_tools packs tools into slots 0..n-1, each at a fixed slot centre).
func _tray_rest_for(tool_id: String) -> Vector3:
	var i := _tray.get_tool_ids().find(tool_id)
	var centre := float(RestorationToolTray.SLOT_COUNT - 1) / 2.0
	var x := (float(i) - centre) * RestorationToolTray.SLOT_SPACING
	return Vector3(x, RestorationToolTray.BENCH_Y, RestorationToolTray.FRONT_Z)
